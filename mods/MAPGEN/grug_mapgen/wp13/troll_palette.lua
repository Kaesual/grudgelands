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
--   * `BASALT` rebinds the WALL and the roof to stone, for the four civic
--     buildings that stand on the cenote's shore. The contract's troll row is
--     "stilt halls on BASALT platforms": the platform is basalt and the hall on
--     it is timber, but the king's hall, the shrine and the moot are the
--     buildings the platform idea is about and they carry the rock up into
--     their walls.
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

	-- The civic handle: basalt WALLS under the capital's ordinary junglewood
	-- roof.
	--
	-- THE ROOF STAYS TIMBER, and that is a decision with a measurement behind
	-- it rather than a taste. `grug_decor` registers the full four-shape family
	-- for basalt, but `wp13/parts.lua`'s own `SHAPED` table -- the library's
	-- one written-down list of the nodes that may carry a facedir -- lists only
	-- `darkage_basalt_stair` and `darkage_basalt_slab`, not the inner and outer
	-- corners the roof rasteriser needs for a hip or a gable end. Binding the
	-- basalt roof family therefore fails at construction time with "has no
	-- paramtype2", and `parts.lua` is the shared library this lane may not
	-- edit. A timber roof on a basalt wall is also the better building: the
	-- contract's troll row is "stilt halls on BASALT PLATFORMS", which is a
	-- statement about what a hall stands on, not about what it is roofed with.
	-- THE CASTLE ROLES GO WITH IT. The independent review of 2026-09-16 read
	-- the king's hall as "a red-brick manor with a timber roof", and the brick
	-- is `grug_decor:castle_pavement_brick` and `castle_stonewall`:
	-- `capitals.king_hall` dresses itself in the CAPITAL vocabulary, not in
	-- `wall`, so rebinding the wall alone changed nothing the eye sees. These
	-- four rebindings put the hall, its turrets and its podium in the same rock
	-- its platform is made of.
	--
	-- Only shapes `wp13/parts.lua`'s `SHAPED` table carries may be bound: it
	-- lists `darkage_basalt_stair` and `darkage_basalt_slab` and NOT the inner
	-- and outer corners, so the single stairs and slabs of the castle kit are
	-- safe and the roof family (which the rasteriser turns corners with) stays
	-- timber. That is the same limit §7.5 of the note records.
	M.BASALT = {
		wall = "grug_decor:darkage_basalt",
		wall_accent = "grug_decor:darkage_basalt_brick",
		castle_wall = "grug_decor:darkage_basalt",
		castle_wall_stair = "grug_decor:darkage_basalt_stair",
		castle_wall_slab = "grug_decor:darkage_basalt_slab",
		castle_paving = "grug_decor:darkage_basalt_brick",
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
