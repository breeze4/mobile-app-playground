# Productionize Orchestration Tooling

Tasks deferred for a dedicated research pass with a tailored prompt.

## Formula Description Templates
- [ ] Decide whether formula templates stay thin (enriched at pour time by scaffolder) or get fleshed out in the formula itself
- [ ] Ensure bead descriptions contain actionable instructions, not just labels, per loop-builder.md spec

## Multi-Model Support
- [ ] Add Codex as a supported model in ralph loops (models.yaml, ralph-once.sh invocation)
- [ ] Run model experimentation plan from e2e-test-harness.md (Claude vs Codex across step types)
- [ ] Document results and finalize pool-to-model assignments

## Hardening
- [ ] Fix JSON injection risk in scaffold.sh and ralph-once.sh — shell variables embedded in Python triple-quoted strings break on content containing `'''`. Use environment variables or tempfiles instead.
