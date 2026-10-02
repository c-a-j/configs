# Pi configuration

Install Pi first, then run:

```sh
bash user/pi/setup.sh            # Vim, planning, Manual/Auto/YOLO permissions
bash user/pi/setup.sh --with-jev # Also install the optional Jev experiment
```

`just update-pi` from `playbooks/` runs the normal setup. Restart Pi or `/reload`
after installation. `PI_CODING_AGENT_DIR` is respected.

Packages are pinned: `pi-vim@0.14.2`, `@signalridge/pi-plan-mode@1.4.2`,
`pi-permission-classifier@0.5.2`, and `@gotgenes/pi-permission-system@36.2.1`.
Local permission extensions are copied into Pi's standard `extensions/` directory: they do
not depend on this checkout or worktree remaining at the same path. Rerun setup
to update those copies. Normal setup does not uninstall an existing Jev extension.

Initial policies in `permissions/` are copied **only if absent**. Runtime changes
stay local and are not overwritten by setup. Credentials, sessions, device IDs,
installed packages, and logs must not be committed.

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

## Permissions

A **fresh** setup defaults to Manual:

| Command | Behavior |
| --- | --- |
| `/manual` | In-project inspection tools are allowed. Edits, writes, all bash commands, unfamiliar tools, sensitive paths, and outside-project access ask you unless a rule/session grant permits them. |
| `/auto` | The same policy, with GPT-4.1 Mini reviewing eligible asks. Benign actions may proceed; uncertain ones prompt; prohibited ones are blocked. Reviewer failures defer to you. Sensitive-path/outside-project asks stay human decisions. |
| `/yolo` | No permission-approval prompts or reviewer calls. Explicit deny rules, if added, still block. |
| `/permissions` | Show/select a mode. `/permissions manual`, `auto`, or `yolo` also work. |

**These controls are global, persistent, and idle-only—not Claude Code-style
session-local hot switches.** Changes reload the invoking session and clear its
in-memory approvals. Other sessions pick up the global config on refresh. YOLO
remains selected for later sessions until changed. Trusted project config/agent
frontmatter can override global policy; the footer reports global configuration,
not those overrides, and other running sessions' indicators can be stale.

A mode command during a run returns immediately **without changing anything**.
To change modes now: interrupt the run, use `/auto` (or another mode), then ask
the agent to continue. Seamless mid-run switching is not implemented; it needs
native runtime support rather than another config-file workaround.

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

## Checks and optional visuals

```sh
node --test user/pi/tests/jev-reviewer.test.mjs
python3 user/pi/tests/permissions-smoke.py
```

These tests make no model calls or live policy changes. They cover shadow safety,
real gate approval/denial, reviewer-failure fallback, mode naming, and busy-mode
rejection. They do **not** establish classifier accuracy, OS isolation, live hot
switching, or the complete interactive planning workflow.

The optional footer-color customization in `extensions/footer-colors.ts` is
independent of this installer; see its installation comment.
