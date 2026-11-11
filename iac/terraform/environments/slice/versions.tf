terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # State lives in the bootstrap bucket; use_lockfile stops two applies at once
  backend "s3" {
    bucket       = "bayou-tfstate-3f2ffbfd"
    key          = "slice/terraform.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
