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

-- Auctionator's history: the 14-day average, days seen, how many listed, and the trend.
WM.clock = 2001 -- a new moment, so the history is read again
WM.history[2851] = {
	{ rawDay = "2000", minSeen = 12000, maxSeen = 12500, available = 7 }, -- today
	{ rawDay = "1999", minSeen = 11000, maxSeen = 11000, available = 9 },
	{ rawDay = "1998", minSeen = 11000, maxSeen = 11000 },                -- the last 3 days: 11333
	{ rawDay = "1996", minSeen = 9000, maxSeen = 9000 },
	{ rawDay = "1994", minSeen = 9000, maxSeen = 9000 },                  -- the 4 before: 9000
	{ rawDay = "1980", minSeen = 1000, maxSeen = 1000 },                  -- over 14 days ago
}
local h = ns.Prices.History(2851)
eq(h.seen, 5, "listed on 5 of the last 14 days")
eq(h.average, 10400, "the 14-day average")
eq(h.listed, 7, "7 listed at the last scan")
eq(h.trend, 1, "going up")
row = ns.Profit.Evaluate("Blacksmithing", belt)
eq(row.market, 10400, "the average stands in for TSM's market value")
eq(row.seen, 5)
eq(row.listed, 7)
eq(row.trend, 1)
ns.db.rankBy = "market"
eq(ns.Profit.Evaluate("Blacksmithing", belt).value, 9880, "profit from the average: 10400 less 5%")
ns.db.rankBy = "buyout"
WM.SetTSM({ DBMarket = { [2851] = 20000 } })
eq(ns.Profit.Evaluate("Blacksmithing", belt).market, 20000, "TSM's market value wins when installed")
WM.SetTSM(nil)
WM.clock = 2002
WM.history[2851][1].minSeen, WM.history[2851][2].minSeen, WM.history[2851][3].minSeen = 9100, 8900, 9000
eq(ns.Prices.History(2851).trend, 0, "level within 5%")
WM.clock = 2003
WM.history[2851][1].minSeen = 5000
eq(ns.Prices.History(2851).trend, -1, "going down")
WM.clock = 2004
WM.history[2851] = { { rawDay = "2000", minSeen = 10000, maxSeen = 10000 } }
eq(ns.Prices.History(2851).trend, nil, "no trend from one day")
WM.clock = 2005
WM.history[2851] = nil
eq(ns.Prices.History(2851), nil, "no history")
eq(ns.Profit.Evaluate("Blacksmithing", belt).market, nil)
-- If Auctionator changes its insides, the history is just missing.
local database = Auctionator.Database
Auctionator.Database = nil
WM.clock = 2006
eq(ns.Prices.History(2851), nil, "no database, no history")
Auctionator.Database = database

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

-- Sorting: by any column, either way round; rows without a value go last.
ns.db.showLosses = true
ns.db.sortBy, ns.db.sortDesc = "cost", false
local sorted = ns.Profit.Rows("Blacksmithing")
for i = 2, #sorted do
	local a, b = sorted[i - 1].cost, sorted[i].cost
	if a and b then ok(a <= b, "cost low to high") end
	if not a then ok(not b, "rows without a cost last") end
end
eq(sorted[#sorted].cost, nil, "unpriced last")
ns.db.sortDesc = true
sorted = ns.Profit.Rows("Blacksmithing")
ok(sorted[1].cost >= sorted[2].cost, "cost high to low")
eq(sorted[#sorted].cost, nil, "unpriced still last")
ns.db.sortBy, ns.db.sortDesc = "item", false
sorted = ns.Profit.Rows("Blacksmithing")
for i = 2, #sorted do
	ok(ns.ItemName(sorted[i - 1].product):lower() <= ns.ItemName(sorted[i].product):lower(), "A to Z")
end
ns.db.sortBy, ns.db.sortDesc, ns.db.showLosses = "profit", true, false
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
eq(beltRow.h, 22, "one line per row")
local function TipHas(text)
	for _, line in ipairs(GameTooltip.lines) do
		if line:find(text, 1, true) then return true end
	end
end
beltRow.scripts.OnEnter(beltRow)
eq(GameTooltip.item, 2851, "the row's tooltip is the item's")
ok(TipHas("Cost (one craft) | 60s"), "then the cost")
ok(TipHas("Sells for after the 5% cut | 95s"), "what it sells for")
ok(TipHas("Profit | 35s"), "the profit")
ok(TipHas("Lowest buyout | 1g"), "the buyout")
ok(not TipHas("Trend"), "no history lines without history")
ok(TipHas("Shift-click to link it"), "and how to use it")
ns.db.showLosses = true
ns.Window.Refresh()
local maceRow = Drawn("Copper Mace")
ok(maceRow, "a recipe you'd learn, shown with the losses")
maceRow.scripts.OnEnter(maceRow)
ok(TipHas("Trainer 50c (skill 15)"), "its tooltip says where to learn it")
ns.db.showLosses = false
ns.Window.Refresh()
eq(beltRow.market.shown, false, "the Market column is off by default")
eq(ns.Window.CurrentPanel().header.market.shown, false, "and its heading")
ns.db.showMarket = true
ns.Window.Refresh()
eq(beltRow.market.shown, true, "Options turns it on")
eq(ns.Window.CurrentPanel().header.market.shown, true)
ns.db.showMarket = false
ns.Window.Refresh()
-- The history columns: each turned on in Options, placed between Buyout and Profit.
WM.clock = 3000
WM.history[2851] = {
	{ rawDay = "2000", minSeen = 10000, maxSeen = 10000, available = 4 },
	{ rawDay = "1995", minSeen = 9000, maxSeen = 9000 },
}
ns.db.showTrend, ns.db.showSeen, ns.db.showListed = true, true, true
ns.Window.Refresh()
eq(beltRow.seen.text, "2/14", "Seen")
beltRow.scripts.OnEnter(beltRow)
ok(TipHas("Seen | 2 of the last 14 days"), "the tooltip has the history")
ok(TipHas("Trend | going up"))
ok(TipHas("Listed at the last scan | 4"))
ok(TipHas("14-day average | 95s"))
eq(beltRow.listed.text, "4", "Listed")
ok(beltRow.trend.text:find("Arrow-Up", 1, true), "Trend: up")
eq(beltRow.cost.points[1][4], -(4 + 96 + 52 + 48 + 44 + 96), "Cost moves left of them")
local headings = ns.Window.CurrentPanel().header.buttons
eq(headings.seen.shown, true, "their headings sort too")
headings.seen:Click()
eq(ns.db.sortBy, "seen")
headings.profit:Click()
ns.db.showTrend, ns.db.showSeen, ns.db.showListed = false, false, false
WM.history[2851] = nil
WM.clock = 3001
ns.Window.Refresh()
eq(beltRow.seen.shown, false, "off again")
eq(beltRow.cost.text, "60s", "the Cost column: 6 Copper Bars at 10s")
eq(beltRow.cost.points[1][4], -(2 * 96 + 4), "Cost left of Buyout and Profit")
eq(beltRow.profit.points[1][4], -4, "Profit at the right edge")

-- The headings sort the list: click one, then again to reverse; an arrow marks it.
local header = ns.Window.CurrentPanel().header
ok(header.profit.text:find("Arrow-Down", 1, true), "Profit sorts, highest first")
header.buttons.cost:Click()
eq(ns.db.sortBy, "cost")
eq(ns.db.sortDesc, true, "money columns start highest first")
ok(header.cost.text:find("Arrow-Down", 1, true), "the arrow moves to Cost")
eq(header.profit.text, "Profit", "and leaves Profit")
header.buttons.cost:Click()
eq(ns.db.sortDesc, false, "again: reversed")
ok(header.cost.text:find("Arrow-Up", 1, true), "lowest first")
header.buttons.item:Click()
eq(ns.db.sortBy, "item")
eq(ns.db.sortDesc, false, "Item starts A to Z")
ok(header.item.text:find("Arrow-Up", 1, true))
eq(header.buttons.market.shown, false, "no Market heading while the column is off")
header.buttons.profit:Click()
eq(ns.db.sortBy, "profit")
eq(ns.db.sortDesc, true)

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

-- The shopping list: Add to list in the materials panel, the Shopping tab, Send to Auctionator.
local function Said(text)
	for _, line in ipairs(WM.printed) do
		if line:find(text, 1, true) then return true end
	end
end
beltRow:Click()
ns.db.crafts = 3
ShownButton("Add to list"):Click()
eq(#ns.db.plan, 1, "a craft planned")
eq(ns.db.plan[1].count, 3, "as many as the Crafts box says")
eq(ns.db.plan[1].prof, "Blacksmithing")
ShownButton("Add to list"):Click()
eq(#ns.db.plan, 1, "the same craft again")
eq(ns.db.plan[1].count, 6, "adds more")
ns.Shopping.Add("Blacksmithing", Find("Rough Sharpening Stone"), 4)
ns.adb.vendorPrices[2835] = 20
WM.items[2835] = { name = "Rough Stone" }
WM.items[2840].count = 10
local plannedCrafts, mats, total = ns.Shopping.Build()
eq(#plannedCrafts, 2)
eq(mats[1].itemID, 2840, "Copper Bar first, the dearest")
eq(mats[1].need, 36, "6 crafts x 6 bars")
eq(mats[1].buy, 26, "less the 10 you hold")
eq(mats[1].cost, 26000)
eq(mats[2].itemID, 2835)
eq(mats[2].vendor, true, "Rough Stone from a vendor")
eq(total, 26080, "the gold to spend")
WM.printed = {}
eq(ns.Shopping.SendToAuctionator(), 1, "one item to Auctionator")
local list = WM.lists.Leprofit
eq(#list, 1)
ok(list[1]:find('"Copper Bar"', 1, true) and list[1]:find("26$"), "Copper Bar, 26 of them: " .. list[1])
ok(Said("Left out because a vendor sells them: Rough Stone"), "the vendor item is named instead")
-- A material nobody has a price for: the total says so.
WM.auctionator[2840] = nil
local _, _, noTotal, priced = ns.Shopping.Build()
eq(noTotal, nil, "no total without every price")
eq(priced, 80, "what has a price")
WM.auctionator[2840] = 1000
-- The tab: its rows, a count changed, Remove, and Clear (after asking).
ns.Window.Select("shopping")
local removeButton = ShownButton("Remove")
ok(removeButton, "each planned craft has Remove")
ns.Shopping.SetCount(1, 2)
eq(ns.db.plan[1].count, 2, "a new count")
ns.Shopping.SetCount(2, 0)
eq(#ns.db.plan, 1, "a count of 0 removes it")
ns.Window.Refresh()
local clearButton = ns.Window.CurrentPanel().clear
clearButton:Click()
local confirm = ns.ConfirmDialog()
ok(confirm:IsShown(), "Clear asks first")
confirm.cancel:Click()
eq(#ns.db.plan, 1, "Cancel keeps the list")
clearButton:Click()
confirm.accept:Click()
eq(#ns.db.plan, 0, "Clear empties it")
ns.Window.Refresh()
WM.printed = {}
eq(ns.Shopping.SendToAuctionator(), 0, "nothing to send")
ok(Said("nothing to buy"), "and it says so")
WM.items[2840].count = nil
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
ok(Printed("Lowest buyout 1g, 14-day average "), "the buyout and the average")
ok(Printed("Auctionator: no price history for it"), "the history line")
WM.history[2851] = {
	{ rawDay = "1999", minSeen = 10000, maxSeen = 10000, available = 3 },
	{ rawDay = "1995", minSeen = 8000, maxSeen = 8000 },
}
WM.clock, WM.printed = 4000, {}
SlashCmdList.LEPROFIT("why Copper Chain Belt")
ok(Printed("Auctionator: listed on 2 of the last 14 days, 3 listed at the last scan (1 day ago), prices going up"), "the history in words")
ok(Printed("14-day average 90s"), "and the average")
WM.history[2851], WM.clock = nil, 4001
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
