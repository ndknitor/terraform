terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

variable "token" {
    default = "???"
}
variable "config_path" {
  default = "/home/kn/Project/Terraform/DigitalOcean/config"
}
variable "private_key_path" {
  default = "/home/kn/.ssh/id_rsa"
}
data "digitalocean_ssh_key" "existing_key" {
    name = "Main key"
}

provider "digitalocean" {
    token = var.token
}
resource "digitalocean_droplet" "main" {
    count              = 2
    name               = "digitalocean-${count.index + 1}"
    image              = "debian-11-x64" 
    size               = "s-1vcpu-1gb"   
    region             = "sgp1"        
    ssh_keys           = [data.digitalocean_ssh_key.existing_key.id] 
    provisioner "remote-exec" {
        inline = [
            "echo 'Hello world'"
        ]
        connection {
            host        = self.ipv4_address
            type        = "ssh"
            user        = "root"
            private_key = file(var.private_key_path)
        }
    }
    provisioner "local-exec" {
        command = <<EOT
            echo 'Host digitalocean-${count.index + 1}' >> ${var.config_path}
            echo '   Hostname ${self.ipv4_address}' >> ${var.config_path}
            echo '   User root' >> ${var.config_path}
            echo '   Port 22' >> ${var.config_path}
            echo '   IdentityFile ${var.private_key_path}' >> ${var.config_path}
        EOT
  }
}

// terraform init
// terraform apply -var-file=token.tfvars