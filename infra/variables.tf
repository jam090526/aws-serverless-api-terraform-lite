variable "aws_region" {
  description = "Region to deploy to. Leave null to use AWS_REGION or your AWS CLI profile's region."
  type        = string
  default     = null
}

variable "manage_api_gateway_account" {
  description = "Create the account-wide CloudWatch role API Gateway needs for access logs. Set to false if your account already has one."
  type        = bool
  default     = true
}
