# Pi configuration

This directory is the source of truth for the Pi setup. [`setup.sh`](setup.sh)
deploys it into the agent directory: `PI_CODING_AGENT_DIR`, or `~/.pi/agent`
when unset.

## Rule: edit the repository, never `~/.pi`

**Every configuration change is made in this directory and committed. Do not
create, edit, or delete managed files under `~/.pi/agent` directly.** This
applies to people and to agents.

This repository exists to keep several machines consistent. A change made only
in `~/.pi/agent` exists on one machine, is invisible to git, never reaches the
others, and is overwritten the next time setup runs. A change made here reaches
every machine through `git pull` and `just update-pi`.

| To change | Edit here | Not here |
| --- | --- | --- |
| Theme, tools, package pins | `user/pi/settings.json` | `~/.pi/agent/settings.json`, `pi install` |
| Permission policy | `user/pi/permissions/config.json` | `~/.pi/agent/extensions/pi-permission-system/config.json` |
| Extensions, prompts, skills, agents | `user/pi/{extensions,prompts,skills,agents}/` | The same directories under `~/.pi/agent` |
| Global instructions, key bindings, subagent and memory settings | The files in `user/pi/` | The same filenames under `~/.pi/agent` |

The workflow is always:

1. Edit the file under `user/pi/`, in place.
2. Run `just update-pi` if you added a file, changed `settings.json`, or changed
   a package pin. Edits to already linked files are live immediately.
3. `/reload` or restart Pi, verify, and commit.

If something in `~/.pi/agent` is wrong, the fix belongs in the source file here
or in `setup.sh`, not in the installed copy. If a change was already made
directly in `~/.pi/agent`, move it into this directory before doing anything
else; otherwise the next setup run discards it.

The only things that legitimately live in `~/.pi/agent` alone are private or
machine-local state: credentials, sessions, learned memory, logs, caches,
installed package files, and the temporary permission mode selected with
`/manual`, `/auto`, or `/yolo`. None of that is committed.

## Exception: model choices are per machine

Machines use different model providers (a personal subscription at home, a
company gateway at work), so which models Pi uses is **not** shared. The
repository supplies first-install defaults only, and setup never overwrites a
machine's own choice:

| What | Repository default | Change it on a machine with |
| --- | --- | --- |
| Startup provider, model, thinking level, model cycle | [`model-defaults.json`](model-defaults.json) | `/model`, `/thinking`, `/scoped-models` (Ctrl+S saves) |
| Model that reviews asks in `/auto` | [`permissions/classifier.json`](permissions/classifier.json) | `/permission-model` |
| Custom endpoints, such as a company gateway | None; never tracked | `models.json` in the agent directory |
| Credentials | None; never tracked | `/login` |

Setup never reads or writes the agent directory's `models.json` or `auth.json`.
On a new machine, set these once after the first `just update-pi`; later runs
leave them alone. `/auto-jev` and `/auto-clef` need Cloudflare Workers AI and
are simply unused where that is not available.

## Installation

Install Pi and `jq` first, then run from the repository root:

```sh
just update-pi   # Same as: bash user/pi/setup.sh
```

Setup works on a new machine and on one with an outdated configuration. It does
three things:

1. **Hard links** every managed file into the agent directory. Edit files here,
   in place, and the change is live after `/reload`; there is no need to rerun
   setup. Files are copied instead when the repository and agent directory are
   on different filesystems.
2. **Merges** [`settings.json`](settings.json) into the installed
   `settings.json` with `jq`. Repository keys win; keys that only exist locally,
   such as `deviceId`, are kept. This file is merged rather than linked because
   Pi rewrites it.
3. **Installs pinned packages** listed under `packages` in
   [`settings.json`](settings.json), skipping those already installed at the
   pinned version. A repeat run makes no network calls.

Rerun setup after anything that replaces files instead of editing them in
place, because that breaks the hard links: `git pull`, `git checkout`, adding a
new file here, or a `/manual`, `/auto`, or `/yolo` mode change (which rewrites
the installed permission policy and never touches the repository copy). Each
run links the repository versions again, replacing modified installed copies
and old symlinks.

Setup never deletes anything. Credentials, sessions, installed packages, learned
memory, logs, and unmanaged extensions, prompts, and skills in the agent
directory are left alone. It does not install or update the Pi host itself, run
the Ansible playbooks, or touch other dotfiles. Never commit private runtime
state.

### Managed files

Paths on the right are relative to the agent directory:

| Repository source | Installed destination |
| --- | --- |
| [`AGENTS.md`](AGENTS.md), [`keybindings.json`](keybindings.json), [`subagents.json`](subagents.json), [`hermes-memory-config.json`](hermes-memory-config.json) | Same filenames |
| [`agents/`](agents/), [`prompts/`](prompts/), [`skills/`](skills/), [`extensions/`](extensions/) | Same paths; every file is linked |
| [`permissions/config.json`](permissions/config.json) | `extensions/pi-permission-system/config.json` |
| [`settings.json`](settings.json) | `settings.json` (merged, not linked; repository wins) |
| [`model-defaults.json`](model-defaults.json) | `settings.json` (merged; the machine's own values win) |
| [`permissions/classifier.json`](permissions/classifier.json) | `extensions/pi-permission-classifier/config.json` (copied only if absent) |

To add a prompt, skill, agent, or extension, put it in the matching directory
and rerun setup. To change a package, edit its pin in `settings.json` and rerun
setup. Removing a pin stops Pi from loading the package; it does not delete the
installed files. To remove a managed file, delete it here and add its installed
path to the `rm -f` line in `setup.sh`, so other machines drop it too.

New memory roots are created with mode `0700`, but learned files are not seeded
from this checkout.

## What is configured

Package pins live only in [`settings.json`](settings.json). Each package's own
documentation is the reference for its behavior; this table records only what
this setup adds or chooses.

| Feature | Source | Use |
| --- | --- | --- |
| Global instructions, terse reply style | [`AGENTS.md`](AGENTS.md); [`skills/caveman/`](skills/caveman/) for other levels | Automatic; "normal mode" for full prose; `/skill:caveman lite` or `ultra` to change level |
| Permission modes | [`extensions/permission-modes.ts`](extensions/permission-modes.ts), [`permissions/`](permissions/), `pi-permission-system`, `pi-permission-classifier` | `/manual`, `/auto`, `/yolo`, `/permissions`, `/permission-model` |
| Review | [`prompts/review.md`](prompts/review.md), [`agents/reviewer.md`](agents/reviewer.md), `pi-subagents` | `/review [focus]`; read-only background agent |
| Teaching | [`prompts/sensei.md`](prompts/sensei.md) | `/sensei [guide\|show] [topic]`, `/sensei off` |
| Design interview | [`prompts/grill-me.md`](prompts/grill-me.md), [`skills/grill-me/`](skills/grill-me/) | `/grill-me [topic]` |
| Vim editing and scrolling | `pi-vim`, [`extensions/vim-scroll.ts`](extensions/vim-scroll.ts) | Ctrl+k / Ctrl+j scroll a quarter page in NORMAL mode, fullscreen TUI only |
| List navigation keys | [`keybindings.json`](keybindings.json) | Ctrl+k / Ctrl+j move in selection lists |
| Footer colors | [`extensions/footer-colors.ts`](extensions/footer-colors.ts) | Green path, red git branch |
| Handoff | `pi-handoff` | `/handoff <goal>`; run while idle |
| Planning | `pi-plan-mode` | `/plan` |
| Memory | `pi-hermes-memory`, [`hermes-memory-config.json`](hermes-memory-config.json) | Automatic; `/memory-insights` |
| Subagents | `pi-subagents`, [`subagents.json`](subagents.json) | Automatic; `/subagents:settings` |
| Web and library docs | `pi-web-access`, `context7-pi` | Automatic; `/websearch`, `/c7-docs` |
| Diagnostics | `pi-lens` | Automatic; `/lens-health` |
| Classifier-model permission review | [`extensions/model-review/`](extensions/model-review/) | `/auto-jev`, `/auto-clef`, `/jev-test`, `/clef-test` |

## Things to know

- **Permission modes are global and persistent, and switch only while idle.**
  Manual asks for edits, writes, and bash. Auto sends eligible asks to the
  classifier model configured in `permissions/classifier.json`; failures fall
  back to asking you. YOLO skips prompts but explicit deny rules still block.
  Setup resets the mode to the repository default, Auto.
- **None of this is a sandbox.** Permission rules gate model tool calls only.
  Extensions, `!` commands, and background helpers run outside that gate.
- **The permission review log is never rotated.** The permission package has no
  rotation setting. The log is
  `extensions/pi-permission-system/logs/*.jsonl` under the agent directory, can
  contain command previews, and is safe to delete. Set `permissionReviewLog` to
  `false` in `permissions/config.json` to stop it.
- **`subagents.json` repeats the memory package pin** in
  `excludedExtensionPackages`, which keeps subagents from learning on their own.
  It must match the pin in `settings.json` exactly; the setup test fails if it
  does not.
- **Memory, web search, subagents, and the classifier make extra model calls**
  and send conversation content to the model provider. Learned memory lives in
  `pi-hermes-memory/` and `projects-memory/` under the agent directory and is
  never committed.
- **`footer-colors.ts` wraps Pi's built-in footer renderer** because Pi has no
  theme tokens for the path and branch. If a Pi update changes the footer, the
  colors may be wrong; the footer content itself is unaffected.
- **`/auto-jev` and `/auto-clef` let a small classifier model approve permission asks.**
  The model labels each ask benign, risky, or unknown. A benign label with at
  least 80% confidence is approved without a prompt; anything else, and every
  failure, asks you. The model never denies. Sensitive-path and outside-project
  asks always go to you. The two modes differ only in the model: Jev draws on
  prepaid Cloudflare credits, clef runs within the free daily Workers AI
  allowance. Each review is a `model-review.decision` entry in the permission
  review log, whose `reviewer` field names the model and whose `requestId`
  matches the package's own entries for the same ask. The models, threshold,
  timeout, and rubric are constants in `extensions/model-review/core.ts`. Both
  need `/login` for Cloudflare Workers AI on each machine; `/jev-test` and
  `/clef-test` each make one real call to check access.
- **Vendored skills are pinned copies.** Each `UPSTREAM.md` records the source
  commit and hashes; setup never fetches updates.

## Checks

Run from the repository root. The tests use temporary directories and never
touch the live agent directory.

```sh
bash -n user/pi/setup.sh
python3 user/pi/tests/setup-smoke.py
node --test user/pi/tests/model-review.test.mjs
git diff --check
```
