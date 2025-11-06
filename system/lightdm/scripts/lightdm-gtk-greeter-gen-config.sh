#!/bin/bash

theme='Adwaita-dark'
iconTheme='Adwaita'
hideUserImage='true'

configSrcDir='/home/cjordan/configs/system/lightdm'
defaultConfig="$configSrcDir/lightdm-gtk-greeter.conf.default"
configSrc="$configSrcDir/lightdm-gtk-greeter.conf"
configDest="/etc/lightdm/lightdm-gtk-greeter.conf"

cp $defaultConfig $configSrc

if ! grep -q '^\[greeter\]' $configSrc; then
  echo '[greeter]' >> $configSrc
fi

sed -i "/^\[greeter\]/a\hide-user-image = $hideUserImage" $configSrc

if [ -d "/usr/share/icons/$iconTheme" ]; then
  sed -i "/^\[greeter\]/a\icon-theme-name = $iconTheme" $configSrc
fi

if [ -d "/usr/share/themes/$theme" ]; then
  sed -i "/^\[greeter\]/a\theme-name = $theme" $configSrc
fi

cp $configSrc $configDest
