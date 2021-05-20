#========================================================
# Creating Two Target Groups For Application LoadBalancer
#========================================================

#-------------------------------------
#Target Group one
#-------------------------------------
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

#-------------------------------------
#Target Group two
#-------------------------------------

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

#========================================================
# Application LoadBalancer
#========================================================

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

#========================================================
# Creating http listener of application loadbalancer
#========================================================

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

#========================================================
# forwarder with domain-hostname to target group
#========================================================

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

#-------------------------------------
#Second forwariding rule
#-------------------------------------

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
#========================================================
# Launch Configuration's
#========================================================

resource "aws_launch_configuration" "launch-one" {
  image_id          = "-choose-a-AMI"
  instance_type     = "-instance-type-"
  security_groups   = [ aws_security_group.sg-web.id ]
  user_data         = file("launch-conf.sh")

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "launch-two" {
  image_id        = "-choose-a-AMI"
  instance_type   = "-Instance-type"
  security_groups = [ aws_security_group.sg-web.id ]
  user_data       = file("launch-conf.sh")

  lifecycle {
    create_before_destroy = true
  }
}

#========================================================
# ASG Creations
#========================================================

#-------------------------------------
#First ASG with Lauch conf one
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

#-------------------------------------
#Second ASG with Lauch conf two
#-------------------------------------

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

#========================================================
#Security_Groups for webserver
#========================================================

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