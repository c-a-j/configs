---
description: Produce a concise continuation brief for a fresh session
argument-hint: "[focus]"
---
Produce a self-contained continuation brief for this task. Optional focus: $ARGUMENTS.

Do not edit files, run commands, start agents, compact the session, or automatically open a new session. Write normal prose suitable for pasting into a fresh session.

Include:
- The user's goal, constraints, and important decisions.
- Completed changes and their file paths.
- Tests actually run and their results; clearly mark unverified work.
- Remaining work, blockers, and the next concrete action.
- Relevant commands and configuration paths, without credentials or secret values.
- Existing unrelated working-tree changes that must be preserved.
- Any running background agents and their IDs. Explain that live agent IDs belong to the current parent session and cannot be resumed from a fresh session.

Keep the brief concise. Do not treat suggestions as approved work, and do not claim unfinished work is complete.
