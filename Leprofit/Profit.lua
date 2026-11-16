-- Leprofit: what each craft makes. Profit per craft = what the items sell for after the auction
-- house cut (and your undercut) - what the materials cost. Each material costs the cheaper of
-- buying it and crafting it with a recipe you know (the source addon's EffectivePrice and CraftOption).
-- Materials you hold count at their price too: using one you could sell costs you that one.
local _, ns = ...

local Profit = {}
ns.Profit = Profit

local MAX_DEPTH = 3 -- materials made from materials made from materials, and no deeper

local EffectivePrice

-- The cheapest way to make one of an item with a recipe you know: { rec, cost } or nil.
local function CraftOption(prof, itemID, depth, memo)
	if depth >= MAX_DEPTH then return nil end
	local best
	for _, rec in ipairs(ns.Recipes.Makers(prof, itemID) or {}) do
		local cost = 0
		for _, r in ipairs(rec.reagents) do
			local p = r[1] ~= itemID and EffectivePrice(prof, r[1], depth + 1, memo)
			if not p then cost = nil break end
			cost = cost + p * r[2]
		end
		if cost then
			local each = cost / math.max(rec.yield or 1, 1)
			if not best or each < best.cost or (each == best.cost and rec.name < best.rec.name) then
				best = { rec = rec, cost = each }
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
--   learning it); age (days since the auction price); stale; hidden (marked "doesn't sell").
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
	row.age = ns.Prices.Age(rec.product)
	row.stale = (row.age and row.age >= (ns.db.staleDays or 3)) and true or false
	row.hidden = ns.db.hidden[rec.product] and true or false
	return row
end

-- The rows the Crafts tab lists for a profession, most profitable first, and how many were left out:
-- { losses = n, hidden = n, unknown = n }.
function Profit.Rows(prof)
	local db, memo = ns.db, {}
	local rows, left = {}, { losses = 0, hidden = 0, unknown = 0 }
	for _, rec in ipairs(ns.Recipes.List(prof)) do
		if rec.source.kind == "unknown" and not db.showUnknown then
			left.unknown = left.unknown + 1
		else
			local row = Profit.Evaluate(prof, rec, memo)
			if row.hidden and not db.showHidden then
				left.hidden = left.hidden + 1
			elseif (not row.profit or row.profit <= 0) and not db.showLosses then
				left.losses = left.losses + 1
			else
				rows[#rows + 1] = row
			end
		end
	end
	table.sort(rows, function(a, b)
		if (a.profit ~= nil) ~= (b.profit ~= nil) then return a.profit ~= nil end
		if a.profit and a.profit ~= b.profit then return a.profit > b.profit end
		return a.rec.name < b.rec.name
	end)
	return rows, left
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
