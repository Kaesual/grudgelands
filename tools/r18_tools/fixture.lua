-- Bounded Round-18 J fixture. Loads the production registrars into a small
-- engine-shaped registry, then inspects final definitions and stack overrides.
return function(repo)
	local function copy(value)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, member in pairs(value) do result[key] = copy(member) end
		return result
	end
	table.copy = copy
	local callbacks = {}
	local core_api = {registered_items = {}, registered_nodes = {}}
	core = core_api
	vector = {copy = copy, offset = function(pos, x, y, z)
		return {x = pos.x + x, y = pos.y + y, z = pos.z + z}
	end, new = function(x, y, z) return {x = x, y = y, z = z} end}
	function core_api.override_item(name, fields)
		local def = assert(core_api.registered_items[name], "missing " .. name)
		for key, value in pairs(fields) do def[key] = value end
	end
	function core_api.register_tool(name, def)
		core_api.registered_items[name] = def
	end
	core_api.get_modpath = function() return nil end
	core_api.register_on_leaveplayer = function() end
	core_api.register_on_mods_loaded = function(fn) callbacks[#callbacks + 1] = fn end
	core_api.node_dig = function() return true end
	core_api.handle_node_drops = function() end
	core_api.log = function() end
	core_api.is_protected = function() return false end
	core_api.get_us_time = function() return 0 end
	core_api.chat_send_player = function() end
	core_api.sound_play = function() end
	core_api.add_particlespawner = function() end

	grug_materials = {}
	dofile(repo .. "/mods/ITEMS/grug_materials/registry.lua")
	dofile(repo .. "/mods/ITEMS/grug_materials/mining.lua")

	local function item(name, groups, caps)
		local def = {description = name, groups = copy(groups or {})}
		if caps then def.tool_capabilities = copy(caps) end
		core_api.registered_items[name] = def
		return def
	end
	local function node(name, groups)
		local def = item(name, groups)
		core_api.registered_nodes[name] = def
		return def
	end
	local shovel_profiles = {
		wood = {{[1]=3.00,[2]=1.60,[3]=0.60}, 10, 1, 1.2, 0, 2},
		stone = {{[1]=1.80,[2]=1.20,[3]=0.50}, 20, 1, 1.4, 0, 2},
		bronze = {{[1]=1.65,[2]=1.05,[3]=0.45}, 25, 2, 1.1, 1, 3},
		steel = {{[1]=1.50,[2]=0.90,[3]=0.40}, 30, 2, 1.1, 1, 3},
	}
	local pick_profiles = {
		wood = {{[3]=1.60},10,1,1.2,0,2}, stone={{[2]=2,[3]=1},20,1,1.3,0,3},
		bronze={{[1]=4.5,[2]=1.8,[3]=0.9},20,2,1,1,4},
		steel={{[1]=4,[2]=1.6,[3]=0.8},20,2,1,1,4},
	}
	for _, key in ipairs({"wood", "stone", "bronze", "steel"}) do
		local s = shovel_profiles[key]
		item("default:shovel_" .. key, {shovel=1}, {full_punch_interval=s[4],
			max_drop_level=s[5], punch_attack_uses=90, groupcaps={crumbly={times=s[1],
			uses=s[2],maxlevel=s[3]}},damage_groups={fleshy=s[6]}})
		local p = pick_profiles[key]
		item("default:pick_" .. key, {pickaxe=1}, {full_punch_interval=p[4],
			max_drop_level=p[5],punch_attack_uses=90,groupcaps={cracky={times=p[1],
			uses=p[2],maxlevel=p[3]}},damage_groups={fleshy=p[6]}})
		item("default:axe_" .. key, {axe=1}, {groupcaps={choppy={times={[3]=1},
			uses=10,maxlevel=1}},damage_groups={fleshy=3},punch_attack_uses=90})
	end
	for _, name in ipairs(grug_materials.NATURAL_GROUND_NODES) do
		local rating = name == "default:gravel" and 2 or 3
		local groups = {crumbly=rating}
		if name == "grug_nodes:ash_ground" or name:match("^grug_nodes:.*dirt") then
			groups.grug_loose = rating
		end
		node(name, groups)
	end
	node("grug_farming:soil", {crumbly=3,grug_loose=3,soil=2})
	node("grug_farming:soil_wet", {crumbly=3,grug_loose=3,soil=3})
	node("default:desert_sand", {crumbly=3,sand=1})
	for _, name in ipairs({"default:sandstone", "default:clay", "default:snow"}) do
		node(name, {crumbly=1,cracky=name == "default:sandstone" and 3 or nil})
	end
	for _, name in ipairs({"default:obsidian", "default:obsidianbrick",
		"default:obsidian_block", "default:steelblock", "default:copperblock",
		"default:tinblock", "default:bronzeblock"}) do node(name,{cracky=1,level=2}) end
	for _, resource in ipairs(grug_materials.RESOURCES) do
		if not core_api.registered_nodes[resource.natural_node] then
			node(resource.natural_node, {cracky=1,level=2})
		end
		item(resource.raw_item)
	end

	dofile(repo .. "/mods/ITEMS/grug_materials/overrides.lua")
	dofile(repo .. "/mods/ITEMS/grug_materials/tools.lua")
	dofile(repo .. "/mods/ITEMS/grug_materials/tool_lifetimes.lua")

	local names = {
		{"default", "wood"}, {"default", "stone"}, {"default", "bronze"},
		{"grug_materials", "iron"}, {"default", "steel"},
		{"grug_materials", "silversteel"}, {"grug_materials", "embersteel"},
		{"grug_materials", "abyssal_steel"},
	}
	local expected_uses = {30,60,300,600,1000,1500,2000,3000}
	function core_api.get_dig_params(groups, caps)
		local best, best_wear, best_group
		local level = groups.level or 0
		for group, cap in pairs(caps.groupcaps or {}) do
			local rating = groups[group]
			local leveldiff = (cap.maxlevel or 0) - level
			local seconds = leveldiff >= 0 and rating and cap.times[rating]
			if seconds and leveldiff > 1 then seconds = seconds / leveldiff end
			if seconds and (not best or seconds < best) then
				best, best_wear, best_group = seconds,
					math.floor(65535 / ((cap.uses or 0) * 3 ^ leveldiff)), group
			end
		end
		return {diggable=best ~= nil,time=best,wear=best_wear,main_group=best_group}
	end
	local function dig(groups, caps)
		local result = core_api.get_dig_params(groups, caps, 0)
		return result.diggable and result.time or nil
	end
	local lines = {}
	for index, row in ipairs(names) do
		local prefix, key = row[1] .. ":", row[2]
		local pick = assert(core_api.registered_items[prefix .. "pick_" .. key])
		local shovel = assert(core_api.registered_items[prefix .. "shovel_" .. key])
		assert(pick._grug_tool_uses == expected_uses[index])
		assert(shovel._grug_tool_uses == expected_uses[index])
		assert(pick.groups.grug_pick_tier and shovel.groups.grug_shovel_tier)
		assert(not shovel.tool_capabilities.groupcaps.crumbly)
		for _, material in ipairs({"default:dirt", "default:gravel", "default:sand",
			"grug_nodes:ash_ground", "grug_farming:soil", "grug_farming:soil_wet"}) do
			local groups = core_api.registered_nodes[material].groups
			local shovel_time = assert(dig(groups, shovel.tool_capabilities))
			assert(dig(groups, pick.tool_capabilities) == shovel_time * 2)
		end
		for _, solid in ipairs({"default:stone", "default:sandstone",
			"default:stone_with_coal", "default:stone_with_iron"}) do
			assert(not dig(core_api.registered_nodes[solid].groups,
				shovel.tool_capabilities), solid .. " shovel route")
		end
		-- A stack capability override is authoritative over the registration.
		local stack_caps = copy(pick.tool_capabilities)
		stack_caps.groupcaps.grug_loose.times[3] = 9
		local loose_level = stack_caps.groupcaps.grug_loose.maxlevel or 0
		local override_time = loose_level > 1 and 9 / loose_level or 9
		assert(dig(core_api.registered_nodes["default:dirt"].groups, stack_caps) ==
			override_time)
		lines[#lines + 1] = key .. "=" .. expected_uses[index]
	end
	local shallow = grug_materials.mining_decision({x=0,y=-101,z=0},
		{name="default:stone_with_gold"}, {is_player=function() return true end,
		get_player_name=function() return "fixture" end,get_wielded_item=function()
			return {is_empty=function() return false end,get_definition=function()
				return core_api.registered_items["default:pick_wood"] end}
		end})
	assert(shallow.reason == "depth" and shallow.max_depth == -100)
	local harvest = grug_materials.mining_decision({x=0,y=0,z=0},
		{name="default:stone_with_gold"}, {is_player=function() return true end,
		get_player_name=function() return "fixture" end,get_wielded_item=function()
			return {is_empty=function() return false end,get_definition=function()
				return core_api.registered_items["default:pick_bronze"] end}
		end})
	assert(harvest.reason == "shatter" and harvest.resource_harvest_tier == 2)
	return "r18-tools: " .. table.concat(lines, ",") ..
		" loose=shovel/pick2x solids=denied depth=denied harvest=shatter stack=override"
end
