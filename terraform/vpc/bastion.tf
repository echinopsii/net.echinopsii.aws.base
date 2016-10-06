variable "bastions_name" {
  type = "list"
  default = ["bastion0"]
}

variable "trusted_networks" {
  type    = "list"
  default = ["0.0.0.0/0"]
}

variable "bastion_ami_basename" {
  type = "list"
}

variable "bastion_type" {
  default = "t2.nano"
}

variable "bastion_key" {}

variable "bastion_ttl" {}

resource "aws_security_group" "remotessh" {
  name        = "${var.vpc_short_name}-remotessh"
  description = "Allow remote ssh from trusted networks"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = "${var.trusted_networks}"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.vpc_name} Public SSH"
  }
}

resource "aws_security_group" "admin" {
  name        = "${var.vpc_short_name}-admin"
  description = "Admin servers"
  vpc_id      = "${aws_vpc.main.id}"

  tags {
    Name = "${var.vpc_name} Admin"
  }
}

resource "aws_security_group" "sshserver" {
  name        = "${var.vpc_short_name}-sshserver"
  description = "Allow all ssh from remote admin servers"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = ["${aws_security_group.admin.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.vpc_name} SSH server"
  }
}

data "aws_ami" "bastion" {
  most_recent = true
  filter {
    name = "name"
    values = "${var.bastion_ami_basename}"
  }
}

data "template_file" "hostname" {
  template = "${file("${path.module}/files/hostname.tpl.sh")}"

  vars {
    hostname = "{name}"
  }
}

data "template_file" "setup_ansible" {
  template = "${file("${path.module}/files/setup_bastion_ansible.sh")}"

  vars {
    TF_VPC_ID = "{vpc_id}"
  }
}

resource "aws_eip" "bastion" {
  count    = "${length(var.bastions_name)}"
  instance = "${element(aws_instance.bastion.*.id,count.index)}"
  vpc      = true
}

resource "aws_instance" "bastion" {
  count                  = "${length(var.bastions_name)}"
  ami                    = "${data.aws_ami.bastion.id}"
  instance_type          = "${var.bastion_type}"
  key_name               = "${var.bastion_key}"
  subnet_id              = "${element(aws_subnet.public.*.id,count.index)}"
  vpc_security_group_ids = ["${aws_security_group.remotessh.id}","${aws_security_group.admin.id}" ]
  user_data              = "${replace(data.template_file.hostname.rendered, "{name}", "${var.bastions_name[count.index]}.${var.vpc_short_name}")}\n${replace(data.template_file.setup_ansible.rendered, "{vpc_id}", aws_vpc.main.id) }" 
  tags {
    Name = "${var.vpc_short_name}.${var.bastions_name[count.index]}"
  }
}

resource "aws_route53_record" "bastion_servers" {
  count   = "${length(var.bastions_name)}"
  zone_id = "${aws_route53_zone.private.zone_id}"
  name    = "${var.bastions_name[count.index]}"
  type    = "A"
  ttl     = "${var.bastion_ttl}"
  records = ["${element(aws_instance.bastion.*.private_ip,count.index)}"]
}

resource "aws_route53_record" "bastion_servers_reverse" {
  count   = "${length(var.bastions_name)}"
  zone_id = "${aws_route53_zone.private_reverse.zone_id}"
  name    = "${replace(element(aws_instance.bastion.*.private_ip,count.index),"/([0-9]+).([0-9]+).([0-9]+).([0-9]+)/","$4.$3")}"
  type    = "PTR"
  ttl     = "${var.bastion_ttl}"
  records = ["${var.bastions_name[count.index]}.${var.vpc_short_name}.${var.private_domain_name}"]
}


output "sg_sshserver" {
  value = "${aws_security_group.sshserver.id}"
}

output "bastion" {
  value = "${join(",",aws_eip.bastion.*.public_ip)}"
}

output "sg_admin" {
  value = "${aws_security_group.admin.id}"
}

