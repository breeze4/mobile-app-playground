# iOS Migration Kit

Portable tooling for completing an iOS app rewrite using autonomous agent loops. Uses a citation-based approach: agents compress existing code into specs with source citations, then implementation agents follow those citations to build in the new architecture.

## What's in the kit

```
scripts/          Ralph loop scripts (autonomous bead execution)
.ralph/           Pool-to-model configuration
formulas/         3-step migration formula (spec-extract -> implement -> test-verify)
skills/           Claude skills (7: triage, reference-packages, spec-extract, spec-reconcile, migration-implement, xcuitest-verify, progress-report)
templates/        Reference formats for specs, triage, CLAUDE.md
docs/             Workflow documentation
```

## Quick Start

```bash
# 1. In your iOS project root:
bd init

# 2. Copy kit into place
cp -r ios-migration-kit/scripts/ scripts/
cp -r ios-migration-kit/.ralph/ .ralph/
cp ios-migration-kit/formulas/*.json .beads/formulas/
cp -r ios-migration-kit/skills/* .claude/skills/
mkdir -p specs

# 3. Make scripts executable
chmod +x scripts/*.sh

# 4. Set up CLAUDE.md from template
# Copy ios-migration-kit/templates/CLAUDE.md.template content into your .claude/CLAUDE.md
# Fill in {SCHEME}, {SIMULATOR}, {TEST_TARGET}, etc.

# 5. Triage modules + identify reference packages
claude -p "Use the module-triage skill to inventory this project"
# Review and classify specs/_triage.yaml
claude -p "Use the reference-packages skill"

# 6. Scaffold beads
scripts/scaffold.sh

# 7. Run migration (see docs/workflow.md for the full 2-week workflow)
scripts/ralph.sh --pool general --iterations 100     # spec extraction
# Run spec-reconcile, resolve decisions, then:
scripts/ralph.sh --pool code-author --iterations 50   # implementation
scripts/ralph.sh --pool test-author --iterations 50   # e2e tests

# 8. Check progress anytime
claude -p "Use the progress-report skill"
```

## Prerequisites

- `bd` CLI (beads issue tracker)
- `claude` CLI (Anthropic)
- Python 3 + PyYAML
- Xcode with iOS Simulator

## Pipeline

| Step | Pool | Model | What it does |
|------|------|-------|-------------|
| spec-extract | general | sonnet | Reads legacy + new code, produces spec with citations |
| implement | code-author | opus | Builds/completes module using spec, writes unit tests |
| test-verify | test-author | sonnet | Writes + runs XCUITest e2e tests |

See `docs/workflow.md` for the full workflow with checkpoints.
