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
pi install npm:@ar-llm/pi-handoff@0.5.0
pi install npm:pi-permission-classifier@0.5.2
pi install npm:@gotgenes/pi-permission-system@36.2.1
pi install npm:@gotgenes/pi-subagents@21.9.1
pi install npm:pi-hermes-memory@0.9.9
pi install npm:pi-web-access@0.35.0
pi install npm:@upstash/context7-pi@0.1.2
pi install npm:pi-lens@4.3.0

# Policies are initial defaults, not files to overwrite on every setup run.
# Install local extensions into Pi's standard directory, not a worktree path.
umask 077
mkdir -p "$agent_dir/extensions/pi-permission-system" "$agent_dir/extensions/pi-permission-classifier"
for spec in 'config:pi-permission-system' 'classifier:pi-permission-classifier'; do
  source_name="${spec%%:*}"
  target="$agent_dir/extensions/${spec#*:}/config.json"
  if [[ ! -e "$target" ]]; then
    cp "$config_dir/permissions/$source_name.json" "$target"
  fi
done
for file in permission-modes.ts footer-colors.ts; do
  target="$agent_dir/extensions/$file"
  # Replace old symlinks, including dangling links to removed worktrees.
  if [[ -L "$target" ]]; then
    rm -- "$target"
  fi
  install -m 600 "$config_dir/extensions/$file" "$target"
done

# Review, teaching, and the grill-me shortcut are native prompt templates.
mkdir -p "$agent_dir/prompts" "$agent_dir/agents"
for file in teach.md review.md grill-me.md; do
  install -m 600 "$config_dir/prompts/$file" "$agent_dir/prompts/$file"
done
install -m 600 "$config_dir/agents/reviewer.md" "$agent_dir/agents/reviewer.md"

# Runtime preferences are initial defaults; preserve local customizations.
for file in subagents.json hermes-memory-config.json; do
  if [[ ! -e "$agent_dir/$file" ]]; then
    install -m 600 "$config_dir/$file" "$agent_dir/$file"
  fi
done
# New memory stores contain personal notes and indexed conversation history.
for directory in pi-hermes-memory projects-memory; do
  if [[ ! -e "$agent_dir/$directory" ]]; then
    install -d -m 700 "$agent_dir/$directory"
  fi
done

# Retire only our exact legacy handoff prompt; preserve locally edited templates.
# Add native search tools without replacing other settings or tool choices.
python3 - "$agent_dir/settings.json" <<'PY'
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile

path = Path(sys.argv[1])
legacy = path.parent / "prompts/handoff.md"
if legacy.is_file():
    digest = hashlib.sha256(legacy.read_bytes()).hexdigest()
    if digest == "3c0cc2092795147757bf262c5cc358a59a89060c90dd5a484c5aa18088635b65":
        legacy.unlink()
    else:
        print("Preserved customized prompts/handoff.md; the /handoff extension takes precedence.", file=sys.stderr)
settings = json.loads(path.read_text()) if path.exists() else {}
existing = settings.get("defaultTools", ["+grep", "+find", "+ls"])
if not isinstance(existing, list) or not all(isinstance(item, str) for item in existing):
    raise SystemExit("settings.json defaultTools must be an array of strings")
# An empty list intentionally disables defaults. Preserve that explicit mode.
relative = bool(existing) and all(item.startswith(("+", "-")) for item in existing)
tools = [item for item in existing if item not in ("-grep", "-find", "-ls")]
for name in ("grep", "find", "ls"):
    if name not in tools and f"+{name}" not in tools:
        tools.append(f"+{name}" if relative else name)
if settings.get("defaultTools") != tools:
    settings["defaultTools"] = tools
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as output:
        temporary = Path(output.name)
        try:
            json.dump(settings, output, indent=2)
            output.write("\n")
            output.close()
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)
PY

# Vendored Markdown skills only: no upstream installers, CLIs, or proxies.
for skill in caveman grill-me; do
  mkdir -p "$agent_dir/skills/$skill"
  for source in "$config_dir/skills/$skill/"*; do
    install -m 600 "$source" "$agent_dir/skills/$skill/${source##*/}"
  done
done

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
