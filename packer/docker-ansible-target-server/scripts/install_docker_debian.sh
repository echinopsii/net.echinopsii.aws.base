#!/usr/bin/env bash 
set -e
set -x

_BDEP="docker-engine python-pip libyaml-dev libpython-dev"
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y apt-transport-https ca-certificates
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "deb https://apt.dockerproject.org/repo debian-jessie main" > /etc/apt/sources.list.d/docker.list

echo "Installing dependencies..."
apt-get update -y
apt-get upgrade -y
apt-get install -y ${_BDEP}

gpasswd -a admin docker

pip install docker-compose 'docker-py==1.9.0' --force-reinstall

mv /tmp/dockerConnect /usr/bin/
mv /tmp/dockerKlean /usr/bin/
