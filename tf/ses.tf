resource "aws_ses_domain_identity" "domain" {
  domain = var.domain
}

resource "aws_route53_record" "ses_verification" {
  zone_id = aws_route53_zone.zone.zone_id
  name    = "_amazonses.${aws_ses_domain_identity.domain.id}"
  type    = "TXT"
  ttl     = "300"
  records = [aws_ses_domain_identity.domain.verification_token]
}

resource "aws_ses_domain_identity_verification" "identity_verification" {
  domain = aws_ses_domain_identity.domain.id

  depends_on = [aws_route53_record.ses_verification]
}

resource "aws_ses_domain_dkim" "dkim" {
  domain = aws_ses_domain_identity.domain.domain
}

resource "aws_route53_record" "ses_dkim" {
  count           = 3
  zone_id         = aws_route53_zone.zone.zone_id
  name            = "${element(aws_ses_domain_dkim.dkim.dkim_tokens, count.index)}._domainkey"
  type            = "CNAME"
  ttl             = "600"
  allow_overwrite = true

  records = ["${element(aws_ses_domain_dkim.dkim.dkim_tokens, count.index)}.dkim.amazonses.com"]
}

resource "aws_ses_receipt_rule_set" "default_rule_set" {
  rule_set_name = "default-rule-set"
}

resource "aws_ses_active_receipt_rule_set" "default_rule_set" {
  rule_set_name = aws_ses_receipt_rule_set.default_rule_set.rule_set_name
}

resource "aws_ses_receipt_rule" "catch_all" {
  name          = "${var.domain}CatchAllEmailForwarding"
  rule_set_name = aws_ses_receipt_rule_set.default_rule_set.id
  enabled       = true

  recipients   = [".${var.domain}", var.domain]
  scan_enabled = true

  s3_action {
    bucket_name       = aws_s3_bucket.email.bucket
    position          = 1
    object_key_prefix = "incoming"
  }

  lambda_action {
    function_arn    = aws_lambda_function.ses_forwarder.arn
    invocation_type = "Event"
    position        = 2
  }
}

resource "aws_ses_email_identity" "gmail" {
  email = "joseph.gruber@gmail.com"
}
