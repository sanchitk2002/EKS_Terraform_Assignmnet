# EKS
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.14.0"

  name    = var.cluster_name
  kubernetes_version = "1.33"

  vpc_id     = data.aws_vpc.existing.id
  subnet_ids = data.aws_subnets.private.ids

  eks_managed_node_groups = {
    bootstrap = {
      instance_types = ["t3.medium"]
      desired_size   = 1
      min_size       = 1
      max_size       = 2

      key_name = var.ssh_key_name # SSH key for node access

      additional_security_group_ids = [
        data.aws_security_group.eks_sg
      ]
    }
  }
}

# Karpenter

module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  cluster_name = module.eks.cluster_name
  
  
  create_pod_identity_association = true

  # Attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}


# Karpenter Helm

resource "helm_release" "karpenter" {
  namespace           = "karpenter"
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.0.0"
  wait                = false

  values = [
    <<-EOT
    serviceAccount:
      name: ${module.karpenter.service_account}
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    EOT
  ]
}

# Karpenter NodePool
resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
  apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: app-pool
spec:
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 60s

  limits:
    cpu: "16"
    memory: 32Gi

  template:
    metadata:
      labels:
        karpenter.sh/nodepool: app-pool   # 🔑 VERY IMPORTANT
    spec:
      nodeClassRef:
        name: default

      requirements:
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]

        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]

        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]

        - key: node.kubernetes.io/instance-type
          operator: In
          values:
            - t3.medium
            - t3.large

YAML
depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}


# Karpenter NodeClass
resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
  apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2

  role: KarpenterNodeRole-my-cluster

  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: my-cluster

  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: my-cluster

  tags:
    Environment: dev
    ManagedBy: karpenter
YAML
depends_on = [
    helm_release.karpenter
  ]
}

# Karpenter Deployment
resource "kubectl_manifest" "karpenter_example_deployment" {
  yaml_body = <<-YAML
  apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
    spec:
      nodeSelector:
        karpenter.sh/nodepool: app-pool   # 🔥 THIS binds app → Karpenter NodePool

      containers:
        - name: demo
          image: nginx
          ports:
            - containerPort: 80
YAML
  depends_on = [
    helm_release.karpenter
  ]
}