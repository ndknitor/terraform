terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

variable "aws_access_key" {
  default = "???"
}

variable "aws_secret_key" {
  default = "???"
}

variable "region" {
  default = "ap-southeast-1"
}

variable "config_path" {
  default = "/home/kn/Project/Terraform/AWS/config"
}

variable "private_key_path" {
  default = "/home/kn/.ssh/main.pem"
}

data "http" "current_ip" {
  url = "https://ipv4.icanhazip.com"
}

provider "aws" {
  region     = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "aws_instance" "teraws" {
  count = 2
  ami   = "ami-0588c11374527e516"
  security_groups = ["inbound-ssh", "outbound-trafic",
    "cloudflare_inbound_https"
  ]
  instance_type = "t2.micro"
  key_name      = "main"
  tags = {
    Name = "aws-${count.index + 1}"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'export PATH=$PATH:/sbin' >> .bashrc",
      "sudo apt update -y",
      # "sudo unattended-upgrade --no-minimal-upgrade-steps",
      # "sudo apt install -y net-tools",

      # # Install Docker
      # "sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release",
      # "curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
      # "echo deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      # "sudo apt-get update -y",
      # "sudo apt-get install -y docker-ce",
      # "sudo usermod -aG docker $USER"
    ]
    connection {
      type        = "ssh"
      user        = "admin"
      private_key = file(var.private_key_path)
      host        = self.public_ip
    }
  }

  provisioner "local-exec" {
    command = <<EOT
      echo 'Host aws-${count.index + 1}' >> ${var.config_path}
      echo '   Hostname ${self.public_ip}' >> ${var.config_path}
      echo '   User admin' >> ${var.config_path}
      echo '   Port 22' >> ${var.config_path}
      echo '   IdentityFile ${var.private_key_path}' >> ${var.config_path}
    EOT
  }
}

resource "aws_security_group" "inbound_ssh" {
  name        = "inbound-ssh"
  description = "Inbound SSH traffic"
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [
      "${chomp(data.http.current_ip.response_body)}/32"
      # "0.0.0.0/0"
    ]
  }
}

resource "aws_security_group" "outbound_traffic" {
  name        = "outbound-trafic"
  description = "Outbound traffic"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# resource "aws_security_group" "web_server" {
#   name        = "inbound-web-server"
#   description = "Allow inbound Http and Https traffic"
#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }


# resource "aws_security_group" "cloudflare_inbound_https" {
#   name        = "cloudflare-inbound-https"
#   description = "Inbound HTTPS trafic from Cloudflare"
#   ingress {
#     from_port = 443
#     to_port   = 443
#     protocol  = "tcp"
#     cidr_blocks = [
#       "173.245.48.0/20",
#       "103.21.244.0/22",
#       "103.22.200.0/22",
#       "103.31.4.0/22",
#       "141.101.64.0/18",
#       "108.162.192.0/18",
#       "190.93.240.0/20",
#       "188.114.96.0/20",
#       "197.234.240.0/22",
#       "198.41.128.0/17",
#       "162.158.0.0/15",
#       "104.16.0.0/13",
#       "104.24.0.0/14",
#       "172.64.0.0/13",
#       "131.0.72.0/22"
#     ]
#     ipv6_cidr_blocks = [
#       "2400:cb00::/32",
#       "2803:f800::/32",
#       "2405:b500::/32",
#       "2405:8100::/32",
#       "2a06:98c0::/29",
#       "2c0f:f248::/32",
#       "2606:4700::/32"
#     ]
#   }
# }

// terraform init
// terraform apply -var-file=settings.tfvars -auto-approve
