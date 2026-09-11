# AGENTS.md

Project rules for any agent working in this repository. devloop is a
test-driven development loop for AI coding agents, shipped as a plugin for
Claude Code and Codex. The product is prompt text: three skills under
`skills/`, three review agents under `agents/`.

**The full engineering config lives in
[`.devloop/config.md`](.devloop/config.md)** (build and test commands,
architecture patterns, standards to verify, blindspots, commit conventions)
and the domain context in [`.devloop/domain.md`](.devloop/domain.md). Read
`config.md` before reviewing or changing anything under `skills/` or
`agents/`. Those files are the canonical home for the rules; this file exists
because it is the harness-native one, and it stays short on purpose.

## Before you commit

- **Run `./validate.sh`.** It must report 0 failed. It is the only automated
  test in this repo.
- **Use standard punctuation.** No em dashes and no en dashes in any
  published file. The suite enforces this; writing them anyway just costs a
  cycle.
- **Commit mechanics** (staging discipline, bumping both plugin manifests
  together) live in [`.devloop/config.md`](.devloop/config.md) under Commit
  Conventions. That is their canonical home; they are not restated here, so
  the two files cannot drift.

## While you work

- **Keep skill and agent prose harness-agnostic.** State the intent and let
  the harness supply the mechanism. Naming a Claude Code keystroke or a Codex
  command breaks the other harness and fails the suite.
- **Working notes go in `.local-docs/`** (gitignored). `docs/` is the
  published GitHub Pages site, not a scratch directory.
- **A prompt change is a behavior change.** Reading the diff does not tell
  you whether a review agent's recall moved. Do not claim a review-agent
  improvement that only inspection supports; see the last standard in
  `.devloop/config.md`.
