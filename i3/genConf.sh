#!/usr/bin/bash

set -eou pipefail

configDir=$(dirname $0)
i3src=$configDir/i3.conf
i3dest=$HOME/.config/i3/config

host=mbp
wsFile=$configDir/$host/workspaces
if [ $HOSTNAME == $host ]; then
  sed -n "/{{WORKSPACE_SETUP}}/!{p;d;}; r $wsFile" $i3src |\
  sed 's|{{SET_MOD_KEY}}|set \$mod mod1|g' > $i3dest
fi

host=nuc
wsFile=$configDir/$host/workspaces
if [ $HOSTNAME == $host ]; then
  sed -n "/{{WORKSPACE_SETUP}}/!{p;d;}; r $wsFile" $i3src |\
  sed 's|{{SET_MOD_KEY}}|set \$mod mod1|g' > $i3dest
fi


