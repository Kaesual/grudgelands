--
-- Humanoid camps: the camp-fire node and its respawn timer
-- (docs/design/biomes_mobs.md §4, row "Bandits / Mirefolk | **no ABM** —
-- camp node timer respawns 120-300 s, anchored to camp, 3-5 per camp").
--
-- Why a node timer and not an ABM: §4's performance justification puts camps
-- and rares "off the ABM entirely (node timers / scheduled) — zero idle
-- cost". A node timer only ticks while its mapblock is ACTIVE, i.e. while a
-- player is nearby, and it costs nothing at all otherwise. That is also why
-- the empty-area branch below is not a hack but the honest reading of the
-- situation: with no player around there are no loaded objects to count and
-- mobs:add_mob would refuse anyway (api.lua:3435, count_mobs needs a player
-- within active_block_range * 2 = 128 m).
--
-- FLOW, end to end:
--   grug_mobs.place_camp(pos, "bandit")   (WP13's settlement pass, or a
--       hand-placed node in creative -> on_construct defaults to "bandit")
--     -> node grug_mobs:camp_fire, meta _grug_camp_type = "bandit"
--     -> node timer starts
--   on_timer -> camp_tick(pos):
--       roll the camp's target size ONCE (meta _grug_camp_target, 3-5)
--       no player within 80 m?          -> re-arm short, do nothing
--       enough living camp mobs?        -> re-arm short, do nothing
--       otherwise spawn exactly ONE mob near the fire and re-arm 120-300 s
--   the spawned mob gets `_grug_home = camp pos` (aggro.lua leashes it back
--       there and heals it on reset) and `_grug_camp_pos = camp pos`
--       (identity for the head count here and for the mirefolk swarm verb)
--   with `_grug_leash_range = 25` in the mob defs, that IS "defends camp".
--
-- STATE lives in node meta, so a camp survives restarts and world unloads
-- with zero mod storage:
--   `_grug_camp_type`   string, a key of grug_mobs.registered_camp_types
--   `_grug_camp_target` int, the rolled 3-5 (0/absent = not rolled yet)
--

--
-- Registry
--

grug_mobs.registered_camp_types = {}

-- id -> {mob = "grug_mobs:bandit", count_min = 3, count_max = 5, radius = 12}
function grug_mobs.register_camp_type(id, def)
	grug_mobs.registered_camp_types[id] = {
		mob = def.mob,
		count_min = def.count_min or 3,
		count_max = def.count_max or 5,
		radius = def.radius or 12,
	}
end

local DEFAULT_TYPE = "bandit"
local META_TYPE = "_grug_camp_type"
local META_TARGET = "_grug_camp_target"

-- Re-arm delay when the tick had nothing to do (nobody around, camp full, no
-- free ground). Short on purpose: it is one cheap check, and it decides how
-- fast a camp repopulates once a player walks up to a stale one.
local IDLE_PERIOD = 30
-- §4: "respawns 120-300 s".
local RESPAWN_MIN, RESPAWN_MAX = 120, 300
-- Do no work at all unless a player is this close. Comfortably inside
-- mobs:add_mob's own 128 m requirement, comfortably outside the camp radius.
local PLAYER_RANGE = 80
-- Head-count radius margin on top of the camp radius: a defending camp mob
-- may stand up to its leash range (25, mob defs) from the fire, and counting
-- it as gone would let the camp overfill. radius + 16 covers that for both
-- registered camp types.
local COUNT_MARGIN = 16
-- Attempts to find open ground for one new mob.
local SPOT_TRIES = 12

--
-- Helpers
--

local function camp_cfg(meta)
	local id = meta:get_string(META_TYPE)
	if id == "" then
		id = DEFAULT_TYPE
	end
	return grug_mobs.registered_camp_types[id], id
end

-- Positions read back from entity staticdata are plain tables without the
-- vector metatable, so `==` on them is silently false (luanti-lua.md rule 7).
local function same_pos(a, b)
	return a and b and a.x == b.x and a.y == b.y and a.z == b.z
end

local function player_near(pos, range)
	local players = core.get_connected_players()
	for i = 1, #players do
		local pp = players[i]:get_pos()
		if pp and vector.distance(pp, pos) <= range then
			return true
		end
	end
	return false
end

-- Living mobs of this camp. Identity is `_grug_camp_pos` (a plain field, so
-- it persists in staticdata with the mob), NOT an ObjectRef list — refs must
-- never be stored across steps.
--
-- Known and accepted blind spot: get_objects_inside_radius sees only ACTIVE
-- objects, so a camp member that wandered into an unloaded block is counted
-- as dead and the camp may briefly hold one mob too many. The leash range of
-- 25 keeps that window small, an extra bandit is not a balance problem, and
-- the alternative (persisting a roster in meta) would have to garbage-collect
-- entities it cannot see either.
local function count_camp_mobs(pos, cfg)
	local n = 0
	local objs = core.get_objects_inside_radius(pos, cfg.radius + COUNT_MARGIN)
	for i = 1, #objs do
		local ent = objs[i]:get_luaentity()
		if ent and ent.name == cfg.mob and (ent.health or 0) > 0
				and same_pos(ent._grug_camp_pos, pos) then
			n = n + 1
		end
	end
	return n
end

-- A standable spot in the ring around the fire: air with air above it and
-- solid, non-liquid ground below. Searched locally (pos.y +-3) instead of via
-- grug_core.find_surface, which scans the absolute band y 120..-16 and would
-- happily answer with the mountain top above a hillside camp.
local function free_spot_near(pos, radius)
	for _ = 1, SPOT_TRIES do
		local angle = math.random() * 2 * math.pi
		local dist = 2 + math.random() * math.max(0, radius - 2)
		local x = math.floor(pos.x + math.cos(angle) * dist + 0.5)
		local z = math.floor(pos.z + math.sin(angle) * dist + 0.5)
		for dy = 3, -3, -1 do
			local p = {x = x, y = pos.y + dy, z = z}
			local here = core.get_node_or_nil(p)
			local above = core.get_node_or_nil({x = x, y = p.y + 1, z = z})
			local below = core.get_node_or_nil({x = x, y = p.y - 1, z = z})
			if here and above and below
					and here.name == "air" and above.name == "air"
					and below.name ~= "air" and below.name ~= "ignore"
					and core.get_item_group(below.name, "liquid") == 0 then
				return p
			end
		end
	end
	return nil
end

--
-- The tick. Returns the number of seconds until the next one.
--

local function camp_tick(pos)
	local meta = core.get_meta(pos)
	local cfg, id = camp_cfg(meta)
	if not cfg then
		-- A camp type that no mod registered (typo, or a removed family):
		-- log once per tick at a slow rate instead of spinning.
		core.log("warning", "[grug_mobs] camp fire at " ..
			core.pos_to_string(pos) .. " has unknown camp type '" .. id .. "'")
		return RESPAWN_MAX
	end
	-- Camp size is rolled ONCE and kept, so a camp has a stable identity
	-- ("this is a five-bandit camp") instead of re-rolling every respawn.
	local target = meta:get_int(META_TARGET)
	if target <= 0 then
		target = math.random(cfg.count_min, cfg.count_max)
		meta:set_int(META_TARGET, target)
	end
	-- Nobody here: the objects would not be loaded and mobs:add_mob would
	-- refuse. Re-arm and leave (see the header).
	if not player_near(pos, PLAYER_RANGE) then
		return IDLE_PERIOD
	end
	if count_camp_mobs(pos, cfg) >= target then
		return IDLE_PERIOD
	end
	local spot = free_spot_near(pos, cfg.radius)
	if not spot then
		return IDLE_PERIOD
	end
	-- `ignore_count = true` is REQUIRED: mobs:add_mob otherwise compares
	-- against the family's mobs:spawn aoc, and a camp family has no
	-- mobs:spawn row at all, so that cap defaults to 1 (api.lua:3444) — every
	-- camp would top out at a single mob. The camp's own target is the cap.
	-- add_mob returns nil whenever it declines (no player in range, active
	-- mob limit, entity missing); that must never be an error here.
	local ent = mobs:add_mob(spot, {name = cfg.mob, ignore_count = true})
	if not ent then
		return IDLE_PERIOD
	end
	-- Plain-table copy, never the caller's table and never an ObjectRef.
	-- `_grug_home` is what aggro.lua leashes to (and heals at); levels.lua's
	-- ensure_init only fills it in if it is still unset, and we are ahead of
	-- the mob's first tick here, so this wins.
	local home = {x = pos.x, y = pos.y, z = pos.z}
	ent._grug_home = home
	ent._grug_camp_pos = {x = pos.x, y = pos.y, z = pos.z}
	return math.random(RESPAWN_MIN, RESPAWN_MAX)
end

--
-- The node
--

-- Deliberately family-agnostic ("camp fire", not "bandit fire"): the same
-- node anchors mirefolk pools and whatever WP13 adds later; the camp TYPE
-- lives in meta.
core.register_node("grug_mobs:camp_fire", {
	description = "Camp Fire",
	drawtype = "nodebox",
	tiles = {"grug_mobs_camp_fire.png"},
	paramtype = "light",
	sunlight_propagates = true,
	-- Flat fire pit: ash bed plus two crossed logs. Walkable false so mobs
	-- and players never get stuck on the camp anchor (§4 gives the camp no
	-- collision role).
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, -0.4, 0.5},
			{-0.4, -0.4, -0.1, 0.4, -0.25, 0.1},
			{-0.1, -0.4, -0.4, 0.1, -0.25, 0.4},
		},
	},
	selection_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, -0.25, 0.5},
	},
	walkable = false,
	is_ground_content = false, -- caves and the ocean mask must not eat a camp
	light_source = 9, -- a camp fire is a landmark at night
	-- cracky 3 = diggable with a pickaxe, not by hand: destroying a camp
	-- should be a deliberate act. grug_camp = 1 is the dispatch group
	-- (AGENTS.md: dispatch on groups, not on name lists) for WP13 and for
	-- anything that later wants to find camps.
	groups = {cracky = 3, grug_camp = 1},
	sounds = default.node_sound_gravel_defaults(),

	on_construct = function(pos)
		local meta = core.get_meta(pos)
		if meta:get_string(META_TYPE) == "" then
			meta:set_string(META_TYPE, DEFAULT_TYPE)
		end
		meta:set_string("infotext", "Camp Fire")
		core.get_node_timer(pos):start(IDLE_PERIOD)
	end,

	-- Returning `true` would re-arm with the SAME timeout (mapblock.cpp
	-- MapBlock::step: the engine calls setNodeTimer(timeout, 0) on a true
	-- return), which is not what we want — the period alternates between the
	-- idle check and the 120-300 s respawn. So we start the next timer
	-- ourselves and return false. That order is safe: the elapsed timer has
	-- already been removed from the block's list before the callback runs, so
	-- the timer started here is the one that survives.
	on_timer = function(pos)
		core.get_node_timer(pos):start(camp_tick(pos))
		return false
	end,
})

--
-- Placement API
--

-- Places (or re-types) a camp. This is the entry point for WP13's settlement
-- pass and for manual testing; placing the bare node by hand also works and
-- defaults to the bandit camp via on_construct.
--
-- Returns true on success, false for an unknown camp type — a silent no-op
-- would hide a typo in a settlement schematic.
function grug_mobs.place_camp(pos, type_id)
	type_id = type_id or DEFAULT_TYPE
	if not grug_mobs.registered_camp_types[type_id] then
		core.log("warning", "[grug_mobs] place_camp: unknown camp type '" ..
			tostring(type_id) .. "'")
		return false
	end
	-- set_node fires on_construct, which writes the default type and arms the
	-- timer; the two lines after it overwrite that default.
	core.set_node(pos, {name = "grug_mobs:camp_fire"})
	local meta = core.get_meta(pos)
	meta:set_string(META_TYPE, type_id)
	meta:set_int(META_TARGET, 0) -- re-rolled for THIS type on the first tick
	-- Populate promptly instead of after the on_construct idle period: a camp
	-- placed next to a player should not stand empty for half a minute.
	core.get_node_timer(pos):start(1)
	return true
end

--
-- The two camp types of §4
--
-- Both are "3-5 per camp" (§4 aoc column). The radii differ by habitat: a
-- bandit camp sprawls across a clearing, a mirefolk camp huddles around one
-- swamp pool (§3.1 "camps at swamp pools").
--

grug_mobs.register_camp_type("bandit", {
	mob = "grug_mobs:bandit",
	count_min = 3,
	count_max = 5,
	radius = 12,
})

grug_mobs.register_camp_type("mirefolk", {
	mob = "grug_mobs:mirefolk",
	count_min = 3,
	count_max = 5,
	radius = 10,
})
