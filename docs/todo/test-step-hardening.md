# Test Step Hardening Analysis

Review of steps 3-5 (test-design, test-implement, test-verify) of the mol-slice-pipeline molecule. These are the most critical steps — they define the contract that the implementation must satisfy.

## Cross-Cutting Issues

### 1. results.json vs results.yaml inconsistency
`docs/e2e-experiment/pipeline-flow.md` specifies `results.json`. The test-verify skill specifies `results.yaml`. Pick one, fix the other. Downstream tooling (report step, bead note updater) will break if this isn't consistent.

### 2. No gate criteria between steps
Nothing defines what pass rate is required to advance to the next step. Can test-verify close with 2/5 flows passing? Can verify (step 7) proceed if test-verify only got 80%?

**Required gates:**
- test-verify: 100% pass against old app before bead can close
- verify: 100% pass against new app before bead can close
- If not 100%, bead stays open and gets flagged for review

**Questions:**
- Should there be a "close with caveats" option for known-flaky tests?
- Should partial pass rates be recorded even if the bead can't close?

### 3. No structured handoff contract between steps
Each skill says what it produces, but the consuming skill doesn't validate what it receives.

**Required validations:**
- test-implement must fail fast if `test-design.yaml` is missing or has malformed entries
- test-verify must fail fast if no flow files exist in the slice directory
- verify (step 7) must fail fast if test-verify (step 5) didn't produce passing results

**Questions:**
- Should handoff validation be in the skills themselves or in a shared pre-check?
- Should the bead system enforce that predecessor beads are closed before a step can start? (It should via deps, but worth confirming.)

## test-design Gaps

### 4. No coverage minimums or categories
The skill says "cover happy paths, edge cases, error states, navigation" but doesn't enforce it. An agent could write 2 happy path tests and call it done.

**Proposed fix:**
- Minimum 1 test per applicable category (happy, edge, error), or explicit justification for why a category doesn't apply
- Each test case tagged with its category in the YAML output
- Report step can then verify coverage breadth

**Questions:**
- What's a reasonable minimum test count per slice? 3? 5? Depends on slice complexity?
- Should the test-design skill produce a coverage summary showing categories covered?

### 5. No data dependency / precondition handling
The `given` field captures preconditions in English, but there's no structure for how to achieve that state. This becomes a problem in test-implement when the agent has to figure out setup steps from scratch.

**Proposed fix:**
- Add an optional `setup_strategy` field to test cases: `clean_state`, `requires_auth`, `requires_data`, `requires_navigation`
- For complex preconditions, test-design should specify the setup sequence, not just the end state
- Shared setup flows should be identified at design time, not discovered during implementation

**Questions:**
- How does the existing app handle test data? Is there a way to seed state?
- Should we define a standard set of "app states" that setup flows can establish?

### 6. No cross-reference to research step output
test-design doesn't require reading or referencing the research bead's notes. The research step identifies behaviors and edge cases. test-design should consume that and demonstrate coverage.

**Proposed fix:**
- test-design skill instructions must require reading the research bead notes
- test-design output should include a `research_coverage` section mapping research findings to test cases
- Uncovered research findings should be explicitly listed as "out of scope" with justification

## test-implement Gaps

### 7. No syntax validation mechanism
"Confirm each YAML file parses correctly" is hand-wavy.

**Proposed fix:**
- Require running `maestro test --dry-run` if available, or YAML parse validation
- Flow files that don't parse should block bead closure

**Questions:**
- Does `maestro test --dry-run` exist? If not, what's the best validation approach?
- Should we write a simple validator script that checks Maestro-specific structure?

### 8. No guidance on dynamic/non-deterministic content
Real apps have timestamps, user-specific greetings, dynamically loaded content. The skill has zero guidance on:
- Regex matchers (`assertVisible: {text: ".*cameras.*", regex: true}`)
- Waiting for network-loaded content
- Handling content that changes between runs

**Proposed fix:**
- Add a "dynamic content" section to the skill with patterns for common scenarios
- Default to generous timeouts for any assertion that follows a network operation
- Require `extendedWaitUntil` instead of bare `assertVisible` when content is loaded async

### 9. No assertion traceability
No mechanism ensures every assertion from test-design.yaml actually appears in the flow file. An agent could write a flow that launches the app and takes a screenshot without checking anything.

**Proposed fix:**
- Each Maestro assertion command in the flow must have a comment referencing the test-design assertion it satisfies
- test-implement output should include a traceability check: count of design assertions vs flow assertions
- Minimum: every flow must contain at least one `assertVisible` or equivalent

### 10. No app state reset strategy
The skill mentions `clearState` but doesn't define when it's mandatory.

**Proposed fix:**
- Flows that modify state (form submissions, toggles, deletions) must begin with `clearState`
- Flows that only read state can skip `clearState` but must document the assumption
- Default recommendation: always `clearState` unless performance is a concern

## test-verify Gaps (Most Critical)

### 11. Retry logic is too shallow
2 retries with no structured diagnosis. Agents will waste retries on blind re-runs.

**Proposed debugging protocol:**
1. Read error output — what command failed?
2. Check screenshot at failure point — is the element present but with different text? Is the screen wrong entirely?
3. Classify failure: timing (element not yet loaded), selector (element doesn't exist), state (wrong screen), environment (emulator crash)
4. Apply category-specific fix:
   - Timing: add `waitForAnimationToEnd` or `extendedWaitUntil`
   - Selector: check element hierarchy, update selector
   - State: add setup steps or `clearState`
   - Environment: report and halt, don't retry

### 12. No distinction between flaky and deterministic failures
A timing issue that passes on retry is different from a wrong selector. Results should capture this:

```yaml
results:
  - flow: flow-001.yaml
    status: pass
    retries: 1
    failure_type: timing  # timing | selector | state | environment | unknown
```

**Questions:**
- Should flaky tests (pass on retry) trigger a flow fix even though they eventually passed?
- What's the threshold for "this flow is too flaky to trust"?

### 13. No false-pass detection
The biggest risk: a test "passes" but validates nothing meaningful.

**Proposed fix:**
- Every flow must contain at least one `assertVisible` or equivalent assertion
- Assertion count in flow should be >= assertion count in test-design for that test case
- Flows with zero assertions should be rejected by test-verify before running

### 14. No app state verification before running
The skill checks app installed + emulator running, but not app state. A previous flow could leave the app on a settings screen.

**Proposed fix:**
- Mandate `stopApp` + `launchApp` (or `clearState`) between each flow run
- Verify the expected start screen before proceeding with test steps
- Add a health check flow (`flow-000-health-check.yaml`) that validates basic app launch

### 15. No structured failure escalation
After 2 retries, the skill says "mark as failed and move on." But different failures need different responses:
- **Flow bug** (test-implement wrote a bad flow) → re-open test-implement bead
- **App bug** (existing app has a real defect) → flag for human review with evidence
- **Environment issue** (emulator crashed) → retry the whole run

**Proposed fix:**
- test-verify must classify each failure and record the classification
- Flow bugs: bead notes should say "test-implement needs revision" with specific flow + error
- App bugs: bead notes should say "possible app defect" with screenshot evidence
- Environment: bead notes should say "environment failure, needs re-run"

### 16. Acceptable modification boundaries undefined
The skill says "minor retry adjustments" to flows. What qualifies?

**Allowed modifications during test-verify:**
- Adding waits (`waitForAnimationToEnd`, `extendedWaitUntil`)
- Increasing timeouts
- Adding `stopApp`/`clearState` for state reset
- Fixing obvious typos in selectors

**Not allowed (requires reopening test-implement):**
- Changing assertion text or expected values
- Removing assertions
- Changing the flow sequence
- Adding new steps not in the test design
- Changing the test's intent

## Priority Order

1. Gate criteria (#2) — pipeline can advance with broken tests without this
2. False-pass detection (#13) — green builds that prove nothing
3. Assertion traceability (#9) — ensures test-implement covers test-design
4. Debugging protocol (#11) — where most agent time will be spent
5. Modification boundaries (#16) — prevents test-verify from gutting the test suite
6. Results format inconsistency (#1) — quick fix, prevents tooling bugs
7. Coverage minimums (#4) — prevents shallow test suites
8. Handoff validation (#3) — prevents wasted work on bad inputs
9. Everything else — important but lower blast radius
