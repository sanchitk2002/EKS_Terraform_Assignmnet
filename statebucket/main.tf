
# S3 Bucket for Terraform State
terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket"
    key            = "eks/dev/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}