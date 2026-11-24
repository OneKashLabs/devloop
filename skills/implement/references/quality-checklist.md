# Quality checklist

These six concerns are the vocabulary `review-plan` and `review-impl`
use, and the self-check you run when a review agent can't run. When the
self-check reviews code (`/implement` Phase 3), use sections 1-6. When it
reviews a plan (`/plan` Phase 4, or a convergence re-gate in
`/implement`), use each concern's plan-time column below and add TDD
quality from `agents/review-plan.md`. Don't run it in addition to an
agent that ran. Verify each point with specific evidence (test results,
grep output, build logs). Each check appears under one concern only.

## Shared concern vocabulary

The concerns fall in three groups, checked in this order: does the change
do what was asked, does it hold up, and can it be maintained.

| # | Concern | `review-plan` (plan-time) | Code-time |
|---|---|---|---|
| 1 | Completeness | every criterion has a chunk and every chunk a criterion; every new item has a consumer in a chunk | every criterion is met and wired; no unrelated changes |
| 2 | Correctness | the plan's assumptions about the code hold | data and logic are correct |
| 3 | Regression | every affected test and caller of a changed signature is in a chunk | the suite still passes |
| 4 | Robustness | error, empty, concurrent and partial-failure paths are planned | those paths hold and data stays consistent |
| 5 | Blindspots | security, privacy and the platform checks are planned where the feature touches them | they hold in the code |
| 6 | Maintainability | the plan follows the project's rules and boundaries, and names the config values, doc updates and dependency pins | the code follows them and leaves nothing stale |

`review-plan` applies concerns 1-6 to the plan and adds TDD quality.
`review-impl` applies them to the code through its lenses (see its own
file): conformance covers 1 and 3, correctness covers 2, 4 and 5, and
cleanup covers 6. The conventions angle, which runs in every lens, checks
the project's written rules and the config's blindspot list.

---

## 1. Completeness

- List every acceptance criterion from the tracker's `acceptance_criteria`
  arrays, not from memory
- For each, name the code that implements it and the test that verifies
  it, and check the test asserts the criterion:
  `- [ ] Criterion: [describe] - verified by [test or file:line]`
- Mark criteria that rely on manual testing (UI changes)
- Grep, including files outside the chunk list: new parameters and
  callbacks are wired at every call site (not passed an empty or no-op
  handler), and no reference to a removed type is left
- The diff holds no change unrelated to the criteria

## 2. Correctness

- Review each data transformation (entity -> UI model), including enum
  and constant values that cross layers
- Check boundary values (0, -1, MAX_VALUE, null, empty), off-by-one in
  ranges, and nullable fields treated as non-null (or the reverse)
- Check timezone handling, numeric precision (type widths, float vs
  integer) and units (milliseconds vs seconds, bytes vs kilobytes)

## 3. Regression

Run the project's test, build, and lint commands (see `.devloop/config.md`)
and record: total test count (should not decrease), build and lint
warnings (should not increase), and pre-existing flaky tests (note, don't
block). A failure in a test class this feature did not modify is likely
pre-existing: run it in isolation to confirm.

## 4. Robustness

- Empty data source: an empty-state message, no crash
- Permission/auth errors and network timeouts: an error state, no crash
- Errors reach the user or the caller and aren't swallowed
- Resources cleaned up on teardown/unmount/dispose; async operations
  cancelled on scope cancellation
- Concurrent access: no race conditions in shared state, rapid repeated
  input, or parallel operations
- Data integrity: a write that fails partway leaves the data consistent
  (no lost, duplicated or half-written records)
- Config/env change: state survives (if expected to)
- Large data: no performance cliff or resource exhaustion

## 5. Blindspots

Self-assessment is weakest here; the `review-impl` correctness lens
covers it in a fresh context. Always check:

- [ ] Security: input validation, injection, auth boundaries
- [ ] Privacy: secrets and personal data stay out of logs, error
  messages, commits and fixtures; the feature collects or shares only
  the data the spec allows

Then the platform blindspots in `.devloop/config.md` §Blindspots to Check
(for example web: CORS, CSP, XSS, accessibility; mobile: dark theme, RTL,
screen sizes, permissions; backend: rate limiting, pagination,
idempotency, timeouts; CLI: signals, stdin/stdout encoding, exit codes).

For each blindspot, note what could go wrong, its likelihood
(low/medium/high), the mitigation (if any), and whether manual testing is
needed.

## 6. Maintainability

How easily the code can be changed, tested and repaired later. Report
only what the diff shows: a project rule it breaks, a precedent in the
surrounding code it ignores, or a concrete later cost.

- Project rules: the guidelines (`CLAUDE.md`, `AGENTS.md`, or
  equivalent), the framework's conventions, and `.devloop/config.md`
  §Standards to Verify
- Boundaries: grep for imports that cross a layer (for example, UI
  importing the data layer), and check the architecture rules in
  `.devloop/config.md`, including the test-double convention; services
  are passed in, not built by the code that uses them, where the project
  injects dependencies; types follow the project's type-safety rules
  (for example a closed set of types instead of string values)
- Leftovers: dead code, imports left after removing a usage, and
  TODO/FIXME or placeholder comments; run the project's lint command for
  unused imports and variables
- Stale text: comments, docstrings and docs the change makes wrong are
  updated; a new public interface has its contract written down
- Configuration: a value that differs by environment or deployment
  (address, limit, timeout, credential) comes from configuration, not a
  literal in code
- Dependencies: a new dependency follows the project's pinning rule; a
  change to a public interface follows the project's versioning rule;
  a breaking change, or a design that will need one later, records its
  migration path
- Error messages: an error says what failed and on which input
- Consistency: naming and structure match how the surrounding code does
  the same job. Without a rule or a precedent to point at, don't report
  naming or structure
