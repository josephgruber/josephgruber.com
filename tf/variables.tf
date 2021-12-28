variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile"
  type        = string
  default     = "personal"
}

variable "tags" {
  type = map(string)
  default = {
    Project = "josephgruber.com"
  }
}

variable "domain" {
  description = "Domain"
  type        = string
  default     = "josephgruber.com"
}

variable "domain_aliases" {
  description = "Website domain aliases"
  type        = list(any)
  default     = ["www.josephgruber.com"]
}

variable "mx_records" {
  description = "MX DNS records"
  type        = string
  default     = "10 inbound-smtp.us-east-1.amazonaws.com"
}

variable "site_verification" {
  description = "Site verification records"
  type        = list(any)
  default = [
    "google-site-verification=IgYNA6ZF1v4tKlzDKi5j8EmhLMoD_-CXw4WIlq18TR8",
    "keybase-site-verification=i3YjqbxTTC3g1AYgjtO2P14KfeSpbWAotr51sNHB-5k"
  ]
}
