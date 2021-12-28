terraform {
  backend "http" {
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.70"
    }
  }

  required_version = ">= 1.1.0"
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region

  default_tags {
    tags = var.tags
  }
}

data "aws_caller_identity" "account" {}
