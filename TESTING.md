# Testing in game

What to check on WoW: Forever before a release. The automated tests (`tests/run_tests.py`) run the
sums and the window against a fake client; these need the real one. Tick each item off with the
build you tried (`/leprofit help` shows it).

## 0.1.0

**Install**
- [ ] `tools\install_forever.cmd` installs `Leprofit` and `Leprofit_Blacksmithing`, stamps the
      build, and packs the zip on the desktop.
- [ ] Both show in the AddOns list; ticking only Leprofit gives "No profession modules are
      enabled" in the window.

**Recipes and prices**
- [ ] Opening the Blacksmithing window, then `/leprofit status`, says how many recipes you know.
- [ ] With Auctionator and a scan, the Crafts tab lists crafts with profit and lowest buyout.
- [ ] A craft's profit matches by hand: lowest buyout x 0.95, less the materials (check one).
- [ ] Options > Auction history columns: Avg 14d, Trend, Seen and Listed each turn on and off;
      after a few days of Auctionator scans they fill in (Seen like 3/14, Listed a count, Trend an
      arrow or =); the item names make room; each heading sorts.
- [ ] Profit from > 14-day average changes the profit where there's history.
- [ ] A recipe you don't know shows its trainer cost or pattern, and "pays back in N crafts".
- [ ] Opening a vendor that sells a material (Weak Flux, Coal...) prints "recorded N material
      prices"; a pattern vendor prints "recorded Plans: ...".
- [ ] A material you can craft cheaper than buy (a sharpening or grinding stone) shows
      "(craft it)" in the materials panel.
- [ ] Opening Leprofit opens your Blacksmithing window (not when it's already open, or in
      combat); switching profession with the arrows opens that one.
- [ ] Learning a recipe at the trainer lists it as known without opening the profession window.
- [ ] `/leprofit why <item>` by name, part of a name, and a shift-clicked link; the sum matches the
      list.
- [ ] The materials panel's Each column and (auction)/(vendor)/(craft it)/(no price) tags.
- [ ] "Not listed" counts losses and "without a price" apart.
- [ ] Columns read Cost, Buyout, Profit (Market before Profit when on); Cost matches the materials
      panel's total for one craft; each heading's tooltip explains it.
- [ ] Clicking a heading sorts by it, again reverses it; the arrow follows; unpriced crafts stay
      last; the order is still there after /reload. Options says "Profit from", not "Rank by".
- [ ] Shift-click a row and a material with the chat box open, then with the auction house (or
      Auctionator) search box focused: the link goes in. Ctrl-click opens the dressing room.
- [ ] Hovering a material shows its tooltip.

**Shopping**
- [ ] Add to list adds the Crafts box's count; again adds more; the chat line says how many.
- [ ] The Shopping tab: planned crafts with counts (typing a new one, 0 removes), Remove; the
      materials combined with what you hold counted once; (vendor) and (no price) tags; the total.
- [ ] Clear asks first. Send to Auctionator makes the "Leprofit" list in Auctionator's Shopping tab
      with the right quantities, replaces it when sent again, and names the vendor materials in chat.

**The window**
- [ ] Rows (one line each) and the materials panel fit at the normal size; resizing works; Escape
      closes.
- [ ] Hovering a row: the item's tooltip, then Leprofit's lines (cost, sells for, profit, buyout,
      history, where to learn it, warnings in orange).
- [ ] Show losses, Known only and the Crafts box behave.
- [ ] Doesn't sell asks first, over a dimmed window: Cancel and Escape hide nothing, Hide hides it.
- [ ] Options > Hidden items lists it; Unhide and Unhide all bring items back.
- [ ] Options: each setting changes the list; Defaults puts them back; they're per character.
- [ ] The coin button on the profession window sits left of its close button and opens Leprofit on
      that profession; the option hides it.
- [ ] The minimap button: left-click Crafts, right-click Options, drag to move; the addon menu
      entry works.
- [ ] No Lua errors (`/console scriptErrors 1`).
