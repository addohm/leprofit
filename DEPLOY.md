# Deploying leprofit

Leprofit is a World of Warcraft addon: a core (`Leprofit/`) and one folder per profession module
(`Leprofit_Alchemy/`, `Leprofit_Blacksmithing/`... `Leprofit_FirstAid/`... `Leprofit_Tailoring/`). It runs inside the game client (WoW: Forever, Interface 16001), and
there's no server.

Releases are published on both CurseForge and Wago (always both), from `release/` with the text
and images in `LISTING.md`. The source is public on GitHub under the GNU GPLv3.

## First-time setup

On the Windows test PC:

1. Clone the repo anywhere: `git clone https://github.com/addohm/leprofit.git` (it needs your
   GitHub login if the repo is private).
2. Open `tools\install_forever.cmd` and check `WOW` at the top: it's the client folder, by default
   `C:\Program Files (x86)\World of Warcraft\_forever_`, the live game.
3. Run `tools\install_forever.cmd` from a terminal, then start the game. At character select, under
   AddOns, tick Leprofit and the modules for that character's professions.

To install by hand instead, copy `Leprofit` and the `Leprofit_*` folders (not the repo root) into
`<WoW>\_forever_\Interface\AddOns\`.

## Shipping a change

1. Run the tests: `.venv/bin/python tests/run_tests.py`.
2. Commit and push.
3. On Windows, run `tools\install_forever.cmd`, then `/reload` (or restart the game if it says so).
4. For a release: bump `## Version` in every `.toc` (the core's and each module's; the tests check
   they match), move the CHANGELOG's Unreleased entries under the new version, and commit. Then
   `python3 tools/make_release.py` writes `release/Leprofit-<version>.zip` with every addon folder
   from the last commit (it refuses if they have uncommitted changes); commit the zip, tag
   (`git tag v0.9.0-beta`) and push with `--tags`. Upload the zip to CurseForge and to Wago, each with
   `LISTING.md`'s release notes; the summary, description, categories and images are there too. Each release also needs `LISTING.md`'s release
   notes and, if the icon changed, `python3 art/make_logo.py` (it redraws `Leprofit/Media/Icon.tga`
   too).

## The install script

`tools\install_forever.cmd` does, in order:

- `git pull --ff-only` (it only gets what's pushed, so push first). The pull can update the
  script itself, so it runs from a copy in `%TEMP%`.
- Mirrors `Leprofit\` and each `Leprofit_*\` folder into `<WOW>\Interface\AddOns\` (`robocopy /MIR`),
  creating them on the first run. If `WOW` itself doesn't exist it stops, since the path is
  probably wrong. A module removed from the repo stays installed: delete its folder by hand.
- Writes the commit into the installed `Leprofit\Build.lua`, so `/leprofit help` shows
  `v<version> build <commit>`. "-dirty" means the copy included uncommitted changes.
- Packs `Leprofit-<version>.zip` on the desktop: `git archive` of the committed addon folders,
  without the build stamp.
- Says whether `/reload` is enough. WoW reads an addon's file list only when the game starts, so
  when a `.toc` changed you must restart the game.

If creating or copying fails, the WoW folder may need the script to run as administrator. The
script needs CRLF line endings to run reliably; `.gitattributes` makes git check it out that way.

## Refreshing a module's data

The recipe, trainer and pattern data comes from the source data file in the git-ignored `.source/`
folder. To refresh it, replace that file with a newer one, run
`.venv/bin/python tools/gen_data.py`, run the tests, and commit the new `Data.lua` files.

## Rolling back

Install an older version: `git checkout <tag> -- Leprofit "Leprofit_*"` in the clone, copy the
folders over the installed ones, then `git checkout main -- Leprofit "Leprofit_*"`
to return.

## Configuration

There are no secrets or environment settings. In-game settings are per character, in
`WTF/Account/<account>/<realm>/<character>/SavedVariables/Leprofit.lua`. Vendor prices and
patterns you record are shared by your characters, in `WTF/Account/<account>/SavedVariables/Leprofit.lua`.

## Troubleshooting

- **Nothing on `/leprofit`:** the addon isn't loaded. Check the AddOns list; if it says out of date,
  the client's Interface number isn't 16001.
- **"No profession modules are enabled":** tick Leprofit - <profession> for this character in the
  AddOns list, then restart or /reload.
- **No crafts listed:** `/leprofit status` says which price addons it found. Without Auctionator or
  TSM there are no auction prices; with them, scan the auction house. "Show losses" lists everything.
- **Lua errors:** `/console scriptErrors 1` shows them; report them with the `/leprofit help` build.
