# EKS Cluster with Karpenter - Terraform Infrastructure

This repository contains Terraform code to provision an Amazon EKS cluster with Karpenter for dynamic node group management across multiple environments (dev, pre-prod, prod).

## Architecture Overview

- **EKS Cluster**: Deployed in private subnets only with private endpoint access
- **Karpenter**: Automated node provisioning and scaling based on workload requirements
- **Networking**: Uses existing VPC and private subnets identified via tags
- **Security**: OfficeIPs security group attached to worker nodes
- **Multi-Environment**: Directory-based separation for dev, pre-prod, and prod

## Prerequisites

Before you begin, ensure you have the following:

1. **AWS CLI** installed and configured with appropriate credentials
2. **Terraform** >= 1.5.0 installed
3. **kubectl** installed for Kubernetes cluster management
4. **AWS Permissions**: IAM user/role with permissions to create:
   - EKS clusters
   - IAM roles and policies
   - EC2 resources (VPC, subnets, security groups)
   - ECR access (for Karpenter Helm chart)

5. **Existing AWS Resources** (identified by tags):
   - VPC with tag `Name = "EKS-vpc"`
   - Private subnets with tags `Name = "EKS-private1"` and `Name = "EKS-private2"`
   - Security group named `OfficeIPs`
   - SSH key pair named `EKS` (for future SSH access to nodes)

## Project Structure

```
EKS_Terraform/
├── envs/
│   ├── dev/
│   │   ├── main.tf              # EKS and Karpenter module instantiation
│   │   ├── data.tf              # Data sources for VPC, subnets, security groups
│   │   └── kubernetes_provider.tf  # Kubernetes provider configuration
│   ├── pre-prod/
│   │   ├── main.tf
│   │   ├── data.tf
│   │   └── kubernetes_provider.tf
│   └── prod/
│       ├── main.tf
│       ├── data.tf
│       └── kubernetes_provider.tf
├── modules/
│   ├── eks/
│   │   ├── main.tf              # EKS cluster resource
│   │   ├── iam.tf               # EKS cluster IAM role and OIDC provider
│   │   ├── subnet_tags.tf       # Subnet tagging for Karpenter discovery
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── karpenter/
│       ├── main.tf              # Karpenter Helm chart
│       ├── iam.tf               # Karpenter controller IAM role
│       ├── node_iam.tf          # Worker node IAM role and instance profile
│       ├── nodepool.tf          # Karpenter NodePool and EC2NodeClass
│       └── variables.tf
├── providers.tf                 # AWS provider configuration
├── versions.tf                  # Terraform and provider version constraints
└── README.md                    # This file
```

## Quick Start

### 1. Configure AWS Provider

Update the AWS region in `providers.tf` if needed:

```hcl
provider "aws" {
  region = "ap-south-1"  # Change to your desired region
}
```

### 2. Verify Prerequisites

Ensure your AWS environment has:
- VPC tagged with `Name = "EKS-vpc"`
- Private subnets tagged with `Name = "EKS-private1"` and `Name = "EKS-private2"`
- Security group named `OfficeIPs`
- SSH key pair named `EKS`

### 3. Deploy to Dev Environment

```bash
# Navigate to dev environment
cd envs/dev

# Initialize Terraform
terraform init

# Review the execution plan
terraform plan

# Apply the configuration
terraform apply
```

The deployment process will:
1. Create the EKS cluster with necessary IAM roles
2. Configure OIDC provider for IRSA (IAM Roles for Service Accounts)
3. Install Karpenter via Helm chart
4. Create Karpenter NodePool and EC2NodeClass
5. Tag subnets for Karpenter discovery

**Note**: The Kubernetes provider requires the cluster to be created first. If you encounter dependency issues, you may need to run `terraform apply` twice (once to create the cluster, then again to configure Karpenter).

### 4. Verify Cluster Access

After deployment, configure kubectl:

```bash
# Update kubeconfig
aws eks update-kubeconfig --name eks-dev --region ap-south-1

# Verify cluster access
kubectl get nodes
kubectl get pods -n karpenter
```

### 5. Deploy to Other Environments

Repeat the process for pre-prod and prod:

```bash
cd ../pre-prod
terraform init
terraform plan
terraform apply

# Or for prod
cd ../prod
terraform init
terraform plan
terraform apply
```

## Configuration Details

### EKS Cluster Configuration

- **Version**: 1.29
- **Endpoint Access**: Private only (no public access)
- **Subnets**: Private subnets only
- **Node Management**: Karpenter (no managed node groups)

### Karpenter Configuration

- **Chart Version**: 0.36.0
- **Node Pool**: Default pool with spot and on-demand instances
- **Instance Types**: t3.medium, t3.large, t3.xlarge, m5.large, m5.xlarge
- **Node Capacity Limits**: 1000 CPU cores
- **Consolidation**: Enabled when nodes are empty (after 30s)

### Security Configuration

- **Security Group**: OfficeIPs attached to all worker nodes
- **SSH Key**: EKS key pair configured for future access
- **Instance Profile**: karpenter-node-{environment} with EKS worker policies

### Networking

- **VPC**: Existing VPC identified by tag `Name = "EKS-vpc"`
- **Subnets**: Private subnets identified by tags `Name = "EKS-private1"` and `Name = "EKS-private2"`
- **Subnet Tags**: Automatically tagged with `karpenter.sh/discovery` for Karpenter discovery

## Module Variables

### EKS Module

- `cluster_name`: Name of the EKS cluster
- `environment`: Environment name (dev/pre-prod/prod)
- `eks_version`: Kubernetes version (default: "1.29")
- `private_subnet_ids`: List of private subnet IDs

### Karpenter Module

- `cluster_name`: EKS cluster name
- `environment`: Environment name
- `ssh_key_name`: SSH key pair name (default: "EKS")
- `security_group_id`: Security group ID for worker nodes
- `subnet_ids`: List of subnet IDs
- `vpc_id`: VPC ID
- Additional OIDC and cluster connection parameters

## Customization

### Changing Instance Types

Edit `modules/karpenter/nodepool.tf` and modify the `requirements` section:

```hcl
{
  key      = "node.kubernetes.io/instance-type"
  operator = "In"
  values   = ["t3.medium", "t3.large", "m5.large"]  # Your instance types
}
```

### Adjusting Node Capacity Limits

Edit `modules/karpenter/nodepool.tf`:

```hcl
limits = {
  cpu = "2000"  # Maximum CPU cores
}
```

### Modifying Subnet Selection

Update the subnet tags in `envs/{environment}/data.tf`:

```hcl
filter {
  name   = "tag:Name"
  values = ["Your-Private-Subnet-1", "Your-Private-Subnet-2"]
}
```

## Troubleshooting

### Kubernetes Provider Authentication Issues

If you encounter authentication errors after cluster creation:

```bash
# Update kubeconfig
aws eks update-kubeconfig --name <cluster-name> --region <region>

# Verify access
kubectl get nodes
```

### Karpenter Not Creating Nodes

1. Check Karpenter logs:
   ```bash
   kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter
   ```

2. Verify IAM permissions for Karpenter controller role
3. Check subnet tags: `kubectl get ec2nodeclass -o yaml`
4. Verify security group and subnet selectors

### Terraform Dependency Errors

If Karpenter resources fail due to cluster not ready:

1. First apply creates the cluster
2. Wait for cluster to be active
3. Run `terraform apply` again to create Karpenter resources

## Cleanup

To destroy the infrastructure:

```bash
cd envs/dev  # or pre-prod/prod
terraform destroy
```

**Warning**: This will delete the EKS cluster and all associated resources. Ensure you have backups of any important data.

## Best Practices

1. **Environment Separation**: Each environment (dev/pre-prod/prod) is in its own directory for clear separation
2. **Modular Design**: Reusable modules for EKS and Karpenter
3. **Security**: Private subnets only, private endpoint access
4. **Tagging**: Consistent resource tagging for identification and cost tracking
5. **IAM**: IRSA (IAM Roles for Service Accounts) for secure access
6. **Cost Optimization**: Karpenter with spot instances for cost efficiency

