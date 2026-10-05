--
-- Round 36 lane R: the rift, the main line's finale place (round36-plan.md
-- §2.1). Runtime content at one clash site (rift_core.lua's SITE), never
-- mapgen:
--   * the void node: not walkable, liquid-like movement, damage per second
--     on the nodes a player stands in, unbreakable and never in a player's
--     hands;
--   * the crack: a jagged line of void two nodes deep, cut into the site's
--     floor once per world when a player first finds the place loaded,
--     recorded in mod storage; only nodes the world protection reports as the
--     site's POI core, never a prop, the central actor clearance or the box's
--     outer ring (rift_core.lua). The one deliberate, recorded exception to
--     "runtime effects never change a POI";
--   * dark particles over the crack while a player is near (per player, one
--     spawner per crack stretch every few seconds; rift_core.lua's budget);
--   * the rift boss: a demonic level-60 elite on the Dungeon Master's mesh,
--     spawned like a leader when a player who may fight him comes near (the
--     finale in his quest log or done, rift_core.lua's eligible), bound to the site by
--     its own leash (aggro.lua's chase leash and evade home, with this boss's
--     radius) and an idle walk home, back about five minutes after its death;
--     loot through bosses.lua's ledger and 24-hour lockout (boss loot once a
--     day, an elite's roll inside the lockout; grug_quality), the kill
--     through grug_mobs.register_on_boss_kill as "rift:<site key>".
--
local modpath = core.get_modpath("grug_mobs")
local R = dofile(modpath .. "/rift_core.lua")
grug_mobs.rift_rules = R
local storage = grug_mobs.storage
local catalog = dofile(core.get_modpath("grug_mapgen") .. "/wp40/r20_poi_catalog.lua")

-- Lane A's art (round36-plan.md §4.9, story bible §3): every texture of the
-- rift is named here and nowhere else.
local TEXTURES = {
	void = "grug_mobs_rift_void.png",
	particle = "grug_mobs_rift_particle.png",
	boss = "grug_mobs_isquarre.png",
	bolt = "grug_mobs_rift_bolt.png",
}

local VOID = "grug_mobs:rift_void"
-- A player in the void loses VOID_PERCENT of his own pool a second, like lava
-- (grug_core node_pool_damage through the group below): about 9 s at any
-- level, armour never reduces it. The node's flat damage_per_second only
-- switches the engine's tick on; it is what a mob that ends up in the void
-- takes (mobs avoid damaging nodes).
local VOID_PERCENT = 11
local VOID_DPS = 300

core.register_node(VOID, {
	description = "Rift Void",
	drawtype = "normal",
	tiles = {TEXTURES.void},
	paramtype = "light",
	light_source = 3,
	-- A player sinks in and moves as in a liquid, so he can swim up and step
	-- out at the edge; no breath is lost and nothing suffocates in it.
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = false,
	floodable = false,
	is_ground_content = false,
	liquid_move_physics = true,
	move_resistance = 2,
	drowning = 0,
	damage_per_second = VOID_DPS,
	post_effect_color = {a = 190, r = 16, g = 0, b = 28},
	drop = "",
	groups = {not_in_creative_inventory = 1, grug_pool_damage = VOID_PERCENT},
	on_blast = function() end,
})

--
-- The site: its catalogue row, anchor and crack, resolved once the zone
-- authority answers.
--
local site
local function current_site()
	if site then return site end
	local zones = rawget(_G, "grug_zones")
	if not zones then return nil end
	local art = R.site_row(catalog, R.SITE)
	local anchor = art and zones.anchor(art.zone_id, art.slot)
	if not anchor then return nil end
	local cells = R.crack_cells(art, R.CANDIDATES[R.SITE])
	site = {key = R.SITE, art = art, id = R.boss_id(R.SITE),
		anchor = {x = anchor.x, y = anchor.y, z = anchor.z},
		cells = cells, nodes = R.crack_nodes(cells, anchor)}
	-- The particle stretches: runs of about eight crack cells, each one
	-- spawner's box.
	site.stretches = {}
	for first = 1, #cells, 8 do
		local box
		for index = first, math.min(#cells, first + 7) do
			local x, z = anchor.x + cells[index][1], anchor.z + cells[index][2]
			if not box then
				box = {x0 = x, x1 = x, z0 = z, z1 = z}
			else
				box.x0, box.x1 = math.min(box.x0, x), math.max(box.x1, x)
				box.z0, box.z1 = math.min(box.z0, z), math.max(box.z1, z)
			end
		end
		site.stretches[#site.stretches + 1] = box
	end
	return site
end
grug_mobs.rift_site = current_site

local function crack_key(key) return "rift_crack:" .. key end
local function due_key(key) return "rift_boss_due:" .. key end

-- Counters for the engine probe (tools/r36_r).
grug_mobs.rift_stats = {crack_nodes = 0, spawners = 0, particles = 0, spawns = 0}

--
-- The crack, written once. Every node must be loaded first; then each cell's
-- floor (the anchor height) must be ground with air above, a walkable node
-- under its two void nodes, and every written node the site's own POI core
-- in the world protection. A cell that fails stays floor. The storage mark
-- (the count written) makes every later load write nothing.
--
local function walkable(node)
	local def = node and core.registered_nodes[node.name]
	return def ~= nil and def.walkable == true
end

local function open_above(node)
	local def = node and core.registered_nodes[node.name]
	return def ~= nil and def.walkable == false and node.name ~= VOID
end

local function write_crack(s)
	if storage:get_string(crack_key(s.key)) ~= "" then return true end
	-- The world protection answers for the site's core once it is installed.
	if grug_core.world_feature_at(s.anchor) ~= "poi" then return false end
	for _, cell in ipairs(s.cells) do
		local x, z = s.anchor.x + cell[1], s.anchor.z + cell[2]
		for dy = -R.DEPTH, 2 do
			if not core.get_node_or_nil({x = x, y = s.anchor.y + dy, z = z}) then
				return false
			end
		end
	end
	local written = 0
	for _, cell in ipairs(s.cells) do
		local x, y, z = s.anchor.x + cell[1], s.anchor.y, s.anchor.z + cell[2]
		local floor = core.get_node({x = x, y = y, z = z})
		local ok = walkable(floor) and
			open_above(core.get_node({x = x, y = y + 1, z = z})) and
			open_above(core.get_node({x = x, y = y + 2, z = z})) and
			walkable(core.get_node({x = x, y = y - R.DEPTH, z = z}))
		for depth = 0, R.DEPTH - 1 do
			ok = ok and grug_core.world_feature_at({x = x, y = y - depth, z = z}) == "poi"
		end
		if ok then
			for depth = 0, R.DEPTH - 1 do
				core.set_node({x = x, y = y - depth, z = z}, {name = VOID})
				written = written + 1
			end
		end
	end
	storage:set_string(crack_key(s.key), tostring(written))
	grug_mobs.rift_stats.crack_nodes = written
	core.log("action", ("[grug_mobs] rift: the crack at %s written once, %d void nodes " ..
		"in %d of %d cells"):format(s.art.label, written, written / R.DEPTH, #s.cells))
	return true
end

--
-- Particles: one spawner per stretch for each near player, every
-- PARTICLE_PERIOD seconds, sent to that player only.
--
local function emit_particles(s, name)
	if #s.stretches == 0 then return end
	local per = math.max(1, math.floor(R.PARTICLE_AMOUNT / #s.stretches + 0.5))
	local y = s.anchor.y + 0.6
	for _, box in ipairs(s.stretches) do
		core.add_particlespawner({
			amount = per, time = R.PARTICLE_PERIOD, playername = name,
			pos = {min = {x = box.x0 - 0.5, y = y, z = box.z0 - 0.5},
				max = {x = box.x1 + 0.5, y = y + 0.4, z = box.z1 + 0.5}},
			vel = {min = {x = -0.15, y = 0.4, z = -0.15},
				max = {x = 0.15, y = 1.1, z = 0.15}},
			exptime = {min = R.PARTICLE_LIFE[1], max = R.PARTICLE_LIFE[2]},
			size = {min = 1.5, max = 3.5},
			texture = TEXTURES.particle, glow = 3,
		})
		grug_mobs.rift_stats.spawners = grug_mobs.rift_stats.spawners + 1
		grug_mobs.rift_stats.particles = grug_mobs.rift_stats.particles + per
	end
end

--
-- The rift boss.
--
local BOSS = "grug_mobs:rift_boss"
-- Its numbers (tools/r36_r/numbers.py; the user: no harder than a dragon): twice a
-- level-60 elite's HP, sized for two or three level-60 players; the leash
-- radius around its spot; the void pulse every PULSE_INTERVAL seconds of a
-- fight (the first after PULSE_FIRST), a PULSE_WINDUP wind-up, then
-- PULSE_MULT times its hit to every player within PULSE_RADIUS with a
-- knockback, on top of the elite's frontal wind-up hit and its void bolts.
local HP_SCALE = 2
local LEASH = 24
local HOME_REACH = 4
local PULSE_FIRST = 8
local PULSE_INTERVAL = 14
local PULSE_WINDUP = 2
local PULSE_MULT = 2
local PULSE_RADIUS = 6
local PULSE_KNOCKBACK = 7
-- The Dungeon Master's box at this size factor (the elite x1.4 comes on
-- top, levels.lua).
local SIZE = 1.15

grug_mobs.register_simple_arrow("grug_mobs:rift_bolt", {
	label = "a void bolt", texture = TEXTURES.bolt, velocity = 9,
	size = {x = 1, y = 1}, glow = 6, tail = true, lifetime = 6,
})

local live -- the boss's ObjectRef while it stands

local function boss_alive()
	local ent = live and live:get_luaentity()
	if ent and (ent.health or 0) > 0 then return true end
	live = nil
	return false
end

local function pulse_particles(pos, radius, amount, time)
	core.add_particlespawner({
		amount = amount, time = time,
		pos = {min = {x = pos.x - radius, y = pos.y, z = pos.z - radius},
			max = {x = pos.x + radius, y = pos.y + 1.5, z = pos.z + radius}},
		vel = {min = {x = -1, y = 0.5, z = -1}, max = {x = 1, y = 2.5, z = 1}},
		exptime = {min = 0.5, max = 1.2}, size = {min = 2, max = 4},
		texture = TEXTURES.particle, glow = 6,
	})
	grug_mobs.rift_stats.particles = grug_mobs.rift_stats.particles + amount
end

-- The way home. aggro.lua's evade run (and the idle walk below) steer
-- straight, and a mob never steps into a damage node, so the crack stops a
-- run that crosses it. A run that makes no progress for STALL seconds asks
-- once for an A* way round (within mobs_redo's per-step path budget, as
-- patrol.lua's path_nudge does; no drop deeper than a node, so never into the
-- crack) and then follows its steps each server step; the evade's 40 s snap
-- home stays the backstop.
local STALL = 2
local PATH_REACH = 40

local function go_home(self, t, pos, dtime)
	local home = self._grug_home
	local dx, dz = pos.x - home.x, pos.z - home.z
	if dx * dx + dz * dz <= HOME_REACH * HOME_REACH then
		t.grug_rift_route, t.grug_rift_walk = nil, nil
		grug_mobs.stall_clear(self)
		return
	end
	local route = t.grug_rift_route
	if route then
		local step = route[route.i]
		while step and (step.x - pos.x) * (step.x - pos.x) +
				(step.z - pos.z) * (step.z - pos.z) <= 1 do
			route.i = route.i + 1
			step = route[route.i]
		end
		if step then
			grug_mobs.walk_toward(self, step.x, step.z, pos)
			-- Knocked off the route (no progress toward its step): drop it,
			-- so the walk below stalls again and asks for a new way.
			t.grug_rift_walk = (t.grug_rift_walk or 0) + dtime
			if t.grug_rift_walk >= 1 then
				local elapsed = t.grug_rift_walk
				t.grug_rift_walk = 0
				if grug_mobs.stall_clock(self, step.x, step.z, pos, elapsed) >= STALL then
					t.grug_rift_route = nil
					grug_mobs.stall_clear(self)
				end
			end
			return
		end
		t.grug_rift_route = nil
	end
	t.grug_rift_walk = (t.grug_rift_walk or 0) + dtime
	if t.grug_rift_walk < 1 then return end
	local elapsed = t.grug_rift_walk
	t.grug_rift_walk = 0
	-- The evade steers itself once a second; the idle walk is ours.
	if not t.grug_evading then grug_mobs.walk_toward(self, home.x, home.z, pos) end
	if grug_mobs.stall_clock(self, home.x, home.z, pos, elapsed) < STALL then return end
	local obstacle = mobs.grug_obstacle
	if not obstacle.spare_path_budget() then return end
	local feet = (self.collisionbox and self.collisionbox[2]) or 0
	local from = vector.round({x = pos.x, y = pos.y + feet, z = pos.z})
	local started = core.get_us_time()
	local path = core.find_path(from, vector.round(home), PATH_REACH, 1, 1, "A*_noprefetch")
	obstacle.note_path_cost(core.get_us_time() - started)
	grug_mobs.stall_clear(self)
	if path then
		path.i = 1
		t.grug_rift_route = path
	end
end

local function boss_tick(self, dtime)
	local s = current_site()
	self._grug_boss_id = s and s.id or self._grug_boss_id
	self.temp = self.temp or {}
	local t = self.temp
	local cast = t.grug_rift_cast
	-- A reset (leash, give-up, idle heal) or a lost target ends the pulse's
	-- wind-up: an evading boss never lands it.
	if cast and (t.grug_evading or not self.attack) then
		t.grug_rift_cast, cast = nil, nil
		t.grug_telegraph = nil
		if self.update_tag then self:update_tag() end
	end
	if cast then
		self:set_velocity(0)
		cast.left = cast.left - dtime
		-- The frontal wind-up (telegraph.lua) waits for the pulse.
		t.grug_tg_cd = math.max(t.grug_tg_cd or 0, cast.left + 1)
		if cast.left <= 0 then
			t.grug_rift_cast = nil
			t.grug_telegraph = nil
			if self.update_tag then self:update_tag() end
			local pos = self.object:get_pos()
			if pos then
				grug_mobs.boss_hit_players(self, PULSE_RADIUS, PULSE_MULT, false,
					PULSE_KNOCKBACK, nil)
				pulse_particles(pos, PULSE_RADIUS, 40, 0.4)
			end
			t.grug_rift_pulse = PULSE_INTERVAL
		end
		return
	end
	local pos = self.object and self.object:get_pos()
	if not pos then return end
	if self.state ~= "attack" or not self.attack or t.grug_evading then
		t.grug_rift_pulse = nil
		-- Idle or evading: back to its spot (a reset inside the leash leaves
		-- it where the fight ended).
		if self._grug_home and (t.grug_evading or not self.attack) then
			go_home(self, t, pos, dtime)
		end
		return
	end
	t.grug_rift_route, t.grug_rift_walk = nil, nil
	t.grug_rift_pulse = (t.grug_rift_pulse or PULSE_FIRST) - dtime
	if t.grug_rift_pulse > 0 or t.grug_tg_left then return end
	t.grug_rift_cast = {left = PULSE_WINDUP}
	grug_mobs.root(self, PULSE_WINDUP)
	t.grug_telegraph = true
	if self.update_tag then self:update_tag() end
	self:set_animation("punch", true)
	pulse_particles(pos, 1.5, 30, PULSE_WINDUP)
end

local function boss_died(self)
	local s = current_site()
	local id = s and s.id or self._grug_boss_id
	if id then grug_mobs.boss_settle(id, self, nil) end
	storage:set_string(due_key(R.SITE), tostring(R.respawn_due(os.time())))
	live = nil
end

local box = {-0.5, -1, -0.5, 0.5, 1.6, 0.5}
local select_box = {-0.9, -1.05, -0.5, 0.9, 1.7, 0.65}
for index = 1, 6 do
	box[index] = box[index] * SIZE
	select_box[index] = select_box[index] * SIZE
end
select_box.rotate = true

grug_mobs.register_mob("grug_mobs:rift_boss", {
	description = R.BOSS_NAME, clock = "any", type = "monster",
	-- An approved voice family (the Dungeon Master's), no new sound.
	_grug_voice = "giant",
	_grug_fixed_level = 60, _grug_tier = "elite",
	_grug_hp_scale = HP_SCALE, _grug_leash_range = LEASH,
	attack_type = "dogshoot", attack_players = true, attack_npcs = false,
	group_attack = false, reach = 3, pathfinding = 1,
	walk_velocity = 1.2, run_velocity = 4.6, walk_chance = 0,
	jump = true, jump_height = 4, stepheight = 1.1, fear_height = 4,
	view_range = 20, dogshoot_switch = 1,
	dogshoot_count_max = 6, dogshoot_count2_max = 3,
	arrow = "grug_mobs:rift_bolt", arrow_override = grug_mobs.stamp_arrow_damage,
	shoot_interval = 2.5, shoot_offset = 1.4,
	visual = "mesh", mesh = "grug_mobs_dungeon_master.b3d", glow = 3,
	textures = {{TEXTURES.boss}},
	visual_size = {x = SIZE, y = SIZE},
	collisionbox = box, selectionbox = select_box,
	makes_footstep_sound = true,
	animation = {
		stand_start = 0, stand_end = 19, stand_speed = 15,
		walk_start = 20, walk_end = 35, walk_speed = 15,
		run_start = 20, run_end = 35, run_speed = 40,
		punch_start = 36, punch_end = 48, punch_speed = 20,
		shoot_start = 36, shoot_end = 48, shoot_speed = 20,
	},
	drops = {}, water_damage = 0, lava_damage = 1, light_damage = 0,
	do_custom = boss_tick,
	on_die = boss_died,
})

-- The boss's floor spot: the anchor column's ground (the centre of the
-- clash composition, its actor clearance).
local function boss_spot(s)
	local x, z = s.anchor.x, s.anchor.z
	for y = s.anchor.y + 2, s.anchor.y - 2, -1 do
		local here = core.get_node_or_nil({x = x, y = y, z = z})
		if not here then return nil end
		if walkable(here) then return {x = x, y = y + 1, z = z} end
	end
	return {x = x, y = s.anchor.y + 1, z = z}
end

local function spawn_boss(s, players)
	local pos = boss_spot(s)
	if not pos then return false end
	for _, player in ipairs(players) do
		local p = player:get_pos()
		local dx, dz = p.x - pos.x, p.z - pos.z
		if dx * dx + dz * dz < R.SPAWN_CLEAR * R.SPAWN_CLEAR then return false end
	end
	local object = core.add_entity(pos, BOSS)
	local ent = object and object:get_luaentity()
	if not ent then return false end
	grug_mobs.place_on_ground(object, pos)
	object:set_properties({static_save = false})
	ent._grug_boss_id = s.id
	ent._grug_home = {x = pos.x, y = pos.y, z = pos.z}
	-- A boss that vanished with its area leaves no ledger behind.
	grug_mobs.boss_attempt_reset(s.id)
	live = object
	grug_mobs.rift_stats.spawns = grug_mobs.rift_stats.spawns + 1
	pulse_particles(pos, 2, 60, 1.5)
	for _, player in ipairs(players) do
		core.chat_send_player(player:get_player_name(),
			R.BOSS_NAME .. " rises from the rift.")
	end
	return true
end

--
-- The one throttled pass: once a second, only while a player is near.
--
-- The players the pass works around: a seam so the engine probe can stand in
-- a point for a player (like spawn_regions.lua's SR.players).
function grug_mobs.rift_players()
	return core.get_connected_players()
end

-- Whether `player` may call the boss up (R.eligible): asked of grug_quests,
-- which loads after grug_mobs and stays optional (without it, everyone).
local function eligible(player)
	local quests = rawget(_G, "grug_quests")
	if not (quests and quests.quest_held) then return true end
	return R.eligible(function(id) return quests.quest_held(player, id) end)
end

local function any_eligible(players)
	for _, player in ipairs(players) do
		if eligible(player) then return true end
	end
	return false
end

local clock, particle_clock = 0, {}
core.register_globalstep(function(dtime)
	clock = clock + dtime
	if clock < 1 then return end
	local elapsed = clock
	clock = 0
	local s = current_site()
	if not s then return end
	local near, range = {}, math.max(R.SPAWN_RANGE, R.PARTICLE_RANGE)
	for _, player in ipairs(grug_mobs.rift_players()) do
		local p = player:get_pos()
		local dx, dz = p.x - s.anchor.x, p.z - s.anchor.z
		if dx * dx + dz * dz <= range * range and math.abs(p.y - s.anchor.y) <= range then
			near[#near + 1] = player
		end
	end
	if #near == 0 then
		particle_clock = {}
		return
	end
	if not write_crack(s) then return end
	local next_clock = {}
	for _, player in ipairs(near) do
		local name = player:get_player_name()
		local left = (particle_clock[name] or 0) - elapsed
		if left <= 0 then
			emit_particles(s, name)
			left = R.PARTICLE_PERIOD
		end
		next_clock[name] = left
	end
	particle_clock = next_clock
	local due = tonumber(storage:get_string(due_key(R.SITE))) or 0
	if R.may_spawn(boss_alive(), due, os.time()) and any_eligible(near) then
		spawn_boss(s, near)
	end
end)
