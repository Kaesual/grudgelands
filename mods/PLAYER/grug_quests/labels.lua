-- How an objective reads in the dialogue, the quest log, the HUD tracker and
-- the message feed. Item names come from grug_core.item_name (never the
-- tooltip); text is plain (translation escapes resolved).
local Q = grug_quests
local plain = grug_core.plain_text

local function title_case(text)
	return (text:gsub("_", " "):gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end

-- The name a mob shows in `zone`: a sub-type's zone display name
-- (grug_mobs subtypes.lua, apply_zone_variant: "Small Jungle Boar" in the
-- Kapok Cradle), else its own display name or entity description.
local function mob_label(name, zone)
	local sub = grug_mobs.subtype and grug_mobs.subtype(name)
	local by_zone = sub and zone and sub.display_by_zone
	if sub then return plain(by_zone and by_zone[zone] or sub.display) end
	local def = core.registered_entities[name]
	local label = def and def.description
	if not label or label == "" then label = title_case(name:match("[^:]+$") or name) end
	return plain(label)
end

-- The zone each kill target (`mobs`, entity names) is met in, so its label
-- reads as the mob does there: a named leader's own zone, else the area's
-- zone ("zone/area"), else the quest's zone. Resolved once at load (the
-- loader keeps it as the objective's `zones`); rendering never reads the
-- world.
function Q.target_zones(mobs, area_ref, zone)
	local regions = grug_mobs.spawn_regions
	local area_zone = area_ref and area_ref:match("^([^/]+)/")
	local zones = {}
	for i, name in ipairs(mobs) do
		local leader = regions and regions.leader(name:match("^grug_mobs:(.+)$") or name)
		zones[i] = leader and leader.zone or area_zone or zone
	end
	return zones
end

-- The short subject: "Wood Axe", "Any Tree", "Small Boar or Large Rat",
-- "Small Jungle Boar", "Elder Maren".
function Q.objective_subject(objective)
	if objective.type == "item" then
		if objective.item then return grug_core.item_name(objective.item) end
		return "Any " .. title_case(objective.group)
	end
	if objective.type == "talk" then
		local npc = Q.registered_npcs[objective.npc]
		return npc and npc.title or tostring(objective.npc)
	end
	local names = {}
	local zones = objective.zones or {}
	for i, name in ipairs(objective.mobs or {}) do names[i] = mob_label(name, zones[i]) end
	return table.concat(names, " or ")
end

-- The task: "Bring Wood Axe", "Defeat Small Boar", "Travel to Elder Maren".
function Q.objective_action(objective)
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
--
-- T is a kind or camp of a zone's spawn recipe, a leader role or a PvP POI
-- (Round 31: a fortress or Battlegrounds camp by its settlement key); a bare
-- id means the quest file's zone, "zone_id/id" another zone (a leader role
-- and a PvP POI are found in any zone). P is a settlement key or anchor id ("highcourt",
-- "goldmead_village", "anchor_015"). A fill that starts a sentence starts
-- with a capital letter. Titles take only {name:T}: they are listed in the
-- dialogue, the quest log and other quests' requirements, and are filled
-- once at load; texts are filled on first display (the region maps are built
-- at server start) and cached, never per frame.
--
local P = {}
Q.placeholders = P
-- Placeholder -> its number of arguments.
P.KINDS = {dir_from_giver = 1, dir_of = 2, zone_area = 1, name = 1}
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

-- What a placeholder target names: {zone, id, what = "leader" | "kind" |
-- "camp" | "poi", name, type (a kind's terrain type)}, or nil and the reason. `zone` is the quest file's zone.
-- Static: no region map is built.
function Q.placeholder_target(zone, ref)
	local regions = grug_mobs.spawn_regions
	local qualified, id = ref:match("^([^/]+)/(.+)$")
	id = id or ref
	local leader = regions.leader(id)
	if leader and (not qualified or qualified == leader.zone) then
		return {zone = leader.zone, id = id, what = "leader", name = mob_label("grug_mobs:" .. id, leader.zone)}
	end
	local area = regions.get_area(qualified or zone, id)
	if not area then
		-- A PvP POI (Round 31) points at its anchor; its name is the POI's.
		local poi = grug_mobs.pvp_garrison and grug_mobs.pvp_garrison.poi(id)
		if poi and (not qualified or qualified == poi.zone_id) then
			return {zone = poi.zone_id, id = id, what = "poi", name = poi.label}
		end
		return nil, ("%s is no kind, camp, leader or PvP POI of %s"):format(id, qualified or zone)
	end
	return {zone = qualified or zone, id = id, what = area.is_camp and "camp" or "kind", name = area.name,
		type = area.type}
end

-- {name:T} only: a title's fill (at load).
function Q.fill_names(text, zone)
	return P.fill(text, function(p)
		if p.kind ~= "name" then return nil end
		local target = Q.placeholder_target(zone, p.args[1])
		return target and target.name or nil
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
