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
- [ ] With TSM, the Market column fills in, and Options > Rank by > Market value changes profit.
- [ ] A recipe you don't know shows its trainer cost or pattern, and "pays back in N crafts".
- [ ] Opening a vendor that sells a material (Weak Flux, Coal...) prints "recorded N material
      prices"; a pattern vendor prints "recorded Plans: ...".
- [ ] A material you can craft cheaper than buy (a sharpening or grinding stone) shows
      "(craft it)" in the materials panel.

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
