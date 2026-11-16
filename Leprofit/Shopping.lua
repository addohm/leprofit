-- Leprofit: the shopping list. Crafts you plan (added from the Crafts tab's materials panel, saved
-- per character in ns.db.plan) and every material they need, combined: what you hold counts once,
-- and materials are bought as they are (the owner's pick: no crafting them first). Send to
-- Auctionator makes one "Leprofit" list from it, as the source addon's Shopping.lua does.
local ADDON, ns = ...

local Shopping = {}
ns.Shopping = Shopping

Shopping.LIST_NAME = "Leprofit"

local function FindRecipe(prof, id)
	for _, rec in ipairs(ns.Recipes.List(prof)) do
		if rec.id == id then return rec end
	end
end

-- Adds n crafts of a recipe (more of it, if it's planned already).
function Shopping.Add(prof, rec, n)
	n = math.max(1, math.floor(n or 1))
	for _, p in ipairs(ns.db.plan) do
		if p.prof == prof and p.id == rec.id then
			p.count = p.count + n
			ns.Refresh()
			return p.count
		end
	end
	table.insert(ns.db.plan, { prof = prof, id = rec.id, count = n })
	ns.Refresh()
	return n
end

function Shopping.SetCount(i, n)
	local p = ns.db.plan[i]
	if not p then return end
	n = math.floor(tonumber(n) or 0)
	if n < 1 then table.remove(ns.db.plan, i) else p.count = n end
	ns.Refresh()
end

function Shopping.Remove(i)
	table.remove(ns.db.plan, i)
	ns.Refresh()
end

function Shopping.Clear()
	wipe(ns.db.plan)
	ns.Refresh()
end

-- The plan and its materials. Returns:
--   crafts: { { plan, rec (nil if its recipe is gone) } } in the order added;
--   materials: { { itemID, need, have, buy, price, cost, vendor } }, what to buy first (dearest
--     first, then unpriced), then what you already hold enough of;
--   total: the gold you'd spend, or nil when something to buy has no price; priced: the total of
--     what has a price.
function Shopping.Build()
	local crafts, needs, order = {}, {}, {}
	for _, p in ipairs(ns.db.plan) do
		local rec = ns.professions[p.prof] and FindRecipe(p.prof, p.id)
		crafts[#crafts + 1] = { plan = p, rec = rec }
		for _, r in ipairs(rec and rec.reagents or {}) do
			if not needs[r[1]] then
				needs[r[1]] = 0
				order[#order + 1] = r[1]
			end
			needs[r[1]] = needs[r[1]] + r[2] * p.count
		end
	end
	local materials, priced, unpriced = {}, 0, false
	for _, itemID in ipairs(order) do
		local need, have = needs[itemID], ns.ItemCount(itemID)
		local buy = math.max(0, need - have)
		local price, how = ns.Prices.Buy(itemID)
		local cost = price and price * buy or nil
		if buy > 0 then
			if cost then priced = priced + cost else unpriced = true end
		end
		materials[#materials + 1] = {
			itemID = itemID, need = need, have = have, buy = buy, price = price, cost = cost, vendor = how == "vendor",
		}
	end
	table.sort(materials, function(a, b)
		if (a.buy > 0) ~= (b.buy > 0) then return a.buy > 0 end
		if (a.cost ~= nil) ~= (b.cost ~= nil) then return a.cost ~= nil end
		if a.cost and a.cost ~= b.cost then return a.cost > b.cost end
		return ns.ItemName(a.itemID) < ns.ItemName(b.itemID)
	end)
	return crafts, materials, (not unpriced) and priced or nil, priced
end

-- Send to Auctionator ---------------------------------------------------------------------------

local function AuctionatorAPI()
	local A = rawget(_G, "Auctionator")
	local api = type(A) == "table" and type(A.API) == "table" and A.API.v1
	if type(api) == "table" and api.CreateShoppingList then return api end
	return nil
end

function Shopping.CanSend()
	return AuctionatorAPI() ~= nil
end

-- One search term in Auctionator's format: the exact name and how many. Older Auctionator versions
-- differ in what ConvertToSearchString takes, so a plain exact-name search is the fallback.
local function SearchString(api, name, quantity)
	if api.ConvertToSearchString then
		local s = ns.Try(api.ConvertToSearchString, ADDON, { searchString = name, isExact = true, quantity = quantity })
		if type(s) == "string" and s ~= "" then return s end
	end
	return '"' .. name .. '"'
end

-- Makes (or remakes) the "Leprofit" list in Auctionator from what's left to buy, leaving out what
-- vendors sell and items whose names haven't loaded yet. Returns how many items went in, or nil.
function Shopping.SendToAuctionator()
	local api = AuctionatorAPI()
	if not api then
		ns.Print("Auctionator isn't installed, or is too old to take shopping lists.")
		return nil
	end
	local _, materials = Shopping.Build()
	local terms, vendor, unnamed = {}, {}, 0
	for _, m in ipairs(materials) do
		if m.buy > 0 then
			local name = ns.ItemName(m.itemID)
			if name:match("^item %d+$") then
				unnamed = unnamed + 1
			elseif m.vendor then
				vendor[#vendor + 1] = name
			else
				terms[#terms + 1] = SearchString(api, name, m.buy)
			end
		end
	end
	if #terms == 0 then
		if #vendor > 0 then
			ns.Print("nothing to buy at the auction house. From a vendor: " .. table.concat(vendor, ", ") .. ".")
		elseif unnamed > 0 then
			ns.Print("the game hasn't loaded those items' names yet; try again in a moment.")
		else
			ns.Print("nothing to buy: you hold everything on the list.")
		end
		return 0
	end
	local ok, err = pcall(api.CreateShoppingList, ADDON, Shopping.LIST_NAME, terms)
	if not ok then
		ns.Print("Auctionator didn't take the list: " .. tostring(err))
		return nil
	end
	ns.Print(("sent %d item%s to Auctionator's |cffffffff%s|r shopping list. At the auction house, open Auctionator's Shopping tab and pick that list.")
		:format(#terms, #terms == 1 and "" or "s", Shopping.LIST_NAME))
	if #vendor > 0 then print("  Left out because a vendor sells them: " .. table.concat(vendor, ", ") .. ".") end
	if unnamed > 0 then
		print(("  %d item%s left out because the game hasn't loaded %s name yet; send again in a moment.")
			:format(unnamed, unnamed == 1 and "" or "s", unnamed == 1 and "its" or "their"))
	end
	return #terms
end
