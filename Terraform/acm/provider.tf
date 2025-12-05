terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.87"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  # Use the same remote backend as the main stack but keep a dedicated state key
  backend "s3" {
    key     = "terraform/acm.tfstate"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
