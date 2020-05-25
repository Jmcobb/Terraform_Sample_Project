# Hello, welcome to my code test. 
# In this test I will use Terraform to configure a ELB, Auto-scaling EC2 Group, and a Redis DB. 
# I will demonstrate my knoldge of basic Terraform Topics below. 

##############################################################################################################
# Set some variables. 
##############################################################################################################
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "region" {
  default = "us-east-1"
}
variable "resource_size" {}
variable "instance_base_number" {}
variable "instance_max_number" {}

##############################################################################################################
# To complete the assigned task I will need to set up a provider. 
##############################################################################################################
provider "aws" {
    access_key = var.aws_access_key
    secret_key = var.aws_secret_key
    # ^ Typically, this would be bad practice to store in a file like this. However, I want to make this simple.
    region = var.region
}

##############################################################################################################
# Now, I will set up a some AMI data to call later. 
##############################################################################################################
data "aws_ami" "aws-linux" {
  most_recent      = true
  owners           = ["amazon"]
}

##############################################################################################################
# Next, via this configuration I will create the AWS services.
##############################################################################################################

# First, I will need to configure a launch configuration.
resource "aws_launch_configuration" "my_launch_configuration" {
  name_prefix   = "my-lc"
  image_id      = "data.aws_ami.aws-linux.id"
  instance_type = var.resource_size
}

# Then, autoscaling group.
resource "aws_autoscaling_group" "my_autoscaling_group" {
  name                 = "my-asg"
  launch_configuration = "aws_launch_configuration.my_launch_configuration.name"
  min_size             = var.instance_base_number
  max_size             = var.instance_max_number
  health_check_type    = "ELB"
  load_balancers       = ["aws_elb.my_elb.name"]
}

# Also, autoscaling policy for good mesure. 
resource "aws_autoscaling_policy" "my_policy" {
  name                   = "my-terraform-autoscaling-policy"
  scaling_adjustment     = var.instance_base_number
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = "aws_autoscaling_group.my_autoscaling_group.name"
}

# Then, the Elastic Load Balancer. 
resource "aws_elb" "my_elb" {
  name                = "my-terraform-elb"
  #vpc_zone_identifier = ["provided-subnet-1", "provided-subnet-2"]   
  # ^ will error out if ran as no actual subnet provided. 
  listener {
    instance_port     = 8000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  health_check {
    healthy_threshold   = var.instance_max_number
    unhealthy_threshold = var.instance_max_number
    timeout             = 3
    target              = "HTTP:8000/"
    interval            = 30
  }
  instances                   = ["aws_autoscaling_group.my_autoscaling_group"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  tags = {
    Name = "my-terraform-elb"
  }
}

# Last, the Redis Instance. 
resource "aws_elasticache_cluster" "my_redis_instance" {
  cluster_id           = "cluster-instance"
  engine               = "redis"
  node_type            = "cache.t2.micro"
  num_cache_nodes      = var.instance_base_number
  parameter_group_name = "default.redis3.2"
  engine_version       = "3.2.10"
  port                 = 8000
}

##############################################################################################################
# Above is a good take on IaC via Terraform. 
##############################################################################################################
