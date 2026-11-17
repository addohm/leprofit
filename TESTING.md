# Testing in game

What to check on WoW: Forever before a release. The automated tests (`tests/run_tests.py`) run the
sums and the window against a fake client; these need the real one. Tick each item off with the
build you tried (`/leprofit help` shows it).

The owner's characters so far are a Blacksmith and a Miner, so the list is split: what those can
check, and what waits for a character with each other profession. Nearly everything is shared code,
so most of it is covered by the first part.

## 0.1.0: on a Blacksmith or a Miner

**Install**
- [ ] `tools\install_forever.cmd` installs `Leprofit` and all nine `Leprofit_*` modules, stamps the
      build, and packs the zip on the desktop.
- [ ] They all show in the AddOns list; ticking only Leprofit gives "No profession modules are
      enabled" in the window.
- [ ] The profession dropdown lists only the modules ticked for this character, with their icons;
      the one shown is ticked, and it follows the profession window's button.

**Blacksmithing** (on the Blacksmith, Leprofit - Blacksmithing ticked)
- [ ] Opening Leprofit opens your Blacksmithing window (not when it's already open, or in combat);
      `/leprofit status` then says how many recipes you know.
- [ ] Learning a recipe at the trainer lists it as known without opening the profession window.
- [ ] A material you can craft cheaper than buy (a sharpening or grinding stone) shows
      "(craft it)" in the materials panel.

**Mining** (Leprofit - Mining ticked)
- [ ] On the Miner, opening Leprofit (or picking Mining in the dropdown) opens the smelting window; `/leprofit status`
      then counts the smelting recipes you know, and Mining's Crafts list shows bars against ore.
- [ ] On a character with both (Mining and Blacksmithing ticked): Blacksmithing's materials panel
      shows "(craft it)" on bars that are cheaper to smelt, and `/leprofit why` says
      "crafted with Smelt ... (Mining)". If the Blacksmith and the Miner are different characters,
      Blacksmithing buys its bars.

**Other professions' lists** (tick, say, Leprofit - Tailoring on the Blacksmith)
- [ ] Without the profession, its list still shows what you could learn (trainer and pattern
      costs, payback), with prices, tooltips, Shopping and `/leprofit why`, all with Show all ticked;
      without it the empty list explains that this character doesn't have the profession. Opening Leprofit on it doesn't try to open a window.
- [ ] Enchanting lists rods, oils and wands, no enchants.

**Prices**
- [ ] With Auctionator and a scan, the Crafts tab lists crafts with profit and lowest buyout.
- [ ] A craft's profit matches by hand: lowest buyout x 0.95, less the materials (check one).
- [ ] Options > Auction history columns: Avg 14d, Trend, Seen and Listed each turn on and off;
      after a few days of Auctionator scans they fill in (Seen like 3/14, Listed a count, Trend an
      arrow or =); the item names make room; each heading sorts.
- [ ] Profit from > 14-day average changes the profit where there's history.
- [ ] A recipe you don't know shows its trainer cost or pattern, and "pays back in N crafts".
- [ ] A pattern names its seller with subzone, zone and coordinates (check one against the map),
      and "(Alliance only)"/"(Horde only)" for a faction's vendor; buying a pattern at a vendor
      records that vendor's place and faction.
- [ ] Opening a vendor that sells a material (Weak Flux, Coal...) prints "recorded N material
      prices"; a pattern vendor prints "recorded Plans: ...".
- [ ] `/leprofit why <item>` by name, part of a name, and a shift-clicked link; the sum matches the
      list.
- [ ] The materials panel's Each column and (auction)/(vendor)/(craft it)/(no price) tags.
- [ ] "Not listed" counts losses and "without a price" apart.

**The Crafts list**
- [ ] Columns read Cost, Buyout, Profit (the history columns before Profit when on); Cost matches
      the materials panel's total for one craft; each heading's tooltip explains it.
- [ ] Clicking a heading sorts by it, again reverses it; the arrow follows; unpriced crafts stay
      last; the order is still there after /reload. Options says "Profit from", not "Rank by".
- [ ] Rows (one line each) and the materials panel fit at the normal size; resizing works; Escape
      closes.
- [ ] Hovering a row: the item's tooltip, then Leprofit's lines (cost, sells for, profit, buyout,
      history, where to learn it, warnings in orange).
- [ ] Shift-click a row and a material with the chat box open, then with the auction house (or
      Auctionator) search box focused: the link goes in. Ctrl-click opens the dressing room.
- [ ] Hovering a material shows its tooltip.
- [ ] Show losses and the Crafts box behave.
- [ ] Recipes you haven't learned but have the skill for are listed greyed out (grey name and
      icon, faded numbers), their tooltip starting "Not learned yet"; Show all adds those needing
      more skill; Hide unlearned leaves only the known ones and greys out Show all; the "Not
      listed" line counts what's left out.
- [ ] The top bar fits at the normal size and at the narrowest the window goes.
- [ ] Doesn't sell asks first, over a dimmed window: Cancel and Escape hide nothing, Hide hides it.
- [ ] Options > Hidden items lists it; Unhide and Unhide all bring items back.

**Shopping**
- [ ] Add to list adds the Crafts box's count; again adds more; the chat line says how many.
- [ ] The Shopping tab: planned crafts with counts (typing a new one, 0 removes), Remove; the
      materials combined with what you hold counted once; (vendor) and (no price) tags; the total.
- [ ] Clear asks first. Send to Auctionator makes the "Leprofit" list in Auctionator's Shopping tab
      with the right quantities, replaces it when sent again, and names the vendor materials in chat.

**The rest of the window**
- [ ] Options: each setting changes the list; Defaults puts them back; they're per character.
- [ ] The coin button on the profession window sits left of its close button and opens Leprofit on
      that profession; the option hides it.
- [ ] The minimap button: left-click Crafts, right-click Options, drag to move; the addon menu
      entry works.
- [ ] No Lua errors (`/console scriptErrors 1`).

## 0.1.0: needs a character with the profession

For each of Alchemy, Cooking, Enchanting, Engineering, First Aid, Leatherworking and Tailoring, on a
character that has it, with its module ticked:
- [ ] Opening Leprofit opens that profession's window; `/leprofit status` counts its known recipes;
      Hide unlearned lists them.
- [ ] Recipes that make several (Engineering's ammo, some Cooking) show x2 and so on, and their
      profit counts every item.
- [ ] Learning a recipe at its trainer lists it as known straight away.
