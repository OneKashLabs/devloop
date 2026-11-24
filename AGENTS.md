# AGENTS.md

Project rules for any agent working in this repository. devloop is a
test-driven development loop for AI coding agents, shipped as a plugin for
Claude Code and Codex. The product is prompt text: three skills under
`skills/`, two review agents under `agents/`.

The full engineering config lives in
[`.devloop/config.md`](.devloop/config.md) (build and test commands,
architecture patterns, standards to verify, blindspots, commit conventions)
and the domain context in [`.devloop/domain.md`](.devloop/domain.md). Read
`config.md` before reviewing or changing anything under `skills/` or
`agents/`. Those files are the canonical home for the rules.

## Before you commit

- Run `./validate.sh`. It must report 0 failed. It is the only automated
  test in this repo.
- Use standard punctuation: no em dashes and no en dashes in any published
  file. `validate.sh` fails on them.
- Commit mechanics (staging discipline, bumping both plugin manifests
  together) live in [`.devloop/config.md`](.devloop/config.md) under Commit
  Conventions.

## While you work

- Keep skill and agent prose harness-agnostic. State the intent and let
  the harness supply the mechanism. Naming a Claude Code keystroke or a Codex
  command breaks the other harness and fails the suite.
- Working notes go in `.local-docs/` (gitignored). The website
  (devloop.onekash.org) lives in its own repository,
  OneKashLabs/devloop-website.
- A prompt change is a behavior change. Reading the diff does not tell
  you whether a review agent's recall moved. Do not claim a review-agent
  improvement that only inspection supports; see the last standard in
  `.devloop/config.md`.
