-- leProfit: a window of text to copy out of the game (/leprofit debug). The text opens selected,
-- so Ctrl+C copies it all; typing doesn't change it; Escape or Close shuts it. In the look of the
-- confirmation dialog.
local _, ns = ...

local frame, edit, text

local function Build()
	frame = CreateFrame("Frame", "leProfitCopy", UIParent, "BackdropTemplate")
	frame:SetSize(640, 420)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0.05, 0.06, 0.09, 0.98)
	frame:SetBackdropBorderColor(0.6, 0.45, 0.15, 1)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	tinsert(UISpecialFrames, "leProfitCopy") -- Escape closes it

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.title:SetPoint("TOPLEFT", 16, -14)
	local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("TOPRIGHT", -16, -16)
	hint:SetText("Ctrl+C copies it all; paste it into your report.")

	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 16, -38)
	scroll:SetPoint("BOTTOMRIGHT", -34, 44)
	edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject(ChatFontNormal)
	edit:SetWidth(580)
	scroll:SetScrollChild(edit)
	edit:SetScript("OnEscapePressed", function() frame:Hide() end)
	-- Read-only: whatever is typed, the report comes back, selected.
	edit:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			self:SetText(text)
			self:HighlightText()
		end
	end)
	frame.edit = edit

	local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	close:SetSize(100, 22)
	close:SetPoint("BOTTOMRIGHT", -16, 14)
	close:SetText("Close")
	close:SetScript("OnClick", function() frame:Hide() end)
end

-- Shows `body` under `title`, selected and ready to copy.
function ns.ShowCopy(title, body)
	if not frame then Build() end
	text = body
	frame.title:SetText(title)
	edit:SetText(body)
	frame:Show()
	edit:SetFocus()
	edit:HighlightText()
end
