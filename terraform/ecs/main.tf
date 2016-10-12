variable "region" {}
variable "state_bucket" {}
variable "vpc_state_key" {}
variable "rds_state_key" {}

variable ecs_cluster_name {
  default="ecs-cluster-demo"
}
variable ecs_cluster_asg_min {
  default="3"
}
variable ecs_cluster_asg_max {
  default="6"
}
variable ecs_cluster_asg_dc {
  default="3"
}

variable ecs_instance_distrib {
  default="ecs-ansible-target*"
}
variable ecs_instance_type {
  default="t2.micro"
}
variable ecs_instance_ansible_group {
  default="some_service"
}
variable ecs_instance_key {}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config {
    bucket = "${var.state_bucket}"
    key = "${var.vpc_state_key}"
    region = "${var.region}"
  }
}

data "terraform_remote_state" "rds" {
  backend = "s3"
  config {
    bucket = "${var.state_bucket}"
    key = "${var.rds_state_key}"
    region = "${var.region}"
  }
}

resource "aws_iam_role" "ecs_host_role" {
  name = "${data.terraform_remote_state.vpc.vpc_short_name}-ecs_host_role"
  assume_role_policy = "${file("files/ecs-role.json")}"
}

resource "aws_iam_role_policy" "ecs_instance_role_policy" {
  name = "${data.terraform_remote_state.vpc.vpc_short_name}-ecs_instance_role_policy"
  policy = "${file("files/ecs-instance-role-policy.json")}"
  role = "${aws_iam_role.ecs_host_role.id}"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${data.terraform_remote_state.vpc.vpc_short_name}-ecs_instance_profile"
  path = "/"
  roles = ["${aws_iam_role.ecs_host_role.name}"]
}

resource "aws_security_group" "ecs_access" {
  name = "${data.terraform_remote_state.vpc.vpc_short_name}-ecs_sg"
  description = "ECS Access"
  vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"

  tags {
    Name = "${data.terraform_remote_state.vpc.vpc_name} ECS Access"
  }
}

resource "aws_security_group_rule" "ecs_admin_access_itcp" {
  type                     = "ingress"
  from_port                = "22"
  to_port                  = "22"
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.ecs_access.id}"
  source_security_group_id = "${data.terraform_remote_state.vpc.sg_admin}"
}

resource "aws_security_group_rule" "ecs_admin_access_e" {
  type              = "egress"
  from_port         = "0"
  to_port           = "0"
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.ecs_access.id}"
}

data "aws_ami" "ecs-ansible-target" {
  most_recent = true
  filter { 
    name = "name"
    values = ["${var.ecs_instance_distrib}"]
  }
}

resource "aws_launch_configuration" "ecs_instance_conf" {
  name = "${data.terraform_remote_state.vpc.vpc_short_name}-${var.ecs_cluster_name}"
  image_id = "${data.aws_ami.ecs-ansible-target.id}"
  instance_type = "${var.ecs_instance_type}"
  security_groups = ["${aws_security_group.ecs_access.id}","${data.terraform_remote_state.rds.sg_rds_client}"]
  iam_instance_profile = "${aws_iam_instance_profile.ecs_instance_profile.name}"
  key_name = "${var.ecs_instance_key}"
  user_data = "#!/bin/bash\necho ECS_CLUSTER='${var.ecs_cluster_name}' > /etc/ecs/ecs.config"
}

resource "aws_autoscaling_group" "ecs_cluster_asg" {
  availability_zones = ["${data.terraform_remote_state.vpc.azs}"]
  name = "${data.terraform_remote_state.vpc.vpc_short_name}-${var.ecs_cluster_name}"
  min_size = "${var.ecs_cluster_asg_min}"
  max_size = "${var.ecs_cluster_asg_max}"
  desired_capacity = "${var.ecs_cluster_asg_dc}"
  health_check_type = "EC2"
  launch_configuration = "${aws_launch_configuration.ecs_instance_conf.name}"
  vpc_zone_identifier = ["${data.terraform_remote_state.vpc.private_subnets}"]
  tag {
    key   = "Name" 
    value = "${data.terraform_remote_state.vpc.vpc_short_name}.${var.ecs_cluster_name}-instance"
    propagate_at_launch = true
  }
  tag {
    key = "ansible_groups"
    value = "${var.ecs_instance_ansible_group}"
    propagate_at_launch = true
  }
  tag {
    key = "ansible_host-var_mysqlFQDN"
    value = "${data.terraform_remote_state.rds.ep_rds}"
    propagate_at_launch = true
  }
  tag {
    key = "ansible_host-var_wwwPath"
    value = "/ecs/${var.ecs_service_ins_task_name}"
    propagate_at_launch = true
  }
}

resource "aws_ecs_cluster" "main" {
  name = "${var.ecs_cluster_name}"
}

output "sg_ecs_access" {
  value = "${aws_security_group.ecs_access.id}"
}
