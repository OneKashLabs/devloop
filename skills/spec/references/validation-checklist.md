# Spec validation checklist

Run this checklist during Phase 4 after the spec is drafted and
clarifications are resolved.

**Evidence rule:** Every WARN or FAIL must quote the exact spec line it
refers to, the way the review agents quote a code line. Do not flag from
memory or paraphrase: if you cannot point at the offending text, it is
not a finding.

---

## 1. Testability

Every acceptance criterion can be converted to a test.

**How to check:**
- For each Given/When/Then, construct the specific assertion: a test
  that passes when this works and fails when it doesn't
- Ask: "Could an implementation pass this criterion while being
  completely wrong?" If yes, the criterion is too vague ("responds
  appropriately" passes for any response)
- The test complexity hint, `(1 test)`, `(parameterized)`,
  `(integration)`, should be present and accurate
- Red flags: criteria using "appropriate", "graceful", "intuitive",
  "fast" without a measurable threshold

---

## 2. Completeness

Every user story has acceptance criteria. Every P1 story has
both happy-path and error-path criteria.

**How to check:**
- Count stories vs criteria. P1 stories should have 2+ criteria
  (at least one happy path, one error path)
- P2/P3 stories need at least 1 criterion each
- No story should have an empty acceptance criteria section
- Consider: the user cancelling midway, empty or invalid input, and
  partial success

**Variant completeness:** If a story's behavior branches by N
variants (scenarios, user roles, platforms, modes), each variant
needs at least one criterion. Count the variants mentioned in
the story, count the criteria covering each, flag uncovered
variants.

---

## 3. Clarity

No vague adjectives without measurable targets. No jargon
without definition. No pronouns with ambiguous referents.

**How to check:**
- Search for: fast, slow, large, small, many, few, appropriate,
  suitable, robust, scalable, intuitive, seamless, modern,
  responsive, secure, efficient, reliable
- Each must have a measurable qualifier or be removed/replaced
- Domain terms should be self-evident from context or defined
  on first use

---

## 4. Scope

Boundaries are explicit. There is an "Out of Scope" section.
P1/P2/P3 boundaries are defensible.

**How to check:**
- "Out of Scope" section exists and has at least one item
  (for medium+ features)
- No "while we're at it" additions hiding in P1 stories, including
  feature creep labelled as edge case handling
- No unbounded requirements ("supports all formats")
- Could someone argue a P2 should be P1? If yes, the "Why P_"
  rationale should address it

---

## 5. Independence

User stories can be implemented and tested independently.
P1 stories deliver standalone value.

**How to check:**
- For each P1 story, ask: "Can I ship this alone and demo it?"
- No circular dependencies between stories
- P2/P3 may depend on P1 but not on each other
- Stories don't share setup assumptions ("US2 assumes US1 ran first";
  acceptance criteria should handle the empty state)
- No stories that are really sub-tasks of a single story, and no shared
  infrastructure missing from every story's acceptance criteria

---

## 6. Priority

Stories are prioritized P1/P2/P3. The P1 set forms a coherent
MVP that delivers user value on its own.

**How to check:**
- At least one P1 story exists
- The P1 set alone would be a useful, shippable increment
- Every story has a "Why P_" justification
- Not every story is P1; if all are, re-rank them
- Priority follows user value, not technical ordering

**Priority dependency check:** If a P1 story depends on work
that's currently P2 or P3 (or doesn't exist yet), flag it:
- Option A: Promote the dependency to P1
- Option B: Restructure the P1 story to remove the dependency
- Option C: Document the dependency in Notes with a plan

---

## 7. Edge cases

Key failure modes and boundary conditions are identified.
At minimum: empty state, error state, boundary values.

**How to check:**
- Edge Cases section is non-empty
- Cross-reference with taxonomy categories 5 (Error handling)
  and 6 (Edge cases and boundaries)
- Each P1 story has at least one edge case
- Domain-specific concerns from .devloop/domain.md are addressed,
  including how the feature interacts with existing domain rules
- Category tags `[Category N]` are present for traceability
- Consider: timezone/locale for time-sensitive features, concurrent
  operations on shared data, and empty state (no data yet) vs error
  state (failed to load)

---

## 8. Resolution

No unresolved `[NEEDS CLARIFICATION]` markers remain.

**How to check:**
- Search the whole spec, nested sections included, for
  `[NEEDS CLARIFICATION]`
- If any remain, they must be either:
  - Resolved (marker replaced with the answer in its original
    location, not only in Clarifications)
  - Deferred with rationale in Notes section:
    `[DEFERRED: not clarified, <reason>]`
- Check for new ambiguities introduced during Phase 4 fixes

---

## Project-specific validation

After the 8 generic points above, check the spec against
project-specific criteria:

1. Load `.devloop/domain.md` "Domain-Specific Concerns" section
2. Verify each concern is addressed (in Edge Cases, Acceptance
   Criteria, or explicitly in Out of Scope)
3. Load `.devloop/domain.md` "Quality Standards" section
4. Verify each standard is met

Document project-specific failures the same way as generic
failures, fix or add to Notes with rationale.

---

## Check mode

In check mode the input is an existing design doc, not a new spec. Build
a mapping first, then run the 8 points on it:

1. List every decision the doc records (a choice made, a value fixed, an
   option rejected). Each becomes one or more acceptance criteria in
   Given/When/Then form, citing the doc's section.
2. A decision that can't be written as a pass/fail criterion is a
   Testability gap. Ask about it in Phase 3; don't invent a criterion.
3. Two decisions that can't both hold are a Resolution gap.
4. Text the doc leaves open ("TBD", "maybe", a listed option with no
   choice) is a `[NEEDS CLARIFICATION]` marker.
5. Out of Scope: use the doc's own deferred or rejected list. If it has
   none, ask whether anything is deferred.

Check mode reports instead of editing. Don't edit the design doc unless
the user asks; it stays the spec `/plan` binds to. The report carries:

- the mapping and its gaps; each failing point is a gap
- each Phase 3 answer as `Q -> A`, which `/plan` turns into acceptance
  criteria that cite it. For a Resolution gap, offer to append the answer to the doc, since the doc stays
  the spec. The `Next:` line carries the answers, so a fresh `/plan`
  session has them
- questions left open, marked deferred
- the status (`Ready` or `Ready-with-warnings`)

Point 6 (Priority) applies only if the doc ranks its decisions; otherwise
report it as not applicable.

---

## Handling failures

**If all 8 points pass:** Mark spec status as `Ready`. Proceed
to Phase 5 (Handoff).

**If points fail (iteration 1):** Fix the spec directly. Re-run
the checklist. Most failures are fixable without user input
(adding missing error criteria, removing vague adjectives,
adding Out of Scope items).

**If points still fail (iteration 2):** Fix what you can.
Document remaining issues in the spec's Notes section with
rationale for why they couldn't be resolved. Mark spec status
as `Ready-with-warnings`. Proceed to Phase 5 with a warning
in the handoff summary. Do not iterate more than twice.
