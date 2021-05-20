# Creating VPC and Application Load Balancer using Terraform

Terraform is a tool for building infrastructure with various technologies including Amazon AWS, Microsoft Azure, Google Cloud, and vSphere.
Here is a simple document on how to use Terraform to build an AWS VPC with Subnets, Network ACL for the VPC along with Application load balancer so that gigingeorge.online will go to target group 1 (tg-1) and blog.gigingeorge.online will go to target group 2 (tg-2).

We will be creating 1 VPC with 3  Public subnet,  Internet Gateway,  Route Tables, 2 Target group,  Autoscaling group and lauch configuration
## Features

- Easy to customise and use as the Terraform modules are created using variables,allowing the module to be customized without altering the module's own source code, and allowing modules to be shared between different configurations.
- Each subnet CIDR block created  automatically using cidrsubnet Function 
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
region = "< Desired region>"
access_key = "IAM user access_key"
secret_key = "IAM user secret_key"
project = "<project name>"
vpc_cidr = "<VPC cidr block>"
```
The Basic configuration for terraform aws is completed. Now we need to initialize the terraform using the loaded values
#### Terraform initialisation
```sh
terraform  init
```
> Once the initialization completes, the terraform is will able to connect to our AWS console as per the privileges set on IAM user on the defined region. 

Now we are going to create a VPC with 3 public subnets  with all it's dependancies.
#### Create new VPC
```sh
vim main.tf
```
```sh
data "aws_availability_zones" "AZ" {
  state = "available"
}
```
> This will gather all the availability zones within our region.

#### To create VPC
```sh
resource "aws_vpc" "vpc" {
    
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project}-vpc"
  }
}
```
 > Note : the format is  resource "resource_name" "local-resource-identifier" {}
 
 > local resource identfier is the name in which the deatils of defined resource is stored on tfstate file
 > tfstate file : This state is used by Terraform to map real world resources to your configuration, keep track of metadata, and to improve performance for large infrastructures. This state is stored by default in a local file named "terraform. tfstate"

#### To create InterGateWay For VPC
```sh
resource "aws_internet_gateway" "igw" {
    
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.project}-igw"
  }
}
```
> Note : vpc_id = aws_vpc.vpc.id  >> this refers to ID of VPC create with name "vpc"

Now we need to create Public subnets. 

> PUBLIC SUBNET :  If a subnet's traffic is routed to an internet gateway, the subnet is known as a public subnet. 

#### Creating public subnets
```sh
resource "aws_subnet" "public1" {
    
  vpc_id                   = aws_vpc.vpc.id
  cidr_block               = cidrsubnet(var.vpc_cidr, 2, 0)
  availability_zone        = element(data.aws_availability_zones.AZ.names,0)
  map_public_ip_on_launch  = true
  tags = {
    Name = "${var.project}-public1"
  }
}
```
```sh
resource "aws_subnet" "public2" {
    
  vpc_id                   = aws_vpc.vpc.id
  cidr_block               = cidrsubnet(var.vpc_cidr, 2, 1)
  availability_zone        = element(data.aws_availability_zones.AZ.names,1)
  map_public_ip_on_launch  = true
  tags = {
    Name = "${var.project}-public2"
  }
}
```
```sh
resource "aws_subnet" "public3" {
    
  vpc_id                   = aws_vpc.vpc.id
  cidr_block               = cidrsubnet(var.vpc_cidr, 2, 2)
  availability_zone        = element(data.aws_availability_zones.AZ.names,2)
  map_public_ip_on_launch  = true
  tags = {
    Name = "${var.project}-public-3"
  }
}
```


> cidrsubnet calculates a subnet address within given IP network address prefix.
```sh
> cidrsubnet(prefix, newbits, netnum) 
```
>   -  prefix must be given in CIDR notation
>   - newbits is the number of additional bits with which to extend the prefix. For example, if given a prefix ending in /16 and a newbits value of 4, the resulting subnet address will have length /20.
>    - netnum is a whole number that can be represented as a binary integer with no more than newbits binary digits, which will be used to populate the additional bits added to the prefix.

> element retrieves a single element from a list.
```sh
 element(list, index)
```
  - The index is zero-based. This function produces an error if used with an empty list. The index must be a non-negative integer.

Now we need to create route tables. 

A route table contains a set of rules, called routes, that are used to determine where network traffic from your subnet or gateway is directed.
- Each subnet in your VPC must be associated with a route table, which controls the routing for the subnet (subnet route table).
- A subnet can only be associated with one route table at a time, but you can associate multiple subnets with the same subnet route table.
- Every route table contains a local route for communication within the VPC.

> The route table for Public subnet should be assigned to interget gatway 

#### Creating Route table 

```sh
resource "aws_route_table" "Route" {
    
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project}-Route"
  }
}
```
The created Route tables must be associated to Subnets
#### Route Table association
```sh
resource "aws_route_table_association" "public1" {        
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.Route.id
}

resource "aws_route_table_association" "public2" {      
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.Route.id
}

resource "aws_route_table_association" "public3" {       
  subnet_id      = aws_subnet.public3.id
  route_table_id = aws_route_table.Route.id
}
```


The VPC creation has been completed. 

Now we need the output of created resources 

#### Creating output variables
```sh

output "VPC" {
value = aws_vpc.vpc.id
}
output "Internet_Gateway" {
value = aws_internet_gateway.igw.id

output "Public_Route_table" {
value = aws_route_table.public.id
}
```
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
The new VPC with name VPC and 3 public subnets has been created. 

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
  vpc_id = aws_vpc.vpc.id
  }
```  

##### Create a security group for load balancer 
```sh
resource "aws_security_group" "alb-sec" {
    
  name        = "alb-sec"
  description = "allows 80 for inbound and all for outbound"
  
  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "-1"
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
    Name = "alb-sec"
  }
}
```

#### Create TargetGroup For Application LoadBalancer
> Lets's create 2 target group so that we can forward the traffic 

```sh
resource "aws_lb_target_group" "tg-1" {
  name     = "lb-tg1"
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
Traget group-2

```sh
resource "aws_lb_target_group" "tg-2" {
  name     = "lb-tg2"
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

> Note : lifecycle is a nested block that can appear within a resource block. 
> create_before_destroy is a meta-argument  that will create new replacement object first, and the prior object is destroyed after the replacement is created.

##### Create Application LoadBalancer
```sh
resource "aws_lb" "mylb" {
  name               = "MY-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb-sec.id]
  subnets            = data.aws_subnet_ids.default.ids
  enable_deletion_protection = false
  depends_on = [ aws_lb_target_group.tg-1 ]
  tags = {
     Name = "MY-LB"
}
}
output "ALB-Endpoint" {
  value = aws_lb.mylb.dns_name
}
```
##### Creating http listener of application loadbalancer
```sh
resource "aws_lb_listener" "listner" {

  load_balancer_arn = aws_lb.mylb.id
  port              = 80
  protocol          = "HTTP"
  # defualt action of the target group.
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

##### forward gigingeorge.online to targetgroup 1 (tg-1)
```sh
resource "aws_lb_listener_rule" "rule" {

  listener_arn = aws_lb_listener.listner.id
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-1.arn
  }
  condition {
    host_header {
      values = ["gigingeorge.online"]
    }
  }
}
```

##### forward blog.gigingeorge.online to targetgroup 2 (tg-2)
```sh
resource "aws_lb_listener_rule" "rule2" {

  listener_arn = aws_lb_listener.listner.id
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-2.arn
  }
  condition {
    host_header {
      values = ["blog.gigingeorge.online"]
    }
  }
}
```
Next, we need to create Launch configuration so that we can create Auto scaling group

#####  Launch Configuration
```sh
resource "aws_launch_configuration" "launch" {
  image_id      = "ami-077e31c4939f6a2f3"
  instance_type = "t2.micro"
security_groups = [ aws_security_group.alb-sec.id ]
  user_data = file("launch-1.sh")

  lifecycle {
    create_before_destroy = true
  }
}
```
> Note : We are using file() to load user data.

###### Create Auto Scaling Group
```sh
resource "aws_autoscaling_group" "asg-1" {

  launch_configuration    =  aws_launch_configuration.launch.id
  health_check_type       = "EC2"
  min_size                = var.asg_count
  max_size                = var.asg_count
  desired_capacity        = var.asg_count
  vpc_zone_identifier       = [aws_subnet.public1.id, aws_subnet.public2.id, aws_subnet.public3.id ]
  target_group_arns       = [ aws_lb_target_group.tg-1.arn ]
  tag {
    key = "Name"
    propagate_at_launch = true
    value = "Asg-1"
  }

  lifecycle {
    create_before_destroy = true
  }
```
Second auto scaling group for tg-2
```sh
}
resource "aws_autoscaling_group" "asg-2" {

  launch_configuration    =  aws_launch_configuration.launch.id
  health_check_type       = "EC2"
  min_size                = var.asg_count
  max_size                = var.asg_count
  desired_capacity        = var.asg_count
  vpc_zone_identifier       = [aws_subnet.public1.id, aws_subnet.public2.id, aws_subnet.public3.id]
  target_group_arns       = [ aws_lb_target_group.tg-2.arn ]
  tag {
    key = "Name"
    propagate_at_launch = true
    value = "Asg-2"
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
vim launch
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
git clone https://github.com/gigingeorge/aws-elb-site  /var/website
cp -r /var/website/*  /var/www/html/
chown -R apache:apache /var/www/html/*
```

> Note : I used the same launch configuration for both the ASG. However, I've inserted code so that it will show the hostname IP, so that we can identify from which target group it was loaded. 


