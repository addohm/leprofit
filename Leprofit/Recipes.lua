-- Leprofit: one profession's recipes, from its module's data (the source addon's players) and what this
-- character's profession window showed (Recorder.lua), with where to learn the ones you don't know.
local _, ns = ...

local Recipes = {}
ns.Recipes = Recipes

local cache = {} -- profession -> { version, list, makers }

local function Rank(faction)
	local mine = UnitFactionGroup("player")
	if faction == mine or faction == "Neutral" or not faction then return 1 end
	return 2
end

-- Who sells a pattern: what you recorded first, then the data's sellers; your faction (and neutral
-- vendors) before the other faction's.
local function Sellers(recorded, pattern)
	local list, seen = {}, {}
	local function Add(s)
		if s and s.vendor and not seen[s.vendor] then
			seen[s.vendor] = true
			list[#list + 1] = {
				vendor = s.vendor, zone = s.zone, subZone = s.subZone, faction = s.faction, mapID = s.mapID, x = s.x, y = s.y,
			}
		end
	end
	Add(recorded)
	for _, s in ipairs(pattern and pattern.sellers or {}) do Add(s) end
	for i, s in ipairs(list) do s.order = i end
	table.sort(list, function(a, b)
		local ra, rb = Rank(a.faction), Rank(b.faction)
		if ra ~= rb then return ra < rb end
		return a.order < b.order
	end)
	return list
end

-- A seller and where they stand, e.g. "Vayn Moongaze in Nightclaw Cavern, Zephras Isle at 63.8, 36.1",
-- with "(Alliance only)" or "(Horde only)" when the vendor serves one faction.
function Recipes.SellerText(s)
	if not s then return nil end
	local place = {}
	if s.subZone and s.subZone ~= s.zone then place[#place + 1] = s.subZone end
	if s.zone then place[#place + 1] = s.zone end
	local text = s.vendor
	if #place > 0 then text = text .. " in " .. table.concat(place, ", ") end
	if s.x and s.y then text = text .. (" at %.1f, %.1f"):format(s.x * 100, s.y * 100) end
	if s.faction == "Alliance" or s.faction == "Horde" then text = text .. " (" .. s.faction .. " only)" end
	return text
end

-- Where to learn a recipe: a trainer (its cost and the skill it needs), a pattern from a vendor
-- (price, skill, sellers), or nobody recorded yet.
local function Source(def, prof, name)
	local t = def.training[name]
	if t then return { kind = "trainer", cost = t.cost, skill = t.skill } end
	local recorded = ns.adb.patterns[prof] and ns.adb.patterns[prof][name]
	local pattern = def.patterns[name]
	if recorded or pattern then
		return {
			kind = "pattern",
			itemID = (recorded and recorded.itemID) or pattern.itemID,
			cost = (recorded and recorded.price) or pattern.price,
			skill = pattern and pattern.skill,
			sellers = Sellers(recorded, pattern),
		}
	end
	return { kind = "unknown" }
end

-- Forever lists a second, never-learnable copy of some recipes under the same name. Keep one per
-- name: the one you know, then one with a known source, then one your window showed, then the
-- earlier grey (the source addon's OnePerName).
local function Better(a, b)
	if (a.learned and true) ~= (b.learned and true) then return a.learned and true end
	local ka, kb = a.source.kind ~= "unknown", b.source.kind ~= "unknown"
	if ka ~= kb then return ka end
	if (a.recorded and true) ~= (b.recorded and true) then return a.recorded and true end
	if (a.grey or 999) ~= (b.grey or 999) then return (a.grey or 999) < (b.grey or 999) end
	return a.id < b.id
end

local function Build(prof)
	local def = ns.professions[prof]
	local all = {}
	for id, r in pairs(def.recipes) do
		all[id] = {
			id = id, name = r.name, product = r.product, yield = r.yield or 1, reagents = r.reagents,
			icon = r.icon, grey = r.grey,
		}
	end
	for id, r in pairs(ns.db.recipes[prof] or {}) do
		local e = all[id] or { id = id }
		e.name = r.name or e.name
		e.product = r.product or e.product
		e.yield = r.yield or e.yield or 1
		if r.reagents and #r.reagents > 0 then e.reagents = r.reagents end
		e.icon = r.icon or e.icon
		e.learned = r.learned
		e.recorded = true
		all[id] = e
	end

	local best = {}
	for _, e in pairs(all) do
		if e.name and e.product and e.reagents and #e.reagents > 0 then
			e.source = e.learned and { kind = "known" } or Source(def, prof, e.name)
			if not best[e.name] or Better(e, best[e.name]) then best[e.name] = e end
		end
	end
	local list, makers = {}, {}
	for _, e in pairs(best) do
		list[#list + 1] = e
		if e.learned then
			makers[e.product] = makers[e.product] or {}
			table.insert(makers[e.product], e)
		end
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list, makers
end

local function Get(prof)
	local c = cache[prof]
	if not c or c.version ~= ns.dataVersion then
		local list, makers = Build(prof)
		c = { version = ns.dataVersion, list = list, makers = makers }
		cache[prof] = c
	end
	return c
end

-- The profession's recipes that make an item, one per name, sorted by name.
function Recipes.List(prof)
	if not ns.professions[prof] then return {} end
	return Get(prof).list
end

-- The recipes you know that make an item, for crafting a material instead of buying it.
function Recipes.Makers(prof, itemID)
	if not ns.professions[prof] then return nil end
	return Get(prof).makers[itemID]
end
