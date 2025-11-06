#!/usr/bin/bash

if [ "$HOSTNAME" == "mbp" ]; then
  xrandr --output eDP --primary --mode 1680x1050
fi

if [ "$HOSTNAME" == "nuc" ]; then
  xrandr --output HDMI-1 --primary --mode 1920x1080
  xrandr --output DP-3 --mode 1920x1080
fi

exit 0
