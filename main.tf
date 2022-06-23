terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}
# Configure the AWS Provider #

provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region     = "${var.region}"
}

# Create VPC #

resource "aws_vpc" "MFP_VPC" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Demo_VPC"
  }

}

# Create Internet Gateway [IGW] #

resource "aws_internet_gateway" "Internet_Gateway" {
  vpc_id = aws_vpc.MFP_VPC.id

  tags = {
    Name = "IGW_Assignment_VPC"
  }
}

# Create Public Subnet #

resource "aws_subnet" "Public_Subnet_Web1" {
  vpc_id     = aws_vpc.MFP_VPC.id
  cidr_block = "10.0.0.16/28"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "Public_Subnet_Web1"
  }
}

resource "aws_subnet" "Public_Subnet_Web2" {
  vpc_id     = aws_vpc.MFP_VPC.id
  cidr_block = "10.0.0.32/28"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "Public_Subnet_Web2"
  }
}

# Create EIP

resource "aws_eip" "nat_gateway1" {
  vpc = true
}

# Create NAT Gateway #

resource "aws_nat_gateway" "Nat_Gateway1" {
#  connectivity_type = "private"
  allocation_id     = aws_eip.nat_gateway1.id
  subnet_id         = aws_subnet.Public_Subnet_Web1.id  ##changed

  tags = {
    Name = "NAT_Gateway1_Assignment_VPC"
  }

}

output "nat_gateway_ip1" {
  value = aws_eip.nat_gateway1.public_ip
}


# Create Security Group for Public Web Subnet #

resource "aws_security_group" "Allow_Web_Traffic" {
  name        = "allow_web_ssh_traffic"
  description = "Allow inbound 22,80,443"
  vpc_id      = aws_vpc.MFP_VPC.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
#   ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
#   ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
#   ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
#   ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Allow_Web_SSH_Access"
  }
}

# Route Table Routes #

resource "aws_route_table" "Route_Table" {

  vpc_id = aws_vpc.MFP_VPC.id

  tags = {
      Name = "Public-RT"
  }
}

resource "aws_route" "public" {
  
  route_table_id = aws_route_table.Route_Table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.Internet_Gateway.id
}

resource "aws_route_table_association" "public1" {
  route_table_id = aws_route_table.Route_Table.id
  subnet_id = aws_subnet.Public_Subnet_Web1.id
}

resource "aws_route_table_association" "public2" {
  subnet_id = aws_subnet.Public_Subnet_Web2.id
  route_table_id = aws_route_table.Route_Table.id
}

######################################################
## Create Bastion Host to access App servers with SSH
######################################################

## Create Security Group for Bastion host

resource "aws_security_group" "sg-bastion" {
  name   = "bastion-security-group"
  vpc_id = aws_vpc.MFP_VPC.id

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = -1
    from_port   = 0 
    to_port     = 0 
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "bastion-host" {
  ami                         = "ami-0e8e39877665a7c92"
  key_name                    = "bootcamp"
  instance_type               = "t2.micro"
  subnet_id = aws_subnet.Public_Subnet_Web2.id
  vpc_security_group_ids            = [aws_security_group.sg-bastion.id]
  associate_public_ip_address = true
}

##############  Application Tier ############

# Create Private Subnet #

resource "aws_subnet" "Private_Subnet_App1" {
  vpc_id     = aws_vpc.MFP_VPC.id
  cidr_block = "10.0.0.48/28"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = "false"

  tags = {
    Name = "Private_Subnet_App1"
  }
}

resource "aws_subnet" "Private_Subnet_App2" {
  vpc_id     = aws_vpc.MFP_VPC.id
  cidr_block = "10.0.0.64/28"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = "false"

  tags = {
    Name = "Private_Subnet_App2"
  }
}

# Create Security Group for Private APP subnet #

resource "aws_security_group" "Allow_APP_Traffic" {
  name        = "allow_APP_web_ssh_traffic"
  description = "Allow inbound 22,80,443"
  vpc_id      = aws_vpc.MFP_VPC.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
#   ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
#   ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    security_groups = ["${aws_security_group.sg-bastion.name}"]
    #cidr_blocks      = ["0.0.0.0/0"]
  #   ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
#   ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Allow_APP_Web_SSH_Access"
  }
}

## Create Route Table for Private Subnet

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.MFP_VPC.id
  
  tags = {
      Name = "Private-RT"
  }
}

resource "aws_route" "private1" {
  
  route_table_id = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.Nat_Gateway1.id
}

## Route Table Association for Private subnet

resource "aws_route_table_association" "private1" {
  route_table_id = aws_route_table.private.id
  subnet_id = aws_subnet.Private_Subnet_App1.id
}

resource "aws_route_table_association" "private2" {
  route_table_id = aws_route_table.private.id
  subnet_id = aws_subnet.Private_Subnet_App2.id
}


############# Database Tier ####################

## Create Database Subnets #

resource "aws_subnet" "Private_Subnet_DB2" {
  vpc_id     = aws_vpc.MFP_VPC.id
  cidr_block = "10.0.0.80/28"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = "false"

  tags = {
    Name = "Private_Subnet_DB2"
  }
}

resource "aws_subnet" "Private_Subnet_DB1" {
  vpc_id     = aws_vpc.MFP_VPC.id
  cidr_block = "10.0.0.96/28"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = "false"

  tags = {
    Name = "Private_Subnet_DB1"
  }
}

## Create Subnet Group

resource "aws_db_subnet_group" "db-subnet" {
  name = "db subnet group"
  subnet_ids = ["${aws_subnet.Private_Subnet_DB1.id}", "${aws_subnet.Private_Subnet_DB2.id}"]
}

# Create Security Group for Private RDS Subnet #

resource "aws_security_group" "Allow_DB_Traffic" {
  name        = "allow_DB_ssh_traffic"
  description = "Allow inbound 3306"
  vpc_id      = aws_vpc.MFP_VPC.id

  ingress {
    description      = "MYSQL"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["10.0.0.80/28", "10.0.0.96/28"]
#   ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
#   ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Allow_RDS_Access"
  }
}

## Create MySQL DB Instance 

resource "aws_db_instance" "RDS-Test" {
  allocated_storage    =  20
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "mydb"
  username             = "admin"
  password             = "password123"
  skip_final_snapshot  = true
  vpc_security_group_ids   =  [aws_security_group.Allow_DB_Traffic.id]
  parameter_group_name = "default.mysql5.7"
  db_subnet_group_name = aws_db_subnet_group.db-subnet.name
  multi_az             = false
}

# Create Application Load Balancer #

# Create Security Group for Public ALB Subnet #

resource "aws_security_group" "Allow_ELB_Web_Traffic" {
  name        = "allow_ELB_web_traffic"
  description = "Allow inbound 80,443"
  vpc_id      = aws_vpc.MFP_VPC.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
#   ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
#   ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
#   ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Allow_ELB_WEB_Access"
  }
}

# Create ALB #

resource "aws_lb" "WEB_ALB" {
  name               = "WEB-ALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.Allow_ELB_Web_Traffic.id]
  subnets            = [aws_subnet.Public_Subnet_Web2.id, aws_subnet.Public_Subnet_Web1.id]         # aws_subnet.public.*.id

  enable_deletion_protection = false
	
  tags = {
    Name = "WEB_Load_Balancer"
  }
}

# Create Target Group #

resource "aws_lb_target_group" "ELB_Target_Group1" {
  name     = "ELB-Target-Group1"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.MFP_VPC.id
  
# Alter the destination of the health check to be the login page.
  
  health_check {
    path = "/index.html"
    port = 80
    healthy_threshold   = 3
    unhealthy_threshold = 5
    timeout             = 10
#   target              = "HTTP:8000/"
    interval            = 30
    protocol            = "HTTP"

  }
}

# Create Listeners HTTP/HTTPS#

resource "aws_lb_listener" "WEB_ELB_Listener_HTTP" {
  load_balancer_arn = aws_lb.WEB_ALB.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ELB_Target_Group1.arn
  }
}
# Create Internal Application Load Balancer #

# Create Security Group for Private ALB Subnet #

resource "aws_security_group" "Allow_ELB_App_Traffic" {
  name        = "allow_ELB_App_traffic"
  description = "Allow inbound 80,443"
  vpc_id      = aws_vpc.MFP_VPC.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
#   ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
#   ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
#   ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Allow_ELB_WEB_Access"
  }
}

# Create ALB #

resource "aws_lb" "APP_ALB" {
  name               = "APP-ALB"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.Allow_ELB_App_Traffic.id]
  subnets            = [aws_subnet.Private_Subnet_App1.id, aws_subnet.Private_Subnet_App2.id]

  enable_deletion_protection = false

  tags = {
    Name = "APP_Load_Balancer"
  }
}

# Create Target Group #

resource "aws_lb_target_group" "ELB_Target_Group2" {
  name     = "ELB-Target-Group2"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.MFP_VPC.id
  
# Alter the destination of the health check to be the login page.
  
  health_check {
    path = "/index.html"
    port = 80
    healthy_threshold   = 3
    unhealthy_threshold = 5
    timeout             = 10
#   target              = "HTTP:8000/"
    interval            = 30
    protocol            = "HTTP"

  }
}

# Create Listeners HTTP/HTTPS#

resource "aws_lb_listener" "APP_ELB_Listener_HTTP" {
  load_balancer_arn = aws_lb.APP_ALB.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ELB_Target_Group2.arn
  }
}

####################################################
## Autosclaing for WEB Tier
#####################################################

# Create Launch Configuration #

resource "aws_launch_configuration" "web_launch_config" {
  name_prefix                 = "WEB-Autoscaling"
  image_id                    = "ami-0e8e39877665a7c92" #Amazon Linux 2 AMI
  instance_type               = "t2.micro"
  key_name                    = "bootcamp"
  associate_public_ip_address = true
  security_groups             = [aws_security_group.Allow_Web_Traffic.id]
  lifecycle {
    create_before_destroy = true
  }
}

# Create Auto Scaling Group #

resource "aws_autoscaling_group" "autoscaling_group" {
  launch_configuration = "${aws_launch_configuration.web_launch_config.id}"
  min_size             = "2"
  max_size             = "3"
  target_group_arns    = [aws_lb_target_group.ELB_Target_Group1.arn]
  vpc_zone_identifier  = [aws_subnet.Public_Subnet_Web2.id, aws_subnet.Public_Subnet_Web1.id]

  tag {
    key                 = "Name"
    value               = "WEB-Server"
    propagate_at_launch = true
  }
}

####################################################
## Autosclaing for APP Tier
#####################################################

# Create Launch Configuration #

resource "aws_launch_configuration" "app_launch_config" {
  name_prefix                 = "APP-Autoscaling"
  image_id                    = "ami-0e8e39877665a7c92" #Amazon Linux 2 AMI
  instance_type               = "t2.micro"
  key_name                    = "bootcamp"
  associate_public_ip_address = false
  security_groups             = [aws_security_group.Allow_APP_Traffic.id]
  lifecycle {
    create_before_destroy = true
  }
}

# Create Auto Scaling Group #

resource "aws_autoscaling_group" "app_autoscaling_group" {
  launch_configuration = "${aws_launch_configuration.app_launch_config.id}"
  min_size             = "2"
  max_size             = "3"
  target_group_arns    = [aws_lb_target_group.ELB_Target_Group2.arn]
  vpc_zone_identifier  = [aws_subnet.Private_Subnet_App1.id, aws_subnet.Private_Subnet_App2.id]

  tag {
    key                 = "Name"
    value               = "APP-Server"
    propagate_at_launch = true
  }
}
