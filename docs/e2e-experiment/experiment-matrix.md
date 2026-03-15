# Experiment Matrix: Model Assignment for Slice Pipeline

## Goal

Determine which model (Claude vs Codex) performs better at test-authoring steps versus code-implementation steps. Run a controlled experiment on 2 representative slices before committing to assignments for the full build.

## Selected Slices

| Slice | Type | Why Selected |
|-------|------|-------------|
| `hello-ui` | vertical | Simple UI feature, representative of screen-level slices. Tests require navigating to a screen and asserting visible elements. |
| `build-config` | horizontal | Cross-cutting concern (Gradle config). Tests are structural (build succeeds, expected outputs exist). No UI interactions. |

These two cover both dimensions of the slice taxonomy: a UI-driven vertical slice and a config-driven horizontal slice.

## 8-Step Pipeline

Each slice goes through:

| Step | Name | Agent Pool |
|------|------|-----------|
| 1 | Research | general |
| 2 | Plan | general |
| 3 | Test Design | test-author |
| 4 | Test Implement | test-author |
| 5 | Test Verify | test-author |
| 6 | Implement | code-author |
| 7 | Verify | code-author |
| 8 | Report | general |

## Experiment Runs

| Run | Test Steps (3-5) | Code Steps (6-7) | Slices |
|-----|-------------------|-------------------|--------|
| A | Claude | Codex | hello-ui, build-config |
| B | Codex | Claude | hello-ui, build-config |

Steps 1-2 and 8 are run by whichever model is available (general pool). The experiment focuses on steps 3-7 where the model-separation contract applies.

## Evaluation Criteria

### Per-Step Metrics

**Test Design (Step 3)**
- Coverage completeness: did the model identify edge cases and error states?
- Clarity: are the given/when/then descriptions unambiguous?
- Missed scenarios: count of test cases a human reviewer adds after review

**Test Implement (Step 4)**
- Syntactic correctness: does the Maestro YAML parse without errors?
- Runnability: do flows launch and execute (even if assertions fail)?
- Assertion quality: are screenshots and checks at the right points?

**Test Verify (Step 5)**
- First-run pass rate: fraction of flows that pass on first attempt
- Debug iterations: number of retry/fix cycles before all green
- Self-sufficiency: did the model fix issues without human intervention?

**Implement (Step 6)**
- Plan adherence: does the code follow the plan from step 2?
- Code quality: idiomatic Kotlin, proper Compose patterns
- First-run test pass rate: how many Maestro flows pass on the first build?

**Verify (Step 7)**
- Diagnosis ability: can the model read Maestro failure output and fix code?
- Fix iterations: number of code changes before all flows pass
- Final pass rate: all flows green?

### Aggregate Metrics

- **Human intervention count**: total times a human had to step in per run
- **Total wall-clock time**: end-to-end duration per slice per run
- **Final parity**: did the new app achieve full parity with the old app?

## Decision Process

After completing all 4 experiment runs (2 slices x 2 configurations):

1. Score each run on the criteria above
2. Compare Run A vs Run B for each slice
3. If one configuration clearly wins on both slices, adopt it
4. If results are mixed (e.g., Claude better at test-design, Codex better at test-implement), consider splitting at a finer granularity
5. Document the decision and rationale in a review section appended to this file

## Results

_To be filled after experiment execution._
