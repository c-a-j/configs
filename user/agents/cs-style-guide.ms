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

## Dependency & Tooling Policy

- Only suggest or add dependencies, tools, and services that are open source under an OSI-approved license.
- Never suggest proprietary, source-available, or commercially licensed options. If the only option is proprietary, say so and stop rather than recommending it.
- When suggesting any dependency or tool, state its license and steward (e.g. "Apache 2.0, CNCF").
- Treat relicensing history as a risk signal. Call it out before suggesting. Known cases to avoid: MediatR and AutoMapper (moved to commercial licensing), FluentValidation (commercial from v12), Moq (shipped SponsorLink telemetry), SpecFlow (proprietary under Tricentis; Reqnroll is the community fork).
- Prefer upstream projects over vendor-branded distributions of them.
- Copyleft (GPL/AGPL) is not proprietary, but flag it explicitly so the user can decide. Grafana and Loki are AGPLv3.

## Working Policies

- Suggest the smallest change that satisfies the user's request.
- Do not make destructive changes unless the user explicitly asks for them.
- Do not assume that older architecture notes are still current.
- When the user pastes an error, do not assume the cause. Read the relevant file(s) and inspect the code path or line where the error is produced before diagnosing.
- When asked to review, prioritize bugs, regressions, risks, and missing tests.
- When asked to edit code, preserve existing project patterns unless the user requests a change in direction.

## Style Rules

Match the code on `master`. When unsure, open `src/Domain/Organizations/Organization.cs`,
`src/Application/Organizations/CreateOrganization.cs`, and
`src/Infrastructure/Data/Repositories/OrganizationRepository.cs` and copy what they do.

### Layout

- Two-space indentation. File-scoped namespaces. Allman braces for types, methods, and blocks.
- Keep lines under ~100 characters; never exceed 120. Wrap instead.
- One statement per line. Never put a query, a call, and an assignment on the same line.
- Separate logical steps with a blank line: guards, then work, then state assignment, then return.

  ```csharp
  public void UpdateDetails(string name, string description)
  {
    ArgumentException.ThrowIfNullOrWhiteSpace(name);
    ArgumentNullException.ThrowIfNull(description);

    name = name.Trim();
    ArgumentOutOfRangeException.ThrowIfGreaterThan(
      name.Length, MaxNameLength, nameof(name)
    );

    Name = name;
    Description = description;
  }
  ```

### Usings

- Two groups separated by one blank line: framework and third-party namespaces first
  (`System`, `Microsoft`, `Npgsql`), then project namespaces (`Domain`, `Application`,
  `Infrastructure`, `Web`).
- Alphabetical within each group.

  ```csharp
  using Microsoft.EntityFrameworkCore;
  using Npgsql;

  using Application.Organizations;
  using Domain.Organizations;
  ```

### Wrapping

- Method chains: one call per line, leading dot, indented once.

  ```csharp
  await db.Organizations
    .AsNoTracking()
    .OrderBy(org => org.Name)
    .ToListAsync(ct);
  ```

- Long parameter lists: one parameter per line, closing paren on its own line followed by the brace.

  ```csharp
  public async Task<Organization> ExecuteAsync(
    string name,
    string? slug,
    OrganizationKind kind,
    CancellationToken ct
  ) {
  ```

- Long argument lists: break after the opening paren, closing paren on its own line.

  ```csharp
  throw new ArgumentOutOfRangeException(
    nameof(maxZoom),
    "Maximum zoom must be greater than or equal to minimum zoom."
  );
  ```

- Ternaries that do not fit on one line: `?` and `:` each start their own line.

  ```csharp
  Slug = slug.TryToSlug(MaxSlugLength, out var normalized)
    ? normalized
    : throw new ArgumentException("Slug must contain a letter or digit.", nameof(slug));
  ```

- Never inline a query in a `foreach` header. Name the result first, then loop.

  ```csharp
  var changedPois = ChangeTracker.Entries<PointOfInterest>()
    .Where(entry => entry.State is EntityState.Added or EntityState.Modified)
    .ToList();

  foreach (var entry in changedPois)
    await ValidatePoiSelectionsAsync(entry, ct);
  ```

### Locals and naming

- Use `var` for locals. Do not spell out types such as `List<PoiCategory>` or `EntityEntry<T>`.
- Lambda parameters get a meaningful name (`org => org.Slug`, `entry => entry.CategoryId`), not `x`.
  Single letters are acceptable only in EF configuration builders (`b`, `o`, `l`).
- Name intermediate results. If the same projection or expression appears twice, bind it to a local.
- `CancellationToken` parameters are named `ct` and come last. Async methods end in `Async`.
- Private fields are `_camelCase`. Length limits are `public const int MaxXLength` on the entity.

### Methods

- A method does one thing. If two blocks have the same shape with different types, extract a
  helper or a generic method; do not copy the block.
- Aim for methods that fit on one screen (~30 lines). Split by intent, and name the pieces after
  what they check or do.
- A method or constructor whose body is a single statement is always expression-bodied:
  `=>` ends the signature line and the statement goes on the following line, indented once.
  Never put the statement on the signature line, even when it fits.

  ```csharp
  public void SetActive(bool active) =>
    IsActive = active;
  ```

- Use a block body only when the body has more than one statement, or its single statement
  cannot be an expression (`if`, `foreach`, `try`).
- Guard clauses first, using the `ThrowIf...` helpers (`ArgumentNullException.ThrowIfNull`,
  `ArgumentOutOfRangeException.ThrowIfGreaterThan`). Validate before mutating any state.
- An `if` or `foreach` body that is a single statement never gets braces, no matter how
  many lines that statement wraps across. The body starts on its own line.

  ```csharp
  if (southwest.Lat > northeast.Lat)
    throw new ArgumentException(
      "Northern latitude must be greater than or equal to southern latitude.",
      nameof(northeast)
    );
  ```

- Two exceptions, where the single-statement body keeps its braces:
  - Nested statements. If the body is itself a control-flow statement (`if`, `foreach`,
    `for`, `while`, `try`), the outer statement gets braces.
  - `if`/`else` chains. If any branch has braces, every branch has them.

  ```csharp
  for (var i = 1; i < color.Length; i++)
  {
    if (!IsHexDigit(color[i]))
      throw new ArgumentException("Color must contain only hexadecimal digits.", paramName);
  }
  ```

### Types

- Primary constructors for services, repositories, and exceptions.
- `sealed` by default; `internal sealed` for Infrastructure and Web implementation types.
- Entities: `private set` properties, a private parameterless constructor for EF, a public
  constructor that delegates to the mutator methods (`Rename`, `Reslug`, `UpdateX`).
- Collections: private `List<T>` field exposed as `IReadOnlyCollection<T>`; `[]` to initialize.
- Requests and responses are `sealed record`s declared at the bottom of the endpoints file,
  with a static `From(...)` mapper on the response.

### Sections

- Every type with more than a handful of members is divided into labeled banner sections:

  ```csharp
  // ---------------------------------------------------------------------------
  // constants
  // ---------------------------------------------------------------------------
  ```

- Default order: `constants`, `properties`, `constructors`, `methods`.
- When a type grows, split `methods` into sections named for what they deal with
  (`zoom`, `icon sets`, `categories`) and keep related members together. A new member goes
  into the section it belongs to, not at the bottom of the file.
- Endpoint files get one banner per handler, labeled with what it does (`get org by slug`),
  and a file-level `data transfer objects` banner above the records.
- Labels are lowercase. One blank line before each banner. No unlabeled banners and no
  empty sections.

### Comments

- Comments explain why, never what. If the member name already says it, write nothing.
- A why-comment on a type or member uses `/// <summary>` so it appears in tooltips.
  Add `<param>`, `<returns>`, or `<remarks>` only when they say something the signature does not.
- Do not document a member just because it is public.
- Inside a method body, use `//` at the line it explains
  (see the `// "Café" → ...` note in `SlugExtensions.cs`).

### Tests

- xUnit `Assert` only. Names follow `Method_WhenCondition_ExpectedResult`.
- Arrange, act, assert separated by blank lines. No comments labelling the sections.
- Hand-written fakes as private nested classes; unused members throw `NotSupportedException`.
