resource "aws_s3_bucket" "main" { # trivy:ignore:AVD-AWS-0320 # trivy:ignore:AVD-AWS-0090
  bucket = var.domain
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" { # trivy:ignore:AVD-AWS-0132
  bucket = aws_s3_bucket.main.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "cloudfront_policy" {
  bucket = aws_s3_bucket.main.id
  policy = templatefile("templates/s3-cf-oac-policy.tftpl", {
    bucket_name  = aws_s3_bucket.main.id,
    account      = data.aws_caller_identity.account.account_id,
    distribution = aws_cloudfront_distribution.distribution.id
  })
}

resource "aws_route53_zone" "zone" {
  name          = var.domain
  comment       = ""
  force_destroy = false
}

resource "aws_route53_record" "nameservers" {
  zone_id         = aws_route53_zone.zone.zone_id
  name            = var.domain
  type            = "NS"
  ttl             = 172800
  allow_overwrite = true

  records = [
    "${aws_route53_zone.zone.name_servers[0]}.",
    "${aws_route53_zone.zone.name_servers[1]}.",
    "${aws_route53_zone.zone.name_servers[2]}.",
    "${aws_route53_zone.zone.name_servers[3]}."
  ]
}

resource "aws_route53_record" "soa" {
  zone_id         = aws_route53_zone.zone.zone_id
  name            = var.domain
  type            = "SOA"
  ttl             = 900
  allow_overwrite = true

  records = ["${aws_route53_zone.zone.name_servers[3]}. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 86400"]
}

resource "aws_kms_key" "ksk" {
  bypass_policy_lockout_safety_check = false
  customer_master_key_spec           = "ECC_NIST_P256"
  key_usage                          = "SIGN_VERIFY"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Id" : "dnssec-policy",
    "Statement" : [
      {
        Sid : "Enable IAM User Permissions",
        Effect : "Allow",
        Principal : {
          AWS = "arn:aws:iam::${data.aws_caller_identity.account.account_id}:root"
        },
        Action : "kms:*",
        Resource : "*"
      },
      {
        Sid : "Allow Route 53 DNSSEC Service",
        Effect : "Allow",
        Principal : {
          Service : "dnssec-route53.amazonaws.com"
        },
        Action : [
          "kms:DescribeKey",
          "kms:GetPublicKey",
          "kms:Sign"
        ],
        Resource : "*",
        Condition : {
          StringEquals : {
            "aws:SourceAccount" : data.aws_caller_identity.account.account_id
          },
          ArnLike : {
            "aws:SourceArn" : "arn:aws:route53:::hostedzone/*"
          }
        }
      },
      {
        Sid : "Allow Route 53 DNSSEC to CreateGrant",
        Effect : "Allow",
        Principal : {
          Service : "dnssec-route53.amazonaws.com"
        },
        Action : "kms:CreateGrant",
        Resource : "*",
        Condition : {
          Bool : {
            "kms:GrantIsForAWSResource" : "true"
          }
        }
      }
    ]
  })
}

resource "aws_route53_key_signing_key" "ksk" {
  hosted_zone_id             = aws_route53_zone.zone.zone_id
  key_management_service_arn = aws_kms_key.ksk.arn
  name                       = "domain_ksk"
}

resource "aws_route53_hosted_zone_dnssec" "dnssec" {
  depends_on = [
    aws_route53_key_signing_key.ksk
  ]
  hosted_zone_id = aws_route53_zone.zone.zone_id
}

resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.zone.zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.distribution.domain_name
    zone_id                = aws_cloudfront_distribution.distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "mx" {
  zone_id = aws_route53_zone.zone.zone_id
  name    = var.domain
  type    = "MX"
  ttl     = "3600"
  records = var.mx_records
}

resource "aws_route53_record" "dkim" {
  for_each = toset(["fm1", "fm2", "fm3"])

  zone_id = aws_route53_zone.zone.zone_id
  name    = "${each.value}._domainkey.${var.domain}"
  records = ["${each.value}.${var.domain}.dkim.fmhosted.com"]
  type    = "CNAME"
  ttl     = "3600"
}

resource "aws_route53_record" "dmarc" {
  zone_id = aws_route53_zone.zone.zone_id
  name    = "_dmarc.${var.domain}"
  type    = "TXT"
  ttl     = "3600"
  records = ["v=DMARC1; p=quarantine; pct=100; rua=mailto:re+x4hdrmbajgx@dmarc.postmarkapp.com; sp=none; aspf=r;"]
}

resource "aws_route53_record" "txt" {
  zone_id = aws_route53_zone.zone.zone_id
  name    = var.domain
  type    = "TXT"
  ttl     = "3600"
  records = var.txt_records
}

resource "aws_route53_record" "bluesky" {
  zone_id = aws_route53_zone.zone.zone_id
  name    = "_atproto.${var.domain}"
  type    = "TXT"
  ttl     = "3600"
  records = ["did=did:plc:65pufxvjifiq2flklfmvylld"]
}

resource "aws_route53_record" "photos" {
  zone_id = aws_route53_zone.zone.zone_id
  name    = "photos.${var.domain}"
  type    = "CNAME"
  ttl     = "300"
  records = ["bluemarble.photography"]
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.zone.zone_id
  name    = "www.${var.domain}"
  type    = "CNAME"
  ttl     = "300"
  records = [var.domain]
}

locals {
  s3_origin_id = "s3JosephGruber"
}

data "aws_cloudfront_cache_policy" "cache_policy" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_distribution" "distribution" { # trivy:ignore:AVD-AWS-0011 # trivy:ignore:AVD-AWS-0010
  aliases             = concat([var.domain], var.domain_aliases)
  default_root_object = "index.html"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.main.bucket_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
    origin_id                = local.s3_origin_id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.cache_policy.id
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.default_root_object.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.certificate.arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }
}

resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = aws_s3_bucket.main.bucket_domain_name
  description                       = "-"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_function" "default_root_object" {
  name    = "default-root-object"
  runtime = "cloudfront-js-1.0"
  publish = true
  code    = file("cloudfront_functions/default-root-object.js")
}

resource "aws_acm_certificate" "certificate" {
  domain_name               = var.domain
  validation_method         = "DNS"
  subject_alternative_names = var.domain_aliases

  options {
    certificate_transparency_logging_preference = "ENABLED"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "validation" {
  certificate_arn         = aws_acm_certificate.certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_cert_validation : record.fqdn]
}

resource "aws_route53_record" "acm_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.certificate.domain_validation_options : dvo.domain_name => {
      name    = dvo.resource_record_name
      record  = dvo.resource_record_value
      type    = dvo.resource_record_type
      zone_id = aws_route53_zone.zone.zone_id
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = each.value.zone_id
}

resource "aws_ses_domain_identity" "domain" {
  domain = var.domain
}

resource "aws_ses_domain_identity_verification" "identity_verification" {
  domain = aws_ses_domain_identity.domain.id
}

resource "aws_ses_domain_dkim" "dkim" {
  domain = aws_ses_domain_identity.domain.domain
}

resource "aws_ses_receipt_rule_set" "default_rule_set" {
  rule_set_name = "default-rule-set"
}

resource "aws_ses_active_receipt_rule_set" "default_rule_set" {
  rule_set_name = aws_ses_receipt_rule_set.default_rule_set.rule_set_name
}

resource "aws_ses_email_identity" "gmail" {
  email = "joseph.gruber@gmail.com"
}
