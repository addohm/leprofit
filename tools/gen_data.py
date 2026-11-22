"""Generate each profession's data file, leProfit/Data/<Profession>.lua.

Run it with no arguments: python3 tools/gen_data.py   (tools/update_data.py runs it for you)

Where each part comes from:

- Recipes: Forever's game data tables in .source/game/ (tools/fetch_sources.py downloads them).
  Every recipe on the profession's skill line (SkillLineAbility) that makes an item (SpellEffect
  "create item") from materials (SpellReagents): its name, what it makes and how many (the
  average, for recipes that make a few), and the skill at which it turns grey. Plus
  tools/learned.json's extraRecipes: Forever's camp and home items, which the game files under
  gathering skills, listed with the crafting professions that use their materials.
- Trainer costs and the skill each needs: tools/learned.json. Trainers aren't in the game data;
  leProfit records them when you open a trainer, and tools/update_data.py adds those.
- Patterns sold by vendors: the recipe each teaches and the skill it needs from the game data
  (ItemXItemEffect, ItemSparse); who sells it, for how much and where from tools/learned.json
  (with what you recorded in game) and from Efficient Games' player-recorded vendors.
- Patterns no vendor sells (drops, quest and reputation rewards): the pattern item from the game
  data, the skill it needs, and whether it binds when picked up (so it can't be bought).
- Recipes that come with the profession (the game data's AcquireMethod 1).
- Vendor prices of materials: tools/learned.json, then Efficient Games' vendors (endless supply).
- Item names: the game data (ItemSparse); tools/learned.json for the few it doesn't have.

Only the standard library is needed.
"""
import csv
import glob
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / ".source"
GAME = SOURCE / "game"
LEARNED = ROOT / "tools" / "learned.json"
DATA = ROOT / "leProfit" / "Data"

# Profession -> (skill line, icon, window names if the game calls the window something else).
# Add a profession here, run the script, and list its file in leProfit.toc.
PROFESSIONS = {
    "Alchemy": (171, "Interface\\Icons\\Trade_Alchemy", None),
    "Blacksmithing": (164, "Interface\\Icons\\Trade_BlackSmithing", None),
    "Cooking": (185, "Interface\\Icons\\INV_Misc_Food_15", None),
    "Enchanting": (333, "Interface\\Icons\\Trade_Engraving", None),
    "Engineering": (202, "Interface\\Icons\\Trade_Engineering", None),
    "First Aid": (129, "Interface\\Icons\\Spell_Holy_SealOfSacrifice", None),
    "Leatherworking": (165, "Interface\\Icons\\Trade_LeatherWorking", None),
    "Mining": (186, "Interface\\Icons\\Trade_Mining", ["Mining", "Smelting"]),
    "Tailoring": (197, "Interface\\Icons\\Trade_Tailoring", None),
}

# Vendor discount by standing with the vendor's faction (4 Neutral ... 8 Exalted): players record
# what they paid, so the full price is worked back from it.
DISCOUNT = {4: 0, 5: 0, 6: 0.10, 7: 0.15, 8: 0.20}


class DataError(Exception):
    pass


def table(name):
    path = GAME / f"{name}.csv"
    if not path.exists():
        raise DataError(f"Can't find .source/game/{name}.csv: run tools/fetch_sources.py first.")
    with open(path, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def eg(dataset, key):
    """One player-recorded dataset merged across every build, newest last (so newest wins)."""
    files = sorted(glob.glob(str(SOURCE / "eg" / f"{dataset}_*.json")),
                   key=lambda p: int(re.search(r"_(\d+)\.json$", p).group(1)))
    merged = {}
    for path in files:
        with open(path, encoding="utf-8") as f:
            for k, v in json.load(f).get(key, {}).items():
                merged.setdefault(k, {}).update(v)
    return merged


def full_price(costs):
    """The undiscounted copper price from a vendor entry's {standing: copper} (0 if none)."""
    best = 0
    for standing, copper in (costs or {}).items():
        d = DISCOUNT.get(int(standing))
        if d is not None and copper:
            best = max(best, round(copper / (1 - d)))
    return best


def load_learned():
    if not LEARNED.exists():
        raise DataError("Can't find tools/learned.json.")
    with open(LEARNED, encoding="utf-8") as f:
        learned = json.load(f)
    for key in ("training", "patterns", "vendorPrices", "itemNames", "extraRecipes"):
        learned.setdefault(key, {})
    return learned


ABOUT = ("What Forever's game data doesn't have, for tools/gen_data.py: trainer costs and the skill "
         "each needs (training), vendors' patterns with their sellers and prices (patterns), vendor "
         "prices of materials in copper for one (vendorPrices), names of items the game data lacks "
         "(itemNames), and recipes the game files under gathering skills, listed here with crafting "
         "professions (extraRecipes). tools/update_data.py adds what leProfit records in game; you "
         "can also edit it by hand.")


def save_learned(learned):
    """Writes tools/learned.json, sorted, so a change reads well in a diff."""
    by_id = lambda kv: int(kv[0])
    out = {
        "about": ABOUT,
        "training": {p: dict(sorted(v.items())) for p, v in sorted(learned["training"].items()) if v},
        "patterns": {p: dict(sorted(v.items())) for p, v in sorted(learned["patterns"].items()) if v},
        "vendorPrices": dict(sorted(learned["vendorPrices"].items(), key=by_id)),
        "itemNames": dict(sorted(learned["itemNames"].items(), key=by_id)),
        "extraRecipes": {p: dict(sorted(v.items(), key=by_id)) for p, v in sorted(learned["extraRecipes"].items()) if v},
    }
    LEARNED.write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")


def game_item_ids():
    """Every item ID the downloaded game data names."""
    return {int(r["ID"]) for r in table("ItemSparse")}


def lua_string(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def lua_number(n):
    n = float(n)
    return str(int(n)) if n.is_integer() else repr(round(n, 4))


def lua_value(v):
    return lua_number(v) if isinstance(v, (int, float)) else lua_string(v)


def data_file(name):
    """The profession's data file: leProfit/Data/ and the profession without spaces."""
    return DATA / (name.replace(" ", "") + ".lua")


class Game:
    """The game data tables, read once."""

    def __init__(self):
        self.build = (SOURCE / "BUILD").read_text(encoding="utf-8").strip() if (SOURCE / "BUILD").exists() else "?"
        self.items = {int(r["ID"]): r for r in table("ItemSparse")}
        self.spell_names = {int(r["ID"]): r["Name_lang"] for r in table("SpellName")}
        self.reagents = {}
        for r in table("SpellReagents"):
            lst = []
            for n in range(8):
                item, count = int(r.get(f"Reagent_{n}") or 0), int(r.get(f"ReagentCount_{n}") or 0)
                if item > 0 and count > 0:
                    lst.append([item, count])
            if lst:
                self.reagents[int(r["SpellID"])] = lst
        self.creates = {}  # spell -> (item, how many on average)
        for r in table("SpellEffect"):
            if r["Effect"] == "24" and int(r["EffectItemType"] or 0) > 0:
                self.creates.setdefault(int(r["SpellID"]), (int(r["EffectItemType"]), max(1.0, float(r["EffectBasePointsF"] or 1))))
        self.abilities = {}  # skill line -> [rows]
        self.grey = {}       # spell -> skill at which it turns grey
        for r in table("SkillLineAbility"):
            self.abilities.setdefault(int(r["SkillLine"]), []).append(r)
            if int(r["TrivialSkillLineRankHigh"] or 0) > 0:
                self.grey.setdefault(int(r["Spell"]), int(r["TrivialSkillLineRankHigh"]))
        effects = {int(r["ID"]): r for r in table("ItemEffect")}
        self.teaches = {}    # recipe item -> spells it teaches (a "learn" effect, trigger type 6)
        self.taught_by = {}  # spell -> the recipe items that teach it
        for r in table("ItemXItemEffect"):
            e = effects.get(int(r["ItemEffectID"]))
            if e and e["TriggerType"] == "6":
                self.teaches.setdefault(int(r["ItemID"]), set()).add(int(e["SpellID"]))
                self.taught_by.setdefault(int(e["SpellID"]), set()).add(int(r["ItemID"]))
        self.map_names = {int(r["ID"]): r["Name_lang"] for r in table("UiMap")}

    def recipe(self, spell, fallback=None):
        """A recipe's name, product, yield, grey and materials, or the fallback's if the game has none."""
        made, reagents = self.creates.get(spell), self.reagents.get(spell)
        if not (made and reagents and self.spell_names.get(spell)):
            return fallback
        r = {"name": self.spell_names[spell], "product": made[0], "yield": made[1], "reagents": reagents}
        grey = self.grey.get(spell) or (fallback or {}).get("grey")
        if grey:
            r["grey"] = grey
        return r

    def binds(self, item):
        """True if the item binds when picked up (or is a quest item), False if it can be traded,
        None if the game data doesn't have it."""
        r = self.items.get(item)
        return None if not r else r["Bonding"] in ("1", "4")

    def item_name(self, item):
        r = self.items.get(item)
        return r["Display_lang"] if r and r["Display_lang"] else None


class Players:
    """Efficient Games' player-recorded vendors: what each sells, for how much, and where."""

    def __init__(self, game):
        vendors, npcs = eg("vendors", "vendors"), eg("npcs", "npcs")
        self.builds = len(glob.glob(str(SOURCE / "eg" / "vendors_*.json")))
        self.sellers = {}  # item -> [(seller, price)]
        self.prices = {}   # item -> copper for one, in endless supply
        for vid, v in vendors.items():
            seller = {"vendor": v.get("name")}
            if not seller["vendor"]:
                continue
            pos = (v.get("positions") or [{}])[0]
            if game.map_names.get(pos.get("uiMap")):
                seller["zone"] = game.map_names[pos["uiMap"]]
            side = (npcs.get(vid) or {}).get("side")
            if side in ("Alliance", "Horde"):
                seller["faction"] = side
            if pos.get("uiMap") and pos.get("mapX") is not None and pos.get("mapY") is not None:
                seller["mapID"], seller["x"], seller["y"] = int(pos["uiMap"]), round(pos["mapX"], 4), round(pos["mapY"], 4)
            for e in (v.get("entries") or {}).values():
                item, price = e.get("itemId"), full_price(e.get("costs"))
                if not item or not price or e.get("costItems"):
                    continue
                self.sellers.setdefault(item, []).append((seller, price))
                if not e.get("limited"):
                    each = price / max(1, e.get("stack") or 1)
                    self.prices[item] = min(self.prices.get(item, each), each)


def profession(name, game, players, learned):
    line, _, _ = PROFESSIONS[name]
    recipes = {}
    for r in game.abilities.get(line, []):
        rec = game.recipe(int(r["Spell"]))
        if rec:
            recipes[int(r["Spell"])] = rec
    for sid, stored in learned["extraRecipes"].get(name, {}).items():
        recipes.setdefault(int(sid), game.recipe(int(sid), stored))
    names = {r["name"] for r in recipes.values()}
    by_spell = {sid: r["name"] for sid, r in recipes.items()}
    materials = set()  # what the recipes make and use: the items a vendor price matters for
    for r in recipes.values():
        materials.add(r["product"])
        materials.update(i for i, _ in r["reagents"])
    used = set(materials)

    training = {k: v for k, v in learned["training"].get(name, {}).items() if k in names and "cost" in v}

    patterns = {}
    for recipe, p in learned["patterns"].get(name, {}).items():
        if recipe in names and p.get("itemID"):
            patterns[recipe] = {"itemID": int(p["itemID"]), "price": p.get("price"), "sellers": list(p.get("sellers") or [])}
    for item, spells in game.teaches.items():
        for spell in spells:
            recipe = by_spell.get(spell)
            if not recipe or item not in players.sellers:
                continue
            p = patterns.setdefault(recipe, {"itemID": item, "price": None, "sellers": []})
            if p["itemID"] != item:
                continue  # another item teaches it too; keep the one already known
            have = {s.get("vendor") for s in p["sellers"]}
            for seller, price in sorted(players.sellers[item], key=lambda sp: sp[0]["vendor"]):
                if seller["vendor"] not in have:
                    have.add(seller["vendor"])
                    p["sellers"].append(seller)
                if p["price"] is None:
                    p["price"] = price
    def skill(item):
        r = game.items.get(item)
        return int(r["RequiredSkillRank"]) if r and int(r["RequiredSkillRank"] or 0) > 0 else None

    for p in patterns.values():
        p["skill"] = skill(p["itemID"])
        used.add(p["itemID"])

    # Recipes that come with the profession, and patterns no vendor sells: one per recipe name, a
    # tradeable one first (it can be bought at the auction house), then one the data can't tell.
    free = set()
    for r in game.abilities.get(line, []):
        rec = recipes.get(int(r["Spell"]))
        if rec and r["AcquireMethod"] == "1" and rec["name"] not in training:
            free.add(rec["name"])
    other = {}
    order = {False: 0, None: 1, True: 2}
    for sid, rec in recipes.items():
        name = rec["name"]
        if name in training or name in patterns or name in free:
            continue
        for item in sorted(game.taught_by.get(sid, ())):
            p = {"itemID": item, "skill": skill(item), "bound": game.binds(item)}
            if name not in other or order[p["bound"]] < order[other[name]["bound"]]:
                other[name] = p
    used.update(p["itemID"] for p in other.values())

    vendor_prices = {}
    for item in materials:
        price = learned["vendorPrices"].get(str(item))
        if price is None:
            price = players.prices.get(item)
        if price is not None:
            vendor_prices[item] = price
    # Names from the game data; a few of Forever's items aren't in it yet, so learned.json keeps theirs.
    item_names = {}
    for i in used:
        n = game.item_name(i) or learned["itemNames"].get(str(i))
        if n:
            item_names[i] = n
    return recipes, training, patterns, other, free, vendor_prices, item_names


def old_names(path):
    """The recipe, trainer and pattern names a data file lists now, to report what changed."""
    if not path.exists():
        return set(), set(), set()
    text = path.read_text(encoding="utf-8")
    recipes = set(re.findall(r'^\t\t\[\d+\] = \{ name = "((?:[^"\\]|\\.)*)"', text, re.M))
    training = set(re.findall(r'^\t\t\["((?:[^"\\]|\\.)*)"\] = \{ cost = ', text, re.M))
    patterns = set(re.findall(r'^\t\t\["((?:[^"\\]|\\.)*)"\] = \{ itemID = ', text, re.M))
    unescape = lambda s: s.replace('\\"', '"').replace("\\\\", "\\")
    return {unescape(n) for n in recipes}, {unescape(n) for n in training}, {unescape(n) for n in patterns}


def write(name, build, recipes, training, patterns, other, free, vendor_prices, item_names):
    _, icon, windows = PROFESSIONS[name]
    out = [
        f"-- leProfit: the {name} data. Generated by tools/gen_data.py: don't edit by hand, run the",
        f"-- script again. Game data from Forever build {build}; vendor data partly from Efficient Games",
        "-- (https://efficient.games), licensed under CC BY 4.0.",
        "local _, ns = ...",
        "ns.RegisterProfession({",
        f"\tname = {lua_string(name)},",
        f"\ticon = {lua_string(icon)},",
    ]
    if windows:
        out.append(f"\twindowNames = {{ {', '.join(lua_string(w) for w in windows)} }},")
    out += ["\t-- recipeID = { name, product (item made), yield, grey (skill), reagents = { { itemID, count } } }",
            "\trecipes = {"]
    for rid in sorted(recipes):
        r = recipes[rid]
        reagents = ", ".join(f"{{ {i}, {n} }}" for i, n in r["reagents"])
        fields = [f"name = {lua_string(r['name'])}", f"product = {r['product']}", f"yield = {lua_number(r['yield'])}"]
        if r.get("grey"):
            fields.append(f"grey = {r['grey']}")
        fields.append(f"reagents = {{ {reagents} }}")
        out.append(f"\t\t[{rid}] = {{ {', '.join(fields)} }},")
    out += ["\t},", "\t-- recipe name = { cost (copper), skill (required) }: what trainers charge", "\ttraining = {"]
    for recipe in sorted(training):
        t = training[recipe]
        skill = f", skill = {lua_number(t['skill'])}" if t.get("skill") is not None else ""
        out.append(f"\t\t[{lua_string(recipe)}] = {{ cost = {lua_number(t['cost'])}{skill} }},")
    out += ["\t},", "\t-- recipe name = { itemID, price, skill, sellers = { { vendor, zone, subZone, faction, mapID, x, y } } }",
            "\tpatterns = {"]
    for recipe in sorted(patterns):
        p = patterns[recipe]
        fields = [f"itemID = {p['itemID']}"]
        if p["price"] is not None:
            fields.append(f"price = {lua_number(p['price'])}")
        if p["skill"] is not None:
            fields.append(f"skill = {lua_number(p['skill'])}")
        sellers = ", ".join("{ " + ", ".join(f"{k} = {lua_value(s[k])}" for k in
                                             ("vendor", "zone", "subZone", "faction", "mapID", "x", "y") if s.get(k) is not None) + " }"
                            for s in p["sellers"])
        fields.append(f"sellers = {{ {sellers} }}")
        out.append(f"\t\t[{lua_string(recipe)}] = {{ {', '.join(fields)} }},")
    out += ["\t},", "\t-- recipe name = { itemID, skill, bound }: patterns no vendor sells (drops, quest and reputation",
            "\t-- rewards); bound = binds when picked up, so it can't be bought; absent when the data doesn't say",
            "\totherPatterns = {"]
    for recipe in sorted(other):
        p = other[recipe]
        fields = [f"itemID = {p['itemID']}"]
        if p["skill"] is not None:
            fields.append(f"skill = {p['skill']}")
        if p["bound"] is not None:
            fields.append(f"bound = {'true' if p['bound'] else 'false'}")
        out.append(f"\t\t[{lua_string(recipe)}] = {{ {', '.join(fields)} }},")
    out += ["\t},", "\t-- recipes that come with the profession", "\tfree = {"]
    for recipe in sorted(free):
        out.append(f"\t\t[{lua_string(recipe)}] = true,")
    out += ["\t},", "\t-- itemID = copper: what vendors charge for one", "\tvendorPrices = {"]
    for i in sorted(vendor_prices):
        out.append(f"\t\t[{i}] = {lua_number(vendor_prices[i])},")
    out += ["\t},", "\titemNames = {"]
    for i in sorted(item_names):
        out.append(f"\t\t[{i}] = {lua_string(item_names[i])},")
    out += ["\t},", "})", ""]
    data_file(name).write_text("\n".join(out), encoding="utf-8", newline="\n")


def generate():
    """Writes every profession's data file. Returns the build and, per profession, its counts and
    the recipe, trainer and pattern names added and removed since the files were last written."""
    game = Game()
    players = Players(game)
    learned = load_learned()
    DATA.mkdir(exist_ok=True)
    report = {}
    for name in PROFESSIONS:
        before = old_names(data_file(name))
        recipes, training, patterns, other, free, vendor_prices, item_names = profession(name, game, players, learned)
        write(name, game.build, recipes, training, patterns, other, free, vendor_prices, item_names)
        now = ({r["name"] for r in recipes.values()}, set(training), set(patterns))
        report[name] = {
            "recipes": len(recipes), "training": len(training), "patterns": len(patterns),
            "otherPatterns": len(other), "tradeable": sum(1 for p in other.values() if p["bound"] is False),
            "free": len(free), "vendorPrices": len(vendor_prices),
            "added": [sorted(n - b) for n, b in zip(now, before)],
            "removed": [sorted(b - n) for n, b in zip(now, before)],
        }
    return game.build, players.builds, report


def main():
    try:
        build, eg_builds, report = generate()
    except DataError as e:
        sys.exit(str(e))
    print(f"Game data from Forever build {build}; player vendor data from {eg_builds} builds.")
    for name, r in report.items():
        print(f"{data_file(name).relative_to(ROOT)}: {r['recipes']} recipes, {r['training']} trainer costs, "
              f"{r['patterns']} vendor patterns, {r['otherPatterns']} other patterns ({r['tradeable']} tradeable), "
              f"{r['free']} free, {r['vendorPrices']} vendor prices")
        for label, added, removed in zip(("recipes", "trainer costs", "patterns"), r["added"], r["removed"]):
            if added:
                print(f"  new {label}: {', '.join(added)}")
            if removed:
                print(f"  gone {label}: {', '.join(removed)}")


if __name__ == "__main__":
    main()
