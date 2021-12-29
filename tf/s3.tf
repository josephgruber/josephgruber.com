resource "aws_s3_bucket" "main" {
  bucket = var.domain
  acl    = "private"
  policy = templatefile("templates/s3-cf-oai-policy.json", {
    oai_arn = "${aws_cloudfront_origin_access_identity.oai.iam_arn}"
    bucket  = "${var.domain}"
    }
  )
  force_destroy = false

  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}

resource "aws_s3_bucket" "email" {
  bucket = "${var.domain}-email"
  acl    = "private"
  policy = templatefile("templates/s3-ses-policy.json", {
    bucket     = "${var.domain}-email",
    account_id = data.aws_caller_identity.account.account_id
    }
  )
  force_destroy = false

  lifecycle_rule {
    id                                     = "Delete Old Emails"
    enabled                                = true
    abort_incomplete_multipart_upload_days = 0
    prefix                                 = "incoming/"

    expiration {
      days                         = 7
      expired_object_delete_marker = false
    }
  }
}

resource "aws_s3_bucket_public_access_block" "email" {
  bucket = aws_s3_bucket.email.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
