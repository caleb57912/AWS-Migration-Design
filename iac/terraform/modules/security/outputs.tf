output "kms_key_arn" {
  value = aws_kms_key.this.arn
}

output "log_bucket" {
  value = aws_s3_bucket.logs.id
}
