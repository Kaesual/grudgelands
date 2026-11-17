--
-- Named rares: scheduled spawner, patrol and faction broadcast
-- (docs/design/biomes_mobs.md §3.3, combat_stats.md §3 "named rares
-- broadcast their spawn faction-wide").
--
-- A named rare is NOT its own mob registration: it is an ordinary mob of an
-- existing family (Grimtusk = grug_mobs:boar) placed by this spawner,
-- renamed, optionally re-textured, and promoted to tier "rare" by the level
-- engine (levels.lua: x2.5 HP, x1.4 dmg, x2 XP, armor 90, scale x2, violet
-- tint, star prefix). Its LEVEL still comes from the field at its spawn
-- position, so the route points in the registrations below decide the level
-- — see the level check comments there.
--
-- Persistence: one mod-storage record per rare id (alive / next_spawn, the
-- latter in core.get_gametime() seconds so the timer counts played world time
-- and survives restarts), plus the liveness record of its key "rare:<id>"
-- (liveness.lua: the instance's generation, its last known place, absence).
-- Runtime work is ONE globalstep throttled to 10 s over the whole registry —
-- no ABM, no per-mob polling.
--

local storage = grug_mobs.storage

local CHECK_INTERVAL = 10 -- s between spawner passes
-- A player has to be this close (horizontally) before we even try: outside
-- the active block range mobs:add_mob refuses anyway (it needs a player
-- within aoc_range * 2 = 128 m, api.lua count_mobs), and an entity added to
-- an inactive block would be pointless. Slightly under 128 so the check we
-- make and the check add_mob makes agree.
local PLAYER_RANGE = 120
local BROADCAST_COLOR = "#ffb733" -- amber (combat_stats §3)

grug_mobs.registered_rares = {} -- id -> spec

-- id -> {alive = bool, next_spawn = n}, mirrored into mod storage.
local state = {}
local liveness = grug_mobs.liveness

local function live_key(id)
	return "rare:" .. id
end

local function save(id)
	local st = state[id]
	storage:set_int("rare_alive:" .. id, st.alive and 1 or 0)
	storage:set_int("rare_next:" .. id, st.next_spawn)
end

--
-- Registration
--

-- spec = {
--   name = "Grimtusk",              -- nametag (plain field `description`)
--   mob = "grug_mobs:boar",         -- an already registered mob name
--   texture = {"a.png", "b.png"},   -- optional, one entry per model slot
--   route is injected from the authenticated stable-anchor payload
--   biome_hint = "the meadows",     -- used verbatim in the broadcast
--   respawn_min = 7200, respawn_max = 14400,  -- seconds of game time
-- }
function grug_mobs.register_rare(id, spec)
	if spec.route ~= nil then
		error("[grug_mobs] rare " .. id .. " supplied a raw route")
	end
	local route = grug_core.rare_route(id)
	if not route then
		error("[grug_mobs] rare " .. id .. " has no stable R7 route")
	end
	spec.route = route
	-- Round 38: data/names.json names the rare (its slot "rare.<id>"); the
	-- broadcast and the nametag read the same name.
	spec.name = grug_mobs.names and grug_mobs.names.lookup("rare." .. id, nil, nil) or spec.name
	grug_mobs.registered_rares[id] = spec
	state[id] = {
		alive = storage:get_int("rare_alive:" .. id) == 1,
		next_spawn = storage:get_int("rare_next:" .. id),
	}
end

-- The stable route is authoritative, but players may still obstruct one of
-- its mutable patrol cells. Never search for a replacement coordinate: use
-- the exact point only while it is loaded, air, and supported by solid land.
local function route_pos(pt)
	local here = core.get_node_or_nil(pt)
	local below = core.get_node_or_nil({x = pt.x, y = pt.y - 1, z = pt.z})
	if not here or not below or here.name ~= "air" or below.name == "air" or
			below.name == "ignore" or
			core.get_item_group(below.name, "liquid") ~= 0 then
		return nil
	end
	return pt
end

-- The players the spawner works around: a seam so the engine probe can stand
-- in a point for a player (like rift.lua's grug_mobs.rift_players).
function grug_mobs.rare_players()
	return core.get_connected_players()
end

-- Horizontal player proximity to a route point. Horizontal on purpose: the
-- stable route y does not affect whether a player keeps its mapblock loaded.
local function player_near_xz(pt, range)
	local players = grug_mobs.rare_players()
	for i = 1, #players do
		local pp = players[i]:get_pos()
		if pp then
			local dx, dz = pp.x - pt.x, pp.z - pt.z
			if dx * dx + dz * dz <= range * range then
				return true
			end
		end
	end
	return false
end

--
-- Spawn + broadcast
--

-- Faction-wide sighting message (combat_stats §3). Goes to the players of
-- the faction whose continent the rare stands on; factionless players (a
-- brand new character still on the spawn platform) get nothing, and neither
-- does the enemy faction — a rare is a meeting point for your own side.
-- grug_zones.faction_at returns the same ids as get_player_faction
-- ("accord"/"throng"), so the comparison is direct.
local function broadcast(spec, pos)
	local territory = grug_zones.faction_at(pos)
	if territory ~= "accord" and territory ~= "throng" then
		return
	end
	local msg = core.colorize(BROADCAST_COLOR,
		spec.name .. " has been sighted in " .. spec.biome_hint .. "!")
	local players = core.get_connected_players()
	for i = 1, #players do
		local name = players[i]:get_player_name()
		if grug_core.get_player_faction(name) == territory then
			core.chat_send_player(name, msg)
		end
	end
end

local function mark_alive(id)
	state[id].alive = true
	save(id)
end

local function try_spawn(id, spec)
	-- Only route points that actually have somebody near them are
	-- candidates; picking blindly would waste most passes on the far end of
	-- the route. Which of the viable ones is used stays random, so a rare
	-- does not always appear in the same corner.
	local viable, n = {}, 0
	for i = 1, #spec.route do
		if player_near_xz(spec.route[i], PLAYER_RANGE) then
			n = n + 1
			viable[n] = spec.route[i]
		end
	end
	if n == 0 then
		return -- nobody there; retry on the next pass
	end
	local pt = viable[math.random(n)]
	if liveness.instance(live_key(id)) then
		-- Already out there (stale alive flag): adopt it, never duplicate.
		mark_alive(id)
		return
	end
	local pos = route_pos(pt)
	if not pos then
		return
	end
	-- Round 25 ruling 24: a hostile rare never appears inside an active
	-- housing claim; the next pass picks a route point again.
	if grug_mobs.claim_refuses_spawn(spec.mob, pos) then
		return
	end
	-- grug_mobs.add_mob, not mobs:add_mob: the wrapper applies the
	-- collisionbox y-lift the ABM spawner does and add_mob does not (init.lua)
	-- — without it the golem- and spider-based rares spawn sunk into the
	-- ground.
	-- The next generation of this rare: any older copy still on disk is stale
	-- and removes itself when its block loads (liveness.lua). Its identity
	-- goes into the first staticdata, so the add-time static copy has it too.
	local key = live_key(id)
	local gen = liveness.next_generation(key)
	local ent = grug_mobs.add_mob(pos, {
		name = spec.mob,
		texture = spec.texture,
		ignore_count = true, -- a rare ignores the family's spawn cap
		-- ... and mobs_redo's active-mob limit, which it does not count
		-- against either (Round 37 MP, mobs/api.lua grug_authored).
		_grug_authored = true,
		_grug_staticdata = {_grug_rare_id = id, _grug_live_key = key,
			_grug_live_gen = gen, lifetimer = 30000, description = spec.name,
			_grug_name_key = "rare." .. id},
	})
	if not ent then
		return
	end
	-- `description` is a plain field of every mobs_redo entity (api.lua mobs:register_mob)
	-- and is what levels.lua's tag_text prints, so the nametag reads
	-- "★ Grimtusk [Lv 12] 325/325". It must be set BEFORE the tier: set_tier
	-- refreshes the tag.
	ent.description = spec.name
	ent._grug_rare_id = id
	-- Its slot "rare.<id>" in data/names.json (names.lua, Round 38).
	ent._grug_name_key = "rare." .. id
	liveness.adopt(ent, key, gen)
	-- Named rares must not evaporate when the last player walks away:
	-- mobs_redo deletes an unloading mob whose lifetimer is below 20000
	-- (mob_staticdata) and expires it on a timer below the same threshold
	-- (mob_expire). A plain field, so the exemption persists with the mob.
	ent.lifetimer = 30000
	-- The object keeps static_save: mob_activate leaves it on for every
	-- ordinary mob (only the terminal unload-despawn path clears it, api.lua
	-- mob_activate), so mob_staticdata runs and reads the lifetimer above.
	grug_mobs.set_tier(ent, "rare")
	-- ... and NOW the ground correction, a second time and deliberately AFTER
	-- the promotion. set_tier scales a rare by x2 (levels.lua
	-- apply_tier_visuals), which doubles the collisionbox — including its
	-- negative floor. The lift add_mob already did used the NORMAL-tier box, so
	-- a Korgan's Bane (golem, floor -1 -> -2) or a Silkfang (spider, -0.4 ->
	-- -0.8) still ended up sunk by the difference. place_on_ground computes
	-- from the ground position, not from where the mob stands, so this second
	-- call simply lands it correctly with the box it actually has now.
	grug_mobs.place_on_ground(ent.object, pos)
	mark_alive(id)
	broadcast(spec, pos)
	core.log("action", "[grug_mobs] rare " .. spec.name .. " spawned at " ..
		core.pos_to_string(vector.round(pos)))
end

--
-- Death -> respawn timer
--

-- Called from init.lua's accepted-player-hit hook on the lethal player punch.
function grug_mobs.rare_killed(id)
	local spec = grug_mobs.registered_rares[id]
	local st = state[id]
	if not spec or not st then
		return
	end
	st.alive = false
	st.next_spawn = core.get_gametime() +
		math.random(spec.respawn_min, spec.respawn_max)
	save(id)
end

-- Watchdog for a rare that left without dying: deleted by an admin or a
-- world edit, lost in a crash. Every death, whoever caused it, books the
-- ordinary respawn through rare_killed (the lethal player hit, or init.lua's
-- settle_mob_death for a guard, lava or a fall). Without the watchdog such a
-- rare would be gone for good, because `alive` would stay true forever.
--
-- liveness.lua decides (Round 37 MP, MOC-01): the rare counts as missing
-- only while its last known place is an active mapblock and no instance
-- stands, and as lost after a minute of that. The old watchdog aged the rare
-- by game time, also while nobody was near, and scanned only around the route
-- points, so the next visitor could meet a second Grimtusk.
local function rare_watch(id, spec, now)
	local st = state[id]
	if liveness.watch(live_key(id), CHECK_INTERVAL) ~= "lost" then
		return
	end
	st.alive = false
	st.next_spawn = now -- lost without a kill: let it come back immediately
	save(id)
	core.log("action", "[grug_mobs] rare " .. spec.name ..
		" lost without a recorded kill, respawn released")
end

--
-- The one slow globalstep (performance rule: accumulator-throttled, and the
-- body only runs over a handful of registry entries).
--

local acc = 0

core.register_globalstep(function(dtime)
	acc = acc + dtime
	if acc < CHECK_INTERVAL then
		return
	end
	acc = 0
	local now = core.get_gametime()
	for id, spec in pairs(grug_mobs.registered_rares) do
		local st = state[id]
		if st.alive then
			rare_watch(id, spec, now)
		elseif now >= st.next_spawn then
			try_spawn(id, spec)
		end
	end
end)

--
-- Patrol
--
-- Wired like leash_tick from init.lua's do_custom wrapper (guarded there by
-- _grug_rare_id, so no normal mob ever enters this function).
--
-- The walk itself is grug_mobs.route_tick (patrol.lua) — the identical
-- movement the outpost patrols of WP6/T8 use, on the shared navigation since
-- Round 42 (a blocked rare finds its way round, and skips a waypoint it
-- cannot reach; it is never snapped); the rationale for not using mobs_redo's
-- go_to() lives there. The current waypoint index stays in the
-- plain field `_grug_rare_wp`, so the route position survives unload/reload
-- with the mob exactly as before.
--

function grug_mobs.rare_tick(self, dtime)
	local spec = grug_mobs.registered_rares[self._grug_rare_id]
	if not spec then
		return
	end
	-- Every named rare resets at once when it cannot reach its target (Round 72
	-- GUARDNAV, aggro.lua grug_mobs.reach_reset). A rare is no registration of
	-- its own, so its registration here switches it on, also on a rare saved
	-- before 0.72.0.
	if not self._grug_reach_reset then self._grug_reach_reset = true end
	grug_mobs.route_tick(self, dtime, spec.route, self, "_grug_rare_wp")
end

-- R7 authority: the registrations below own presentation and respawn
-- metadata only. Each rare's coordinates and level come from its
-- authenticated R7 source anchor and patrol offsets; the named-zone route and
-- the target level per rare are biomes_mobs.md §3.3's table. The pre-R7
-- per-point level derivations that stood here are retired (git history keeps
-- them).

-- Grimtusk: boar, Goldmead Vale.
grug_mobs.register_rare("grimtusk", {
	name = "Grimtusk",
	mob = "grug_mobs:boar",
	biome_hint = "the central meadows",
	respawn_min = 7200, -- 2 h (biomes_mobs §3.3: respawn 2-4 h after kill)
	respawn_max = 14400, -- 4 h
})

-- Ashmaw: plague boar, Redtusk Savanna. The boar model has TWO texture slots
-- (boar.lua: {boar, blank}), and mobs:add_mob assigns def.texture straight to
-- base_texture and to set_properties{textures=...} (api.lua mobs:add_mob) --
-- so it has to be the full per-slot list, not a bare string. levels.lua then
-- reads this list as the pristine base and layers the rare violet tint on it.
grug_mobs.register_rare("ashmaw", {
	name = "Ashmaw",
	mob = "grug_mobs:boar",
	texture = {"grug_mobs_boar_plague.png", "grug_mobs_blank.png"},
	biome_hint = "the savanna",
	respawn_min = 7200,
	respawn_max = 14400,
})

-- Old Whitefang: wolf, Ashenward March. No `texture`: the base wolf skin is
-- the grey-white one, and levels.lua lays the rare violet tint over it.
grug_mobs.register_rare("old_whitefang", {
	name = "Old Whitefang",
	mob = "grug_mobs:wolf",
	biome_hint = "the deep forest",
	respawn_min = 7200, -- 2 h (§3.3: respawn 2-4 h after kill)
	respawn_max = 14400, -- 4 h
})

-- Marrowclaw: plaguehide bear, Blackwind Rise. No `texture`: the family
-- already wears the right skin.
grug_mobs.register_rare("marrowclaw", {
	name = "Marrowclaw",
	mob = "grug_mobs:plaguehide_bear",
	biome_hint = "the bone forest",
	respawn_min = 7200,
	respawn_max = 14400,
})

-- Korgan's Bane: stone golem, Stormvault Heights. The base family is the
-- game's only DEF-LEVEL ELITE (golem.lua, _grug_tier = "elite").
-- set_tier(ent, "rare") in try_spawn REPLACES that tier, it does not stack
-- on it: the rare multipliers apply to the base formula, and
-- apply_tier_visuals scales relative to the tier already APPLIED -- still
-- "normal" at that moment, because set_tier runs before the mob's first tick
-- and ensure_init then does level, stats, scale and tint in one go
-- (levels.lua). So Korgan's Bane is x2 scale and violet, never x1.4 gold or
-- x3.2 of both. It keeps the golem's telegraph (telegraph.lua fires for
-- "elite" AND "rare"). No `texture`: the golem already wears the crags skin.
grug_mobs.register_rare("korgans_bane", {
	name = "Korgan's Bane",
	mob = "grug_mobs:stone_golem",
	biome_hint = "the high crags",
	respawn_min = 7200, -- 2 h (§3.3: respawn 2-4 h after kill)
	respawn_max = 14400, -- 4 h
})

-- Silkfang: jungle spider, The Skyglass Canopy. No `texture`: the family
-- already wears the jungle skin.
grug_mobs.register_rare("silkfang", {
	name = "Silkfang",
	mob = "grug_mobs:jungle_spider",
	biome_hint = "the jungle fringe",
	respawn_min = 7200,
	respawn_max = 14400,
})

-- Dustwing: vulture, Bannerbreak Mesa. No `texture`: the family already
-- wears the dark badlands retint.
grug_mobs.register_rare("dustwing", {
	name = "Dustwing",
	mob = "grug_mobs:vulture",
	biome_hint = "the badlands",
	respawn_min = 7200,
	respawn_max = 14400,
})

-- Emerald Coil: serpent, the Stormscale Summit approach. No `texture`: the
-- family has only the one skin.
grug_mobs.register_rare("emerald_coil", {
	name = "Emerald Coil",
	mob = "grug_mobs:serpent",
	biome_hint = "the deep jungle",
	respawn_min = 7200,
	respawn_max = 14400,
})

-- Captain Bonerattle x2: skeleton raider, The Broken Causeway and The
-- Shattered Line, at the spawn region's level. §3.3 lists "Captain
-- Bonerattle (x2, one per continent)": both carry the SAME name, only the
-- registry ids differ. The ids keep them apart where it matters: the
-- liveness key is "rare:<id>", so the northern captain can never be mistaken
-- for the southern one. No `texture`: the family already wears the grimy
-- war-coast bones, and levels.lua lays the rare violet tint over them.
grug_mobs.register_rare("bonerattle_south", {
	name = "Captain Bonerattle",
	mob = "grug_mobs:skeleton_raider",
	-- The authenticated southern route belongs to the Accord.
	biome_hint = "the war coast",
	respawn_min = 7200, -- 2 h (§3.3: respawn 2-4 h after kill)
	respawn_max = 14400, -- 4 h
})

grug_mobs.register_rare("bonerattle_north", {
	name = "Captain Bonerattle",
	mob = "grug_mobs:skeleton_raider",
	biome_hint = "the war coast",
	respawn_min = 7200,
	respawn_max = 14400,
})
