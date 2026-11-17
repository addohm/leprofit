-- Leprofit: what each craft makes. Profit per craft = what the items sell for after the auction
-- house cut (and your undercut) - what the materials cost. Each material costs the cheaper of
-- buying it and crafting it with a recipe you know (the source addon's EffectivePrice and CraftOption).
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

-- Everything about one recipe's craft. Returns a row:
--   rec, product, yield; cost (materials for one craft) and materials = { { itemID, count, price,
--   how } }, missing (a material nobody has a price for); buyout, market, value (one item, after
--   the cut), via ("auction"/"vendor"), bop; profit (one craft); payback (crafts to pay for
--   learning it); age (days since the auction price); stale.
function Profit.Evaluate(prof, rec, memo)
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

	row.buyout, row.market = ns.Prices.Buyout(rec.product), ns.Prices.Market(rec.product)
	local vendor, bop = ns.ItemSale(rec.product)
	row.bop = bop
	row.value, row.via = SaleValue(row.buyout, row.market, vendor, bop)
	if row.value and row.cost then
		row.profit = row.value * row.yield - row.cost
	end

	local learn = rec.source and rec.source.cost
	if learn and learn > 0 and row.profit and row.profit > 0 then
		row.payback = math.ceil(learn / row.profit)
	end
	local h = ns.Prices.History(rec.product)
	if h then row.seen, row.days, row.listed, row.trend = h.seen, h.days, h.listed, h.trend end
	row.age = ns.Prices.Age(rec.product)
	row.stale = (row.age and row.age >= (ns.db.staleDays or 3)) and true or false
	return row
end

-- The rows the Crafts tab lists for a profession, most profitable first, and how many were left out:
-- { unlearned = n (Known only), unknown = n (no known source), hidden = n, unpriced = n (a material
-- or the item has no price), losses = n (0 or less) }.
function Profit.Rows(prof)
	local db, memo = ns.db, {}
	local rows, left = {}, { unlearned = 0, unknown = 0, hidden = 0, unpriced = 0, losses = 0 }
	for _, rec in ipairs(ns.Recipes.List(prof)) do
		if db.knownOnly and rec.source.kind ~= "known" then
			left.unlearned = left.unlearned + 1
		elseif rec.source.kind == "unknown" and not db.showUnknown then
			left.unknown = left.unknown + 1
		elseif db.hidden[rec.product] then
			left.hidden = left.hidden + 1
		else
			local row = Profit.Evaluate(prof, rec, memo)
			if not row.profit and not db.showLosses then
				left.unpriced = left.unpriced + 1
			elseif row.profit and row.profit <= 0 and not db.showLosses then
				left.losses = left.losses + 1
			else
				rows[#rows + 1] = row
			end
		end
	end
	Profit.Sort(rows)
	return rows, left
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
	local row = Profit.Evaluate(prof, rec)
	local M, db = ns.Money, ns.db
	local lines = {}
	local function Add(s) lines[#lines + 1] = s end
	local known = rec.source.kind == "known" and "you know it" or "you don't know it"
	Add(("%s (%s, %s)"):format(ns.ItemNameColored(rec.product), prof, known))
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
		local s = src.sellers and src.sellers[1]
		Add(("  The pattern costs %s%s"):format(M(src.cost), s and (" from " .. s.vendor) or ""))
	elseif src.kind == "unknown" then
		Add("  Where to learn it isn't recorded")
	end
	if row.payback then Add(("  Pays back in %d craft%s"):format(row.payback, row.payback == 1 and "" or "s")) end
	if row.age then Add(("  The auction price is %d day%s old"):format(row.age, row.age == 1 and "" or "s")) end
	if db.hidden[rec.product] then Add("  Marked doesn't sell (Options lists it)") end
	return lines
end
