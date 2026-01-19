output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "cluster_certificate_authority_data" { value = module.eks.cluster_certificate_authority_data }
output "oidc_provider_arn" { value = module.eks.oidc_provider_arn }
output "cluster_id" { value = module.eks.cluster_id }
output "cluster_primary_security_group_id" { 
  value = module.eks.cluster_primary_security_group_id 
}

output "eks_managed_node_groups" {
  description = "Mapping of Managed node groups"
  value       = module.eks.eks_managed_node_groups
}