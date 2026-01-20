provider "aws" {
  region = "ap-south-1"
}

terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "6.28.0"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "helm" {
  kubernetes  {
    host = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}


module "eks" {
  source = "../../modules/eks"

  cluster_name  = var.cluster_name
  vpc_id       = data.aws_vpc.existing.id
  subnet_ids   = data.aws_subnets.private.ids
  office_sg_id = data.aws_security_group.existing.id
  ssh_key_name  = var.ssh_key_name
}

module "karpenter" {
  source = "../../modules/karpenter"

  cluster_name       = module.eks.cluster_name
  cluster_endpoint   = module.eks.cluster_endpoint
  oidc_provider_arn  = module.eks.oidc_provider_arn
  tags               = var.tags
}

resource "aws_ec2_tag" "karpenter_discovery_tag" {
  resource_id = module.eks.cluster_primary_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

# AWS-AUTH

resource "kubernetes_config_map_v1_data" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
  data = {
    mapRoles = yamlencode([
      {
        rolearn  = module.eks.eks_managed_node_groups["initial"].iam_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      },
      {
        rolearn  = module.karpenter.role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      }
    ])
  }
  force = true
  depends_on = [ module.eks, module.karpenter ]
}

# KARPENTER CONFIG

resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1beta1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2
      role: "${module.karpenter.role_name}"
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: "${module.eks.cluster_name}"
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: "${module.eks.cluster_name}"
  YAML
  depends_on = [ module.karpenter, module.eks ]
}

resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        spec:
          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: kubernetes.io/os
              operator: In
              values: ["linux"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["on-demand"]
          nodeClassRef:
            name: default
      limits:
        cpu: 1000
      disruption:
        consolidationPolicy: WhenUnderutilized
        expireAfter: 720h
  YAML
  depends_on = [ kubectl_manifest.karpenter_node_class ]
}

