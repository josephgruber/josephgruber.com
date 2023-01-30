data "archive_file" "lambda_zip_file" {
  type        = "zip"
  output_path = "${path.module}/lambda-${var.domain}.zip"

  source {
    content  = file("lambda/index.js")
    filename = "index.js"
  }
}

resource "aws_lambda_function" "ses_forwarder" {
  function_name = "SesForwarder"
  role          = aws_iam_role.lambda_ses_forwarder.arn
  handler       = "index.handler"

  filename         = data.archive_file.lambda_zip_file.output_path
  source_code_hash = data.archive_file.lambda_zip_file.output_base64sha256

  runtime = "nodejs12.x"
  timeout = "10"
}

resource "aws_lambda_permission" "allow_ses" {
  statement_id   = "AllowExecutionFromSes"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.ses_forwarder.function_name
  principal      = "ses.amazonaws.com"
  source_arn     = aws_ses_receipt_rule_set.default_rule_set.arn
  source_account = data.aws_caller_identity.account.account_id
}
