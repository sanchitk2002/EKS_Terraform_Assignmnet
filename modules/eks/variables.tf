variable "cluster_name" { 
  type = string 
}

variable "ssh_key_name" {
  description = "SSH key pair for node access"
  type        = string
}

variable "vpc_id" { 
  type = string 
}

variable "subnet_ids" { 
  type = list(string) 
}

variable "office_sg_id" { 
  type = string 
}

