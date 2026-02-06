provider "aws" {
  region = var.aws_region
}

resource "aws_lambda_function" "forticnapp_lambda" {
  filename         = var.lambda_zip_file
  function_name    = var.lambda_function_name
  role            = aws_iam_role.lambda_exec.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.14"
  source_code_hash = filebase64sha256(var.lambda_zip_file)
  environment {
    variables = {
      TAG_KEY = var.tag_key
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "var.lambda_execution_role_name"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "ec2_tagging_policy" {
  name = "ec2_tagging_policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:DescribeTags"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_fcnapp_ec2_tags" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.ec2_tagging_policy.arn
}

resource "aws_iam_policy_attachment" "lambda_logs" {
  name       = "lambda_logs_attachment"
  roles      = [aws_iam_role.lambda_exec.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_event_bus" "forticnapp_event_bus" {
  name = var.event_bus_name
}

resource "aws_cloudwatch_event_rule" "forticnapp_event_rule" {
  name        = var.event_rule_name
  event_bus_name = aws_cloudwatch_event_bus.forticnapp_event_bus.name
  event_pattern = <<EOF
{
  "account": ["434813966438"]
}
EOF
}

resource "aws_cloudwatch_event_target" "forticnapp_lambda_target" {
  rule      = aws_cloudwatch_event_rule.forticnapp_event_rule.name
  event_bus_name = aws_cloudwatch_event_bus.forticnapp_event_bus.name
  arn       = aws_lambda_function.forticnapp_lambda.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.forticnapp_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.forticnapp_event_rule.arn
}
