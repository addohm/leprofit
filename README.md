# leprofit

A World of Warcraft: Forever addon for profit crafting. For each of your professions it lists the
crafts that make gold, most profitable first: what the items sell for on the auction house after
the cut, less what the materials cost. That includes recipes you'd have to learn first, with what
the trainer or pattern costs and how many crafts pay it back. It's for crafters who want to know
what's worth making and selling.

leProfit is one addon covering every crafting profession: Alchemy, Blacksmithing, Cooking,
Enchanting, Engineering, First Aid, Leatherworking, Mining (smelting) and Tailoring. 1.1.0 is the current release;
[TESTING.md](TESTING.md) is what's left to check in game. Source:
[addohm/leprofit](https://github.com/addohm/leprofit).

## Getting started

1. Copy the `leProfit` folder into `World of Warcraft\_forever_\Interface\AddOns\`, or run
   `tools\install_forever.cmd` from a clone ([DEPLOY.md](DEPLOY.md)). Coming from 1.0, when it
   was called Leprofit? Delete its `Leprofit` folder first (Windows would keep the old name), and
   its separate `Leprofit_<Profession>` folders: they're built in now (and ignored if left). Your
   settings carry over.
2. Install **Auctionator** (or TradeSkillMaster) and scan the auction house: auction prices come
   from their scans.
3. Optional: **QuestieDB** (Questie installs it on Forever). With it, tooltips say where every
   pattern comes from, and which side can get it, from its database.
4. Open leProfit. It knows which recipes each character knows from the game itself.

## Usage

Open the window with `/leprofit`, the minimap button (right-click for Options), the addon menu by
the minimap.
leProfit doesn't need your profession window: which recipes a character knows comes from the game
itself, for every profession, and a recipe you learn counts as known straight away. When you do
open the profession window, leProfit reads it quietly too, for the few recipes the built-in data
lacks.

**Crafts tab**
- The dropdown at the top picks the profession: every crafting profession is there, so you can
  look at one this character hasn't got to see what it could make. It starts on one this
  character has. **All professions** lists them all together (each row's tooltip names its
  profession).
- The **search** box filters the list as you type: it matches the item's name, the recipe's name
  and the names of its materials, so "copper bar" finds every craft that uses Copper Bars. It
  searches the profession shown, or all of them with All professions picked. Escape or the x
  clears it, and closing the window does too. The other filters still apply, and the "Not listed"
  line counts what didn't match.
- Each row is a craft: the item, then **Cost** (the materials for one craft), **Buyout** (the lowest
  buyout for one item) and **Profit** (per craft, after the cut). A recipe that makes several (x3
  after its name) sells them all, so its Cost and Buyout don't add up to its Profit. Hover over a
  heading for what it means.
- Four more columns come from Auctionator's price history (the days you scanned; it keeps 21 by
  default). Each is turned on in Options:
  - **Avg 14d:** each day's lowest price averaged over 14 days, steadier than the lowest buyout
    (TSM's market value instead, if TSM is installed).
  - **Trend:** an arrow up or down, or = when level: the last 3 days' prices against the 4 before.
  - **Seen:** on how many of the last 14 days it was listed, e.g. 9/14. Days you didn't scan don't
    count.
  - **Listed:** how many were up at your last scan: your competition.
  They show what was listed, not what sold. The history isn't part of Auctionator's official
  interface, so if an Auctionator update changes it, these columns just show "-".
- Click a heading to sort the list by it, and again to reverse the order; an arrow marks the one
  sorting. Profit, highest first, is the default. Crafts without a value in that column go last.
  The order is saved per character.
- Shift-click a row to put the item's link in chat or a search box (the auction house's, or
  Auctionator's); ctrl-click shows it in the dressing room.
- Each row is one line; hover over it for the detail. Under the game's item tooltip, leProfit adds
  the cost, what it sells for after the cut, the profit, the lowest buyout, Auctionator's history
  (14-day average, trend, days seen, how many listed), where to learn the recipe (trainer or
  pattern, its price, the skill it needs, and how many crafts pay it back), and anything to be wary
  of: a material with no price, an item that binds on pickup or that a vendor pays more for, an
  auction price several days old.
- Crafts at 0 or negative profit are hidden; tick **Show losses** to see them.
- The list shows the recipes you know, and **greyed out** the trainer and pattern recipes you could
  learn now (your skill is enough). Hover over a greyed one for what learning it costs and how many
  crafts pay that back: is it worth learning? A pattern names its seller and where they stand,
  e.g. "from Vayn Moongaze in Nightclaw Cavern, Zephras Isle at 63.8, 36.0", with "(Alliance
  only)" or "(Horde only)" when the vendor serves one faction. **Show all** adds the ones needing more skill than
  you have, greyed too. **Hide unlearned** leaves only the recipes you know.
- Recipes learned from a pattern no vendor sells (a world drop, say) are listed too when the
  pattern can be traded: learning one costs the pattern's price at the auction house, from your
  Auctionator scans ("no auction price yet" until a scan has seen it). Patterns that bind when
  picked up (raid and dungeon drops, quest and reputation rewards, token vendors) can't be
  bought: **Show all** lists those recipes too. A profession's starter recipes "come with the
  profession".
- A pattern's tooltip says where to get it: the reputation it needs, who sells it (for gold or
  tokens, with where they stand), the quests that reward it, and what drops it. With QuestieDB
  installed, leProfit asks it, in game, for each pattern, as it asks Auctionator for prices;
  without it, or for an item QuestieDB doesn't know, the built-in data answers (with how often
  players saw a drop, as a percentage once enough loot is recorded).
- Recipes only the other side can get are never listed: a one-side reputation, quests only for
  the other side, or a pattern only the other side's vendors sell. A vendor's side comes from
  QuestieDB, or from Efficient Games' or your own record of it; a vendor nobody has recorded
  counts for both sides. The trade camps' Merchant's Favor plans count for both (each side's camp
  sells them).
- The line above the materials panel says how many crafts were left out and why: not learned (with
  Hide unlearned), needing more skill, at a loss, without a price (a material or the item has none), marked doesn't sell, from
  patterns that bind, with no known source (Show all lists those two), or only for the other side. Where prices come from is at its right.
- Click a row for its materials panel: what it sells for and the profit, where to learn it, and each
  material's need, what you hold, what to buy, its price for one (**Each**) and its cost for the
  number of **Crafts** you set. After each name, where its price is from: auction, vendor, craft it,
  or no price. Hover over a material for its tooltip; shift-click it to link it, for example into
  the auction house search.
  **Doesn't sell** hides the item from the list, after asking; Options lists the hidden items, where
  you can unhide them. **Add to list** puts that many crafts on the Shopping tab (again adds more).

**How profit is worked out**
- An item sells for the lowest buyout (or the 14-day average, see Options) less your undercut, less
  the auction house cut (5% by default). The deposit is left out: it's 1 copper at least, and it
  comes back when the item sells. If a vendor pays more, or the item binds on pickup, the vendor's
  price is used.
- Each material costs the cheaper of buying it (a vendor's price if one is recorded, else the
  auction house) and crafting it with a recipe you know, in any of this character's professions: a Blacksmith who also mines gets bars at their ore's price when smelting is
  cheaper. Materials you already hold count at their
  price too: using one you could sell costs you that one. The materials panel shows the gold you'd
  actually spend on what you don't have.
- leProfit records vendor prices for materials, and the patterns vendors sell, when you open a
  vendor. Auctionator's own record of vendor prices counts too. Opening a profession trainer
  records what it charges for each recipe and the skill it needs; that cost replaces the built-in
  one for all your characters.
- `/leprofit why <item>` prints the whole sum for one craft in chat: each material, its price and
  where it's from, the buyout, 14-day average and vendor price, Auctionator's history (days seen,
  how many listed, the trend), the cut, the profit, and where to learn it. Type the name (or part of it), or shift-click the item.

**Shopping tab** (saved per character)
- The crafts you've planned, each with its count (type a new one and press Enter; 0 removes it) and
  **Remove**.
- Every material they need, combined: need, what you hold (counted once across the list), what to
  buy, the price of one and the cost. Materials are bought as they are, not crafted first. Vendor
  materials are tagged (vendor); ones with no price, (no price).
- The gold to spend, **Clear** (after asking), and **Send to Auctionator**: it makes Auctionator's
  "leProfit" shopping list from what's left to buy (exact names and how many), replacing the last
  one. Vendor materials are left out and named in chat. At the auction house, open Auctionator's
  Shopping tab and pick the list.

**Options tab** (saved per character)
- Profit from the lowest buyout or the 14-day average (where there's no average, the lowest buyout
  is used); the Avg 14d, Trend, Seen and Listed columns; the auction house cut; your undercut; how
  old an auction price is before it's flagged.
- Hide unlearned and Show all, as on the Crafts tab; show crafts at a loss or without a price; and
  recipes from patterns that bind, or with no known source (hidden by default because there are
  hundreds).
- The minimap button.
- **Hidden items:** everything marked Doesn't sell, each with an **Unhide** button, and
  **Unhide all**. Defaults leaves them hidden.

**Commands**

| Command | What it does |
|---|---|
| `/leprofit` | Open or close the window |
| `/leprofit status` | Price sources, and this character's professions and recipes known |
| `/leprofit why <item>` | The whole sum for one craft (name, part of it, or a shift-clicked link) |
| `/leprofit minimap` | Show or hide the minimap button |
| `/leprofit reset` | Put the window back in the middle at its normal size |
| `/leprofit help` | The commands and the build |

Enchanting lists only what makes an item (rods, oils, wands): enchants on gear can't be posted.
Mining lists its smelting, each bar against its ore. A
few of Forever's camp and home items (Camp Chair, Fishing Hut...) are listed by several
professions' windows, so they show under each.

English game clients only: profession and pattern names are matched in English.

## Where the data comes from

Every profession's recipes (what each makes and from what), trainer costs and pattern sellers
are built in. What your own profession window, trainers and vendors show is added on top. Nothing
is sent to other players.

The recipes, recipe items, item names, reputation requirements and factions come from Forever's
own game data (its DB2 tables, via [wago.tools](https://wago.tools)). Pattern sellers, vendor
prices, trainer costs, drops and quest rewards come partly from
[Efficient Games](https://efficient.games)' player-recorded data, licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The rest (most trainer costs and pattern
sellers, from 1.0's data) is kept in `tools/learned.json`, which grows with what leProfit records.

### Updating the data yourself

After a Forever patch adds recipes, or after you've visited trainers and vendors, refresh the
built-in data on your own PC: double-click `tools\update_data.cmd` in a clone (or run
`python3 tools/update_data.py`). It needs [Python 3](https://www.python.org/downloads/) and git,
and asks before each change. It:

1. gets the latest leProfit from GitHub;
2. downloads Forever's newest game data and the players' data (about 70 MB the first time, then
   only what changed);
3. adds what leProfit recorded in your game (trainer costs, patterns and their sellers, vendor
   prices: the game saves them when you log out or `/reload`) to `tools/learned.json`;
4. rebuilds `leProfit/Data/` and lists what's new;
5. runs the tests (it can set up the one thing they need);
6. commits and pushes, if you say so, and installs it into the game.

## Development

- Tests: `python3 -m venv .venv && .venv/bin/pip install lupa` once, then
  `.venv/bin/python tests/run_tests.py`. They load the addon into a fake client
  (`tests/wowmock.lua`) and run `tests/smoke.lua`.
- Profession data: `tools/update_data.py` does it all, asking first (above). Underneath,
  `tools/fetch_sources.py` downloads the game data and player data into the git-ignored
  `.source/`, and `tools/gen_data.py` writes `leProfit/Data/<Profession>.lua` from them and
  `tools/learned.json` (Python 3, nothing to install; [DEPLOY.md](DEPLOY.md)).
- Installing and releasing: [DEPLOY.md](DEPLOY.md).

## Problems, ideas and testing

Bug reports and test reports are welcome on the
[issues page](https://github.com/addohm/leprofit/issues), especially from players with the
professions that haven't been tried in game yet (all but Blacksmithing and Mining): say what you
did and what you expected, and paste `/leprofit why <item>` and `/leprofit help` (the version).
[TESTING.md](TESTING.md) lists what to check. Security problems: see [SECURITY.md](SECURITY.md).

## License

GNU General Public License v3.0: see [LICENSE](LICENSE).

## Docs

- [CHANGELOG.md](CHANGELOG.md): what changed in each version
- [LISTING.md](LISTING.md): the CurseForge and Wago page text, images and release notes
- [DEPLOY.md](DEPLOY.md): how it's installed and released
- [TESTING.md](TESTING.md): what to check in game
- [SECURITY.md](SECURITY.md): secrets, access, reporting problems
- [ROADMAP.md](ROADMAP.md): what's done and what's next
- [CLAUDE.md](CLAUDE.md): notes for Claude working on it
