### Provider import
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.38.0"
    }
  }
}

provider "aws" {
  region = "eu-west-3"
}


### Retrieve default VPC ID and default Subnets ID - we will need them later on for other resources
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

### Cluster configuration

# 1 Create Launch Configuration - a template for our EC2 insaznces
resource "aws_launch_configuration" "launch" {
  image_id        = "ami-05262a4bcea6f9fa2"
  instance_type   = "t2.micro"
  user_data = "${file("install.sh")}"

  lifecycle {
    create_before_destroy = true
  }

}

# 2 Create ASG
resource "aws_autoscaling_group" "cluster" {
  launch_configuration = aws_launch_configuration.launch.name
  vpc_zone_identifier = data.aws_subnets.default.ids

  min_size = 2
  max_size = 3

}


## Load Balancer

#1. Create Security Group to allow external request to port 80 from Load Balancer and allow all outbound requests
resource "aws_security_group" "security_group" {
  name = "alb-security_group"

  # Allow inbound HTTP requests
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound requests
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# 2. Create an Application Load Balancer
resource "aws_lb" "guest-app" {
  name               = "guest-app"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  # security_groups    = [aws_security_group.security_group.id]



}

# 3. Create Target group to redirect request to port 5000 of EC2 instances
resource "aws_lb_target_group" "guest-app" {
   name     = "guest-app"
   port     = 5000
   protocol = "HTTP"
   vpc_id = data.aws_vpc.default.id
 }


# 4. Listener that will listen on HTTP request coming to port 80 of the Load Balancer
resource "aws_lb_listener" "guest-app" {
  load_balancer_arn = aws_lb.guest-app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.guest-app.arn
  }
}


# 5. Attach cluster and target group
resource "aws_autoscaling_attachment" "guest-app" {
  autoscaling_group_name = aws_autoscaling_group.cluster.id
  lb_target_group_arn   = aws_lb_target_group.guest-app.arn
}


