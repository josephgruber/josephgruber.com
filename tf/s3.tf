resource "aws_s3_bucket" "main" { #tfsec:ignore:aws-s3-enable-bucket-logging tfsec:ignore:aws-s3-enable-versioning tfsec:ignore:aws-s3-encryption-customer-key tfsec:ignore:aws-s3-enable-bucket-encryption
  bucket = var.domain
}

resource "aws_s3_bucket" "email" { #tfsec:ignore:aws-s3-enable-bucket-logging tfsec:ignore:aws-s3-enable-versioning tfsec:ignore:aws-s3-encryption-customer-key tfsec:ignore:aws-s3-enable-bucket-encryption
  bucket = "${var.domain}-email"
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "email" {
  bucket = aws_s3_bucket.email.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudfront_policy" {
  bucket = aws_s3_bucket.main.id
  policy = templatefile("s3-cf-oac-policy.tftpl", {
    bucket_name  = aws_s3_bucket.main.id,
    account      = data.aws_caller_identity.account.account_id,
    distribution = aws_cloudfront_distribution.distribution.id
  })
}

resource "aws_s3_bucket_policy" "ses_policy" {
  bucket = aws_s3_bucket.email.id
  policy = templatefile("templates/s3-ses-policy.tftpl", {
    bucket     = aws_s3_bucket.email.bucket
    account_id = data.aws_caller_identity.account.account_id
    }
  )
}

resource "aws_s3_bucket_lifecycle_configuration" "email_lifecycle" {
  bucket = aws_s3_bucket.email.id

  rule {
    id                                     = "Delete Old Emails"
    status                                 = "Enabled"
    abort_incomplete_multipart_upload_days = 0
    prefix                                 = "incoming/"

    expiration {
      days                         = 7
      expired_object_delete_marker = false
    }
  }
}
