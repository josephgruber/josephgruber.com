resource "aws_s3_bucket" "main" {
  bucket        = var.domain
  acl           = "public-read"
  policy        = templatefile("templates/s3-policy.json", { bucket = "${var.domain}" })
  force_destroy = false

  website {
    index_document = "index.html"
    error_document = "index.html"
  }
}

resource "aws_s3_bucket" "www" {
  bucket        = "www.${var.domain}"
  acl           = "private"
  force_destroy = false

  website {
    redirect_all_requests_to = "https://${var.domain}"
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
    abort_incomplete_multipart_upload_days = 0
    enabled                                = true
    id                                     = "/incoming"

    expiration {
      days                         = 7
      expired_object_delete_marker = false
    }
  }
}
