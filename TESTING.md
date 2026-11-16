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
- [ ] The Market column is off; Options > Show the Market column turns it on (shows "-" without
      TSM), and Profit and Buyout move back to make room.
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
      panel's total for one craft; the headings' tooltip explains them.
- [ ] Shift-click a row and a material with the chat box open, then with the auction house (or
      Auctionator) search box focused: the link goes in. Ctrl-click opens the dressing room.
- [ ] Hovering a material shows its tooltip.

**The window**
- [ ] Rows, notes and the materials panel fit at the normal size; resizing works; Escape closes.
- [ ] Show losses, Known only and the Crafts box behave.
- [ ] Doesn't sell asks first, over a dimmed window: Cancel and Escape hide nothing, Hide hides it.
- [ ] Options > Hidden items lists it; Unhide and Unhide all bring items back.
- [ ] Options: each setting changes the list; Defaults puts them back; they're per character.
- [ ] The coin button on the profession window sits left of its close button and opens Leprofit on
      that profession; the option hides it.
- [ ] The minimap button: left-click Crafts, right-click Options, drag to move; the addon menu
      entry works.
- [ ] No Lua errors (`/console scriptErrors 1`).
