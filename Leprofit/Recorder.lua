-- Leprofit: what the game shows you. The profession window gives the recipes you know (and what
-- each makes, from what); vendors give material prices and the patterns they sell. Detection and
-- the guards against stale lists are the source addon's (its Recorder.lua and ReadMerchantItem).
local _, ns = ...
local Try = ns.Try

local Recorder = {}
ns.Recorder = Recorder

-- The profession window ------------------------------------------------------------------------

-- Each asks the game which profession window is open, a different way.
local DETECTORS = {
	function()
		local info = Try(C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo)
		return info and info.professionName
	end,
	function()
		local _, name = Try(C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLine)
		return name
	end,
	function()
		return (Try(GetTradeSkillLine))
	end,
}

local function Usable(name)
	name = ns.Plain(name)
	return name and name ~= "UNKNOWN" and name
end

-- Which registered profession the window shows, or nil. Right after switching windows the ways of
-- asking can disagree; with `strict` every one that answers must name the same profession.
function Recorder.OpenProfession(strict)
	local found
	for _, detect in ipairs(DETECTORS) do
		local name = Usable(detect())
		if name then
			local match
			for prof in pairs(ns.professions) do
				if name:find(prof, 1, true) then match = prof end
			end
			if strict and found and match ~= found then return nil end
			if strict and not match then return nil end
			found = found or match
			if not strict and found then return found end
		end
	end
	return found
end

local function ReadRecipes()
	local api = C_TradeSkillUI
	local ids = api and Try(api.GetAllRecipeIDs)
	if not ids then return nil end
	local list = {}
	for _, id in ipairs(ids) do
		local info = Try(api.GetRecipeInfo, id)
		local schematic = Try(api.GetRecipeSchematic, id, false)
		if info and info.name and schematic and schematic.outputItemID then
			local r = {
				id = id, name = info.name, learned = info.learned and true or false, icon = info.icon,
				product = schematic.outputItemID, reagents = {},
			}
			-- Some recipes make a few at a time: count the average.
			local lo, hi = schematic.quantityMin or 1, schematic.quantityMax or schematic.quantityMin or 1
			r.yield = (lo + math.max(lo, hi)) / 2
			for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
				local reagent = slot.reagents and slot.reagents[1]
				if reagent and reagent.itemID and slot.required ~= false then
					table.insert(r.reagents, { reagent.itemID, slot.quantityRequired or 1 })
				end
			end
			list[#list + 1] = r
		end
	end
	return list
end

-- Which other profession a recipe ID belongs to (a module's data or a list already read).
local function OtherProfession(id, prof)
	for name, def in pairs(ns.professions) do
		if name ~= prof and (def.recipes[id] or (ns.db.recipes[name] and ns.db.recipes[name][id])) then
			return name
		end
	end
end

function Recorder.Record()
	if not ns.db then return end
	local prof = Recorder.OpenProfession(true)
	if not prof then return end
	local list = ReadRecipes()
	if not list or #list == 0 then return end
	-- Right after switching windows the game can still hand over the previous profession's list.
	-- If most of it belongs to another profession, wait for the next update.
	local foreign = 0
	for _, r in ipairs(list) do
		if OtherProfession(r.id, prof) then foreign = foreign + 1 end
	end
	if foreign >= 5 and foreign * 2 >= #list then return end

	ns.db.recipes[prof] = ns.db.recipes[prof] or {}
	local store, changed = ns.db.recipes[prof], false
	for _, r in ipairs(list) do
		local old = store[r.id]
		if not old or old.learned ~= r.learned or old.product ~= r.product or #(old.reagents or {}) ~= #r.reagents
		   or old.yield ~= r.yield then
			changed = true
		end
		store[r.id] = { name = r.name, learned = r.learned, icon = r.icon, product = r.product, yield = r.yield, reagents = r.reagents }
	end
	if changed then ns.DataChanged() end
end

-- Profession events come several at a time: read once, half a second after the last.
local pending = false
local function RecordSoon()
	if pending then return end
	pending = true
	C_Timer.After(0.5, function()
		pending = false
		Recorder.Record()
	end)
end

-- Vendors ---------------------------------------------------------------------------------------

-- Every item any profession's recipe uses.
local function IsMaterial(itemID)
	for prof, def in pairs(ns.professions) do
		for _, rec in pairs(def.recipes) do
			for _, r in ipairs(rec.reagents) do
				if r[1] == itemID then return true end
			end
		end
		for _, rec in pairs(ns.db.recipes[prof] or {}) do
			for _, r in ipairs(rec.reagents or {}) do
				if r[1] == itemID then return true end
			end
		end
	end
	return false
end

-- The profession whose recipe a pattern ("Plans: Copper Chain Belt") teaches, and the recipe's name.
local PREFIXES = { "Plans", "Pattern", "Recipe", "Formula", "Schematic", "Manual" }
local function PatternFor(itemName)
	for _, prefix in ipairs(PREFIXES) do
		local recipe = itemName:match("^" .. prefix .. ": (.+)$")
		if recipe then
			for prof in pairs(ns.professions) do
				for _, rec in ipairs(ns.Recipes.List(prof)) do
					if rec.name == recipe then return prof, recipe end
				end
			end
		end
	end
end

local function MerchantItem(i)
	local itemID = Try(GetMerchantItemID, i)
	local name, price, stack, available, extended
	local info = C_MerchantFrame and Try(C_MerchantFrame.GetItemInfo, i)
	if info then
		name, price, stack, available, extended = info.name, info.price, info.stackCount, info.numAvailable, info.hasExtendedCost
	elseif GetMerchantItemInfo then
		local n, _, p, q, a, _, _, e = Try(GetMerchantItemInfo, i)
		name, price, stack, available, extended = n, p, q, a, e
	end
	return itemID, ns.Plain(name), price, stack, available, extended
end

local function Where()
	local mapID = C_Map and Try(C_Map.GetBestMapForUnit, "player")
	local map = mapID and Try(C_Map.GetMapInfo, mapID)
	return map and map.name or ns.Plain(Try(GetZoneText)), ns.Plain(Try(GetSubZoneText))
end

function Recorder.ScanMerchant()
	if not ns.db then return end
	local vendor = ns.Plain(Try(UnitName, "npc"))
	local changed, prices = false, 0
	for i = 1, (Try(GetMerchantNumItems) or 0) do
		local itemID, name, price, stack, available, extended = MerchantItem(i)
		if itemID and price and price > 0 and not extended then
			local prof, recipe = nil, nil
			if name then prof, recipe = PatternFor(name) end
			if prof then
				-- A pattern: limited stock is fine, vendors often sell just one at a time.
				ns.adb.patterns[prof] = ns.adb.patterns[prof] or {}
				local old = ns.adb.patterns[prof][recipe]
				if not old or old.price ~= price or old.vendor ~= vendor then
					local zone, subZone = Where()
					ns.adb.patterns[prof][recipe] = {
						itemID = itemID, price = price, vendor = vendor, zone = zone, subZone = subZone,
						faction = Try(UnitFactionGroup, "player"),
					}
					changed = true
					ns.Print(("recorded %s from %s: %s"):format(name, vendor or "this vendor", ns.Money(price)))
				end
			elseif (not available or available < 0) and IsMaterial(itemID) then
				-- A material in endless supply; the price is for the stack the vendor sells.
				local each = price / math.max(stack or 1, 1)
				if ns.adb.vendorPrices[itemID] ~= each then
					ns.adb.vendorPrices[itemID] = each
					if name then ns.adb.itemNames[itemID] = name end
					changed, prices = true, prices + 1
				end
			end
		end
	end
	if prices > 0 then
		ns.Print(("recorded %d material price%s from %s."):format(prices, prices == 1 and "" or "s", vendor or "this vendor"))
	end
	if changed then ns.DataChanged() end
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "NEW_RECIPE_LEARNED", "MERCHANT_SHOW", "MERCHANT_UPDATE" }) do
	pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event)
	if event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
		Recorder.ScanMerchant()
	else
		RecordSoon()
	end
end)
