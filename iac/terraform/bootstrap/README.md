# Bootstrap

Creates the S3 bucket for remote Terraform state. It runs with local state once, because the remote state bucket can't store the state of its own creation.
