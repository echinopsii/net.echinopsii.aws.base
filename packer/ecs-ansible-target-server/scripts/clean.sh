#!/usr/bin/env bash

sed -i '/ packer /d' /home/*/.ssh/authorized_keys /root/.ssh/authorized_keys

echo "Remove backup files"
find /etc -name '*-' -delete
find /etc -name '*~' -delete

echo "Remove server ssh keys"
rm /etc/ssh/ssh_host*

echo "Remove local configurations by cloudinit"
rm /etc/default/locale
rm /etc/hostname
rm /etc/sudoers.d/cloud-init
rm -rf /var/lib/cloud/instances/*
rm -rf /var/lib/cloud/data/*

echo "Remove log files"
for CLEAN in $(find /var/log/ -type f)
do
    cp /dev/null  $CLEAN
done
