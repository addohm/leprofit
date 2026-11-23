# Deploying leprofit

leProfit is a World of Warcraft addon in one folder (`leProfit/`), every profession's data built in
(`leProfit/Data/`). It runs inside the game client (WoW: Forever, Interface 16001), and there's no
server.

Releases are published on both CurseForge and Wago (always both), from `release/` with the text
and images in `LISTING.md`. The source is public on GitHub under the GNU GPLv3.

## First-time setup

On the Windows test PC:

1. Clone the repo anywhere: `git clone https://github.com/addohm/leprofit.git` (it needs your
   GitHub login if the repo is private).
2. Open `tools\install_forever.cmd` and check `WOW` at the top: it's the client folder, by default
   `C:\Program Files (x86)\World of Warcraft\_forever_`, the live game.
3. Run `tools\install_forever.cmd` from a terminal, then start the game. Check that leProfit is
   enabled under AddOns at character select.

To install by hand instead, copy the `leProfit` folder (not the repo root) into
`<WoW>\_forever_\Interface\AddOns\`.

## Renamed to leProfit

Builds before 1.1.0 were called Leprofit. The install script removes an installed `Leprofit`
folder before copying (Windows ignores letter case, so it would otherwise keep the old spelling,
which is the addon's name in game). Settings carry over by themselves: the saved files are the
same, and leProfit moves `LeprofitCharDB` and `LeprofitDB` into `leProfitCharDB` and
`leProfitDB` at the first login. If you install by hand, delete the old `Leprofit` folder first.

The first run of the install script after pulling the rename still runs the old script (it runs
from a copy made before the pull), so it installs into the old `Leprofit` folder: run it again.

## Shipping a change

1. Run the tests: `.venv/bin/python tests/run_tests.py`.
2. Commit and push.
3. On Windows, run `tools\install_forever.cmd`, then `/reload` (or restart the game if it says so).
4. For a release: bump `## Version` in `leProfit/leProfit.toc`, move the CHANGELOG's Unreleased entries under the new version, and commit. Then
   `python3 tools/make_release.py` writes `release/leProfit-<version>.zip` with the `leProfit`
   folder from the last commit (it refuses if it has uncommitted changes); commit the zip, tag
   (`git tag v1.0.0`) and push with `--tags`. Upload the zip to CurseForge and to Wago, each with
   `LISTING.md`'s release notes; the summary, description, categories and images are there too. Each release also needs `LISTING.md`'s release
   notes and, if the icon changed, `python3 art/make_logo.py` (it redraws `leProfit/Media/Icon.tga`
   too).

## The install script

`tools\install_forever.cmd` does, in order:

- `git pull --ff-only` (it only gets what's pushed, so push first). The pull can update the
  script itself, so it runs from a copy in `%TEMP%`. If the pull fails because GitHub's history was
  rewritten (this copy's last commit isn't in it any more), it says so and prints the two commands
  that move the copy onto GitHub's: `git fetch origin --tags --force` and
  `git reset --hard origin/main` (they throw away commits and edits made only in the copy).
- Removes an installed folder spelled any other way (`Leprofit`, before 1.1.0), then mirrors
  `leProfit\` into `<WOW>\Interface\AddOns\leProfit` (`robocopy /MIR`), creating it on
  the first run. If `WOW` itself doesn't exist it stops, since the path is probably wrong.
- Deletes old `Leprofit_<Profession>` folders from AddOns: Leprofit 1.0's separate modules, whose
  data is built into leProfit now.
- Writes the commit into the installed `leProfit\Build.lua`, so `/leprofit help` shows
  `v<version> build <commit>`. "-dirty" means the copy included uncommitted changes.
- Packs `leProfit-<version>.zip` on the desktop: `git archive` of the committed addon folders,
  without the build stamp.
- Says whether `/reload` is enough. WoW reads an addon's file list only when the game starts, so
  when a `.toc` changed you must restart the game.

If creating or copying fails, the WoW folder may need the script to run as administrator. The
script needs CRLF line endings to run reliably; `.gitattributes` makes git check it out that way.

## Refreshing the profession data

`leProfit/Data/*.lua` are generated; don't edit them by hand. The easy way to refresh them is
`tools\update_data.cmd` on Windows (or `python3 tools/update_data.py` anywhere): it pulls, downloads,
adds what leProfit recorded in your game (from
`<WoW>\WTF\Account\<account>\SavedVariables\leProfit.lua`, written at logout or `/reload`),
rebuilds, runs the tests, and offers to commit, push and install. It needs Python 3 and git; for
the tests it offers to put lupa in `.venv`. It remembers your WoW folder in
`.source/update_data.json` (the first time it suggests the install script's `WOW`).

By hand:

1. `python3 tools/fetch_sources.py` downloads Forever's game data tables for the newest client
   build (from wago.tools, about 12 MB) and Efficient Games' player-recorded vendors, NPCs,
   trainers, loot, quests, creatures and objects for every live build into the git-ignored
   `.source/` (about 60 MB the first time; Efficient Games' index says when a file changed, so
   later runs only fetch those). Give a build to get older game data:
   `python3 tools/fetch_sources.py 1.60.1.71037`.
2. `python3 tools/gen_data.py` writes the data files and lists what's new or gone: recipes,
   trainer costs and patterns, per profession. Besides vendor patterns, each file lists the
   patterns no vendor sells for gold (`otherPatterns`: the item, its skill, whether it binds, the
   reputation it needs, token vendors, quests and drops), the starter recipes (`free`), and what a
   Craftsman's Writ asks for (`writs`: the item made and the writ, matched by the writ's name; the
   run lists any writ no recipe makes). A
   pattern's `side` is set when only one side can get it: a one-side reputation (from the game's
   Faction table), or every known source that side's (its vendors' faction, its quests' races).
   A vendor's faction comes from Efficient Games' NPC data, else from what leProfit recorded at
   it (`learned.json` sellers); 1.0's factions were dropped, as they were often the recording
   player's. A vendor nobody has recorded has none. Merchant's Favor vendors count for both
   sides (`camp`), and `otherCamp` names the camp nobody has recorded yet. In game, QuestieDB's
   answer (when installed) comes before all of this; a one-side reputation still decides.
3. Run the tests, then commit `leProfit/Data/` (and `tools/learned.json` if it changed).

`tools/learned.json` holds what the game data doesn't: trainer costs and the skill each needs,
pattern sellers and prices, vendor prices of materials, a few item names the game data lacks yet,
and Forever's camp and home items (the game files them under gathering skills; they're listed with
the crafting professions). It started from 1.0's data; you can edit it by hand.

## Rolling back

Install an older version: `git checkout <tag>` in the clone, delete the installed `leProfit`
folder, and copy the tag's addon folders into AddOns (before 1.1.0 they're `Leprofit` and, for
1.0, the `Leprofit_*` modules), then `git checkout main` to return.

## Configuration

There are no secrets or environment settings. In-game settings are per character, in
`WTF/Account/<account>/<realm>/<character>/SavedVariables/leProfit.lua`. Vendor prices and
patterns you record are shared by your characters, in `WTF/Account/<account>/SavedVariables/leProfit.lua`.

## Troubleshooting

- **Nothing on `/leprofit`:** the addon isn't loaded. Check the AddOns list; if it says out of date,
  the client's Interface number isn't 16001.
- **Old `Leprofit_<Profession>` folders in AddOns:** left from Leprofit 1.0. They're ignored;
  delete them (the install script does).
- **No crafts listed:** `/leprofit status` says which price addons it found. Without Auctionator or
  TSM there are no auction prices; with them, scan the auction house. "Show losses" lists everything.
- **Lua errors:** `/console scriptErrors 1` shows them; report them with the `/leprofit help` build.
