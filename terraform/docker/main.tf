variable "region" {}
variable "state_bucket" {}
variable "vpc_state_key" {}
variable "consul_state_key" {}

variable "docker_overlay_itcp" {
  type = "list"
  default = ["2377","7946","4789"]
}
variable "docker_overlay_iudp" {
  type = "list"
  default = ["7946","4789"]
}

variable "docker_key" {}
variable "dockerhosts" {
  type = "list"
}
variable "dockerhost_distrib" {
  default = "ansible-target"
}
variable "dockerhost_type" {
  type = "list"
}
variable "dockerhost_root_disk_size" {}
variable "dockerhost_ttl" { default=300 }

variable "docker_registry" { default="" }
variable "docker_overlay" {}
variable "docker_overlay_advertise" { default="eth0:2376"}

variable "aws_instance_tags" {
  type = "list"
}

provider "aws" {
  region = "${var.region}"
}

data "terraform_remote_state" "vpc" {
    backend = "s3"
    config {
        bucket = "${var.state_bucket}"
        key = "${var.vpc_state_key}"
        region = "${var.region}"
    }
}

data "terraform_remote_state" "consul" {
    backend = "s3"
    config {
        bucket = "${var.state_bucket}"
        key = "${var.consul_state_key}"
        region = "${var.region}"
    }
}

resource "aws_security_group" "docker_overlay" {
     name = "${var.docker_overlay}"
     description = "Docker Overlay"
     vpc_id = "${data.terraform_remote_state.vpc.vpc_id}"
}

resource "aws_security_group_rule" "docker_overlay_itcp" {
    count = "${length(var.docker_overlay_itcp)}"
    type = "ingress"
    from_port = "${var.docker_overlay_itcp[count.index]}"
    to_port = "${var.docker_overlay_itcp[count.index]}"
    protocol = "tcp"
    cidr_blocks =  ["${data.terraform_remote_state.vpc.private_subnets_cidr_block}"]
    security_group_id = "${aws_security_group.docker_overlay.id}"
}

resource "aws_security_group_rule" "docker_overlay_iudp" {
    count = "${length(var.docker_overlay_iudp)}"
    type = "ingress"
    from_port = "${var.docker_overlay_iudp[count.index]}"
    to_port = "${var.docker_overlay_iudp[count.index]}"
    protocol = "udp"
    cidr_blocks =  ["${data.terraform_remote_state.vpc.private_subnets_cidr_block}"]
    security_group_id = "${aws_security_group.docker_overlay.id}"
}

resource "aws_security_group_rule" "docker_overlay_egress" {
    type = "egress"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.docker_overlay.id}"
}

resource "aws_route53_record" "docker_servers" {
  count   = "${length(var.dockerhosts)}"
  zone_id = "${data.terraform_remote_state.vpc.private_host_zone}"
  name    = "${var.dockerhosts[count.index]}"
  type    = "A"
  ttl     = "${var.dockerhost_ttl}"
  records = ["${aws_instance.docker.*.private_ip[count.index]}"]
}

resource "aws_route53_record" "docker_servers_reverse" {
  count   = "${length(var.dockerhosts)}"
  zone_id = "${data.terraform_remote_state.vpc.private_host_zone_reverse}"
  name    = "${replace(element(aws_instance.docker.*.private_ip,count.index),"/([0-9]+).([0-9]+).([0-9]+).([0-9]+)/","$4.$3")}"
  type    = "PTR"
  ttl     = "${var.dockerhost_ttl}"
  records = ["${var.dockerhosts[count.index]}.${data.terraform_remote_state.vpc.private_domain_name}"]
}

data "template_file" "hostname" {
  template = "${file("${path.module}/files/hostname.sh.tpl")}"

  vars {
    TF_HOSTNAME = "{hostname}"
  }
}

data "template_file" "setup_docker" {
    template     = "${file("${path.module}/files/setup_docker.sh.tpl")}"

    vars {
        docker_hostname = "{hostname}"
        insecure_registry = "${var.docker_registry}"
        overlay_store = "${data.terraform_remote_state.consul.consul_address}"
        overlay_advertise = "${var.docker_overlay_advertise}"
    }
}

data "aws_ami" "docker" {
  most_recent = true
  filter {
    name = "name"
    values = "${list(var.ami_basenames["${var.dockerhost_distrib}"])}"
  }
}

resource "aws_instance" "docker" {
    count = "${length(var.aws_instance_tags)}"
    ami = "${data.aws_ami.docker.id}"
    instance_type = "${var.dockerhost_type[count.index]}"
    key_name = "${var.docker_key}"
    subnet_id = "${data.terraform_remote_state.vpc.private_subnets[count.index]}"

    vpc_security_group_ids = ["${data.terraform_remote_state.vpc.sg_sshserver}", "${data.terraform_remote_state.consul.sg_consul_client}","${aws_security_group.docker_overlay.id}"]
    root_block_device {
        volume_type = "gp2"
        volume_size = "${var.dockerhost_root_disk_size}"
        delete_on_termination = "true"
    }

    user_data="${replace(data.template_file.hostname.rendered,"{hostname}",var.dockerhosts[count.index])}\n${replace(data.template_file.setup_docker.rendered,"{hostname}",var.dockerhosts[count.index])}"

    tags="${var.aws_instance_tags[count.index]}"
}
