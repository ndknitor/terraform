// terraform init
// terraform apply -var-file=settings.tfvars -auto-approve
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

variable "region" {
  default = "ap-southeast-1"
}

variable "ami_id" {
  description = "Debian AMI ID for the EC2 instance"
  default     = "ami-0acbb557db23991cc"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "key_name" {
  description = "Key pair name for EC2 instance"
  default     = "Main"
}

variable "bucket_name" {
  description = "Unique name for the S3 bucket"
  default     = "s3-main-bucket"
}

# Provider Configuration
provider "aws" {
  region = var.region
}

# resource "random_string" "bucket_suffix" {
#   length  = 6
#   special = false
#   upper   = false
# }

# resource "aws_s3_bucket" "s3_bucket" {
#   bucket = "${var.bucket_name}-${random_string.bucket_suffix.result}"

#   tags = {
#     Name        = "S3Bucket"
#     Environment = "Dev"
#   }
# }

# # IAM Role and Policies
# resource "aws_iam_role" "ec2_role" {
#   name = "ec2-s3-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect    = "Allow"
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         }
#         Action = "sts:AssumeRole"
#       },
#     ]
#   })
# }

# resource "aws_iam_policy" "s3_access_policy" {
#   name = "s3-access-policy"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect   = "Allow"
#         Action   = ["s3:*"]
#         Resource = [
#           "${aws_s3_bucket.s3_bucket.arn}",
#           "${aws_s3_bucket.s3_bucket.arn}/*",
#         ]
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "attach_policy" {
#   role       = aws_iam_role.ec2_role.name
#   policy_arn = aws_iam_policy.s3_access_policy.arn
# }

# # EC2 Instance Profile
# resource "aws_iam_instance_profile" "instance_profile" {
#   name = "ec2-instance-profile"
#   role = aws_iam_role.ec2_role.name
# }

# Security Group for EC2
resource "aws_security_group" "ec2_sg" {
  name        = "allow_ssh"
  description = "Allow SSH traffic"

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

# EC2 Instance
resource "aws_instance" "ec2_instance" {
    count = 1
    ami                         = var.ami_id
    instance_type               = var.instance_type
    key_name                    = var.key_name
    #iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
    security_groups             = [aws_security_group.ec2_sg.name]

    tags = {
      Name = "s3-mounted-${count.index}"
    }

#     user_data = <<-EOF
# #!/bin/bash
# apt-get update -y
# apt-get install -y s3fs gcc libfuse-dev fuse make pkg-config libcurl4-openssl-dev libxml2-dev automake libtool

# # Setup s3fs
# mkdir -p /mnt/s3bucket
# echo "${aws_s3_bucket.s3_bucket.bucket}:/mnt/s3bucket" > /etc/fstab
# echo "${aws_iam_role.ec2_role.name}:${aws_iam_role.ec2_role.id}" > /etc/passwd-s3fs
# chmod 600 /etc/passwd-s3fs
# s3fs ${aws_s3_bucket.s3_bucket.bucket} /mnt/s3bucket -o iam_role=auto -o allow_other
#     EOF
}

# Generate Content Map for Template
# locals {
#   content = { for tag, instance in aws_instance.ec2_instance :
#     tag => instance.public_ip }
# }

# resource "local_file" "inventory" {
#   content  = templatefile("inventory.tmpl",  { content = local.content })
#   filename = "inventory.yaml"
# }

output "ansible_inventory" {
  value = templatefile("inventory.tpl", {
    instances = [
      for i, instance in aws_instance.ec2_instance :
      {
        name      = instance.tags["Name"]
        public_ip = instance.public_ip
      }
    ]
  })
}

# Save the Ansible inventory to a local file
resource "local_file" "ansible_inventory" {
  filename = "inventory.yaml"
  content  = templatefile("inventory.tpl", {
    instances = [
      for i, instance in aws_instance.ec2_instance :
      {
        name      = instance.tags["Name"]
        public_ip = instance.public_ip
      }
    ]
  })
}