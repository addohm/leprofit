# leProfit: CurseForge and Wago listing

Copy-paste material for the project pages: it's published on both CurseForge and Wago. Keep the
feature list in step with README.md.

---

## Basics

| Field | Value |
| --- | --- |
| Name | leProfit |
| Slug | `leprofit` |
| Game version | WoW: Forever (Interface 16001) |
| Author | addohm |
| Release type | Release (1.3.0) |
| License | GNU GPLv3 (`LICENSE`) |
| Source | https://github.com/addohm/leprofit |
| Issues | https://github.com/addohm/leprofit/issues |
| Upload | `release/leProfit-<version>.zip` (one `leProfit` folder) |

**Images**
- Avatar: `art/leprofit-icon-400.png`
- Banner / header: `art/leprofit-banner.png` (1600x500)

**Categories**
- CurseForge: Professions (main), Auction & Economy
- Wago: Professions (main), Auction & Economy

**Summary** (the one-liner under the name; 158 characters)

> Which crafts make gold: auction price after the cut, less the materials, most profitable first,
> with what to buy and where to learn each recipe. WoW: Forever.

**Short tagline** (for images or a Discord post)

> Which crafts make gold, most profitable first.

---

## Description

*(Paste as Markdown. Both sites accept it.)*

### leProfit

**Which crafts make gold, most profitable first. Built for WoW: Forever.**

leProfit lists every craft in your professions with what it costs to make, what it sells for,
and the profit: the auction price after the house's cut, less the materials. Each material costs
whichever is cheaper, buying it or crafting it yourself. Recipes you could learn now are listed
too, greyed out, with what learning them costs and how many crafts pay that back.

#### The Crafts list

- **Cost, Buyout and Profit** for every craft, most profitable first. Click any heading to sort
  by it.
- **Hover a row** for the whole story: the sum, the price history, where to learn the recipe
  (the trainer's cost, or the pattern's price and **where its seller stands**, with coordinates
  and their faction), how many crafts pay it back, and anything to watch out for: a material
  with no price, an item that binds on pickup, an auction price days old.
- **Recipes you haven't learned** but have the skill for are greyed out, recipes from world-drop
  patterns included, priced at the auction house from your scans. **Show all** lists everything
  you could get: more skill, patterns that bind, and the rest. Hide unlearned keeps only what you
  know. The other faction's recipes are never listed.
- **Click a craft** for its materials: what you need, what you hold, what to buy and what it
  costs, for as many crafts as you like. Hide items that never sell (it asks first).
- **Price history** from your Auctionator scans, as optional columns: a 14-day average, the
  trend (up, down or level), how many days it was listed, and how many are up now.
- **Search** item, recipe and material names as you type ("copper bar" finds everything made from
  Copper Bars), in one profession or all of them at once.
- **Craftsman's Writ crafts** are marked with a scroll; search "writ" to list them all.
- **Specializations:** Armorsmith, Weaponsmith and the weapon masters, the leatherworking paths,
  Gnomish and Goblin Engineering. Each path's recipes say so, and a dropdown lists one path's (or
  only those every crafter can learn). Once you've picked a path, the others' are listed only
  with Show all.
- **Shift-click** a craft or a material to link it in chat or the auction house search.

#### Shopping

- Add crafts to a shopping list; the Shopping tab adds up every material, counts what you hold
  once, and shows the gold to spend.
- **Send to Auctionator** turns it into an Auctionator shopping list with the right quantities.
  Materials vendors sell are left out and named in chat.

#### Professions

One addon, every crafting profession built in; pick any in the dropdown, even one this character
hasn't got, to see what it could make. Alchemy, Blacksmithing, Cooking, Enchanting (rods, oils and wands), Engineering, First Aid,
Leatherworking, Mining (smelting: bars against ore) and Tailoring. Recipes, trainer costs and
pattern sellers are built in; what your own profession window, trainers and vendors show is added
on top. Tooltips say where to get each pattern: vendors, reputation, quests and drops. Recipes
come from Forever's game data; vendor, trainer, loot and quest data partly from Efficient Games
(https://efficient.games, CC BY 4.0).
A Blacksmith who also mines gets bars at their ore's price when smelting is cheaper.

#### Commands

| Command | |
| --- | --- |
| `/leprofit` | Open or close the window (also the minimap button and the addon menu) |
| `/leprofit why <item>` | The whole sum for one craft, in chat (type the name or shift-click it) |
| `/leprofit status` | Price sources, your professions and recipes known |
| `/leprofit debug <item>` | A report to paste into a bug report: every price behind that craft's sums |
| `/leprofit help` | All commands |

#### Good to know

- **Needs Auctionator** (or TradeSkillMaster) for auction prices: scan the auction house and the
  list fills in.
- **Better with QuestieDB** (Questie installs it): tooltips then say where every pattern comes
  from and which side can get it, from its database. Optional.
- **Reports welcome, especially from other professions.** Blacksmithing and Mining have been
  tried most in game; the other professions' lists work on any character. If you have Alchemy, Cooking, Enchanting, Engineering, First Aid, Leatherworking or Tailoring,
  please try it and report what you find on the
  [issues page](https://github.com/addohm/leprofit/issues): what you did, what you expected, and
  the output of `/leprofit why <item>` and `/leprofit help` (it shows the version).
- **Listings aren't sales:** the price history shows what was listed, not what sold.
- Settings are per character. English game clients only. Nothing is sent to other players.
- Open source under the GNU GPLv3: [github.com/addohm/leprofit](https://github.com/addohm/leprofit).

---

## Screenshots to take

1. The Crafts tab on a Blacksmith after an Auctionator scan: the list sorted by Profit, one row
   selected with its materials panel open.
2. A row's tooltip for a greyed-out recipe: the pattern's price, where its seller stands, and
   "pays back in N crafts".
3. The history columns turned on (Avg 14d, Trend, Seen, Listed), sorted by Seen.
4. The Shopping tab with two planned crafts and their combined materials.
5. Auctionator's Shopping tab with the "leProfit" list after Send to Auctionator.
6. `/leprofit why <item>` output in chat.

---

## Release notes

### 1.3.0

**Craftsman's Writ crafts are marked:** a small scroll after the name of every craft a trade
faction's Craftsman's Writ asks for, and a tooltip line naming the writ. Search "writ" (with All
professions picked) to list them all.

### 1.2.0

- **No more lag spikes:** each craft's sums are kept until prices or settings change, and long
  lists are worked out a little per frame. `/leprofit perf` shows what leProfit's work costs.
- **Losses are shown, in red:** Hide losses (off at first) replaces Show losses, so a craft no
  longer seems missing because of an unticked box.
- **Your profession window is left alone:** leProfit knows which recipes you know from the game
  itself, in every profession, without opening it.
- **`/leprofit debug <item>`:** a report to paste into a bug report, with every price behind
  that craft's sums.
- The button on the profession window is gone (it never showed on Forever); the minimap button
  and the addon menu open leProfit.

### 1.1.0

**Renamed to leProfit, and one addon:** every profession is built in, with no modules to install.
Coming from 1.0? Delete the old `Leprofit` folder and the `Leprofit_<Profession>` folders from
AddOns first; your settings carry over.

- Recipes from world-drop patterns are listed, with the pattern's auction price as what learning
  costs. **Show all** now lists everything you could get, patterns that bind included.
- Tooltips say where to get each pattern: vendors and where they stand, reputation, quests and
  drops. With **QuestieDB** installed (Questie installs it), leProfit asks it for the full
  picture.
- The other faction's recipes are never listed.
- Opening a trainer records what it charges, for all your characters. Mining's smelting is built
  in.
- The built-in data comes from Forever's own game data, with vendor, trainer, loot and quest
  data partly from Efficient Games (https://efficient.games, CC BY 4.0).

### 1.0.0

Out of beta. New since the beta: **search** the Crafts list by item, recipe and material names
as you type ("copper bar" finds everything made from Copper Bars), in one profession or, with the
dropdown's new **All professions**, in every ticked module at once. Leprofit is open source under
the GNU GPLv3.

### 0.9.0-beta

The first beta. The Crafts list ranks every craft by profit (auction price after the cut and
undercut, less materials at the cheaper of buying and crafting), with Cost, Buyout and Profit,
sortable headings, optional price-history columns from Auctionator, greyed-out recipes you could
learn with their cost, payback and where the pattern's seller stands, and a materials panel. A
Shopping tab adds up what to buy and sends it to Auctionator. Nine profession modules, ticked per
character, including Mining's smelting feeding Blacksmithing. Diagnostics with `/leprofit why`.
