-- Under One Roof. Drafts use the active tiles with a pale stone wash and
-- ^[opacity:150. Set use_texture_alpha = "blend" on draft nodes.
local prefix = "grug_housing_stone_"
local draft_finish = "^[colorize:#b6b7a8:92^[opacity:150"

local function variant(kind, boxes)
	local shape = {type = "fixed", fixed = boxes}
	local base = prefix .. kind .. "_"
	local item = base .. "item.png"

	local function node(state, finish)
		local wall = base .. state .. "_"
		return {
			node_box = shape,
			selection_box = shape,
			collision_box = shape,
			-- Engine order: +Y, -Y, +X, -X, +Z, -Z. The doors face -Z.
			tiles = {
				base .. "top.png" .. finish,
				prefix .. "bottom.png" .. finish,
				wall .. "right.png" .. finish,
				wall .. "left.png" .. finish,
				wall .. "back.png" .. finish,
				wall .. "front.png" .. finish,
			},
		}
	end

	local active = node("active", "")
	return {
		active = active,
		empty = node("empty", ""),
		draft = node("active", draft_finish),
		inventory_image = item,
		wield_image = item,
		marker_texture = active.tiles[6],
	}
end

-- Both carvings stand on the same sill. The timber beam and the first
-- roof course share a footprint, so one box carries both materials.
local sill = {-0.5, -0.5, -0.4375, 0.5, -0.375, 0.4375}
local walls = {-0.4375, -0.375, -0.3125, 0.4375, 0, 0.3125}

return {
	[""] = variant("personal", {
		sill, walls,
		{-0.5, 0, -0.375, 0.5, 0.1875, 0.375},
		{-0.375, 0.1875, -0.375, 0.375, 0.3125, 0.375},
		{-0.25, 0.3125, -0.375, 0.25, 0.4375, 0.375},
		{-0.125, 0.4375, -0.375, 0.125, 0.5, 0.375},
		-- Chimney shaft and cap.
		{0.25, 0.3125, 0.0625, 0.375, 0.4375, 0.25},
		{0.1875, 0.4375, 0, 0.4375, 0.5, 0.3125},
	}),
	account = variant("account", {
		sill, walls,
		{-0.5, 0, -0.375, 0.5, 0.125, 0.375},
		-- Three courses above each half of the shared beam.
		{-0.4375, 0.125, -0.375, -0.0625, 0.25, 0.375},
		{-0.375, 0.25, -0.375, -0.125, 0.375, 0.375},
		{-0.3125, 0.375, -0.375, -0.1875, 0.4375, 0.375},
		{0.0625, 0.125, -0.375, 0.4375, 0.25, 0.375},
		{0.125, 0.25, -0.375, 0.375, 0.375, 0.375},
		{0.1875, 0.375, -0.375, 0.3125, 0.4375, 0.375},
	}),
}
