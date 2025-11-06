#!/bin/bash

scriptDir='/usr/local/bin'

echo "### BEFORE RUNNING SCRIPT" > /tmp/lightdm-debug
tail -n 20 /etc/lightdm/lightdm-gtk-greeter.conf >> /tmp/lightdm-debug
echo ""

# set random background
bgScript=lightdm-gtk-greeter-set-bg
$scriptDir/$bgScript || true

echo "### AFTER RUNNING SCRIPT" >> /tmp/lightdm-debug
tail -n 20 /etc/lightdm/lightdm-gtk-greeter.conf >> /tmp/lightdm-debug
echo ""

exit 0
