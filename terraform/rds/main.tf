variable "state_bucket" {}
variable "vpc_state_key" {}
variable "region" {}

variable "cluster_id" {
  default = "aurora-cluster-demo"
}
variable "cluster_db_name" {
  default = "mydb"
}
variable "cluster_master_user" {
  default = "user"
}
variable "cluster_master_pwd" {
  default = "my_secret!"
}
variable "cluster_brp" {
  default = 5
}
variable "cluster_pbw" {
  default = "07:00-09:00"
}

variable "cluster_instances_name" {
  type = "list"
  default = ["aurora-cluster-demo-0","aurora-cluster-demo-1","aurora-cluster-demo-2"]
}
variable "cluster_instances_type" {
  type = "list"
  default = ["db.r3.large","db.r3.large","db.r3.large"]
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config {
    bucket = "${var.state_bucket}"
    key    = "${var.vpc_state_key}"
    region = "${var.region}"
  }
}

resource "aws_security_group" "rds_client" {
  name        = "${data.terraform_remote_state.vpc.vpc_short_name}-rdsclient"
  description = "RDS Client"
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"

  tags {
    Name = "${data.terraform_remote_state.vpc.vpc_name} RDS Client"
  }
}

resource "aws_security_group" "rds_access" {
  name        = "${data.terraform_remote_state.vpc.vpc_short_name}-rdsaccess"
  description = "Accessing RDS"
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"

  tags {
    Name = "${data.terraform_remote_state.vpc.vpc_name} RDS Access"
  }
}

resource "aws_security_group_rule" "rds_admin_access_tcp" {
  type                     = "ingress"
  from_port                = "3306"
  to_port                  = "3306"
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.rds_access.id}"
  source_security_group_id = "${data.terraform_remote_state.vpc.sg_admin}"
}

resource "aws_security_group_rule" "rds_client_access_tcp" {
  type                     = "ingress"
  from_port                = "3306"
  to_port                  = "3306"
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.rds_access.id}"
  source_security_group_id = "${aws_security_group.rds_client.id}"
}

resource "aws_db_subnet_group" "default" {
    name = "${data.terraform_remote_state.vpc.vpc_short_name}-subnets-group"
    subnet_ids = ["${data.terraform_remote_state.vpc.private_subnets}"]
}

resource "aws_rds_cluster" "default" {
  cluster_identifier = "${var.cluster_id}"
  availability_zones = ["${data.terraform_remote_state.vpc.azs}"]
  database_name = "${var.cluster_db_name}"
  master_username = "${var.cluster_master_user}"
  master_password = "${var.cluster_master_pwd}"
  backup_retention_period = "${var.cluster_brp}"
  preferred_backup_window = "${var.cluster_pbw}"
  db_subnet_group_name = "${aws_db_subnet_group.default.name}"
  vpc_security_group_ids = ["${aws_security_group.rds_access.id}"]
}

resource "aws_rds_cluster_instance" "cluster_instances" {
  count              = "${length(var.cluster_instances_name)}"
  identifier         = "${var.cluster_instances_name[count.index]}"
  cluster_identifier = "${aws_rds_cluster.default.id}"
  instance_class     = "${var.cluster_instances_type[count.index]}"
  db_subnet_group_name = "${aws_db_subnet_group.default.name}"
}

output "sg_rds_client" {
  value = "${aws_security_group.rds_client.id}"
}

output "ep_rds" {
  value = "${aws_rds_cluster.default.endpoint}"
}
