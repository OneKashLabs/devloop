# .devloop/domain.md - devloop itself

Domain knowledge for `/spec` when specifying a change to devloop. The
engineering settings live in `config.md`.

---

## Domain Context

devloop is a test-driven development loop for AI coding agents, shipped as a
plugin for Claude Code and Codex. The product is prompt text, not running
software: three skills (`/spec`, `/plan`, `/implement`) and two review agents
(`review-plan`, and `review-impl` with conformance, correctness and cleanup
lenses).

Each phase writes an artifact the next phase reviews. The reviews run in agents
with fresh context, because the author's context cannot review its own work.
Every gate can return FAIL.

---

## Architecture Overview

Each command has one gate. `/implement` can also re-run the plan gate
in-session (the convergence back-edge). Artifacts carry state
between phases: a spec document, then a JSON tracker holding the chunk graph,
per-chunk status, the `plan_review` verdict, and `spec_doc`. `/implement` refuses
to start on a tracker whose `plan_review` did not pass.

Described in full in the README, not restated here.

---

## Domain-Specific Concerns

- Prompt changes are behavior changes, and the behavior varies run to run.
  Reading a prompt diff does not tell you whether recall moved; measure it over
  fixtures. The samples are small, so report the caveats with the number.
- Instruction wording changes recall. Hedging language ("be conservative",
  "only high severity") lowers recall in a way ordinary prose does not.
- Two harnesses with different capabilities: Claude Code registers skills and
  agents; Codex registers skills only. Anything that assumes agent
  registration, or a harness-specific mechanic, fails on Codex.
- Scope: devloop covers the inner loop: specify, plan, build, review. It does
  not own deploy gates, monitoring, incident records, or managed-settings
  hooks, and adds no lifecycle stage it cannot enforce.

---

## Quality Standards

- Findings and verdicts are evidence-backed: quote the line, name the concrete
  failure, mark uncertain findings as uncertain; don't state a guess as fact.
- A change to review-agent behavior ships with the evidence that motivated it,
  including refuted candidates. Negative results are recorded, not dropped.
- Prose is harness-agnostic: state the intent and let the harness supply the
  mechanism.
