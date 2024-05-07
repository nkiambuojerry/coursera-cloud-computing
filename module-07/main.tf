# Terraform for Module 07
##############################################################################
# You will need to fill in the blank values using the values in terraform.tfvars
# or using the links to the documentation. You can also make use of the auto-complete
# in VSCode
# Reference your code in Module 04 to fill out the values
# This is the same exercise but converting from Bash to HCL
##############################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpcs
##############################################################################
data "aws_vpc" "main" {
  default = true
}

output "vpcs" {
  value = data.aws_vpc.main.id
}
##############################################################################
# https://developer.hashicorp.com/terraform/tutorials/configuration-language/data-source
##############################################################################
data "aws_availability_zones" "available" {
  state = "available"
  /*
  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
*/
}

##############################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones
##############################################################################
data "aws_availability_zones" "primary" {
  filter {
    name   = "zone-name"
    values = ["us-east-1a"]
  }
}

data "aws_availability_zones" "secondary" {
  filter {
    name   = "zone-name"
    values = ["us-east-1b"]
  }
}

##############################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets
##############################################################################
# The data value is essentially a query and or a filter to retrieve values
data "aws_subnets" "subneta" {
  filter {
    name   = "availabilityZone"
    values = ["us-east-1a"]
  }
}

data "aws_subnets" "subnetb" {
  filter {
    name   = "availabilityZone"
    values = ["us-east-1b"]
  }
}

data "aws_subnets" "subnetc" {
  filter {
    name   = "availabilityZone"
    values = ["us-east-1c"]
  }
}

output "subnetid-1a" {
  value = [data.aws_subnets.subneta.ids]
}

##############################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb
##############################################################################
resource "aws_lb" "lb" {
  name               = var.elb-name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.vpc_security_group_ids]
  subnets = [data.aws_subnets.subneta.ids[0], data.aws_subnets.subnetb.ids[0]]
  
  enable_deletion_protection = false

  tags = {
    Environment = var.module-tag
  }
}

# output will print a value out to the screen
output "url" {
  value = aws_lb.lb.dns_name
}

