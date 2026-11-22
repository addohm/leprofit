"""Generate each profession's data file, leProfit/Data/<Profession>.lua.

Run it with no arguments: python3 tools/gen_data.py   (tools/update_data.py runs it for you)

Where each part comes from:

- Recipes: Forever's game data tables in .source/game/ (tools/fetch_sources.py downloads them).
  Every recipe on the profession's skill line (SkillLineAbility) that makes an item (SpellEffect
  "create item") from materials (SpellReagents): its name, what it makes and how many (the
  average, for recipes that make a few), and the skill at which it turns grey. Plus
  tools/learned.json's extraRecipes: Forever's camp and home items, which the game files under
  gathering skills, listed with the crafting professions that use their materials.
- Trainer costs and the skill each needs: tools/learned.json, then Efficient Games' trainers.
  Trainers aren't in the game data; leProfit records them when you open a trainer, and
  tools/update_data.py adds those to learned.json.
- Patterns sold by vendors: the recipe each teaches and the skill it needs from the game data
  (ItemXItemEffect, ItemSparse); who sells it, for how much and where from tools/learned.json
  (with what you recorded in game) and from Efficient Games' player-recorded vendors.
- Patterns no vendor sells for gold (drops, quest and reputation rewards, token vendors): the
  pattern item from the game data, the skill it needs, and whether it binds when picked up (so it
  can't be bought); where to get it from Efficient Games' loot, quest and vendor data; the
  reputation it needs from the game data.
- Which side can get a pattern, when only one can: a one-side reputation (the game data's
  Faction table), or every known source that side's (its vendors' faction, its quests' races).
  leProfit leaves the other side's out.
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

STANDINGS = ["Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted"]
ALLIANCE_RACES, HORDE_RACES = 0x4D, 0xB2  # Human, Dwarf, Night Elf, Gnome / Orc, Undead, Tauren, Troll
MOST_DROPS, MOST_QUESTS = 5, 5            # sources kept per pattern
MERCHANTS_FAVOR = 3402  # the trade factions' currency: each side's camp sells the same rewards
# Towns whose vendors serve both sides. 1.0's data sometimes gave a vendor there the faction of the
# player who recorded it; vendors Efficient Games knows get their own faction from its data instead.
NEUTRAL_PLACES = {"Booty Bay", "The Old Port Authority", "Gadgetzan", "Steamwheedle Port", "Ratchet", "Everlook",
                  "Cenarion Hold", "Valor's Rest", "Light's Hope Chapel", "Nighthaven", "Yojamba Isle",
                  "Thorium Point", "Ravenholdt Manor", "Powderfuse Port"}


def side_of_races(mask):
    """"Alliance" or "Horde" when a race mask holds only that side's races, else None."""
    m = mask & 0xFF
    a, h = m & ALLIANCE_RACES, m & HORDE_RACES
    return "Alliance" if a and not h else "Horde" if h and not a else None


def money(copper):
    g, s, c = copper // 10000, copper // 100 % 100, copper % 100
    return " ".join(f"{n}{u}" for n, u in ((g, "g"), (s, "s"), (c, "c")) if n) or "0c"


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
    """A value as Lua: numbers, strings, true/false, and dicts and lists as one-line tables (None
    and empty entries left out)."""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return lua_number(v)
    if isinstance(v, dict):
        fields = [f"{k} = {lua_value(x)}" for k, x in v.items() if x is not None and x != [] and x != {}]
        return "{ " + ", ".join(fields) + " }" if fields else "{}"
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua_value(x) for x in v) + " }" if v else "{}"
    return lua_string(v)


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
        self.areas = {int(r["ID"]): r["AreaName_lang"] for r in table("AreaTable")}
        # A faction only one side can earn: the other side's races start at Hated and can't move.
        self.factions = {}
        for r in table("Faction"):
            locked = 0
            for i in range(4):
                if int(r.get(f"ReputationBase_{i}") or 0) <= -42000:
                    locked |= int(r.get(f"ReputationRaceMasks{i}_0") or 0)
            shut = side_of_races(locked)
            self.factions[int(r["ID"])] = (r["Name_lang"], {"Horde": "Alliance", "Alliance": "Horde"}.get(shut))

    def reputation(self, item):
        """The reputation an item needs: { faction, standing, side (when only one side can earn it) }."""
        r = self.items.get(item)
        fid = int(r["MinFactionID"] or 0) if r else 0
        if not fid or fid not in self.factions:
            return None
        name, side = self.factions[fid]
        standing = int(r["MinReputation"] or 0)
        out = {"faction": name, "standing": STANDINGS[standing] if 0 <= standing < len(STANDINGS) else str(standing)}
        if side:
            out["side"] = side
        return out

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
    """Efficient Games' player-recorded data: who sells what (for gold or tokens) and where, what
    trainers charge, what drops from what, and which quests reward what."""

    def __init__(self, game):
        vendors, npcs = eg("vendors", "vendors"), eg("npcs", "npcs")
        creatures, objects = eg("creatures", "creatures"), eg("object_details.enUS", "objects")
        self.builds = len(glob.glob(str(SOURCE / "eg" / "vendors_*.json")))
        self.sellers = {}  # item -> [(seller, copper)], for gold
        self.tokens = {}   # item -> [seller with a "cost" text], for tokens or currency
        self.prices = {}   # item -> copper for one, in endless supply

        def where(seller, positions):
            pos = (positions or [{}])[0]
            if game.map_names.get(pos.get("uiMap")):
                seller["zone"] = game.map_names[pos["uiMap"]]
            if pos.get("uiMap") and pos.get("mapX") is not None and pos.get("mapY") is not None:
                seller["mapID"], seller["x"], seller["y"] = int(pos["uiMap"]), round(pos["mapX"], 4), round(pos["mapY"], 4)
            return seller

        # Each NPC's own faction, by name: Alliance, Horde, or Neutral when no record names a side.
        sides = {}
        for n in npcs.values():
            if n.get("name"):
                sides.setdefault(n["name"], set()).add(n.get("side") if n.get("side") in ("Alliance", "Horde") else None)
        self.npc_side = {}
        for name, s in sides.items():
            known = s - {None}
            self.npc_side[name] = known.pop() if len(known) == 1 else "Neutral" if not known else None

        for vid, v in vendors.items():
            if not v.get("name"):
                continue
            seller = {"vendor": v["name"]}
            side = (npcs.get(vid) or {}).get("side")
            if side in ("Alliance", "Horde"):
                seller["faction"] = side
            where(seller, v.get("positions"))
            for e in (v.get("entries") or {}).values():
                item, price = e.get("itemId"), full_price(e.get("costs"))
                if not item:
                    continue
                if e.get("costItems"):
                    parts = [money(price)] if price else []
                    parts += [f"{c.get('amount', 1)} {c.get('name') or 'tokens'}" for c in e["costItems"]]
                    s = dict(seller, cost=" and ".join(parts))
                    if any(c.get("currencyId") == MERCHANTS_FAVOR for c in e["costItems"]):
                        s["camp"] = True  # a trade-faction camp's: the other side's camp sells it too
                    self.tokens.setdefault(item, []).append(s)
                    continue
                if not price:
                    continue
                self.sellers.setdefault(item, []).append((seller, price))
                if not e.get("limited"):
                    each = price / max(1, e.get("stack") or 1)
                    self.prices[item] = min(self.prices.get(item, each), each)

        self.trainers = {}  # spell -> { cost, skill }
        for t in eg("trainers", "trainers").values():
            for sid, s in (t.get("services") or {}).items():
                cost = full_price(s.get("costs"))
                if cost or s.get("costs"):
                    entry = {"cost": cost}
                    if int(s.get("skillRank") or 0) > 0:
                        entry["skill"] = int(s["skillRank"])
                    self.trainers[int(sid)] = entry

        # Loot: per item, per source (a creature, an object, a container, a fishing spot), the
        # drops and the loot windows opened, added up over every build and way of looting.
        loot = {}
        for path in sorted(glob.glob(str(SOURCE / "eg" / "loot_*.json"))):
            with open(path, encoding="utf-8") as f:
                for key, s in json.load(f).get("sources", {}).items():
                    base = key.split("|")[0]
                    for item, e in (s.get("items") or {}).items():
                        d = loot.setdefault(int(item), {}).setdefault(base, {"drops": 0, "windows": 0, "positions": None})
                        d["drops"] += int(e.get("drops") or 0)
                        d["windows"] += int(s.get("windows") or 0)
                        d["positions"] = d["positions"] or s.get("positions")
        self.drops = {}  # item -> [{ how, from, zone, drops, of (loot windows) }], likeliest first
        for item, sources in loot.items():
            out = []
            for base, d in sources.items():
                kind, _, ident = base.partition(":")
                ident = int(ident) if ident.isdigit() else None
                if kind == "npc":
                    name = (npcs.get(str(ident)) or {}).get("name") or (creatures.get(str(ident)) or {}).get("name")
                    how = "drop"
                elif kind == "object":
                    name, how = (objects.get(str(ident)) or {}).get("name"), "object"
                elif kind == "item":
                    name, how = game.item_name(ident), "container"
                elif kind == "fishing":
                    name, how = game.map_names.get(ident), "fishing"
                else:
                    continue
                if not name:
                    continue
                e = {"how": how, "from": name}
                zone = where({}, d["positions"]).get("zone")
                if zone and how != "fishing":
                    e["zone"] = zone
                if d["windows"]:
                    e["drops"], e["of"] = min(d["drops"], d["windows"]), d["windows"]
                out.append(e)
            out.sort(key=lambda e: (-(e.get("drops", 0) / max(1, e.get("of", 1))), -e.get("of", 0), e["from"]))
            if out:
                self.drops[item] = out[:MOST_DROPS]

        self.quests = {}  # item -> [{ title, zone, side }]
        for q in eg("quests.enUS", "quests").values():
            r = q.get("rewards") or {}
            mask = q.get("raceMask")
            side = side_of_races(int(mask, 16)) if isinstance(mask, str) and re.fullmatch(r"[0-9a-fA-F]+", mask) else None
            for x in (r.get("items") or []) + (r.get("choices") or []):
                if not x.get("itemId") or not q.get("title"):
                    continue
                e = {"title": q["title"]}
                if game.areas.get(q.get("zoneAreaId")):
                    e["zone"] = game.areas[q["zoneAreaId"]]
                if side:
                    e["side"] = side
                lst = self.quests.setdefault(int(x["itemId"]), [])
                if e not in lst and len(lst) < MOST_QUESTS:
                    lst.append(e)


def only_side(rep, sellers, quests, drops):
    """The one side that can get a pattern, or None (the owner's rule: if it's Horde, an Alliance
    player doesn't see it). A one-side reputation decides it; else every way of getting it known
    is that side's: its vendors' faction, its quests' races. A drop, a neutral vendor, or a trade
    camp's quartermaster (both sides' camps sell the same) is anyone's."""
    if rep and rep.get("side"):
        return rep["side"]
    sides = {None if s.get("camp") else s.get("faction") for s in sellers} | {q.get("side") for q in quests}
    if drops or len(sides) != 1:
        return None
    side = sides.pop()
    return side if side in ("Alliance", "Horde") else None


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
    for sid, rec in sorted(recipes.items()):
        if rec["name"] not in training and sid in players.trainers:
            training[rec["name"]] = players.trainers[sid]

    def faction_fixed(s):
        """A seller from learned.json with its faction checked: Efficient Games' for the NPC, or
        Neutral in a neutral town."""
        s = dict(s)
        side = players.npc_side.get(s.get("vendor"))
        if side:
            s["faction"] = side
        elif s.get("subZone") in NEUTRAL_PLACES:
            s["faction"] = "Neutral"
        return s

    patterns = {}
    for recipe, p in learned["patterns"].get(name, {}).items():
        if recipe in names and p.get("itemID"):
            patterns[recipe] = {"itemID": int(p["itemID"]), "price": p.get("price"),
                                "sellers": [faction_fixed(s) for s in p.get("sellers") or []]}
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
        p["bound"] = game.binds(p["itemID"])
        p["rep"] = game.reputation(p["itemID"])
        p["side"] = only_side(p["rep"], p["sellers"], [], [])
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
    for p in other.values():
        item = p["itemID"]
        p["rep"] = game.reputation(item)
        p["sellers"] = sorted(players.tokens.get(item, []), key=lambda s: s["vendor"])
        p["quests"] = players.quests.get(item, [])
        p["drops"] = players.drops.get(item, [])
        p["side"] = only_side(p["rep"], p["sellers"], p["quests"], p["drops"])
        # Only one side's trade camp recorded: say the other's sells it too.
        camps = {s.get("faction") for s in p["sellers"] if s.get("camp")}
        p["otherCamp"] = {"Horde": "Alliance", "Alliance": "Horde"}.get(camps.pop()) if len(camps) == 1 else None
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

    def section(name):
        m = re.search(rf"^\t{name} = {{\n(.*?)^\t}},", text, re.M | re.S)
        return m.group(1) if m else ""
    recipes = set(re.findall(r'^\t\t\[\d+\] = \{ name = "((?:[^"\\]|\\.)*)"', section("recipes"), re.M))
    training = set(re.findall(r'^\t\t\["((?:[^"\\]|\\.)*)"\] = ', section("training"), re.M))
    patterns = set(re.findall(r'^\t\t\["((?:[^"\\]|\\.)*)"\] = ', section("patterns"), re.M))
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
    seller_keys = ("vendor", "zone", "subZone", "faction", "mapID", "x", "y", "cost")
    sellers_of = lambda p: [{k: s.get(k) for k in seller_keys} for s in p["sellers"]]
    out += ["\t},", "\t-- recipe name = { itemID, price, skill, bound, side, rep = { faction, standing, side },",
            "\t--   sellers = { { vendor, zone, subZone, faction, mapID, x, y } } }: patterns vendors sell for gold;",
            "\t--   bound = binds when picked up; side = the only side that can get it",
            "\tpatterns = {"]
    for recipe in sorted(patterns):
        p = patterns[recipe]
        entry = {"itemID": p["itemID"], "price": p["price"], "skill": p["skill"], "bound": p["bound"] or None,
                 "side": p["side"], "rep": p["rep"], "sellers": sellers_of(p) or {}}
        out.append(f"\t\t[{lua_string(recipe)}] = {lua_value(entry)},")
    out += ["\t},", "\t-- recipe name = { itemID, skill, bound, side, rep, sellers = { { ..., cost } },",
            "\t--   quests = { { title, zone, side } }, drops = { { how, from, zone, drops, of } } }: patterns no vendor",
            "\t--   sells for gold (drops, quest and reputation rewards, token vendors); bound = binds when picked",
            "\t--   up (false: it can be traded; absent: the data doesn't say); side = the only side that can get it;",
            "\t--   otherCamp = the side whose trade camp sells it too, though players haven't recorded it there",
            "\totherPatterns = {"]
    for recipe in sorted(other):
        p = other[recipe]
        entry = {"itemID": p["itemID"], "skill": p["skill"], "bound": p["bound"], "side": p["side"], "rep": p["rep"],
                 "sellers": sellers_of(p), "otherCamp": p["otherCamp"], "quests": p["quests"], "drops": p["drops"]}
        out.append(f"\t\t[{lua_string(recipe)}] = {lua_value(entry)},")
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
