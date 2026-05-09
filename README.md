# josephgruber.com

Personal website at [josephgruber.com](https://josephgruber.com).

## Stack

Raw HTML/CSS/JS — no framework, no build step.

## Deploy

GitHub Actions deploys automatically on push to `main`:

1. Syncs all files to S3 (excluding `.git/` and `.github/`)
2. Invalidates the CloudFront distribution

AWS credentials are obtained via OIDC using the role from `infra-aws-base`.
The S3 bucket and CloudFront distribution ID are fetched at deploy time from
SSM parameters managed by `infra-website`.
