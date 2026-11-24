# .devloop/config.md - devloop itself

devloop's own engineering config, read by `/plan`, `/implement`, `review-plan`,
`review-impl`, and `/spec`. This repo runs its own loop on itself,
so this is live config, not a sample. The README tells users to commit
`config.md` and `domain.md`; this is that instruction applied here.

---

## Build & Test Commands

```bash
# The full invariant suite. Must report 0 failed before any commit.
./validate.sh

# Validate the Claude Code manifest against the current plugin schema.
claude plugin validate --strict .
```

The product here is prompt text, so `validate.sh` is the whole test suite. It
checks structure and cannot check behavior: a change to what a review agent
finds is covered by no automated check in this repo. See the last
standard below.

**Pre-review checks** (run by `/implement` before the code review; the
conformance lens runs `./validate.sh` itself):

- `claude plugin validate --strict .`

**Verify recipe**: none. The product is prompt text with no runtime surface to drive;
`validate.sh` and the evals are its checks.

---

## Architecture Patterns

- Author-evaluator isolation: the context that wrote the code never approves
  it. A change that lets an author grade its own work breaks this.
- Verdict vocabularies are contracts. An agent's verdict values and the
  consuming skill's branches are two halves of one interface.
- Config is read from `.devloop/` at runtime, never baked into shipped
  prose, and every skill and agent must still function in generic mode when it
  is absent.

The component model (skills in the main loop, agents in fresh isolated context,
and why a skill cannot invoke another skill) is covered in the README and
`domain.md`, not restated here.

---

## Standards to Verify (Quality Checklist §6)

Only the rules `validate.sh` cannot mechanize. Nothing here restates a check
the suite enforces; a rule the suite can check belongs in the suite. Each rule is here because it has broken in this repo; the citation is the
release that fixed it.

- [ ] Every verdict value an agent can emit is branched on by the skill that
      consumes it (2.5.0: a gate branched on `WARN`, which `review-plan` never
      emits; 3.1.1: an overview named only `PASS` where `PASS-WITH-WARNINGS`
      also passes)
- [ ] Every section pointer and heading citation resolves to a heading that
      exists (3.1.1: `chunk-template.md` pointed at a non-existent `§3.1`)
- [ ] Docs describe what the skills do, with no aspirational or stale
      claims (3.1.1: the README called the concrete `examples/` files
      placeholder templates)
- [ ] No project-specific assumption is hardcoded into a shipped skill or agent
      (2.5.0: a hard-coded spec directory)
- [ ] An agent's instructions do not contradict the skill that spawns it
      (2.5.0: `review-impl` required a post-implementation document that
      `/implement` had made conditional)
- [ ] Gate state is written crash-safely and never pre-stamped optimistic
      (3.0.0: a tracker created with `plan_review: "PASS"` before the gate ran)
- [ ] Text duplicated across files has one canonical source, or is verbatim
      identical (3.1.1: marketplace descriptions drifted from `plugin.json`)
- [ ] A change to what a review agent finds is backed by an eval run, not by
      inspection alone (3.2.0: two candidates survived adversarial inspection
      and were then refuted by measurement)

---

## Blindspots to Check (Quality Checklist §5)

- [ ] Codex as well as Claude Code: does this hold where agents are not
      registered as agents, and where no subagent can be spawned?
- [ ] Both manifests bumped together, plus both marketplace catalogs
- [ ] Generic mode: does the loop still run with no `.devloop/` present?
- [ ] Recall: could this make a review agent find less, and would anything
      notice if it did?
- [ ] README, CHANGELOG, and the website (OneKashLabs/devloop-website) still match the new behavior

---

## Commit Conventions

```text
# Short imperative subject; no conventional-commit prefixes in this repo.
Fix broken chunk-template section pointer; extend dash guard to examples

# Release commits carry the version.
v3.2.0: conventions faults block the code review gate
```

- Stage only the files you changed. Never `git add .` or `git add -A`.
- Bump `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` in the same
  commit. A version present in only one manifest is a defect.
- Tag at finalization, not per commit. Prefer folding follow-up changes into
  the current unreleased version and force-moving its tag over cutting a new
  version number.

---

## Autonomy

- Review rounds: 3
- Finish steps: none (the owner commits, tags and publishes)
- Stop and ask on: any push or tag

---

## Documentation Location

```text
CHANGELOG.md      # one section per release, user-visible changes
README.md         # install, the loop, the config convention
examples/<stack>/ # published example configs users copy into .devloop/
.local-docs/      # working notes, specs, eval artifacts (gitignored)
```

```text
spec-directory:    .local-docs/specs/    # /spec writes here, local by choice
tracker-directory: .devloop/trackers/    # /plan writes the tracker (default)
done-trackers:     keep                   # keep | archive | delete a finished tracker (default keep)
```
