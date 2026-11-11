provider "aws" {
  region = "us-west-2"

  default_tags {
    tags = {
      Environment  = "slice"
      Owner        = "it-infra"
      CostCenter   = "shared"
      Application  = "ehr"
      DataClass    = "internal"
      Compliance   = "none"
      BackupPolicy = "none"
      ManagedBy    = "terraform"
    }
  }
}
