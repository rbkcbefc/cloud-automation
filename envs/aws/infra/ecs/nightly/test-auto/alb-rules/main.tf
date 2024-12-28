# Note to Execute: tf init -backend-config=../../../../../backend-s3-nightly.conf

data "aws_lb_target_group" "tg-ecs-test-auto" {
  name = "ecs-mock-email-service"
}

data "aws_lb" "alb-test-auto" {
  name = "ecs-test-auto"
}

data "aws_lb_listener" "alb-test-auto-listener-http" {
  load_balancer_arn = data.aws_lb.alb-test-auto.arn
  port = 80
}

data "aws_lb_listener" "alb-test-auto-listener-https" {
  load_balancer_arn = data.aws_lb.alb-test-auto.arn
  port = 443
}

resource "aws_alb_listener_rule" "alb-rule-mock-email-service-http" {
  listener_arn = data.aws_lb_listener.alb-test-auto-listener-http.arn
  action {    
    type             = "forward"    
    target_group_arn = data.aws_lb_target_group.tg-ecs-test-auto.arn
  }
  condition {
    path_pattern {
     values = ["/mock-email-service/*"]
    }
  }
}

resource "aws_alb_listener_rule" "alb-rule-mock-email-service-https" {
  listener_arn = data.aws_lb_listener.alb-test-auto-listener-https.arn
  action {    
    type             = "forward"    
    target_group_arn = data.aws_lb_target_group.tg-ecs-test-auto.arn
  }
  condition {
    path_pattern {
     values = ["/mock-email-service/*"]
    }
  }
}

terraform {
  backend "s3" {
    key = "envs/aws/infra/ecs/nightly/test-auto/alb-rules/terraform.state"
  }
}