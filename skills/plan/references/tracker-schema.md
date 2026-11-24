# JSON tracker schema

The tracker file, `impl-tracker-<feature>.json`, records the
feature's implementation progress and is the handoff between sessions. Commit it for cross-machine resumability or gitignore it.
Write it atomically (write a temp file, then rename over the old one) so a
crash mid-write cannot corrupt it.

---

## Schema

```json
{
  "phase": "Human-readable phase/feature name",
  "issue": "GitHub/GitLab issue reference (e.g., org/repo#76)",
  "design_doc": "path/to/design-doc.md (optional)",
  "plan_doc": "path/to/plan.md (optional)",
  "spec_doc": "docs/specs/<feature>.md or a design doc (optional, set by /plan)",
  "proof": "Bug fixes: the failing test and the failure seen, or the probe sent and the reply",
  "plan_review": "PENDING",
  "chunks": [
    {
      "id": 1,
      "name": "Short descriptive name",
      "status": "pending",
      "files_create": ["path/to/NewFile.ext"], "files_modify": ["path/to/ExistingFile.ext"], "test_files": ["path/to/TestFile.ext"],
      "acceptance_criteria": ["Criterion 1", "Criterion 2"],
      "tdd": "Write test for X. Run -> fail -> implement -> pass.",
      "depends_on": [],
      "notes": "Optional notes: decisions, constraints, pattern to follow (file:function), and pitfalls to avoid."
    }
  ],
  "quality_verification": {
    "completeness": "Summary of completeness check",
    "correctness": "Summary of correctness check",
    "regression": "Summary of regression check",
    "robustness": "Summary of robustness check",
    "blindspots": "Summary of blindspots check",
    "maintainability": "Summary of maintainability check",
    "final": "Verdict and what is left for the user"
  }
}
```

---

## Field definitions

### Top-level fields

| Field | Required | Description |
|-------|----------|-------------|
| `phase` | Yes | Human-readable name for the feature or phase |
| `issue` | Yes | Issue tracker reference |
| `design_doc` | No | Path to design document |
| `plan_doc` | No | Path to plan document |
| `spec_doc` | No | Path to the source spec, set by `/plan` so `/implement` and the review agents bind to the exact spec instead of globbing the spec directory. It may name a spec file (`docs/specs/*.md`) or a design doc whose recorded decisions are the acceptance criteria; when it names a design doc, `design_doc` is not needed. `review-plan` checks the plan against whichever file it names |
| `proof` | Bug fixes | The failing test (name and the failure seen) or the live probe (what was sent and what came back). `/plan` Phase 1.1 says when it is required |
| `plan_review` | No | Review-plan gate verdict. **Lifecycle:** `/plan` Phase 3 creates the tracker with `"PENDING"` (gate not yet run); the Phase 4 gate overwrites it with `"PASS"`, `"PASS-WITH-WARNINGS"`, or `"FAIL"`. `/implement` refuses to start the TDD cycle unless it is `PASS` or `PASS-WITH-WARNINGS`, so `"PENDING"` and `"FAIL"` both hard-stop. Never pre-stamp `"PASS"` at creation |
| `chunks` | Yes | Array of implementation chunks |
| `quality_verification` | No | The 6 concern summaries (written when checkpoint 2 is approved) and `final` (verdict and what is left, written at close). Review counts are not stored: the round count lives in the session, see [review-and-finish.md](../../implement/references/review-and-finish.md) |

### Chunk fields

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Integer, sequential starting at 1 |
| `name` | Yes | Short descriptive name (5-10 words) |
| `status` | Yes | `pending`, `in_progress`, `complete`, or `error` |
| `files_create` | Yes | Paths of new files to create (empty array if none) |
| `files_modify` | Yes | Paths of existing files to modify (empty array if none) |
| `test_files` | Yes | Paths of test files (new or modified) |
| `acceptance_criteria` | Yes | Array of testable pass/fail conditions for this chunk |
| `tdd` | Yes | TDD instructions: what to test, expected fail, then pass |
| `depends_on` | Yes | Array of chunk IDs that must be `complete` first |
| `notes` | No | Decisions, constraints, pattern hints and pitfalls the other fields can't carry (see §Resuming a chunk) |

---

## Status transitions

```text
pending ──> in_progress ──> complete
                │
                └──> error ──> in_progress   (retry once the blocker is resolved)
```

Rules:
- Set `in_progress` before starting work (not after)
- Set `complete` only after tests pass and tracker is verified
- Set `error` if blocked; add notes explaining what went wrong
- Never skip `in_progress` (helps session resumption)
- `error` is not terminal: a session re-enters it (like `in_progress`)
  once the blocker is resolved, or escalates. A chunk left at `error`, or
  no selectable `pending` chunk while not all are `complete` (a cycle or
  dangling dependency), is a blocked feature: `/implement` surfaces it to
  the user, never silently finishes with the Phase 3 gate un-triggered.

---

## Resuming a chunk

A resuming session reads the chunk's required fields directly:
`name` (what), `files_create` + `files_modify` (where), `tdd` (test
conditions), `acceptance_criteria` (pass/fail). They must let a fresh
session build the chunk without re-deriving the plan. Add a `notes`
entry only for what it can't infer from those, such as a
`Pattern: file:function` hint or an `Avoid: ...` pitfall.

```json
{
  "notes": "Pattern: follow getItemsByDate() in SqlItemRepository. Avoid: changing service return types; wrap the result internally."
}
```

---

## Batch chunk convention

When multiple files must change together (won't compile between), prefix the
`tdd` field with "BATCH":

```json
{
  "tdd": "BATCH - all 3 files must change together. No standalone unit test (UI). Verified by build + full suite regression. Update 16 breaking assertions in ServiceTest."
}
```

---

## Single-chunk features

For small features (1 chunk), the tracker is still created but simplified:

```json
{
  "phase": "Feature Name",
  "issue": "org/repo#XX",
  "spec_doc": "docs/specs/feature-name.md",
  "plan_review": "PENDING",
  "chunks": [
    {
      "id": 1,
      "name": "Feature description",
      "status": "pending",
      "files_create": [], "files_modify": ["path/to/File.ext"], "test_files": ["path/to/Test.ext"],
      "acceptance_criteria": ["Describe the pass/fail condition"],
      "tdd": "Pre-test: existing TestClass covers logic. Pure UI change. Post-test: full suite regression.",
      "depends_on": [],
      "notes": "Optional context."
    }
  ],
  "quality_verification": { }
}
```

---

## Dependency graph notation

Document the execution order in the plan (not the tracker):

```text
Layer 1 (no deps):             Chunks 1, 2, 9
Layer 2 (depends on Layer 1):  Chunks 3, 4, 5, 6
Layer 3 (depends on Layer 2):  Chunks 7, 8
Layer N (final):               Chunk 10 (regression)
```

In a multi-chunk tracker the final chunk is a regression chunk (full
suite, build, lint) that depends on every prior chunk; a 1-chunk tracker
runs them in its one chunk.
