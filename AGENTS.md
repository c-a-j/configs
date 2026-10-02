# Working in this repository

This repository contains user dotfiles and local Ansible installation playbooks.

- Preserve unrelated working-tree changes. Do not deploy all configuration as a
  side effect of editing one component.
- User configuration lives under `user/`; installation playbooks and Just
  targets live under `playbooks/`.
- Pi configuration lives under `user/pi/`. Read `user/pi/README.md` before
  changing setup, permissions, agent definitions, or prompt templates.
- Pin Pi package versions. Preserve local settings, permission policies,
  authentication, and learned memory when updating installation code.
- Never commit credentials, live sessions, memory databases, or review logs.
- Prefer native Pi settings and prompt templates over custom runtime patches.
- Use agents for clearly scoped independent work. Background reviews are
  read-only and request-driven, not automatic on every edit. Keep concurrent
  writers in separate worktrees or serialize their edits.
- Write code, comments, documentation, and handoff briefs in normal prose,
  regardless of the conversational response style.

For Pi changes, run `bash -n user/pi/setup.sh`,
`python3 user/pi/tests/permissions-smoke.py`,
`python3 user/pi/tests/features-smoke.py`, and `git diff --check`.
These checks require the pinned packages to be installed. Run Ansible syntax
checks for changed playbooks; use isolated destinations for deployment tests.
Do not run `just update-all` or live deployment without user authorization.
