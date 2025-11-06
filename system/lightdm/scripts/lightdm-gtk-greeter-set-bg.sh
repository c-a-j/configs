#!/bin/bash

bgDir="/usr/share/backgrounds" 
config="/home/cjordan/configs/system/lightdm/lightdm-gtk-greeter.conf"

bgFile=$(find "$bgDir" -name '*.png' -o -name '*.jpg' -type f -print0 2>/dev/null | shuf -n 1 -z 2>/dev/null | xargs -0 echo 2>/dev/null || true)


echo "bgDir = $bgDir" >> /tmp/lightdm-debug
echo "config = $config" >> /tmp/lightdm-debug
echo "bgFile = $bgFile" >> /tmp/lightdm-debug

if [ -n "$bgFile" ]; then
  echo "ENTERING FIRST CONDITION" >> /tmp/lightdm-debug
  if grep -q '^background' "$config"; then
    echo "backgroun exists, using sed to modify" >> /tmp/lightdm-debug
    echo "bgFile value: '$bgFile'" >> /tmp/lightdm-debug
    echo "matching line:" >> /tmp/lightdm-debug
    grep '^background' "$config" >> /tmp/lightdm-debug
    sed -i -E "s|^background.*=.*|background=$bgFile|" "$config" 2>>/tmp/lightdm-debug
    sed_exit=$?
    echo "sed exit code: $sed_exit" >> /tmp/lightdm-debug
  else
      echo "backgroun doesn't exist, using sed to modify" >> /tmp/lightdm-debug
      sed -i -E "/^\[greeter\]/a\background=$bgFile" "$config"
  fi
fi

cp $config /etc/lightdm/lightdm-gtk-greeter.conf