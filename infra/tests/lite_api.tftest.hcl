# Infrastructure tests with mocked providers: no AWS account or credentials needed.
# Run with: npm run test:infra

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
      name   = "us-east-1"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/test-role"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/lambda/test"
    }
  }

  mock_resource "aws_lambda_function" {
    defaults = {
      invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:test/invocations"
    }
  }

  mock_resource "aws_api_gateway_rest_api" {
    defaults = {
      execution_arn = "arn:aws:execute-api:us-east-1:123456789012:abc123"
    }
  }
}

mock_provider "archive" {
  mock_data "archive_file" {
    defaults = {
      output_base64sha256 = "47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU="
    }
  }
}

run "creates_two_nodejs_24_arm_functions_with_tracing" {
  command = apply

  assert {
    condition     = length(aws_lambda_function.this) == 2
    error_message = "Expected 2 functions."
  }

  assert {
    condition = alltrue([
      for fn in aws_lambda_function.this :
      fn.runtime == "nodejs24.x" && fn.architectures[0] == "arm64" && fn.tracing_config[0].mode == "Active"
    ])
    error_message = "Every function must be Node.js 24 on ARM64 with active tracing."
  }
}

run "applies_throttling_tracing_and_access_logs_to_the_stage" {
  command = apply

  assert {
    condition     = aws_api_gateway_stage.this.xray_tracing_enabled && length(aws_api_gateway_stage.this.access_log_settings) == 1
    error_message = "Stage must have tracing and access logs."
  }

  assert {
    condition = (
      aws_api_gateway_method_settings.all.settings[0].throttling_rate_limit == 10 &&
      aws_api_gateway_method_settings.all.settings[0].throttling_burst_limit == 20
    )
    error_message = "Stage throttling must be 10 requests/second with bursts of 20."
  }
}
