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

-- Auctionator's record of what vendors charge counts as a vendor price.
WM.auctionatorVendor[2840] = 700
eq(ns.Profit.Evaluate("Blacksmithing", belt).cost, 4200, "Copper Bars at Auctionator's vendor price")
WM.auctionatorVendor[2840] = nil

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
ok(left.unpriced > 0, "crafts without a price left out")
eq(left.losses, 0, "and counted apart from losses")
ns.db.hidden[990002] = true
rows, left = ns.Profit.Rows("Blacksmithing")
eq(rows[1].rec.name, "Copper Chain Belt", "marked doesn't sell")
eq(left.hidden, 1)
ns.db.hidden[990002] = nil
eq(ns.Profit.Rows("Blacksmithing")[1].rec.name, "Test Sharpened Thing", "unhidden")
-- Known only: the recipes you'd have to learn are left out, and counted.
ns.db.showLosses = true
ns.db.knownOnly = true
rows, left = ns.Profit.Rows("Blacksmithing")
for _, r in ipairs(rows) do eq(r.rec.source.kind, "known", "known only: " .. r.rec.name) end
eq(#rows, 3, "the three recipes the window showed")
ok(left.unlearned > 50, "the rest counted: " .. left.unlearned)
ns.db.knownOnly, ns.db.showLosses = false, false
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

-- Learning a recipe marks it known straight away.
WM.profession = nil
eq(Find("Copper Chain Pants").source.kind, "trainer")
WM.Fire("NEW_RECIPE_LEARNED", 2662)
eq(ns.db.recipes.Blacksmithing[2662].learned, true, "Copper Chain Pants learned")
eq(Find("Copper Chain Pants").source.kind, "known", "and listed as known")
eq(ns.Recorder.KnownCount("Blacksmithing"), 4)

-- The window: both tabs build and refresh.
Defaults()
WM.auctionator[2840] = 1000
WM.auctionator[2851] = 10000
ns.db.profession = "Blacksmithing"
SlashCmdList.LEPROFIT("")
WM.RunTimers()
ok(ns.Window.IsShown(), "/leprofit opens the window")
eq(#WM.opened, 1, "and the profession window")
eq(WM.opened[1], 164, "Blacksmithing's")
ok(ns.Window.CurrentPanel(), "a page is shown")
local function Drawn(text)
	for _, f in ipairs(WM.frames) do
		if f.shown and type(f.name) == "table" and type(f.name.text) == "string" and f.name.text:find(text, 1, true) then return f end
	end
end
local beltRow = Drawn("Copper Chain Belt")
ok(beltRow, "the Crafts list shows Copper Chain Belt")
ok(beltRow.profit.text and beltRow.profit.text ~= "", "with its profit")
eq(beltRow.market.shown, false, "the Market column is off by default")
eq(ns.Window.CurrentPanel().header.market.shown, false, "and its heading")
ns.db.showMarket = true
ns.Window.Refresh()
eq(beltRow.market.shown, true, "Options turns it on")
eq(ns.Window.CurrentPanel().header.market.shown, true)
ns.db.showMarket = false
ns.Window.Refresh()
eq(beltRow.cost.text, "60s", "the Cost column: 6 Copper Bars at 10s")
eq(beltRow.cost.points[1][4], -(2 * 96 + 4), "Cost left of Buyout and Profit")
eq(beltRow.profit.points[1][4], -4, "Profit at the right edge")

-- Shift-click links the item; a plain click picks the row.
WM.modifier = "CHATLINK"
beltRow:Click()
ok(WM.linked[#WM.linked]:find("item:2851", 1, true), "shift-click links the crafted item")
local function MaterialRowFor(itemID)
	for _, f in ipairs(WM.frames) do
		if f.kind == "Button" and f.itemID == itemID and f.shown then return f end
	end
end
local barRow = MaterialRowFor(2840)
ok(barRow, "the materials panel lists Copper Bar")
barRow:Click()
ok(WM.linked[#WM.linked]:find("item:2840", 1, true), "shift-click links a material")
-- Without the game's handler, the link goes in the chat box.
local handler = HandleModifiedItemClick
HandleModifiedItemClick = nil
local inserted
ChatFrameUtil = { InsertLink = function(link) inserted = link end }
barRow:Click()
ok(inserted and inserted:find("item:2840", 1, true), "into the chat box")
HandleModifiedItemClick, ChatFrameUtil = handler, nil
WM.modifier = nil
beltRow:Click()
local function ShownButton(text)
	for _, f in ipairs(WM.frames) do
		if f.kind == "Button" and f.shown and f.text == text then return f end
	end
end

-- Doesn't sell asks first: Cancel leaves the item listed, Hide hides it.
local selectedItem = beltRow.product
ShownButton("Doesn't sell"):Click()
local dialog = ns.ConfirmDialog()
ok(dialog and dialog:IsShown(), "Doesn't sell asks first")
ok(dialog.text.text:find("Copper Chain Belt", 1, true), "naming the item")
eq(ns.db.hidden[selectedItem], nil, "nothing hidden yet")
dialog.cancel:Click()
ok(not dialog:IsShown(), "Cancel closes it")
eq(ns.db.hidden[selectedItem], nil, "Cancel hides nothing")
ShownButton("Doesn't sell"):Click()
dialog.accept:Click()
eq(ns.db.hidden[selectedItem], true, "Hide hides it")
ok(not dialog:IsShown(), "and closes the dialog")

-- Options lists it with an Unhide button.
ns.Window.Select("options")
local unhide = ShownButton("Unhide")
ok(unhide, "the hidden item has an Unhide button")
unhide:Click()
eq(ns.db.hidden[selectedItem], nil, "Unhide brings it back")
ns.db.hidden[2851], ns.db.hidden[2862] = true, true
ns.Window.Refresh()
ShownButton("Unhide all"):Click()
eq(next(ns.db.hidden), nil, "Unhide all")
ns.Window.Select("crafts")
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

-- /leprofit why: the whole sum for one craft, by name, link or part of a name.
local function Printed(text)
	for _, line in ipairs(WM.printed) do
		if line:find(text, 1, true) then return true end
	end
end
WM.printed = {}
SlashCmdList.LEPROFIT("why Copper Chain Belt")
ok(Printed("6 x Copper Bar: 10s each (auction) = 60s"), "each material and its price")
ok(Printed("Lowest buyout 1g, a vendor pays 2s"), "the buyout, no market value with the column off")
ok(Printed("Sells for 95s each after 5% cut, by lowest buyout"), "the sale")
ok(Printed("Profit: 35s a craft"), "the profit")
WM.printed = {}
SlashCmdList.LEPROFIT("why |cff1eff00|Hitem:2851::::::::|h[Copper Chain Belt]|h|r")
ok(Printed("Copper Chain Belt|r (Blacksmithing, you know it)"), "a shift-clicked link")
WM.printed = {}
SlashCmdList.LEPROFIT("why copper")
ok(Printed("recipes match"), "part of a name lists the matches")
WM.printed = {}
SlashCmdList.LEPROFIT("why zzzz")
ok(Printed("no recipe"), "nothing matches")
WM.printed = {}
WM.auctionator[2835] = 100 -- Rough Stone, so the stones can be crafted
SlashCmdList.LEPROFIT("why Test Sharpened")
ok(Printed("crafted with Rough Sharpening Stone"), "a crafted material says how")

-- Recipes not read yet: Known only explains instead of saying nothing makes a profit.
local saved = ns.db.recipes.Blacksmithing
ns.db.recipes.Blacksmithing = {}
ns.db.knownOnly = true
ns.DataChanged()
ns.Window.Show("crafts")
ns.Window.Refresh()
eq(ns.Recorder.KnownCount("Blacksmithing"), 0)
ns.db.recipes.Blacksmithing, ns.db.knownOnly = saved, false
ns.DataChanged()
ns.Window.Hide()

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
local openedBefore = #WM.opened
button:Click()
ok(ns.Window.IsShown(), "it opens the window")
eq(ns.db.profession, "Blacksmithing", "on the open profession")
eq(#WM.opened, openedBefore, "the profession window is already open")
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
