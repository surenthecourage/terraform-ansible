# Project VPC
resource "aws_vpc" "project_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.project_vpc.id
  cidr_block = var.public_subnet_cidr
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

#Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.project_vpc.id
  cidr_block = var.private_subnet_cidr

  tags = {
    Name = "${var.project_name}-private-subnet"
  }
}

#Internet Gateway
resource "aws_internet_gateway" "project_igw" {
  vpc_id = aws_vpc.project_vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

#NAT gateway
resource "aws_nat_gateway" "project_nat" {
  allocation_id = aws_eip.project_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "${var.project_name}-nat"
  }
}

# Public IP for Nat Gateway
resource "aws_eip" "project_eip" {
  tags = {
    Name = "${var.project_name}-eip"
  }
}

# Route table - Public
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.project_vpc.id

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Public Route
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.project_igw.id
}

# Public Route table association
resource "aws_route_table_association" "public_rta" {
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnet.id
}

# Route table - Private
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.project_vpc.id

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# Private Route
resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.project_nat.id
}

# Private Route table association
resource "aws_route_table_association" "private_rta" {
  route_table_id = aws_route_table.private_route_table.id
  subnet_id      = aws_subnet.private_subnet.id
}

# Security Groups for private subnet instances
resource "aws_security_group" "project_main_sg" {
  name   = "HTTP and SSH rule"
  vpc_id = aws_vpc.project_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public_subnet.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-security-group"
  }
}

# AWS key pair
resource "aws_key_pair" "project_ssh_key" {
  key_name   = "ssh_key"
  public_key = file(var.public_key_path)

  tags = {
    Name = "ssh-key"
  }
}

# EC2 instances located in private subnet
resource "aws_instance" "project_instance" {
  for_each      = var.instances
  instance_type = each.value["instance_type"]
  ami           = each.value["ami_id"]
  key_name      = aws_key_pair.project_ssh_key.key_name

  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.project_main_sg.id]
  subnet_id                   = aws_subnet.private_subnet.id

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = each.value["tags"]
}

# python script execution to run inventory script
resource "null_resource" "run_inventory_script" {
  provisioner "local-exec" {
    command = "python3 dynamic_inventory.py"
  }
  depends_on = [aws_instance.project_instance]
}

#BASTION HOST CONFIGURATION

#Bastion security Group
resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.project_vpc.id
  name   = "Bastion Security Group"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["<your-ip>/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-bastion-sg"
  }
}

# Bastion host ec2 instance
resource "aws_instance" "bastion" {
  ami           = "ami-04a81a99f5ec58529"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.project_ssh_key.key_name

  subnet_id = aws_subnet.public_subnet.id

  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  tags = {
    Name = "${var.project_name}-bastion"
  }
}