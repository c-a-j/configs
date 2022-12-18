#!/usr/bin/bash

if [ $HOSTNAME == "macinArch" ]; then
    # set i3 configuration file
    cat ~/configs/i3.conf | sed 's|set \$mod KEY|set \$mod mod4|g' >| ~/.config/i3/config

    # set keyboard layout
    setxkbmap -model mac-us -layout us -option caps:swapescape

    # set resolution
    xrandr --output eDP-1 --primary --mode 1920x1200

    # set bg image
    feh --bg-scale "/usr/share/backgrounds/simpleArch.png"

fi

if [ $HOSTNAME == "intelArch" ]; then
    # set i3 configuration file
    cat ~/configs/i3.conf | sed 's|set \$mod KEY|set \$mod mod1|g' >| ~/.config/i3/config

    # set keyboard layout
    setxkbmap -model mac-us -layout us -option caps:swapescape

    # set resolution
    xrandr --output eDP-1 --primary --mode 1920x1200

    # set bg image
    feh --bg-scale "/usr/share/backgrounds/simpleArch.png"
fi
