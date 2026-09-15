-- Architectural acceptance for the Highcourt capital pilot.
--
-- `blueprint_kat.lua` holds the six START blueprints to the invariants of
-- docs/research/wp13-settlement-pipeline.md section 5. A capital is a
-- different shape -- one core plus a list of terrain-relative district plots
-- plus an avenue overlay that has no cells until a surface is handed to it --
-- so this file is its equivalent, and it checks the three of them against
-- docs/research/wp13-capitals-pois-contract.md (section 2.1 envelopes,
-- section 2.3 budgets) and docs/research/wp13-npc-sockets-contract.md
-- (section 2, the socket field).
--
-- What it does NOT repeat: the six starts, the eighteen capital parts at four
-- rotations, and the palette-wide registry scan. Those are `blueprint_kat`
-- and `library_kat` section 12. What it adds is everything that only exists
-- once a composition assembles those parts:
--
--   1. the core's envelope, budget, canonicity and flat ground course;
--   2. the same registry rules the parts are held to, applied to the cells
--      the COMPOSITION emits -- including the two node families no palette
--      in `palette.lua` binds, the crown's marble and its slate roof;
--   3. every doorway and every gate opening passable, and every destination
--      reachable from the arrival crossing by the conservative walk;
--   4. the socket contract, with the capital's exact role multiset, the king
--      on his throne, the two vendor families and ONE patrol loop whose
--      orders are 1..n without a gap or a repeat;
--   5. every plot: its own envelope and budget, its reference column, its
--      foundation skirt down to -6 and its cleared airspace;
--   6. the avenue overlay on a synthetic terrace profile: pavement at the
--      surface, a walkable climb over every terrace joint, lamps on the
--      rhythm, and not one height query the caller did not answer.
--
-- Plain Lua 5.1; the same bytes must run under LuaJIT and PUC 5.1.

return function(repo)
	local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
	local parts = dofile(wp13 .. "/parts.lua")
	local palettes = dofile(wp13 .. "/palette.lua")
	local avenue = dofile(wp13 .. "/avenue.lua")(wp13)
	local wall = dofile(wp13 .. "/wall.lua")(wp13)
	local capital = dofile(wp13 .. "/nhal_veyr.lua")(wp13)
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local registry = dofile(repo .. "/tools/wp13/stub_registry.lua")
	local world = registry.load(repo)

	local report = {}
	local function say(...)
		report[#report + 1] = table.concat({...}, "\t") .. "\n"
	end

	-- Independent direction model, as in `library_kat`.
	local FACEDIR_DIR = {[0] = {0, 1}, [1] = {1, 0}, [2] = {0, -1},
		[3] = {-1, 0}}
	local WALL_DIR = {[0] = {0, 1, 0}, [1] = {0, -1, 0}, [2] = {1, 0, 0},
		[3] = {-1, 0, 0}, [4] = {0, 0, 1}, [5] = {0, 0, -1}}

	-- The retirement roster, read out of its two sources exactly as
	-- `library_kat` reads them: a composition may name no node the game
	-- unregisters, and this composition names two families -- the darkage
	-- marble of the crown and its slate roof -- that no palette in
	-- `palette.lua` binds, so nothing else checks them.
	local removed = {}
	local function retire(name)
		removed[name] = true
		local material = name:match("^default:([%w_]+)$")
		if material then
			for _, shape in ipairs({"stair_", "stair_inner_", "stair_outer_",
					"slab_"}) do
				removed["stairs:" .. shape .. material] = true
			end
		end
	end
	local curation = assert(io.open(repo ..
		"/mods/ITEMS/grug_materials/content_curation.lua", "r"),
		"content curation source is missing")
	local curation_text = curation:read("*a")
	curation:close()
	local blocks = 0
	for block in curation_text:gmatch("local REMOVED_[A-Z_]+ = {(.-)}") do
		blocks = blocks + 1
		for name in block:gmatch('"([%w_]+:[%w_]+)"') do retire(name) end
	end
	assert(blocks >= 3, "curation source no longer lists its removals")
	for _, derivative in ipairs(world.storage_derivatives) do
		retire(derivative.source)
	end
	assert(removed["default:ladder_steel"] and removed["default:steel_ingot"],
		"both retirement sources must be in the roster")

	local function walkable(name)
		local def = world.nodes[name]
		return def ~= nil and def.walkable ~= false
	end

	-- The support direction of an attached node, transcribed from
	-- `builtin_shared.check_attached_node`
	-- (reference_projects/luanti/builtin/game/falling.lua:391-434).
	local function attach_step(def, param2)
		local rating = (type(def.groups) == "table") and
			(def.groups.attached_node or 0) or 0
		if rating == 0 then return nil end
		if rating == 3 then return 0, -1, 0 end
		if rating == 4 then return 0, 1, 0 end
		if rating == 2 then
			if def.paramtype2 == "facedir" then
				local dir = FACEDIR_DIR[param2 % 4]
				return dir[1], 0, dir[2]
			end
			return 0, 0, 1
		end
		if def.paramtype2 == "wallmounted" then
			local dir = WALL_DIR[param2]
			if not dir then return 0, 1, 0 end
			return dir[1], dir[2], dir[3]
		end
		return 0, -1, 0
	end

	local LOOSE = {plantlike = true, torchlike = true, signlike = true,
		airlike = true}
	local NEIGHBOUR_STEPS = {{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0},
		{0, 0, 1}, {0, 0, -1},
		{1, 1, 0}, {-1, 1, 0}, {0, 1, 1}, {0, 1, -1},
		{1, -1, 0}, {-1, -1, 0}, {0, -1, 1}, {0, -1, -1}}

	-- The undead palette's own vocabulary, plus the two families the
	-- composition overrides into it. Used for the walk and the light rules.
	local undead = palettes.new("undead")

	-- ------------------------------------------------------------------
	-- THE WORK SOCKETS OF SECTION 8.1, and the feature each activity names
	-- ------------------------------------------------------------------
	--
	-- The sockets contract's section 8 (playtest round 3) adds the role
	-- `work`: a resident's workplace, always staffed, always static, naming
	-- the ACTIVITY it does and FACING the feature that activity works within
	-- three nodes. The registry (`grug_core/settlement_sockets.lua`) owns the
	-- closed vocabulary and refuses a typo at load; what it cannot do is look
	-- at the blueprint and see whether there is an anvil in front of the
	-- smith. That is this file's half of section 8.5, and it is the half that
	-- catches the real defect: a socket whose dressing moved.
	--
	-- The vocabulary is spelled here rather than read from the registry
	-- because the registry is an engine module and this KAT has no engine; the
	-- two lists disagreeing is exactly what `settlement_sockets_kat.lua` and
	-- the contract table are for.
	--
	-- THE WAVE-2 SIX ARE IN IT (section 8.2, 2026-09-15): `mine`, `brew`,
	-- `carve`, `mourn`, `spar` and `forage`, which the coordinator landed in
	-- `grug_core/settlement_sockets.lua` before this lane started and which
	-- this capital is the first structure lane to author.
	local ACTIVITIES = {smith = true, fish = true, farm = true, chop = true,
		tend = true, pray = true, stall = true, sit = true, sweep = true,
		mine = true, brew = true, carve = true, mourn = true, spar = true,
		forage = true}
	-- Section 8.4: the two `grug_traders` families, the wave-1 five professions
	-- and the wave-2 seven.
	local VENDOR_KINDS = {race = true, general = true, butcher = true,
		smith = true, fishmonger = true, baker = true, tailor = true,
		mason = true, brewer = true, bowyer = true, herbalist = true,
		armourer = true, tanner = true, embalmer = true}
	-- The two the CORE alone may publish: `grug_traders` has exactly two
	-- vendor families and the core's ossuary court already carries one of
	-- each, so one out in a district would have the runtime place a third.
	local CORE_VENDOR_KINDS = {race = true, general = true}

	-- Which node names satisfy which activity. Built from the PALETTE's own
	-- roles wherever the contract names a palette thing ("an anvil", "a log",
	-- "a crop"), so a palette rebinding moves the rule with it.
	--
	-- `sit` and `sweep` name no feature: the contract says so in as many words
	-- ("`sit` sits on the ground it stands on", and a sweeper walks a line
	-- beside its socket). `stall` is the one rule that is geometric rather
	-- than a name list -- "a counter (any solid node at waist height)" -- so it
	-- is answered below by solidity at the socket's own feet course rather
	-- than by a set.
	local FEATURE = {}
	local function feature_set(activity, roles, extra)
		local set = {}
		for _, role in ipairs(roles) do
			local name = undead.maybe(role)
			if name then set[name] = true end
		end
		for _, name in ipairs(extra or {}) do set[name] = true end
		FEATURE[activity] = set
	end
	-- `smith`: "an anvil or a furnace". `grug_decor:cottages_anvil` is spelled
	-- by NAME and not through the `workbench` role, because in this palette
	-- that role is the bone carver's bench -- an xdecor workbench cube -- and
	-- the two compositions that place a smith here write the anvil literally
	-- for exactly that reason. The role stays in the set anyway: a palette
	-- whose workbench IS an anvil (the human one) would otherwise stop
	-- satisfying a rule it satisfies today.
	feature_set("smith", {"workbench", "hearth"},
		{"default:furnace", "default:furnace_active",
			"grug_decor:cottages_anvil"})
	-- `fish` is CAPITAL-ONLY (contract section 8.1): a start blueprint may
	-- contain no water cell at all, so no start can satisfy this rule; a
	-- capital plot may dig its own pond, and Highcourt's does.
	feature_set("fish", {"water"},
		{"default:water_source", "default:water_flowing",
			"default:river_water_source", "default:river_water_flowing"})
	feature_set("farm", {"crop_soil", "crop"}, {"farming:soil_wet"})
	feature_set("chop", {"tree_log", "post", "beam"}, {})
	--
	-- `tend`: A PLANT OR A FLOWER, and nothing else. `undergrowth` is NOT in
	-- the set, which is where this capital's rule is tighter than the pilot's
	-- and has to be: in the human palette that role is a bush and in this one
	-- it is `grug_nodes:bone_pile`, so a set built from the role would let a
	-- gardener tend a heap of bones. The wave-2 coordinator's review asked for
	-- exactly this, and the assertion below is what makes the answer checkable
	-- rather than a promise -- every name that survives into `tend` or `forage`
	-- has to be a plant BY ITS OWN REGISTRATION.
	feature_set("tend", {"flower", "flower_alt", "hedge", "hedge_stem",
		"grass_tuft", "fern", "crop", "tree_leaves"}, {})
	-- `pray`: THE CHAPEL'S DOOR, AN ALTAR, A CANDLE OR A GRAVE MARKER
	-- (contract section 8.1, corrected 2026-09-15 after the NPC lane's review).
	-- The first wording said "any node of the chapel interior", which
	-- contradicted the rule every socket obeys -- a socket stands OUTSIDE a
	-- room -- and this KAT implemented that first wording by accepting the
	-- chapel's own walls and furniture. It does not any more: a wall is not
	-- something to pray at.
	--
	-- `low_wall` is the grave marker (`dressing.grave` sets one on a flagstone)
	-- and the door family is the palette's `door` prefix, which `palette.node`
	-- refuses to hand out as a family base, so the two door shapes are named.
	--
	-- `signature` IS NOT IN IT, for the reason `mine` lost its paving roles.
	-- It is `default:obsidianbrick`, which is also this palette's `foundation`
	-- -- the footing course of every building in the city -- so an altar set
	-- carrying it lets any wall base read as an altar, and the review found
	-- eight of the nine `pray` sockets resolving to exactly that. What this
	-- capital prays at is a candle or a grave marker, which is the contract's
	-- own list and what every one of those sockets was authored to face.
	feature_set("pray", {"light_post", "light_wall", "light_indoor",
		"low_wall"},
		{"doors:door_steel", "doors:door_steel_a", "doors:door_steel_b",
			"doors:door_steel_c", "doors:door_steel_d"})

	--
	-- THE WAVE-2 SIX (contract section 8.2). Each is the feature that table
	-- names, resolved through this palette's roles wherever the contract names
	-- a thing a palette binds, and spelled by name where it does not.
	--
	-- `mine`: "a stone, ore or cobble node AT HEAD OR CHEST HEIGHT". This
	-- palette's `foundation` is obsidian brick and its `castle_wall` is dungeon
	-- stone; the bone rampart's quarry face is two courses of the former.
	--
	-- THE PAVING ROLES ARE NOT IN IT, and the review of 2026-09-16 is why. The
	-- first version of this set carried `path`, `plaza`, `castle_paving`,
	-- `rubble` and `signature` beside them, on the reasoning that a cobble is a
	-- cobble -- and in this palette `castle_paving` is the stone every court in
	-- the city is laid in and `signature` is the same obsidian brick as
	-- `foundation`. Retyping one `pray` socket of the PAVED pyre court to
	-- `mine` left the KAT green, satisfied by the court's own floor one course
	-- under the miner's feet. A quarry face is what this activity names; a
	-- floor is not one.
	-- What is left is ROCK and only rock -- the country cobble the bone
	-- rampart's quarry face is cut in, and its neighbours. Neither
	-- `foundation` nor `signature` is here, and neither is `castle_wall`: the
	-- curtain and every crypt wall in the city are dungeon stone, so a set
	-- carrying it would let a miner face the outside of a building.
	feature_set("mine", {},
		{"default:cobble", "default:stone", "default:mossycobble",
			"default:desert_stone", "default:desert_cobble"})
	-- `brew`: "a cauldron, barrel or a cooking pot". `hearth` IS the xdecor
	-- cauldron in this palette and `storage` is its barrel.
	feature_set("brew", {"hearth", "storage"}, {})
	-- `carve`: "a log, a totem/statue part or a stone block". The gravewood
	-- stack, the embalmer's obsidian slab and the citadel's own masonry.
	feature_set("carve", {"tree_log", "post", "beam", "castle_wall"}, {})
	-- `mourn`: "a grave marker, a coffin or a candle". `low_wall` is the marker
	-- `dressing.grave` sets on its flagstone and the three light roles are the
	-- candles; this palette binds no coffin node, and a role that does not
	-- exist is simply not in the set.
	feature_set("mourn", {"low_wall", "light_post", "light_wall",
		"light_indoor"}, {})
	-- `spar`: "another `spar` socket or a training dummy (a fence post or a
	-- wool node)". The dummy half is a name set; the socket half cannot be --
	-- it is a question about the socket list and not about the cells -- so it
	-- is answered beside the feature search, where the list is in hand.
	-- `tree_log` is in it beside `post`, and that is the review's N3: this
	-- palette binds the two to the same gravewood node, so the muster field's
	-- three sockets passed by a coincidence of the palette --
	-- `dressing.drill_post` builds its post out of `tree_log`, and a palette
	-- that bound the two differently would have turned this rule red on a
	-- correct composition.
	feature_set("spar", {"fence", "fence_rail", "post", "tree_log", "rug",
		"rug_accent"}, {})
	-- `forage`: "a mushroom, a bush, a plant, a vine or leaves". `ivy` is the
	-- vine and `tree_leaves` the leaves; the bone piles of `undergrowth` are
	-- NOT in it, because a bone pile is none of the five and a rule that
	-- accepted it because a necropolis has bone piles would accept anything.
	feature_set("forage", {"ivy", "tree_leaves", "flower", "flower_alt",
		"crop", "grass_tuft", "fern", "hedge", "hedge_stem"}, {})

	--
	-- AND THE TWO PLANT SETS ARE HELD TO THE REGISTRY, not to their role names.
	-- The sockets contract's section 8.1 says `tend` faces "a plant or a
	-- flower" and 8.2 says `forage` faces "a mushroom, a bush, a plant, a vine
	-- or leaves"; a set built out of palette roles says what a palette CALLS a
	-- thing, and this says what the thing IS. A node qualifies when its own
	-- registration draws it as a plant (`plantlike`, `plantlike_rooted`,
	-- `firelike`, or the wallmounted `signlike` a vine is) or puts it in the
	-- leaves group. `grug_nodes:bone_pile` is a normal opaque cube and fails
	-- both, which is the whole reason this assertion exists.
	do
		local PLANT_DRAW = {plantlike = true, plantlike_rooted = true,
			firelike = true, signlike = true}
		for _, activity in ipairs({"tend", "forage"}) do
			local counted = 0
			for name in pairs(FEATURE[activity]) do
				local def = world.nodes[name]
				assert(def, "the " .. activity .. " feature " .. name ..
					" is not a registered node")
				local draw = def.drawtype or "normal"
				local leaves = type(def.groups) == "table" and
					(def.groups.leaves or 0) > 0
				assert(PLANT_DRAW[draw] or leaves, "the " .. activity ..
					" feature " .. name .. " is drawn as " .. draw ..
					" and is in no leaves group, so it is not a plant")
				counted = counted + 1
			end
			assert(counted > 0, "the " .. activity .. " feature set is empty")
			say("nhal_veyr_" .. activity .. "_features", counted)
		end
	end

	local LIGHT = {}
	for _, role in ipairs({"light_wall", "light_post", "light_indoor"}) do
		LIGHT[undead.node(role)] = true
	end
	-- What a lamp standard may NOT stand on. The road writes none of these, so
	-- the set is the engine's water families rather than a palette role.
	local LIQUID = {["default:water_source"] = true,
		["default:water_flowing"] = true,
		["default:river_water_source"] = true,
		["default:river_water_flowing"] = true}
	local LEAF = {}
	for _, name in ipairs(undead.names("door")) do LEAF[name] = true end
	local HIDDEN = undead.node("door_hidden")
	local THRONE = undead.maybe("throne")

	-- Nodes an ordinary walk passes through. Everything else counts as solid,
	-- which keeps the route check conservative; a door counts as passable
	-- because a player opens it (pipeline contract section 5 invariant 3).
	local PASSABLE = {["air"] = true, [HIDDEN] = true}
	for name in pairs(LEAF) do PASSABLE[name] = true end
	-- The pond's own water (playtest round 3). It is PASSABLE and not solid,
	-- which is what stops the conservative walk from crossing the pond dry
	-- shod and what stops a socket from being credited with a floor it would
	-- sink through; `standable` answers the same thing from the registry,
	-- because river water is `walkable = false`.
	local WATER = undead.maybe("water")
	if WATER then PASSABLE[WATER] = true end
	for _, name in ipairs({"default:torch", "default:torch_wall",
			"default:grass_3", "default:grass_4", "default:fern_1",
			"grug_decor:cottages_straw_mat"}) do
		PASSABLE[name] = true
	end

	-- ------------------------------------------------------------------
	-- the shared body: every rule a finished WP13 composition has to pass
	-- ------------------------------------------------------------------
	--
	-- `spec` carries what differs between the core and a plot: the envelope,
	-- the cell budget and the y the ground course sits at.
	local function check_composition(label, blueprint, spec)
		local cells = blueprint.cells
		assert(type(blueprint.schema) == "string" and blueprint.schema ~= "",
			label .. " has no schema")
		assert(#cells <= spec.budget, label .. " writes " .. #cells ..
			" cells, over the contract budget of " .. spec.budget)
		assert(#cells > 500, label .. " is empty")

		local index, solids, lights, oriented = {}, 0, 0, 0
		local water_cells = {}
		local previous
		for _, cell in ipairs(cells) do
			assert(cell.x % 1 == 0 and cell.y % 1 == 0 and cell.z % 1 == 0,
				label .. " has a fractional cell")
			assert(cell.x >= -spec.reach and cell.x <= spec.reach and
					cell.z >= -spec.reach and cell.z <= spec.reach,
				label .. " reaches " .. cell.x .. "," .. cell.z ..
					", outside the envelope of +-" .. spec.reach)
			assert(cell.y >= spec.ymin and cell.y <= spec.ymax,
				label .. " reaches y " .. cell.y .. ", outside " ..
					spec.ymin .. ".." .. spec.ymax)
			assert(cell.param2 % 1 == 0 and cell.param2 >= 0 and
					cell.param2 <= 255, label .. " has a bad param2")
			assert(type(cell.name) == "string" and cell.name ~= "ignore",
				label .. " has a bad name")
			assert(cell.name ~= "grug_nodes:guard_banner" and
				cell.name ~= "grug_nodes:camp_fire",
				label .. " writes a decorative spawner")
			--
			-- NO COMPOSITION WRITES A LIQUID, with exactly one exception: a
			-- composition that DECLARES a pond may write the palette's own
			-- water, and every cell of it is then held to the containment
			-- rule below. Lava is refused outright and always was.
			--
			-- The declaration is the point. "No water" was the rule that kept
			-- a settlement from being built into a river; a town pond is the
			-- opposite thing -- water the capital dug, lined on five sides --
			-- and the difference between the two is whether the composition
			-- says so and can prove the lining.
			--
			assert(not cell.name:find("lava"), label .. " writes lava")
			if cell.name:find("water") then
				assert(spec.water and WATER and cell.name == WATER,
					label .. " writes a liquid")
				water_cells[#water_cells + 1] = cell
			end
			local key = cell.x .. ":" .. cell.y .. ":" .. cell.z
			assert(index[key] == nil, label .. " writes " .. key .. " twice")
			if previous then
				assert(previous.z < cell.z or previous.z == cell.z and
						(previous.y < cell.y or previous.y == cell.y and
							previous.x < cell.x),
					label .. " is not in canonical order at " .. key)
			end
			previous = cell
			index[key] = cell
			if cell.name ~= "air" then solids = solids + 1 end
			if LIGHT[cell.name] then lights = lights + 1 end
			if cell.param2 ~= 0 then oriented = oriented + 1 end
		end
		assert(lights >= spec.min_lights, label .. " carries " .. lights ..
			" lights, fewer than " .. spec.min_lights)
		assert(oriented > 0, label .. " has no shaped architecture")

		-- The palette: complete, deduplicated and in ASCII byte order.
		local names, palette_count = {}, 0
		for _, cell in ipairs(cells) do
			if not names[cell.name] then
				names[cell.name] = true
				palette_count = palette_count + 1
			end
		end
		assert(palette_count == #blueprint.palette,
			label .. " palette is not the set of its own names")
		for position, name in ipairs(blueprint.palette) do
			assert(names[name], label .. " palette names the unwritten " ..
				name)
			assert(position == 1 or
					parts.less_bytes(blueprint.palette[position - 1], name),
				label .. " palette is not in byte order at " .. name)
		end

		-- The bounds landmark is the real extent.
		local bounds = assert(blueprint.bounds, label .. " has no bounds")
		local minp, maxp = bounds.min, bounds.max
		for _, cell in ipairs(cells) do
			assert(cell.x >= minp.x and cell.x <= maxp.x and
					cell.y >= minp.y and cell.y <= maxp.y and
					cell.z >= minp.z and cell.z <= maxp.z,
				label .. " has a cell outside its own bounds")
		end

		local function at(x, y, z) return index[x .. ":" .. y .. ":" .. z] end

		-- THE POND IS LINED (playtest round 3). Every water cell's four
		-- horizontal neighbours and the cell under it are cells of THIS
		-- composition and are either water or solid -- so the basin is a
		-- vessel the plot itself wrote, and not a hole whose walls are
		-- whatever terrain the seam happened to project it onto. That is what
		-- makes a pond on a terraced envelope legal: it cannot drain into the
		-- district below it.
		local lined = 0
		for _, cell in ipairs(water_cells) do
			for _, step in ipairs({{1, 0, 0}, {-1, 0, 0}, {0, 0, 1},
					{0, 0, -1}, {0, -1, 0}}) do
				local neighbour = at(cell.x + step[1], cell.y + step[2],
					cell.z + step[3])
				assert(neighbour ~= nil and neighbour.name ~= "air",
					label .. ": the pond leaks at " .. cell.x .. "," ..
						cell.y .. "," .. cell.z .. " towards " ..
						step[1] .. "," .. step[2] .. "," .. step[3])
				lined = lined + 1
			end
		end
		assert((#water_cells > 0) == (spec.water == true),
			label .. " and its declaration disagree about water")
		-- Outside the cell list a column at or below the ground course is
		-- the settlement's own terrain, which holds what rests on it; above
		-- it an absent cell is air.
		local function node(x, y, z)
			local cell = at(x, y, z)
			if cell then return cell.name end
			return (y <= 0) and "default:stone" or "air"
		end
		local function solid(x, y, z) return not PASSABLE[node(x, y, z)] end
		local function stand(x, y, z)
			return solid(x, y - 1, z) and not solid(x, y, z) and
				not solid(x, y + 1, z)
		end
		local function standable(x, y, z)
			local cell = at(x, y, z)
			if cell == nil then return y <= 0 end
			return cell.name ~= "air" and walkable(cell.name)
		end
		local function free(x, y, z)
			local cell = at(x, y, z)
			return cell == nil or cell.name == "air"
		end

		-- Every name against the real registry, and the authored tables of
		-- `parts.lua` in both directions; then round A's two shape rules,
		-- the settled panes, the attachment ratings, the detached-cell rule
		-- and the torch rule. Same body as `library_kat` section 12, applied
		-- to a whole composition.
		local panes, attached, torches = 0, 0, 0
		for _, cell in ipairs(cells) do
			if cell.name ~= "air" then
				local def = world.nodes[cell.name]
				assert(def, label .. " writes the unregistered " .. cell.name)
				assert(not removed[cell.name],
					label .. " writes the retired " .. cell.name)
				local kind = parts.param2_kind(cell.name)
				if kind == parts.FACEDIR then
					assert(def.paramtype2 == "facedir", label .. ": " ..
						cell.name .. " is rotated as facedir but is " ..
						tostring(def.paramtype2))
				elseif kind == parts.WALLMOUNTED then
					assert(def.paramtype2 == "wallmounted", label .. ": " ..
						cell.name .. " is rotated as wallmounted but is " ..
						tostring(def.paramtype2))
				elseif kind ~= parts.MESHOPTIONS then
					assert(cell.param2 == 0, label .. ": unoriented " ..
						cell.name .. " carries param2 " .. cell.param2)
				end
				assert(parts.pane_connects(cell.name) ==
						registry.pane_connects(world, cell.name),
					label .. ": parts.pane_connects disagrees for " ..
						cell.name)
				assert(parts.full_solid(cell.name) ==
						registry.is_opaque_full(world, cell.name),
					label .. ": parts.full_solid disagrees for " .. cell.name)
				local groups = (type(def.groups) == "table") and def.groups or {}
				assert(parts.shaped(cell.name) ==
						((groups.slab or 0) > 0 or (groups.stair or 0) > 0),
					label .. ": parts.shaped disagrees for " .. cell.name)
				if def.place_param2 ~= nil then
					assert(cell.param2 == def.place_param2, label .. ": " ..
						cell.name .. " pins place_param2 " ..
						def.place_param2 .. " but a cell carries " ..
						cell.param2)
				end
				local axis = cell.param2 - (cell.param2 % 4)
				local above = at(cell.x, cell.y + 1, cell.z)
				if (groups.slab or 0) > 0 and axis == 0 then
					assert(above == nil or above.name == "air",
						label .. ": a bottom slab carries " ..
							tostring(above and above.name) .. " at " ..
							cell.x .. "," .. cell.y .. "," .. cell.z)
				end
				if def.paramtype2 == "facedir" and axis ~= 0 then
					assert(axis == 20, label .. ": " .. cell.name ..
						" carries the unsupported facedir axis " .. axis)
					assert((groups.slab or 0) > 0 or (groups.stair or 0) > 0,
						label .. ": " .. cell.name .. " is upside down but " ..
							"is neither slab nor stair")
					assert(above ~= nil and above.name ~= "air",
						label .. ": a top slab meets nothing at " .. cell.x ..
							"," .. cell.y .. "," .. cell.z)
				end
				if (groups.pane or 0) > 0 then
					panes = panes + 1
					local base = cell.name
					if base:sub(-5) == "_flat" then base = base:sub(1, -6) end
					local any, total, hit = cell.param2, 0, {}
					for dir = 0, 3 do
						local step = FACEDIR_DIR[dir]
						local other = at(cell.x + step[1], cell.y,
							cell.z + step[2])
						hit[dir] = other ~= nil and
							registry.pane_connects(world, other.name)
						if hit[dir] then
							any = dir
							total = total + 1
						end
					end
					local want, want_param2
					if total == 0 then
						want, want_param2 = base .. "_flat", cell.param2
					elseif total == 1 or (total == 2 and
							((hit[0] and hit[2]) or (hit[1] and hit[3]))) then
						want, want_param2 = base .. "_flat", (any + 1) % 4
					else
						want, want_param2 = base, 0
					end
					assert(cell.name == want and cell.param2 == want_param2,
						label .. ": pane at " .. cell.x .. "," .. cell.y ..
							"," .. cell.z .. " is " .. cell.name .. "/" ..
							cell.param2 .. " but update_pane would leave " ..
							want .. "/" .. want_param2)
				end
				local ax, ay, az = attach_step(def, cell.param2)
				if ax then
					attached = attached + 1
					assert(standable(cell.x + ax, cell.y + ay, cell.z + az),
						label .. ": " .. cell.name .. " at " .. cell.x .. "," ..
							cell.y .. "," .. cell.z .. " is attached to " ..
							"nothing the engine would keep it on")
				end
				local loose = LOOSE[def.drawtype] or
					def.paramtype2 == "wallmounted" or
					(groups.tree or 0) > 0 or (groups.leaves or 0) > 0 or
					(groups.leafdecay or 0) > 0
				if not loose then
					local touched = false
					for _, step in ipairs(NEIGHBOUR_STEPS) do
						local other = at(cell.x + step[1], cell.y + step[2],
							cell.z + step[3])
						if (other ~= nil and other.name ~= "air") or
								(other == nil and cell.y + step[2] <= 0) then
							touched = true
						end
					end
					assert(touched, label .. ": " .. cell.name ..
						" stands detached at " .. cell.x .. "," .. cell.y ..
						"," .. cell.z)
				end
				if LIGHT[cell.name] then
					torches = torches + 1
					local dir = assert(WALL_DIR[cell.param2],
						label .. ": a torch has no wallmounted direction")
					local support = at(cell.x + dir[1], cell.y + dir[2],
						cell.z + dir[3])
					assert(support and
							registry.is_opaque_full(world, support.name),
						label .. ": torch at " .. cell.x .. "," .. cell.y ..
							"," .. cell.z .. " hangs on " ..
							tostring(support and support.name or "air"))
				end
			end
		end

		-- Nothing floats as an ISLAND either. The neighbour rule above is
		-- local -- two cells that touch each other and nothing else pass it
		-- -- so the same adjacency is flooded from the GROUND COURSE up:
		-- every piece of architecture has to be connected to the pad through
		-- other cells and not merely to itself. Same rule as `library_kat`
		-- section 12 (f2), applied to a whole composition, where the seed is
		-- the settlement's own ground and footings rather than the terrain
		-- under a part.
		local grounded, frontier, frontier_count = {}, {}, 0
		for _, cell in ipairs(cells) do
			if cell.name ~= "air" and cell.y <= 0 then
				local key = cell.x .. ":" .. cell.y .. ":" .. cell.z
				if not grounded[key] then
					grounded[key] = true
					frontier_count = frontier_count + 1
					frontier[frontier_count] = cell
				end
			end
		end
		local head = 1
		while head <= frontier_count do
			local cell = frontier[head]
			head = head + 1
			for _, step in ipairs(NEIGHBOUR_STEPS) do
				local other = at(cell.x + step[1], cell.y + step[2],
					cell.z + step[3])
				if other ~= nil and other.name ~= "air" then
					local key = other.x .. ":" .. other.y .. ":" .. other.z
					if not grounded[key] then
						grounded[key] = true
						frontier_count = frontier_count + 1
						frontier[frontier_count] = other
					end
				end
			end
		end
		local islands = 0
		for _, cell in ipairs(cells) do
			if cell.name ~= "air" then
				local def = world.nodes[cell.name]
				local groups = (def and type(def.groups) == "table") and
					def.groups or {}
				local loose = def == nil or LOOSE[def.drawtype] or
					def.paramtype2 == "wallmounted" or
					(groups.tree or 0) > 0 or (groups.leaves or 0) > 0 or
					(groups.leafdecay or 0) > 0
				if not loose then
					islands = islands + 1
					assert(grounded[cell.x .. ":" .. cell.y .. ":" .. cell.z],
						label .. ": " .. cell.name .. " at " .. cell.x .. "," ..
							cell.y .. "," .. cell.z .. " is an island -- " ..
							"nothing connects it to the ground")
				end
			end
		end

		-- Every floor a player walks on rests on something -- and where it
		-- does not, it is an UPPER floor carried on walls, and the
		-- composition says how many such cells it has, exactly.
		--
		-- That is `blueprint_kat`'s rule for Kapok's boardwalks, and for the
		-- same reason: no geometric test separates a chamber floor carried
		-- on its piers from a cantilevered apron, because both have their
		-- bearing one node to the side. So the number is declared, and a
		-- podium built one node too small shows up here as a number that
		-- moved.
		local PAVED = {}
		for _, role in ipairs({"path", "plaza", "plaza_edge"}) do
			PAVED[undead.node(role)] = true
		end
		PAVED[undead.node("castle_paving")] = true
		local raised, first_raised = 0, nil
		for _, cell in ipairs(cells) do
			if PAVED[cell.name] and cell.y >= 1 and
					node(cell.x, cell.y - 1, cell.z) == "air" then
				raised = raised + 1
				first_raised = first_raised or (cell.name .. " at " ..
					cell.x .. "," .. cell.y .. "," .. cell.z)
			end
		end
		assert(raised == spec.raised, label .. ": " .. raised ..
			" paved cells stand clear of what is under them, not " ..
			spec.raised .. ", first " .. tostring(first_raised))

		-- The lights landmark is the light population, exactly.
		local declared = {}
		for _, pos in ipairs(blueprint.landmarks.lights) do
			local key = pos.x .. ":" .. pos.y .. ":" .. pos.z
			assert(not declared[key], label .. " declares a light twice")
			declared[key] = true
			assert(LIGHT[node(pos.x, pos.y, pos.z)],
				label .. " declares a light where there is none")
		end
		assert(#blueprint.landmarks.lights == lights,
			label .. " declares " .. #blueprint.landmarks.lights ..
				" lights but writes " .. lights)

		-- Every doorway is a real door, passable, with a standable step on
		-- both sides (pipeline contract section 5 invariant 2).
		local doorways = assert(blueprint.landmarks.doors,
			label .. " has no door landmarks")
		assert(#doorways >= spec.min_doors, label .. " has " .. #doorways ..
			" doors, fewer than " .. spec.min_doors)
		for _, door in ipairs(doorways) do
			assert(LEAF[node(door.x, door.y, door.z)],
				label .. ": door landmark at " .. door.x .. "," .. door.y ..
					"," .. door.z .. " is " .. node(door.x, door.y, door.z))
			assert(node(door.x, door.y + 1, door.z) == HIDDEN,
				label .. ": door has no hidden upper node")
			local step = assert(FACEDIR_DIR[door.face],
				label .. ": door landmark has no orientation")
			for _, sign in ipairs({1, -1}) do
				local sx = door.x + step[1] * sign
				local sz = door.z + step[2] * sign
				assert(free(sx, door.y, sz) and free(sx, door.y + 1, sz),
					label .. ": the doorway at " .. door.x .. "," .. door.y ..
						"," .. door.z .. " is blocked on the " ..
						(sign == 1 and "inside" or "outside"))
				assert(standable(sx, door.y - 1, sz),
					label .. ": the doorstep at " .. sx .. "," ..
						(door.y - 1) .. "," .. sz .. " is not walkable")
			end
			local function jamb(jx, jz)
				return solid(jx, door.y, jz) or LEAF[node(jx, door.y, jz)]
			end
			assert(jamb(door.x + step[2], door.z - step[1]) and
				jamb(door.x - step[2], door.z + step[1]),
				label .. ": door orientation does not match its wall")
		end

		-- Every closed room is roofed and lit (section 5 invariant 4).
		local rooms = assert(blueprint.landmarks.rooms,
			label .. " has no room landmarks")
		for _, room in ipairs(rooms) do
			if room.closed then
				local lit = 0
				for z = room.min.z, room.max.z do
					for x = room.min.x, room.max.x do
						local covered = false
						for y = room.top + 1, spec.ymax do
							if node(x, y, z) ~= "air" then covered = true end
						end
						for y = 1, spec.ymax do
							if declared[x .. ":" .. y .. ":" .. z] then
								lit = lit + 1
							end
						end
						assert(covered, label .. ": interior column " .. x ..
							"," .. z .. " of room " .. tostring(room.id) ..
							" is open to the sky")
					end
				end
				assert(lit > 0, label .. ": the room " .. tostring(room.id) ..
					" is unlit")
			end
		end

		-- Every destination is reachable from the composition's own arrival
		-- point by the conservative walk.
		local arrival = assert(blueprint.landmarks.arrival,
			label .. " has no arrival landmark")
		assert(stand(arrival.x, arrival.y, arrival.z),
			label .. ": the arrival point is not standable")
		local start = arrival.x .. ":" .. arrival.y .. ":" .. arrival.z
		local queue, visited = {arrival}, {[start] = true}
		local cursor = 1
		local STEPS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
		while cursor <= #queue do
			local pos = queue[cursor]
			cursor = cursor + 1
			for _, offset in ipairs(STEPS) do
				local x, z = pos.x + offset[1], pos.z + offset[2]
				if x >= -spec.reach and x <= spec.reach and
						z >= -spec.reach and z <= spec.reach then
					for dy = -1, 1 do
						local y = pos.y + dy
						local key = x .. ":" .. y .. ":" .. z
						if y >= 1 and y <= spec.ymax and not visited[key] and
								stand(x, y, z) and
								(dy <= 0 or
									not solid(pos.x, pos.y + 2, pos.z)) and
								(dy >= 0 or not solid(x, pos.y + 1, z)) then
							visited[key] = true
							queue[#queue + 1] = {x = x, y = y, z = z}
						end
					end
				end
			end
		end
		for _, pos in ipairs(blueprint.landmarks.destinations) do
			assert(visited[pos.x .. ":" .. pos.y .. ":" .. pos.z],
				label .. ": unreachable interior " .. pos.id)
		end

		-- The socket contract, section 2, against the registry.
		local sockets = assert(blueprint.landmarks.sockets,
			label .. " publishes no sockets")
		local seen, roles, loops = {}, {}, {}
		local spare_count = 0
		local work_count, work_features = 0, 0
		for _, entry in ipairs(sockets) do
			assert(type(entry.id) == "string" and entry.id ~= "",
				label .. " publishes a socket with no id")
			assert(not seen[entry.id],
				label .. " publishes the socket id " .. entry.id .. " twice")
			seen[entry.id] = true
			roles[entry.role] = (roles[entry.role] or 0) + 1
			assert(entry.face ~= nil and entry.face >= 0 and entry.face <= 3,
				label .. ": socket " .. entry.id .. " has no facedir")
			local dx, dz = parts.facedir_step(entry.face)
			assert(entry.dir and entry.dir.x == dx and entry.dir.z == dz,
				label .. ": socket " .. entry.id ..
					" publishes a dir that is not its own facing")
			assert(free(entry.x, entry.y, entry.z) and
					free(entry.x, entry.y + 1, entry.z),
				label .. ": socket " .. entry.id .. " has no headroom at " ..
					entry.x .. "," .. entry.y .. "," .. entry.z)
			assert(standable(entry.x, entry.y - 1, entry.z),
				label .. ": socket " .. entry.id .. " stands on air at " ..
					entry.x .. "," .. entry.y .. "," .. entry.z)
			if entry.role == "guard_patrol" then
				assert(type(entry.group) == "string" and
						type(entry.order) == "number",
					label .. ": patrol waypoint " .. entry.id ..
						" carries no loop or no order")
				loops[entry.group] = loops[entry.group] or {}
				assert(loops[entry.group][entry.order] == nil,
					label .. ": the loop " .. entry.group ..
						" has two waypoints at order " .. entry.order)
				loops[entry.group][entry.order] = entry.id
			else
				assert(entry.group == nil and entry.order == nil,
					label .. ": socket " .. entry.id ..
						" carries a patrol field but is no waypoint")
			end
			--
			-- THE VENDOR FAMILIES of section 8.4: the two `grug_traders`
			-- families plus the five professions. Which of them a district may
			-- publish, and the rule that the capital holds at most one of each
			-- kind, are asserted where the whole capital is in hand; here the
			-- kind only has to BE one.
			--
			if entry.role == "vendor" then
				assert(VENDOR_KINDS[entry.kind],
					label .. ": vendor " .. entry.id .. " names no family")
			else
				assert(entry.kind == nil, label .. ": socket " .. entry.id ..
					" carries a vendor family but is no vendor")
			end
			--
			-- A WORKPLACE (section 8.1). Every standing test above has already
			-- run against it, because a work socket is held to every rule an
			-- idle socket is. What is left is its own three:
			--
			--   * it names an activity of the closed vocabulary;
			--   * it is a SPAWN socket -- a workplace nobody works at is a
			--     spare with a hammer in its hand, and the contract gives
			--     `spawn = false` to `idle` alone;
			--   * the FEATURE the activity names stands where `dir` points,
			--     within three nodes. That is the rule a moved piece of
			--     dressing breaks, and nothing else in the tree would see it.
			--
			if entry.role == "work" then
				assert(ACTIVITIES[entry.activity], label .. ": the work " ..
					"socket " .. entry.id .. " names the activity " ..
					tostring(entry.activity) .. ", which is not one of the " ..
					"contract's")
				assert(entry.spawn == nil, label .. ": the work socket " ..
					entry.id .. " is spare, and only an idle socket may be")
				local wdx, wdz = parts.facedir_step(entry.face)
				local wanted = FEATURE[entry.activity]
				if wanted then
					--
					-- THE SEARCH STOPS AT THE FIRST SOLID NODE ON THE SOCKET'S
					-- OWN COURSE (contract section 8.1, 2026-09-15): a feature
					-- behind a wall does not count, because the resident cannot
					-- see or reach it. The cell that stops the search is
					-- examined first, so a counter or an anvil -- which is
					-- itself solid -- still counts at the range it stands at.
					--
					-- AND IT LOOKS AT THE RESIDENT'S OWN COURSE AND THE ONE
					-- ABOVE IT, not at the floor under its feet. `entry.y` is
					-- the feet cell, so `dy = -1` is the ground -- and the
					-- contract says "at head or chest height" for `mine` and
					-- names a candle, a marker, an anvil, a pot for the rest,
					-- none of which is a floor. The review of 2026-09-16 proved
					-- what the looser window bought by retyping one `pray`
					-- socket of the paved pyre court to `mine`: the KAT stayed
					-- green, satisfied by the court's own paving one course
					-- down. Nothing this capital ships needed that course --
					-- the same review's mutation of the quarry face turns the
					-- rule red with the window as it is now.
					local found, blocked = nil, false
					for reach = 1, 3 do
						local fx = entry.x + wdx * reach
						local fz = entry.z + wdz * reach
						if not blocked then
							for dy = 0, 1 do
								local cell = at(fx, entry.y + dy, fz)
								if found == nil and cell and wanted[cell.name] then
									found = cell.name
								end
							end
							if found == nil and solid(fx, entry.y, fz) then
								blocked = true
							end
						end
					end
					--
					-- `spar` HAS A SECOND READING, and the contract gives both
					-- (section 8.2): "another `spar` socket OR a training
					-- dummy". The dummy half is the name set above; the
					-- partner half is a question about the socket list and not
					-- about the cells, so it is answered here, where the list
					-- is in hand. Two guards two nodes apart facing each other
					-- is what sparring looks like and neither of them faces a
					-- fence post.
					if found == nil and entry.activity == "spar" then
						for _, other in ipairs(sockets) do
							if other ~= entry and other.role == "work" and
									other.activity == "spar" then
								for reach = 1, 3 do
									if other.x == entry.x + wdx * reach and
											other.z == entry.z + wdz * reach then
										found = "spar_partner"
									end
								end
							end
						end
					end
					assert(found, label .. ": the work socket " .. entry.id ..
						" does " .. entry.activity .. " but faces no " ..
						entry.activity .. " feature within three nodes of " ..
						entry.x .. "," .. entry.y .. "," .. entry.z)
					work_features = work_features + 1
				elseif entry.activity == "stall" then
					-- A counter: a solid node at the socket's own feet
					-- course, which is waist height to somebody standing
					-- beside it.
					-- A counter IS the first solid node on the socket's own
					-- course, so the stopping rule above is this rule: the
					-- first solid cell within three either is the counter or
					-- there is none.
					local found = false
					for reach = 1, 3 do
						if not found and solid(entry.x + wdx * reach, entry.y,
								entry.z + wdz * reach) then
							found = true
						end
					end
					assert(found, label .. ": the work socket " .. entry.id ..
						" keeps a stall but faces no counter within three " ..
						"nodes")
					work_features = work_features + 1
				end
				work_count = work_count + 1
			else
				assert(entry.activity == nil, label .. ": socket " ..
					entry.id .. " carries an activity but is no workplace")
			end
			--
			-- A SPARE SOCKET (playtest round 2): a wander target of the amble
			-- that nobody is placed on. Every standing test above has already
			-- run against it -- a spare is a real authored position, not a
			-- coordinate -- and only an `idle` socket may be one, exactly as the
			-- runtime registry insists (grug_core/settlement_sockets.lua).
			--
			if entry.spawn ~= nil then
				assert(entry.spawn == false and entry.role == "idle",
					label .. ": only an idle socket may be spare: " .. entry.id)
				assert(entry.tags == nil, label .. ": the spare socket " ..
					entry.id .. " carries a tag")
				spare_count = spare_count + 1
			end
			--
			-- THE ELDER FACES THE STREET (user ruling, playtest round 2). The
			-- chapel's quest socket stands on the chapel doorstep facing the
			-- door, and `door` is what makes the consumer turn it round
			-- (start_npcs.lua socket_face_yaw). Both halves are measured: the
			-- authored facing runs into the building within five nodes, and the
			-- cell behind -- where the elder will actually look -- is free and
			-- is one of the positions the walk above reached.
			--
			-- Scoped to `quest`, because `door` is a CONSUMER rule ("turn this
			-- NPC round") and the capital's own gate and service sockets use it
			-- the other way round: they stand inside a gate looking in, and the
			-- turn faces them at the door they are about to leave by.
			--
			if entry.role == "quest" then
				assert(entry.tags and entry.tags[1] == "door",
					label .. ": the quest socket " .. entry.id ..
						" is not tagged `door`")
				local fdx, fdz = parts.facedir_step(entry.face)
				local closed_at
				for reach = 1, 5 do
					if closed_at == nil and
							not free(entry.x + fdx * reach, entry.y,
								entry.z + fdz * reach) then
						closed_at = reach
					end
				end
				assert(closed_at ~= nil, label .. ": the door socket " ..
					entry.id .. " faces open ground")
				local bx, bz = entry.x - fdx, entry.z - fdz
				assert(free(bx, entry.y, bz) and
					visited[bx .. ":" .. entry.y .. ":" .. bz],
					label .. ": the door socket " .. entry.id ..
						" has no open street behind it")
			end
		end
		-- The patrol loops: one group per composition, and its orders are
		-- 1..n with no gap. A loop with a gap is a walk that teleports.
		-- A DISTRICT plot carries only its own share of the district's loop
		-- -- one loop over nine compositions -- so only a composition that
		-- owns a whole loop is held to 1..n here; the district's own walk is
		-- assembled and checked across its plots below.
		local loop_count, loop_length = 0, 0
		for group, orders in pairs(loops) do
			loop_count = loop_count + 1
			local length = 0
			for _ in pairs(orders) do length = length + 1 end
			if spec.whole_loop then
				for order = 1, length do
					assert(orders[order], label .. ": the loop " .. group ..
						" has no waypoint at order " .. order)
				end
			end
			loop_length = loop_length + length
		end
		assert(loop_count == spec.loops, label .. " publishes " ..
			loop_count .. " patrol loops, not " .. spec.loops)
		for role, wanted in pairs(spec.roles) do
			assert((roles[role] or 0) == wanted, label .. " publishes " ..
				(roles[role] or 0) .. " " .. role .. " sockets, not " ..
				wanted)
		end
		for role in pairs(roles) do
			assert(spec.roles[role] ~= nil, label ..
				" publishes an unexpected " .. role .. " socket")
		end
		assert(spare_count == (spec.spare or 0), label .. " publishes " ..
			spare_count .. " spare sockets, not " .. (spec.spare or 0))

		return {cells = #cells, solids = solids, palette = palette_count,
			lights = lights, doors = #doorways, rooms = #rooms,
			sockets = #sockets, spare = spare_count, water = #water_cells,
			work = work_count, work_features = work_features, roles = roles,
			reachable = #queue, panes = panes,
			attached = attached, torches = torches, oriented = oriented,
			loop = loop_length, node = node, at = at, stand = stand,
			index = index}
	end

	-- ------------------------------------------------------------------
	-- 1. the core
	-- ------------------------------------------------------------------
	local core = capital.core()
	local CORE = {
		reach = 47, ymin = -2, ymax = 40, budget = 150000,
		min_lights = 40, min_doors = 12, loops = 5,
		-- The four gatehouses' chamber floors and fighting decks, and the
		-- four corner drums' own paved floors. Nothing else in the core is a
		-- floor over air. The number is DECLARED and not derived, for the
		-- reason written above the test: no geometric rule separates a
		-- chamber floor carried on its piers from a cantilevered apron.
		raised = 505, whole_loop = true,
		-- The capital's socket roster, exactly. The three singular roles are
		-- the reason the composition owns a socket policy at all: one
		-- throne, one travel pad for WP17, two `grug_traders` vendor
		-- families.
		-- 6 waypoints in the city's own loop -- four precinct corners and the
		-- two colonnades -- and 8 in the four gate towers' own two-waypoint
		-- watches.
		-- The idle count is every idle socket the core publishes INCLUDING
		-- the 10 SPARES of playtest round 2, which nobody is placed on and
		-- every core citizen may wander to; `spare` says how many of them
		-- those are.
		roles = {king = 1, waypoint = 1, quest = 1, vendor = 2, work = 3,
			guard_post = 12, guard_patrol = 14, idle = 42},
		spare = 10,
	}
	local core_result = check_composition("nhal veyr core", core, CORE)

	-- The core is FLAT: y = 0 is its ground course everywhere it builds, and
	-- only foundations reach below it (contract section 2.1).
	local FOOTING = {}
	for _, role in ipairs({"foundation", "subsoil"}) do
		FOOTING[undead.node(role)] = true
	end
	FOOTING[undead.node("castle_wall")] = true
	FOOTING[undead.node("signature")] = true
	FOOTING["grug_decor:darkage_marble"] = true
	local footings, ground_cells = 0, 0
	for _, cell in ipairs(core.cells) do
		if cell.y < 0 then
			assert(FOOTING[cell.name], "capital core: " .. cell.name ..
				" is buried at y " .. cell.y .. "; only footings go below " ..
				"the flat ground course")
			footings = footings + 1
		elseif cell.y == 0 then
			ground_cells = ground_cells + 1
		end
	end
	assert(ground_cells >= 95 * 95 - 200, "capital core: the ground " ..
		"course has " .. ground_cells .. " cells, so the core is not flat " ..
		"ground from edge to edge")

	-- The authored populations, exactly. The floor the composition lays inside
	-- the mausoleum, the gravewood stands it plants, the burial ground it
	-- scatters, the parapet it walks round the pad, the barred openings in
	-- that parapet, the four corner drums and the blight flora are ALL placed
	-- by rules that can silently plant nothing -- a band that finds no paving,
	-- a corner with no open ground, a scatter whose every column is already
	-- taken -- and the number is what says they did not. Dawnmere lost 22 of
	-- 27 props to exactly that shape of code, and this composition lost all
	-- but one of its gravewoods to it once, because the burial ground ran
	-- first.
	for _, row in ipairs({{"nave_floor", 90}, {"gravewoods", 15},
			{"graves", 122}, {"parapet_columns", 229}, {"parapet_bars", 56},
			{"corner_drums", 4}, {"flora", 1413}}) do
		assert(core.landmarks[row[1]] == row[2], "the core's " .. row[1] ..
			" population is " .. tostring(core.landmarks[row[1]]) ..
			", not " .. row[2])
	end

	-- The four gate openings and their avenues: five wide, walkable end to
	-- end, and each one really reaching its gate at the core edge.
	local RADIUS = 47
	for _, gate in ipairs({"south", "north", "east", "west"}) do
		local box = assert(core.landmarks["avenue_" .. gate],
			"capital core has no avenue_" .. gate)
		local edge = assert(core.landmarks["gate_" .. gate],
			"capital core has no gate_" .. gate)
		assert(math.abs(edge.x) == RADIUS or math.abs(edge.z) == RADIUS,
			"the " .. gate .. " gate is not on the core edge")
		local width = (box.max.x - box.min.x == 4) and "x" or "z"
		assert(width == "x" or box.max.z - box.min.z == 4,
			"the " .. gate .. " avenue is not five wide")
		local blocked = 0
		for z = box.min.z, box.max.z do
			for x = box.min.x, box.max.x do
				if not core_result.stand(x, 1, z) then
					blocked = blocked + 1
				end
			end
		end
		assert(blocked == 0, "the " .. gate .. " avenue is blocked in " ..
			blocked .. " columns")
		-- The gate column itself is on the avenue and walkable, so the road
		-- really leaves the core there.
		assert(core_result.stand(edge.x, edge.y, edge.z),
			"the " .. gate .. " gate opening is not passable")
	end

	-- The king stands on his throne: the socket looks at the seat, one node
	-- in front of it, which is what "the throne room the king encounter will
	-- use" means for an entity placer.
	local king
	for _, entry in ipairs(core.landmarks.sockets) do
		if entry.role == "king" then king = entry end
	end
	assert(king, "capital core publishes no king socket")
	assert(THRONE, "the undead palette binds no throne")
	local found_throne = false
	for dz = -2, 2 do
		for dx = -1, 1 do
			if core_result.node(king.x + dx, king.y, king.z + dz) == THRONE then
				found_throne = true
			end
		end
	end
	assert(found_throne, "the king socket is not at the throne")
	-- ... and the king SITS THE RIGHT WAY ROUND. Playtest round 1 found the
	-- backrest between the king and his hall. Both nodes the throne role can
	-- bind carry their back on their own +Z side -- the chair's posts and back
	-- panel, a stair-seat's raised half -- and a facedir node's +Z side looks
	-- along `facedir_to_dir(param2)`, so the seat looks the OTHER way. Derived
	-- from FACEDIR_DIR here rather than from `parts.seat`'s `(face + 2) % 4`,
	-- which is the arithmetic under test, and compared against the king
	-- socket's own facing so the two cannot drift apart.
	--
	-- The window is searched exhaustively and the seat must be ALONE in it: with
	-- two chairs beside the king the orientation test below would silently be
	-- about whichever one the loop happened to end on.
	local throne_cell, throne_count = nil, 0
	for dz = -2, 2 do
		for dx = -1, 1 do
			local cell = core_result.at(king.x + dx, king.y, king.z + dz)
			if cell and cell.name == THRONE then
				throne_cell = cell
				throne_count = throne_count + 1
			end
		end
	end
	assert(throne_cell, "the throne is not a cell of the core")
	assert(throne_count == 1, "the king socket has " .. throne_count ..
		" thrones within reach, so none of them is THE throne")
	local back = assert(FACEDIR_DIR[throne_cell.param2],
		"the throne carries a param2 outside the upright facedir family")
	-- `0 - 0` is a NEGATIVE zero in a double and prints as "-0", which would put
	-- a byte in the report that means nothing; the cardinal directions are the
	-- only values here, so flip the sign only where there is one.
	local function opposite(value) return value == 0 and 0 or -value end
	local look = {opposite(back[1]), opposite(back[2])}
	local king_look = assert(FACEDIR_DIR[king.face],
		"the king socket carries a param2 outside the upright facedir family")
	assert(look[1] == king_look[1] and look[2] == king_look[2],
		"the throne looks " .. look[1] .. "," .. look[2] ..
			" while the king it seats looks " .. king_look[1] .. "," ..
			king_look[2])
	-- And that shared direction is DOWN THE APPROACH: the great door is the
	-- low-z end of the hall, so both must look at -z.
	local hall = assert(core.landmarks.kings_hall)
	assert(look[1] == 0 and look[2] == -1,
		"the throne does not look at the great door")
	assert(throne_cell.z > hall.min.z and throne_cell.z <= hall.max.z,
		"the throne is not at the far end of its own hall")
	say("nhal_veyr_throne", throne_cell.param2, king.face,
		look[1] .. "," .. look[2], "great_door")
	-- ... and the throne is inside the hall's own landmark box.
	assert(king.x >= hall.min.x and king.x <= hall.max.x and
		king.z >= hall.min.z and king.z <= hall.max.z,
		"the king socket is outside the king's hall")

	-- The two vendor families are the two the runtime knows.
	local families = {}
	for _, entry in ipairs(core.landmarks.sockets) do
		if entry.role == "vendor" then
			assert(not families[entry.kind],
				"two vendors of the family " .. entry.kind)
			families[entry.kind] = entry.id
		end
	end
	assert(families.race and families.general,
		"the core does not publish one vendor of each family")

	-- The waypoint plaza is flat and open: nothing but its own paving inside
	-- the reserved square, so WP17's travel pad has room and sky.
	local plaza = assert(core.landmarks.waypoint_plaza)
	local occupied = 0
	for z = plaza.min.z, plaza.max.z do
		for x = plaza.min.x, plaza.max.x do
			for y = 1, 40 do
				if core_result.node(x, y, z) ~= "air" then
					occupied = occupied + 1
				end
			end
		end
	end
	assert(occupied == 0, "the waypoint plaza carries " .. occupied ..
		" cells inside the area reserved for WP17")
	local waypoint
	for _, entry in ipairs(core.landmarks.sockets) do
		if entry.role == "waypoint" then waypoint = entry end
	end
	assert(waypoint and waypoint.x >= plaza.min.x and
		waypoint.x <= plaza.max.x and waypoint.z >= plaza.min.z and
		waypoint.z <= plaza.max.z, "the waypoint socket is not on its plaza")

	-- A second construction cannot depend on table iteration order.
	local again = capital.core()
	assert(#again.cells == #core.cells, "the core is not deterministic")
	for position, cell in ipairs(core.cells) do
		local other = again.cells[position]
		for _, field in ipairs({"x", "y", "z", "name", "param2"}) do
			assert(cell[field] == other[field],
				"non-deterministic core architecture at cell " .. position)
		end
	end
	assert(#again.landmarks.sockets == #core.landmarks.sockets,
		"the core's socket list is not deterministic")

	say("nhal_veyr_core", core.schema, core_result.cells, core_result.solids,
		core_result.palette, core_result.lights, core_result.doors,
		core_result.rooms, core_result.sockets, core_result.spare,
		core_result.loop, core_result.reachable, footings, ground_cells)

	-- ------------------------------------------------------------------
	-- 2. the four districts, their lots and the seeded permutation
	-- ------------------------------------------------------------------
	--
	-- The contract's four district roles stand one per quadrant, and which
	-- role stands where is a permutation of the world seed. Two things follow
	-- and both are checked here rather than assumed:
	--
	--   * a LOT is a lot whichever district takes it, so the geometry (no two
	--     lots sharing ground, none on a street, in a gate corridor, on the
	--     core or outside its own quarter) is checked on the 36 LOTS, once,
	--     independently of any assignment -- which is what makes it true for
	--     all 24 permutations instead of for the one this run happened to
	--     build;
	--   * every plot of every district therefore has to FIT that lot: inside
	--     +-13 of its origin, clearing at least 8 nodes of airspace.
	local PLOT = {
		reach = 15, ymin = -6, ymax = 24, budget = 12000,
		min_lights = 2, min_doors = 0, loops = 1, raised = 0,
	}
	-- A plot whose part carries paving with nothing under it declares how
	-- many such cells it has, exactly, the same way the core declares its
	-- 505. Nhal Veyr has none: its two watchposts carry a timber deck and not
	-- a paved one, and no plot of this capital stands a colonnade.
	local PLOT_RAISED = {}
	-- The plots of this capital that write water: NONE. The undead envelope
	-- has no water column anywhere on either gate seed and this capital digs
	-- no pond, so the blanket refusal stands unweakened -- which is worth an
	-- empty table rather than a deleted rule, because the next terrain change
	-- that put a river here would then be caught.
	local PLOT_WATER = {}
	-- Which plots carry one of their district's four spare wander spots.
	-- Declared rather than measured, for the same reason the core declares
	-- its ten: a spare that quietly stops being one is a wander target that
	-- has become somebody's permanent doorstep.
	local PLOT_SPARES = {
		market_copse = 1, market_charnel = 1,
		watch_drill_yard = 1, watch_tower = 1,
		vigil_copse = 1, vigil_cloister = 1,
		homes_fallen_east = 1, homes_cistern = 1,
		-- and the ones each district's DRESSINGS carry
		market_bone_yard = 1, market_close = 1,
		watch_bone_rampart = 1, watch_close = 1,
		vigil_ruin_close = 1, vigil_close = 1,
		homes_blight_garden = 1, homes_green = 1,
	}
	local quadrants = dofile(wp13 .. "/nhal_veyr_quadrants.lua")()
	local districts = dofile(wp13 .. "/nhal_veyr_districts.lua")(wp13)
	local plot_builder = dofile(wp13 .. "/nhal_veyr_plot.lua")(wp13)

	-- THE LOT ENVELOPE IS ONE NUMBER SET, TYPED IN TWO FILES.
	--
	-- `nhal_veyr_plot.lua` builds to it, `nhal_veyr_quadrants.lua` chose the
	-- lots against it, and this file checks both -- so a third copy typed here
	-- would be a KAT that passes while the builder and the grids disagree.
	-- These four asserts are what binds them; everything below reads the
	-- modules.
	local LOT_REACH = quadrants.LOT.reach
	local LOT_CLEAR = quadrants.LOT.clear
	assert(plot_builder.REACH == quadrants.LOT.reach,
		"the plot builder reaches " .. plot_builder.REACH ..
			" and the lots were chosen for " .. quadrants.LOT.reach)
	assert(-plot_builder.FLOOR == quadrants.LOT.fall,
		"the foundation skirt reaches " .. -plot_builder.FLOOR ..
			" and the lots allow a fall of " .. quadrants.LOT.fall)
	assert(plot_builder.MIN_CLEAR == quadrants.LOT.clear,
		"a plot clears at least " .. plot_builder.MIN_CLEAR ..
			" and the lots were chosen against " .. quadrants.LOT.clear)
	assert(quadrants.LOT.rise < quadrants.LOT.clear,
		"a lot may rise " .. quadrants.LOT.rise ..
			" into an airspace of " .. quadrants.LOT.clear)

	-- 2a. The permutation.
	--
	-- It is arithmetic on a digest, so it is checked as arithmetic: all 24
	-- indices decode to 24 distinct permutations of four, the canonical
	-- assignment is the identity one, a seed answers the same thing twice,
	-- and the two gate seeds and a spread of small ones do not all answer the
	-- same thing (a permutation that never permutes is the defect this row
	-- exists to catch).
	do
		local seen, count = {}, 0
		for index = 0, 23 do
			local permutation = quadrants.permutation_of_index(index)
			assert(#permutation == 4, "permutation " .. index .. " is not four")
			local used = {}
			for position = 1, 4 do
				local value = permutation[position]
				assert(value >= 1 and value <= 4 and not used[value],
					"permutation " .. index .. " is not a permutation")
				used[value] = true
			end
			local key = table.concat(permutation, ",")
			assert(not seen[key], "two indices decode to " .. key)
			seen[key] = true
			count = count + 1
		end
		assert(count == 24, "the factorial decode is not onto")
		local canonical = quadrants.canonical()
		for position = 1, 4 do
			assert(canonical[position] == position,
				"the canonical assignment is not the authored order")
		end
		local sha = common.new_sha256()
		local answers, distinct = {}, 0
		for _, seed in ipairs({"531802985935182545", "8675309", "0", "1", "2",
				"3", "12345", "999999999"}) do
			local first = table.concat(quadrants.permutation(seed, sha), ",")
			local again = table.concat(quadrants.permutation(seed, sha), ",")
			assert(first == again, "seed " .. seed .. " is not deterministic")
			if not answers[first] then
				answers[first] = true
				distinct = distinct + 1
			end
			say("nhal_veyr_quadrant_permutation", seed, first)
		end
		assert(distinct >= 4, "eight seeds produced only " .. distinct ..
			" assignments; the permutation does not permute")
		-- A world's seed is a string of digits, and nothing else is.
		local refused = pcall(quadrants.permutation, "not a seed", sha)
		assert(not refused, "the permutation accepted a seed that is not one")
		-- And a permutation handed in from outside is a bijection or it is
		-- refused: two roles on one quadrant would put two districts on one
		-- set of lots and leave a quarter of the capital empty, which nothing
		-- downstream would notice.
		assert(quadrants.check_permutation({4, 3, 2, 1}),
			"the guard refused a permutation")
		for _, broken in ipairs({{1, 1, 2, 3}, {1, 2, 3}, {1, 2, 3, 5},
				{1, 2, 3, 0}, {1, 2, 3, "4"}, {1, 2, 3, 4, 1}}) do
			assert(not pcall(quadrants.check_permutation, broken),
				"the guard accepted something that is not a permutation")
			assert(not pcall(quadrants.assign, {permutation = broken}),
				"assign accepted something that is not a permutation")
		end
	end

	-- 2b. The 36 lots.
	--
	-- `ENVELOPE_EDGE` is the outermost column a lot's footprint may occupy:
	-- 250 is the field the plot predicate measures and the seam's terrain
	-- audit walks a two-node margin round every reference plot, so 248 is the
	-- last column that leaves that margin inside it.
	local ENVELOPE_EDGE = 248
	do
		local runs = {}
		for _, list in ipairs({capital.avenues, capital.ring,
				quadrants.lane_runs()}) do
			for _, spec in ipairs(list) do runs[#runs + 1] = spec end
		end
		-- The curtain is a run of the same overlay, so a lot may no more
		-- stand on it than on a street; it is `wall.HALF` either side of its
		-- centre line rather than the road's verge, which is why it is
		-- appended here with its own half-width rather than folded into the
		-- list above.
		local wall_runs = {}
		for _, spec in ipairs(capital.wall) do
			wall_runs[#wall_runs + 1] = spec
		end
		-- Every lane starts on an avenue, which is what makes a district
		-- reachable from the city rather than merely near it, and no two runs
		-- share an id (the overlay's identity is the list of them).
		local run_ids = {}
		for _, spec in ipairs(runs) do
			assert(not run_ids[spec.id], "two street runs are called " .. spec.id)
			run_ids[spec.id] = true
		end
		for _, lane in ipairs(quadrants.lane_runs()) do
			local met = false
			for _, spec in ipairs(capital.avenues) do
				-- An avenue and a lane meet where the lane's END lies inside
				-- the avenue's carriageway.
				for _, at in ipairs({lane.from, lane.to}) do
					local x = (lane.axis == "x") and at or lane.at
					local z = (lane.axis == "x") and lane.at or at
					local along = (spec.axis == "x") and x or z
					local across = (spec.axis == "x") and z or x
					if along >= math.min(spec.from, spec.to) - 2 and
							along <= math.max(spec.from, spec.to) + 2 and
							math.abs(across - spec.at) <= 2 then
						met = true
					end
				end
			end
			assert(met, lane.id .. " starts on no avenue, so its district is " ..
				"not reached from the city")
		end
		local STREET_HALF = math.floor(avenue.WIDTH / 2) + 1
		local lots, lot_count = {}, 0
		for turns = 0, 3 do
			local name = quadrants.QUADRANTS[turns + 1]
			local grid = assert(quadrants.LOTS[name],
				"quadrant " .. tostring(name) .. " has no lots")
			assert(#grid == #quadrants.AUTHORED,
				name .. " does not carry one lot per authored lot")
			for index, lot in ipairs(grid) do
				local id = name .. "/" .. index
				local x0, x1 = lot.x - LOT_REACH, lot.x + LOT_REACH
				local z0, z1 = lot.z - LOT_REACH, lot.z + LOT_REACH
				-- INSIDE THE 512 ENVELOPE, with the two-node margin the
				-- seam's own terrain audit walks round every reference plot:
				-- an edge at 248 leaves that margin inside +-250, which is
				-- the field the plot predicate measures and the ground WP40
				-- terraces. Being clear of the CURTAIN is a separate rule and
				-- is asserted against the wall runs below, so this number is
				-- about the envelope alone.
				assert(math.max(math.abs(x0), math.abs(x1)) <= ENVELOPE_EDGE and
					math.max(math.abs(z0), math.abs(z1)) <= ENVELOPE_EDGE,
					id .. " leaves the envelope")
				-- off the civic core
				assert(x0 > 48 or x1 < -48 or z0 > 48 or z1 < -48,
					id .. " stands on the civic core")
				-- in its OWN quarter: rotated back into the authored
				-- south-east frame it must be clear of both avenues by the
				-- quarter's own margin, which is what stops two districts
				-- meeting in a corner.
				local qx, qz = quadrants.rotate(lot.x, lot.z, 4 - turns)
				assert(qx - LOT_REACH >= quadrants.LOT.quarter and
					qz + LOT_REACH <= -quadrants.LOT.quarter,
					id .. " leaves its own quarter")
				-- off every street run, carriageway and verge
				for _, spec in ipairs(runs) do
					local along_min = (spec.axis == "x") and x0 or z0
					local along_max = (spec.axis == "x") and x1 or z1
					local across_min = (spec.axis == "x") and z0 or x0
					local across_max = (spec.axis == "x") and z1 or x1
					local overlap = along_max >= math.min(spec.from, spec.to) and
						along_min <= math.max(spec.from, spec.to) and
						across_max >= spec.at - STREET_HALF and
						across_min <= spec.at + STREET_HALF
					assert(not overlap, id .. " stands on " .. spec.id)
				end
				-- off the curtain wall, which is `wall.HALF` either side of
				-- its own centre line
				for _, spec in ipairs(wall_runs) do
					local along_min = (spec.axis == "x") and x0 or z0
					local along_max = (spec.axis == "x") and x1 or z1
					local across_min = (spec.axis == "x") and z0 or x0
					local across_max = (spec.axis == "x") and z1 or x1
					local overlap = along_max >= math.min(spec.from, spec.to) and
						along_min <= math.max(spec.from, spec.to) and
						across_max >= spec.at - wall.HALF and
						across_min <= spec.at + wall.HALF
					assert(not overlap, id .. " stands on " .. spec.id)
				end
				-- clear of the 32-node gate corridor of every avenue
				for _, spec in ipairs(capital.avenues) do
					local along_min = (spec.axis == "x") and x0 or z0
					local along_max = (spec.axis == "x") and x1 or z1
					local across_min = (spec.axis == "x") and z0 or x0
					local across_max = (spec.axis == "x") and z1 or x1
					if along_max >= math.min(spec.from, spec.to) and
							along_min <= math.max(spec.from, spec.to) then
						assert(across_min > spec.at + 16 or
							across_max < spec.at - 16,
							id .. " reaches into the gate corridor of " .. spec.id)
					end
				end
				-- and a lane between it and every other lot, in every
				-- quadrant at once
				for _, other in ipairs(lots) do
					local apart = (x0 > other.x1 + quadrants.LOT.lane) or
						(x1 + quadrants.LOT.lane < other.x0) or
						(z0 > other.z1 + quadrants.LOT.lane) or
						(z1 + quadrants.LOT.lane < other.z0)
					assert(apart, id .. " has no lane between it and " .. other.id)
				end
				lots[#lots + 1] = {id = id, x0 = x0, x1 = x1, z0 = z0, z1 = z1}
				lot_count = lot_count + 1
			end
		end
		assert(lot_count == 36, "the capital has " .. lot_count .. " lots")
		say("nhal_veyr_lots", lot_count, #quadrants.QUADRANTS,
			#quadrants.AUTHORED, LOT_REACH, quadrants.LOT.lane, #runs,
			#quadrants.lane_runs())
		-- AND WHERE THE THIRTY-SIX ACTUALLY STAND.
		--
		-- Everything above is a geometric rule, and a lot that MOVES four nodes
		-- still keeps every one of them, so until WP13 round 3 the whole fixture
		-- set answered byte-identically while three lots walked. A lot position
		-- is a design decision made against measured ground; it may move, but it
		-- may not move quietly. This row is the grid itself.
		local grid_rows = {}
		for turns = 0, 3 do
			local name = quadrants.QUADRANTS[turns + 1]
			for index, lot in ipairs(quadrants.LOTS[name]) do
				grid_rows[#grid_rows + 1] = table.concat({name, index, lot.x,
					lot.z}, ":")
			end
		end
		say("nhal_veyr_lot_grid", #grid_rows,
			common.hex(common.new_sha256()(table.concat(grid_rows, "\n"))))

		-- 2b-bis. THE 16 FILL LOTS (playtest round 3).
		--
		-- The dressings stand on lots of their own, and a fill lot is held to
		-- the same geometry the 36 are -- envelope, core, quarter, streets,
		-- gate corridors, the curtain -- with two differences the fill
		-- envelope owns: its own reach per slot, and a lane of 4 rather than 8,
		-- because a garden between two cottages is four nodes of grass. The
		-- terrain half is `nhal_veyr_plots.lua` against the two gate seeds; the
		-- geometry half is here, once, for all 24 permutations at the same
		-- time -- which is the whole reason a fill lot belongs to a QUADRANT
		-- and a fill plot to a district.
		local FILL = quadrants.FILL
		local fill_count = 0
		local fill_lots = {}
		for turns = 0, 3 do
			local name = quadrants.QUADRANTS[turns + 1]
			local grid = assert(quadrants.FILL_LOTS[name],
				"quadrant " .. tostring(name) .. " has no fill lots")
			assert(#grid == #quadrants.FILL_AUTHORED,
				name .. " does not carry one fill lot per authored slot")
			for index, lot in ipairs(grid) do
				local reach = quadrants.FILL_AUTHORED[index].reach
				assert(type(reach) == "number" and reach >= 3 and
					reach <= LOT_REACH,
					"fill slot " .. index .. " has no usable reach")
				local id = name .. "/fill" .. index
				local x0, x1 = lot.x - reach, lot.x + reach
				local z0, z1 = lot.z - reach, lot.z + reach
				assert(math.max(math.abs(x0), math.abs(x1)) <= ENVELOPE_EDGE and
					math.max(math.abs(z0), math.abs(z1)) <= ENVELOPE_EDGE,
					id .. " leaves the envelope")
				assert(x0 > 48 or x1 < -48 or z0 > 48 or z1 < -48,
					id .. " stands on the civic core")
				local qx, qz = quadrants.rotate(lot.x, lot.z, 4 - turns)
				assert(qx - reach >= FILL.quarter and
					qz + reach <= -FILL.quarter,
					id .. " leaves its own quarter")
				for _, spec in ipairs(runs) do
					local along_min = (spec.axis == "x") and x0 or z0
					local along_max = (spec.axis == "x") and x1 or z1
					local across_min = (spec.axis == "x") and z0 or x0
					local across_max = (spec.axis == "x") and z1 or x1
					local overlap = along_max >= math.min(spec.from, spec.to) and
						along_min <= math.max(spec.from, spec.to) and
						across_max >= spec.at - STREET_HALF and
						across_min <= spec.at + STREET_HALF
					assert(not overlap, id .. " stands on " .. spec.id)
				end
				for _, spec in ipairs(wall_runs) do
					local along_min = (spec.axis == "x") and x0 or z0
					local along_max = (spec.axis == "x") and x1 or z1
					local across_min = (spec.axis == "x") and z0 or x0
					local across_max = (spec.axis == "x") and z1 or x1
					local overlap = along_max >= math.min(spec.from, spec.to) and
						along_min <= math.max(spec.from, spec.to) and
						across_max >= spec.at - wall.HALF and
						across_min <= spec.at + wall.HALF
					assert(not overlap, id .. " stands on " .. spec.id)
				end
				for _, spec in ipairs(capital.avenues) do
					local along_min = (spec.axis == "x") and x0 or z0
					local along_max = (spec.axis == "x") and x1 or z1
					local across_min = (spec.axis == "x") and z0 or x0
					local across_max = (spec.axis == "x") and z1 or x1
					if along_max >= math.min(spec.from, spec.to) and
							along_min <= math.max(spec.from, spec.to) then
						assert(across_min > spec.at + 16 or
							across_max < spec.at - 16,
							id .. " reaches into the gate corridor of " ..
								spec.id)
					end
				end
				-- A lane of 4 between it and every district lot, and between
				-- it and every other fill lot. Two rectangles are apart when
				-- they are apart on EITHER axis, which is the rule a garden
				-- strip between two houses needs: it overlaps them in z and
				-- clears them in x.
				for _, other in ipairs(lots) do
					local apart = (x0 > other.x1 + FILL.lane) or
						(x1 + FILL.lane < other.x0) or
						(z0 > other.z1 + FILL.lane) or
						(z1 + FILL.lane < other.z0)
					assert(apart, id .. " has no lane between it and " ..
						other.id)
				end
				for _, other in ipairs(fill_lots) do
					local apart = (x0 > other.x1 + FILL.lane) or
						(x1 + FILL.lane < other.x0) or
						(z0 > other.z1 + FILL.lane) or
						(z1 + FILL.lane < other.z0)
					assert(apart, id .. " has no lane between it and " ..
						other.id)
				end
				fill_lots[#fill_lots + 1] = {id = id, x0 = x0, x1 = x1,
					z0 = z0, z1 = z1}
				fill_count = fill_count + 1
			end
		end
		assert(fill_count == 16, "the capital has " .. fill_count ..
			" fill lots")
		say("nhal_veyr_fill_lots", fill_count, #quadrants.FILL_AUTHORED,
			FILL.lane, quadrants.FILL_AUTHORED[1].reach,
			quadrants.FILL_AUTHORED[3].reach, quadrants.FILL_AUTHORED[4].reach)
		-- AND WHERE THE SIXTEEN FILL LOTS ACTUALLY STAND, for the reason
		-- above and in a row of their own. Folding them into the digest above
		-- would move a value `main` froze this morning for a reason that has
		-- nothing to do with the dressings.
		local fill_grid_rows = {}
		for turns = 0, 3 do
			local name = quadrants.QUADRANTS[turns + 1]
			for index, lot in ipairs(quadrants.FILL_LOTS[name] or {}) do
				fill_grid_rows[#fill_grid_rows + 1] = table.concat({name, index,
					lot.x, lot.z, quadrants.FILL_AUTHORED[index].reach}, ":")
			end
		end
		say("nhal_veyr_fill_grid", #fill_grid_rows,
			common.hex(common.new_sha256()(table.concat(fill_grid_rows, "\n"))))
	end

	-- 2c. The four districts.
	local plot_list = districts.resolve()
	assert(#plot_list == 52, "the capital has " .. #plot_list .. " plots")
	-- The capital's whole socket census, filled per composition below: the
	-- vendor family rule of section 8.4 and the resident ratio of section 8.3
	-- are statements about the WHOLE capital and can only be made here.
	local capital_roles = {}
	local vendor_kinds = {}
	local activity_count = {}
	local function census(label, blueprint)
		for _, socket in ipairs(blueprint.landmarks.sockets) do
			capital_roles[socket.role] = (capital_roles[socket.role] or 0) + 1
			if socket.role == "vendor" then
				assert(vendor_kinds[socket.kind] == nil,
					"the capital publishes two " .. socket.kind ..
						" vendors: " .. tostring(vendor_kinds[socket.kind]) ..
						" and " .. label .. "/" .. socket.id)
				vendor_kinds[socket.kind] = label .. "/" .. socket.id
			end
			if socket.role == "work" then
				activity_count[socket.activity] =
					(activity_count[socket.activity] or 0) + 1
			end
			if socket.role == "idle" and socket.spawn == false then
				capital_roles.spare = (capital_roles.spare or 0) + 1
			end
		end
	end
	census("core", core)
	local seen_schema = {}
	local posts_by_role = {}
	local capital_plot_cells, worst_plot, worst_plot_id = 0, 0, "-"
	for district_index = 1, #districts.districts do
	local district = districts.districts[district_index]
	assert(district.role == quadrants.ROLES[district_index],
		"district " .. district_index .. " is not " ..
			quadrants.ROLES[district_index])
	assert(#district.plots == 9, district.key .. " has " ..
		#district.plots .. " plots")
	assert(#district.fill == 4, district.key .. " has " ..
		#district.fill .. " dressings")
	local district_cells, district_loop = 0, {}
	local district_spares, district_posts = 0, 0
	local taken = {}
	-- The nine building plots and then the four DRESSINGS, in the order the
	-- resolver hands them to the seam. Everything below holds a dressing to
	-- exactly the rules a building plot is held to, because a dressing IS a
	-- plot -- the only differences are the lot it stands on (its own reach)
	-- and that it publishes no patrol waypoint, having no place in the walk.
	local roster = {}
	for _, plot in ipairs(district.plots) do
		roster[#roster + 1] = {entry = plot, reach = LOT_REACH, kind = "plot"}
	end
	for index, plot in ipairs(district.fill) do
		roster[#roster + 1] = {entry = plot, kind = "fill",
			reach = quadrants.FILL_AUTHORED[index].reach}
	end
	for _, row in ipairs(roster) do
		local entry = row.entry
		local plot = entry.build()
		local spec = {}
		for key, value in pairs(PLOT) do spec[key] = value end
		spec.raised = PLOT_RAISED[entry.id] or 0
		spec.spare = PLOT_SPARES[entry.id] or 0
		spec.water = PLOT_WATER[entry.id]
		spec.loops = (row.kind == "fill") and 0 or PLOT.loops
		-- Every plot publishes the roles its own part publishes, so the
		-- multiset is read off the plot and only its SHAPE is asserted:
		-- at least one flair spot, and no role the contract does not name.
		spec.roles = {}
		for _, socket in ipairs(plot.landmarks.sockets) do
			spec.roles[socket.role] = (spec.roles[socket.role] or 0) + 1
		end
		for role in pairs(spec.roles) do
			assert(role == "guard_post" or role == "guard_patrol" or
				role == "idle" or role == "quest" or role == "vendor" or
				role == "work",
				entry.id .. " publishes the role " .. role ..
					", which no district plot may own")
		end
		assert((spec.roles.idle or 0) >= 1,
			entry.id .. " publishes no flair spot")
		local result = check_composition("plot " .. entry.id, plot, spec)
		district_cells = district_cells + result.cells
		census(entry.id, plot)

		-- The reference column: inside the plot, and a column the plot
		-- itself paves, because it is the column whose terrain height the
		-- whole plot is levelled to.
		local reference = assert(plot.reference,
			entry.id .. " publishes no reference column")
		assert(math.abs(reference.x) <= PLOT.reach and
			math.abs(reference.z) <= PLOT.reach,
			entry.id .. ": the reference column is outside the plot")
		local floor = result.at(reference.x, 0, reference.z)
		assert(floor and floor.name ~= "air" and walkable(floor.name),
			entry.id .. ": the reference column has no ground course")

		-- The foundation skirt reaches the contract's floor all the way
		-- round the plot, and the airspace above the plot is cleared.
		local box = assert(plot.landmarks.plot, entry.id .. " has no box")
		local skirted, cleared = 0, 0
		for z = box.min.z, box.max.z do
			for x = box.min.x, box.max.x do
				local edge = (x == box.min.x or x == box.max.x or
					z == box.min.z or z == box.max.z)
				if edge then
					for y = -1, -6, -1 do
						local cell = result.at(x, y, z)
						assert(cell and cell.name ~= "air",
							entry.id .. ": the skirt has a hole at " .. x ..
								"," .. y .. "," .. z)
					end
					skirted = skirted + 1
				end
				-- Up to the airspace the plot SAYS it cleared, which is its
				-- own roof and two courses over it, or the lot floor of 8
				-- where that is higher. Reading `bounds.max.y` instead
				-- would credit the plot with the headroom a lamp post or a
				-- fruit tree reaches into and never cut.
				for y = 1, plot.clear_to do
					assert(result.at(x, y, z) ~= nil, entry.id ..
						": the airspace at " .. x .. "," .. y .. "," .. z ..
						" was never cleared, so a terrace shoulder stays " ..
						"in the plot")
				end
				cleared = cleared + 1
			end
		end
		assert(skirted > 0 and cleared > 0, entry.id .. " has no plot box")

		-- THE PLOT FITS ITS LOT. Every geometric question about WHERE a
		-- plot stands is answered on the 36 lots in section 2b, once and for
		-- every permutation; what is left for the plot is that it fits
		-- inside the lot envelope those 36 answers were computed for. A plot
		-- one node wider than +-13 would make every one of them a claim
		-- about a footprint that is not this one.
		assert(plot.bounds.min.x >= -row.reach and
			plot.bounds.max.x <= row.reach and
			plot.bounds.min.z >= -row.reach and
			plot.bounds.max.z <= row.reach,
			entry.id .. " is wider than the lot envelope of +-" .. row.reach)
		assert(plot.clear_to >= LOT_CLEAR, entry.id .. " clears only " ..
			tostring(plot.clear_to) .. " nodes of airspace, and a lot may " ..
			"rise " .. quadrants.LOT.rise .. " under it")
		assert(not seen_schema[plot.schema],
			"two plots publish the schema " .. plot.schema)
		seen_schema[plot.schema] = true

		for _, socket in ipairs(plot.landmarks.sockets) do
			if socket.role == "guard_patrol" then
				assert(socket.group == district.patrol_group,
					entry.id .. ": the waypoint " .. socket.id ..
						" is not in the district's loop")
				assert(district_loop[socket.order] == nil,
					"the district loop has two waypoints at order " ..
						socket.order)
				district_loop[socket.order] = socket.id
			end
			if socket.role == "guard_post" then
				district_posts = district_posts + 1
			end
			-- A district publishes no `race` or `general` vendor:
			-- `grug_traders` has exactly two such families and the core's
			-- service court already carries one of each, so one out here
			-- would have the runtime place a third trader. A PROFESSION
			-- vendor is the opposite case (section 8.4): it belongs at the
			-- counter of the building that sells it, which is a district
			-- plot, and the capital-wide family rule above is what keeps it
			-- to one of each.
			assert(socket.role ~= "king" and socket.role ~= "waypoint",
				entry.id .. " publishes " .. socket.role ..
					", which belongs to the core alone")
			assert(socket.role ~= "vendor" or
					not CORE_VENDOR_KINDS[socket.kind],
				entry.id .. " publishes the " .. tostring(socket.kind) ..
					" vendor, which belongs to the core alone")
			-- A spare is `spawn = false` and nothing else -- no tag, the same
			-- way the core's ten are authored. `check_composition` has already
			-- held it to the role rule and to every standing test; this only
			-- counts them per district.
			if socket.spawn ~= nil then
				district_spares = district_spares + 1
			end
		end

		if result.cells > worst_plot then
			worst_plot, worst_plot_id = result.cells, entry.id
		end
		say("nhal_veyr_plot", entry.id, row.kind, result.cells,
			result.solids, result.palette, result.lights, result.doors,
			result.rooms, result.sockets, result.work, result.work_features,
			result.reachable, plot.clear_to)
	end
	-- The district's loop is one walk, 1..n, across all its plots.
	local district_length = 0
	for _ in pairs(district_loop) do district_length = district_length + 1 end
	for order = 1, district_length do
		assert(district_loop[order],
			"the " .. district.key .. " patrol loop has no waypoint at order " ..
				order)
	end
	assert(district_length >= 8, "the " .. district.key .. " patrol loop is " ..
		district_length .. " waypoints long")
	assert(district_cells <= 12000 * (#district.plots + #district.fill),
		district.key .. " is over its plot budget")
	-- FOUR spare wander spots per district since playtest round 3: the two
	-- the building plots have always carried, plus one on each of the two
	-- dressings that have room for one. The district gained residents with the
	-- work sockets, and a spare is where a walker goes that is not somebody
	-- else's doorstep (contract section 6), so the two numbers move together.
	assert(district_spares == 4, district.key .. " publishes " ..
		district_spares .. " spare wander spots, not four")
	-- The garrison is where the guard posts are. Not the ONLY place: a
	-- barracks publishes its own door post wherever it stands, and the
	-- market's watch house is a barracks. What the contract's "guard posts in
	-- the martial district" means is therefore that the garrison has them and
	-- has more of them than anybody else, which is the shape this asserts.
	posts_by_role[district.role] = district_posts
	capital_plot_cells = capital_plot_cells + district_cells
	say("nhal_veyr_district", district.key, district.role, #district.plots,
		district_cells, district_length, district_spares, district_posts)
	end

	-- ------------------------------------------------------------------
	-- 2d. THE CAPITAL'S SOCKET CENSUS (sockets contract sections 8.3 and 8.4)
	-- ------------------------------------------------------------------
	--
	-- Two of section 8's rules are statements about the WHOLE capital and can
	-- only be made once every composition has been read:
	--
	--   * AT MOST ONE VENDOR PER KIND. Asserted as the census is taken, above,
	--     because the second one is the interesting one and the message wants
	--     to name both. Here the seven kinds are printed and the two that
	--     belong to the core alone are checked to be the core's.
	--   * AT LEAST ONE IDLE SPAWN SOCKET PER FIVE RESIDENTS (section 8.3).
	--     A resident is a SPAWN socket: an `idle` that is not a spare, plus
	--     every `work`. The NPC lane makes every fifth idle spawn socket a
	--     walker and everything else static, and its own KAT asserts the
	--     resulting walker share is 10..30 % of residents -- which a capital
	--     of nothing but workplaces would fail. This is the structure lane's
	--     half of the same rule, and it is the half that has to hold BEFORE
	--     the NPC lane can pass its own.
	do
		local idle_total = capital_roles.idle or 0
		local spares = capital_roles.spare or 0
		local idle_spawn = idle_total - spares
		local work = capital_roles.work or 0
		local residents = idle_spawn + work
		assert(idle_spawn * 5 >= residents, "the capital has " .. residents ..
			" residents and only " .. idle_spawn .. " idle spawn sockets; " ..
			"section 8.3 wants one per five, so the NPC lane could not " ..
			"reach a walker share of 10 %")
		for kind in pairs(CORE_VENDOR_KINDS) do
			local where = vendor_kinds[kind]
			assert(where and where:sub(1, 5) == "core/",
				"the " .. kind .. " vendor is " .. tostring(where) ..
					" and belongs to the core")
		end
		local kinds = {}
		for kind in pairs(VENDOR_KINDS) do kinds[#kinds + 1] = kind end
		table.sort(kinds)
		local vendor_row = {}
		for _, kind in ipairs(kinds) do
			vendor_row[#vendor_row + 1] = kind .. "=" ..
				(vendor_kinds[kind] and 1 or 0)
		end
		local activities = {}
		for activity in pairs(ACTIVITIES) do activities[#activities + 1] = activity end
		table.sort(activities)
		local activity_row = {}
		for _, activity in ipairs(activities) do
			activity_row[#activity_row + 1] = activity .. "=" ..
				(activity_count[activity] or 0)
		end
		local roles = {}
		for role in pairs(capital_roles) do roles[#roles + 1] = role end
		table.sort(roles)
		local role_row = {}
		for _, role in ipairs(roles) do
			role_row[#role_row + 1] = role .. "=" .. capital_roles[role]
		end
		local total = 0
		for role, count in pairs(capital_roles) do
			if role ~= "spare" then total = total + count end
		end
		say("nhal_veyr_sockets", total, table.concat(role_row, ","))
		say("nhal_veyr_work", work, residents, idle_spawn,
			table.concat(activity_row, ","))
		say("nhal_veyr_vendors", #kinds, table.concat(vendor_row, ","))
	end

	do
		local garrison = posts_by_role.martial_garrison or 0
		assert(garrison >= 5, "the garrison publishes " .. garrison ..
			" guard posts")
		for role, count in pairs(posts_by_role) do
			assert(role == "martial_garrison" or count < garrison,
				role .. " publishes as many guard posts as the garrison")
		end
	end

	-- The whole capital against the contract's section 2.3 budget. The
	-- overlay is computed per mapchunk and stored nowhere, so what is counted
	-- is the core plus every plot of every district.
	assert(capital_plot_cells + core_result.cells <= 400000,
		"the capital is " .. (capital_plot_cells + core_result.cells) ..
			" cells, over the 400,000 budget")
	say("nhal_veyr_capital", core_result.cells, capital_plot_cells,
		core_result.cells + capital_plot_cells, worst_plot, worst_plot_id)

	-- ------------------------------------------------------------------
	-- 3. the avenue overlay
	-- ------------------------------------------------------------------
	--
	-- The overlay has no cells of its own until a surface is handed to it, so
	-- it is checked as a function: over profiles worse than the undead
	-- plateau's, in every lane, for the three properties the successor will
	-- depend on -- the road lies on the ground, it is walkable, and a piece
	-- of it is the same cells as that stretch of the whole run.
	--
	-- A cell at y spans [y - 0.5, y + 0.5]: a full node's walking surface is
	-- its top at y + 0.5, and a stair carries two, the top of its own lower
	-- half at y and its raised half at y + 0.5. A surface is only a surface
	-- when the cell above it is free.
	local function lane_tops(index, x, z, floor)
		local tops = {}
		for y = floor - 2, floor + 16 do
			local cell = index[x .. ":" .. y .. ":" .. z]
			if cell and index[x .. ":" .. (y + 1) .. ":" .. z] == nil then
				local def = world.nodes[cell.name]
				assert(def, "the avenue writes the unregistered " .. cell.name)
				local groups = (type(def.groups) == "table") and def.groups or {}
				if (groups.stair or 0) > 0 then tops[#tops + 1] = y end
				tops[#tops + 1] = y + 0.5
			end
		end
		return tops
	end

	-- Walk one lane end to end in half-node steps, which is what the engine
	-- lets a player do without jumping. Within a column every surface the
	-- walk can reach in half nodes is taken, up AND down: the two halves of
	-- one stair are exactly such a pair, and a flight is walked both ways.
	local function walk_lane(label, cells, from, to, ground, lanes)
		local index = {}
		for _, cell in ipairs(cells) do
			index[cell.x .. ":" .. cell.y .. ":" .. cell.z] = cell
		end
		local climbs = 0
		for _, z in ipairs(lanes) do
			local reach = nil
			for x = from, to do
				local tops = lane_tops(index, x, z, ground(x, z))
				assert(#tops > 0, label .. ": the column " .. x .. "," .. z ..
					" carries nothing to walk on")
				local here = {}
				if reach == nil then
					for _, top in ipairs(tops) do here[top] = true end
				else
					for _, top in ipairs(tops) do
						for previous in pairs(reach) do
							if math.abs(top - previous) <= 0.5 then
								here[top] = true
							end
						end
					end
				end
				local any = false
				for _ in pairs(here) do any = true end
				assert(any, label .. ": the road is not walkable into " ..
					"column " .. x .. " of lane " .. z ..
					" -- no surface within half a node of the last column")
				local spreading = true
				while spreading do
					spreading = false
					for _, top in ipairs(tops) do
						if not here[top] then
							for other in pairs(here) do
								if math.abs(top - other) <= 0.5 then
									here[top] = true
									spreading = true
								end
							end
						end
					end
				end
				if reach ~= nil then
					local same = true
					for top in pairs(here) do
						if not reach[top] then same = false end
					end
					if not same then climbs = climbs + 1 end
				end
				reach = here
			end
		end
		return climbs
	end

	-- (a) The pilot profile: a flat approach, a two-node rise (the undead
	-- terrace step), a four-node rise (dwarf and orc), a three-node drop
	-- (elf, undead and troll) and a flat tail, with the joints off the lamp
	-- rhythm and one node of cross fall on the southern verge, so the five
	-- lanes do not share one profile.
	local STEPS = {{-40, 20}, {-12, 22}, {5, 26}, {26, 23}}
	local function surface(x, z)
		local height = 20
		for _, step in ipairs(STEPS) do
			if x >= step[1] then height = step[2] end
		end
		if z <= -2 then height = height - 1 end
		return height
	end
	local queried = {}
	local function counted_surface(x, z)
		queried[x .. ":" .. z] = (queried[x .. ":" .. z] or 0) + 1
		return surface(x, z)
	end
	local avenue_spec = {id = "kat_avenue", axis = "x", at = 0, from = -48,
		to = 48, lamp_phase = -48}
	local run = avenue.run(undead, avenue_spec, counted_surface)

	-- One query per column, none twice, none outside the run's own
	-- carriageway, verges and look-around window. That window is what makes
	-- the overlay chunk independent, and it is also what it costs: five lanes
	-- over the span plus twice the reach, and the two verges only where the
	-- rhythm puts a lamp.
	local columns = 0
	for key, times in pairs(queried) do
		assert(times == 1, "the avenue queried the column " .. key .. " " ..
			times .. " times")
		local x, z = key:match("^(-?%d+):(-?%d+)$")
		x, z = tonumber(x), tonumber(z)
		assert(x >= avenue_spec.from - avenue.REACH and
			x <= avenue_spec.to + avenue.REACH,
			"the avenue queried " .. key .. ", outside its run and window")
		assert(math.abs(z) <= 3, "the avenue queried " .. key ..
			", outside its own carriageway and verges")
		columns = columns + 1
	end
	local lamp_positions = 0
	for p = avenue_spec.from, avenue_spec.to do
		if (p - avenue_spec.lamp_phase) % avenue.LAMP_SPACING == 0 then
			lamp_positions = lamp_positions + 1
		end
	end
	local wanted_columns = (avenue_spec.to - avenue_spec.from +
		2 * avenue.REACH + 1) * avenue.WIDTH + 2 * lamp_positions
	assert(columns == wanted_columns and run.queries == wanted_columns,
		"the avenue queried " .. columns .. " columns and reported " ..
			run.queries .. ", not the " .. wanted_columns ..
			" its carriageway, window and lamp rhythm need")

	-- (b) The road lies ON the ground: a cell at every column's surface, and
	-- nothing under it.
	local index = {}
	for _, cell in ipairs(run.cells) do
		index[cell.x .. ":" .. cell.y .. ":" .. cell.z] = cell
		assert(cell.y >= surface(cell.x, cell.z),
			"the avenue writes " .. cell.name .. " at " .. cell.y ..
				", under the surface of its own column")
	end
	for x = avenue_spec.from, avenue_spec.to do
		for z = -2, 2 do
			assert(index[x .. ":" .. surface(x, z) .. ":" .. z],
				"the avenue leaves the column " .. x .. "," .. z ..
					" unpaved at its surface")
		end
	end

	-- (c) Every lane walkable end to end.
	local climbs = walk_lane("kat_avenue", run.cells, avenue_spec.from,
		avenue_spec.to, surface, {-2, -1, 0, 1, 2})
	assert(climbs > 0, "the pilot profile produced no climb at all")

	-- (d) The lamps: on the rhythm, on both verges, each on its own column's
	-- surface with a torch on top of its standard.
	local lamp_columns = {}
	for _, lamp in ipairs(run.lamps) do
		assert(math.abs(lamp.z) == 3, "a lamp stands on the carriageway")
		assert(lamp.y == surface(lamp.x, lamp.z) + 3,
			"a lamp is not carried on its own column's surface")
		assert(LIGHT[index[lamp.x .. ":" .. lamp.y .. ":" .. lamp.z].name],
			"a lamp landmark is not a light")
		-- EVERY STANDARD STANDS ON ITS OWN FOOTING, written by the run itself.
		-- On ordinary ground the world's own terrain is under the post and the
		-- footing is a paving stone; over water it is the only thing there.
		-- Highcourt's east avenue crosses a river as a causeway, and sixteen
		-- standards stood in it before this rule, so the run may not rely on
		-- the world having put something under the verge.
		local base = index[lamp.x .. ":" .. (lamp.y - 3) .. ":" .. lamp.z]
		assert(base, "a lamp standard has no footing of its own at " ..
			lamp.x .. "," .. (lamp.y - 3) .. "," .. lamp.z ..
			"; over water it would stand on nothing")
		assert(base.name ~= parts.AIR and not LIQUID[base.name],
			"a lamp standard's footing is " .. base.name)
		local shaft = index[lamp.x .. ":" .. (lamp.y - 1) .. ":" .. lamp.z]
		assert(shaft and shaft.name == undead.node("post"),
			"a lamp standard has no shaft under its light")
		lamp_columns[lamp.x] = (lamp_columns[lamp.x] or 0) + 1
	end
	local spacing_ok = 0
	for x = avenue_spec.from, avenue_spec.to do
		if (x - avenue_spec.from) % avenue.LAMP_SPACING == 0 then
			assert(lamp_columns[x] == 2, "the avenue has " ..
				tostring(lamp_columns[x]) .. " lamps at " .. x .. ", not 2")
			spacing_ok = spacing_ok + 1
		else
			assert(lamp_columns[x] == nil,
				"the avenue lit a column off its own rhythm at " .. x)
		end
	end
	assert(spacing_ok > 4, "the lamp rhythm was never exercised")

	-- (e) Two runs of the same arguments are the identical cell list.
	local twin = avenue.run(undead, avenue_spec, surface)
	assert(#twin.cells == #run.cells, "the avenue is not deterministic")
	for position, cell in ipairs(run.cells) do
		local other = twin.cells[position]
		for _, field in ipairs({"x", "y", "z", "name", "param2"}) do
			assert(cell[field] == other[field],
				"non-deterministic avenue at cell " .. position)
		end
	end

	-- (f) The profiles the per-joint version could not carry, and the cut
	-- that proves the overlay is a per-chunk function.
	--
	-- Each profile is walked in every lane, and each is CUT at every column:
	-- the union of the two pieces has to be the whole run, cell for cell, or
	-- a successor emerging the road one mapchunk at a time gets a wall where
	-- a joint fell on a chunk border and a flight that lost its outer treads
	-- where it reached back over one.
	--
	-- The heights stay inside a range narrower than `avenue.REACH`, which is
	-- the condition the window's exactness rests on, and the assertion says
	-- so rather than trusting the profiles to be modest.
	local PROFILES = {
		{name = "four_node_rise", f = function(x)
			return (x >= 0) and 14 or 10
		end},
		{name = "adjacent_two_and_two", f = function(x)
			if x >= 2 then return 14 end
			if x >= 0 then return 12 end
			return 10
		end},
		{name = "adjacent_four_and_four", f = function(x)
			if x >= 1 then return 18 end
			if x >= 0 then return 14 end
			return 10
		end},
		{name = "terrace_stair", f = function(x)
			return 10 + 3 * math.max(0, math.min(6, math.floor((x + 12) / 2)))
		end},
		-- A random walk over the three race terrace steps, off the library's
		-- own position hash so both interpreters walk the same ground, and
		-- bounded the way WP40 bounds a capital envelope (cut 24, fill 16).
		{name = "random_terraces", f = function(x)
			local height = 20
			for step = -60, x do
				if step % 3 == 0 then
					local hash = parts.position_hash(step, 7) % 6
					local size = 2 + hash % 3
					if hash < 3 then
						height = height + size
					else
						height = height - size
					end
					if height > 32 then height = 32 end
					if height < 8 then height = 8 end
				end
			end
			return height
		end},
	}
	local SPLIT_FROM, SPLIT_TO = -16, 16
	local splits, split_cells = 0, 0
	for _, profile in ipairs(PROFILES) do
		local function ground(x, z)
			local height = profile.f(x)
			if z <= -2 then height = height - 1 end
			if z >= 2 then height = height + 1 end
			return height
		end
		local low, high
		for x = SPLIT_FROM - avenue.REACH, SPLIT_TO + avenue.REACH do
			for z = -3, 3 do
				local height = ground(x, z)
				if low == nil or height < low then low = height end
				if high == nil or height > high then high = height end
			end
		end
		assert(high - low < avenue.REACH, profile.name .. " spans " ..
			(high - low) .. " nodes, which the look-around window of " ..
			avenue.REACH .. " cannot see across")
		local function piece(from, to)
			return avenue.run(undead, {id = profile.name, axis = "x", at = 0,
				from = from, to = to, lamp_phase = SPLIT_FROM}, ground)
		end
		local whole = piece(SPLIT_FROM, SPLIT_TO)
		walk_lane(profile.name, whole.cells, SPLIT_FROM, SPLIT_TO, ground,
			{-2, -1, 0, 1, 2})
		local wanted = {}
		for _, cell in ipairs(whole.cells) do
			wanted[cell.x .. ":" .. cell.y .. ":" .. cell.z] =
				cell.name .. "/" .. cell.param2
		end
		split_cells = split_cells + #whole.cells
		for cut = SPLIT_FROM, SPLIT_TO - 1 do
			local union, count = {}, 0
			for _, half_run in ipairs({piece(SPLIT_FROM, cut),
					piece(cut + 1, SPLIT_TO)}) do
				for _, cell in ipairs(half_run.cells) do
					local key = cell.x .. ":" .. cell.y .. ":" .. cell.z
					local value = cell.name .. "/" .. cell.param2
					if union[key] == nil then count = count + 1 end
					union[key] = value
					assert(wanted[key] == value, profile.name ..
						": the piece cut at " .. cut .. " writes " .. value ..
						" at " .. key .. ", which the whole run does not")
				end
			end
			assert(count == #whole.cells, profile.name ..
				": the two pieces cut at " .. cut .. " carry " .. count ..
				" cells, the whole run " .. #whole.cells)
			splits = splits + 1
		end
	end

	-- (g) The four gate avenues and the ring street of the capital itself are
	-- runs this module can take, each starting clear of the core edge and
	-- ending at its gate station, and the ring is a closed circuit.
	local runs = 0
	for _, spec in ipairs(capital.avenues) do
		-- PAST the gate station, not to it. The curtain is centred on that
		-- same line at +-256 and its gate tunnel runs through the whole
		-- seven-node thickness, so a road that stopped at 256 would stop
		-- inside the gate; 261 leaves the tunnel by two nodes.
		assert(math.abs(spec.from) >= 256 or math.abs(spec.to) >= 256,
			"the avenue " .. spec.id .. " does not reach its gate station")
		assert(math.abs(spec.from) <= 261 and math.abs(spec.to) <= 261,
			"the avenue " .. spec.id .. " runs past the wall's own outer face")
		assert(math.abs(spec.from) >= 48 and math.abs(spec.to) >= 48,
			"the avenue " .. spec.id .. " starts inside the core")
		local ride = avenue.run(undead, {id = spec.id, axis = spec.axis,
			at = spec.at, from = spec.from, to = spec.from + 16}, surface)
		assert(#ride.cells > 0, "the avenue " .. spec.id .. " writes nothing")
		runs = runs + 1
	end
	local ring = {}
	for _, spec in ipairs(capital.ring) do
		ring[spec.id] = spec
		local ride = avenue.run(undead, {id = spec.id, axis = spec.axis,
			at = spec.at, from = spec.from, to = spec.from + 16}, surface)
		assert(#ride.cells > 0, "the ring run " .. spec.id .. " writes nothing")
		runs = runs + 1
	end
	-- The ring closes. Each side has to reach the centre line of the two runs
	-- that meet it, or the circuit has a hole at every corner -- which is
	-- what a ring street shorter than its own width apart really is.
	for _, along in ipairs({"west", "east"}) do
		for _, across in ipairs({"south", "north"}) do
			local side = assert(ring["ring_" .. along], "no ring_" .. along)
			local cap = assert(ring["ring_" .. across], "no ring_" .. across)
			assert(side.from <= cap.at and cap.at <= side.to,
				"the ring street stops short of the corner where ring_" ..
					along .. " meets ring_" .. across)
			assert(cap.from <= side.at and side.at <= cap.to,
				"the ring street stops short of the corner where ring_" ..
					across .. " meets ring_" .. along)
		end
	end

	say("nhal_veyr_avenue", #run.cells, run.pavement, run.treads, run.risers,
		#run.lamps, run.queries, climbs, runs, #PROFILES, splits, split_cells)

	-- ------------------------------------------------------------------
	-- 3a-bis. THE WALL RING (user ruling, playtest round 3)
	-- ------------------------------------------------------------------
	--
	-- Highcourt's curtain is the same module Dur Brannoc's is (`wp13/wall.lua`)
	-- in the undead palette, so it is held to the same five rules, which are the
	-- ones no road needs:
	--
	--   (a) EVERY CELL IS INSIDE THE RUN RECTANGLE the seam activates the run
	--       on -- `wall.HALF` either side of the centre line. A cell outside it
	--       is a cell in a mapchunk the run is never called for.
	--   (b) NO GAP. Every column of curtain is masonry, without a hole, from
	--       under its own lowest ground to its walk.
	--   (c) THE WALK IS WALKED: the deck changes by at most a node per column.
	--   (d) THE GATE IS OPEN: seven columns carry no masonry below the walk,
	--       through the whole thickness, so the avenue rides through it.
	--   (e) A PIECE OF A RUN IS EXACTLY THAT STRETCH of the whole run.
	--
	-- Plus the digest of the built geometry, for the reason the road's exists:
	-- an overlay's manifest identity is its SPECIFICATION and would not move if
	-- every node of the wall did.
	local WALL_LANES = wall.HALF
	assert(WALL_LANES == (avenue.WIDTH - 1) / 2 + 1,
		"the wall's own half-width is no longer the seam's activation band")
	assert(#capital.wall == 4, "a capital envelope has four sides, not " ..
		#capital.wall)
	local wall_by_id = {}
	for _, spec in ipairs(capital.wall) do
		wall_by_id[spec.id] = spec
		local plan = assert(capital.wall_plan[spec.id],
			"the wall run " .. spec.id .. " carries no plan")
		assert(plan.outside == 1 or plan.outside == -1,
			"the wall run " .. spec.id .. " does not say which side is the field")
		assert(#plan.gates == 1 and plan.gates[1] == 0,
			"the wall run " .. spec.id .. " does not carry exactly one gate " ..
				"on its own axis")
		assert(math.abs(spec.at) == 256,
			"the wall run " .. spec.id .. " is not on the 512 envelope edge")
	end
	for _, id in ipairs({"wall_west", "wall_east"}) do
		local plan = capital.wall_plan[id]
		assert(#plan.cross_towers == 2,
			id .. " does not carry the two corner turrets")
		assert(wall_by_id[id].to >= 256 + wall.TURRET_HALF,
			id .. " ends before its own corner turret does")
	end
	for _, id in ipairs({"wall_south", "wall_north"}) do
		local plan = capital.wall_plan[id]
		assert(#plan.cross_towers == 0, id .. " claims a corner turret")
		assert(wall_by_id[id].to <= 256 - WALL_LANES,
			id .. " reaches into the corner turret of the run it meets")
	end

	-- The synthetic ground the four runs are built over: the undead plateau's
	-- own two-node terraces, a flat reach, two steps one column apart and a
	-- cross fall across the wall's own thickness, which is what a river bank
	-- inside the envelope does to it.
	local function wall_ground(p)
		local y = 60
		if p > -150 then y = y - 2 end
		if p > -70 then y = y - 2 end
		if p > -69 then y = y - 2 end
		if p > 10 then y = y + 2 end
		if p > 80 then y = y - 2 end
		if p > 160 then y = y - 2 end
		return y
	end
	local function wall_surface(axis, at)
		return function(x, z)
			local p, lane
			if axis == "x" then p, lane = x, z - at else p, lane = z, x - at end
			local y = wall_ground(p)
			if lane >= 2 and p > -20 and p < 60 then y = y - 2 end
			return y
		end
	end

	local WALL_NAMES = {}
	for _, name in ipairs(wall.palette_names(undead)) do WALL_NAMES[name] = true end

	local wall_digest_rows, wall_cells, wall_columns = {}, 0, 0
	local wall_gaps, wall_steps, wall_passage = 0, 0, 0
	for _, spec in ipairs(capital.wall) do
		local plan = capital.wall_plan[spec.id]
		local wsurface = wall_surface(spec.axis, spec.at)
		local piece = wall.run(undead, {id = spec.id, axis = spec.axis,
			at = spec.at, from = spec.from, to = spec.to, width = avenue.WIDTH,
			lamp_spacing = avenue.LAMP_SPACING, lamp_phase = spec.from,
			reach = avenue.REACH}, wsurface, plan)
		wall_cells = wall_cells + #piece.cells
		wall_columns = wall_columns + piece.columns

		local at_cell = {}
		for _, cell in ipairs(piece.cells) do
			assert(WALL_NAMES[cell.name], spec.id .. " writes " .. cell.name ..
				", which is outside the wall's own palette")
			local p, lane
			if spec.axis == "x" then
				p, lane = cell.x, cell.z - spec.at
			else
				p, lane = cell.z, cell.x - spec.at
			end
			assert(lane >= -WALL_LANES and lane <= WALL_LANES,
				spec.id .. " writes a cell " .. lane ..
					" lanes from its centre line, outside the " .. WALL_LANES ..
					" the seam activates the run on")
			at_cell[p .. ":" .. lane .. ":" .. cell.y] = cell.name
			wall_digest_rows[#wall_digest_rows + 1] =
				table.concat({p, lane, cell.y, cell.name, cell.param2 or 0}, ":")
		end

		-- The walk of a column, read back out of the PIECE and not out of the
		-- module that wrote it: the highest solid cell of the centre lane that
		-- carries authored air directly above it.
		local function deck_of(p)
			for y = 140, 20, -1 do
				local here = at_cell[p .. ":0:" .. y]
				local above = at_cell[p .. ":0:" .. (y + 1)]
				if here ~= nil and here ~= parts.AIR and above == parts.AIR then
					return y
				end
			end
			return nil
		end

		local gate_from, gate_to = -wall.GATE_PASSAGE, wall.GATE_PASSAGE
		local previous_deck
		for p = spec.from, spec.to do
			local deck = deck_of(p)
			assert(deck, spec.id .. ": the column " .. p .. " has no walk at all")
			local in_gate = p >= gate_from and p <= gate_to
			if in_gate then
				for lane = -WALL_LANES, WALL_LANES do
					for y = wall_ground(p) + 1, deck - 1 do
						local name = at_cell[p .. ":" .. lane .. ":" .. y]
						assert(name == nil or name == parts.AIR,
							spec.id .. ": the gate passage at " .. p .. "," ..
								lane .. "," .. y .. " is " .. name)
					end
					wall_passage = wall_passage + 1
				end
			else
				for lane = -2, 2 do
					local ground = wsurface(
						spec.axis == "x" and p or spec.at + lane,
						spec.axis == "x" and spec.at + lane or p)
					local lowest
					for y = ground, 20, -1 do
						if at_cell[p .. ":" .. lane .. ":" .. y] == nil then
							lowest = y + 1
							break
						end
					end
					assert(lowest and lowest <= ground, spec.id ..
						": the curtain at " .. p .. "," .. lane ..
						" does not reach its own ground")
					for y = lowest, deck do
						local name = at_cell[p .. ":" .. lane .. ":" .. y]
						if name == nil or name == parts.AIR then
							wall_gaps = wall_gaps + 1
						end
					end
				end
			end
			if previous_deck ~= nil then
				local step = deck - previous_deck
				assert(math.abs(step) <= 1, spec.id ..
					": the walk changes by " .. step .. " nodes at column " .. p)
				if step ~= 0 then wall_steps = wall_steps + 1 end
			end
			previous_deck = deck
		end
	end
	assert(wall_gaps == 0, "the curtain has " .. wall_gaps ..
		" cells of hole between its footing and its walk")
	assert(wall_steps >= 12, "the test profile did not exercise the walk: " ..
		wall_steps .. " one-node steps")

	-- (e) a piece of a run is exactly that stretch of the whole run.
	local cut_spec = {id = "wall_east", axis = "z", at = 256, from = -40,
		to = 40, width = avenue.WIDTH, lamp_spacing = avenue.LAMP_SPACING,
		lamp_phase = -40, reach = avenue.REACH}
	local cut_plan = capital.wall_plan.wall_east
	local cut_surface = wall_surface("z", 256)
	local whole_wall = wall.run(undead, cut_spec, cut_surface, cut_plan)
	local whole_index = {}
	for _, cell in ipairs(whole_wall.cells) do
		whole_index[cell.x .. ":" .. cell.y .. ":" .. cell.z] =
			cell.name .. ":" .. (cell.param2 or 0)
	end
	local wall_splits = 0
	for cut = cut_spec.from, cut_spec.to - 1 do
		local union, count = {}, 0
		for _, half in ipairs({{cut_spec.from, cut}, {cut + 1, cut_spec.to}}) do
			local piece = wall.run(undead, {id = cut_spec.id, axis = "z",
				at = 256, from = half[1], to = half[2], width = cut_spec.width,
				lamp_spacing = cut_spec.lamp_spacing,
				lamp_phase = cut_spec.lamp_phase, reach = cut_spec.reach},
				cut_surface, cut_plan)
			for _, cell in ipairs(piece.cells) do
				local key = cell.x .. ":" .. cell.y .. ":" .. cell.z
				local value = cell.name .. ":" .. (cell.param2 or 0)
				assert(whole_index[key] == value, cut_spec.id ..
					": the piece cut at " .. cut .. " writes " .. value ..
					" at " .. key .. ", which the whole run does not")
				if union[key] == nil then
					union[key] = value
					count = count + 1
				end
			end
		end
		assert(count == #whole_wall.cells, cut_spec.id ..
			": the two pieces cut at " .. cut .. " carry " .. count ..
			" cells, the whole run " .. #whole_wall.cells)
		wall_splits = wall_splits + 1
	end

	-- (f) THE CROSSING RULE DOES NOT REACH THE WALL.
	--
	-- Since the route lane landed, the seam hands every run of an overlay an
	-- `overhead(x, z)` callback and `avenue.run` ramps the carriageway up to a
	-- bridge deck wherever a route crosses with less than three blocks of
	-- clearance. A curtain must not do that: a wall that climbed to meet a deck
	-- would leave the ground it is founded on, which is the one thing
	-- `wall.lua`'s no-gap guarantee promises cannot happen.
	--
	-- `capital.overlay_run` therefore copies the spec WITHOUT `overhead`
	-- before handing it to the wall module. This is the bite test for that: the
	-- same run is built twice, once through `overlay_run` with an `overhead`
	-- that would lift a road six courses over its whole span, and once with no
	-- overhead at all, and the two cell lists must be identical. It goes red
	-- either if the dispatcher starts passing the seam on or if `wall.lua`
	-- starts reading it.
	do
		-- A deck two blocks over the ground, which is under the module's own
		-- `MIN_CLEAR` and therefore a column a road must climb onto rather
		-- than walk under.
		local lift_calls = 0
		local function lifting_overhead(x, z)
			lift_calls = lift_calls + 1
			return wall_ground(cut_spec.axis == "x" and x or z) + 2
		end
		local plain = wall.run(undead, cut_spec, cut_surface, cut_plan)
		local through = capital.overlay_run(avenue, undead, {
			id = cut_spec.id, axis = cut_spec.axis, at = cut_spec.at,
			from = cut_spec.from, to = cut_spec.to, width = cut_spec.width,
			lamp_spacing = cut_spec.lamp_spacing,
			lamp_phase = cut_spec.lamp_phase, reach = cut_spec.reach,
			overhead = lifting_overhead}, cut_surface)
		assert(#through.cells == #plain.cells, "the wall run built with an " ..
			"overhead carries " .. #through.cells .. " cells and the same run " ..
			"without one " .. #plain.cells .. ": the curtain obeyed the " ..
			"crossing rule")
		for index = 1, #plain.cells do
			local a, b = plain.cells[index], through.cells[index]
			assert(a.x == b.x and a.y == b.y and a.z == b.z and
				a.name == b.name and (a.param2 or 0) == (b.param2 or 0),
				"the wall run moved when it was given an overhead, at cell " ..
					index)
		end
		assert(lift_calls == 0, "the wall asked the overhead seam " ..
			lift_calls .. " questions; it may not ask any")
		local wall_lift_calls = lift_calls
		-- And the control: the ROAD does move when it is given the same
		-- overhead, so the test above is not passing because the fixture is
		-- inert.
		local road_plain = avenue.run(undead, {id = "control", axis = "z",
			at = 256, from = cut_spec.from, to = cut_spec.to,
			width = avenue.WIDTH, lamp_spacing = avenue.LAMP_SPACING,
			lamp_phase = cut_spec.from, reach = avenue.REACH}, cut_surface)
		local road_lifted = avenue.run(undead, {id = "control", axis = "z",
			at = 256, from = cut_spec.from, to = cut_spec.to,
			width = avenue.WIDTH, lamp_spacing = avenue.LAMP_SPACING,
			lamp_phase = cut_spec.from, reach = avenue.REACH,
			overhead = lifting_overhead}, cut_surface)
		assert(road_lifted.crossings and #road_lifted.crossings > 0,
			"the control road crossed nothing under a deck two blocks over " ..
				"its own ground, so the wall test proves nothing")
		assert(#road_lifted.cells ~= #road_plain.cells,
			"the control road did not move under a deck it has to climb, so " ..
				"the wall test proves nothing")
		say("nhal_veyr_wall_crossing", #plain.cells, wall_lift_calls,
			#road_plain.cells, #road_lifted.cells, #road_lifted.crossings,
			lift_calls)
	end

	-- (g) NO AVENUE LAMP STANDARD IN A WALL PIER: a lamp stands on the verge,
	-- and inside a gate that verge is a column of the gatehouse. The avenue is
	-- authored BEFORE the wall and wins every cell the two share, so the gate
	-- passage has to be at least as wide as the carriageway plus both verges.
	local lamps_in_gate = 0
	for _, spec in ipairs(capital.avenues) do
		local half = (avenue.WIDTH - 1) / 2 + 1
		for p = spec.from, spec.to do
			if (p - spec.from) % avenue.LAMP_SPACING == 0 then
				for _, side in ipairs({256, -256}) do
					local lane = p - side
					if lane >= -WALL_LANES and lane <= WALL_LANES then
						assert(half <= wall.GATE_PASSAGE,
							"the avenue's verge is " .. half ..
								" lanes out and the gate passage only " ..
								wall.GATE_PASSAGE .. " columns wide, so a " ..
								"standard stands in a pier")
						lamps_in_gate = lamps_in_gate + 1
					end
				end
			end
		end
	end

	say("nhal_veyr_wall", #capital.wall, wall_columns, wall_cells,
		wall_steps, wall_passage, wall_splits, lamps_in_gate,
		common.hex(common.new_sha256()(table.concat(wall_digest_rows, "\n"))))

	-- 3b. the BUILT GEOMETRY of the two real runs, digested
	--
	-- Everything above tests the overlay's PROPERTIES. Nothing hashed its
	-- output, and nothing else in the tree does either: the seam publishes the
	-- overlay's identity from its SPECIFICATION (it has no cells until a
	-- surface arrives), and the six-start engine gate excludes capitals by
	-- construction. So a change to `avenue.run` could move every node of every
	-- capital road and no gate would say a word.
	--
	-- This is that gate. Two of Highcourt's own runs -- the east avenue and the
	-- north one, one per axis -- are built over ONE synthetic profile that
	-- carries every feature the real ground has (terraces of each race step, a
	-- flat reach, and a stretch below a water line so the causeway and its lamp
	-- footings are in the digest), and the cell list is hashed. The profile is
	-- deterministic and interpreter-independent, so the two interpreters of the
	-- final micro pair agree on the value, and the engine pass digests the SAME
	-- runs as actually built in terrain (`run_capital.sh`).
	local function reference_profile(x, z)
		-- Terraces of 2, 3 and 4 over the run, a flat middle, and a basin that
		-- the walkable surface floors at the water line, which is how the
		-- successor hands a river to the overlay.
		local WATER = 12
		local ground
		if x < -160 then ground = 30 - 2 * math.floor((x + 256) / 24)
		elseif x < -60 then ground = 10 + 3 * math.floor((x + 160) / 20)
		elseif x < 40 then ground = 8
		else ground = 8 + 4 * math.floor((x - 40) / 30) end
		-- One node of cross fall, so the five lanes do not share a profile.
		if z > 0 then ground = ground - 1 end
		if ground < WATER then return WATER end
		return ground
	end
	local digest_rows = {}
	local digest_runs = 0
	for _, spec in ipairs({capital.avenues[4], capital.avenues[2]}) do
		local built = avenue.run(undead, {id = spec.id, axis = spec.axis,
			at = spec.at, from = spec.from, to = spec.to},
			reference_profile)
		digest_runs = digest_runs + 1
		digest_rows[#digest_rows + 1] = spec.id .. "/" .. #built.cells
		for _, cell in ipairs(built.cells) do
			digest_rows[#digest_rows + 1] = table.concat({cell.x, cell.y, cell.z,
				cell.name, cell.param2 or 0}, ":")
		end
		-- And on this profile every standard's footing is written by the run,
		-- which is what the causeway needs and the bare terrain does not care
		-- about.
		local built_index = {}
		for _, cell in ipairs(built.cells) do
			built_index[cell.x .. ":" .. cell.y .. ":" .. cell.z] = cell
		end
		for _, lamp in ipairs(built.lamps) do
			local base = built_index[lamp.x .. ":" .. (lamp.y - 3) .. ":" .. lamp.z]
			assert(base and base.name ~= parts.AIR and not LIQUID[base.name],
				"a standard of " .. spec.id .. " has no footing at " .. lamp.x ..
					"," .. lamp.z)
		end
	end
	assert(digest_runs == 2, "the built-geometry digest lost a run")
	say("nhal_veyr_avenue_built", digest_runs,
		common.hex(common.new_sha256()(table.concat(digest_rows, "\n"))))

	----------------------------------------------------------------------
	-- 7. THE GATE RAMP
	----------------------------------------------------------------------
	--
	-- The coordinator's ruling of 2026-09-16: an avenue ARRIVES AT ITS GATE
	-- POINT -- (ax +- 256, az), (ax, az +- 256), which is where Lane R ends its
	-- route at free-terrain height -- AT THE FREE TERRAIN THERE, descending
	-- inside the envelope at no more than a node a column, railed where the
	-- fill under it reaches three courses, nothing floating.
	--
	-- `avenue.lua` walks a road at the one-Lipschitz UPPER envelope of the
	-- ground and therefore cannot follow a slope that falls faster than a node
	-- a column: it rides out over its own fill instead, which is what this
	-- capital's north axis does on all nine seeds and what the independent
	-- review of 2026-09-16 found. The composition's answer is a CAP on the
	-- surface it hands the road module -- `min(ground, gate_y + |p - gate_at|)`
	-- -- and the two corrections that follow from it, the cutting and the rail
	-- (`wp13/nhal_veyr.lua`, the gate ramp).
	--
	-- This section holds the rule to a synthetic profile that falls TWO nodes a
	-- column into the gate, which is the shape of the real north axis and
	-- steeper than any of the other three.
	do
		local GATE = 256
		local RAIL_FILL = 3
		-- A plateau at 120 inland, falling TWO A COLUMN from 232 to 64 at 260,
		-- then flat: the shape of this capital's real north axis and steeper
		-- than any of the other three, continuous so that what the rules are
		-- tested against is the slope and not a cliff in the fixture.
		local function ground(p)
			if p <= 232 then return 120 end
			if p >= 260 then return 64 end
			return 120 - 2 * (p - 232)
		end
		local function surface(x, z)
			return ground(z)
		end
		local spec = {id = "avenue_north", axis = "z", at = 0, from = 48,
			to = 261, width = avenue.WIDTH,
			lamp_spacing = avenue.LAMP_SPACING, lamp_phase = 48,
			reach = avenue.REACH}
		local piece = capital.overlay_run(avenue, undead, spec, surface)
		assert(piece.gate_at == GATE, "the north avenue's gate point is " ..
			tostring(piece.gate_at) .. ", not " .. GATE)
		assert(piece.gate_y == ground(GATE),
			"the ramp anchored on " .. tostring(piece.gate_y) ..
				" and the free terrain at the gate point is " .. ground(GATE))

		-- The road's own surface per column, and the rail cells apart from it.
		local STONE = undead.maybe("castle_wall") or undead.node("wall_accent")
		local road_top, road_low, rail_at, air_at = {}, {}, {}, {}
		for _, cell in ipairs(piece.cells) do
			local key = cell.x .. ":" .. cell.z
			if cell.name == "air" then
				air_at[cell.x .. ":" .. cell.y .. ":" .. cell.z] = true
			else
				if road_top[key] == nil or cell.y > road_top[key] then
					road_top[key] = cell.y
				end
				if road_low[key] == nil or cell.y < road_low[key] then
					road_low[key] = cell.y
				end
			end
		end
		-- The rail sits one course over its kerb column, so the road's own top
		-- there is one lower. Both are needed, and both are derived here rather
		-- than trusted from the piece's own counters.
		for _, cell in ipairs(piece.cells) do
			if cell.name == STONE then
				local key = cell.x .. ":" .. cell.z
				if cell.y == road_top[key] then rail_at[key] = cell.y end
			end
		end

		local half = (avenue.WIDTH - 1) / 2
		-- (a) THE ROAD ARRIVES AT THE GATE AT THE FREE TERRAIN, on every lane.
		for offset = -half, half do
			local key = offset .. ":" .. GATE
			local top = assert(road_top[key],
				"the carriageway has no cell at the gate point on lane " ..
					offset)
			assert(top == ground(GATE), "lane " .. offset ..
				" arrives at the gate point at " .. top ..
				", and the free terrain there is " .. ground(GATE))
		end

		-- (b) AND IT DESCENDS A NODE A COLUMN AT MOST, the whole way.
		local worst_step = 0
		for offset = -half, half do
			for p = spec.from, spec.to - 1 do
				local here = road_top[offset .. ":" .. p]
				local next_one = road_top[offset .. ":" .. (p + 1)]
				if here and next_one then
					if rail_at[offset .. ":" .. p] then here = here - 1 end
					if rail_at[offset .. ":" .. (p + 1)] then
						next_one = next_one - 1
					end
					local rise = math.abs(here - next_one)
					if rise > worst_step then worst_step = rise end
				end
			end
		end
		assert(worst_step <= 1, "the ramp steps " .. worst_step ..
			" nodes between two columns")

		-- (c) EVERY KERB COLUMN THE ROAD FILLED BY THREE OR MORE IS RAILED,
		-- and nothing else is.
		local railed, filled = 0, 0
		for offset = -half, half do
			for p = spec.from, spec.to do
				local key = offset .. ":" .. p
				local top, low = road_top[key], road_low[key]
				if top and low then
					local span = top - low
					if rail_at[key] then span = span - 1 end
					local wants = (math.abs(offset) == half) and
						span >= RAIL_FILL
					if wants then filled = filled + 1 end
					assert((rail_at[key] ~= nil) == wants,
						"the column " .. key .. " spans " .. span ..
							" courses and " ..
							(rail_at[key] and "carries" or "carries no") ..
							" rail")
					if rail_at[key] then railed = railed + 1 end
				end
			end
		end
		assert(filled > 0,
			"this profile fills no kerb column, so the rail rule is untested")
		assert(railed == piece.rail, "the piece reports " .. piece.rail ..
			" rails and writes " .. railed)

		-- (d) THE CUTTING IS COMPLETE: wherever the cap put the road below the
		-- hillside, every cell between the road and the natural ground is air.
		local cut_deepest = 0
		for offset = -half, half do
			for p = spec.from, spec.to do
				local key = offset .. ":" .. p
				local top = road_top[key]
				if top and ground(p) > top then
					local depth = ground(p) - top
					if depth > cut_deepest then cut_deepest = depth end
					for y = top + 1, ground(p) do
						assert(air_at[offset .. ":" .. y .. ":" .. p],
							"the cutting at " .. key ..
								" leaves the hillside at y " .. y)
					end
				end
			end
		end
		assert(cut_deepest >= 3, "this profile cuts " .. cut_deepest ..
			" nodes, so the excavation rule is barely tested")
		assert(piece.cut_max == cut_deepest, "the piece reports a cut of " ..
			piece.cut_max .. " and cuts " .. cut_deepest)

		-- (e) AND A PIECE OF THE RUN IS EXACTLY THAT STRETCH OF THE WHOLE RUN.
		-- The ramp reads the surface through a cap that depends on ONE extra
		-- query at the gate column and on nothing else, so cutting the run in
		-- two must reproduce it cell for cell -- which is the property the
		-- successor's per-mapchunk call rests on.
		local whole = {}
		for _, cell in ipairs(piece.cells) do
			whole[cell.x .. ":" .. cell.y .. ":" .. cell.z] =
				cell.name .. "/" .. (cell.param2 or 0)
		end
		local splits = 0
		for _, cut in ipairs({120, 200, 244, 255}) do
			local count = 0
			for _, half_spec in ipairs({
					{from = spec.from, to = cut},
					{from = cut + 1, to = spec.to}}) do
				local part = capital.overlay_run(avenue, undead,
					{id = spec.id, axis = spec.axis, at = spec.at,
						from = half_spec.from, to = half_spec.to,
						width = spec.width, lamp_spacing = spec.lamp_spacing,
						lamp_phase = spec.lamp_phase, reach = spec.reach},
					surface)
				for _, cell in ipairs(part.cells) do
					local key = cell.x .. ":" .. cell.y .. ":" .. cell.z
					local value = cell.name .. "/" .. (cell.param2 or 0)
					assert(whole[key] == value, "the piece cut at " .. cut ..
						" writes " .. value .. " at " .. key ..
						" and the whole run writes " .. tostring(whole[key]))
					count = count + 1
				end
			end
			assert(count == #piece.cells, "the two pieces cut at " .. cut ..
				" carry " .. count .. " cells and the whole run " ..
				#piece.cells)
			splits = splits + 1
		end
		say("nhal_veyr_gate_ramp", piece.gate_at, piece.gate_y, #piece.cells,
			piece.cut, piece.rail, piece.fill_max, piece.cut_max, worst_step,
			splits)
	end

	return table.concat(report)
end
