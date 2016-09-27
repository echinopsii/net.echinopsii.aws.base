#!/usr/bin/env bash
echo ${TF_HOSTNAME} > /etc/hostname
echo "$(hostname -I) ${TF_HOSTNAME}" >> /etc/hosts
hostname ${TF_HOSTNAME}
