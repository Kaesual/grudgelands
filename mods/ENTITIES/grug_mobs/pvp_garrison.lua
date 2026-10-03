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
--             captain                   the named captain, elite at the top
--                                       of the band
-- Looks: fortress guards and bodyguards a race of their faction, the General
-- his faction's seat race, a camp's people its own race (round31-plan §1:
-- lane A's look roll replaces the race roll through one seam in
-- start_npcs.lua, `grug_mobs.roll_garrison_look`).
--
-- Plain Lua 5.1, no globals.
--
local M = {}

M.FORTRESS_GUARD_LEVEL = 60
M.BODYGUARD_LEVEL = 60
M.GENERAL_LEVEL = 65

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
}

-- The entity of each garrison role and faction.
function M.guard_entity(faction) return "grug_mobs:guard_" .. faction end
function M.captain_entity(faction) return "grug_mobs:captain_" .. faction end
function M.general_entity(faction) return "grug_mobs:general_" .. faction end
function M.bodyguard_entity(faction) return "grug_mobs:bodyguard_" .. faction end

-- What grug_pvp counts a kill of each garrison entity as (its NPC counters,
-- ruling 16); the faction guards are counted by name already.
function M.pvp_kind(entity)
	if entity:find("^grug_mobs:captain_") then return "captain" end
	if entity:find("^grug_mobs:general_") then return "general" end
	if entity:find("^grug_mobs:bodyguard_") then return "guard" end
	return nil
end

local function fail(message)
	error("grug_mobs PvP garrison: " .. message, 0)
end

-- `catalog` is r31_pvp_catalog.lua's table, `names` the decoded
-- data/pvp_names.json ({generals = {accord, throng}, captains = {<camp key> =
-- {<race> = name}}}). Fails loudly when a General or any captain a camp can
-- roll has no name.
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

	function G.general_name(faction)
		return names.generals[faction]
	end

	function G.captain_name(key, race)
		local captains = names.captains[key]
		return captains and captains[race] or nil
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
	-- General's group), royal, leader, name, looks (races to roll from),
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
				spec.tier, spec.respawn, spec.looks = "elite", M.RESPAWN.fortress_guard, races
			elseif role == "general" then
				spec.entity, spec.tier = M.general_entity(faction), "elite"
				spec.royal, spec.leader = true, true
				spec.looks = {catalog.SEAT_RACE[faction]}
			elseif role == "bodyguard" then
				spec.entity, spec.tier = M.bodyguard_entity(faction), "elite"
				spec.royal, spec.looks = true, races
			else
				return nil
			end
			return spec
		end
		if role ~= "guard_post" and role ~= "captain" then return nil end
		if type(band) ~= "table" or type(band[1]) ~= "number" or type(band[2]) ~= "number" then
			fail(key .. ": the zone's level band differs")
		end
		local of_faction = false
		for _, race in ipairs(races) do of_faction = of_faction or race == race_id end
		if not of_faction then fail(key .. ": race " .. tostring(race_id) .. " is not of " .. faction) end
		local low, high = catalog.camp_levels(band[1], band[2], row.band)
		spec.looks = {race_id}
		if role == "captain" then
			spec.entity = M.captain_entity(faction)
			spec.level_min, spec.level_max = high, high
			spec.tier, spec.respawn = "elite", M.RESPAWN.captain
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
