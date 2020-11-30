
# 0. Provider Info
provider "aws" {
  region = "us-east-1"
}

# 1.create vpc

resource "aws_vpc" "venkat-vpc" {
  cidr_block       = "190.160.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "venkat"
    Location = "Maryland"
  }
}

#2.create internet gateway

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.venkat-vpc.id

  tags = {
    Name = "venkat-vpc-igw"
  }
}

# 3.create custom route table
resource "aws_route_table" "venkat_route_table" {
  vpc_id = aws_vpc.venkat-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "venkat-routetable"
  }
}

# 4.create a subnet
 
resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.venkat-vpc.id
  cidr_block = "190.160.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "venkat-vpc-subnet1"
  }
}

#5.associate subnet with route table

resource "aws_route_table_association" "rta-a" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.venkat_route_table.id
}

#6.create security group to allow port 22,80 and 443

resource "aws_security_group" "allow_web_traffic" {
  name        = "allow_web"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.venkat-vpc.id

  ingress {
    description = "https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ssh"
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
    Name = "web-traffic"
  }
}

#7.create a network interface with an ip in the subnet created in step #4

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet. subnet1.id
  private_ips     = ["190.160.1.5"]
  security_groups = [aws_security_group.allow_web_traffic.id]

  #attachment {
  #  instance     = aws_instance.test.id
  #  device_index = 0
  #}
}

#8.assign an elastic ip for the network interface created in step #7

resource "aws_eip" "web-server-cipone" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "190.160.1.5"
  depends_on = [ aws_internet_gateway.igw ]
}

#9.create ubuntu server install/enable apache2
resource "aws_instance" "web-server-instance" {
  ami = "ami-0885b1f6bd170450c"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "jenkins"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo your very first webserver> /var/www/html/index.html'
              EOF
  tags = {
    Name = "web-server"
  }            
}
