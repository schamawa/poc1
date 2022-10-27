provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "test_vpc" {
  cidr_block = "10.10.0.0/16"

  tags = {
    Name = "vpc"
  }
}

##########Subnet ap-south-1a######################################

resource "aws_subnet" "test_subnet_pub1" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = "10.10.3.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "subnet_pub1"
  }
}

resource "aws_subnet" "test_subnet_pvt1" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = "10.10.5.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = "false"

  tags = {
    Name = "subnet_pvt1"
  }
}

##########Subnet ap-south-1b######################################

resource "aws_subnet" "test_subnet_pub2" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = "10.10.4.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "subnet_pub2"
  }
}

resource "aws_subnet" "test_subnet_pvt2" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = "10.10.6.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = "false"

  tags = {
    Name = "subnet_pvt2"
  }
}
################ IGW ################################################

resource "aws_internet_gateway" "test_igw" {
  vpc_id = aws_vpc.test_vpc.id

  tags = {
    Name = "test_IGW"
  }
}


#################NAT GW #################################################
resource "aws_eip" "test1" {
  
  vpc      = true
}


resource "aws_nat_gateway" "Nat_GW" {
  
  allocation_id = aws_eip.test1.id
  subnet_id     = aws_subnet.test_subnet_pub1.id

  tags = {
    Name = "Nat_GW"
  }
}

###################### Route_Table ######################################

resource "aws_route_table" "test_rt1" {
  vpc_id = aws_vpc.test_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # All resources in public subnet are accessible from all internet.
    gateway_id = aws_internet_gateway.test_igw.id
  }

  tags = {
    Name = "Public-route"
  }
}



resource "aws_route_table_association" "test_rta1" {
  route_table_id = aws_route_table.test_rt1.id
  subnet_id      = aws_subnet.test_subnet_pub1.id
}

resource "aws_route_table" "test_rt2" {
  vpc_id = aws_vpc.test_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # All resources in private subnet are accessible from all internet.
    nat_gateway_id = aws_nat_gateway.Nat_GW.id
  }

  tags = {
    Name = "private-route"
  }
}



resource "aws_route_table_association" "test_rta2" {
  route_table_id = aws_route_table.test_rt2.id
  subnet_id      = aws_subnet.test_subnet_pvt1.id
}



resource "aws_route_table" "test_rt3" {
  vpc_id = aws_vpc.test_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # All resources in public subnet are accessible from all internet.
    gateway_id = aws_internet_gateway.test_igw.id
  }

  tags = {
    Name = "Public-route1"
  }
}

resource "aws_route_table_association" "test_rta3" {
  route_table_id = aws_route_table.test_rt3.id
  subnet_id      = aws_subnet.test_subnet_pub2.id
}

resource "aws_route_table" "test_rt4" {
  vpc_id = aws_vpc.test_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # All resources in private subnet are accessible from all internet.
    nat_gateway_id = aws_nat_gateway.Nat_GW.id
  }

  tags = {
    Name = "Private-route2"
  }
}

resource "aws_route_table_association" "test_rta4" {
  route_table_id = aws_route_table.test_rt4.id
  subnet_id      = aws_subnet.test_subnet_pvt2.id
}
################ Security_Group ###############################################

resource "aws_security_group" "test_sg" {
  name   = "test_sg"
  vpc_id = aws_vpc.test_vpc.id

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    security_groups = [aws_security_group.test_sg1.id]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "test_sg"
  }

}

resource "aws_security_group" "test_sg1" {
  name   = "test_sg1"
  vpc_id = aws_vpc.test_vpc.id


  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

     tags = {
    Name = "test_sg1"
  }

}
##############################EC2 Instance ###############################################

resource "aws_instance" "test_ec2" {
  ami           = "ami-076e3a557efe1aa9c" # ap-south1
  subnet_id     = aws_subnet.test_subnet_pvt1.id
  instance_type = "t2.micro"
  security_groups = [aws_security_group.test_sg.id]
  key_name = "su"
  ebs_block_device {
               device_name = "/dev/sdb"
               volume_size = "1"
               }
  user_data = <<EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
chkconfig httpd on
EC2_AVAIL_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
echo "<h1>Hello VF-Cloud World – running on $(hostname -f) in AZ $EC2_AVAIL_ZONE on port 80 </h1>" > /test/index.html
ln -s /test/index.html /var/www/html/index.html
pvcreate /dev/sdb
vgcreate test_vg /dev/sdb
lvcreate -n test_lv -L 750M test_vg
mkfs -t xfs /dev/test_vg/test_lv
mkdir /test
mount /dev/test_vg/test_lv  /test
EOF


  tags = {
    Name = "test-ec2"
  }


}


resource "aws_instance" "test1_ec2" {
  ami           = "ami-076e3a557efe1aa9c" # ap-south1
  subnet_id     = aws_subnet.test_subnet_pvt2.id
  instance_type = "t2.micro"
  security_groups = [aws_security_group.test_sg.id]
  key_name = "su"
  ebs_block_device {
               device_name = "/dev/sdb"
               volume_size = "1"
               }
  user_data = <<EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
chkconfig httpd on
EC2_AVAIL_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
echo "<h1>Hello VF-Cloud World – running on $(hostname -f) in AZ $EC2_AVAIL_ZONE on port 80 </h1>" > /test/index.html
ln -s /test/index.html /var/www/html/index.html
pvcreate /dev/sdb
vgcreate test_vg /dev/sdb
lvcreate -n test_lv -L 750M test_vg
mkfs -t xfs /dev/test_vg/test_lv
mkdir /test
mount /dev/test_vg/test_lv  /test
EOF


  tags = {
    Name = "test1-ec2"
  }
}

resource "aws_instance" "test2_ec2" {
  ami           = "ami-076e3a557efe1aa9c" # ap-south1
  subnet_id     = aws_subnet.test_subnet_pub2.id
  instance_type = "t2.micro"
  security_groups = [aws_security_group.test_sg.id]
  key_name = "su"
  provisioner "file" {
    source      = "su.pem"
    destination = "/home/ec2-user/.ssh/id_rsa"


    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("${path.module}/su.pem")
      host        = aws_instance.test2_ec2.public_ip
    }
  }
      user_data = <<EOF
#!/bin/bash
chmod 600 /home/ec2-user/.ssh/id_rsa
EOF

  tags = {
    Name = "test2-ec2"
  }

}

####################Application Load Balancer #########################

resource "aws_lb_target_group" "test-target-group" {
  health_check {
    interval            = 10
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  name        = "test-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.test_vpc.id
}


resource "aws_lb_target_group_attachment" "test-alb-target-group-attachment1" {
  target_group_arn = "${aws_lb_target_group.test-target-group.arn}"
  target_id        = aws_instance.test_ec2.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "test-alb-target-group-attachment2" {
  target_group_arn = "${aws_lb_target_group.test-target-group.arn}"
  target_id        = aws_instance.test1_ec2.id
  port             = 80
}


resource "aws_lb" "test-aws-alb" {
  name     = "test-test-alb"
  internal = false

  security_groups = [aws_security_group.test_sg1.id]

  subnets = [aws_subnet.test_subnet_pub1.id, aws_subnet.test_subnet_pub2.id]

  tags = {
    Name = "test-alb"
  }

  ip_address_type    = "ipv4"
  load_balancer_type = "application"
}


resource "aws_lb_listener" "test-alb-listner" {
  load_balancer_arn = "${aws_lb.test-aws-alb.arn}"
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.test-target-group.arn}"
  }
}
