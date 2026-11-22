"""Download the source data tools/gen_data.py reads into .source/ (git-ignored).

Run it with no arguments: python3 tools/fetch_sources.py [client build]
(tools/update_data.py runs it for you.)

- Forever's game data tables (DB2) as CSV from wago.tools, for one client build (the newest
  wowf build by default): the recipes, what they make and from what, recipe items, item names,
  factions and zones.
- Efficient Games' player-recorded data for every Forever build, from
  github.com/JIVESCORP/eg-link-output-wowf (CC BY 4.0: the README credits it): vendors (who sells
  what, for how much, where), trainers (what they charge), loot (what drops from what), quests
  (their rewards), and the names of creatures, NPCs and objects. Its index says when each file
  last changed, so a file already here and unchanged isn't downloaded again.

A player file that fails to download or isn't JSON is skipped; gen_data.py works with whatever
player data it finds. Only the standard library is needed.
"""
import json
import pathlib
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / ".source"
GAME = SOURCE / "game"
EG = SOURCE / "eg"

WAGO = "https://wago.tools"
EG_RAW = "https://raw.githubusercontent.com/JIVESCORP/eg-link-output-wowf/main/data"
EG_PRODUCT = "wowf"

TABLES = ["SkillLineAbility", "SpellEffect", "SpellReagents", "SpellName", "ItemSparse", "ItemEffect",
          "ItemXItemEffect", "UiMap", "Faction", "AreaTable"]
EG_DATASETS = ["vendors", "npcs", "trainers", "loot", "quests.enUS", "creatures", "object_details.enUS"]


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "leProfit-data-tool"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def newest_build():
    builds = json.loads(get(f"{WAGO}/api/builds"))
    return max((b["version"] for b in builds.get("wowf", [])), key=lambda v: [int(x) for x in v.split(".")])


def fetch(build=None, say=print):
    """Downloads everything; returns the game build. say(text) reports progress."""
    GAME.mkdir(parents=True, exist_ok=True)
    EG.mkdir(parents=True, exist_ok=True)
    build = build or newest_build()
    say(f"Game data: Forever build {build}")
    for table in TABLES:
        data = get(f"{WAGO}/db2/{table}/csv?build={build}")
        if not data.startswith(b"ID,") and b",ID," not in data.split(b"\n", 1)[0]:
            raise RuntimeError(f"wago.tools didn't send {table} as CSV for build {build}")
        (GAME / f"{table}.csv").write_bytes(data)
        say(f"  {table}.csv ({len(data) // 1024} KB)")
    (SOURCE / "BUILD").write_text(build + "\n", encoding="utf-8")

    index = json.loads(get(f"{EG_RAW}/index.json"))
    builds = index.get("products", {}).get(EG_PRODUCT, {})
    seen_path = EG / "index.json"  # what each file here was, by the index, when it was downloaded
    try:
        seen = json.loads(seen_path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        seen = {}
    now, got, kept = {}, 0, 0
    for b, datasets in sorted(builds.items()):
        short = b.split(".")[-1]
        for ds in EG_DATASETS:
            info = datasets.get(ds)
            if not info:
                continue
            stamp = f"{info.get('lastCollectedOn')}/{info.get('records')}/{info.get('sources')}"
            path = EG / f"{ds}_{short}.json"
            if path.exists() and seen.get(b, {}).get(ds) == stamp:
                now.setdefault(b, {})[ds] = stamp
                kept += 1
                continue
            try:
                data = get(f"{EG_RAW}/{EG_PRODUCT}/{b}/{ds}.json")
                json.loads(data)
            except Exception as e:
                say(f"  skipped {b}/{ds}.json ({type(e).__name__})")
                continue
            path.write_bytes(data)
            now.setdefault(b, {})[ds] = stamp
            got += 1
    seen_path.write_text(json.dumps(now, indent=1), encoding="utf-8")
    say(f"Player data: {got} files downloaded, {kept} unchanged, from {len(builds)} builds")
    return build


def main():
    fetch(sys.argv[1] if len(sys.argv) > 1 else None)
    print("Done. Now run tools/gen_data.py.")


if __name__ == "__main__":
    main()
