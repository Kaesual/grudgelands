-- Round 31 Lane G portable test (LuaJIT): the PvP garrisons, captains and
-- Generals (round31-plan.md §1 G; pvp-plan rulings 12 and 16-20 and the
-- coordinator defaults).
--
--   luajit tools/r31_g/portable_test.lua [REPO]
--
--   N  names: data/pvp_names.json is the Astra file, two Generals and a
--      captain for every camp and every race of its faction, all distinct;
--      a missing name stops the load;
--   R  the rules (pvp_garrison.lua) over every real socket of lane S's
--      blueprints: the fortress of each faction (2 gate and 10 inner guards
--      at level 60 elite, the General, 2 bodyguards; quest givers, the
--      Quartermaster and the waystone are no garrison) and both camp layouts
--      of every catalogue row in every race of its faction (4 or 5 guards in
--      the camp's 3-level band, never elite, and the named captain at the top
--      level, no elite but a leader: grug_mobs.LEADER's 1.15 size and 1.5 HP
--      in his definition, once, nothing per entity); levels per band, respawn intervals, the mixed look of
--      the fortress guards and bodyguards (lane A's npc_race contract), quest
--      areas; a camp race of the other faction is refused;
--   P  placement through the REAL start_npcs.lua, guard.lua and bosses.lua
--      (under a small engine model) on a fortress and two camps registered
--      in the real socket registry: the right entity on every socket, level,
--      tier, name, the mixed-race mark before the first draw, quest area,
--      post or home, the royal encounter id; the General's one fixed look of
--      his seat race in the royal guards' tabard; the quest givers and the
--      Quartermaster on their sockets;
--   T  respawn timers: a camp guard returns 100-140 s, a captain 270-330 s
--      and a fortress guard 180-360 s of world time after its death, each
--      re-rolled in its band; a dead bodyguard stays down until the General's
--      encounter resets; the General's death books the whole group for 15
--      minutes of wall-clock time, the king rule;
--   K  kill counting: grug_pvp's real eligible-kill hook counts an enemy
--      player's kills of fortress and camp guards, bodyguards, captains and
--      Generals, and nothing of the own side's;
--   Q  the fortress quest givers' records (grug_quests/npcs.lua) follow the
--      registry: three per registered fortress, none for one that is not;
--      the placed quest shell (the REAL start_villagers.lua elder) shows its
--      role title as nametag and as its own name (`description`), also after
--      a reload;
--   L  the General's loot (user ruling): grug_quality's REAL kill-loot hook
--      and gear roll give him a boss's drop (Round 33: two items at item
--      level 65, each blue or gold at even odds) and his
--      bodyguards, kings and royal guards none; the hook only runs for a
--      kill aggro.lua's REAL player_drop_tagger credits, which for a faction
--      NPC is an enemy player's (the war trophies' rule).
-- Prints "R31 G PORTABLE PASS checks=<n>" or the failures.

grug_sounds = {play = function() return false end, CLICK_STYLE = ""} -- Round 34 sound hooks: silent here
local repo = arg and arg[1] or "."
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end

local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = copy(v) end
	return out
end
table.copy = copy

local function read(path)
	local handle = assert(io.open(path, "rb"), path)
	local text = handle:read("*a")
	handle:close()
	return text
end

local json = dofile(repo .. "/tools/r28_b1/json.lua")
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local catalog = dofile(wp40 .. "/r31_pvp_catalog.lua")
local source = dofile(wp40 .. "/source/simple_map.lua")
local M = dofile(repo .. "/mods/ENTITIES/grug_mobs/pvp_garrison.lua")
local names = json.parse(read(repo .. "/mods/ENTITIES/grug_mobs/data/pvp_names.json"))
local G = M.new(catalog, names)

local zone_of = {}
for _, zone in ipairs(source.zones) do zone_of[zone.id] = zone end
local function band_of(row)
	local zone = zone_of[row.zone_id]
	return {zone.level_min, zone.level_max}
end

------------------------------------------------------------------------------
-- N. Names.
------------------------------------------------------------------------------
do
	local astra = json.parse(read(repo .. "/docs/planning/round31/pvp-names.json"))
	local function same(a, b)
		if type(a) ~= type(b) then return false end
		if type(a) ~= "table" then return a == b end
		for k, v in pairs(a) do if not same(v, b[k]) then return false end end
		for k in pairs(b) do if a[k] == nil then return false end end
		return true
	end
	-- Round 36 adds the war commanders' working names (tools/r36_r), which
	-- the Round 31 Astra file does not carry. Round 38 renamed one captain
	-- (the user's accepted names, 2026-10-06); the rest are the Astra file.
	astra.captains.pvp_camp_skyglass_canopy_throng_low.undead = "Captain Morveth Stillwake"
	check(same({generals = names.generals, captains = names.captains}, astra),
		"N the shipped Generals and captains are the Astra file (and Round 38's rename)")
	local seen, count, keys = {}, 0, 0
	local function name_ok(name, label)
		check(type(name) == "string" and name ~= "" and not seen[name], "N " .. label .. " named once")
		if name then seen[name] = true end
		count = count + 1
	end
	name_ok(G.general_name("accord"), "the Accord General")
	name_ok(G.general_name("throng"), "the Throng General")
	for _, row in ipairs(catalog.rows) do
		if row.kind ~= "pvp_fortress" then
			keys = keys + 1
			for _, race in ipairs(catalog.FACTION_RACES[row.faction]) do
				name_ok(G.captain_name(row.key, race), row.key .. " " .. race)
				check(G.captain_name(row.key, race):find("^Captain ") ~= nil,
					"N " .. row.key .. " " .. race .. " is a Captain")
			end
		end
	end
	eq(keys, 16, "N sixteen camps")
	eq(count, 50, "N two Generals and 48 captains")
	local extra = 0
	for key in pairs(names.captains) do
		if not G.poi(key) then extra = extra + 1 end
	end
	eq(extra, 0, "N every named camp is a catalogue camp")
	local broken = copy(names)
	broken.captains.pvp_camp_broken_causeway_accord_low.elf = nil
	check(not pcall(M.new, catalog, broken), "N a camp race without a captain name stops the load")
	broken = copy(names)
	broken.generals.throng = nil
	check(not pcall(M.new, catalog, broken), "N a faction without a General name stops the load")
end

------------------------------------------------------------------------------
-- R. Rules over the real blueprint sockets.
------------------------------------------------------------------------------
_G.core = {}
local build = dofile(wp40 .. "/r31_pvp_poi_blueprint.lua")
local function sockets_of(kind, faction, race)
	local bp = build({}, {art = {kind = kind, faction = faction, race = race, turns = 0},
		blueprint_schema = "r31_g_test", numeric_id = 1})
	return bp.landmarks.sockets, bp.landmarks.race
end
local function tag_of(socket) return socket.tags and socket.tags[1] end

for _, faction in ipairs({"accord", "throng"}) do
	local key = "pvp_fortress_" .. faction
	local sockets, race = sockets_of("pvp_fortress", faction)
	eq(race, catalog.SEAT_RACE[faction], "R " .. key .. " registers as the seat race")
	local count = {gate = 0, inner = 0, general = 0, bodyguard = 0, none = 0}
	for _, socket in ipairs(sockets) do
		local spec = G.slot(key, race, socket, nil)
		local where = "R " .. key .. " " .. socket.id
		if socket.role == "guard_post" then
			count[tag_of(socket)] = count[tag_of(socket)] + 1
			eq(spec.entity, "grug_mobs:guard_" .. faction, where .. " entity")
			check(spec.level_min == 60 and spec.level_max == 60, where .. " level 60")
			eq(spec.tier, "elite", where .. " elite")
			check(spec.respawn[1] == 180 and spec.respawn[2] == 360, where .. " guard-post respawn")
			check(not spec.royal and not spec.name, where .. " an ordinary guard")
			eq(spec.mixed, true, where .. " any race of the faction")
			eq(spec.area, (faction == "accord" and "elandor_ashenward_march/" or
				"kragmar_bannerbreak_mesa/") .. key, where .. " quest area")
		elseif socket.role == "general" then
			count.general = count.general + 1
			eq(spec.entity, "grug_mobs:general_" .. faction, where .. " entity")
			check(spec.royal and spec.leader and not spec.respawn and not spec.level_min,
				where .. " the leader of a royal group at his own level")
			check(not spec.mixed, where .. " of the seat race")
		elseif socket.role == "bodyguard" then
			count.bodyguard = count.bodyguard + 1
			eq(spec.entity, "grug_mobs:bodyguard_" .. faction, where .. " entity")
			check(spec.royal and not spec.leader and not spec.respawn, where .. " retinue")
			eq(spec.mixed, true, where .. " any race of the faction")
		else
			count.none = count.none + 1
			eq(spec, nil, where .. " (" .. socket.role .. ") is no garrison post")
		end
	end
	eq(count.gate, 2, "R " .. key .. " two gate guards")
	check(count.inner >= 8, "R " .. key .. " at least eight inner guards (" .. count.inner .. ")")
	eq(count.general, 1, "R " .. key .. " one General")
	eq(count.bodyguard, 2, "R " .. key .. " two bodyguards")
	eq(count.none, 5, "R " .. key .. " three quest givers, the Quartermaster, the waystone")
end

local banded = {}
for _, row in ipairs(catalog.rows) do
	if row.kind ~= "pvp_fortress" then
		local band = band_of(row)
		local low, high = catalog.camp_levels(band[1], band[2], row.band)
		eq(high - low, 2, "R " .. row.key .. " a three-level band")
		banded[row.key] = {low, high}
		for _, race in ipairs(catalog.FACTION_RACES[row.faction]) do
			local sockets = sockets_of(row.kind, row.faction, race)
			local guards, captains = 0, 0
			for _, socket in ipairs(sockets) do
				local spec = G.slot(row.key, race, socket, band)
				local where = "R " .. row.key .. " " .. race .. " " .. socket.id
				if socket.role == "guard_post" then
					guards = guards + 1
					eq(spec.entity, "grug_mobs:guard_" .. row.faction, where .. " entity")
					check(spec.level_min == low and spec.level_max == high, where .. " the camp band")
					eq(spec.tier, "normal", where .. " never elite")
					check(spec.respawn[1] == 100 and spec.respawn[2] == 140, where .. " about 2 min")
					check(not spec.mixed, where .. " the camp's race")
					eq(spec.area, row.zone_id .. "/" .. row.key, where .. " quest area")
				elseif socket.role == "captain" then
					captains = captains + 1
					eq(spec.entity, "grug_mobs:captain_" .. row.faction, where .. " entity")
					check(spec.level_min == high and spec.level_max == high, where .. " the top level")
					eq(spec.tier, "normal", where .. " no elite")
					check(spec.respawn[1] == 270 and spec.respawn[2] == 330, where .. " about 5 min")
					eq(spec.name, names.captains[row.key][race], where .. " named")
					check(not spec.mixed, where .. " the camp's race")
					eq(spec.area, row.zone_id .. "/" .. row.key, where .. " quest area")
				else
					eq(spec, nil, where .. " is no garrison post")
				end
			end
			eq(guards, row.band == "low" and 4 or 5, "R " .. row.key .. " " .. race .. " guards")
			eq(captains, 1, "R " .. row.key .. " " .. race .. " one captain")
		end
		local other = catalog.FACTION_RACES[row.faction == "accord" and "throng" or "accord"][1]
		check(not pcall(G.slot, row.key, other, {role = "captain"}, band),
			"R " .. row.key .. " a race of the other faction is refused")
	end
end
check(banded.pvp_camp_broken_causeway_accord_low[1] == 41 and
	banded.pvp_camp_broken_causeway_accord_low[2] == 43, "R the Causeway's lower camp 41-43")
check(banded.pvp_camp_broken_causeway_throng_high[1] == 48 and
	banded.pvp_camp_broken_causeway_throng_high[2] == 50, "R the Causeway's higher camp 48-50")
check(banded.pvp_camp_gravesalt_escarpment_accord_low[1] == 51 and
	banded.pvp_camp_skyglass_canopy_throng_high[2] == 60, "R the 51-60 camps 51-53 and 58-60")
eq(G.slot("hearthpine", "dwarf", {role = "guard_post"}), nil, "R a start is no PvP POI")
eq(G.settlement_kind("pvp_fortress_throng"), "pvp_fortress", "R the fortress kind")
eq(G.settlement_kind("pvp_camp_shattered_line_throng_high"), "pvp_camp", "R the camp kind")
eq(M.pvp_kind("grug_mobs:captain_accord"), "captain", "R a captain counts as a captain")
eq(M.pvp_kind("grug_mobs:general_throng"), "general", "R a General counts as a General")
eq(M.pvp_kind("grug_mobs:bodyguard_throng"), "guard", "R a bodyguard counts as a guard")

------------------------------------------------------------------------------
-- Engine model for P, T, K and Q.
------------------------------------------------------------------------------
local serial, steps, loaded, logs = {}, {}, {}, {}
local gametime, walltime = 5000, 1700000000
os.time = function() return walltime end -- luacheck: ignore
local store = {}
local storage = {
	get_string = function(_, k) return store[k] or "" end,
	set_string = function(_, k, v) store[k] = v end,
}
local live = {}
local function noop() end
_G.core = setmetatable({
	registered_entities = {},
	serialize = function(value) serial[#serial + 1] = copy(value); return "S" .. #serial end,
	deserialize = function(text)
		local index = type(text) == "string" and tonumber(text:match("^S(%d+)$"))
		return index and copy(serial[index]) or nil
	end,
	log = function(level, text) logs[#logs + 1] = level .. ": " .. text end,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
	after = noop,
	get_gametime = function() return gametime end,
	pos_to_string = function(p) return ("(%d,%d,%d)"):format(p.x, p.y, p.z) end,
	get_node_or_nil = function() return {name = "default:dirt_with_grass"} end,
	compare_block_status = function() return false end,
	dir_to_yaw = function(d) return math.atan2(-d.x, d.z) end,
	get_mod_storage = function() return storage end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
	is_player = function(obj) return type(obj) == "table" and obj.is_player ~= nil and obj:is_player() end,
	get_objects_inside_radius = function()
		local out = {}
		for _, entity in ipairs(live) do
			if entity.object.valid then out[#out + 1] = entity.object end
		end
		return out
	end,
}, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return noop end
	return nil
end})
_G.vector = {new = function(x, y, z) return {x = x, y = y, z = z} end}

local function activate(name, staticdata, pos)
	local def = assert(core.registered_entities[name], name)
	local object = {pos = copy(pos), valid = true}
	local entity = setmetatable({name = name, object = object}, {__index = def})
	function object:get_pos() return self.valid and copy(self.pos) or nil end
	function object:remove() self.valid = false end
	function object:get_luaentity() return self.valid and entity or nil end
	function object:is_player() return false end
	for k, v in pairs(core.deserialize(staticdata) or {}) do entity[k] = v end
	live[#live + 1] = entity
	return object, entity
end
core.add_entity = function(pos, name, staticdata) return (activate(name, staticdata, pos)) end

_G.grug_core = setmetatable({}, {__index = function(_, key)
	if type(key) == "string" and key:match("^register_") then return noop end
	return nil
end})
dofile(repo .. "/mods/CORE/grug_core/settlement_sockets.lua")
local IDENTITIES = {}
for faction, races in pairs(catalog.FACTION_RACES) do
	for _, race in ipairs(races) do IDENTITIES[#IDENTITIES + 1] = {race_id = race, faction_id = faction} end
end
grug_core.start_identities = function() return IDENTITIES end
grug_core.start_anchor = function() return nil end
grug_core.capital_anchor = function() return nil end
grug_core.start_ready = function() return false end
grug_core.opposing_faction = function(id) return id == "accord" and "throng" or "accord" end
_G.grug_zones = {get = function(id) return zone_of[id] end}

_G.mobs = {mob_class = {}}
function mobs:remove(entity) entity.object:remove() end
_G.grug_mobs = {
	-- Round 38: the shipped names (bosses.lua reads them).
	names = dofile(repo .. "/tools/r38_b1/names_stub.lua").shipped(repo),
	storage = storage,
	pvp_garrison = G,
	place_on_ground = noop,
	face_yaw = noop,
	clear_boss_activity = noop,
	register_dragon_bosses = noop,
	-- levels.lua's leader factors (the real values; levels.lua is not loaded).
	LEADER = {size = 1.15, hp = 1.5},
	-- levels.lua's two seams the garrison install calls, reduced to the fields.
	set_tier = function(entity, tier) entity._grug_tier = tier end,
	relevel = function(entity, level) entity._grug_level = level end,
	refresh_visual = noop,
	-- The wrapper's registration, reduced to keeping the definition (mobs_redo
	-- copies its fields; a live entity reads them through its prototype here).
	register_mob = function(name, def) core.registered_entities[name] = def end,
}
dofile(repo .. "/mods/ENTITIES/grug_mobs/guard.lua")
dofile(repo .. "/mods/ENTITIES/grug_mobs/bosses.lua")
-- The quest shell is start_villagers.lua's real elder (its nametag path);
-- the Quartermaster a stand-in (grug_traders' resolver, as vendors.lua
-- registers it).
local carrier_text = {}
grug_mobs.noncombatant = function(def) return def end
grug_mobs.set_plain_tag = function(self, text) carrier_text[self] = text end
function mobs:register_mob(name, def) core.registered_entities[name] = def end
dofile(repo .. "/mods/ENTITIES/grug_mobs/start_villagers.lua")
core.registered_entities["grug_traders:vendor_general_accord"] = {}
-- Only start_npcs.lua's heartbeat runs below (not bosses.lua's dragon clock).
steps = {}
dofile(repo .. "/mods/ENTITIES/grug_mobs/start_npcs.lua")
grug_mobs.register_start_socket_role("vendor", function(socket, settlement)
	return socket.kind == "general" and "grug_traders:vendor_general_" .. settlement.faction_id or nil
end)

-- A fortress and two camps in the real registry, at test anchors.
local POIS = {
	{key = "pvp_fortress_accord", kind = "pvp_fortress", faction = "accord", anchor = {x = 0, y = 20, z = -900}},
	{key = "pvp_camp_broken_causeway_accord_low", kind = "pvp_camp_low", faction = "accord",
		race = "dwarf", anchor = {x = -800, y = 10, z = -100}},
	{key = "pvp_camp_shattered_line_throng_high", kind = "pvp_camp_high", faction = "throng",
		race = "troll", anchor = {x = 800, y = 30, z = 100}},
}
for _, poi in ipairs(POIS) do
	local sockets, race = sockets_of(poi.kind, poi.faction, poi.race)
	poi.race = race
	grug_core.register_settlement_sockets(poi.key, race, poi.anchor, sockets, poi.key)
end
-- grug_quests loads after the registry, before the mods-loaded placement.
_G.grug_quests = {}
dofile(repo .. "/mods/PLAYER/grug_quests/registry.lua")
dofile(repo .. "/mods/PLAYER/grug_quests/npcs.lua")
for _, fn in ipairs(loaded) do fn() end
local npc_steps = steps
local function heartbeat(seconds)
	gametime = gametime + seconds
	walltime = walltime + seconds
	for _, fn in ipairs(npc_steps) do fn(5) end
end
local function count_logs(pattern)
	local n = 0
	for _, line in ipairs(logs) do if line:find(pattern, 1, true) then n = n + 1 end end
	return n
end
eq(count_logs("is not a published start"), 0, "P every PvP POI is a known settlement kind")
eq(count_logs("resolves to no registered entity"), 0, "P every socket resolves")

-- The live NPC of each socket of a settlement.
local function holders(key)
	local out = {}
	for _, entity in ipairs(live) do
		if entity.object.valid and entity._grug_start == key then
			check(out[entity._grug_socket] == nil, "P one NPC on " .. key .. "/" .. tostring(entity._grug_socket))
			out[entity._grug_socket] = entity
		end
	end
	return out
end

------------------------------------------------------------------------------
-- P. Placement.
------------------------------------------------------------------------------
heartbeat(5)
local placed = {}
for _, poi in ipairs(POIS) do
	placed[poi.key] = holders(poi.key)
	local registered = grug_core.settlement_sockets_at(poi.key)
	local band = poi.kind ~= "pvp_fortress" and band_of(G.poi(poi.key)) or nil
	for _, socket in ipairs(registered) do
		local entity = placed[poi.key][socket.id]
		local where = "P " .. poi.key .. " " .. socket.id
		local spec = G.slot(poi.key, poi.race, socket, band)
		if socket.role == "waypoint" then
			eq(entity, nil, where .. ": nobody on the waystone")
		elseif check(entity ~= nil, where .. " placed") then
			if spec then
				eq(entity.name, spec.entity, where .. " entity")
				eq(entity._grug_area, spec.area, where .. " quest area")
				eq(entity._grug_mixed_race, spec.mixed, where .. " mixed race marked before the first draw")
				eq(entity._grug_tier or "normal", spec.tier, where .. " tier")
				local level = entity._grug_level or entity._grug_fixed_level
				check(level and level >= (spec.level_min or level) and level <= (spec.level_max or level),
					where .. " level " .. tostring(level))
				eq(entity._grug_elite_checked, true, where .. " no later promotion")
				if socket.role == "guard_post" or socket.role == "captain" then
					check(entity._grug_post_x == socket.pos.x and entity._grug_post_z == socket.pos.z,
						where .. " holds its post")
				elseif socket.role == "general" then
					-- Round 41 ruling 2: the General holds his seat like a post.
					check(entity._grug_home and entity._grug_post_x == socket.pos.x and
						entity._grug_post_z == socket.pos.z, where .. " a royal home, holds his seat")
					eq(entity._grug_boss_id, "general:" .. poi.faction, where .. " the General's encounter")
				else
					check(entity._grug_home and entity._grug_post_x == nil, where .. " a royal home, no post")
					eq(entity._grug_boss_id, "general:" .. poi.faction, where .. " the General's encounter")
				end
			elseif socket.role == "quest" then
				eq(entity.name, "grug_mobs:elder_human", where .. " a protected quest shell of the seat race")
			elseif socket.role == "vendor" then
				eq(entity.name, "grug_traders:vendor_general_accord", where .. " the faction Quartermaster")
			end
		end
	end
end
do
	local fortress = placed.pvp_fortress_accord
	eq(fortress.general._grug_fixed_level, 65, "P the General is level 65")
	eq(fortress.general.description, "General Haldren Ashward", "P the General's name")
	eq(fortress.general._grug_tier, "elite", "P the General is an elite")
	eq(fortress.bodyguard_west._grug_fixed_level, 60, "P a bodyguard is level 60")
	eq(fortress.gate_west._grug_level, 60, "P a gate guard is level 60")
	local camp = placed.pvp_camp_broken_causeway_accord_low
	eq(camp.captain.description, names.captains.pvp_camp_broken_causeway_accord_low.dwarf,
		"P the dwarf captain's name")
	eq(camp.captain._grug_level, 43, "P the lower Causeway captain is level 43")
	local high = placed.pvp_camp_shattered_line_throng_high
	eq(high.captain._grug_level, 50, "P the higher Shattered Line captain is level 50")
	eq(high.captain.description, names.captains.pvp_camp_shattered_line_throng_high.troll,
		"P the troll captain's name")
	eq(high.captain._grug_mixed_race, nil, "P the captain is drawn as his camp's race")
	-- The leader: normal tier, the leader factors in the definition once
	-- (levels.lua derives HP from `_grug_hp_scale` on every activation, so a
	-- reload neither loses nor doubles them), nothing scaled per entity.
	local real_levels = read(repo .. "/mods/ENTITIES/grug_mobs/levels.lua")
	check(real_levels:find("grug_mobs.LEADER = {size = 1.15, hp = 1.5}", 1, true) ~= nil,
		"P the harness's leader factors are levels.lua's")
	local guard_def = core.registered_entities["grug_mobs:guard_throng"]
	for _, faction in ipairs({"accord", "throng"}) do
		local def = core.registered_entities["grug_mobs:captain_" .. faction]
		check(math.abs(def.visual_size.x - 1.15) < 1e-9 and math.abs(def.visual_size.y - 1.15) < 1e-9,
			"P a " .. faction .. " captain is drawn at 1.15")
		check(math.abs(def.collisionbox[5] - guard_def.collisionbox[5] * 1.15) < 1e-9 and
			math.abs(def.collisionbox[1] - guard_def.collisionbox[1] * 1.15) < 1e-9,
			"P ...his box at 1.15 of a guard's")
		eq(def._grug_hp_scale, 1.5, "P ...and 1.5 times the HP of his level")
		eq(def._grug_tier, nil, "P ...on the normal tier")
	end
	for _, captain in ipairs({camp.captain, high.captain}) do
		eq(captain._grug_tier or "normal", "normal", "P a placed captain stays normal")
		eq(captain._grug_elite_checked, true, "P ...and is never promoted (a level-60 one included)")
		eq(rawget(captain, "visual_size"), nil, "P ...with no size of his own")
	end
	local look = fortress.general.name and core.registered_entities[fortress.general.name]._grug_visual
	local spec = look(fortress.general)
	check(spec.race == "human" and spec.royal == "guard" and type(spec.look) == "table",
		"P the General: the seat race in the royal guards' tabard, no crown")
	local again = look(fortress.general)
	check(again.look == spec.look, "P ...one fixed look")
end
local census = {}
for _, row in ipairs(grug_mobs.start_npc_census()) do census[row.key] = row end
eq(census.pvp_fortress_accord.kind, "pvp_fortress", "P census: the fortress kind")
eq(census.pvp_fortress_accord.live, 19, "P census: 12 guards, the General, 2 bodyguards, 3 quest givers, the Quartermaster")
eq(census.pvp_camp_broken_causeway_accord_low.live, 5, "P census: the lower camp holds 5")
eq(census.pvp_camp_shattered_line_throng_high.live, 6, "P census: the higher camp holds 6")

------------------------------------------------------------------------------
-- T. Respawn timers.
------------------------------------------------------------------------------
local function die(entity)
	if entity.on_die then entity.on_die(entity) end
	entity.object:remove()
end
local function due(key, socket)
	return tonumber(store["startnpcdue:" .. key .. ":" .. socket])
end
do
	local camp = "pvp_camp_broken_causeway_accord_low"
	local guard, captain = placed[camp].gate_west, placed[camp].captain
	local fortress_guard = placed.pvp_fortress_accord.gate_east
	local t0 = gametime
	die(guard); die(captain); die(fortress_guard)
	local g, c, f = due(camp, "gate_west"), due(camp, "captain"), due("pvp_fortress_accord", "gate_east")
	check(g and g >= t0 + 100 and g <= t0 + 140, "T a camp guard is due in 100-140 s (" .. tostring(g and g - t0) .. ")")
	check(c and c >= t0 + 270 and c <= t0 + 330, "T a captain is due in 270-330 s (" .. tostring(c and c - t0) .. ")")
	check(f and f >= t0 + 180 and f <= t0 + 360, "T a fortress guard is due in 180-360 s (" .. tostring(f and f - t0) .. ")")
	heartbeat(95)
	eq(holders(camp).gate_west, nil, "T the camp guard is not back before its time")
	heartbeat(50)
	local back = holders(camp).gate_west
	check(back ~= nil and back ~= guard, "T a fresh camp guard after about 2 min")
	check(back and back._grug_level >= 41 and back._grug_level <= 43, "T ...in the camp band")
	eq(holders(camp).captain, nil, "T the captain is not back yet")
	heartbeat(200)
	local captain2 = holders(camp).captain
	check(captain2 ~= nil and captain2 ~= captain, "T a fresh captain after about 5 min")
	eq(captain2 and captain2.description, captain.description, "T ...with the same name")
	eq(captain2 and captain2._grug_level, 43, "T ...at the top of the band")
	eq(captain2 and (captain2._grug_tier or "normal"), "normal", "T ...a leader, no elite")
	check(holders("pvp_fortress_accord").gate_east ~= nil, "T the fortress guard is back within 6 min")

	-- The General's group, the king rule.
	local fortress = holders("pvp_fortress_accord")
	local general, west, east = fortress.general, fortress.bodyguard_west, fortress.bodyguard_east
	for _, entity in ipairs({general, west, east}) do entity.do_custom(entity, 0) end
	eq(general._grug_royal_king, true, "T the General leads his encounter")
	eq(west._grug_boss_id, "general:accord", "T a bodyguard shares it")
	die(west)
	heartbeat(600)
	eq(holders("pvp_fortress_accord").bodyguard_west, nil, "T a dead bodyguard stays down during the attempt")
	grug_mobs.boss_leash_reset(general)
	heartbeat(5)
	local west2 = holders("pvp_fortress_accord").bodyguard_west
	check(west2 ~= nil and west2 ~= west, "T the General's reset brings his bodyguards back")
	check(holders("pvp_fortress_accord").bodyguard_east ~= east, "T ...both of them, fresh")
	east = holders("pvp_fortress_accord").bodyguard_east
	local w0 = walltime
	die(general)
	for _, socket in ipairs({"general", "bodyguard_west", "bodyguard_east"}) do
		eq(due("pvp_fortress_accord", socket), w0 + 900, "T the General's death books " .. socket .. " at 15 min")
	end
	check(not east.object.valid and not west2.object.valid, "T the bodyguards leave with their General")
	heartbeat(890)
	eq(holders("pvp_fortress_accord").general, nil, "T no General before 15 min")
	heartbeat(15)
	local after = holders("pvp_fortress_accord")
	check(after.general and after.bodyguard_west and after.bodyguard_east,
		"T the whole group returns after 15 min")
end

------------------------------------------------------------------------------
-- K. Kill counting through grug_pvp's real hook.
------------------------------------------------------------------------------
do
	steps, loaded = {}, {}
	local eligible
	grug_mobs.register_on_eligible_kill = function(fn) eligible = fn end
	_G.grug_factions = {
		get_faction = function(player) return player.faction end,
		get_object_faction = function(obj)
			if obj:is_player() then return obj.faction end
			local ent = obj:get_luaentity()
			return ent and ent._grug_faction
		end,
	}
	_G.sfinv = {pages = {}, pages_unordered = {}, contexts = {},
		register_page = function(name, def) sfinv.pages[name] = def end}
	core.get_modpath = function() return repo .. "/mods/PLAYER/grug_pvp" end
	core.get_current_modname = function() return "grug_pvp" end
	core.get_connected_players = function() return {} end
	dofile(repo .. "/mods/PLAYER/grug_pvp/init.lua")
	check(eligible ~= nil, "K grug_pvp hooks grug_mobs' eligible kills")
	local function player(faction)
		local meta = {}
		return {faction = faction, is_player = function() return true end,
			get_meta = function()
				return {get_int = function(_, k) return meta[k] or 0 end,
					set_int = function(_, k, v) meta[k] = v end}
			end}
	end
	local org, ann = player("throng"), player("accord")
	local fortress = holders("pvp_fortress_accord")
	local accord_camp = holders("pvp_camp_broken_causeway_accord_low")
	local throng_camp = holders("pvp_camp_shattered_line_throng_high")
	for _, entity in ipairs({fortress.gate_west, fortress.corner_northeast, fortress.bodyguard_east,
			fortress.general, accord_camp.yard_west, accord_camp.captain}) do
		eligible(org, entity)
		eligible(ann, entity)
	end
	eligible(ann, throng_camp.captain)
	eligible(ann, throng_camp.tower_east)
	local so, sa = grug_pvp.stats(org), grug_pvp.stats(ann)
	eq(so.guards, 4, "K the Throng player: two fortress guards, a bodyguard, a camp guard")
	eq(so.captains, 1, "K the Throng player: one captain")
	eq(so.generals, 1, "K the Throng player: one General")
	eq(sa.guards, 1, "K the Accord player counts only the enemy camp guard")
	eq(sa.captains, 1, "K ...and the enemy captain")
	eq(sa.generals, 0, "K ...never the own General")
end

------------------------------------------------------------------------------
-- Q. The fortress quest givers' records.
------------------------------------------------------------------------------
do
	local Q = grug_quests
	for _, role in ipairs({"warmaster", "drillmaster", "outrider"}) do
		local npc = Q.registered_npcs["r31_accord_" .. role]
		check(npc and npc.settlement == "pvp_fortress_accord" and npc.socket == "quest_" .. role,
			"Q the Accord fortress " .. role .. " stands on its socket")
		eq(Q.registered_npcs["r31_throng_" .. role], nil, "Q no record for an unregistered fortress")
	end
	eq(grug_mobs.quest_socket_title("pvp_fortress_accord", "quest_warmaster"), "Warmaster",
		"Q the quest shell takes the record's title")
	-- The placed shells: nametag and own name are the role title, not the
	-- race's "Village Elder", at placement and after a reload.
	local fortress = holders("pvp_fortress_accord")
	for _, pair in ipairs({{"quest_warmaster", "Warmaster"}, {"quest_drillmaster", "Drillmaster"},
			{"quest_outrider", "Outrider"}}) do
		local shell = fortress[pair[1]]
		if check(shell ~= nil, "Q " .. pair[1] .. " placed") then
			eq(carrier_text[shell], pair[2], "Q " .. pair[1] .. " nametag")
			eq(shell.description, pair[2], "Q " .. pair[1] .. " own name")
			eq(shell._grug_npc_tag, pair[2], "Q " .. pair[1] .. " spoken name")
			-- Reload: the saved plain fields onto a fresh entity, then the
			-- family's after_activate, as mob_activate does.
			local saved = {}
			for k, v in pairs(shell) do
				if type(v) ~= "function" and k ~= "object" and k ~= "temp" and k ~= "name" then
					saved[k] = copy(v)
				end
			end
			shell.object:remove()
			local _, back = activate(shell.name, core.serialize(saved), shell.object.pos)
			core.registered_entities[shell.name].after_activate(back)
			eq(carrier_text[back], pair[2], "Q " .. pair[1] .. " nametag after a reload")
			eq(back.description, pair[2], "Q " .. pair[1] .. " own name after a reload")
		end
	end
end

------------------------------------------------------------------------------
-- L. The General's loot.
------------------------------------------------------------------------------
do
	-- grug_quality under small stubs: an item stack with meta, PCG as a plain
	-- LCG, one gear item per tier, and the hooks it registers captured.
	local loot_hook
	local saved_core, saved_mobs = _G.core, _G.grug_mobs
	local function stack_of(name)
		local meta_store = {}
		local meta = {
			set_int = function(_, k, v) meta_store[k] = v end,
			get_int = function(_, k) return tonumber(meta_store[k]) or 0 end,
			set_string = function(_, k, v) meta_store[k] = v end,
			get_string = function(_, k) return meta_store[k] or "" end,
		}
		return {name = name, meta_store = meta_store,
			get_meta = function() return meta end,
			get_definition = function() return {groups = {}} end,
			get_name = function() return name end,
			is_empty = function() return false end,
			get_count = function() return 1 end}
	end
	_G.ItemStack = function(name) return stack_of(name) end
	_G.PcgRandom = function(seed)
		local state = seed % 2147483647
		return {next = function(_, a, b)
			state = (state * 48271) % 2147483647
			return a + state % (b - a + 1)
		end}
	end
	local dropped = {}
	_G.core = setmetatable({
		add_item = function(_, stack)
			dropped[#dropped + 1] = stack
			return {set_velocity = noop}
		end,
		get_us_time = function() return 123456789 end,
		get_gametime = function() return gametime end,
		serialize = function() return "" end,
	}, {__index = function() return noop end})
	local quality_mobs = setmetatable({
		register_kill_loot_hook = function(fn) loot_hook = fn end,
	}, {__index = function() return noop end})
	_G.grug_mobs = quality_mobs
	_G.grug_gear = {drop_pool = {}}
	for tier = 1, 6 do grug_gear.drop_pool[tier] = {"grug_gear:test_" .. tier} end
	local saved_items = rawget(_G, "grug_items")
	_G.grug_items = nil
	setmetatable(_G, {__index = function(_, name)
		if type(name) == "string" and name:match("^grug_") then
			return setmetatable({}, {__index = function() return noop end})
		end
	end})
	dofile(repo .. "/mods/ITEMS/grug_quality/init.lua")
	setmetatable(_G, nil)
	local rolled = {}
	grug_items.roll_enchants = function(stack, ilvl, count)
		rolled[#rolled + 1] = {quality = count + 1, ilvl = ilvl}
	end
	check(loot_hook ~= nil, "L grug_quality hooks the kill loot")
	-- Round 33 (round33-plan.md §2.1): a boss's two items, each blue or gold.
	local row = grug_items.BOSS_DROPS
	check(row and row.count == 2 and row.gold == 50 and row.ilvl.general == 65,
		"L the General drops two items, gold at 50 %, item level 65")

	local general = {name = "grug_mobs:general_accord", _grug_boss_id = "general:accord",
		_grug_royal_king = true, _grug_tier = "elite", _grug_level = 65,
		object = {get_pos = function() return {x = 0, y = 0, z = 0} end}}
	local bodyguard = {name = "grug_mobs:bodyguard_accord", _grug_boss_id = "general:accord",
		_grug_tier = "elite", _grug_level = 60, object = general.object}
	local king = {name = "grug_mobs:king_human", _grug_boss_id = "king:human",
		_grug_royal_king = true, _grug_tier = "elite", _grug_level = 65, object = general.object}
	local royal = {name = "grug_mobs:royal_guard_human", _grug_boss_id = "king:human",
		_grug_tier = "elite", _grug_level = 60, object = general.object}
	-- 2000 seeded rolls: the item level, the count and the split.
	local uncommon, rare, n = 0, 0, 2000
	local ilvl_ok, count_ok = true, true
	for seed = 1, n do
		rolled = {}
		grug_items.roll_mob_gear(general, seed * 7919)
		count_ok = count_ok and #rolled == 2
		for _, roll in ipairs(rolled) do
			ilvl_ok = ilvl_ok and roll.ilvl == 65
			if roll.quality == 2 then uncommon = uncommon + 1 else rare = rare + 1 end
		end
	end
	check(ilvl_ok, "L the General's gear is item level 65")
	check(count_ok, "L ...always two items")
	check(math.abs(uncommon / (2 * n) - 0.50) < 0.05,
		("L blue about 50 %% (%.1f %%)"):format(50 * uncommon / n))
	check(uncommon + rare == 2 * n, "L ...the rest gold")
	-- The hook: the General drops gear (over many kills), his bodyguards,
	-- kings and royal guards none.
	local function drops_over(entity, kills)
		dropped = {}
		for _ = 1, kills do loot_hook(entity, "org") end
		return #dropped
	end
	check(drops_over(general, 50) >= 100, "L the kill-loot hook drops the General's gear")
	eq(drops_over(bodyguard, 50), 0, "L a bodyguard drops no gear")
	eq(drops_over(king, 50), 0, "L a king's gear stays in his reward ledger")
	eq(drops_over(royal, 50), 0, "L a royal guard drops no gear")

	-- Whose kill runs the hook: aggro.lua's player_drop_tagger, the war
	-- trophies' predicate (the REAL function cut out of the source).
	local src = read(repo .. "/mods/ENTITIES/grug_mobs/aggro.lua")
	local body = src:match("(function grug_mobs%.player_drop_tagger%(self%).-\nend)\n")
	check(body ~= nil, "L player_drop_tagger found in aggro.lua")
	_G.grug_mobs = {}
	_G.core = {is_player = function(obj) return type(obj) == "table" and obj.player == true end,
		get_gametime = function() return gametime end}
	local factions = {org = "throng", ann = "accord"}
	_G.grug_core = {get_player_faction = function(name) return factions[name] end,
		opposing_faction = function(id) return id == "accord" and "throng" or "accord" end}
	assert(loadstring(body))()
	local function killer(name)
		return {player = true, get_player_name = function() return name end}
	end
	local function tagged(by)
		local victim = {_grug_faction = "accord", cause_of_death = by and {puncher = by} or nil}
		return grug_mobs.player_drop_tagger(victim)
	end
	eq(tagged(killer("org")), "org", "L an enemy player's kill of the General drops")
	eq(tagged(killer("ann")), nil, "L an own-faction player's kill drops nothing")
	eq(tagged({player = false}), nil, "L a mob's kill drops nothing")
	eq(tagged(nil), nil, "L a death without a puncher drops nothing")
	_G.core, _G.grug_mobs, _G.grug_items = saved_core, saved_mobs, saved_items
end

if failures > 0 then
	error(("%d checks, %d failures"):format(checks, failures), 0)
end
print(("R31 G PORTABLE PASS checks=%d"):format(checks))
