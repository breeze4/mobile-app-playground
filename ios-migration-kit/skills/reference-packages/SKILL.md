# Skill: reference-packages

Analyze all `done` packages in `./Packages/` and recommend 2-3 that best represent the project's architecture patterns. Write the results into the project's CLAUDE.md.

## When to use

Run this once during setup, after triage is complete but before scaffold. The triage tells us which packages are `done` — this skill reads them and picks the best examples for implementing agents to study.

## Why this matters

Every implementing agent needs to study existing packages to learn the project's patterns before writing code. If they pick arbitrarily, they might study a trivial utility package and miss the navigation pattern, or study an atypical package and replicate a one-off approach. This skill picks representative packages so every agent learns from the same blueprints.

## Instructions

### 1. Read the triage

Read `specs/_triage.yaml`. Collect all modules with `status: done` and their `source_files` paths.

### 2. Analyze each done package

For each `done` package, use subagents in parallel to read the source files and evaluate:

**Architectural breadth** — does this package demonstrate multiple layers?
- Has a View (SwiftUI)
- Has a ViewModel (`@Published`, `@Observable`, `@StateObject`)
- Has a Model (data structures)
- Has a Service or Repository (protocol-based, async)
- Has navigation (NavigationStack, sheets, coordinators)
- Has dependency injection (environment, init params)

**Test quality** — does this package show how to test?
- Has unit tests
- Number of test cases
- Tests ViewModels with injected mock services
- Tests business logic / validation

**Complexity** — is it representative of real work?
- Number of source files
- Handles async operations (network calls, loading states)
- Handles error states
- Has list/detail patterns or data-driven UI
- Not trivially simple (a package with one model file is not representative)

**Slice type coverage**
- Is it a vertical (user-facing feature)?
- Is it a horizontal (shared infrastructure)?
- Ideally the reference set includes both

Score each package on these dimensions. Don't produce numeric scores — just note which dimensions it covers.

### 3. Select 2-3 reference packages

Pick packages that together cover the most architectural patterns:

- **One vertical with full stack**: View + ViewModel + Service + navigation + tests. This is the primary blueprint for implementing agents. Prefer the one with the most behaviors and the cleanest separation.
- **One horizontal**: Service protocol + implementation + tests. Shows how shared infrastructure packages are structured and consumed.
- **One complex vertical** (optional, if different from the first): A package with list/detail patterns, search/filter, or multi-step flows. Shows how to handle more complex UI and state.

If only 2 packages are needed to cover all patterns, use 2. If the project is small and only has 1-2 done packages, use what's available and note the pattern gaps.

### 4. Write descriptions

For each selected reference package, write a one-line description of what architectural patterns it demonstrates. Be specific:
- "Login flow — ViewModel with form validation, async auth service call, navigation on success, error state handling, 12 unit tests covering validation rules"
- NOT "Auth package — shows MVVM pattern"

### 5. Update CLAUDE.md

Find the `## Reference Packages` section in the project's CLAUDE.md (or `.claude/CLAUDE.md`) and fill it in:

```markdown
## Reference Packages

When implementing a new module, study these packages FIRST to learn the project's architecture patterns. Read their Views, ViewModels, Services, and Tests before writing any code.

- `Packages/Auth` — Login flow: ViewModel with form validation + async auth service + NavigationStack routing + error state handling. 12 unit tests cover validation rules and auth state transitions.
- `Packages/Networking` — Horizontal: protocol-based APIClient with Endpoint enum, async/await, structured error types. 8 unit tests with mock URLSession.
- `Packages/Dashboard` — Complex vertical: list/detail with search + filter, pagination, pull-to-refresh, empty state. ViewModel manages 4 published properties. 15 unit tests.

These are the most architecturally representative packages in the project. Every new module should match their patterns for Views, ViewModels, dependency injection, navigation, and testing.
```

### 6. Note pattern gaps

If the selected packages don't cover certain patterns that implementing agents will need, note them after the reference list:

```markdown
### Pattern Gaps
- No existing package demonstrates Core Data / persistence integration
- No existing package demonstrates deep linking or URL handling
- No existing package uses @Observable (all use @Published + ObservableObject)
```

This tells implementing agents where they'll need to make architecture decisions without a reference, and tells you what might need attention before running the implementation loop.

## What this skill does NOT do

- Does not modify any package source code
- Does not write specs
- Does not create beads
- Does not implement anything — it only identifies examples
