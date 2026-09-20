-- Check the production banner's face coverage using pinned nodebox UV rules.
return function(repo)
	local definitions = {}
	local environment = setmetatable({
		core = {
			register_node = function(name, def) definitions[name:gsub("^:", "")] = def end,
			get_modpath = function(name)
				assert(name == "grug_nodes")
				return repo .. "/mods/ITEMS/grug_nodes"
			end,
		},
		grug_materials = {natural_groups = function(groups) return groups end},
		default = {
			node_sound_dirt_defaults = function() return {} end,
			node_sound_wood_defaults = function() return {} end,
			node_sound_gravel_defaults = function() return {} end,
		},
	}, {__index = _G})
	local production = assert(loadfile(repo .. "/mods/ITEMS/grug_nodes/init.lua"))
	setfenv(production, environment)
	production()
	local banner = assert(definitions["grug_nodes:guard_banner"])
	assert(banner.drawtype == "nodebox" and banner.use_texture_alpha == "clip")
	assert(banner.groups.grug_camp == 1 and banner.drop == "" and not banner.walkable)

	-- Read the authored atlas rather than duplicating its transparent regions.
	local file = assert(io.open(repo .. "/tools/gen_mob_item_textures.py", "rb"))
	local source = file:read("*a")
	file:close()
	local art = assert(source:match('GUARD_BANNER = """\n(.-)\n"""'))
	local rows = {}
	for row in art:gmatch("[^\n]+") do
		assert(#row == 16)
		rows[#rows + 1] = row
	end
	assert(#rows == 16)
	local texture = "grug_nodes_guard_banner.png"
	local function sample(tile, u, v)
		local x, y = math.floor(u * 16), math.floor(v * 16)
		if tile == texture .. "^[transformFX" then
			x = 15 - x
		elseif tile == texture .. "^[sheet:16x16:7,8" then
			x, y = 7, 8
		else
			assert(tile == texture, "unsupported banner texture modifier")
		end
		return rows[y + 1]:sub(x + 1, x + 1)
	end
	-- content_mapblock.cpp generateCuboidTextureCoords: up/down/right/left/back/front.
	local function face_uv(box)
		local x1, y1, z1 = box[1] + 0.5, box[2] + 0.5, box[3] + 0.5
		local x2, y2, z2 = box[4] + 0.5, box[5] + 0.5, box[6] + 0.5
		return {
			{x1, 1 - z2, x2, 1 - z1}, {x1, z1, x2, z2},
			{z1, 1 - y2, z2, 1 - y1}, {1 - z2, 1 - y2, 1 - z1, 1 - y1},
			{1 - x2, 1 - y2, 1 - x1, 1 - y1}, {x1, 1 - y2, x2, 1 - y1},
		}
	end
	local count = 0
	for _, box in ipairs(banner.node_box.fixed) do
		for face, uv in ipairs(face_uv(box)) do
			local tile = banner.tiles[math.min(face, #banner.tiles)]
			for row = 0, 15 do
				for col = 0, 15 do
					local u = uv[1] + (uv[3] - uv[1]) * (col + 0.5) / 16
					local v = uv[2] + (uv[4] - uv[2]) * (row + 0.5) / 16
					assert(sample(tile, u, v) ~= ".", "transparent banner face " .. face)
					count = count + 1
				end
			end
		end
	end
	-- At the same world-space X/Y, front and back must show the same cloth pixel.
	for y = 1, 7 do
		for x = 10, 14 do
			local u, v = (x + 0.5) / 16, (y + 0.5) / 16
			assert(sample(banner.tiles[5], 1 - u, v) == sample(banner.tiles[6], u, v))
		end
	end
	return "banner_faces\t" .. count .. "\topaque\tfront_back_match\n"
end
