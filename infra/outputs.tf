output "api_url" {
  description = "Base URL of the API, e.g. https://abc123.execute-api.us-east-1.amazonaws.com/dev"
  value       = aws_api_gateway_stage.this.invoke_url
}

output "region" {
  value = data.aws_region.current.region
}
