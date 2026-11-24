# Review and finish

Rules the review gates share. `/plan` Phase 4 and `/implement` Phase 3
link here instead of restating them.

## Autonomy

The process stops for the user at two fixed checkpoints, which config
can't turn off: before `/implement` builds anything (`/plan` Phase 5), and
after the code review, before any finish step (Checkpoint 2 below). The
optional `## Autonomy` section of `.devloop/config.md` tunes the
unattended stretches between them:

- **Review rounds**: how many reviews a gate runs before its checkpoint,
  the first one included (default 3).
- **Finish steps**: what runs, in order, after the user approves
  checkpoint 2 (for example the project's preflight, a commit, a release
  command); default none, which means report and stop.
- **Convergence**: `auto` (default) or `ask`. When a code review shows
  the plan was wrong, `auto` appends corrective chunks, re-gates them
  through `review-plan` and builds them without asking, up to a limit
  (`/implement` Phase 3, Converge); `ask` lists the change at checkpoint 2
  and waits. A spec change always goes to the user.
- **Stop and ask on**: extra conditions that stop the run.

An invalid `Review rounds` value (missing, zero, or not a number) falls
back to 3; a `Convergence` line without `auto` or `ask` falls back to
`ask`. What the
user says in the session overrides the section for that session.

One stop is built in and config can't remove it: a check or test that
still fails after a fix attempt (failures inside the current chunk's TDD
loop, red and then the attempts to go green, are expected, not stops).
Any stop ends the unattended stretch: report what happened and ask the
user.

Example:

```markdown
## Autonomy

- Review rounds: 3
- Convergence: auto
- Finish steps:
  1. Run the full test suite and lint
  2. Commit (see Commit Conventions)
- Stop and ask on: anything that publishes outside this repository
```

## Review protocol

Both gates run the same loop:

1. **Review.** Spawn the gate's reviewers, with the gate's saved report
   (below) as the previous report when there is one.
2. **Fix.** Give each finding an `outcome`: `fixed` (at the code gate,
   with the test that shows a behavior fix), `skipped` (with the reason)
   or `no_change_needed`. At a plan gate (`/plan` Phase 4 or a convergence
   re-gate), write `plan_review: "FAIL"` before revising the tracker,
   whatever the verdict was; with no rounds left, don't revise for a
   warning or recommendation: list it at the checkpoint with its proposed
   fix, and an approved fix goes through §Edits at a checkpoint. At the
   code gate, handle each finding by the finding policy below and run the
   suite after the fixes.
3. **Re-review** when something was fixed and the gate has rounds left:
   spawn the reviewers again with the previous report. A code re-review
   runs the `conformance` and `correctness` lenses (conformance runs the
   suite), plus any other lens that has a finding whose outcome is `fixed`
   or whose reported lines a fix touched; on a small diff that is one
   `lenses: all` agent, on a large diff one agent per lens. A lens not
   re-run keeps its verdict and open findings; when the spawn shape
   changes between rounds (small diff to large), every lens re-runs. A fix
   made with no rounds left is presented as unreviewed (a plan stays at
   `FAIL`).
4. **Checkpoint.** Present the findings with their outcomes. The user
   decides what follows: approve, another round, an edit, or stop. A
   convergence re-gate ends at a checkpoint when it fails or under
   `Convergence: ask`; a passing re-gate under `auto` goes straight to
   Converge step 3.

The count lives in the session. After a session reset, don't continue the
loop on your own: report where it stood and ask the user.

Save each gate's report next to the tracker, so a re-review after
compaction or a resumed session has the previous report:
`<feature>-plan-review.md` and `<feature>-code-review.md` in the tracker
directory. Save the merged report when it arrives (each lens's latest
verdict and open findings, carried forward from earlier rounds for a lens
not re-run; resolved findings kept with their outcome and fix test; a
finding raised again as `repeated` loses its earlier outcome until step 2
gives a new one), then again after the fixes with this round's outcomes.
Each save overwrites the last, written the way the tracker is (temp file,
then rename). Pass it to a re-review as the previous report, never as a
file under review, and leave it out of the reviewed diff. It moves with
the tracker (`done-trackers`, and back when `/plan` moves an archived
tracker back). A fallback self-check is saved the same way. The fast lane
has no tracker: its report stays in the session.

## Edits at a checkpoint

An edit the user asks for at a checkpoint is reviewed before the
checkpoint is presented again; this review comes from the user's request
and doesn't use up Review rounds:

- At checkpoint 1, write `plan_review: "FAIL"` before editing the
  tracker, run `review-plan` with the previous report, and record its
  verdict as `plan_review`.
- At a convergence checkpoint, write `plan_review: "FAIL"` before editing
  the tracker and run `review-plan` with the previous report. Record its
  verdict only in the saved plan report: `plan_review` stays `FAIL` until
  the user approves the appended chunks (`/implement` Phase 3, Converge
  step 3). This checkpoint is reached whenever Converge step 3 handles the
  verdict as with `ask`, and when the re-gate fails.
- At checkpoint 2, a code edit is re-reviewed as in step 3 of the review
  protocol (same lenses and spawn, with the previous report). A tracker
  edit (chunks, criteria, `depends_on`) goes through Converge
  (`/implement` Phase 3), since a plan change always goes back through
  `review-plan`.

Don't present an unreviewed revision as reviewed.

## Fast lane

For a change `/plan`'s When to use this process table puts in the fast lane: write the
failing test (for a bug fix, the proof test), make it pass, run the
pre-review checks, then spawn one `review-impl` with `lenses: all`. Pass
it the diff range, say there is no tracker, and state the request and the
proof test, so conformance has something to check and runs the suite. With
no tracker, the conformance rows that read tracker fields (Plan
Conformance, the test count in Test Quality, Documentation) have nothing
to compare; treat a warning that only says the tracker is missing as not
applicable. If the fix grows past the fast-lane criteria, stop and re-run
`/plan` asking for a tracker; so does a conformance finding that the plan
itself is wrong. The review protocol, runtime verification, checkpoint 2
and the finish steps apply; there are no summaries to write and nothing to
close. A bug fix records its proof in the commit message.

## Pre-review checks

Before spawning the code reviewers:

- Make every new file the change added visible to them (from `git status`
  with git; leave out scratch and probe files and the saved reports): pass
  their paths, or with git mark them intent-to-add (`git add -N <file>`),
  which stages nothing for commit but puts them in `git diff`. List any
  file you marked at checkpoint 2.
- Run the commands the config lists as pre-review checks (a labeled
  `Pre-review checks` list under Build & Test Commands) and fix what they
  report; one that still fails after a fix attempt is a built-in stop.
  Pass their output to the reviewers. No list: skip this.

## No edits while reviewers run

Reviewers read the working tree. Keep it still until every reviewer has
reported: a file that changes mid-review gets judged half old, half new.
Fix after the reports are in, then re-run.

## Diff size

The code review sizes by the change, not by how `/plan` sized the work:

- **Small**: one production file plus its tests.
- **Large**: anything more.

`/implement` Phase 3 gives the spawn for each.

## Combining verdicts

When a gate has more than one reviewer, their verdicts combine: any FAIL
gives FAIL; else any PASS-WITH-WARNINGS gives PASS-WITH-WARNINGS; else
PASS. A lens not re-run counts with its last verdict.

At the code gate each `review-impl` agent ends with a JSON list of its
findings. Join the lists. Lens agents run in parallel can report the same
defect (conventions runs in every lens), so merge findings for the same
defect that name the same line or overlap through `also_at` into one,
listing every lens that reported it (re-run selection and checkpoint 2 use
that list), keeping the most concrete failure scenario and the higher
confidence. When they mark the same earlier finding differently, keep
`open`.

## Finding policy

What happens to each finding, unless the project's config adds rules
(under Standards to Verify):

- **Confirmed correctness**: write a failing test that shows it, then fix.
- **Plausible correctness**: the author's call; list it at checkpoint 2
  with what was done.
- **Pre-existing** (either confidence): don't fix it in this change; list
  it at checkpoint 2 so it can be recorded and fixed on its own.
- **Conformance**: fix the code to match the plan. If the plan itself was
  wrong, converge (`/implement` Phase 3, Converge); the plan change goes
  back through `review-plan`, never straight into the tracker. A finding
  that an acceptance criterion itself is wrong is a spec change and goes
  to the user.
- **Conventions**: a finding whose failure scenario is a real fault
  (security, data loss, a broken documented invariant, a robustness gap)
  is handled like confirmed correctness; a stylistic one like cleanup.
- **Cleanup**: apply it if it stays inside the diff; otherwise decline it
  with a reason.

## Runtime verification

This step runs the change and records what it does. It runs when the config names a `Verify recipe` (a labeled
list under Build & Test Commands saying how to build, launch and drive
the project) and the diff has a runtime surface; otherwise skip it with a
one-line note. Test-only and docs-only diffs have no runtime surface.

After the code review's last round and before checkpoint 2, the author
follows the recipe and records the claim (what the change should do), the
inference (what a user would then observe, including that untouched paths
behave as before), the steps run, the output observed, and a verdict:
PASS, or FAIL with what was wrong. Drive the changed flow to where the
change shows; launching it is not enough. A step that changes data
outside the project and its build output runs against a copy, a mock or a
dry run; where none exists, say what could not be checked.

This is evidence for the user, not an approval: the reviewers still gate
the code. Save the record with the code report (in the fast lane it stays
in the session and is shown at checkpoint 2). A code change made after a
run, including a fix for a FAIL, is re-reviewed by §Review protocol step 3
(a code edit the user asks for at checkpoint 2 follows §Edits at a
checkpoint), then the recipe runs again; with no rounds left it is
presented as unreviewed and finish steps are not offered; checkpoint 2
shows the latest run.

## Checkpoint 2

After the code review's last round, present and wait for explicit
approval:

- the combined verdict, and any FAIL still unresolved
- the findings, by lens, each with its outcome
- the test that shows each fix
- pre-existing findings, for the user to record
- the runtime verification verdict and its evidence, when it ran
- each convergence that ran: the finding, the appended chunks, the
  re-gate verdict, its open warnings and set-aside findings; and plan or
  spec changes waiting for the user's approval
- the finish steps about to run

Finish steps are offered only here, and only when the latest code review
ran after the last code change, the latest verification run came after the
last code change (when runtime verification applies), and no plan or spec
change is waiting for approval; with a tracker, also only when every chunk
is `complete` and `plan_review` passes. Otherwise report with no finish
steps offered; approving a waiting plan or spec change converges first,
and finish steps are offered at the next checkpoint 2. Finish steps count
as offered when these conditions held, whether or not the config lists
any. When the code verdict or the verification verdict is still FAIL,
finish steps run only if the user approves them knowing that. On an
approval at which finish steps were offered, write the
`quality_verification` summaries (none in the fast lane). Approving a plan
or spec change writes no summaries and doesn't close the tracker.

## Finish steps and close

After checkpoint 2 is approved, run the config's finish steps in order.
A step with a condition that doesn't hold (for example "if the strings
file changed", judged from the diff) is skipped with a note. A step the
agent can't start (for example a slash command the harness won't start on
the user's behalf) stops the run: report it as `Next: <command>`, with the
steps after it still to run and the tracker left open; the user runs the
remaining steps, then a later session closes it. Starting a named command
after the user's approval is not one skill calling another. Don't fix
code inside a finish step: the first step that fails stops the run with a
report naming the step and what is left, and the fix goes through a
normal review later. Generated output (translations) and release metadata
(a version bump) are not code changes.

Close only after an approval at which finish steps were offered: after the
last finish step, or right after that approval when there are none. With a
tracker, also only when every chunk is `complete` and `plan_review`
passes: write `quality_verification.final` (the verdict and what is left
for the user, such as a device test), then apply `done-trackers`. A
tracker is done when every chunk is `complete` and `final` is set;
appending chunks clears `final` and the summaries. If the project commits
its trackers, the close is left for the next commit; say so in the
summary. A commit among the finish steps is covered by `/implement`'s
Commit Guidance.

`done-trackers` is a project setting next to `tracker-directory` in the
config: `keep | archive | delete`, default keep. `archive` moves the
tracker to `<tracker-directory>/archive/`.
