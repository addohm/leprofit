"""Leprofit's checks: Lua 5.1 syntax, each addon's TOC file list, globals, and the scenarios in
smoke.lua against the fake client in wowmock.lua, with the core and every profession module loaded.

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
CORE = "Leprofit"
MODULES = sorted(p.name for p in ROOT.glob("Leprofit_*") if (p / f"{p.name}.toc").exists())
ALLOWED_GLOBALS = {"Leprofit", "LeprofitDB", "LeprofitCharDB", "LeprofitFrame", "LeprofitMinimapButton",
                   "LeprofitConfirm", "SLASH_LEPROFIT1", "Leprofit_OnAddonCompartmentClick"}

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
    if name != CORE and not re.search(r"^## Dependencies:\s*Leprofit\s*$", text, re.M):
        fail(f"{name}.toc doesn't depend on Leprofit")
    if name != CORE and not re.search(r"^## LoadOnDemand:\s*1\s*$", text, re.M):
        fail(f"{name}.toc isn't LoadOnDemand: 1 (Leprofit loads its modules itself)")
    if name != CORE and not re.search(r"^## X-Leprofit-Profession:\s*\S", text, re.M):
        fail(f"{name}.toc doesn't say which profession it's for (## X-Leprofit-Profession)")
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
modules = [(m, addon_chunks(m)) for m in MODULES]
if not MODULES:
    fail("no profession modules (Leprofit_<Profession>/)")

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
    fire = lua.globals().WM.Fire
    fire("ADDON_LOADED", CORE)
    # The modules are LoadOnDemand: the fake client lists them, and runs one only when Leprofit
    # asks C_AddOns.LoadAddOn for it, as the game does.
    def loader(m, chunks):
        def load():
            run(m, chunks, lua.table())
            fire("ADDON_LOADED", m)
        return load
    listed = []
    for m, chunks in modules:
        meta = {}
        for line in (ROOT / m / f"{m}.toc").read_text(encoding="utf-8").splitlines():
            if line.startswith("## ") and ":" in line:
                key, value = line[3:].split(":", 1)
                meta[key.strip()] = value.strip()
        listed.append(lua.table_from({"name": m, "meta": lua.table_from(meta), "load": loader(m, chunks)}))
    lua.globals().WM.addonList = lua.table_from(listed)
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

print("FAILED" if failed else f"OK: syntax, TOCs, globals and smoke scenarios ({CORE} + {', '.join(MODULES)})")
sys.exit(1 if failed else 0)
