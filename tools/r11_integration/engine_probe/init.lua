-- Staged only by tools/luanti_headless.sh into a disposable /tmp world.
-- This probe deliberately suppresses automatic six-capital emergence. It
-- proves registration and native liquid callbacks, not generated landscapes.
grug_core.request_starts_preload = function() return false end

local base
local protected_hits, allowed_floods = 0, 0
local function point(x, z)
	return {x = base.x + x, y = base.y + 3, z = base.z + z}
end
local function guarded(pos)
	return base and pos.x == base.x + 7 and pos.y == base.y + 3 and
		(pos.z == base.z + 2 or pos.z == base.z + 5 or
		 pos.z == base.z + 8 or pos.z == base.z + 11)
end
grug_core.register_world_alteration_guard(function(pos)
	if guarded(pos) then return false end
end)
core.register_node("grug_r11_integration_probe:plant", {
	description = "Disposable flood witness", tiles = {"default_grass.png"},
	paramtype2 = "color", floodable = true, buildable_to = true,
	on_flood = function(pos)
		assert(not guarded(pos), "protected original on_flood was invoked")
		allowed_floods = allowed_floods + 1
	end,
})
core.register_on_liquid_transformed(function(positions)
	for _, pos in ipairs(positions) do
		if guarded(pos) then protected_hits = protected_hits + 1 end
	end
end)

local function catalog()
	assert(jit and jit.version, "Round 11 forbids PUC runtime")
	assert(grug_classes.registered_classes.scout, "Scout class missing")
	local families = dofile(core.get_modpath("grug_farming") .. "/seed_visuals.lua")
	local count = 0
	for key, image in pairs(families) do
		local def = assert(core.registered_items["grug_farming:seed_" .. key])
		assert(def.inventory_image == image, "integrated seed hook missing: " .. key)
		count = count + 1
	end
	assert(count == 17, "seed catalog changed")
	assert(core.registered_items["grug_farming:empty_iron_bucket"])
	assert(core.registered_items["grug_farming:water_bucket"])
	local hoes = 0
	for name, def in pairs(core.registered_items) do
		if def._grug_hoe_uses then
			hoes = hoes + 1
			assert(grug_gear.reference_purchase_price(ItemStack(name)), name)
		end
	end
	assert(hoes == 7, "hoe catalog changed")
	core.log("action", "[R11_INTEGRATION] catalog PASS 17 seeds / 7 hoes / Scout / repair; " .. jit.version)
end

local function setup()
	catalog()
	-- Pick a single mutable surface column, then create only one 16-node
	-- scratch block high above it. No mapgen population/emerge is requested.
	for _, candidate in ipairs({{x=-800,z=-1600}, {x=-1504,z=-1504},
			{x=-432,z=-2736}, {x=800,z=-1600}}) do
		local clear = true
		for _, z in ipairs({2,5,8,11}) do
			for x = 3, 10 do
				if not grug_core.world_alterable({x=candidate.x+x,
					y=9011,z=candidate.z+z}) then clear = false end
			end
		end
		if clear then base = {x=candidate.x,y=9008,z=candidate.z}; break end
	end
	assert(base, "no mutable scratch column")
	local high = {x=base.x+15,y=base.y+15,z=base.z+15}
	local vm = core.get_voxel_manip()
	local low, upper = vm:read_from_map(base, high)
	assert(vector.equals(low, base) and vector.equals(upper, high))
	local data = vm:get_data()
	local stone = core.get_content_id("default:stone")
	for index = 1, #data do data[index] = stone end
	vm:set_data(data)
	vm:write_to_map()
	vm:close()
	for row, z in ipairs({2,5,8,11}) do
		for x = 3, 10 do core.set_node(point(x,z), {name="air"}) end
		core.set_node(point(5,z), {name="grug_r11_integration_probe:plant"})
		if row % 2 == 0 then
			core.set_node(point(7,z), {name="grug_r11_integration_probe:plant",param2=7})
			core.get_meta(point(7,z)):set_string("witness", "preserved")
		end
		core.set_node(point(6,z), {name=row <= 2 and
			"default:water_source" or "default:river_water_source"})
	end
	core.after(12, function()
		for row, z in ipairs({2,5,8,11}) do
			local node = core.get_node(point(7,z))
			if row % 2 == 0 then
				assert(node.name == "grug_r11_integration_probe:plant" and node.param2 == 7)
				assert(core.get_meta(point(7,z)):get_string("witness") == "preserved")
			else
				assert(node.name == "air", "protected air was flooded")
			end
			local allowed = core.get_node(point(5,z))
			assert(allowed.name == (row <= 2 and "default:water_flowing" or
				"default:river_water_flowing"), "control channel did not flow")
		end
		assert(protected_hits > 0 and allowed_floods >= 4,
			"native liquid callback boundary was not exercised")
		local report = "R11_INTEGRATION_PASS\nengine=" .. core.get_version().string ..
			"\ninterpreter=" .. jit.version .. "\nprotected_air_callbacks=" ..
			protected_hits .. "\nallowed_plant_callbacks=" .. allowed_floods .. "\n"
		assert(core.safe_file_write(core.get_worldpath() .. "/r11-integration.txt", report))
		core.log("action", "[R11_INTEGRATION] COMPLETE " .. protected_hits .. " / " .. allowed_floods)
		core.request_shutdown("Round 11 bounded engine witness complete", false, 0)
	end)
end
core.register_on_mods_loaded(function() core.after(0, setup) end)
