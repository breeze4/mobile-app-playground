# Skill: progress-report

Produce a migration progress dashboard from beads status and spec artifacts.

## When to use

Run each morning to see what happened overnight, or anytime you need to understand migration status.

## Instructions

### 1. Query beads

Run `bd list --json` and categorize every bead:
- By step: spec-extract, implement, test-verify
- By status: open, in_progress, closed, failed (open with failure comments)
- By slice type: horizontal, vertical

### 2. Check artifacts

- Count spec files in `specs/` — how many modules have specs?
- Check `e2e/output/*/results.yaml` — aggregate pass/fail across all modules
- Check for `specs/_reconciliation.md` — has reconciliation run?

### 3. Check failures

- Read `.ralph/state/bead-failures/` — which beads have failed and how many times?
- Read recent ralph logs in `.ralph/logs/` — any patterns in failures? (timeouts, compilation errors, same error repeated)
- Identify beads that have hit the 2-failure skip limit

### 4. Produce dashboard

Print to stdout (not a file):

```
=== Migration Progress ===
Date: {today}

## Summary
Modules total: {count}
  Horizontal: {count} | Vertical: {count}

## By Phase
                  Done    In Progress    Blocked    Failed    Remaining
Spec Extract      {n}     {n}            {n}        {n}       {n}
Implement         {n}     {n}            {n}        {n}       {n}
Test Verify       {n}     {n}            {n}        {n}       {n}

## Test Results (from completed test-verify beads)
Total tests: {n} | Passed: {n} | Failed: {n} | Pass rate: {pct}%

## Failures Needing Attention
{List each failed bead with: module name, step, failure count, last error summary}

## Blocked Beads
{List each blocked bead with: what it's waiting on}

## Recommended Actions
- {e.g., "Fix auth-token:Implement (failed 2x: compilation error in TokenStore.swift)"}
- {e.g., "Re-run test-verify for camera-capture (simulator crash, likely transient)"}
- {e.g., "Run spec-reconcile — 5 new specs since last reconciliation"}
```

### 5. Suggest next overnight run

Based on current state, recommend the ralph command(s) for tonight:
- Which pool to run
- How many iterations
- Any beads to manually unblock first

## What this skill does NOT do

- Does not modify any beads, specs, or code
- Does not fix failures — it reports them
- Does not run tests — it reads existing results
