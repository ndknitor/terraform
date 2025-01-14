// terraform init
// terraform apply -var-file=settings.tfvars -auto-approve

variable "protected" {
  default = false
}

variable "prefix_name" {
  default     = "kn"
}

variable "local_private_key_path" {
  default = "~/.ssh/id_key"
}

variable "region" {
  default = "ap-southeast-1"
}

variable "ami" {
  description = "Debian AMI ID for the EC2 instance"
  default     = "ami-0acbb557db23991cc"
}

variable "username" {
  description = "Username of AMI"
  default     = "admin"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "key_name" {
  description = "Key pair name for EC2 instance"
  default     = "id_key"
}

variable "vpc_cidr_block" {
  default = "10.0.0.0/16"
}

variable "public_subnet" {
  default = "10.0.1.0/24"
}

variable "private_subnet_nat" {
  default = "10.0.2.0/24"
}

variable "private_subnet" {
  default = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24"]
}


variable "azs" {
 type        = list(string)
 description = "Availability Zones"
 default     = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
}


variable "rds_admin_password" {
  default = "???"
}

variable "rds_instance_class" {
  default = "db.t4g.micro"
} 

variable "rds_allocated_storage" {
  default = 20
}


provider "aws" {
  region = var.region
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.prefix_name}-vpc"
  }
#   lifecycle {
#     prevent_destroy = var.protected
#   }
}

# Create a Private Subnet
resource "aws_subnet" "private" {
  count = length(var.private_subnet)
  vpc_id     = aws_vpc.main.id
  cidr_block = element(var.private_subnet, count.index)
  availability_zone = element(var.azs, count.index)
  tags = {
    Name = "${var.prefix_name}-private-subnet"
  }
}

# Create a Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.prefix_name}-public-subnet"
  }
}

# Create a Private NAT Subnet
resource "aws_subnet" "private_nat" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_nat
  tags = {
    Name = "${var.prefix_name}-private-subnet-nat"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.prefix_name}-igw"
  }
}

# Route table for public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.prefix_name}-public-route-table"
  }
}

# Associate the public route table with the public subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
}

resource "aws_eip" "nat" {
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "private_route_table_association" {
  subnet_id      = aws_subnet.private_nat.id
  route_table_id = aws_route_table.private_route_table.id
}

# Security Group for EC2 Instances
resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.main.id

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

  tags = {
    Name = "${var.prefix_name}-ec2-security-group"
  }
}

# EC2 Instance with Public IP
resource "aws_instance" "public_ec2" {
  ami           =  var.ami
  instance_type = var.instance_type
  key_name = var.key_name
  subnet_id     = aws_subnet.public.id
  security_groups = [aws_security_group.ec2_sg.id]

  tags = {
    Name = "${var.prefix_name}-public-ec2"
  }
   provisioner "local-exec" {
    command = <<EOT
echo "Host ${var.prefix_name}-public-ec2
    Hostname ${self.public_ip}
    User ${var.username}
    IdentityFile ${var.local_private_key_path}" >> config 
    EOT
  }
}

# EC2 Instance with Private IP
resource "aws_instance" "private_ec2" {
  depends_on = [ aws_instance.public_ec2 ]
  ami           = var.ami
  instance_type = var.instance_type
  key_name = var.key_name
  subnet_id     = aws_subnet.private_nat.id
  security_groups = [aws_security_group.ec2_sg.id]

  tags = {
    Name = "${var.prefix_name}-private-ec2"
  }

   provisioner "local-exec" {
    command = <<EOT
echo "Host ${var.prefix_name}-private-ec2
    Hostname ${self.private_ip}
    User ${var.username}
    ProxyJump ${aws_instance.public_ec2.tags["Name"]}
    IdentityFile ${var.local_private_key_path}" >> config 
    EOT
  }
}

# Security Group for RDS Instance
resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix_name}-rds-security-group"
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.prefix_name}-rds-subnet-group"
  subnet_ids = tolist(aws_subnet.private[*].id)

  
  tags = {
    Name = "${var.prefix_name}-rds-subnet-group"
  }
}

# RDS Instance with Private IP
resource "aws_db_instance" "rds" {
  identifier = "${var.prefix_name}-rds"
  allocated_storage    = var.rds_allocated_storage
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = var.rds_instance_class
  username             = "admin"
  password             = var.rds_admin_password
  multi_az                    = false
  auto_minor_version_upgrade  = false
  skip_final_snapshot  = true
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  tags = {
    Name = "${var.prefix_name}-rds"
  }
}
