# Skill: test-verify

Run Maestro e2e flows against a device or emulator and produce a test results summary.

## When to use

Use this skill after the test-implement skill has created Maestro flow files. This skill runs the flows, captures artifacts, and reports results.

## Instructions

### 1. Check prerequisites

Before running any flows, verify:
- Maestro CLI is installed (`maestro --version`)
- An Android emulator or device is connected (`adb devices` shows a device)
- The target app is installed on the device
- Determine which environment config to use (`e2e/config/env.old.yaml` or `e2e/config/env.new.yaml`)

If any prerequisite is missing, stop and report what is needed. Do not attempt to install Maestro or start an emulator.

### 2. Run flows

For each flow file in the target slice directory:

```bash
maestro test --env e2e/config/{env-file}.yaml \
  --output e2e/output/{slice-name}/ \
  e2e/flows/{slice-name}/flow-NNN-{name}.yaml
```

Run flows in sequence (not parallel) to avoid device contention.

### 3. Handle failures

When a flow fails:
- Read the Maestro error output to identify the failing command
- Check if it is a timing issue (add `waitForAnimationToEnd` or `extendedWaitUntil`)
- Check if it is a selector issue (element text changed, ID missing)
- Retry the flow up to 2 times after making adjustments
- If it still fails after 2 retries, mark it as failed and move on

Do not spend more than 2 retry attempts per flow. Flag persistent failures for human review.

### 4. Collect artifacts

After all flows have run, ensure these artifacts are in `e2e/output/{slice-name}/`:
- Screenshots from `takeScreenshot` commands
- Maestro log output
- Any video recordings if enabled

### 5. Produce results summary

Write a results file to `e2e/output/{slice-name}/results.yaml`:

```yaml
slice: <slice-name>
env: <env file used>
run_at: <ISO 8601 timestamp>
results:
  - flow: flow-NNN-{name}.yaml
    status: pass | fail
    retries: <number of retries needed>
    error: <error message if failed, omit if passed>
    screenshots:
      - <list of screenshot filenames>
summary:
  total: <count>
  passed: <count>
  failed: <count>
```

### 6. Report

- If all flows pass, report success with the summary counts
- If any flows fail, list the failing flows with their error messages
- Include the path to the full results file and screenshot directory

## Output

- `e2e/output/{slice-name}/results.yaml` — structured test results
- Screenshots and logs in `e2e/output/{slice-name}/`
- Console summary of pass/fail counts

## What this skill does NOT do

- Does not design test cases (that is the test-design skill)
- Does not write or modify flow files beyond minor retry adjustments (that is the test-implement skill)
- Does not install Maestro CLI or start emulators
- Does not modify application source code to fix test failures
