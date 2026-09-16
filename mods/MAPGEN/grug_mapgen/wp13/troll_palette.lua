-- Kezamba's palette handles: the troll start palette with the capital's own
-- rebindings on top of it.
--
-- `wp13/palette.lua` is the shared library and not this lane's to edit, and it
-- does not have to be: `palettes.new(race, overrides)` rebinds any DECLARED
-- role on top of a race, and every role below is already declared there. So
-- this file is a table of overrides and nothing else, which is the wave-2 rule
-- for extending the library ("NEW files named wp13/<race>_*.lua that register
-- into the existing registries at load").
--
-- Three handles, and each one exists because a building that used the one
-- before it read wrong:
--
--   * `TIMBER` is the plain troll palette -- junglewood walls, basalt footings,
--     rainforest litter -- and is what the houses, the yards and the streets
--     are built from.
--   * `BASALT` rebinds the WALL, the castle vocabulary and, since 2026-09-16,
--     the ROOF to stone. Two buildings carry it -- the king's hall and the moot
--     house -- and they are the pair the contract's troll row is about: "stilt
--     halls on BASALT platforms". The platform is basalt and so, now, is what
--     stands on it.
--   * `WATER` adds the one optional role the troll palette has never needed:
--     `default:river_water_source`, for the two authored basins of the fill.
--     It is river water and not ordinary water for the reason the Highcourt
--     fill records: `liquid_renewable = false` and `liquid_range = 2`
--     (mods/BASE/default/nodes.lua), so a player who digs the liner out floods
--     two nodes of bank and not the district below.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader()
	local M = {}

	-- The civic handle: basalt walls, and since 2026-09-16 a BASALT ROOF over
	-- them.
	--
	-- THE CASTLE ROLES ARE PART OF IT. The independent review of 2026-09-16
	-- read the king's hall as "a red-brick manor with a timber roof", and the
	-- brick is `grug_decor:castle_pavement_brick` and `castle_stonewall`:
	-- `capitals.king_hall` dresses itself in the CAPITAL vocabulary, not in
	-- `wall`, so rebinding the wall alone changed nothing the eye sees. Those
	-- four rebindings put the hall, its turrets and its podium in the same rock
	-- its platform is made of.
	--
	-- THE ROOF USED TO STAY TIMBER, and the reason was mechanical rather than a
	-- taste. `roofs.raster` turns a hip with `roof_stair_outer` and a valley
	-- with `roof_stair_inner`, and `wp13/parts.lua`'s SHAPED table -- the
	-- library's one written-down list of the nodes that may carry a facedir --
	-- carried the straight basalt stair and the basalt slab but not the two
	-- corners, so binding the basalt roof family failed at construction time
	-- with "has no paramtype2". `grug_decor` had registered all four shapes
	-- since the darkage import (`mods/ITEMS/grug_decor/darkage.lua` runs every
	-- name of its `shaped` list through `register_shapes`); only the library's
	-- list was short. The wave-3 polish lane added the two corner names to
	-- SHAPED, append-only and in its own commit, so the family can be bound now
	-- and is.
	--
	-- What that changes, measured on the king's hall (23 x 23, rise 6, this
	-- handle, 22937 cells before and after): 600 straight stairs, 12 outer
	-- stairs and 27 slabs swap junglewood for basalt, and the hall stops being
	-- the one building in Kezamba whose roof disagrees with its walls. The six
	-- junglewood stairs that remain are the `seat` role, which is furniture.
	-- This hall's roof has no valley and no flat cap, so `roof_stair_inner` and
	-- `roof_ridge` are bound and not emitted by it; they are bound anyway
	-- because `roofs.raster` reads all four off the palette, and any L-shaped
	-- or flat-capped basalt roof after this one needs them.
	--
	-- THE CONTRACT'S TROLL ROW is "stilt halls on basalt platforms, junglewood
	-- walkways, totem posts, cauldron courts, emergent trees kept" (capitals
	-- contract section 2.4). The walkways, the lanes, the aprons and every
	-- house outside this handle stay junglewood: only the two buildings that
	-- carry the handle are rock all the way up, which is what makes them read
	-- as the civic pair.
	M.BASALT = {
		wall = "grug_decor:darkage_basalt",
		wall_accent = "grug_decor:darkage_basalt_brick",
		castle_wall = "grug_decor:darkage_basalt",
		castle_wall_stair = "grug_decor:darkage_basalt_stair",
		castle_wall_slab = "grug_decor:darkage_basalt_slab",
		castle_paving = "grug_decor:darkage_basalt_brick",
		roof_stair = "grug_decor:darkage_basalt_stair",
		roof_stair_outer = "grug_decor:darkage_basalt_stair_outer",
		roof_stair_inner = "grug_decor:darkage_basalt_stair_inner",
		roof_slab = "grug_decor:darkage_basalt_slab",
		roof_ridge = "grug_decor:darkage_basalt",
	}

	-- The water handle, for the fill's own basins.
	M.WATER = {water = "default:river_water_source"}

	-- Both at once, for a civic building that also owns a basin.
	function M.merged(...)
		local out = {}
		for _, source in ipairs({...}) do
			for role, name in pairs(source) do out[role] = name end
		end
		return out
	end

	return M
end

return loader
