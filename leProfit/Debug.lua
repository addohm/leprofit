-- leProfit: /leprofit debug, a plain-text report of what leProfit saw, to copy into a bug report:
-- the setup (versions, the character's faction and professions), the settings that change the
-- sums, the price addons found, the slowest work so far, and for one craft every price it could
-- have used, which it chose and why, the sums, and why the list shows it or not. No names of
-- characters or realms go in.
local _, ns = ...
local Try = ns.Try

local Debug = {}
ns.Debug = Debug

-- Money as plain text ("1g 63s 80c"): the report is copied out of the game, so no coin icons.
local function M(copper)
	if not copper then return "none" end
	local negative = copper < 0
	copper = math.floor(math.abs(copper) + 0.5)
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	local parts = {}
	if g > 0 then parts[#parts + 1] = g .. "g" end
	if s > 0 then parts[#parts + 1] = s .. "s" end
	if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
	return (negative and "-" or "") .. table.concat(parts, " ")
end
Debug.Money = M -- (tests)

local function YesNo(v) return v and "yes" or "no" end

local function AddonVersion(name)
	local v = C_AddOns and C_AddOns.GetAddOnMetadata and Try(C_AddOns.GetAddOnMetadata, name, "Version")
	return v and (" " .. v) or ""
end

-- The header every report starts with.
local function Setup(lines)
	local function Add(s) lines[#lines + 1] = s end
	local version, build = Try(GetBuildInfo)
	local first = ns.professions[ns.professionOrder[1]]
	Add("leProfit debug report")
	Add(("leProfit %s | game %s (%s) %s | data from game build %s"):format(ns.Version(), tostring(version),
		tostring(build), tostring(Try(GetLocale)), first and first.dataBuild or "?"))
	local profs = {}
	for _, prof in ipairs(ns.professionOrder) do
		local skill = ns.Skill(prof)
		if skill then profs[#profs + 1] = ("%s %s (knows %d)"):format(prof, skill, ns.Recorder.KnownCount(prof)) end
	end
	Add(("Character: %s | %s"):format(tostring(ns.Plain(Try(UnitFactionGroup, "player"))),
		#profs > 0 and table.concat(profs, ", ") or "no crafting profession"))
	local db = ns.db
	Add(("Settings: profit from %s | cut %s%% | undercut %s%% | old price after %s days | Hide losses %s | Show all %s | Hide unlearned %s | columns: Avg 14d %s, Trend %s, Seen %s, Listed %s"):format(
		db.rankBy == "market" and "the steadier price" or "lowest buyout", tostring(db.cut), tostring(db.undercut),
		tostring(db.staleDays), YesNo(db.hideLosses), YesNo(db.showAll), YesNo(db.hideUnlearned),
		YesNo(db.showMarket), YesNo(db.showTrend), YesNo(db.showSeen), YesNo(db.showListed)))
	Add(("Price addons: Auctionator %s | TSM %s | %s"):format(
		ns.Prices.HasAuctionator() and ("found" .. AddonVersion("Auctionator")) or "not found",
		ns.Prices.HasTSM() and ("found" .. AddonVersion("TradeSkillMaster")) or "not found",
		ns.Questie.StatusText()))
	Add(("Versions: data %d, sums %d"):format(ns.dataVersion, ns.sumsVersion))
end

local function Timings(lines)
	local list, parts = ns.Timings(), {}
	for i = 1, math.min(5, #list) do
		local t = list[i]
		parts[#parts + 1] = ("%s worst %.0f ms (%dx, avg %.1f)"):format(t.name, t.worst, t.n, t.total / t.n)
	end
	lines[#lines + 1] = "Slowest work: " .. (#parts > 0 and table.concat(parts, " | ") or "nothing timed yet")
end

-- Every price leProfit can see for an item, on one line.
local function PriceLine(itemID)
	local d = ns.Prices.Detail(itemID)
	local parts = {
		("Auctionator %s%s"):format(M(d.auctionator), d.age and (" (" .. d.age .. " days old)") or ""),
		("TSM min %s, market %s"):format(M(d.tsmMin), M(d.tsmMarket)),
	}
	local h = d.history
	if h then
		parts[#parts + 1] = ("14-day average %s, seen %d/%d, listed %s, trend %s"):format(M(h.average), h.seen, h.days,
			tostring(h.listed), h.trend == 1 and "up" or h.trend == -1 and "down" or h.trend == 0 and "level" or "none")
	end
	parts[#parts + 1] = ("vendor: recorded %s, data %s%s, Auctionator's %s"):format(M(d.vendorRecorded), M(d.vendorData),
		d.vendorDataFrom and (" (" .. d.vendorDataFrom .. ")") or "", M(d.vendorAuctionator))
	return table.concat(parts, " | ")
end

local LEARN = {
	known = "known", free = "comes with the profession", trainer = "trainer", unknown = "nobody knows where",
	pattern = "a pattern a vendor sells", other = "a pattern no vendor sells for gold (drop, quest, reputation or tokens)",
}

local LEFT_OUT = {
	nomatch = "it doesn't match the search",
	unlearned = "Hide unlearned is ticked and the character doesn't know it",
	otherSide = "only the other side can get it",
	unknown = "nobody knows where to learn it (Show all lists it)",
	bound = "its pattern binds when picked up (Show all lists it)",
	later = "it needs more skill (Show all lists it)",
	hidden = "it's marked doesn't sell",
	unpriced = "it has no price and Hide losses is ticked",
	losses = "it's at a loss and Hide losses is ticked",
}

local function Craft(lines, prof, rec)
	local function Add(s) lines[#lines + 1] = s end
	local src = rec.source
	local row = ns.Profit.Evaluate(prof, rec, nil, true)
	local why = ns.Profit.LeftOut(prof, rec, nil, ns.Skill(prof))
	Add(("Craft: %s (recipe %d, %s) makes %s (item %d) x%s"):format(rec.name, rec.id, prof, ns.ItemName(rec.product),
		rec.product, tostring(row.yield)))
	local recorded = ns.db.recipes[prof] and ns.db.recipes[prof][rec.id]
	local game = IsPlayerSpell and Try(IsPlayerSpell, rec.id) == true
	Add(("  Known: %s (window says %s, game says %s) | learn: %s%s%s%s%s%s"):format(YesNo(src.kind == "known"),
		recorded and YesNo(recorded.learned) or "never read", YesNo(game), LEARN[src.kind] or src.kind,
		src.itemID and (" (item " .. src.itemID .. ")") or "",
		src.cost and (" " .. M(src.cost)) or "", src.skill and (" skill " .. src.skill) or "",
		src.side and (" | only the " .. src.side) or "", src.bound ~= nil and (" | binds " .. YesNo(src.bound)) or ""))
	for _, line in ipairs((src.kind == "pattern" or src.kind == "other") and ns.Recipes.WhereLines(src, 4) or {}) do
		Add("    where: " .. line)
	end
	Add("  Listed: " .. (why and ("no, " .. LEFT_OUT[why]) or "yes"))
	local writ = ns.writs[rec.product]
	if writ then Add(("  Writ: %s (item %d) asks for it"):format(ns.ItemName(writ), writ)) end
	local sell, bop = ns.ItemSale(rec.product)
	Add(("  Sale: %s each via %s (buyout %s, steadier %s; vendor pays %s; binds on pickup %s)"):format(M(row.value),
		tostring(row.via), M(row.buyout), M(row.market), M(sell), YesNo(bop)))
	Add("    item " .. rec.product .. ": " .. PriceLine(rec.product))
	Add(("  Materials: %s for one craft%s"):format(M(row.cost), row.missing and (" (no price for item " .. row.missing .. ")") or ""))
	for _, m in ipairs(row.materials) do
		Add(("    %d x %s (item %d): %s each via %s = %s"):format(m.count, ns.ItemName(m.itemID), m.itemID, M(m.price),
			tostring(m.how), m.price and M(m.price * m.count) or "none"))
		Add("      " .. PriceLine(m.itemID))
		if m.option then
			Add(("      crafted: %s (%s) %s each"):format(m.option.rec.name, m.option.prof, M(m.option.cost)))
		end
	end
	Add(("  Profit: %s a craft | learning costs %s | pays back in %s crafts | price %s days old%s"):format(M(row.profit),
		M(row.learnCost), tostring(row.payback or "-"), tostring(row.age or "?"), row.stale and " (old)" or ""))
end

-- The report: the setup, and the craft's details when one is given.
function Debug.Report(prof, rec)
	local lines = {}
	Setup(lines)
	if prof and rec then Craft(lines, prof, rec) end
	Timings(lines)
	return table.concat(lines, "\n")
end
