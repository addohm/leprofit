-- Leprofit: the profession modules, loaded on demand. Each Leprofit_<Profession> addon is
-- LoadOnDemand, and its .toc names its profession (## X-Leprofit-Profession). At login Leprofit
-- loads the modules for the professions this character has, and the one the window last showed;
-- the profession dropdown loads any other the moment it's picked. Nobody has to tick modules in
-- the AddOns list, and a module someone turns off there stays off.
local _, ns = ...
local Try = ns.Try

local Modules = {}
ns.Modules = Modules

-- The installed modules that can load: profession -> addon name. Read from the AddOns list each
-- time (it's short), so a module turned on or off is seen straight away.
function Modules.Available()
	local found = {}
	local api = C_AddOns
	if not api then return found end
	for i = 1, (Try(api.GetNumAddOns) or 0) do
		local name, _, _, _, reason = Try(api.GetAddOnInfo, i)
		name = ns.Plain(name)
		if name and name:find("^Leprofit_") and reason ~= "DISABLED" then
			local prof = ns.Plain(Try(api.GetAddOnMetadata, name, "X-Leprofit-Profession"))
			if prof then found[prof] = name end
		end
	end
	return found
end

-- Every profession the dropdown offers: the loaded ones and the ones that can load, A to Z.
function Modules.Choices()
	local seen, list = {}, {}
	for _, prof in ipairs(ns.professionOrder) do
		seen[prof] = true
		list[#list + 1] = prof
	end
	for prof in pairs(Modules.Available()) do
		if not seen[prof] then
			seen[prof] = true
			list[#list + 1] = prof
		end
	end
	table.sort(list)
	return list
end

-- A profession's icon, loaded or not (an unloaded module's comes from its .toc).
function Modules.Icon(prof)
	local def = ns.professions[prof]
	if def and def.icon then return def.icon end
	local addon = Modules.Available()[prof]
	return addon and ns.Plain(Try(C_AddOns.GetAddOnMetadata, addon, "IconTexture"))
end

-- Loads a profession's module if it isn't loaded yet. True if the profession is there now.
function Modules.Load(prof)
	if not prof or ns.professions[prof] then return ns.professions[prof] ~= nil end
	local addon = Modules.Available()[prof]
	if not addon then return false end
	Try(C_AddOns.LoadAddOn, addon)
	return ns.professions[prof] ~= nil
end

-- Loads the modules for the professions this character has, and the one the window last showed.
function Modules.LoadKnown()
	for prof in pairs(Modules.Available()) do
		if ns.Skill(prof) then Modules.Load(prof) end
	end
	local last = ns.db and ns.db.profession
	if last and last ~= ns.ALL then Modules.Load(last) end
end

-- Learning a profession, or opening its window, loads its module.
local events = CreateFrame("Frame")
events:RegisterEvent("SKILL_LINES_CHANGED")
events:RegisterEvent("TRADE_SKILL_SHOW")
events:SetScript("OnEvent", function()
	if ns.db then Modules.LoadKnown() end
end)
