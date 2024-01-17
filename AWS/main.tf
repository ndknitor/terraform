terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

variable "access_key" {
  default = "???"
}
variable "secret_key" {
  default = "???"
}

provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = "your_aws_region"
}

resource "aws_instance" "example" {
  count         = 2
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  key_name      = "your_key_pair_name"

  provisioner "remote-exec" {
    inline = [
      "echo 'Hello world' > hello.txt"
    ]
    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("/home/kn/.ssh/id_rsa")
    }
  }
}
