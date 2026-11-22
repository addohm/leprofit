# Testing in game

What to check on WoW: Forever before a release. The automated tests (`tests/run_tests.py`) run the
sums and the window against a fake client; these need the real one. Tick each item off with the
build you tried (`/leprofit help` shows it).

The owner's characters so far are a Blacksmith and a Miner, so the list is split: what those can
check, and what waits for a character with each other profession. Nearly everything is shared code,
so most of it is covered by the first part.

## 1.1.0: on a Blacksmith or a Miner

**Install**
- [ ] The release zip unzips into AddOns as one `leProfit` folder, and the AddOns list shows its
      coin-and-arrow icon.
- [ ] `tools\install_forever.cmd` installs `leProfit`, deletes old `Leprofit_<Profession>` folders
      (saying so), stamps the build, and packs the zip on the desktop.
- [ ] After a history rewrite on GitHub, the install script says the histories differ and prints
      the fetch and reset commands; after running them, it installs.
- [ ] Over a Leprofit install (1.0 or earlier builds): the install script removes the `Leprofit`
      folder (saying so) and installs `leProfit` (the first run after pulling still uses the old
      script, so run it twice); the AddOns list and the window read leProfit; settings, hidden
      items, the shopping list and recorded vendor prices are all still there.
- [ ] With old `Leprofit_<Profession>` folders still installed (a hand update), no Lua errors:
      they're ignored.
- [ ] `/leprofit status` lists this character's professions in full and names the rest as built in;
      the window opens on one of this character's professions.
- [ ] The search box (with its grey hint and x): typing filters as you go, by item, recipe and
      material names; Escape and the x clear it; closing the window clears it; with All
      professions picked it searches every profession, and a row's tooltip names its
      profession.
- [ ] The profession dropdown lists all nine professions, with icons;
      the one shown is ticked, and it follows the profession window's button.

**Updating the data** (on the Windows PC)
- [ ] Double-clicking `tools\update_data.cmd` finds Python (or says where to get it), shows the
      status in colour, and quits on Enter at the menu.
- [ ] Update everything: it pulls, downloads, suggests the install script's WoW folder, reads
      your accounts' `leProfit.lua` (after a logout), lists what's new, offers to set up the
      tests and runs them, then commits, pushes and installs when you say yes; the next run
      remembers the folder.
- [ ] After visiting a trainer and logging out, a run lists its recipes as "new trainer costs".

**Blacksmithing** (on the Blacksmith)
- [ ] Opening leProfit (and picking a profession in its dropdown) doesn't open the profession
      window; Blacksmithing's known recipes are right anyway (not greyed), and `/leprofit status`
      counts them, without the profession window opened since login.
- [ ] Learning a recipe at the trainer lists it as known without opening the profession window.
- [ ] A material you can craft cheaper than buy (a sharpening or grinding stone) shows
      "(craft it)" in the materials panel.

**Mining**
- [ ] On a character without Mining, Mining's list shows the smelting recipes, with Show all and
      Options > "Show recipes from patterns that bind, or with no known source" ticked (smelting's
      trainer costs aren't known yet).
- [ ] On the Miner, `/leprofit status` counts the smelting recipes you know without the smelting
      window opened, and Mining's Crafts list shows bars against ore.
- [ ] On a character with both Mining and Blacksmithing: Blacksmithing's materials panel
      shows "(craft it)" on bars that are cheaper to smelt, and `/leprofit why` says
      "crafted with Smelt ... (Mining)". If the Blacksmith and the Miner are different characters,
      Blacksmithing buys its bars.

**Other professions' lists** (pick, say, Tailoring in the dropdown on the Blacksmith)
- [ ] Without the profession, its list still shows what you could learn (trainer and pattern
      costs, payback), with prices, tooltips, Shopping and `/leprofit why`, all with Show all ticked;
      without it the empty list explains that this character doesn't have the profession. Opening leProfit on it doesn't try to open a window.
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
- [ ] Opening a profession trainer (and a Mining trainer, for smelting) prints "recorded N trainer
      costs" the first time, nothing the next; an unlearned recipe's tooltip then shows that
      trainer's cost and skill, on your other characters too.
- [ ] `/leprofit why <item>` by name, part of a name, and a shift-clicked link; the sum matches the
      list.
- [ ] The materials panel's Each column and (auction)/(vendor)/(craft it)/(no price) tags.
- [ ] "Not listed" counts losses and "without a price" apart, and "from patterns that bind" apart
      from "with no known source" (only a handful).
- [ ] A recipe from a world-drop pattern (Golden Scale Shoulders): its tooltip says
      "Plans: ... at the auction house" with the price after an Auctionator scan has seen the
      plans ("no auction price yet" before), the payback, and "Drops from ..."; `/leprofit why`
      says the same.
- [ ] Bloodsoul Breastplate (plans that bind) is left out, and listed with Show all, its tooltip
      saying "Needs Zandalar Tribe reputation: Revered"; Veteran's Boots names Gor'mak and "30
      Merchant's Favor"; a starter recipe (Copper Rod) says "Comes with the profession".
- [ ] On an Alliance character, Cloudy Skyforged plans (Earthen Ring) and Engineering's Red
      Firework (sold only in Orgrimmar) never show, even with Show all, and "Not listed" counts
      them as "only the other side can get"; on a Horde one, Azure Skyforged (Kirin Tor) don't.
- [ ] With Questie (and so QuestieDB) installed: `/leprofit status` says "QuestieDB found"; a
      pattern's tooltip lists QuestieDB's vendors with places ("Sold by Kania in Silithus at ..."),
      quests, and drops ("Drops from 40 creatures (a world drop), such as ..."); Red Firework
      stays hidden on the Alliance; no Lua errors. Without it, status says it isn't installed and
      tooltips use the built-in lines.
- [ ] Veteran's Boots shows for both sides; on the Alliance its tooltip adds "Also sold at the
      Alliance trade camp (not recorded yet)". Wizard Oil (Kania, Cenarion Hold) shows for both.

**The Crafts list**
- [ ] Columns read Cost, Buyout, Profit (the history columns before Profit when on); Cost matches
      the materials panel's total for one craft; each heading's tooltip explains it.
- [ ] Clicking a heading sorts by it, again reverses it; the arrow follows; unpriced crafts stay
      last; the order is still there after /reload. Options says "Profit from", not "Rank by".
- [ ] Rows (one line each) and the materials panel fit at the normal size; resizing works; Escape
      closes.
- [ ] Hovering a row: the item's tooltip, then leProfit's lines (cost, sells for, profit, buyout,
      history, where to learn it, warnings in orange).
- [ ] Shift-click a row and a material with the chat box open, then with the auction house (or
      Auctionator) search box focused: the link goes in. Ctrl-click opens the dressing room.
- [ ] Hovering a material shows its tooltip.
- [ ] Hide losses is off at first: crafts at a loss are listed with their profit in red, and
      unpriced ones last; ticking it leaves both out and "Not listed" counts them. The Crafts box
      behaves.
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
- [ ] Clear asks first. Send to Auctionator makes the "leProfit" list in Auctionator's Shopping tab
      with the right quantities, replaces it when sent again, and names the vendor materials in chat.

**The rest of the window**
- [ ] Options: each setting changes the list; Defaults puts them back; they're per character.
- [ ] The minimap button: left-click Crafts, right-click Options, drag to move; the addon menu
      entry works.
- [ ] No Lua errors (`/console scriptErrors 1`).

## 1.1.0: needs a character with the profession

For each of Alchemy, Cooking, Enchanting, Engineering, First Aid, Leatherworking and Tailoring, on a
character that has it:
- [ ] Without opening that profession's window, `/leprofit status` counts its known recipes and
      Hide unlearned lists them.
- [ ] Recipes that make several (Engineering's ammo, some Cooking) show x2 and so on, and their
      profit counts every item.
- [ ] Learning a recipe at its trainer lists it as known straight away.
