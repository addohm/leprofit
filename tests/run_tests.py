"""leProfit's checks: Lua 5.1 syntax, each addon's TOC file list, globals, the scenarios in
smoke.lua against the fake client in wowmock.lua, and the data tools' SavedVariables reader and
merge (tools/update_data.py).

Run: .venv/bin/python tests/run_tests.py   (needs lupa: python3 -m venv .venv && .venv/bin/pip install lupa)
"""
import pathlib
import re
import sys

try:
    from lupa import lua51
except ImportError:
    sys.exit("lupa is not installed: python3 -m venv .venv && .venv/bin/pip install lupa")

ROOT = pathlib.Path(__file__).resolve().parent.parent
TESTS = ROOT / "tests"
CORE = "leProfit"
ALLOWED_GLOBALS = {"Leprofit", "leProfitDB", "leProfitCharDB", "leProfitFrame", "leProfitMinimapButton",
                   "leProfitConfirm", "SLASH_LEPROFIT1", "leProfit_OnAddonCompartmentClick"}

OPTIONAL_GLOBALS = {"GetTradeSkillLine", "GetMerchantItemInfo", "GetProfessions", "GetProfessionInfo",
                    "GetCoinTextureString", "GetItemCount", "GetItemInfo", "issecretvalue", "TSM_API"}

failed = False


def fail(msg):
    global failed
    failed = True
    print("FAIL " + msg)


lua = lua51.LuaRuntime(unpack_returned_tuples=True)
compile_chunk = lua.eval("function(src, name) local f, err = loadstring(src, '@' .. name) return f or false, err end")
version = None


def addon_chunks(name):
    """Checks an addon's TOC against its files, compiles them, and returns them in TOC order."""
    global version
    folder = ROOT / name
    text = (folder / f"{name}.toc").read_text(encoding="utf-8")
    v = re.search(r"^## Version:\s*(\S+)", text, re.M)
    if not v:
        fail(f"{name}.toc has no ## Version")
    elif version is None:
        version = v.group(1)
    elif v.group(1) != version:
        fail(f"{name}.toc is version {v.group(1)}, the core is {version}")
    toc = [line.strip().replace("\\", "/") for line in text.splitlines()
           if line.strip().endswith(".lua") and not line.startswith("#")]
    on_disk = sorted(str(p.relative_to(folder)) for p in folder.rglob("*.lua"))
    for f in on_disk:
        if f not in toc:
            fail(f"{name}/{f} is not in {name}.toc")
    chunks = []
    for f in toc:
        path = folder / f
        if not path.exists():
            fail(f"{name}.toc lists {f}, which doesn't exist")
            continue
        chunk, err = compile_chunk(path.read_text(encoding="utf-8"), f"{name}/{f}")
        if not chunk:
            fail(err)
        else:
            chunks.append((f, chunk))
    return chunks


core = addon_chunks(CORE)

if not failed:
    lua.globals().WM = lua.execute((TESTS / "wowmock.lua").read_text(encoding="utf-8"))
    names = lua.eval("function() local t = {} for k in pairs(_G) do t[#t+1] = k end return t end")
    before = set(names().values())
    ns = lua.table()

    def run(addon, chunks, namespace):
        for f, chunk in chunks:
            try:
                chunk(addon, namespace)
            except Exception as e:
                fail(f"loading {addon}/{f}: {e}")

    run(CORE, core, ns)
    # Settings saved before the rename to leProfit, which the game loads before ADDON_LOADED: they
    # should move to the new names (smoke.lua checks), leaving no old global behind.
    lua.execute('LeprofitCharDB = { carried = "character" } LeprofitDB = { carried = "account" }')
    fire = lua.globals().WM.Fire
    fire("ADDON_LOADED", CORE)
    fire("PLAYER_LOGIN")
    after = set(names().values())
    for g in sorted(after - before - ALLOWED_GLOBALS):
        fail(f"unexpected global {g}")
    lua.globals().ns = ns
    # Reading a global nobody defined is usually a typo. These are real WoW functions the fake
    # client leaves out, which the addon only calls when they exist.
    optional = lua.table_from({n: True for n in OPTIONAL_GLOBALS})
    lua.execute("""
        local optional = ...
        WM.unknownGlobals = {}
        setmetatable(_G, { __index = function(_, k)
            if not optional[k] then WM.unknownGlobals[k] = true end
        end })
    """, optional)
    try:
        smoke, err = compile_chunk((TESTS / "smoke.lua").read_text(encoding="utf-8"), "smoke.lua")
        if not smoke:
            raise RuntimeError(err)
        smoke()
        if not lua.globals().WM.done:
            fail("smoke.lua stopped before the end")
        for k in sorted(lua.globals().WM.unknownGlobals.keys()):
            fail(f"read an undefined global: {k}")
    except Exception as e:
        fail(f"smoke.lua: {e}")

# The data tools: reading WoW's SavedVariables files and adding leProfit's records to learned.json.
sys.path.insert(0, str(ROOT / "tools"))
try:
    import update_data as ud

    saved = ud.parse_saved_variables(r'''
leProfitDB = {
["vendorPrices"] = {
[3466] = 2000,
[2880] = 12.5,
},
["itemNames"] = {
[3466] = "Strong Flux",
[999001] = "A \"New\" Item\\",
},
["patterns"] = {
["Blacksmithing"] = {
["Azure Skyforged Chain"] = {
["itemID"] = 276955,
["price"] = 900,
["vendor"] = "Smith Argus",
["faction"] = "Alliance",
["mapID"] = 1453,
["x"] = 0.6420000195503235,
["y"] = -0.25,
},
},
},
["training"] = {
["Blacksmithing"] = {
["Copper Chain Pants"] = {
["cost"] = 60,
["skill"] = 20,
},
},
["Mining"] = {
["Smelt Copper"] = {
["cost"] = 25,
},
},
},
["list"] = {
"a", -- [1]
true, -- [2]
},
}
LeprofitDB = nil
''')
    db = saved["leProfitDB"]
    if saved.get("LeprofitDB", 0) is not None or db["list"] != {1: "a", 2: True}:
        fail("parse_saved_variables: nil or a list read wrong")
    if db["itemNames"][999001] != 'A "New" Item\\' or db["vendorPrices"][2880] != 12.5:
        fail("parse_saved_variables: a string or number read wrong")
    learned = {"training": {"Blacksmithing": {"Copper Chain Pants": {"cost": 50, "skill": 15}}},
               "patterns": {"Blacksmithing": {"Azure Skyforged Chain": {"itemID": 276955, "price": 1000,
                            "sellers": [{"vendor": "Smith Argus", "zone": "Old"}, {"vendor": "Other"}]}}},
               "vendorPrices": {"3466": 2000}, "itemNames": {}, "extraRecipes": {}}
    counts = ud.merge_recorded(learned, db, game_items={3466})
    if counts != {"training": 2, "patterns": 1, "vendorPrices": 1, "itemNames": 1}:
        fail(f"merge_recorded counts: {counts}")
    chain = learned["patterns"]["Blacksmithing"]["Azure Skyforged Chain"]
    if (chain["price"] != 900 or [s["vendor"] for s in chain["sellers"]] != ["Smith Argus", "Other"]
            or chain["sellers"][0].get("zone") or chain["sellers"][0]["x"] != 0.642):
        fail(f"merge_recorded: the pattern {chain}")
    if (learned["training"]["Blacksmithing"]["Copper Chain Pants"] != {"cost": 60, "skill": 20}
            or learned["training"]["Mining"]["Smelt Copper"] != {"cost": 25}):
        fail("merge_recorded: trainer costs")
    if learned["vendorPrices"].get("2880") != 12.5 or list(learned["itemNames"]) != ["999001"]:
        fail("merge_recorded: vendor prices or item names")
    if ud.merge_recorded(learned, db, game_items={3466}) != {"training": 0, "patterns": 0, "vendorPrices": 0, "itemNames": 0}:
        fail("merge_recorded: adding the same records twice changed something")
except Exception as e:
    fail(f"the data tools: {type(e).__name__}: {e}")

print("FAILED" if failed else "OK: syntax, the TOC, globals, smoke scenarios and the data tools")
sys.exit(1 if failed else 0)
