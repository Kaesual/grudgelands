-- Disposable engine probe (Round 28 Lane A5). Never shipped:
-- tools/r28_a5_player/run.sh stages it through tools/luanti_headless.sh.
--
-- A headless server has no client, so players are table stand-ins that answer
-- the accessors the code under test uses (core.is_player accepts a table with
-- is_player). Everything else is real: the movement aggregator, grug_home's
-- respawn with the real innkeeper registry, emerge and start positions, the
-- registered projectile entities and death messages, the workspace station
-- overrides, core.node_dig and core.is_protected.
--
--   E  every mob projectile carries a readable death-message label; every
--      station node has the content-dropping dig hook;
--   D  real projectile entities: the message names the live shooter, then
--      the projectile's label once the shooter is removed (ruling 17);
--   R  respawn of an unbound and of a capital-bound stand-in: one teleport to
--      the innkeeper arrival, held (gravity 0, no movement) until emerged,
--      then released; never a velocity added (ruling 16);
--   S  a full furnace and a full profession station with another player's
--      saved record dug through core.node_dig in unprotected land: every item
--      reaches the digger; a station in a protected town refuses (ruling 18).

local P = "[r28_a5_probe] "
local failures, checks = 0, 0
local clock = 0
local function log(msg) core.log("action", P .. msg) end
local function check(ok, msg)
	checks = checks + 1
	if ok then
		log("ok   " .. msg)
	else
		failures = failures + 1
		core.log("error", P .. "FAIL " .. msg)
	end
	return ok
end
local function readable(text)
	return type(text) == "string" and text ~= "" and not text:find("^[%w_]+:[%w_]+$")
end

core.register_entity("grug_probe_r28_a5:shooter", {
	initial_properties = {physical = false, pointable = false, static_save = false,
		visual = "sprite", textures = {"blank.png"}, is_visible = false},
	description = "Probe Archer",
})

--
-- Player stand-ins.
--
local fakes = {}
local get_player_by_name = core.get_player_by_name
core.get_player_by_name = function(name)
	return fakes[name] or get_player_by_name(name)
end

local function make_player(name, fields, pos)
	local inv_name = "grug_probe_r28_a5_" .. name
	local inv = core.create_detached_inventory(inv_name, {})
	inv:set_size("main", 32)
	local p = {name = name, pos = vector.copy(pos), hp = 20, log = {}, physics = {},
		fields = fields, inv = inv}
	local meta = {}
	function meta.get_string(_, k) return p.fields[k] or "" end
	function meta.set_string(_, k, v) p.fields[k] = v ~= "" and v or nil end
	function meta.get_int(_, k) return tonumber(p.fields[k]) or 0 end
	function meta.set_int(_, k, v) p.fields[k] = tostring(v) end
	function meta.contains(_, k) return p.fields[k] ~= nil end
	function p:is_player() return true end
	function p:get_player_name() return self.name end
	function p:get_meta() return meta end
	function p:get_pos() return vector.copy(self.pos) end
	function p:set_pos(v)
		self.log[#self.log + 1] = {kind = "set_pos", pos = vector.copy(v), t = clock}
		self.pos = vector.copy(v)
	end
	-- The stale server-side speed of a lethal fall.
	function p:get_velocity() return vector.new(0, -38, 0) end
	function p:add_velocity(v) self.log[#self.log + 1] = {kind = "add_velocity", v = v} end
	function p:get_hp() return self.hp end
	function p:get_physics_override() return table.copy(self.physics) end
	function p:set_physics_override(o)
		for k, v in pairs(o) do self.physics[k] = v end
		self.log[#self.log + 1] = {kind = "physics", gravity = o.gravity, t = clock}
	end
	function p:get_properties() return {hp_max = 20, eye_height = 1.47, breath_max = 10} end
	function p:get_armor_groups() return {fleshy = 100} end
	function p:get_inventory() return self.inv end
	function p:get_wielded_item() return ItemStack("") end
	function p:set_wielded_item() return true end
	function p:get_wield_index() return 1 end
	function p:get_wield_list() return "main" end
	function p:get_look_horizontal() return 0 end
	function p:get_look_dir() return vector.new(0, 0, 1) end
	function p:get_player_control() return {} end
	function p:get_attach() return nil end
	function p:set_detach() end
	fakes[name] = p
	return p
end
local function count(p, kind)
	local n = 0
	for _, entry in ipairs(p.log) do if entry.kind == kind then n = n + 1 end end
	return n
end

--
-- Scenario as a coroutine: wait(pred, timeout) yields until pred() is true.
--
local function wait(pred, timeout, label)
	local until_t = clock + timeout
	while not pred() do
		if clock > until_t then
			check(false, "timed out waiting for " .. label)
			return false
		end
		coroutine.yield()
	end
	return true
end

local function registry()
	local arrows, stations = 0, 0
	for name, def in pairs(core.registered_entities) do
		if def.hit_player and name:find("^grug_mobs:") then
			arrows = arrows + 1
			check(readable(def._grug_projectile_label),
				("E %s carries a readable label (%s)"):format(name, tostring(def._grug_projectile_label)))
		end
	end
	for name, def in pairs(core.registered_nodes) do
		if def._grug_station then
			stations = stations + 1
			check(type(def.preserve_metadata) == "function" and type(def.can_dig) == "function",
				"E station " .. name .. " drops its contents when dug")
		end
	end
	check(arrows >= 8, "E mob projectiles found: " .. arrows)
	check(stations >= 8, "E station nodes found: " .. stations)
end

local function death_messages(base)
	for _, case in ipairs({
		{"grug_mobs:arrow_entity", "an arrow"}, {"grug_mobs:hex_bottle", "a hex bottle"},
		{"grug_mobs:dungeon_fireball", "a fireball"}, {"grug_mobs:ice_breath", "frost breath"},
		{"grug_mobs:storm_breath", "storm breath"}, {"grug_mobs:rock_entity", "a hurled rock"},
		{"grug_mobs:ember_entity", "an ember"}, {"grug_mobs:crystal_shard_entity", "a crystal shard"},
	}) do
		local shooter = core.add_entity(base, "grug_probe_r28_a5:shooter")
		local arrow = core.add_entity(base, case[1])
		local ent = arrow and arrow:get_luaentity()
		if check(shooter and ent, "D " .. case[1] .. " added") then
			ent._grug_source = shooter
			local reason = {type = "punch", object = arrow}
			local _, live = grug_core.death_message("probe", reason)
			check(live:find("Probe Archer", 1, true) ~= nil, "D live shooter named: " .. live)
			check(grug_core.damage_source(arrow) == shooter, "D damage_source is the live shooter")
			shooter:remove()
			local _, gone = grug_core.death_message("probe", reason)
			check(gone:find(case[2], 1, true) ~= nil and not gone:find(":", 1, true),
				"D shooter gone, readable fallback: " .. gone)
			check(grug_core.damage_source(arrow) == nil, "D damage_source of a gone shooter is nil")
			arrow:remove()
		end
	end
end

local function respawn(label, bound)
	local fields = {["grug_factions:faction"] = "accord", ["grug_classes:race"] = "human",
		["grug_home:id"] = bound}
	local p = make_player("probe_" .. label, fields, vector.new(37, 300, -51))
	local home = grug_home.innkeeper(p)
	if not check(home ~= nil, "R " .. label .. " has an innkeeper home") then return end
	if bound then check(home.id == bound, "R " .. label .. " home is the bound " .. bound) end
	local t0 = clock
	check(grug_home.respawn(p) == true, "R " .. label .. " respawn handled")
	check(count(p, "set_pos") == 1 and vector.distance(p.pos, home.arrival) < 1e-6,
		"R " .. label .. " one teleport straight to the innkeeper arrival")
	check(grug_core.is_movement_held(p, "grug_home:respawn") and p.physics.gravity == 0 and
		p.physics.speed_walk == 0, "R " .. label .. " held without gravity or movement")
	wait(function() return not grug_core.is_movement_held(p, "grug_home:respawn") end, 90,
		label .. " release")
	log(("R %s held for %.2f s while the home emerged"):format(label, clock - t0))
	check(p.physics.gravity == 1, "R " .. label .. " gravity handed back")
	check(count(p, "set_pos") == 1, "R " .. label .. " still exactly one teleport")
	check(count(p, "add_velocity") == 0, "R " .. label .. " no velocity added")
	local floor = core.get_node_or_nil({x = home.arrival.x, y = math.floor(home.arrival.y), z = home.arrival.z})
	local def = floor and core.registered_nodes[floor.name]
	check(def and def.walkable, "R " .. label .. " stands on a solid floor (" ..
		tostring(floor and floor.name) .. ")")
	fakes[p.name] = nil
end

local function emerge(pos)
	local done = false
	core.emerge_area(pos, pos, function(_, _, remaining) if remaining == 0 then done = true end end)
	return wait(function() return done end, 60, "emerge at " .. core.pos_to_string(pos))
end

local function station_name(station)
	for name, def in pairs(core.registered_nodes) do
		if def._grug_station == station and not name:find("_active$") then return name end
	end
end

local PREFIX = "grug_jobs:workspace:"
local function stations(start)
	-- The digger is a Human of the Accord: protection resolves its faction by
	-- name, so it exists before the spot search.
	local digger = make_player("probe_dig", {["grug_factions:faction"] = "accord",
		["grug_classes:race"] = "human"}, start)
	local spot
	for _, off in ipairs({{120, 0}, {-120, 0}, {0, 120}, {0, -120}, {250, 250},
			{-250, -250}, {400, 0}, {-400, 0}, {0, 400}, {0, -400}}) do
		local cand = vector.new(start.x + off[1], start.y + 60, start.z + off[2])
		if not core.is_protected(cand, "probe_dig") and
				not core.is_protected(vector.offset(cand, 2, 0, 0), "probe_dig") then
			spot = cand
			break
		end
	end
	if not check(spot ~= nil, "S an unprotected spot") then return end
	log("S spot " .. core.pos_to_string(spot) .. " territory " ..
		tostring(rawget(_G, "grug_zones") and grug_zones.territory_rule_at(spot)))
	if not emerge(spot) then return end
	local forge = station_name("forge")
	check(forge ~= nil, "S a forge station node: " .. tostring(forge))
	digger.pos = vector.offset(spot, 1, 1, 1)
	-- A full furnace.
	core.set_node(spot, {name = "default:furnace"})
	local meta = core.get_meta(spot)
	local inv = meta:get_inventory()
	inv:set_stack("src", 1, "default:iron_lump 4")
	inv:set_stack("fuel", 1, "default:coal_lump 5")
	inv:set_stack("dst", 1, "default:steel_ingot 2")
	meta:set_string(PREFIX .. "someone", core.serialize({lists = {dst = {"default:gold_lump 3"}}}))
	local def = core.registered_nodes["default:furnace"]
	check(def.can_dig(spot, digger), "S a full furnace can be dug")
	local ok, err = pcall(core.node_dig, spot, core.get_node(spot), digger)
	if not ok then log("note: a dig callback failed on the stand-in: " .. tostring(err)) end
	check(core.get_node(spot).name == "air", "S furnace removed")
	local main = digger.inv
	for _, item in ipairs({"default:furnace", "default:iron_lump 4", "default:coal_lump 5",
			"default:steel_ingot 2", "default:gold_lump 3"}) do
		check(main:contains_item("main", item), "S digger received " .. item)
	end
	-- A profession station holding inputs and another player's saved remainder.
	if forge then
		local at = vector.offset(spot, 2, 0, 0)
		core.set_node(at, {name = forge})
		local fmeta = core.get_meta(at)
		fmeta:get_inventory():set_stack("craft", 5, "default:steel_ingot 7")
		fmeta:set_string(PREFIX .. "other", core.serialize({lists = {output = {"default:mese_crystal 1"}}}))
		main:set_list("main", {})
		check(core.registered_nodes[forge].can_dig(at, digger), "S a full forge can be dug")
		ok, err = pcall(core.node_dig, at, core.get_node(at), digger)
		if not ok then log("note: a dig callback failed on the stand-in: " .. tostring(err)) end
		for _, item in ipairs({forge, "default:steel_ingot 7", "default:mese_crystal 1"}) do
			check(main:contains_item("main", item), "S digger received " .. item)
		end
	end
	-- A station inside a protected town refuses the dig.
	check(core.is_protected(start, "probe_dig"), "S the start town is protected")
	core.load_area(start)
	local before = core.get_node(start)
	core.set_node(start, {name = "default:furnace"})
	digger.pos = vector.offset(start, 1, 0, 1)
	check(not def.can_dig(start, digger), "S protection refuses the dig")
	core.set_node(start, before)
	fakes.probe_dig = nil
end

local function scenario()
	log("stage E: registry")
	registry()
	wait(function() return grug_core.world_preparation_status().ready end, 240, "world preparation")
	log(("world preparation ready at t=%.1fs"):format(clock))
	local start = grug_core.start_position("accord", "human")
	if not check(start ~= nil, "human start position") then return end
	core.load_area(vector.offset(start, -8, -4, -8), vector.offset(start, 8, 8, 8))
	log("stage D: death messages")
	death_messages(vector.offset(start, 0, 3, 0))
	log("stage R: respawn")
	respawn("unbound", nil)
	respawn("capital", "highcourt")
	log("stage S: stations")
	stations(start)
end

local co = coroutine.create(scenario)
local finished = false
core.register_globalstep(function(dtime)
	clock = clock + dtime
	if finished then return end
	local ok, err = coroutine.resume(co)
	if not ok then
		check(false, "scenario raised: " .. tostring(err))
	end
	if not ok or coroutine.status(co) == "dead" then
		finished = true
		log(("RESULT %s checks=%d failures=%d t=%.1fs"):format(
			failures == 0 and "PASS" or "FAIL", checks, failures, clock))
		core.after(1, function() core.request_shutdown("r28 a5 probe done") end)
	end
end)
