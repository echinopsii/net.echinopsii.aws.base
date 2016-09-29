#!/usr/bin/env bash 
set -e
set -x

groupadd ansible
useradd --home-dir /home/ansible -g ansible -G docker -s /bin/bash -m ansible
echo "ansible ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/90-cloud-init-users

mkdir /home/ansible/.ssh
cp /home/admin/.ssh/authorized_keys /home/ansible/.ssh/
chown -R ansible.ansible /home/ansible/.ssh
chmod 700 /home/ansible/.ssh/

