provider "aws" {
  region = var.aws_region
}

resource "aws_lambda_function" "forticnapp_isolation" {
  function_name = var.lambda_function_name
  filename      = "lambda_function.zip"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.13"
  role          = aws_iam_role.lambda_role.arn
    environment {
    variables = {
      SECURITY_GROUP_NAME = var.security_group_name
    }
  }
}



resource "aws_security_group" "block_all" {
  count  = length(var.vpc_ids)
  vpc_id = var.vpc_ids[count.index]
  name   = var.security_group_name
  description = "Security group with no ingress or egress rules"
}

resource "aws_cloudwatch_event_bus" "forticnapp_event_bus" {
  name = var.event_bus_name
}

resource "aws_cloudwatch_event_rule" "forticnapp_event_rule" {
  name           = var.event_rule_name
  event_bus_name = aws_cloudwatch_event_bus.forticnapp_event_bus.name
  event_pattern  = jsonencode({"account": ["434813966438"]})
}

resource "aws_cloudwatch_event_target" "forticnapp_lambda_target" {
  rule           = aws_cloudwatch_event_rule.forticnapp_event_rule.name
  arn            = aws_lambda_function.forticnapp_isolation.arn
  event_bus_name = aws_cloudwatch_event_bus.forticnapp_event_bus.name
}

resource "aws_iam_role" "lambda_role" {
  name = var.lambda_role_name
  assume_role_policy = jsonencode({
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }],
    Version = "2012-10-17"
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = var.lambda_policy_name
  description = "Policy for Lambda to manage EC2 and Security Groups"
  policy = jsonencode({
    Statement = [{
      Action   = ["ec2:Describe*", "ec2:ModifyInstanceAttribute", "ec2:RevokeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupIngress", "ec2:DeleteSecurityGroup"],
      Effect   = "Allow",
      Resource = "*"
    }],
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_iam_policy_attachment" "lambda_logs" {
  name       = "lambda_logs_attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.forticnapp_isolation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.forticnapp_event_rule.arn
}