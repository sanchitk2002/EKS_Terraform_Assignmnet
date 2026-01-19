output "role_name" {
  description = "IAM role created for Karpenter nodes"
  value       = module.karpenter.role_name
}

output "karpenter_arn" {
  value = module.karpenter.irsa_arn
}

output "role_arn" {
  description = "IAM Role ARN for Karpenter Node Group"
  value       = module.karpenter.role_arn
}