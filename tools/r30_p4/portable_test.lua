-- Round 30 Lane P4 portable test (perf review #7, #10, #14, #15, #16, #19;
-- docs/planning/round30-plan.md). Loads the REAL files under small stubs:
--   F  grug_farming/init.lua: soil re-checks every 60 s without a growing
--      crop and every 15 s under one (planting and regrowth re-arm 15 s at
--      once); drying still pauses and rewetting resumes a crop; the crop
--      geometry LBM writes nothing when the plant already stands and still
--      repairs a missing helper.
--   M  grug_mounts/entity.lua: flight_state and the flight-boundary sweep
--      (warning_state) give exactly the answers of the former per-sample
--      code (faction read per sample, grug_zones.at per sample) on a field
--      with ocean, home, contested, enemy and dragon-island columns, while
--      the sweep reads the faction once and copies no zone record.
-- Usage (repo root): luajit tools/r30_p4/portable_test.lua [REPO]
local repo = arg[1] or "."

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
