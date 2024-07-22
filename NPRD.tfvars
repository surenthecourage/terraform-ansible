instances = {
  instance_one = {
    instance_type = "t2.small"
    ami_id        = "ami-04a81a99f5ec58529"
    tags = {
      Name = "project-ec2-instance-1"
    }
  },
  instance_two = {
    instance_type = "t2.micro"
    ami_id        = "ami-04a81a99f5ec58529"
    tags = {
      Name = "project-ec2-instance-2"
    }
  },
  instance_three = {
    instance_type = "t2.nano"
    ami_id        = "ami-04a81a99f5ec58529"
    tags = {
      Name = "project-ec2-instance-3"
    }
  }
}

vpc_cidr    = "10.10.0.0/16"
public_subnet_cidr = "10.10.1.0/24"
private_subnet_cidr = "10.10.2.0/24"
public_key_path = "~/.ssh/id_rsa.pub"
