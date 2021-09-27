
# 
Automating EC2-Type Deployments with Terraform 


**Create virtal private cloud**
**Creating ECR registry for storing the docker image**

**Creating Dockerfile and building the image**

**Creating terraform code for IAM role**

**Creating tf file for EC2-instance**

**Creating Application Load Balancer**

**Creating Route 53 hosted zone**

**Creating cloudwatch log group**

**Creating terraform code for IAM role**

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
**Internet gateway**
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
resource "aws_security_group" "ecs_sg" {
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

Creating an IAM role and assigning Policy:-
Roles are a really brilliant part of the aws stack. Inside of IAM or identity access and management, you can create roles. These are collections of privileges. I’m allowed to use this S3 bucket, but not others. I can use EC2, but not Athena. And so forth. There are some special policies already created just for ECS and you’ll need roles to use them.
These roles will be applied at the instance level, so your ecs host doesn’t have to pass credentials around

```python
resource "aws_iam_role" "test_role" {
  name = "test_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
      tag-key = "tag-value"
  }
}
resource "aws_iam_instance_profile" "test_profile" {
  name = "test_profile"
  role = "${aws_iam_role.test_role.name}"
}
resource "aws_iam_role_policy" "test_policy" {
  name = "test_policy"
  role = "${aws_iam_role.test_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}
resource "aws_instance" "role-test" {
  ami = "ami-0bbe6b35405ecebdb"
  instance_type = "t2.micro"
  iam_instance_profile = "${aws_iam_instance_profile.test_profile.name}"
  key_name = "mytestpubkey"
}



```

**EC2-instance.tf**

  ```python
  ###########################################################
# AWS ECS-EC2
###########################################################
resource "aws_instance" "ec2_instance" {
  ami                    = "ami-08935252a36e25f85"
  subnet_id              =  "subnet-087e48d4db31e442d" #CHANGE THIS
  instance_type          = "t2.medium"
  iam_instance_profile   = "ecsInstanceRole" #CHANGE THIS
  vpc_security_group_ids = ["sg-01849003c4f9203ca"] #CHANGE THIS
  key_name               = "pnl-test" #CHANGE THIS
  ebs_optimized          = "false"
  source_dest_check      = "false"
  root_block_device = {
    volume_type           = "gp2"
    volume_size           = "30"
    delete_on_termination = "true"
  }

  tags {
    Name                   = "openapi-ecs-ec2_instance"
}

  lifecycle {
    ignore_changes         = ["ami", "user_data", "subnet_id", "key_name", "ebs_optimized", "private_ip"]
  }
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
  

  
   provisioner "local-exec" {
	command = "ansible-playbook -u ubuntu --key-file ansible-key.pem -T 300 -i '${self.public_ip},', app.yml"  }
 
```
EC2ALB.tf�
```####################################################################
# AWS-ALB
#####################################################################

resource "aws_lb" "loadbalancer" {
  internal            = "${var.internal}"  # internal = true else false
  name                = "openapi-alb-name"
  subnets             = ["${var.subnet1}", "${var.subnet2}"] # enter the private subnet 
  security_groups     = ["sg-01849003c4f9203ca"] #CHANGE THIS
}


resource "aws_lb_target_group" "lb_target_group" {
  name        = "openapi-target-alb-name"
  port        = "80"
  protocol    = "HTTP"
  vpc_id      = "vpc-000851116d62e0c13" # CHNAGE THIS
  target_type = "ip"


#STEP 1 - ECS task Running
  health_check {
    healthy_threshold   = "3"
    interval            = "10"
    port                = "8080"
    path                = "/index.html"
    protocol            = "HTTP"
    unhealthy_threshold = "3"
  }
}

resource "aws_lb_listener" "lb_listener" {
  "default_action" {
    target_group_arn = "${aws_lb_target_group.lb_target_group.id}"
    type             = "forward"
  }

  #certificate_arn   = "arn:aws:acm:us-east-1:689019322137:certificate/9fcdad0a-7350-476c-b7bd-3a530cf03090"
  load_balancer_arn = "${aws_lb.loadbalancer.arn}"
  port              = "80"
  protocol          = "HTTP"
}
```
```
**Route53.tf**

```
###############################################################
# AWS ROUTE53
###############################################################
```
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

Finally, deploy the resource with terraform apply

#############################################

**A summary of the potential improvements to the application**

###############################################


1. We can use S3 bucker for saving application file  to download it from S3(data has to be encrypt by EKS) to move to EC2
2. To scale up services we can use autoscaling services on AWS.
3. To maintain *.tfstae for terraform we should create a s3 buackt to save all Terraform's state  by cloud solution .
4. We can desgin your service with EKS/ECS services on AWS
