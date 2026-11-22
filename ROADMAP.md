# Roadmap

What's done for leprofit, and what's next. Update it in the same commit as the
change.

## Done

- Standard docs (2026-11-16).
- Design agreed (2026-11-16, below).
- Data from the game (2026-11-22): recipes from Forever's game data tables,
  pattern sellers and vendor prices partly from Efficient Games' player data,
  the rest carried in `tools/learned.json`; Mining's smelting built in.
- One addon (2026-11-20): the nine profession modules merged into leProfit, after a
  load-on-demand version that was never released.
- 1.0.0 released (2026-11-19): out of beta, with search and All professions.
- 0.9.0-beta released (2026-11-18): the release kit (icon and banner art,
  LISTING.md, the zip and the v0.9.0-beta tag).
- 0.1.0 built (2026-11-16): the core with the Crafts and Options tabs and
  the Blacksmithing module, install/release/data tools and tests. Not yet
  tried in game (TESTING.md).
- The Shopping tab and Send to Auctionator (2026-11-16).
- The other seven modules (2026-11-16): Alchemy, Cooking, Enchanting,
  Engineering, First Aid, Leatherworking, Tailoring.
- Mining (smelting), read from your smelting window, and make-vs-buy across
  your professions: bars at their ore's price for Blacksmithing
  (2026-11-17). TESTING.md split into what a Blacksmith/Miner can check and
  what needs each other profession.
- Forever checks (2026-11-16):
  - The auction house cut isn't published and the game's AH API doesn't
    report it, so 5% stays a setting. The minimum deposit is 1 copper since
    the Nov 10 hotfix, so leaving the deposit out is fine.
  - Auctionator supports Forever (third-party guides). TSM doesn't seem to
    work on Forever (the owner, 2026-11-16), so the average comes from
    Auctionator's own price history instead.
  - CraftProfit Forever (vystery, all rights reserved, ~95k downloads) already
    puts profit tags in the profession window. leprofit differs with its own
    window, recipes you'd buy, and hiding what doesn't sell. Don't copy its
    code.

## Design (agreed 2026-11-16)

- **Profit per craft** = auction price x (1 - cut) - materials. The cut is 5%
  by default, undercut 0; both are settings. The deposit is left out.
- **Prices:** profit from the lowest buyout (a setting switches to market
  value); the list sorts by any column, Profit by default. Auctionator, then TSM. Optional columns
  from Auctionator's price history (internal, guarded): 14-day average (TSM's market value if
  installed), trend, days seen of 14, listed at the last scan. Vendor prices for materials.
- **Materials** cost the cheaper of buying and crafting them. Materials you
  own count at their market price; a second figure shows the gold you'd
  actually spend after what you hold.
- **Recipes:** the ones you know, and ones you could buy. Those show the
  pattern's price, where to buy it, and how many crafts pay it back.
- **Only crafts that make an item** (no enchants on gear).
- **Selling:** crafts at 0 or negative profit are hidden (a setting shows
  them). Items with no auction listing seen for some days are flagged, and
  you can mark an item as "doesn't sell" to hide it (after a confirmation;
  Options lists hidden items to unhide). Recipes you could learn now are
  listed greyed out; Show all adds those needing more skill; Hide unlearned
  lists only the known (the owner's pick, after trying a skill slider).
- **Recipe data:** built-in data, one file per profession, plus
  what you record playing. No in-game sharing, no share website. Since
  2026-11-22 it's generated from Forever's game data and Efficient Games'
  player data, with what neither has (trainer costs, most pattern sellers)
  in `tools/learned.json`.
- **One addon:** every profession's data built in (it was a core plus one
  addon per profession until 2026-11-20: the data is only 2.7 MB, so the
  modules weren't worth their trouble). The dropdown lists all nine, starting
  on one the character has.
- **Window:** its own window, in leboof's style (dark panel, gold border, flat
  tabs). Tabs: Crafts (ranked list; click a row for its materials, a craft
  count and Add to list), Shopping (planned crafts, combined materials
  bought as they are, Clear, Send to Auctionator as one "leProfit" list
  without vendor materials), Options. A search box on the Crafts tab
  matches item, recipe and material names; the dropdown's All professions
  lists every profession together.
- **Opening it:** `/leprofit`, a minimap button and the addon menu, and a
  button on the profession window. Opening it opens your profession window
  too, every time (the owner's pick), so your known recipes are read.
- **Settings** are per character.
- **Tools** as in leboof: an install script for the Windows PC, a release
  script that zips the addons, and tests that run here.

## Next

1. Fix what players report, especially from the professions only other characters have
   (TESTING.md).

## Ideas

- Record your own sales from the "Auction successful" mails: real sales, not listings.
- Count materials on your other characters.
- Profit lines in item tooltips.
