# Environment Variables

variable "region" {
  type = string
}
variable "aws_account_ids" {
  type = string
}

# Cluster
variable "cluster_name" {
  type = string
}

# SSH Key
variable "ssh_key_name" {
  type = string
}