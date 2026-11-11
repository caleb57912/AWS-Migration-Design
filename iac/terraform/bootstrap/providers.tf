provider "aws" {
  region = "us-west-2"

  # Applied to every resource; matches the 8-tag standard
  default_tags {
    tags = {
      Environment  = "shared"
      Owner        = "it-infra"
      CostCenter   = "shared"
      Application  = "terraform-state"
      DataClass    = "confidential"
      Compliance   = "none"
      BackupPolicy = "none"
      ManagedBy    = "terraform"
    }
  }
}