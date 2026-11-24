---
name: plan
description: "Structured planning process: explores the code, decomposes a feature into independently-testable TDD chunks with a dependency graph, writes a JSON tracker, and gates the plan through an independent review-plan agent before any code is written (a fast-lane change is built in-session instead, with one code review). Use after /spec (or on its own) and before /implement, to decide how to build it."
argument-hint: "[description of feature, fix, or refactor]"
effort: high
---

# Planning process (chunk decomposition and plan review)

Plan the following before implementation begins: $ARGUMENTS

Planning decides how to build what the spec describes. This skill
produces a reviewable plan, a JSON tracker of independently testable
chunks, and runs it through an independent plan-review gate before any
code is written (a change that fits the fast lane is built in-session
instead). When the gate passes, hand off to `/implement`.

## When to use this process

| Scope | Approach |
|---|---|
| Trivial (typo, rename, version bump; never a bug fix) | Don't plan; make the change directly |
| Fast lane (one production file plus its tests, no new behavior beyond the fix; project rules or config may narrow it) | No tracker; see [review-and-finish.md](../implement/references/review-and-finish.md) §Fast lane |
| Small (not fast-lane, still small) | Small feature shortcut (1-chunk tracker) |
| Medium+ (multi-file, unfamiliar code) | Full process |
| Large (cross-cutting, multi-session) | Full process, thorough decomposition |

**Small feature shortcut:** collapse Phase 2 to a single chunk and keep
the checkpoint light, but still write the tracker (Phase 3) and run the
review gate (Phase 4): small features carry the same regression risk. Use
a 1-chunk tracker (see [tracker-schema.md](references/tracker-schema.md)
§Single-chunk features).

## Supporting files

Load these on demand, not all upfront:

| File | When to load |
|---|---|
| [chunk-template.md](references/chunk-template.md) | Phase 2, when decomposing into chunks (skip for small features) |
| [tracker-schema.md](references/tracker-schema.md) | Phase 3, when creating the tracker (all features) |
| [quality-checklist.md](../implement/references/quality-checklist.md) | Phase 4, only as the fallback self-check if the review-plan agent is unavailable |
| [review-and-finish.md](../implement/references/review-and-finish.md) | Phase 1 (fast lane), Phases 4 and 5: Autonomy, review protocol, edits at a checkpoint |

Each phase must complete before the next begins. The review gate
(Phase 4) runs before the checkpoint (Phase 5), so the user approves a
plan that has already been reviewed.

---

## Phase 1: Analysis

### 1.1 Understand the request

- Identify the request type: new feature, enhancement, bug fix,
  refactor, or test
- Check the spec directory (the spec-directory setting in
  `.devloop/config.md`, default `docs/specs/`) for an existing spec
  file matching the feature. If found, use it as primary input: its user
  stories, acceptance criteria and edge cases become the basis for chunk
  decomposition. (Specs are produced by the
  companion `/spec` skill, which writes to the same configurable
  location.) Note its path, you record it as the tracker's `spec_doc`
  field in Phase 3 so `/implement` and the review agents bind to this
  exact spec instead of globbing the spec directory.
- If the user names a design doc instead (decisions already recorded,
  often with options, mockups or probes), the design doc is the spec:
  record its path as `spec_doc` and turn each decision it records into
  acceptance criteria. A `/spec` check-mode answer becomes an acceptance
  criterion that cites it ("check-mode answer: Q -> A"); it overrides the
  decision it resolves. `review-plan` checks the plan against the
  decisions and those cited answers.
- Ask clarifying questions if the scope is ambiguous

**Bug fix: proof first.** Before decomposing a bug fix, get a proof: a
failing test over the real code, or a live probe, with the failure you
observed. With no proof yet, the first step is the probe, not chunks. The
proof goes in the tracker's `proof` field when Phase 3 writes the tracker,
and the proof test becomes chunk 1's red test. If the probe shows the bug
isn't there, report that and stop without writing a tracker.

### 1.2 Explore the current code

- Read the files that will be affected
- Trace the data flow through the application layers
- Identify existing patterns, utilities, abstractions to reuse
- Check for existing test coverage in the affected area

### 1.3 Check industry standards

- Check official documentation for the frameworks in use, and the
  changelogs and migration guides for your dependency versions
- Identify relevant specs (RFCs, W3C, language specs) and note
  platform-specific conventions, quirks and edge cases

### 1.4 Check project architecture patterns

Load the project's engineering config (build/test/lint commands,
architecture rules, standards, and blindspots, the same context
`/implement` uses). Resolve it as `.devloop/config.md` in the project
root. Verify the change aligns with it. If it's absent or only template
placeholders (`YOUR_*_HERE`), proceed without it:
infer the test/build commands from the project (build files, CI config,
`Makefile`), confirm them with the user before recording them in the
tracker, note the miss in the tracker, and suggest creating one.

Common patterns to verify: layered architecture respected (UI -> Domain
-> Data), repository/service boundaries not bypassed, test doubles match
the project convention (fakes/mocks/stubs), DI bindings exist for new
dependencies, type safety enforced where expected (sealed types, enums,
branded).

### 1.5 Verify signatures and dependencies

Check constructor parameters, return types and method signatures against
the code as it is now.

**Fast-lane check.** At the end of the analysis, take the fast lane when
all of these hold: no tracker exists for this feature (the §3.1 location,
`archive/` included), no spec or design doc was given or found in 1.1, the
request did not come back from the fast lane, and the change fits the
fast-lane row of the When to use this process table as the project's rules and config
narrow it. A bug fix is never Trivial. Then stop planning, write no
tracker, tell the user, and continue with
[review-and-finish.md](../implement/references/review-and-finish.md) §Fast
lane in this session. A Trivial change exits the same way, done directly.
In every other case, or when the user asks for a tracker, plan as below; a
change that came back from the fast lane plans from the tree as it is and
notes the partial fix in the tracker.

---

## Phase 2: Decompose

### 2.1 Chunk decomposition

Break the feature into implementation chunks.
See [chunk-template.md](references/chunk-template.md).

Rules:

- Prefer the fewest chunks that keep each independently testable,
  over-chunking adds handoffs without safety
- Each chunk is independently testable (or marked BATCH)
- Chunks list files to create and modify
- Chunks specify test files and TDD instructions
- Chunks declare dependencies on other chunks
- Optional `notes` field captures pattern hints / pitfalls a resuming
  session can't infer from `name` + files + `tdd`

### 2.2 Dependency graph

Organize chunks into dependency layers, with a final regression chunk
(full suite, build, lint); notation in
[tracker-schema.md](references/tracker-schema.md) §Dependency graph
notation.

---

## Phase 3: Tracker

### 3.1 Check for an existing tracker

Before writing, check the tracker location (the tracker-directory setting
in `.devloop/config.md`, default `.devloop/trackers/`, and its `archive/`
folder) for an existing `impl-tracker-<feature>.json`; move an archived
match back, with its saved review reports, before merging. If one exists,
you are revisiting or re-gating a plan (an `/implement` convergence round
routed back here, or a resumed session), not starting fresh:

- Preserve every chunk already at `status: complete`, and any
  `pending` chunks `/implement` appended during convergence. Do not reset
  their status and do not drop them: regenerating from scratch would make
  `/implement` rebuild finished work and lose the corrective chunks a
  convergence round added.
- Merge the new or revised plan into it: add or edit chunks, update
  `depends_on`, keep the completed work intact. Write
  `plan_review: "FAIL"` before the first chunk edit, so a merge is never
  built under the old verdict.
- Preserve the other top-level fields (`spec_doc`, `issue`): a merge
  edits chunks, it does not re-serialize a fresh object with the schema
  defaults. Appending chunks clears `quality_verification.final` and the
  summaries
  ([review-and-finish.md](../implement/references/review-and-finish.md)
  §Finish steps and close).
- If the old chunks no longer apply, confirm with the user before
  discarding completed chunks, the same way `/spec` Phase 1.5 asks
  "update or start fresh?"

Only when no tracker exists do you create one from scratch in 3.2.

### 3.2 Create or update the JSON tracker

Create (or update per 3.1) a tracker file following the schema in
[tracker-schema.md](references/tracker-schema.md), in the tracker
directory from 3.1 (create it if it doesn't exist). The tracker is always
present, even for single-chunk features. Record the spec path noted in
Phase 1.1 in the `spec_doc` field. Create the tracker with
`plan_review: "PENDING"` (never `"PASS"`): the
gate has not run yet, and pre-stamping `PASS` would let a crash before
Phase 4 leave `/implement` free to build an ungated plan. The Phase 4
gate overwrites `plan_review` with the real verdict.

New chunks start at `status: pending`; chunks
carried over from an existing tracker keep their current status. Record
the acceptance criteria per chunk so `/implement` and the review agents
have a concrete checklist.

Ensure `depends_on` forms a directed acyclic graph: every referenced id
exists and no chunk depends (directly or transitively) on itself.
`/implement` validates this before building and hard-stops on a cycle or
dangling id.

### 3.3 Self-check before the gate

Run these before spawning `review-plan`; they cover the failures plan
review raises most often:

- Every changed constructor, signature or return shape: search the tests
  for its callers and list each test file that breaks in the owning
  chunk's `test_files`.
- Every API, file or behavior the plan names: cite it as `file:line` from
  the code as it is now.
- Every planned test: say in `tdd` why it fails on the current code. A
  test that would already pass is not a red test.
- After editing a chunk's acceptance criteria, re-read that chunk's `tdd`
  and `notes` and fix what no longer matches.

---

## Phase 4: Plan review gate

Run this review on the Phase 3 tracker. Don't hand off to `/implement`
until it completes.

The tracker file is the review input. Spawn the `review-plan`
agent as a subagent so the reviewer operates in a fresh context
without author bias:

```
Use the review-plan agent to review [path to tracker]
(on a re-run, add the previous report)
```

The agent evaluates the six concerns in
[quality-checklist.md](../implement/references/quality-checklist.md)
plus TDD quality, which only the plan has.

This gate runs unattended: don't ask the user between rounds. Run it by
[review-and-finish.md](../implement/references/review-and-finish.md)
§Review protocol: review, revise, re-review up to Review rounds, then
Phase 5.

**FAIL:** write `plan_review: "FAIL"` to the tracker first (so a crash
cannot leave a stale `"PENDING"`/`"PASS"` that lets `/implement` build an
ungated plan), then update the plan and re-run review-plan. When the
rounds are used up, or at a stop
([review-and-finish.md](../implement/references/review-and-finish.md)
§Autonomy), go to Phase 5 with the plan still at `FAIL`.
**PASS or PASS-WITH-WARNINGS:** record the verdict (and any warnings). A
warning is revised only while rounds are left
([review-and-finish.md](../implement/references/review-and-finish.md)
§Review protocol, steps 2 and 3); otherwise go to Phase 5.
**No subagent capability** (the harness cannot spawn agents at all, not
only a failed spawn) **or agent failure** (timeout, error): fall back to
an in-context self-check against
[quality-checklist.md](../implement/references/quality-checklist.md) and
proceed. Note in the tracker that the gate ran without isolation: the
self-check runs without the reviewer's separate context.

Record the verdict in the tracker's top-level `plan_review` field so the
gate survives session resets; `/implement` starts only on `PASS` or
`PASS-WITH-WARNINGS`.

---

## Phase 5: Checkpoint

Planning writes no production code (a bug fix's proof test is the one
exception; the fast-lane check in Phase 1 leaves planning before any fix
is written). Present, then wait for explicit approval:

- Context: why this change is needed
- The plan: acceptance criteria, chunk breakdown with dependency graph,
  files affected, quality verification approach
- The review outcome: verdict per round, warnings still open, and any
  findings the reviewer set aside
- Every decision the plan made, including choices the user hasn't seen
  yet (readings of the spec, scope calls, declined review suggestions)

If your harness has a dedicated plan/approval mode or a structured-choice
prompt, use it; otherwise present the plan as a message and ask the user
to approve or request changes. When the gate ended with the plan at
`FAIL`, say why and offer: one more round, a change, or stop. `/implement`
won't start on a `FAIL`.

Any tracker edit at the checkpoint that changes what a chunk builds or
tests, or the order chunks build in, writes `plan_review: "FAIL"` first
and gets one review, as
[review-and-finish.md](../implement/references/review-and-finish.md)
§Edits at a checkpoint says. Notes that only record approval or
bookkeeping are not such an edit.

### Handoff

Output to the user:

- Tracker file path
- Number of chunks and the dependency layers
- Acceptance criteria count
- Plan review verdict (and any warnings)

```
Next: /implement <feature> (tracker: .devloop/trackers/impl-tracker-<feature>.json)
```

If the review has warnings, note them:
"The plan has N warnings, review them before starting implementation."

**Non-code projects:** If the work covers content, configuration, or
documentation (no executable code), the chunk/tracker model still
applies: treat each chunk as a content unit with validation criteria
instead of tests, and suggest a structured build order.

---

## Planning rules

1. **Trace both ways** -
   Map each criterion to a chunk and each chunk to a criterion. A
   criterion with no chunk is a gap; a chunk with no criterion is scope
   creep.
2. **Take criteria from the spec** -
   Acceptance criteria come from the spec; the plan adds files, chunks,
   dependencies and test strategy. If the criteria need rewriting, the
   spec was wrong: fix it in `/spec`, not here.

---

## Commit guidance

Do not commit proactively. Wait for the user to request it.
Refer to `.devloop/config.md` for project-specific commit conventions
(author, message format, trailers).

---

## Session scope

Planning completes in one session and produces the tracker (or, after the
fast-lane check, hands off to the fast lane). To revisit a
plan later, re-run `/plan`, or edit the tracker directly and re-run the
Phase 4 review gate.
