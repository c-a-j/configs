# Pi configuration

This directory contains the repository-managed Pi setup. [`setup.sh`](setup.sh)
is the source of truth for package pins, copied resources, and initial defaults.
The installed agent directory is separate: `PI_CODING_AGENT_DIR`, or
`~/.pi/agent` when unset. Existing runtime settings can differ because setup
preserves them. The feature sections below describe the repository setup;
they do not imply that every resource has already been deployed.

## Current installation

The on-disk installation checked on **2026-10-03** uses Pi **1.0.1**. Its ten
configured packages and installed versions match the pins listed below.
The following are local runtime settings, not defaults imposed by this repository:

- `settings.json` selects `openai/gpt-6.1-sol` with `high` thinking. Its model
  scope is `openai/gpt-6.1-sol`, `openai/gpt-6-astra`, `openai/gpt-6-luna`, and
  `openai/gpt-6-sol`.
- The theme is `system`, the TUI is `fullscreen`, and `defaultTools` is
  `["+grep", "+find", "+ls"]`, retaining Pi's default read/bash/edit/write tools.
- The permission policy is currently **YOLO** (`yoloMode: true`,
  `authorizerChain: []`), not the fresh setup's Auto mode. The classifier is
  configured as `openai/gpt-4.1-mini`, but YOLO does not call it.
- Subagent settings, memory settings, the reviewer, `/review`, `/grill-me`,
  permission-mode controls, and footer colors match the repository copies.
  The optional Jev extension and its initial configuration are also present.
- `/handoff` is installed. `extensions/chain.ts` and `prompts/sensei.md` are
  **not installed**, so `/chain` and `/sensei` are not supplied by this setup
  in the current agent directory. The exact retired `/teach` prompt remains.
  Running setup would install `/chain` and `/sensei` and remove that legacy copy.
- The installed global `AGENTS.md` contains only the Caveman default-style
  instructions. The repository's broader agent guidelines have not been merged;
  setup deliberately preserves an existing global file.
- Local resources outside this setup include `extensions/workmux-status.ts`,
  Workmux workflow skills, and native list navigation bindings: Up/Ctrl+k and
  Down/Ctrl+j. `settings.json` explicitly includes the footer extension and the
  local `open-pr` skill. No user or project pi-lens config file was found at
  `~/.pi-lens/config.json` or `.pi-lens.json` in this checkout.

This is a snapshot of files, not a guarantee about every running session.
Project overrides, CLI flags, and later local changes can alter behavior. This
README update does not deploy resources or change the live settings above.

## Installation

Install Pi first, then run from the repository root:

```sh
bash user/pi/setup.sh            # Pinned packages, workflow prompts, and local defaults
bash user/pi/setup.sh --with-jev # Also install the optional Jev experiment
```

`just update-pi` uses the repository-root [`justfile`](../../justfile) and runs
the normal setup. It does not run the Ansible playbooks or update other dotfiles.
Setup installs extension packages, not the Pi host itself. Restart Pi or `/reload`
after installation. `PI_CODING_AGENT_DIR` is respected.

Packages are pinned: `pi-vim@0.14.2`, `@signalridge/pi-plan-mode@1.4.2`,
`@ar-llm/pi-handoff@0.5.0`, `pi-permission-classifier@0.5.2`,
`@gotgenes/pi-permission-system@36.2.1`,
`@gotgenes/pi-subagents@21.9.1`, `pi-hermes-memory@0.9.9`,
`pi-web-access@0.35.0`, `@upstash/context7-pi@0.1.2`, and `pi-lens@4.3.0`.
Setup also requires Python 3 to merge native tool settings.
Local permission, footer, and chain extensions are copied into Pi's standard `extensions/` directory: they do
not depend on this checkout or worktree remaining at the same path. Rerun setup
to update those copies. Normal setup does not uninstall an existing Jev extension.

Initial policies in `permissions/`, `subagents.json`,
`hermes-memory-config.json`, and global `AGENTS.md` instructions are copied
**only if absent**. Runtime customizations
stay local and are not overwritten by setup. Templates, the reviewer definition,
core local extensions, and the vendored Caveman and Grill Me skills are refreshed
each run. Existing Jev extension sources are refreshed only with `--with-jev`.
Setup preserves model selection, thinking levels, keybindings, custom resources,
and personal web settings; it merges only the native search-tool selection.
Credentials, sessions, device IDs, learned memory, databases, and logs must not
be committed.

### Configuration files

Paths on the right are relative to the installed agent directory:

| Repository source | Installed destination | Setup behavior |
| --- | --- | --- |
| [`permissions/config.json`](permissions/config.json) | `extensions/pi-permission-system/config.json` | Copy only if absent |
| [`permissions/classifier.json`](permissions/classifier.json) | `extensions/pi-permission-classifier/config.json` | Copy only if absent |
| [`permissions/jev.json`](permissions/jev.json) | `extensions/jev-reviewer/config.json` | Copy only if absent, with `--with-jev` |
| [`subagents.json`](subagents.json), [`hermes-memory-config.json`](hermes-memory-config.json), [`AGENTS.md`](AGENTS.md) | Same filenames | Copy only if absent |
| [`agents/reviewer.md`](agents/reviewer.md) | `agents/reviewer.md` | Refresh each run |
| [`prompts/`](prompts/) | `prompts/{review,sensei,grill-me}.md` | Refresh each run |
| [`extensions/`](extensions/) core `.ts` files | `extensions/{permission-modes,footer-colors,chain,vim-scroll}.ts` | Refresh each run |
| [`extensions/jev-reviewer/`](extensions/jev-reviewer/) sources | `extensions/jev-reviewer/{index.ts,core.mjs,package.json}` | Refresh with `--with-jev` |
| [`skills/`](skills/) | `skills/{caveman,grill-me}/` | Refresh each run |

There is no repository `settings.json` or `keybindings.json` to deploy. Pi manages
package declarations in the installed `settings.json`; setup merges its
`defaultTools`. New memory roots are created privately, but learned files are
not seeded from this checkout.

Fresh global instructions also require user authorization before implementation
or deployment, scoped delegation, preservation of local configuration and learned
memory, and no agent attribution or signature trailers in commits. These are
conversational instructions, not enforced permission rules. Existing global
instructions require a deliberate manual merge to adopt these changes.

## Native search and workflow commands

Setup enables Pi's native `grep`, `find`, and `ls` through `defaultTools` in the
agent's `settings.json`. It preserves other settings and existing tool choices,
except explicit exclusions for these three approved tools. This avoids shell
commands for ordinary search and directory inspection. No custom tool extension
is needed. Project settings and CLI overrides can still change the selection.

```text
/review                  # Review staged, unstaged, and relevant untracked changes
/review error handling   # Focus the review
/handoff finish the remaining tests  # Review a summary, switch, and continue
```

`/review` gathers a read-only diff and launches the `reviewer` background agent
when available. The agent receives the supplied diff and relevant paths, not the
full conversation. It reports concrete findings with file and line references;
it does not edit files, execute shell commands, or run tests. Results arrive
asynchronously. The prompt falls back to a read-only review in the main agent
if subagents are unavailable. Reviews are **request-driven**, not a watcher
that automatically runs after every edit. This prompt is conversational guidance;
the child agent's explicit tool allowlist enforces its lack of mutation tools.

### Handoff

The maintained [`@ar-llm/pi-handoff`](https://github.com/arichiardi/ar-llm/tree/main/extensions/pi-handoff)
extension replaces our old text-only prompt. In interactive Pi, run
`/handoff <goal for the next session>`; a goal is required. It summarizes the
active branch (including relevant compaction context), opens a review editor,
then creates a fresh session linked to the original and **automatically submits
the edited summary**. Accepting the editor starts work in the new session; it
is not just a clipboard brief or an unsent draft. The original remains available
through `/resume`.

Run handoff **while idle**, after finishing or collecting background agents.
The extension does not wait for idle or transfer agents, and session shutdown
aborts subagents. Generation failure, empty model output, or cancellation before
switching leaves the original session active. The pinned version mislabels review
editor cancellation as an editor error, but does not switch. Session replacement
failures have no guaranteed rollback. This is not a transactional workflow.

Summary generation makes an additional model call using the active model and
Pi authentication by default; the selected conversation is sent to that provider.
Review the summary for secrets, constraints, test results, and unfinished work
before accepting it. Setup adds no custom runtime patch or handoff configuration.
It removes only the exact legacy `prompts/handoff.md`; locally edited copies are
preserved, but the extension command takes precedence. Rename a custom copy if
you want to keep using it as a separate prompt command.

No `/test-plan` prompt is installed, and the main thinking level is unchanged.

### Group a task and handoff

The local `extensions/chain.ts` extension adds an explicit workflow command:

```text
/chain Update .plans/init.md with our decisions then /handoff Continue inserting models in teaching mode.
```

The separator can also start a new line:

```text
/chain Update .plans/init.md with our decisions.
then /handoff Continue inserting models in teaching mode.
```

Chain submits the ordinary task first. It waits for Pi's final `agent_settled`
notification, including automatic continuations, before dispatching the installed
`/handoff` extension. The usual summary editor remains mandatory; accepting the
summary creates a fresh session and starts the continuation. Chain does not
replace the maintained handoff implementation or change permissions.

This first version supports **one ordinary task and one terminal `/handoff`**,
not arbitrary command pipelines, shell syntax, or recursive chains. The exact
`then /<command>` pattern is reserved syntax even inside quotes or Markdown;
avoid it in the task or goal except for the handoff separator. Neither task nor
goal may begin with a slash command. Describe teaching mode in the goal instead
of appending `/sensei` or `/learn`. Commands embedded in other ordinary messages
still do not execute.

Start while idle, with no queued messages. A second chain is rejected while one
is pending. Model errors, aborts, truncated responses, new user input, other user
messages entering the run, transformed tasks, session shutdown, and tree
navigation prevent the pending handoff. New input cancels the chain, not the
ongoing task. `/chain status` reports whether a handoff is pending;
`/chain cancel` removes that pending handoff without aborting the task. Cancel
before invoking another session-changing command yourself. If prompt preflight
fails or another extension consumes the task without running it, use
`/chain cancel` before retrying.

Normal model completion is **not proof that the requested work succeeded**.
Review the summary for unanswered questions, failed tests, or incomplete work.
Chain does not collect or transfer background agents; have the initial task
collect their results before finishing. Handoff cancellation, provider failures,
and session-switch failures retain the pinned extension's documented behavior.

Chain requires interactive Pi **1.0.1** or newer with deferred message dispatch
from `agent_settled`. The offline SDK test verifies the pinned handoff on 1.0.1;
future host versions still need compatibility checks. This extension adds no
model call beyond the initial task and the handoff's existing summary and
continuation calls.

## Web research and library documentation

The maintained [Pi Web Access](https://github.com/nicobailon/pi-web-access)
package provides web search, page extraction, source checking, and stored-result
retrieval. The official [Context7 extension](https://github.com/upstash/context7/tree/master/packages/pi)
provides current library documentation and examples. No custom web extension or
MCP adapter is installed, and Interactive Shell is not included.

Ask Pi to research a topic or retrieve documentation for the library version you
use. Context7's bundled skill prefers its documentation tools over general web
search for library-specific questions. Explicit entry points are also available:

```text
/c7-docs next.js How do Cache Components work?
/skill:context7-docs
/websearch              # Web Access configuration UI
```

Context7 registers `resolve-library-id` and `query-docs`. Web Access registers
`web_search`, `fetch_content`, `source_check`, and `get_search_content`; it may
activate these lazily through `web_enable`, depending on the model. The restricted
reviewer retains its existing read-only tool allowlist, without web tools.

Neither package requires a new API key to try its default service. Context7 uses
IP-based limits without a key; optionally export `CONTEXT7_API_KEY` for higher
quotas. Web Access supports keyless Exa search and eligible existing Pi Codex
authentication, as well as separately configured providers. Personal Web Access
settings live in `web-search.json` under the agent directory. Setup does not
create or overwrite that file, add credentials, or change provider routing.
Keep API keys outside this repository.

**Privacy and cost:** searches, documentation queries, and requested URLs leave
your machine. Do not include secrets, personal data, or proprietary code in
queries. Web Access defaults to its `none` workflow, without generated summaries
or the curator; explicit summary workflows and some providers can make additional
billable calls. Browser-cookie access and third-party hosted page extraction are
upstream opt-ins, not enabled by this setup. Existing personal configuration can
change these behaviors. Tool-call permissions still apply, but extensions are not
an OS or network sandbox, and fetched content is untrusted input.

## Code diagnostics and navigation

[`pi-lens`](https://github.com/apmantza/pi-lens) provides language-aware
diagnostics after edits, LSP navigation, symbol search, and structural analysis.
It also monitors read-before-edit and adds diagnostic tools and bundled skills.
No custom runtime patch or pi-lens configuration is installed by setup; existing
local configuration is preserved.

```text
/lens-health           # Runtime health and degraded checks
/lens-tools            # Language server and tool installation status
/lens-toggle           # Enable/disable pi-lens for this session
```

Upstream defaults enable diagnostics, context injection, related-test execution,
autoformatting, and autofixes. Formatting normally runs at the end of an agent
run; fixes can change written files immediately or edited files at run end.
Language servers, linters, and scanners may be downloaded automatically as needed
in trusted projects. These extension-managed subprocesses and file changes are
not an OS sandbox and are not individually gated by tool-call permissions.
The experimental commit/push guard is opt-in and is not enabled by setup.

Optional user settings live in `~/.pi-lens/config.json`; project overrides live
in `.pi-lens.json`. See upstream [settings](https://github.com/apmantza/pi-lens/blob/master/docs/settings.md)
for precedence and controls. For example, `--no-autoformat --no-autofix --no-tests`
disables automatic rewriting and related-test execution for one Pi invocation.
Some project settings can override global mutation defaults, but explicit
disabling CLI flags take precedence.

The isolated smoke test below checks command/tool registration using the Pi
executable on `PATH` and TypeScript symbol parsing without model calls, tool
downloads, or live settings changes. It does not validate the complete LSP fleet,
automatic fixers, or interactive rendering. The package's standalone self-test checks grammars in a
dependency directory rather than the bundled `grammars/` directory, so its
missing-grammar result alone does not establish a runtime parsing failure.

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

The local [`extensions/vim-scroll.ts`](extensions/vim-scroll.ts) extension adds
**Ctrl+k** (a quarter page up) and **Ctrl+j** (a quarter page down) in NORMAL
mode when Pi uses the fullscreen TUI. Each step uses one quarter of the current
terminal height, rounded down to at least one line. INSERT mode keeps native Ctrl+j newline
and Ctrl+k delete-to-line-end. Existing list-navigation bindings are unchanged;
focused dialogs and overlays retain their keys. VISUAL mode is not remapped.
In regular TUI mode, the terminal owns scrollback and these shortcuts are unchanged.

The extension decorates the installed pi-vim editor in place after all
`session_start` handlers, using `resources_discover` as the post-start lifecycle
hook. It calls Pi's public fullscreen `scrollBy()` method, without changing
`keybindings.json` or patching packages. Pi's stable renderer reference also
supports switching between regular and fullscreen modes. Pi-vim currently reports
its `:` EX mini-mode as NORMAL, so these shortcuts also scroll during EX input.
Do not bind native `tui.altScreen.lineUp`/`lineDown` directly to Ctrl+k/j: native
fullscreen bindings run before the editor and would override INSERT behavior.

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

The pinned planning package declares Pi 0.x peers. The installed host is Pi
1.0.1; the full interactive approval/handoff workflow has not been verified end
to end.

## Sensei

`/sensei [guide | show] [topic]` asks Pi to act as a coding tutor, one step at a
time. You type the code and run commands; Pi waits for your result before
continuing. It may inspect code with read-only tools, but is instructed not to
change files or execute commands.

- `guide` explains the goal, relevant concepts, file/location, and success
  criteria, then gives actionable instructions without solution code, diffs, or
  solution-shaped pseudocode. It reviews your attempt and explains problems
  without supplying replacement code.
- `show` explains each step, supplies short code examples, and explains the
  important lines. This is the default whenever `/sensei` has no explicit mode.

The selected mode stays active on subsequent ordinary messages until changed or
teaching ends. Switch modes without a topic to continue the current lesson rather
than restart it. Setup and verification command examples are allowed in both
modes, but `guide` must not hide implementation code inside commands. Asking for
solution code in `guide` prompts a mode-switch question rather than silently
changing modes. Active teaching instructions and the selected mode should be
preserved in conversation summaries.

```text
/sensei build a small Python CLI          # Defaults to show
/sensei guide build a small Python CLI    # Instructions without solution code
/sensei show                             # Demonstrate the current lesson step
/sensei guide                            # Continue without solution code
/sensei off
```

This uses Pi's native prompt template in `prompts/sensei.md`, copied by setup. No
additional package or custom extension is needed. It changes conversational
behavior, not permissions: it is **not** an enforced read-only mode. It does not
change global settings, but its instructions remain part of the conversation
when you resume it. `/sensei off` explicitly ends teaching.

The current Sensei template is self-contained and defines guide/show behavior,
learner-owned execution, small steps, and preservation of active teaching
instructions in conversation summaries. It does not contain an engineering
principles section. The permission smoke test still expects that section; see
[Checks and footer colors](#checks-and-footer-colors) for the known mismatch.

Sensei replaces the old `/teach` command; the teaching restrictions are unchanged. Setup
removes `prompts/teach.md` only when it exactly matches the former repository
template. Customized copies are preserved with a warning, so a local `/teach`
command may remain until you rename or remove that custom template yourself.

## Caveman

Only the core [upstream Caveman skill](https://github.com/JuliusBrussee/caveman)
is included, copied verbatim from commit
`b39c90862855ad2f0813ce775b8bf07a9d6d2a50`. Its licenses, notice, source, and hash
are preserved in `skills/caveman/`. Setup copies it into the agent's standard
skills directory; no Caveman CLI, proxy, executable extension, or other skills
are installed. Updates are explicit, not fetched during setup.

```text
/skill:caveman        # Full style by default
/skill:caveman lite   # Concise, normal sentences; recommended with /sensei
/skill:caveman ultra  # Maximum terseness
/skill:caveman off    # Return to normal prose
```

Pi uses `/skill:caveman`, not upstream's `/caveman` shorthand. Fresh setup installs
`user/pi/AGENTS.md` as native global instructions in the agent directory, so new
conversations start in **Caveman full** mode without a command. The instructions
ask the model to load the installed skill before its first conversational reply.
No startup model call or custom extension is added. Existing global `AGENTS.md`
files are preserved; merge the default-style instructions yourself if one exists.
An `AGENTS.override.md` can override global instruction discovery.

`/skill:caveman off` or "normal mode" restores normal replies for the current
conversation; the next new conversation defaults to full again. To change the
persistent default, edit the agent directory's `AGENTS.md`. Restart Pi or `/reload`
after changing it. Code, comments, documentation, and other durable text remain
in normal prose. This is conversational guidance, not a permission control. The
skill keeps exact errors intact and prioritizes clarity for warnings. It does not
compress input or internal reasoning; loading it adds input context, and net token
savings are not guaranteed.

## Grill Me

Matt Pocock's [Grill Me skill](https://skills.sh/mattpocock/skills/grill-me)
stress-tests a plan or design through an interview. It asks one question at a
time, recommends an answer, and inspects the codebase when it can resolve a
question without asking you.

```text
/grill-me                    # Discuss the current plan, or ask for a topic
/grill-me my caching design  # Start with a specific topic
/skill:grill-me              # Pi's native skill command
```

The self-contained upstream skill and MIT license are vendored verbatim from
commit `383b6a06d59c4ce0ffcb14112bfd91265a86cf91` in `skills/grill-me/`, with
source and SHA-256 hashes in `UPSTREAM.md`. Setup copies them into Pi's standard
skills directory. The native `prompts/grill-me.md` template provides the short
command by asking the model to load that skill. No executable extension, skill
collection, or runtime patch is installed, and setup does not fetch updates.
This is conversational guidance, not a permission or read-only enforcement mode.

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

Run these checks from the repository root after installing the pinned packages:

```sh
bash -n user/pi/setup.sh
node --test user/pi/tests/jev-reviewer.test.mjs
python3 user/pi/tests/permissions-smoke.py
python3 user/pi/tests/features-smoke.py
node user/pi/tests/handoff-smoke.mjs
node user/pi/tests/chain-smoke.mjs
node user/pi/tests/vim-scroll-smoke.mjs
python3 user/pi/tests/lens-smoke.py
git diff --check
```

**Current check status:** `bash -n user/pi/setup.sh` and
`python3 user/pi/tests/features-smoke.py` pass on the installed Pi 1.0.1 host.
`python3 user/pi/tests/permissions-smoke.py` fails at line 94 with
`AssertionError: Keep principles directly in the prompt`: it requires a
`## Engineering principles` section that is absent from `prompts/sensei.md`.
The failure occurs before the runtime gate checks. The template and test need
to be reconciled before claiming those permission checks pass.

These tests make no model calls or live policy changes. Their intended coverage
includes shadow safety, real gate approval/denial, reviewer-failure fallback,
mode naming, busy-mode
rejection, settings preservation, feature discovery (including Web Access and Context7
registration without network calls), parsed reviewer restrictions,
isolated Markdown/SQLite memory storage and search, and real Pi session
replacement/continuation with a mocked handoff model. Handoff checks also cover
compaction context, cancellation, empty output, provider errors, and switch vetoes.
Chain checks exercise real task settlement and fresh-session handoff, automatic
continuations, busy rejection, explicit cancellation, new and queued input,
interrupted/failed/truncated tasks, transformed or consumed input, summary/editor
failures, missing handoff, unsupported modes, and syntax validation. They use
mocked models and a mocked terminal UI, not a real interactive terminal.
Automatic learning is disabled in the memory test. They do **not** establish
classifier or review accuracy, live model-backed delegation, learning or handoff,
OS isolation, live hot switching, live search/documentation retrieval, or the
complete interactive planning workflow.
The handoff and chain SDK tests need a Node-based Pi host; set `PI_TEST_HOST_DIR`
to the `@earendil-works/pi-coding-agent` package directory for non-managed
installations. Chain defaults to the managed 1.0.1 host; the older handoff test
defaults to 1.0.0.

Setup installs `extensions/footer-colors.ts` as a regular file: green path, red
git branch, with Pi's other footer information unchanged. It replaces old
symlinks so deleting a setup worktree cannot silently disable the colors.
Restart Pi or `/reload` after updating the installed extension.
