#!/usr/bin/env bash 
set -e
set -x

_BDEP="python-pip libffi-dev libpython-dev libssl-dev git"
export DEBIAN_FRONTEND=noninteractive

echo "Installing dependencies..."
apt-get update -y
apt-get upgrade -y
apt-get install -y ${_BDEP}

pip install ansible==1.9.6

mkdir /ANSIBLE && cd /ANSIBLE
git clone $ANSIBLE_REPO
