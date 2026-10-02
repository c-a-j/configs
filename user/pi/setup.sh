#!/usr/bin/env bash
set -euo pipefail

if (( $# > 1 )) || [[ "${1:-}" != "" && "${1:-}" != "--with-jev" ]]; then
  printf 'Usage: bash user/pi/setup.sh [--with-jev]\n' >&2
  exit 2
fi

config_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
agent_dir="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"

# Pi manages packages and preserves existing settings and authentication.
pi install npm:pi-vim@0.14.2
pi install npm:@signalridge/pi-plan-mode@1.4.2
pi install npm:pi-permission-classifier@0.5.2
pi install npm:@gotgenes/pi-permission-system@36.2.1

# Policies are initial defaults, not files to overwrite on every setup run.
# Install our helper into Pi's standard directory, not a temporary worktree path.
umask 077
mkdir -p "$agent_dir/extensions/pi-permission-system" "$agent_dir/extensions/pi-permission-classifier"
for spec in 'config:pi-permission-system' 'classifier:pi-permission-classifier'; do
  source_name="${spec%%:*}"
  target="$agent_dir/extensions/${spec#*:}/config.json"
  if [[ ! -e "$target" ]]; then
    cp "$config_dir/permissions/$source_name.json" "$target"
  fi
done
install -m 600 "$config_dir/extensions/permission-modes.ts" "$agent_dir/extensions/permission-modes.ts"

# Jev is an optional experiment, not part of normal Auto mode.
if [[ "${1:-}" == "--with-jev" ]]; then
  target="$agent_dir/extensions/jev-reviewer"
  mkdir -p "$target"
  if [[ ! -e "$target/config.json" ]]; then
    cp "$config_dir/permissions/jev.json" "$target/config.json"
  fi
  for file in index.ts core.mjs package.json; do
    install -m 600 "$config_dir/extensions/jev-reviewer/$file" "$target/$file"
  done
fi

printf 'Pi setup complete. Restart Pi or run /reload.\n'
