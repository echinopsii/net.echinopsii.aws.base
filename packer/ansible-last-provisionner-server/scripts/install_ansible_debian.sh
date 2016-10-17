#!/usr/bin/env bash 
set -e
set -x

DEP="python-pip libffi-dev libpython-dev libssl-dev git libyaml-dev vim net-tools netcat"
export DEBIAN_FRONTEND=noninteractive

echo "Installing dependencies..."
apt-get update -y
apt-get upgrade -y
apt-get install -y ${DEP}

pip install setuptools==11.3
pip install ansible
