#!/usr/bin/env bash

#!/bin/bash
if [ "$XDG_SESSION_DESKTOP" = "sway" ] || [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    xrandr --auto
fi:
