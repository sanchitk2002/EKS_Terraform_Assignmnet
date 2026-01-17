# Lookup VPC by tag
# If lookup fails, uncomment and use VPC ID directly:
# data "aws_vpc" "eks_vpc" {
#   id = "vpc-07687dd69c4d561df"
# }
data "aws_vpc" "eks_vpc" {
  tags = {
    Name = "EKS-vpc"
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.eks_vpc.id]
  }

  filter {
    name   = "tag:kubernetes.io/role/internal-elb"
    values = ["1"]
  }
}


data "aws_security_group" "office_ips" {
  filter {
    name   = "group-name"
    values = ["OfficeIPs"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.eks_vpc.id]
  }
}


data "aws_subnet" "private" {
  for_each = toset(data.aws_subnets.private.ids)
  id       = each.value
}
