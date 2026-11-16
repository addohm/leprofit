-- Leprofit: the Options tab. How profit is worked out (which price, the cut, the undercut), what the
-- Crafts list leaves out, the buttons, and the items marked "doesn't sell", each with an Unhide
-- button. Everything here is saved for this character.
local _, ns = ...
local UI = ns.UI

local function Percent(list)
	local out = {}
	for _, n in ipairs(list) do out[#out + 1] = { n, n .. "%" } end
	return out
end

local DAYS = {}
for _, n in ipairs({ 1, 2, 3, 5, 7, 14 }) do DAYS[#DAYS + 1] = { n, n == 1 and "1 day" or (n .. " days") } end

local stack, settings, hiddenHeading, noneRow, allRow, footer
local hiddenRows = {} -- reused rows for the hidden items' list

local function Setting(key)
	return function() return ns.db[key] end, function(v)
		ns.db[key] = v
		ns.Refresh()
	end
end

-- The items marked "doesn't sell", sorted by name.
local function HiddenItems()
	local list = {}
	for itemID in pairs(ns.db.hidden) do list[#list + 1] = itemID end
	table.sort(list, function(a, b)
		local na, nb = ns.ItemName(a), ns.ItemName(b)
		if na ~= nb then return na < nb end
		return a < b
	end)
	return list
end

local function HiddenRow(panel, i)
	if hiddenRows[i] then return hiddenRows[i] end
	local row
	row = UI.OptionButton(panel, "", "Unhide", function()
		ns.db.hidden[row.itemID] = nil
		ns.Window.Refresh()
	end)
	hiddenRows[i] = row
	return row
end

local function Build(panel)
	stack = UI.Stack(panel)
	settings = {}
	local function Add(row) settings[#settings + 1] = row end

	Add(UI.OptionHeading(panel, "Prices"))
	local get, set = Setting("rankBy")
	Add(UI.OptionSelect(panel, "Profit from", {
		{ "buyout", "Lowest buyout" }, { "market", "Market value" },
	}, get, set, { tooltip = {
		"Profit from",
		"Which auction price profit is worked out from. Lowest buyout is what you can sell for today (Auctionator or TSM). Market value is TSM's steadier average; without TSM the lowest buyout is used. Click the Crafts list's headings to sort it.",
	} }))
	get, set = Setting("showMarket")
	Add(UI.OptionCheck(panel, "Show the Market column (needs TSM)", get, set, {
		"Market column",
		"TradeSkillMaster's market value, a steadier average than the lowest buyout. TSM doesn't seem to run on Forever yet; without it the column shows -.",
	}))
	get, set = Setting("cut")
	Add(UI.OptionSelect(panel, "Auction house cut", Percent({ 0, 1, 3, 5, 10, 15 }), get, set, { tooltip = {
		"Auction house cut",
		"What the auction house keeps when an item sells. Classic's faction auction houses took 5%.",
	} }))
	get, set = Setting("undercut")
	Add(UI.OptionSelect(panel, "Undercut", Percent({ 0, 1, 2, 3, 5, 10 }), get, set, { tooltip = {
		"Undercut",
		"How far under the price you post your items.",
	} }))
	get, set = Setting("staleDays")
	Add(UI.OptionSelect(panel, "Flag prices older than", DAYS, get, set, { tooltip = {
		"Flag prices older than",
		"Crafts whose auction price (from Auctionator) is this old get a note: nobody may have listed the item since.",
	} }))

	Add(UI.OptionHeading(panel, "The Crafts list"))
	get, set = Setting("knownOnly")
	Add(UI.OptionCheck(panel, "Show only recipes this character knows", get, set))
	get, set = Setting("showLosses")
	Add(UI.OptionCheck(panel, "Show crafts at a loss or without a price", get, set))
	get, set = Setting("showUnknown")
	Add(UI.OptionCheck(panel, "Show recipes nobody has recorded a trainer or vendor for", get, set, {
		"Recipes with no known source",
		"Drops, quests, and recipes Forever lists but no one can learn. Hidden by default so they don't crowd the list.",
	}))

	Add(UI.OptionHeading(panel, "Buttons"))
	Add(UI.OptionCheck(panel, "Minimap button", function() return not ns.db.minimap.hide end,
		function(v) ns.Minimap.SetShown(v) end))
	Add(UI.OptionCheck(panel, "Button on the profession window", function() return ns.db.professionButton end,
		function(v)
			ns.db.professionButton = v
			ns.ProfessionButton.Apply()
		end))

	hiddenHeading = UI.OptionHeading(panel, "Hidden items")
	noneRow = UI.OptionText(panel, "None. Items you mark Doesn't sell on the Crafts tab are listed here.", 24)
	allRow = UI.OptionButton(panel, "", "Unhide all", function()
		wipe(ns.db.hidden)
		ns.Window.Refresh()
	end)
	footer = UI.OptionText(panel, function()
		return "Settings are saved for this character. " .. ns.Version()
	end, 30)
end

-- The page is laid out again each time, since the hidden items' list changes.
local function Refresh()
	stack:Reset()
	for _, row in ipairs(settings) do stack:Add(row) end
	stack:Add(hiddenHeading)
	local items = HiddenItems()
	if #items == 0 then
		stack:Add(noneRow)
	else
		for i, itemID in ipairs(items) do
			local row = HiddenRow(stack.inner, i)
			row.itemID = itemID
			row.label:SetText(ns.ItemNameColored(itemID))
			stack:Add(row)
		end
		if #items > 1 then stack:Add(allRow) end
	end
	stack:Add(footer)
	stack:Done()
	stack:Sync()
end

local function Defaults()
	ns.ResetOptions()
	ns.ProfessionButton.Apply()
end

ns.Window.AddPage({ id = "options", label = "Options", build = Build, refresh = Refresh, defaults = Defaults })
