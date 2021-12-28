data "aws_iam_policy" "AmazonSESFullAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
}

resource "aws_iam_role" "lambda_ses_forwarder" {
  name               = "LamdaSESForward"
  assume_role_policy = file("templates/iam-ses-trust.json")

  inline_policy {
    name   = "oneClick_lambda_basic_execution_1529955340135"
    policy = templatefile("templates/iam-ses-forwarder-policy.json", { bucket = "${var.domain}-email" })
  }
}

resource "aws_iam_role_policy_attachment" "lambda_ses_forwarder_ses_full_access" {
  role       = aws_iam_role.lambda_ses_forwarder.name
  policy_arn = data.aws_iam_policy.AmazonSESFullAccess.arn
}
