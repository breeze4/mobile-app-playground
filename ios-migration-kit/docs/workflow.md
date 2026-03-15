# iOS Migration Workflow

End-to-end workflow for migrating an iOS app using the citation-based approach.

## Prerequisites

- `bd` CLI installed (beads)
- `claude` CLI installed
- Python 3 + PyYAML (`pip3 install pyyaml`)
- Xcode with simulator configured
- iOS project with both legacy and new-architecture code

## Setup

```bash
# 1. Initialize beads in your iOS project root
bd init

# 2. Copy kit contents into place
cp -r ios-migration-kit/scripts/ scripts/
cp -r ios-migration-kit/.ralph/ .ralph/
cp ios-migration-kit/formulas/*.json .beads/formulas/
cp -r ios-migration-kit/skills/* .claude/skills/

# 3. Create specs directory
mkdir -p specs

# 4. Add CLAUDE.md template content to your project's CLAUDE.md
# (see templates/CLAUDE.md.template)

# 5. Make scripts executable
chmod +x scripts/*.sh
```

## Phase 0: Triage

Classify every module in the project.

```bash
# Option A: Run the module-triage skill interactively
claude -p "Use the module-triage skill to inventory this project. Write output to specs/_triage.yaml"

# Option B: Copy and fill in the template manually
cp ios-migration-kit/templates/triage-template.yaml specs/_triage.yaml
# Edit specs/_triage.yaml — set status for each module
```

Review `specs/_triage.yaml` and classify every module:
- `done` — fully migrated, just needs spec for reference
- `partial` — partially migrated, needs completion + tests
- `todo` — not started, needs full migration
- `manual` — excluded from automation

## Phase 0b: Reference Packages

Identify which existing packages best represent the project's architecture patterns.

```bash
claude -p "Use the reference-packages skill. Read specs/_triage.yaml, analyze all done packages, and update CLAUDE.md with the best reference packages."
```

Review the output — does it capture the patterns you care about? Are there pattern gaps that need addressing before implementation?

## Phase 1: Scaffold

Create beads from the triage.

```bash
# Dry run first
scripts/scaffold.sh --dry-run

# Create the beads
scripts/scaffold.sh

# Verify
bd ready
```

## Phase 2: Spec Extraction

Run ralph to extract specs from all modules.

```bash
scripts/ralph.sh --pool general --iterations 100 --timeout 900
```

### Checkpoint (CRITICAL — this is the human gate)

This is the most important step in the entire workflow. Specs generated from spaghetti code will contain accidental behavior documented as requirements, missing edge cases, and hallucinated plausibility. Every spec must pass these gates before Loop 2 runs.

**Gate 1: Behavioral coverage**
- Does the spec cover all primary user flows (or API contracts for horizontals)?
- Are error states, empty states, and loading states documented?
- Are network failure paths covered, not just success?

**Gate 2: Accidental vs intentional**
- Review the `## Questionable Behaviors` section in each spec
- For each item: decide keep (it's intentional), drop (it's a bug), or fix (implement correctly)
- Remove dropped items. Move kept items into the main Behavior Specification.
- If Questionable Behaviors is empty, be suspicious — spaghetti code always has accidents

**Gate 3: Architecture decoupling**
- Does the spec read like a product requirement, or does it read like a UIKit code walkthrough?
- Are there UIKit class names, delegate method signatures, or lifecycle references that leaked in?
- Could you hand this spec to a developer who has never seen the legacy codebase and have them build the module?

**Gate 4: Testability**
- Can every given/when/then map to at least one XCUITest or XCTest?
- Are states and transitions specific enough to write a failing test from the spec alone?
- Vague qualifiers like "sometimes shows" or "may display" are spec gaps, not requirements

**Gate 5: Business rule separation**
- Are business rules in the Business Rules section, not embedded in behavioral descriptions?
- Does the spec distinguish what belongs in a ViewModel vs what belongs in a service?

If a spec fails any gate, fix it manually or re-run spec-extract with more specific instructions. Do NOT proceed to implementation with bad specs — the cost of fixing bad implementation is 10x the cost of fixing a bad spec.

## Phase 2b: Reconciliation

After all specs are generated, run the spec-reconcile skill to cross-reference everything.

```bash
claude -p "Use the spec-reconcile skill. Read all specs in specs/ and specs/_triage.yaml. Produce reconciliation report."
```

This skill automatically:
- Aggregates misplaced logic across all specs to find missing horizontal slices
- Classifies every questionable behavior as drop/keep/fix/investigate
- Builds a dependency graph and checks for circular deps and missing modules
- Finds cross-spec contradictions in business rules
- Corrects triage statuses based on what specs revealed
- Updates triage YAML and spec files for drop/keep decisions

What it leaves for you:
- "Investigate" items in the questionable behaviors (needs your product knowledge)
- Circular dependency design decisions
- Cross-spec contradictions that need resolution
- Review and run the printed scaffold commands for any new beads

Review `specs/_reconciliation.md`, resolve the manual items, then run any printed scaffold commands.

```bash
# If new horizontals were added to triage:
scripts/scaffold.sh --dry-run  # verify new beads
scripts/scaffold.sh            # create them
```

## Phase 3: Implementation

Run ralph to implement/complete all modules.

```bash
scripts/ralph.sh --pool code-author --iterations 50 --timeout 3600
```

### Checkpoint

```bash
# Verify full project compilation (use scheme from CLAUDE.md)
xcodebuild build -scheme {SCHEME} -destination 'generic/platform=iOS Simulator'

# Run all unit tests
xcodebuild test -scheme {SCHEME} -destination 'platform=iOS Simulator,name={SIMULATOR}'
```

## Phase 4: Test Verification

Run ralph to write and run XCUITests.

```bash
scripts/ralph.sh --pool test-author --iterations 50 --timeout 1800
```

### Checkpoint

- Review `e2e/output/*/results.yaml` for pass/fail summary
- Triage failures: test bug vs app bug vs timing issue
- Re-run failed modules if needed

## Overnight Run

## Overnight Scripts

Reconciliation requires human decisions on Day 2, so overnight runs are phased:

**Night 1 (after triage + scaffold):** Spec extraction only.
```bash
#!/usr/bin/env bash
# night-1-specs.sh — run after triage and scaffold are done
set -euo pipefail
scripts/ralph.sh --pool general --iterations 200 --timeout 600 --max-failures 5
bd stats
```

**Night 2+ (after reconciliation):** Implementation and test verification.
```bash
#!/usr/bin/env bash
# night-2-implement.sh — run after reconciliation is complete
set -euo pipefail

echo "=== Implementation ==="
scripts/ralph.sh --pool code-author --iterations 100 --timeout 3600 --max-failures 3

echo "=== Test Verification ==="
scripts/ralph.sh --pool test-author --iterations 100 --timeout 1800 --max-failures 10

echo "=== Done ==="
bd stats
```

Note: test-author uses `--max-failures 10` because XCUITest failures are often transient (simulator timing, state pollution). Per-bead retry tracking (2-failure skip) prevents the same flaky bead from burning all retries.

## Multi-Day Workflow (2-week project)

### Day 1 (Monday)
- Setup: copy kit, bd init, run module-triage, run reference-packages
- Review triage, classify modules, choose reference packages
- Run scaffold
- Kick off Loop 1 (spec extraction) — afternoon/evening

### Day 2 (Tuesday)
- Morning: run progress-report, review spec extraction results
- Run spec-reconcile (interactive mode — first time, make product decisions)
- Resolve "Investigate" items, store decisions in _decisions.yaml
- Re-scaffold if new horizontals were added
- Kick off Loop 2 (implementation) for horizontals — evening

### Days 3-5 (Wed-Fri)
- Morning routine: run progress-report, fix failed beads, review results
- Implementation loop continues overnight
- Horizontal implementations finish → vertical implementations unblock
- Run spec-reconcile in automatic mode if new specs were generated

### Days 6-10 (Week 2)
- Implementation completes for most modules
- Kick off Loop 3 (xcuitest-verify) as implement beads close
- Morning routine: review test results, triage failures
- Fix real bugs found by tests, re-run failed test beads
- Manual testing for `manual` modules

### Daily Morning Routine
1. `claude -p "Use the progress-report skill"`
2. Review failures — fix or reset beads that hit the 2-failure limit
3. Reset per-bead failure counts for beads you've fixed: `rm .ralph/state/bead-failures/{bead-id}`
4. Kick off next overnight run based on progress-report recommendation

## Validation

After all phases complete:

1. Run the full XCUITest suite as a regression check
2. Run existing Appium tests against the rewritten app as a baseline
3. Review `bd stats` for any unclosed beads
4. Manual testing for modules marked `manual` in triage
