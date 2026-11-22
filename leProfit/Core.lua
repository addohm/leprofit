-- leProfit: settings, the profession modules, events and slash commands. Settings are per character
-- (leProfitCharDB, ns.db); what you record at vendors is shared by your characters (leProfitDB, ns.adb).
local ADDON, ns = ...

ns.ICON = "Interface\\AddOns\\leProfit\\Media\\Icon" -- art/make_logo.py

local DEFAULTS = {
	rankBy = "buyout",       -- rank by "buyout" (the lowest buyout) or "market" (TSM's market value)
	cut = 5,                 -- the auction house cut, percent
	undercut = 0,            -- how far under the price you post, percent
	staleDays = 3,           -- flag items whose auction price is this many days old or more
	hideLosses = false,      -- leave out crafts at 0 or negative profit, and ones that can't be priced
	hideUnlearned = false,   -- list only the recipes this character knows
	showAll = false,         -- also list the recipes needing more skill than you have (greyed out)
	showMarket = false,      -- the Avg 14d column (Auctionator's 14-day average, or TSM's market value)
	showTrend = false,       -- the Trend column (Auctionator's history)
	showSeen = false,        -- the Seen column: days listed of the last 14
	showListed = false,      -- the Listed column: how many at the last scan
	sortBy = "profit",       -- the Crafts list's order: "item", "cost", "buyout", "market" or "profit"
	sortDesc = true,         -- highest (or Z) first
	hidden = {},             -- itemID -> true: marked "doesn't sell", never listed (Options unhides them)
	plan = {},               -- the shopping list: { { prof, id (recipe), count } } (Shopping.lua)
	recipes = {},            -- profession -> recipeID -> what the profession window showed (Recorder.lua)
	crafts = 1,              -- the craft count in the materials panel
	window = {},             -- the window: pos, size, tab
	minimap = { angle = 300, hide = false }, -- clear of Nothing Wasted (200), Ticky (225), Leboof (250), Leproc (275)
}
ns.DEFAULTS = DEFAULTS

-- The settings the Options tab's Defaults button puts back.
ns.OPTION_KEYS = { "rankBy", "cut", "undercut", "staleDays", "showMarket", "showTrend", "showSeen", "showListed", "hideLosses", "hideUnlearned", "showAll" }

local ACCOUNT_DEFAULTS = {
	vendorPrices = {}, -- itemID -> copper for one, recorded at vendors
	itemNames = {},    -- itemID -> name, for items the game hasn't loaded yet
	patterns = {},     -- profession -> recipe name -> { itemID, price, vendor, zone, subZone, faction }
	training = {},     -- profession -> recipe name -> { cost, skill }, recorded at trainers
}

local function CopyDefaults(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then
			dst[k] = type(v) == "table" and CopyDefaults({}, v) or v
		elseif type(v) == "table" and type(dst[k]) == "table" then
			CopyDefaults(dst[k], v)
		end
	end
	return dst
end

function ns.Print(msg)
	print("|cffffd100leProfit|r: " .. msg)
end

function ns.Version()
	local v = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
	return "v" .. v .. (ns.build and (" build " .. ns.build) or "")
end

function ns.ResetOptions()
	for _, k in ipairs(ns.OPTION_KEYS) do ns.db[k] = DEFAULTS[k] end
end

-- Professions ----------------------------------------------------------------------------------

-- Each profession's data file (Data/<Profession>.lua) registers it here as the addon loads.
ns.professions, ns.professionOrder = {}, {}
ns.dataVersion = 0 -- bumped whenever recipes, patterns or prices recorded here change

function ns.DataChanged()
	ns.dataVersion = ns.dataVersion + 1
	ns.Refresh()
end

function ns.RegisterProfession(def)
	if type(def) ~= "table" or type(def.name) ~= "string" then return end
	def.recipes, def.training, def.patterns = def.recipes or {}, def.training or {}, def.patterns or {}
	def.vendorPrices, def.itemNames = def.vendorPrices or {}, def.itemNames or {}
	def.otherPatterns, def.free = def.otherPatterns or {}, def.free or {}
	def.windowNames = def.windowNames or { def.name } -- what the game calls its profession window
	if not ns.professions[def.name] then
		table.insert(ns.professionOrder, def.name)
		table.sort(ns.professionOrder)
	end
	ns.professions[def.name] = def
	ns.DataChanged()
end

-- Leprofit 1.0 came with a separate Leprofit_<Profession> addon per profession. Their data is
-- built in now; if old copies are still in AddOns, they call this when they load, and it ignores
-- them. Their folders can be deleted.
Leprofit = { RegisterProfession = function() end }

-- The profession the window shows: the last one picked, else the first this character has, else
-- the first. nil while the dropdown shows every profession (ns.ALL).
ns.ALL = "all"
function ns.ShowingAll()
	return ns.db and ns.db.profession == ns.ALL and #ns.professionOrder > 0 or false
end
function ns.CurrentProfession()
	local name = ns.db and ns.db.profession
	if name == ns.ALL and #ns.professionOrder > 0 then return nil end
	if name and ns.professions[name] then return name end
	for _, prof in ipairs(ns.professionOrder) do
		if ns.Skill(prof) then return prof end
	end
	return ns.professionOrder[1]
end

function ns.SetProfession(name)
	if ns.professions[name] or name == ns.ALL then
		ns.db.profession = name
		ns.Refresh()
	end
end

-- Refreshing ---------------------------------------------------------------------------------

-- Many events can arrive at once (bags, prices, the profession list): redraw once, a moment later.
local queued = false
function ns.Refresh()
	if queued or not ns.Window then return end
	queued = true
	C_Timer.After(0.2, function()
		queued = false
		ns.Window.Refresh()
	end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")
events:SetScript("OnEvent", function(_, event, arg)
	if event == "ADDON_LOADED" and arg == ADDON then
		-- Before the rename to leProfit (1.1.0) the settings were LeprofitCharDB and LeprofitDB (the
		-- TOC still loads them): carry them over once.
		local oldChar, oldAccount = rawget(_G, "LeprofitCharDB"), rawget(_G, "LeprofitDB")
		if leProfitCharDB == nil and type(oldChar) == "table" then leProfitCharDB = oldChar end
		if leProfitDB == nil and type(oldAccount) == "table" then leProfitDB = oldAccount end
		LeprofitCharDB, LeprofitDB = nil, nil
		leProfitCharDB = CopyDefaults(type(leProfitCharDB) == "table" and leProfitCharDB or {}, DEFAULTS)
		leProfitDB = CopyDefaults(type(leProfitDB) == "table" and leProfitDB or {}, ACCOUNT_DEFAULTS)
		ns.db, ns.adb = leProfitCharDB, leProfitDB
		-- Earlier builds: the Known only box is Hide unlearned now; the Show slider is gone.
		if ns.db.knownOnly then ns.db.hideUnlearned = true end
		ns.db.knownOnly, ns.db.showUpTo = nil, nil
		ns.db.showUnknown = nil -- Show all lists those now
		ns.db.professionButton = nil -- the profession window's button is gone
		ns.db.showLosses = nil -- Hide losses, off by default, replaced it: losses are listed (in red)
	elseif event == "PLAYER_LOGIN" then
		ns.Minimap.Init()
	else
		-- What you hold changed, or a scan brought new prices.
		ns.Refresh()
	end
end)

-- Slash commands -------------------------------------------------------------------------------

local function Status()
	ns.Print(ns.Version())
	ns.Print("Prices: " .. ns.Prices.SourcesText())
	ns.Print(ns.Questie.StatusText())
	-- This character's professions in full; the others just by name.
	local others = {}
	for _, name in ipairs(ns.professionOrder) do
		local known = ns.Recorder.KnownCount(name)
		if ns.Skill(name) or known > 0 then
			local count = 0
			for _ in pairs(ns.professions[name].recipes) do count = count + 1 end
			ns.Print(("%s (skill %s): %d recipes in the data, %d known by this character%s"):format(name,
				ns.Skill(name) or "?", count, known, known == 0 and " (open your profession window once)" or ""))
		else
			others[#others + 1] = name
		end
	end
	if #others > 0 then ns.Print("Also built in (pick one in the dropdown): " .. table.concat(others, ", ")) end
end

local function Help()
	ns.Print(ns.Version())
	ns.Print("/leprofit - open or close the window")
	ns.Print("/leprofit status - price sources, modules and recipes known")
	ns.Print("/leprofit why <item> - the whole sum for one craft: name, item ID or shift-click a link")
	ns.Print("/leprofit minimap - show or hide the minimap button")
	ns.Print("/leprofit reset - put the window back in the middle at its normal size")
end

SLASH_LEPROFIT1 = "/leprofit"
local function Why(query)
	if query == "" then
		ns.Print("/leprofit why <item>: type the item's name or shift-click it.")
		return
	end
	local prof, rec = ns.Profit.Find(query)
	if not prof then
		local list = rec or {}
		if #list == 0 then
			ns.Print("no recipe in your enabled professions makes '" .. query .. "'.")
		else
			local names = {}
			for i = 1, math.min(#list, 8) do names[i] = list[i].rec.name end
			ns.Print(("%d recipes match: %s%s. Type more of the name."):format(#list, table.concat(names, ", "),
				#list > 8 and ", ..." or ""))
		end
		return
	end
	for i, line in ipairs(ns.Profit.Explain(prof, rec)) do
		if i == 1 then ns.Print(line) else print(line) end
	end
end

SlashCmdList.LEPROFIT = function(msg)
	local cmd, rest = strtrim(msg or ""):match("^(%S*)%s*(.-)$")
	cmd = cmd:lower()
	if cmd == "" then
		ns.Window.Toggle()
	elseif cmd == "help" then
		Help()
	elseif cmd == "status" then
		Status()
	elseif cmd == "why" then
		Why(rest)
	elseif cmd == "minimap" then
		ns.Minimap.SetShown(ns.db.minimap.hide)
	elseif cmd == "reset" then
		ns.Window.ResetPosition()
		ns.Print("the window is back in the middle.")
	else
		ns.Print("unknown command '" .. cmd .. "'. /leprofit help lists the commands.")
	end
end
