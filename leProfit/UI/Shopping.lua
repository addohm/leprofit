-- leProfit: the Shopping tab. The crafts you planned (count and Remove for each), every material
-- they need combined (need, have, buy, each, cost), the gold to spend, Clear, and Send to
-- Auctionator. Crafts are added from the Crafts tab's materials panel.
local _, ns = ...

local GREY, ORANGE = "|cff9d9d9d", "|cffff9933"
local CRAFT_H, MAT_H, HEAD_H = 26, 16, 24
local MAT_COLS, MAT_W = 5, 70

local panel, scroll, inner, emptyText, totalText, sendButton
local craftRows, matRows = {}, {}
local craftsHeading, matsHeading, matsHeader

local function Heading(text)
	local fs = inner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetText(text)
	return fs
end

local function CraftRow(i)
	if craftRows[i] then return craftRows[i] end
	local r = CreateFrame("Button", nil, inner)
	r:SetHeight(CRAFT_H)
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(18, 18)
	r.icon:SetPoint("LEFT", 4, 0)
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	r.name:SetPoint("LEFT", 28, 0)
	r.name:SetPoint("RIGHT", r, "RIGHT", -170, 0)
	r.name:SetJustifyH("LEFT")
	r.name:SetWordWrap(false)
	r.remove = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
	r.remove:SetSize(72, 20)
	r.remove:SetPoint("RIGHT", -4, 0)
	r.remove:SetText("Remove")
	r.remove:SetScript("OnClick", function() ns.Shopping.Remove(r.index) end)
	r.count = CreateFrame("EditBox", nil, r, "InputBoxTemplate")
	r.count:SetSize(40, 20)
	r.count:SetPoint("RIGHT", r.remove, "LEFT", -14, 0)
	r.count:SetAutoFocus(false)
	r.count:SetNumeric(true)
	r.count:SetMaxLetters(3)
	r.count:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		ns.Shopping.SetCount(r.index, self:GetText())
	end)
	r.count:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		ns.Window.Refresh()
	end)
	local label = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("RIGHT", r.count, "LEFT", -8, 0)
	label:SetText("Crafts")
	r:SetScript("OnEnter", function(self)
		if not self.product then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetItemByID(self.product)
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", GameTooltip_Hide)
	r:SetScript("OnClick", function(self) ns.ItemModifiedClick(self.product) end)
	craftRows[i] = r
	return r
end

local function MatRow(i)
	if matRows[i] then return matRows[i] end
	local r = CreateFrame("Button", nil, inner)
	r:SetHeight(MAT_H)
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.name:SetPoint("LEFT", 8, 0)
	r.name:SetPoint("RIGHT", r, "RIGHT", -(MAT_COLS * MAT_W + 4), 0)
	r.name:SetJustifyH("LEFT")
	r.name:SetWordWrap(false)
	r.cols = {}
	for c = 1, MAT_COLS do
		local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		fs:SetWidth(MAT_W - 4)
		fs:SetJustifyH("RIGHT")
		fs:SetPoint("RIGHT", r, "RIGHT", -((MAT_COLS - c) * MAT_W + 4), 0)
		r.cols[c] = fs
	end
	r:SetScript("OnEnter", function(self)
		if not self.itemID then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetItemByID(self.itemID)
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", GameTooltip_Hide)
	r:SetScript("OnClick", function(self) ns.ItemModifiedClick(self.itemID) end)
	matRows[i] = r
	return r
end

local function Build(p)
	panel = p
	scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -4)
	scroll:SetPoint("BOTTOMRIGHT", -24, 34)
	inner = CreateFrame("Frame", nil, scroll)
	inner:SetSize(500, 1)
	scroll:SetScrollChild(inner)
	scroll:SetScript("OnSizeChanged", function(_, width) inner:SetWidth(width) end)

	craftsHeading = Heading("Planned crafts")
	matsHeading = Heading("Materials")
	matsHeader = MatRow(0)
	matsHeader:EnableMouse(false)
	matsHeader.name:SetFontObject("GameFontNormalSmall")
	matsHeader.name:SetText("Material")
	for c, text in ipairs({ "Need", "Have", "Buy", "Each", "Cost" }) do
		matsHeader.cols[c]:SetFontObject("GameFontNormalSmall")
		matsHeader.cols[c]:SetText(text)
	end

	emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	emptyText:SetPoint("TOPLEFT", 8, -16)
	emptyText:SetPoint("RIGHT", panel, "RIGHT", -8, 0)
	emptyText:SetJustifyH("LEFT")
	emptyText:SetText("Nothing planned yet. On the Crafts tab, pick a craft, set how many in Crafts, and press Add to list.")

	local rule = panel:CreateTexture(nil, "BORDER")
	rule:SetPoint("BOTTOMLEFT", 0, 30)
	rule:SetPoint("BOTTOMRIGHT", 0, 30)
	rule:SetHeight(1)
	rule:SetColorTexture(0.6, 0.45, 0.15, 0.6)

	sendButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	sendButton:SetSize(160, 22)
	sendButton:SetPoint("BOTTOMRIGHT", -2, 2)
	sendButton:SetText("Send to Auctionator")
	sendButton:SetScript("OnClick", function() ns.Shopping.SendToAuctionator() end)
	sendButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Send to Auctionator")
		GameTooltip:AddLine(("Makes Auctionator's \"%s\" shopping list from what's left to buy, replacing the last one. Materials vendors sell are left out."):format(ns.Shopping.LIST_NAME), 1, 1, 1, true)
		if not ns.Shopping.CanSend() then GameTooltip:AddLine("Needs Auctionator.", 1, 0.6, 0.2) end
		GameTooltip:Show()
	end)
	sendButton:SetScript("OnLeave", GameTooltip_Hide)
	local clear = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	clear:SetSize(80, 22)
	clear:SetPoint("RIGHT", sendButton, "LEFT", -8, 0)
	clear:SetText("Clear")
	clear:SetScript("OnClick", function()
		if #ns.db.plan == 0 then return end
		ns.Confirm("Clear the shopping list?\n\nEvery planned craft is removed.", "Clear", ns.Shopping.Clear)
	end)
	panel.clear = clear

	totalText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	totalText:SetPoint("BOTTOMLEFT", 4, 8)
	totalText:SetPoint("RIGHT", clear, "LEFT", -8, 0)
	totalText:SetJustifyH("LEFT")
end

-- Puts a row (full width) or a heading at y in the scroll area; returns the y below it.
local function Place(f, y, height)
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", inner, "TOPLEFT", 0, -y)
	f:SetPoint("RIGHT", inner, "RIGHT")
	f:SetHeight(height)
	f:Show()
	return y + height
end
local function PlaceHeading(fs, y, height)
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", inner, "TOPLEFT", 4, -y - 4)
	fs:Show()
	return y + height
end

local function Refresh()
	local crafts, materials, total, priced = ns.Shopping.Build()
	local empty = #crafts == 0
	emptyText:SetShown(empty)
	craftsHeading:SetShown(not empty)
	matsHeading:SetShown(not empty)
	matsHeader:SetShown(not empty)

	local y = 0
	if not empty then
		y = PlaceHeading(craftsHeading, y, HEAD_H)
	end
	for i, c in ipairs(crafts) do
		local r = CraftRow(i)
		r.index, r.product = i, c.rec and c.rec.product
		r.icon:SetTexture(r.product and ns.ItemIcon(r.product) or "Interface\\Icons\\INV_Misc_QuestionMark")
		local yield = c.rec and c.rec.yield ~= 1 and (GREY .. " x" .. c.rec.yield .. "|r") or ""
		r.name:SetText(c.rec and (ns.ItemNameColored(c.rec.product) .. yield .. GREY .. "  " .. c.plan.prof .. "|r")
			or (ORANGE .. "A recipe that's no longer listed (" .. c.plan.prof .. ")|r"))
		if not r.count:HasFocus() then r.count:SetText(tostring(c.plan.count)) end
		y = Place(r, y, CRAFT_H)
	end
	for i = #crafts + 1, #craftRows do craftRows[i]:Hide() end

	if not empty then
		y = PlaceHeading(matsHeading, y + 6, HEAD_H)
		y = Place(matsHeader, y, MAT_H)
	end
	for i, m in ipairs(materials) do
		local r = MatRow(i)
		r.itemID = m.itemID
		local tag = m.vendor and (GREY .. " (vendor)|r") or (not m.price and (ORANGE .. " (no price)|r") or "")
		r.name:SetText(ns.ItemNameColored(m.itemID) .. tag)
		r.cols[1]:SetText(m.need)
		r.cols[2]:SetText(m.have > 0 and m.have or (GREY .. "0|r"))
		r.cols[3]:SetText(m.buy > 0 and m.buy or (GREY .. "-|r"))
		r.cols[4]:SetText(m.price and ns.Money(m.price) or (ORANGE .. "?|r"))
		r.cols[5]:SetText(m.buy > 0 and (m.cost and ns.Money(m.cost) or (ORANGE .. "?|r")) or (GREY .. "-|r"))
		y = Place(r, y, MAT_H)
	end
	for i = #materials + 1, #matRows do matRows[i]:Hide() end
	inner:SetHeight(math.max(1, y))

	if empty then
		totalText:SetText("")
	elseif total then
		totalText:SetText("To buy: " .. ns.Money(total))
	else
		totalText:SetText(("To buy: %s, and %s"):format(ns.Money(priced), ORANGE .. "some materials have no price|r"))
	end
	sendButton:SetEnabled(not empty)
	panel.clear:SetEnabled(not empty)
end

ns.Window.AddPage({ id = "shopping", label = "Shopping", build = Build, refresh = Refresh })
