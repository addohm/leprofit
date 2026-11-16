-- Leprofit: the Options tab. How profit is worked out (which price, the cut, the undercut), what the
-- Crafts list leaves out, and the buttons. Everything here is saved for this character.
local _, ns = ...
local UI = ns.UI

local function Percent(list)
	local out = {}
	for _, n in ipairs(list) do out[#out + 1] = { n, n .. "%" } end
	return out
end

local DAYS = {}
for _, n in ipairs({ 1, 2, 3, 5, 7, 14 }) do DAYS[#DAYS + 1] = { n, n == 1 and "1 day" or (n .. " days") } end

local stack

local function Setting(key)
	return function() return ns.db[key] end, function(v)
		ns.db[key] = v
		ns.Refresh()
	end
end

local function Build(panel)
	stack = UI.Stack(panel)
	stack:Add(UI.OptionHeading(panel, "Prices"))
	local get, set = Setting("rankBy")
	stack:Add(UI.OptionSelect(panel, "Rank by", {
		{ "buyout", "Lowest buyout" }, { "market", "Market value" },
	}, get, set, { tooltip = {
		"Rank by",
		"Which auction price profit is worked out from. Lowest buyout is what you can sell for today (Auctionator or TSM). Market value is TSM's steadier average; without TSM the lowest buyout is used.",
	} }))
	get, set = Setting("cut")
	stack:Add(UI.OptionSelect(panel, "Auction house cut", Percent({ 0, 1, 3, 5, 10, 15 }), get, set, { tooltip = {
		"Auction house cut",
		"What the auction house keeps when an item sells. Classic's faction auction houses took 5%.",
	} }))
	get, set = Setting("undercut")
	stack:Add(UI.OptionSelect(panel, "Undercut", Percent({ 0, 1, 2, 3, 5, 10 }), get, set, { tooltip = {
		"Undercut",
		"How far under the price you post your items.",
	} }))
	get, set = Setting("staleDays")
	stack:Add(UI.OptionSelect(panel, "Flag prices older than", DAYS, get, set, { tooltip = {
		"Flag prices older than",
		"Crafts whose auction price (from Auctionator) is this old get a note: nobody may have listed the item since.",
	} }))

	stack:Add(UI.OptionHeading(panel, "The Crafts list"))
	get, set = Setting("showLosses")
	stack:Add(UI.OptionCheck(panel, "Show crafts at a loss or without a price", get, set))
	get, set = Setting("showHidden")
	stack:Add(UI.OptionCheck(panel, "Show items marked doesn't sell", get, set))
	get, set = Setting("showUnknown")
	stack:Add(UI.OptionCheck(panel, "Show recipes nobody has recorded a trainer or vendor for", get, set, {
		"Recipes with no known source",
		"Drops, quests, and recipes Forever lists but no one can learn. Hidden by default so they don't crowd the list.",
	}))

	stack:Add(UI.OptionHeading(panel, "Buttons"))
	stack:Add(UI.OptionCheck(panel, "Minimap button", function() return not ns.db.minimap.hide end,
		function(v) ns.Minimap.SetShown(v) end))
	stack:Add(UI.OptionCheck(panel, "Button on the profession window", function() return ns.db.professionButton end,
		function(v)
			ns.db.professionButton = v
			ns.ProfessionButton.Apply()
		end))
	stack:Add(UI.OptionText(panel, function()
		return "Settings are saved for this character. " .. ns.Version()
	end, 30))
end

local function Refresh()
	stack:Sync()
end

local function Defaults()
	ns.ResetOptions()
	ns.ProfessionButton.Apply()
end

ns.Window.AddPage({ id = "options", label = "Options", build = Build, refresh = Refresh, defaults = Defaults })
