# Creating Application Load Balancer using Terraform
[![Builds](https://travis-ci.org/joemccann/dillinger.svg?branch=master)](https://travis-ci.org/joemccann/dillinger)

Terraform is a tool for building infrastructure with various technologies including Amazon AWS, Microsoft Azure, Google Cloud, and vSphere.
Here is a simple document on how to use Terraform to build an AWS ALB Application load balancer.

## Features

- Easy to customise with just a quick look with terrafrom code
- AWS informations are defined using tfvars file and can easily changed
- Project name is appended to the resources that are creating which will make easier to identify the resources.

## Terraform Installation
- Create an IAM user on your AWS console that have access to create the required resources.
- Create a dedicated directory where you can create terraform configuration files.
- Download Terrafom, click here [Terraform](https://www.terraform.io/downloads.html).
- Install Terraform, click here [Terraform installation](https://learn.hashicorp.com/tutorials/terraform/install-cli?in=terraform/aws-get-started)

Use the following command to install Terraform
```sh
wget https://releases.hashicorp.com/terraform/0.15.3/terraform_0.15.3_linux_amd64.zip
unzip terraform_0.15.3_linux_amd64.zip 
ls -l
-rwxr-xr-x 1 root root 79991413 May  6 18:03 terraform  <<=======
-rw-r--r-- 1 root root 32743141 May  6 18:50 terraform_0.15.3_linux_amd64.zip
mv terraform /usr/bin/
which terraform 
/usr/bin/terraform
```
#### Lets create a file for declaring the variables. 
> Note : The terrafom files must be created with .tf extension. 

This is used to declare the variable and pass values to terraform source code.
```sh
vim variable.tf
```
#### Declare the variables for initialising terraform (for terraform provider file )
```sh
variable "region" {}
variable "access_key" {}
variable "secret_key" {}
variable "project" {}
variable "vpc_cidr" {}
```
#### Create the provider file
> Note : Terraform relies on plugins called "providers" to interact with remote systems. Terraform configurations must declare which providers they require, so that Terraform can install and use them. 
I'm using AWS as provider


```sh
vim provider.tf
```
```sh
provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}
```

#### Create a terraform.tfvars
> Note : A terraform.tfvars file is used to set the actual values of the variables.

```sh
vim terraform.tfvars
```
```sh
region = "Desired region"
access_key = "IAM user access_key"
secret_key = "IAM user secret_key"
project = " Your project name"
vpc_cidr = "VPC cidr block"
```
The Basic configuration for terraform aws is completed. Now we need to initialize the terraform using the loaded values

## Creating Application Load Balancer
> A load balancer serves as the single point of contact for clients. The load balancer distributes incoming application traffic across multiple targets, such as EC2 instances, in multiple Availability Zones.

The main components of an Application load balancer are 

- [Listeners](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-listeners.html) : A listener checks for connection requests from clients, using the protocol and port that you configure. The rules that you define for a listener determine how the load balancer routes requests to its registered targets. Each rule consists of a priority, one or more actions, and one or more conditions. When the conditions for a rule are met, then its actions are performed. You must define a default rule for each listener, and you can optionally define additional rules.

- [Traget Group](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html) : Each target group routes requests to one or more registered targets, such as EC2 instances, using the protocol and port number that you specify. You can register a target with multiple target groups. You can configure health checks on a per target group basis. Health checks are performed on all targets registered to a target group that is specified in a listener rule for your load balancer.

The following diagram illustrates the basic components. 

![alt text](https://i.ibb.co/dQ7rc4k/Screenshot-from-2021-05-19-18-59-29.png)

##### Get all subnet of new vpc

```sh
data "aws_subnet_ids" "default" {
  vpc_id = "existing-vpc-id"  <===================== Please note that your existing VPC ID.
  }
```  

##### Create a security group for load balancer 

```sh
resource "aws_security_group" "sg-web" {
  name        = "sgweb"
  description = "Allow 80,443,22"
  
  ingress {
    description      = "HTTPS"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
   cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
   cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
   cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "webserver"
  }
    lifecycle {
    create_before_destroy = true
  }
}
```

#### Create TargetGroup For Application LoadBalancer
> Lets's create 2 target group so that we can forward the traffic 

> Target Group One
```sh
resource "aws_lb_target_group" "tg-one" {
  name     = "lb-tg-one"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id
  load_balancing_algorithm_type = "round_robin"
  deregistration_delay = 60
  stickiness {
    enabled = false
    type    = "lb_cookie"
    cookie_duration = 60
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = 200
    
  }

  lifecycle {
    create_before_destroy = true
  }
}

```

> Target Group Two

```sh
resource "aws_lb_target_group" "tg-two" {
  name     = "lb-tg-two"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id
  load_balancing_algorithm_type = "round_robin"
  deregistration_delay = 60
  stickiness {
    enabled = false
    type    = "lb_cookie"
    cookie_duration = 60
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = 200

  }

  lifecycle {
    create_before_destroy = true
  }
}
```

> _Note : lifecycle is a nested block that can appear within a resource block._ 
> _create_before_destroy is a meta-argument  that will create new replacement object first, and the prior object is destroyed after the replacement is created._

##### Create Application LoadBalancer
```sh
resource "aws_lb" "lb" {
  name               = "lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alltraffic.id]
  subnets            = data.aws_subnet_ids.default.ids
  enable_deletion_protection = false
  depends_on = [ aws_lb_target_group.tg-one ]
  tags = {
     Name = "${var.project}-lb"
   }
}

output "alb-endpoint" {
  value = aws_lb.lb.dns_name
} 
```
##### Creating http listener of application loadbalancer with default action.
```sh
resource "aws_lb_listener" "listner" {
  
  load_balancer_arn = aws_lb.lb.id
  port              = 80
  protocol          = "HTTP"
  
#-------------------------------------
#defualt action of the target group.
#-------------------------------------

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = " No such Site Found"
      status_code  = "200"
   }
}
    
  depends_on = [  aws_lb.mylb ]
}
```
> Note : Use the depends_on meta-argument to handle hidden resource or module dependencies that Terraform can't automatically infer.

##### forward first hostname to targetgroup-one (eg: one-yousaf.com)
```sh
#-------------------------------------
#First forwording rule
#-------------------------------------

resource "aws_lb_listener_rule" "rule-one" {

  listener_arn = aws_lb_listener.listner.id
  priority     = 5

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-one.arn
  }

  condition {
    host_header {
      values = ["first-host-name-"]
    }
  }
}
```

##### forward second hostname to targetgroup-two (eg: two-yousaf.com)
```sh
resource "aws_lb_listener_rule" "rule-two" {
    
  listener_arn = aws_lb_listener.listner.id
  priority     = 5

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-two.arn
  }

  condition {
    host_header {
      values = ["-second-host-name-"]
    }
  }
}
```
Next, we need to create Launch configuration so that we can create Auto scaling group

#####  Launch Configuration
```sh
#-------------------------------------
#First Lauch Configuration
#-------------------------------------

resource "aws_launch_configuration" "launch-one" {
  image_id          = "-choose-a-AMI"
  instance_type     = "-instance-type-"
  security_groups   = [ aws_security_group.sg-web.id ]
  user_data         = file("launch-conf.sh")

  lifecycle {
    create_before_destroy = true
  }
}

#-------------------------------------
#Second Lauch configuration
#-------------------------------------

resource "aws_launch_configuration" "launch-two" {
  image_id        = "-choose-a-AMI"
  instance_type   = "-Instance-type"
  security_groups = [ aws_security_group.sg-web.id ]
  user_data       = file("launch-conf.sh")

  lifecycle {
    create_before_destroy = true
  }
}


```
> Note : We are using file() to load user data.

###### Create Auto Scaling Group One with Lauch configuration one to Target group one
```sh
#-------------------------------------
#First ASG with Lauch configuration one
#-------------------------------------

resource "aws_autoscaling_group" "asg-one" {

  launch_configuration    = aws_launch_configuration.launch-one.id
  health_check_type       = "EC2"
  min_size                = var.asg_count
  max_size                = var.asg_count
  desired_capacity        = var.asg_count
  vpc_zone_identifier     = [-choose-public-subjet-one-,-choose-public-subjet-two-]
  target_group_arns       = [ aws_lb_target_group.tg-one.arn ]
  tag {
    key = "Name"
    propagate_at_launch = true
    value = "Asg-one"
  }

  lifecycle {
    create_before_destroy = true
  }
}
```
###### Create Auto Scaling Group two with Lauch configuration two to Target group two
```sh
resource "aws_autoscaling_group" "asg-two" {

  launch_configuration    = aws_launch_configuration.launch-two.id
  health_check_type       = "EC2"
  min_size                = var.asg_count
  max_size                = var.asg_count
  desired_capacity        = var.asg_count
  vpc_zone_identifier     = [-choose-public-subjet-one-,-choose-public-subjet-two-]
  target_group_arns       = [ aws_lb_target_group.tg-two.arn ]
  tag {
    key = "Name"
    propagate_at_launch = true
    value = "asg-two"
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

Now we need to create a variable file for the autoscaling count
```sh
vim variable-asg.tf
```
```sh
 variable "asg_count" {
  default = 2
}                                          
```
We need to create 2 user data for launch configuration. 
```sh
vim launch-conf.sh
```
```sh
#!/bin/bash

echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
echo "LANG=en_US.utf-8" >> /etc/environment
echo "LC_ALL=en_US.utf-8" >> /etc/environment


echo "password123" | passwd root --stdin
sed  -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
service sshd restart

yum install http php git -y
systemctl start httpd
systemctl enable httpd
git clone https://github.com/yousafkhamza/aws-elb-site.git /var/website
cp -r /var/website/*  /var/www/html/
chown -R apache:apache /var/www/html/*
```

> Note : I used the same launch configuration for both the ASG. However, I've inserted code so that it will show the hostname IP, so that we can identify from which target group it was loaded. 

#### Terraform Validation
> This will check for any errors on the source code

```sh
terraform validate
```
#### Terraform Plan
> The terraform plan command provides a preview of the actions that Terraform will take in order to configure resources per the configuration file. 

```sh
terraform plan
```
#### Terraform apply
> This will execute the tf file we created

```sh
terraform apply
```

-----
## Conclusion

Here is a simple document on how to use Terraform to build an AWS ALB Application load balancer.

#### ⚙️ Connect with Me

<p align="center">
<a href="mailto:yousaf.k.hamza@gmail.com"><img src="https://img.shields.io/badge/Gmail-D14836?style=for-the-badge&logo=gmail&logoColor=white"/></a>
<a href="https://www.linkedin.com/in/yousafkhamza"><img src="https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white"/></a> 
<a href="https://www.instagram.com/yousafkhamza"><img src="https://img.shields.io/badge/Instagram-E4405F?style=for-the-badge&logo=instagram&logoColor=white"/></a>
<a href="https://wa.me/%2B917736720639?text=This%20message%20from%20GitHub."><img src="https://img.shields.io/badge/WhatsApp-25D366?style=for-the-badge&logo=whatsapp&logoColor=white"/></a>
