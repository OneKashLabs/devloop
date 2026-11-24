# Spec template

The output format for spec files, loaded in `/spec` Phase 2 (Specify).
Phase 2.7 says where the file goes and how it is named.

---

## Template

```markdown
---
feature: "<Feature Name>"
status: Draft
created: YYYY-MM-DD
source: "<the user's original request text>"
spec-version: 1
---

# Feature: <Feature Name>

## Overview

<What this feature does and why it matters (see guidelines).>

## User Stories

### US1: <Story Title> [P1]

**As a** <role>, **I want** <goal>, **so that** <benefit>.

**Why P1:** <one sentence justifying this priority>

**Acceptance Criteria:**
1. **Given** <precondition>, **When** <action>, **Then** <outcome> (1 test)
2. **Given** <precondition>, **When** <error condition>, **Then** <error outcome> (1 test)
3. **Given** <varying inputs>, **When** <action>, **Then** <expected outcomes> (parameterized)

### US2: <Story Title> [P2]

**As a** <role>, **I want** <goal>, **so that** <benefit>.

**Why P2:** <one sentence justifying this priority>

**Acceptance Criteria:**
1. **Given** <precondition>, **When** <action>, **Then** <outcome> (1 test)

## Edge Cases

- <Edge case 1: scenario and expected behavior> [Category N]
- <Edge case 2: scenario and expected behavior> [Category N]

## Out of Scope

- <Explicitly excluded behavior 1>
- <Explicitly excluded behavior 2>

## Assumptions

- <Reasonable default chosen, with rationale>
- <Another assumption, with what would change if wrong>

## Affected Components

| File / Module | Role | Impact |
|---|---|---|
| <path/to/file> | <what it does> | <what changes> |
| <path/to/module> | <what it does> | <what changes> |

## Downstream Mapping

| Spec Section | Consumed by | How to Use |
|---|---|---|
| User Stories | /plan Phase 1 (Analysis) | Scope of what to explore |
| Affected Components | /plan Phases 1-2 | Starting point for chunk decomposition |
| Assumptions | /plan Phase 1 (Analysis) | Context for architecture decisions |
| Acceptance Criteria | /plan (chunk criteria), /implement (tests) | Become per-chunk criteria, then failing tests |
| Edge Cases | /implement Phase 2 (TDD cycle) | Additional test cases |

## Clarifications

### Session YYYY-MM-DD

- Q: <question> -> A: <resolved answer>

## Notes

<Validation warnings, deferred items, or anything that doesn't
fit above. Remove this section if empty.>
```

---

## Section guidelines

### Frontmatter

```yaml
---
feature: "User Search"        # Human-readable feature name
status: Draft                  # Draft | Ready | Ready-with-warnings
created: 2026-03-26            # Date spec was first created
source: "add search to..."    # The user's original $ARGUMENTS
spec-version: 1                # Bumped when spec is re-run/updated
---
```

### Overview

- Focus on user value, not technical approach
- One sentence for what it does, one for why
- No implementation details: no framework names, file paths, API
  endpoints or algorithms

### User Stories

- **P1:** Must-have for the feature to be useful
- **P2:** Important but the feature works without it
- **P3:** Nice-to-have, could be a separate follow-up spec
- Avoid stories that are implementation tasks disguised as user needs

### Acceptance Criteria

- Each criterion should map to one or more tests
- Be specific: "error message appears" is too vague,
  "red banner shows 'Failed to save. Retry?'" is testable
- Hint at test complexity in parentheses:
  - `(1 test)`, single assertion
  - `(parameterized)`, multiple input/output combinations
  - `(integration)`, requires external dependency or multi-step setup
- Avoid criteria that test implementation ("database row is created");
  test behavior ("user sees the new item in their list")

### Edge Cases

- Focus on scenarios that would break a naive implementation
- Domain-specific concerns from .devloop/domain.md get their own items

### Out of Scope

- State what this feature does not do
- Prevents scope creep during TDD implementation
- "Out of scope" items are candidates for future specs

### Assumptions

- Only document non-obvious assumptions
- Each should include: what was assumed, why, and what changes
  if the assumption is wrong
- Don't document obvious defaults ("errors show error messages")

### Affected Components

- File paths and modules from Phase 1 exploration
- Brief role description so /plan can skip redundant exploration
- Impact column describes what will change, not how

### Downstream Mapping

- Always include this section: `/plan` reads it to find which spec
  section each phase uses
- Maps each spec section to the /plan or /implement phase that consumes it
- Non-code projects adapt the mapping as `/spec` Phase 5.3 says

### Clarifications

- Added during Phase 3 as questions are resolved
- One `### Session YYYY-MM-DD` heading per `/spec` invocation
- Preserved across re-runs (when user chooses "update")

### Notes

- Validation warnings from Phase 4
- Deferred items (ambiguities that weren't worth clarifying)
- Remove this section if empty
