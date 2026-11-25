-- leProfit: what each craft makes. Profit per craft = what the items sell for after the auction
-- house cut (and your undercut) - what the materials cost. Each material costs the cheaper of
-- buying it and crafting it with a recipe you know.
-- Materials you hold count at their price too: using one you could sell costs you that one.
local _, ns = ...

local Profit = {}
ns.Profit = Profit

local MAX_DEPTH = 3 -- materials made from materials made from materials, and no deeper

local EffectivePrice

-- The cheapest way to make one of an item with a recipe you know, in any of your professions with
-- a module (smelting a bar for Blacksmithing, say): { rec, prof, cost } or nil.
local function CraftOption(prof, itemID, depth, memo)
	if depth >= MAX_DEPTH then return nil end
	local best
	for _, maker in ipairs(ns.professionOrder) do
		for _, rec in ipairs(ns.Recipes.Makers(maker, itemID) or {}) do
			local cost = 0
			for _, r in ipairs(rec.reagents) do
				local p = r[1] ~= itemID and EffectivePrice(prof, r[1], depth + 1, memo)
				if not p then cost = nil break end
				cost = cost + p * r[2]
			end
			if cost then
				local each = cost / math.max(rec.yield or 1, 1)
				if not best or each < best.cost or (each == best.cost and rec.name < best.rec.name) then
					best = { rec = rec, prof = maker, cost = each }
				end
			end
		end
	end
	return best
end

-- What one of a material costs you: the price, and "vendor", "auction" or "craft".
function EffectivePrice(prof, itemID, depth, memo)
	local key = itemID .. ":" .. depth
	local m = memo[key]
	if m then return m[1], m[2], m[3] end
	local price, how = ns.Prices.Buy(itemID)
	local craft = CraftOption(prof, itemID, depth, memo)
	local option
	if craft and (not price or craft.cost < price) then
		price, how, option = craft.cost, "craft", craft
	end
	memo[key] = { price, how, option }
	return price, how, option
end

-- The settings the sums use, as fractions.
local function Rates()
	local db = ns.db
	return (db.cut or 0) / 100, (db.undercut or 0) / 100, db.rankBy == "market"
end

-- What one of the item brings in: posted at the ranked price less the undercut, less the cut; or
-- the vendor's price when that's more, or when the item binds on pickup (it can't be posted).
-- Returns the amount and how ("auction" or "vendor"), or nil when nothing is known.
local function SaleValue(buyout, market, vendor, bop)
	local cut, undercut, byMarket = Rates()
	local price
	if byMarket then price = market or buyout else price = buyout or market end
	local auction = (price and not bop) and math.floor(price * (1 - undercut) * (1 - cut)) or nil
	if auction and (not vendor or auction >= vendor) then return auction, "auction" end
	if vendor and vendor > 0 then return vendor, "vendor" end
	return nil, nil
end
Profit.SaleValue = SaleValue -- (tests)

-- A pattern no vendor sells for gold ("other") can be bought at the auction house unless it binds
-- when picked up. The data says which for most; for the rest the game does once it has loaded the item (until
-- then it counts as bound; the list redraws when the item loads).
function Profit.Bound(src)
	if src.bound ~= nil then return src.bound end
	local _, bop = ns.ItemSale(src.itemID)
	return bop ~= false
end

-- What learning a recipe costs: the trainer's or vendor's price, nothing for one that comes with
-- the profession, the auction price of a pattern you can buy there (nil until a scan has seen it).
function Profit.LearnCost(src)
	if src.kind == "other" then
		if Profit.Bound(src) then return nil end
		return ns.Prices.Buyout(src.itemID) or ns.Prices.Market(src.itemID)
	end
	return src.cost
end

-- True when only the other side can get the recipe: a reputation or quests for one side only.
function Profit.OtherSideOnly(src)
	if not src.side then return false end
	return src.side ~= ns.Plain(ns.Try(UnitFactionGroup, "player"))
end

-- Specializations: paths a character picks within a profession (Armorsmith or Weaponsmith, and
-- within Weaponsmith one of the masters; a leatherworking path; Gnomish or Goblin Engineering),
-- each with its own recipes. Whether the character has one: the game says (it's a spell).
function Profit.HasSpec(prof, name)
	local s = ns.professions[prof] and ns.professions[prof].specs[name]
	return s and IsPlayerSpell and ns.Try(IsPlayerSpell, s.id) == true or false
end

-- True when a path is closed to the character: it has picked another beside it (a sibling with the
-- same parent), or the path it's within is closed (an Armorsmith can't be a Master Axesmith).
local function OtherPath(prof, name)
	local specs = ns.professions[prof].specs
	local spec = specs[name]
	if not spec then return false end
	for other, s in pairs(specs) do
		if other ~= name and s.parent == spec.parent and Profit.HasSpec(prof, other) then return true end
	end
	return spec.parent and OtherPath(prof, spec.parent) or false
end

-- True when the recipe needs a specialization the character can't have: another path's recipes
-- are never listed for it. A character with no path yet sees them all.
function Profit.OtherSpecOnly(prof, rec)
	return rec.spec and OtherPath(prof, rec.spec) or false
end

-- The profession's paths the character could have, for the Specialization dropdown: each with
-- the paths within it straight after, by name. { { name, parent } }
function Profit.Specs(prof)
	local def = ns.professions[prof]
	local list = {}
	if not def then return list end
	local function Add(parent)
		local names = {}
		for name, s in pairs(def.specs) do
			if s.parent == parent and not OtherPath(prof, name) then names[#names + 1] = name end
		end
		table.sort(names)
		for _, name in ipairs(names) do
			list[#list + 1] = { name = name, parent = parent }
			Add(name)
		end
	end
	Add(nil)
	return list
end

-- The Specialization dropdown's pick for a profession: a path's name, "none" (only recipes that
-- need none) or nil (all). A path the character can't have (or the data no longer lists) is all.
function Profit.SpecFilter(prof)
	local pick = ns.db.specFilter[prof]
	if pick == "none" then return pick end
	local def = ns.professions[prof]
	if def and def.specs[pick] and not OtherPath(prof, pick) then return pick end
	return nil
end

-- Whether a recipe fits the dropdown's pick: a path takes in the paths within it (Weaponsmith,
-- its masters' recipes too).
local function FitsSpec(prof, rec, pick)
	if not pick then return true end
	if pick == "none" then return rec.spec == nil end
	if rec.spec == pick then return true end
	local s = rec.spec and ns.professions[prof].specs[rec.spec]
	return s and s.parent == pick or false
end

-- "Armorsmith only", and whether the character has that path: for tooltips.
function Profit.SpecText(prof, rec)
	if not rec.spec then return nil end
	if rec.source.kind == "known" or Profit.HasSpec(prof, rec.spec) then return rec.spec .. " only" end
	return rec.spec .. " only: a path you haven't picked"
end

-- Everything about one recipe's craft. Returns a row:
--   rec, product, yield; cost (materials for one craft) and materials = { { itemID, count, price,
--   how } }, missing (a material nobody has a price for); buyout, market, value (one item, after
--   the cut), via ("auction"/"vendor"), bop; profit (one craft); learnCost (Profit.LearnCost);
--   payback (crafts to pay for learning it); age (days since the auction price); stale.
-- The steadier price and the auction history cost more to read, so they're read only when a
-- column shows them, profit is ranked by the steadier price, or `full` asks (/leprofit why).
function Profit.Evaluate(prof, rec, memo, full)
	memo = memo or {}
	local row = { rec = rec, product = rec.product, yield = math.max(rec.yield or 1, 1), cost = 0, materials = {} }
	for _, r in ipairs(rec.reagents) do
		local price, how, option = EffectivePrice(prof, r[1], 0, memo)
		row.materials[#row.materials + 1] = { itemID = r[1], count = r[2], price = price, how = how, option = option }
		if price then
			row.cost = row.cost + price * r[2]
		else
			row.missing = row.missing or r[1]
		end
	end
	if row.missing then row.cost = nil end

	local db = ns.db
	local history = full or db.showMarket or db.showTrend or db.showSeen or db.showListed
	row.buyout = ns.Prices.Buyout(rec.product)
	if history or db.rankBy == "market" or not row.buyout then row.market = ns.Prices.Market(rec.product) end
	local vendor, bop = ns.ItemSale(rec.product)
	row.bop = bop
	row.value, row.via = SaleValue(row.buyout, row.market, vendor, bop)
	if row.value and row.cost then
		row.profit = row.value * row.yield - row.cost
	end

	local learn = rec.source and Profit.LearnCost(rec.source)
	row.learnCost = learn
	if learn and learn > 0 and row.profit and row.profit > 0 then
		row.payback = math.ceil(learn / row.profit)
	end
	local h = history and ns.Prices.History(rec.product)
	if h then row.seen, row.days, row.listed, row.trend = h.seen, h.days, h.listed, h.trend end
	row.age = ns.Prices.Age(rec.product)
	row.stale = (row.age and row.age >= (db.staleDays or 3)) and true or false
	return row
end

-- Each craft's sums are kept until something they depend on changes (ns.sumsVersion: the data,
-- auction prices, the settings, items the game finished loading). Redrawing the list (bags,
-- sorting, the boxes, the search) then costs next to nothing.
local cache, cacheVersion, cacheMemo = {}, nil, {}
local function Fresh()
	if cacheVersion ~= ns.sumsVersion then cache, cacheVersion, cacheMemo = {}, ns.sumsVersion, {} end
end
local function Cached(prof, rec)
	Fresh()
	local key = prof .. ":" .. rec.id
	local row = cache[key]
	if not row then
		row = Profit.Evaluate(prof, rec, cacheMemo)
		row.prof = prof
		cache[key] = row
	end
	return row
end

-- Working out many crafts' sums at once (a long list shown for the first time, or after prices
-- changed) is done a few milliseconds per frame, so the game never stalls: Prepare works through
-- the professions' recipes, building each list and then its sums, and calls done() when it's
-- finished. It returns true when there was nothing (left) to do and the list can be drawn now.
Profit.BUDGET = 8 -- milliseconds of work per frame
local job
function Profit.Prepare(profs, done)
	if job then
		job.done = done
		return false
	end
	local version = ns.sumsVersion
	local start
	-- Only real work counts against the budget: a list that's all worked out is one quick pass, so
	-- it never waits for a frame (else it could never finish).
	local function Pause()
		if debugprofilestop() - start >= Profit.BUDGET then coroutine.yield() end
	end
	local co = coroutine.create(function()
		-- First what every sum needs: which recipes each profession has (make-vs-buy asks all of
		-- them) and the lists shown, built a step at a time; then the sums.
		-- Only real work pauses: with everything built, this is one quick pass.
		for _, prof in ipairs(ns.professionOrder) do
			if not ns.Recipes.MakersBuilt(prof) then
				ns.Recipes.Makers(prof, 0)
				Pause()
			end
		end
		for _, prof in ipairs(profs) do
			if not ns.Recipes.Built(prof) then ns.Recipes.List(prof, Pause) end
		end
		for _, prof in ipairs(profs) do
			for _, rec in ipairs(ns.Recipes.List(prof)) do
				Fresh()
				if not cache[prof .. ":" .. rec.id] then
					Cached(prof, rec)
					if debugprofilestop() - start >= Profit.BUDGET then coroutine.yield() end
				end
			end
		end
	end)
	local function Step()
		start = debugprofilestop()
		local ok, err = ns.Timed("work out sums (a slice)", coroutine.resume, co)
		if not ok then
			job = nil
			error(err, 0)
		end
		if coroutine.status(co) == "dead" or version ~= ns.sumsVersion then
			-- Done; or something changed meanwhile, and the refresh that follows starts again.
			local finished = job
			job = nil
			if finished then finished.done() end
			return true
		end
		job = job or { done = done }
		C_Timer.After(0, Step)
		return false
	end
	return Step()
end

-- The rows the Crafts tab lists for a profession (those matching the search, when there is one),
-- each with its prof, sorted, and how many were left out: { nomatch = n (the search), specFilter = n
-- (the Specialization dropdown), unlearned = n (Hide unlearned), otherSide = n (only the other side
-- can get them: never listed), otherSpec = n (another path's: never listed), unknown = n (no known source),
-- bound = n (from a pattern that binds; Show all lists those and the unknown), later = n (needing more skill
-- than you have, without Show all), hidden = n, unpriced = n (a material or the item has no price),
-- losses = n (0 or less) }. Recipes you'd learn are listed (greyed) when you have the skill.
-- The search: the item, the recipe, or any of its materials has the text in its name (query is
-- lower case); or the specialization it needs, or the path that's within ("weaponsmith" finds the
-- masters' recipes too).
local function Matches(rec, query, prof)
	if ns.ItemName(rec.product):lower():find(query, 1, true) or rec.name:lower():find(query, 1, true) then
		return true
	end
	-- "writ" (or "craftsman") finds every craft a Craftsman's Writ asks for.
	if ns.writs[rec.product] and ("craftsman's writ"):find(query, 1, true) then return true end
	if rec.spec then
		if rec.spec:lower():find(query, 1, true) then return true end
		local s = prof and ns.professions[prof] and ns.professions[prof].specs[rec.spec]
		if s and s.parent and s.parent:lower():find(query, 1, true) then return true end
	end
	for _, r in ipairs(rec.reagents) do
		if ns.ItemName(r[1]):lower():find(query, 1, true) then return true end
	end
	return false
end
Profit.Matches = Matches -- (tests)

-- Why the Crafts list leaves a recipe out (a key of Rows' counts), or nil and its row when it's
-- listed. The one place that decides: the list and /leprofit debug both ask it. `spec` is the
-- Specialization dropdown's pick (Profit.SpecFilter; nil for all).
function Profit.LeftOut(prof, rec, query, skill, spec)
	local db = ns.db
	local known = rec.source.kind == "known"
	local need = rec.source.skill
	if query and not Matches(rec, query, prof) then return "nomatch" end
	if not FitsSpec(prof, rec, spec) then return "specFilter" end
	if not known and db.hideUnlearned then return "unlearned" end
	if not known and Profit.OtherSideOnly(rec.source) then return "otherSide" end
	if not known and Profit.OtherSpecOnly(prof, rec) then return "otherSpec" end
	if rec.source.kind == "unknown" and not db.showAll then return "unknown" end
	if rec.source.kind == "other" and not db.showAll and Profit.Bound(rec.source) then return "bound" end
	if not known and not db.showAll and not (need and skill and need <= skill) then return "later" end
	if db.hidden[rec.product] then return "hidden" end
	local row = Cached(prof, rec)
	if not row.profit and db.hideLosses then return "unpriced", row end
	if row.profit and row.profit <= 0 and db.hideLosses then return "losses", row end
	return nil, row
end

local function NoneLeft()
	return { nomatch = 0, specFilter = 0, unlearned = 0, otherSide = 0, otherSpec = 0, unknown = 0, bound = 0, later = 0,
		hidden = 0, unpriced = 0, losses = 0 }
end

function Profit.Rows(prof, query, spec)
	local rows, left = {}, NoneLeft()
	local skill = ns.Skill(prof)
	for _, rec in ipairs(ns.Recipes.List(prof)) do
		local why, row = Profit.LeftOut(prof, rec, query, skill, spec)
		if why then
			left[why] = left[why] + 1
		else
			rows[#rows + 1] = row
		end
	end
	Profit.Sort(rows)
	return rows, left
end

-- Every ticked profession's rows together ("All professions" in the dropdown), sorted as one list.
-- A recipe several professions list (Forever's camp and home items) appears once. The
-- Specialization dropdown is one profession's, so it doesn't apply here.
function Profit.RowsAll(query)
	local rows, left, seen = {}, nil, {}
	for _, prof in ipairs(ns.professionOrder) do
		local r, l = Profit.Rows(prof, query)
		for _, row in ipairs(r) do
			if not seen[row.rec.id] then
				seen[row.rec.id] = true
				rows[#rows + 1] = row
			end
		end
		if not left then
			left = l
		else
			for k, v in pairs(l) do left[k] = left[k] + v end
		end
	end
	Profit.Sort(rows)
	return rows, left or NoneLeft()
end

-- What each Crafts column sorts by.
local SORT_VALUE = {
	item = function(r) return ns.ItemName(r.product):lower() end,
	cost = function(r) return r.cost end,
	buyout = function(r) return r.buyout end,
	market = function(r) return r.market end,
	trend = function(r) return r.trend end,
	seen = function(r) return r.seen end,
	listed = function(r) return r.listed end,
	profit = function(r) return r.profit end,
}

-- Sorts rows by the column picked (ns.db.sortBy, highest or Z first when sortDesc). Rows without a
-- value in that column go last either way; ties go by recipe name.
function Profit.Sort(rows)
	local value = SORT_VALUE[ns.db.sortBy] or SORT_VALUE.profit
	local desc = ns.db.sortDesc and true or false
	for _, r in ipairs(rows) do r.sortValue = value(r) end
	table.sort(rows, function(a, b)
		local va, vb = a.sortValue, b.sortValue
		if (va ~= nil) ~= (vb ~= nil) then return va ~= nil end
		if va ~= nil and va ~= vb then
			if desc then return va > vb end
			return va < vb
		end
		return a.rec.name < b.rec.name
	end)
end

-- For n crafts: each material's need, what you hold, what to buy and its cost, and the gold you'd
-- spend in all. Crafted materials are listed as bought at their crafting cost.
function Profit.Shopping(row, n)
	local list, spend, unpriced = {}, 0, false
	for _, m in ipairs(row.materials) do
		local need = m.count * n
		local have = ns.ItemCount(m.itemID)
		local buy = math.max(0, need - have)
		local cost = m.price and m.price * buy or nil
		if cost then spend = spend + cost elseif buy > 0 then unpriced = true end
		list[#list + 1] = { itemID = m.itemID, need = need, have = have, buy = buy, cost = cost, how = m.how, price = m.price }
	end
	return list, not unpriced and spend or nil
end

-- /leprofit why: the recipe a name, an item ID or an item link means, in any enabled profession.
-- Returns the profession and recipe, or nil and the recipes whose names contain the text.
function Profit.Find(query)
	local id = tonumber(query) or tonumber(query:match("item:(%d+)"))
	local q = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
	local partial = {}
	for _, prof in ipairs(ns.professionOrder) do
		for _, rec in ipairs(ns.Recipes.List(prof)) do
			local name, item = rec.name:lower(), ns.ItemName(rec.product):lower()
			if (id and rec.product == id) or (not id and (name == q or item == q)) then return prof, rec end
			if not id and q ~= "" and (name:find(q, 1, true) or item:find(q, 1, true)) then
				partial[#partial + 1] = { prof = prof, rec = rec }
			end
		end
	end
	if #partial == 1 then return partial[1].prof, partial[1].rec end
	return nil, partial
end

local SOURCES = { auction = "auction", vendor = "vendor", craft = "crafted" }

-- The whole sum for one recipe, as lines of text: each material and its price, the sale, the
-- profit, and where to learn it.
function Profit.Explain(prof, rec)
	local row = Profit.Evaluate(prof, rec, nil, true)
	local M, db = ns.Money, ns.db
	local lines = {}
	local function Add(s) lines[#lines + 1] = s end
	local known = rec.source.kind == "known" and "you know it" or "you don't know it"
	Add(("%s (%s, %s)"):format(ns.ItemNameColored(rec.product), prof, known))
	if rec.spec then Add("  " .. Profit.SpecText(prof, rec)) end
	for _, m in ipairs(row.materials) do
		local how = m.how == "craft"
			and ("crafted with " .. m.option.rec.name .. (m.option.prof ~= prof and (" (" .. m.option.prof .. ")") or ""))
			or SOURCES[m.how] or "no price"
		Add(("  %d x %s: %s each (%s)%s"):format(m.count, ns.ItemName(m.itemID), M(m.price), how,
			m.price and (" = " .. M(m.price * m.count)) or ""))
	end
	Add("  Materials: " .. (row.cost and M(row.cost) or ("no price for " .. ns.ItemName(row.missing))) .. " a craft")
	local vendor = ns.ItemSale(rec.product)
	Add(("  Lowest buyout %s, %s %s, a vendor pays %s%s"):format(M(row.buyout), ns.Prices.MarketName(),
		M(row.market), M(vendor), row.bop and "; binds on pickup" or ""))
	local h = ns.Prices.History(rec.product)
	if h then
		local trend = h.trend and ({ [1] = ", prices going up", [0] = ", prices level", [-1] = ", prices going down" })[h.trend] or ""
		Add(("  Auctionator: listed on %d of the last %d days%s%s"):format(h.seen, h.days,
			h.listed and (", " .. h.listed .. " listed at the last scan" .. (h.lastSeen > 0 and (" (" .. h.lastSeen .. (h.lastSeen == 1 and " day" or " days") .. " ago)") or "")) or "",
			trend))
	else
		Add("  Auctionator: no price history for it")
	end
	if row.value then
		local why = row.via == "vendor" and "to a vendor"
			or ("after %d%% cut%s, by %s"):format(db.cut, db.undercut > 0 and (" and " .. db.undercut .. "% undercut") or "",
				db.rankBy == "market" and ns.Prices.MarketName() or "lowest buyout")
		Add(("  Sells for %s each %s; makes %s"):format(M(row.value), why, row.yield))
	else
		Add("  No sale price: nobody has recorded one")
	end
	Add("  Profit: " .. (row.profit and M(row.profit) .. " a craft" or "can't tell without every price"))
	local src = rec.source
	if src.kind == "trainer" then
		Add(("  Learn it from a trainer for %s%s"):format(M(src.cost), src.skill and (", skill " .. src.skill) or ""))
	elseif src.kind == "pattern" then
		Add(("  The pattern costs %s%s"):format(M(src.cost), src.skill and (", skill " .. src.skill) or ""))
		for _, line in ipairs(ns.Recipes.WhereLines(src)) do Add("    " .. line) end
	elseif src.kind == "free" then
		Add("  It comes with the profession")
	elseif src.kind == "other" then
		local skill = src.skill and (", skill " .. src.skill) or ""
		if Profit.Bound(src) then
			Add(("  Learn it from %s%s, which binds when picked up:"):format(ns.ItemName(src.itemID), skill))
		else
			Add(("  Learn it from %s%s: %s at the auction house, or:"):format(ns.ItemName(src.itemID), skill,
				row.learnCost and M(row.learnCost) or "no price seen yet"))
		end
		local where = ns.Recipes.WhereLines(src)
		if #where == 0 then where = { "where to get it isn't recorded yet" } end
		for _, line in ipairs(where) do Add("    " .. line) end
	elseif src.kind == "unknown" then
		Add("  Where to learn it isn't known")
	end
	if row.payback then Add(("  Pays back in %d craft%s"):format(row.payback, row.payback == 1 and "" or "s")) end
	if row.age then Add(("  The auction price is %d day%s old"):format(row.age, row.age == 1 and "" or "s")) end
	if db.hidden[rec.product] then Add("  Marked doesn't sell (Options lists it)") end
	return lines
end
