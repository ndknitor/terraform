terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

variable "digital_ocean_token" {
    default = "???"
}
provider "digitalocean" {
    token = var.digital_ocean_token
}
data "digitalocean_ssh_key" "existing_key" {
    name = "Main key"
}

resource "digitalocean_droplet" "main" {
    count              = 1
    name               = "main-${count.index + 1}"
    image              = "debian-11-x64" 
    size               = "s-1vcpu-1gb"   
    region             = "sgp1"        
    ssh_keys           = [data.digitalocean_ssh_key.existing_key.id] 
    provisioner "remote-exec" {
        inline = [
            "echo 'Hello world' > hello.txt"
        ]
        connection {
            host        = self.ipv4_address
            type        = "ssh"
            user        = "root"
            private_key = file("/home/kn/.ssh/id_rsa")
        }
    }
}


