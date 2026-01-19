module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "19.21.0"
  
  cluster_name = var.cluster_name

  # To enable the IAM Roles for Service Accounts (IRSA)
  irsa_oidc_provider_arn          = var.oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]


  create_instance_profile = true

  tags = var.tags
}

# Installing Karpenter using Helm

resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "v0.32.1"

  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = var.cluster_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.irsa_arn
  }

  set {
    name  = "settings.defaultInstanceProfile"
    value = module.karpenter.instance_profile_name
  }

  set {
    name  = "settings.interruptionQueueName"
    value = module.karpenter.queue_name
  }
}

# Full permission for Karpenter role

resource "aws_iam_role_policy" "karpenter_extra_access" {
  name = "KarpenterAssignmentExtraAccess"
  role = module.karpenter.irsa_name 

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateTags",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeImages",
          "ec2:DescribeSpotPriceHistory",
          "ec2:TerminateInstances",
          "ec2:DeleteLaunchTemplate",
          "ssm:GetParameter",
          "pricing:GetProducts",
          "iam:PassRole",
          "iam:GetInstanceProfile",
          "iam:CreateInstanceProfile",
          "iam:TagInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}