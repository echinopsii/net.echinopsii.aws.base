variable "region" {}
variable "state_bucket" {}
variable "vpc_state_key" {}
variable "ecs_state_key" {}

variable service_elb_port {
  default="80"
}
variable service_elb_proto {
  default="tcp"
}
variable service_ins_port {
  default="80"
}
variable service_ins_proto {
  default="tcp"
}
variable service_ins_ptt {
  default="index.html"
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config {
    bucket = "${var.state_bucket}"
    key = "${var.vpc_state_key}"
    region = "${var.region}"
  }
}

data "terraform_remote_state" "ecs" {
  backend = "s3"
  config {
    bucket = "${var.state_bucket}"
    key = "${var.ecs_state_key}"
    region = "${var.region}"
  }
}

resource "aws_security_group" "elb_pubaccess" {
  name = "${data.terraform_remote_state.vpc.vpc_short_name}-lb_sg"
  description = "ELB Public Access"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"

  tags {
    Name = "${data.terraform_remote_state.vpc.vpc_name} ELB Access"
  }
}

resource "aws_security_group_rule" "elb_public_access_itcp" {
  type              = "ingress"
  from_port         = "${var.service_elb_port}"
  to_port           = "${var.service_elb_port}"
  protocol          = "tcp"
  security_group_id = "${aws_security_group.elb_pubaccess.id}"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "elb_public_access_etcp" {
  type             = "egress"
  from_port        = "${var.service_elb_port}"
  to_port          = "${var.service_elb_port}"
  protocol         = "tcp"
  security_group_id = "${aws_security_group.elb_pubaccess.id}"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "elb_ecs_access_itcp" {
  type                     = "ingress"
  from_port                = "80"
  to_port                  = "80"
  protocol                 = "tcp"
  security_group_id        = "${data.terraform_remote_state.ecs.sg_ecs_access}"
  source_security_group_id = "${aws_security_group.ecs_elb_pubaccess.id}"
}

resource "aws_elb" "ecs_service_elb" {
  name = "${data.terraform_remote_state.vpc.vpc_short_name}-ecs-elb"
  security_groups = ["${aws_security_group.ecs_elb_pubaccess.id}"]
  subnets = ["${data.terraform_remote_state.vpc.public_subnets}"]
  instances = ["${data.terraform_remote_state.ecs.ecs_instances_id}"]

  listener {
    lb_protocol = "${var.service_elp_proto}"
    lb_port = "${var.service_elb_port}"
    instance_protocol = "${var.service_ins_proto}"
    instance_port = "${var.service_ins_port}"
  }
  
  health_check {
    healthy_threshold = 3 
    unhealthy_threshold = 2
    timeout = 3
    target = "TCP:${var.service_ins_port}"
    interval = 5
  }
  
  cross_zone_load_balancing = true
}
