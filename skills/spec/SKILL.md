---
name: spec
description: "Structured specification process: explores code, generates user stories with testable acceptance criteria, resolves ambiguities through interactive clarification, validates completeness, and outputs a lightweight spec. Use before /plan to clarify what to build."
argument-hint: "[description of feature, fix, or change]"
effort: high
---

# Feature specification process

Create a specification for the following: $ARGUMENTS

A spec settles what to build before implementation starts. Find
ambiguity now, by exploring and asking questions, not during
implementation.

## When to use this process

| Scope | Approach |
|---|---|
| Trivial (typo, config, rename) | Don't use this skill; make the change directly |
| Small (well-understood, single concern) | Quick spec shortcut (skip clarification) |
| Medium (multi-concern, some ambiguity) | Full process |
| Large (cross-cutting, unfamiliar domain) | Full process, thorough clarification |
| An existing design doc records the decisions | Check mode (below) |

**Quick spec shortcut:** For small well-understood changes with
no domain ambiguity, collapse to: Explore -> Specify -> Validate
-> Handoff. Skip clarification entirely. Use when the feature can
be described in one sentence and has no competing interpretations.

**Check mode:** When the request names an existing design doc whose
decisions are already made, check that doc instead of writing a second
spec. Phase 1 reads the doc and the code it names. Phase 2 maps each
recorded decision to a user story or acceptance criterion (see
validation-checklist.md §Check mode). Phase 3 asks only about the gaps the
mapping finds (§Check mode). Phase 4 runs the 8-point check on the mapping
and reports what fails instead of editing the doc. Phase 5 reports the
gaps and hands the doc itself to `/plan`: the tracker records the design
doc's path as its `spec_doc`. Write a separate spec file only if the user
asks for one.

**Scope negotiation:** If the request contains 3+ distinct features,
recommend splitting into separate specs before proceeding. Each spec
should cover one coherent feature with independent user value.

**Product vs feature:** If the request describes an entire product
or system (multiple independent capabilities, separate components,
its own installation story), treat it as a product-level spec:

- One user story per major capability (not per implementation task)
- Acceptance criteria verify capability, not component details
- Implementation chunking goes in Notes or during TDD, not as
  separate specs

If a product spec exceeds 12 stories, consider splitting into a
product spec (overview) + separate feature specs (details).

Product specs with interacting capabilities need explicit
interface contracts (file paths, data formats, handoff
expectations), in Assumptions or a dedicated section.

## Supporting files

Load these on demand, not all upfront:

| File | When to load |
|---|---|
| [spec-template.md](references/spec-template.md) | Phase 2, when generating the spec |
| [clarification-taxonomy.md](references/clarification-taxonomy.md) | Phase 2 (scanning) and Phase 3 (questions) |
| [validation-checklist.md](references/validation-checklist.md) | Phase 4 (validation) |

Each phase must complete before the next begins.

---

## Phase 1: Explore

### 1.1 Understand the request

- Identify the request type: new feature, enhancement, bug fix, behavior change,
  integration, or workflow change
- Extract key concepts: actors, actions, data, constraints, triggers
- Note initial assumptions about scope and intent

### 1.2 Explore the current code

- Read files in the affected area (focus on files mentioned in the
  request + 1 layer of direct dependencies)
- Trace the data flow through the application layers
- Identify existing patterns, utilities, and conventions to reference
- Note what already exists, don't spec what you can grep: reference an
  existing pattern instead of re-specifying it

**Greenfield projects:** If the codebase doesn't exist yet, explore
the inputs that define what to build: analysis docs, design docs,
reference materials, domain knowledge files, and similar projects.
Here the context lives in documents, not code.

Steps 1.2 and 1.3 are independent, so they can run concurrently.

### 1.3 Read project context

- Load the domain config, `.devloop/domain.md` in the project root, for
  domain context, architecture overview, existing patterns, and
  domain-specific concerns. These inform edge case detection, affected
  component identification, and project-specific validation in Phase 4
- `domain.md` holds only domain knowledge. The one operational path `/spec`
  needs, the spec directory, lives in `.devloop/config.md` and is read where
  it's used (Phase 1.5 and 2.7)
- If the file is absent or contains only template placeholders
  (`YOUR_*_HERE`), proceed without it: the generic taxonomy categories
  still apply. If the project clearly needs one (complex domain, multiple
  conventions), recommend `.devloop/domain.md` in the spec's Notes; don't
  block the spec on it

### 1.4 Identify affected components

- List files and modules that will likely change
- Note their role in the architecture (data layer, domain, UI, etc.)
- This becomes the spec's "Affected Components" section and later
  feeds into TDD chunk decomposition

### 1.5 Check for an existing spec

- Check the spec directory (the spec-directory setting in
  `.devloop/config.md`, default `docs/specs/`) for an existing spec
  file matching this feature
- If found, load it and show a summary to the user
- Ask: "A spec already exists for this feature. Update it, or
  start fresh?"
  - **Update:** Preserve Clarifications history, bump `spec-version`,
    revise stories and criteria based on new request
  - **Fresh:** Archive old spec with `.bak` suffix (overwrite any
    existing `.bak`), generate new one

---

## Phase 2: Specify

### 2.1 Load the spec template

Read [spec-template.md](references/spec-template.md) for the
output format. Use its section structure and frontmatter schema.

### 2.2 Generate user stories

For each distinct user-facing behavior:

- Write a user story: **As a** <role>, **I want** <goal>,
  **so that** <benefit>
- Assign priority: P1 (must-have), P2 (should-have), P3 (nice-to-have)
- Include a "Why P_" line justifying the priority
- Ensure P1 stories form a coherent MVP that delivers value alone
- Each story should be independently implementable and testable

### 2.3 Write acceptance criteria

For each user story, write testable acceptance criteria:

- Use Given/When/Then format for every criterion
- P1 stories need both happy-path and error-path criteria
- P2/P3 stories need at least one criterion each
- Scan the domain config's Quality Standards while writing and add the
  criteria they call for (accessibility, for example) now, not in
  Phase 4
- See spec-template.md §Acceptance Criteria for complexity hints
  and specificity guidelines
- **Depth target:** Criteria should be specific enough to write a
  test from, but not so specific that they dictate implementation.
  When in doubt, describe the observable outcome

### 2.4 Identify edge cases

Load [clarification-taxonomy.md](references/clarification-taxonomy.md).
Scan all 9 categories against the feature:

- For each category, assess: Clear / Partial / Missing
- Document edge cases discovered in the spec's Edge Cases section
- Tag each edge case with its taxonomy category: `[Category N]`
- At minimum for P1 features: empty state, error state, boundary values
- Check the domain config's domain-specific concerns (Category 9)

### 2.5 Document assumptions

Record reasonable defaults for unspecified details. See
spec-template.md §Assumptions for guidelines. Use the taxonomy's
"Reasonable defaults" as a guide.

### 2.6 Mark ambiguities

For categories marked Partial or Missing where the ambiguity
materially impacts the spec:

- Add `[NEEDS CLARIFICATION: <specific question>]` markers
- At most 5 markers in the whole spec
- Prioritize by impact, see
  [clarification-taxonomy.md §Prioritization](references/clarification-taxonomy.md)
  for the full ranking
- Make informed guesses for everything else (document in Assumptions)
- Write the "Out of Scope" section, at least one item for medium+
  features

### 2.7 Write the spec file

- Create the spec directory if it doesn't exist
- Write the spec to the configured location (the spec-directory
  setting in `.devloop/config.md`, default `docs/specs/<feature-name>.md`)
  using kebab-case for the filename
- Include all sections from the template
- Set frontmatter status to `Draft`
- Size check: a standard feature's spec runs about 80-150 lines
  before Clarifications. If it is well over, check whether it holds
  more than one feature and apply scope negotiation (see §When to use
  this process). Product-level specs (see §Product vs feature) run
  longer, up to about 300 lines for products with 6-12 user stories

---

## Phase 3: Clarify

Skip this phase if no `[NEEDS CLARIFICATION]` markers exist.
Report: "No critical ambiguities detected. Skipping clarification."

### 3.1 Prioritize questions

From the `[NEEDS CLARIFICATION]` markers:

- Rank by (impact x uncertainty), highest first
- Select up to 5 for the question queue
- Each question must materially affect implementation or testing
- Never reveal upcoming questions, one at a time only

### 3.2 Interactive questioning loop

For each question in the queue:

1. **State context:** Quote the relevant spec section
2. **Recommend an answer:** Based on codebase patterns, project
   context, and best practices. Format:
   `**Recommended:** Option X (<one sentence reasoning>)`
3. **Present options** as a markdown table:

   | Option | Description | Implications |
   |---|---|---|
   | A | ... | ... |
   | B | ... | ... |
   | C | ... | ... |

4. **Accept response:** an option letter, "yes" or "recommended" for
   the recommendation, or a custom short answer
5. **Update the spec immediately** after each answer (check mode: see
   validation-checklist.md §Check mode instead):
   - Replace the `[NEEDS CLARIFICATION]` marker with the answer
   - Add to Clarifications section: `- Q: <question> -> A: <answer>`
   - Save the file (atomic update)
6. **Handle scope changes:** If the user's answer introduces new
   scope (new scenarios, new capabilities, new actors), update
   affected stories and criteria before proceeding. Revise the
   affected section as a small re-spec; recording the answer alone is
   not enough
7. **Proceed to next question** or stop

### 3.3 Stop conditions

Stop asking questions when:

- All markers are resolved
- User signals completion ("done", "skip", "proceed", "no more")
- 5 questions have been asked
- Remaining ambiguities are low-impact

### 3.4 Full abort

If the user says "wrong approach", "start over", or similar:

- Delete the spec file
- Report: "Spec discarded. Re-run /spec with a revised description."
- Stop the process

### 3.5 Deferred markers

If questions remain after early termination, replace unresolved
markers with: `[DEFERRED: not clarified, <reason>]` (check mode:
list them as deferred in the report).

---

## Phase 4: Validate

### 4.1 Load the validation checklist

Read [validation-checklist.md](references/validation-checklist.md)
for the 8-point criteria.

### 4.2 Run the 8-point check

Verify each point (Testability, Completeness, Clarity, Scope,
Independence, Priority, Edge cases, Resolution) with specific evidence
from the spec.

### 4.3 Project-specific validation

Using the domain config (already loaded in Phase 1), run the
project-specific checks per validation-checklist.md
§Project-specific validation.

### 4.4 Fix issues

If points fail, fix the spec directly and re-run the checklist (check
mode: see validation-checklist.md §Check mode).
See validation-checklist.md §Handling failures for the iteration
limit and fallback behavior.

### 4.5 Mark the spec ready

Update frontmatter status (check mode: see validation-checklist.md §Check mode):
- All points pass: `status: Ready`
- Some warnings remain: `status: Ready-with-warnings`

---

## Phase 5: Handoff

### 5.1 Summary report

Output to the user:

- Spec file path
- Number of user stories by priority (P1/P2/P3)
- Number of acceptance criteria total
- Number of clarifications resolved (if Phase 3 ran)
- Validation result (Ready or Ready-with-warnings)
- Any deferred ambiguities or validation warnings

### 5.2 Downstream integration

Explain how the spec feeds `/plan` (which decomposes it into chunks) and
then `/implement` (which builds them), using the spec's Downstream
Mapping table ([spec-template.md](references/spec-template.md)).

### 5.3 Suggest the next step

```
Next: /plan <feature> (spec: docs/specs/<feature>.md)
```

In check mode, point at the design doc instead:
`Next: /plan <feature> (spec: <design doc path>; answers: Q -> A; ...)`.

If the spec has warnings, note them:
"The spec has N unresolved warnings, review the Notes section
before planning."

**Non-code projects:** If the spec covers content, configuration,
or documentation (no executable code), adapt the mapping: failing tests
become validation criteria or review checks, chunk decomposition becomes
content chunking, and suggest a structured build order rather than
`/plan` + `/implement`.

---

## Post-validation pivot

If the user challenges a fundamental assumption after the spec is
marked Ready (e.g., changing the architecture, switching platforms,
redefining scope), re-spec it in these steps:

1. Accept the pivot; don't argue for the existing spec
2. Assess impact: which stories survive the pivot and which need rewriting
3. Bump `spec-version` and update the frontmatter
4. Rewrite the affected sections: stories, criteria, affected components
5. Re-run Phase 4 validation on the updated spec
6. Log the pivot in Clarifications: `- Pivot: <old> → <new> (<reason>)`

This is also the landing point when `/plan` or `/implement` discovers
mid-build that an acceptance *criterion itself* was wrong: they route the
user back here to fix the criterion rather than inventing the fix
downstream, then re-run `/plan` so §3.1 merges the revised spec into the
existing tracker and `review-plan` re-gates.

---

## Spec rules

1. **Rank additions low** -
   Be strict: a "while we're at it" addition is P2 or P3 unless the
   request needs it. Ship P1, then spec P2 separately.
2. **Write criteria, not narrative** -
   Write the spec as a checklist of criteria. Cut narrative and opinion.

---

## Session scope

Specs complete in one session. There is no tracker or session
resumption mechanism. To revisit a feature's spec later, re-run
`/spec`: Phase 1.5 detects the existing file and offers update
or fresh start.

---

## Commit guidance

Do not commit proactively. Wait for the user to request it.
Refer to `.devloop/config.md` for project-specific commit conventions
(author, message format, trailers).
