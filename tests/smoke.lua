-- leProfit's scenarios, run by run_tests.py against the fake client (WM) with the real
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

-- Settings saved before the rename to leProfit (run_tests.py loads some, as the game would) carry
-- over to the new names, and the old ones are cleared.
eq(ns.db, leProfitCharDB, "the settings are leProfitCharDB")
eq(ns.db.carried, "character", "the character's old settings carried over")
eq(ns.adb.carried, "account", "the account's old records carried over")
eq(rawget(_G, "LeprofitCharDB"), nil, "the old per-character settings cleared")
eq(rawget(_G, "LeprofitDB"), nil, "the old account records cleared")
-- Once moved, a stray old copy doesn't replace them.
LeprofitCharDB = { carried = "stale" }
WM.Fire("ADDON_LOADED", "leProfit")
eq(ns.db.carried, "character", "the new settings stay")
eq(rawget(_G, "LeprofitCharDB"), nil, "the stray copy cleared")
ns.db.carried, ns.adb.carried = nil, nil

-- Every profession is built in. Old Leprofit 1.0 module folders, if they're still installed,
-- call Leprofit.RegisterProfession: that's ignored.
eq(#ns.professionOrder, 9, "nine professions built in")
Leprofit.RegisterProfession({ name = "Old module", recipes = {} })
eq(ns.professions["Old module"], nil, "an old module is ignored")

-- The module registered, and its recipes are listed one per name.
ok(ns.professions.Blacksmithing, "Blacksmithing is registered")
eq(ns.CurrentProfession(), ns.professionOrder[1], "the first module shown at first")

-- Every module: registered, recipes that make something from something, no recipe in two
-- professions, and a skill line for opening its window.
local PROFESSIONS = { "Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering", "First Aid", "Leatherworking", "Mining", "Tailoring" }
eq(#ns.professionOrder, #PROFESSIONS, "all nine professions")
local owner, shared = {}, 0
for i, name in ipairs(PROFESSIONS) do
	eq(ns.professionOrder[i], name, "in alphabetical order")
	local def = ns.professions[name]
	local n = 0
	for id, r in pairs(def.recipes) do
		n = n + 1
		ok(r.name and r.product and #r.reagents > 0, name .. " recipe " .. id .. " makes something from something")
		if owner[id] then shared = shared + 1 end
		owner[id] = name
	end
	ok(n > 15, name .. " has recipes: " .. n) -- Mining has the fewest: 18, its smelting
	ok(#ns.Recipes.List(name) > 0, name .. " lists them")
end
-- A few recipes are listed by several professions (Forever's camp and home items); more than a
-- handful would mean a data refresh went wrong.
ok(shared <= 16, "recipes listed by more than one profession: " .. shared)

-- Which recipes the character knows comes from the game (IsPlayerSpell), no window needed.
local function KnownIn(prof, name)
	for _, r in ipairs(ns.Recipes.List(prof)) do
		if r.name == name then return r.learned and true or false end
	end
end
eq(KnownIn("Tailoring", "Linen Cloak"), false, "not known")
WM.spells[2387] = true -- Linen Cloak
WM.Fire("SPELLS_CHANGED")
eq(KnownIn("Tailoring", "Linen Cloak"), true, "known once the game says so, with no window read")
eq(ns.Recorder.KnownCount("Tailoring"), 1)
WM.spells[2387] = nil
WM.Fire("SPELLS_CHANGED")
eq(KnownIn("Tailoring", "Linen Cloak"), false)
WM.opened = {}
ns.db.profession = "Blacksmithing"
eq(ns.CurrentProfession(), "Blacksmithing", "the profession picked")
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
local savedProf = ns.db.profession
ns.db.profession = nil
eq(ns.CurrentProfession(), "Blacksmithing", "with nothing picked, the first profession this character has")
ns.db.profession = savedProf
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

-- Smelting: the smelting window (the game may call it Smelting) gives Mining's recipes, and a bar
-- you can smelt costs its ore in Blacksmithing's sums when that's cheaper.
WM.profession = "Smelting"
eq(ns.Recorder.OpenProfession(true), "Mining", "the smelting window is Mining's")
WM.skills.Mining = 30
WM.recipes = {
	{ id = 2657, name = "Smelt Copper", learned = true, product = 2840, reagents = { { 2770, 1 } } },
	{ id = 3304, name = "Smelt Tin", learned = false, product = 3576, reagents = { { 2771, 1 } } },
}
ns.Recorder.Record()
eq(ns.db.recipes.Mining[2657].learned, true, "Smelt Copper recorded under Mining")
eq(ns.db.recipes.Blacksmithing[2657], nil, "and not under Blacksmithing")
local smeltCopper
for _, r in ipairs(ns.Recipes.List("Mining")) do if r.name == "Smelt Copper" then smeltCopper = r end end
ok(smeltCopper, "Mining lists it")
WM.items[2770] = { name = "Copper Ore" }
WM.auctionator[2770] = 400
row = ns.Profit.Evaluate("Mining", smeltCopper)
eq(row.cost, 400, "a bar from one ore")
eq(row.profit, 950 - 400, "the bar after the cut, less the ore")
belt = Find("Copper Chain Belt")
row = ns.Profit.Evaluate("Blacksmithing", belt)
eq(row.materials[1].how, "craft", "Blacksmithing smelts its bars")
eq(row.materials[1].option.prof, "Mining", "with Mining")
eq(row.cost, 2400, "6 bars at their ore's price")
WM.auctionator[2770] = 2000
eq(ns.Profit.Evaluate("Blacksmithing", belt).materials[1].how, "auction", "buys them when that's cheaper")
WM.auctionator[2770] = 400
WM.printed = {}
SlashCmdList.LEPROFIT("why Copper Chain Belt")
local saidSmelt = false
for _, line in ipairs(WM.printed) do
	if line:find("crafted with Smelt Copper (Mining)", 1, true) then saidSmelt = true end
end
ok(saidSmelt, "why names the smelting")
WM.auctionator[2770] = nil
-- A stale smelting list read as Blacksmithing isn't recorded there.
WM.profession = "Blacksmithing"
ns.Recorder.Record()
eq(ns.db.recipes.Blacksmithing[2657], nil, "smelting stays with Mining")

-- The list: most profitable first; losses, hidden items and unknown sources left out.
local rows, left = ns.Profit.Rows("Blacksmithing")
ok(#rows >= 2, "profitable crafts listed: " .. #rows)
eq(rows[1].rec.name, "Test Sharpened Thing", "the most profitable first")
eq(rows[2].rec.name, "Copper Chain Belt")
ok(left.bound > 200, "recipes from patterns that bind left out: " .. left.bound)
ok(left.unknown < 10, "and the few with no known source: " .. left.unknown)
ok(left.unpriced > 0, "crafts without a price left out")
eq(left.losses, 0, "and counted apart from losses")
ns.db.hidden[990002] = true
rows, left = ns.Profit.Rows("Blacksmithing")
eq(rows[1].rec.name, "Copper Chain Belt", "marked doesn't sell")
eq(left.hidden, 1)
ns.db.hidden[990002] = nil
eq(ns.Profit.Rows("Blacksmithing")[1].rec.name, "Test Sharpened Thing", "unhidden")
-- Recipes you haven't learned: listed (greyed out) when you have the skill for them; Show all adds
-- the ones needing more; Hide unlearned leaves only the ones you know.
ns.db.showLosses = true
rows, left = ns.Profit.Rows("Blacksmithing")
local learnable = 0
for _, r in ipairs(rows) do
	if r.rec.source.kind ~= "known" then
		learnable = learnable + 1
		ok(r.rec.source.skill and r.rec.source.skill <= 40, "learnable at your skill (40): " .. r.rec.name)
	end
end
ok(learnable >= 5, "the trainer recipes you could learn now are listed: " .. learnable)
ok(left.later > 50, "the ones needing more skill are counted: " .. left.later)
ns.db.showAll = true
rows, left = ns.Profit.Rows("Blacksmithing")
eq(left.later, 0, "Show all lists them")
local above = 0
for _, r in ipairs(rows) do
	if r.rec.source.skill and r.rec.source.skill > 40 and r.rec.source.kind ~= "known" then above = above + 1 end
end
ok(above > 50, "recipes needing more skill: " .. above)
ns.db.hideUnlearned = true
rows, left = ns.Profit.Rows("Blacksmithing")
for _, r in ipairs(rows) do eq(r.rec.source.kind, "known", "hide unlearned: " .. r.rec.name) end
eq(#rows, 3, "the three recipes the window showed")
ok(left.unlearned > 50, "the rest counted: " .. left.unlearned)
-- The old Known only box becomes Hide unlearned, and the slider's setting goes.
ns.db.hideUnlearned, ns.db.knownOnly, ns.db.showUpTo = false, true, { Blacksmithing = 150 }
WM.Fire("ADDON_LOADED", "leProfit")
eq(ns.db.hideUnlearned, true, "Known only becomes Hide unlearned")
eq(ns.db.knownOnly, nil)
eq(ns.db.showUpTo, nil)
ns.ResetOptions()
eq(ns.db.hideUnlearned, false, "Defaults: off")
eq(ns.db.showAll, false)
ns.db.showLosses = false

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
ns.db.showAll = true
local _, left2 = ns.Profit.Rows("Blacksmithing")
eq(left2.unknown, 0, "Show all lists unknown sources")
eq(left2.bound, 0, "and patterns that bind")
ns.db.showAll = false

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
-- Where the seller stands, and their faction when they serve only one.
eq(ns.Recipes.SellerText(chain.source.sellers[1]), "Vayn Moongaze in Nightclaw Cavern, Zephras Isle at 63.8, 36.0",
	"the place and coordinates; a neutral vendor needs no faction")
eq(ns.Recipes.SellerText({ vendor = "A", zone = "Z", subZone = "S", faction = "Horde", x = 0.5, y = 0.25 }),
	"A in S, Z at 50.0, 25.0 (Horde only)", "a faction's own vendor says so")
eq(ns.Recipes.SellerText({ vendor = "B", zone = "Z", subZone = "Z", faction = "Alliance" }),
	"B in Z (Alliance only)", "no coordinates, and no subzone the same as the zone")
WM.items[277019] = { name = "Azure Skyforged Chain" }
WM.auctionator[277019] = 6632 -- 6300 after the cut: 300 profit on 6000 of bars
row = ns.Profit.Evaluate("Blacksmithing", chain)
eq(row.profit, 300)
eq(row.payback, 4, "950 over 300 a craft")

-- A vendor: material prices and patterns are recorded.
WM.vendorName = "Smith Argus"
WM.npcFaction = "Alliance"
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
eq(pattern.faction, "Alliance", "the vendor's own faction")
eq(pattern.x, 0.642, "and where they stand")
chain = Find("Azure Skyforged Chain")
eq(chain.source.cost, 900, "your price wins")
eq(chain.source.sellers[1].vendor, "Smith Argus", "your seller first")
eq(#chain.source.sellers, 2)
ok(#WM.printed >= 2, "the pattern and the prices are announced")

-- A trainer: what it charges for each recipe, and the skill it needs, are recorded account-wide,
-- and the list uses them before the built-in costs.
eq(Find("Copper Chain Pants").source.cost, 50, "the built-in cost")
WM.trainer = {
	{ name = "Blacksmithing", kind = "header" },
	{ name = "Copper Chain Pants", cost = 60, skill = 20, line = "Blacksmithing" },
	{ name = "Journeyman Blacksmith", cost = 500, line = "Blacksmithing" },
	{ name = "Smelt Copper", cost = 25, line = "Mining" },
	{ name = "Copper Bracers", cost = 40, skill = 1 }, -- no skill line given: found by name
	{ name = "Learned Already", kind = "used", cost = 0, line = "Blacksmithing" },
}
WM.printed = {}
WM.Fire("TRAINER_SHOW")
local trained = ns.adb.training.Blacksmithing
eq(trained["Copper Chain Pants"].cost, 60, "the trainer's cost")
eq(trained["Copper Chain Pants"].skill, 20, "and skill")
eq(trained["Journeyman Blacksmith"], nil, "a rank isn't a recipe")
eq(trained["Learned Already"], nil, "nor is a name no recipe has")
eq(ns.adb.training.Mining["Smelt Copper"].cost, 25, "smelting's under Mining")
eq(ns.adb.training.Mining["Smelt Copper"].skill, nil, "no skill needed")
eq(trained["Copper Bracers"].cost, 40, "found by its name")
eq(WM.printed[1], "|cffffd100leProfit|r: recorded 3 trainer costs.")
local pants = Find("Copper Chain Pants")
eq(pants.source.cost, 60, "the recorded cost wins")
eq(pants.source.skill, 20)
WM.printed = {}
WM.Fire("TRAINER_UPDATE")
eq(#WM.printed, 0, "nothing new, nothing said")
wipe(ns.adb.training)
WM.trainer = {}
ns.DataChanged()

-- Recipes that come with the profession; patterns no vendor sells for gold, bought at the auction
-- house when they can be traded; where each can be had.
local rod = Find("Copper Rod")
eq(rod.source.kind, "free", "Copper Rod comes with Blacksmithing")
eq(ns.Profit.LearnCost(rod.source), 0, "for nothing")
local shoulders = Find("Golden Scale Shoulders")
eq(shoulders.source.kind, "other", "Golden Scale Shoulders is learned from plans no vendor sells")
eq(shoulders.source.bound, false, "that can be traded")
eq(shoulders.source.skill, 150)
eq(ns.Profit.LearnCost(shoulders.source), nil, "no auction price yet")
WM.auctionator[3871] = 2500
eq(ns.Profit.LearnCost(shoulders.source), 2500, "the plans' auction price")
eq(ns.Recipes.WhereLines(shoulders.source)[1], "Drops from Razorfen Battleguard in The Barrens (1 of 4 recorded)",
	"where they drop, and how often players saw it")
local said = table.concat(ns.Profit.Explain("Blacksmithing", shoulders), "\n")
ok(said:find("at the auction house", 1, true) and said:find("Razorfen Battleguard", 1, true), "why says both: " .. said)
local blood = Find("Bloodsoul Breastplate")
eq(blood.source.kind, "other")
eq(ns.Profit.Bound(blood.source), true, "Bloodsoul Breastplate's plans bind")
eq(ns.Profit.LearnCost(blood.source), nil, "so they can't be bought")
eq(ns.Recipes.WhereLines(blood.source)[1], "Needs Zandalar Tribe reputation: Revered")
said = table.concat(ns.Profit.Explain("Blacksmithing", blood), "\n")
ok(said:find("binds when picked up", 1, true) and said:find("Zandalar Tribe", 1, true), "why says where: " .. said)
local boots = Find("Veteran's Boots")
eq(ns.Recipes.WhereLines(boots.source)[1], "30 Merchant's Favor from Gor'mak in The Barrens at 49.8, 29.7 (Horde only)",
	"a token vendor, its price and side")
eq(ns.Recipes.WhereLines(boots.source)[2], "Also sold at the Alliance trade camp (not recorded yet)",
	"a trade camp's plans: the other side's camp sells them too")
eq(ns.Profit.OtherSideOnly(boots.source), false, "so they're anyone's")
-- A pattern only one side's vendors sell is that side's: Sovik in Orgrimmar's Red Firework.
local function FindIn(prof, name)
	for _, r in ipairs(ns.Recipes.List(prof)) do
		if r.name == name then return r end
	end
end
local firework = FindIn("Engineering", "Red Firework")
eq(firework.source.kind, "pattern")
eq(firework.source.side, "Horde", "sold only in Orgrimmar")
eq(ns.Profit.OtherSideOnly(firework.source), true, "so not for this Alliance character")
-- A vendor nobody has recorded the faction of has none: 1.0's (often the recording player's) are
-- gone. So Kania's Wizard Oil is anyone's.
local wizardOil = FindIn("Enchanting", "Wizard Oil")
eq(wizardOil.source.side, nil, "Kania's side isn't known, so it isn't hidden")
eq(wizardOil.source.sellers[1].faction, nil)
local cloudy = Find("Cloudy Skyforged Helm")
eq(cloudy.source.side, "Horde", "Earthen Ring's plans are the Horde's")
eq(ns.Profit.OtherSideOnly(cloudy.source), true, "not for this Alliance character")
local azure = Find("Azure Skyforged Helm")
eq(azure.source.side, "Alliance", "Kirin Tor's are the Alliance's")
eq(ns.Profit.OtherSideOnly(azure.source), false)
-- Plans the game data doesn't describe: the game says, once it has loaded the item.
local defender = Find("Obsidian Defender")
eq(defender.source.bound, nil)
eq(ns.Profit.Bound(defender.source), true, "counted as binding until the game has the item")
WM.items[234228] = { name = "Plans: Obsidian Defender", bindType = 0 }
eq(ns.Profit.Bound(defender.source), false, "the game says they trade")
WM.items[234228].bindType = 1
eq(ns.Profit.Bound(defender.source), true, "or that they bind")
WM.items[234228] = nil
-- In the list: tradeable plans are listed; binding ones with Show all; the other side's never.
local saved = { ns.db.showAll, ns.db.showLosses }
local function Listed(name)
	for _, r in ipairs((ns.Profit.Rows("Blacksmithing"))) do
		if r.rec.name == name then return r end
	end
end
ns.db.showAll, ns.db.showLosses = false, true
WM.skills.Blacksmithing = 300
ok(Listed("Golden Scale Shoulders"), "tradeable plans are listed at your skill")
ok(not Listed("Bloodsoul Breastplate"), "binding plans aren't, without Show all")
local _, counted = ns.Profit.Rows("Blacksmithing")
ok(counted.bound > 200, "they're counted: " .. counted.bound)
ns.db.showAll = true
local shouldersRow = Listed("Golden Scale Shoulders")
eq(shouldersRow.learnCost, 2500, "with what the plans cost")
ok(Listed("Bloodsoul Breastplate"), "Show all lists binding plans")
ok(Listed("Veteran's Boots"), "and token vendors' plans")
ok(not Listed("Cloudy Skyforged Helm"), "but never the other side's")
local function ListedIn(prof, name)
	for _, r in ipairs((ns.Profit.Rows(prof))) do
		if r.rec.name == name then return r end
	end
end
WM.skills.Engineering = 300
ok(not ListedIn("Engineering", "Red Firework"), "nor a pattern only the other side's vendors sell")
ok(Listed("Azure Skyforged Helm"), "your side's are")
_, counted = ns.Profit.Rows("Blacksmithing")
ok(counted.otherSide >= 2, "the other side's are counted: " .. counted.otherSide)
WM.faction = "Horde"
ok(Listed("Cloudy Skyforged Helm") and not Listed("Azure Skyforged Helm"), "and the other way round for the Horde")
ok(ListedIn("Engineering", "Red Firework"), "the Horde sees Red Firework")
WM.skills.Engineering = nil
WM.faction = "Alliance"

-- QuestieDB, when installed, says where a pattern comes from and for whom; the built-in data
-- answers when it isn't, or knows nothing of the item.
eq(ns.Questie.Available(), false, "no QuestieDB")
ok(ns.Questie.StatusText():find("isn't installed", 1, true), "status says so")
WM.InstallQuestieDB({ contract = 2 })
ns.Questie.Forget()
eq(ns.Questie.Available(), false, "too old a QuestieDB is ignored")
ok(ns.Questie.StatusText():find("too old", 1, true))
WM.InstallQuestieDB({
	Item = {
		[20755] = { vendors = { 15419 } },                     -- Formula: Wizard Oil, from Kania
		[18647] = { vendors = { 3413 } },                      -- Schematic: Red Firework, from Sovik
		[3871] = { npcDrops = { 11, 12, 13, 14, 15 } },        -- Plans: Golden Scale Shoulders, a world drop
		[19776] = { questRewards = { 9001 } },                 -- Plans: Bloodsoul Breastplate
		[251355] = { vendors = { 777 } },                      -- Plans: Veteran's Boots, Gor'mak only
		[276976] = { vendors = { 15419 } },                    -- Plans: Cloudy Skyforged Helm (Earthen Ring)
	},
	Npc = {
		[15419] = { name = "Kania", friendlyToFaction = "AH", spawns = { [1377] = { { 51.97, 39.7 } } } },
		[3413] = { name = "Sovik", friendlyToFaction = "H", spawns = { [1637] = { { 75.6, 25.1 } } } },
		[777] = { name = "Gor'mak", friendlyToFaction = "H" },
		[11] = { name = "Ogre A" }, [12] = { name = "Ogre B" }, [13] = { name = "Ogre C" },
		[14] = { name = "Ogre D" }, [15] = { name = "Ogre E" },
	},
	Quest = { [9001] = { name = "Zandalar's Plea", requiredRaces = 77 + 2 ^ 32, zoneOrSort = 1519 } },
})
ns.Questie.Forget()
ns.DataChanged()
eq(ns.Questie.Available(), true, "QuestieDB found")
ok(ns.Questie.StatusText():find("QuestieDB found", 1, true))
eq(ns.Questie.HasAnyBit(77 + 2 ^ 32, 2 ^ 32), true, "race masks past 32 bits")
eq(ns.Questie.HasAnyBit(77, 178), false)
wizardOil = FindIn("Enchanting", "Wizard Oil")
eq(ns.Recipes.WhereLines(wizardOil.source)[1], "Sold by Kania in Silithus at 52.0, 39.7", "QuestieDB's seller and place")
eq(wizardOil.source.side, nil, "friendly to both")
firework = FindIn("Engineering", "Red Firework")
eq(firework.source.side, "Horde", "Sovik serves the Horde only")
eq(ns.Recipes.WhereLines(firework.source)[1], "Sold by Sovik in Orgrimmar at 75.6, 25.1 (Horde only)")
shoulders = Find("Golden Scale Shoulders")
eq(ns.Recipes.WhereLines(shoulders.source)[1], "Drops from 5 creatures (a world drop), such as Ogre A, Ogre B, Ogre C")
eq(shoulders.source.side, nil, "a drop is anyone's")
blood = Find("Bloodsoul Breastplate")
local bloodLines = ns.Recipes.WhereLines(blood.source)
eq(bloodLines[1], "Needs Zandalar Tribe reputation: Revered", "the reputation from the game data first")
eq(bloodLines[2], "Reward from the quest Zandalar's Plea in Stormwind City (Alliance only)", "a quest for Alliance races")
eq(blood.source.side, "Alliance", "so the Alliance's only")
WM.faction = "Horde"
eq(ns.Profit.OtherSideOnly(blood.source), true, "not for the Horde")
WM.faction = "Alliance"
boots = Find("Veteran's Boots")
eq(boots.source.side, nil, "a trade camp's plans stay both sides', whatever one camp's vendor says")
cloudy = Find("Cloudy Skyforged Helm")
eq(cloudy.source.side, "Horde", "a one-side reputation decides, whatever the vendor")
WM.RemoveQuestieDB()
ns.Questie.Forget()
ns.DataChanged()
eq(Find("Bloodsoul Breastplate").source.side, nil, "without QuestieDB, the built-in data again")

WM.skills.Blacksmithing = 40
ns.db.showAll, ns.db.showLosses = saved[1], saved[2]
WM.auctionator[3871] = nil

-- A stale list right after switching windows: the window says Blacksmithing but lists another
-- profession's recipes. ns.RegisterProfession adds a made-up profession for the test.
ns.RegisterProfession({ name = "Testcraft", recipes = {
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
WM.profession = "Jewelcrafting"
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
eq(#WM.opened, 0, "and no profession window")
ok(ns.Window.CurrentPanel(), "a page is shown")
-- The profession dropdown: every ticked module, the one shown selected; picking one switches.
local dropdown = ns.Window.CurrentPanel().picker.dropdown
eq(dropdown.menuGenerator, ns.BuildProfessionMenu, "the dropdown's menu")
local root = WM.MenuRoot()
ns.BuildProfessionMenu(dropdown, root)
eq(#root.radios, #ns.professionOrder + 1, "All professions, then one entry per module")
eq(root.radios[1].text, "All professions")
ok(root.radios[2].text:find("Trade_Alchemy", 1, true) and root.radios[2].text:find("Alchemy$"), "with its icon")
for _, r in ipairs(root.radios) do
	eq(r.isSelected(), r.text:find("Blacksmithing$") ~= nil, "only the profession shown is selected: " .. r.text)
end
local function Radio(r, name)
	for _, radio in ipairs(r.radios) do
		if radio.text:find(name .. "$") then return radio end
	end
end
WM.opened = {}
Radio(root, "Tailoring"):setSelected()
eq(ns.db.profession, "Tailoring", "picking switches")
eq(#WM.opened, 0, "no window for a profession this character doesn't have")
local picked = WM.MenuRoot()
ns.BuildProfessionMenu(dropdown, picked)
ok(Radio(picked, "Tailoring").isSelected(), "and it's selected now")
Radio(root, "Blacksmithing"):setSelected()
eq(ns.db.profession, "Blacksmithing")
eq(#WM.opened, 0, "picking one you have doesn't open its window either")


-- The top bar's Hide unlearned and Show all; Show all is greyed while Hide unlearned is on.
local crafts = ns.Window.CurrentPanel()
crafts.hideUnlearned:SetChecked(true)
crafts.hideUnlearned:Click()
eq(ns.db.hideUnlearned, true, "Hide unlearned")
crafts.hideUnlearned:SetChecked(false)
crafts.hideUnlearned:Click()
crafts.showAll:SetChecked(true)
crafts.showAll:Click()
eq(ns.db.showAll, true, "Show all")
crafts.showAll:SetChecked(false)
crafts.showAll:Click()
eq(ns.db.hideUnlearned, false)
eq(ns.db.showAll, false)
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
eq(maceRow.unlearned, true, "greyed out: not learned")
eq(maceRow.icon.desaturated, true, "a grey icon")
eq(maceRow.line.alpha, 0.55, "faded numbers")
eq(beltRow.icon.desaturated, false, "a recipe you know isn't")
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

-- The search: item, recipe and material names, in the profession shown or all of them.
ns.db.showLosses = true
rows, left = ns.Profit.Rows("Blacksmithing", "copper bar")
ok(#rows > 0, "crafts using Copper Bars: " .. #rows)
for _, r in ipairs(rows) do ok(ns.Profit.Matches(r.rec, "copper bar"), "matches: " .. r.rec.name) end
ok(left.nomatch > 0, "the rest don't match: " .. left.nomatch)
eq(rows[1].prof, "Blacksmithing", "each row knows its profession")
local found = {}
for _, r in ipairs(ns.Profit.RowsAll("copper bar")) do found[r.prof] = true end
ok(found.Blacksmithing and found.Mining, "all professions: Blacksmithing's and Mining's (Smelt Copper makes Copper Bars)")
-- In the window: All professions, then type.
WM.opened = {}
Radio(root, "All professions"):setSelected()
eq(ns.ShowingAll(), true, "All professions")
eq(ns.CurrentProfession(), nil)
eq(#WM.opened, 0, "no profession window to open for all of them")
local box = ns.Window.CurrentPanel().search
box:SetText("smelt copper")
box.scripts.OnTextChanged(box, true)
WM.RunTimers()
local smeltRow = Drawn("Copper Bar")
ok(smeltRow, "Mining's Smelt Copper is listed")
eq(smeltRow.row.prof, "Mining")
ok(not Drawn("Copper Chain Belt"), "and not what doesn't match")
smeltRow.scripts.OnEnter(smeltRow)
ok(TipHas("leProfit: Mining"), "the tooltip names the profession")
box.scripts.OnEscapePressed(box)
eq(box.text, "", "Escape clears it")
box.scripts.OnTextChanged(box, true)
WM.RunTimers()
ok(Drawn("Copper Chain Belt"), "everything again")
box:SetText("chain belt")
box.scripts.OnTextChanged(box, true)
-- A tradeable pattern's row says what it costs at the auction house.
ns.db.showAll = true
WM.items[3841] = { name = "Golden Scale Shoulders" }
WM.items[3871] = { name = "Plans: Golden Scale Shoulders" }
WM.auctionator[3871] = 2500
ns.DataChanged()
box:SetText("golden scale shoulders")
box.scripts.OnTextChanged(box, true)
WM.RunTimers()
local plansRow = Drawn("Golden Scale Shoulders")
ok(plansRow, "Golden Scale Shoulders is listed")
plansRow.scripts.OnEnter(plansRow)
ok(TipHas("Plans: Golden Scale Shoulders " .. ns.Money(2500)) and TipHas("at the auction house"), "its tooltip says where to buy the plans")
ok(TipHas("Drops from Razorfen Battleguard in The Barrens"), "and where they drop")
ns.db.showAll = false
WM.auctionator[3871] = nil
ns.Window.Hide()
eq(box.text, "", "closing the window clears the search")
ns.Window.Show("crafts")
Radio(root, "Blacksmithing"):setSelected()
ns.db.showLosses = false
WM.opened = {}

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
local list = WM.lists.leProfit
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

-- Recipes not read yet: Show at Known explains instead of saying nothing makes a profit.
local saved = ns.db.recipes.Blacksmithing
ns.db.recipes.Blacksmithing = {}
ns.db.hideUnlearned = true
ns.DataChanged()
ns.Window.Show("crafts")
ns.Window.Refresh()
eq(ns.Recorder.KnownCount("Blacksmithing"), 0)
ns.db.recipes.Blacksmithing, ns.db.hideUnlearned = saved, false
ns.DataChanged()
ns.Window.Hide()

-- No professions at all (the data files missing): the window says so.
local order = ns.professionOrder
ns.professionOrder = {}
ns.db.profession = nil
ns.Window.Show("crafts")
ns.Window.Refresh()
ns.professionOrder = order

-- The profession window's button opens leProfit on that profession.
WM.profession = "Blacksmithing"
-- The profession window's button goes on as soon as the window exists, before it shows (on
-- Forever it shows later than the game's event).
local host = WM.NewFrame("Frame", "ProfessionsFrame")
host.CloseButton = WM.NewFrame("Button", nil, host)
host:Hide()
WM.Fire("ADDON_LOADED", "Blizzard_Professions")
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
leProfitMinimapButton:Click("RightButton")
SlashCmdList.LEPROFIT("minimap")
ok(ns.db.minimap.hide, "/leprofit minimap hides the button")
leProfit_OnAddonCompartmentClick(nil, "LeftButton")

-- run_tests.py checks the scenarios got this far.
WM.done = true
