terraform{
backend "s3" {
    bucket = "460469849793-terraform-state-bucket"
    region = "ap-south-1"
    key    = "eks.tfstate"
}
}