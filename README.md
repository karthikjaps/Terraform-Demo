Terraform AWS Web Server Deployment

Overview

This Terraform configuration deploys a web server setup on AWS, including a VPC with public and private subnets, an Application Load Balancer (ALB), Auto Scaling Group, and related resources. The setup includes a bastion host for SSH access and a web server running Nginx.

Services Used
AWS VPC
AWS EC2
AWS ALB
AWS Auto Scaling
AWS CloudWatch
AWS SNS
AWS Systems Manager (SSM)

Workflow

VPC Setup: Creates a VPC with public and private subnets across multiple availability zones.

Internet Gateway: Attaches an Internet Gateway to the VPC for internet access.

Subnet Configuration: Defines public and private subnets in different availability zones.

Route Tables: Creates route tables for public and private subnets with appropriate routes.

Security Groups: Configures security groups for the bastion host, web server, ALB, and other components.

Bastion Host: Deploys an Ubuntu instance as a bastion host in the public subnet for SSH access using AWS Systems Manager Session Manager for keyless login.

Web Server: Launches an Ubuntu instance in the private subnet running Nginx for serving web content.

ALB Setup: Configures an Application Load Balancer with listeners and target groups for routing traffic to the web server instances.

Auto Scaling: Sets up an Auto Scaling Group to automatically adjust the number of web server instances based on traffic load.

CloudWatch Alarms: Creates CloudWatch alarms to monitor the ALB's health and CPU utilization of the web server instances.

Notifications: Sets up an SNS topic with email subscriptions for receiving notifications from CloudWatch alarms.

Usage
Clone this repository:


https://github.com/karthikjaps/Terraform-Demo.git


Modify the following variables in terraform.tfvars file:

AWS _CLI:configure AWS CLI

region: AWS region to deploy resources.

key_name: Name of your EC2 key pair for SSH access.

endpoint: Email endpoint for SNS notifications.

Initialize Terraform:

terraform init

Review the Terraform plan:

terraform plan

Deploy the infrastructure:

terraform apply

Access the web server:

Use the bastion host's public IP to access the Systems Manager Session Manager for keyless SSH login to the bastion host.
From the bastion host, you can access the web server's private IP to view the Nginx default page.

Clean up:


terraform destroy
