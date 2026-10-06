-- How an objective reads in the dialogue, the quest log, the HUD tracker and
-- the message feed. Item names come from grug_core.item_name (never the
-- tooltip); text is plain (translation escapes resolved).
local Q = grug_quests
local plain = grug_core.plain_text

local function title_case(text)
	return (text:gsub("_", " "):gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end

-- An entity's registered name: the fallback when the names file names no
-- slot of it (grug_mobs names.lua).
local function entity_label(name)
	local def = core.registered_entities[name]
	local label = def and def.description
	if not label or label == "" then label = title_case(name:match("[^:]+$") or name) end
	return plain(label)
end

-- The race a PvP camp registered as on this world (the settlement registry,
-- as start_npcs.lua places its garrison), or nil.
local camp_races
local function camp_race(key)
	if not camp_races then
		camp_races = {}
		for _, record in ipairs(grug_core.settlement_socket_settlements()) do
			camp_races[record.key] = record.race_id
		end
	end
	return camp_races[key]
end

-- The name a PvP camp's captain shows on this world (data/pvp_names.json
-- by the camp's race), or nil.
function Q.captain_name(key)
	local garrison = grug_mobs.pvp_garrison
	local race = camp_race(key)
	return race and garrison and garrison.captain_name(key, race) or nil
end

-- The name a PvP POI's garrison `role` shows: the captain's, commander's
-- and General's pvp_names.json name, the guards' and bodyguards' slot
-- "<POI key>.<post>" of the names file.
local function garrison_name(poi, role, zone)
	local garrison = grug_mobs.pvp_garrison
	if role:find("^captain_") then return Q.captain_name(poi.key) end
	if role:find("^commander_") then return garrison.commander_name(poi.key) end
	if role:find("^general_") then return garrison.general_name(poi.faction) end
	local post = role:match("^(%a+)_")
	return post and grug_mobs.names.lookup(poi.key .. "." .. post, zone, nil) or nil
end

-- Round 38, the quest-name guarantee: the names a kill objective or quest
-- drop counts. Its roles and area only SELECT them; a mob then counts by
-- the name it shows, wherever it spawned (state.lua mob_counts). Per role,
-- in level order: a named leader's slot; else the slots of the area (a
-- kind or camp: the role's levels there; a PvP garrison: its post's name);
-- else the slots of the quest zone's kinds and camps; else the role's name
-- in that zone. Resolved once at load (the loader keeps it as the
-- objective's `names`); an empty list is a load error (validate.lua
-- E-no-name). Returns {per role {name, ...}}.
function Q.target_names(mobs, area_ref, zone)
	local regions = grug_mobs.spawn_regions
	local names = grug_mobs.names
	local area_zone, area_id = (area_ref or ""):match("^([^/]+)/(.+)$")
	local out = {}
	for i, name in ipairs(mobs) do
		local role = name:match("^grug_mobs:(.+)$") or name
		local leader = regions.leader(role)
		local list, seen
		if leader then
			local found = names.lookup(role, leader.zone, leader.level)
			list = found and {found} or {}
		elseif area_id then
			local unit = regions.get_area(area_zone, area_id)
			local range = unit and unit.levels_by_role[role]
			if range then
				list = names.names_in(role, area_zone, range[1], range[2])
			else
				local poi = grug_mobs.pvp_garrison and grug_mobs.pvp_garrison.poi(area_id)
				local found = poi and poi.zone_id == area_zone and garrison_name(poi, role, area_zone)
				list = found and {found} or {}
			end
		else
			list, seen = {}, {}
			for _, id in ipairs(regions.zone_area_ids(zone)) do
				local range = regions.get_area(zone, id).levels_by_role[role]
				for _, found in ipairs(range and names.names_in(role, zone, range[1], range[2]) or {}) do
					if not seen[found] then seen[found] = true; list[#list + 1] = found end
				end
			end
			if #list == 0 then
				local found = names.lookup(role, zone, nil)
				list = found and {found} or {}
			end
		end
		out[i] = list
	end
	return out
end

-- The place of a "use at a place" objective (Round 36): a clash site by its
-- settlement key ("r20_anchor_076"), else a quest place of a spawn recipe,
-- "zone_id/place_id" (a bare id: `zone`, the quest file's). Returns {ref
-- (the canonical reference: the key, or "zone_id/place_id"), zone, id, name,
-- clash}, or nil and the reason. Static: no region map is built.
function Q.use_place(ref, zone)
	if type(ref) ~= "string" or ref == "" then return nil, "a place is a clash site key or a quest place" end
	local regions = grug_mobs.spawn_regions
	local qualified, id = ref:match("^([^/]+)/(.+)$")
	if not qualified then
		local site = regions.clash_site(ref)
		if site then return {ref = ref, zone = site.zone, id = ref, name = site.name, clash = true} end
		qualified, id = zone, ref
	end
	local place = qualified and regions.zone_place(qualified, id)
	if not place then
		return nil, ("%s is no clash site and no quest place of %s"):format(ref, tostring(qualified))
	end
	return {ref = qualified .. "/" .. id, zone = qualified, id = id, name = place.name}
end

-- {name = true} of every name of Q.target_names' result.
function Q.name_set(by_role)
	local set = {}
	for _, list in ipairs(by_role) do
		for _, name in ipairs(list) do set[name] = true end
	end
	return set
end

-- {lo, hi} over every slot bearing one of the names (grug_mobs names.lua)
-- and `selected` (the selection's own levels, kept for a name the names
-- file does not hold), or nil.
function Q.names_levels(by_role, selected)
	local lo, hi = selected and selected[1], selected and selected[2]
	for _, list in ipairs(by_role or {}) do
		for _, name in ipairs(list) do
			local range = grug_mobs.names.levels_of(name)
			if range then
				lo, hi = math.min(lo or range[1], range[1]), math.max(hi or range[2], range[2])
			end
		end
	end
	return lo and {lo, hi} or nil
end

-- The short subject: "Wood Axe", "Any Tree", "Barrow Piglet or Grave Rat",
-- "Yam Piglet", "Elder Maren", "Light the signal fire". A kill's
-- subject is the names it counts (Q.target_names); a role the names file
-- does not name reads as its entity.
function Q.objective_subject(objective)
	if objective.type == "use" then return objective.label end
	if objective.type == "item" then
		if objective.item then return grug_core.item_name(objective.item) end
		return "Any " .. title_case(objective.group)
	end
	if objective.type == "talk" then
		local npc = Q.registered_npcs[objective.npc]
		return npc and npc.title or tostring(objective.npc)
	end
	local names = {}
	local by_role = objective.names or {}
	for i, name in ipairs(objective.mobs or {}) do
		local list = by_role[i] or {}
		if #list == 0 then
			names[#names + 1] = entity_label(name)
		else
			for _, shown in ipairs(list) do names[#names + 1] = plain(shown) end
		end
	end
	return table.concat(names, " or ")
end

-- The task: "Bring Wood Axe", "Defeat Barrow Piglet", "Travel to Elder Maren",
-- "Light the signal fire at Saltgate Remnant".
function Q.objective_action(objective)
	if objective.type == "use" then
		return objective.label .. (objective.place_name and " at " .. objective.place_name or "")
	end
	local verb = objective.type == "item" and "Bring " or
		(objective.type == "talk" and "Travel to " or "Defeat ")
	return verb .. Q.objective_subject(objective)
end

-- The level range of an objective's targets (Lane Q0, computed once at load
-- by validate.objective_levels): " (level 1–4)", " (level 10)"; "" without
-- one (plain gathering and crafting items, unknown targets).
function Q.objective_levels_text(objective)
	local levels = objective.levels
	if not levels then return "" end
	if levels[1] == levels[2] then return (" (level %d)"):format(levels[1]) end
	return (" (level %d–%d)"):format(levels[1], levels[2])
end

-- A repeatable's cooldown in words: "30 min", "2 h", "1 h 30 min".
function Q.cooldown_text(seconds)
	local minutes = math.ceil(seconds / 60)
	local hours = math.floor(minutes / 60)
	minutes = minutes - hours * 60
	if hours == 0 then return minutes .. " min" end
	if minutes == 0 then return hours .. " h" end
	return ("%d h %d min"):format(hours, minutes)
end

--
-- Placeholders in quest titles and texts (Round 29 Lane Q1, the user's text
-- rule of 2026-10-02): directions and places that depend on the seed are
-- never written as fixed words; the text names them and the game fills them
-- from this world's spawn regions and leader spots
-- (grug_mobs.spawn_regions.describe, spawn_regions.md "Directions"):
--
--   {dir_from_giver:T}  "southeast from here", "nearby" (from the giver)
--   {dir_of:P:T}        "southeast of Highcourt", "near Highcourt"
--   {zone_area:T}       "in the southeast of Dawnmere Fields",
--                       "in the heart of Dawnmere Fields"
--   {name:T}            the display name: "Dawnmere Meadows", "Crumb"
--   {captain:T}         the captain of PvP camp T (its settlement key) by
--                       the name he shows on this world (Round 38: the
--                       name depends on the camp's race), "Captain Vrakk"
--
-- T is a kind or camp of a zone's spawn recipe, a leader role, a PvP POI
-- (Round 31: a fortress or Battlegrounds camp by its settlement key), or a
-- quest place (Round 36: a recipe's quest place, or a clash site by its
-- settlement key); a bare id means the quest file's zone, "zone_id/id"
-- another zone (a leader role, a PvP POI and a clash site are found in any
-- zone). P is a settlement key or anchor id ("highcourt",
-- "goldmead_village", "anchor_015"). A fill that starts a sentence starts
-- with a capital letter. Titles take only {name:T}: they are listed in the
-- dialogue, the quest log and other quests' requirements, and are filled
-- once at load; texts are filled on first display (the region maps are built
-- at server start) and cached, never per frame.
--
local P = {}
Q.placeholders = P
-- Placeholder -> its number of arguments.
P.KINDS = {dir_from_giver = 1, dir_of = 2, zone_area = 1, name = 1, captain = 1}
P.DIRECTIONS = {dir_from_giver = true, dir_of = true, zone_area = true}

-- Fixed compass words are never written into a quest text: every
-- direction word, its -ern, -erly, -ward, -wards, -bound, -most, -ernmost,
-- -erner and -erners forms, in any case and hyphenation ("north-east" reads as the words "north" and "east"). Only
-- whole words count, so names such as "Northfold" or "Westbrook" stay.
P.COMPASS = {}
for _, base in ipairs({"north", "south", "east", "west", "northeast", "northwest",
		"southeast", "southwest"}) do
	for _, suffix in ipairs({"", "ern", "erly", "ward", "wards", "bound", "most", "ernmost", "erner",
			"erners"}) do
		P.COMPASS[base .. suffix] = true
	end
end

-- The fixed compass words of a title or text, placeholders left out.
function P.compass_words(text)
	local found = {}
	for word in text:gsub("%b{}", " "):gmatch("%a+") do
		if P.COMPASS[word:lower()] then found[#found + 1] = word end
	end
	return found
end

local TARGET = "^[a-z][a-z0-9_]*$"
local QUALIFIED = "^[a-z][a-z0-9_]*/[a-z][a-z0-9_]*$"

-- Every placeholder of `text` as {from, to, kind, args}, and the syntax
-- errors: a brace outside a well-formed placeholder, an unknown kind, a
-- wrong number of arguments or a malformed id.
function P.scan(text)
	local found, errors = {}, {}
	local pos = 1
	while true do
		local s = text:find("[{}]", pos)
		if not s then break end
		local e = text:sub(s, s) == "{" and text:find("[{}]", s + 1)
		if not e or text:sub(e, e) ~= "}" then
			errors[#errors + 1] = ("unmatched brace at character %d"):format(s)
			pos = s + 1
		else
			local raw = text:sub(s, e)
			local args = {}
			for part in (text:sub(s + 1, e - 1) .. ":"):gmatch("([^:]*):") do args[#args + 1] = part end
			local kind = table.remove(args, 1)
			local message
			if not P.KINDS[kind] then
				message = "unknown placeholder"
			elseif #args ~= P.KINDS[kind] then
				message = ("takes %d argument%s"):format(P.KINDS[kind], P.KINDS[kind] == 1 and "" or "s")
			else
				local target = args[#args]
				if not (target:match(TARGET) or target:match(QUALIFIED)) or
						(kind == "dir_of" and not args[1]:match(TARGET)) then
					message = "ids are snake_case (a target may be zone_id/id)"
				end
			end
			if message then
				errors[#errors + 1] = raw .. ": " .. message
			else
				found[#found + 1] = {from = s, to = e, kind = kind, args = args, raw = raw}
			end
			pos = e + 1
		end
	end
	return found, errors
end

-- `text` with every placeholder replaced by resolve(placeholder) (nil keeps
-- it as written). A fill at the start of the text or of a sentence starts
-- with a capital letter.
function P.fill(text, resolve)
	local found = P.scan(text)
	if #found == 0 then return text end
	local parts, pos = {}, 1
	for _, p in ipairs(found) do
		local before = text:sub(1, p.from - 1)
		local value = resolve(p)
		if value and (before:match("^%s*$") or before:match("[%.!?][\"']?%s+$") or before:match("\n%s*$")) then
			value = value:gsub("^%l", string.upper)
		end
		parts[#parts + 1] = text:sub(pos, p.from - 1)
		parts[#parts + 1] = value or p.raw
		pos = p.to + 1
	end
	parts[#parts + 1] = text:sub(pos)
	return table.concat(parts)
end

-- What a placeholder target names: {zone, id, what = "leader" | "place" |
-- "kind" | "camp" | "poi", name, type (a kind's terrain type)}, or nil and
-- the reason (a clash site reads as a "poi": it is described at its anchor).
-- `zone` is the quest file's zone. Static: no region map is built.
function Q.placeholder_target(zone, ref)
	local regions = grug_mobs.spawn_regions
	local qualified, id = ref:match("^([^/]+)/(.+)$")
	id = id or ref
	local leader = regions.leader(id)
	if leader and (not qualified or qualified == leader.zone) then
		return {zone = leader.zone, id = id, what = "leader",
			name = plain(grug_mobs.names.lookup(id, leader.zone, leader.level) or entity_label("grug_mobs:" .. id))}
	end
	local area = regions.get_area(qualified or zone, id)
	local place = not area and regions.zone_place(qualified or zone, id)
	if place then
		return {zone = place.zone, id = id, what = "place", name = place.name}
	end
	if not area then
		-- A PvP POI (Round 31) and a clash site (Round 36) point at their
		-- anchor; the name is the POI's.
		local poi = grug_mobs.pvp_garrison and grug_mobs.pvp_garrison.poi(id)
		if poi and (not qualified or qualified == poi.zone_id) then
			return {zone = poi.zone_id, id = id, what = "poi", name = poi.label}
		end
		local site = regions.clash_site(id)
		if site and (not qualified or qualified == site.zone) then
			return {zone = site.zone, id = id, what = "poi", name = site.name}
		end
		return nil, ("%s is no kind, camp, leader, quest place, clash site or PvP POI of %s")
			:format(id, qualified or zone)
	end
	return {zone = qualified or zone, id = id, what = area.is_camp and "camp" or "kind", name = area.name,
		type = area.type}
end

-- {name:T} and {captain:T} only: a title's fill (at load).
function Q.fill_names(text, zone)
	return P.fill(text, function(p)
		local target = (p.kind == "name" or p.kind == "captain") and Q.placeholder_target(zone, p.args[1])
		if not target then return nil end
		if p.kind == "captain" then return target.what == "poi" and Q.captain_name(target.id) or nil end
		return target.name
	end)
end

-- The giver's socket position {x, z} (sockets exist before any terrain).
local giver_pos = {}
local function giver_position(npc_id)
	if giver_pos[npc_id] == nil then
		local npc = Q.registered_npcs[npc_id]
		giver_pos[npc_id] = false
		for _, socket in ipairs(npc and grug_core.settlement_sockets_at(npc.settlement) or {}) do
			if socket.id == npc.socket then giver_pos[npc_id] = {x = socket.pos.x, z = socket.pos.z} end
		end
	end
	return giver_pos[npc_id] or nil
end

local function zone_name(zone)
	local record = grug_zones.get(zone)
	return record and record.display_name or zone
end

-- One placeholder of quest `def`'s text, filled for this world. "From
-- here" is true only in the giver's own dialogue (`at_giver`); the quest log
-- and another NPC's dialogue read it from the giver's settlement ("northeast
-- of Dawnmere"). A target whose phrase cannot be built (no region of that
-- kind on this seed, a map that failed to build) falls back to the zone or
-- the place, without a direction, and is logged once.
local function placeholder_value(def, p, at_giver)
	local target, reason = Q.placeholder_target(def.zone, p.args[#p.args])
	if not target then
		core.log("warning", ("[grug_quests] %s: %s: %s"):format(def.id, p.raw, reason))
		return nil
	end
	if p.kind == "name" then return target.name end
	if p.kind == "captain" then
		local name = target.what == "poi" and Q.captain_name(target.id)
		if name then return name end
		core.log("warning", ("[grug_quests] %s: %s names no PvP camp's captain on this world"):format(def.id, p.raw))
		return nil
	end
	local regions = grug_mobs.spawn_regions
	-- A PvP POI is described at its anchor ({x, z}, spawn_regions.place).
	local subject = target.what == "poi" and regions.place(target.id) or target.id
	local result
	if p.kind == "dir_from_giver" and not at_giver then
		local npc = Q.registered_npcs[def.npc]
		result, reason = regions.describe(target.zone, subject, "of", npc and npc.settlement)
	elseif p.kind == "dir_from_giver" then
		local pos = giver_position(def.npc)
		result, reason = pos and regions.describe(target.zone, subject, "from", pos)
		reason = reason or "the giver has no position"
	elseif p.kind == "dir_of" then
		result, reason = regions.describe(target.zone, subject, "of", p.args[1])
	else
		result, reason = regions.describe(target.zone, subject, "zone")
	end
	if result then return result.phrase end
	core.log("warning", ("[grug_quests] %s: %s has no direction on this world (%s)")
		:format(def.id, p.raw, tostring(reason)))
	if p.kind == "dir_of" then
		local place = regions.place(p.args[1])
		return "around " .. (place and place.name or p.args[1])
	end
	return "in " .. zone_name(target.zone)
end

-- The quest's text (with its requirements) as players read it: in the
-- giver's dialogue (`at_giver`), else in the quest log or at another NPC.
-- Each form is filled once and cached; the title is filled at load
-- (Q.fill_names).
local texts = {}
function Q.quest_text(def, at_giver)
	local key = at_giver and def.id .. "@giver" or def.id
	local text = texts[key]
	if not text then
		text = def.description:find("{", 1, true) and
			P.fill(def.description, function(p) return placeholder_value(def, p, at_giver) end) or
			def.description
		texts[key] = text
	end
	return text
end
