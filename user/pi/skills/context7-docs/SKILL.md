---
name: context7-docs
description: Verify uncertain or version-sensitive library APIs, configuration, migrations, and CLI behavior with Context7. Use when local evidence is insufficient or the user explicitly requests a documentation lookup.
---

# Targeted documentation lookup

Use documentation to resolve uncertainty, not merely because a library is named.

## When to look up documentation

- The user explicitly requests a lookup or current documentation.
- API syntax, signatures, configuration, or behavior is uncertain or version-sensitive.
- A migration or unfamiliar dependency requires verification.
- Local code, installed types, tests, and documentation do not settle the question.

Skip a redundant lookup when reliable evidence already in context or the installed
version's local documentation settles the question. Reuse relevant results from
this session unless the version, question, or evidence changes. Do not substitute
uncertain recollection for verification.

## Procedure

1. Establish the relevant library version from the project when possible.
2. Call `resolve-library-id` with the library name and a focused question. If the user supplies a Context7 ID such as `/org/project` or `/org/project/version`, use it directly.
3. Call `query-docs` with the selected ID and one specific unresolved question. Prefer version-matched documentation and authoritative sources.
4. Explain the answer and cite the library ID used. State any version mismatch or remaining uncertainty.

Do not call either tool more than three times per question. Never send credentials,
personal data, or proprietary code in lookup queries.
