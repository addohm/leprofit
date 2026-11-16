-- Leprofit: a confirmation over the window, in its style: a question, an accept button and Cancel.
-- The window behind is dimmed and takes no clicks until you answer. It's Leprofit's own rather than
-- the game's StaticPopup, because addon code showing the game's popups can stop Blizzard's own
-- protected popups working until a /reload.
local _, ns = ...

local dialog

local function Build(window)
	dialog = CreateFrame("Frame", "LeprofitConfirm", window)
	dialog:SetAllPoints(window)
	dialog:SetFrameStrata("DIALOG")
	dialog:EnableMouse(true) -- the dimmed window takes no clicks
	local dim = dialog:CreateTexture(nil, "BACKGROUND")
	dim:SetPoint("TOPLEFT", 4, -4)
	dim:SetPoint("BOTTOMRIGHT", -4, 4)
	dim:SetColorTexture(0, 0, 0, 0.55)
	dialog:Hide()
	tinsert(UISpecialFrames, "LeprofitConfirm") -- Escape cancels

	local box = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
	box:SetSize(380, 140)
	box:SetPoint("CENTER")
	box:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	box:SetBackdropColor(0.05, 0.06, 0.09, 0.98)
	box:SetBackdropBorderColor(0.6, 0.45, 0.15, 1)

	dialog.text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	dialog.text:SetPoint("TOPLEFT", 20, -20)
	dialog.text:SetPoint("BOTTOMRIGHT", -20, 46)
	dialog.text:SetJustifyH("CENTER")
	dialog.text:SetJustifyV("MIDDLE")

	dialog.accept = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
	dialog.accept:SetSize(110, 22)
	dialog.accept:SetPoint("BOTTOMRIGHT", box, "BOTTOM", -6, 16)
	dialog.accept:SetScript("OnClick", function()
		local fn = dialog.onAccept
		dialog.onAccept = nil
		dialog:Hide()
		if fn then fn() end
	end)
	local cancel = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
	cancel:SetSize(110, 22)
	cancel:SetPoint("BOTTOMLEFT", box, "BOTTOM", 6, 16)
	cancel:SetText("Cancel")
	cancel:SetScript("OnClick", function()
		dialog.onAccept = nil
		dialog:Hide()
	end)
	dialog.cancel = cancel
end

-- Asks `text`; onAccept runs only if the accept button (labelled `accept`) is pressed.
function ns.Confirm(text, accept, onAccept)
	local window = ns.Window.Frame()
	if not window then return end
	if not dialog then Build(window) end
	dialog.text:SetText(text)
	dialog.accept:SetText(accept)
	dialog.onAccept = onAccept
	dialog:Show()
end

-- (tests)
function ns.ConfirmDialog() return dialog end
