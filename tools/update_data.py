"""leProfit's data updater: refreshes the built-in profession data on your own PC.

Double-click tools\\update_data.cmd (Windows), or run: python3 tools/update_data.py

It asks before each change. In order, it:

1. Gets the latest leProfit from GitHub (git pull), so you build on what's there.
2. Downloads Forever's newest game data and the player-recorded data: vendors, trainers, loot and
   quests (tools/fetch_sources.py; only what changed since the last run).
3. Adds what leProfit recorded in your game to tools/learned.json: trainer costs, patterns and
   who sells them, vendor prices. They're in WTF\\Account\\<account>\\SavedVariables\\leProfit.lua,
   which the game writes when you log out or /reload.
4. Rebuilds leProfit/Data/ (tools/gen_data.py) and lists what's new.
5. Runs the tests (it can install lupa, the one thing they need, into .venv).
6. Commits and pushes, if you say so, and can install it into the game.

Needs Python 3 and git, nothing else.
"""
import glob
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"
SOURCE = ROOT / ".source"
SETTINGS = SOURCE / "update_data.json"
sys.path.insert(0, str(TOOLS))

LINE = "=" * 78
STEP, STEPS = 0, 0


# Output and questions, in revtunnel's style --------------------------------------------------

def say(*lines):
    for line in lines:
        print(f"    {line}")


def dim(*lines):
    for line in lines:
        print(f"    \033[2m{line}\033[0m")


def ok(text):
    print(f"    \033[32m[ok]\033[0m   {text}")


def warn(text):
    print(f"    \033[33m[!]\033[0m    {text}")


def bad(text):
    print(f"    \033[31m[x]\033[0m    {text}")


def step(title, *details):
    global STEP
    STEP += 1
    print(f"\n\033[36mStep {STEP} of {STEPS}: {title}\033[0m")
    dim(*details)


def banner(title, *lines):
    print(f"\n\033[33m{LINE}\n  {title}\n{LINE}\033[0m")
    for line in lines:
        print(f"  {line}")
    print(f"\033[33m{LINE}\033[0m")


def ask(question, default):
    answer = input(f"    {question} [{default}]: ").strip()
    return answer or default


def ask_yn(question, default=False):
    hint = "Y/n" if default else "y/N"
    while True:
        answer = input(f"    {question} [{hint}]: ").strip().lower()
        if answer in ("y", "yes"):
            return True
        if answer in ("n", "no"):
            return False
        if answer == "":
            return default


def counted(n, word):
    """"1 pattern", "2 patterns"."""
    return f"{n} {word}{'' if n == 1 else 's'}"


def listed(names, most=12):
    """Names as one line, with "and N more" past `most`."""
    names = list(names)
    text = ", ".join(names[:most])
    return text + (f" and {len(names) - most} more" if len(names) > most else "")


# Settings: the WoW folder, remembered in the git-ignored .source/ -----------------------------

def load_settings():
    try:
        return json.loads(SETTINGS.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def save_settings(settings):
    SOURCE.mkdir(exist_ok=True)
    SETTINGS.write_text(json.dumps(settings, indent=1), encoding="utf-8")


def default_wow():
    """The WoW folder: the one used last, else the one tools\\install_forever.cmd installs into."""
    saved = load_settings().get("wow")
    if saved:
        return saved
    script = TOOLS / "install_forever.cmd"
    if script.exists():
        m = re.search(r'^set "WOW=(.+)"\s*$', script.read_text(encoding="utf-8", errors="replace"), re.M)
        if m:
            return m.group(1)
    return r"C:\Program Files (x86)\World of Warcraft\_forever_"


# WoW's SavedVariables files -------------------------------------------------------------------

class SavedVariablesError(ValueError):
    pass


def parse_saved_variables(text):
    """A SavedVariables file (lines of NAME = value, as WoW writes them) as {name: value}. Tables
    become dicts keyed as written (strings or numbers), nil becomes None."""
    pos, n = 0, len(text)
    token_re = re.compile(r'\s+|--[^\n]*|(-?(?:\d+\.?\d*(?:[eE][-+]?\d+)?|\.\d+))|([A-Za-z_][A-Za-z0-9_]*)|(")|([{}\[\]=,;])')

    def token():
        nonlocal pos
        while pos < n:
            m = token_re.match(text, pos)
            if not m:
                raise SavedVariablesError(f"unexpected {text[pos:pos + 20]!r} at {pos}")
            if m.group(1) is None and m.group(2) is None and m.group(3) is None and m.group(4) is None:
                pos = m.end()  # space or a comment
                continue
            if m.group(3):
                return "string", read_string(m.end())
            pos = m.end()
            if m.group(1):
                number = float(m.group(1))
                return "value", int(number) if number.is_integer() and "." not in m.group(1) and "e" not in m.group(1).lower() else number
            if m.group(2):
                word = m.group(2)
                if word in ("true", "false", "nil"):
                    return "value", {"true": True, "false": False, "nil": None}[word]
                return "name", word
            return m.group(4), None
        return "end", None

    escapes = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'", "\n": "\n", "a": "\a", "b": "\b", "f": "\f", "v": "\v"}

    def read_string(start):
        nonlocal pos
        out, i = [], start
        while i < n and text[i] != '"':
            c = text[i]
            if c == "\\" and i + 1 < n:
                e = text[i + 1]
                if e.isdigit():
                    digits = re.match(r"\d{1,3}", text[i + 1:]).group(0)
                    out.append(chr(int(digits)))
                    i += 1 + len(digits)
                    continue
                out.append(escapes.get(e, e))
                i += 2
                continue
            out.append(c)
            i += 1
        if i >= n:
            raise SavedVariablesError("a string doesn't end")
        pos = i + 1
        return "".join(out)

    def value(kind, v):
        if kind in ("value", "string"):
            return v
        if kind == "{":
            return table()
        raise SavedVariablesError(f"expected a value, got {kind} at {pos}")

    def table():
        nonlocal pos
        out, index = {}, 1
        while True:
            kind, v = token()
            if kind == "}":
                return out
            if kind in (",", ";"):
                continue
            if kind == "[":
                key = value(*token())
                if token()[0] != "]" or token()[0] != "=":
                    raise SavedVariablesError(f"expected ] = after a key at {pos}")
                out[key] = value(*token())
            elif kind == "name":
                save = pos
                if token()[0] == "=":
                    out[v] = value(*token())
                else:
                    raise SavedVariablesError(f"unexpected name {v!r} at {save}")
            else:
                out[index] = value(kind, v)
                index += 1

    result = {}
    while True:
        kind, name = token()
        if kind == "end":
            return result
        if kind != "name" or token()[0] != "=":
            raise SavedVariablesError(f"expected NAME = at {pos}")
        result[name] = value(*token())


def saved_files(wow):
    """leProfit's account-wide saved files under the WoW folder, one per account. The name before
    the rename (Leprofit.lua) counts too; on Windows they're the same file."""
    found = {}
    for name in ("leProfit.lua", "Leprofit.lua"):
        for path in glob.glob(os.path.join(wow, "WTF", "Account", "*", "SavedVariables", name)):
            found[os.path.normcase(os.path.abspath(path))] = path
    return sorted(found.values())


def number(v):
    if isinstance(v, float) and v.is_integer():
        return int(v)
    return round(v, 4) if isinstance(v, float) else v


SELLER_KEYS = ("vendor", "zone", "subZone", "faction", "mapID", "x", "y")


def merge_recorded(learned, db, game_items=None):
    """Adds one account's records (its leProfitDB) to learned.json's tables. game_items, if given,
    is the item IDs the game data names: names are only kept for the others. Returns how many
    trainer costs, patterns, vendor prices and item names were new or changed."""
    counts = {"training": 0, "patterns": 0, "vendorPrices": 0, "itemNames": 0}
    for prof, recipes in (db.get("training") or {}).items():
        for name, t in (recipes or {}).items():
            if not isinstance(t, dict) or not isinstance(t.get("cost"), (int, float)):
                continue
            entry = {"cost": number(t["cost"])}
            if isinstance(t.get("skill"), (int, float)) and t["skill"] > 0:
                entry["skill"] = number(t["skill"])
            if learned["training"].setdefault(prof, {}).get(name) != entry:
                learned["training"][prof][name] = entry
                counts["training"] += 1
    for prof, recipes in (db.get("patterns") or {}).items():
        for name, r in (recipes or {}).items():
            if not isinstance(r, dict) or not r.get("itemID"):
                continue
            old = learned["patterns"].setdefault(prof, {}).get(name)
            p = json.loads(json.dumps(old)) if old else {"itemID": int(r["itemID"]), "sellers": []}
            if isinstance(r.get("price"), (int, float)):
                p["price"] = number(r["price"])
            if r.get("vendor"):
                seller = {k: number(r[k]) for k in SELLER_KEYS if r.get(k) is not None}
                p["sellers"] = [seller] + [s for s in p.get("sellers", []) if s.get("vendor") != seller["vendor"]]
            if p != old:
                learned["patterns"][prof][name] = p
                counts["patterns"] += 1
    for item, price in (db.get("vendorPrices") or {}).items():
        if isinstance(item, (int, float)) and isinstance(price, (int, float)) and price > 0:
            key = str(int(item))
            if learned["vendorPrices"].get(key) != number(price):
                learned["vendorPrices"][key] = number(price)
                counts["vendorPrices"] += 1
    for item, name in (db.get("itemNames") or {}).items():
        if isinstance(item, (int, float)) and isinstance(name, str) and name:
            key = str(int(item))
            if (game_items is None or int(item) not in game_items) and learned["itemNames"].get(key) != name:
                learned["itemNames"][key] = name
                counts["itemNames"] += 1
    return counts


# Git and the steps ----------------------------------------------------------------------------

def git(*args, quiet=False):
    """Runs git in the repo; returns (exit code, output)."""
    r = subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True)
    out = (r.stdout + r.stderr).strip("\n")
    if not quiet and out:
        for line in out.splitlines():
            dim(line)
    return r.returncode, out


def file_hash(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None


def data_build():
    """The game build the committed data was built from, read from a data file's header."""
    path = ROOT / "leProfit" / "Data" / "Blacksmithing.lua"
    m = re.search(r"Forever build (\S+);", path.read_text(encoding="utf-8")) if path.exists() else None
    return m.group(1) if m else None


def downloaded():
    """The build downloaded into .source/ and when, or (None, None)."""
    build = SOURCE / "BUILD"
    if not build.exists() or not (SOURCE / "game" / "SkillLineAbility.csv").exists():
        return None, None
    import datetime
    when = datetime.date.fromtimestamp(build.stat().st_mtime).isoformat()
    return build.read_text(encoding="utf-8").strip(), when


def show_status():
    import gen_data
    say(f"Built-in data: Forever build {data_build() or 'unknown'}")
    build, when = downloaded()
    say(f"Downloaded: build {build}, on {when}" if build else "Downloaded: nothing yet")
    try:
        learned = gen_data.load_learned()
        say(f"tools/learned.json: {sum(map(len, learned['training'].values()))} trainer costs, "
            f"{sum(map(len, learned['patterns'].values()))} patterns, {len(learned['vendorPrices'])} vendor prices")
    except (gen_data.DataError, ValueError) as e:
        warn(f"tools/learned.json: {e}")


def get_latest(choice):
    step("Get the latest leProfit from GitHub",
         "So the update builds on what's there. Only what's pushed comes down.")
    if not shutil.which("git"):
        warn("git isn't installed, so this step is skipped.")
        return True
    before = file_hash(pathlib.Path(__file__))
    code, out = git("pull", "--ff-only")
    if code != 0:
        bad("git pull failed (see above).")
        # The usual reason: GitHub's history was rewritten, so this copy's last commit isn't in it
        # (merge-base exits 1 then, 128 when it can't tell).
        git("fetch", "origin", "--tags", "--force", quiet=True)
        if subprocess.run(["git", "-C", str(ROOT), "merge-base", "--is-ancestor", "HEAD", "@{u}"],
                          capture_output=True).returncode == 1:
            say("This copy and GitHub have different histories, usually because GitHub's was rewritten.",
                "To move this copy onto GitHub's, run these two commands, then this script again.",
                "They throw away commits and edits made in this copy that aren't on GitHub.",
                f'  git -C "{ROOT}" fetch origin --tags --force',
                f'  git -C "{ROOT}" reset --hard origin/main')
        return ask_yn("Carry on with this copy anyway?")
    ok("Up to date with GitHub.")
    if file_hash(pathlib.Path(__file__)) != before:
        say("This script was updated: starting the new one.")
        sys.exit(subprocess.call([sys.executable, str(pathlib.Path(__file__)), "--pulled", choice]))
    if "gen_data" in sys.modules:  # the pull may have changed it
        import importlib
        importlib.reload(sys.modules["gen_data"])
    return True


def download():
    import fetch_sources
    step("Download Forever's game data and the players' data",
         "From wago.tools (the game's data tables, for one client build) and Efficient Games (what",
         "players recorded: vendors, trainers, loot, quests; CC BY 4.0), into the .source folder.",
         "About 70 MB the first time; after that only what changed.")
    try:
        newest = fetch_sources.newest_build()
    except Exception as e:
        bad(f"Couldn't reach wago.tools: {e}")
        return False
    build = ask("Forever client build", newest)
    try:
        fetch_sources.fetch(build, say=dim)
    except Exception as e:
        bad(f"The download failed: {e}")
        return False
    ok(f"Downloaded build {build}.")
    return True


def add_recorded():
    import gen_data
    step("Add what leProfit recorded in your game",
         "Trainer costs, patterns and their sellers, and vendor prices, from each account's",
         "WTF\\Account\\<account>\\SavedVariables\\leProfit.lua. The game saves these when you log out",
         "or /reload, so do that first if you've just played.")
    wow = ask("Your WoW: Forever folder", default_wow())
    files = saved_files(wow)
    if not files:
        if not os.path.isdir(wow):
            warn(f"There's no folder {wow}.")
        else:
            warn("No leProfit saved files there yet (log in with leProfit installed, then log out).")
        return ask_yn("Carry on without them?", default=True)
    settings = load_settings()
    settings["wow"] = wow
    save_settings(settings)
    learned = gen_data.load_learned()
    try:
        game_items = gen_data.game_item_ids()
    except gen_data.DataError:
        game_items = None
    total = {"training": 0, "patterns": 0, "vendorPrices": 0, "itemNames": 0}
    for path in files:
        try:
            saved = parse_saved_variables(pathlib.Path(path).read_text(encoding="utf-8", errors="replace"))
        except SavedVariablesError as e:
            warn(f"Couldn't read {path}: {e}")
            continue
        for var in ("LeprofitDB", "leProfitDB"):  # the old name first, so the newer records win
            if isinstance(saved.get(var), dict):
                for k, v in merge_recorded(learned, saved[var], game_items).items():
                    total[k] += v
        dim(f"Read {path}")
    gen_data.save_learned(learned)
    ok(f"New or changed: {counted(total['training'], 'trainer cost')}, {counted(total['patterns'], 'pattern')}, "
       f"{counted(total['vendorPrices'], 'vendor price')}, {counted(total['itemNames'], 'item name')}.")
    return True


def rebuild():
    import gen_data
    step("Rebuild leProfit's data", "Writes leProfit/Data/<Profession>.lua from the downloads and tools/learned.json.")
    try:
        build, eg_builds, report = gen_data.generate()
    except gen_data.DataError as e:
        bad(str(e))
        return None
    for name, r in report.items():
        say(f"{name}: {counted(r['recipes'], 'recipe')}, {counted(r['training'], 'trainer cost')}, "
            f"{counted(r['patterns'], 'vendor pattern')}, {counted(r['otherPatterns'], 'other pattern')} "
            f"({r['tradeable']} tradeable)")
        for label, added, removed in zip(("recipes", "trainer costs", "patterns"), r["added"], r["removed"]):
            if added:
                dim(f"  new {label}: {listed(added)}")
            if removed:
                dim(f"  gone {label}: {listed(removed)}")
    ok(f"Built from Forever build {build} and player data from {eg_builds} builds.")
    return build


def venv_python():
    win = ROOT / ".venv" / "Scripts" / "python.exe"
    return win if win.exists() else ROOT / ".venv" / "bin" / "python"


def has_lupa(python):
    return python.exists() and subprocess.run([str(python), "-c", "import lupa"], capture_output=True).returncode == 0


def run_tests():
    step("Check it", "leProfit's tests load the addon with the new data into a fake game client.")
    python = venv_python()
    if not has_lupa(python):
        say("The tests need lupa (Lua for Python), in a .venv folder here (a few MB).")
        if not ask_yn("Set that up now?", default=True):
            warn("Tests skipped.")
            return None
        subprocess.run([sys.executable, "-m", "venv", str(ROOT / ".venv")])
        python = venv_python()
        subprocess.run([str(python), "-m", "pip", "install", "--quiet", "lupa"])
        if not has_lupa(python):
            bad("Couldn't install lupa (a very new Python may not have it yet), so the tests are skipped.")
            return None
    r = subprocess.run([str(python), str(ROOT / "tests" / "run_tests.py")], capture_output=True, text=True)
    for line in (r.stdout + r.stderr).strip().splitlines()[-15:]:
        dim(line)
    if r.returncode == 0:
        ok("The tests pass.")
        return True
    bad("The tests fail (see above): something in the new data doesn't fit.")
    return False


def save(build, tested):
    step("Save it", "Commit the new data and push it to GitHub, so it's in the next release.")
    if not shutil.which("git"):
        warn("git isn't installed: the new files are in leProfit/Data and tools/learned.json.")
        return
    _, changes = git("status", "--porcelain", "--", "leProfit/Data", "tools/learned.json", quiet=True)
    if not changes:
        ok("Nothing changed: the data was already up to date.")
        return
    for line in changes.splitlines():
        dim(line)
    if tested is False:
        warn("The tests failed, so committing isn't offered. Undo with: git checkout -- leProfit/Data tools/learned.json")
        return
    if tested is None and not ask_yn("The tests didn't run. Commit anyway?"):
        return
    if ask_yn("Commit the new data?", default=True):
        code, _ = git("add", "--", "leProfit/Data", "tools/learned.json")
        if code == 0:
            code, _ = git("commit", "-m", f"Update the data: Forever build {build}")
        if code != 0:
            bad("The commit failed (see above).")
            return
        ok("Committed.")
        if ask_yn("Push it to GitHub?", default=True):
            code, _ = git("push")
            if code == 0:
                ok("Pushed.")
            else:
                bad("The push failed (see above).")


def install():
    script = TOOLS / "install_forever.cmd"
    if os.name != "nt" or not script.exists():
        return
    if ask_yn("Install it into the game now (tools\\install_forever.cmd)?", default=True):
        subprocess.call(["cmd", "/c", str(script)])


def main():
    global STEPS
    if os.name == "nt":
        os.system("")  # turns on colours in the Windows console
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="replace")
    print("\033[36mleProfit update_data - refresh the built-in data from the game and what you recorded\033[0m")
    # After a pull that changed this script, the new one is started with --pulled and the choice.
    pulled = sys.argv[1:2] == ["--pulled"]
    print()
    show_status()
    have = downloaded()[0]
    if pulled and sys.argv[2:3]:
        choice = sys.argv[2]
    else:
        print()
        say("What would you like to do?")
        say("  1  Update everything: get the latest, download the game data, add what you recorded,",
            "     rebuild and test")
        if have:
            say(f"  2  The same without the download (use build {have}, already downloaded)")
        say(f"  {3 if have else 2}  Nothing (quit)")
        choice = ask("Choice", "3" if have else "2")
    if choice not in ("1", "2") or (choice == "2" and not have):
        return
    STEPS = (6 if choice == "1" else 5) - (1 if pulled else 0)
    if not pulled and not get_latest(choice):
        return
    if choice == "1" and not download():
        return
    if not add_recorded():
        return
    build = rebuild()
    if not build:
        return
    tested = run_tests()
    save(build, tested)
    if tested is not False:
        install()
    banner("DONE", "The data in leProfit/Data is up to date with Forever build " + build + ".",
           "Run this again after a Forever patch, or after visiting trainers and vendors.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print()
        warn("Stopped.")
        sys.exit(1)
