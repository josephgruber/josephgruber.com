variable "default_tags" {
  default = {
    "ManagedBy" = "Terraform"
    "Project"   = "josephgruber.com"
  }
  description = "Key-value map of default tags to add to resources"
  type        = map(string)
}

variable "aws_region" {
  default     = "us-east-1"
  description = "AWS region"
  type        = string
}

variable "domain" {
  default     = "josephgruber.com"
  description = "Domain"
  type        = string
}

variable "domain_aliases" {
  default     = ["www.josephgruber.com"]
  description = "Website domain aliases"
  type        = list(string)
}

variable "mx_records" {
  default = [
    "10 in1-smtp.messagingengine.com",
    "20 in2-smtp.messagingengine.com"
  ]
  description = "MX DNS records"
  type        = list(string)
}

variable "txt_records" {
  default = [
    "google-site-verification=IgYNA6ZF1v4tKlzDKi5j8EmhLMoD_-CXw4WIlq18TR8",
    "keybase-site-verification=i3YjqbxTTC3g1AYgjtO2P14KfeSpbWAotr51sNHB-5k",
    "v=spf1 include:spf.messagingengine.com ?all"
  ]
  description = "Site verification records"
  type        = list(any)
}

variable "atproto_did" {
  description = "DID for atproto integration"
  type        = string
  default     = "did=did:plc:65pufxvjifiq2flklfmvylld"
}
