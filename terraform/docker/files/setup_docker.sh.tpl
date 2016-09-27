#!/bin/bash

apt-get update
apt-get install -y apt-transport-https ca-certificates
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D

echo "deb https://apt.dockerproject.org/repo debian-jessie main" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-engine

gpasswd -a admin docker

easy_install pip
pip install docker-compose

registry=${insecure_registry}
host=${docker_hostname}
store=${overlay_store}
advertise=${overlay_advertise}

docker_host="fd://"
docker_registry_option=""
docker_overlay_store_option=""
docker_overlay_advertise_option=""

if [ -n "$host" ]
then
	docker_host="tcp://0.0.0.0:2375"
fi

if [ -n "$registry" ]
then
	docker_registry_option="--insecure-registry $registry:5000"
fi

if [ -n "$store" ]
then
	docker_overlay_store_option="--cluster-store=consul://$store"
fi

if [ -n "$advertise" ]
then
	docker_overlay_advertise_option="--cluster-advertise=$advertise"
fi

mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/10-execstart-override.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/docker daemon -H $docker_host $docker_registry_option $docker_overlay_store_option $docker_overlay_advertise_option
EOF
systemctl daemon-reload
systemctl restart docker

echo "export DOCKER_HOST=tcp://0.0.0.0:2375" >> /etc/environment
