terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "ap-south-1" # Change to your desired region
}

# Create a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create an internet gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
}

# Create public subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a" # Change to match your availability zone
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b" # Change to match your availability zone
}

# Create private subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "ap-south-1a" # Change to match your availability zone
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "ap-south-1b" # Change to match your availability zone
}

# Create a route table for public subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}

# Associate public subnets with the public route table
resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Create Elastic IPs
resource "aws_eip" "nat_eip" {
  vpc = true
}

# Create NAT Gateways
resource "aws_nat_gateway" "nat_gateway" {
allocation_id = aws_eip.nat_eip.id
subnet_id     = aws_subnet.public_subnet_1.id
}

# Create a route table for private subnets
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id # Use the first NAT Gateway
  }
}

# Associate private subnets with the private route table
resource "aws_route_table_association" "private_subnet_1_association" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_subnet_2_association" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}

# Create a security group for the bastion host
resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create a security group for the Ubuntu server
resource "aws_security_group" "ubuntu_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create a security group for the web server
resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private_subnet_1.cidr_block, aws_subnet.private_subnet_2.cidr_block]
  }
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.my_vpc.id

  # Add rules as needed for your application
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an Ubuntu instance for the bastion host
  resource "aws_instance" "bastion_host" {
  ami                    = "ami-03f4878755434977f" # Specify the AMI for Ubuntu
  instance_type          = "t2.micro"
  key_name               = "karthik-test-server" # Specify your key pair name
  subnet_id              = aws_subnet.public_subnet_1.id
  associate_public_ip_address = true
  vpc_security_group_ids     = [aws_security_group.bastion_sg.id]

  tags = {
    Name = "BastionHost"
  }
}

# Create an Ubuntu instance for the web server
resource "aws_instance" "web_server" {
  ami                    = "ami-03f4878755434977f" # Specify the AMI for Ubuntu
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet_1.id
  key_name               = "karthik-test-server" # Specify your key pair name
  vpc_security_group_ids     = [aws_security_group.web_sg.id]
  user_data               = <<-EOF
                              #!/bin/bash
                              apt-get update
                              apt-get install -y nginx
                              service nginx start
                            EOF

  tags = {
    Name = "WebServer"
  }
}

# Update the load balancer to include the web server

resource "aws_alb" "my_alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  tags = {
    Name = "MyALB"
  }
}



# Create a listener for the ALB
resource "aws_alb_listener" "my_alb_listener" {
  load_balancer_arn = aws_alb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.my_target_group.arn
  }
}

# Create a target group for the ALB
resource "aws_alb_target_group" "my_target_group" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id

  health_check {
    path = "/"
  }
}

# Attach the web server to the target group
resource "aws_alb_target_group_attachment" "web_server_attachment" {
  target_group_arn = aws_alb_target_group.my_target_group.arn
  target_id        = aws_instance.web_server.id
}

# Create an Auto Scaling Group
resource "aws_autoscaling_group" "my_asg" {
  launch_configuration = aws_launch_configuration.my_lc.name
  min_size             = 1
  max_size             = 3
  desired_capacity     = 2
  vpc_zone_identifier  = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
}

# Create a launch configuration
resource "aws_launch_configuration" "my_lc" {
  image_id        = data.aws_ami.latest_ami.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.web_sg.id]
  key_name        = "karthik-test-server" # Specify your key pair name

  # User data script to install and configure a web server
  user_data = <<-EOF
                #!/bin/bash
                apt-get update
                apt-get install -y nginx
                service nginx start
              EOF
 # Add the following block to configure the instance for Systems Manager
  metadata_options {
    http_tokens     = "required"
    http_put_response_hop_limit = 2
    http_endpoint   = "enabled"
  }

  # Add the following block to configure the instance for Systems Manager
  lifecycle {
    ignore_changes = [metadata_options]
  }

  # Define root volume and secondary volume for logs
  root_block_device {
    volume_size = 30
    volume_type = "gp2"
  }

  ebs_block_device {
    device_name = "/dev/xvdb"
    volume_size = 10
    volume_type = "gp2"
  }

}

resource "aws_iam_role" "ssm_role" {
  name               = "ssm_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ssm_role.name
}


# Data source to get the latest AWS AMI
data "aws_ami" "latest_ami" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_cloudwatch_metric_alarm" "my_alb_alarm" {
  alarm_name          = "my-alb-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"

  dimensions = {
    LoadBalancer = aws_alb.my_alb.name
  }

  alarm_description = "This metric monitors the number of healthy hosts behind the ALB."
  alarm_actions     = [aws_sns_topic.my_sns_topic.arn]
  insufficient_data_actions = [aws_sns_topic.my_sns_topic.arn]

  treat_missing_data = "breaching"

  tags = {
    Name = "my-alb-alarm"
  }
}



resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.my_asg.name
  alb_target_group_arn   = aws_alb_target_group.my_target_group.arn
}


resource "aws_sns_topic" "my_sns_topic" {
  name = "my-sns-topic"
}

resource "aws_sns_topic_subscription" "ses_subscription" {
  topic_arn = aws_sns_topic.my_sns_topic.arn
  protocol  = "email"
  endpoint  = "b.karthik01@gmail.com"  // Replace with your email address
}


resource "aws_sns_topic_subscription" "ses_subscription2" {
  topic_arn = aws_sns_topic.my_sns_topic.arn
  protocol  = "email"
  endpoint  = "megha.rande@siemens-energy.com"  // Replace with your email address
}


resource "aws_autoscaling_policy" "scale_out_policy" {
  name                   = "scale-out-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.my_asg.name
}

resource "aws_autoscaling_policy" "scale_in_policy" {
  name                   = "scale-in-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.my_asg.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_utilization_alarm" {
  alarm_name          = "cpu-utilization-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alarm when CPU exceeds 80%"
  alarm_actions       = [aws_autoscaling_policy.scale_out_policy.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.my_asg.name
  }
}


# Output the ALB DNS name for reference
output "alb_dns_name" {
  value = aws_alb.my_alb.dns_name
}
# Output the IDs and IPs for reference
output "vpc_id" {
  value = aws_vpc.my_vpc.id
}

output "public_subnet_1_id" {
  value = aws_subnet.public_subnet_1.id
}

output "public_subnet_2_id" {
  value = aws_subnet.public_subnet_2.id
}

output "private_subnet_1_id" {
  value = aws_subnet.private_subnet_1.id
}

output "private_subnet_2_id" {
  value = aws_subnet.private_subnet_2.id
}

output "bastion_sg_id" {
  value = aws_security_group.bastion_sg.id
}

output "ubuntu_sg_id" {
  value = aws_security_group.ubuntu_sg.id
}

output "bastion_host_public_ip" {
  value = aws_instance.bastion_host.public_ip
}

output "web_server_private_ip" {
  value = aws_instance.web_server.private_ip
}

