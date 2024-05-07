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
    key                 = "module7-tag"
    value               = var.module-tag
    propagate_at_launch = true
  }

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }
}

# Creating 3 EBS Volumes
resource "aws_ebs_volume" "main" {
  count             = 3  
  availability_zone = aws_instance.available.availability_zone
  size              = 10  

  tags = {
    Name = "module7-tag"
  }
}

# Attaching the created EBS Volumes
resource "aws_volume_attachment" "ebs_att" {
  count       = 3  # Attach each of the 3 created volumes
  device_name = "/dev/sda1"
  volume_id   = aws_ebs_volume.main.id
  instance_id = aws_instance.example.id
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