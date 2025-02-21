variable "aws_region" {}
variable "vpc_ids" { type = list(string) }
variable "lambda_function_name" {}
variable "security_group_name" {}
variable "event_bus_name" {}
variable "event_rule_name" {}
variable "lambda_role_name" {}
variable "lambda_policy_name" {}