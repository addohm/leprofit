# CLAUDE.md

Orientation for Claude working on leprofit. Read this first.

## What this is

No code yet; the repo holds only the standard docs. The remote is
`addohm/leprofit` on GitHub.

TODO: what is leprofit? (Ask the owner before starting; plan first.)

## Layout

- `README.md`, `CHANGELOG.md`, `DEPLOY.md`, `SECURITY.md`, `ROADMAP.md`: the
  standard docs
- `CLAUDE.md`: this file
- `source.zip`, `.source/` (gitignored): its author's Profession
  Planner 1.2.0, a Forever profession-levelling addon, kept as reference

TODO: add the code layout once there is some.

## Workflow

1. Start from the latest: pull before changing anything.
2. Make the change with tests.
3. **Update the docs in the same commit.** Every change updates the docs it
   affects:
   - README.md: setup and usage
   - CHANGELOG.md: an entry under *Unreleased*
   - DEPLOY.md: when deploying or running it live changes
   - SECURITY.md: when secrets, access or permissions change
   - ROADMAP.md: when something on it is done, or new plans are made
   - this file: when the layout, workflow or conventions change
4. Run the checks (TODO: none yet; add the lint and test commands with the first code), then commit.

## Conventions

TODO: none yet. What language/stack will it use?

## Don't

- Commit secrets (`.env`, keys, tokens).
- Copy code from the source addon, or commit it: its licence is all rights
  reserved and forbids copying or modifying it.
