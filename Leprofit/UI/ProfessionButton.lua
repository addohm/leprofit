-- Leprofit: a small button on the profession window, left of its close button, that opens Leprofit
-- on the profession the window shows. Forever's profession window (ProfessionsFrame, loaded when
-- first opened) has nothing else there; TradeSkillFrame is the older one.
local _, ns = ...

local PB = {}
ns.ProfessionButton = PB

local buttons = {} -- host frame -> button

local function Host()
	for _, name in ipairs({ "ProfessionsFrame", "TradeSkillFrame" }) do
		local f = rawget(_G, name)
		if f and f.IsShown and f:IsShown() then return f end
	end
end

local function Create(host)
	local b = CreateFrame("Button", nil, host)
	b:SetSize(22, 22)
	b:SetFrameLevel((host:GetFrameLevel() or 1) + 10)
	if host.CloseButton then
		b:SetPoint("RIGHT", host.CloseButton, "LEFT", -2, 0)
	else
		b:SetPoint("TOPRIGHT", host, "TOPRIGHT", -30, -4)
	end
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture(ns.ICON)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	b:SetScript("OnClick", function()
		local prof = ns.Recorder.OpenProfession(false)
		if prof then ns.SetProfession(prof) end
		ns.Window.Show("crafts")
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine("Leprofit")
		GameTooltip:AddLine("The crafts that make gold.", 1, 1, 1)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", GameTooltip_Hide)
	return b
end

function PB.Apply()
	local host = Host()
	if host and not buttons[host] then buttons[host] = Create(host) end
	for _, b in pairs(buttons) do b:SetShown(ns.db.professionButton and true or false) end
end

function PB.Init()
	local events = CreateFrame("Frame")
	events:RegisterEvent("TRADE_SKILL_SHOW")
	events:SetScript("OnEvent", function()
		-- The window is shown a moment after the event.
		C_Timer.After(0, PB.Apply)
	end)
	PB.Apply()
end
