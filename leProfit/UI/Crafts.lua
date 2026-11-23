-- leProfit: the Crafts tab. A profession dropdown, the crafts that make gold (most profitable first;
-- each column sorts), with Auctionator's history in optional columns, and for the one picked its
-- materials: what you hold, what to buy, and what that costs for the number of crafts you set.
local _, ns = ...

local ROW_H = 22
local RIGHT = 4           -- the list's right edge, inside the scroll bar
local DETAIL_H = 214      -- the materials panel at the bottom
local MAT_ROWS = 7        -- the most materials a recipe needs
local MAT_COLS = 5        -- Need, Have, Buy, Each, Cost
local GREY, ORANGE, RED = "|cff9d9d9d", "|cffff9933", "|cffff4040"
-- Where each material's price comes from, after its name in the materials panel.
local SOURCE_TAGS = {
	auction = GREY .. " (auction)|r", vendor = GREY .. " (vendor)|r", craft = GREY .. " (craft it)|r",
	none = ORANGE .. " (no price)|r",
}

local panel, scroll, inner, emptyText, leftText, picker, sourcesText, searchBox
local search = "" -- the search box's text; cleared when the window closes
local detail
local rows = {}
local selected -- the product of the recipe picked

-- The columns right of the item, left to right, with their widths. Profit is always at the right
-- edge; the ones with a setting are turned on in Options.
local COLUMNS = {
	{ key = "cost", w = 96 },
	{ key = "buyout", w = 96 },
	{ key = "market", w = 96, setting = "showMarket" },
	{ key = "trend", w = 44, setting = "showTrend" },
	{ key = "seen", w = 48, setting = "showSeen" },
	{ key = "listed", w = 52, setting = "showListed" },
	{ key = "profit", w = 96 },
}

local function Shown(col)
	return not col.setting or (ns.db[col.setting] and true or false)
end

-- Places a row's (or the header's) columns from the right edge, hiding the ones turned off; the
-- name stops where they start.
local function PlaceColumns(f, name, owner)
	local x = RIGHT
	for i = #COLUMNS, 1, -1 do
		local col = COLUMNS[i]
		local fs, on = f[col.key], Shown(col)
		fs:SetShown(on)
		if f.buttons then f.buttons[col.key]:SetShown(on) end
		if on then
			fs:ClearAllPoints()
			fs:SetPoint("RIGHT", fs.anchor, "RIGHT", -x, 0)
			x = x + col.w
		end
	end
	if name then
		name:ClearAllPoints()
		name:SetPoint("TOPLEFT", 28, -4)
		name:SetPoint("RIGHT", owner, "RIGHT", -x, 0)
	end
end

-- The headings: each is a button that sorts the list by its column; clicking it again reverses
-- the order. The one sorting has an arrow: up for lowest (or A) first, down for highest first.
local HEADINGS = {
	item = "Item", cost = "Cost", buyout = "Buyout", market = "Avg 14d", trend = "Trend", seen = "Seen",
	listed = "Listed", profit = "Profit",
}
local HEADING_TIPS = {
	item = "The item the recipe makes. A recipe that makes several shows x3 (or so) after it.",
	cost = "The materials for one craft, each at the cheaper of buying and crafting it.",
	buyout = "The lowest buyout for one item, from your last scan.",
	market = "The average of each day's lowest price over the last 14 days of your Auctionator scans (TSM's market value instead, if TSM is installed). One cheap listing doesn't swing it.",
	trend = "The last 3 days' prices against the 4 days before: up, down, or level (within 5%).",
	seen = "How many of the last 14 days it was listed in your scans. It only counts days you scanned.",
	listed = "How many were listed at your last scan: the competition you'd post against.",
	profit = "One craft's items after the cut, less the cost. A recipe that makes several sells them all, so Cost and Buyout don't add up for it.",
}
local UP, DOWN = "|TInterface\\Buttons\\Arrow-Up-Up:12:12|t", "|TInterface\\Buttons\\Arrow-Down-Up:12:12|t"
local TREND = { [1] = UP, [0] = GREY .. "=|r", [-1] = DOWN }

local function HeadingTexts(header)
	for key, label in pairs(HEADINGS) do
		local text = label
		if ns.db.sortBy == key then
			local arrow = ns.db.sortDesc and DOWN or UP
			text = key == "item" and (label .. " " .. arrow) or (arrow .. " " .. label)
		end
		header[key]:SetText(text)
	end
end

local function SortButton(header, key)
	local fs = header[key]
	local b = CreateFrame("Button", nil, header)
	b:SetPoint("TOPLEFT", fs, "TOPLEFT", -2, 3)
	b:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 2, -3)
	b:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
	b:SetScript("OnClick", function()
		if ns.db.sortBy == key then
			ns.db.sortDesc = not ns.db.sortDesc
		else
			ns.db.sortBy, ns.db.sortDesc = key, key ~= "item"
		end
		ns.Window.Refresh()
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(HEADINGS[key])
		GameTooltip:AddLine(HEADING_TIPS[key], 1, 1, 1, true)
		GameTooltip:AddLine("Click to sort by it; again to reverse.", 0.7, 0.7, 0.7, true)
		if key == "item" then GameTooltip:AddLine("Shift-click a row to link the item in chat or a search box.", 0.7, 0.7, 0.7, true) end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", GameTooltip_Hide)
	header.buttons[key] = b
end

local function Column(parent, font, width)
	local fs = parent:CreateFontString(nil, "OVERLAY", font)
	fs:SetWidth(width - 6)
	fs:SetJustifyH("RIGHT")
	fs:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
	fs.anchor = parent
	return fs
end

-- A profit: red, minus sign and all, at a loss; "?" when it can't be worked out.
local function ProfitText(p)
	if not p then return GREY .. "?|r" end
	if p < 0 then return RED .. "-" .. ns.Money(-p) .. "|r" end
	return ns.Money(p)
end

-- Each column's cell for a row.
local function CellText(key, row)
	if key == "cost" then return row.cost and ns.Money(row.cost) or (ORANGE .. "?|r") end
	if key == "buyout" then return ns.Money(row.buyout) end
	if key == "market" then return ns.Money(row.market) end
	if key == "trend" then return row.trend and TREND[row.trend] or (GREY .. "-|r") end
	if key == "seen" then return row.seen and (row.seen .. "/" .. row.days) or (GREY .. "-|r") end
	if key == "listed" then return row.listed and tostring(row.listed) or (GREY .. "-|r") end
	if key == "profit" then return ProfitText(row.profit) end
end

-- Where to learn a recipe you don't know, and what it pays back in; nil for one you know.
local function LearnLine(row, prof)
	local src = row.rec.source
	local skill = ns.Skill(prof)
	local function SkillText(need)
		if not need then return "" end
		if skill and skill >= need then return (" (skill %d)"):format(need) end
		return (" (skill %d, you have %s)"):format(need, skill or "none")
	end
	local text
	if src.kind == "trainer" then
		text = "Trainer " .. ns.Money(src.cost) .. SkillText(src.skill)
	elseif src.kind == "pattern" then
		text = "Pattern " .. ns.Money(src.cost) .. SkillText(src.skill) .. ":"
	elseif src.kind == "free" then
		text = "Comes with the profession"
	elseif src.kind == "other" then
		if ns.Profit.Bound(src) then
			text = ns.ItemName(src.itemID) .. SkillText(src.skill) .. ", binds when picked up:"
		else
			text = ns.ItemName(src.itemID) .. " " .. (row.learnCost and ns.Money(row.learnCost) or "(no auction price yet)")
				.. SkillText(src.skill) .. " at the auction house, or:"
		end
	elseif src.kind == "unknown" then
		text = "Where to learn it isn't known"
	else
		return nil
	end
	if row.payback then
		text = text .. (", pays back in %d craft%s"):format(row.payback, row.payback == 1 and "" or "s")
	end
	return text
end

-- Anything to be wary of about a craft.
local function Warnings(row)
	local list = {}
	if row.missing then list[#list + 1] = "No price for " .. ns.ItemName(row.missing) end
	if row.bop then
		list[#list + 1] = "Binds on pickup: vendor only"
	elseif row.via == "vendor" then
		list[#list + 1] = (row.buyout or row.market) and "A vendor pays more than the auction house" or "No auction price: the vendor's price"
	end
	if row.stale then list[#list + 1] = ("The auction price is %d days old"):format(row.age) end
	return list
end

-- The row's tooltip: the game's item tooltip, then leProfit's sum, the auction history, where to
-- learn the recipe and any warnings. The list's columns are a summary; this is the detail.
local function RowTooltip(owner, row, prof)
	local tip = GameTooltip
	tip:SetOwner(owner, "ANCHOR_RIGHT")
	tip:SetItemByID(row.product)
	tip:AddLine(" ")
	tip:AddLine("leProfit: " .. prof)
	local function Pair(label, value) tip:AddDoubleLine(label, value, 1, 0.82, 0, 1, 1, 1) end
	Pair("Cost (one craft)", row.cost and ns.Money(row.cost) or (ORANGE .. "?|r"))
	if row.value then
		local how = row.via == "vendor" and "to a vendor" or ("after the " .. ns.db.cut .. "% cut")
		Pair("Sells for " .. how .. (row.yield ~= 1 and (", x" .. row.yield) or ""), ns.Money(row.value))
	end
	Pair("Profit", ProfitText(row.profit))
	Pair("Lowest buyout", ns.Money(row.buyout))
	local h = ns.Prices.History(row.product)
	local market = row.market or ns.Prices.Market(row.product)
	if h then
		Pair(ns.Prices.MarketName(), ns.Money(market))
		local trend = h.trend and ({ [1] = "going up", [0] = "level", [-1] = "going down" })[h.trend] or "-"
		Pair("Trend", trend)
		Pair("Seen", ("%d of the last %d days"):format(h.seen, h.days))
		if h.listed then Pair("Listed at the last scan", tostring(h.listed)) end
	elseif market then
		Pair(ns.Prices.MarketName(), ns.Money(market))
	end
	local learn = LearnLine(row, prof)
	if learn then
		tip:AddLine("Not learned yet. " .. learn, 1, 1, 1, true)
		local src = row.rec.source
		if src.kind == "pattern" or src.kind == "other" then
			local where = ns.Recipes.WhereLines(src, 6)
			if #where == 0 then where = { "Where to get it isn't recorded yet" } end
			for _, line in ipairs(where) do tip:AddLine("  " .. line, 0.85, 0.85, 0.85, true) end
		end
	end
	for _, w in ipairs(Warnings(row)) do tip:AddLine(w, 1, 0.6, 0.2, true) end
	tip:AddLine("Click for its materials. Shift-click to link it.", 0.6, 0.6, 0.6, true)
	tip:Show()
end

-- List rows -------------------------------------------------------------------------------------

local function GetRow(i)
	if rows[i] then return rows[i] end
	local b = CreateFrame("Button", nil, inner)
	b:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
	b.sel = b:CreateTexture(nil, "BACKGROUND")
	b.sel:SetAllPoints()
	b.sel:SetColorTexture(1, 0.82, 0, 0.12)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(18, 18)
	b.icon:SetPoint("TOPLEFT", 4, -2)
	b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	b.name:SetPoint("TOPLEFT", 28, -4)
	b.name:SetPoint("RIGHT", b, "RIGHT", -RIGHT, 0)
	b.name:SetJustifyH("LEFT")
	b.name:SetWordWrap(false)
	b.line = CreateFrame("Frame", nil, b) -- the columns
	b.line:SetAllPoints()
	for _, col in ipairs(COLUMNS) do
		b[col.key] = Column(b.line, col.key == "profit" and "GameFontHighlight" or "GameFontHighlightSmall", col.w)
	end
	b:SetScript("OnClick", function(self)
		if ns.ItemModifiedClick(self.product) then return end
		selected = self.product
		ns.Window.Refresh()
	end)
	b:SetScript("OnEnter", function(self)
		if self.row then RowTooltip(self, self.row, self.row.prof) end
	end)
	b:SetScript("OnLeave", GameTooltip_Hide)
	rows[i] = b
	return b
end

-- The materials panel ------------------------------------------------------------------------------

local function MaterialRow(parent, y)
	local r = CreateFrame("Button", nil, parent)
	r:SetScript("OnEnter", function(self)
		if not self.itemID then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetItemByID(self.itemID)
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", GameTooltip_Hide)
	r:SetScript("OnClick", function(self) ns.ItemModifiedClick(self.itemID) end)
	r:SetPoint("TOPLEFT", 0, y)
	r:SetPoint("RIGHT")
	r:SetHeight(15)
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.name:SetPoint("LEFT", 4, 0)
	r.name:SetPoint("RIGHT", r, "RIGHT", -(MAT_COLS * 70 + 4), 0)
	r.name:SetJustifyH("LEFT")
	r.name:SetWordWrap(false)
	r.cols = {}
	for i = 1, MAT_COLS do
		local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		fs:SetWidth(66)
		fs:SetJustifyH("RIGHT")
		fs:SetPoint("RIGHT", r, "RIGHT", -((MAT_COLS - i) * 70 + 4), 0)
		r.cols[i] = fs
	end
	return r
end

local function BuildDetail()
	detail = CreateFrame("Frame", nil, panel)
	detail:SetPoint("BOTTOMLEFT")
	detail:SetPoint("BOTTOMRIGHT")
	detail:SetHeight(DETAIL_H)
	local rule = detail:CreateTexture(nil, "BORDER")
	rule:SetPoint("TOPLEFT")
	rule:SetPoint("TOPRIGHT")
	rule:SetHeight(1)
	rule:SetColorTexture(0.6, 0.45, 0.15, 0.6)

	detail.icon = detail:CreateTexture(nil, "ARTWORK")
	detail.icon:SetSize(26, 26)
	detail.icon:SetPoint("TOPLEFT", 4, -8)
	detail.title = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	detail.title:SetPoint("LEFT", detail.icon, "RIGHT", 8, 0)
	detail.title:SetPoint("RIGHT", detail, "RIGHT", -350, 0)
	detail.title:SetJustifyH("LEFT")
	detail.title:SetWordWrap(false)

	detail.hide = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
	detail.hide:SetSize(110, 22)
	detail.hide:SetPoint("TOPRIGHT", -2, -10)
	detail.hide:SetText("Doesn't sell")
	detail.hide:SetScript("OnClick", function()
		local item = selected
		if not item then return end
		ns.Confirm(("Hide %s from the list?\n\nHidden items are listed in Options, where you can unhide them.")
			:format(ns.ItemNameColored(item)), "Hide", function()
			ns.db.hidden[item] = true
			ns.Window.Refresh()
		end)
	end)
	detail.hide:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Doesn't sell")
		GameTooltip:AddLine("Hide this item from the list, for example when nobody buys it. Hidden items are listed in Options, where you can unhide them.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	detail.hide:SetScript("OnLeave", GameTooltip_Hide)

	detail.add = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
	detail.add:SetSize(96, 22)
	detail.add:SetPoint("RIGHT", detail.hide, "LEFT", -8, 0)
	detail.add:SetText("Add to list")
	detail.add:SetScript("OnClick", function()
		local row = detail.row
		if not row then return end
		local n = math.max(1, ns.db.crafts or 1)
		local total = ns.Shopping.Add(row.prof, row.rec, n)
		ns.Print(("added %d x %s to the shopping list (%d planned)."):format(n, ns.ItemNameColored(row.product), total))
	end)
	detail.add:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Add to list")
		GameTooltip:AddLine("Adds the number of crafts in the box to the Shopping tab's list.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	detail.add:SetScript("OnLeave", GameTooltip_Hide)

	detail.count = CreateFrame("EditBox", nil, detail, "InputBoxTemplate")
	detail.count:SetSize(40, 20)
	detail.count:SetPoint("RIGHT", detail.add, "LEFT", -10, 0)
	detail.count:SetAutoFocus(false)
	detail.count:SetNumeric(true)
	detail.count:SetMaxLetters(3)
	local function Apply(self)
		local n = tonumber(self:GetText() or "")
		if n and n >= 1 then ns.db.crafts = math.floor(n) end
		self:ClearFocus()
		ns.Window.Refresh()
	end
	detail.count:SetScript("OnEnterPressed", Apply)
	detail.count:SetScript("OnEditFocusLost", function(self)
		local n = tonumber(self:GetText() or "")
		if n and n >= 1 and n ~= ns.db.crafts then Apply(self) end
	end)
	detail.count:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		ns.Window.Refresh()
	end)
	local label = detail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("RIGHT", detail.count, "LEFT", -8, 0)
	label:SetText("Crafts")

	detail.sale = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	detail.sale:SetPoint("TOPLEFT", 4, -40)
	detail.sale:SetPoint("RIGHT", detail, "RIGHT", -4, 0)
	detail.sale:SetJustifyH("LEFT")
	detail.learn = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	detail.learn:SetPoint("TOPLEFT", 4, -56)
	detail.learn:SetPoint("RIGHT", detail, "RIGHT", -4, 0)
	detail.learn:SetJustifyH("LEFT")

	detail.header = MaterialRow(detail, -76)
	detail.header.name:SetFontObject("GameFontNormalSmall")
	detail.header.name:SetText("Material")
	for i, text in ipairs({ "Need", "Have", "Buy", "Each", "Cost" }) do
		detail.header.cols[i]:SetFontObject("GameFontNormalSmall")
		detail.header.cols[i]:SetText(text)
	end
	detail.mats = {}
	for i = 1, MAT_ROWS do detail.mats[i] = MaterialRow(detail, -76 - 15 * i) end
	detail.total = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	detail.total:SetPoint("BOTTOMLEFT", 4, 4)
	detail.total:SetPoint("RIGHT", detail, "RIGHT", -4, 0)
	detail.total:SetJustifyH("LEFT")
end

local function SaleText(row)
	local db = ns.db
	local each
	if row.via == "auction" then
		local price = (db.rankBy == "market" and (row.market or row.buyout)) or (row.buyout or row.market)
		local which = (price == row.market and price ~= row.buyout) and ns.Prices.MarketName() or "lowest buyout"
		each = ("Sells for %s each (%s %s, less %d%% cut%s)."):format(ns.Money(row.value), which, ns.Money(price),
			db.cut, db.undercut > 0 and (" and " .. db.undercut .. "% undercut") or "")
	elseif row.via == "vendor" then
		each = (row.bop and "Binds on pickup, so it can't be posted: a vendor pays %s." or "A vendor pays %s each.")
			:format(ns.Money(row.value))
	else
		each = ORANGE .. "No auction price yet: scan the auction house with Auctionator or TSM.|r"
	end
	local makes = row.yield ~= 1 and ("Makes %s. "):format(row.yield) or ""
	local profit = row.profit and (" Profit %s a craft."):format(ProfitText(row.profit)) or ""
	return makes .. each .. profit
end

local function LearnText(row, prof)
	local src = row.rec.source
	local payback = row.payback and (" Pays back in %d craft%s."):format(row.payback, row.payback == 1 and "" or "s") or ""
	if src.kind == "known" then return "You know this recipe." end
	if src.kind == "trainer" then
		return ("Learn it from a %s trainer for %s%s.%s"):format(prof, ns.Money(src.cost),
			src.skill and (" at skill " .. src.skill) or "", payback)
	end
	local where = (src.kind == "pattern" or src.kind == "other") and ns.Recipes.WhereLines(src) or {}
	local more = #where > 1 and (" %d more in the tooltip."):format(#where - 1) or ""
	if src.kind == "pattern" then
		return ("The pattern costs %s%s.%s %s.%s"):format(ns.Money(src.cost), src.skill and (" (skill " .. src.skill .. ")") or "",
			payback, where[1] or "No seller recorded", more)
	end
	if src.kind == "free" then return "It comes with the profession." end
	if src.kind == "other" then
		local skill = src.skill and (" (skill " .. src.skill .. ")") or ""
		local first = (where[1] or "Where to get it isn't recorded yet") .. "." .. more
		if ns.Profit.Bound(src) then
			return ("Learn it from %s%s, which binds when picked up. %s"):format(ns.ItemName(src.itemID), skill, first)
		end
		return ("Learn it from %s%s: %s at the auction house.%s %s"):format(ns.ItemName(src.itemID), skill,
			row.learnCost and ns.Money(row.learnCost) or "no price seen yet (scan for it)", payback, first)
	end
	return "Where to learn it isn't known: a quest, perhaps, or not in Forever."
end

local function ShowDetail(row, prof)
	if not row then
		detail:Hide()
		return
	end
	detail:Show()
	detail.row = row
	local n = math.max(1, ns.db.crafts or 1)
	detail.icon:SetTexture(ns.ItemIcon(row.product))
	detail.title:SetText(ns.ItemNameColored(row.product))
	if not detail.count:HasFocus() then detail.count:SetText(tostring(n)) end
	detail.sale:SetText(SaleText(row))
	detail.learn:SetText(LearnText(row, prof))
	local list, spend = ns.Profit.Shopping(row, n)
	for i, r in ipairs(detail.mats) do
		local m = list[i]
		r.itemID = m and m.itemID
		if m then
			r.name:SetText(ns.ItemNameColored(m.itemID) .. (SOURCE_TAGS[m.how] or SOURCE_TAGS.none))
			r.cols[1]:SetText(m.need)
			r.cols[2]:SetText(m.have > 0 and m.have or (GREY .. "0|r"))
			r.cols[3]:SetText(m.buy > 0 and m.buy or (GREY .. "-|r"))
			r.cols[4]:SetText(m.price and ns.Money(m.price) or (ORANGE .. "?|r"))
			r.cols[5]:SetText(m.buy > 0 and (m.cost and ns.Money(m.cost) or (ORANGE .. "?|r")) or (GREY .. "-|r"))
			r:Show()
		else
			r:Hide()
		end
	end
	local total = row.cost and ns.Money(row.cost * n) or (ORANGE .. "?|r")
	detail.total:SetText(("Materials for %d: %s. You'd spend %s on what you don't have."):format(n, total,
		spend and ns.Money(spend) or (ORANGE .. "?|r")))
end

-- The page ------------------------------------------------------------------------------------

-- The profession shown: a dropdown (Blizzard's menu system, like leboof's checklist) listing the
-- modules ticked for this character, each with its icon. Picking one also opens its window.
local function ProfessionText(name)
	local icon = ns.professions[name] and ns.professions[name].icon
	return icon and ("|T" .. icon .. ":16:16|t " .. name) or name
end

local function PickProfession(name)
	selected = nil
	ns.SetProfession(name)
	ns.Window.Refresh()
end

function ns.BuildProfessionMenu(_, root)
	-- All professions: every ticked module's crafts in one list, to search them all at once.
	if #ns.professionOrder > 1 then
		root:CreateRadio("All professions", function() return ns.ShowingAll() end, function() PickProfession(ns.ALL) end)
	end
	for _, name in ipairs(ns.professionOrder) do
		root:CreateRadio(ProfessionText(name), function() return ns.CurrentProfession() == name end,
			function() PickProfession(name) end)
	end
end

-- A checkbox with its label in the top bar; the label greys when the box is disabled.
local function TopCheck(parent, label, tooltip, onClick)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(26, 26)
	cb.label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
	cb.label:SetText(label)
	cb:SetScript("OnClick", function(self)
		onClick(self:GetChecked() and true or false)
		ns.Window.Refresh()
	end)
	cb:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine(label)
		GameTooltip:AddLine(tooltip, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	cb:SetScript("OnLeave", GameTooltip_Hide)
	cb.SetUsable = function(self, usable)
		self:SetEnabled(usable)
		if usable then self.label:SetTextColor(1, 1, 1) else self.label:SetTextColor(0.5, 0.5, 0.5) end
	end
	return cb
end

local function Picker(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(28)
	local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
	dropdown:SetWidth(190)
	dropdown:SetPoint("LEFT", 2, 0)
	dropdown:SetDefaultText("|cff999999No modules|r")
	dropdown:SetupMenu(ns.BuildProfessionMenu)
	row.dropdown = dropdown
	row.right = 196
	-- The profession can change elsewhere (the profession window's button): show the one in use.
	row.Sync = function() dropdown:GenerateMenu() end
	return row
end

local function Build(p)
	panel = p
	picker = Picker(panel)
	picker:SetPoint("TOPLEFT", 0, 2)
	picker:SetPoint("RIGHT", panel, "RIGHT")
	panel.picker = picker

	local losses = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	losses:SetSize(26, 26)
	losses:SetPoint("LEFT", picker, "LEFT", picker.right + 8, 0)
	losses:SetScript("OnClick", function(self)
		ns.db.hideLosses = self:GetChecked() and true or false
		ns.Window.Refresh()
	end)
	local lossesLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	lossesLabel:SetPoint("LEFT", losses, "RIGHT", 2, 0)
	lossesLabel:SetText("Hide losses")
	panel.losses = losses

	panel.hideUnlearned = TopCheck(panel, "Hide unlearned",
		"List only the recipes this character knows. Otherwise the ones you could learn now are listed too, greyed out, with what learning them costs in their tooltip.",
		function(v) ns.db.hideUnlearned = v end)
	panel.hideUnlearned:SetPoint("LEFT", lossesLabel, "RIGHT", 12, 0)
	panel.showAll = TopCheck(panel, "Show all",
		"Also list, greyed out, the recipes that need more skill than you have, those from patterns that bind when picked up, and those nobody knows a source for. Recipes only the other side can get are never listed.",
		function(v) ns.db.showAll = v end)
	panel.showAll:SetPoint("LEFT", panel.hideUnlearned.label, "RIGHT", 12, 0)

	local header = CreateFrame("Frame", nil, panel)
	-- The search: item, recipe and material names, as you type.
	searchBox = CreateFrame("EditBox", nil, panel, "SearchBoxTemplate")
	searchBox:SetSize(260, 20)
	searchBox:SetPoint("TOPLEFT", 8, -30)
	searchBox:SetAutoFocus(false)
	local hint = searchBox.Instructions -- the template's grey placeholder text
	if type(hint) == "table" and hint.SetText then hint:SetText("Search items and materials") end
	searchBox:HookScript("OnTextChanged", function(self)
		search = strtrim(self:GetText() or "")
		ns.Refresh()
	end)
	searchBox:HookScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)
	panel.search = searchBox
	-- Closing the window clears the search, so it never opens on a mysteriously short list.
	local window = ns.Window.Frame()
	if window then
		window:HookScript("OnHide", function()
			search = ""
			searchBox:SetText("")
		end)
	end

	header:SetPoint("TOPLEFT", 0, -56)
	header:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
	header:SetHeight(16)
	header.buttons = {}
	header.item = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	header.item:SetPoint("LEFT", 28, 0)
	header.item:SetWidth(160)
	header.item:SetJustifyH("LEFT")
	SortButton(header, "item")
	for _, col in ipairs(COLUMNS) do
		header[col.key] = Column(header, "GameFontNormalSmall", col.w)
		SortButton(header, col.key)
	end
	panel.header = header
	local rule = panel:CreateTexture(nil, "BORDER")
	rule:SetPoint("TOPLEFT", 0, -74)
	rule:SetPoint("TOPRIGHT", 0, -74)
	rule:SetHeight(1)
	rule:SetColorTexture(0.6, 0.45, 0.15, 0.6)

	scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -78)
	scroll:SetPoint("BOTTOMRIGHT", -24, DETAIL_H + 22)
	inner = CreateFrame("Frame", nil, scroll)
	inner:SetSize(500, 1)
	scroll:SetScrollChild(inner)
	scroll:SetScript("OnSizeChanged", function(_, width) inner:SetWidth(width) end)

	emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	emptyText:SetPoint("TOPLEFT", scroll, "TOPLEFT", 8, -12)
	emptyText:SetPoint("RIGHT", scroll, "RIGHT", -8, 0)
	emptyText:SetJustifyH("LEFT")

	-- Above the materials panel: what was left out, and where prices come from.
	sourcesText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	sourcesText:SetPoint("BOTTOMRIGHT", -4, DETAIL_H + 6)
	sourcesText:SetJustifyH("RIGHT")
	leftText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	leftText:SetPoint("BOTTOMLEFT", 4, DETAIL_H + 6)
	leftText:SetPoint("RIGHT", sourcesText, "LEFT", -12, 0)
	leftText:SetWordWrap(false)
	leftText:SetJustifyH("LEFT")

	BuildDetail()
end

local function LeftOutText(left)
	local parts = {}
	if left.nomatch > 0 then parts[#parts + 1] = left.nomatch .. " don't match the search" end
	if left.unlearned > 0 then parts[#parts + 1] = left.unlearned .. " you haven't learned" end
	if left.later > 0 then parts[#parts + 1] = left.later .. " needing more skill" end
	if left.losses > 0 then parts[#parts + 1] = left.losses .. " at a loss" end
	if left.unpriced > 0 then parts[#parts + 1] = left.unpriced .. " without a price" end
	if left.hidden > 0 then parts[#parts + 1] = left.hidden .. " marked doesn't sell" end
	if left.bound > 0 then parts[#parts + 1] = left.bound .. " from patterns that bind" end
	if left.unknown > 0 then parts[#parts + 1] = left.unknown .. " with no known source" end
	if left.otherSide > 0 then parts[#parts + 1] = left.otherSide .. " only the other side can get" end
	if #parts == 0 then return "" end
	return "Not listed: " .. table.concat(parts, ", ") .. "."
end

local function Refresh()
	picker.Sync()
	panel.losses:SetChecked(ns.db.hideLosses)
	panel.hideUnlearned:SetChecked(ns.db.hideUnlearned)
	panel.showAll:SetChecked(ns.db.showAll)
	panel.showAll:SetUsable(not ns.db.hideUnlearned)
	PlaceColumns(panel.header)
	HeadingTexts(panel.header)
	local hasAuction = ns.Prices.HasAuctionator() or ns.Prices.HasTSM()
	sourcesText:SetText((hasAuction and "Prices: " or ORANGE) .. ns.Prices.SourcesText() .. (hasAuction and "" or "|r"))

	local all = ns.ShowingAll()
	local prof = ns.CurrentProfession()
	if not prof and not all then
		for _, b in ipairs(rows) do b:Hide() end
		emptyText:SetText("No profession data loaded: leProfit's Data files are missing. Reinstall leProfit.")
		emptyText:Show()
		leftText:SetText("")
		detail:Hide()
		return
	end

	-- Many crafts' sums to work out (first time shown, or prices changed): spread over a few frames,
	-- keeping what's drawn until they're ready, then draw again.
	if not ns.Profit.Prepare(all and ns.professionOrder or { prof }, function() ns.Window.Refresh() end) then
		if not rows[1] or not rows[1]:IsShown() then
			emptyText:SetText("Working out the sums...")
			emptyText:Show()
		end
		leftText:SetText("Working out the sums...")
		return
	end

	local query = search ~= "" and search:lower() or nil
	local list, left
	if all then list, left = ns.Profit.RowsAll(query) else list, left = ns.Profit.Rows(prof, query) end
	local y, picked = 0, nil
	for i, row in ipairs(list) do
		local b = GetRow(i)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", 0, -y)
		b:SetPoint("RIGHT", inner, "RIGHT")
		b:SetHeight(ROW_H)
		y = y + ROW_H
		b.product, b.row = row.product, row
		b.icon:SetTexture(ns.ItemIcon(row.product))
		local yield = row.yield ~= 1 and (GREY .. " x" .. row.yield .. "|r") or ""
		-- Recipes you haven't learned are greyed out: grey name, grey icon, faded numbers.
		local learned = row.rec.source.kind == "known"
		b.icon:SetDesaturated(not learned)
		b.name:SetText((learned and ns.ItemNameColored(row.product) or (GREY .. ns.ItemName(row.product) .. "|r")) .. yield)
		b.line:SetAlpha(learned and 1 or 0.55)
		b.unlearned = not learned
		for _, col in ipairs(COLUMNS) do b[col.key]:SetText(CellText(col.key, row)) end
		PlaceColumns(b, b.name, b)
		b.sel:SetShown(row.product == selected)
		if row.product == selected then picked = row end
		b:Show()
	end
	for i = #list + 1, #rows do rows[i]:Hide() end
	inner:SetHeight(math.max(1, y))

	-- A profession with no recipe known: the game didn't say (it should), so the window may.
	local unread = prof and ns.Skill(prof) and ns.Recorder.KnownCount(prof) == 0
	local db = ns.db
	if #list == 0 then
		local text
		if query then
			text = ("Nothing matches \"%s\"%s."):format(search, all and "" or (" in " .. prof .. ". Pick All professions in the dropdown to search them all"))
		elseif prof and not ns.Skill(prof) and (db.hideUnlearned or not db.showAll) then
			text = "This character doesn't have " .. prof .. "." .. (db.hideUnlearned and " Untick Hide unlearned and tick" or " Tick")
				.. " Show all to see what it could learn."
		elseif prof and db.hideUnlearned and unread then
			text = ("leProfit doesn't know your %s recipes yet: open your %s window once."):format(prof, prof)
		elseif not hasAuction then
			text = "No auction prices: install Auctionator (or TSM) and scan the auction house, then open this again."
		elseif db.hideLosses then
			text = "Nothing here makes a profit at these prices. Untick Hide losses to see the rest"
				.. ((db.hideUnlearned or not db.showAll) and ", or tick Show all." or ".")
		elseif db.hideUnlearned then
			text = "No recipes known here. Untick Hide unlearned to see what you could learn."
		else
			text = "Nothing to list here." .. (db.showAll and "" or " Tick Show all to see recipes needing more skill.")
		end
		emptyText:SetText(text)
		emptyText:Show()
	else
		emptyText:Hide()
	end
	local leftOut = LeftOutText(left)
	if unread then
		leftOut = ORANGE .. ("Open your %s window so leProfit knows your recipes.|r "):format(prof) .. leftOut
	end
	leftText:SetText(leftOut)
	if not picked then
		picked = list[1]
		selected = picked and picked.product
		if rows[1] and picked then rows[1].sel:Show() end
	end
	ShowDetail(picked, picked and picked.prof)
end

ns.Window.AddPage({ id = "crafts", label = "Crafts", build = Build, refresh = Refresh })
