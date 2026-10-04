# Working in this repository

This repository contains user dotfiles and local Ansible installation playbooks.

- Preserve unrelated working-tree changes. Do not deploy all configuration as a
  side effect of editing one component.
- Preserve existing hard links when modifying repository files: edit files in
  place and keep their inode numbers unchanged whenever possible. Avoid
  replacement-by-rename or delete-and-recreate workflows that break hard links.

## Edit the source, never the installed copy

This repository exists to keep several machines consistent. **Make every
configuration change in the tracked source under `user/`. Never create, edit,
or delete files directly in an installed location** such as `~/.pi`,
`~/.config`, or `~/.local`. A change made only in the installed location exists
on one machine, is invisible to git, never reaches the others, and is
overwritten by the next setup run.

- If installed configuration is wrong, fix the source file or the installation
  code here, not the installed copy.
- If a change was already made directly in an installed location, move it into
  the tracked source before doing anything else.
- For Pi, the source is `user/pi/` and the installed location is `~/.pi/agent`.
  Change settings and package pins in `user/pi/settings.json`, not with
  `pi install` or by editing `~/.pi/agent/settings.json`. Change permission
  policies in `user/pi/permissions/`. Add extensions, prompts, skills, and
  agents under `user/pi/`. `just update-pi` hard links these into place and is
  needed only after adding a file or changing `settings.json`.
- Only private or machine-local state belongs in the installed location alone:
  credentials, sessions, learned memory, logs, caches, installed packages, and
  Pi model choices. Machines use different model providers, so
  `user/pi/model-defaults.json` and `user/pi/permissions/classifier.json` are
  first-install defaults that setup never applies over a machine's own values.

## General rules

- User configuration lives under `user/`; installation playbooks and Just
  targets live under `playbooks/`.
- Pi configuration lives under `user/pi/`. Read `user/pi/README.md` before
  changing setup, permissions, agent definitions, or prompt templates.
- Pin Pi package versions. Installation code must never delete or overwrite
  authentication, sessions, learned memory, or machine-local settings keys.
- Never commit credentials, live sessions, memory databases, or review logs.
- Prefer native Pi settings and prompt templates over custom runtime patches.
- Use agents for clearly scoped independent work. Background reviews are
  read-only and request-driven, not automatic on every edit. Keep concurrent
  writers in separate worktrees or serialize their edits.
- Write code, comments, documentation, and handoff briefs in normal prose,
  regardless of the conversational response style.

For Pi changes, run `bash -n user/pi/setup.sh`,
`python3 user/pi/tests/setup-smoke.py`, and `git diff --check`. Run Ansible syntax
checks for changed playbooks; use isolated destinations for deployment tests.
Do not run `just update-all` or live deployment without user authorization.
