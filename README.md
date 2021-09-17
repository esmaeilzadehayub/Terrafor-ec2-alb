
# Terrafor-ecs-aws
Automating ECS-EC2-Type Deployments with Terraform 



![image](https://user-images.githubusercontent.com/28998255/133679876-b7fd2d14-21c2-4b2d-9f6f-0545e6e0783d.png)

AWS Elastic Container Service (ECS)

ECS is Amazon’s Elastic Container Service. That’s greek for how you get docker containers running in the cloud. It’s sort of like Kubernetes
Amazon Elastic Container Service (Amazon ECS) is a scalable, high-performance container orchestration service that supports Docker containers and allows you to easily run and scale containerized applications on AWS. ECS eliminates the need for you to install and operate your own container orchestration software, manage and scale a cluster of virtual machines, or schedule containers on those virtual machines
On this page:-

#Creating ECR registry for storing the docker image.

#Creating Dockerfile and building the image.

#Creating terraform code for IAM role

#Creating tf file for ECS-EC2-instance

#Creating ECS Task Definition

#Creating ECS Service

#Creating Application Load Balancer

#Creating Route 53 hosted zone

#Creating cloudwatch log group

#Creating terraform code for IAM role

Cre
ECR Registry:-

```python
 resource "aws_ecr_repository" "ecr" {
  name = "ecr-repo-name"
  tags = {
   name = ecr-image
}

output "repo-url" {
 value = "${aws_ecr_repository.ecr.repository_url}"
```

Creating an IAM role and assigning Policy:-
Roles are a really brilliant part of the aws stack. Inside of IAM or identity access and management, you can create roles. These are collections of privileges. I’m allowed to use this S3 bucket, but not others. I can use EC2, but not Athena. And so forth. There are some special policies already created just for ECS and you’ll need roles to use them.
These roles will be applied at the instance level, so your ecs host doesn’t have to pass credentials around

ecs-instance-role

ecs-service-role

ecs-instance-profile


```python
resource "aws_iam_role" "ecs-instance-role" {
  name = "ecs-instance-role"
  path = "/"
  assume_role_policy = "${data.aws_iam_policy_document.ecs-instance-policy.json}"
}



data "aws_iam_policy_document" "ecs-instance-policy" {
   statement {
  actions = ["sts:AssumeRole"]
  principals {
  type = "Service"
  identifiers = ["ec2.amazonaws.com"]
  }
 }
}

resource "aws_iam_role_policy_attachment" "ecs-instance-role-attachment" {
   role = "${aws_iam_role.ecs-instance-role.name}"
   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs-instance-profile" {
  name = "ecs-instance-profile"
  path = "/"
  role = "${aws_iam_role.ecs-instance-role.id}"
  provisioner "local-exec" {
  command = "sleep 60"
 }
}

resource "aws_iam_role" "ecs-service-role" {
  name = "ecs-service-role"
  path = "/"
  assume_role_policy = "${data.aws_iam_policy_document.ecs-service-policy.json}"
}

resource "aws_iam_role_policy_attachment" "ecs-service-role-attachment" {
  role = "${aws_iam_role.ecs-service-role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

data "aws_iam_policy_document" "ecs-service-policy" {
  statement {
  actions = ["sts:AssumeRole"]
  principals {
  type = "Service"
  identifiers = ["ecs.amazonaws.com"]
  }
 }
}
```

Elastic container service (ECS-EC2-Type):-
Here we are going to create the ECS cluster with launch type as EC2-TYPE. This involves the following resource.
ECS-Cluster.tf

ECS-ec2-instance.tf

ECS-task-defination.tf

ECS-services.tf

ECS-ALB.tf

ECS-cloudwatch.tf

ECS-Route53.tf

ECS-Cluster.tf:-

```pyhton
##########################################################
# AWS ECS-CLUSTER
#########################################################

resource "aws_ecs_cluster" "cluster" {
  name = "ecs-devl-cluster"
  tags = {
   name = ecs-cluster-name
   }
   
  }
  ```
  ECS-ec2-instance.tf �
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
  user_data              = "${data.template_file.user_data.rendered}"
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
ECS-task-defination.tf👎

```
############################################################
# AWS ECS-TASK
############################################################

resource "aws_ecs_task_definition" "task_definition" {
  container_definitions    = "${data.template_file.task_definition_json.rendered}"                                         # task defination json file location
  execution_role_arn       = "EcsTaskExecutionRole" #CHANGE THIS                                                                      # role for executing task
  family                   = "openapi-task-defination"                                                                      # task name
  network_mode             = "awsvpc"                                                                                      # network mode awsvpc, brigde
  memory                   = "2048"
  cpu                      = "1024"
  requires_compatibilities = ["EC2"]                                                                                       # Fargate or EC2
  task_role_arn            = "EcsTaskExecutionRole"  #CHANGE THIS                                                                     # TASK running role
} 

data "template_file" "task_definition_json" {
  template = "${file("${path.module}/task_definition.json")}"
}
```
task_definition_json👎
```
[
  {
      "name": "openapi-ecs-container",
     "image": "XXXaccount_idxx.dkr.ecr.eu-west-1.amazonaws.com/swagger:ui", # ecs registry image url
      "cpu": 10,
      "memory": 512,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "openapi-devl-cw",
          "awslogs-region": "eu-west-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "links": [],
      "portMappings": [
          { 
              "hostPort": 8080,
              "containerPort": 8080,
              "protocol": "tcp"
          }
      ],
      "essential": true,
      "entryPoint": [],
      "command": [],
      "environment": [],
      "mountPoints": [],
      "volumesFrom": []
  }
]
```

ECS-services.tf �
```
##############################################################
# AWS ECS-SERVICE
##############################################################

resource "aws_ecs_service" "service" {
  cluster                = "${aws_ecs_cluster.cluster.id}"                                 # ecs cluster id
  desired_count          = 1                                                         # no of task running
  launch_type            = "EC2"                                                     # Cluster type ECS OR FARGATE
  name                   = "openapi-service"                                         # Name of service
  task_definition        = "${aws_ecs_task_definition.task_definition.arn}"        # Attaching Task to service
  load_balancer {
    container_name       = "openapi-ecs-container"                                  #"container_${var.component}_${var.environment}"
    container_port       = "8080"
    target_group_arn     = "${aws_lb_target_group.lb_target_group.arn}"         # attaching load_balancer target group to ecs
 }
  network_configuration {
    security_groups       = ["sg-01849003c4f9203ca"] #CHANGE THIS
    subnets               = ["${var.subnet1}", "${var.subnet2}"]  ## Enter the private subnet id
    assign_public_ip      = "false"
  }
  depends_on              = ["aws_lb_listener.lb_listener"]
}
```
ECS-ALB.tf�
```####################################################################
# AWS ECS-ALB
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












  
  
