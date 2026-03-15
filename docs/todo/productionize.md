# Productionize Orchestration Tooling

Tasks deferred for a dedicated research pass with a tailored prompt.

## Formula Description Templates
- [ ] Decide whether formula templates stay thin (enriched at pour time by scaffolder) or get fleshed out in the formula itself
- [ ] Ensure bead descriptions contain actionable instructions, not just labels, per loop-builder.md spec

## Multi-Model Support
- [ ] Add Codex as a supported model in ralph loops (models.yaml, ralph-once.sh invocation)
- [ ] Run model experimentation plan from e2e-test-harness.md (Claude vs Codex across step types)
- [ ] Document results and finalize pool-to-model assignments

## Slice Pipeline Skills — Harden and Iterate
- [ ] Apply fixes from `docs/todo/test-step-hardening.md` to all three test skills (test-design, test-implement, test-verify)
- [ ] Create clear skills for each remaining pipeline step (research, plan, implement, verify, report) with the same rigor as the test skills
- [ ] Fix results.json vs results.yaml inconsistency across pipeline-flow.md and test-verify skill
- [ ] Add gate criteria to test-verify and verify steps (100% pass required to close bead)
- [ ] Add handoff validation to each skill (fail fast on missing/malformed input from prior step)
- [ ] Add assertion traceability to test-implement (map flow assertions back to test-design assertions)
- [ ] Add false-pass detection to test-verify (reject flows with zero assertions)
- [ ] Define structured debugging protocol and modification boundaries for test-verify
- [ ] Run full research → test-design → test-implement → test-verify pipeline on many real slices
- [ ] Review results, identify skill instruction failures, update skills
- [ ] Run the pipeline again on the same slices with updated skills
- [ ] Compare iteration 1 vs iteration 2 results — document what improved and what still breaks
- [ ] Run a third iteration if iteration 2 still has significant skill instruction gaps
- [ ] Finalize skill instructions based on iterative results

## Hardening
- [ ] Fix JSON injection risk in scaffold.sh and ralph-once.sh — shell variables embedded in Python triple-quoted strings break on content containing `'''`. Use environment variables or tempfiles instead.
