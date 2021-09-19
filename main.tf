provider "aws" {      # Defining the Provider Amazon  as we need to run this on AWS   
  region = "us-east-1"
}
resource "aws_vpc" "vpc" {
    cidr_block = "10.0.0.0/24"
    enable_dns_support   = true
    enable_dns_hostnames = true
    tags       = {
        Name = "Terraform VPC"
    }
}
resource "aws_internet_gateway" "internet_gateway" {
    vpc_id = aws_vpc.vpc.id
}


resource "aws_subnet" "pub_subnet" {
    vpc_id                  = aws_vpc.vpc.id
    cidr_block              = "10.1.0.0/22"
}
Route Table

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.internet_gateway.id
    }
}

resource "aws_route_table_association" "route_table_association" {
    subnet_id      = aws_subnet.pub_subnet.id
    route_table_id = aws_route_table.public.id
}


resource "aws_security_group" "ec2_sg" {
    vpc_id      = aws_vpc.vpc.id

    ingress {
        from_port       = 22
        to_port         = 22
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }
     ingress {
        from_port       = 80
        to_port         = 80
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    ingress {
        from_port       = 443
        to_port         = 443
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    egress {
        from_port       = 0
        to_port         = 65535
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }
}

resource "aws_lb" "app" {
  name               = "main-app-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.pub_subnet.id
  security_groups    = aws_security_group.id
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_taget_group.arn
  }
}
 resource "aws_lb_target_group" "my-target-group" {
  health_check {
    interval            = 10
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  name        = "my-test-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = "${var.vpc_id}"
}
resource "aws_lb_target_group_attachment" "my-alb-target-group-attachment1" {
  target_group_arn = "${aws_lb_target_group.my-target-group.arn}"
  target_id        = "${aws_instance.ec2_instance.id}"
  port             = 80
}
resource "aws_key_pair" "deployer" {     # Creating the Key pair on AWS 
  key_name   = "deployer-key"
  public_key = "${file("~/.ssh/id_rsa.pub")}" # Generated private and public key on local machine
}

resource "aws_eip" "lb" {
  instance = aws_instance.web.id
  vpc      = true
}
resource "aws_instance" "web" {
  count = 1    # Here we are creating identical 4 machines.
  subnet_id = aws_subnet.pub_subnet.id 
  ami = var.ami
  instance_type = var.instance_type
  key_name = aws_key_pair.deployer.key_name

  tags = {
    Name = "my-machine-${count.index}"
         }
   provisioner "remote-exec" {
    inline = ["sudo apt update -y",
              "sudo  install python -y",
              "sudo apt install -y software-properties-common",
              "sudo apt-add-repository --yes --update ppa:ansible/ansible",
               "sudo apt install -y ansible"
              ]
    connection {
      type ="ssh"
      user = "ubuntu"
      host = {self.public.ip}
      private_key = "test.pem"
    
  }
   provisioner "file" {                    # Provisioner 3 [needs SSH/Winrm connection]
    source      = "*.yml"
    destination = "/tmp/app.yml"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = self.public_ip
      private_key = "${file("~/.ssh/id_rsa")}"
      agent       = false
      timeout     = "30s"
    }
    provisioner "remote-exec" {
    inline = ["sudo ansible-playbook -u ubuntu --key-file ansible-key.pem -T 300 -i '${self.public_ip}'  /tmp/app.yml " ] 
    connection {
      type ="ssh"
      user = "ubuntu"
      host = {self.public.ip}
      private_key = "test.pem"
    
  }
  }  
}

output "ansible_command" {
value = "ansible-playbook -u ubuntu --key-file ansible-key.pem -T 300 -i '${aws_instance.ansible_server.public_ip},', app.yml"
}