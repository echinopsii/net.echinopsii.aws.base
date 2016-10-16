#!/usr/bin/env bash 
set -e
set -x

echo "[defaults]\n\ninventory = ~/ansible.base/tools/ec2.py\nhost_key_checking = False" > ~/.ansible.cfg

mkdir ~/.aws
echo "[default]\nregion = eu-west-1" > ~/.aws/config
echo "[default]\naws_secret_access_key = ${ANSIBLE_SAK}\naws_access_key_id = ${ANSIBLE_AKI}" > ~/.aws/credentials

git clone $ANSIBLE_REPO ~/ansible.base

mv /tmp/files/ansible.ec2.ini /home/admin/.ansible.ec2.ini
echo "\nexport EC2_INI_PATH=~/.ansible.ec2.ini" >> ~/.bashrc
