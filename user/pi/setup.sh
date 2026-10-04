#!/usr/bin/env bash
set -euo pipefail

for tool in pi jq; do
  command -v "$tool" >/dev/null || { printf 'setup.sh requires %s\n' "$tool" >&2; exit 1; }
done

agent_dir="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

# Hard link a repository file into the agent directory, so later repository
# edits apply without rerunning setup. Copy if the filesystems differ.
link() {
  [[ "$1" -ef "$2" ]] && return
  mkdir -p "${2%/*}"
  ln -f -- "$1" "$2" 2>/dev/null || cp --remove-destination -- "$1" "$2"
}

# Learned memory is private; never seeded from the repository.
mkdir -p -m 700 "$agent_dir" "$agent_dir"/{pi-hermes-memory,projects-memory}

while IFS= read -r -d '' file; do
  link "$file" "$agent_dir/$file"
done < <(find AGENTS.md keybindings.json subagents.json hermes-memory-config.json \
  agents prompts skills extensions -type f -print0)
link permissions/config.json "$agent_dir/extensions/pi-permission-system/config.json"

# Model choices differ per machine (home and work use different providers), so
# the repository only supplies first-install defaults and local values win.
classifier="$agent_dir/extensions/pi-permission-classifier/config.json"
if [[ ! -e "$classifier" ]]; then
  mkdir -p "${classifier%/*}"
  cp permissions/classifier.json "$classifier"
fi

# Files deleted from the repository stay installed until removed here.
rm -f -- "$agent_dir/extensions/chain.ts" "$agent_dir"/extensions/jev-reviewer/{config.json,core.mjs}

# Pi rewrites settings.json and stores machine-local keys there, so merge into
# it instead of linking. Precedence, lowest first: model-defaults.json, the
# installed file, settings.json.
settings="$agent_dir/settings.json"
[[ -s "$settings" ]] || printf '{}\n' > "$settings"
jq -s '.[1] * .[0] * .[2]' "$settings" model-defaults.json settings.json > "$settings.tmp"
mv -- "$settings.tmp" "$settings"

# Install only the pinned packages that are missing or at another version.
mapfile -t packages < <(jq -r '.packages[]' settings.json)
for package in "${packages[@]}"; do
  spec="${package#npm:}"
  manifest="$agent_dir/npm/node_modules/${spec%@*}/package.json"
  if [[ "$(jq -r .version "$manifest" 2>/dev/null)" != "${spec##*@}" ]]; then
    pi install "$package"
  fi
done

printf 'Pi setup complete.\n'
