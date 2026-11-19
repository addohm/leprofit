# Changelog

All notable changes to leprofit. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

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
