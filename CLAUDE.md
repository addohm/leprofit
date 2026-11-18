# CLAUDE.md

Orientation for Claude working on leprofit. Read this first.

## What this is

A WoW: Forever addon (Lua, interface 16001) that ranks the crafts that make
gold. A core addon plus one module per profession. The agreed design is in
ROADMAP.md. 0.9.0-beta (core + nine modules) is released, partly tested in game. The
remote is `addohm/leprofit` on GitHub, public, GPLv3; releases go to CurseForge and Wago.

Discuss each feature with the owner before building it.

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
  - `Shopping.lua`: the shopping list (ns.db.plan), its combined materials,
    and Send to Auctionator
  - `Recorder.lua`: reads the profession window and vendors, opens the
    profession window, marks recipes learned at trainers
  - `UI/`: `Widgets.lua`, `Window.lua`, `Minimap.lua` (from leboof), `Confirm.lua`
    (the confirmation dialog), `Crafts.lua`, `Shopping.lua` and `Options.lua`
    (the tabs),
    `ProfessionButton.lua`
- `Leprofit_<Profession>/`: one module per profession (nine); `Data.lua` is generated
  by `tools/gen_data.py` and calls `Leprofit.RegisterProfession`. Mining's is
  written by hand: no recipes (they're read from the smelting window) and
  `windowNames` = Mining or Smelting.
- `tests/`: `run_tests.py` (syntax, TOCs, globals, then `smoke.lua` against
  the fake client `wowmock.lua`)
- `tools/`: `gen_data.py` (module data), `install_forever.cmd` (Windows
  install), `make_release.py` (release zip)
- `TESTING.md`: the in-game checklist
- `LISTING.md`: the CurseForge and Wago page text and release notes
- `art/`: `make_logo.py` draws the icons, the banner and `Leprofit/Media/Icon.tga`
  (the in-game icon); the PNGs it makes
- `release/`: the release zips, one per version
- The standard docs, `LICENSE` (GNU GPLv3), and this file.
- `.source/` (git-ignored): the source data `tools/gen_data.py` reads. Where it
  comes from isn't written in the repo.

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
  limits: guard secret values with `ns.Plain`).
- The UI follows leboof's look (`addohm/leboof`, `Leboof/UI/`).
- Settings are per character.
- When the Crafts list gets dense, put per-craft detail in the row tooltip;
  add a column only for things worth sorting or scanning by (the owner's
  rule).
- Tabs for indentation; a comment at the top of each file says what it's
  for, and comments explain why, in plain words (leboof's style).
- Every module's `.toc` version matches the core's (the tests check).
- A new profession module: make `Leprofit_<Profession>/` (no spaces:
  `Leprofit_FirstAid`) with a `.toc` like Blacksmithing's, add it to
  `PROFESSIONS` in `tools/gen_data.py`, run it, add it to the tests' list,
  run them, and update README, TESTING and the install notes.
- A few recipe IDs are in several professions' data (Forever's camp and home
  items, Synthetic Gordok Ogre Suit); that's kept on purpose.
- Make-vs-buy looks at the recipes this character knows in every enabled
  module (smelting feeds Blacksmithing); "Smelt ..." recipes are only ever
  recorded under Mining.
- Batch files need CRLF (`.gitattributes`).

## Don't

- Commit secrets (`.env`, keys, tokens).
- Commit the source data (`.source/`), or name where it comes from in anything
  committed: code, data, docs or commit messages.
- Show the version or build in the addon's window: chat only (`/leprofit help`).
