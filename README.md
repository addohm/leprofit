# leprofit

A World of Warcraft: Forever addon for profit crafting. For each of your professions it lists the
crafts that make gold, most profitable first: what the items sell for on the auction house after
the cut, less what the materials cost. That includes recipes you'd have to learn first, with what
the trainer or pattern costs and how many crafts pay it back. It's for crafters who want to know
what's worth making and selling.

Leprofit is a core addon plus one module per profession. 0.1.0 has the core and Blacksmithing;
it hasn't been tried in game yet ([TESTING.md](TESTING.md)). Source:
[addohm/leprofit](https://github.com/addohm/leprofit).

## Getting started

1. Copy the `Leprofit` and `Leprofit_Blacksmithing` folders into
   `World of Warcraft\_forever_\Interface\AddOns\`, or run `tools\install_forever.cmd` from a clone
   ([DEPLOY.md](DEPLOY.md)).
2. In the AddOns list at character select, tick **Leprofit** and the profession modules this
   character has (**Leprofit - Blacksmithing**). Modules are ticked per character.
3. Install **Auctionator** (or TradeSkillMaster) and scan the auction house: auction prices come
   from their scans.
4. Open Leprofit: it opens your profession window too, and reads the recipes you know from it.

## Usage

Open the window with `/leprofit`, the minimap button (right-click for Options), the addon menu by
the minimap, or the coin button on the profession window, which opens it on that profession.
Opening Leprofit (or picking another profession in it) also opens your profession window, unless
it's already open, you don't have that profession, or you're in combat: Leprofit reads the recipes
you know from it. Recipes you learn at a trainer count as known straight away.

**Crafts tab**
- The arrows at the top pick the profession.
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
- Each row is one line; hover over it for the detail. Under the game's item tooltip, Leprofit adds
  the cost, what it sells for after the cut, the profit, the lowest buyout, Auctionator's history
  (14-day average, trend, days seen, how many listed), where to learn the recipe (trainer or
  pattern, its price, the skill it needs, and how many crafts pay it back), and anything to be wary
  of: a material with no price, an item that binds on pickup or that a vendor pays more for, an
  auction price several days old.
- Crafts at 0 or negative profit are hidden; tick **Show losses** to see them. Tick **Known only**
  to list just the recipes this character knows. The line above the materials panel says how many
  crafts were left out and why: you don't know them, at a loss, without a price (a material or the
  item has none), marked doesn't sell, or no known trainer or vendor.
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
  auction house) and crafting it with a recipe you know. Materials you already hold count at their
  price too: using one you could sell costs you that one. The materials panel shows the gold you'd
  actually spend on what you don't have.
- Leprofit records vendor prices for materials, and the patterns vendors sell, when you open a
  vendor. Auctionator's own record of vendor prices counts too.
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
  "Leprofit" shopping list from what's left to buy (exact names and how many), replacing the last
  one. Vendor materials are left out and named in chat. At the auction house, open Auctionator's
  Shopping tab and pick the list.

**Options tab** (saved per character)
- Profit from the lowest buyout or the 14-day average (where there's no average, the lowest buyout
  is used); the Avg 14d, Trend, Seen and Listed columns; the auction house cut; your undercut; how
  old an auction price is before it's flagged.
- Show only the recipes this character knows; crafts at a loss or without a price; and recipes
  nobody has recorded a trainer or vendor for (drops, quests, and recipes Forever lists but nobody
  can learn; hidden by default because there are hundreds).
- The minimap button and the profession window button.
- **Hidden items:** everything marked Doesn't sell, each with an **Unhide** button, and
  **Unhide all**. Defaults leaves them hidden.

**Commands**

| Command | What it does |
|---|---|
| `/leprofit` | Open or close the window |
| `/leprofit status` | Price sources, modules, and recipes known |
| `/leprofit why <item>` | The whole sum for one craft (name, part of it, or a shift-clicked link) |
| `/leprofit minimap` | Show or hide the minimap button |
| `/leprofit reset` | Put the window back in the middle at its normal size |
| `/leprofit help` | The commands and the build |

English game clients only, like the source addon: profession and pattern names are matched in English.

## Where the data comes from

Each module's recipes (what each makes and from what), trainer costs and pattern sellers come from
the source addon's shared data (the source addon), recorded by its
players and used with its author's permission. What your own profession window and vendors show
is added on top. Nothing is sent to other players.

## Development

- Tests: `python3 -m venv .venv && .venv/bin/pip install lupa` once, then
  `.venv/bin/python tests/run_tests.py`. They load the core and every module into a fake client
  (`tests/wowmock.lua`) and run `tests/smoke.lua`.
- Module data: `tools/gen_data.py` writes `Leprofit_<Profession>/Data.lua` from the source addon's
  `CommunityData.lua` (unzip the source addon into the repo first; it's git-ignored).
- Installing and releasing: [DEPLOY.md](DEPLOY.md).

## Docs

- [CHANGELOG.md](CHANGELOG.md): what changed in each version
- [DEPLOY.md](DEPLOY.md): how it's installed and released
- [TESTING.md](TESTING.md): what to check in game
- [SECURITY.md](SECURITY.md): secrets, access, reporting problems
- [ROADMAP.md](ROADMAP.md): what's done and what's next
- [CLAUDE.md](CLAUDE.md): notes for Claude working on it
