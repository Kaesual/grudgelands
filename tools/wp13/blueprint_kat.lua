-- Compact architectural acceptance, usable in the final interpreter pair.
--
-- Checks the generator invariants of
-- docs/research/wp13-settlement-pipeline.md section 5 against every finished
-- WP13 start blueprint, without loading the engine.
--
-- The invariants are the same for every settlement; the node vocabulary is
-- not, so each start carries a spec naming the nodes an ordinary walk passes
-- through, the nodes a doorstep may stand on, the roof family, the tree
-- species and the ground mix its identity depends on. Adding a start means
-- adding a spec, not a second copy of the checks.
return function(repo)
	local SETTLEMENTS = {
		{
			key = "hearthpine",
			file = "r7_hearthpine_blueprint.lua",
			schema = "grug_wp13_hearthpine_blueprint_v1",
			light = {"default:torch", "default:torch_wall"},
			passable = {"air", "default:torch", "default:torch_wall",
				"default:grass_1", "default:fern_1", "default:fern_2",
				"doors:door_wood_a", "doors:door_wood_b", "doors:hidden"},
			paved = {"default:cobble", "default:stone_block",
				"default:stonebrick"},
			-- Both roof materials: the forge hall and the community hall carry
			-- the stone-brick stair family, the rest pine.
			roof = {"stairs:stair_pine_wood", "stairs:stair_outer_pine_wood",
				"stairs:stair_inner_pine_wood", "stairs:slab_pine_wood",
				"stairs:stair_stonebrick", "stairs:stair_outer_stonebrick",
				"stairs:stair_inner_stonebrick", "stairs:slab_stonebrick"},
			door_leaves = {"doors:door_wood_a", "doors:door_wood_b"},
			tree = {log = "default:pine_tree", leaves = "default:pine_needles",
				min_trunk = 5, reach = 2, low = 4, high = 1, min_stems = 40},
			ground = {{"default:dirt_with_coniferous_litter", 8000},
				{"default:dirt_with_grass", 100}, {"default:dirt", 50}},
			min_destinations = 9, min_doors = 8, min_rooms = 9,
			min_lights = 8, min_oriented = 8,
			-- Hearthpine carries no cart, bale, stepping stone or wheel; its
			-- barrels are the ones its interiors' kits stand on the floor.
			props = {{"grug_decor:cottages_straw_bale", 0},
				{"grug_decor:xdecor_barrel", 39},
				{"grug_decor:xdecor_stonepath", 0},
				{"grug_decor:cottages_wagon_wheel", 0, "wallmounted"}},
			carts = 0,
		},
		{
			key = "dawnmere",
			file = "r7_dawnmere_blueprint.lua",
			schema = "grug_wp13_dawnmere_blueprint_v1",
			light = {"default:torch", "default:torch_wall"},
			-- `grug_decor:cottages_straw_mat` is the ONE entry here that is
			-- not a plant, a torch or a door: it is a floor mat registered
			-- `walkable = false` with a nodebox a few pixels high, so a player
			-- walks over it exactly as over the boards beside it. Treating it
			-- as solid would wall off the bed alcoves it lies in and make this
			-- fixture's route and doorway tests report rooms as unreachable
			-- that the engine lets anyone walk into. Every other permissive
			-- name in this list is passable in the engine for the obvious
			-- reason; no other decor node may be added without the same
			-- `walkable = false` evidence.
			passable = {"air", "default:torch", "default:torch_wall",
				"default:grass_3", "default:grass_4", "default:junglegrass",
				"default:fern_1", "grug_decor:cottages_straw_mat",
				"doors:door_wood_a", "doors:door_wood_b", "doors:hidden"},
			paved = {"default:cobble", "default:brick"},
			roof = {"stairs:stair_wood", "stairs:stair_outer_wood",
				"stairs:stair_inner_wood", "stairs:slab_wood",
				"stairs:stair_brick", "stairs:stair_outer_brick",
				"stairs:stair_inner_brick", "stairs:slab_brick"},
			door_leaves = {"doors:door_wood_a", "doors:door_wood_b"},
			tree = {log = "default:tree", leaves = "default:leaves",
				min_trunk = 4, reach = 3, low = 1, high = 4, min_stems = 8},
			ground = {{"default:dirt_with_grass", 6000},
				{"default:dirt", 400}, {"default:gravel", 20}},
			min_destinations = 9, min_doors = 8, min_rooms = 9,
			min_lights = 8, min_oriented = 8,
			-- The farming hamlet's loose props, exactly. 27 bales: four yard
			-- stacks of two, three and two, plus the barn kit's seven columns.
			-- 24 barrels: three cart loads and the interiors' own. 25 stepping
			-- stones over the green's turf. 12 wheels: two on each of the
			-- three hand carts, four leaning on the barn and the inn, two in
			-- the barn's kit.
			props = {{"grug_decor:cottages_straw_bale", 27},
				{"grug_decor:xdecor_barrel", 24},
				{"grug_decor:xdecor_stonepath", 25},
				{"grug_decor:cottages_wagon_wheel", 12, "wallmounted"}},
			carts = 3, cart_load = "grug_decor:xdecor_barrel",
		},
		{
			key = "silverleaf",
			file = "r7_silverleaf_blueprint.lua",
			schema = "grug_wp13_silverleaf_blueprint_v1",
			light = {"grug_decor:xdecor_candle",
				"grug_decor:xdecor_lantern_hanging",
				"grug_materials:emberglass_lamp"},
			-- The elf lamps are not all wallmounted, so this start says how
			-- each of its lights is carried; see `light_carrier` below.
			light_support = {
				["grug_decor:xdecor_lantern_hanging"] = "above",
				["grug_materials:emberglass_lamp"] = "self",
			},
			passable = {"air", "grug_decor:xdecor_candle",
				"grug_decor:xdecor_lantern_hanging",
				"grug_decor:xdecor_potted_viola",
				"grug_decor:xdecor_potted_dandelion_white",
				"default:grass_2", "default:fern_2", "default:fern_3",
				"doors:door_wood_a", "doors:door_wood_b", "doors:hidden"},
			paved = {"grug_decor:darkage_marble_tile",
				"grug_decor:darkage_slate_tile", "grug_decor:darkage_marble",
				"grug_decor:darkage_serpentine"},
			-- Two roof materials: the shrine, the lore hall and the gate
			-- lookout carry the pale silver sandstone brick family, every
			-- domestic roof the darkage slate tile one.
			roof = {"grug_decor:darkage_slate_tile_stair",
				"grug_decor:darkage_slate_tile_stair_outer",
				"grug_decor:darkage_slate_tile_stair_inner",
				"grug_decor:darkage_slate_tile_slab",
				"stairs:stair_silver_sandstone_brick",
				"stairs:stair_outer_silver_sandstone_brick",
				"stairs:stair_inner_silver_sandstone_brick",
				"stairs:slab_silver_sandstone_brick"},
			door_leaves = {"doors:door_wood_a", "doors:door_wood_b"},
			tree = {log = "grug_trees:silverwood_tree",
				leaves = "grug_trees:silverwood_leaves",
				min_trunk = 9, reach = 2, low = 5, high = 1, min_stems = 40},
			ground = {{"grug_nodes:dirt_with_silver_litter", 8000},
				{"default:dirt_with_grass", 100}, {"default:dirt", 20}},
			min_destinations = 9, min_doors = 8, min_rooms = 9,
			min_lights = 8, min_oriented = 8,
			-- The glade's loose props, exactly. No straw, no cart and no
			-- wheel: this settlement carries none. 20 barrels are the ones
			-- the interiors' kits and the four crate stacks stand on the
			-- floor, and 24 stepping stones are the six four-cell runs off
			-- the paving into the litter.
			props = {{"grug_decor:cottages_straw_bale", 0},
				{"grug_decor:xdecor_barrel", 20},
				{"grug_decor:xdecor_stonepath", 24},
				{"grug_decor:cottages_wagon_wheel", 0, "wallmounted"}},
			carts = 0,
		},
		{
			key = "stillgrave",
			file = "r7_stillgrave_blueprint.lua",
			schema = "grug_wp13_stillgrave_blueprint_v1",
			light = {"default:torch", "grug_decor:xdecor_candle"},
			passable = {"air", "default:torch", "grug_decor:xdecor_candle",
				"default:dry_shrub", "grug_nodes:bone_pile",
				"grug_decor:xdecor_cobweb", "grug_decor:xdecor_ivy",
				"doors:door_steel_a", "doors:door_steel_b", "doors:hidden"},
			paved = {"default:mossycobble", "default:obsidianbrick",
				"grug_decor:castle_pavement_brick"},
			-- Both roof materials: the hamlet is obsidian brick, the
			-- crypt-chapel alone carries the pale stone-brick family.
			roof = {"stairs:stair_obsidianbrick",
				"stairs:stair_outer_obsidianbrick",
				"stairs:stair_inner_obsidianbrick", "stairs:slab_obsidianbrick",
				"stairs:stair_stonebrick", "stairs:stair_outer_stonebrick",
				"stairs:stair_inner_stonebrick", "stairs:slab_stonebrick"},
			door_leaves = {"doors:door_steel_a", "doors:door_steel_b"},
			tree = {log = "grug_trees:gravewood_tree",
				leaves = "grug_trees:gravewood_leaves",
				min_trunk = 5, reach = 3, low = 3, high = 1, min_stems = 40},
			ground = {{"grug_nodes:blight_dirt", 6000},
				{"grug_nodes:dirt_with_bone_litter", 1000},
				{"default:gravel", 20}},
			min_destinations = 5, min_doors = 6, min_rooms = 8,
			min_lights = 8, min_oriented = 8,
			-- The Hollow's loose props, exactly. 18 stepping stones worn over
			-- the court paving. 14 barrels: five crate stacks and the
			-- interiors' own. 13 ivy tendrils on the two ruins' standing
			-- walls. No bale, no wheel and no hand cart: nothing here is
			-- carted anywhere. The cobweb is deliberately absent from this
			-- list -- it is the one prop in the corpus that SHOULD hang with
			-- nothing under it, and the check below is a floating-prop check.
			--
			-- 418 low walls: the ten burial-ground runs (164 cells once the
			-- shared corners are counted once), the grave markers inside
			-- them, the six kerbed court plots, the gate's two flanking runs
			-- and the cairn's four corner blocks. Six of the ten runs used to
			-- be dropped in silence when an earlier run had claimed their
			-- corner, and NOTHING here noticed -- a burial ground open on
			-- three sides passes every geometric invariant in this file. An
			-- exact population is what catches that class of defect.
			props = {{"grug_decor:cottages_straw_bale", 0},
				{"grug_decor:xdecor_barrel", 14},
				{"grug_decor:xdecor_stonepath", 18},
				{"walls:mossycobble", 418},
				{"grug_decor:xdecor_ivy", 13, "wallmounted"},
				{"grug_decor:cottages_wagon_wheel", 0, "wallmounted"}},
			carts = 0,
		},
		{
			key = "sunscar",
			file = "r7_sunscar_blueprint.lua",
			schema = "grug_wp13_sunscar_blueprint_v1",
			light = {"default:torch", "default:torch_wall"},
			passable = {"air", "default:torch", "default:torch_wall",
				"default:dry_grass_3", "default:dry_grass_5",
				"default:dry_shrub", "grug_decor:cottages_straw_mat",
				"doors:door_wood_a", "doors:door_wood_b", "doors:hidden"},
			paved = {"default:desert_cobble", "default:desert_sand",
				"default:desert_stone_block"},
			-- One roof family: every deck in the camp is the desert
			-- stonebrick stair family, flat, behind a breastwork.
			roof = {"stairs:stair_desert_stonebrick",
				"stairs:stair_outer_desert_stonebrick",
				"stairs:stair_inner_desert_stonebrick",
				"stairs:slab_desert_stonebrick"},
			door_leaves = {"doors:door_wood_a", "doors:door_wood_b"},
			tree = {log = "default:acacia_tree",
				leaves = "default:acacia_leaves",
				min_trunk = 5, reach = 3, low = 1, high = 2, min_stems = 20},
			ground = {{"default:dirt_with_dry_grass", 6000},
				{"default:dry_dirt", 400}, {"default:desert_sand", 400}},
			min_destinations = 9, min_doors = 8, min_rooms = 9,
			min_lights = 8, min_oriented = 8,
			-- The camp's loose gear, exactly. 27 bales: eight drill-post
			-- heads, seven in the three yard targets and twelve in the five
			-- feed stacks. 24 barrels: seven crate stacks and the interiors'
			-- own. No stepping stones -- the orc palette binds none. 19
			-- wheels: three on each of the five wagons and four leaning on
			-- walls. 15 wagon loads, one on every bearer of every wagon,
			-- which is also the cart count below.
			props = {{"grug_decor:cottages_straw_bale", 27},
				{"grug_decor:xdecor_barrel", 24},
				{"grug_decor:xdecor_stonepath", 0},
				{"grug_decor:cottages_wagon_wheel", 19, "wallmounted"},
				{"grug_decor:cottages_wagon_load", 15}},
			carts = 15, cart_load = "grug_decor:cottages_wagon_load",
		},
		{
			key = "kapok",
			file = "r7_kapok_blueprint.lua",
			schema = "grug_wp13_kapok_blueprint_v1",
			light = {"default:torch", "default:torch_wall"},
			-- The rope and the lantern really are `walkable = false`, so a
			-- route may pass through them; the window bars are not, so they
			-- stay solid and keep counting as wall.
			passable = {"air", "default:torch", "default:torch_wall",
				"default:grass_1", "default:fern_1", "default:junglegrass",
				"grug_decor:cottages_straw_mat", "grug_decor:xdecor_lantern",
				"grug_decor:xdecor_rope",
				"doors:door_wood_a", "doors:door_wood_b", "doors:hidden"},
			-- A stilt village's doorsteps stand on plank verandas and the
			-- lodge's on its basalt platform, so both count as paving.
			paved = {"default:junglewood", "default:mossycobble",
				"grug_decor:darkage_basalt_brick",
				"grug_decor:darkage_serpentine"},
			roof = {"stairs:stair_junglewood", "stairs:stair_outer_junglewood",
				"stairs:stair_inner_junglewood", "stairs:slab_junglewood"},
			door_leaves = {"doors:door_wood_a", "doors:door_wood_b"},
			-- A jungle tree carries its crown in the top three courses over a
			-- long bare trunk and hangs leaf spurs far below it, and an
			-- emergent's crown stands four courses above its last log, so the
			-- rooting window is deeper and taller than an orchard's.
			tree = {log = "default:jungletree", leaves = "default:jungleleaves",
				min_trunk = 8, reach = 3, low = 10, high = 8, min_stems = 20},
			ground = {{"default:dirt_with_rainforest_litter", 6000},
				{"grug_nodes:mud", 1000}, {"default:dirt", 100}},
			min_destinations = 8, min_doors = 8, min_rooms = 8,
			min_lights = 8, min_oriented = 8,
			-- The stilt village's loose props, exactly. No bale, no cart and
			-- no wheel: nothing here is wheeled. 20 barrels, all of them the
			-- interiors' own. 42 stepping stones where the boardwalk stops.
			-- 56 rope cells: two under each of the sixteen veranda corners,
			-- two under each of the twelve rack lines, and four on the
			-- smoker's drying beam. 16 lanterns under the bridges and the
			-- verandas -- every one of them hanging from the deck above,
			-- which is what `group:attached_node = 3` means.
			props = {{"grug_decor:cottages_straw_bale", 0},
				{"grug_decor:xdecor_barrel", 20},
				{"grug_decor:xdecor_stonepath", 42},
				{"grug_decor:cottages_wagon_wheel", 0, "wallmounted"},
				{"grug_decor:xdecor_rope", 56, "ceiling"},
				{"grug_decor:xdecor_lantern", 16, "ceiling"}},
			carts = 0,
		},
	}

	local function set(list)
		local out = {}
		for _, name in ipairs(list) do out[name] = true end
		return out
	end

	local report = {}
	for _, spec in ipairs(SETTLEMENTS) do
		local build = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/" .. spec.file)
		local blueprint = build()
		assert(blueprint.schema == spec.schema)
		local LIGHT = set(spec.light)
		local PASSABLE = set(spec.passable)
		local PAVED = set(spec.paved)
		local ROOF = set(spec.roof)
		local LEAF = set(spec.door_leaves)
		local cells, names, count, lights, oriented = {}, {}, 0, 0, 0
		local function key(x, y, z) return x .. ":" .. y .. ":" .. z end
		local previous
		for _, cell in ipairs(blueprint.cells) do
			assert(cell.x % 1 == 0 and cell.y % 1 == 0 and cell.z % 1 == 0)
			assert(cell.x >= -63 and cell.x <= 63 and cell.z >= -63 and cell.z <= 63)
			assert(cell.y >= -2 and cell.y <= 24)
			assert(cell.param2 % 1 == 0 and cell.param2 >= 0 and cell.param2 <= 255)
			assert(type(cell.name) == "string" and cell.name ~= "ignore")
			assert(cell.name ~= "grug_nodes:guard_banner" and
				cell.name ~= "grug_nodes:camp_fire", "decorative spawner")
			assert(not cell.name:find("water") and not cell.name:find("lava"))
			local address = key(cell.x, cell.y, cell.z)
			assert(not cells[address], "duplicate blueprint cell")
			if previous then
				assert(previous.z < cell.z or previous.z == cell.z and
					(previous.y < cell.y or previous.y == cell.y and previous.x < cell.x),
					"blueprint order differs")
			end
			previous = cell
			cells[address] = cell.name
			names[cell.name] = true
			if cell.name ~= "air" then count = count + 1 end
			if LIGHT[cell.name] then lights = lights + 1 end
			if cell.param2 ~= 0 then oriented = oriented + 1 end
		end
		assert(#blueprint.cells < 125000 and count > 1000,
			"bounded inhabited architecture")
		assert(lights >= spec.min_lights and oriented >= spec.min_oriented,
			"lighting and shaped architecture missing")
		local palette_count = 0
		for name in pairs(names) do palette_count = palette_count + 1 end
		assert(palette_count == #blueprint.palette)
		for i, name in ipairs(blueprint.palette) do
			assert(names[name] and (i == 1 or blueprint.palette[i - 1] < name))
		end
		local function node(x, y, z)
			return cells[key(x, y, z)] or (y <= 0 and "default:stone" or "air")
		end
		-- Nodes an ordinary walk can pass through. Stairs and slabs count as
		-- whole nodes, which keeps the route check conservative; doors count
		-- as passable, because a player opens them (section 5 invariant 3).
		local function solid(x, y, z)
			return not PASSABLE[node(x, y, z)]
		end
		local function stand(x, y, z)
			return solid(x, y - 1, z) and not solid(x, y, z) and
				not solid(x, y + 1, z)
		end
		-- Luanti's wallmounted direction points from the torch to its support.
		local support_dir = {[0] = {0, 1, 0}, {0, -1, 0}, {1, 0, 0},
			{-1, 0, 0}, {0, 0, 1}, {0, 0, -1}}
		-- How a light is carried. A wallmounted lamp (the default, and every
		-- torch of the first two starts) names its support with its own
		-- param2; a lamp in `group:attached_node = 4` always hangs from the
		-- node above it; a lamp that is a full cube carries itself. The rule
		-- is per start because the palettes differ, and it is the same
		-- invariant in all three cases: a light that is not held up is a
		-- light the engine drops.
		local function light_carrier(name, param2)
			local rule = spec.light_support and spec.light_support[name]
			if rule == "self" then return nil end
			if rule == "above" then
				assert(param2 == 0, "hanging lamp carries a param2")
				return {0, 1, 0}
			end
			return assert(support_dir[param2], "unsupported torch rotation")
		end
		for _, cell in ipairs(blueprint.cells) do
			if LIGHT[cell.name] then
				local dir = light_carrier(cell.name, cell.param2)
				if dir then
					assert(solid(cell.x + dir[1], cell.y + dir[2],
						cell.z + dir[3]),
						"floating light at " .. key(cell.x, cell.y, cell.z))
				end
			end
		end
		-- The loose props: their exact population, and none of them floating.
		--
		-- Section 5 has no invariant for a bale, a stepping stone or a hand
		-- cart, and that is exactly where this settlement lost three carts,
		-- two wheels and four bale stacks in silence -- each of them skipped
		-- by a placement test whose false nobody read -- and left one cart's
		-- barrel hanging in the air beside the cart instead of on it. The
		-- composition now refuses to skip a prop; the counts below are the
		-- independent check that it did not, and they are EXACT, so a prop
		-- that moves under another prop's feet shows up here as a number.
		local prop_wanted, prop_mode, prop_seen = {}, {}, {}
		for _, row in ipairs(spec.props) do
			prop_wanted[row[1]] = row[2]
			prop_mode[row[1]] = row[3]
			prop_seen[row[1]] = 0
		end
		local carts = 0
		for _, cell in ipairs(blueprint.cells) do
			if prop_wanted[cell.name] then
				prop_seen[cell.name] = prop_seen[cell.name] + 1
				-- A wallmounted prop hangs on the node its param2 points at; a
				-- ceiling prop (`group:attached_node = 3`, and a rope tied to
				-- a beam) on the node ABOVE it; everything else rests on the
				-- node under it.
				local dir = {0, -1, 0}
				if prop_mode[cell.name] == "wallmounted" then
					dir = assert(support_dir[cell.param2],
						"unsupported prop rotation")
				elseif prop_mode[cell.name] == "ceiling" then
					dir = {0, 1, 0}
				end
				assert(node(cell.x + dir[1], cell.y + dir[2],
						cell.z + dir[3]) ~= "air",
					"floating " .. cell.name .. " at " ..
						key(cell.x, cell.y, cell.z))
			end
			-- A hand cart is its load riding ON a bearer log, never beside it.
			if spec.cart_load and cell.name == spec.cart_load and cell.y == 2 and
					node(cell.x, 1, cell.z) == spec.tree.log then
				carts = carts + 1
			end
		end
		for _, row in ipairs(spec.props) do
			assert(prop_seen[row[1]] == row[2], "prop population differs: " ..
				row[1] .. " is " .. prop_seen[row[1]] .. ", not " .. row[2])
		end
		assert(carts == spec.carts,
			"hand cart population differs: " .. carts .. ", not " .. spec.carts)

		local declared_lights = {}
		for _, pos in ipairs(blueprint.landmarks.lights) do
			local address = key(pos.x, pos.y, pos.z)
			assert(not declared_lights[address], "duplicate light landmark")
			declared_lights[address] = true
			assert(LIGHT[node(pos.x, pos.y, pos.z)], "light landmark has no torch")
		end
		assert(#blueprint.landmarks.lights == lights,
			"light landmark population differs")
		assert(solid(0, 0, 0) and stand(0, 1, 0) and not solid(0, 3, 0))
		-- The road is a five-wide clear route, not a cosmetic line. Its
		-- extent -- and with it its DIRECTION -- is read out of the
		-- `main_street` landmark rather than assumed: the three Elandor
		-- starts leave their pad toward +z and the three Kragmar starts
		-- toward -z, because the zone catalog gives the northern group a
		-- `start:north` gate and the southern group a `start:south` one.
		local street = assert(blueprint.landmarks.main_street,
			"no main street landmark")
		-- Anchored to the pad, not merely five wide and sixty-four deep: the
		-- route runs up the middle of the settlement and reaches its centre,
		-- so x is exactly -2..2 and one end of the z span is the origin. An
		-- extent test alone would accept a five-wide strip anywhere.
		assert(street.min.x == -2 and street.max.x == 2,
			"the main street is not the pad's own five-wide corridor")
		assert(street.max.z - street.min.z == 63,
			"the main street is not the contract's pad-deep route")
		assert(street.min.z == 0 or street.max.z == 0,
			"the main street does not reach the pad centre")
		for z = street.min.z, street.max.z do
			for x = street.min.x, street.max.x do
				assert(stand(x, 1, z), "blocked main road at " .. key(x, 1, z))
			end
		end

		-- Section 5 invariant 2: every door is a real, usable doorway.
		local facedir = {[0] = {0, 1}, {1, 0}, {0, -1}, {-1, 0}}
		local doorways = assert(blueprint.landmarks.doors, "no door landmarks")
		assert(#doorways >= spec.min_doors, "every building needs a door")
		for _, door in ipairs(doorways) do
			assert(LEAF[node(door.x, door.y, door.z)],
				"door landmark is not a door")
			assert(node(door.x, door.y + 1, door.z) == "doors:hidden",
				"door has no hidden upper node")
			local step = facedir[door.face]
			assert(step, "door landmark has no orientation")
			local ix, iz = door.x + step[1], door.z + step[2]
			local ox, oz = door.x - step[1], door.z - step[2]
			assert(stand(ix, door.y, iz), "door's inside foot is not standable")
			assert(stand(ox, door.y, oz), "door's outside foot is not standable")
			assert(PAVED[node(ox, door.y - 1, oz)],
				"door's outside foot is not on a path or plaza")
			local function jamb(jx, jz)
				return solid(jx, door.y, jz) or LEAF[node(jx, door.y, jz)]
			end
			assert(jamb(door.x + step[2], door.z - step[1]) and
				jamb(door.x - step[2], door.z + step[1]),
				"door orientation does not match its wall")
		end

		-- Section 5 invariant 4 plus the lit-interior rule, per authored room.
		local rooms = assert(blueprint.landmarks.rooms, "no room landmarks")
		assert(#rooms >= spec.min_rooms, "every building needs a room")
		-- A cell inside SOME room is never an eave: a building whose wing
		-- shares a wall with its main block has ring cells that fall inside
		-- the main room, and the roof above those is a roof over a room, not
		-- an unsupported eave.
		local function indoors(x, z)
			for _, room in ipairs(rooms) do
				if x >= room.min.x and x <= room.max.x and
						z >= room.min.z and z <= room.max.z then
					return true
				end
			end
			return false
		end
		-- A room declared a RUIN is the one exception to the roof and light
		-- invariant, and it is an exception by construction, not by neglect:
		-- a roofless ruin has no roof to be watertight and no light to be
		-- lit. The relaxation is keyed on the flag the generator publishes,
		-- so it reaches exactly those rooms; every inhabited room of every
		-- settlement -- including the two intact homes on the same lane as
		-- Stillgrave's two ruins -- keeps the full invariant below.
		local ruins = 0
		for _, room in ipairs(rooms) do
			local lit, open_columns = 0, 0
			for z = room.min.z, room.max.z do
				for x = room.min.x, room.max.x do
					local covered = false
					for y = room.top + 1, 24 do
						if node(x, y, z) ~= "air" then covered = true end
						if declared_lights[key(x, y, z)] then lit = lit + 1 end
					end
					for y = 1, room.top do
						if declared_lights[key(x, y, z)] then lit = lit + 1 end
					end
					if not covered then open_columns = open_columns + 1 end
					assert(covered or room.ruin,
						"interior column open to the sky in " .. room.id)
				end
			end
			if room.ruin then
				ruins = ruins + 1
				-- `ruin` switches off the watertight-roof and lit-interior
				-- invariants, which are two of the strongest rules in this
				-- file, so the flag itself is checked rather than believed.
				-- A room that claims it is a ruin must BE one: nothing lives
				-- there (no door landmark opens into it, it is nobody's
				-- destination), it is unlit, and it is genuinely open --
				-- at least one of its columns really does see the sky.
				-- Without the last test a fully roofed, fully furnished
				-- building could turn off both invariants by setting a flag.
				assert(lit == 0, "a ruin is not a lit room: " .. room.id)
				assert(open_columns > 0,
					"a room flagged ruin is roofed over: " .. room.id)
				for _, door in ipairs(doorways) do
					assert(not (door.x >= room.min.x and door.x <= room.max.x and
						door.z >= room.min.z and door.z <= room.max.z),
						"a room flagged ruin has a door in it: " .. room.id)
				end
				for _, pos in ipairs(blueprint.landmarks.destinations) do
					assert(not (pos.x >= room.min.x and pos.x <= room.max.x and
						pos.z >= room.min.z and pos.z <= room.max.z),
						"a room flagged ruin is a destination: " .. room.id)
				end
			else
				assert(lit > 0, "unlit interior in " .. room.id)
			end
			-- The eaves land on a full node: no half-node gap over any wall
			-- that actually exists (an open-sided workyard has none to check).
			if room.closed then
				for z = room.min.z - 1, room.max.z + 1 do
					for x = room.min.x - 1, room.max.x + 1 do
						if x == room.min.x - 1 or x == room.max.x + 1 or
								z == room.min.z - 1 or z == room.max.z + 1 then
							if node(x, 1, z) ~= "air" and not indoors(x, z) then
								local eave
								for y = room.top, 24 do
									if ROOF[node(x, y, z)] then eave = y break end
								end
								if eave then
									assert(node(x, eave - 1, z) ~= "air",
										"roof lacks a bearing at " .. key(x, eave, z))
								end
							end
						end
					end
				end
			end
		end

		-- Every authored tree stands on an unbroken stem that starts on the
		-- ground, and no leaf floats away from one.
		local tree = spec.tree
		local trunks, stems = {}, 0
		for _, cell in ipairs(blueprint.cells) do
			if cell.name == tree.log and cell.y == 1 then
				local top = 1
				while node(cell.x, top + 1, cell.z) == tree.log do top = top + 1 end
				if node(cell.x, top + 1, cell.z) == tree.leaves then
					assert(top >= tree.min_trunk,
						"authored tree has a short or broken trunk")
					trunks[cell.x .. ":" .. cell.z] = top
					stems = stems + 1
				end
			end
		end
		assert(stems >= tree.min_stems, "the settlement lost its trees")
		for _, cell in ipairs(blueprint.cells) do
			if cell.name == tree.leaves then
				local rooted = false
				for dz = -tree.reach, tree.reach do
					for dx = -tree.reach, tree.reach do
						local top = trunks[(cell.x + dx) .. ":" .. (cell.z + dz)]
						if top and cell.y >= top - tree.low and
								cell.y <= top + tree.high then
							rooted = true
						end
					end
				end
				assert(rooted, "floating leaves at " .. key(cell.x, cell.y, cell.z))
			end
		end

		local ground = {}
		for _, row in ipairs(spec.ground) do ground[row[1]] = 0 end
		for z = -63, 63 do
			for x = -63, 63 do
				local name = node(x, 0, z)
				if ground[name] then ground[name] = ground[name] + 1 end
			end
		end
		for _, row in ipairs(spec.ground) do
			assert(ground[row[1]] > row[2], "natural ground must dominate the " ..
				"spaces between plots: " .. row[1] .. " is " .. ground[row[1]])
		end

		local queue, visited = {{x = 0, y = 1, z = 0}}, {[key(0, 1, 0)] = true}
		local cursor = 1
		local directions = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
		while cursor <= #queue do
			local pos = queue[cursor]
			cursor = cursor + 1
			for _, offset in ipairs(directions) do
				local x, z = pos.x + offset[1], pos.z + offset[2]
				if x >= -63 and x <= 63 and z >= -63 and z <= 63 then
					for dy = -1, 1 do
						local y = pos.y + dy
						local address = key(x, y, z)
						if y >= 1 and y <= 24 and not visited[address] and
								stand(x, y, z) and
								(dy <= 0 or not solid(pos.x, pos.y + 2, pos.z)) and
								(dy >= 0 or not solid(x, pos.y + 1, z)) then
							visited[address] = true
							queue[#queue + 1] = {x = x, y = y, z = z}
						end
					end
				end
			end
		end
		local destinations = assert(blueprint.landmarks.destinations)
		assert(#destinations >= spec.min_destinations,
			"every building needs a reachable interior")
		for _, pos in ipairs(destinations) do
			assert(visited[key(pos.x, pos.y, pos.z)],
				"unreachable interior: " .. pos.id)
		end
		-- A second construction cannot depend on table iteration order or RNG.
		local again = build()
		assert(#again.cells == #blueprint.cells)
		for i, cell in ipairs(blueprint.cells) do
			local other = again.cells[i]
			for _, field in ipairs({"x", "y", "z", "name", "param2"}) do
				assert(cell[field] == other[field], "non-deterministic architecture")
			end
		end
		report[#report + 1] = table.concat({"wp13_blueprint", spec.key,
			#blueprint.cells, count, palette_count, lights, oriented,
			#destinations, #doorways, #rooms, ruins, stems, #queue}, "\t") .. "\n"
	end
	return table.concat(report)
end
