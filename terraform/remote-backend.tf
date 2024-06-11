terraform {
  backend "s3" {
    bucket = "sn-labs-devops"
    key    = "apps/portfolio-app/app.tfstate"
    region = "us-east-1"
  }
}