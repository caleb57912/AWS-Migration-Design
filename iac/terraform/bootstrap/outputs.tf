output "state_bucket" {
  description = "Bucket name for the backend block in each environment"
  value       = aws_s3_bucket.state.bucket
}