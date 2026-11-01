data "archive_file" "lambda_function_file" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function_payload.zip"
}

resource "aws_lambda_function" "VisitorCounter" {
  function_name    = "VisitorCounter"
  filename         = data.archive_file.lambda_function_file.output_path
  source_code_hash = data.archive_file.lambda_function_file.output_base64sha256
  role             = aws_iam_role.visitorCounterRole.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 3
  memory_size      = 128
}