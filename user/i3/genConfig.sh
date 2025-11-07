#!/usr/bin/bash

set -eou pipefail

configDir=$(dirname $0)
i3template=$configDir/i3.config.template
i3src=$configDir/i3.config
i3dest=$HOME/.config/i3/config

layoutDir=$configDir/layouts

colorSchemeFile="default"
colorSchemeDir=$configDir/color-schemes
colorScheme=$colorSchemeDir/$colorSchemeFile

# ensure color scheme exists and is valid
if [ ! -f $colorScheme ]; then
  echo "error: color scheme file, $colorScheme, doesn't exist"
  exit 1
fi
if ! i3 -c $colorScheme -C > /dev/null; then
  echo "error: color scheme file, $colorScheme, is invalid"
  exit 1
fi

# check for host specific startup layout
if [ -f $layoutDir/$HOSTNAME/startup ]; then
  startupLayout=$layoutDir/$HOSTNAME/startup
else
  startupLayout=$layoutDir/default/startup
fi

case $HOSTNAME in
  nuc)
    modKey="mod1"
    ;;
  mbp)
    modKey="mod4"
    ;;
  *)
    modKey="mod1"
    ;;
esac

cp $i3template $i3src

sed -i "s|{{MOD_KEY}}|set \$mod $modKey|" $i3src

if i3 -c $startupLayout -C > /dev/null; then
  sed -i \
    -e "/{{STARTUP_LAYOUT}}/r $startupLayout" \
    -e "/{{STARTUP_LAYOUT}}/d" $i3src
else
  sed -i "/{{STARTUP_LAYOUT}}/d" $i3src
fi

sed -i \
  -e "/{{COLOR_SCHEME}}/r $colorScheme" \
  -e "/{{COLOR_SCHEME}}/d" $i3src

cp $i3src $i3dest
