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
	local capital = dofile(wp13 .. "/dur_brannoc.lua")(wp13)
	local wall = dofile(wp13 .. "/wall.lua")(wp13)
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

	-- The dwarf palette's own vocabulary, plus the two families the
	-- composition overrides into it. Used for the walk and the light rules.
	local dwarf = palettes.new("dwarf")
	local LIGHT = {}
	for _, role in ipairs({"light_wall", "light_post", "light_indoor"}) do
		LIGHT[dwarf.node(role)] = true
	end
	-- What a lamp standard may NOT stand on. The road writes none of these, so
	-- the set is the engine's water families rather than a palette role.
	local LIQUID = {["default:water_source"] = true,
		["default:water_flowing"] = true,
		["default:river_water_source"] = true,
		["default:river_water_flowing"] = true}
	local LEAF = {}
	for _, name in ipairs(dwarf.names("door")) do LEAF[name] = true end
	local HIDDEN = dwarf.node("door_hidden")
	local THRONE = dwarf.maybe("throne")

	-- ------------------------------------------------------------------
	-- THE WORK SOCKETS OF SECTION 8.1, and the feature each activity names
	-- ------------------------------------------------------------------
	--
	-- The sockets contract's section 8 adds the role `work`: a resident's
	-- workplace, always staffed, always static, naming the ACTIVITY it does and
	-- FACING the feature that activity works within three nodes. The registry
	-- (`grug_core/settlement_sockets.lua`) owns the closed vocabulary and
	-- refuses a typo at load; what it cannot do is look at the blueprint and
	-- see whether there is a rock face in front of the miner. That is this
	-- file's half of section 8.5 for the six WAVE-2 activities this capital
	-- places, and it is the half that catches the real defect: a socket whose
	-- dressing moved.
	--
	-- The vocabulary is spelled here rather than read from the registry because
	-- the registry is an engine module and this KAT has no engine; the two
	-- lists disagreeing is what `settlement_sockets_kat.lua` and the contract
	-- table are for.
	local ACTIVITIES = {smith = true, fish = true, farm = true, chop = true,
		tend = true, pray = true, stall = true, sit = true, sweep = true,
		mine = true, brew = true, carve = true, mourn = true, spar = true,
		forage = true}
	-- Section 8.4: the two `grug_traders` families, the five wave-1
	-- professions and the seven of wave 2.
	local VENDOR_KINDS = {race = true, general = true, butcher = true,
		smith = true, fishmonger = true, baker = true, tailor = true,
		mason = true, brewer = true, bowyer = true, herbalist = true,
		armourer = true, tanner = true, embalmer = true}
	-- The two the CORE alone may publish: `grug_traders` has exactly two
	-- vendor families and the core's forge court already carries one of each,
	-- so one out in a district would have the runtime place a third.
	local CORE_VENDOR_KINDS = {race = true, general = true}

	-- Which node names satisfy which activity. Built from the PALETTE's own
	-- roles wherever the contract names a palette thing ("a cauldron", "a
	-- log", "a stone block"), so a palette rebinding moves the rule with it.
	--
	-- `sit` and `sweep` name no feature: the contract says so in as many words.
	-- `stall` is geometric rather than a name list -- "a counter (any solid
	-- node at waist height)" -- and is answered below by solidity at the
	-- socket's own feet course. `spar` is the one rule whose feature may be
	-- ANOTHER SOCKET, and that half is answered where the whole composition's
	-- socket list is in hand.
	local FEATURE = {}
	local function feature_set(activity, roles, extra)
		local set = {}
		for _, role in ipairs(roles) do
			local name = dwarf.maybe(role)
			if name then set[name] = true end
		end
		for _, name in ipairs(extra or {}) do set[name] = true end
		FEATURE[activity] = set
	end
	feature_set("smith", {"workbench", "hearth"},
		{"default:furnace", "default:furnace_active"})
	feature_set("chop", {"tree_log", "post", "beam"}, {})
	-- `tend` is "a plant or a flower" and a stone trough is neither: the set is
	-- growing things and the soil they grow in, and nothing else. A bed's KERB
	-- is masonry and stops the search on the socket's own course, which is why
	-- `dressing.plant` exists and why every `tend` socket of this capital has a
	-- plant written at the cell it looks at.
	feature_set("tend", {"flower", "flower_alt", "hedge", "hedge_stem",
		"undergrowth", "grass_tuft", "fern", "crop", "tree_leaves",
		"planter_soil"}, {})
	feature_set("pray", {"light_post", "light_wall", "light_indoor",
		"low_wall", "signature"},
		{"doors:door_wood", "doors:door_wood_a", "doors:door_wood_b"})
	-- WAVE 2 (contract section 8.2, the six race-flavoured activities). Each
	-- set is the contract's own sentence read against the dwarf palette:
	--   `mine`   "a stone, ore or cobble node at head or chest height";
	--   `brew`   "a cauldron, barrel or a cooking pot node";
	--   `carve`  "a log, a totem/statue part or a stone block";
	--   `mourn`  "a grave marker, a coffin or a candle";
	--   `forage` "a mushroom, a bush, a plant, a vine or leaves".
	feature_set("mine", {"castle_wall", "castle_rubble", "foundation",
		"plaza", "plaza_edge", "path", "rubble", "signature", "wall_accent"},
		{})
	feature_set("brew", {"hearth", "storage"}, {})
	feature_set("carve", {"tree_log", "signature", "signature_stair",
		"signature_slab", "foundation", "plaza_edge", "wall_accent"}, {})
	feature_set("mourn", {"low_wall", "light_post", "light_wall"}, {})
	feature_set("forage", {"undergrowth", "fern", "grass_tuft", "tree_leaves",
		"flower", "planter_soil", "crop"}, {})

	-- Nodes an ordinary walk passes through. Everything else counts as solid,
	-- which keeps the route check conservative; a door counts as passable
	-- because a player opens it (pipeline contract section 5 invariant 3).
	local PASSABLE = {["air"] = true, [HIDDEN] = true}
	for name in pairs(LEAF) do PASSABLE[name] = true end
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
			assert(not cell.name:find("water") and not cell.name:find("lava"),
				label .. " writes a liquid")
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
			PAVED[dwarf.node(role)] = true
		end
		PAVED[dwarf.node("castle_paving")] = true
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
		local work_count, work_features, work_checked = 0, 0, 0
		local spar_sockets, spar_dummy = {}, {}
		local spares = 0
		for _, entry in ipairs(sockets) do
			assert(type(entry.id) == "string" and entry.id ~= "",
				label .. " publishes a socket with no id")
			assert(not seen[entry.id],
				label .. " publishes the socket id " .. entry.id .. " twice")
			seen[entry.id] = true
			roles[entry.role] = (roles[entry.role] or 0) + 1
			-- A SPARE SOCKET IS A DESTINATION, NOT A HOME. `spawn = false` is
			-- the sockets contract's own word (playtest round 2, 2026-09-15):
			-- the position is real and reaches every consumer, and nobody is
			-- placed on it, so a villager's amble has somewhere to go that is
			-- not another villager's doorstep. `grug_core/settlement_sockets.lua`
			-- refuses the field on any role but `idle`, and so does this: a
			-- `guard_post` with `spawn = false` is a gate nobody mans, written
			-- as one word.
			--
			-- The first version of this composition wrote its two spares as
			-- ordinary idle spots with a `walk` TAG, which is a description and
			-- not a contract -- the engine placed a villager on each of them.
			-- The tag says what the spot is for; this field is what the
			-- placement engine reads.
			if entry.spawn ~= nil then
				assert(entry.spawn == false, label .. ": socket " .. entry.id ..
					" carries a spawn field that is not false")
				assert(entry.role == "idle", label .. ": socket " ..
					entry.id .. " is a spare " .. entry.role ..
					", and only an idle socket may be spare")
				spares = spares + 1
			end
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
			-- THE VENDOR FAMILIES of section 8.4. Which of them a composition
			-- may publish, and the rule that the capital holds at most one of
			-- each kind, are asserted where the whole capital is in hand; here
			-- the kind only has to BE one, and the CORE is additionally held to
			-- the two `grug_traders` families it has always carried.
			if entry.role == "vendor" then
				assert(VENDOR_KINDS[entry.kind],
					label .. ": vendor " .. entry.id .. " names no family")
				if spec.core_vendors then
					assert(CORE_VENDOR_KINDS[entry.kind], label ..
						": the core may publish no " .. tostring(entry.kind) ..
						" vendor")
				end
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
				-- `sit` and `sweep` name no feature -- the contract says so in
				-- as many words -- so they are workplaces that are not counted
				-- as checked. Everything else is.
				if wanted or entry.activity == "stall" or
						entry.activity == "spar" then
					work_checked = work_checked + 1
				end
				if wanted then
					--
					-- THE SEARCH STOPS AT THE FIRST SOLID NODE ON THE SOCKET'S
					-- OWN COURSE (contract section 8.1): a feature behind a
					-- wall does not count, because the resident cannot see or
					-- reach it. The cell that stops the search is examined
					-- first, so a cauldron or a rock face -- which is itself
					-- solid -- still counts at the range it stands at.
					--
					local found, blocked = nil, false
					for reach = 1, 3 do
						local fx = entry.x + wdx * reach
						local fz = entry.z + wdz * reach
						if not blocked then
							for dy = -1, 1 do
								local cell = at(fx, entry.y + dy, fz)
								if found == nil and cell and
										wanted[cell.name] then
									found = cell.name
								end
							end
							if found == nil and solid(fx, entry.y, fz) then
								blocked = true
							end
						end
					end
					assert(found, label .. ": the work socket " .. entry.id ..
						" does " .. entry.activity .. " but faces no " ..
						entry.activity .. " feature within three nodes of " ..
						entry.x .. "," .. entry.y .. "," .. entry.z)
					work_features = work_features + 1
				elseif entry.activity == "stall" then
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
				elseif entry.activity == "spar" then
					-- "Another `spar` socket or a training dummy". The dummy
					-- half is `dressing.drill_post`, whose cap is the palette's
					-- `rug` over a `tree_log`; the partner half is answered
					-- after the whole socket list is read, below.
					local found = false
					for reach = 1, 3 do
						local fx = entry.x + wdx * reach
						local fz = entry.z + wdz * reach
						for dy = -1, 1 do
							local cell = at(fx, entry.y + dy, fz)
							if cell and (cell.name == dwarf.node("tree_log") or
									cell.name == dwarf.node("rug")) then
								found = true
							end
						end
					end
					spar_sockets[#spar_sockets + 1] = entry
					if found then work_features = work_features + 1 end
					spar_dummy[entry.id] = found
				end
				work_count = work_count + 1
			else
				assert(entry.activity == nil, label .. ": socket " ..
					entry.id .. " carries an activity but is no workplace")
			end
		end
		-- THE PARTNER HALF OF `spar`: a socket whose facing found no dummy is
		-- legal when another `spar` socket of the same composition stands
		-- within three nodes along its own facing. Both halves are built here,
		-- so both are checked.
		for _, entry in ipairs(spar_sockets) do
			if not spar_dummy[entry.id] then
				local wdx, wdz = parts.facedir_step(entry.face)
				local partner = false
				for _, other in ipairs(spar_sockets) do
					for reach = 1, 3 do
						if other.id ~= entry.id and
								other.x == entry.x + wdx * reach and
								other.z == entry.z + wdz * reach then
							partner = true
						end
					end
				end
				assert(partner, label .. ": the work socket " .. entry.id ..
					" spars but faces neither a training dummy nor another " ..
					"spar socket within three nodes")
				work_features = work_features + 1
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
		assert(spares == (spec.spares or 0), label .. " publishes " .. spares ..
			" spare sockets, not " .. (spec.spares or 0))

		return {cells = #cells, solids = solids, palette = palette_count,
			lights = lights, doors = #doorways, rooms = #rooms,
			sockets = #sockets, reachable = #queue, panes = panes,
			attached = attached, torches = torches, oriented = oriented,
			loop = loop_length, node = node, at = at, stand = stand,
			index = index, spares = spares, work = work_count,
			work_features = work_features, work_checked = work_checked,
			roles = roles}
	end

	-- ------------------------------------------------------------------
	-- 1. the core
	-- ------------------------------------------------------------------
	local core = capital.core()
	local CORE = {
		reach = 47, ymin = -2, ymax = 40, budget = 150000,
		min_lights = 40, min_doors = 12, loops = 5,
		-- 371 paved cells stand over air, and the number has two halves:
		-- 298 of them are STRUCTURE -- the four gatehouses' chamber floors
		-- (90 at y = 6) and their fighting decks (208 at y = 11), which is
		-- the same architecture Highcourt declares -- and 73 are an artefact
		-- of this palette's own spelling. The dwarf `plaza` role and its
		-- `signature` role are BOTH `default:stone_block`, so every string
		-- course, merlon band and statue block of signature masonry
		-- corbelled over air is counted here as well; Highcourt's signature
		-- is marble and its paving cobble, so its number sees only the
		-- floors. The declaration still does its job -- a podium built one
		-- node too small moves it -- but it is not only floors.
		raised = 371, whole_loop = true,
		-- The capital's socket roster, exactly. The three singular roles are
		-- the reason the composition owns a socket policy at all: one throne,
		-- one travel pad for WP17, two vendor families.
		-- Six waypoints in the city's own loop (the two colonnades and the
		-- four corners of the precinct) and 8 in the four gate towers' own
		-- two-waypoint watches. 34 idle spots, two of which are the SPARE
		-- wander-only spots this capital adds: the NPC lane walks a flair
		-- villager from one spot of its composition to another, and a roster
		-- with exactly as many spots as villagers gives every one of them the
		-- same two ends of the same line.
		roles = {king = 1, waypoint = 1, quest = 1, vendor = 2,
			guard_post = 12, guard_patrol = 14, idle = 34},
		-- The core is the one composition of this capital held to the two
		-- `grug_traders` families and nothing else: the profession vendors of
		-- the sockets contract's section 8.4 stand in the districts, at the
		-- counters of the buildings that sell them.
		core_vendors = true,
		-- Two of those 34 idle spots are SPARE, and the roster the runtime
		-- places is therefore 32 of them. Declared, because an authored spare
		-- that quietly became an ordinary spot is the exact defect the review
		-- of this package found.
		spares = 2,
	}
	local core_result = check_composition("dur brannoc core", core, CORE)

	-- The core is FLAT: y = 0 is its ground course everywhere it builds, and
	-- only foundations reach below it (contract section 2.1).
	local FOOTING = {}
	for _, role in ipairs({"foundation", "subsoil"}) do
		FOOTING[dwarf.node(role)] = true
	end
	FOOTING[dwarf.node("castle_wall")] = true
	FOOTING[dwarf.node("signature")] = true
	local footings, ground_cells = 0, 0
	for _, cell in ipairs(core.cells) do
		if cell.y < 0 then
			assert(FOOTING[cell.name], "dur brannoc core: " .. cell.name ..
				" is buried at y " .. cell.y .. "; only footings go below " ..
				"the flat ground course")
			footings = footings + 1
		elseif cell.y == 0 then
			ground_cells = ground_cells + 1
		end
	end
	assert(ground_cells >= 95 * 95 - 200, "dur brannoc core: the ground " ..
		"course has " .. ground_cells .. " cells, so the core is not flat " ..
		"ground from edge to edge")

	-- The authored populations, exactly. The floor the composition lays inside
	-- the king's hall, the pines it plants, the drums at the corners of the pad
	-- and the parapet it walks round it are all placed by rules that can
	-- silently place nothing -- a band that finds no paving, a corner with no
	-- open ground -- and the number is what says they did not. Dawnmere lost 22
	-- of 27 props to exactly that shape of code.
	--
	-- The parapet in particular: it is walked column by column round the whole
	-- boundary ring and skips every column that is paved or already built on,
	-- so 240 is the length of the four open stretches left between the four
	-- gatehouses, the four drums and the two avenues that leave the pad.
	for _, row in ipairs({{"nave_floor", 90}, {"pines", 12},
			{"corner_drums", 4}, {"parapet_columns", 240}}) do
		assert(core.landmarks[row[1]] == row[2], "the core's " .. row[1] ..
			" population is " .. tostring(core.landmarks[row[1]]) ..
			", not " .. row[2])
	end

	-- The four gate openings and their avenues: five wide, walkable end to
	-- end, and each one really reaching its gate at the core edge.
	local RADIUS = 47
	for _, gate in ipairs({"south", "north", "east", "west"}) do
		local box = assert(core.landmarks["avenue_" .. gate],
			"dur brannoc core has no avenue_" .. gate)
		local edge = assert(core.landmarks["gate_" .. gate],
			"dur brannoc core has no gate_" .. gate)
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
	assert(king, "dur brannoc core publishes no king socket")
	assert(THRONE, "the dwarf palette binds no throne")
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
	say("dur_brannoc_throne", throne_cell.param2, king.face,
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

	say("dur_brannoc_core", core.schema, core_result.cells, core_result.solids,
		core_result.palette, core_result.lights, core_result.doors,
		core_result.rooms, core_result.sockets, core_result.loop,
		core_result.reachable, footings, ground_cells, core_result.spares)

	-- ------------------------------------------------------------------
	-- 2. the four districts: 36 plots and 16 dressings
	-- ------------------------------------------------------------------
	--
	-- Wave 1 had ONE district of nine plots at hand-picked positions. Wave 2
	-- has four, one per quadrant, standing on the lot grids of
	-- `wp13/dur_brannoc_quadrants.lua`, and which district takes which quadrant
	-- is the world seed's. Everything below is therefore asserted of the
	-- RESOLVED list -- 52 entries with the offsets one assignment gives them --
	-- and the assignment itself is asserted separately, because a permutation
	-- that is not a bijection would put two districts on one grid and leave a
	-- quarter of the capital empty.
	local PLOT = {
		reach = 13, ymin = -6, ymax = 24, budget = 12000,
		min_lights = 2, min_doors = 0, loops = 1, raised = 0,
	}
	-- WHICH PLOTS CARRY AN UPPER FLOOR, and how many cells of it. No geometric
	-- test separates a roof deck carried on piers from a cantilevered apron --
	-- both have their bearing one node to the side -- so the number is
	-- declared, and a plot whose architecture moved shows up here as a number
	-- that moved. The market arcade is the only one of this capital's 52: a
	-- `capitals.colonnade` is a paved deck on two rows of piers.
	local PLOT_RAISED = {terrace_market = 59}
	-- The FILL lots are four deliberately different sizes and a dressing is
	-- clamped to its own lot's reach, so the envelope a fill composition is
	-- held to is the slot's and not the district lot's.
	local quadrants = capital.quadrants
	local districts = capital.districts

	assert(#districts.districts == 4,
		"Dur Brannoc has " .. #districts.districts .. " districts, not 4")
	for index, role in ipairs(quadrants.ROLES) do
		assert(districts.districts[index].role == role,
			"district " .. index .. " is not " .. role)
	end

	-- THE SEEDED PERMUTATION. Three properties, none of which the composition
	-- can check for itself: the canonical assignment is the identity, a seeded
	-- one is a bijection of the four roles onto the four quadrants, and two
	-- different seeds do not have to differ but the twenty-four indices must
	-- each produce a different permutation.
	do
		local canonical = quadrants.assign()
		local used = {}
		for _, role in ipairs(quadrants.ROLES) do
			local placement = canonical[role]
			assert(type(placement) == "table" and placement.lots,
				"the canonical assignment gives " .. role .. " no lots")
			assert(not used[placement.quadrant],
				"the canonical assignment puts two districts in " ..
					placement.quadrant)
			used[placement.quadrant] = role
		end
		local seen = {}
		for index = 0, 23 do
			local permutation = quadrants.permutation_of_index(index)
			local key = table.concat(permutation, ",")
			assert(not seen[key], "permutation index " .. index ..
				" repeats " .. key)
			seen[key] = index
			quadrants.check_permutation(permutation)
		end
		local ok = pcall(quadrants.check_permutation, {1, 1, 2, 3})
		assert(not ok, "a permutation that is not a bijection was accepted")
		-- The hash itself, against the framing R6 uses: the same seed and the
		-- same prefix must always give the same index, and Dur Brannoc's prefix
		-- must not give Highcourt's answer -- two capitals laying their
		-- districts out in lockstep is the defect a shared prefix produces.
		local highcourt_quadrants = dofile(wp13 .. "/highcourt_quadrants.lua")()
		local same, different = 0, 0
		for _, seed in ipairs({"531802985935182545", "8675309",
				"15912857179583385436", "0", "1", "2", "42", "12345",
				"999999999"}) do
			local mine = quadrants.permutation(seed, common.new_sha256())
			local twice = quadrants.permutation(seed, common.new_sha256())
			assert(table.concat(mine, ",") == table.concat(twice, ","),
				"the permutation of seed " .. seed .. " is not a function")
			local theirs =
				highcourt_quadrants.permutation(seed, common.new_sha256())
			if table.concat(mine, ",") == table.concat(theirs, ",") then
				same = same + 1
			else
				different = different + 1
			end
		end
		assert(different >= 5, "Dur Brannoc's district permutation follows " ..
			"Highcourt's on " .. same .. " of nine seeds, so the two prefixes " ..
			"are not independent")
		say("dur_brannoc_quadrants", #quadrants.QUADRANTS, #quadrants.ROLES,
			#quadrants.AUTHORED, #quadrants.FILL_AUTHORED,
			#quadrants.lane_runs(), same, different)
	end

	-- Every lot of every quadrant is inside the envelope, off the core, off the
	-- gate corridors and a lane clear of every other lot of its own quadrant.
	-- The TERRAIN half of the same question needs a world and is
	-- `tools/wp13/capital_lots.lua`; this is the half a composition can answer
	-- on its own, and it is here because the offline predicate needs nine
	-- engine field dumps to run at all.
	do
		local LOT = quadrants.LOT
		for turns = 0, 3 do
			local name = quadrants.QUADRANTS[turns + 1]
			local grid = quadrants.LOTS[name]
			assert(#grid == #quadrants.AUTHORED, name .. " has " .. #grid ..
				" lots, not " .. #quadrants.AUTHORED)
			local here = {}
			local function place(x, z, reach, lane, id)
				assert(math.abs(x) + reach <= 248 and
					math.abs(z) + reach <= 248,
					id .. " reaches past the gate stations")
				assert(math.abs(x) - reach > 47 or math.abs(z) - reach > 47,
					id .. " stands on the civic core")
				assert(math.abs(z) - reach > 16 or math.abs(x) + reach < 0,
					id .. " reaches into a gate corridor")
				assert(math.abs(x) - reach > 16, id ..
					" reaches into a gate corridor")
				for _, other in ipairs(here) do
					local gap = math.max(lane, other.lane)
					local far = math.abs(x - other.x) >
							reach + other.reach + gap or
						math.abs(z - other.z) > reach + other.reach + gap
					assert(far, id .. " stands less than a lane from " ..
						other.id)
				end
				here[#here + 1] = {x = x, z = z, reach = reach, lane = lane,
					id = id}
			end
			for index, lot in ipairs(grid) do
				place(lot.x, lot.z, LOT.reach, quadrants.FILL.lane,
					name .. "/" .. index)
			end
			local fill = quadrants.FILL_LOTS[name]
			assert(#fill == #quadrants.FILL_AUTHORED, name .. " has " ..
				#fill .. " fill lots, not " .. #quadrants.FILL_AUTHORED)
			for index, lot in ipairs(fill) do
				place(lot.x, lot.z, quadrants.FILL_AUTHORED[index].reach,
					quadrants.FILL.lane, name .. "/fill" .. index)
			end
		end
	end

	local resolved = districts.resolve()
	assert(#resolved == 52, "the four districts resolve to " .. #resolved ..
		" plots, not 52")

	local district_cells, district_spares = 0, 0
	local district_work, district_features, district_checked = 0, 0, 0
	local settlement_idle, placed_idle = 0, 0
	local loops_by_group = {}
	local vendor_kinds = {}
	local activity_count = {}
	local plot_ids = {}
	for _, entry in ipairs(core.landmarks.sockets) do
		if entry.role == "idle" then
			settlement_idle = settlement_idle + 1
			if entry.spawn ~= false then placed_idle = placed_idle + 1 end
		end
		if entry.role == "vendor" then
			assert(vendor_kinds[entry.kind] == nil,
				"the capital publishes two " .. entry.kind .. " vendors")
			vendor_kinds[entry.kind] = "core/" .. entry.id
		end
	end

	local taken = {}
	-- The street runs a plot may not stand on: the four avenues, the four
	-- sides of the ring, the eight district lanes -- five wide plus a verge --
	-- and the four sides of the CURTAIN, which are `wall.HALF` either side of
	-- their centre line. The rule is read off the same specs the overlay is
	-- given rather than approximated by the square round the anchor.
	--
	-- The wall and the lanes belong here and not only in the offline
	-- predicates: those need engine field dumps to run at all, so without this
	-- row a plot pushed against the curtain or across a lane would be caught
	-- only by somebody who had nine worlds to hand.
	local STREET_HALF = math.floor(avenue.WIDTH / 2)
	local street_runs = {}
	for _, list in ipairs({capital.avenues, capital.ring,
			quadrants.lane_runs()}) do
		for _, spec in ipairs(list) do
			street_runs[#street_runs + 1] = {spec = spec, half = STREET_HALF}
		end
	end
	for _, spec in ipairs(capital.wall) do
		street_runs[#street_runs + 1] = {spec = spec, half = wall.HALF}
	end
	local function on_a_street(x, z)
		for _, run in ipairs(street_runs) do
			local spec, half = run.spec, run.half
			local along = (spec.axis == "x") and x or z
			local across = (spec.axis == "x") and z or x
			if along >= math.min(spec.from, spec.to) - half and
					along <= math.max(spec.from, spec.to) + half and
					math.abs(across - spec.at) <= half then
				return spec.id
			end
		end
		return nil
	end

	for _, entry in ipairs(resolved) do
		local plot = entry.build()
		assert(not plot_ids[entry.id],
			"two compositions are called " .. entry.id)
		plot_ids[entry.id] = entry.district
		local reach = PLOT.reach
		if entry.kind == "fill" then
			reach = quadrants.FILL_AUTHORED[entry.lot].reach
		end
		local spec = {}
		for key, value in pairs(PLOT) do spec[key] = value end
		spec.reach = reach
		spec.raised = PLOT_RAISED[entry.id] or 0
		-- A BUILDING plot carries one waypoint of its district's patrol loop;
		-- a FILL dressing carries none, because a watch walks the street the
		-- houses stand on and not the field behind them (the shape Highcourt's
		-- districts settled on in playtest round 3).
		spec.loops = (entry.kind == "fill") and 0 or 1
		-- Every plot publishes the roles its own part publishes, so the
		-- multiset is read off the plot and only its SHAPE is asserted: at
		-- least one flair spot, and no role the contract does not name.
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
		-- A district plot MAY publish spares now (the round-3 shape Highcourt's
		-- districts settled on: two or three per district, so an ambling
		-- villager has somewhere to go that is not another villager's
		-- doorstep). The arithmetic is asserted over the settlement below.
		spec.spares = nil
		local spare_here = 0
		for _, socket in ipairs(plot.landmarks.sockets) do
			if socket.role == "idle" then
				settlement_idle = settlement_idle + 1
				if socket.spawn ~= false then placed_idle = placed_idle + 1 end
				if socket.spawn == false then spare_here = spare_here + 1 end
			end
			if socket.role == "vendor" then
				assert(vendor_kinds[socket.kind] == nil,
					"the capital publishes two " .. tostring(socket.kind) ..
						" vendors: " .. tostring(vendor_kinds[socket.kind]) ..
						" and " .. entry.id .. "/" .. socket.id)
				vendor_kinds[socket.kind] = entry.id .. "/" .. socket.id
			end
			if socket.role == "work" then
				activity_count[socket.activity] =
					(activity_count[socket.activity] or 0) + 1
			end
		end
		spec.spares = spare_here
		local result = check_composition(entry.kind .. " " .. entry.id, plot,
			spec)
		district_cells = district_cells + result.cells
		district_spares = district_spares + result.spares
		district_work = district_work + result.work
		district_features = district_features + result.work_features
		district_checked = district_checked + result.work_checked

		-- The plot fits the LOT it stands on: a composition wider than its lot
		-- is a composition the lot predicate never measured.
		for _, axis in ipairs({"x", "z"}) do
			local low = math.abs(plot.bounds.min[axis])
			local high = math.abs(plot.bounds.max[axis])
			assert(low <= reach and high <= reach, entry.id ..
				" reaches " .. math.max(low, high) .. " on " .. axis ..
				", outside its lot's " .. reach)
		end
		assert(plot.clear_to >= quadrants.LOT.clear, entry.id ..
			" clears only " .. plot.clear_to .. " nodes of airspace")

		-- The reference column: inside the plot, and a column the plot itself
		-- paves, because it is the column whose terrain height the whole plot
		-- is levelled to.
		local reference = assert(plot.reference,
			entry.id .. " publishes no reference column")
		assert(math.abs(reference.x) <= reach and
			math.abs(reference.z) <= reach,
			entry.id .. ": the reference column is outside the plot")
		local floor = result.at(reference.x, 0, reference.z)
		assert(floor and floor.name ~= "air" and walkable(floor.name),
			entry.id .. ": the reference column has no ground course")

		-- The foundation skirt reaches the contract's floor all the way round
		-- the plot, and the airspace above the plot is cleared.
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
				-- Up to the airspace the composition PUBLISHES as cut, which
				-- is the number the seam's own load-time `audit_terrain` holds
				-- the terrain rise against.
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

		-- No plot shares a column with another plot or with anything the
		-- OVERLAY writes.
		for z = entry.z + plot.bounds.min.z, entry.z + plot.bounds.max.z do
			for x = entry.x + plot.bounds.min.x, entry.x + plot.bounds.max.x do
				local key = x .. ":" .. z
				assert(taken[key] == nil, entry.id .. " overlaps " ..
					tostring(taken[key]) .. " at " .. key)
				taken[key] = entry.id
				local street = on_a_street(x, z)
				assert(street == nil, entry.id .. " stands on " ..
					tostring(street) .. " at " .. key)
			end
		end
		-- and no plot reaches into the 32-node gate corridor WP40 keeps clear
		-- on each axis (`capital_gate_width`), which nothing else enforces.
		for _, spec_run in ipairs(capital.avenues) do
			local along_min = (spec_run.axis == "x") and
				(entry.x + plot.bounds.min.x) or (entry.z + plot.bounds.min.z)
			local along_max = (spec_run.axis == "x") and
				(entry.x + plot.bounds.max.x) or (entry.z + plot.bounds.max.z)
			local across_min = (spec_run.axis == "x") and
				(entry.z + plot.bounds.min.z) or (entry.x + plot.bounds.min.x)
			local across_max = (spec_run.axis == "x") and
				(entry.z + plot.bounds.max.z) or (entry.x + plot.bounds.max.x)
			local inside = (along_max >= math.min(spec_run.from, spec_run.to))
				and (along_min <= math.max(spec_run.from, spec_run.to))
			if inside then
				assert(across_min > spec_run.at + 16 or
					across_max < spec_run.at - 16,
					entry.id .. " reaches into the 32-node gate corridor of " ..
						spec_run.id)
			end
		end

		for _, socket in ipairs(plot.landmarks.sockets) do
			if socket.role == "guard_patrol" then
				loops_by_group[socket.group] =
					loops_by_group[socket.group] or {}
				assert(loops_by_group[socket.group][socket.order] == nil,
					"the loop " .. socket.group ..
						" has two waypoints at order " .. socket.order)
				loops_by_group[socket.group][socket.order] = socket.id
			end
		end

		say("dur_brannoc_plot", entry.id, entry.district, entry.kind,
			entry.lot, entry.x, entry.z, result.cells, result.solids,
			result.palette, result.lights, result.doors, result.rooms,
			result.sockets, result.reachable, result.work)
	end

	-- Each district's loop is one walk, 1..n, across its own plots.
	local loop_total = 0
	for index = 1, #districts.districts do
		local district = districts.districts[index]
		local orders = assert(loops_by_group[district.patrol_group],
			district.key .. " publishes no patrol loop")
		local length = 0
		for _ in pairs(orders) do length = length + 1 end
		for order = 1, length do
			assert(orders[order], district.key ..
				": the patrol loop has no waypoint at order " .. order)
		end
		assert(length >= 8, district.key .. "'s patrol loop is " .. length ..
			" waypoints long")
		loop_total = loop_total + length
		say("dur_brannoc_district", district.key, district.role,
			#district.plots, #district.fill, length)
	end

	assert(district_cells <= 12000 * #resolved,
		"the districts are over their plot budget")

	-- THE CAPITAL AGAINST THE CONTRACT'S 400 000-CELL BUDGET (section 2.3).
	-- The overlay is not in it: it has no cells until a surface is handed to
	-- it and is computed per mapchunk, never stored.
	local capital_cells = core_result.cells + district_cells
	assert(capital_cells <= 400000, "the capital writes " .. capital_cells ..
		" cells, over the contract budget of 400 000")

	-- THE 80/20 RULE (sockets contract section 8.3). The NPC lane makes every
	-- fifth idle SPAWN socket a walker and asserts the resulting share is
	-- 10-30 % of residents; a capital of nothing but workplaces would fail
	-- that, and this is the structure lane's half of the same rule: at least
	-- one idle spawn socket per work socket.
	local work_total = district_work
	assert(placed_idle >= work_total, "the capital publishes " .. work_total ..
		" work sockets against " .. placed_idle .. " idle spawn sockets, so " ..
		"the walker share falls below the contract's band")
	local residents = placed_idle + work_total
	local walkers = math.ceil(placed_idle / 5)
	assert(walkers * 100 >= residents * 10 and walkers * 100 <= residents * 30,
		"the walker share is " .. walkers .. " of " .. residents ..
			" residents, outside the contract's 10-30 %")
	-- Every work socket whose activity NAMES a feature faces one. `sit` and
	-- `sweep` name none (the contract says so), so they are workplaces this
	-- count does not reach, and the two numbers are printed side by side rather
	-- than folded together.
	assert(district_features == district_checked, "only " ..
		district_features .. " of " .. district_checked ..
		" work sockets whose activity names a feature face one")

	-- THE SETTLEMENT'S SPARES, over the whole of it and not per composition: a
	-- spare is an `idle` socket with `spawn = false`, which is the runtime's
	-- own word for a wander target nobody is placed on, so the roster the
	-- engine really places is every idle socket MINUS these.
	local spare_total = core_result.spares + district_spares
	assert(settlement_idle - placed_idle == spare_total,
		"the placed idle roster is " .. placed_idle .. " of " ..
			settlement_idle .. " idle sockets, which is not " .. spare_total ..
			" spares")
	assert(core_result.spares == 2, "the core publishes " ..
		core_result.spares .. " spare sockets, not 2")
	assert(district_spares >= 8, "the four districts publish " ..
		district_spares .. " spare sockets, fewer than two each")
	say("dur_brannoc_spares", core_result.spares, district_spares,
		settlement_idle, placed_idle)

	-- THE VENDOR FAMILIES over the whole capital: at most one of each kind
	-- (sockets contract section 8.4), and the two `grug_traders` families are
	-- among them.
	local vendor_total = 0
	for _ in pairs(vendor_kinds) do vendor_total = vendor_total + 1 end
	assert(vendor_kinds.race and vendor_kinds.general,
		"the capital publishes no race or no general vendor")
	local activity_total = 0
	for _ in pairs(activity_count) do activity_total = activity_total + 1 end
	say("dur_brannoc_trades", vendor_total, work_total, activity_total,
		district_checked, district_features, capital_cells, residents, walkers)

	-- ------------------------------------------------------------------
	-- 2b. the four avenues reach the four GATE POINTS, exactly
	-- ------------------------------------------------------------------
	--
	-- WP40 fixes four gate stations per capital at (ax +- 256, az) and
	-- (ax, az +- 256), and the wave-2 route lane moves every WP40 route end
	-- from the capital anchor to those four points on the avenue centre lines,
	-- with no route cell or bridge deck inside the 512 envelope. A road that
	-- stopped at the core edge, or half a node off the axis, would leave the
	-- world's road network ending at a wall. So each avenue is asserted to run
	-- ALONG its own axis with `at = 0` -- the centre line the gate point sits
	-- on -- from the core edge to at least 256, and the capital's curtain is
	-- asserted to carry a gate on that same axis.
	--
	-- The reach is 261 and not 256 because this capital has a wall: the
	-- curtain's centre line is at 256 and its gate tunnel runs through the
	-- whole seven-node thickness, so a road that stopped at the centre line
	-- would stop inside the gate.
	do
		local GATE_AT = 256
		local seen = {}
		for _, spec in ipairs(capital.avenues) do
			assert(spec.at == 0, spec.id ..
				" does not run on its own gate axis")
			local far = math.max(math.abs(spec.from), math.abs(spec.to))
			assert(far >= GATE_AT, spec.id .. " reaches " .. far ..
				", short of the gate station at " .. GATE_AT)
			local near = math.min(math.abs(spec.from), math.abs(spec.to))
			assert(near <= 48, spec.id .. " starts at " .. near ..
				", away from the core edge")
			local sign = (spec.to > 0) and 1 or -1
			seen[spec.axis .. ":" .. sign] = spec.id
			assert(type(spec.gate) == "string",
				spec.id .. " names no gate of the core")
		end
		local count = 0
		for _ in pairs(seen) do count = count + 1 end
		assert(count == 4, "the capital has " .. count ..
			" gate axes, not four")
		-- And the curtain carries a gate where each avenue crosses it: the
		-- wall plan's `gates` list is the offset along the run, and every
		-- avenue is at 0.
		for _, spec in ipairs(capital.wall) do
			local plan = capital.wall_plan[spec.id]
			assert(type(plan) == "table" and type(plan.gates) == "table",
				spec.id .. " has no wall plan")
			local on_axis = false
			for _, gate in ipairs(plan.gates) do
				if gate == 0 then on_axis = true end
			end
			assert(on_axis, spec.id ..
				" carries no gate on the avenue's centre line")
		end
		say("dur_brannoc_gate_points", count, #capital.wall, GATE_AT,
			capital.avenues[1].to, capital.avenues[4].to)
	end

	-- ------------------------------------------------------------------
	-- 3. the avenue overlay
	-- ------------------------------------------------------------------
	--
	-- The overlay has no cells of its own until a surface is handed to it, so
	-- it is checked as a function: over profiles worse than the dwarf
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

	-- (a) The pilot profile: a flat approach, a two-node rise (the dwarf
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
	local run = avenue.run(dwarf, avenue_spec, counted_surface)

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
		assert(shaft and shaft.name == dwarf.node("post"),
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
	local twin = avenue.run(dwarf, avenue_spec, surface)
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
			return avenue.run(dwarf, {id = profile.name, axis = "x", at = 0,
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
		-- PAST the gate station, not to it. Highcourt's avenues stop at the
		-- station at 256 because Highcourt has no wall; Dur Brannoc's curtain
		-- is centred on that same line and its gate tunnel runs through the
		-- whole seven-node thickness, so a road that stopped at 256 would stop
		-- inside the gate. 261 leaves the tunnel by two nodes.
		assert(math.abs(spec.from) >= 256 or math.abs(spec.to) >= 256,
			"the avenue " .. spec.id .. " does not reach its gate station")
		assert(math.abs(spec.from) <= 261 and math.abs(spec.to) <= 261,
			"the avenue " .. spec.id .. " runs past the wall's own outer face")
		assert(math.abs(spec.from) >= 48 and math.abs(spec.to) >= 48,
			"the avenue " .. spec.id .. " starts inside the core")
		local ride = avenue.run(dwarf, {id = spec.id, axis = spec.axis,
			at = spec.at, from = spec.from, to = spec.from + 16}, surface)
		assert(#ride.cells > 0, "the avenue " .. spec.id .. " writes nothing")
		runs = runs + 1
	end
	local ring = {}
	for _, spec in ipairs(capital.ring) do
		ring[spec.id] = spec
		local ride = avenue.run(dwarf, {id = spec.id, axis = spec.axis,
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

	say("dur_brannoc_avenue", #run.cells, run.pavement, run.treads, run.risers,
		#run.lamps, run.queries, climbs, runs, #PROFILES, splits, split_cells)

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
	-- runs as actually built in terrain (`run_highcourt.sh`).
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
		local built = avenue.run(dwarf, {id = spec.id, axis = spec.axis,
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
	say("dur_brannoc_avenue_built", digest_runs,
		common.hex(common.new_sha256()(table.concat(digest_rows, "\n"))))

	-- ------------------------------------------------------------------
	-- 4. THE CURTAIN WALL
	--
	-- Dur Brannoc is the first walled capital, and the wall is the same kind
	-- of thing as the road -- a pure function of the column surface, evaluated
	-- per mapchunk (`wp13/wall.lua`). So it is checked the same way and with
	-- four rules of its own that no road needs:
	--
	--   (a) EVERY CELL IS INSIDE THE RUN RECTANGLE the seam activates the run
	--       on. `r7_settlement.lua` offers a mapchunk a run when that chunk
	--       meets `at +- (half + 1)`, which is three nodes either side of the
	--       centre line for the contract's five-wide carriageway. A wall cell
	--       outside that band is a cell in a mapchunk the run is never called
	--       for, and no other fixture in this tree would see it.
	--   (b) NO GAP. Every column of curtain is masonry, without a hole, from
	--       under its own lowest ground to its walk. That is the whole reason
	--       the wall is an overlay and not a row of stamped plots.
	--   (c) THE WALK IS WALKED. The deck never changes by more than a node
	--       between two columns and every change is a stair, so a four-node
	--       terrace step is climbed half a node at a time.
	--   (d) THE GATE IS OPEN. Seven columns of the run carry no masonry at all
	--       below the walk, through the whole thickness.
	--
	-- Plus the two the avenue is held to: a piece of a run is exactly that
	-- stretch of the whole run, and the built geometry is digested, because an
	-- overlay's manifest identity is its SPECIFICATION and would not move if
	-- every node of the wall did.
	-- ------------------------------------------------------------------
	local WALL_LANES = wall.HALF
	assert(WALL_LANES == (avenue.WIDTH - 1) / 2 + 1,
		"the wall's own half-width is no longer the seam's activation band")

	-- The four runs, as the composition authors them.
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
			"the wall run " .. spec.id .. " does not carry exactly one gate on " ..
				"its own axis")
		assert(math.abs(spec.at) == 256,
			"the wall run " .. spec.id .. " is not on the 512 envelope edge")
	end
	-- The corner turrets live on the two z-runs and only there, and the two
	-- x-runs stop one node short of their faces: the successor's first-run-wins
	-- arbitration would otherwise decide which half of a corner survives, and
	-- half a turret is not a corner.
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

	-- The synthetic ground: a terraced profile carrying every feature the
	-- measured ground at Dur Brannoc has (docs/research/wp13-dur-brannoc.md
	-- section 3) -- flat reaches, four-node steps down and up, two steps one
	-- column apart, and a four-node cross fall across the wall's own thickness,
	-- which is the worst the two gate seeds show.
	local function wall_ground(p)
		local y = 120
		if p > -140 then y = y - 4 end
		if p > -60 then y = y - 4 end
		if p > -59 then y = y - 4 end
		if p > 20 then y = y + 4 end
		if p > 90 then y = y - 4 end
		if p > 150 then y = y - 4 end
		return y
	end
	local function wall_surface(axis, at)
		return function(x, z)
			local p, lane
			if axis == "x" then p, lane = x, z - at else p, lane = z, x - at end
			local y = wall_ground(p)
			-- The cross fall: the outer two lanes a step lower on one stretch.
			if lane >= 2 and p > -20 and p < 60 then y = y - 4 end
			return y
		end
	end

	local WALL_NAMES = {}
	for _, name in ipairs(wall.palette_names(dwarf)) do WALL_NAMES[name] = true end

	local wall_digest_rows, wall_cells, wall_columns = {}, 0, 0
	local wall_gaps, wall_steps, wall_treads, wall_passage = 0, 0, 0, 0
	for _, spec in ipairs(capital.wall) do
		local plan = capital.wall_plan[spec.id]
		local surface = wall_surface(spec.axis, spec.at)
		local piece = wall.run(dwarf, {id = spec.id, axis = spec.axis,
			at = spec.at, from = spec.from, to = spec.to, width = avenue.WIDTH,
			lamp_spacing = avenue.LAMP_SPACING, lamp_phase = spec.from,
			reach = avenue.REACH}, surface, plan)
		wall_cells = wall_cells + #piece.cells
		wall_columns = wall_columns + piece.columns

		-- Index the piece by (p, lane, y), which is the frame every rule below
		-- is written in.
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
			-- (a) the activation band.
			assert(lane >= -WALL_LANES and lane <= WALL_LANES,
				spec.id .. " writes a cell " .. lane ..
					" lanes from its centre line, outside the " .. WALL_LANES ..
					" the seam activates the run on")
			at_cell[p .. ":" .. lane .. ":" .. cell.y] = cell.name
			wall_digest_rows[#wall_digest_rows + 1] =
				table.concat({p, lane, cell.y, cell.name, cell.param2 or 0}, ":")
		end

		-- The walk of a column, read back out of the piece and NOT out of the
		-- module that wrote it: the highest cell of the centre lane that is
		-- solid and carries AUTHORED AIR directly above it. That is what a
		-- walkway is and nothing else in the section is -- a turret's fighting
		-- floor has nothing written above it, and the masonry of a chamber wall
		-- has more masonry above it.
		local function deck_of(p)
			for y = 200, 80, -1 do
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
				-- (d) the gate is open: no masonry under the walk anywhere
				-- across the thickness.
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
				-- (b) no gap: the five curtain lanes are solid from the footing
				-- to one course under the walk.
				for lane = -2, 2 do
					local ground = surface(spec.axis == "x" and p or spec.at + lane,
						spec.axis == "x" and spec.at + lane or p)
					local lowest
					for y = ground, 80, -1 do
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
			-- (c) the walk: at most one node of change per column, and a change
			-- is always a stair.
			if previous_deck ~= nil then
				local step = deck - previous_deck
				assert(math.abs(step) <= 1, spec.id ..
					": the walk changes by " .. step .. " nodes at column " .. p)
				if step ~= 0 then wall_steps = wall_steps + 1 end
			end
			previous_deck = deck
			if not in_gate then
				local centre = at_cell[p .. ":0:" .. deck]
				if centre ~= nil and world.nodes[centre] and
						(world.nodes[centre].groups or {}).stair then
					wall_treads = wall_treads + 1
				end
			end
		end
	end
	assert(wall_gaps == 0, "the curtain has " .. wall_gaps ..
		" cells of hole between its footing and its walk")
	assert(wall_steps >= 20, "the test profile did not exercise the walk: " ..
		wall_steps .. " one-node steps")
	assert(wall_treads >= wall_steps - 8, "only " .. wall_treads ..
		" of the walk's " .. wall_steps .. " steps are stairs")

	-- (e) A piece of a run is exactly that stretch of the whole run: the wall
	-- is cut at every column of a representative stretch and the union of the
	-- two pieces compared with the whole, cell for cell. That is what lets the
	-- successor call it per mapchunk.
	local cut_spec = {id = "wall_east", axis = "z", at = 256, from = -40,
		to = 60, width = avenue.WIDTH, lamp_spacing = avenue.LAMP_SPACING,
		lamp_phase = -40, reach = avenue.REACH}
	local cut_plan = capital.wall_plan.wall_east
	local cut_surface = wall_surface("z", 256)
	local whole_wall = wall.run(dwarf, cut_spec, cut_surface, cut_plan)
	local whole_index = {}
	for _, cell in ipairs(whole_wall.cells) do
		whole_index[cell.x .. ":" .. cell.y .. ":" .. cell.z] =
			cell.name .. ":" .. (cell.param2 or 0)
	end
	local wall_splits = 0
	for cut = cut_spec.from, cut_spec.to - 1 do
		local left = wall.run(dwarf, {id = cut_spec.id, axis = "z", at = 256,
			from = cut_spec.from, to = cut, width = cut_spec.width,
			lamp_spacing = cut_spec.lamp_spacing, lamp_phase = cut_spec.lamp_phase,
			reach = cut_spec.reach}, cut_surface, cut_plan)
		local right = wall.run(dwarf, {id = cut_spec.id, axis = "z", at = 256,
			from = cut + 1, to = cut_spec.to, width = cut_spec.width,
			lamp_spacing = cut_spec.lamp_spacing, lamp_phase = cut_spec.lamp_phase,
			reach = cut_spec.reach}, cut_surface, cut_plan)
		local union, count = {}, 0
		for _, piece in ipairs({left, right}) do
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

	-- (f) NO AVENUE LAMP STANDARD IN A WALL PIER. A lamp stands on the verge,
	-- one node outside the carriageway, and inside a gate that verge is a
	-- column of the gatehouse. The avenue is authored BEFORE the wall and wins
	-- every cell the two share, so a standard in a pier is a lamp post walled
	-- into solid masonry with a hole round it. The gate passage is seven
	-- columns wide -- the carriageway plus both verges -- for exactly this
	-- reason, and this is the rule that says so.
	local lamps_in_gate = 0
	for _, spec in ipairs(capital.avenues) do
		local half = (avenue.WIDTH - 1) / 2 + 1
		for p = spec.from, spec.to do
			if (p - spec.from) % avenue.LAMP_SPACING == 0 then
				-- The wall this avenue passes through stands at +-256 on the
				-- avenue's own axis; the lamp is on the verge at that p.
				for _, side in ipairs({256, -256}) do
					local lane = p - side
					if lane >= -WALL_LANES and lane <= WALL_LANES then
						assert(half <= wall.GATE_PASSAGE, "the avenue's verge is " ..
							half .. " lanes out and the gate passage only " ..
							wall.GATE_PASSAGE .. " columns wide, so a standard " ..
							"stands in a pier")
						lamps_in_gate = lamps_in_gate + 1
					end
				end
			end
		end
	end

	say("dur_brannoc_wall", #capital.wall, wall_columns, wall_cells,
		wall_steps, wall_treads, wall_passage, wall_splits, lamps_in_gate,
		common.hex(common.new_sha256()(table.concat(wall_digest_rows, "\n"))))

	-- ------------------------------------------------------------------
	-- 5. THE CAUSEWAY PARAPET, which is this capital's own addition to the
	-- shared road module rather than a change to it.
	--
	-- WP40 blends the flat civic core down to the granite terraces over some
	-- forty nodes and the ground falls TWO nodes per column on that stretch,
	-- while the road's one-Lipschitz envelope may fall only one: the avenue
	-- leaves the ground and runs out of the citadel on an embankment eight to
	-- ten nodes high. `avenue.lua` cannot be the place that rails it -- it is
	-- the shared module and Highcourt's built road is frozen against it -- so
	-- the composition adds the rail to the piece the road module returns, and
	-- this is where that is held to its rule:
	--
	--   * a rail stands only on a KERB lane, never in the carriageway;
	--   * only where the road stands at least `RAIL_FILL` courses above its own
	--     ground, so an ordinary terrace stair is not railed into a trench;
	--   * and it is chunk-independent, because it reads only the piece's own
	--     cells -- cut the run anywhere and the union is the same rail.
	-- ------------------------------------------------------------------
	local RAIL_FILL = 3
	local function ramp_surface(x, z)
		-- Flat plateau, ten columns of two-node fall -- which is what makes the
		-- road leave the ground -- and then four-node terraces, the shape of
		-- the real ground under this capital's east avenue.
		--
		-- TWENTY nodes of fall, not the forty the real blend band has, and that
		-- is deliberate: `avenue.REACH` is 40 and a column's influence decays
		-- by one node per column, so a plateau forty-four columns from the road
		-- it lifts is at the very edge of what the look-around can see. A test
		-- profile that falls forty nodes in twenty columns is outside it, and
		-- the first version of this row was -- it failed the cut test on a
		-- one-node disagreement between two pieces whose look-around windows
		-- started either side of the plateau edge. The REAL ground falls its
		-- forty-four nodes over forty-four columns, an average of one per
		-- column, which is exactly the rate at which influence decays and is
		-- therefore inside the reach; the built road on the user seed has no
		-- step over one node anywhere along its 205 columns, across three
		-- mapchunk borders (docs/research/wp13-dur-brannoc.md section 7).
		local p = x
		if p <= 60 then return 149 end
		if p <= 70 then return 149 - 2 * (p - 60) end
		return 129 - 4 * math.floor((p - 70) / 20)
	end
	local ramp_spec = {id = "avenue_east", axis = "x", at = 0, from = 48,
		to = 200, width = avenue.WIDTH, lamp_spacing = avenue.LAMP_SPACING,
		lamp_phase = 48, reach = avenue.REACH}
	local railed = capital.overlay_run(avenue, dwarf, ramp_spec, ramp_surface)
	local bare = avenue.run(dwarf, ramp_spec, ramp_surface)
	assert(#railed.cells > #bare.cells,
		"the composition added no parapet to the embankment")
	assert(railed.rail == #railed.cells - #bare.cells,
		"the parapet count and the cells added disagree")
	-- Every added cell is on a kerb lane, one course over the road's top there,
	-- and that column really is filled three or more courses.
	local bare_index, bare_low, bare_high = {}, {}, {}
	for _, cell in ipairs(bare.cells) do
		bare_index[cell.x .. ":" .. cell.y .. ":" .. cell.z] = cell.name
		local column = cell.x .. ":" .. cell.z
		if bare_low[column] == nil or cell.y < bare_low[column] then
			bare_low[column] = cell.y
		end
		if bare_high[column] == nil or cell.y > bare_high[column] then
			bare_high[column] = cell.y
		end
	end
	local rails, rail_columns = 0, {}
	local half = (avenue.WIDTH - 1) / 2
	for _, cell in ipairs(railed.cells) do
		local key = cell.x .. ":" .. cell.y .. ":" .. cell.z
		if bare_index[key] == nil then
			rails = rails + 1
			assert(cell.z == ramp_spec.at - half or cell.z == ramp_spec.at + half,
				"a causeway rail stands at z = " .. cell.z ..
					", which is not a kerb lane")
			local column = cell.x .. ":" .. cell.z
			assert(cell.y == bare_high[column] + 1,
				"a causeway rail at " .. column .. " is not one course over " ..
					"the road")
			assert(bare_high[column] - bare_low[column] >= RAIL_FILL,
				"a causeway rail at " .. column .. " stands over a fill of " ..
					(bare_high[column] - bare_low[column]) .. " courses")
			rail_columns[column] = true
		end
	end
	assert(rails == railed.rail, "the parapet cells and its count disagree")
	-- ... and NOTHING that should be railed is missed.
	local missed = 0
	for column, high in pairs(bare_high) do
		local x, z = column:match("^(%-?%d+):(%-?%d+)$")
		z = tonumber(z)
		if (z == ramp_spec.at - half or z == ramp_spec.at + half) and
				high - bare_low[column] >= RAIL_FILL and
				not rail_columns[column] then
			missed = missed + 1
		end
	end
	assert(missed == 0, missed .. " embankment columns carry no rail")
	-- Chunk independence: cut the run at every column and compare the union of
	-- the two railed pieces with the whole railed run.
	local whole_rail = {}
	for _, cell in ipairs(railed.cells) do
		whole_rail[cell.x .. ":" .. cell.y .. ":" .. cell.z] =
			cell.name .. ":" .. (cell.param2 or 0)
	end
	local rail_splits = 0
	for cut = ramp_spec.from, ramp_spec.to - 1 do
		local union, count = {}, 0
		for _, piece_spec in ipairs({{ramp_spec.from, cut},
				{cut + 1, ramp_spec.to}}) do
			local piece = capital.overlay_run(avenue, dwarf,
				{id = ramp_spec.id, axis = "x", at = 0, from = piece_spec[1],
					to = piece_spec[2], width = ramp_spec.width,
					lamp_spacing = ramp_spec.lamp_spacing,
					lamp_phase = ramp_spec.lamp_phase,
					reach = ramp_spec.reach}, ramp_surface)
			for _, cell in ipairs(piece.cells) do
				local key = cell.x .. ":" .. cell.y .. ":" .. cell.z
				local value = cell.name .. ":" .. (cell.param2 or 0)
				assert(whole_rail[key] == value,
					"the railed piece cut at " .. cut .. " writes " .. value ..
						" at " .. key .. ", which the whole run does not")
				if union[key] == nil then
					union[key] = value
					count = count + 1
				end
			end
		end
		assert(count == #railed.cells, "the two railed pieces cut at " .. cut ..
			" carry " .. count .. " cells, the whole run " .. #railed.cells)
		rail_splits = rail_splits + 1
	end
	say("dur_brannoc_causeway", #bare.cells, #railed.cells, rails, rail_splits)

	return table.concat(report)
end
