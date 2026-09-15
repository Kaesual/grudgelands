-- Disposable engine probe for WP13's one weapon ladder (playtest round 2).
--
-- Everything the pure fixtures can check is checked in
-- `tools/wp13/gear_catalogue_kat.lua`; what only a real server can say is
-- whether the REGISTRY ends up the way the generator meant after `default`,
-- `grug_materials`' curation and every override have had their turn. So this
-- prints the ladder as the engine holds it, and fails loudly when a texture
-- file a registered item names is not actually on disk -- the one class of
-- defect that produces an untextured icon on a client and nothing at all in
-- the server log.
--
-- Staged with PROBE=, never shipped.

local function log(line)
	core.log("action", "[probe] " .. line)
end

-- `dofile`/`io` are restricted under secure.enable_security, but the game and
-- mod directories stay readable (AGENTS.md), which is all this needs.
local function texture_exists(modname, filename)
	local path = core.get_modpath(modname) .. "/textures/" .. filename
	local handle = io.open(path, "rb")
	if not handle then
		return false
	end
	handle:close()
	return true
end

local function image_name(def)
	local image = def.inventory_image
	if type(image) == "table" then
		image = image.name
	end
	return type(image) == "string" and image or ""
end

core.register_on_mods_loaded(function()
	local problems = {}

	--
	-- 1. the weapon ladder
	--
	local families = {"sword", "dagger", "greataxe", "staff"}
	for bracket = 1, #grug_gear.BRACKETS do
		local names = {}
		for _, family in ipairs(families) do
			local itemname = grug_gear.weapon_item(family, bracket)
			local def = core.registered_items[itemname]
			if not def then
				problems[#problems + 1] = itemname .. " is not registered"
			else
				local image = image_name(def)
				if not texture_exists("grug_gear", image) then
					problems[#problems + 1] = itemname .. " names a missing " ..
						"texture: " .. image
				end
				names[#names + 1] = (def.description:gsub("\n.*", "")) ..
					" [" .. image .. "]"
			end
		end
		log("weapons T" .. bracket .. ": " .. table.concat(names, ", "))
	end

	local starter = core.registered_items[grug_gear.STARTER_STAFF]
	if not starter then
		problems[#problems + 1] = "the starter staff is not registered"
	else
		local image = image_name(starter)
		if not texture_exists("grug_gear", image) then
			problems[#problems + 1] = "the starter staff names a missing " ..
				"texture: " .. image
		end
		log("starter: " .. (starter.description:gsub("\n.*", "")) ..
			" [" .. image .. "], hands " .. tostring(starter._grug_hands))
	end

	--
	-- 2. the tool ladder, and the pick tier every rung claims
	--
	local tools = {}
	for _, tier in ipairs(grug_materials.TIERS) do
		for _, family in ipairs({"pick", "axe", "shovel"}) do
			for _, itemname in ipairs({
					"default:" .. family .. "_" .. tier.key,
					"grug_materials:" .. family .. "_" .. tier.key}) do
				local def = core.registered_items[itemname]
				if def then
					local entry = itemname
					local pick_tier = (def.groups or {}).grug_pick_tier
					if pick_tier then
						entry = entry .. "(T" .. pick_tier .. ")"
					end
					tools[#tools + 1] = entry
					local image = image_name(def)
					local modname = itemname:match("^([^:]+)")
					if not texture_exists(modname, image) then
						problems[#problems + 1] = itemname ..
							" names a missing texture: " .. image
					end
					if def.wield_image and def.wield_image ~= "" then
						problems[#problems + 1] = itemname ..
							" declares a wield_image (" .. def.wield_image ..
							"), breaking the one held-item convention"
					end
				end
			end
		end
	end
	log("tools: " .. table.concat(tools, " "))

	--
	-- 3. one item per concept: the two retired swords are gone, the two
	--    below-ladder starters are not
	--
	for _, itemname in ipairs({"default:sword_bronze", "default:sword_steel"}) do
		if rawget(core.registered_items, itemname) then
			problems[#problems + 1] = itemname ..
				" is still registered next to its grug_gear replacement"
		end
	end
	for _, itemname in ipairs({"default:sword_wood", "default:sword_stone"}) do
		if not rawget(core.registered_items, itemname) then
			problems[#problems + 1] = itemname ..
				" (a below-ladder starter) was removed"
		end
	end
	log("retired: default:sword_bronze/steel gone, wood/stone kept")

	--
	-- 4. the starter weapon per class
	--
	local kit = {}
	for _, class_id in ipairs(grug_classes.class_ids) do
		kit[#kit + 1] = class_id .. "=" ..
			tostring(grug_inventory.STARTER_WEAPON[class_id])
	end
	log("starter weapons: " .. table.concat(kit, " "))

	--
	-- 5. the hand transform, as the running server computed it
	--
	local wield = grug_visuals.WIELD
	log(string.format("wield pos %.3f,%.3f,%.3f rot %.0f,%.0f,%.0f size %.3f",
		wield.pos.x, wield.pos.y, wield.pos.z,
		wield.rot.x, wield.rot.y, wield.rot.z, wield.size.x))
	for _, race in ipairs({"dwarf", "human", "troll"}) do
		local stature = grug_visuals.RACES[race].stature
		local compensated = grug_visuals.wield_transform(stature)
		log(string.format("wield %s stature %.2f -> size %.4f (absolute %.4f)",
			race, stature, compensated.size.x, compensated.size.x * stature))
	end

	if #problems > 0 then
		table.sort(problems)
		for _, message in ipairs(problems) do
			core.log("error", "[probe] " .. message)
		end
	else
		log("PROBE PASS: no missing texture, no stray registration")
	end
end)
