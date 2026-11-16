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
4. Open your profession window once on each character, so Leprofit reads the recipes you know.

## Usage

Open the window with `/leprofit`, the minimap button (right-click for Options), the addon menu by
the minimap, or the coin button on the profession window, which opens it on that profession.

**Crafts tab**
- The arrows at the top pick the profession.
- Each row is a craft: the item, its profit per craft, the lowest buyout and the market value (TSM
  only).
- The grey line under a row says where to learn the recipe (trainer or pattern, its price, and the
  skill it needs), how many crafts pay that back, and anything to be wary of: a material with no
  price, an item that binds on pickup or that a vendor pays more for, an auction price several days
  old.
- Crafts at 0 or negative profit are hidden; tick **Show losses** to see them. Tick **Known only**
  to list just the recipes this character knows. The line above the materials panel says how many
  crafts were left out and why.
- Click a row for its materials panel: what it sells for and the profit, where to learn it, and each
  material's need, what you hold, what to buy and its cost for the number of **Crafts** you set.
  **Doesn't sell** hides the item from the list, after asking; Options lists the hidden items, where
  you can unhide them.

**How profit is worked out**
- An item sells for the lowest buyout (or the market value, see Options) less your undercut, less
  the auction house cut (5% by default). The deposit is left out: it's 1 copper at least, and it
  comes back when the item sells. If a vendor pays more, or the item binds on pickup, the vendor's
  price is used.
- Each material costs the cheaper of buying it (a vendor's price if one is recorded, else the
  auction house) and crafting it with a recipe you know. Materials you already hold count at their
  price too: using one you could sell costs you that one. The materials panel shows the gold you'd
  actually spend on what you don't have.
- Leprofit records vendor prices for materials, and the patterns vendors sell, when you open a
  vendor.

**Options tab** (saved per character)
- Rank by lowest buyout or market value; the auction house cut; your undercut; how old an auction
  price is before it's flagged.
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
