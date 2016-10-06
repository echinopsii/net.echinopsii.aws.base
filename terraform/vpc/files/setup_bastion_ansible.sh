#!/bin/sh

if [ -f /home/admin/.ansible.ec2.ini ]; then
	sed -i "s/##VPC-ID/${TF_VPC_ID}/g" /home/admin/.ansible.ec2.ini
	cd /home/admin/ansible.base;
	sudo -u admin git pull
fi
