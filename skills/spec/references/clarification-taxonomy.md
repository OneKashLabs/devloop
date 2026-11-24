# Clarification taxonomy

Structured categories for detecting ambiguity in feature specs.
Use this during Phase 2 (to identify edge cases and mark ambiguities)
and Phase 3 (to prioritize clarification questions).

For each category, assess: **Clear** | **Partial** | **Missing**

**Category filtering:** Not all 9 categories apply to every project.
Skip categories that are structurally irrelevant, e.g., skip
"Users and roles" for single-user CLI tools, skip "Interaction flow"
for non-interactive content packages. Mark skipped categories as
"N/A" rather than "Clear" to distinguish "doesn't apply" from
"assessed and satisfied."

Categories marked Partial or Missing are candidates for
`[NEEDS CLARIFICATION]` markers. Only promote to a marker when the
ambiguity would materially change implementation or tests, no reasonable
default exists, and the interpretations have materially different
implications.

---

## Categories

### 1. Scope and boundaries

What is included in this feature? What is explicitly excluded?

**Check for:** Feature boundaries (where this feature starts and stops);
MVP vs future work (what's P1 vs deferred); Size/volume limits (max
items, file sizes, user counts); Version boundaries (does this replace
existing behavior?); Behavioral migration (what happens to users of the
old behavior?); Feature flags (gradual rollout or all-at-once?).

**Reasonable defaults:** If not specified, assume all-at-once
rollout, no feature flags, standard volume for the project type.

### 2. Users and roles

Who uses this feature? Does behavior differ by user type?

**Check for:** Primary user persona (who benefits most?); Permission
levels (admin, user, guest, anonymous); Multi-tenancy (data isolation
between users/orgs); Authentication requirements (logged in vs public).

**Reasonable defaults:** If not specified, assume single user type,
authentication required, no multi-tenancy.

### 3. Data and state

What data does this feature create, read, update, or delete?

**Check for:** Entities and relationships (what data objects are
involved?); Required vs optional fields; State transitions (draft ->
published -> archived); Data volume assumptions (hundreds vs millions of
records); Data retention and cleanup; Migration needs (does existing
data need transformation?).

**Reasonable defaults:** If not specified, assume standard CRUD,
industry-standard retention, no migration needed.

### 4. Interaction flow

What is the primary user journey?

**Check for:** Happy path (the main user flow from trigger to
completion); Entry points (how does the user reach this feature?);
Multi-step flows (can they be interrupted and resumed?); Loading states
(what does the user see while waiting?); Empty states (what does the
user see with no data?); Confirmation steps (destructive actions need
confirmation?).

**Reasonable defaults:** If not specified, assume single entry
point, loading spinner, "no items yet" empty state, confirmation
for destructive actions.

### 5. Error handling

What happens when things go wrong?

**Check for:** Input validation errors (what's invalid? how
communicated?); Network/service failures (timeout, 500, offline);
Permission denied (unauthorized access attempts); Partial failure (3 of
5 items succeed, what happens?); Retry behavior (automatic? manual? how
many times?); Degraded mode (can the feature work with reduced
capability?).

**Reasonable defaults:** If not specified, assume user-friendly
error messages, manual retry, no degraded mode.

### 6. Edge cases and boundaries

What boundary conditions and concurrent scenarios exist?

**Check for:** Zero/one/max values (empty list, single item, overflow);
Null/missing/malformed data; Concurrent operations (two users editing
the same thing); Race conditions (rapid clicks, parallel requests);
Timezone and locale sensitivity; Unicode, emoji, RTL text in user input;
Long strings, large files.

**Reasonable defaults:** If not specified, assume the
platform's usual limits, no special concurrent handling
beyond standard framework protections.

### 7. Integration and dependencies

What existing systems does this feature interact with?

**Check for:** External services/APIs (what happens if they're down?);
Existing features affected (does this change existing behavior?); Data
format contracts (JSON schema, protobuf, XML); Versioning (API version,
protocol version); Timeouts and circuit breakers; Backward compatibility
(old clients, old data).

**Reasonable defaults:** If not specified, assume current API
version, standard timeout (30s), no backward compatibility
concerns unless the project has existing consumers.

### 8. Non-functional concerns

Which quality attributes does this feature have to meet, and how will
each be checked? Scan the five groups below and ask only about the
attributes the project's domain config or the feature makes relevant. An
answer becomes an acceptance criterion with a number or a named standard
and a way to verify it (a test, a benchmark, a measurement, a manual
check), for example "search returns in under 300 ms for 10,000 items,
measured by a benchmark test". "Fast", "secure" or "accessible" alone is
not a criterion.

**Operation:** Availability (uptime target, behavior when a dependency
is down, offline use); Reliability (what happens on failure, retries,
recovery time); Data integrity (no lost, duplicated or half-written
records; validation at the boundary); Recovery (backup, restore, what
survives a crash or reinstall).

**Performance:** Response time (P50, P95, P99 latency, startup time);
Throughput (requests or items per second); Capacity and scale (largest
data set, number of users, growth); Resource use (memory, CPU, battery,
bandwidth, storage).

**Security and compliance:** Authentication and authorization; Data
protection (encryption in transit and at rest); Input sanitization
(injection prevention); Privacy (which personal data is collected,
stored, shared or logged, and for how long); Compliance (a legal,
regulatory or store rule that applies); Audit trail (who did what, when).

**Interoperability and maintenance:** Interoperability (formats,
protocols and API versions it must read and write, backward
compatibility); Portability (platforms, versions and devices it must
run on); Observability (which events are logged at which level, which
metrics are kept and at which thresholds they alert, tracing across
services, what an operator can see when it fails).

**User experience:** Accessibility (screen reader support, keyboard
navigation, contrast, target size, the conformance level, for example
WCAG AA); Internationalization (translated text, plural rules,
right-to-left layout, date, number and currency formats); Usability
(the task the user must finish, and how quickly or in how many steps).

**Reasonable defaults:** If not specified, assume the platform's usual
performance, the project's existing auth, no specific WCAG target,
standard logging at info and error levels, and the platforms and locales the project
already supports. Record each default you assume in the spec's
Assumptions.

### 9. Domain-specific concerns

Project-specific patterns from `.devloop/domain.md`.

**Check for:** Domain-specific edge cases listed in .devloop/domain.md;
Industry standards or regulations that apply; Known domain pitfalls from
the project's Lessons Learned; Patterns that every feature in this
project must address.

This category has no reasonable defaults, it's entirely
project-specific. If .devloop/domain.md doesn't exist or has no
domain concerns listed, skip this category.

---

## Prioritization

When multiple categories have ambiguities, promote to
`[NEEDS CLARIFICATION]` in this priority order:

1. Scope and boundaries: a wrong scope wastes the implementation
2. Data and state: a wrong model forces rework
3. Error handling: missing error handling causes production incidents
4. Users and roles: wrong permissions cause security issues
5. Edge cases: missing edge cases become bugs found later
6. Integration: missed dependencies break features
7. Interaction flow: a wrong flow hurts the user experience
8. Non-functional: a missing target can't be tested, and is found late
9. Domain-specific: rank by the project's domain config

---

## Question design

`/spec` Phases 3.1 and 3.2 set the question format (context, recommendation,
options table, one at a time). In addition:

- Offer 2-5 options, mutually exclusive, with no overlapping choices
- Include a "Custom" row if a free-form answer makes sense
- State the impact: why this question matters for the spec
