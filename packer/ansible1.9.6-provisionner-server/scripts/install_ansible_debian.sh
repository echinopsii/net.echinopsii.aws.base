#!/usr/bin/env bash -x
set -e
set -x

_BDEP="python-pip libffi-dev"
export DEBIAN_FRONTEND=noninteractive

echo "Installing dependencies..."
apt-get update -y
apt-get upgrade -y
apt-get install -y ${_BDEP}

#pip install ansible==1.9.6
