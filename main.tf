terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
  default_tags {
    tags = {
      Training = "Platform-Engineering-4"
    }
  }
}

# 1. Look up the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  owners = ["099720109477"] # Canonical
}

# 2. Your Local Ed25519 SSH Key Pair Configuration
resource "aws_key_pair" "deployer" {
  key_name   = "platform-eng-key-3b"
  # Adjusted for your Ed25519 key (fix spelling here if your file has the extra '3')
  public_key = file(pathexpand("~/.ssh/id_ed25519.pub")) 
}

# 3. Create a Brand New Custom VPC
resource "aws_vpc" "custom_vpc" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "Exercise-3b-VPC"
  }
}

# 4. Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.custom_vpc.id

  tags = {
    Name = "Exercise-3b-IGW"
  }
}

# 5. Create a Public Subnet inside the Custom VPC
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.custom_vpc.id
  cidr_block              = "10.10.1.0/24"
  map_public_ip_on_launch = true # This makes it a "Public" subnet

  tags = {
    Name = "Exercise-3b-Public-Subnet"
  }
}

# 6. Create a Route Table Routing Traffic to the Internet Gateway
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.custom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Exercise-3b-Route-Table"
  }
}

# 7. Associate the Route Table with your Public Subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# 8. Create a Security Group inside the NEW Custom VPC
resource "aws_security_group" "allow_ssh_3b" {
  name        = "allow_ssh_3b"
  description = "Allow inbound SSH traffic"
  vpc_id      = aws_vpc.custom_vpc.id

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

# 9. Spin up the EC2 Instance inside the New Public Subnet
resource "aws_instance" "web_server_3b" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet.id
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.allow_ssh_3b.id]

  tags = {
    Name = "Exercise-3b-EC2"
  }
}

# 10. Output the resulting public IP address
output "instance_public_ip_3b" {
  value = aws_instance.web_server_3b.public_ip
}
