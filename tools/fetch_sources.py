"""Download the source data tools/gen_data.py reads into .source/ (git-ignored).

Run it with no arguments: python3 tools/fetch_sources.py [client build]
(tools/update_data.py runs it for you.)

- Forever's game data tables (DB2) as CSV from wago.tools, for one client build (the newest
  wowf build by default): the recipes, what they make and from what, recipe items, item names.
- Efficient Games' player-recorded data (vendors and NPCs) for every Forever build, from
  github.com/JIVESCORP/eg-link-output-wowf (CC BY 4.0: the README credits it): who sells what,
  for how much, and where they stand.

Player files that fail to download or aren't JSON are skipped (not every build has both); gen_data.py works with
whatever player data it finds. Only the standard library is needed.
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
EG_API = "https://api.github.com/repos/JIVESCORP/eg-link-output-wowf/contents/data/wowf"
EG_RAW = "https://raw.githubusercontent.com/JIVESCORP/eg-link-output-wowf/main/data/wowf"

TABLES = ["SkillLineAbility", "SpellEffect", "SpellReagents", "SpellName", "ItemSparse", "ItemEffect",
          "ItemXItemEffect", "UiMap"]
EG_DATASETS = ["vendors", "npcs"]


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

    builds = [x["name"] for x in json.loads(get(EG_API)) if x["type"] == "dir"]
    got = 0
    for b in builds:
        short = b.split(".")[-1]
        for ds in EG_DATASETS:
            try:
                data = get(f"{EG_RAW}/{b}/{ds}.json")
                json.loads(data)
            except Exception:  # not every build has every dataset
                continue
            (EG / f"{ds}_{short}.json").write_bytes(data)
            got += 1
    say(f"Player data: {got} files from {len(builds)} builds")
    return build


def main():
    fetch(sys.argv[1] if len(sys.argv) > 1 else None)
    print("Done. Now run tools/gen_data.py.")


if __name__ == "__main__":
    main()
