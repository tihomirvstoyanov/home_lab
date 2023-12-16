terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

### DEFINE VARIABLES:
variable "pc_ip_addr" {
  description = "IP address of the local PC"
}
variable "pub_key" {
  description = "SHA of your public key"
}
variable "rds_password" {
  description = "RDS password to connect to the DB"
}

### Create VPC
resource "aws_vpc" "customer_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "customer-vpc"
  }
}

### Create Internet Gateway
resource "aws_internet_gateway" "customer_igw" {
  vpc_id = aws_vpc.customer_vpc.id

  tags = {
    Name = "customer_igw"
  }
}

### Create public subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.customer_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "public_subnet_1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.customer_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "public_subnet_2"
  }
}

### Create private subnets
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.customer_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private_subnet_1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.customer_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private_subnet_2"
  }
}

### Create Elastic IP for NAT Gateway
resource "aws_eip" "nat_gateway_eip" {
  tags = {
    Name = "nat_gateway_eip"
  }
}

### Create NAT GW
resource "aws_nat_gateway" "customer_nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
}

### Route Table for public subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.customer_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.customer_igw.id
  }

  tags = {
    Name = "public_route_table"
  }
}

### Route Table for private subnets
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.customer_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.customer_nat_gateway.id
  }

  tags = {
    Name = "private_route_table"
  }
}

### Associate Route Table with Public Subnets
resource "aws_route_table_association" "public_subnet_association_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_association_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

### Associate Route Table with Private Subnets
resource "aws_route_table_association" "private_subnet_association_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_subnet_association_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}

### Bastion EC2 Host Security Group
resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.customer_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.pc_ip_addr] # REFERENCING VARIABLE
  }

  tags = {
    Name = "bastion_sg"
  }
}

### EC2 Web-App SG
resource "aws_security_group" "web_app_ec2_sg" {
  vpc_id = aws_vpc.customer_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web_app_ec2_sg"
  }
}

### EFS Security Group
resource "aws_security_group" "sg-web-app-efs" {
  vpc_id = aws_vpc.customer_vpc.id

  egress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-web-app-efs"
  }
}

### RDS Security Group
resource "aws_security_group" "rds-web-app-sg" {
  vpc_id = aws_vpc.customer_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_app_ec2_sg.id]
  }

  tags = {
    Name = "rds-web-app-sg"
  }
}

### Key Pair
resource "aws_key_pair" "ssh_key_pair" {
  key_name   = "ssh_key_pair"
  public_key = var.pub_key # REFERENCING VARIABLE
}

### EC2 BASTION HOST
resource "aws_instance" "bastion_host" {
  ami                         = "ami-02aead0a55359d6ec"
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.ssh_key_pair.key_name
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  subnet_id                   = aws_subnet.public_subnet_1.id
  associate_public_ip_address = true

  tags = {
    Name = "bastion_host"
  }
}

### EC2 Web-App Instance #1
resource "aws_instance" "web-app-server-1" {
  ami                    = "ami-02aead0a55359d6ec"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ssh_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.web_app_ec2_sg.id]
  subnet_id              = aws_subnet.private_subnet_1.id

  user_data = <<-EOF
              #!/bin/bash
              sudo su
              yum install httpd -y
              systemctl enable httpd
              systemctl start httpd
              touch /var/www/html/index.html
              echo 'Client APP ver 0.01' > /var/www/html/index.html
              mkdir ~/efs-mount-point
              mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${aws_efs_file_system.web-app-efs.dns_name}:/ ~/efs-mount-point/
              yum install mariadb -y
              EOF

  tags = {
    Name = "web-app-server-1"
  }
}

### EC2 Web-App Instance #2
resource "aws_instance" "web-app-server-2" {
  ami                    = "ami-02aead0a55359d6ec"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.ssh_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.web_app_ec2_sg.id]
  subnet_id              = aws_subnet.private_subnet_2.id

  user_data = <<-EOF
              #!/bin/bash
              sudo su
              yum install httpd -y
              systemctl enable httpd
              systemctl start httpd
              touch /var/www/html/index.html
              echo 'Client APP ver 0.01' > /var/www/html/index.html
              mkdir ~/efs-mount-point
              mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${aws_efs_file_system.web-app-efs.dns_name}:/ ~/efs-mount-point/
              yum install mariadb -y
              EOF

  tags = {
    Name = "web-app-server-2"
  }
}

### EFS File System
resource "aws_efs_file_system" "web-app-efs" {
  creation_token = "web-app-efs"
  encrypted      = true

  tags = {
    Name = "web-app-efs"
  }
}

### Mount Target for EFS
resource "aws_efs_mount_target" "web-app-efs_mount_target-private_subnet_1" {
  file_system_id  = aws_efs_file_system.web-app-efs.id
  subnet_id       = aws_subnet.private_subnet_1.id
  security_groups = [aws_security_group.sg-web-app-efs.id]
}
resource "aws_efs_mount_target" "web-app-efs_mount_target-private_subnet_2" {
  file_system_id  = aws_efs_file_system.web-app-efs.id
  subnet_id       = aws_subnet.private_subnet_2.id
  security_groups = [aws_security_group.sg-web-app-efs.id]
}

### RDS Instance
resource "aws_db_instance" "web-app-database" {
  identifier             = "web-app-database"
  engine                 = "mysql"
  instance_class         = "db.t2.micro"
  allocated_storage      = 10
  storage_type           = "gp2"
  username               = "admin"
  password               = var.rds_password # REFERENCING VARIABLE
  db_subnet_group_name   = aws_db_subnet_group.web-app-database-subnet-group.name
  vpc_security_group_ids = [aws_security_group.rds-web-app-sg.id]

  tags = {
    Name = "web-app-database"
  }
}

### DB Subnet Group
resource "aws_db_subnet_group" "web-app-database-subnet-group" {
  name       = "web-app-database-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
}

### Application Load Balancer
resource "aws_lb" "web-app-alb" {
  name               = "web-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web-app-alb-sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  enable_deletion_protection = false

  enable_http2 = true

  tags = {
    Name = "web-app-alb"
  }
}

### Security Group for Web-App ALB
resource "aws_security_group" "web-app-alb-sg" {
  vpc_id = aws_vpc.customer_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.pc_ip_addr] # REFERENCING VARIABLE
  }

  tags = {
    Name = "web-app-alb-sg"
  }
}

#### ALB Target Group
resource "aws_lb_target_group" "web-app-alb-target-group" {
  name        = "web-app-alb-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.customer_vpc.id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    path                = "/"
    port                = "80"
    protocol            = "HTTP"
  }

  tags = {
    Name = "web-app-alb-target-group"
  }
}

### Attach TG to EC2 instance
resource "aws_lb_target_group_attachment" "web-app-alb-target-group-attachment-1" {
  target_group_arn = aws_lb_target_group.web-app-alb-target-group.arn
  target_id        = aws_instance.web-app-server-1.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "web-app-alb-target-group-attachment-2" {
  target_group_arn = aws_lb_target_group.web-app-alb-target-group.arn
  target_id        = aws_instance.web-app-server-2.id
  port             = 80
}

### ALB Listener
resource "aws_lb_listener" "web-app-alb-listener" {
  load_balancer_arn = aws_lb.web-app-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.web-app-alb-target-group.arn
    type             = "forward"
  }
}

### Create CloudWatch alarm for high ALB incoming request based on defined threshold 
resource "aws_cloudwatch_metric_alarm" "web-app-alb-request-count-alarm" {
  alarm_name          = "web-app-alb-request-count-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 1000 # Set your desired threshold

  dimensions = {
    LoadBalancer = aws_lb.web-app-alb.id
  }

  alarm_description = "Alarm triggered when the request count exceeds the threshold."
  actions_enabled   = true
}


### Output Variables
output "web-app-alb-dns-name" {
  value = aws_lb.web-app-alb.dns_name
}
output "bastion_host_public_ip" {
  value = aws_instance.bastion_host.public_ip
}
output "web-app-server-1-private-dns" {
  value = aws_instance.web-app-server-1.private_dns
}
output "web-app-server-2-private-dns" {
  value = aws_instance.web-app-server-2.private_dns
}
output "rds-database-endpoint" {
  value = aws_db_instance.web-app-database.endpoint
}
