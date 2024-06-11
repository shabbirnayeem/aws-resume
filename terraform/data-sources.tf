data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = ["default"]
  }
}

data "aws_subnet" "subnet-a" {
  filter {
    name   = "tag:Name"
    values = ["public-a"]
  }
}

data "aws_subnet" "subnet-b" {
  filter {
    name   = "tag:Name"
    values = ["public-b"]
  }
}

data "aws_route53_zone" "zone" {
  name = "shabbirnayeem.com"
}

data "aws_iam_role" "ecsTaskExecutionRole" {
  name = "ecsTaskExecutionRole"
}

data "aws_acm_certificate" "cert" {
  domain      = "www.shabbirnayeem.com"
  statuses    = ["ISSUED"]
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}
