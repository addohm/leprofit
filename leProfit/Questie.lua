-- leProfit: where a pattern comes from, asked of QuestieDB (the database Questie uses on Forever)
-- when it's installed, the way prices are asked of Auctionator. Nothing is copied from it: each
-- pattern item is looked up in game. Without it, the built-in data answers (Recipes.lua).
local _, ns = ...
local Try = ns.Try

local Q = {}
ns.Questie = Q

local CONTRACT = 3 -- the oldest QuestieDB contract with the factions' race masks (Enum.factionRaceMasks)
local MOST_DROPS = 3 -- creatures named when many drop a pattern ("a world drop")

local api, checked = nil, false
local function API()
	if checked then return api end
	checked = true
	local lib = rawget(_G, "LibQuestieDB")
	if type(lib) ~= "table" or type(lib.RequireContract) ~= "function" then return nil end
	local ok, fine = pcall(lib.RequireContract, CONTRACT)
	if not ok or not fine then return nil end
	if type(lib.Item) ~= "table" or type(lib.Npc) ~= "table" or type(lib.Quest) ~= "table" then return nil end
	api = lib
	return api
end

-- True when QuestieDB is installed and new enough.
function Q.Available()
	return API() ~= nil
end

local function Get(entity, id, key)
	local lib = API()
	local e = lib and lib[entity]
	if not (e and e.Get and id) then return nil end
	return Try(e.Get, id, key)
end

-- An area's name (QuestieDB keys spawns and quests by AreaTable ID).
local function AreaName(areaID)
	if type(areaID) ~= "number" or areaID <= 0 then return nil end
	local name = C_Map and C_Map.GetAreaInfo and Try(C_Map.GetAreaInfo, areaID)
	return ns.Plain(name)
end

-- Where an NPC or object first stands: zone name and x, y (0 to 100), from its spawns.
local function FirstSpawn(spawns)
	if type(spawns) ~= "table" then return nil end
	local best
	for zone in pairs(spawns) do
		if type(zone) == "number" and (not best or zone < best) then best = zone end
	end
	local point = best and type(spawns[best]) == "table" and spawns[best][1]
	return AreaName(best), point and tonumber(point[1]), point and tonumber(point[2])
end

-- Does a race mask hold any of these races? Masks pass 32 bits on Forever (its Skyborne races),
-- so this is arithmetic, not bit.band.
local function HasAnyBit(mask, other)
	mask, other = tonumber(mask) or 0, tonumber(other) or 0
	while mask > 0 and other > 0 do
		if mask % 2 == 1 and other % 2 == 1 then return true end
		mask, other = math.floor(mask / 2), math.floor(other / 2)
	end
	return false
end
Q.HasAnyBit = HasAnyBit -- (tests)

-- The sides a quest is for, from its required races (0: everyone).
local function QuestSides(races)
	races = tonumber(races) or 0
	local masks = API().Enum and API().Enum.factionRaceMasks
	if races == 0 or type(masks) ~= "table" then return true, true end
	return HasAnyBit(races, masks.Alliance), HasAnyBit(races, masks.Horde)
end

local function Place(zone, x, y)
	local text = zone and (" in " .. zone) or ""
	if x and y and (x ~= 0 or y ~= 0) then text = text .. (" at %.1f, %.1f"):format(x, y) end
	return text
end

local ONLY = { A = " (Alliance only)", H = " (Horde only)" }

-- Which sides can get an item, from the fewest lookups: its vendors' friendliness and its quests'
-- races; a drop, object or container is anyone's. Asked for every pattern when a list is built,
-- so it reads no names or places. nil when QuestieDB knows no way to get it.
local function SideOf(itemID)
	local alliance, horde, any = false, false, false
	for _, npc in ipairs(Get("Item", itemID, "vendors") or {}) do
		local friendly = Get("Npc", npc, "friendlyToFaction")
		if friendly == "A" or friendly == "AH" then alliance = true end
		if friendly == "H" or friendly == "AH" then horde = true end
		any = true
	end
	for _, quest in ipairs(Get("Item", itemID, "questRewards") or {}) do
		local a, h = QuestSides(Get("Quest", quest, "requiredRaces"))
		alliance, horde, any = alliance or a, horde or h, true
	end
	if Get("Item", itemID, "npcDrops") or Get("Item", itemID, "objectDrops") or Get("Item", itemID, "itemDrops") then
		alliance, horde, any = true, true, true
	end
	if not any then return false end
	return { side = (alliance and not horde and "Alliance") or (horde and not alliance and "Horde") or nil }
end

-- Where an item comes from, as tooltip lines: its vendors (and whom they serve), the quests that
-- reward it (and for whom), and what drops it. Only read when a row's tooltip or /leprofit why
-- asks, since names and places cost more to read.
local function LinesOf(itemID)
	local lines = {}
	for _, npc in ipairs(Get("Item", itemID, "vendors") or {}) do
		local name = Get("Npc", npc, "name")
		if name then
			local friendly = Get("Npc", npc, "friendlyToFaction")
			lines[#lines + 1] = "Sold by " .. name .. Place(FirstSpawn(Get("Npc", npc, "spawns"))) .. (ONLY[friendly] or "")
		end
	end
	for _, quest in ipairs(Get("Item", itemID, "questRewards") or {}) do
		local name = Get("Quest", quest, "name")
		if name then
			local a, h = QuestSides(Get("Quest", quest, "requiredRaces"))
			local zone = Get("Quest", quest, "zoneOrSort")
			lines[#lines + 1] = ("Reward from the quest %s%s%s"):format(name, Place(AreaName(zone)),
				(a and not h and ONLY.A) or (h and not a and ONLY.H) or "")
		end
	end
	local drops = {}
	for _, npc in ipairs(Get("Item", itemID, "npcDrops") or {}) do
		local name = Get("Npc", npc, "name")
		if name then drops[#drops + 1] = { name = name, npc = npc } end
	end
	if #drops > MOST_DROPS then
		table.sort(drops, function(a, b) return a.name < b.name end)
		local some = {}
		for i = 1, MOST_DROPS do some[i] = drops[i].name end
		lines[#lines + 1] = ("Drops from %d creatures (a world drop), such as %s"):format(#drops, table.concat(some, ", "))
	else
		for _, d in ipairs(drops) do lines[#lines + 1] = "Drops from " .. d.name .. Place(FirstSpawn(Get("Npc", d.npc, "spawns"))) end
	end
	for _, object in ipairs(Get("Item", itemID, "objectDrops") or {}) do
		local name = Get("Object", object, "name")
		if name then lines[#lines + 1] = "Found in " .. name .. Place(FirstSpawn(Get("Object", object, "spawns"))) end
	end
	for _, container in ipairs(Get("Item", itemID, "itemDrops") or {}) do
		local name = Get("Item", container, "name")
		if name then lines[#lines + 1] = "Found in " .. name end
	end
	return lines
end

-- Each answer is read once per item: QuestieDB's data doesn't change while you play.
local sides, lines = {}, {}

-- Which side can get a pattern by QuestieDB: { side = "Alliance" / "Horde" / nil (both) }, or nil
-- when QuestieDB isn't installed or knows no way to get the item.
function Q.Side(itemID)
	if not itemID or not API() then return nil end
	if sides[itemID] == nil then sides[itemID] = SideOf(itemID) end
	return sides[itemID] or nil
end

-- Where a pattern comes from by QuestieDB, as lines; nil when it knows nothing.
function Q.Lines(itemID)
	if not Q.Side(itemID) then return nil end
	if not lines[itemID] then lines[itemID] = LinesOf(itemID) end
	return lines[itemID]
end

-- Forgets what was asked, so the next lookup checks for QuestieDB again (tests).
function Q.Forget()
	api, checked, sides, lines = nil, false, {}, {}
end

-- For /leprofit status.
function Q.StatusText()
	local lib = rawget(_G, "LibQuestieDB")
	if API() then return ("QuestieDB found (contract %s): it says where patterns come from"):format(tostring(lib.contractVersion)) end
	if type(lib) == "table" then return "QuestieDB is too old (needs contract " .. CONTRACT .. "): the built-in data says where patterns come from" end
	return "QuestieDB isn't installed: the built-in data says where patterns come from"
end
