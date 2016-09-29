#!/usr/bin/env bash 
set -e
set -x

groupadd ansible
useradd --home-dir /ansible -g ansible -G docker -s /bin/bash -m ansible
echo "ansible ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/ansible

mkdir /ansible/.ssh
echo $ANSIBLE_AUTHORIZED_KEYS > /ansible/.ssh/authorized_keys
chown -R ansible.ansible /ansible/.ssh
chmod 700 /ansible/.ssh/

