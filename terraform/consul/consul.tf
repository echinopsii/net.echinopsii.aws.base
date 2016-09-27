variable "state_bucket" {}

variable "vpc_state_key" {}

variable "region" {}

variable "consul_servers" {
  type = "list"
  default = ["consul0","consul1","consul2"]
}

variable "consul_version" {}
variable "consul_ami_basename" {}

variable "consul_type" {
  default = "t2.micro"
}

variable "consul_key" {}

variable "consul_servers_tcp" {
  type = "list"
  default = [ "8300", "8301", "8302" ]
}

variable "consul_servers_udp" {
  type = "list"
  default = [ "8301", "8302" ]
}

variable "consul_clients_tcp" {
  type = "list"
  default = ["8500","8600"]
}

variable "consul_clients_udp" {
  type = "list"
  default = ["8600"]
}

variable "ttl" {}

data "terraform_remote_state" "vpc" {
  backend = "s3"

  config {
    bucket = "${var.state_bucket}"
    key    = "${var.vpc_state_key}"
    region = "${var.region}"
  }
}

data "aws_ami" "consul" {
  most_recent = true
  filter {
    name = "name"
    values = "${list(var.consul_ami_basename)}"
  }
  filter {
    name = "tag:ConsulVersion"
    values = "${list(var.consul_version)}"
  }
}


resource "aws_security_group" "consul_client" {
  name        = "${data.terraform_remote_state.vpc.vpc_short_name}-consulclient"
  description = "Client accessing consul"
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"

  tags {
    Name = "${data.terraform_remote_state.vpc.vpc_name} Consul Client"
  }
}

resource "aws_security_group" "consul" {
  name        = "${data.terraform_remote_state.vpc.vpc_short_name}-consul"
  description = "Consul internal traffic"
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"

  tags {
    Name = "${data.terraform_remote_state.vpc.vpc_name} Consul Nodes"
  }
}

resource "aws_security_group_rule" "consul_servers_tcp" {
  count             = "${length(var.consul_servers_tcp)}"
  type              = "ingress"
  from_port         = "${var.consul_servers_tcp[count.index]}"
  to_port           = "${var.consul_servers_tcp[count.index]}"
  protocol          = "tcp"
  security_group_id = "${aws_security_group.consul.id}"
  self              = true
}

resource "aws_security_group_rule" "consul_servers_udp" {
  count             = "${length(var.consul_servers_udp)}"
  type              = "ingress"
  from_port         = "${var.consul_servers_udp[count.index]}"
  to_port           = "${var.consul_servers_udp[count.index]}"
  protocol          = "udp"
  security_group_id = "${aws_security_group.consul.id}"
  self              = true
}

resource "aws_security_group_rule" "consul_clients_tcp" {
  count                    = "${length(var.consul_clients_tcp)}"
  type                     = "ingress"
  from_port                = "${var.consul_clients_tcp[count.index]}"
  to_port                  = "${var.consul_clients_tcp[count.index]}"
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.consul.id}"
  source_security_group_id = "${aws_security_group.consul_client.id}"
}

resource "aws_security_group_rule" "consul_clients_udp" {
  count                    = "${length(var.consul_clients_udp)}"
  type                     = "ingress"
  from_port                = "${var.consul_clients_udp[count.index]}"
  to_port                  = "${var.consul_clients_udp[count.index]}"
  protocol                 = "udp"
  security_group_id        = "${aws_security_group.consul.id}"
  source_security_group_id = "${aws_security_group.consul_client.id}"
}

resource "aws_security_group_rule" "consul_admin_tcp" {
  count                    = "${length(var.consul_clients_tcp)}"
  type                     = "ingress"
  from_port                = "${var.consul_clients_tcp[count.index]}"
  to_port                  = "${var.consul_clients_tcp[count.index]}"
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.consul.id}"
  source_security_group_id = "${data.terraform_remote_state.vpc.sg_admin}"
}

resource "aws_security_group_rule" "consul_admin" {
  count                    = "${length(var.consul_clients_udp)}"
  type                     = "ingress"
  from_port                = "${var.consul_clients_udp[count.index]}"
  to_port                  = "${var.consul_clients_udp[count.index]}"
  protocol                 = "udp"
  security_group_id        = "${aws_security_group.consul.id}"
  source_security_group_id = "${data.terraform_remote_state.vpc.sg_admin}"
}


resource "aws_instance" "consul" {
  count                  = "${length(var.consul_servers)}"
  ami                    = "${data.aws_ami.consul.id}"
  instance_type          = "${var.consul_type}"
  key_name               = "${var.consul_key}"
  subnet_id              = "${data.terraform_remote_state.vpc.private_subnets[count.index]}"
  vpc_security_group_ids = ["${data.terraform_remote_state.vpc.sshserver}", "${aws_security_group.consul.id}"]
  user_data              = "${replace(data.template_file.hostname.rendered,"{hostname}",var.consul_servers[count.index])}\n${data.template_file.consul_config.rendered}"

  tags {
    Name = "${var.consul_servers[count.index]}"
  }
}

data "template_file" "hostname" {
  template = "${file("${path.module}/files/hostname.tpl.sh")}"

  vars {
    #TF_HOSTNAME = "${element(split(",",var.consul_servers),count.index)}"
    TF_HOSTNAME = "{hostname}"
  }
}

data "template_file" "consul_config" {
  template = "${file("${path.module}/files/config_consul.tpl.sh")}"

  vars {
    TF_CONSUL_SERVERS = "${join(",",var.consul_servers)}"
    TF_CONSUL_ROLE    = "server"
    TF_CONSUL_OPTIONS = ""
    TF_CONSUL_PUBLIC = "yes"
  }
}

resource "aws_route53_record" "consul_servers" {
  count   = "${length(var.consul_servers)}"
  zone_id = "${data.terraform_remote_state.vpc.private_host_zone}"
  name    = "${var.consul_servers[count.index]}"
  type    = "A"
  ttl     = "${var.ttl}"
  records = ["${aws_instance.consul.*.private_ip[count.index]}"]
}

resource "aws_route53_record" "consul_servers_reverse" {
  count   = "${length(var.consul_servers)}"
  zone_id = "${data.terraform_remote_state.vpc.private_host_zone_reverse}"
  name    = "${replace(element(aws_instance.consul.*.private_ip,count.index),"/([0-9]+).([0-9]+).([0-9]+).([0-9]+)/","$4.$3")}"
  type    = "PTR"
  ttl     = "${var.ttl}"
  records = ["${var.consul_servers[count.index]}.${data.terraform_remote_state.vpc.private_domain_name}"]
}

output "consul_server_ips" {
  value = ["${aws_instance.consul.*.private_ip}"]
}

output "consul_servers" {
  value = ["${aws_route53_record.consul_servers.*.name}"]
}

output "sg_consul_client" {
  value = "${aws_security_group.consul_client.id}"
}

output "consul_address" {
  value = "${aws_route53_record.consul_servers.0.name}:8500"
}
