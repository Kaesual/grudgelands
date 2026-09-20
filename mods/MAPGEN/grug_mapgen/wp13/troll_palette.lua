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
--   * `BASALT` rebinds the WALL and the castle vocabulary to stone and leaves
--     the ROOF timber. Two buildings carry it -- the king's hall and the moot
--     house -- and they are the pair the contract's troll row is about: "stilt
--     halls on BASALT platforms, JUNGLEWOOD walkways". The platform and the
--     walls are basalt; what is over them is wood.
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

	-- The civic handle: basalt walls under the capital's ordinary junglewood
	-- roof.
	--
	-- THE CASTLE ROLES ARE PART OF IT. The independent review of 2026-09-16
	-- read the king's hall as "a red-brick manor with a timber roof", and the
	-- brick is `grug_decor:castle_pavement_brick` and `castle_stonewall`:
	-- `capitals.king_hall` dresses itself in the CAPITAL vocabulary, not in
	-- `wall`, so rebinding the wall alone changed nothing the eye sees. Those
	-- four rebindings put the hall, its turrets and its podium in the same rock
	-- its platform is made of, and they stay.
	--
	-- THE ROOF STAYS TIMBER, AND THAT IS NOW A CHOICE RATHER THAN A LIMIT.
	-- Until 2026-09-16 it was a limit: `roofs.raster` turns a hip with
	-- `roof_stair_outer` and a valley with `roof_stair_inner`, and
	-- `wp13/parts.lua`'s SHAPED table -- the library's one written-down list of
	-- the nodes that may carry a facedir -- carried the straight basalt stair
	-- and the basalt slab but not the two corners, so binding the basalt roof
	-- family failed at construction time with "has no paramtype2". `grug_decor`
	-- had registered all four shapes since the darkage import
	-- (`mods/ITEMS/grug_decor/darkage.lua` runs every name of its `shaped` list
	-- through `register_shapes`); only the library's list was short. The wave-3
	-- polish lane added the two corner names to SHAPED, append-only and in its
	-- own commit, so the family CAN be bound now.
	--
	-- IT IS NOT, and both reasons are recorded because the decision is the
	-- user's to reverse. The variant was built and rendered
	-- (`tools/wp13/evidence/20260916-polish/renders/kings-hall-{before,after}.png`)
	-- and BOTH the lane and the independent review read the all-basalt hall the
	-- same way: roof, walls, turrets, podium and plinth in one basalt texture,
	-- so the building loses its silhouette and reads as an undifferentiated
	-- dark mass, while the timber roof gives it a legible ridge and eaves. And
	-- the capitals contract's troll row names the wood outright -- "stilt halls
	-- on basalt platforms, JUNGLEWOOD walkways, totem posts, cauldron courts,
	-- emergent trees kept" (section 2.4) -- so a timber roof over a basalt hall
	-- is what the contract asks for rather than a compromise.
	--
	-- TO TURN IT ON, and this is the honest cost rather than "one table": add
	-- the five `roof_*` lines below to this table AND move `kezamba_kat`'s
	-- section 6 back to asserting an all-basalt roof (it asserts the library
	-- gap and the roof family's completeness instead, which is what holds for
	-- either binding). The Kezamba core digest moves to
	-- ef258e33b9e62cefaf4baabf0df2fd1340baa872519f36b0b8be3bcfa487165a; the
	-- `parts.lua` SHAPED entries stay either way.
	--
	--     roof_stair       = "grug_decor:darkage_basalt_stair",
	--     roof_stair_outer = "grug_decor:darkage_basalt_stair_outer",
	--     roof_stair_inner = "grug_decor:darkage_basalt_stair_inner",
	--     roof_slab        = "grug_decor:darkage_basalt_slab",
	--     roof_ridge       = "grug_decor:darkage_basalt",
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

	-- THE CROP HANDLE, and the playtest finding it answers.
	--
	-- Playtest 5 (2026-09-16, user): "Fields in Kezamba grow 'Mossy Stone'?
	-- That cannot be right."
	--
	-- Two separate things made that true and neither of them was a crop.
	-- `dressing.crop_rows` falls back to `ground_patch` and `planter_soil` for
	-- a race that binds neither `crop_soil` nor `crop`, and for the troll
	-- palette BOTH of those are `grug_nodes:mud`: the three crop fields were
	-- a rectangle of bare mud with nothing growing in it at all. And
	-- `dressing.planter` kerbs a bed in `planter`, which for this palette is
	-- `default:mossycobble`, so `kezamba_districts.lua`'s one-row terraces --
	-- a bed of depth one is all kerb and no interior -- laid eight solid rows
	-- of mossy cobble across each vineyard. That is the stone the user saw,
	-- and §3 of the districts file is where it is fixed; this handle is the
	-- other half.
	--
	-- `crop` IS PAPYRUS, which is a reed and is what a troll basin grows.
	-- It is registered by `default` (`mods/BASE/default/nodes.lua`), it is
	-- already in `wp40/r7_content.lua`'s accepted content rows so the content
	-- channel resolves it without a new name, and it carries none of the
	-- `META_FIELDS` a VoxelManip-written cell cannot serve (its only callback
	-- is `after_dig_node`, which runs on dig).
	--
	-- `crop_soil` IS TILLED SOIL, for the reason the human palette records and
	-- for a second one this race adds. The first: `grug_farming:soil`
	-- carries no `spreading_dirt_type` and is not named by default's "Grass
	-- spread" ABM, so a field stays a field. The second: default's "Grow
	-- papyrus" ABM lifts a reed to four nodes only when the node UNDER it is
	-- one of the six `default:dirt*` surfaces (`default/functions.lua`,
	-- `grow_papyrus`) -- tilled soil is not one of them, so these rows stay
	-- the one course the blueprint drew and the field the KAT measured is the
	-- field the player walks past a week later. Mud would have been the
	-- prettier furrow for a flooded basin and it is what `ground_patch`
	-- already lays everywhere else; it is not bound here because it is the
	-- role the fallback used, and the whole point is that a FIELD must read
	-- differently from the ground beside it.
	M.CROP = {
		crop_soil = "grug_farming:soil",
		crop = "default:papyrus",
	}

	-- THE VINE HANDLE: what a raised bed grows.
	--
	-- `dressing.planter` is the shared library's raised bed and it fills its
	-- interior from two fixed ROLES -- `fern` for one cell in three and
	-- `grass_tuft` for the rest -- which for the troll race are
	-- `default:fern_1` and `default:grass_1`. So the first version of the crop
	-- round left `shore_vineyard` and `vine_terraces` growing wild grass in mud
	-- and the independent review of 2026-09-16 called it "the weaker half of
	-- the crop answer": the stone was gone, but a plot named a vineyard was a
	-- weed patch.
	--
	-- Rebinding the two roles for THESE TWO PLOTS ONLY is the whole fix, and it
	-- needs no change to the shared dressing. `default:junglegrass` is the tall
	-- leafy growth of this race's own jungle, it is what the troll palette
	-- already binds `undergrowth` to, it is registered by `default`
	-- (`nodes.lua:1450`) and carries no callback bulk placement skips, and the
	-- KAT's `tend` and `forage` feature sets already accept it through
	-- `undergrowth` -- so the two garden sockets keep facing something the
	-- sockets contract calls a plant.
	--
	-- BOTH roles, not one. A bed of a single crop reads as cultivation and a
	-- mix of two wild species reads as the weed patch the review named; the
	-- alternation `dressing.planter` does between them is variety a hedgerow
	-- wants and a vineyard does not. The FIELDS keep papyrus (`M.CROP`), so the
	-- two kinds of planted ground still read apart from one another.
	M.VINE = {
		fern = "default:junglegrass",
		grass_tuft = "default:junglegrass",
	}

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
