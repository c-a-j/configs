---
description: Review current changes in a read-only background agent
argument-hint: "[focus]"
---
Review the current working-tree and staged changes. Focus: ${@:-correctness, regressions, security, and missing tests}.

Do not edit files, install dependencies, execute tests, or apply fixes. Inspect git status and both diffs using read-only commands with external diff helpers and text conversion disabled. Include relevant untracked source files, but do not read or transmit credentials or secret files.

If the subagent tool is available, launch one `reviewer` agent with a self-contained prompt containing the requested focus, relevant diff, affected paths, and necessary context. Do not fork the full conversation or override the agent's locked settings. This agent runs in the background by default. Return its ID and scope; do not repeatedly poll or imply that review is complete before results arrive. If subagents are unavailable, perform the same read-only review yourself.

Report only concrete, actionable findings introduced by these changes. Give severity, file and line references, the failure scenario, and a suggested fix. Distinguish confirmed defects from missing test coverage. If no findings are identified, say so and state the remaining validation gaps. Do not silently fix findings when the background result arrives.
