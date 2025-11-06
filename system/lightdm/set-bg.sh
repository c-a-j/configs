#!/bin/bash

set -eou pipefail

bgDir="/usr/share/backgrounds" # Or your preferred image directory
ldmConfig="/etc/lightdm/lightdm-gtk-greeter.conf"

# Find a random image file
bgFile=$(find "$bgDir" -type f -print0 | shuf -n 1 -z | xargs -0 echo)

if [ -n "$bgFile" ]; then
    # Update the background in the config file
    sed -i -e "s|^background.*=.*|background=$bgFile|g" "$ldmConfig"
else
    echo "No images found in $bgDir"
fi
