---
name: implement
description: "Test-driven implementation of a plan produced by /plan: loads the JSON tracker, then per chunk writes a failing test, implements until it passes, runs the code review gate (review-impl with conformance, correctness and cleanup lenses), stops at a checkpoint, then runs the configured finish steps. Use after /plan has produced an approved tracker; requires a tracker whose plan_review gate passed. A fast-lane change (see /plan) takes no tracker and does not use this skill."
argument-hint: "[feature name, or path to the impl-tracker JSON from /plan]"
effort: high
---

# Implementation process (test-driven)

Implement the plan for: $ARGUMENTS

Write tests first, then implement until they pass, so running the tests
checks the code.

This skill builds. The companion `/plan` skill explores the code,
decomposes the work into chunks and runs the plan-review gate; it produces
the tracker this skill reads. The skills don't call each other
mid-process, so with no approved tracker this skill stops and asks you to
run `/plan` first.

## When to use this process

| Scope | Approach |
|---|---|
| Trivial (typo, rename, version bump) | Don't use this skill; make the change directly |
| Fast lane | No tracker; see `/plan`'s When to use this process and [review-and-finish.md](references/review-and-finish.md) §Fast lane |
| Anything larger | Run `/plan` first to produce a tracker, then `/implement` builds it |

`/plan` sizes the work (a small fix becomes a 1-chunk tracker; a
cross-cutting feature becomes a layered one). This skill reads whatever
the tracker holds and builds it chunk by chunk.

## Supporting files

Load these on demand, not all upfront:

| File | When to load |
|---|---|
| [tracker-schema.md](../plan/references/tracker-schema.md) | Phase 1, to read/update tracker status and resume fields |
| [quality-checklist.md](references/quality-checklist.md) | Phase 3, only as the fallback self-check if the review-impl agent can't run |
| [review-and-finish.md](references/review-and-finish.md) | Phase 3: review protocol, checkpoint edits, fast lane, pre-review checks, diff size, combining verdicts, finding policy, runtime verification, checkpoint 2, finish, close |

## Process overview

```text
Phase 1: Load the plan (verify plan_review gate; blocks the TDD cycle)
Phase 2: TDD cycle (per chunk: Red -> Green -> Verify)
Phase 3: Quality verification
  └─ Gate: review-impl agent, by lens (blocks completion), then checkpoint 2
```

Each phase must complete before the next begins. For multi-chunk
features, Phase 2 repeats per chunk in dependency order. Gates are
artifact-triggered: a passing `plan_review` (`PASS` or
`PASS-WITH-WARNINGS`) in the tracker unblocks Phase 2;
all chunks complete triggers the review-impl gate in Phase 3.

---

## Phase 1: Load the plan

The engineering config (build/test/lint commands, standards, blindspots,
and the spec/tracker directory settings) resolves in this order:
`.devloop/config.md` in the project root, else generic mode. Later
mentions of `.devloop/config.md` in this skill refer to that file when it
exists.

### 1.1 Locate the tracker

- Find the tracker `/plan` produced (filename `impl-tracker-<feature>.json`;
  the tracker-directory setting in `.devloop/config.md`, default
  `.devloop/trackers/`)
- If more than one matches, confirm which feature with the user
- Read the plan/spec files the tracker references (`plan_doc`,
  `design_doc`, and `spec_doc`, falling back to any file in the configured
  spec directory (the spec-directory setting in `.devloop/config.md`,
  default `docs/specs/`) only if `spec_doc` is absent) for chunk detail

### 1.2 Verify the plan-review gate

Read the tracker's top-level `plan_review` field:

- `PASS` or `PASS-WITH-WARNINGS`: proceed (note any warnings)
- Anything else, `PENDING` (created but the gate has not run), `FAIL`,
  missing, or no tracker at all: stop without writing code, and report:
  "No approved plan found. Run `/plan <feature>` first, it decomposes the
  work and gates the plan through review-plan." This is a hard stop.

### 1.3 Validate the chunk graph

Before building, confirm the chunk graph is sound, these are the states
where "next `pending` chunk" selection and the "all chunks complete" gate
would otherwise disagree and leave the feature silently unfinished:

- Every `depends_on` id exists and the graph is acyclic (no chunk depends,
  directly or transitively, on itself). A cycle or a dangling id means no
  chunk ever becomes selectable and the loop stalls, so stop and report
  the bad edge to the user instead of building.
- No chunk is stuck at `status: error`. An `error` chunk (set when a chunk
  was blocked) is re-entered here like `in_progress`: read its `notes`,
  resolve the blocker, set it back to `in_progress`, and finish it. If it
  cannot be resolved, stop and surface it, never skip past it (a
  skipped `error` chunk means Phase 3 never triggers).

### 1.4 Orient on the next chunk

- If every chunk is already `complete` when this skill starts, don't run
  the gate on your own: follow Session resumption step 2 (report the
  tracker's state and ask the user)
- Find the next `pending` chunk whose `depends_on` are all `complete`
- Read its `name`, `files_create`/`files_modify`, `test_files`, `tdd`,
  `acceptance_criteria`, and any `notes`, this is a complete handoff
- Read the current state of the files it touches

---

## Phase 2: TDD cycle (per chunk)

Repeat for each chunk in dependency order: **Red** (failing test) ->
**Green** (implement) -> **Verify** (tests pass, no regression).

### 2.1 Start the chunk

Set the chunk `status` to `in_progress` in the tracker before writing
anything. The tracker is a file-based artifact that survives context resets; update it first so a
resuming session knows where work stopped.

### 2.2 Determine the test strategy (Red)

| Chunk type | Test strategy |
|---|---|
| Data class with logic | Computed properties, boundary values |
| Sealed type / union | Property delegation for each variant |
| Repository / service impl | Conversion helpers, filtering, errors |
| Observer / manager | Lifecycle, debounce, state changes |
| Configuration / preferences | Defaults, type conversions, round-trips |
| Composite / aggregating layer | Merge logic, fallbacks, empty states |
| Interface / trait only | No test (tested via downstream fake) |
| UI: state-holder / hoisted state | Test: extract the holder, unit-test transitions |
| UI: rendering only (no logic) | No test (build + regression) |
| DI wiring / config | No test (verified by compilation) |
| Type migration / rename | No test (verified by compilation) |

**State-holder detection:** Hoisted state (`mutableStateOf`,
`useState`, `ref`, `@State`), branching effects (`LaunchedEffect`,
`useEffect` with deps), or input transformation = testable logic.
Extract the holder out of the framework component and unit-test the
transitions. Don't use a "No test" UI row for a UI component that holds a
state machine; test its transitions.

### 2.3 Write failing tests (or verify existing coverage)

If the test strategy says "No test," verify existing coverage is green
and skip to 2.5. Otherwise:

- Write tests referencing the new function/class/property
- Tests describe expected behavior, not implementation
- For new functions: expect compile errors
- For behavior changes: expect assertion failures

**Pre-written tests skip the Red step.** When failing tests already
exist (compliance review, bug reproduction, user-provided case), this
step collapses to "verify they still fail for the right reason." Don't
rewrite or duplicate them.

### 2.4 Run tests, expect failure

Run the project's test command (see `.devloop/config.md`) targeting the
specific test class. Confirm tests fail for the right reason (compile error or
assertion failure, not infrastructure).

### 2.5 Implement production code (Green)

- Follow existing patterns in the codebase
- Reuse existing utilities (don't reinvent)
- Keep changes minimal and focused
- For BATCH chunks: all files change together

### 2.6 Handle constructor and signature cascading

Prefer a signature change that stays compatible with existing callers;
when one can't, cascade it as below.

When adding a dependency to a class or changing a function signature:

- Grep for all test files that instantiate the class or call the function
- Add the new parameter to every test call site
- This is the most common source of compile failures

### 2.7 Clean up dead code

When a fix eliminates a code path, remove the dead code in the same
chunk, not in a later cleanup pass.

- Exception class no longer thrown -> remove class + all catch sites
- Feature flag removed -> remove both branches
- Method parameter no longer used -> remove parameter + update callers

Dead code misleads readers and grep, and the implementer knows best what
became unreachable.

### 2.8 Run chunk tests (Verify)

Run the project's test command targeting the specific test class. All
tests must pass. If a test fails, fix the code (not the test) unless the
test is wrong about expected behavior.

### 2.9 Regression and build (last chunk)

For intermediate chunks, chunk tests are sufficient. After the last
chunk (or if a chunk touches widely-shared code), run the full suite,
the build/compile command and the lint command. Check for regressions. Note pre-existing
flaky tests but don't block.

### 2.10 Complete the chunk and manage context

Set the chunk `status` to `complete`. Then decide on context:

Continue in the same session by default. Reset only when context is
degrading. When you do reset, the tracker
(`name` + `files_*` + `tdd` + `acceptance_criteria` + any `notes`) is a
complete handoff. Prefer a clean reset over lossy compaction. If your
harness supports focused compaction, scope it to the current chunk,
tracker path, and test results.

---

## Phase 3: Quality verification

After all chunks complete, the gate is the review-impl agent below. The
six concerns in [quality-checklist.md](references/quality-checklist.md)
are the reviewers' shared vocabulary and your fallback self-check when an
agent cannot run; don't run the checklist in addition to the agents.
1. **Completeness** 2. **Correctness** 3. **Regression**
4. **Robustness** 5. **Blindspots** 6. **Maintainability**

"All chunks complete" means every chunk is `status: complete`. A chunk at
`error`, or a graph where no `pending` chunk is selectable but not all are
`complete` (see Phase 1.3), is a blocked feature: do not treat it as
complete or trigger this gate, stop and surface it to the user.

When all chunks are complete, run the code review. The code review is
one read-only agent, `review-impl`, with three lenses:

- **conformance**: does the code do what the plan says, and does a test
  prove each acceptance criterion?
- **correctness (5 angles)**: what breaks, regardless of the plan?
  Recall-biased: surfaces everything, then verifies each finding.
- **cleanup** (reuse, simplification, efficiency, altitude,
  maintainability): what is duplicated, over-built, wasteful, at the
  wrong depth, or hard to change later?

A bug that follows a flawed plan is caught only by the
correctness lens; a correct but off-plan change only by conformance.

Run the gate by [review-and-finish.md](references/review-and-finish.md):
pre-review checks, a still tree while reviewers run, the spawn sized by
its diff-size rule, then §Review protocol (review, fix, re-review up to
Review rounds, checkpoint).

Small diff (one agent, every lens):

```
- Use the review-impl agent with lenses: all to review implementation against [path to tracker]
```

Large diff (one agent per lens, in parallel):

```
In parallel:
- Use the review-impl agent with lenses: conformance to review implementation against [path to tracker]
- Use the review-impl agent with lenses: correctness to review implementation against [path to tracker]
- Use the review-impl agent with lenses: cleanup to review implementation against [path to tracker]
```

Add to each spawn: the pre-review check output, the paths of new files, and
the gate's saved report when there is one.

Merging findings, the finding policy, runtime verification, checkpoint 2,
finish steps and close all follow the same file.

With no project rule file: when neither `.devloop/config.md` nor a project
rules file (`CLAUDE.md`/`AGENTS.md`) exists, the conventions angle has no
rules to quote and returns nothing. Cover standards and architecture
yourself: run checklist point 6 (Maintainability) as an in-context
self-check so they are not dropped.

### Converge (when a finding invalidates the plan or the spec)

Most findings are fixed in place. A discovery during Phase 2 that
invalidates the plan (for example, a dependency that behaves differently
at the pinned version) stops the build: set the current chunk to `error`
with a note saying why, tell the user right away, and wait for their
decision. A review finding that reaches past the code:

- **The spec was wrong** (an acceptance *criterion itself* is wrong,
  missing, or contradictory): always goes to the user, listed at
  checkpoint 2 as a spec change. The plan gate rejects divergence from
  the spec, so re-gating a plan that contradicts it would fail. The
  user re-runs `/spec` (update mode); then `/plan` merges the revised spec
  into this tracker (§3.1) and re-gates. Don't invent the corrected
  requirement here.
- **The plan was wrong** (a chunk's approach is wrong, or the review
  surfaces work no chunk covers, while the spec's criteria stand):
  converge in-session, on this tracker. With `Convergence: auto` (the
  default, [review-and-finish.md](references/review-and-finish.md)
  §Autonomy) the steps below run without asking, for at most
  `Review rounds` automatic convergences per session (the session keeps
  the count, as it does for review rounds; the chunk notes record each
  convergence for checkpoint 2); once
  that many have run, or while any spec change waits for the user, a plan
  change is handled as with `Convergence: ask`: listed at checkpoint 2,
  and started only on the user's approval. A convergence the user asks for
  at a checkpoint doesn't count toward the limit.

1. Append the corrective work as new `pending` chunks (with acceptance
   criteria and `tdd`; the first appended chunk's notes name the finding
   this convergence answers), and in the same write set `plan_review` to
   `FAIL`. Leave the built chunks at `complete`. If the session is lost
   before step 3 writes a passing verdict, resumption sees `FAIL` and
   routes to `/plan`, which merges into this tracker (§3.1) instead of
   building ungated chunks.
2. Gate the change by
   [review-and-finish.md](references/review-and-finish.md) §Review
   protocol, spawning the `review-plan` agent directly. Revise only
   the appended chunks; a finding against a completed chunk becomes a new
   corrective chunk, or goes to the user. Don't re-run the `/plan` skill:
   it would regenerate the tracker and lose the completed and appended
   chunks.

   ```
   Use the review-plan agent to review [path to tracker]
   ```

   If the harness cannot spawn agents at all (not only a failed spawn),
   fall back to the in-context self-check against
   [quality-checklist.md](references/quality-checklist.md) and note the
   lost isolation in the tracker.
3. Record the re-gate verdict, its open warnings and set-aside findings
   once, in the first appended chunk's notes. With `auto`, a `PASS` or
   `PASS-WITH-WARNINGS` from the `review-plan` agent is written to
   `plan_review`, then the chunks are built (Phase 2) and the code review
   runs again (Phase 3). A verdict from a self-check (no agent could run)
   is handled as with `ask`. With `ask`, keep `plan_review` at `FAIL`,
   save the verdict in the plan report, and present the appended chunks at
   a checkpoint; build only on the user's approval (a session lost there
   leaves `FAIL`, so resumption routes to `/plan`). On a `FAIL` after the
   gate's rounds, stop and offer the user one more round, a change, or
   stop. Don't enter Phase 2 while `plan_review` is `FAIL`.

Checkpoint 2 lists every convergence that ran, from those notes, as
[review-and-finish.md](references/review-and-finish.md) §Checkpoint 2 says.

**Dropping a convergence.** If the user drops the change, then with their
confirmation (it throws away the corrective work) drop that
convergence's appended chunks and set `plan_review` back to `PASS`; the
completed chunks were already gated. This is the one tracker edit that
doesn't re-gate, and it is refused when a later chunk depends on the
dropped ones. For an automatic convergence already built, reverting its
code is an edit at checkpoint 2
([review-and-finish.md](references/review-and-finish.md) §Edits at a
checkpoint).

**Agent failure** (timeout, error): fall back to a self-check against
the full [quality-checklist.md](references/quality-checklist.md).
Document any agent failures in the tracker.

### Post-implementation documentation

Create or update a reference document when the work will outlive this
session: multi-chunk features, deferred follow-ups, bug fixes with a
non-obvious root cause, or changes to a subsystem that already has a
design or analysis doc. Skip it for small, self-contained changes whose
full story is already in the diff, commit message and tracker; writing
one anyway is scope the user didn't ask for. Write one when a future
session would need it to continue.

When you do write one, cover what changed and why, what was tested and
confirmed, and what remains (known gaps, future work, test locations).
If the feature already has a design doc or issue tracker, update that
instead of creating a new one.

---

## Implementation rules

1. **Catch narrow exceptions for skip and continue** -
   When converting `throw` to `continue` (a resilience fix), narrow the
   catch. A fatal error means the runtime is broken and continuing
   cascades failures; make sure cancellation can't reach the catch site
2. **Fix sibling components together** -
   If two components share the same bug pattern, fix both in one pass
3. **Adding checks breaks existing tests** -
   A new validation or permission check fails existing tests that skip
   its setup. Grep the test files and add the setup
4. **Guard against false positive tests** -
   An assertion on a string or pattern must match in the right context,
   not in a comment, label or unrelated field. Prefer line-level,
   anchored assertions over broad substring checks
5. **Calibrate evaluation criteria** -
   After Phase 3, compare your assessment with what the user flagged. If
   the user finds gaps after you marked all criteria met, tighten the
   checklist or the criteria

---

## Commit guidance

Do not commit proactively. Wait for the user to request it;
approving checkpoint 2 with a commit among the finish steps is that
request. Refer to `.devloop/config.md` for project-specific commit
conventions (author, message format, trailers).

---

## Session resumption

When resuming work on an in-progress feature:

1. Read the JSON tracker to find current progress
2. Check `plan_review`, if it is `"PENDING"`, `"FAIL"`, or missing, the
   plan is not gated, run `/plan` before proceeding (this skill doesn't
   start it for you). If every chunk is `complete`, don't continue on
   your own: report the tracker's state (whether `quality_verification`
   holds summaries and `final`, and the saved review reports) and ask
   the user what to do, since a code review, checkpoint 2 or finish steps
   may already have run
3. Read the plan file for detailed chunk descriptions
4. Re-enter any unfinished chunk first. A chunk left at `in_progress`
   or `error` (e.g. a crash mid-build) is neither `pending` nor
   `complete`, so the next-`pending` search below never selects it.
   Re-enter it, finish or re-verify it, before looking for new work (see
   Phase 1.3)
5. Find the next `pending` chunk where all `depends_on` are `complete`
6. Read `name`, `files_create`/`files_modify`, `tdd`,
   `acceptance_criteria`, and any `notes` on that chunk
7. Follow the Phase 2 TDD cycle
8. Update tracker status

If your harness supports named or resumable sessions, use one to return
to the same context instead of starting fresh.
