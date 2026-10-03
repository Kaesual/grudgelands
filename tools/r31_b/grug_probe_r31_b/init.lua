-- Round 31 Lane B engine probe (disposable, never shipped): enchant colours
-- (round31-plan.md §2.2) on a real server (tools/r31_b/engine.sh).
--   1. A loot roll on a real stack writes the coloured per-stack image; a
--      plain stack has no image key; an enchant operation plan changes it.
--   2. Dropped: the item entity of an enchanted stack carries the image in
--      its item string and its wield_item property.
--   3. Wielded: wield_appearance keeps the image (the player's visible
--      weapon); a king, spawned for real, holds his weapon in his fixed
--      colours.
--   4. Body: a humanoid entity composed with enchanted worn pieces wears the
--      colour layers in its texture.
-- Ends the server itself; "RESULT PASS" is the verdict line.

local PREFIX = "[r31_b_probe] "
local checks, failures = 0, 0
local function log(message) core.log("action", PREFIX .. message) end
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		core.log("error", PREFIX .. "FAIL " .. label)
	end
	return ok
end

local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("r31 b probe done", false, 0)
end

core.register_entity("grug_probe_r31_b:dummy", {
	initial_properties = {visual = "mesh", mesh = "character.b3d",
		textures = {"character.png"}, physical = false, static_save = false},
})

local POS = {x = 0, y = 300, z = 0}

local function image_of(stack)
	return stack:get_meta():get_string("inventory_image")
end

local function stage_items()
	-- 1. Per-stack image.
	local plain = ItemStack("grug_gear:sword_steel")
	grug_items.regenerate_description(plain)
	check(plain:get_meta():to_table().fields.inventory_image == nil, "plain: no image key")
	local sword = ItemStack("grug_gear:sword_steel")
	sword:get_meta():set_int("grug_quality", 3)
	check(grug_items.roll_enchants(sword, 30, "world", 2, 777), "roll on a real stack")
	local affixes = grug_items.get_affixes(sword)
	local prefix, suffix = grug_visuals.affix_pair(affixes)
	local def = core.registered_items["grug_gear:sword_steel"]
	check(image_of(sword) == grug_gear.enchant_image(def.inventory_image, prefix, suffix),
		"rolled sword carries its colours: " .. image_of(sword))
	log("rolled sword " .. tostring(prefix) .. "/" .. tostring(suffix) .. ": " .. image_of(sword))
	-- 3a. The player's visible weapon keeps the image.
	local appearance = ItemStack(grug_visuals.wield_appearance(sword))
	check(image_of(appearance) == image_of(sword), "wield_appearance keeps the image")
	return sword
end

local function stage_drop(sword, done)
	-- 2. Dropped.
	local object = core.add_item(POS, sword)
	check(object ~= nil, "enchanted item dropped")
	if object then
		local entity = object:get_luaentity()
		check(entity and image_of(ItemStack(entity.itemstring)) == image_of(sword),
			"dropped item string keeps the image")
		local properties = object:get_properties()
		check(type(properties.wield_item) == "string" and
			properties.wield_item:find("_ench.png", 1, true) ~= nil,
			"dropped item draws the coloured image: " .. tostring(properties.wield_item))
		object:remove()
	end
	done()
end

local function stage_body(done)
	-- 4. Body: enchanted worn pieces on a humanoid entity.
	local worn, armor = {}, {}
	for slot, item in pairs({head = "grug_gear:head_metal_steel",
			chest = "grug_gear:chest_leather_scaled", legs = "grug_gear:legs_cloth_silk",
			feet = "grug_gear:feet_metal_iron"}) do
		local stack = ItemStack(item)
		stack:get_meta():set_int("grug_quality", 3)
		grug_items.roll_enchants(stack, 30, "world", 2, 900 + #item)
		worn[slot] = {name = item, affixes = grug_items.get_affixes(stack)}
		armor[slot] = item
	end
	local layers = grug_visuals.armor_layers(worn)
	local object = core.add_entity(vector.add(POS, {x = 2, y = 0, z = 0}), "grug_probe_r31_b:dummy")
	check(object ~= nil, "body entity added")
	if not object then return done() end
	local entity = object:get_luaentity()
	local result = grug_visuals.apply_entity(entity, {race = "orc", armor = armor,
		armor_layers = layers, weapon_family = "dagger",
		weapon_colors = {prefix = "dex", suffix = "crit_percent"}})
	local texture = object:get_properties().textures[1]
	local count = select(2, texture:gsub("_ench%.png", ""))
	check(result and texture == result.textures[1], "body texture applied")
	check(count >= 4, "body wears the colour layers (" .. count .. " layers)")
	for slot, layer in pairs(layers) do
		check(texture:find(layer, 1, true) ~= nil, "body: " .. slot .. " layer present")
	end
	log("body texture " .. #texture .. " chars, " .. count .. " colour layers")
	core.after(1, function()
		local wield = entity._grug_wield_obj
		local item = wield and wield:get_properties().wield_item or ""
		check(item:find("_ench.png", 1, true) ~= nil,
			"NPC weapon_colors: the held dagger is coloured: " .. item)
		object:remove()
		done()
	end)
end

local function stage_king(done)
	-- 3b. A real king holds his weapon in his fixed colours. He stands on a
	-- probe floor, so he does not fall out of the loaded block.
	for x = -6, 0 do
		for z = -3, 3 do
			core.set_node({x = POS.x + x, y = POS.y - 1, z = POS.z + z}, {name = "default:stone"})
		end
	end
	local object = core.add_entity(vector.add(POS, {x = -3, y = 0, z = 0}), "grug_mobs:king_human")
	check(object ~= nil, "king added")
	if not object then return done() end
	local tries = 0
	local function poll()
		tries = tries + 1
		local entity = object:get_luaentity()
		local wield = entity and entity._grug_wield_obj
		local item = wield and wield:get_properties().wield_item or ""
		if item ~= "" or tries > 10 then
			log(("king: entity %s, skin %s, wield %s"):format(tostring(entity ~= nil),
				tostring(entity and entity._grug_visual_skin and #entity._grug_visual_skin),
				tostring(wield ~= nil)))
			check(item:find("_ench.png", 1, true) ~= nil, "king's sword is coloured: " .. item)
			if entity then object:remove() end
			return done()
		end
		core.after(1, poll)
	end
	poll()
end

core.register_on_mods_loaded(function()
	core.after(3, function()
		core.forceload_block(POS, true)
		core.emerge_area(vector.subtract(POS, 16), vector.add(POS, 16), function(_, _, left)
			if left > 0 then return end
			core.after(2, function()
				local ok, err = pcall(function()
					local sword = stage_items()
					stage_drop(sword, function()
						stage_body(function()
							stage_king(finish)
						end)
					end)
				end)
				if not ok then
					check(false, "probe error: " .. tostring(err))
					finish()
				end
			end)
		end)
	end)
end)
