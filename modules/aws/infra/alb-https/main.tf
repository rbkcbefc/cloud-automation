
variable "tg_name" {}
variable "domain_name" {}
variable "alb_name" {}
variable "alb_https_port" {
  default = 443
}

data "aws_alb" "alb" {
  name = var.alb_name
}

data "aws_alb_target_group" "target-group" {
  name = var.tg_name
}

data "aws_acm_certificate" "cert" {
  domain = var.domain_name
}

resource "aws_alb_listener" "alb-listener-https" {
  load_balancer_arn = data.aws_alb.alb.arn
  port              = var.alb_https_port
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = data.aws_alb_target_group.target-group.arn
  }
}

resource "aws_alb_listener_rule" "alb-rule-http-mock-nasa-sound-api" {
  listener_arn = aws_alb_listener.alb-listener-https.arn
  action {    
    type             = "forward"    
    target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:318075166670:targetgroup/ecs-mock-email-service/ec180b4671412a95"
  }   
  condition {
    path_pattern {
     values = ["/"]
   }
  }
}

