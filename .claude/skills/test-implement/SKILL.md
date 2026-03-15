# Skill: test-implement

Translate test design YAML into executable Maestro flow files.

## When to use

Use this skill after the test-design skill has produced a `test-design.yaml` for a slice. This skill converts each test case into a runnable Maestro YAML flow.

## Instructions

### 1. Read test design

- Load `e2e/flows/{slice-name}/test-design.yaml`
- Verify all test cases have `name`, `given`, `when`, `then`, and `assertions` fields

### 2. Create flow files

For each test case, create a Maestro flow file at:
```
e2e/flows/{slice-name}/flow-NNN-{test-case-name}.yaml
```

Where NNN is the test case's sequence number, zero-padded to three digits.

### 3. Flow file structure

Every flow file must follow this template:

```yaml
appId: ${APP_ID}
---
# {slice-name}: {test-case-name}
# Given: {given from test design}
# When: {when from test design}
# Then: {then from test design}
- launchApp
# ... setup steps to reach the precondition ...
# ... action steps matching the "when" ...
# ... assertion steps matching each assertion ...
- takeScreenshot: "{slice-name}-{test-case-name}-final"
```

### 4. Maestro command reference

Use these common Maestro commands to implement flows:

- `launchApp` / `stopApp` / `clearState` — app lifecycle
- `tapOn: "text"` or `tapOn: {id: "view-id"}` — tap elements
- `assertVisible: "text"` / `assertNotVisible: "text"` — visibility checks
- `inputText: "value"` — type into focused field
- `scrollUntilVisible: {element: "text", direction: "DOWN"}` — scroll to find elements
- `back` — press back button
- `waitForAnimationToEnd` — wait for transitions
- `takeScreenshot: "name"` — capture screenshot
- `extendedWaitUntil: {visible: "text", timeout: 10000}` — wait with timeout
- `swipe: {direction: "LEFT", duration: 500}` — swipe gestures
- `repeat: {times: N, commands: [...]}` — repeat actions
- `runFlow: "path/to/other-flow.yaml"` — reuse common setup flows

### 5. Screenshot conventions

- Take a screenshot after the final assertion: `{slice-name}-{test-case-name}-final`
- For multi-step flows, take intermediate screenshots at key states: `{slice-name}-{test-case-name}-step-N`
- Screenshot names use kebab-case, no file extension

### 6. Setup and teardown

- If multiple flows share setup steps (e.g., logging in), extract a shared flow to `e2e/flows/{slice-name}/setup-{name}.yaml` and reference it with `runFlow`
- Always start flows with `launchApp` so they can run independently
- Use `clearState` at the start of flows that need a clean app state

### 7. Validate

After writing all flows:
- Confirm each YAML file parses correctly
- Verify filenames match the naming convention
- Verify every test case from the design has a corresponding flow file
- Check that all assertions from the test design are covered by Maestro commands

## Output

One Maestro flow YAML file per test case, placed in `e2e/flows/{slice-name}/`.

## What this skill does NOT do

- Does not design test cases (that is the test-design skill)
- Does not run or verify flows (that is the test-verify skill)
- Does not modify the test design YAML
- Does not create tests for slices that lack a test design
