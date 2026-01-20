# EKS
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.14.0"

  name    = var.cluster_name
  kubernetes_version = "1.34"

  vpc_id     = var.vpc_id   
  subnet_ids = var.subnet_ids
  enable_irsa = true

  tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  eks_managed_node_groups = {
    initial = {
      instance_types = ["t3.medium"]
      desired_size   = 1
      min_size       = 1
      max_size       = 2

    # SSH key for node access
      key_name = var.ssh_key_name 


    # Office security group
      vpc_security_group_ids = [var.office_sg_id]
    }
  }
}