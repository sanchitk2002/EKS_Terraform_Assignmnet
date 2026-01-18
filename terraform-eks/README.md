
# Amazon EKS with Karpenter (Terraform)

This repository provisions an Amazon EKS cluster with Karpenter using Terraform.
The solution supports dev, pre-prod, and prod environments via directory-based separation.

## Environments
- dev/
- pre-prod/
- prod/

Each environment is deployed independently and has its own Terraform state.

## Usage
```bash
cd dev
terraform init
terraform apply
```
