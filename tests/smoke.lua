-- Leprofit's scenarios, run by run_tests.py against the fake client (WM) with the real
-- Blacksmithing data loaded. Item IDs are the game's: 2840 Copper Bar, 2851 Copper Chain Belt,
-- 2835 Rough Stone, 2862 Rough Sharpening Stone, 3466 Strong Flux, 277019 Azure Skyforged Chain.
local function eq(a, b, msg)
	if a ~= b then error((msg or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end
local function ok(v, msg)
	if not v then error(msg or "expected true", 2) end
end
local function Find(name)
	for _, r in ipairs(ns.Recipes.List("Blacksmithing")) do
		if r.name == name then return r end
	end
end
local function Defaults()
	ns.ResetOptions()
	wipe(ns.db.hidden)
	wipe(ns.adb.vendorPrices)
	wipe(WM.auctionator)
	wipe(WM.ages)
	WM.SetTSM(nil)
	ns.DataChanged()
end

-- The module registered, and its recipes are listed one per name.
ok(ns.professions.Blacksmithing, "Blacksmithing is registered")
eq(ns.CurrentProfession(), "Blacksmithing", "the profession shown")
local list = ns.Recipes.List("Blacksmithing")
ok(#list > 400, "one recipe per name: " .. #list)
local names = {}
for _, r in ipairs(list) do
	ok(not names[r.name], "listed twice: " .. r.name)
	names[r.name] = true
end

-- Profit = lowest buyout less the 5% cut, less the materials.
WM.items[2840] = { name = "Copper Bar" }
WM.items[2851] = { name = "Copper Chain Belt", sellPrice = 200, quality = 2 }
WM.auctionator[2840] = 1000
WM.auctionator[2851] = 10000
local belt = Find("Copper Chain Belt")
eq(belt.source.kind, "trainer", "Copper Chain Belt is taught")
eq(belt.source.cost, 100, "its training cost")
local row = ns.Profit.Evaluate("Blacksmithing", belt)
eq(row.cost, 6000, "6 Copper Bars")
eq(row.value, 9500, "1g less 5%")
eq(row.via, "auction")
eq(row.profit, 3500, "profit")
eq(row.payback, 1, "the trainer's cost pays back in one craft")

-- The cut and the undercut.
ns.db.cut, ns.db.undercut = 10, 5
eq(ns.Profit.Evaluate("Blacksmithing", belt).value, 8550, "1g less 5% undercut less 10% cut")
ns.db.cut, ns.db.undercut = 5, 0

-- Ranking by market value needs TSM; without a market value the buyout is used.
ns.db.rankBy = "market"
eq(ns.Profit.Evaluate("Blacksmithing", belt).value, 9500, "no TSM: the buyout")
WM.SetTSM({ DBMarket = { [2851] = 20000 } })
row = ns.Profit.Evaluate("Blacksmithing", belt)
eq(row.market, 20000, "TSM's market value")
eq(row.buyout, 10000, "Auctionator's buyout still")
eq(row.value, 19000, "2g less 5%")
ns.db.rankBy = "buyout"
WM.SetTSM(nil)

-- A vendor's price beats the auction for materials.
ns.adb.vendorPrices[2840] = 500
eq(ns.Profit.Evaluate("Blacksmithing", belt).cost, 3000, "Copper Bars from a vendor")
ns.adb.vendorPrices[2840] = nil

-- Binds on pickup: it can't be posted, so a vendor's price.
WM.items[2851].bindType = 1
row = ns.Profit.Evaluate("Blacksmithing", belt)
eq(row.bop, true)
eq(row.via, "vendor")
eq(row.value, 200)
WM.items[2851].bindType = nil

-- A vendor paying more than the auction wins.
WM.auctionator[2851] = 100
row = ns.Profit.Evaluate("Blacksmithing", belt)
eq(row.via, "vendor", "the vendor pays more")
eq(row.value, 200)
WM.auctionator[2851] = 10000

-- A material nobody has a price for: no profit.
WM.auctionator[2840] = nil
row = ns.Profit.Evaluate("Blacksmithing", belt)
eq(row.missing, 2840, "the unpriced material")
eq(row.profit, nil, "no profit without a price")
WM.auctionator[2840] = 1000

-- Old auction prices are flagged.
WM.ages[2851] = 5
eq(ns.Profit.Evaluate("Blacksmithing", belt).stale, true, "5 days old")
WM.ages[2851] = 1
eq(ns.Profit.Evaluate("Blacksmithing", belt).stale, false, "1 day old")

-- The profession window: recipes you know are recorded, and one you know can make a material
-- cheaper than buying it.
WM.profession = "Blacksmithing"
WM.skills.Blacksmithing = 40
WM.recipes = {
	{ id = 2660, name = "Rough Sharpening Stone", learned = true, product = 2862, reagents = { { 2835, 1 } } },
	{ id = 2661, name = "Copper Chain Belt", learned = true, product = 2851, reagents = { { 2840, 6 } } },
	{ id = 990001, name = "Test Sharpened Thing", learned = true, product = 990002, min = 2, max = 4, reagents = { { 2862, 3 } } },
}
WM.Fire("TRADE_SKILL_SHOW")
WM.RunTimers()
eq(ns.db.recipes.Blacksmithing[2660].learned, true, "Rough Sharpening Stone recorded as known")
eq(ns.db.recipes.Blacksmithing[990001].yield, 3, "makes 2 to 4: 3 on average")
belt = Find("Copper Chain Belt")
eq(belt.source.kind, "known", "you know it now")
row = ns.Profit.Evaluate("Blacksmithing", belt)
eq(row.payback, nil, "nothing to pay back")

WM.items[990002] = { name = "Test Sharpened Thing" }
WM.auctionator[2835] = 100   -- Rough Stone
WM.auctionator[2862] = 1000  -- Rough Sharpening Stone, cheaper to make
WM.auctionator[990002] = 2000
local thing = Find("Test Sharpened Thing")
ok(thing, "a recipe only your window showed is listed")
row = ns.Profit.Evaluate("Blacksmithing", thing)
eq(row.materials[1].how, "craft", "the stones are crafted")
eq(row.cost, 300, "3 stones at 1 Rough Stone each")
eq(row.yield, 3)
eq(row.profit, 3 * 1900 - 300, "three items after the cut, less the stones")

-- The list: most profitable first; losses, hidden items and unknown sources left out.
local rows, left = ns.Profit.Rows("Blacksmithing")
ok(#rows >= 2, "profitable crafts listed: " .. #rows)
eq(rows[1].rec.name, "Test Sharpened Thing", "the most profitable first")
eq(rows[2].rec.name, "Copper Chain Belt")
ok(left.unknown > 300, "recipes with no known source left out: " .. left.unknown)
ok(left.losses > 0, "crafts without a price left out")
ns.db.hidden[990002] = true
rows, left = ns.Profit.Rows("Blacksmithing")
eq(rows[1].rec.name, "Copper Chain Belt", "marked doesn't sell")
eq(left.hidden, 1)
ns.db.showHidden = true
eq(ns.Profit.Rows("Blacksmithing")[1].rec.name, "Test Sharpened Thing", "shown again")
ns.db.showHidden, ns.db.hidden[990002] = false, nil
ns.db.showLosses = true
local all = ns.Profit.Rows("Blacksmithing")
ok(#all > #rows, "losses shown")
eq(all[#all].profit, nil, "the unpriced last")
ns.db.showLosses = false
ns.db.showUnknown = true
local _, left2 = ns.Profit.Rows("Blacksmithing")
eq(left2.unknown, 0, "unknown sources shown")
ns.db.showUnknown = false

-- Shopping for n crafts: what you hold is subtracted.
WM.items[2840].count = 10
local shop, spend = ns.Profit.Shopping(ns.Profit.Evaluate("Blacksmithing", belt), 3)
eq(shop[1].need, 18)
eq(shop[1].have, 10)
eq(shop[1].buy, 8)
eq(spend, 8000, "8 bars to buy")
WM.items[2840].count = nil

-- A pattern: its price, who sells it, and how many crafts pay it back.
local chain = Find("Azure Skyforged Chain")
eq(chain.source.kind, "pattern")
eq(chain.source.cost, 950)
eq(chain.source.sellers[1].vendor, "Vayn Moongaze")
WM.items[277019] = { name = "Azure Skyforged Chain" }
WM.auctionator[277019] = 6632 -- 6300 after the cut: 300 profit on 6000 of bars
row = ns.Profit.Evaluate("Blacksmithing", chain)
eq(row.profit, 300)
eq(row.payback, 4, "950 over 300 a craft")

-- A vendor: material prices and patterns are recorded.
WM.vendorName = "Smith Argus"
WM.merchant = {
	{ itemID = 3466, name = "Strong Flux", price = 4000, stack = 2 },
	{ itemID = 9999, name = "Not A Material", price = 100 },
	{ itemID = 2840, name = "Copper Bar", price = 800, available = 3 },
	{ itemID = 276955, name = "Plans: Azure Skyforged Chain", price = 900, available = 1 },
}
WM.printed = {}
WM.Fire("MERCHANT_SHOW")
eq(ns.adb.vendorPrices[3466], 2000, "Strong Flux for one")
eq(ns.adb.vendorPrices[9999], nil, "not a material")
eq(ns.adb.vendorPrices[2840], nil, "limited stock isn't a vendor price")
local pattern = ns.adb.patterns.Blacksmithing["Azure Skyforged Chain"]
eq(pattern.price, 900, "the pattern recorded")
eq(pattern.vendor, "Smith Argus")
chain = Find("Azure Skyforged Chain")
eq(chain.source.cost, 900, "your price wins")
eq(chain.source.sellers[1].vendor, "Smith Argus", "your seller first")
eq(#chain.source.sellers, 2)
ok(#WM.printed >= 2, "the pattern and the prices are announced")

-- A stale list right after switching windows: the window says Blacksmithing but lists another
-- profession's recipes. Leprofit.RegisterProfession adds a second module for the test.
Leprofit.RegisterProfession({ name = "Testcraft", recipes = {
	[880001] = { name = "A", product = 1, reagents = { { 2, 1 } } }, [880002] = { name = "B", product = 1, reagents = { { 2, 1 } } },
	[880003] = { name = "C", product = 1, reagents = { { 2, 1 } } }, [880004] = { name = "D", product = 1, reagents = { { 2, 1 } } },
	[880005] = { name = "E", product = 1, reagents = { { 2, 1 } } },
} })
local before = 0
for _ in pairs(ns.db.recipes.Blacksmithing) do before = before + 1 end
WM.recipes = {}
for id = 880001, 880005 do
	table.insert(WM.recipes, { id = id, name = "x" .. id, learned = true, product = 1, reagents = { { 2, 1 } } })
end
ns.Recorder.Record()
local after = 0
for _ in pairs(ns.db.recipes.Blacksmithing) do after = after + 1 end
eq(after, before, "another profession's list isn't recorded")
-- Detectors that disagree: nothing is recorded.
WM.profession = "Mining"
eq(ns.Recorder.OpenProfession(true), nil, "not a module's profession")

-- The window: both tabs build and refresh.
Defaults()
WM.auctionator[2840] = 1000
WM.auctionator[2851] = 10000
ns.db.profession = "Blacksmithing"
SlashCmdList.LEPROFIT("")
WM.RunTimers()
ok(ns.Window.IsShown(), "/leprofit opens the window")
ok(ns.Window.CurrentPanel(), "a page is shown")
local function Drawn(text)
	for _, f in ipairs(WM.frames) do
		if f.shown and type(f.name) == "table" and type(f.name.text) == "string" and f.name.text:find(text, 1, true) then return f end
	end
end
local beltRow = Drawn("Copper Chain Belt")
ok(beltRow, "the Crafts list shows Copper Chain Belt")
ok(beltRow.profit.text and beltRow.profit.text ~= "", "with its profit")
beltRow:Click()
ns.Window.Select("options")
ns.Window.Select("crafts")
SlashCmdList.LEPROFIT("")
ok(not ns.Window.IsShown(), "/leprofit closes it")
WM.printed = {}
SlashCmdList.LEPROFIT("status")
ok(#WM.printed >= 3, "status lines")
SlashCmdList.LEPROFIT("help")
SlashCmdList.LEPROFIT("nonsense")
ok(WM.printed[#WM.printed]:find("unknown command"), "unknown command")
SlashCmdList.LEPROFIT("reset")

-- No modules: the window explains what to enable.
local order = ns.professionOrder
ns.professionOrder = {}
ns.db.profession = nil
ns.Window.Show("crafts")
ns.Window.Refresh()
ns.professionOrder = order

-- The profession window's button opens Leprofit on that profession.
WM.profession = "Blacksmithing"
local host = WM.NewFrame("Frame", "ProfessionsFrame")
host.CloseButton = WM.NewFrame("Button", nil, host)
WM.Fire("TRADE_SKILL_SHOW")
WM.RunTimers()
local button
for _, f in ipairs(host.children) do
	if f.kind == "Button" and f ~= host.CloseButton then button = f end
end
ok(button, "a button on the profession window")
ns.Window.Hide()
ns.db.profession = "Testcraft"
button:Click()
ok(ns.Window.IsShown(), "it opens the window")
eq(ns.db.profession, "Blacksmithing", "on the open profession")
ns.db.professionButton = false
ns.ProfessionButton.Apply()
ok(not button:IsShown(), "the option hides it")

-- The minimap button.
LeprofitMinimapButton:Click("RightButton")
SlashCmdList.LEPROFIT("minimap")
ok(ns.db.minimap.hide, "/leprofit minimap hides the button")
Leprofit_OnAddonCompartmentClick(nil, "LeftButton")

-- run_tests.py checks the scenarios got this far.
WM.done = true
