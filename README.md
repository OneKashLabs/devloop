[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Plugin-blueviolet.svg)](https://claude.com/claude-code)
[![Codex](https://img.shields.io/badge/Codex-Plugin-10A37F.svg)](https://developers.openai.com/plugins/build/plugins)

# devloop

A test-driven development loop for
[Claude Code](https://docs.anthropic.com/en/docs/claude-code) and
[Codex](https://developers.openai.com/plugins/build/plugins):
specify, plan, implement, with independent review agents that catch
design bugs before coding and correctness bugs before commit.

```
/spec          Clarify what to build (user stories, acceptance criteria),
    ↓            or check an existing design doc (spec validation gate)
/plan          Plan how to build it (chunks, dependencies, tracker);
    ↓            a bug fix starts with a proof: a failing test or probe
review-plan    Independent agent reviews the plan; review, fix and
    ↓            re-review run unattended, up to 3 rounds by default
checkpoint 1   You approve the reviewed plan and every decision it made
    ↓
/implement     Build it with TDD (failing test → code → pass), per chunk
    ↓
review-impl    Independent agent reviews the diff: conformance,
    ↓            correctness and cleanup lenses
checkpoint 2   You approve the findings and fixes, then finish steps run
   │
   └─ converge  If a review finding invalidates the plan (not only the
      (back-edge) code), /implement appends corrective chunks, re-gates
                 them via the review-plan agent and builds them, up to
                 the round limit (Convergence: auto, the default)
```

Small fixes take the fast lane (no tracker): `/plan` checks the size at the
end of its analysis and takes it itself; see `/plan`'s sizing table.

Each command ends at a gate. The review agents run in a context that did
not write the plan or the code.

Changes in 4.0, including what breaks for 3.x users (`red-team` is gone;
use `review-impl` lenses): [CHANGELOG.md](CHANGELOG.md).

## Ad-hoc prompting vs devloop

Ad-hoc prompting means a run of prompts, perhaps plan mode, and a
`CLAUDE.md` or `AGENTS.md` for the project's rules. It leaves the steps
around the code to you:

- Requirements and design get settled while the code is being written.
  `/spec` and `/plan` settle them first, and you approve the reviewed plan
  before any code.
- The session that wrote the code also reviews it. devloop reviews the plan
  and the code in a context that didn't write them.
- The plan lives in the conversation, and compaction or a new session loses
  detail. devloop keeps it in a tracker file that survives a reset.
- "Done" can arrive without a test for each requirement. Chunks with logic
  start from a failing test, and the review checks each acceptance
  criterion against a test.
- You ask for tests first, a review and a pause before commit, again each
  session. devloop builds the process in, and an `## Autonomy` section sets
  how much runs without asking.

## What the review layer adds

- A plan review runs before any code is written.
- `review-impl` checks the diff through three lenses: conformance,
  correctness and cleanup (see The `review-impl` agent below). A bug that
  follows a flawed plan is caught only by the correctness lens; a correct
  change that is off spec only by conformance.
- The correctness lens first lists every candidate defect, then a verify
  pass keeps only CONFIRMED and PLAUSIBLE findings.
- Both reviews use one list of six concerns in three groups: does the
  change do what was asked (completeness, correctness, regression), does
  it hold up (robustness, blindspots such as security and privacy), and
  can it be maintained (project rules, boundaries, stale docs,
  configuration, dependencies). Each checklist item sits under one
  concern.
- `/spec` asks about the non-functional requirements that apply
  (performance, security, accessibility and others) and records each with
  a number and a way to verify it, so it becomes an acceptance criterion
  the review checks.

## How the loop works

The loop is not strictly linear. If an `/implement` review finding
invalidates the plan itself (a chunk's whole approach is wrong, or the
review surfaces work no chunk covers), `/implement` converges: it appends
corrective chunks to the tracker, re-runs the plan-review gate by spawning
the `review-plan` agent in-session (not by re-invoking `/plan`, which would
regenerate the tracker), and builds them once that gate passes. By default
this runs without asking, at most as many times per session as the review
rounds allow, and checkpoint 2 lists every correction it made; set
`Convergence: ask` to approve each one first. A finding that the *spec*
was wrong always comes to you.

The interactive steps are skills (`/spec`, `/plan`, `/implement`); the
isolated steps that return a verdict are agents (`review-plan`,
`review-impl`). The split follows the kind of work, so it ports across
harnesses. It also means you start each of the three commands yourself: a
skill can't call another skill, and coupling them into one agent would tie
the loop to a single harness.

The gates depend on spawning those agents. On a harness with no subagent
capability at all, each gate degrades to an in-context self-check and
loses the author-evaluator isolation; the skills state this at each gate.

## What's included

| Piece | Type | Invocation | Purpose |
|-------|------|-----------|---------|
| [spec](skills/spec/SKILL.md) | Skill | `/spec <feature>` | User stories, acceptance criteria, edge cases |
| [plan](skills/plan/SKILL.md) | Skill | `/plan <feature>` | Chunk decomposition, dependency graph, JSON tracker, plan-review gate |
| [implement](skills/implement/SKILL.md) | Skill | `/implement <feature>` | TDD chunk cycle against the tracker, code-review gate |
| [review-plan](agents/review-plan.md) | Agent | auto (`/plan`; `/implement` convergence) | Plan review in fresh context (six concerns plus TDD quality) |
| [review-impl](agents/review-impl.md) | Agent | auto (`/implement` Phase 3) / manual | Code review in fresh context: conformance, correctness and cleanup lenses |

### Reviewing any diff

To review a diff with no plan (a hotfix, someone else's branch), invoke
`review-impl` with the diff range and say there is no tracker. It won't
look for one; conformance checks the change against the request you state,
and the correctness and cleanup lenses discover the project's standards at
runtime.

## The `review-impl` agent

`review-impl` is the plugin's code reviewer. It reads the diff in a fresh
context, read-only, through three lenses:

- **Conformance**: the change does what the plan says, and each acceptance
  criterion is marked confirmed (a quoted test asserts it), plausible (the
  code does it but no test asserts it) or refuted.
- **Correctness** (5 angles): line-by-line diff scan, removed-behavior
  auditor, cross-file caller/callee tracer, language-pitfall
  specialist, wrapper/proxy correctness.
- **Cleanup** (5 angles): reuse, simplification, efficiency, altitude,
  maintainability (stale docs, hard-coded environment values, dependency
  and versioning rules, error messages).
- **Conventions** (runs in every lens): reads the project's own rules
  file (`CLAUDE.md`/`AGENTS.md`) and `.devloop/config.md` at runtime and
  flags only rules it can quote. A quotable violation with a real fault
  (security, data loss, a broken documented invariant, a robustness gap)
  fails the gate like a correctness bug; a pure style violation stays
  a warning.

Each report ends with one JSON list of findings. The session that wrote
the code joins the lists from all lenses and records what it did with each
finding (fixed, skipped or no change needed). When the project's config names a
`Verify recipe`, the author also drives the change end to end before the
second checkpoint and shows you the result; it is evidence for you, not an
approval, so the reviewers still gate the code.

Correctness findings are verified (PLAUSIBLE by default, REFUTED only
when the code proves it), then a sweep looks for gaps the first pass
missed. Each finding says whether the change introduced it or it was
pre-existing; a pre-existing bug is reported,
not fixed in the change, and never fails the gate on its own.

It takes `lenses`: `conformance`, `correctness`, `cleanup`, or `all`
(default).

```
Use the review-impl agent with lenses: all to review implementation against [tracker]
Use the review-impl agent with lenses: cleanup on HEAD~3..HEAD, no tracker
```

At the `/implement` gate, a small diff (one production file plus its
tests) gets one `review-impl` with `lenses: all`; anything larger gets one
agent per lens in parallel. Pre-registered evals checked the merged
reviewer against the two agents it replaced and against real bugs that
had got past an earlier review; results and limits are in CHANGELOG 4.0.0.

## Install

**Claude Code.** Install from the marketplace:

```
/plugin marketplace add OneKashLabs/devloop
/plugin install devloop@onekashlabs
```

Claude Code auto-discovers the three skills (`skills/`) and two agents
(`agents/`); the manifest is `.claude-plugin/plugin.json`. To vendor the
plugin instead, copy `skills/` and `agents/` into your project's `.claude/`
directory.

**Codex.** Install from the same marketplace:

```
codex plugin marketplace add OneKashLabs/devloop
codex plugin add devloop@onekashlabs
```

Codex reads `.codex-plugin/plugin.json` and its own catalog
(`.agents/plugins/marketplace.json`). Both harnesses use the same three
skills. A Codex plugin carries skills, MCP servers, assets and hooks but
not agents (Codex custom agents are TOML files in `.codex/agents/`), so the
two review agents under `agents/` ship as prompt files: the skills spawn
them as subagents where the harness supports delegation, and otherwise
fall back to the in-context self-check the gates document.

**Other Agent Plugins clients.** The repo root also carries a `plugin.json`
in the vendor-neutral [Agent Plugins](https://agent-plugins.org) 1.0.0 format,
validated against the published schema, so the three skills install on
clients that support the standard (Kiro, for one, has [announced
support](https://kiro.dev/blog/powers-supports-plugins/)). Clients that support
subagent delegation get the isolated-context review; the rest degrade to the
self-check, the same as Codex. Claude Code and Codex read their own manifests
and ignore this one.

Then give the loop project context in a `.devloop/` directory at your
project root:

```
.devloop/
  config.md    # engineering: build/test/lint, architecture, standards,
               #   blindspots, commit conventions, and the spec/tracker
               #   directory settings. Read by /plan, /implement,
               #   review-plan, review-impl, and /spec (which
               #   reads the spec-directory setting from here).
  domain.md    # domain context, architecture overview, domain-specific
               #   concerns. Read by /spec.
  trackers/    # impl-tracker-<feature>.json, written by /plan
```

Each skill and agent resolves its config as `.devloop/<file>` in your
project, else generic mode (the loop still runs, with less
project-specific insight). This is why a plugin install works: the skills
live in a read-only cache, but they read `.devloop/` from your project,
not the cache. There is no copied-in fallback; `.devloop/` is the only
project-config source.

The fastest start is to copy the closest
[`examples/<stack>/`](examples/) directory (`typescript-node`, `python`,
`rust`, `android-kotlin`; each holds a `config.md` and a `domain.md`) to
`.devloop/` in your project and adapt it.

Commit `config.md` and `domain.md` so the whole team shares one
context. `.devloop/trackers/` holds in-progress work; commit it for
cross-machine resumability or gitignore it, your call. Each tracker's
latest review reports (`<feature>-plan-review.md`,
`<feature>-code-review.md`) sit next to it and follow the same choice.

### Optional `## Autonomy` section

The loop stops for you at two fixed
checkpoints: before `/implement` builds anything, and after the code
review, before anything is committed or shipped. An `## Autonomy` section
in `config.md` tunes the unattended stretches between them: how many
review rounds a gate runs before its checkpoint (default 3), whether plan
corrections run on their own (`Convergence: auto`, the default, or `ask`),
the finish steps that run after you approve the second checkpoint (default
none), and extra conditions that stop the run:

```markdown
## Autonomy

- Review rounds: 3
- Convergence: auto
- Finish steps:
  1. Run the full test suite and lint
  2. Commit (see Commit Conventions)
- Stop and ask on: anything that publishes outside this repository
```

The rules, and the stop it can't remove (a check that still fails after a
fix attempt), are in
[review-and-finish.md](skills/implement/references/review-and-finish.md)
§Autonomy.

Three more optional settings, all shown in the examples: a
`Pre-review checks` list under Build & Test Commands (lint or static checks
`/implement` runs and fixes before the code review), a `Verify recipe` list
(how to build, launch and drive the project to see a change working before
checkpoint 2; see
[review-and-finish.md](skills/implement/references/review-and-finish.md)
§Runtime verification), and a `done-trackers: keep | archive | delete` line
next to `tracker-directory` for what happens to a finished tracker (default
keep).

## Optional: recording that checks ran (rung)

`review-impl` quotes the test line that proves each acceptance criterion
and verifies each correctness finding before reporting, but the green step
still trusts that the agent ran the tests it says passed.
[rung](https://github.com/rung-dev/rung) records whether a check drove the
real surface (not only an isolated test or a reading of the code) and
whether an independent context ran it, then gates on that record. Its
record of each check lets anyone re-check the TDD green step.

rung is optional and not bundled. devloop ships only markdown and
a bash validator, with no runtime dependencies; rung is a separate
`pip install rung-ai` CLI (or GitHub Action). To use it, wrap the
regression run in `rung run --rung 1` and gate CI on `rung gate`
(exit `0` is the only pass). Keep it out of the core loop unless you want
CI-enforceable proof that the checks were real.

## Related work

Anthropic's [AI-Native SDLC
playbook](https://claude.com/blog/the-ai-native-sdlc-playbook) reframes the
classic six stages (Plan, Design, Build, Test, Deploy, Maintain) as a loop in
which each stage commits a version-controlled artifact the next stage reads,
with governance enforced while the agent works. devloop is a concrete implementation of that loop's inner stages:
`/spec` commits a spec, `/plan` commits a reviewed JSON tracker, and
`/implement` builds test-first behind review agents that grade the work in a
context that did not write it.

devloop works per change. Most engineering fundamentals are project setup
that devloop uses but does not own:

| Area | Where it lives |
|---|---|
| Requirements, including non-functional | `/spec` |
| Design and its review | `/plan` and `review-plan` |
| Automated tests | `/implement` (test first, per chunk) |
| Code review | `review-impl` |
| Documentation | the maintainability checks, and post-implementation docs |
| Build, test and run commands (developer experience) | your `.devloop/config.md` |
| Source control and commit rules | your config's commit conventions and finish steps |
| CI, deployment, monitoring, incident response | your CI and harness (managed settings, hooks) |
| Team process (planning, retrospectives, feedback) | your team |

The grouping of non-functional requirements in `/spec` follows Microsoft's
[Code With Engineering
Playbook](https://github.com/microsoft/code-with-engineering-playbook)
(CC BY 4.0), rewritten for this loop.

[GitHub Spec Kit](https://github.com/github/spec-kit) is a spec-driven
development toolkit in the same space, with a comparable specify -> plan ->
tasks -> implement flow across several coding agents. devloop's `/spec ->
/plan -> /implement` shape covers similar ground; where it differs is the
review layer: two independent agents (`review-plan`, and `review-impl`
with three lenses) run in author-isolated context as hard gates between the
phases, and the loop is TDD-first with a JSON tracker that survives context
resets. For the broader spec-driven tooling ecosystem, start with Spec Kit;
for the gated, review-heavy loop, devloop is narrower by design.

## License

Apache-2.0. See [LICENSE](LICENSE).
