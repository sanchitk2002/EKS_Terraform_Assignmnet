variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "EKS-dev"
}

variable "ssh_key_name" {
  description = "SSH key pair name for EKS nodes"
  type        = string
  default     = "EKS"
}

variable "env_name" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Terraform   = "true"
    ManagedBy   = "Terraform"
    Project     = "EKS-Assignment"
  }
}