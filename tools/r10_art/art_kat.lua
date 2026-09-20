return function(root)
	local function read(relative)
		local file = assert(io.open(root .. "/" .. relative, "rb"), relative)
		local data = assert(file:read("*a")); file:close()
		return data
	end
	local digest, count = 5381, 0
	local function include(relative)
		local data = read(relative)
		for index = 1, #data do
			digest = (digest * 33 + data:byte(index)) % 2147483647
		end
		count = count + 1
		return data
	end
	local function contains(source, token, label)
		assert(source:find(token, 1, true), "R10 ART KAT: " .. label)
	end
	local gear = include("mods/ITEMS/grug_gear/init.lua")
	local compose = include("mods/PLAYER/grug_visuals/compose.lua")
	local farming = include("mods/ITEMS/grug_farming/init.lua")
	local cooking = include("mods/ITEMS/grug_cooking/init.lua")
	local mount_catalog = include("mods/PLAYER/grug_mounts/catalog.lua")
	local mount_items = include("mods/PLAYER/grug_mounts/items.lua")
	local mount_state = include("mods/PLAYER/grug_mounts/state.lua")
	local loot = include("mods/ENTITIES/grug_mobs/items.lua")
	contains(compose, 'grug_visuals.LINES = {"cloth", "leather", "metal"}',
		"three armor lines not bound")
	contains(compose, 'materials[line].key .. ".png"', "tier overlay binding absent")
	contains(gear, 'line.key .. "_" .. grade.key .. ".png"', "tier icon binding absent")
	contains(farming, 'row.key == "salt_crust"', "salt visual branch absent")
	contains(farming, 'drawtype = "nodebox"', "salt nodebox absent")
	contains(farming, 'type = "vertical_frames"', "salt animation absent")
	contains(cooking, 'image = "grug_cooking_wild_grain.png"',
		"harvest icon catalog absent")
	contains(cooking, "inventory_image = row.image", "harvest icon binding absent")
	contains(mount_catalog, 'icon = "grug_mounts_icon_" .. id .. ".png"',
		"horse icon binding absent")
	contains(mount_state, 'meta:set_string("inventory_image", model.icon)',
		"owner mount icon binding absent")
	contains(mount_items, 'grug_mounts_icon_t1_accord.png', "mount fallback icon absent")
	contains(loot, 'inventory_image = "grug_mobs_item_" .. name .. ".png"',
		"loot icon binding absent")
	local slots = {"head", "chest", "legs", "feet"}
	local grades = {
		metal = {"bronze", "iron", "steel", "silversteel", "embersteel", "abyssal_steel"},
		cloth = {"patch", "woven", "heavy", "silkweave", "silk", "stormweave"},
		leather = {"light", "cured", "heavy", "scaled", "sleek", "nightscale"},
	}
	for _, line in ipairs({"metal", "cloth", "leather"}) do
		local tiers = grades[line]
		for _, slot in ipairs(slots) do
			for _, tier in ipairs(tiers) do
				include("mods/ITEMS/grug_gear/textures/grug_gear_item_" .. slot ..
					"_" .. line .. "_" .. tier .. ".png")
				include("mods/PLAYER/grug_visuals/textures/grug_visuals_" .. line ..
					"_" .. slot .. "_" .. tier .. ".png")
			end
		end
	end
	local crops = {"wild_grain", "carrot", "cassava", "wild_onion", "fire_pepper",
		"pumpkin", "blightberry", "sunberry", "jungle_berry", "frost_melon",
		"sugar_cane", "bamboo_shoot", "cave_cap", "salt_crust", "ember_moss",
		"potato", "corn"}
	for _, crop in ipairs(crops) do
		for stage = 1, 4 do
			include("mods/ITEMS/grug_farming/textures/grug_farming_" .. crop ..
				"_" .. stage .. ".png")
		end
	end
	for stage = 1, 4 do
		include("mods/ITEMS/grug_farming/textures/grug_farming_salt_crust_" ..
			stage .. "_side.png")
	end
	include("mods/ITEMS/grug_farming/textures/grug_farming_salt_crust_bottom.png")
	for _, crop in ipairs(crops) do
		if crop ~= "potato" and crop ~= "corn" then
			include("mods/ITEMS/grug_cooking/textures/grug_cooking_" .. crop .. ".png")
		end
	end
	for _, name in ipairs({"boar_tusk", "feather", "heavy_leather", "light_leather",
		"sleek_pelt", "slime_gel", "zombie_flesh"}) do
		include("mods/ENTITIES/grug_mobs/textures/grug_mobs_item_" .. name .. ".png")
	end
	for _, id in ipairs({"dwarf", "elf", "expert_accord", "expert_throng", "human",
		"master_accord", "master_throng", "orc", "t1_accord", "t1_throng",
		"troll", "undead"}) do
		local icon = "grug_mounts_icon_" .. id .. ".png"
		contains(mount_catalog, '"' .. id .. '"', "catalog model absent: " .. id)
		include("mods/PLAYER/grug_mounts/textures/" .. icon)
	end
	return string.format("r10_art_v1\tfiles=%d\tdigest=%d\n", count, digest)
end
