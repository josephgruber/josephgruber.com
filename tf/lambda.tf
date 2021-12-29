data "archive_file" "lambda_zip_file" {
  type        = "zip"
  output_path = "/tmp/lambda.zip"

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
