#!/usr/bin/env bash

echo "Clean up apt cache"
apt-get --purge -y autoremove
apt-get clean -y
rm -rf /var/lib/apt/lists/*

echo "Remove log files"
for CLEAN in $(find /var/log/ -type f)
do
    cp /dev/null  $CLEAN
done
