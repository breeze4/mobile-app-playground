# Pipeline Flow: Slice Lifecycle

End-to-end documentation of how a single slice moves through the 8-step pipeline, including artifact storage, bead integration, and test result propagation.

## The 8-Step Pipeline

```
research -> plan -> test-design -> test-implement -> test-verify -> implement -> verify -> report
```

### Step Details

**1. Research** (agent_pool: general)
- Analyze existing app code for this slice
- Identify behaviors, edge cases, dependencies
- Output: research notes in bead notes

**2. Plan** (agent_pool: general)
- Create implementation plan for the new app
- Output: plan document in bead notes

**3. Test Design** (agent_pool: test-author)
- Write behavioral test cases in given/when/then format
- Output: structured YAML test case definitions
- Stored at: `e2e/flows/{slice-name}/test-design.yaml`

**4. Test Implement** (agent_pool: test-author)
- Translate test cases into Maestro YAML flows
- Output: runnable Maestro flow files
- Stored at: `e2e/flows/{slice-name}/flow-NNN-*.yaml`

**5. Test Verify** (agent_pool: test-author)
- Run flows against existing (reference) app
- Debug and fix flows until all pass
- Output: test results, videos, screenshots
- Stored at: `e2e/output/{slice-name}/{timestamp}/`
- Bead note updated with: pass/fail summary, artifact paths

**6. Implement** (agent_pool: code-author)
- Write the feature code in the new app
- Must satisfy the test contract from steps 3-5
- Output: source code changes

**7. Verify** (agent_pool: code-author)
- Run Maestro flows against new app
- Fix code until all flows pass (parity achieved)
- Output: test results, videos, screenshots
- Stored at: `e2e/output/{slice-name}/{timestamp}/`
- Bead note updated with: pass/fail summary, parity status

**8. Report** (agent_pool: general)
- Generate post-build report with all artifacts
- Output: summary report with links to videos/screenshots

## Artifact Storage

All test artifacts follow a standard directory structure:

```
e2e/output/{slice-name}/{timestamp}/
  videos/           # Maestro video recordings per flow
  screenshots/      # Screenshots captured during flows
  results.json      # Machine-readable test results
```

### results.json Schema

```json
{
  "slice": "hello-ui",
  "app_id": "com.example.app",
  "timestamp": "2026-03-14T10:30:00Z",
  "step": "test-verify",
  "flows": [
    {
      "name": "flow-001-launch-screen.yaml",
      "status": "PASS",
      "duration_ms": 4200,
      "screenshots": ["screenshots/hello-ui-launch-final.png"],
      "video": "videos/flow-001-launch-screen.mp4"
    }
  ],
  "summary": {
    "total": 3,
    "passed": 3,
    "failed": 0,
    "pass_rate": 1.0
  }
}
```

## Bead Integration

### How the Scaffolder Creates Beads

The scaffolder (see `docs/plans/bead-scaffolding.md`) uses the `mol-slice-pipeline` formula to pour a molecule per slice. Each molecule contains 8 sequentially-dependent child beads, one per step.

```bash
bd mol pour mol-slice-pipeline \
  --var slice_name=hello-ui \
  --var slice_type=vertical \
  --var slice_description="Main activity with Compose-based hello world screen" \
  --var slice_files="app/src/main/java/.../MainActivity.kt"
```

This creates:
- 1 molecule (parent bead for the slice)
- 8 child beads with sequential dependencies (step 1 blocks step 2, etc.)
- Each bead tagged with its `agent_pool`

### Bead Note Updates

On completion of **test-verify** (step 5) and **verify** (step 7), the bead notes are updated with a test results summary:

```
## Test Results

- **Run date:** 2026-03-14T10:30:00Z
- **App ID:** com.example.oldapp
- **Pass rate:** 3/3 (100%)
- **Artifacts:** e2e/output/hello-ui/20260314-103000/

| Flow | Status | Duration |
|------|--------|----------|
| flow-001-launch-screen.yaml | PASS | 4.2s |
| flow-002-hello-text.yaml | PASS | 3.1s |
| flow-003-button-tap.yaml | PASS | 5.0s |
```

This is done by reading `results.json` from the artifact directory and formatting a markdown summary appended to the bead's notes via `bd note`.

### Tagging Beads with Model Assignments

After the experiment results are in (see `model-assignments.md`), the scaffolder formula is updated:

```json
{
  "steps": [
    {"name": "research",       "agent_pool": "general"},
    {"name": "plan",           "agent_pool": "general"},
    {"name": "test-design",    "agent_pool": "test-author",  "model": "<result>"},
    {"name": "test-implement", "agent_pool": "test-author",  "model": "<result>"},
    {"name": "test-verify",    "agent_pool": "test-author",  "model": "<result>"},
    {"name": "implement",      "agent_pool": "code-author",  "model": "<result>"},
    {"name": "verify",         "agent_pool": "code-author",  "model": "<result>"},
    {"name": "report",         "agent_pool": "general"}
  ]
}
```

When molecules are poured, each child bead inherits the `model` tag, which downstream tooling (loop builder, orchestrator) uses to route work to the correct agent.

## Example: Full Pipeline for `hello-ui`

```
1. [research]       Analyze MainActivity.kt, Compose setup, existing UI behavior
2. [plan]           Plan: recreate hello world screen with Compose, matching layout/text
3. [test-design]    Define 3 test cases: app launches, hello text visible, button works
4. [test-implement] Write 3 Maestro flows in e2e/flows/hello-ui/
5. [test-verify]    Run against com.example.oldapp -> 3/3 pass
                    -> artifacts in e2e/output/hello-ui/20260314-103000/
                    -> bead note updated with results
6. [implement]      Write HelloScreen.kt, wire into navigation
7. [verify]         Run against com.example.newapp -> 3/3 pass (parity achieved)
                    -> artifacts in e2e/output/hello-ui/20260314-113000/
                    -> bead note updated with results
8. [report]         Generate summary: full parity, 3/3 flows, links to videos
```
