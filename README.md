
# 
Automating EC2-Type Deployments with Terraform 



# create virtal private cloud 
#Creating ECR registry for storing the docker image.

#Creating Dockerfile and building the image.

#Creating terraform code for IAM role

#Creating Route 53 hosted zone

#Creating cloudwatch log group

#Creating ELB for EC2


Create Virtual private cloud:
```
provider "aws" {}

resource "aws_vpc" "vpc" {
    cidr_block = "10.0.0.0/24"
    enable_dns_support   = true
    enable_dns_hostnames = true
    tags       = {
        Name = "Terraform VPC"
    }
}
```
Internet gateway
```
resource "aws_internet_gateway" "internet_gateway" {
    vpc_id = aws_vpc.vpc.id
}
```

Subnet
Within the VPC let’s add a public subnet:
```
resource "aws_subnet" "pub_subnet" {
    vpc_id                  = aws_vpc.vpc.id
    cidr_block              = "10.1.0.0/22"
}
```
Route Table
```
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
```

Security Groups

Security groups works like a firewalls for the instances (where ACL works like a global firewall for the VPC). Because we allow all the traffic from the internet to and from the VPC we might set some rules to secure the instances themselves.
```
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

```
Create ECR Registry:-

```python
 resource "aws_ecr_repository" "ecr" {
  name = "ecr-repo-name"
  tags = {
   name = ecr-image
}

output "repo-url" {
 value = "${aws_ecr_repository.ecr.repository_url}"
```

Creaet docker file 
```
FROM tiangolo/uwsgi-nginx-flask:python3.8
RUN pip install boto3 

COPY ./app /app
```
Create an app directory and enter in it

Create a main.py file (it should be named like that and should be in your app directory) with:

```
from flask import Flask
import boto3


app = Flask(__name__)

@app.route("/")
def hello():
    client = boto3.client(
    's3',
    aws_access_key_id=ACCESS_KEY,
    aws_secret_access_key=SECRET_KEY,
    aws_session_token=SESSION_TOKEN
     )
    return response = client.list_buckets()
    


if __name__ == "__main__":
    # Only for debugging while developing
    app.run(host='0.0.0.0', debug=True, port=80)
````
#######################warning####################################
Warning

ACCESS_KEY, SECRET_KEY, and SESSION_TOKEN are variables that contain your access key, secret key, and optional session token. Note that the examples above do not have hard coded credentials. We do not recommend hard coding credentials in your source code.
#####################################################################

Go to the project directory (in where your Dockerfile is, containing your app directory)
Build your Flask image:
```
docker build -t myimage .
Run a container based on your image:
 #docker push to ECR
docker tag e9ae3c220b23 aws_account_id.dkr.ecr.region.amazonaws.com/my-repository:tag
```


Create ELB

```
resource "aws_lb" "app" {
  name               = "main-app-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = $aws_subnet.pub_subnet.id
  security_groups    = $aws_security_group" "ec2_sg
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
```
  EC2-instance.tf �
  ```python
  ###########################################################
# AWS ECS-EC2
###########################################################
resource "aws_instance" "my-machine" {
  count = 2    # Here we are creating identical 4 machines.
  
  ami = var.ami
  instance_type = var.instance_type
  key_name = aws_key_pair.deployer.key_name
  tags = {
    Name = "my-machine-${count.index}"
         }
 provisioner  "remote-exec" {            # Provisioner 2 [needs SSH/Winrm connection]
      connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${file("~/.ssh/id_rsa")}"
      agent       = false
      host        = aws_instance.my-machine.public_ip       # Using my instance to connect
      timeout     = "30s"
    }
      inline = [
        "sudo apt install -y python",
        "sudo apt install ansible -y",
        
      ]
  }
   provisioner "file" {                    # Provisioner 3 [needs SSH/Winrm connection]
    source      = "*.yml"
    destination = "/tmp/file.json"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = aws_instance.my-machine.public_ip
      private_key = "${file("~/.ssh/id_rsa")}"
      agent       = false
      timeout     = "30s"
    }
  }  
}
```


ECS-cloudwatch.tf👎
```
resource "aws_cloudwatch_log_group" "log_group" {
  name = "openapi-devl-cw"
    tags = {
    Environment = "production"
  }
}
```
ECS-Route53.tf👎

```
###############################################################
# AWS ECS-ROUTE53
###############################################################
resource "aws_route53_zone" "r53_private_zone" {
  name         = "vpn-devl.us.e10.c01.example.com."
  private_zone = false
}

resource "aws_route53_record" "dns" {
  zone_id = "${aws_route53_zone.r53_private_zone.zone_id}"
  name    = "openapi-editor-devl"
  type    = "A"

  alias {
    evaluate_target_health = false
    name                   = "${aws_lb.loadbalancer.dns_name}"
    zone_id                = "${aws_lb.loadbalancer.zone_id}"
  }
}
```
Running the Terraform script
Go to the project folder and type “terraform plan” , this command will show youwhat you will be creating in the AWS.

Then you can validate the terraform code with “terraform validate”

Finally, deploy the resource with “terraform apply”

And thats it! After our resources are provisioned, we can visit our EC2 Dashboard, find our Load Balancer URL and visit the site running on our newly deployed ECS cluster












  
  
