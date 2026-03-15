# Skill: spec-reconcile

Read all generated specs and the triage YAML, find inconsistencies, surface missing slices, and produce a reconciliation report with recommended actions. Run this after spec extraction completes and before implementation begins.

## When to use

Use this skill once, after all spec-extract beads have closed and before running the implementation loop. This is the checkpoint gate between Loop 1 and Loop 2.

## Modes

- **Interactive** (first run): Full reconciliation. Produces report with "Investigate" items for human. Creates `specs/_decisions.yaml` to store human decisions.
- **Automatic** (subsequent runs): Reads `specs/_decisions.yaml` and applies stored decisions to new specs. Only flags NEW questionable behaviors not covered by existing decisions. Wires new bead dependencies. This mode can run unattended overnight.

## What this skill solves

Spec extraction runs one agent per module in isolation. Each agent reads its files and writes its spec independently. This means:
- Multiple specs may flag the same misplaced logic, revealing missing horizontal slices
- Dependency chains may exist that the triage didn't capture
- Questionable behaviors need human decisions before implementation
- Some modules may need reclassification (done→partial, partial→todo)
- Business rules may contradict across specs
- The bead structure may need updating (new beads, new dependencies)

No human is going to read 30 specs and cross-reference all of this manually. This skill does it.

## Instructions

### 1. Read all specs and the triage

- Read `specs/_triage.yaml`
- Read every `specs/{group}/{module}.md` file
- Build a mental model of the full module graph

### 2. Analyze Misplaced Logic across all specs

This is the highest-value check. Aggregate every `## Misplaced Logic` entry across all specs.

For each unique piece of misplaced logic:
- How many specs flag it?
- Which horizontal slice do they say it belongs to?
- Does that horizontal slice exist in the triage?
- If it exists, is it `done` or does it need work?
- If it doesn't exist, it's a **missing horizontal** — recommend adding it

Produce a table:

| Misplaced Logic | Flagged By (count) | Belongs To | In Triage? | Status | Action |
|---|---|---|---|---|---|
| Inline auth token refresh | 6 specs | auth-token | Yes | partial | Ensure auth-token is migrated before these verticals |
| Direct URLSession calls | 8 specs | networking | Yes | done | No action — networking package exists, verticals should import it |
| Inline Keychain access | 3 specs | auth-token | Yes | partial | Already covered by auth-token |
| Analytics tracking calls | 5 specs | analytics | **No** | — | **Add analytics horizontal to triage** |
| Core Data saves in VCs | 4 specs | persistence | **No** | — | **Add persistence horizontal to triage** |

### 2b. Apply stored decisions

If `specs/_decisions.yaml` exists, read it. For each questionable behavior found in step 2:
- If a matching decision exists (by pattern/description), apply it automatically (drop/keep/fix)
- Only flag items that have no matching decision as "Investigate"

This allows overnight runs to handle new specs without human intervention for previously-decided patterns.

### 3. Analyze Questionable Behaviors

Aggregate all `## Questionable Behaviors` across specs. For each:
- Classify as: likely-bug, likely-workaround, likely-dead-code, needs-investigation
- Recommend an action: drop (don't implement), keep (implement as-is), fix (implement correctly), investigate (needs human input)
- Group related items (e.g., "3 modules have the same silent error swallowing pattern — this is likely a systemic workaround, not 3 independent bugs")

Produce a decision list:

```
## Questionable Behavior Decisions

### Drop (do not implement)
- [camera-capture] Spinner never stops on network timeout — Source: CaptureVC.swift:340. Likely bug.
- [settings-export] Dead code path for CSV export — Source: ExportController.swift:200-230. Unreachable.

### Keep (implement as-is)
- [login] 3-attempt lockout before showing "forgot password" — Source: LoginVC.swift:90. Looks intentional.

### Fix (implement correctly)
- [alert-rules, camera-capture, settings-export] Silent error swallowing on API failures — systemic pattern across 3 modules. Implement proper error handling with user feedback.

### Investigate (needs human decision)
- [login] Password field allows paste on iOS but blocks paste on the web — intentional platform difference or inconsistency? Source: LoginVC.swift:145.
```

### 4. Analyze Dependencies

Build a dependency graph from the `## Dependencies` sections across all specs.

Check for:
- **Circular dependencies**: Module A depends on B, B depends on A
- **Missing dependencies**: Module A says it depends on module X, but X isn't in the triage
- **Ordering issues**: A vertical depends on a horizontal that is `todo` — the horizontal must be implemented first
- **Unblocked chains**: Which modules have all dependencies satisfied and can be implemented immediately?

Produce a dependency summary and recommended implementation order.

### 5. Check for cross-spec contradictions

Look for business rules that contradict across specs:
- Module A's spec says "the API returns raw JSON" but module B's spec says "the API returns decoded models"
- Module A says "auth tokens expire after 1 hour" but module C says "tokens expire after 24 hours"
- Two specs describe the same behavior differently

Flag each contradiction with the relevant specs and source citations.

### 6. Check triage accuracy

Based on what the specs revealed:
- Any modules marked `done` that the spec shows are actually `partial`? (e.g., spec found missing behaviors or dependencies on SecuroNet)
- Any modules marked `partial` that should be `todo`? (e.g., the existing Package code is minimal and it would be easier to start fresh)
- Any modules that should be `manual` that aren't? (e.g., spec reveals complex hardware/animation dependencies)

### 7. Produce reconciliation report

Write to `specs/_reconciliation.md`:

```markdown
# Spec Reconciliation Report

Generated: {timestamp}
Specs analyzed: {count}
Modules in triage: {count}

## Missing Horizontal Slices
{Table from step 2 — only entries where In Triage = No}

Recommended actions:
- Add {slice} to triage as {horizontal, status: todo}
- ...

## Misplaced Logic Summary
{Full table from step 2}

## Questionable Behavior Decisions
{Decision list from step 3 — Drop / Keep / Fix / Investigate sections}

## Dependency Analysis
{Graph summary from step 4}

### Recommended Implementation Order
1. {horizontal slices first, in dependency order}
2. {verticals with no remaining horizontal deps}
3. {verticals with horizontal deps, after those horizontals complete}

### Circular Dependencies
{List, or "None found"}

### Missing Dependencies
{List of modules referenced in specs but not in triage}

## Cross-Spec Contradictions
{List from step 5, or "None found"}

## Triage Corrections
{List from step 6, or "No corrections needed"}

## Actions Required Before Implementation

### Automatic (this skill will do these now)
- [ ] Update _triage.yaml: add missing horizontals
- [ ] Update _triage.yaml: correct module statuses
- [ ] Update specs: move "Keep" questionable behaviors into Behavior Specification
- [ ] Update specs: remove "Drop" questionable behaviors
- [ ] Wire cross-slice bead dependencies (bd dep add)
- [ ] Scaffold new beads if triage changed

## Stored Decisions
decisions.yaml updated: {yes/no}
New decisions needed: {count}
Decisions auto-applied: {count}
```

### Manual (human must decide)
- [ ] {Each "Investigate" item from questionable behaviors}
- [ ] {Each circular dependency that needs a design decision}
- [ ] {Each cross-spec contradiction that needs resolution}
```

### 8. Apply automatic fixes

For actions marked "Automatic" in the report:
- Update `specs/_triage.yaml` to add missing horizontal slices (status: todo)
- Update `specs/_triage.yaml` to correct module statuses
- Update individual spec files: move "Keep" items from Questionable Behaviors into the main Behavior Specification section
- Update individual spec files: remove "Drop" items from Questionable Behaviors
- Do NOT touch "Investigate" items — leave them for the human

### 9. Wire cross-slice bead dependencies

This is critical for correct implementation ordering. Use `bd list --json` to get all existing beads, then:

1. Find every implement bead (title contains ": Implement")
2. From the dependency graph (step 4), determine which implement beads depend on which
3. For each vertical implement bead that depends on a horizontal:
   - Find the horizontal's implement bead ID
   - Run `bd dep add <vertical-implement-bead-id> <horizontal-implement-bead-id>`
4. For horizontals that depend on other horizontals, wire those too

This ensures ralph won't try to implement a vertical before its horizontal dependencies are done.

### 10. Re-scaffold if needed

If the triage was modified (new horizontals added, statuses changed):
- Run `scripts/scaffold.sh` to create beads for newly added modules
- Wire the new beads' dependencies using the same approach as step 9
- Verify with `bd ready` that the unblocked beads make sense (should be spec-extract beads for new modules, and implement beads for modules whose horizontal deps are already done)

## What this skill does NOT do

- Does not make product decisions — "Investigate" items are left for the human
- Does not run implementation — it prepares the ground for Loop 2
- Does not resolve circular dependencies — it flags them for a design decision
- Does not modify implementation code
