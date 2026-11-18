# Leprofit: CurseForge and Wago listing

Copy-paste material for the project pages. Placeholders are in [brackets]. Keep the feature list
in step with README.md.

---

## Basics

| Field | Value |
| --- | --- |
| Name | Leprofit |
| Slug | `leprofit` |
| Game version | WoW: Forever (Interface 16001) |
| Author | addohm |
| Release type | Beta (0.9.0-beta) |
| License | [choose: All Rights Reserved, MIT, ...] |
| Source | [https://github.com/addohm/leprofit, if the repo is public] |
| Issues | [https://github.com/addohm/leprofit/issues, if public] |
| Upload | `release/Leprofit-0.9.0-beta.zip` (the core and all nine profession modules) |

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

### Leprofit

**Which crafts make gold, most profitable first. Built for WoW: Forever.**

Leprofit lists every craft in your professions with what it costs to make, what it sells for,
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
  you'd need more skill for; Hide unlearned keeps only what you know.
- **Click a craft** for its materials: what you need, what you hold, what to buy and what it
  costs, for as many crafts as you like. Hide items that never sell (it asks first).
- **Price history** from your Auctionator scans, as optional columns: a 14-day average, the
  trend (up, down or level), how many days it was listed, and how many are up now.
- **Shift-click** a craft or a material to link it in chat or the auction house search.

#### Shopping

- Add crafts to a shopping list; the Shopping tab adds up every material, counts what you hold
  once, and shows the gold to spend.
- **Send to Auctionator** turns it into an Auctionator shopping list with the right quantities.
  Materials vendors sell are left out and named in chat.

#### Professions

One module per profession: tick only the ones each character has, so each loads only its own data.
Alchemy, Blacksmithing, Cooking, Enchanting (rods, oils and wands), Engineering, First Aid,
Leatherworking, Mining (smelting: bars against ore) and Tailoring. Recipes, trainer costs and
pattern sellers are built in; what your own profession window and vendors show is added on top.
A Blacksmith who also mines gets bars at their ore's price when smelting is cheaper.

#### Commands

| Command | |
| --- | --- |
| `/leprofit` | Open or close the window (also the minimap button, the addon menu, and a button on the profession window) |
| `/leprofit why <item>` | The whole sum for one craft, in chat (type the name or shift-click it) |
| `/leprofit status` | Price sources, modules, and recipes known |
| `/leprofit help` | All commands |

#### Good to know

- **Needs Auctionator** (or TSM) for auction prices: scan the auction house and the list fills
  in. TradeSkillMaster doesn't seem to run on Forever yet; Auctionator does.
- **This is a beta.** Blacksmithing and Mining have been tried in game; the other professions'
  lists work on any character, but reading their windows is new. `/leprofit why` shows where every
  number comes from, which helps with reports.
- **Listings aren't sales:** the price history shows what was listed, not what sold.
- Settings are per character. English game clients only. Nothing is sent to other players.

---

## Screenshots to take

1. The Crafts tab on a Blacksmith after an Auctionator scan: the list sorted by Profit, one row
   selected with its materials panel open.
2. A row's tooltip for a greyed-out recipe: the pattern's price, where its seller stands, and
   "pays back in N crafts".
3. The history columns turned on (Avg 14d, Trend, Seen, Listed), sorted by Seen.
4. The Shopping tab with two planned crafts and their combined materials.
5. Auctionator's Shopping tab with the "Leprofit" list after Send to Auctionator.
6. `/leprofit why <item>` output in chat.

---

## Release notes

### 0.9.0-beta

The first beta. The Crafts list ranks every craft by profit (auction price after the cut and
undercut, less materials at the cheaper of buying and crafting), with Cost, Buyout and Profit,
sortable headings, optional price-history columns from Auctionator, greyed-out recipes you could
learn with their cost, payback and where the pattern's seller stands, and a materials panel. A
Shopping tab adds up what to buy and sends it to Auctionator. Nine profession modules, ticked per
character, including Mining's smelting feeding Blacksmithing. Diagnostics with `/leprofit why`.
