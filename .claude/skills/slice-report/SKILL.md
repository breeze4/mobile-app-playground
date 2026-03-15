# Skill: slice-report

Generate a test execution report for a completed slice, collecting all artifacts into a structured report.json file.

## When to use

Use this skill at the final step (step 8: report) of the slice pipeline, after test-verify (step 5) and verify (step 7) have completed. This collects all test artifacts and produces the report that the Slice Planner Reports UI displays.

## Instructions

### 1. Identify the slice and locate artifacts

- Accept a slice name as input (e.g., `hello-ui`)
- Look for test output in the following locations (relative to project root):
  - `test-output/{slice-name}/old_app/` — test results from the old app
  - `test-output/{slice-name}/new_app/` — test results from the new app
  - Each flow directory contains: `recording.mp4`, screenshots (`*.png`), and `results.json`
- Look for the slice definition in `docs/slices/` YAML files or in the Slice Planner database

### 2. Collect slice metadata

From the slice definition, gather:
- `slice_name` — the slice identifier
- `slice_type` — "vertical" or "horizontal"
- `description` — human-readable description
- `files` — list of file paths assigned to this slice

### 3. Extract test cases

From the test specification or results files, build the `test_cases` array. Each entry needs:
- `name` — test case name
- `given` — precondition
- `when` — action
- `then` — expected result
- `assertions` — list of specific assertions checked

### 4. Extract test results

From the results.json files in each flow directory, build the `test_results` array:
- `flow_name` — name of the test flow
- `old_app.passed` — boolean pass/fail for old app
- `old_app.duration_ms` — execution time in milliseconds
- `new_app.passed` — boolean pass/fail for new app
- `new_app.duration_ms` — execution time in milliseconds

### 5. Catalog artifacts

For each flow in both old_app and new_app, record:
- `video` — relative path to the recording video (e.g., `old_app/flow-name/recording.mp4`)
- `screenshots` — list of relative paths to screenshot PNGs
- `results` — relative path to the results.json file

Paths must be relative to the report directory (`reports/{slice-name}/`).

### 6. Extract step timings

If step timing data is available from the test runner output or results files, build the `step_timings` array:
- `step` — human-readable step name
- `start_seconds` — when the step starts in the video
- `duration_seconds` — how long the step takes

Also set `video_offset_seconds` — the time offset between the video start and the first test step.

### 7. Copy artifacts and generate report

- Create the directory `tools/slice-planner/reports/{slice-name}/`
- Copy or symlink all artifact files (videos, screenshots, results) into the report directory, preserving the `old_app/` and `new_app/` structure
- Generate `report.json` in the report directory with the following structure:

```json
{
  "slice_name": "...",
  "slice_type": "vertical|horizontal",
  "description": "...",
  "files": ["..."],
  "test_cases": [{"name":"...", "given":"...", "when":"...", "then":"...", "assertions":["..."]}],
  "test_results": [{"flow_name":"...", "old_app":{"passed":true,"duration_ms":0}, "new_app":{"passed":true,"duration_ms":0}}],
  "artifacts": {
    "old_app": {"flow-name": {"video":"...", "screenshots":["..."], "results":"..."}},
    "new_app": {"flow-name": {"video":"...", "screenshots":["..."], "results":"..."}}
  },
  "step_timings": [{"step":"...", "start_seconds":0, "duration_seconds":0}],
  "video_offset_seconds": 0,
  "generated_at": "ISO 8601 timestamp"
}
```

### 8. Validate

After generating the report:
- Confirm `report.json` is valid JSON
- Verify all referenced artifact paths exist on disk
- Verify `slice_name` matches the input slice
- Verify `generated_at` is a valid ISO 8601 timestamp
- Check that test_results flow_names match the artifact keys

## What this skill does NOT do

- Does not run tests — it only collects results from already-completed test runs
- Does not modify the Slice Planner database
- Does not analyze code or determine test coverage
- Does not generate video or screenshots — those come from the test runner
