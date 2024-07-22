resource "aws_vpc" "project_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "project_subnet" {
  vpc_id     = aws_vpc.project_vpc.id
  cidr_block = var.subnet_cidr

  tags = {
    "Name" = "${var.project_name}-subnet"
  }
}

resource "aws_internet_gateway" "project-igw" {
  vpc_id = aws_vpc.project_vpc.id

  tags = {
    "Name" = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "project-rt" {
  vpc_id = aws_vpc.project_vpc.id

  tags = {
    "Name" = "${var.project_name}-rt"
  }
}

resource "aws_route" "project-route-igw" {
  route_table_id         = aws_route_table.project-rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.project-igw.id

}

resource "aws_route_table_association" "project-rta" {
  route_table_id = aws_route_table.project-rt.id
  subnet_id      = aws_subnet.project_subnet.id

}

resource "aws_security_group" "project-main-sg" {
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
    cidr_blocks = ["0.0.0.0/0"]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {
    "Name" = "${var.project_name}-security-group"
  }
}

resource "aws_key_pair" "project_ssh_key" {
  key_name   = "ssh_key"
  public_key = file(var.public_key_path)

  tags = {
    "Name" = "ssh-key"
  }
}

resource "aws_instance" "project_instance" {

  for_each      = var.instances
  instance_type = each.value["instance_type"]
  ami           = each.value["ami_id"]
  key_name      = aws_key_pair.project_ssh_key.key_name

  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.project-main-sg.id]
  subnet_id                   = aws_subnet.project_subnet.id


  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = each.value["tags"]
}

resource "null_resource" "run_inventory_script" {
  provisioner "local-exec" {
    command = "python3 dynamic_inventory.py"
  }
  depends_on = [aws_instance.project_instance]
}