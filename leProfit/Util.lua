-- leProfit: small helpers shared by the other files: safe calls, money text, item names, icons,
-- what an item sells to a vendor for, whether it binds on pickup, and how many you hold.
local _, ns = ...

-- Calls fn safely and returns everything it returns; nil if it's missing or errors.
local function Pass(ok, ...)
	if ok then return ... end
	return nil
end
function ns.Try(fn, ...)
	if not fn then return nil end
	return Pass(pcall(fn, ...))
end
local Try = ns.Try

-- A string the addon may look at, or nil. Forever hides some names from addons ("secret values",
-- an NPC's name for example), and comparing one is an error.
function ns.Plain(v)
	if type(v) ~= "string" then return nil end
	local isSecret = rawget(_G, "issecretvalue")
	if type(isSecret) == "function" then
		local ok, secret = pcall(isSecret, v)
		if ok and secret == true then return nil end
	end
	if not pcall(function() return v == "" end) then return nil end
	return v
end

-- Copper as gold, silver and copper with the coin icons. Above a gold the copper is dropped, so
-- the columns stay short. Negative amounts are red with a minus.
function ns.Money(copper)
	if not copper then return "|cff999999-|r" end
	local negative = copper < 0
	copper = math.floor(math.abs(copper) + 0.5)
	if copper >= 10000 then copper = copper - copper % 100 end
	if copper == 0 then return "0" end
	local text
	if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
		text = C_CurrencyInfo.GetCoinTextureString(copper)
	elseif GetCoinTextureString then
		text = GetCoinTextureString(copper)
	else
		text = copper .. "c"
	end
	return negative and ("|cffff5555-|r" .. text) or text
end

-- Timing ----------------------------------------------------------------------------------------

-- How long each kind of leProfit's work takes (an event, a redraw, a slice of sums), for
-- /leprofit perf: the way to find what's behind a lag spike.
local perf = {}
function ns.Timed(name, fn, ...)
	local start = debugprofilestop()
	local a, b, c = fn(...)
	local ms = debugprofilestop() - start
	local p = perf[name]
	if not p then
		p = { n = 0, total = 0, worst = 0 }
		perf[name] = p
	end
	p.n, p.total = p.n + 1, p.total + ms
	if ms > p.worst then p.worst = ms end
	return a, b, c
end

-- The timings, slowest first: { { name, n, total, worst } }.
function ns.Timings()
	local list = {}
	for name, p in pairs(perf) do list[#list + 1] = { name = name, n = p.n, total = p.total, worst = p.worst } end
	table.sort(list, function(a, b) return a.worst > b.worst end)
	return list
end

function ns.ResetTimings()
	perf = {}
end

-- Item names --------------------------------------------------------------------------------

-- Items whose names the game hasn't loaded yet: ask for them, remember each name when it
-- arrives, and redraw. Each item is asked for once a session: one the game never fills in can't
-- keep the sums being redone.
local asked = {}
local function RequestName(itemID)
	if asked[itemID] or not (Item and Item.CreateFromItemID) then return end
	asked[itemID] = true
	local item = Try(Item.CreateFromItemID, Item, itemID)
	if not item or Try(item.IsItemEmpty, item) then return end
	pcall(item.ContinueOnItemLoad, item, function()
		local name = Try(item.GetItemName, item)
		if name and ns.adb then ns.adb.itemNames[itemID] = name end
		ns.ItemsLoaded()
	end)
end

-- Items finish loading in bursts, hundreds when a long list is first shown. What they reveal (a
-- name, what a vendor pays, whether it binds) can change the sums, so those are redone once a
-- second at most rather than for each item.
local loadedTimer = false
function ns.ItemsLoaded()
	if loadedTimer then return end
	loadedTimer = true
	C_Timer.After(1, function()
		loadedTimer = false
		ns.SumsChanged()
	end)
end

function ns.ItemName(itemID)
	if not itemID then return "?" end
	local name = C_Item and C_Item.GetItemNameByID and Try(C_Item.GetItemNameByID, itemID)
	name = name or (ns.adb and ns.adb.itemNames[itemID])
	if not name then
		for _, def in pairs(ns.professions) do
			name = name or def.itemNames[itemID]
		end
	end
	if not name then RequestName(itemID) end
	return name or ("item " .. itemID)
end

-- The item's name in its quality colour, when the game knows the quality.
function ns.ItemNameColored(itemID)
	local name = ns.ItemName(itemID)
	local quality = C_Item and C_Item.GetItemQualityByID and Try(C_Item.GetItemQualityByID, itemID)
	local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
	if color and color.hex then return color.hex .. name .. "|r" end
	return name
end

-- The item's link, once the game has loaded the item.
function ns.ItemLink(itemID)
	local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
	local _, link = ns.Try(getInfo, itemID)
	if not link then RequestName(itemID) end
	return link
end

-- Shift-click (the game's "chat link" click) puts the item's link in the text box you're typing in:
-- chat, or the auction house's search. Ctrl-click shows it in the dressing room. True if it was one
-- of those clicks. The game's HandleModifiedItemClick does both; failing that, the chat box only.
function ns.ItemModifiedClick(itemID)
	if not (IsModifiedClick("CHATLINK") or IsModifiedClick("DRESSUP")) then return false end
	local link = itemID and ns.ItemLink(itemID)
	if not link then return true end
	local handle = rawget(_G, "HandleModifiedItemClick")
	if handle then
		handle(link)
	elseif IsModifiedClick("CHATLINK") then
		local util = rawget(_G, "ChatFrameUtil")
		local insert = (util and util.InsertLink) or rawget(_G, "ChatEdit_InsertLink")
		if insert then insert(link) end
	end
	return true
end

function ns.ItemIcon(itemID)
	local icon = itemID and C_Item and C_Item.GetItemIconByID and Try(C_Item.GetItemIconByID, itemID)
	return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- What the item sells to a vendor for, and whether it binds when picked up (so it can't be
-- posted): GetItemInfo's 11th and 14th returns. Unknown until the game has loaded the item.
-- Read once per item: it doesn't change, and the list asks for hundreds.
local sales = {}
function ns.ItemSale(itemID)
	local s = sales[itemID]
	if s then return s[1], s[2] end
	local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
	local ok, name, _, _, _, _, _, _, _, _, _, sellPrice, _, _, bindType = pcall(getInfo, itemID)
	if not ok or not name then
		RequestName(itemID)
		return nil, nil
	end
	sales[itemID] = { sellPrice or 0, bindType == 1 }
	return sellPrice or 0, bindType == 1
end

-- Forgets what ns.ItemSale read (tests change items under it).
function ns.ForgetItemSales()
	sales = {}
end

-- How many you hold in your bags and bank.
function ns.ItemCount(itemID)
	local count = (C_Item and C_Item.GetItemCount) or GetItemCount
	return Try(count, itemID, true, false, true, true) or 0
end

-- Your skill in a profession, or nil if you don't have it.
function ns.Skill(profession)
	for i = 1, (Try(GetNumSkillLines) or 0) do
		local name, isHeader, _, rank = Try(GetSkillLineInfo, i)
		if name == profession and not isHeader then return rank end
	end
	local a, b = Try(GetProfessions)
	for _, index in ipairs({ a, b }) do
		local name, _, rank = Try(GetProfessionInfo, index)
		if name == profession then return rank end
	end
	return nil
end
