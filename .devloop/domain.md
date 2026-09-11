# .devloop/domain.md - devloop itself

Domain knowledge for `/spec` when specifying a change to devloop. The
engineering settings live in `config.md`.

---

## Domain Context

devloop is a test-driven development loop for AI coding agents, shipped as a
plugin for Claude Code and Codex. The product is **prompt text**, not running
software: three skills (`/spec`, `/plan`, `/implement`) and three review agents
(`review-plan`, `review-impl`, `red-team`).

The thesis it defends: an AI coding lifecycle is only as good as its
enforcement. Artifacts create reviewable checkpoints, and independent agents in
fresh context provide the review an author's own context cannot. A methodology
with no gate that can say FAIL is theater.

---

## Architecture Overview

Three commands map to three gates, one per command, plus a convergence back-edge
where `/implement` re-runs the plan gate in-session. Artifacts carry state
between phases: a spec document, then a JSON tracker holding the chunk graph,
per-chunk status, the `plan_review` verdict, and `spec_doc`. `/implement` refuses
to start on a tracker whose `plan_review` did not pass.

Described in full in the README, not restated here.

---

## Domain-Specific Concerns

- **Prompt changes are behavior changes, and behavior here is stochastic.**
  Reading a prompt diff does not tell you whether recall moved. Confidence
  requires measurement over fixtures, and the samples are small enough that
  honest caveats matter more than the headline number.
- **Instruction wording is load-bearing.** Hedging language measurably lowers
  recall ("be conservative", "only high severity") in a way ordinary prose does
  not.
- **Two harnesses, unequal capabilities.** Claude Code registers skills and
  agents; Codex registers skills only. Anything that assumes agent registration,
  or a harness-specific mechanic, breaks half the audience.
- **Scope boundary.** devloop covers the inner loop: specify, plan, build,
  review. It deliberately does not own deploy gates, monitoring, incident
  records, or managed-settings hooks. Adopting lifecycle stages it cannot
  enforce would be cargo-culting.

---

## Quality Standards

- Findings and verdicts are evidence-backed: quote the line, name the concrete
  failure, label uncertainty honestly rather than rounding a guess up to a fact.
- A change to review-agent behavior ships with the evidence that motivated it,
  including refuted candidates. Negative results are recorded, not dropped.
- Prose is harness-agnostic: state the intent and let the harness supply the
  mechanism.
