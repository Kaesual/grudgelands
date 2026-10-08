-- Round 30 Lane P4 portable test (perf review #7, #10, #14, #15, #16, #19;
-- docs/planning/round30-plan.md). Loads the REAL files under small stubs:
--   F  grug_farming/init.lua: soil re-checks every 60 s without a growing
--      crop and every 15 s under one (planting and regrowth re-arm 15 s at
--      once); drying still pauses and rewetting resumes a crop; the crop
--      geometry LBM writes nothing when the plant already stands and still
--      repairs a missing helper.
--   C  retired in Round 45 (the craft lookup index is gone with the grid).
--   T  grug_core/tag_carrier.lua: the carrier pass runs in eight slots of
--      the second, each carrier still once per second with the same 25/30
--      node hysteresis; visibility callbacks run while a carrier is observed
--      or when its observer set changes, never for an unobserved carrier
--      whose set stays empty; removal still reports; the test seam
--      manage_tag_carriers is a full pass.
--   X  grug_abilities/crosshair.lua and grug_mobs/target_frame.lua: the
--      skill ray is repeated from the last result (no ray) while the same
--      skill looks from the same eye along the same direction and the last
--      ray hit no object, for at most 0.25 s; any change or an object hit
--      casts again; recent_aim hands the Target Frame the last aim, which it
--      uses instead of its own ray when that settles the frame (empty, node,
--      beyond 20 m, a framable target, a wall within hand reach) and not
--      otherwise (short skill range, non-framable object, stale aim).
--   M  grug_mounts/entity.lua: flight_state and the flight-boundary sweep
--      (warning_state) give exactly the answers of the former per-sample
--      code (faction read per sample, grug_zones.at per sample) on a field
--      with ocean, home, contested, enemy and dragon-island columns, while
--      the sweep reads the faction once and copies no zone record.
-- Usage (repo root): luajit tools/r30_p4/portable_test.lua [REPO]
local repo = arg[1] or "."
-- Round 44: item sources give through grug_inventory.give (main[9..], the
-- bags, the hotbar last; tools/r44_ih); this fixture keeps a main-only
-- stand-in.
grug_inventory = {give = function(player, stack)
	return player:get_inventory():add_item("main", stack)
end, slot_order = function(inv)
	local slots = {}
	for index = 1, inv:get_size("main") do slots[index] = {list = "main", index = index} end
	return slots
end}

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

local function noop() end
local function key(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end

------------------------------------------------------------------------------
-- F: grug_farming soil timers (#15) and crop geometry LBM (#16).
------------------------------------------------------------------------------
do
	local nodes, metas, timers = {}, {}, {}
	local writes = 0
	local registered_nodes, registered_items, lbms = {}, {}, {}
	local soil_callbacks

	local function new_timer()
		local t = {timeout = 0, elapsed = 0, started = false}
		function t:start(timeout) self.timeout, self.elapsed, self.started = timeout, 0, true end
		function t:set(timeout, elapsed) self.timeout, self.elapsed, self.started = timeout, elapsed, true end
		function t:stop() self.started, self.timeout = false, 0 end
		function t:is_started() return self.started end
		function t:get_elapsed() return self.elapsed end
		function t:get_timeout() return self.started and self.timeout or 0 end
		return t
	end
	local function new_meta()
		local store = {}
		return {
			get_float = function(_, k) return tonumber(store[k]) or 0 end,
			set_float = function(_, k, v) store[k] = v end,
			get_string = function(_, k) return store[k] or "" end,
			set_string = function(_, k, v) store[k] = v end,
		}
	end

	_G.core = {
		registered_nodes = registered_nodes,
		registered_items = registered_items,
		settings = {get_bool = function(_, _, default) return default end},
		get_modpath = function(name) return repo .. "/mods/ITEMS/" .. name end,
		get_current_modname = function() return "grug_farming" end,
		register_craftitem = function(name, def) registered_items[name] = def end,
		register_tool = function(name, def) registered_items[name] = def end,
		register_node = function(name, def)
			registered_nodes[name] = def
			registered_items[name] = def
		end,
		register_craft = noop, register_globalstep = noop, register_on_mods_loaded = noop,
		register_lbm = function(def) lbms[def.name] = def end,
		log = noop, sound_play = noop, record_protection_violation = noop,
		is_protected = function() return false end,
		is_creative_enabled = function() return false end,
		get_item_group = function() return 0 end,
		get_node = function(pos) return {name = nodes[key(pos)] or "air"} end,
		get_node_or_nil = function(pos) return {name = nodes[key(pos)] or "air"} end,
		set_node = function(pos, node)
			writes = writes + 1
			nodes[key(pos)] = node.name
			local def = registered_nodes[node.name]
			if def and def.on_construct then def.on_construct(pos) end
			return true
		end,
		swap_node = function(pos, node) writes = writes + 1; nodes[key(pos)] = node.name end,
		remove_node = function(pos) writes = writes + 1; nodes[key(pos)] = nil end,
		get_meta = function(pos)
			local k = key(pos)
			metas[k] = metas[k] or new_meta()
			return metas[k]
		end,
		get_node_timer = function(pos)
			local k = key(pos)
			timers[k] = timers[k] or new_timer()
			return timers[k]
		end,
		find_node_near = function(pos, radius, names)
			assert(names[1] == "group:water")
			for x = pos.x - radius, pos.x + radius do
				for y = pos.y - radius, pos.y + radius do
					for z = pos.z - radius, pos.z + radius do
						if nodes[x .. "," .. y .. "," .. z] == "default:water_source" then
							return {x = x, y = y, z = z}
						end
					end
				end
			end
		end,
	}
	_G.default = {node_sound_leaves_defaults = function() return {} end,
		sapling_growth_defs = {}}
	_G.grug_materials = {TIERS = {}}
	_G.grug_core = {natural_renewal_allowed = function() return true end}
	-- The seeds' on_place asks it first (Round 37, ITM-03).
	dofile(repo .. "/mods/CORE/grug_core/node_rightclick.lua")
	_G.grug_mapgen = {wp40 = {vegetation = {}, planner_source = {}}}
	_G.grug_nodes = {
		bind_crop_soil_callbacks = function(callbacks) soil_callbacks = callbacks end,
		crop_visual = function() return {} end,
	}
	local profiles = dofile(repo .. "/mods/ITEMS/grug_farming/crop_profiles.lua")
	local plants = {}
	for crop in pairs(profiles) do
		if crop ~= "potato" and crop ~= "corn" then
			local item = "grug_cooking:" .. crop
			registered_items[item] = {description = crop, inventory_image = crop .. ".png"}
			plants[#plants + 1] = {name = crop, description = crop, item = item}
		end
	end
	table.sort(plants, function(a, b) return a.name < b.name end)
	for _, crop in ipairs({"potato", "corn"}) do
		registered_items["grug_gathering:" .. crop] = {description = crop,
			inventory_image = crop .. ".png"}
	end
	_G.grug_cooking = {PLANTS = plants}
	dofile(repo .. "/mods/ITEMS/grug_farming/init.lua")
	-- grug_nodes owns the soil registrations (crop_soil.lua) and binds the
	-- callbacks farming installs; air is the only other node here.
	registered_nodes.air = {buildable_to = true}
	for _, name in ipairs({grug_farming.SOIL_DRY, grug_farming.SOIL_WET}) do
		registered_nodes[name] = {
			on_construct = function(pos) return soil_callbacks.on_construct(pos) end,
			on_timer = function(pos, elapsed) return soil_callbacks.on_timer(pos, elapsed) end,
		}
	end

	local SOIL, WET = grug_farming.SOIL_DRY, grug_farming.SOIL_WET
	local function timer_at(pos) return core.get_node_timer(pos) end
	local function fire_soil(pos)
		-- The engine removes an expired timer before it calls on_timer.
		local timer = timer_at(pos)
		local timeout = timer.timeout
		timer.started, timer.timeout = false, 0
		if soil_callbacks.on_timer(pos, timeout) then timer:start(timeout) end
	end

	-- Empty wet soil next to water: the hoe path starts 15 s, then 60 s.
	local soil = {x = 0, y = 0, z = 0}
	local above = {x = 0, y = 1, z = 0}
	nodes["2,0,0"] = "default:water_source"
	core.set_node(soil, {name = SOIL})
	eq(timer_at(soil):get_timeout(), 15, "F: new soil starts the 15 s check")
	fire_soil(soil)
	eq(nodes[key(soil)], WET, "F: soil next to water turns wet")
	eq(timer_at(soil):get_timeout(), 60, "F: empty soil re-checks after 60 s")

	-- Planting re-arms 15 s at once and the crop grows on wet soil.
	local seed = registered_items["grug_farming:seed_carrot"]
	local stack = {take_item = noop}
	local placer = {get_player_name = function() return "farmer" end}
	seed.on_place(stack, placer, {type = "node", under = soil, above = above})
	eq(nodes[key(above)], "grug_farming:carrot_1", "F: planted carrot")
	eq(timer_at(soil):get_timeout(), 15, "F: planting puts the soil on 15 s")
	check(timer_at(above):is_started(), "F: crop timer runs on wet soil")
	fire_soil(soil)
	eq(timer_at(soil):get_timeout(), 15, "F: soil under a growing crop stays on 15 s")

	-- Water removed: the next 15 s check dries the soil and pauses the crop.
	nodes["2,0,0"] = nil
	timer_at(above).elapsed = 120
	fire_soil(soil)
	eq(nodes[key(soil)], SOIL, "F: soil dries without water")
	check(not timer_at(above):is_started(), "F: drying pauses the crop timer")
	eq(core.get_meta(above):get_float("wet_progress"), 120, "F: partial progress kept")
	nodes["2,0,0"] = "default:water_source"
	fire_soil(soil)
	eq(nodes[key(soil)], WET, "F: rewetting")
	check(timer_at(above):is_started() and timer_at(above).elapsed == 120,
		"F: rewetting resumes the crop at its progress")

	-- Mature crop: back to 60 s; a regrow harvest re-arms 15 s at once.
	core.swap_node(above, {name = "grug_farming:fire_pepper_4"})
	fire_soil(soil)
	eq(timer_at(soil):get_timeout(), 60, "F: soil under a mature crop re-checks after 60 s")
	local clicker = {is_player = function() return true end,
		get_player_name = function() return "farmer" end,
		get_player_control = function() return {} end,
		get_inventory = function() return {add_item = function() return {is_empty = function() return true end} end} end}
	registered_nodes["grug_farming:fire_pepper_4"].on_rightclick(above,
		{name = "grug_farming:fire_pepper_4"}, clicker, stack)
	eq(nodes[key(above)], "grug_farming:fire_pepper_2", "F: pepper regrows to stage 2")
	eq(timer_at(soil):get_timeout(), 15, "F: regrowth puts the soil back on 15 s")

	-- The soil LBM starts a missing timer at the interval its crop needs.
	local lbm = lbms["grug_farming:start_soil_timer"]
	local bare = {x = 10, y = 0, z = 0}
	nodes[key(bare)] = WET
	lbm.action(bare, {name = WET})
	eq(timer_at(bare):get_timeout(), 60, "F: LBM arms bare soil with 60 s")
	local planted = {x = 12, y = 0, z = 0}
	nodes[key(planted)] = WET
	nodes["12,1,0"] = "grug_farming:corn_2"
	lbm.action(planted, {name = WET})
	eq(timer_at(planted):get_timeout(), 15, "F: LBM arms soil under a crop with 15 s")

	-- Crop geometry LBM: a standing corn writes nothing, a broken one is repaired.
	local geometry = lbms["grug_farming:activate_crop_geometry"]
	local root = {x = 20, y = 1, z = 0}
	nodes["20,0,0"] = WET
	nodes[key(root)] = "grug_farming:corn_4"
	nodes["20,2,0"] = "grug_farming:corn_4_upper_1"
	nodes["20,3,0"] = "grug_farming:corn_4_upper_2"
	writes = 0
	geometry.action(root, {name = "grug_farming:corn_4"})
	eq(writes, 0, "F: standing corn is not rewritten on load")
	nodes["20,3,0"] = nil
	geometry.action(root, {name = "grug_farming:corn_4"})
	check(writes > 0, "F: a missing helper is rewritten")
	eq(nodes["20,3,0"], "grug_farming:corn_4_upper_2", "F: missing helper restored")
	writes = 0
	geometry.action(root, {name = "grug_farming:corn_4"})
	eq(writes, 0, "F: repaired corn is left alone afterwards")

	_G.core, _G.default, _G.grug_materials, _G.grug_core = nil, nil, nil, nil
	_G.grug_mapgen, _G.grug_nodes, _G.grug_cooking, _G.grug_farming = nil, nil, nil, nil
end

------------------------------------------------------------------------------
-- C (grug_jobs craft lookup index) was retired in Round 45: the recipe
-- registry names its recipes by id and matches no craft grid (tools/r45_rg).
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- T: tag-carrier slots (#10).
------------------------------------------------------------------------------
do
	local registered, players, globalsteps = {}, {}, {}
	local function new_object(pos, entity)
		local o = {pos = pos, valid = true, entity = entity, props = {}, visits = 0}
		function o:is_valid() return self.valid end
		function o:get_pos() return self.valid and self.pos or nil end
		function o:get_properties() return self.props end
		function o:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
		function o:set_attach(parent) self.parent = parent end
		function o:get_attach() self.visits = self.visits + 1; return self.parent end
		function o:get_luaentity() return self.entity end
		function o:is_player() return false end
		function o:set_observers(observers) self.observers = observers end
		function o:remove() self.valid = false end
		if entity then entity.object = o end
		return o
	end
	_G.core = {
		settings = {get = function() return nil end,
			get_bool = function(_, _, default) return default end},
		colorspec_to_colorstring = function(v) return v end,
		registered_entities = registered,
		register_entity = function(name, def) registered[name] = def end,
		register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end,
		get_connected_players = function() return players end,
		add_entity = function(pos, name)
			local def = registered[name]
			local entity = setmetatable({name = name}, {__index = def})
			local o = new_object(pos, entity)
			if def.on_activate then def.on_activate(entity) end
			return o
		end,
	}
	_G.grug_core = {}
	dofile(repo .. "/mods/CORE/grug_core/tag_carrier.lua")
	local step = globalsteps[1]
	local calls = {}
	grug_core.register_tag_visibility(function(parent, observers, removed)
		local n = 0
		for _ in pairs(observers) do n = n + 1 end
		calls[#calls + 1] = {parent = parent, count = n, removed = removed}
	end)
	local function player(name, x)
		return {get_pos = function(self) return {x = self.x, y = 0, z = 0} end,
			get_player_name = function() return name end, x = x}
	end
	-- 40 mob parents in a row 2 nodes apart; carriers attach to them.
	local parents, carriers = {}, {}
	for i = 1, 40 do
		parents[i] = new_object({x = i * 2, y = 0, z = 0},
			{name = "grug_mobs:test", _grug_disposition = "aggressive"})
		carriers[i] = grug_core.create_tag_carrier(parents[i])
	end
	local viewer = player("viewer", 0)
	players[1] = viewer
	local function seen(i) return carriers[i]:get_luaentity()._grug_observers.viewer == true end
	local function visits()
		local list = {}
		for i = 1, 40 do list[i] = carriers[i].visits; carriers[i].visits = 0 end
		return list
	end

	-- Eight steps of 0.125 s: one slot each, every carrier exactly once.
	visits()
	local per_step = {}
	for s = 1, 8 do
		local before = 0
		for i = 1, 40 do before = before + carriers[i].visits end
		step(0.125)
		local after = 0
		for i = 1, 40 do after = after + carriers[i].visits end
		per_step[s] = after - before
	end
	local once = true
	for _, n in ipairs(visits()) do if n ~= 1 then once = false end end
	check(once, "T: every carrier visited exactly once per second")
	local balanced = true
	for s = 1, 8 do if per_step[s] ~= 5 then balanced = false end end
	check(balanced, "T: 40 carriers spread 5 per slot")
	local shown = 0
	for i = 1, 40 do if seen(i) then shown = shown + 1 end end
	eq(shown, 12, "T: carriers within 25 nodes are shown (x = 2..24)")

	-- Hysteresis: moving 4 nodes away keeps 25..30 observed, hides beyond.
	viewer.x = -4
	for _ = 1, 8 do step(0.125) end
	check(seen(12) and not seen(14) and not seen(15),
		"T: an observed carrier at 28 nodes stays, one at 32 is hidden")
	viewer.x = 0
	for _ = 1, 8 do step(0.125) end
	check(not seen(13), "T: a carrier first seen at 26 nodes is not shown")

	-- Callbacks: observed carriers every visit, unobserved unchanged never.
	calls = {}
	for _ = 1, 8 do step(0.125) end
	local by_parent = {}
	for _, call in ipairs(calls) do by_parent[call.parent] = (by_parent[call.parent] or 0) + 1 end
	eq(by_parent[parents[1]], 1, "T: an observed carrier reports on its tick")
	eq(by_parent[parents[30]], nil, "T: an unobserved carrier with an unchanged set is skipped")
	viewer.x = 200
	calls = {}
	for _ = 1, 8 do step(0.125) end
	local emptied = 0
	for _, call in ipairs(calls) do
		if call.count == 0 and not call.removed then emptied = emptied + 1 end
	end
	eq(emptied, 12, "T: each carrier reports once with the empty set when the viewer leaves")
	calls = {}
	for _ = 1, 8 do step(0.125) end
	eq(#calls, 0, "T: nothing reported while nobody observes anything")

	-- Lag: a 0.5 s step handles four slots, a 3 s step all eight once.
	visits()
	step(0.5)
	local visited = 0
	for i = 1, 40 do visited = visited + carriers[i].visits end
	eq(visited, 20, "T: a 0.5 s step covers four slots (20 carriers)")
	step(0.5)
	local twice = true
	for _, n in ipairs(visits()) do if n ~= 1 then twice = false end end
	check(twice, "T: two 0.5 s steps visit every carrier once")
	step(3)
	local capped = true
	for _, n in ipairs(visits()) do if n ~= 1 then capped = false end end
	check(capped, "T: a 3 s step visits every carrier exactly once (cap of eight)")
	step(0.125)
	visited = 0
	for _, n in ipairs(visits()) do visited = visited + n end
	eq(visited, 5, "T: after the long step the cadence is one slot per 1/8 s again")

	-- Removal reports and the carrier leaves its slot.
	grug_core.remove_tag_carrier(carriers[3])
	check(#calls == 1 and calls[1].removed and calls[1].parent == parents[3],
		"T: removal reports once")
	visits()
	for _ = 1, 8 do step(0.125) end
	eq(visits()[3], 0, "T: a removed carrier is no longer visited")
	-- The test seam is a full pass over every carrier.
	grug_core.manage_tag_carriers()
	local all = true
	for i, n in ipairs(visits()) do if i ~= 3 and n ~= 1 then all = false end end
	check(all, "T: manage_tag_carriers visits every carrier once")
	_G.core, _G.grug_core = nil, nil
end

------------------------------------------------------------------------------
-- X: crosshair skill-ray skip and the Target Frame's reuse of it (#8).
------------------------------------------------------------------------------
do
	local now = 0
	local joins, globalsteps = {}, {}
	_G.vector = {
		equals = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end,
		offset = function(v, x, y, z) return {x = v.x + x, y = v.y + y, z = v.z + z} end,
		add = function(a, b) return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z} end,
		multiply = function(v, f) return {x = v.x * f, y = v.y * f, z = v.z * f} end,
	}
	local raycasts = 0
	local ray_hits = {}
	_G.core = {
		get_us_time = function() return now end,
		register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
		register_on_leaveplayer = noop,
		register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end,
		get_player_window_information = function() return nil end,
		is_player = function(v) return type(v) == "table" and v.is_player ~= nil and v:is_player() end,
		raycast = function()
			raycasts = raycasts + 1
			local i = 0
			return function() i = i + 1; return ray_hits[i] end
		end,
		get_node = function() return {name = "stone"} end,
		registered_nodes = {stone = {walkable = true}},
	}
	local eye = {x = 0, y = 1.5, z = 0}
	local look = {x = 0, y = 0, z = 1}
	local walled, rays = false, 0
	local next_ray = {reason = "empty", status = "aim_miss", range = 30}
	local def = {id = "fireball", target_kind = "hostile"}
	_G.grug_core = {
		combat_eye_pos = function() return {x = eye.x, y = eye.y, z = eye.z} end,
		-- The aiming ray (grug_core.aim_raycast, tested in tools/r35_t).
		aim_raycast = function(o, d, liquids) return core.raycast(o, d, true, liquids) end,
		hud_layout = {image_element = function(_, d) return d end},
	}
	_G.grug_abilities = {
		input = {aims_at_interactive = function() return false, walled end,
			allowed = function() return true end},
		is_unlocked = function() return true end,
		aimed_target = function()
			rays = rays + 1
			return next_ray.target, next_ray
		end,
	}
	local C = dofile(repo .. "/mods/PLAYER/grug_abilities/crosshair.lua")({
		selected = function() return def end,
	})
	grug_abilities.crosshair = C
	local mage = {get_hp = function() return 20 end, get_player_name = function() return "mage" end,
		get_look_dir = function() return {x = look.x, y = look.y, z = look.z} end,
		get_pos = function() return {x = 0, y = 0, z = 0} end,
		get_properties = function() return {eye_height = 1.5} end,
		is_player = function() return true end,
		hud_add = function() return 1 end, hud_change = noop}

	-- The skill ray skip.
	eq(C.state(mage), nil, "X: empty aim, no state")
	eq(rays, 1, "X: first refresh casts the skill ray")
	now = 150000
	C.state(mage)
	eq(rays, 1, "X: unchanged eye, look and skill: no second ray")
	check(C.recent_aim(mage, 500000).ray.reason == "empty",
		"X: the repeated ray's aim stays the recent aim")
	now = 200000
	C.state(mage)
	eq(rays, 1, "X: still none within 0.25 s")
	now = 250001
	C.state(mage)
	eq(rays, 2, "X: after 0.25 s the ray is cast again")
	look = {x = 0.1, y = 0, z = 0.995}
	C.state(mage)
	eq(rays, 3, "X: a turned look casts again")
	eye = {x = 0.2, y = 1.5, z = 0}
	C.state(mage)
	eq(rays, 4, "X: a moved eye casts again")
	def = {id = "smite", target_kind = "hostile"}
	C.state(mage)
	eq(rays, 5, "X: another skill casts again")
	local mob = {name = "m", _grug_level = 5, health = 10}
	local mob_ref = {is_player = function() return false end,
		get_luaentity = function() return mob end}
	next_ray = {reason = "hostile", status = "target", range = 30, distance = 12,
		target = mob_ref, pointed = {type = "object", ref = mob_ref}}
	-- A mob walks into a still crosshair: marked within 0.25 s.
	local since = now
	now = since + 150000
	eq(C.state(mage), nil, "X: a still crosshair repeats the empty ray for now")
	eq(rays, 5, "X: no ray while unchanged")
	now = since + 250001
	eq(C.state(mage), "hostile", "X: within 0.25 s the mob is marked")
	eq(rays, 6, "X: the repeat ray found it")
	now = now + 150000
	eq(C.state(mage), "hostile", "X: still marked")
	eq(rays, 7, "X: after an object hit every refresh casts again")
	walled = true
	C.state(mage)
	eq(rays, 7, "X: a wall within hand reach skips the ray")
	check(C.recent_aim(mage, 500000).blocked, "X: the wall is the recent aim")
	walled = false
	-- Turning from the wall: no stale "blocked" aim survives a refresh.
	look = {x = 1, y = 0, z = 0}
	now = now + 150000
	C.state(mage)
	check(C.recent_aim(mage, 500000).ray ~= nil, "X: the next skill ray replaces the wall")
	walled = true
	C.state(mage)
	def = {id = "blink", target_kind = "self"}
	walled = false
	now = now + 150000
	C.state(mage)
	eq(C.recent_aim(mage, 500000), nil, "X: without a targeted skill the wall aim is cleared")
	def = {id = "smite", target_kind = "hostile"}

	-- The Target Frame on top of recent_aim.
	local frame_hud = {}
	local viewer = {get_hp = function() return 20 end, get_player_name = function() return "mage" end,
		get_look_dir = function() return {x = 0, y = 0, z = 1} end,
		get_pos = function() return {x = 0, y = 0, z = 0} end,
		get_properties = function() return {eye_height = 1.5} end,
		is_player = function() return true end,
		hud_add = function() return 7 end,
		hud_change = function(_, _, key, value) frame_hud[key] = value end}
	_G.grug_mobs = {tag_text = function(m) return "mob " .. m.name end}
	_G.grug_xp = {get_level = function() return 5 end}
	_G.grug_factions = {get_faction = function() return "accord" end,
		display_name = function() return "The Accord" end}
	local players = {viewer}
	core.get_connected_players = function() return players end
	dofile(repo .. "/mods/ENTITIES/grug_mobs/target_frame.lua")
	joins[#joins](viewer)
	local frame_step = globalsteps[#globalsteps]
	local function frame(aim)
		C.recent_aim = function() return aim end
		raycasts = 0
		frame_hud.text = nil
		frame_step(0.5)
		return frame_hud.text, raycasts
	end
	frame_hud.text = "x"
	local text, casts = frame({at = 0, ray = {reason = "hostile", range = 30, distance = 12,
		pointed = {type = "object", ref = mob_ref}}})
	check(text == "mob m" and casts == 0, "X: a framable target on the crosshair ray, no own ray")
	frame({at = 0, ray = {reason = "empty", range = 30}}) -- clears the text
	text, casts = frame({at = 0, ray = {reason = "empty", range = 30}})
	check(text == nil and casts == 0, "X: an empty crosshair ray settles the frame")
	text, casts = frame({at = 0, ray = {reason = "node", range = 20, distance = 8}})
	check(casts == 0, "X: a crosshair ray ending at a wall settles the frame")
	text, casts = frame({at = 0, ray = {reason = "hostile", range = 40, distance = 25,
		pointed = {type = "object", ref = mob_ref}}})
	check(casts == 0, "X: an object beyond 20 m settles the frame (nothing framable)")
	text, casts = frame({at = 0, blocked = true})
	check(casts == 0, "X: a wall within hand reach settles the frame")
	text, casts = frame({at = 0, ray = {reason = "empty", range = 12}})
	eq(casts, 1, "X: a short skill ray needs the frame's own ray")
	local arrow_ref = {is_player = function() return false end,
		get_luaentity = function() return {name = "arrow"} end}
	text, casts = frame({at = 0, ray = {reason = "object", range = 30, distance = 5,
		pointed = {type = "object", ref = arrow_ref}}})
	eq(casts, 1, "X: a non-framable object needs the frame's own ray")
	text, casts = frame(nil)
	eq(casts, 1, "X: no recent aim needs the frame's own ray")
	ray_hits = {{type = "object", ref = mob_ref}}
	text, casts = frame(nil)
	check(text == "mob m" and casts == 1, "X: the own ray still frames as before")
	ray_hits = {}

	-- init.lua: the crosshair refresh has its own 0.15 s beat.
	local init = assert(io.open(repo .. "/mods/PLAYER/grug_abilities/init.lua")):read("*a")
	check(init:find("local CROSSHAIR_STEP = 0.15", 1, true) ~= nil and
		init:find("if crosshair_due then grug_abilities.crosshair.update(player) end", 1, true) ~= nil,
		"X: the crosshair refresh runs every 0.15 s, input and ready ring every pass")
	_G.core, _G.grug_core, _G.grug_abilities, _G.vector = nil, nil, nil, nil
	_G.grug_mobs, _G.grug_xp, _G.grug_factions = nil, nil, nil
end

------------------------------------------------------------------------------
-- M: grug_mounts flight-boundary sweep (#14).
------------------------------------------------------------------------------
do
	local function round(v)
		-- grug_zones rounds half away from zero (zones.lua normalize_coordinate).
		if v >= 0 then
			local b = math.floor(v)
			return v - b >= 0.5 and b + 1 or b
		end
		local b = math.ceil(v)
		return b - v >= 0.5 and b - 1 or b
	end
	local RECORDS = {
		home_a = {id = "home_a", territory_rule = "accord_home"},
		home_t = {id = "home_t", territory_rule = "throng_home"},
		front = {id = "front", territory_rule = "contested_land"},
		front_wyrmglass_crown = {id = "front_wyrmglass_crown", territory_rule = "contested_land"},
	}
	local function owner(x, z)
		x, z = round(x), round(z)
		if z >= 60 and x < -10 then return "front_wyrmglass_crown" end
		if z >= 25 then return "front" end
		if x < 0 then return "home_a" end
		return "home_t"
	end
	local function water(x, z)
		x, z = round(x), round(z)
		if x > 70 then return "deep_ocean" end
		if x > 64 then return "planned_water" end
		if (x - 30) * (x - 30) + (z + 40) * (z + 40) < 50 then return "shallow_ocean" end
		return "land"
	end
	local function copy(t) local r = {} for k, v in pairs(t) do r[k] = v end return r end
	local counts = {at = 0, faction = 0}
	_G.grug_zones = {
		water_class_at = water,
		id_at = function(x, z) return owner(x, z) end,
		get = function(id) return RECORDS[id] and copy(RECORDS[id]) end,
		at = function(pos) counts.at = counts.at + 1; return copy(RECORDS[owner(pos.x, pos.z)]) end,
	}
	_G.grug_factions = {
		get_faction = function(player) counts.faction = counts.faction + 1; return player.faction end,
		register_on_faction_chosen = noop,
	}
	_G.grug_classes = {register_on_race_chosen = noop}
	_G.core = {register_entity = noop, register_on_player_hpchange = noop,
		register_on_dieplayer = noop, register_on_leaveplayer = noop,
		register_on_shutdown = noop}
	_G.grug_mounts = {}
	dofile(repo .. "/mods/PLAYER/grug_mounts/entity.lua")

	-- The former code (base 451f393b), verbatim apart from the names.
	local DRAGON = {front_wyrmglass_crown = true, front_stormscale_summit = true}
	local DIST = {1, 2, 4, 8, 16, 32, 48}
	local DIRS = {}
	for index = 0, 15 do
		local angle = index * math.pi / 8
		DIRS[#DIRS + 1] = {x = math.cos(angle), z = math.sin(angle)}
	end
	local function old_flight_state(player, pos)
		local w = grug_zones.water_class_at(pos.x, pos.z)
		if w ~= "land" and w ~= "planned_water" then return false, "ocean" end
		local faction = grug_factions.get_faction(player)
		if faction ~= "accord" and faction ~= "throng" then return false, "enemy" end
		local zone = grug_zones.at(pos)
		if zone and DRAGON[zone.id] then return false, "island" end
		local territory = zone and zone.territory_rule
		if territory == "contested_land" or territory == faction .. "_home" then
			return true, nil
		end
		return false, "enemy"
	end
	local function old_warning_state(player, pos)
		local sample = {x = pos.x, y = pos.y, z = pos.z}
		for _, distance in ipairs(DIST) do
			for _, direction in ipairs(DIRS) do
				sample.x = pos.x + direction.x * distance
				sample.z = pos.z + direction.z * distance
				local legal, kind = old_flight_state(player, sample)
				if not legal then return kind end
			end
		end
		return nil
	end

	local players = {{faction = "accord"}, {faction = "throng"}, {faction = nil}}
	local same_state, same_warning, total, kinds = 0, 0, 0, {}
	for _, player in ipairs(players) do
		for x = -130, 130, 7.3 do
			for z = -130, 130, 6.7 do
				local pos = {x = x, y = 80, z = z}
				total = total + 1
				local a1, a2 = grug_mounts.flight_state(player, pos)
				local b1, b2 = old_flight_state(player, pos)
				if a1 == b1 and a2 == b2 then same_state = same_state + 1 end
				local w1 = grug_mounts.warning_state(player, pos)
				local w2 = old_warning_state(player, pos)
				if w1 == w2 then same_warning = same_warning + 1 end
				kinds[tostring(w1)] = true
			end
		end
	end
	eq(same_state, total, "M: flight_state equals the former code")
	eq(same_warning, total, "M: warning_state equals the former code")
	check(kinds["nil"] and kinds.ocean and kinds.enemy and kinds.island,
		"M: the field exercises no warning, ocean, enemy and island")
	counts.at, counts.faction = 0, 0
	eq(grug_mounts.warning_state(players[1], {x = -60, y = 80, z = -60}), nil,
		"M: deep in home territory no warning")
	eq(counts.faction, 1, "M: one faction read per sweep (112 samples)")
	eq(counts.at, 0, "M: no zone record copied per sample")

	_G.grug_zones, _G.grug_factions, _G.grug_classes, _G.core, _G.grug_mounts =
		nil, nil, nil, nil, nil
end

print(("%d checks, %d failures"):format(checks, failures))
if failures > 0 then error("R30 P4 PORTABLE FAIL") end
print("R30 P4 PORTABLE PASS checks=" .. checks)
