# iOS Migration Kit

## Context

We have orchestration tooling (beads, ralph loops, skills, formulas) built in the Android playground repo. The goal is to create a portable, self-contained directory (`ios-migration-kit/`) that can be copied to a Mac workspace alongside an iOS project to drive completion of a partial rewrite (~50% done). The iOS app needs unit tests (XCTest) and e2e tests (XCUITest) for all modules, plus implementation of remaining legacy modules in the target architecture.

The kit uses a citation-based migration approach: agents first compress existing code into specs with source file citations, then implementation agents follow those citations to study original code while building in the new architecture.

**What we keep**: beads + ralph core, pool-based model assignment, test workflow patterns
**What we drop**: slice planner web app, 8-step formula, Maestro, bead scaffolder
**What's new**: spec-extraction skills, 3-step migration formula, XCUITest skills, triage workflow

---

## Directory Structure

```
ios-migration-kit/
├── README.md                          # Setup instructions
├── scripts/
│   ├── ralph.sh                       # Outer loop (copy from playground, no changes)
│   ├── ralph-once.sh                  # Inner loop (copy from playground, no changes)
│   ├── bd-done.sh                     # Commit + close (copy from playground, no changes)
│   └── scaffold.sh                    # New: reads _triage.yaml, pours molecules
├── .ralph/
│   └── models.yaml                    # Pool-to-model mapping
├── formulas/
│   └── mol-migration-module.json      # 3-step formula: spec-extract -> implement -> test-verify
├── skills/
│   ├── spec-extract/SKILL.md          # Study source + tests, produce spec with citations
│   ├── migration-implement/SKILL.md   # Implement module using spec citations
│   ├── xcuitest-verify/SKILL.md       # Write + run XCUITest from spec
│   └── module-triage/SKILL.md         # Walk project, produce _triage.yaml
├── templates/
│   ├── spec-template.md               # Spec file format reference
│   ├── triage-template.yaml           # _triage.yaml format reference
│   └── CLAUDE.md.template             # Project CLAUDE.md additions for iOS workspace
└── docs/
    └── workflow.md                     # How to run the full migration workflow
```

When copied to the iOS workspace:
- `scripts/` -> `scripts/`
- `.ralph/` -> `.ralph/`
- `formulas/` contents -> `.beads/formulas/`
- `skills/` contents -> `.claude/skills/`
- `templates/` are reference -- user copies/adapts as needed

---

## Deliverables

### 1. Scripts (copy from playground, no modifications)

- **`scripts/ralph.sh`** -- outer loop, project-agnostic
- **`scripts/ralph-once.sh`** -- inner loop, project-agnostic
- **`scripts/bd-done.sh`** -- commit + close helper

### 2. New script: `scripts/scaffold.sh`

Reads `specs/_triage.yaml` and creates beads:
- For `todo` and `partial` modules: pour `mol-migration-module` molecule (3 beads each)
- For `done` modules: create single `spec-extract` bead (populates spec library for cross-reference)
- Skip `manual` modules entirely
- Add cross-module dependencies from triage data

### 3. Formula: `mol-migration-module.json`

3-step pipeline replacing the 8-step slice pipeline:

| Step | Name | Pool | Depends On | Purpose |
|------|------|------|------------|---------|
| 0 | spec-extract | general | -- | Study legacy + new files, produce spec with citations |
| 1 | implement | code-author | 0 | Build/complete module using spec, run unit tests |
| 2 | test-verify | test-author | 1 | Write XCUITest, run it, debug failures |

Why implement before test-verify: XCUITest needs the feature built to run against. Unlike Android where Maestro tested the old app first, here the module may already be partially done.

Why not separate test-design from test-verify: For XCUITest, the agent can design and implement in one pass. Splitting adds a bead handoff without adding value.

### 4. Skill: `spec-extract`

**Input**: Module name, legacy files, new files, test files (from bead description)
**Output**: `specs/{group}/{module_name}.md`

Spec format:
```
# Module: {name}
Status: todo | partial | done

## Source Files
- `path/to/File.swift` -- {role}

## Test Files
- `path/to/Tests.swift` -- {what it tests}

## Behavior Specification
### {Flow Name}
- **Given** {precondition}
- **When** {action}
- **Then** {expected result}
- **Citations**: `File.swift:45-67`, `Tests.swift:12-30`

## Functionality Specification
### Data Model
{Models, relationships, persistence}
Citations: `Model.swift:1-50`

### Business Logic
{Algorithms, validation, state transitions}
Citations: `ViewModel.swift:80-120`

## Dependencies
- Depends on: {other modules}
- Required by: {dependent modules}
```

Key instructions for the skill:
- Use subagents to read files in parallel when many files
- Cross-reference: which tests cover which behaviors
- Identify gaps: behaviors with no test coverage
- For `partial` modules: note what exists in new architecture vs what needs porting

### 5. Skill: `migration-implement`

**Input**: Spec file path (from bead description)
**Output**: Implemented/completed module + XCTest unit tests

Key instructions:
- Read spec first for high-level understanding
- Follow citations to study original implementation
- For `partial`: only build missing pieces
- Read existing new-architecture files as pattern reference
- Run `xcodebuild build` to verify compilation
- Write unit tests alongside implementation
- Do NOT write e2e tests (that's test-verify)

### 6. Skill: `xcuitest-verify`

**Input**: Module name, spec file path (from bead description)
**Output**: XCUITest classes + `e2e/output/{module}/results.yaml`

Key instructions:
- Read behavioral spec section for test cases
- Write XCUITest classes using XCUIApplication, tap/swipe/assert APIs
- Run via `xcodebuild test -scheme ... -destination 'platform=iOS Simulator,...'`
- On failure: read output, adjust selectors/waits, retry up to 2 times
- Capture screenshots via `XCUIScreen.main.screenshot()`
- Happy paths first, then edge cases

### 7. Skill: `module-triage` (one-time use)

**Input**: Project root
**Output**: `specs/_triage.yaml`

Walks the iOS project:
- Identifies modules by directory structure
- Lists legacy files, new-architecture files, test files per module
- Sets initial status to `unknown` for human review
- Respects `.gitignore`

### 8. Templates

- **`spec-template.md`** -- copy of the spec format above, for reference
- **`triage-template.yaml`** -- example `_triage.yaml` with `done`/`partial`/`todo`/`manual` examples
- **`CLAUDE.md.template`** -- lines to add to the iOS project's CLAUDE.md (beads workflow, skill references, ralph instructions)

### 9. `.ralph/models.yaml`

```yaml
pools:
  general:
    model: "claude-sonnet-4-6"
    description: "Spec extraction and triage"
  test-author:
    model: "claude-sonnet-4-6"
    description: "XCUITest writing and verification"
  code-author:
    model: "claude-opus-4-6"
    description: "Module implementation"
default_model: "claude-sonnet-4-6"
```

### 10. `docs/workflow.md`

Documents the end-to-end workflow:

1. **Setup**: `bd init`, copy scripts/formulas/skills into place
2. **Triage**: Run module-triage skill or manually create `_triage.yaml`, then classify modules
3. **Scaffold**: Run `scripts/scaffold.sh` to create beads from triage
4. **Phase 1 -- Spec extraction**: `scripts/ralph.sh --pool general --iterations 100 --timeout 900`
5. **Checkpoint**: Spot-check specs, verify citations point to real files
6. **Phase 2 -- Implementation**: `scripts/ralph.sh --pool code-author --iterations 50 --timeout 3600`
7. **Checkpoint**: `xcodebuild build` succeeds, unit tests pass
8. **Phase 3 -- Test verification**: `scripts/ralph.sh --pool test-author --iterations 50 --timeout 1800`
9. **Checkpoint**: Review `e2e/output/*/results.yaml`, triage failures
10. **Validation**: Run existing 12 Appium tests as baseline check (manual, not in pipeline)

Overnight wrapper:
```bash
scripts/ralph.sh --pool general --iterations 200 --timeout 600 --max-failures 5
scripts/ralph.sh --pool code-author --iterations 100 --timeout 3600 --max-failures 3
scripts/ralph.sh --pool test-author --iterations 100 --timeout 1800 --max-failures 3
```

### 11. `README.md`

Quick-start:
1. Copy kit contents to iOS workspace (where to put each dir)
2. Prerequisites: `bd` CLI, `claude` CLI, Python 3 + PyYAML
3. Initialize: `bd init && scripts/scaffold.sh`
4. Run: `scripts/ralph.sh --pool general`

---

## Implementation Checklist

- [ ] Create `ios-migration-kit/` directory
- [ ] Copy `ralph.sh`, `ralph-once.sh`, `bd-done.sh` to `ios-migration-kit/scripts/`
- [ ] Create `.ralph/models.yaml`
- [ ] Write `formulas/mol-migration-module.json` (3-step formula)
- [ ] Write `skills/spec-extract/SKILL.md`
- [ ] Write `skills/migration-implement/SKILL.md`
- [ ] Write `skills/xcuitest-verify/SKILL.md`
- [ ] Write `skills/module-triage/SKILL.md`
- [ ] Write `scripts/scaffold.sh` (reads triage YAML, pours molecules)
- [ ] Write `templates/spec-template.md`
- [ ] Write `templates/triage-template.yaml`
- [ ] Write `templates/CLAUDE.md.template`
- [ ] Write `docs/workflow.md`
- [ ] Write `README.md`

---

## Verification

- Run `shellcheck scripts/*.sh` on all bash scripts
- Verify formula JSON is valid: `python3 -c "import json; json.load(open('formulas/mol-migration-module.json'))"`
- Dry-run scaffold against a sample triage YAML to verify bead creation
- Review each SKILL.md for completeness: does it specify inputs, outputs, key instructions, and what NOT to do?
