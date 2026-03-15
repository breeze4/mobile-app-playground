# E2E Test Harness

## Overview

A Maestro-based e2e testing pipeline integrated into the slice workflow. Tests are written against the existing app to capture current behavior, then run against the new app to verify parity. The test authoring and code implementation are done by different models to prevent shared blind spots.

## Framework Choice: Maestro

- Black-box testing — no changes to existing app code
- YAML test flows — declarative, simple to write and review
- Portable — same flows run against old or new app builds by swapping bundle ID
- Built-in video recording (`maestro record`) and screenshots (`takeScreenshot`)
- Free CLI tool, runs on simulator locally

## Updated Slice Pipeline (8 steps)

```
research → plan → test design → test implement → test verify → implement → verify → report
```

| Step | Purpose | Model Pool |
|------|---------|------------|
| Research | Analyze existing code for this slice | TBD |
| Plan | Implementation plan for the new app | TBD |
| Test Design | Plain English given/when/then behavioral test cases | Model A |
| Test Implement | Translate test cases into Maestro YAML flows | Model A |
| Test Verify | Run flows against existing app, debug until green | Model A |
| Implement | Write the feature code in the new app | Model B |
| Verify | Run Maestro flows against new app, confirm parity | Model B |
| Report | Generate post-build report with artifacts | TBD |

**Model A and Model B must be different models/agents.** The test suite is the contract; the implementation must satisfy it independently.

## Maestro Flow Structure

### Directory layout
```
e2e/
  flows/
    {slice-name}/
      flow-001-{test-case-name}.yaml
      flow-002-{test-case-name}.yaml
      ...
  config/
    env.old.yaml    # APP_ID for existing app
    env.new.yaml    # APP_ID for new app
  output/
    {slice-name}/
      videos/
      screenshots/
      results.yaml
```

### Flow template
```yaml
appId: ${APP_ID}
---
# {slice-name}: {test-case-name}
# Given: {precondition}
# When: {action}
# Then: {expected result}
- launchApp
- ...test steps...
- takeScreenshot: "{slice-name}-{test-case-name}-final"
```

### Running
```bash
# Against existing app
maestro test -e APP_ID=com.example.oldapp e2e/flows/{slice-name}/

# Against new app
maestro test -e APP_ID=com.example.newapp e2e/flows/{slice-name}/

# With video recording
maestro record -e APP_ID=com.example.oldapp e2e/flows/{slice-name}/flow-001.yaml
```

## Agent Skills

### `test-design` skill
- Input: slice definition + research notes + plan
- Analyzes the existing feature behavior
- Produces given/when/then test cases in structured YAML:
  ```yaml
  slice: camera-list-page
  test_cases:
    - name: load-camera-list
      given: user is authenticated and on home screen
      when: user taps camera list tab
      then: list of cameras loads with names and thumbnails
      assertions:
        - camera list is visible
        - at least one camera entry displayed
        - each entry shows name and thumbnail
  ```
- Covers happy paths, edge cases, error states
- Checkpoint: user reviews test cases before implementation

### `test-implement` skill
- Input: test design YAML from previous step
- Translates each test case into a Maestro YAML flow
- Follows the directory layout and naming convention
- Includes screenshots at key assertion points
- Checkpoint: user can review generated flows before running

### `test-verify` skill
- Input: implemented Maestro flows
- Runs flows against the existing app on simulator
- Captures video and screenshots for each flow
- If a flow fails: analyzes the failure, adjusts the flow, retries
- Max retry attempts before flagging for human review
- Output: test results summary with pass/fail per flow, artifacts in output dir

## Model Experimentation Plan

### Goal
Determine which model (Claude family vs ChatGPT/Codex family) performs better at which pipeline steps. Run a controlled experiment on 1-2 representative slices before committing to assignments.

### Setup
Pick 2 slices: 1 vertical (UI feature), 1 horizontal (cross-cutting concern). Run each through the full 8-step pipeline twice with swapped model assignments.

### Experiment matrix

| Run | Test Steps (design/implement/verify) | Code Steps (implement/verify) |
|-----|--------------------------------------|-------------------------------|
| A   | Claude                               | Codex                         |
| B   | Codex                                | Claude                        |

### Evaluation criteria per step
- **Test Design**: coverage completeness (did it catch edge cases?), clarity of GWT descriptions, missed scenarios
- **Test Implement**: correct Maestro syntax, flows actually runnable, proper use of assertions/screenshots
- **Test Verify**: ability to self-debug failing flows, number of retries needed, final pass rate
- **Implement**: code quality, adherence to plan, does it actually pass the tests on first run?
- **Verify**: ability to diagnose and fix test failures in the new code

### What to measure
- Pass rate of Maestro flows on first run (before debug loop)
- Number of debug iterations needed in test-verify and verify steps
- Human intervention count (times you had to step in)
- Subjective quality of test case design (edge case coverage, readability)

### Decision
After the 2-slice experiment, assign models to step types for the full run. Document the rationale in this plan's review section.

## Implementation Checklist

### Phase 1: Maestro setup
- [x] Install Maestro CLI, verify it runs on the playground Android app via emulator
- [x] Create `e2e/` directory structure (flows, config, output)
- [x] Write one manual sample flow against the playground app to validate the setup
- [x] Verify: `maestro test` and `maestro record` both work, artifacts land in output dir

### Phase 2: Test skills
- [x] Create `test-design` skill with instructions for producing GWT YAML from slice context
- [x] Create `test-implement` skill with Maestro YAML generation instructions and conventions
- [x] Create `test-verify` skill with run/debug/retry loop instructions
- [x] Verify: run all three skills manually on one slice of the playground app

### Phase 3: Parity comparison workflow
- [x] Script that runs the same Maestro flow suite against two different APP_IDs
- [x] Diff report: which flows pass on old app vs new app, side-by-side
- [x] Verify: intentionally break a feature in the new app, confirm diff report catches it

### Phase 4: Model experiment
- [x] Pick 2 slices (1 vertical, 1 horizontal) from the playground app
- [x] Run experiment matrix (Claude vs Codex swapped across test/code steps)
- [x] Document results and assign models to step types
- [x] Update bead scaffolder to tag beads with assigned model/agent type

### Phase 5: Integration with bead pipeline
- [x] Update bead scaffolder to create 8 steps instead of 6
- [x] Test artifacts (videos, screenshots, results) stored in standard location per slice
- [x] Bead notes updated with test results summary on completion of test-verify and verify steps
- [x] Verify: full pipeline run on one playground slice, all 8 beads created and closeable

## Out of Scope
- Real device testing — simulator only for now
- CI/CD integration — local runs only
- Performance/load testing — strictly functional parity
- iOS-specific setup — built and tested on Android first, ported later
