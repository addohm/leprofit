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
| Release type | Release (1.0.0) |
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
- **Recipes you haven't learned** but have the skill for are greyed out. Show all adds the ones
  you'd need more skill for; Hide unlearned keeps only what you know. That includes recipes from
  world-drop patterns you can buy at the auction house, priced from your scans.
- **Click a craft** for its materials: what you need, what you hold, what to buy and what it
  costs, for as many crafts as you like. Hide items that never sell (it asks first).
- **Price history** from your Auctionator scans, as optional columns: a 14-day average, the
  trend (up, down or level), how many days it was listed, and how many are up now.
- **Search** item, recipe and material names as you type ("copper bar" finds everything made from
  Copper Bars), in one profession or all of them at once.
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
| `/leprofit` | Open or close the window (also the minimap button, the addon menu, and a button on the profession window) |
| `/leprofit why <item>` | The whole sum for one craft, in chat (type the name or shift-click it) |
| `/leprofit status` | Price sources, your professions and recipes known |
| `/leprofit help` | All commands |

#### Good to know

- **Needs Auctionator** (or TSM) for auction prices: scan the auction house and the list fills
  in. TradeSkillMaster doesn't seem to run on Forever yet; Auctionator does.
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
