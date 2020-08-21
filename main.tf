# Configure the AWS Provider with keys
provider "aws" {
  region  = "ap-south-1"
  access_key = "##############################"
  secret_key = "##########################################"
}

# 1. Create VPC
resource "aws_vpc" "main1" {
  cidr_block = "10.0.0.0/16"
  tags = {
    "Name" = "Prod_VPC1"
  }
  }

# 2. Create Internet Gateway
resource "aws_internet_gateway" "prodgw1" {
  vpc_id = aws_vpc.main1.id
  tags = {
    Name = "Prod_IGW1"
  }
}

# 3. Create Custom Route Table
resource "aws_route_table" "Prod_route" {
  vpc_id = aws_vpc.main1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prodgw1.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.prodgw1.id
  }

  tags = {
    Name = "Prod_route1"
  }
}

# 4. Create a Subnet
resource "aws_subnet" "subnet1" {
  vpc_id = aws_vpc.main1.id
  cidr_block = "10.0.1.0/24"
  tags = {
    "Name" = "Prod_sub1"
  }
}

# 5. Associate Subnet with Route Table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.Prod_route.id
}

# 6. Create Security Group to allow port 22,80,443 

resource "aws_security_group" "allow_web" {
  name        = "allow_webtrafic"
  description = "Allow webtraffic inbound traffic"
  vpc_id      = aws_vpc.main1.id

  ingress {
    description = "https from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "http from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    description = "ssh from VPC"
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
    Name = "allow_web"
  }
}

# 7. Create a network interface with an ip in the subnet that that was created in step 4

resource "aws_network_interface" "vmnic1" {
  subnet_id       = aws_subnet.subnet1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}


# 8. Assign an Elastic IP to the network interface created in step 7

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.vmnic1.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.prodgw1]
}

# 9. Create Ubuntu server and install/enable apache2

resource "aws_instance" "Ubuntu_web" {
   ami = "ami-02b5fbc2cb28b77b8"
   instance_type = "t2.micro"
   key_name= "ec2test"
   network_interface {
     device_index = 0
     network_interface_id = aws_network_interface.vmnic1.id
   }
   
   user_data = <<-EOF
               #!/bin/bash
               sudo apt update -y
               sudo apt install apache2 -y
               sudo systemctl enable apache2
               sudo systemctl start apache2
               sudo bash -c 'echo This is first web ubunru server >/var/www/html/index.html'
                EOF
   tags = {
   Name = "EC2-Ubuntu"
}
}
