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
  count    = 2
  name     = "do-${count.index + 1}"
  image    = "debian-11-x64"
  size     = "s-1vcpu-1gb"
  region   = "sgp1"
  ssh_keys = [data.digitalocean_ssh_key.existing_key.id]
  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt upgrade -y",
      "sudo apt install -y net-tools ufw",
      "echo 'export PATH=$PATH:/sbin' >> .bashrc",

      #Install Docker
      "sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release",
      "curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
      "echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update",
      "sudo apt-get install -y docker-ce",

      "sudo ufw default deny incoming",
      "sudo ufw default allow outgoing",
      "sudo ufw allow 22",

      # Allow HTTP and HTTPS traffic
      # "sudo ufw allow 443",
      # "sudo ufw allow 80",

      # Allow Cloudflare inbound HTTPS traffic 
      # "sudo ufw allow from 173.245.48.0/20 to any port 443",
      # "sudo ufw allow from 103.21.244.0/22 to any port 443",
      # "sudo ufw allow from 103.22.200.0/22 to any port 443",
      # "sudo ufw allow from 103.31.4.0/22 to any port 443",
      # "sudo ufw allow from 141.101.64.0/18 to any port 443",
      # "sudo ufw allow from 108.162.192.0/18 to any port 443",
      # "sudo ufw allow from 190.93.240.0/20 to any port 443",
      # "sudo ufw allow from 188.114.96.0/20 to any port 443",
      # "sudo ufw allow from 197.234.240.0/22 to any port 443",
      # "sudo ufw allow from 198.41.128.0/17 to any port 443",
      # "sudo ufw allow from 162.158.0.0/15 to any port 443",
      # "sudo ufw allow from 104.16.0.0/13 to any port 443",
      # "sudo ufw allow from 104.24.0.0/14 to any port 443",
      # "sudo ufw allow from 172.64.0.0/13 to any port 443",
      # "sudo ufw allow from 131.0.72.0/22 to any port 443",
      # "sudo ufw allow from 2400:cb00::/32 to any port 443",
      # "sudo ufw allow from 2606:4700::/32 to any port 443",
      # "sudo ufw allow from 2803:f800::/32 to any port 443",
      # "sudo ufw allow from 2405:b500::/32 to any port 443",
      # "sudo ufw allow from 2405:8100::/32 to any port 443",
      # "sudo ufw allow from 2a06:98c0::/29 to any port 443",
      # "sudo ufw allow from 2c0f:f248::/32 to any port 443",

      "sudo ufw enable",
      "sudo ufw status"
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
            echo 'Host do-${count.index + 1}' >> ${var.config_path}
            echo '   Hostname ${self.ipv4_address}' >> ${var.config_path}
            echo '   User root' >> ${var.config_path}
            echo '   Port 22' >> ${var.config_path}
            echo '   IdentityFile ${var.private_key_path}' >> ${var.config_path}
        EOT
  }
}

// terraform init
// terraform apply -var-file=token.tfvars -auto-approve
