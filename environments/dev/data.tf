# Existing VPC
data "aws_vpc" "existing" {
  tags = {
    Name = "EKS-vpc"
    Environment = "dev"
  }  
}

# Existing Private Subnets
data "aws_subnets" "private" {
  filter {
    name   = "tag:Name"
    values = ["EKS-private*"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
}

# Existing Security Group
data "aws_security_group" "eks_sg" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  filter {
    name   = "group-name"
    values = ["OfficeIPs"]
  }
}