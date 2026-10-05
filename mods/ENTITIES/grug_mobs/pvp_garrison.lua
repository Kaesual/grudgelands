--
-- Round 31 PvP garrisons (pvp-plan rulings 12 and 16-20, its coordinator
-- defaults; round31-plan.md §1 lane G): which NPC stands on which socket of
-- a PvP fortress or Battlegrounds camp, at which level and tier, how soon it
-- comes back, what it is called and where a quest credits it. Pure rules over
-- lane S's catalogue (`grug_mapgen/wp40/r31_pvp_catalog.lua`) and the Astra
-- names (`data/pvp_names.json`); tools/r31_g drives them directly.
--
-- Who does what with them: guard.lua registers the captains, bosses.lua the
-- Generals and their bodyguards (the king chassis), start_npcs.lua places
-- every garrison on its sockets and books the respawn slots. The quest
-- givers, the Quartermaster and the waystone of a fortress are no garrison:
-- their roles keep the ordinary resolvers (a protected quest shell, the
-- faction's general vendor, nothing).
--
-- The garrison by socket (r31_pvp_poi_blueprint.lua's role list):
--   fortress  guard_post (gate, inner)  the faction guard, level 60 elite
--             general                   the General, level 65 elite
--             bodyguard                 the General's guard, level 60 elite
--   camp      guard_post (gate, camp)   the faction guard at a level of the
--                                       camp's 3-level band, never elite
--             captain                   the named captain at the top of the
--                                       band: no elite, a leader's size and
--                                       HP (grug_mobs.LEADER, guard.lua)
--             commander                 Round 36 (round36-plan.md §2.3): in
--                                       the camps data/pvp_names.json names
--                                       one for, a named level-60 elite
--                                       with a leader's size and HP; no
--                                       authored socket -- he stands across
--                                       the captain from the west yard post
--                                       (M.commander_socket)
-- Looks (round31-plan §1, lane A's contract at grug_visuals.npc_race): a
-- camp's people are of the camp's race and the General of his fortress's seat
-- race, both the race their settlement registered as; fortress guards and
-- bodyguards are `mixed`, any race of their faction, rolled once.
--
-- Plain Lua 5.1, no globals.
--
local M = {}

M.FORTRESS_GUARD_LEVEL = 60
M.BODYGUARD_LEVEL = 60
M.GENERAL_LEVEL = 65
M.COMMANDER_LEVEL = 60
M.COMMANDER_TIER = "elite"

-- Respawn slots (world.md §4a), seconds of world time, one refill rolled in
-- [min, max]. A fortress guard keeps the guard-post rhythm; the camps take the
-- coordinator defaults (about 2 min a guard, about 5 min a captain), rough
-- values for the playtest. The General and his bodyguards are no slots: they
-- are one group that returns like a king's (bosses.lua, start_npcs.lua's royal
-- path, 15 min of wall-clock time after the General's death).
M.RESPAWN = {
	fortress_guard = {180, 360},
	camp_guard = {100, 140},
	captain = {270, 330},
	-- Round 36: like the captains.
	commander = {270, 330},
}

-- The entity of each garrison role and faction.
function M.guard_entity(faction) return "grug_mobs:guard_" .. faction end
function M.captain_entity(faction) return "grug_mobs:captain_" .. faction end
function M.general_entity(faction) return "grug_mobs:general_" .. faction end
function M.bodyguard_entity(faction) return "grug_mobs:bodyguard_" .. faction end
function M.commander_entity(faction) return "grug_mobs:commander_" .. faction end

-- What grug_pvp counts a kill of each garrison entity as (its NPC counters,
-- ruling 16); the faction guards are counted by name already. A war
-- commander counts as a camp's captain.
function M.pvp_kind(entity)
	if entity:find("^grug_mobs:captain_") then return "captain" end
	if entity:find("^grug_mobs:commander_") then return "captain" end
	if entity:find("^grug_mobs:general_") then return "general" end
	if entity:find("^grug_mobs:bodyguard_") then return "guard" end
	return nil
end

local function fail(message)
	error("grug_mobs PvP garrison: " .. message, 0)
end

-- The war commander's post (Round 36): no socket of its own, so a camp's
-- sockets give it -- the captain's position mirrored through the west yard
-- post (a higher camp has no east yard post, so that spot is open floor
-- beside the command tent), at the captain's height and facing. A socket
-- in the registry's form ({id, role, pos, yaw}), or nil without both posts.
function M.commander_socket(sockets)
	local captain, yard
	for _, socket in ipairs(sockets) do
		if socket.role == "captain" then captain = socket end
		if socket.id == "yard_west" then yard = socket end
	end
	if not captain or not yard then return nil end
	local c, y = captain.pos, yard.pos
	return {id = "commander", role = "commander", yaw = captain.yaw,
		pos = {x = 2 * c.x - y.x, y = c.y, z = 2 * c.z - y.z}}
end

-- `catalog` is r31_pvp_catalog.lua's table, `names` the decoded
-- data/pvp_names.json ({generals = {accord, throng}, captains = {<camp key> =
-- {<race> = name}}, commanders = {<camp key> = name}}). Fails loudly when a
-- General or any captain a camp can roll has no name, or a commander names
-- no higher camp.
function M.new(catalog, names)
	if type(catalog) ~= "table" or type(catalog.rows) ~= "table" or
			type(catalog.FACTION_RACES) ~= "table" or type(catalog.SEAT_RACE) ~= "table" or
			type(catalog.camp_levels) ~= "function" then
		fail("catalogue differs")
	end
	if type(names) ~= "table" or type(names.generals) ~= "table" or
			type(names.captains) ~= "table" then
		fail("names differ")
	end
	-- The instance answers the module's constants and entity names too.
	local G = setmetatable({catalog = catalog, names = names}, {__index = M})
	local commanders = names.commanders or {}
	if type(commanders) ~= "table" then fail("commander names differ") end
	local by_key = {}
	for _, row in ipairs(catalog.rows) do
		local races = catalog.FACTION_RACES[row.faction]
		if not races then fail(row.key .. ": faction differs") end
		by_key[row.key] = row
		if row.kind == "pvp_fortress" then
			local general = names.generals[row.faction]
			if type(general) ~= "string" or general == "" then
				fail("no General name for " .. row.faction)
			end
		else
			local captains = names.captains[row.key]
			for _, race in ipairs(races) do
				local name = type(captains) == "table" and captains[race]
				if type(name) ~= "string" or name == "" then
					fail("no captain name for " .. row.key .. " " .. race)
				end
			end
		end
	end
	for key, name in pairs(commanders) do
		local row = by_key[key]
		if not row or row.kind ~= "pvp_camp_high" then
			fail("a commander for " .. tostring(key) .. ", which is no higher war camp")
		end
		if type(name) ~= "string" or name == "" then fail("no commander name for " .. key) end
	end

	-- The catalogue row of a settlement key, or nil (not a PvP POI).
	function G.poi(key)
		return by_key[key]
	end

	-- The settlement kind start_npcs.lua serves a PvP POI as.
	function G.settlement_kind(key)
		local row = by_key[key]
		if not row then return nil end
		return row.kind == "pvp_fortress" and "pvp_fortress" or "pvp_camp"
	end

	-- The quest area a garrison carries (`_grug_area`, grug_quests matches a
	-- kill objective's `area` against it): "<zone>/<settlement key>", the
	-- spawn regions' "<zone>/<kind or camp>" form.
	function G.area(key)
		local row = by_key[key]
		return row and (row.zone_id .. "/" .. key) or nil
	end

	-- What a kill objective may name in that area (Round 31 lane Q): role
	-- (the entity name without "grug_mobs:") -> {level_min, level_max}, as
	-- G.slot places them; `band` as there (camps only).
	function G.area_roles(key, band)
		local row = by_key[key]
		if not row then return nil end
		local function role(entity) return (entity:gsub("^grug_mobs:", "")) end
		local faction, out = row.faction, {}
		if row.kind == "pvp_fortress" then
			out[role(M.guard_entity(faction))] = {M.FORTRESS_GUARD_LEVEL, M.FORTRESS_GUARD_LEVEL}
			out[role(M.bodyguard_entity(faction))] = {M.BODYGUARD_LEVEL, M.BODYGUARD_LEVEL}
			out[role(M.general_entity(faction))] = {M.GENERAL_LEVEL, M.GENERAL_LEVEL}
			return out
		end
		local low, high = catalog.camp_levels(band[1], band[2], row.band)
		out[role(M.guard_entity(faction))] = {low, high}
		out[role(M.captain_entity(faction))] = {high, high}
		if commanders[key] then
			out[role(M.commander_entity(faction))] = {M.COMMANDER_LEVEL, M.COMMANDER_LEVEL}
		end
		return out
	end

	function G.general_name(faction)
		return names.generals[faction]
	end

	function G.captain_name(key, race)
		local captains = names.captains[key]
		return captains and captains[race] or nil
	end

	-- The war commander's name in a camp, or nil (no commander there).
	function G.commander_name(key)
		return commanders[key]
	end

	-- The war commander of a camp (Round 36), in G.slot's form, or nil.
	function G.commander(key)
		local row, name = by_key[key], commanders[key]
		if not row or not name then return nil end
		return {entity = M.commander_entity(row.faction), faction = row.faction,
			area = G.area(key), name = name,
			level_min = M.COMMANDER_LEVEL, level_max = M.COMMANDER_LEVEL,
			tier = M.COMMANDER_TIER, respawn = M.RESPAWN.commander}
	end

	-- The garrison of one socket, or nil when the socket is no garrison post
	-- (quest, vendor, waypoint keep their ordinary resolvers).
	--   key      the settlement key (a catalogue row)
	--   race_id  the race the settlement registered as (a camp's rolled race,
	--            a fortress's seat race)
	--   socket   {role, tags}
	--   band     {level_min, level_max} of the POI's zone (camps only)
	-- Returns {entity, level_min, level_max (nil: the entity's own fixed
	-- level), tier ("elite" | "normal"), respawn ({min, max}, nil for the
	-- General's group), royal, leader, name, mixed (a race of the faction
	-- instead of the settlement's),
	-- area, faction}.
	function G.slot(key, race_id, socket, band)
		local row = by_key[key]
		if not row then return nil end
		local faction, role = row.faction, socket.role
		local races = catalog.FACTION_RACES[faction]
		local spec = {faction = faction, area = G.area(key)}
		if row.kind == "pvp_fortress" then
			if role == "guard_post" then
				spec.entity = M.guard_entity(faction)
				spec.level_min, spec.level_max = M.FORTRESS_GUARD_LEVEL, M.FORTRESS_GUARD_LEVEL
				spec.tier, spec.respawn, spec.mixed = "elite", M.RESPAWN.fortress_guard, true
			elseif role == "general" then
				spec.entity, spec.tier = M.general_entity(faction), "elite"
				spec.royal, spec.leader = true, true
			elseif role == "bodyguard" then
				spec.entity, spec.tier = M.bodyguard_entity(faction), "elite"
				spec.royal, spec.mixed = true, true
			else
				return nil
			end
			return spec
		end
		if role == "commander" then return G.commander(key) end
		if role ~= "guard_post" and role ~= "captain" then return nil end
		if type(band) ~= "table" or type(band[1]) ~= "number" or type(band[2]) ~= "number" then
			fail(key .. ": the zone's level band differs")
		end
		local of_faction = false
		for _, race in ipairs(races) do of_faction = of_faction or race == race_id end
		if not of_faction then fail(key .. ": race " .. tostring(race_id) .. " is not of " .. faction) end
		local low, high = catalog.camp_levels(band[1], band[2], row.band)
		if role == "captain" then
			spec.entity = M.captain_entity(faction)
			spec.level_min, spec.level_max = high, high
			spec.tier, spec.respawn = "normal", M.RESPAWN.captain
			spec.name = G.captain_name(key, race_id)
			if not spec.name then fail(key .. ": no captain name for " .. tostring(race_id)) end
		else
			spec.entity = M.guard_entity(faction)
			spec.level_min, spec.level_max = low, high
			spec.tier, spec.respawn = "normal", M.RESPAWN.camp_guard
		end
		return spec
	end

	return G
end

return M
