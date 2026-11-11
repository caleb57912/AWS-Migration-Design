output "vpc_id" {
  value = module.network.vpc_id
}

output "data_subnet_ids" {
  value = module.network.data_subnet_ids
}

output "kms_key_arn" {
  value = module.security.kms_key_arn
}
