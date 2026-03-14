# Skill: test-design

Analyze a slice definition and produce structured given/when/then test cases for Maestro e2e flows.

## When to use

Use this skill when you have a slice definition (from slice planning) and need to design e2e test cases before implementing Maestro flows. This is the first step in the e2e testing pipeline.

## Instructions

### 1. Gather inputs

- Read the slice definition from `docs/slices/` or the slice planner database
- Read any research notes or implementation plans associated with the slice
- Identify the screens, user interactions, and expected behaviors the slice covers

### 2. Analyze existing app behavior

- Review the source code for the slice's packages to understand what the feature does
- Identify all user-visible entry points (screens, buttons, navigation paths)
- Note any data dependencies (API calls, database reads, authentication state)
- Identify error states and edge cases (empty lists, network errors, permission denials)

### 3. Design test cases

For each identifiable user flow, write test cases covering:

- **Happy paths**: The primary intended usage of the feature
- **Edge cases**: Empty states, boundary values, long text, special characters
- **Error states**: Network failures, missing permissions, invalid data
- **Navigation**: Entering and leaving the feature via all possible routes

Each test case must have:
- A short, descriptive `name` (kebab-case, used in the flow filename)
- `given`: The precondition (app state before the test starts)
- `when`: The user action being tested
- `then`: The expected visible result
- `assertions`: A list of specific things to verify on screen

### 4. Order and number test cases

- Order test cases from simplest to most complex
- Happy paths first, then edge cases, then error states
- Number them sequentially (these become the NNN in `flow-NNN-name.yaml`)

### 5. Produce output

Write the test design to `e2e/flows/{slice-name}/test-design.yaml`.

## Output

```yaml
slice: <slice-name>
test_cases:
  - name: <kebab-case-name>
    given: <precondition in plain English>
    when: <user action in plain English>
    then: <expected result in plain English>
    assertions:
      - <specific visible element or state to verify>
      - <another assertion>
```

## What this skill does NOT do

- Does not write Maestro YAML flows (that is the test-implement skill)
- Does not run tests or verify them (that is the test-verify skill)
- Does not modify application source code
- Does not design unit tests or integration tests, only e2e UI tests
