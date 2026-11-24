# Chunk decomposition guide

How to break a feature into implementation chunks for TDD workflow. The
decomposition rules are in `/plan` Phase 2.1; this file gives the chunk
categories, the process, and a worked example.

---

## Chunk categories

| Category | Contains | Test strategy |
|---|---|---|
| Data layer | Data classes, entities, models, schemas; repository/service interface + implementation; test doubles (fakes, stubs) | Unit tests for computed properties, conversion helpers |
| Domain / business logic | Domain models (sealed types, data classes, enums); extensions on domain types; coordinator/service methods | Unit tests for logic, integration tests for orchestration |
| UI layer | Components, pages, views; ViewModel / controller state; screen wiring (click handlers, navigation, routing) | Build verification + manual testing (unless UI test infra exists) |
| Migration (BATCH) | Type changes that ripple through files: shared type fields, return types on shared interfaces | Update breaking assertions, build + full suite |
| Verification | Final regression check; depends on every prior chunk | Full suite, build, lint (the code review covers the quality concerns) |

---

## Decomposition process

### Step 1: Identify the data flow
Trace the feature through the application layers: user action -> UI
handler -> domain service / use case -> data layer (DB, API, file).

### Step 2: Identify new code and modified code
- New files: need creation + test files
- Modified files: need careful diffing to avoid breaking existing behavior

### Step 3: Group by compilation unit
If changing file A requires changing file B to compile:
- Put A and B in the same chunk (BATCH)
- Or introduce an intermediate interface so they can change independently

### Step 4: Order by dependencies
Data layer (no deps) -> domain layer -> UI layer -> verification.

### Step 5: Write acceptance criteria

For each chunk, define acceptance criteria: explicit pass/fail
conditions, agreed before implementation begins, that decide whether the
chunk is done. Each is testable (maps to a test assertion or verifiable
output), specific ("search returns filtered results", not "search
works"), and together they cover happy path, edge cases, and error cases.
What goes in `notes` is in
[tracker-schema.md](tracker-schema.md) §Resuming a chunk.

---

## Example: share feature

### Chunk 1: Domain logic (data layer)
```json
{
  "id": 1,
  "name": "buildShareText and toDuplicate helpers",
  "acceptance_criteria": [
    "buildShareText returns formatted string with title and date",
    "buildShareText includes location when present, omits when empty",
    "toDuplicate copies all fields except generates new ID",
    "toDuplicate preserves timed format with start/end times"
  ],
  "files_create": [], "files_modify": ["src/domain/model/Item.ts"], "test_files": ["src/domain/model/Item.test.ts"],
  "tdd": "Write 6 tests: property mapping, default ID, date format, timed format, location present, location empty. Run -> compile error -> implement -> pass.",
  "depends_on": []
}
```

### Chunk 2: UI components (depends on chunk 1)
```json
{
  "id": 2,
  "name": "Share button in QuickView",
  "acceptance_criteria": [
    "Share button renders in QuickView detail panel",
    "Button click triggers onShare callback with current item"
  ],
  "files_create": [], "files_modify": ["src/ui/components/QuickView.tsx"], "test_files": [],
  "tdd": "No unit test (UI: rendering only, pure callback threading, no hoisted state or branching effects). Verified by build.",
  "depends_on": [1]
}
```

> If this chunk introduced hoisted state, a `useEffect`/`LaunchedEffect`,
> or input transformation, it would be a UI: state-holder chunk and need a
> test on the extracted holder. See the implement SKILL.md §2.2 (Determine
> the test strategy) state-holder detection.

### Chunk 3: Wiring (depends on chunks 1 and 2)
```json
{
  "id": 3,
  "name": "App-level callback wiring",
  "acceptance_criteria": [
    "Share callback connected from App to QuickView",
    "Share action calls buildShareText and opens share dialog"
  ],
  "files_create": [], "files_modify": ["src/App.tsx"], "test_files": [],
  "tdd": "No unit test (wiring). Verified by build + full suite regression.",
  "depends_on": [1, 2]
}
```

### Chunk 4: Regression
```json
{
  "id": 4,
  "name": "Full regression run",
  "acceptance_criteria": [
    "Full test suite passes with no new failures",
    "Build compiles without errors or new warnings",
    "Lint reports no new errors"
  ],
  "files_create": [], "files_modify": [], "test_files": [],
  "tdd": "Run the full test suite, build and lint.",
  "depends_on": [1, 2, 3]
}
```

---

## Anti-patterns

- **Over-chunking:** 10 chunks for a 3-file change; 1-3 chunks that map
  to natural boundaries is the target
- **Missing BATCH:** chunk A changes a shared type and chunk B its
  consumer; one BATCH chunk changes both
- **Vague names:** `"Implement the feature"` instead of a name like
  `"buildShareText and toDuplicate helpers"` with concrete files and `tdd`
