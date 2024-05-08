# Terraform for Final Summative Assesment
##############################################################################
# You will need to fill in the blanks
# This assessment combines Module 5, 6, and 7 requriements into one Terraform script
#
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

########################################################
# Security Group Rule for ALB 
########################################################
resource "aws_security_group_rule" "allow_http" {
  type            = "ingress"
  from_port       = 80
  to_port         = 80
  protocol        = "tcp"
  security_group_id = var.vpc_security_group_ids
  cidr_blocks     = ["0.0.0.0/0"]
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
    "Name" = var.elb-name
    "module7-tag" = var.module-tag
  }
}

# output will print a value out to the screen
output "url" {
  value = aws_lb.lb.dns_name
}

##############################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group
##############################################################################

resource "aws_lb_target_group" "main" {
  # depends_on is effectively a waiter -- it forces this resource to wait until the listed
  # resource is ready
  depends_on  = [aws_lb.lb]
  name        = var.tg-name
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.main.id
}

##############################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener
##############################################################################

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

##############################################################################
# Create launch template
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/launch_template
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template
##############################################################################
resource "aws_launch_template" "main" {
  image_id                             = var.imageid
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = var.instance-type
  key_name                             = var.key-name


# Creating and attaching Second EBS volume after the initial AMI specified Volume
  block_device_mappings {
    device_name = "/dev/sdf"  
    ebs {
      volume_size           = var.ebs-size  
      delete_on_termination = true  
      volume_type           = "gp2"  
    }
  }

# Third EBS volume
  block_device_mappings {
    device_name = "/dev/sdg"
    ebs {
      volume_size           = var.ebs-size
      delete_on_termination = true
      volume_type           = "gp2"
    }
  }

  tags = {
    Name = var.module-tag
  }


  monitoring {
    enabled = true
  }

  placement {
    availability_zone = data.aws_availability_zones.primary.id
  }

  network_interfaces {
  associate_public_ip_address = true
  subnet_id = data.aws_subnets.subneta.ids[0]
  security_groups = [var.vpc_security_group_ids]
  }
  
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.lt-name
      "module7-tag" = var.module-tag
    }
  }
  user_data = filebase64("./install-env.sh")
}


##############################################################################
# Create autoscaling group
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group
##############################################################################

resource "aws_autoscaling_group" "main" {
  name                      = var.asg-name
  depends_on                = [aws_launch_template.main]
  desired_capacity          = var.desired
  max_size                  = var.max
  min_size                  = var.min
  health_check_grace_period = 300
  health_check_type         = "ELB"
  target_group_arns         = [aws_lb_target_group.main.arn]
  vpc_zone_identifier       = [data.aws_subnets.subneta.ids[0], data.aws_subnets.subnetb.ids[0]]

  tag {
    key                 = "assessment"
    value               = var.module-tag
    propagate_at_launch = true
  }

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }
}

##############################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_attachment
##############################################################################
# Create a new ALB Target Group attachment

resource "aws_autoscaling_attachment" "main" {
  # Wait for lb to be running before attaching to asg
  depends_on  = [aws_lb_listener.main]
  autoscaling_group_name = aws_autoscaling_group.main.id
  lb_target_group_arn    = aws_lb_target_group.main.arn
}

output "alb-lb-tg-arn" {
  value = aws_lb_target_group.main.arn
}

output "alb-lb-tg-id" {
  value = aws_lb_target_group.main.id
}

##############################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table
##############################################################################

resource "aws_dynamodb_table" "mp2-dynamodb-table" {
  name           = var.dynamodb-table-name
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "Email"
  range_key      = "RecordNumber"

  # This will be the UUID and how we uniquely identify records
  attribute {
    name = "RecordNumber"
    type = "S"
  }

  attribute {
    name = "Email"
    type = "S"
  }

  tags = {
    Name        = var.module-tag
    key         = var.module-tag
  }
}

##############################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table_item
##############################################################################

resource "aws_dynamodb_table_item" "insert-sample-record" {
  depends_on = [aws_dynamodb_table.mp2-dynamodb-table]
  table_name = var.dynamodb-table-name
  hash_key   = aws_dynamodb_table.mp2-dynamodb-table.hash_key
  range_key  = aws_dynamodb_table.mp2-dynamodb-table.range_key

  item = <<ITEM
{
  "Email": {"S": "njerry@hawk.iit.edu"},
  "RecordNumber": {"S": "9e8091b0-8d53-11ee-95e6-035fc6c6cfb4"},
  "CustomerName": {"S": "Jerry Nkiambuo"},
  "Phone": {"S": "674187622"},
  "Stat": {"N": "0"},
  "RAWS3URL": {"S": ""},
  "FINSIHEDS3URL": {"S": ""}
}
ITEM
}

##############################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
# https://stackoverflow.com/questions/65984400/how-to-delete-non-empty-s3-bucket-with-terraform
##############################################################################

resource "aws_s3_bucket" "raw-bucket" {
  bucket = var.raw-s3-bucket
  force_destroy = true
}

resource "aws_s3_bucket" "finished-bucket" {
  bucket = var.finished-s3-bucket
  force_destroy = true
}