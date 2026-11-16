# CLAUDE.md

Orientation for Claude working on leprofit. Read this first.

## What this is

A WoW: Forever addon (Lua, interface 16001) that ranks the crafts that make
gold. A core addon plus one module per profession. The agreed design is in
ROADMAP.md. 0.1.0 (core + Blacksmithing) is built, untested in game. The
remote is `addohm/leprofit` on GitHub.

Discuss each feature with the owner before building it. the source addon (below)
is the reference: check how it handles an area before writing that area.

## Layout

- `Leprofit/`: the core addon.
  - `Core.lua`: settings (per character, `LeprofitCharDB` as `ns.db`; vendor
    records account-wide, `LeprofitDB` as `ns.adb`), the module registry
    (`Leprofit.RegisterProfession`), events, slash commands
  - `Util.lua`: safe calls, `ns.Plain` (secret values), money text, item
    names/icons/sale info, counts, skill
  - `Prices.lua`: Auctionator and TSM prices, vendor prices, and Auctionator's
    price history (its internal database: every step guarded)
  - `Recipes.lua`: a profession's recipes (module data + what the window
    showed), one per name, and where to learn each
  - `Profit.lua`: the sums: make-vs-buy, sale value after the cut, profit,
    payback, flags, the filtered and sorted rows, shopping for n crafts
  - `Recorder.lua`: reads the profession window and vendors, opens the
    profession window, marks recipes learned at trainers
  - `UI/`: `Widgets.lua`, `Window.lua`, `Minimap.lua` (from leboof), `Confirm.lua`
    (the confirmation dialog), `Crafts.lua` and `Options.lua` (the tabs),
    `ProfessionButton.lua`
- `Leprofit_<Profession>/`: one module per profession; `Data.lua` is generated
  by `tools/gen_data.py` and calls `Leprofit.RegisterProfession`.
- `tests/`: `run_tests.py` (syntax, TOCs, globals, then `smoke.lua` against
  the fake client `wowmock.lua`)
- `tools/`: `gen_data.py` (module data), `install_forever.cmd` (Windows
  install), `make_release.py` (release zip)
- `TESTING.md`: the in-game checklist
- The standard docs, and this file.
- `source.zip`, `.source/` (gitignored): its author's Profession
  Planner 1.2.0, a Forever profession-levelling addon, kept as reference.

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
4. Run the checks: `.venv/bin/python tests/run_tests.py` (set up with
   `python3 -m venv .venv && .venv/bin/pip install lupa`), then commit.
   Push when asked; say "Pushed: <commit>" after each push.

## Conventions

- Lua for WoW: Forever (Classic content, modern client, Midnight addon
  limits: guard secret values as the source addon's `ns.Plain` does).
- The UI follows leboof's look (`addohm/leboof`, `Leboof/UI/`).
- Settings are per character.
- When the Crafts list gets dense, put per-craft detail in the row tooltip;
  add a column only for things worth sorting or scanning by (the owner's
  rule).
- Tabs for indentation; a comment at the top of each file says what it's
  for, and comments explain why, in plain words (leboof's style).
- Every module's `.toc` version matches the core's (the tests check).
- A new profession module: make `Leprofit_<Profession>/` with a `.toc` like
  Blacksmithing's, add it to `PROFESSIONS` in `tools/gen_data.py`, run it,
  run the tests, and update README, TESTING and the install notes.
- Batch files need CRLF (`.gitattributes`).

## Don't

- Commit secrets (`.env`, keys, tokens).
- Commit the source addon itself; it stays gitignored. Its licence is all rights
  reserved, but its author has given the owner permission to copy and
  reference its code as needed.
