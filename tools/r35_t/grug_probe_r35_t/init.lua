-- Disposable Round 35 T probe (tools/r35_t/engine.sh). Never shipped.
--
-- A stone platform in the air above the Accord human start (so terrain plays
-- no part), forceloaded; every mob on it is frozen (no AI step) at a yaw the
-- probe sets.
--   SWEEP  a held cast on a mob turning through all yaws (0-345 deg, 15 deg
--          steps, one yaw per server step): a Braindead-style zombie and a
--          crocodile. Per yaw a fake player aims from four sides at points
--          inside the box the client draws (the zombie's axis at three
--          heights; the crocodile's axis and a point along its body, so its
--          side), through the engine's raycast alone (the bug), the combat
--          ray and the Fireball's aimed_target (the held cast's aim).
--   COST   a busy fight: 20 zombies at random yaws in a 6 x 6 cluster and
--          6 fake players at 2.5 m each aiming at its own zombie; per ray the
--          median and best microseconds of the bare engine raycast, the
--          combat ray at 4 m (melee hold) and 20 m, and the Fireball's
--          aimed_target; hits counted.
-- Every line carries "[r35t]"; the probe ends the server when done. The same
-- probe runs before and after the change (it only calls grug_core.combat_ray
-- and grug_abilities.aimed_target, which exist on both). With
-- grug_core.aim_raycast present, COST also times the same calls with it
-- swapped for the plain engine raycast (the code path before the change),
-- round by round alternating with the real one, so both see the same load.
local P = "[r35t] "
local function log(s) core.log("action", P .. s) end
local now_us = core.get_us_time

-- ------------------------------------------------------------ fake players
local fakes, fake_list = {}, {}
local orig_gcp = core.get_connected_players
local orig_gpbn = core.get_player_by_name
local include_fakes = false
core.get_connected_players = function()
	local real = orig_gcp()
	if not include_fakes or #fake_list == 0 then return real end
	local out = {}
	for i = 1, #real do out[i] = real[i] end
	for i = 1, #fake_list do out[#out + 1] = fake_list[i] end
	return out
end
core.get_player_by_name = function(name) return fakes[name] or orig_gpbn(name) end
local orig_gpwi = core.get_player_window_information
core.get_player_window_information = function(name)
	if fakes[name] then
		return {size = {x = 1920, y = 1080}, max_formspec_size = {x = 20, y = 11.25},
			real_gui_scaling = 1, real_hud_scaling = 1}
	end
	return orig_gpwi(name)
end

local orig_gpi = core.get_player_information
core.get_player_information = function(name)
	if fakes[name] then
		return {address = "127.0.0.1", ip_version = 4, connection_uptime = 100,
			protocol_version = 48, formspec_version = 8, lang_code = "",
			min_rtt = 0.01, max_rtt = 0.05, avg_rtt = 0.02, min_jitter = 0,
			max_jitter = 0, avg_jitter = 0, version_string = "5.15.0"}
	end
	return orig_gpi(name)
end
-- A nametag carrier cannot attach to a table: fake players get none.
local fake_refs = {}
local orig_ctc = grug_core.create_tag_carrier
grug_core.create_tag_carrier = function(parent, owner)
	if fake_refs[parent] then return nil end
	return orig_ctc(parent, owner)
end

local function new_meta()
	local store = {}
	local m = {}
	function m:get_string(k) return store[k] or "" end
	function m:set_string(k, v)
		v = tostring(v or "")
		store[k] = v ~= "" and v or nil
	end
	function m:get(k) return store[k] end
	function m:get_int(k) return math.floor(tonumber(store[k]) or 0) end
	function m:set_int(k, v) store[k] = tostring(math.floor(v)) end
	function m:get_float(k) return tonumber(store[k]) or 0 end
	function m:set_float(k, v) store[k] = tostring(v) end
	function m:contains(k) return store[k] ~= nil end
	function m:get_keys() local r = {} for k in pairs(store) do r[#r + 1] = k end return r end
	function m:to_table() return {fields = table.copy(store)} end
	function m:from_table() return true end
	function m:equals(o) return o == m end
	function m:mark_as_private() end
	return m
end

-- A table answering the ObjectRef methods the game calls on players
-- (the Round 31 PvP probe stand-in).
local function make_fake(name, pos, faction)
	local inv = core.create_detached_inventory("r35t_" .. name, {}, name)
	for list, size in pairs({main = 32, craft = 9, craftpreview = 1,
			craftresult = 1, hand = 1}) do
		inv:set_size(list, size)
	end
	inv:set_width("craft", 3)
	local p = {_name = name, _pos = vector.copy(pos), _yaw = 0, _pitch = 0,
		_hp = 20, _breath = 10, _inv = inv, _meta = new_meta(), _huds = {},
		_next_hud = 0, _wield = 1, _formspec = "", _prepend = "",
		_armor = {fleshy = 100}, _physics = {speed = 1, jump = 1, gravity = 1},
		_props = {hp_max = 20, breath_max = 10, eye_height = 1.625,
			collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
			selectionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
			visual = "mesh", mesh = "character.b3d", textures = {"character.png"},
			visual_size = {x = 1, y = 1}, stepheight = 0.6, nametag = ""},
		_flags = {breathing = true, drowning = true, node_damage = true},
		_hudflags = {hotbar = true, healthbar = true, crosshair = true,
			wielditem = true, breathbar = true, minimap = false,
			minimap_radar = false, basic_debug = false, chat = true},
		_nametag = {color = {a = 255, r = 255, g = 255, b = 255}, text = ""},
		_lighting = {}, _sky = {}, _anim = {range = {x = 0, y = 0}, speed = 0, blend = 0, loop = true},
		_eye1 = vector.zero(), _eye3 = vector.zero()}
	p._meta:set_string("grug_factions:faction", faction)
	p._meta:set_string("grug_classes:race", faction == "accord" and "human" or "orc")
	p._meta:set_string("grug_classes:class", "warrior")
	local M = {}
	function M:is_player() return true end
	function M:is_valid() return true end
	function M:get_player_name() return self._name end
	function M:get_pos() return vector.copy(self._pos) end
	function M:set_pos(v) self._pos = vector.copy(v) end
	function M:move_to(v) self._pos = vector.copy(v) end
	function M:get_velocity() return vector.zero() end
	function M:get_look_horizontal() return self._yaw end
	function M:get_look_vertical() return self._pitch end
	function M:get_yaw() return self._yaw end
	function M:get_look_dir()
		local c = math.cos(self._pitch)
		return vector.new(-math.sin(self._yaw) * c, -math.sin(self._pitch), math.cos(self._yaw) * c)
	end
	function M:get_hp() return self._hp end
	function M:set_hp(hp) self._hp = math.max(0, math.min(self._props.hp_max or 20, math.floor(hp))) end
	function M:get_breath() return self._breath end
	function M:get_properties() return table.copy(self._props) end
	function M:set_properties(t) for k, v in pairs(t or {}) do self._props[k] = v end end
	function M:get_meta() return self._meta end
	function M:get_inventory() return self._inv end
	function M:get_wield_index() return self._wield end
	function M:get_wield_list() return "main" end
	function M:get_wielded_item() return self._inv:get_stack("main", self._wield) end
	function M:set_wielded_item(s) self._inv:set_stack("main", self._wield, s) return true end
	function M:get_player_control()
		return {up = false, down = false, left = false, right = false, jump = false,
			aux1 = false, sneak = false, dig = false, place = false, LMB = false,
			RMB = false, zoom = false, movement_x = 0, movement_y = 0}
	end
	function M:get_player_control_bits() return 0 end
	function M:get_armor_groups() return table.copy(self._armor) end
	function M:set_armor_groups(t) self._armor = table.copy(t) end
	function M:get_physics_override() return table.copy(self._physics) end
	function M:set_physics_override(t) for k, v in pairs(t or {}) do self._physics[k] = v end end
	function M:get_attach() return nil end
	function M:get_children() return {} end
	function M:get_luaentity() return nil end
	function M:get_eye_offset() return vector.copy(self._eye1), vector.copy(self._eye3), vector.copy(self._eye3) end
	function M:get_flags() return table.copy(self._flags) end
	function M:hud_get_flags() return table.copy(self._hudflags) end
	function M:get_sky() return self._sky end
	function M:get_lighting() return self._lighting end
	function M:get_nametag_attributes() return table.copy(self._nametag) end
	function M:set_nametag_attributes(t) for k, v in pairs(t or {}) do self._nametag[k] = v end end
	function M:get_animation() local a = self._anim return a.range, a.speed, a.blend, a.loop end
	function M:get_formspec_prepend() return self._prepend end
	function M:get_inventory_formspec() return self._formspec end
	function M:set_inventory_formspec(fs) self._formspec = fs end
	function M:get_camera() return {mode = "any"} end
	function M:hud_add(def)
		self._next_hud = self._next_hud + 1
		self._huds[self._next_hud] = table.copy(def or {})
		return self._next_hud
	end
	function M:hud_change(id, stat, value)
		if self._huds[id] then self._huds[id][stat] = value end
	end
	function M:hud_remove(id) self._huds[id] = nil end
	function M:hud_get(id) return self._huds[id] and table.copy(self._huds[id]) end
	setmetatable(p, {__index = function(_, key)
		local fn = M[key]
		if fn then return fn end
		if type(key) == "string" and (key:match("^get_") or key:match("^set_") or
				key:match("^hud_") or key:match("^is_") or key:match("^add_") or
				key:match("^send_") or key:match("^override_") or
				key == "punch" or key == "respawn" or key == "remove") then
			return function() return nil end
		end
		return nil
	end})
	fake_refs[p] = true
	return p
end

local function join_fake(p, only_mod)
	pcall(function()
		local h = core.get_auth_handler()
		if not h.get_auth(p._name) then h.create_auth(p._name, "") end
	end)
	fakes[p._name] = p
	fake_list[#fake_list + 1] = p
	for _, cb in ipairs(core.registered_on_joinplayers) do
		local origin = core.callback_origins[cb]
		if not only_mod or (origin and origin.mod == only_mod) then
			local ok, err = pcall(cb, p, nil)
			if not ok then log("JOINERR " .. tostring(origin and origin.mod) .. " " .. tostring(err):sub(1, 200)) end
		end
	end
end


-- ---------------------------------------------------------------- helpers
local ROUNDS = 15
local real_aim, plain_aim
-- `ROUNDS` rounds of `n` calls of `fn` (which may do several rays and returns
-- how many); median and best microseconds per ray. With the workaround
-- present each round is followed by one with the plain engine ray in its
-- place ("engine only").
local function bench(label, n, fn)
	local per, plain = {}, {}
	local function round(into)
		local t, rays = now_us(), 0
		for _ = 1, n do rays = rays + fn() end
		into[#into + 1] = (now_us() - t) / rays
	end
	for _ = 1, ROUNDS do
		round(per)
		if real_aim then
			grug_core.aim_raycast = plain_aim
			round(plain)
			grug_core.aim_raycast = real_aim
		end
	end
	for _, list in ipairs({per, plain}) do
		if #list > 0 then
			table.sort(list)
			log(("COST %-58s median %8.3f us  best %8.3f us  (n=%d x %d)"):format(
				label .. (list == plain and " [engine only]" or ""),
				list[math.ceil(ROUNDS / 2)], list[1], n, ROUNDS))
		end
	end
end

-- Put a fake player's eye at `eye`, looking at `at`.
local function aim_fake(f, eye, at)
	local d = vector.direction(eye, at)
	f._pos = vector.offset(eye, 0, -(f._props.eye_height or 1.625), 0)
	f._yaw = math.atan2(-d.x, d.z)
	f._pitch = -math.asin(d.y)
end

local function freeze(obj, yaw)
	local ent = obj and obj:get_luaentity()
	if not ent then return nil end
	ent.on_step = function() end
	ent.health = 1e9
	obj:set_velocity({x = 0, y = 0, z = 0})
	obj:set_acceleration({x = 0, y = 0, z = 0})
	obj:set_yaw(yaw or 0)
	return ent
end

local function engine_hit(eye, at, obj)
	local to = vector.add(eye, vector.multiply(vector.direction(eye, at), 20))
	for pointed in core.raycast(eye, to, true, false) do
		if pointed.type == "object" and pointed.ref == obj then return true end
	end
	return false
end

-- --------------------------------------------------------------- SWEEP
-- Points inside the client box, relative to the mob (local x, y, z, before
-- the mob's yaw turns them): the zombie's axis at three heights; the
-- crocodile's axis and 1.5 nodes back along its body.
local SWEEP = {
	{mob = "grug_mobs:zombie", points = {{0, 0.3, 0}, {0, 0.9, 0}, {0, 1.5, 0}}},
	{mob = "grug_mobs:crocodile", points = {{0, 0.3, 0}, {0, 0.3, -1.5}}},
}
local SIDES = {{0, -3}, {3, 0}, {0, 3}, {-3, 0}}
local fireball
local sweep = {}

local function local_to_world(base, yaw, p)
	local c, s = math.cos(yaw), math.sin(yaw)
	-- The client turns a mob's model (and its rotated box) by its yaw: local
	-- +z becomes (-sin yaw, 0, cos yaw).
	return {x = base.x + p[1] * c - p[3] * s, y = base.y + p[2],
		z = base.z + p[1] * s + p[3] * c}
end

local function sweep_start(arena, f)
	for i, row in ipairs(SWEEP) do
		local base = vector.offset(arena, -8 + 8 * (i - 1), 0, -8)
		local obj = core.add_entity(base, row.mob)
		local ent = freeze(obj, 0)
		sweep[i] = {row = row, obj = obj, base = obj and obj:get_pos() or base,
			ok = ent ~= nil, deg = 0, misses = {engine = 0, ray = 0, cast = 0},
			n = 0, lines = {}}
		log(("SWEEP %s spawned=%s"):format(row.mob, tostring(ent ~= nil)))
	end
	return f
end

-- One yaw of every sweep mob; true when all are done.
local function sweep_step(f)
	local done = true
	for _, s in ipairs(sweep) do
		if s.ok and s.deg <= 345 then
			done = false
			local yaw = math.rad(s.deg)
			s.obj:set_yaw(yaw)
			local base = s.obj:get_pos()
			local marks = {}
			for _, side in ipairs(SIDES) do
				for _, p in ipairs(s.row.points) do
					local at = local_to_world(base, yaw, p)
					local eye = {x = at.x + side[1], y = at.y + 0.4, z = at.z + side[2]}
					aim_fake(f, eye, at)
					local e = engine_hit(eye, at, s.obj)
					local r = grug_core.combat_ray(f, 20)
					local ray_ok = r.status == "target" and r.target == s.obj
					local target = grug_abilities.aimed_target(f, fireball)
					local cast_ok = target == s.obj
					s.n = s.n + 1
					if not e then s.misses.engine = s.misses.engine + 1 end
					if not ray_ok then s.misses.ray = s.misses.ray + 1 end
					if not cast_ok then s.misses.cast = s.misses.cast + 1 end
					marks[#marks + 1] = (e and "e" or "-") .. (ray_ok and "r" or "-") ..
						(cast_ok and "c" or "-")
				end
			end
			log(("SWEEP %s yaw %3d %s"):format(s.row.mob, s.deg, table.concat(marks, " ")))
			s.deg = s.deg + 15
		end
	end
	return done
end

local function sweep_report()
	for _, s in ipairs(sweep) do
		log(("RESULT SWEEP %s rays=%d engine_misses=%d combat_ray_misses=%d cast_misses=%d"):format(
			s.row.mob, s.n, s.misses.engine, s.misses.ray, s.misses.cast))
		if s.obj then s.obj:remove() end
	end
end

-- ---------------------------------------------------------------- COST
local NMOBS, NPLAYERS = 20, 6
local fight = {}

local function cost_spawn(arena)
	local rng = PcgRandom(35)
	local centre = vector.offset(arena, 0, 0, 6)
	for i = 1, NMOBS do
		local pos = vector.offset(centre, rng:next(-30, 30) / 10, 0, rng:next(-30, 30) / 10)
		local obj = core.add_entity(pos, "grug_mobs:zombie")
		if freeze(obj, math.rad(rng:next(0, 359))) then fight[#fight + 1] = obj end
	end
	log(("COST zombies %d of %d"):format(#fight, NMOBS))
	return centre
end

local function run_cost(centre, fakes_list)
	-- Each fake player stands 2.5 m from its own zombie, outside the
	-- cluster's middle, and aims at the zombie's chest.
	local aims = {}
	for i, f in ipairs(fakes_list) do
		local obj = fight[i]
		local m = obj:get_pos()
		local away = vector.direction(centre, m)
		if vector.length(away) < 0.01 then away = {x = 1, y = 0, z = 0} end
		away.y = 0
		away = vector.normalize(away)
		local at = vector.offset(m, 0, 1.2, 0)
		local eye = vector.add(at, vector.multiply(away, 2.5))
		aims[i] = {f = f, eye = eye, at = at, obj = obj,
			dir = vector.direction(eye, at)}
		aim_fake(f, eye, at)
	end
	real_aim = grug_core.aim_raycast
	plain_aim = real_aim and function(o, d, liquids, pointabilities)
		return core.raycast(o, d, true, liquids == true, pointabilities)
	end
	local hits = {engine = 0, ray4 = 0, ray20 = 0, cast = 0}
	-- Hits are counted in the real rounds only.
	local function count(key, ok)
		if ok and grug_core.aim_raycast == real_aim then hits[key] = hits[key] + 1 end
	end
	bench("engine raycast alone (20 m), per ray", 200, function()
		for _, a in ipairs(aims) do
			count("engine", engine_hit(a.eye, a.at, a.obj))
		end
		return #aims
	end)
	bench("combat_ray 4 m (melee hold), per ray", 200, function()
		for _, a in ipairs(aims) do
			local r = grug_core.combat_ray(a.f, 4)
			count("ray4", r.target == a.obj)
		end
		return #aims
	end)
	bench("combat_ray 20 m, per ray", 200, function()
		for _, a in ipairs(aims) do
			local r = grug_core.combat_ray(a.f, 20)
			count("ray20", r.target == a.obj)
		end
		return #aims
	end)
	bench("aimed_target(fireball) 20 m, per ray", 200, function()
		for _, a in ipairs(aims) do
			count("cast", grug_abilities.aimed_target(a.f, fireball) == a.obj)
		end
		return #aims
	end)
	-- Part of the workaround's cost: the candidate query of a 20 m ray (its
	-- box widened by 5 nodes, as the engine's) and one luaentity per object.
	local listed = 0
	bench("candidate query + get_luaentity (20 m ray box), per ray", 200, function()
		for _, a in ipairs(aims) do
			local to = vector.add(a.eye, vector.multiply(a.dir, 20))
			local minp = vector.subtract(vector.new(math.min(a.eye.x, to.x),
				math.min(a.eye.y, to.y), math.min(a.eye.z, to.z)), 5)
			local maxp = vector.add(vector.new(math.max(a.eye.x, to.x),
				math.max(a.eye.y, to.y), math.max(a.eye.z, to.z)), 5)
			local list = core.get_objects_in_area(minp, maxp)
			for _, obj in ipairs(list) do obj:get_luaentity() end
			listed = listed + #list
		end
		return #aims
	end)
	log(("COST objects per 20 m ray box: %.1f"):format(listed / (200 * ROUNDS * #aims *
		(real_aim and 2 or 1))))
	-- The engine calls a near candidate and a hit add, on one zombie.
	local z = fight[1]
	bench("zombie get_properties()", 2000, function() z:get_properties() return 1 end)
	bench("zombie get_pos() + get_rotation()", 2000, function()
		z:get_pos()
		z:get_rotation()
		return 1
	end)
	-- The aiming ray alone, fully iterated (no classification): the
	-- workaround's own overhead; and how many objects one 20 m ray yields
	-- (every rotated one read its properties once).
	local yielded = {real = 0, plain = 0}
	bench("aim ray alone, fully iterated (20 m), per ray", 200, function()
		local key = grug_core.aim_raycast == real_aim and "real" or "plain"
		for _, a in ipairs(aims) do
			local to = vector.add(a.eye, vector.multiply(a.dir, 20))
			for pointed in grug_core.aim_raycast(a.eye, to, false) do
				if pointed.type == "object" then yielded[key] = yielded[key] + 1 end
			end
		end
		return #aims
	end)
	local rays = 200 * ROUNDS * #aims
	log(("COST objects on one 20 m ray: %.2f with the workaround, %.2f engine only"):format(
		yielded.real / rays, real_aim and yielded.plain / rays or 0))
	local total = 200 * ROUNDS * #aims
	log(("RESULT COST hits of %d: engine=%d ray4=%d ray20=%d cast=%d"):format(
		total, hits.engine, hits.ray4, hits.ray20, hits.cast))
end

-- ---------------------------------------------------------------- driver
local phase, phase_t, total_t = "wait", 0, 0
local arena, sweeper, centre
local emerge_done = false
local function set_phase(p) phase, phase_t = p, 0; log("phase -> " .. p) end

local function build_platform()
	for x = arena.x - 16, arena.x + 16 do
		for z = arena.z - 16, arena.z + 16 do
			core.set_node({x = x, y = arena.y - 1, z = z}, {name = "default:stone"})
		end
	end
end

core.register_globalstep(function(dtime)
	total_t = total_t + dtime
	phase_t = phase_t + dtime
	if phase == "wait" then
		if total_t > 3 and grug_core.zone_authority_installed() then
			local start = grug_core.start_position("accord", "human")
			arena = vector.round({x = start.x, y = start.y + 60, z = start.z})
			log("arena " .. core.pos_to_string(arena) .. " aim_raycast=" ..
				tostring(grug_core.aim_raycast ~= nil))
			core.emerge_area(vector.subtract(arena, {x = 24, y = 8, z = 24}),
				vector.add(arena, {x = 24, y = 8, z = 24}), function(_, _, remaining)
					if remaining == 0 then emerge_done = true end
				end)
			-- Without a real player no block is active: keep the arena's.
			for dx = -16, 16, 16 do
				for dz = -16, 16, 16 do
					for dy = -16, 0, 16 do
						core.forceload_block({x = arena.x + dx, y = arena.y + dy,
							z = arena.z + dz}, true)
					end
				end
			end
			set_phase("emerge")
		end
	elseif phase == "emerge" then
		if emerge_done or phase_t > 90 then
			log("emerge done=" .. tostring(emerge_done) .. (" after %.1f s"):format(phase_t))
			build_platform()
			fireball = grug_abilities.registered.fireball
			include_fakes = true
			local list = {}
			for i = 1, NPLAYERS do
				local f = make_fake("r35t" .. i, arena, "accord")
				join_fake(f)
				list[i] = f
			end
			sweeper = list[1]
			sweep_start(arena, sweeper)
			centre = cost_spawn(arena)
			fight.players = list
			set_phase("settle")
		end
	elseif phase == "settle" then
		if phase_t > 2 then set_phase("sweep") end
	elseif phase == "sweep" then
		if sweep_step(sweeper) then
			sweep_report()
			set_phase("cost")
		end
	elseif phase == "cost" then
		if #fight >= NPLAYERS then
			run_cost(centre, fight.players)
		else
			log("COST too few zombies")
		end
		set_phase("done")
	elseif phase == "done" then
		if phase_t > 1 then
			log("RESULT DONE")
			set_phase("off")
			core.request_shutdown("r35t probe done", false, 0)
		end
	end
end)
