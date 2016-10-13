variable ecs_service_elb_port {
  default="80"
}
variable ecs_service_elb_proto {
  default="tcp"
}
variable ecs_service_ins_port {
  default="80"
}
variable ecs_service_ins_trproto {
  default="tcp"
}
variable ecs_service_ins_appproto {
  default="tcp"
}
variable ecs_service_ins_name {
  default="httpd"
}
variable ecs_service_ins_ptt {
  default="index.html"
}
variable ecs_service_ins_task_name {
  default="httpd"
}
variable ecs_service_ins_task_file {
  default="apache_http.json"
}

resource "aws_iam_role" "ecs_service_role" {
    name = "${data.terraform_remote_state.vpc.vpc_short_name}-ecs_service_role"
    assume_role_policy = "${file("files/ecs-role.json")}"
}

resource "aws_iam_role_policy" "ecs_service_role_policy" {
    name = "${data.terraform_remote_state.vpc.vpc_short_name}-ecs_service_role_policy"
    policy = "${file("files/ecs-service-role-policy.json")}"
    role = "${aws_iam_role.ecs_service_role.id}"
}

resource "aws_security_group" "ecs_elb_pubaccess" {
  name = "${data.terraform_remote_state.vpc.vpc_short_name}-ecs_lb_sg"
  description = "ECS ELB Public Access"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"

  tags {
    Name = "${data.terraform_remote_state.vpc.vpc_name} ECS ELB Access"
  }
}

resource "aws_security_group_rule" "ecs_elb_public_access_itcp" {
  type              = "ingress"
  from_port         = "${var.ecs_service_elb_port}"
  to_port           = "${var.ecs_service_elb_port}"
  protocol          = "tcp"
  security_group_id = "${aws_security_group.ecs_elb_pubaccess.id}"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ecs_elb_public_access_etcp" {
  type             = "egress"
  from_port         = "${var.ecs_service_elb_port}"
  to_port           = "${var.ecs_service_elb_port}"
  protocol         = "tcp"
  security_group_id = "${aws_security_group.ecs_elb_pubaccess.id}"
  cidr_blocks       = ["0.0.0.0/0"]
}


resource "aws_security_group_rule" "ecs_elb_access_itcp" {
  type                     = "ingress"
  from_port                = "80"
  to_port                  = "80"
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.ecs_access.id}"
  source_security_group_id = "${aws_security_group.ecs_elb_pubaccess.id}"
}

resource "aws_elb" "ecs_service_elb" {
  name = "${data.terraform_remote_state.vpc.vpc_short_name}-ecs-elb"
  security_groups = ["${aws_security_group.ecs_elb_pubaccess.id}"]
  subnets = ["${data.terraform_remote_state.vpc.private_subnets}"]

  listener {
    lb_protocol = "${var.ecs_service_elb_proto}"
    lb_port = "${var.ecs_service_elb_port}"
    instance_protocol = "${var.ecs_service_ins_appproto}"
    instance_port = "${var.ecs_service_ins_port}"
  }

  health_check {
    healthy_threshold = 3
    unhealthy_threshold = 2
    timeout = 3
    # target = "HTTP:${var.ecs_service_ins_port}/${var.ecs_service_ins_ptt}"
    target = "TCP:${var.ecs_service_ins_port}"
    interval = 5
  }

  cross_zone_load_balancing = true
}

resource "aws_security_group_rule" "ecs_admin_access_isomeservice" {
  type                     = "ingress"
  from_port                = "${var.ecs_service_ins_port}"
  to_port                  = "${var.ecs_service_ins_port}"
  protocol                 = "${var.ecs_service_ins_trproto}"
  security_group_id        = "${aws_security_group.ecs_access.id}"
  source_security_group_id = "${data.terraform_remote_state.vpc.sg_admin}"
}

resource "aws_ecs_task_definition" "some_task" {
  family = "${var.ecs_service_ins_task_name}"
  container_definitions = "${file("files/${var.ecs_service_ins_task_file}")}"

  volume {
    name = "${var.ecs_service_ins_task_name}"
    host_path = "/ecs/${var.ecs_service_ins_task_name}"
  }
}

resource "aws_ecs_service" "some_service" {
  name = "${data.terraform_remote_state.vpc.vpc_short_name}-wordpress"
  cluster = "${aws_ecs_cluster.main.id}"
  task_definition = "${aws_ecs_task_definition.some_task.arn}"
  desired_count = 3

  iam_role = "${aws_iam_role.ecs_service_role.arn}"
  depends_on = ["aws_iam_role_policy.ecs_service_role_policy"]
  load_balancer {
    elb_name = "${aws_elb.ecs_service_elb.name}"
    container_name = "${var.ecs_service_ins_name}"
    container_port = "${var.ecs_service_ins_port}"
  }
}
