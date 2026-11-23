# Changelog

All notable changes to leprofit. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.3.0] - 2026-11-23

Crafts a Craftsman's Writ asks for are marked.

### Added

- Crafts a trade faction's Craftsman's Writ asks for are marked with a small scroll (the writ's
  icon) after their name, and their tooltip names the writ. Searching "writ" (or "craftsman")
  lists them all. 146 of Forever's 150 writs ask for something leProfit crafts (Alchemy,
  Blacksmithing, Engineering, Leatherworking, Tailoring); the match comes from each writ's name
  in the game data. `/leprofit debug` names the writ too.

## [1.2.0] - 2026-11-23

No more lag spikes from leProfit, losses shown in red rather than hidden, and the profession window
left alone: leProfit knows your recipes from the game itself.

### Changed

- **Hide losses** replaces Show losses, and it's off: crafts at a loss are listed, their profit in
  red, and crafts without a price come last. Tick it to leave both out, as before. A craft no
  longer seems missing because of a box you didn't know was unticked.
- Opening leProfit no longer opens your profession window. Which recipes each character knows
  comes from the game itself, for every profession, without the window; opening the window
  yourself still adds what it shows.

### Added

- `/leprofit debug [item]`: a report to copy into a bug report, in a window with it all selected
  (Ctrl+C). The versions (leProfit, the game, the data), the faction and professions, the
  settings that change the sums, the price addons found, the slowest work, and for the item every
  price leProfit could have used (Auctionator, TSM's minimum and market value, the history,
  vendors, crafting it), which it chose, the sums, and why the list shows it or not. No character
  or realm names.
- `/leprofit perf`: how long each kind of leProfit's work has taken since login (each event, a
  redraw, a slice of sums), slowest first, so a lag report can say what's behind it.

### Fixed

- A 123 ms hitch when the sums are worked out (seen with `/leprofit perf`): working out one craft's
  materials asked every profession what this character can craft, and that built every
  profession's full list, QuestieDB lookups and all, in one go. Make-vs-buy now uses a cheap list
  of the recipes you know by what they make, and the full lists are built a step at a time with
  the sums. Reading the profession window keeps each recipe's materials after the first read
  (they don't change), so later reads only ask which recipes are learned.
- Lag at intervals: the game's "profession list updated" event also comes while the profession
  window is closed, and leProfit read the whole recipe list each time. It reads only while the
  window is open now (between the game's open and close events).
- Lag spikes (over a second at worst): every redraw of the Crafts list redid every craft's sums,
  read Auctionator's price history and the game's item details for each, and the first look at a
  profession asked QuestieDB for every pattern's sources at once. Now each craft's sums are kept
  until prices, the data or the settings change (an Auctionator scan, a recipe learned, Options);
  a long list's first sums are worked out a few milliseconds per frame ("Working out the
  sums..."); the price history is only read for a history column or a tooltip; item details are
  read once; QuestieDB's names and places are only read for a tooltip; and vendors and trainers
  look names up without rebuilding the lists.

### Removed

- The button on the profession window: it never showed on Forever's profession windows. The
  minimap button, the addon menu and `/leprofit` open leProfit; its Options box is gone too.

## [1.1.0] - 2026-11-22

Renamed to leProfit, and one addon: every profession is built in. The built-in data comes from
Forever's own game data now, and tooltips say where to get every pattern.

### Added

- Recipes learned from a pattern no vendor sells for gold are listed when the pattern can be
  traded: learning one costs the pattern's auction price, and the payback counts from it (about
  640 across the professions, 105 of them Blacksmithing's). Patterns that bind when picked up are
  listed with **Show all**, which now lists everything you could get: more skill, patterns that
  bind, and recipes with no known source (the separate Options box is gone). Each profession's
  starter recipes show as coming with the profession.
- Tooltips, the materials panel and `/leprofit why` say where to get a pattern: the reputation
  it needs, the vendors who sell it (for gold, or tokens such as Merchant's Favor), the quests
  that reward it, and what drops it, with how often players saw it drop. From Efficient Games'
  player-recorded loot, quests and vendors, and the game data's reputation requirements.
- Recipes only the other side can get are never listed, and the "Not listed" line counts them:
  a one-side reputation (Kirin Tor, Earthen Ring), quests only for the other side's races, or a
  pattern only the other side's vendors sell (Red Firework, sold only in Orgrimmar). A vendor's
  side comes only from a record of the vendor itself (QuestieDB, Efficient Games, or what you
  recorded); 1.0's vendor factions are dropped, since they were often the faction of the player
  who saw the vendor. The trade camps' Merchant's Favor plans count for both sides, with a note
  when only one camp's quartermaster has been recorded.
- With **QuestieDB** installed (Questie's database on Forever), leProfit asks it in game where
  each pattern comes from (vendors and which sides they serve, quests and the races they're for,
  creatures, objects and containers that drop it) and uses that before the built-in data. It's
  optional, like Auctionator; `/leprofit status` says whether it's found.
- Trainer costs players recorded (Efficient Games) fill in what the built-in data lacks: Mining's
  smelting, for one.
- `tools\update_data.cmd` (or `python3 tools/update_data.py`): refresh the built-in data on your
  own PC, asking before each step. It gets the latest, downloads Forever's newest game data and the
  players' data (only what changed since the last run), adds what leProfit recorded in your game,
  rebuilds, runs the tests, and can commit, push and install. Needs Python 3 and git.
- Opening a profession trainer records what it charges for each recipe it lists, and the skill
  each needs, for all your characters; those costs replace the built-in ones. The game data has no
  trainers, so this is how new recipes' costs get known.

### Changed

- The built-in data comes from Forever's own game data now: recipes, what they make and from
  what, recipe items and item names. Some pattern sellers and vendor prices come from Efficient
  Games' player-recorded data (CC BY 4.0). What neither has (trainer costs, most pattern sellers)
  is carried over from 1.0. So:
  - Mining's smelting is built in (18 recipes): its list works without opening the smelting window,
    and on characters without Mining.
  - Four more vendor patterns (Alchemy's Arcanite, Iron to Gold and Mithril to Truesilver
    transmutes, Cooking's Mithril Headed Trout), and more sellers for others.
  - Recipes that make a few at random (Engineering's dynamite and bombs) count the average made,
    as the profession window does, not the fewest.
  - Rogue poisons are no longer listed under Cooking.
- Renamed to **leProfit**: the folder, title, chat prefix, saved settings (`leProfitCharDB`,
  `leProfitDB`), frames, the Auctionator shopping list and the zips. Your settings and recorded
  vendor prices carry over from `LeprofitCharDB` and `LeprofitDB` at the first login. The
  install script removes an installed `Leprofit` folder first, since Windows would otherwise keep
  the old spelling; installing by hand, delete it yourself. `/leprofit` is unchanged. An old
  "Leprofit" list in Auctionator can be deleted.
- One addon: every profession's data is built into leProfit, so there are no separate
  `Leprofit_<Profession>` modules to install or tick. Coming from 1.0, delete the old
  `Leprofit_<Profession>` folders (they're ignored if left; the install script removes them). The
  profession dropdown lists all nine professions and starts on one the character has;
  `/leprofit status` lists this character's professions.

## [1.0.0] - 2026-11-19

Out of beta. Blacksmithing and Mining have been tried in game; the other professions work on any
character, and reports from players who have them are welcome.

### Added

- Licensed under the GNU GPLv3 (`LICENSE`); the repository is public, and the listing asks
  players with other professions to help test.
- Search on the Crafts tab: item, recipe and material names, as you type, in the profession
  shown or in all of them with the dropdown's new All professions.
- The install script explains a failed update when GitHub's history was rewritten, and prints
  the two commands that fix the copy.

## [0.9.0-beta] - 2026-11-18

The first release: a beta. Blacksmithing and Mining have been tried in game; the other
professions' lists work on any character, but reading their profession windows hasn't been tried
yet.

### Added

- **The Crafts tab** ranks the crafts that make gold: what the items sell for on the auction
  house after the cut (5%, a setting) and your undercut, less what the materials cost. Each
  material costs the cheaper of buying it and crafting it, in any of this character's
  professions (bars smelted for Blacksmithing, say).
  - Columns: Cost, Buyout and Profit; Avg 14d, Trend, Seen and Listed from Auctionator's price
    history are optional (Options). Click a heading to sort by it, again to reverse.
  - Rows are one line; hover for the detail under the item's tooltip: the sum, the price
    history, where to learn the recipe (trainer or pattern, its price, and where the seller
    stands, with their faction when they serve one) and how many crafts pay it back, and any
    warnings (a material with no price, binds on pickup, an old price).
  - Recipes you could learn now are listed greyed out; Show all adds those needing more skill;
    Hide unlearned lists only the ones you know. Crafts at a loss are hidden unless you tick
    Show losses.
  - Click a craft for its materials panel: need, have, buy, each and cost for the number of
    crafts you set, with where each price comes from; Add to list; Doesn't sell hides the item
    (after asking), and Options lists hidden items to unhide.
  - Shift-click a craft or a material to link it in chat or a search box.
  - A profession dropdown lists the modules ticked for this character.
- **The Shopping tab**: the crafts you planned and every material they need, combined, with
  what you hold counted once and the gold to spend; Send to Auctionator makes one "Leprofit"
  shopping list (vendor materials left out).
- **The Options tab**: which price profit is worked out from, the cut, the undercut, when to flag
  an old price, the optional columns, what the list leaves out, the buttons, and the hidden
  items. Settings are per character.
- **Nine profession modules**, ticked per character: Alchemy (200 recipes), Blacksmithing (506),
  Cooking (164), Enchanting (85 that make an item), Engineering (272), First Aid (41),
  Leatherworking (595), Mining (smelting, read from your window) and Tailoring (471), with
  trainer costs and pattern sellers built in.
- Opening Leprofit opens your profession window, so it reads the recipes you know; learning one
  at a trainer marks it known straight away. Vendors' material prices and patterns are recorded
  when you open them, and Auctionator's own vendor prices count too.
- `/leprofit` (with `why <item>` for the whole sum of one craft, `status`, `minimap`, `reset` and
  `help`), a minimap button, the addon menu entry, and a button on the profession window.
- For developers: the Windows install script, the release zip script, the module data generator,
  the art script, and tests with a fake client.
