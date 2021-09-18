
# 
Automating EC2-Type Deployments with Terraform 



# create virtal private cloud 
#Creating ECR registry for storing the docker image.

#Creating Dockerfile and building the image.

#Creating terraform code for IAM role

#Creating Route 53 hosted zone

#Creating cloudwatch log group

#Creating terraform code for IAM role

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


  EC2-instance.tf �
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
    inline = ["sudo apt-get -qq install python -y"]
  }
  

  
   provisioner "local-exec" {
	command = <<EOT
    sleep 30;
	  >java.ini;
	  echo "[java]" | tee -a java.ini;
	  echo "${aws_instance.ec2_instance.public_ip} ec2_user=${var.ec2_user} ec2_ssh_private_key_file=${var.private_key}" | tee -a java.ini;
    export ANSIBLE_HOST_KEY_CHECKING=False;
	  ansible-playbook -u ${var.ec2_user} --private-key ${var.private_key} -i java.ini install_java.yaml
    EOT
  }
  
    connection {
    private_key = "${file(var.private_key)}"
    user        = "ubuntu"
  }

data "template_file" "user_data" {
  template = "${file("${path.module}/user_data.tpl")}"
}
```
  user_data.tpl
  ```
  #!/bin/bash

# Update all packages

sudo yum update -y
sudo yum install -y ecs-init
sudo service docker start
sudo start ecs

#Adding cluster name in ecs config
echo ECS_CLUSTER=openapi-devl-cluster >> /etc/ecs/ecs.config
cat /etc/ecs/ecs.config | grep "ECS_CLUSTER"
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












  
  
