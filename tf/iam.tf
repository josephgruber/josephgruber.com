data "aws_iam_policy" "AmazonSESFullAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
}

resource "aws_iam_role" "lambda_ses_forwarder" {
  name               = "LamdaSESForward"
  assume_role_policy = file("templates/iam-ses-trust.tftpl")

  inline_policy {
    name   = "ses-forwarder"
    policy = templatefile("templates/iam-ses-forwarder-policy.tftpl", { bucket = "${var.domain}-email" })
  }
}

resource "aws_iam_role_policy_attachment" "lambda_ses_forwarder_ses_full_access" {
  role       = aws_iam_role.lambda_ses_forwarder.name
  policy_arn = data.aws_iam_policy.AmazonSESFullAccess.arn
}
