-- Original wall art. Static meshes: no entities, inventories or timers.
local catalog = dofile(core.get_modpath("grug_decor") .. "/paintings_catalog.lua")

local function solid_wall(pos)
	local node = core.get_node_or_nil(pos)
	local def = node and core.registered_nodes[node.name]
	return def and def.walkable ~= false and not def.buildable_to and
		(def.drawtype == nil or def.drawtype == "normal")
end

local function place(size)
	return function(stack, placer, pointed)
		local clicked = grug_core.node_rightclick(stack, placer, pointed)
		if clicked then return clicked end
		if not placer or not pointed or pointed.type ~= "node" then return stack end
		local back = vector.subtract(pointed.under, pointed.above)
		if back.y ~= 0 or math.abs(back.x) + math.abs(back.z) ~= 1 then return stack end
		local param2 = core.dir_to_facedir(back)
		-- Local +X for horizontal facedir 0,1,2,3.
		local right = {x = back.z, y = 0, z = -back.x}
		local name = placer:get_player_name()
		for x = 0, size - 1 do
			for y = 0, size - 1 do
				local p = {x = pointed.above.x + x * right.x,
					y = pointed.above.y + y, z = pointed.above.z + x * right.z}
				local node = core.get_node_or_nil(p)
				local def = node and core.registered_nodes[node.name]
				if not def or not def.buildable_to or not solid_wall(vector.add(p, back)) then
					return stack
				end
				if core.is_protected(p, name) then
					core.record_protection_violation(p, name)
					return stack
				end
			end
		end
		return core.item_place_node(stack, placer, pointed, param2)
	end
end

for _, row in ipairs(catalog) do
	local size = row.size
	local texture = "grug_decor_painting_" .. row.id .. ".png"
	local description = row.title .. " (" .. size .. " x " .. size .. " Painting)"
	if row.id == "trade_map" then description = description .. "\nDecorative map; not for navigation" end
	core.register_node("grug_decor:painting_" .. row.id, {
		description = description,
		drawtype = "mesh", mesh = "grug_decor_painting_" .. size .. ".obj",
		tiles = {"default_wood.png", texture}, inventory_image = texture,
		wield_image = texture, paramtype = "light", paramtype2 = "facedir",
		use_texture_alpha = "opaque", sunlight_propagates = true, walkable = false,
		selection_box = {type = "fixed", fixed = {-.46, -.46, .43, size-.54, size-.54, .495}},
		groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 2, attached_node = 2},
		is_ground_content = false, sounds = default.node_sound_wood_defaults(),
		on_place = place(size), on_rotate = function() return false end,
		_grug_decor_mount = "wall", _grug_decor_family = row.expedition and "A03" or
			(row.id == "trade_map" and "A05" or (row.id == "charter" or row.id == "tavern") and "A04" or
			(size == 1 and "A02" or "A01")),
	})
end
