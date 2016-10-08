variable "consul_agent_name" {}

resource "aws_instance" "agent" {
  ami                    = "${data.aws_ami.consul.id}"
  instance_type          = "t2.nano"
  key_name               = "${var.consul_key}"
  subnet_id              = "${data.terraform_remote_state.vpc.private_subnets[0]}"
  vpc_security_group_ids = ["${data.terraform_remote_state.vpc.sg_sshserver}", "${aws_security_group.consul.id}"]
  user_data              = "${data.template_file.agent_hostname.rendered}\n${data.template_file.agent_consul_config.rendered}"

  tags {
    Name = "${data.terraform_remote_state.vpc.vpc_short_name}.${var.consul_agent_name}"
  }
}

data "template_file" "agent_hostname" {
  template = "${file("${path.module}/files/hostname.tpl.sh")}"

  vars {
    TF_HOSTNAME = "${var.consul_agent_name}"
  }
}

data "template_file" "agent_consul_config" {
  template = "${file("${path.module}/files/config_consul.tpl.sh")}"

  vars {
    TF_CONSUL_SERVERS = "${join(",",var.consul_servers_name)}"
    TF_CONSUL_ROLE    = "client"
    TF_CONSUL_OPTIONS = "-ui"
    TF_CONSUL_PUBLIC = "yes"
  }
}

resource "aws_route53_record" "consul_agent" {
  zone_id = "${data.terraform_remote_state.vpc.private_host_zone}"
  name    = "${var.consul_agent_name}"
  type    = "A"
  ttl     = "${var.ttl}"
  records = ["${aws_instance.agent.private_ip}"]
}

resource "aws_route53_record" "consul_agent_reverse" {
  zone_id = "${data.terraform_remote_state.vpc.private_host_zone_reverse}"
  name    = "${replace(aws_instance.agent.private_ip,"/([0-9]+).([0-9]+).([0-9]+).([0-9]+)/","$4.$3")}"
  type    = "PTR"
  ttl     = "${var.ttl}"
  records = ["${var.consul_agent_name}.${data.terraform_remote_state.vpc.vpc_short_name}.${data.terraform_remote_state.vpc.private_domain_name}"]
}

