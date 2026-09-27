# -----------------------------------------------------------------------------
# AWS Serverless API — Lite (Terraform)
#   API Gateway (REST)  ->  Lambda (Node.js 24, TypeScript, ARM64)
# with throttling, access logs, X-Ray tracing and structured logging.
#
# Want auth (Cognito), a database (DynamoDB), alarms, dashboards, remote state,
# dev/prod stages and CI/CD deploys? See the full starter kit linked in the README.
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.21.0, < 7.0.0" # 6.21 added the nodejs24.x runtime
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.7.0, < 3.0.0"
    }
  }
}

provider "aws" {
  # null = use AWS_REGION or your AWS CLI profile's region, like `cdk deploy` does.
  region = var.aws_region

  default_tags {
    tags = { project = "serverless-api-lite" }
  }
}

data "aws_region" "current" {}

locals {
  name  = "serverless-api-lite"
  stage = "dev"

  # Every endpoint. Add one here and a handler in src/handlers/ (see README).
  routes = {
    "health" = { method = "GET", path = "/health", handler = "health" }
    "hello"  = { method = "POST", path = "/hello", handler = "hello" }
  }

  paths = distinct([for route in values(local.routes) : route.path])
}

# -----------------------------------------------------------------------------
# Lambda functions — one per route
# -----------------------------------------------------------------------------

data "archive_file" "lambda" {
  for_each = local.routes

  type        = "zip"
  source_dir  = "${path.module}/../dist/${each.value.handler}"
  output_path = "${path.module}/../dist/_zips/${each.key}.zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  for_each = local.routes

  name              = "/aws/lambda/${local.name}-${each.key}"
  retention_in_days = 14
}

resource "aws_iam_role" "lambda" {
  for_each = local.routes

  name = "${local.name}-${each.key}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Each function may only write its own logs and send X-Ray traces.
resource "aws_iam_role_policy" "lambda" {
  for_each = local.routes

  name = "logs-and-tracing"
  role = aws_iam_role.lambda[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["${aws_cloudwatch_log_group.lambda[each.key].arn}:*"]
      },
      {
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
        Resource = ["*"]
      },
    ]
  })
}

resource "aws_lambda_function" "this" {
  for_each = local.routes

  function_name = "${local.name}-${each.key}"
  role          = aws_iam_role.lambda[each.key].arn
  runtime       = "nodejs24.x"
  architectures = ["arm64"]
  handler       = "index.handler"
  memory_size   = 256
  timeout       = 10

  filename         = data.archive_file.lambda[each.key].output_path
  source_code_hash = data.archive_file.lambda[each.key].output_base64sha256

  environment {
    variables = {
      STAGE                   = local.stage
      POWERTOOLS_SERVICE_NAME = local.name
      POWERTOOLS_LOG_LEVEL    = "INFO"
      NODE_OPTIONS            = "--enable-source-maps"
    }
  }

  tracing_config {
    mode = "Active"
  }

  logging_config {
    log_format = "Text" # Powertools already writes structured JSON
    log_group  = aws_cloudwatch_log_group.lambda[each.key].name
  }

  depends_on = [aws_iam_role_policy.lambda]
}

resource "aws_lambda_permission" "api_gateway" {
  for_each = local.routes

  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/${each.value.method}${each.value.path}"
}

# -----------------------------------------------------------------------------
# API Gateway (REST) — defined as an OpenAPI document built from local.routes
# -----------------------------------------------------------------------------

locals {
  cors_preflight = {
    responses = {
      "204" = {
        description = "CORS preflight"
        headers = {
          "Access-Control-Allow-Origin"  = { schema = { type = "string" } }
          "Access-Control-Allow-Methods" = { schema = { type = "string" } }
          "Access-Control-Allow-Headers" = { schema = { type = "string" } }
        }
      }
    }
    "x-amazon-apigateway-integration" = {
      type             = "mock"
      requestTemplates = { "application/json" = "{\"statusCode\": 204}" }
      responses = {
        default = {
          statusCode = "204"
          responseParameters = {
            "method.response.header.Access-Control-Allow-Origin"  = "'*'"
            "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
            "method.response.header.Access-Control-Allow-Headers" = "'Content-Type'"
          }
        }
      }
    }
  }

  openapi = {
    openapi = "3.0.1"
    info    = { title = local.name, version = "1.0.0" }
    paths = {
      for path in local.paths : path => merge(
        {
          for key, route in local.routes : lower(route.method) => {
            "x-amazon-apigateway-integration" = {
              type                = "aws_proxy"
              httpMethod          = "POST"
              uri                 = aws_lambda_function.this[key].invoke_arn
              passthroughBehavior = "when_no_match"
            }
          } if route.path == path
        },
        { options = local.cors_preflight },
      )
    }
  }
}

resource "aws_api_gateway_rest_api" "this" {
  name = local.name
  body = jsonencode(local.openapi)

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  triggers    = { redeployment = sha1(aws_api_gateway_rest_api.this.body) }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "api_access" {
  name              = "/aws/apigateway/${local.name}/access"
  retention_in_days = 14
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id          = aws_api_gateway_rest_api.this.id
  deployment_id        = aws_api_gateway_deployment.this.id
  stage_name           = local.stage
  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      user           = "$context.identity.user"
      caller         = "$context.identity.caller"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  depends_on = [aws_api_gateway_account.this]
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    throttling_rate_limit  = 10
    throttling_burst_limit = 20
  }
}

# API Gateway needs an account-level role to write access logs to CloudWatch
# (the same thing CDK's `cloudWatchRole: true` creates). It is an account-wide
# setting: set manage_api_gateway_account = false if your account already has one.
resource "aws_iam_role" "api_gateway_cloudwatch" {
  count = var.manage_api_gateway_account ? 1 : 0

  name = "${local.name}-apigw-cloudwatch"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  count = var.manage_api_gateway_account ? 1 : 0

  role       = aws_iam_role.api_gateway_cloudwatch[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "this" {
  count = var.manage_api_gateway_account ? 1 : 0

  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch[0].arn
  depends_on          = [aws_iam_role_policy_attachment.api_gateway_cloudwatch]
}
