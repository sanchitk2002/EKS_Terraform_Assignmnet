# EKS Cluster with Karpenter – Terraform Infrastructure

## Architecture Overview

The following diagram illustrates how **Karpenter dynamically provisions and optimizes compute capacity** in response to Kubernetes workload demands.

![Karpenter Architecture](terraform-eks/diagram/karpenter-architecture.png)

### Flow Explanation

* **Pending Pods**

  * New workloads are submitted to the Kubernetes scheduler.
* **Existing Capacity Check**

  * Scheduler attempts to place pods on existing nodes.
* **Unschedulable Pods**

  * If no suitable capacity is available, pods remain pending.
* **Karpenter Intervention**

  * Karpenter detects unschedulable pods and provisions **just-in-time EC2 capacity**.
* **Optimized Capacity**

  * Nodes are right-sized for workloads.
  * Underutilized nodes are consolidated or terminated to reduce cost.

This approach ensures:
* Fast workload scaling
* Efficient resource utilization
* Reduced infrastructure costs using on-demand and spot instances




---
This repository contains Terraform code to provision an **Amazon EKS cluster with Karpenter** for dynamic node provisioning.
The infrastructure supports **multiple environments (dev, pre-prod, prod)** using **directory-based separation**, following Terraform and AWS best practices.

## Architecture

* **EKS Cluster**

  * Deployed in **private subnets only**
  * Kubernetes API endpoint access restricted to **private access**
* **Karpenter**

  * Manages worker nodes dynamically based on workload demand
  * Supports both **on-demand and spot instances**
* **Networking**

  * Uses an **existing VPC and private subnets**
  * Resources are discovered dynamically using **Terraform data sources and tags**
* **Security**

  * Existing security group **OfficeIPs** attached to worker nodes
  * Existing SSH key pair **EKS** configured for future access
* **Multi-Environment Support**

  * Separate directories for `dev`, `pre-prod`, and `prod`
  * Independent Terraform state per environment

---

## Prerequisites

Before you begin, ensure you have the following installed and configured:

### Tools

* **AWS CLI** (configured with appropriate credentials)
* **Terraform >= 1.5.0**
* **kubectl**

### AWS Permissions

The IAM user or role must have permissions to create and manage:

* EKS clusters
* IAM roles and policies
* EC2 resources (VPC, subnets, security groups)
* ECR access (for pulling Karpenter images)

### Existing AWS Resources (Required)

The following resources **must already exist** in your AWS account:

* **VPC**

  * Tag: `Name = "EKS-vpc"`
* **Private Subnets**

  * Tags:

    * `Name = "EKS-private1"`
    * `Name = "EKS-private2"`
* **Security Group**

  * Name: `OfficeIPs`
* **SSH Key Pair**

  * Name: `EKS`

---

## Repository Structure

```text
.
├── environment
│   ├── dev
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   ├── pre-prod
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   └── prod
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars
│
├── module
│   ├── eks
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── karpenter
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── statebucket
│   └── main.tf
│
└── README.md
```

Each environment is **fully self-contained** and can be deployed independently.

---

## Quick Start

### 1. Deploy Dev Environment

```bash
cd dev
terraform init
terraform plan
terraform apply
```

Terraform will:

* Create the EKS cluster
* Configure IAM roles and OIDC provider
* Install Karpenter via Helm
* Create Karpenter NodePool and EC2NodeClass
* Attach the `OfficeIPs` security group to worker nodes

> ⚠️ **Note**
> If Karpenter resources fail on the first run due to cluster readiness, wait until the cluster becomes `ACTIVE` and run:
>
> ```bash
> terraform apply
> ```

---

### 2. Configure kubectl Access

```bash
aws eks update-kubeconfig \
  --name eks-cluster-dev \
  --region ap-south-1
```

Verify:

```bash
kubectl get nodes
kubectl get pods -n karpenter
```

---

### 3. Deploy Other Environments

Repeat the same steps for `pre-prod` and `prod`:

```bash
cd ../pre-prod
terraform init
terraform apply
```

```bash
cd ../prod
terraform init
terraform apply
```

---

## Configuration Details

### EKS Cluster

* **Kubernetes Version**: 1.29
* **Endpoint Access**: Private only
* **Subnets**: Private subnets only
* **Node Management**: Karpenter (no managed node groups)

### Karpenter

* **Provisioning Type**: On-demand + Spot
* **Instance Types**:

  * `t3.medium`
  * `t3.large`
  * `t3.xlarge`
  * `m5.large`
  * `m5.xlarge`
* **Consolidation**: Enabled (empty nodes consolidated after 30s)
* **Capacity Limit**: 1000 vCPU

---

## Customization

### Change Instance Types

Edit `main.tf` and update the Karpenter NodePool requirements:

```hcl
values = ["t3.medium", "t3.large", "m5.large"]
```

### Modify Subnet Selection

Update filters in `data.tf`:

```hcl
values = ["Your-Private-Subnet-1", "Your-Private-Subnet-2"]
```

---

## Troubleshooting

### Kubernetes Authentication Issues

```bash
aws eks update-kubeconfig --name <cluster-name> --region <region>
kubectl get nodes
```

### Karpenter Not Creating Nodes

```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter
```

Verify:

* IAM permissions
* Subnet tags
* Security group association

### Terraform Dependency Errors

If Karpenter fails initially:

1. First `terraform apply` creates the cluster
2. Wait for cluster to become ACTIVE
3. Run `terraform apply` again

---

## Cleanup

To destroy resources:

```bash
cd dev   # or pre-prod / prod
terraform destroy
```

⚠️ **Warning**: This will permanently delete the EKS cluster and all related resources.

---

## Best Practices Followed

* Clear environment separation
* Infrastructure as Code using Terraform
* Private networking only
* Existing infrastructure reused via data sources
* IRSA for secure AWS access
* Cost optimization using Karpenter and spot instances

---

## Author

**Sanchit Kumar**
Terraform | AWS | EKS | Karpenter
