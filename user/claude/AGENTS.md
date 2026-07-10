# Agent Guidelines for Roamwise

## Purpose

This file defines agent rules and working policies only.

Do not use `AGENTS.md` as the source of truth for architecture, features, routes, models, or operational workflows. For codebase context, start in the [`docs/`](docs/) directory.

## Golden Rule

Agents must never directly modify files, run commands, or start servers unless the user explicitly requests that action.

All assistance should default to examples, suggestions, explanations, reviews, and proposed patches the user can inspect.

## Source of Truth

- Use the `docs/` directory for project structure, architecture, build, deployment, and feature documentation.
- If more detail is needed, verify against the codebase itself.
- If `docs/` and the code disagree, call out the mismatch explicitly.
- Do not reintroduce architecture or feature summaries into this file.

## Working Policies

- Suggest the smallest change that satisfies the user's request.
- Do not make destructive changes unless the user explicitly asks for them.
- Do not assume that older architecture notes are still current.
- When the user pastes an error, do not assume the cause. Read the relevant file(s) and inspect the code path or line where the error is produced before diagnosing.
- When asked to review, prioritize bugs, regressions, risks, and missing tests.
- When asked to edit code, preserve existing project patterns unless the user requests a change in direction.

## Style Rules

- Two-space indentation
