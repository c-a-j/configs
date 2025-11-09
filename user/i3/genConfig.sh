#!/usr/bin/bash

set -eou pipefail

configDir=$(dirname $0)
i3template=$configDir/i3.config.template
i3src=$configDir/i3.config
i3dest=$HOME/.config/i3/config

layoutDir=$configDir/layouts

colorSchemeFile="custom"
colorSchemeDir=$configDir/color-schemes
colorScheme=$colorSchemeDir/$colorSchemeFile

missing-or-invalid() {
  if [ -n $1 ]; then
    echo "error: mod keys file, $1, is missing or invalid"
  fi
  exit 1
}

# check for host specific configs
if [ -d $layoutDir/$HOSTNAME ]; then
  layoutDir=$layoutDir/$HOSTNAME
else
  layoutDir=$layoutDir/default
fi

cp $i3template $i3src

modkeys=$layoutDir/modkeys
bindings=$layoutDir/bindings
startup=$layoutDir/startup

if i3 -c $modkeys -C &> /dev/null && grep -q '^set $mod' $modkeys; then
  sed -i \
    -e "/{{MOD_KEYS}}/r $modkeys" \
    -e "/{{MOD_KEYS}}/d" $i3src
else
  missing-or-invalid $modkeys
fi

if i3 -c $startup -C &> /dev/null; then
  sed -i \
    -e "/{{STARTUP_LAYOUT}}/r $startup" \
    -e "/{{STARTUP_LAYOUT}}/d" $i3src
else
  sed -i "/{{STARTUP_LAYOUT}}/d" $i3src
fi

if i3 -c $bindings -C &> /dev/null; then
  sed -i \
    -e "/{{BINDINGS}}/r $bindings" \
    -e "/{{BINDINGS}}/d" $i3src
else
  sed -i "/{{BINDINGS}}/d" $i3src
fi

if i3 -c $colorScheme -C &> /dev/null; then
  sed -i \
    -e "/{{COLOR_SCHEME}}/r $colorScheme" \
    -e "/{{COLOR_SCHEME}}/d" $i3src
else
  missing-or-invalid $colorScheme
fi

if i3 -c $i3src -C &> /dev/null; then
  cp $i3src $i3dest
else
  echo "error: resulting config is invalid"
  exit 1
fi
