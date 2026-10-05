-- Disposable Round 36 lane G probe (tools/r36_g/engine.sh). Never shipped.
--
-- Only the two dragon arenas (their 82 x 82 squares emerged, nothing else):
--   HAZARDS  the arena nodes the mapgen wrote in each arena, counted per node
--            (thin ice, ice water, frost stone, ember, basalt);
--   PUSH     the Stormscale wyvern (spawned by bosses.lua once its lair is
--            loaded) fights a stand-in player 4 nodes from it; every wind-up
--            cue and every velocity the dragon adds to the stand-in is logged
--            with its time, plus the particles spawned around the push; then
--            dragon and stand-in are moved near the arena edge (the stand-in
--            at radius 33, the dragon 6 nodes further in) for a second push.
-- The stand-in is a Lua table the probe makes `core.is_player`,
-- `core.get_objects_inside_radius` and the faction lookup accept; the
-- dragon's own step then skips mobs_redo's generic attack (do_custom returns
-- false) and its breath, lightning and dive are held back (the primary
-- cooldown kept full), so only the push acts on it.
-- Every line carries "[r36g]"; the probe ends the server when done.
local P = "[r36g] "
local function log(s) core.log("action", P .. s) end
local now = function() return core.get_us_time() / 1e6 end

local layout = dofile(core.get_modpath("grug_mapgen") .. "/wp40/arena_layout.lua")
local ARENAS = {
	{id = "stormscale", x = 3260, z = -40},
	{id = "wyrmglass", x = -3260, z = -40},
}
local DRAGON = "grug_mobs:jungle_wyvern"
local STANDIN = "r36g_standin"

-- ------------------------------------------------------------- the stand-in
local Standin = {}
Standin.__index = Standin
local standin
local pushes = {}
local t_engaged
local dragon_obj
function Standin:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
function Standin:get_hp() return 20000 end
function Standin:get_player_name() return STANDIN end
function Standin:is_player() return true end
function Standin:get_luaentity() return nil end
function Standin:get_velocity() return {x = 0, y = 0, z = 0} end
function Standin:punch() end
function Standin:set_hp() end
function Standin:add_velocity(v)
	local d = dragon_obj and dragon_obj:get_pos()
	local h = math.sqrt(v.x * v.x + v.z * v.z)
	local dist = d and math.sqrt((self.pos.x - d.x) * (self.pos.x - d.x) + (self.pos.z - d.z) * (self.pos.z - d.z)) or -1
	pushes[#pushes + 1] = {t = now(), h = h}
	log(("PUSH t=%.2f s velocity=(%.2f, %.2f, %.2f) horizontal=%.2f stand-in %.1f from the dragon")
		:format(now() - (t_engaged or now()), v.x, v.y, v.z, h, dist))
end

-- ------------------------------------------------------------------ seams
local particles, spawners = 0, 0
core.register_on_mods_loaded(function()
	local is_player = core.is_player
	core.is_player = function(o)
		if type(o) == "table" and getmetatable(o) == Standin then return true end
		return is_player(o)
	end
	local inside = core.get_objects_inside_radius
	core.get_objects_inside_radius = function(pos, r)
		local list = inside(pos, r)
		if standin then
			local p = standin.pos
			local dx, dy, dz = p.x - pos.x, p.y - pos.y, p.z - pos.z
			if dx * dx + dy * dy + dz * dz <= r * r then list[#list + 1] = standin end
		end
		return list
	end
	local faction = grug_core.get_player_faction
	grug_core.get_player_faction = function(name)
		if name == STANDIN then return "accord" end
		return faction(name)
	end
	local play = grug_sounds.play
	grug_sounds.play = function(event, target, ...)
		if t_engaged and (event == "telegraph" or event:find("^dragon")) then
			log(("CUE t=%.2f s %s"):format(now() - t_engaged, event))
		end
		return play(event, target, ...)
	end
	local add_spawner, add_particle = core.add_particlespawner, core.add_particle
	core.add_particlespawner = function(def)
		spawners = spawners + 1
		particles = particles + (def.amount or 0)
		return add_spawner(def)
	end
	core.add_particle = function(def)
		particles = particles + 1
		return add_particle(def)
	end
	local slow = grug_mobs.slow_player
	grug_mobs.slow_player = function(player, duration, factor)
		if player == standin then
			log(("SLOW %.1f s x%.2f"):format(duration, factor))
			return
		end
		return slow(player, duration, factor)
	end
	local proto = core.registered_entities[DRAGON]
	local custom = proto.do_custom
	proto.do_custom = function(self, dtime, moveresult)
		custom(self, dtime, moveresult)
		return false
	end
end)

-- ---------------------------------------------------------------- hazards
local NODE_KEYS = {"thin_ice", "ice_water", "frost_stone", "ember", "basalt"}
local function count_hazards(a)
	local y = grug_zones.terrain_height_at(a.x, a.z)
	local vm = core.get_voxel_manip()
	local e1, e2 = vm:read_from_map({x = a.x - 41, y = y - 12, z = a.z - 41},
		{x = a.x + 41, y = y + 24, z = a.z + 41})
	local area = VoxelArea:new({MinEdge = e1, MaxEdge = e2})
	local data = vm:get_data()
	local ids, counts = {}, {}
	for _, k in ipairs(NODE_KEYS) do ids[core.get_content_id(layout.NODES[k])] = k; counts[k] = 0 end
	for z = a.z - 41, a.z + 41 do
		for yy = y - 12, y + 24 do
			for x = a.x - 41, a.x + 41 do
				local k = ids[data[area:index(x, yy, z)]]
				if k then counts[k] = counts[k] + 1 end
			end
		end
	end
	local parts = {}
	for _, k in ipairs(NODE_KEYS) do parts[#parts + 1] = k .. "=" .. counts[k] end
	log(("HAZARDS %s (floor y %d): %s"):format(a.id, y, table.concat(parts, " ")))
end

-- ------------------------------------------------------------------ phases
local phase, phase_t, total_t, clock = "emerge", 0, 0, 0
local emerged = 0
local function set_phase(p) phase, phase_t = p, 0; log("phase -> " .. p) end

core.after(1, function()
	for _, a in ipairs(ARENAS) do
		local y = grug_zones.terrain_height_at(a.x, a.z)
		a.y = y + 1
		core.emerge_area({x = a.x - 48, y = y - 16, z = a.z - 48},
			{x = a.x + 48, y = y + 32, z = a.z + 48}, function(_, _, remaining)
				if remaining == 0 then emerged = emerged + 1 end
			end)
	end
	local s = ARENAS[1]
	-- 16 blocks (the engine's default forceload limit): the centre to radius
	-- 40 eastward, where the second push happens.
	for bx = math.floor((s.x - 8) / 16), math.floor((s.x + 40) / 16) do
		for bz = math.floor((s.z - 8) / 16), math.floor((s.z + 8) / 16) do
			for by = math.floor((s.y - 8) / 16), math.floor((s.y + 8) / 16) do
				core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
			end
		end
	end
	log("emerging both arenas, forceloading the Stormscale centre and its east half")
end)

local function find_dragon(a)
	for _, o in ipairs(core.get_objects_inside_radius({x = a.x, y = a.y, z = a.z}, 60)) do
		local e = o:get_luaentity()
		if e and e.name == DRAGON then return o, e end
	end
end

local function finish()
	log(("RESULT DONE pushes=%d"):format(#pushes))
	core.request_shutdown("r36g probe done", false, 1)
end

core.register_globalstep(function(dtime)
	clock = clock + dtime
	if clock < 0.25 then return end
	local dt = clock
	clock = 0
	phase_t, total_t = phase_t + dt, total_t + dt
	if total_t > 280 and phase ~= "done" then
		log("TIMEOUT in phase " .. phase)
		set_phase("done")
		finish()
		return
	end
	local s = ARENAS[1]
	if phase == "emerge" then
		if emerged == #ARENAS then
			for _, a in ipairs(ARENAS) do count_hazards(a) end
			set_phase("spawn")
		end
	elseif phase == "spawn" then
		local obj = find_dragon(s)
		if obj and phase_t > 2 then
			dragon_obj = obj
			local p = obj:get_pos()
			standin = setmetatable({pos = {x = p.x + 4, y = p.y, z = p.z}}, Standin)
			t_engaged = now()
			log(("dragon at (%.1f, %.1f, %.1f); stand-in 4 nodes east"):format(p.x, p.y, p.z))
			set_phase("push1")
		end
	elseif phase == "push1" or phase == "push2" then
		local e = dragon_obj and dragon_obj:get_luaentity()
		if not e then log("the dragon is gone"); set_phase("done"); finish(); return end
		e.attack = standin
		-- No breath, lightning or dive: only the push acts on the stand-in.
		local st = e.temp and e.temp.grug_dragon
		if st and not st.action then st.primary = 99 end
		local want = phase == "push1" and 1 or 2
		if math.floor(phase_t / 5) ~= math.floor((phase_t - dt) / 5) and st then
			local p = dragon_obj:get_pos()
			log(("state t=%.1f mode=%s gust=%.1f engaged=%s target=%s action=%s dragon=(%.1f, %.1f, %.1f)")
				:format(phase_t, tostring(st.mode), st.gust or -1, tostring(st.engaged),
				tostring(e.attack == standin), st.action and st.action.kind or "-", p.x, p.y, p.z))
		end
		if #pushes >= want and now() - pushes[want].t > 0.6 then
			log(("particles during the phase: %d in %d spawners/particles calls"):format(particles, spawners))
			if phase == "push1" then
				-- near the edge: the stand-in at radius 33, the dragon 6 further in
				local fy = grug_zones.terrain_height_at(s.x + 27, s.z) + 1
				dragon_obj:set_pos({x = s.x + 27, y = fy, z = s.z})
				standin.pos = {x = s.x + 33, y = grug_zones.terrain_height_at(s.x + 33, s.z) + 1, z = s.z}
				particles, spawners = 0, 0
				t_engaged = now()
				log("moved: dragon at radius 27, stand-in at radius 33 (room to the hazard edge 36: 3)")
				set_phase("push2")
			else
				set_phase("done")
				finish()
			end
		elseif phase_t > 60 then
			log("no push within 60 s in " .. phase)
			set_phase("done")
			finish()
		end
	end
end)
