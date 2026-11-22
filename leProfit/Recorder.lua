-- leProfit: what the game shows you. Which recipes you know comes from the game itself
-- (Recipes.lua asks IsPlayerSpell); the profession window, when you open it, adds what each makes
-- and from what, and recipes the built-in data lacks. Vendors give material prices and the patterns
-- they sell; trainers what they charge for each recipe. leProfit never opens a window itself.
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
			for prof, def in pairs(ns.professions) do
				for _, w in ipairs(def.windowNames) do
					if name:find(w, 1, true) then match = prof end
				end
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

-- The profession window, if one is shown: Forever's ProfessionsFrame, or the older TradeSkillFrame.
function Recorder.Frame()
	for _, name in ipairs({ "ProfessionsFrame", "TradeSkillFrame" }) do
		local f = rawget(_G, name)
		if f and f.IsShown and f:IsShown() then return f end
	end
end

-- How many of a profession's recipes this character knows (by the game, or its window).
function Recorder.KnownCount(prof)
	local n = 0
	for _, rec in ipairs(ns.Recipes.List(prof)) do
		if rec.learned then n = n + 1 end
	end
	return n
end

-- Learning a recipe (at a trainer, or from a pattern) marks it known straight away; the game
-- says which recipe. The next look at the profession window fills in the rest. A few recipes
-- (Forever's camp and home items) are listed by several professions: it's marked in each.
function Recorder.Learned(recipeID)
	if not (ns.db and recipeID) then return end
	local found = false
	for prof, def in pairs(ns.professions) do
		local own = ns.db.recipes[prof] and ns.db.recipes[prof][recipeID]
		local data = def.recipes[recipeID]
		if own or data then
			ns.db.recipes[prof] = ns.db.recipes[prof] or {}
			if not own then
				own = { name = data.name, icon = data.icon, product = data.product, yield = data.yield, reagents = data.reagents }
				ns.db.recipes[prof][recipeID] = own
			end
			own.learned = true
			found = true
		end
	end
	if found then ns.DataChanged() end
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
	-- Smelting recipes belong to Mining: a stale smelting list read as another profession (too short
	-- for the check above to catch) is left alone.
	if prof ~= "Mining" then
		for i = #list, 1, -1 do
			if list[i].name:find("^Smelt ") then table.remove(list, i) end
		end
	end

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

-- Every item any profession's recipe uses, gathered once and again when the data changes (with
-- all eight modules that's over 2,000 recipes, too many to search for each item a vendor sells).
local materials, materialsVersion = nil, nil
local function IsMaterial(itemID)
	if materialsVersion ~= ns.dataVersion then
		materials, materialsVersion = {}, ns.dataVersion
		for prof, def in pairs(ns.professions) do
			for _, rec in pairs(def.recipes) do
				for _, r in ipairs(rec.reagents) do materials[r[1]] = true end
			end
			for _, rec in pairs(ns.db.recipes[prof] or {}) do
				for _, r in ipairs(rec.reagents or {}) do materials[r[1]] = true end
			end
		end
	end
	return materials[itemID] or false
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

-- Where you're standing (at a vendor: where the vendor is): zone, subzone, map and x, y (0 to 1).
local function Where()
	local mapID = C_Map and Try(C_Map.GetBestMapForUnit, "player")
	local map = mapID and Try(C_Map.GetMapInfo, mapID)
	local pos = mapID and Try(C_Map.GetPlayerMapPosition, mapID, "player")
	local x, y
	if pos and pos.GetXY then x, y = pos:GetXY() end
	return map and map.name or ns.Plain(Try(GetZoneText)), ns.Plain(Try(GetSubZoneText)), mapID, x, y
end

-- The vendor's own faction: Alliance, Horde, or Neutral (friendly to both, in goblin towns).
local function NPCFaction()
	local faction = ns.Plain(Try(UnitFactionGroup, "npc"))
	if faction == "Alliance" or faction == "Horde" then return faction end
	if Try(UnitReaction, "npc", "player") == 4 then return "Neutral" end
	return faction
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
					local zone, subZone, mapID, x, y = Where()
					ns.adb.patterns[prof][recipe] = {
						itemID = itemID, price = price, vendor = vendor, zone = zone, subZone = subZone,
						faction = NPCFaction(), mapID = mapID, x = x, y = y,
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

-- Trainers -------------------------------------------------------------------------------------

-- The profession a trainer's recipe belongs to: the skill line the trainer files it under, else
-- the one profession with a recipe of that name. Ranks ("Journeyman Blacksmith") aren't recipes.
local function TrainerProfession(i, name, names)
	local function Has(prof)
		if not names[prof] then
			names[prof] = {}
			for _, rec in ipairs(ns.Recipes.List(prof)) do names[prof][rec.name] = true end
		end
		return names[prof][name]
	end
	local line = GetTrainerServiceSkillLine and ns.Plain(Try(GetTrainerServiceSkillLine, i))
	if line and ns.professions[line] then return Has(line) and line or nil end
	local found
	for prof in pairs(ns.professions) do
		if Has(prof) then
			if found then return nil end -- in two professions: can't tell which
			found = prof
		end
	end
	return found
end

-- What a profession trainer charges for each recipe it lists, and the skill it needs. Trainers
-- aren't in the game data, so this is how their costs get known (account-wide: every character
-- pays the same; tools/update_data.py adds them to the built-in data). Only what the window lists
-- is read: its filters may hide some.
function Recorder.ScanTrainer()
	if not (ns.adb and GetNumTrainerServices and GetTrainerServiceInfo and GetTrainerServiceCost) then return end
	local names, recorded = {}, 0
	for i = 1, (Try(GetNumTrainerServices) or 0) do
		local name, _, kind = Try(GetTrainerServiceInfo, i)
		name = ns.Plain(name)
		local prof = name and kind ~= "header" and TrainerProfession(i, name, names)
		local cost = prof and Try(GetTrainerServiceCost, i)
		if type(cost) == "number" then
			local _, skill = Try(GetTrainerServiceSkillReq, i)
			skill = type(skill) == "number" and skill > 0 and skill or nil
			ns.adb.training[prof] = ns.adb.training[prof] or {}
			local old = ns.adb.training[prof][name]
			if not old or old.cost ~= cost or old.skill ~= skill then
				ns.adb.training[prof][name] = { cost = cost, skill = skill }
				recorded = recorded + 1
			end
		end
	end
	if recorded > 0 then
		ns.Print(("recorded %d trainer cost%s."):format(recorded, recorded == 1 and "" or "s"))
		ns.DataChanged()
	end
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "NEW_RECIPE_LEARNED", "MERCHANT_SHOW", "MERCHANT_UPDATE",
	"TRAINER_SHOW", "TRAINER_UPDATE", "SPELLS_CHANGED", "SKILL_LINES_CHANGED" }) do
	pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event, arg)
	if event == "SPELLS_CHANGED" or event == "SKILL_LINES_CHANGED" then
		-- What the character knows may have changed (and at login, the spells are only ready now).
		ns.DataChanged()
	elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
		Recorder.ScanMerchant()
	elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
		Recorder.ScanTrainer()
	else
		if event == "NEW_RECIPE_LEARNED" then Recorder.Learned(arg) end
		RecordSoon()
	end
end)
