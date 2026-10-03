-- Disposable Round 31 P1 probe (tools/r31_pvp/run.sh). Never shipped.
--
--   ZONE  (needs grug_pvp) pvp-plan §7: the location flag grug_pvp's rules give
--         for an Accord and a Throng player on a 64-node grid of the whole
--         map, by water class (land, planned water, shelf, deep ocean, dragon
--         channel) and zone rule, at every registered settlement anchor (POI,
--         camp, village, town and capital boxes) and below y -701 under the
--         six capitals; every answer is compared with the expectation of
--         rulings 2/3 and the zone record.
--   MICRO the PvE combat paths before/after: valid_target on a live mob, the
--         crosshair combat ray onto it, the full hp-change chain of a mob
--         punch on a player, the combat timer; plus the same for an enemy
--         player pair (PvP, for comparison). Two fake player stand-ins join
--         through the real join chain.
--   TICK  (needs grug_pvp) the location tick with 0, 50 and 100 fake players
--         on random land columns, against grug_map's location sample.
-- Every line carries "[r31pvp]"; the probe ends the server when done.
local P = "[r31pvp] "
local function log(s) core.log("action", P .. s) end
local now_us = core.get_us_time
local has_pvp = core.global_exists("grug_pvp")

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
-- (the r29/r30 perf probe B stand-in, without its traffic accounting).
local function make_fake(name, pos, faction)
	local inv = core.create_detached_inventory("r31pvp_" .. name, {}, name)
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

-- ---------------------------------------------------------------- benches
-- `rounds` rounds of `n` calls; median and best microseconds per call.
-- `setup` (untimed) runs before every round.
local ROUNDS = 15
local function bench(label, n, fn, setup)
	local rounds = ROUNDS
	local per = {}
	for r = 1, rounds do
		if setup then setup() end
		local t = now_us()
		for _ = 1, n do fn() end
		per[r] = (now_us() - t) / n
	end
	table.sort(per)
	log(("MICRO %-52s median %8.3f us  best %8.3f us  (n=%d x %d)"):format(
		label, per[math.ceil(rounds / 2)], per[1], n, rounds))
end

-- ---------------------------------------------------------------- ZONE
local function expected_loc(previous, rule, here, own)
	if rule == nil then return previous end
	if rule == "contested" then return "contested" end
	if here ~= own then return "enemy" end
	return false
end

local zone_failures = 0
local function zone_check(label, pos, rows)
	local rule = grug_zones.pvp_rule_at(pos)
	local here = rule == "peaceful" and grug_zones.faction_at(pos) or nil
	for _, own in ipairs({"accord", "throng"}) do
		for _, previous in ipairs({false, "contested"}) do
			local got = grug_pvp.rules.location(previous, rule, here, own)
			if got ~= expected_loc(previous, rule, here, own) then
				zone_failures = zone_failures + 1
				if zone_failures <= 10 then
					log(("ZONEFAIL %s %s own=%s prev=%s got=%s"):format(label,
						core.pos_to_string(pos), own, tostring(previous), tostring(got)))
				end
			end
		end
	end
	local key = label .. " rule=" .. tostring(rule) .. " faction=" ..
		tostring(rule == "peaceful" and here or "-") ..
		" -> accord:" .. tostring(grug_pvp.rules.location(false, rule, here, "accord")) ..
		" throng:" .. tostring(grug_pvp.rules.location(false, rule, here, "throng"))
	rows[key] = (rows[key] or 0) + 1
	return rule
end

local function dump_rows(title, rows)
	local keys = {}
	for k in pairs(rows) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do log(("ZONE %s %-90s n=%d"):format(title, k, rows[k])) end
end

local function run_zone_checks()
	local t0 = now_us()
	local rows, record_mismatch = {}, 0
	for x = -3600, 3600, 64 do
		for z = -3200, 3200, 64 do
			local class = grug_zones.water_class_at(x, z)
			local id = grug_zones.id_at(x, z)
			local pos = {x = x, y = 10, z = z}
			local rule = zone_check(class, pos, rows)
			if id then
				local record = grug_zones.get(id)
				local here = grug_zones.faction_at(pos)
				if record.pvp_rule ~= rule or record.faction ~= here then
					record_mismatch = record_mismatch + 1
				end
			end
		end
	end
	dump_rows("grid", rows)
	log("ZONE grid record mismatches (rule/faction vs the zone record): " .. record_mismatch)
	-- Settlement anchors: POI, camp, village, start town and capital boxes.
	rows = {}
	for _, row in ipairs(grug_core.settlement_socket_settlements()) do
		local kind = (row.key or "?"):match("^([^:_]+)") or "?"
		local pos = {x = row.anchor.x, y = row.anchor.y + 1, z = row.anchor.z}
		local territory = grug_zones.territory_rule_at(pos)
		local feature = grug_core.world_feature_at(pos) or "-"
		zone_check(kind .. " territory=" .. territory .. " feature=" .. feature, pos, rows)
	end
	dump_rows("settlement", rows)
	-- Deep under the six capitals.
	rows = {}
	for _, id in ipairs(grug_core.start_identities()) do
		local a = grug_core.capital_anchor(id.faction_id, id.race_id)
		if a then
			for _, y in ipairs({-700, -701, -1200}) do
				zone_check("capital " .. id.race_id .. " y=" .. y,
					{x = a.x, y = y, z = a.z}, rows)
			end
		end
	end
	dump_rows("deep", rows)
	log(("ZONE failures=%d (%.1f ms)"):format(zone_failures, (now_us() - t0) / 1000))
end

-- ---------------------------------------------------------------- MICRO
local mob_obj, fa, ft
local candidates = {}
local CANDIDATES = {"grug_mobs:wolf", "grug_mobs:boar", "grug_mobs:stag",
	"grug_mobs:bear", "grug_mobs:guard_throng"}

local function ground_above(x, z, y0)
	for y = y0 + 12, y0 - 20, -1 do
		local node = core.get_node({x = x, y = y, z = z})
		local above = core.get_node({x = x, y = y + 1, z = z})
		local def = core.registered_nodes[node.name]
		local adef = core.registered_nodes[above.name]
		if def and def.walkable and adef and not adef.walkable then
			return {x = x, y = y + 1, z = z}
		end
	end
	return nil
end

local function spawn_candidates(center)
	for i, name in ipairs(CANDIDATES) do
		local pos = ground_above(center.x + 6 * i, center.z + 8, center.y)
		local obj = pos and core.add_entity(vector.offset(pos, 0, 0.5, 0), name)
		candidates[i] = {name = name, obj = obj, pos = pos}
	end
end

local function pick_mob()
	for _, c in ipairs(candidates) do
		local alive = c.obj and c.obj:get_pos() ~= nil
		local valid = alive and grug_abilities.valid_target(fa, c.obj, "hostile")
		log(("MICRO candidate %s at %s alive=%s valid=%s"):format(c.name,
			c.pos and core.pos_to_string(c.pos) or "-", tostring(alive), tostring(valid)))
		if valid and not mob_obj then mob_obj = c.obj end
	end
end

local function run_micro(center)
	pick_mob()
	if not mob_obj or not mob_obj:get_pos() then
		log("MICRO no mob")
		return
	end
	local ent = mob_obj:get_luaentity()
	ent.health = 1e9 -- never dies in the benches
	log("MICRO mob " .. ent.name .. " at " .. core.pos_to_string(vector.round(mob_obj:get_pos())))
	include_fakes = true
	bench("valid_target(player, mob, hostile)", 20000, function()
		grug_abilities.valid_target(fa, mob_obj, "hostile")
	end)
	-- The mob walks: before every round, an origin 2 m beside or above it
	-- whose ray reaches it (the first of five), then the round's rays.
	local hits, aim = 0, nil
	local OFFSETS = {{-2, 0.4, 0}, {2, 0.4, 0}, {0, 0.4, -2}, {0, 0.4, 2}, {0, 2.5, 0}}
	local function find_aim()
		aim = nil
		local m = mob_obj:get_pos()
		local centre = {x = m.x, y = m.y + 0.4, z = m.z}
		local reasons = {}
		for _, o in ipairs(OFFSETS) do
			local origin = {x = m.x + o[1], y = m.y + o[2], z = m.z + o[3]}
			local opts = {origin = origin,
				direction = vector.normalize(vector.subtract(centre, origin))}
			local r = grug_core.combat_ray(fa, 10, opts)
			if r.status == "target" then aim = opts return end
			reasons[#reasons + 1] = r.reason
		end
		log("MICRO no aim at the mob: " .. table.concat(reasons, ","))
	end
	local fallback = {origin = {x = 0, y = 0, z = 0}, direction = {x = 1, y = 0, z = 0}}
	bench("combat_ray onto the mob (10 m)", 2000, function()
		local r = grug_core.combat_ray(fa, 10, aim or fallback)
		if r.status == "target" then hits = hits + 1 end
	end, find_aim)
	log(("MICRO ray hits on the mob: %d of %d"):format(hits, 2000 * ROUNDS))
	local hpc = core.registered_on_player_hpchange
	bench("hp-change chain: mob punch 3 on a player", 2000, function()
		hpc(fa, -3, {type = "punch", object = mob_obj, from = "mod"})
		fa._hp = 20
	end)
	bench("mark_in_combat + in_combat", 20000, function()
		grug_core.mark_in_combat(fa)
		grug_core.in_combat(fa)
	end)
	bench("in_combat", 20000, function() grug_core.in_combat(fa) end)
	-- PvP (comparison): an enemy pair, flagged in the after run.
	if has_pvp then
		grug_pvp.flag_now(fa)
		grug_pvp.flag_now(ft)
	end
	bench("valid_target(player, enemy player, hostile)", 20000, function()
		grug_abilities.valid_target(fa, ft, "hostile")
	end)
	bench("hp-change chain: enemy player punch 3", 2000, function()
		hpc(fa, -3, {type = "punch", object = ft, from = "mod"})
		fa._hp = 20
	end)
	include_fakes = false
end

-- ---------------------------------------------------------------- TICK
local function random_land(rng)
	for _ = 1, 200 do
		local x, z = rng:next(-3500, 3500), rng:next(-3100, 3100)
		if grug_zones.water_class_at(x, z) == "land" then
			return {x = x, y = grug_zones.terrain_height_at(x, z) + 1, z = z}
		end
	end
	return {x = 0, y = 10, z = 0}
end

local function run_tick()
	local rng = PcgRandom(31)
	local tick_fakes = {}
	local saved_list = fake_list
	fake_list = tick_fakes -- join_fake appends here
	for _, count in ipairs({0, 50, 100}) do
		while #tick_fakes < count do
			local i = #tick_fakes + 1
			join_fake(make_fake(("r31tick%03d"):format(i), random_land(rng),
				i % 2 == 0 and "accord" or "throng"), "grug_pvp")
		end
		include_fakes = true
		local stats = grug_pvp.tick_stats
		stats.samples, stats.us = 0, 0
		local t = now_us()
		local runs = 20
		for _ = 1, runs do grug_pvp.location_tick() end
		local total = (now_us() - t) / runs
		include_fakes = false
		log(("TICK %3d fake players: %8.1f us per tick, %6.2f us per player, sample %6.2f us (samples %d)"):format(
			count, total, count > 0 and total / count or 0,
			stats.samples > 0 and stats.us / stats.samples or 0, stats.samples))
		if count > 0 then
			local t2 = now_us()
			for _ = 1, runs do
				for i = 1, count do grug_map.location.text_at(tick_fakes[i]._pos) end
			end
			log(("TICK %3d fake players: grug_map location text_at %6.2f us per player (comparison)"):format(
				count, (now_us() - t2) / runs / count))
		end
	end
	local flagged = 0
	for _, p in ipairs(tick_fakes) do
		if grug_pvp.flagged(p) then flagged = flagged + 1 end
	end
	log(("TICK flagged after the samples: %d of %d"):format(flagged, #tick_fakes))
	fake_list = saved_list
end

-- ---------------------------------------------------------------- driver
local phase, phase_t, total_t, center = "wait", 0, 0, nil
local emerge_done = false
local function set_phase(p) phase, phase_t = p, 0; log("phase -> " .. p) end

core.register_globalstep(function(dtime)
	total_t = total_t + dtime
	phase_t = phase_t + dtime
	if phase == "wait" then
		if total_t > 3 and grug_core.zone_authority_installed() then
			center = grug_core.start_position("accord", "human")
			log("center " .. core.pos_to_string(center) .. " grug_pvp=" .. tostring(has_pvp))
			core.emerge_area(vector.subtract(center, {x = 24, y = 16, z = 24}),
				vector.add(center, {x = 24, y = 16, z = 24}), function(_, _, remaining)
					if remaining == 0 then emerge_done = true end
				end)
			-- Without a real player no block is active: keep the bench mobs'.
			for dx = 0, 3 do
				for dz = 0, 1 do
					core.forceload_block({x = center.x + dx * 16, y = center.y,
						z = center.z + dz * 16}, true)
				end
			end
			set_phase("emerge")
		end
	elseif phase == "emerge" then
		if emerge_done or phase_t > 90 then
			log("emerge done=" .. tostring(emerge_done) .. (" after %.1f s"):format(phase_t))
			if has_pvp then run_zone_checks() end
			fa = make_fake("r31a", center, "accord")
			ft = make_fake("r31t", vector.offset(center, 2, 0, 0), "throng")
			join_fake(fa)
			join_fake(ft)
			spawn_candidates(center)
			set_phase("settle")
		end
	elseif phase == "settle" then
		if phase_t > 3 then
			run_micro(center)
			if has_pvp then run_tick() end
			set_phase("done")
		end
	elseif phase == "done" then
		if phase_t > 1 then
			log("RESULT DONE")
			set_phase("off")
			core.request_shutdown("r31pvp probe done", false, 0)
		end
	end
end)
