-- Leprofit: the Crafts tab. A profession picker, the crafts that make gold (most profitable first,
-- with lowest buyout and market value), and for the one picked its materials: what you hold, what
-- to buy, and what that costs for the number of crafts you set.
local _, ns = ...

local ROW_H, NOTE_H = 22, 14
local COL_W = 96          -- the Cost, Buyout, Market and Profit columns
local RIGHT = 4           -- the list's right edge, inside the scroll bar
local DETAIL_H = 214      -- the materials panel at the bottom
local MAT_ROWS = 7        -- the most materials a recipe needs
local MAT_COLS = 5        -- Need, Have, Buy, Each, Cost
local GREY, ORANGE = "|cff9d9d9d", "|cffff9933"
-- Where each material's price comes from, after its name in the materials panel.
local SOURCE_TAGS = {
	auction = GREY .. " (auction)|r", vendor = GREY .. " (vendor)|r", craft = GREY .. " (craft it)|r",
	none = ORANGE .. " (no price)|r",
}

local panel, scroll, inner, emptyText, leftText, picker, sourcesText
local detail
local rows = {}
local selected -- the product of the recipe picked

-- Places the money columns of a row (or the header), left to right: Cost, Buyout, Market (when
-- that column is on) and Profit at the right edge; the name stops where they start.
local function Place(fs, slot)
	fs:ClearAllPoints()
	fs:SetPoint("RIGHT", fs.anchor, "RIGHT", -(slot * COL_W + RIGHT), 0)
end
local function PlaceColumns(f, name, owner)
	local market = ns.db.showMarket
	local n = market and 4 or 3
	Place(f.profit, 0)
	Place(f.market, 1)
	Place(f.buyout, market and 2 or 1)
	Place(f.cost, market and 3 or 2)
	f.market:SetShown(market and true or false)
	if f.buttons then f.buttons.market:SetShown(market and true or false) end
	if name then
		name:ClearAllPoints()
		name:SetPoint("TOPLEFT", 28, -4)
		name:SetPoint("RIGHT", owner, "RIGHT", -(n * COL_W + RIGHT), 0)
	end
end

-- The headings: each is a button that sorts the list by its column; clicking it again reverses
-- the order. The one sorting has an arrow: up for lowest (or A) first, down for highest first.
local HEADINGS = { item = "Item", cost = "Cost", buyout = "Buyout", market = "Market", profit = "Profit" }
local HEADING_TIPS = {
	item = "The item the recipe makes. A recipe that makes several shows x3 (or so) after it.",
	cost = "The materials for one craft, each at the cheaper of buying and crafting it.",
	buyout = "The lowest buyout for one item.",
	market = "TSM's market value for one item.",
	profit = "One craft's items after the cut, less the cost. A recipe that makes several sells them all, so Cost and Buyout don't add up for it.",
}
local UP, DOWN = "|TInterface\\Buttons\\Arrow-Up-Up:12:12|t", "|TInterface\\Buttons\\Arrow-Down-Up:12:12|t"

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

local function Column(parent, font, rightOffset, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY", font)
	fs:SetWidth(COL_W - 6)
	fs:SetJustifyH(justify or "RIGHT")
	fs:SetPoint("RIGHT", parent, "RIGHT", rightOffset, 0)
	fs.anchor = parent
	return fs
end

-- The notes under a craft: where to learn it and what it pays back in, and anything to be wary of.
local function Notes(row, prof)
	local notes, src = {}, row.rec.source
	local skill = ns.Skill(prof)
	local function SkillText(need)
		if not need then return "" end
		if skill and skill >= need then return (" (skill %d)"):format(need) end
		return (" (skill %d, you have %s)"):format(need, skill or "none")
	end
	if src.kind == "trainer" then
		notes[#notes + 1] = "Trainer " .. ns.Money(src.cost) .. SkillText(src.skill)
	elseif src.kind == "pattern" then
		local s = src.sellers and src.sellers[1]
		notes[#notes + 1] = "Pattern " .. ns.Money(src.cost) .. (s and (" from " .. s.vendor) or "") .. SkillText(src.skill)
	elseif src.kind == "unknown" then
		notes[#notes + 1] = "where to learn it isn't recorded"
	end
	if row.payback then
		notes[#notes + 1] = ("pays back in %d craft%s"):format(row.payback, row.payback == 1 and "" or "s")
	end
	if row.missing then
		notes[#notes + 1] = ORANGE .. "no price for " .. ns.ItemName(row.missing) .. "|r" .. GREY
	end
	if row.bop then
		notes[#notes + 1] = "binds on pickup: vendor only"
	elseif row.via == "vendor" then
		notes[#notes + 1] = (row.buyout or row.market) and "a vendor pays more" or "no auction price: vendor price"
	end
	if row.stale then
		notes[#notes + 1] = ORANGE .. ("auction price %d days old"):format(row.age) .. "|r" .. GREY
	end
	if #notes == 0 then return nil end
	return GREY .. table.concat(notes, " · ") .. "|r"
end

local function ProfitText(p)
	if not p then return GREY .. "?|r" end
	return ns.Money(p)
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
	b.name:SetPoint("RIGHT", b, "RIGHT", -(3 * COL_W + RIGHT), 0)
	b.name:SetJustifyH("LEFT")
	b.name:SetWordWrap(false)
	b.note = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.note:SetPoint("TOPLEFT", 28, -ROW_H + 2)
	b.note:SetPoint("RIGHT", b, "RIGHT", -RIGHT, 0)
	b.note:SetJustifyH("LEFT")
	b.note:SetWordWrap(false)
	b.line = CreateFrame("Frame", nil, b) -- the money columns sit on the first line
	b.line:SetPoint("TOPLEFT")
	b.line:SetPoint("TOPRIGHT")
	b.line:SetHeight(ROW_H)
	b.cost = Column(b.line, "GameFontHighlightSmall", 0)
	b.buyout = Column(b.line, "GameFontHighlightSmall", 0)
	b.market = Column(b.line, "GameFontHighlightSmall", 0)
	b.profit = Column(b.line, "GameFontHighlight", 0)
	b:SetScript("OnClick", function(self)
		if ns.ItemModifiedClick(self.product) then return end
		selected = self.product
		ns.Window.Refresh()
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetItemByID(self.product)
		GameTooltip:Show()
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
	detail.title:SetPoint("RIGHT", detail, "RIGHT", -250, 0)
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

	detail.count = CreateFrame("EditBox", nil, detail, "InputBoxTemplate")
	detail.count:SetSize(40, 20)
	detail.count:SetPoint("RIGHT", detail.hide, "LEFT", -12, 0)
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
		local which = (price == row.market and price ~= row.buyout) and "market value" or "lowest buyout"
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
	if src.kind == "pattern" then
		local s = src.sellers and src.sellers[1]
		local where = s and (" from %s (%s%s%s)"):format(s.vendor, s.zone or "?", s.subZone and (", " .. s.subZone) or "",
			(s.faction and s.faction ~= UnitFactionGroup("player") and s.faction ~= "Neutral") and (", " .. s.faction) or "") or ""
		local others = src.sellers and #src.sellers > 1 and (" %d other sellers."):format(#src.sellers - 1) or ""
		return ("The pattern costs %s%s%s.%s%s"):format(ns.Money(src.cost), where,
			src.skill and (", skill " .. src.skill) or "", payback, others)
	end
	return "Where to learn it isn't recorded: a drop, a quest, or not in Forever."
end

local function ShowDetail(row, prof)
	if not row then
		detail:Hide()
		return
	end
	detail:Show()
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

-- The profession shown: arrows on each side of its name, which steps to the next one.
local function Picker(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(28)
	local function Step(dir)
		local order = ns.professionOrder
		if #order == 0 then return end
		local idx = 1
		for i, name in ipairs(order) do
			if name == ns.CurrentProfession() then idx = i end
		end
		selected = nil
		ns.SetProfession(order[(idx - 1 + dir) % #order + 1])
		ns.Recorder.OpenWindow(ns.CurrentProfession())
		ns.Window.Refresh()
	end
	local function Arrow(dir, x)
		local b = CreateFrame("Button", nil, row)
		b:SetSize(26, 26)
		b:SetPoint("LEFT", x, 0)
		local base = dir < 0 and "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-" or "Interface\\Buttons\\UI-SpellbookIcon-NextPage-"
		b:SetNormalTexture(base .. "Up")
		b:SetPushedTexture(base .. "Down")
		b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
		b:SetScript("OnClick", function() Step(dir) end)
		return b
	end
	Arrow(-1, 0)
	local box = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	box:SetSize(150, 24)
	box:SetPoint("LEFT", 30, 0)
	box:SetScript("OnClick", function() Step(1) end)
	Arrow(1, 184)
	row.right = 212
	row.Sync = function()
		box:SetText(ns.CurrentProfession() or "|cff999999no modules|r")
	end
	return row
end

local function Build(p)
	panel = p
	picker = Picker(panel)
	picker:SetPoint("TOPLEFT", 0, 2)
	picker:SetPoint("RIGHT", panel, "RIGHT")

	local losses = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	losses:SetSize(26, 26)
	losses:SetPoint("LEFT", picker, "LEFT", picker.right + 8, 0)
	losses:SetScript("OnClick", function(self)
		ns.db.showLosses = self:GetChecked() and true or false
		ns.Window.Refresh()
	end)
	local lossesLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	lossesLabel:SetPoint("LEFT", losses, "RIGHT", 2, 0)
	lossesLabel:SetText("Show losses")
	panel.losses = losses

	local known = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	known:SetSize(26, 26)
	known:SetPoint("LEFT", lossesLabel, "RIGHT", 12, 0)
	known:SetScript("OnClick", function(self)
		ns.db.knownOnly = self:GetChecked() and true or false
		ns.Window.Refresh()
	end)
	local knownLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	knownLabel:SetPoint("LEFT", known, "RIGHT", 2, 0)
	knownLabel:SetText("Known only")
	panel.known = known

	sourcesText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	sourcesText:SetPoint("RIGHT", picker, "RIGHT", -4, 0)
	sourcesText:SetJustifyH("RIGHT")

	local header = CreateFrame("Frame", nil, panel)
	header:SetPoint("TOPLEFT", 0, -32)
	header:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
	header:SetHeight(16)
	header.buttons = {}
	header.item = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	header.item:SetPoint("LEFT", 28, 0)
	header.item:SetWidth(160)
	header.item:SetJustifyH("LEFT")
	SortButton(header, "item")
	for _, key in ipairs({ "cost", "buyout", "market", "profit" }) do
		header[key] = Column(header, "GameFontNormalSmall", 0)
		SortButton(header, key)
	end
	panel.header = header
	local rule = panel:CreateTexture(nil, "BORDER")
	rule:SetPoint("TOPLEFT", 0, -50)
	rule:SetPoint("TOPRIGHT", 0, -50)
	rule:SetHeight(1)
	rule:SetColorTexture(0.6, 0.45, 0.15, 0.6)

	scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -54)
	scroll:SetPoint("BOTTOMRIGHT", -24, DETAIL_H + 22)
	inner = CreateFrame("Frame", nil, scroll)
	inner:SetSize(500, 1)
	scroll:SetScrollChild(inner)
	scroll:SetScript("OnSizeChanged", function(_, width) inner:SetWidth(width) end)

	emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	emptyText:SetPoint("TOPLEFT", scroll, "TOPLEFT", 8, -12)
	emptyText:SetPoint("RIGHT", scroll, "RIGHT", -8, 0)
	emptyText:SetJustifyH("LEFT")

	leftText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	leftText:SetPoint("BOTTOMLEFT", 4, DETAIL_H + 6)
	leftText:SetPoint("RIGHT", panel, "RIGHT", -4, 0)
	leftText:SetJustifyH("LEFT")

	BuildDetail()
end

local function LeftOutText(left)
	local parts = {}
	if left.unlearned > 0 then parts[#parts + 1] = left.unlearned .. " you don't know" end
	if left.losses > 0 then parts[#parts + 1] = left.losses .. " at a loss" end
	if left.unpriced > 0 then parts[#parts + 1] = left.unpriced .. " without a price" end
	if left.hidden > 0 then parts[#parts + 1] = left.hidden .. " marked doesn't sell" end
	if left.unknown > 0 then parts[#parts + 1] = left.unknown .. " with no known trainer or vendor" end
	if #parts == 0 then return "" end
	return "Not listed: " .. table.concat(parts, ", ") .. "."
end

local function Refresh()
	picker.Sync()
	panel.losses:SetChecked(ns.db.showLosses)
	panel.known:SetChecked(ns.db.knownOnly)
	PlaceColumns(panel.header)
	HeadingTexts(panel.header)
	local hasAuction = ns.Prices.HasAuctionator() or ns.Prices.HasTSM()
	sourcesText:SetText((hasAuction and "Prices: " or ORANGE) .. ns.Prices.SourcesText() .. (hasAuction and "" or "|r"))

	local prof = ns.CurrentProfession()
	if not prof then
		for _, b in ipairs(rows) do b:Hide() end
		emptyText:SetText("No profession modules are enabled for this character. In the AddOns list (at character select, or Esc > AddOns), tick Leprofit - Blacksmithing, then /reload.")
		emptyText:Show()
		leftText:SetText("")
		detail:Hide()
		return
	end

	local list, left = ns.Profit.Rows(prof)
	local y, picked = 0, nil
	for i, row in ipairs(list) do
		local b = GetRow(i)
		local note = Notes(row, prof)
		local h = note and (ROW_H + NOTE_H) or ROW_H
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", 0, -y)
		b:SetPoint("RIGHT", inner, "RIGHT")
		b:SetHeight(h)
		y = y + h
		b.product = row.product
		b.icon:SetTexture(ns.ItemIcon(row.product))
		local yield = row.yield ~= 1 and (GREY .. " x" .. row.yield .. "|r") or ""
		b.name:SetText(ns.ItemNameColored(row.product) .. yield)
		b.note:SetText(note or "")
		b.profit:SetText(ProfitText(row.profit))
		b.buyout:SetText(ns.Money(row.buyout))
		b.market:SetText(ns.Money(row.market))
		b.cost:SetText(row.cost and ns.Money(row.cost) or (ORANGE .. "?|r"))
		PlaceColumns(b, b.name, b)
		b.sel:SetShown(row.product == selected)
		if row.product == selected then picked = row end
		b:Show()
	end
	for i = #list + 1, #rows do rows[i]:Hide() end
	inner:SetHeight(math.max(1, y))

	-- Recipes you know are read from the profession window: until then none count as known.
	local unread = ns.Skill(prof) and ns.Recorder.KnownCount(prof) == 0
	if #list == 0 then
		local text
		if ns.db.knownOnly and not ns.Skill(prof) then
			text = "This character doesn't have " .. prof .. ". Untick Known only to see what it could learn."
		elseif ns.db.knownOnly and unread then
			text = ("Leprofit hasn't read your %s recipes yet: open your %s window."):format(prof, prof)
		elseif not hasAuction then
			text = "No auction prices: install Auctionator (or TSM) and scan the auction house, then open this again."
		elseif ns.db.knownOnly then
			text = "Nothing you know makes a profit at these prices. Untick Known only, or tick Show losses."
		else
			text = "Nothing makes a profit at these prices. Tick Show losses to see everything."
		end
		emptyText:SetText(text)
		emptyText:Show()
	else
		emptyText:Hide()
	end
	local leftOut = LeftOutText(left)
	if unread then
		leftOut = ORANGE .. ("Open your %s window so Leprofit knows your recipes.|r "):format(prof) .. leftOut
	end
	leftText:SetText(leftOut)
	if not picked then
		picked = list[1]
		selected = picked and picked.product
		if rows[1] and picked then rows[1].sel:Show() end
	end
	ShowDetail(picked, prof)
end

ns.Window.AddPage({ id = "crafts", label = "Crafts", build = Build, refresh = Refresh })
