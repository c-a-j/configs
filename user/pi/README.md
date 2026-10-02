# Pi configuration

Install Pi first, then run:

```sh
bash user/pi/setup.sh            # Pinned packages, workflow prompts, and local defaults
bash user/pi/setup.sh --with-jev # Also install the optional Jev experiment
```

`just update-pi` from `playbooks/` runs the normal setup. Restart Pi or `/reload`
after installation. `PI_CODING_AGENT_DIR` is respected.

Packages are pinned: `pi-vim@0.14.2`, `@signalridge/pi-plan-mode@1.4.2`,
`pi-permission-classifier@0.5.2`, `@gotgenes/pi-permission-system@36.2.1`,
`@gotgenes/pi-subagents@21.9.1`, and `pi-hermes-memory@0.9.9`.
Setup also requires Python 3 to merge native tool settings.
Local permission and footer extensions are copied into Pi's standard `extensions/` directory: they do
not depend on this checkout or worktree remaining at the same path. Rerun setup
to update those copies. Normal setup does not uninstall an existing Jev extension.

Initial policies in `permissions/`, `subagents.json`, and
`hermes-memory-config.json` are copied **only if absent**. Runtime customizations
stay local and are not overwritten by setup. Templates, the reviewer definition,
local extensions, and the vendored Caveman skill are refreshed each run.
Credentials, sessions, device IDs, learned memory, databases, and logs must not
be committed.

## Native search and workflow prompts

Setup enables Pi's native `grep`, `find`, and `ls` through `defaultTools` in the
agent's `settings.json`. It preserves other settings and existing tool choices,
except explicit exclusions for these three approved tools. This avoids shell
commands for ordinary search and directory inspection. No custom tool extension
is needed. Project settings and CLI overrides can still change the selection.

```text
/review                  # Review staged, unstaged, and relevant untracked changes
/review error handling   # Focus the review
/handoff                 # Produce a brief to paste into a fresh session
/handoff remaining tests
```

`/review` gathers a read-only diff and launches the `reviewer` background agent
when available. The agent receives the supplied diff and relevant paths, not the
full conversation. It reports concrete findings with file and line references;
it does not edit files, execute shell commands, or run tests. Results arrive
asynchronously. The prompt falls back to a read-only review in the main agent
if subagents are unavailable. Reviews are **request-driven**, not a watcher
that automatically runs after every edit. This prompt is conversational guidance;
the child agent's explicit tool allowlist enforces its lack of mutation tools.

`/handoff` only produces text. It does not save files, compact, open a session,
or transfer live background agents. Finish or collect those agents before
switching sessions. No `/test-plan` prompt is installed, and the main thinking
level is unchanged.

## Subagents and background reviewers

The maintained `@gotgenes/pi-subagents` extension provides foreground and
background agents, parallel work, result retrieval, steering, and continuation
within the same parent session. Ask Pi to delegate a scoped task or use `/review`.

```text
/subagents:settings      # Project-level runtime settings
/subagents:sessions      # Read-only child session transcripts
```

Initial global settings in `subagents.json` limit concurrency to two and set a
20-turn default with two grace turns. Interrupting the parent aborts background
agents by default. `agents/reviewer.md` is restricted to `read`, `grep`, `find`,
and `ls`; its 12-turn limit, no-conversation-fork setting, and background mode
are locked against model tool-call overrides. The package may add grace turns
at the limit. The reviewer inherits the current model and thinking level.

Built-in general-purpose agents can edit and execute commands under the
existing permission extension. The permission extension is **not excluded**
from children. This is not an OS sandbox, and this setup supplies **no automatic
worktree isolation**: use separate worktrees or serialize edits for concurrent
writers. Agent definitions and trusted project settings can override defaults.

Memory is excluded from children using the exact pinned package source string
in `excludedExtensionPackages`. Update that string when changing the memory
package version, or child sessions can start learning independently.

## Automatic memory

`pi-hermes-memory` maintains local Markdown notes, project memory, and a SQLite
full-text index of memories and Pi sessions. Initial configuration uses a compact
retrieval policy instead of injecting the complete notes into every request.
It reviews recent context after 20 turns or 30 tool calls, detects corrections,
and flushes useful context before compaction. Session-exit flushing and standing
instruction injection are disabled. Background learning can write local memory
without an interactive approval for each write.

```text
/memory-insights         # Inspect stored notes; no model call
/memory-preview-context  # Inspect the memory context policy
```

Global stores live under `~/.pi/agent/pi-hermes-memory/`, including `MEMORY.md`,
`USER.md`, failure notes, generated skills, and `sessions.db`. Project stores
live under `~/.pi/agent/projects-memory/`. All paths follow
`PI_CODING_AGENT_DIR`. The initial 30-day retention applies to the extension's
indexed sessions, **not** Pi's original session files.

**Privacy and cost:** automatic learning and subagents make additional model
calls using existing Pi authentication. Memory helpers use the current model
unless you configure an override. Recent conversation content is sent to the
model provider for learning; stored notes and searchable history may contain
sensitive information. Secret scanning is not a guarantee. Keep these directories
private, inspect learned entries, and never commit them. Setup creates new default
memory roots with mode `0700`; it does not change permissions on existing or
custom memory directories. The tool-call permission
gate is not a sandbox for extension-managed background calls or persistence.

Edit `hermes-memory-config.json` in the agent directory and reload to change
learning frequency or model settings. To disable the extension entirely:

```sh
pi remove npm:pi-hermes-memory@0.9.9
```

Restart Pi afterwards. This removes the package, not learned data; rerunning
setup installs it again. On Node-based Pi installations, SQLite depends on the
native `better-sqlite3` module and may require a rebuild after Node upgrades.
The compiled Bun-based Pi uses Bun's SQLite instead.

## Vim

The prompt starts in INSERT mode. `Esc` enters NORMAL; `i` returns to INSERT.
Use `hjkl`, `w/b/e`, `gg/G`, `dw`, `ciw`, `v/V`, `u`, `Ctrl+r`, and `.` as usual.
An additional `Esc` in NORMAL passes through to Pi. This is not full Vim:
search/macros/named registers are absent and visual selections are not highlighted.

## Planning

`/plan` opens the planning menu. `/plan start` enters directly; `/plan <prompt>`
starts planning with a task. Inspection and restricted bash are allowed;
implementation requires explicit approval. Useful commands:

- `/plan show`, `/plan finalize`, `/plan save`
- `/plan export [path]` (Markdown, no overwrite)
- `/plan implement` (implement here), `/plan exit` (leave/clear)

The menu also supports fresh-session implementation. An approved plan stays active
through compaction until cleared. Planning is an independent guardrail even in
YOLO, not an OS sandbox. Explicit plan export is a user-requested file mutation.

The pinned planning package declares Pi 0.x peers. It loads on Pi 1.0.0, but the
full interactive approval/handoff workflow has not been verified end to end.

## Teaching

`/teach [topic]` asks Pi to act as a coding tutor: short examples, explanations of
how the code works, and one step at a time. You type the code and run commands;
Pi waits for your result before continuing. It may inspect code with read-only
tools, but is instructed not to change files or execute commands.

```text
/teach build a small Python CLI
/teach explain the code in this project
/teach off
```

This uses Pi's native prompt template in `prompts/teach.md`, copied by setup. No
additional package or custom extension is needed. It changes conversational
behavior, not permissions: it is **not** an enforced read-only mode. It does not
change global settings, but its instructions remain part of the conversation
when you resume it. `/teach off` explicitly ends teaching.

## Caveman

Only the core [upstream Caveman skill](https://github.com/JuliusBrussee/caveman)
is included, copied verbatim from commit
`b39c90862855ad2f0813ce775b8bf07a9d6d2a50`. Its licenses, notice, source, and hash
are preserved in `skills/caveman/`. Setup copies it into the agent's standard
skills directory; no Caveman CLI, proxy, executable extension, or other skills
are installed. Updates are explicit, not fetched during setup.

```text
/skill:caveman        # Full style by default
/skill:caveman lite   # Concise, normal sentences; recommended with /teach
/skill:caveman ultra  # Maximum terseness
/skill:caveman off    # Return to normal prose
```

Pi uses `/skill:caveman`, not upstream's `/caveman` shorthand. The skill changes
reply style for the conversation, not global settings or permissions. It keeps
code and exact errors intact and prioritizes clarity for warnings. It does not
compress input or internal reasoning, and token savings are not guaranteed.

## Permissions

A **fresh** setup defaults to Auto:

| Command | Behavior |
| --- | --- |
| `/manual` | In-project inspection tools are allowed. Edits, writes, all bash commands, unfamiliar tools, sensitive paths, and outside-project access ask you unless a rule/session grant permits them. |
| `/auto` | The same policy, with GPT-4.1 Mini reviewing eligible asks. Benign actions may proceed; uncertain ones prompt; prohibited ones are blocked. Reviewer failures defer to you. Sensitive-path/outside-project asks stay human decisions. |
| `/yolo` | No permission-approval prompts or reviewer calls. Explicit deny rules, if added, still block. |
| `/permissions` | Show/select a mode. `/permissions manual`, `auto`, or `yolo` also work. |

**These controls are global, persistent, and idle-only—not Claude Code-style
session-local hot switches.** Changes reload the invoking session and clear its
in-memory approvals. Other sessions pick up the global config on refresh. YOLO
remains selected for later sessions until changed; `/auto` restores Auto. Trusted project config/agent
frontmatter can override global policy; the footer reports global configuration,
not those overrides, and other running sessions' indicators can be stale.

A mode command during a run returns immediately **without changing anything**.
To change modes now: interrupt the run, use `/auto` (or another mode), then ask
the agent to continue. Seamless mid-run switching is not implemented; it needs
native runtime support rather than another config-file workaround.

The classifier package's `judge:...` footer names its configured reviewer, not
whether review is active. It can appear in Manual or YOLO even though neither
mode calls it.

`/permission-model` changes the GPT reviewer independently of the coding model.
Its initial setting is `openai/gpt-4.1-mini`, with a 10-second timeout, using Pi's
existing authentication. Review sends request facts, visible command context, and
trusted guidance to the model provider; it is not full code review or a sandbox.

Policies live in `extensions/pi-permission-system/config.json` under the agent
directory; the GPT configuration is in `extensions/pi-permission-classifier/`.
Mode selection replaces `authorizerChain`, not permission rules. The policy has no
broad bash allowlist. Headless asks without an approval UI are denied. User-entered
`!` commands and explicit extension commands are not model tool calls and are not
governed by this tool-call gate. Logs can contain commands/input previews: treat
`extensions/pi-permission-system/logs/` as sensitive.

## Optional: Jev shadow review

Jev is **not Auto mode** yet. Install with `--with-jev`, authenticate using
`/login vercel-ai-gateway` and an AI Gateway API key, then reload:

```text
/jev-status  # Model and link registration; no model call
/jev-test    # One potentially billable classification of pwd; never executes it
/jev-shadow  # Manual approvals plus Jev recommendations (global, idle only)
/manual      # Manual without review
/auto        # Actual automatic review using GPT, not Jev
```

The model is `vercel-ai-gateway/typesafe-ai/jev`. Config is
`extensions/jev-reviewer/config.json` under the agent directory: 10-second timeout,
8 KiB request-state budget. All Jev recommendations **always defer to you**, even
confident benign results. There is no live-approval switch, automatic denial, or
silent GPT fallback. Path/outside-project asks skip Jev entirely.

Eligible requests send structured facts and complete evidence to Vercel, not the
conversation or fetched file contents. Evidence itself can contain secrets.
`jev.shadow` review-log entries record recommendations/probabilities, model/rubric,
latency, request ID, and state size/hash—not raw evidence. Compare request IDs with
your actual decisions before considering live approval authority.

The initial live test reached Vercel but returned HTTP 403
`customer_verification_required`. Vercel required a card on file for Gateway
access/free credits. Complete that verification and rerun `/jev-test`. Successful
live judgments and their quality have not yet been validated.

## Checks and footer colors

```sh
node --test user/pi/tests/jev-reviewer.test.mjs
python3 user/pi/tests/permissions-smoke.py
python3 user/pi/tests/features-smoke.py
```

These tests make no model calls or live policy changes. They cover shadow safety,
real gate approval/denial, reviewer-failure fallback, mode naming, busy-mode
rejection, settings preservation, feature discovery, parsed reviewer restrictions,
and isolated Markdown/SQLite memory storage and search. Automatic learning is
disabled in the memory test. They do **not** establish classifier or review
accuracy, live model-backed delegation/learning, OS isolation, live hot switching,
or the complete interactive planning workflow.

Setup installs `extensions/footer-colors.ts` as a regular file: green path, red
git branch, with Pi's other footer information unchanged. It replaces old
symlinks so deleting a setup worktree cannot silently disable the colors.
Restart Pi or `/reload` after updating the installed extension.
