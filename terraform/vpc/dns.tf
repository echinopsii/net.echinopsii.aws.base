variable "private_domain_name" {}
variable "reverse_dns" {}

resource "aws_route53_zone" "private" {
  name   = "${var.private_domain_name}"
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route53_zone" "private_reverse" {
  name   = "${var.reverse_dns}.in-addr.arpa."
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_vpc_dhcp_options" "dns_resolver" {
  domain_name_servers = ["${cidrhost(var.cidr_block, "2") }"]
  domain_name         = "${var.private_domain_name}"

  tags {
    Name = "${var.vpc_name}_DNS_CONFIG"
  }
}

resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  vpc_id          = "${aws_vpc.main.id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.dns_resolver.id}"
}

output "private_domain_name" {
  value = "${var.private_domain_name}"
}

output "private_host_zone" {
  value = "${aws_route53_zone.private.zone_id}"
}

output "private_host_zone_reverse" {
  value = "${aws_route53_zone.private_reverse.zone_id}"
}
