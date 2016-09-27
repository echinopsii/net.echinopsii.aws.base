#!/bin/sh
echo ${hostname} > /etc/hostname
echo "$(hostname -I) ${hostname}" >> /etc/hosts
hostname ${hostname}
