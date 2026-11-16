# CLAUDE.md

Orientation for Claude working on leprofit. Read this first.

## What this is

A WoW: Forever addon (Lua, interface 16001) that ranks the crafts that make
gold. A core addon plus one module per profession. The agreed design is in
ROADMAP.md. No code yet; the remote is `addohm/leprofit` on GitHub.

Discuss each feature with the owner before building it. the source addon (below)
is the reference: check how it handles an area before writing that area.

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

- Lua for WoW: Forever (Classic content, modern client, Midnight addon
  limits: guard secret values as the source addon's `ns.Plain` does).
- The UI follows leboof's look (`addohm/leboof`, `Leboof/UI/`).
- Settings are per character.

## Don't

- Commit secrets (`.env`, keys, tokens).
- Commit the source addon itself; it stays gitignored. Its licence is all rights
  reserved, but its author has given the owner permission to copy and
  reference its code as needed.
