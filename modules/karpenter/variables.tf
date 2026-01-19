variable "cluster_name" { type = string } 

variable "oidc_provider_arn" { type = string }

variable "tags" { type = map(string) }

variable "cluster_endpoint" { type = string }