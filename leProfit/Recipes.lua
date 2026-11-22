-- leProfit: one profession's recipes, from its module's data and what this
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
				cost = s.cost, -- a token vendor's price, as text ("30 Merchant's Favor")
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

-- Where to get a pattern, as lines: the reputation it needs, who sells it (for gold or tokens),
-- the quests that reward it, what drops it (with how often, of the loot players recorded). At most
-- `most` lines, the last saying how many more.
local DROP_VERB = { drop = "Drops from", object = "Found in", container = "Found in", fishing = "Fished up in" }
function Recipes.WhereLines(src, most)
	local lines = {}
	if src.rep then
		lines[#lines + 1] = ("Needs %s reputation: %s%s"):format(src.rep.faction, src.rep.standing,
			src.rep.side and (" (" .. src.rep.side .. " only)") or "")
	end
	if src.questie then
		-- QuestieDB's answer, after a seller you recorded yourself (it has the price).
		local mine = src.recorded and src.recorded.vendor
		if mine then lines[#lines + 1] = "Sold by " .. Recipes.SellerText(src.sellers[1]) end
		for _, line in ipairs(src.questie.lines) do
			if not (mine and line:find("Sold by " .. mine, 1, true) == 1) then lines[#lines + 1] = line end
		end
		return Recipes.Trim(lines, most)
	end
	for _, s in ipairs(src.sellers or {}) do
		lines[#lines + 1] = (s.cost and (s.cost .. " from ") or "Sold by ") .. Recipes.SellerText(s)
	end
	if src.otherCamp then
		lines[#lines + 1] = ("Also sold at the %s trade camp (not recorded yet)"):format(src.otherCamp)
	end
	for _, q in ipairs(src.quests or {}) do
		lines[#lines + 1] = ("Reward from the quest %s%s%s"):format(q.title, q.zone and (" in " .. q.zone) or "",
			q.side and (" (" .. q.side .. " only)") or "")
	end
	for _, d in ipairs(src.drops or {}) do
		local odds = ""
		if d.of then
			odds = d.of >= 20 and (" (%d%%)"):format(math.floor(d.drops / d.of * 100 + 0.5))
				or (" (%d of %d recorded)"):format(d.drops, d.of)
		end
		lines[#lines + 1] = ("%s %s%s%s"):format(DROP_VERB[d.how] or "From", d.from,
			(d.zone and d.zone ~= d.from) and (" in " .. d.zone) or "", odds)
	end
	return Recipes.Trim(lines, most)
end

-- At most `most` lines, the last saying how many more.
function Recipes.Trim(lines, most)
	if most and #lines > most then
		local more = #lines - most + 1
		for i = #lines, most, -1 do lines[i] = nil end
		lines[most] = ("and %d more"):format(more)
	end
	return lines
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

-- Where to learn a recipe: it comes with the profession; a trainer (its cost and the skill it
-- needs; what you recorded at one first); a pattern a vendor sells for gold (price, skill, sellers,
-- the reputation it needs); a pattern no vendor sells for gold ("other": a drop, quest or
-- reputation reward or a token vendor, with where to get it; Profit.lua prices it at the auction
-- house unless it binds); or nobody knows. `side` is set when only one side can get it.
-- QuestieDB, when installed, says where a pattern comes from and for whom (Questie.lua); the
-- built-in data answers otherwise. A one-side reputation always decides the side, and the trade
-- camps' Merchant's Favor plans are both sides' whatever one camp's vendor says.
local function SideOf(rep, camp, questie, builtIn)
	if rep and rep.side then return rep.side end
	if camp then return nil end
	if questie then return questie.side end
	return builtIn
end

local function Source(def, prof, name)
	if def.free[name] then return { kind = "free", cost = 0, skill = 1 } end
	local t = (ns.adb.training[prof] and ns.adb.training[prof][name]) or def.training[name]
	if t then return { kind = "trainer", cost = t.cost, skill = t.skill } end
	local recorded = ns.adb.patterns[prof] and ns.adb.patterns[prof][name]
	local pattern = def.patterns[name]
	if recorded or pattern then
		local itemID = (recorded and recorded.itemID) or pattern.itemID
		local questie = ns.Questie.Sources(itemID)
		return {
			kind = "pattern",
			itemID = itemID,
			cost = (recorded and recorded.price) or pattern.price,
			skill = pattern and pattern.skill,
			sellers = Sellers(recorded, pattern),
			recorded = recorded,
			rep = pattern and pattern.rep,
			questie = questie,
			-- one you recorded is at a vendor you could get to
			side = not recorded and SideOf(pattern and pattern.rep, false, questie, pattern and pattern.side) or nil,
		}
	end
	local o = def.otherPatterns[name]
	if o then
		local questie = ns.Questie.Sources(o.itemID)
		return {
			kind = "other", itemID = o.itemID, skill = o.skill, bound = o.bound, rep = o.rep,
			sellers = Sellers(nil, o), otherCamp = o.otherCamp, quests = o.quests, drops = o.drops,
			questie = questie, side = SideOf(o.rep, o.camp, questie, o.side),
		}
	end
	return { kind = "unknown" }
end

-- Forever lists a second, never-learnable copy of some recipes under the same name. Keep one per
-- name: the one you know, then one with a known source, then one your window showed, then the
-- earlier grey.
local function Better(a, b)
	if (a.learned and true) ~= (b.learned and true) then return a.learned and true end
	local ka, kb = a.source.kind ~= "unknown", b.source.kind ~= "unknown"
	if ka ~= kb then return ka end
	if (a.recorded and true) ~= (b.recorded and true) then return a.recorded and true end
	if (a.grey or 999) ~= (b.grey or 999) then return (a.grey or 999) < (b.grey or 999) end
	return a.id < b.id
end

-- Whether this character knows a recipe, by asking the game (no profession window needed): the
-- recipe is a spell the character has.
local function KnowsSpell(id)
	return IsPlayerSpell and ns.Try(IsPlayerSpell, id) == true or false
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
		if not e.learned and KnowsSpell(e.id) then e.learned = true end
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
