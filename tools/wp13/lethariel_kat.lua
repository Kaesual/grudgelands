-- Architectural acceptance for Lethariel, the elf capital.
--
-- `blueprint_kat.lua` holds the six START blueprints to the invariants of
-- docs/research/wp13-settlement-pipeline.md section 5, and `highcourt_kat.lua`
-- and `dur_brannoc_kat.lua` do the same for the first two capitals. A capital
-- is a core plus terrain-relative plots plus an overlay that has no cells
-- until a surface is handed to it, and this file is Lethariel's equivalent,
-- held to docs/research/wp13-capitals-pois-contract.md (2.1 envelopes, 2.3
-- budgets, 2.4 the elf row, 4 the open-edge ruling) and
-- docs/research/wp13-npc-sockets-contract.md (2 the socket field, 6 spares,
-- 7 the door tag, 8 work sockets and profession vendors).
--
-- What it does NOT repeat: the six starts, the capital parts at four
-- rotations, and the palette-wide registry scan -- those are `blueprint_kat`
-- and `library_kat`. What it adds is everything that only exists once THIS
-- composition assembles those parts, and three rules no capital before it had:
--
--   1. THE MERE. WP40 leaves a planned lake inside this capital's 96 x 96
--      civic core, and the composition must write nothing over it. Section 1
--      asserts that every cell of the core stands on a column the committed
--      shore table calls dry, that the table is a contiguous wedge, and that
--      the causeway band the north avenue owns carries no core cell either.
--   2. THE GROVE EDGE. An open capital's boundary, and a boundary that is not
--      masonry still has to be a boundary. Section 5 asserts every cell inside
--      the seam's activation band, the threshold passage clear through, the
--      belt silent over water, and the piece cut at every column with the
--      union compared to the whole -- the property that lets the successor
--      call it per mapchunk.
--   3. THREE DISTRICTS OF NINE AND ONE OF THREE, and the permutation over the
--      three quarters that can carry one. Section 4 asserts the lot tables,
--      the quarter rule, the lane clearance and every one of the six
--      permutations.
--
-- Plain Lua 5.1; the same bytes must run under LuaJIT and PUC 5.1.

return function(repo)
	local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
	local parts = dofile(wp13 .. "/parts.lua")
	local avenue = dofile(wp13 .. "/avenue.lua")(wp13)
	local capital = dofile(wp13 .. "/lethariel.lua")(wp13)
	local quadrants = dofile(wp13 .. "/lethariel_quadrants.lua")()
	local districts = dofile(wp13 .. "/lethariel_districts.lua")(wp13)
	local grove = dofile(wp13 .. "/elf_grove.lua")(wp13)
	local elf = dofile(wp13 .. "/elf_parts.lua")(wp13)
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local registry = dofile(repo .. "/tools/wp13/stub_registry.lua")
	local world = registry.load(repo)

	local report = {}
	local function say(...)
		report[#report + 1] = table.concat({...}, "\t") .. "\n"
	end

	local handles = elf.handles()
	local palette = handles.elf

	local function walkable(name)
		local def = world.nodes[name]
		return def ~= nil and def.walkable ~= false
	end

	-- ------------------------------------------------------------------
	-- the shared body: every rule a finished WP13 composition has to pass
	-- ------------------------------------------------------------------
	local LIGHT = {}
	for _, role in ipairs({"light_wall", "light_post", "light_indoor",
			"light_beacon", "light_hanging"}) do
		local name = palette.maybe(role)
		if name then LIGHT[name] = true end
	end
	local WATER = palette.node("water")

	local function check_composition(label, blueprint, spec)
		local cells = blueprint.cells
		assert(type(blueprint.schema) == "string" and blueprint.schema ~= "",
			label .. " has no schema")
		assert(#cells <= spec.budget, label .. " writes " .. #cells ..
			" cells, over the contract budget of " .. spec.budget)
		assert(#cells > 200, label .. " is empty")

		local index, solids, lights, oriented, water = {}, 0, 0, 0, 0
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
			-- The ONE water this library writes is the town pond of playtest
			-- round 3 -- a basin the settlement dug, lined on five sides --
			-- and only a plot that declares one may carry it. Lava and every
			-- other liquid stay forbidden everywhere.
			if cell.name == WATER then
				assert(spec.pond, label .. " writes water and is not a pond")
				water = water + 1
			else
				assert(not cell.name:find("water") and
					not cell.name:find("lava"),
					label .. " writes the liquid " .. cell.name)
			end
			assert(cell.name == "air" or world.nodes[cell.name] ~= nil,
				label .. " writes the unregistered node " .. cell.name)
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

		-- The bounds are the real extent.
		local bounds = assert(blueprint.bounds, label .. " has no bounds")
		local hit = {x0 = false, x1 = false, z0 = false, z1 = false}
		for _, cell in ipairs(cells) do
			assert(cell.x >= bounds.min.x and cell.x <= bounds.max.x and
					cell.y >= bounds.min.y and cell.y <= bounds.max.y and
					cell.z >= bounds.min.z and cell.z <= bounds.max.z,
				label .. " has a cell outside its own bounds")
			if cell.x == bounds.min.x then hit.x0 = true end
			if cell.x == bounds.max.x then hit.x1 = true end
			if cell.z == bounds.min.z then hit.z0 = true end
			if cell.z == bounds.max.z then hit.z1 = true end
		end
		assert(hit.x0 and hit.x1 and hit.z0 and hit.z1,
			label .. " bounds are wider than its cells")

		-- Every torch on an opaque full node, every attached node on the
		-- support its rating names. The conservative half of the rule the
		-- library KAT proves against the registry: a wallmounted light needs
		-- something behind it.
		for _, cell in ipairs(cells) do
			local def = world.nodes[cell.name]
			if def and LIGHT[cell.name] and def.paramtype2 == "wallmounted" then
				local step = ({[0] = {0, 1, 0}, [1] = {0, -1, 0},
					[2] = {1, 0, 0}, [3] = {-1, 0, 0}, [4] = {0, 0, 1},
					[5] = {0, 0, -1}})[cell.param2]
				assert(step, label .. " has a light with a bad wallmount")
				local support = index[(cell.x + step[1]) .. ":" ..
					(cell.y + step[2]) .. ":" .. (cell.z + step[3])]
				assert(support and support.name ~= "air" and
					walkable(support.name),
					label .. " hangs a light on nothing at " .. cell.x .. "," ..
						cell.y .. "," .. cell.z)
			end
		end
		return {cells = #cells, solids = solids, lights = lights,
			oriented = oriented, water = water, index = index,
			palette = palette_count}
	end

	-- ------------------------------------------------------------------
	-- the socket contract, over one composition
	-- ------------------------------------------------------------------
	--
	-- The closed activity vocabulary of the sockets contract's section 8.2,
	-- wave 1 and wave 2, and the feature each of them expects under `dir`
	-- within three nodes (section 8.1 and the wave-2 table). `nil` means the
	-- activity names no feature: `sit` sits on the ground it stands on, and
	-- `sweep` is the one activity that moves.
	local FEATURE = {}
	local function feature(activity, roles, extra)
		local set = {}
		for _, role in ipairs(roles or {}) do
			local name = palette.maybe(role)
			if name then set[name] = true end
		end
		for _, name in ipairs(extra or {}) do set[name] = true end
		FEATURE[activity] = set
	end
	feature("smith", {"workbench", "hearth"})
	feature("fish", {"water"}, {"default:water_source",
		"default:river_water_source", "default:river_water_flowing"})
	feature("farm", {"crop", "crop_soil"})
	feature("chop", {"tree_log", "post", "beam"})
	feature("pray", {"signature", "signature_slab", "light_post",
		"light_wall", "low_wall"})
	feature("tend", {"flower", "flower_alt", "hedge", "hedge_stem",
		"undergrowth", "grass_tuft", "fern", "crop", "tree_leaves"})
	feature("brew", {"hearth", "storage"})
	feature("carve", {"tree_log", "signature", "signature_slab"})
	feature("mourn", {"low_wall", "light_post", "light_wall"})
	feature("spar", {"fence", "rug", "rug_accent"})
	feature("forage", {"hedge", "tree_leaves", "undergrowth", "grass_tuft",
		"fern", "flower", "flower_alt"})
	feature("mine", {"rubble", "wall_accent", "castle_wall"})
	-- `stall` is "a counter (any solid node at waist height)", so its set is
	-- open and the check is the height, not the name.
	FEATURE.stall = true
	FEATURE.sit = false
	FEATURE.sweep = false

	local ROLES = {guard_post = true, guard_patrol = true, vendor = true,
		idle = true, quest = true, king = true, waypoint = true, work = true}

	local FACEDIR_DIR = {[0] = {0, 1}, [1] = {1, 0}, [2] = {0, -1},
		[3] = {-1, 0}}

	local capital_vendor_kinds = {}
	local capital_loops = {}
	local capital_totals = {work = 0, idle_spawn = 0, spare = 0, vendor = 0,
		guard_post = 0, guard_patrol = 0, quest = 0, king = 0, waypoint = 0,
		sockets = 0}
	local capital_activities = {}

	local function check_sockets(label, blueprint, result, options)
		options = options or {}
		local sockets = blueprint.landmarks.sockets
		assert(type(sockets) == "table", label .. " publishes no sockets")
		local seen = {}
		local counts = {}
		for _, socket in ipairs(sockets) do
			assert(ROLES[socket.role], label .. " socket " ..
				tostring(socket.id) .. " has the unknown role " ..
				tostring(socket.role))
			assert(type(socket.id) == "string" and socket.id ~= "" and
				not seen[socket.id],
				label .. " repeats the socket id " .. tostring(socket.id))
			seen[socket.id] = true
			counts[socket.role] = (counts[socket.role] or 0) + 1
			capital_totals.sockets = capital_totals.sockets + 1
			assert(socket.x % 1 == 0 and socket.y % 1 == 0 and
				socket.z % 1 == 0, label .. " socket " .. socket.id ..
				" is not on a node")
			-- The contract's `dir`: the four axis vectors, and the facedir the
			-- composition converted it from.
			assert(type(socket.dir) == "table" and
				socket.dir.x == FACEDIR_DIR[socket.face % 4][1] and
				socket.dir.z == FACEDIR_DIR[socket.face % 4][2],
				label .. " socket " .. socket.id .. " has a dir that is not " ..
					"its own facing")
			-- Feet and head air, walkable ground below.
			local function at(x, y, z)
				return result.index[x .. ":" .. y .. ":" .. z]
			end
			for _, level in ipairs({socket.y, socket.y + 1}) do
				local cell = at(socket.x, level, socket.z)
				assert(cell == nil or cell.name == "air" or
					not walkable(cell.name),
					label .. " socket " .. socket.id ..
						" is blocked at y " .. level .. " by " ..
						tostring(cell and cell.name))
			end
			local below = at(socket.x, socket.y - 1, socket.z)
			assert(below ~= nil and below.name ~= "air" and
				walkable(below.name),
				label .. " socket " .. socket.id .. " stands on " ..
					(below and below.name or "air"))
			-- `spawn` is either absent or exactly false, and only an `idle`
			-- socket may carry it; a spare carries NO TAG.
			if socket.spawn ~= nil then
				assert(socket.spawn == false and socket.role == "idle",
					label .. " socket " .. socket.id .. " abuses `spawn`")
				assert(socket.tags == nil,
					label .. " spare " .. socket.id .. " carries a tag")
				capital_totals.spare = capital_totals.spare + 1
			elseif socket.role == "idle" then
				capital_totals.idle_spawn = capital_totals.idle_spawn + 1
			end
			if socket.role == "work" then
				capital_totals.work = capital_totals.work + 1
				local activity = socket.activity
				assert(type(activity) == "string" and
					FEATURE[activity] ~= nil,
					label .. " work socket " .. socket.id ..
						" names the activity " .. tostring(activity) ..
						", which is not in the closed vocabulary")
				capital_activities[activity] =
					(capital_activities[activity] or 0) + 1
				local wanted = FEATURE[activity]
				if wanted ~= false then
					-- THE SEARCH STOPS AT THE FIRST SOLID NODE ON THE SOCKET'S
					-- OWN COURSE (sockets contract section 8.1): a feature
					-- behind a wall does not count, because the resident can
					-- neither see nor reach it. The cell that stops the search
					-- is examined first, so a counter or an altar -- which is
					-- itself solid -- still counts at the range it stands at,
					-- and the course either side of the feet cell is read too,
					-- because a pond's surface lies at the ground the angler
					-- stands on. This is `highcourt_kat`'s rule, spelled the
					-- same way.
					local found, blocked = nil, false
					for reach = 1, 3 do
						local fx = socket.x + socket.dir.x * reach
						local fz = socket.z + socket.dir.z * reach
						if not blocked then
							local own = at(fx, socket.y, fz)
							local own_solid = own ~= nil and
								own.name ~= "air" and walkable(own.name)
							if wanted == true then
								if own_solid then found = own.name end
							else
								for dy = -1, 1 do
									local cell = at(fx, socket.y + dy, fz)
									if found == nil and cell and
											wanted[cell.name] then
										found = cell.name
									end
								end
								if found == nil and own_solid then
									blocked = true
								end
							end
						end
					end
					assert(found, label .. " work socket " .. socket.id ..
						" (" .. activity .. ") faces no feature its " ..
						"activity names within three nodes")
				end
			end
			if socket.role == "vendor" then
				assert(type(socket.kind) == "string" and socket.kind ~= "",
					label .. " vendor " .. socket.id .. " has no kind")
				assert(not capital_vendor_kinds[socket.kind],
					"Lethariel holds two vendors of the kind " .. socket.kind)
				capital_vendor_kinds[socket.kind] = label
				capital_totals.vendor = capital_totals.vendor + 1
			end
			if socket.role == "guard_patrol" then
				assert(type(socket.group) == "string" and
					type(socket.order) == "number",
					label .. " patrol " .. socket.id .. " has no loop")
				local loop = capital_loops[socket.group] or {}
				assert(loop[socket.order] == nil,
					"the loop " .. socket.group .. " repeats order " ..
						socket.order)
				loop[socket.order] = socket.id
				capital_loops[socket.group] = loop
				capital_totals.guard_patrol = capital_totals.guard_patrol + 1
			end
			if socket.role == "guard_post" then
				capital_totals.guard_post = capital_totals.guard_post + 1
			end
			if socket.role == "quest" then
				capital_totals.quest = capital_totals.quest + 1
			end
			if socket.role == "king" then
				capital_totals.king = capital_totals.king + 1
			end
			if socket.role == "waypoint" then
				capital_totals.waypoint = capital_totals.waypoint + 1
			end
			if socket.tags ~= nil then
				assert(type(socket.tags) == "table" and #socket.tags >= 1,
					label .. " socket " .. socket.id .. " has an empty tag list")
			end
		end
		if options.min_sockets then
			assert(#sockets >= options.min_sockets, label .. " publishes " ..
				#sockets .. " sockets, fewer than " .. options.min_sockets)
		end
		return counts
	end

	-- ------------------------------------------------------------------
	-- 1. THE CORE, AND THE MERE
	-- ------------------------------------------------------------------
	local core = capital.core()
	local core_result = check_composition("lethariel core", core,
		{reach = 47, ymin = -2, ymax = 40, budget = 150000, min_lights = 40})
	local core_counts = check_sockets("lethariel core", core, core_result,
		{min_sockets = 60})

	-- THE SHORE. The composition's own committed wedge is read back out of
	-- the finished cells: not one cell of the core may stand on a column the
	-- world plan calls water, and the wedge has to be what the composition
	-- says it is -- one contiguous run per row, growing northward from a tip.
	--
	-- The table itself lives in `wp13/lethariel.lua` and is not exported, so
	-- this section derives the same shape from the cells: the set of columns
	-- inside +-47 the core wrote NOTHING in, minus the causeway band the
	-- north avenue owns.
	local wrote = {}
	for _, cell in ipairs(core.cells) do
		wrote[cell.x .. ":" .. cell.z] = true
	end
	local silent_rows, tip_z, widest, previous_width = 0, nil, 0, 0
	local silent_columns = 0
	for z = -47, 47 do
		local first, last, count = nil, nil, 0
		for x = -47, 47 do
			if not wrote[x .. ":" .. z] then
				count = count + 1
				if first == nil then first = x end
				last = x
			end
		end
		if z < 22 then
			assert(count == 0, "the core is silent at z " .. z ..
				", south of the mere's own tip")
		else
			assert(count > 0, "the core writes across the mere at z " .. z)
			-- ONE CONTIGUOUS RUN per row: the lake is one body of water and
			-- the causeway band the north avenue owns lies inside it, so a
			-- hole with ground on both sides would mean the composition had
			-- laid turf over part of the water.
			assert(last - first + 1 == count,
				"the mere is not one run at z " .. z .. " (" .. first ..
					".." .. last .. " holds " .. count .. " columns)")
			-- The seven lanes of the causeway are always part of it: the
			-- north avenue starts at z = 22 and a core cell in its band would
			-- be a cell two blueprints claim.
			assert(first <= -3 and last >= 3,
				"the causeway band is not clear at z " .. z)
			assert(count >= previous_width,
				"the mere narrows northward at z " .. z)
			previous_width = count
			silent_rows = silent_rows + 1
			silent_columns = silent_columns + count
			if tip_z == nil then tip_z = z end
			if count > widest then widest = count end
		end
	end
	assert(tip_z == 22, "the mere's tip is at z " .. tostring(tip_z) ..
		", not at 22")
	assert(silent_rows == 26, "the mere covers " .. silent_rows ..
		" rows, not 26")

	-- The ground course: every column the core DID write carries ground or
	-- paving at y = 0, so the pad is a surface and not a lattice.
	local ground_columns = 0
	for z = -47, 47 do
		for x = -47, 47 do
			if wrote[x .. ":" .. z] then
				local cell = core_result.index[x .. ":0:" .. z]
				assert(cell ~= nil and cell.name ~= "air",
					"the core has no ground course at " .. x .. "," .. z)
				ground_columns = ground_columns + 1
			end
		end
	end

	-- The four landmarks every consumer reads, and the throne.
	local L = core.landmarks
	for _, key in ipairs({"arrival", "gate_south", "gate_north", "gate_east",
			"gate_west", "waypoint_plaza", "kings_hall", "star_hall",
			"sacred_grove", "destinations", "doors", "rooms", "lights",
			"sockets"}) do
		assert(L[key] ~= nil, "the core publishes no " .. key)
	end
	assert(#L.destinations >= 10, "the core names " .. #L.destinations ..
		" destinations")
	-- The reserved travel plaza is empty above its paving: WP17's pad needs
	-- room and sky.
	local plaza = L.waypoint_plaza
	for z = plaza.min.z, plaza.max.z do
		for x = plaza.min.x, plaza.max.x do
			for y = 1, plaza.max.y do
				local cell = core_result.index[x .. ":" .. y .. ":" .. z]
				assert(cell == nil or cell.name == "air",
					"the travel plaza carries " .. cell.name .. " at " .. x ..
						"," .. y .. "," .. z)
			end
		end
	end

	-- THE OPEN EDGE. Lethariel carries no curtain wall (contract section 4),
	-- so no cell of the core's own boundary ring may be castle masonry, and
	-- the ring that is there has to be planted.
	-- The curtain masonry of BOTH handles: the plain palette's and the civic
	-- one's, which rebinds `castle_wall` to the pale cut of its own silver
	-- sandstone. Reading one of them would make this rule vacuous the moment a
	-- handle rebinds the role, which is exactly what happened when this
	-- capital's civic quarter stopped being brown.
	local masonry_names = {}
	for _, handle in ipairs({handles.elf, handles.pale}) do
		for _, role in ipairs({"castle_wall", "castle_wall_slab",
				"castle_wall_stair"}) do
			local name = handle.maybe(role)
			if name then masonry_names[name] = true end
		end
	end
	local masonry = {}
	for _, cell in ipairs(core.cells) do
		if cell.y == 1 and masonry_names[cell.name] then
			masonry[cell.x .. ":" .. cell.z] = true
		end
	end
	local longest = 0
	local function walk_edge(fixed_axis, fixed, low, high)
		local run = 0
		for step = low, high do
			local key
			if fixed_axis == "z" then key = step .. ":" .. fixed
			else key = fixed .. ":" .. step end
			if masonry[key] then
				run = run + 1
				if run > longest then longest = run end
			else
				run = 0
			end
		end
	end
	for _, edge in ipairs({{"z", -47}, {"z", 47}, {"x", -47}, {"x", 47},
			{"z", -46}, {"z", 46}, {"x", -46}, {"x", 46}}) do
		walk_edge(edge[1], edge[2], -47, 47)
	end
	-- A GATEHOUSE IS NOT A WALL. Lethariel carries no curtain (contract
	-- section 4), and the property that says so is not "no masonry on the
	-- boundary" -- the three inner gates stand on it and are masonry -- but
	-- that no unbroken RUN of it is longer than one gate. A gatehouse is
	-- thirteen wide; anything much longer is a wall somebody built by
	-- accident.
	assert(longest <= 13, "the core's boundary carries " .. longest ..
		" unbroken columns of castle masonry, which is a curtain wall")

	assert(L.hedge_columns >= 100, "the core's planted edge is only " ..
		L.hedge_columns .. " columns")
	assert(L.standards >= 16, "the core keeps only " .. L.standards ..
		" silverwood standards")
	assert(L.lantern_pillars >= 16, "the core lights only " ..
		L.lantern_pillars .. " lantern pillars")

	say("lethariel_core", core.schema, core_result.cells, core_result.solids,
		core_result.lights, core_result.palette, #core.landmarks.sockets,
		ground_columns, silent_rows, silent_columns, widest,
		L.quay_columns, L.hedge_columns,
		L.standards, L.lantern_pillars, longest,
		common.hex(common.new_sha256()(core.schema .. "/" ..
			core_result.cells .. "/" .. ground_columns)))

	-- ------------------------------------------------------------------
	-- 2. THE DISTRICT PLOTS
	-- ------------------------------------------------------------------
	local resolved, assignment, permutation = districts.resolve()
	assert(#resolved == 44, "Lethariel resolves " .. #resolved .. " plots")
	local plot_results, plot_cells = {}, 0
	local by_id = {}
	for _, entry in ipairs(resolved) do
		local blueprint = entry.build()
		assert(blueprint.schema == "grug_wp13_lethariel_plot_" .. entry.id ..
			"_v1", "the plot " .. entry.id .. " publishes " .. blueprint.schema)
		local pond = entry.id == "mere_stages"
		local result = check_composition("plot " .. entry.id, blueprint,
			{reach = quadrants.LOT.reach, ymin = -6, ymax = 24,
				budget = 12000, min_lights = 1, pond = pond})
		check_sockets("plot " .. entry.id, blueprint, result)
		-- The reference column is the plot origin and nothing else.
		assert(blueprint.reference.x == 0 and blueprint.reference.z == 0,
			"the plot " .. entry.id .. " levels to a corner")
		-- The foundation skirt reaches the contract's floor on the perimeter.
		local bounds = blueprint.bounds
		assert(bounds.min.y == -6, "the plot " .. entry.id ..
			" skirts to y " .. bounds.min.y .. ", not to -6")
		local skirt = 0
		for _, cell in ipairs(blueprint.cells) do
			if cell.y == -6 then skirt = skirt + 1 end
		end
		assert(skirt >= 40, "the plot " .. entry.id .. " has only " .. skirt ..
			" cells of footing")
		-- The cleared airspace is published and is at least the lot's rise.
		assert(type(blueprint.clear_to) == "number" and
			blueprint.clear_to >= quadrants.LOT.clear,
			"the plot " .. entry.id .. " clears " ..
				tostring(blueprint.clear_to))
		if pond then
			assert(result.water > 0, "the fishing stages have no water")
		end
		plot_results[entry.id] = {result = result, entry = entry,
			blueprint = blueprint}
		by_id[entry.id] = entry
		plot_cells = plot_cells + result.cells
	end

	-- Every district has the roster its quarter can carry.
	local per_district = {}
	for _, entry in ipairs(resolved) do
		local row = per_district[entry.district] or
			{plot = 0, fill = 0, quadrant = entry.quadrant, role = entry.role}
		row[entry.kind] = row[entry.kind] + 1
		per_district[entry.district] = row
	end
	local district_rows = {}
	for key, row in pairs(per_district) do
		district_rows[#district_rows + 1] = key .. ":" .. row.quadrant .. ":" ..
			row.plot .. ":" .. row.fill
	end
	table.sort(district_rows)
	assert(#district_rows == 4, "Lethariel has " .. #district_rows ..
		" districts")
	assert(per_district.lethariel_mere.quadrant == "northeast" and
		per_district.lethariel_mere.plot == 3 and
		per_district.lethariel_mere.fill == 2,
		"the mere precinct is not the north-east's three plots and two " ..
		"dressings")

	say("lethariel_district", #resolved, plot_cells,
		table.concat(district_rows, ","))

	-- ------------------------------------------------------------------
	-- 3. THE CAPITAL'S SOCKET ROSTER
	-- ------------------------------------------------------------------
	assert(capital_totals.king == 1, "Lethariel has " .. capital_totals.king ..
		" thrones")
	assert(capital_totals.waypoint == 1, "Lethariel reserves " ..
		capital_totals.waypoint .. " travel pads")
	assert(capital_totals.quest == 2, "Lethariel has " ..
		capital_totals.quest .. " quest shells, not the core's and the " ..
		"mere shrine's")
	assert(capital_vendor_kinds.race and capital_vendor_kinds.general,
		"Lethariel is missing one of the two vendor families")
	-- Every patrol loop is 1..n with no gap and no repeat.
	local loop_rows = {}
	for group, loop in pairs(capital_loops) do
		local count = 0
		for _ in pairs(loop) do count = count + 1 end
		for order = 1, count do
			assert(loop[order] ~= nil, "the loop " .. group ..
				" has no waypoint " .. order)
		end
		assert(count >= 2, "the loop " .. group .. " is one waypoint long")
		loop_rows[#loop_rows + 1] = group .. ":" .. count
	end
	table.sort(loop_rows)
	-- The 80/20 rule of the sockets contract's section 8.3: at least one
	-- `idle` spawn socket per `work` socket, and the walker share the NPC lane
	-- derives from that inside the 10..30 per cent band.
	assert(capital_totals.idle_spawn >= capital_totals.work,
		"Lethariel authors " .. capital_totals.work .. " work sockets " ..
		"against " .. capital_totals.idle_spawn .. " idle spawn sockets")
	local residents = capital_totals.idle_spawn + capital_totals.work
	local walkers = math.ceil(capital_totals.idle_spawn / 5)
	local share = math.floor(walkers * 1000 / residents)
	assert(share >= 100 and share <= 300, "Lethariel's walker share is " ..
		share .. " per mille, outside the contract's 10..30 per cent")
	assert(capital_totals.spare >= 20, "Lethariel offers only " ..
		capital_totals.spare .. " spare wander spots")

	local activity_rows = {}
	for activity, count in pairs(capital_activities) do
		activity_rows[#activity_rows + 1] = activity .. ":" .. count
	end
	table.sort(activity_rows)
	local kind_rows = {}
	for kind in pairs(capital_vendor_kinds) do
		kind_rows[#kind_rows + 1] = kind
	end
	table.sort(kind_rows)

	say("lethariel_sockets", capital_totals.sockets, capital_totals.work,
		capital_totals.idle_spawn, capital_totals.spare,
		capital_totals.vendor, capital_totals.guard_post,
		capital_totals.guard_patrol, residents, walkers, share,
		table.concat(loop_rows, ","))
	say("lethariel_activities", #activity_rows,
		table.concat(activity_rows, ","), table.concat(kind_rows, ","))

	-- ------------------------------------------------------------------
	-- 4. THE LOTS AND THE PERMUTATION
	-- ------------------------------------------------------------------
	local LOT = quadrants.LOT
	local function overlaps(a1, a2, b1, b2) return a1 <= b2 and b1 <= a2 end
	local street_runs = {}
	local function add_run(run, half)
		if run.axis == "x" then
			street_runs[#street_runs + 1] = {id = run.id, min_x = run.from,
				max_x = run.to, min_z = run.at - half, max_z = run.at + half}
		else
			street_runs[#street_runs + 1] = {id = run.id, min_z = run.from,
				max_z = run.to, min_x = run.at - half, max_x = run.at + half}
		end
	end
	for _, list in ipairs({capital.avenues, capital.ring,
			quadrants.lane_runs()}) do
		for index = 1, #list do
			add_run(list[index], (avenue.WIDTH - 1) / 2 + 1)
		end
	end
	for index = 1, #capital.edge do
		add_run(capital.edge[index], grove.HALF)
	end

	local lot_count, fill_count = 0, 0
	local placed = {}
	for _, quadrant in ipairs(quadrants.QUADRANTS) do
		local turns = quadrants.turns_of(quadrant)
		local function check_lot(lot, reach, lane, tag)
			local min_x, max_x = lot.x - reach, lot.x + reach
			local min_z, max_z = lot.z - reach, lot.z + reach
			assert(min_x >= -250 and max_x <= 250 and min_z >= -250 and
				max_z <= 250, tag .. " leaves the envelope")
			assert(not (overlaps(min_x, max_x, -48, 48) and
				overlaps(min_z, max_z, -48, 48)), tag .. " stands on the core")
			assert(not overlaps(min_z, max_z, -16, 16), tag ..
				" stands in the x gate corridor")
			assert(not overlaps(min_x, max_x, -16, 16), tag ..
				" stands in the z gate corridor")
			-- Inside its OWN quarter, which is the one rule that is not
			-- symmetric in the lot alone.
			local qx, qz = quadrants.rotate(lot.x, lot.z, (4 - turns) % 4)
			assert(qx - reach >= LOT.quarter and qz + reach <= -LOT.quarter,
				tag .. " leaves its own quarter")
			for _, run in ipairs(street_runs) do
				assert(not (overlaps(min_x, max_x, run.min_x, run.max_x) and
					overlaps(min_z, max_z, run.min_z, run.max_z)),
					tag .. " stands on the street " .. run.id)
			end
			for _, other in ipairs(placed) do
				local gap = math.max(lane, other.lane)
				assert(not (overlaps(min_x - gap, max_x + gap,
						other.x - other.reach, other.x + other.reach) and
					overlaps(min_z - gap, max_z + gap,
						other.z - other.reach, other.z + other.reach)),
					tag .. " leaves no lane to " .. other.tag)
			end
			placed[#placed + 1] = {x = lot.x, z = lot.z, reach = reach,
				lane = lane, tag = tag}
		end
		local lots = quadrants.LOTS[quadrant]
		local expect = (quadrant == quadrants.FIXED_QUADRANT) and
			#quadrants.MERE_AUTHORED or #quadrants.AUTHORED
		assert(#lots == expect, quadrant .. " carries " .. #lots .. " lots")
		for index = 1, #lots do
			lot_count = lot_count + 1
			check_lot(lots[index], LOT.reach, LOT.lane,
				quadrant .. " lot " .. index)
		end
		local fills = quadrants.FILL_LOTS[quadrant]
		local reaches = (quadrant == quadrants.FIXED_QUADRANT) and
			quadrants.MERE_FILL_REACHES or quadrants.FILL_REACHES
		assert(#fills == #reaches, quadrant .. " carries " .. #fills ..
			" fill lots against " .. #reaches .. " reaches")
		for index = 1, #fills do
			fill_count = fill_count + 1
			check_lot(fills[index], reaches[index], quadrants.FILL.lane,
				quadrant .. " fill " .. index)
		end
	end
	assert(lot_count == 30 and fill_count == 14,
		"Lethariel carries " .. lot_count .. " lots and " .. fill_count ..
		" fill lots")

	-- Every plot fits the lot it stands on.
	for _, entry in ipairs(resolved) do
		local blueprint = plot_results[entry.id].blueprint
		local reach = LOT.reach
		if entry.kind == "fill" then
			local reaches = (entry.quadrant == quadrants.FIXED_QUADRANT) and
				quadrants.MERE_FILL_REACHES or quadrants.FILL_REACHES
			reach = reaches[entry.lot]
		end
		assert(blueprint.bounds.min.x >= -reach and
			blueprint.bounds.max.x <= reach and
			blueprint.bounds.min.z >= -reach and
			blueprint.bounds.max.z <= reach,
			"the plot " .. entry.id .. " overruns its lot of +-" .. reach)
	end

	-- The permutation: all six are bijections of the three moving roles, the
	-- canonical one is the authored order, the fixed role never moves, and a
	-- seeded assignment reproduces itself.
	local permutations = {}
	for index = 0, 5 do
		local candidate = quadrants.permutation_of_index(index)
		quadrants.check_permutation(candidate)
		local key = table.concat(candidate, "")
		assert(not permutations[key], "two indices give the permutation " ..
			key)
		permutations[key] = true
		local seeded = quadrants.assign({permutation = candidate})
		assert(seeded[quadrants.FIXED_ROLE].quadrant ==
			quadrants.FIXED_QUADRANT, "the mere precinct moved")
		local taken = {}
		for _, role in ipairs(quadrants.MOVING_ROLES) do
			local quadrant = seeded[role].quadrant
			assert(quadrant ~= quadrants.FIXED_QUADRANT and not taken[quadrant],
				"the permutation " .. key .. " puts two districts in " ..
					quadrant)
			taken[quadrant] = true
		end
	end
	local raw_sha256 = common.new_sha256()
	local seeded_rows = {}
	for _, seed in ipairs({"531802985935182545", "8675309",
			"15912857179583385436"}) do
		local first = quadrants.permutation(seed, raw_sha256)
		local again = quadrants.permutation(seed, raw_sha256)
		assert(table.concat(first, "") == table.concat(again, ""),
			"the permutation for seed " .. seed .. " is not a function")
		seeded_rows[#seeded_rows + 1] = seed .. ":" .. table.concat(first, "")
	end
	assert(table.concat(permutation, "") ==
		table.concat(quadrants.canonical(), ""),
		"the engine-free resolve is not the canonical assignment")

	say("lethariel_lots", lot_count, fill_count, LOT.reach, LOT.lane,
		quadrants.FILL.lane, table.concat(seeded_rows, ","))

	-- ------------------------------------------------------------------
	-- 5. THE OVERLAY: the avenues and the GROVE EDGE
	-- ------------------------------------------------------------------
	--
	-- A synthetic terraced profile, three nodes per terrace, which is the elf
	-- step of the contract's section 1.
	local STEP = 3
	local function surface(x, z)
		return 40 + STEP * math.floor((x + 2 * z) / 41)
	end
	local runs = capital.overlay_runs(quadrants.lane_runs())
	assert(#runs == 19, "Lethariel's overlay carries " .. #runs .. " runs")
	local names = capital.overlay_names(avenue, palette)
	for position, name in ipairs(names) do
		assert(position == 1 or parts.less_bytes(names[position - 1], name),
			"the overlay palette is not in byte order at " .. name)
	end

	local function run_spec(run, from, to)
		return {id = run.id, axis = run.axis, at = run.at,
			from = from or run.from, to = to or run.to,
			width = avenue.WIDTH, lamp_spacing = avenue.LAMP_SPACING,
			lamp_phase = run.from, reach = avenue.REACH}
	end

	local overlay_cells, road_cells, edge_cells = 0, 0, 0
	local edge_rows = {}
	local digest_parts = {}
	for _, run in ipairs(runs) do
		local piece = capital.overlay_run(avenue, palette,
			run_spec(run), surface)
		local plan = capital.edge_plan[run.id]
		local half = plan and grove.HALF or ((avenue.WIDTH - 1) / 2 + 1)
		for _, cell in ipairs(piece.cells) do
			local across = (run.axis == "x") and (cell.z - run.at) or
				(cell.x - run.at)
			assert(math.abs(across) <= half, run.id ..
				" writes a cell " .. across .. " lanes off its centre line, " ..
				"outside the seam's activation band")
			local along = (run.axis == "x") and cell.x or cell.z
			assert(along >= run.from and along <= run.to, run.id ..
				" writes at " .. along .. ", outside its own span")
			assert(cell.name == "air" or world.nodes[cell.name] ~= nil,
				run.id .. " writes the unregistered node " .. cell.name)
		end
		overlay_cells = overlay_cells + #piece.cells
		if plan then
			edge_cells = edge_cells + #piece.cells
			edge_rows[#edge_rows + 1] = run.id .. ":" .. #piece.cells .. ":" ..
				piece.hedges .. ":" .. piece.standards .. ":" ..
				piece.thresholds
			-- THE THRESHOLD PASSAGE is clear from the ground to the lintel, so
			-- the road that runs through it is a road.
			for _, gate in ipairs(plan.gates) do
				for step = -grove.GATE_PASSAGE, grove.GATE_PASSAGE do
					for lane = -grove.HALF, grove.HALF do
						local x, z
						if run.axis == "x" then x, z = gate + step, run.at + lane
						else x, z = run.at + lane, gate + step end
						for y = surface(x, z) + 1,
								surface(x, z) + avenue.MIN_CLEAR do
							for _, cell in ipairs(piece.cells) do
								if cell.x == x and cell.y == y and
										cell.z == z then
									assert(cell.name == "air", run.id ..
										" blocks its own threshold at " .. x ..
										"," .. y .. "," .. z .. " with " ..
										cell.name)
								end
							end
						end
					end
				end
			end
			-- THE BELT STOPS AT THE WATER.
			for _, span in ipairs(plan.water or {}) do
				for _, cell in ipairs(piece.cells) do
					local along = (run.axis == "x") and cell.x or cell.z
					assert(along < span[1] or along > span[2], run.id ..
						" plants a hedge on the water at " .. along)
				end
			end
		else
			road_cells = road_cells + #piece.cells
		end
		digest_parts[#digest_parts + 1] = run.id .. "/" .. #piece.cells
	end

	-- A PIECE OF A RUN IS EXACTLY THAT STRETCH OF THE WHOLE RUN. The edge is
	-- cut at every column of a representative stretch and the union compared
	-- with the whole, cell for cell -- the property that lets the successor
	-- call it per mapchunk, and the one this module got wrong first (its
	-- standards wrote their crowns from the centre and two hundred cells were
	-- never written by any mapchunk).
	local cut_run = capital.edge[2]
	local whole = capital.overlay_run(avenue, palette,
		run_spec(cut_run, -60, 60), surface)
	local union, union_count = {}, 0
	for column = -60, 60 do
		local piece = capital.overlay_run(avenue, palette,
			run_spec(cut_run, column, column), surface)
		for _, cell in ipairs(piece.cells) do
			local key = cell.x .. ":" .. cell.y .. ":" .. cell.z
			if union[key] == nil then
				union[key] = cell.name
				union_count = union_count + 1
			else
				assert(union[key] == cell.name,
					"two one-column pieces of " .. cut_run.id ..
						" disagree at " .. key)
			end
		end
	end
	assert(union_count == #whole.cells, "the cut union of " .. cut_run.id ..
		" has " .. union_count .. " cells against the whole's " ..
		#whole.cells)
	for _, cell in ipairs(whole.cells) do
		local key = cell.x .. ":" .. cell.y .. ":" .. cell.z
		assert(union[key] == cell.name, "the cut union of " .. cut_run.id ..
			" differs at " .. key)
	end

	-- The road itself: pavement at the surface, a walkable climb over every
	-- terrace joint, and no height query the caller did not answer.
	local road = capital.overlay_run(avenue, palette,
		run_spec(capital.avenues[4]), surface)
	local deck = {}
	for _, cell in ipairs(road.cells) do
		if cell.z == 0 then
			local top = deck[cell.x]
			if top == nil or cell.y > top then deck[cell.x] = cell.y end
		end
	end
	local worst_step = 0
	for x = capital.avenues[4].from + 1, capital.avenues[4].to do
		if deck[x] and deck[x - 1] then
			local step = math.abs(deck[x] - deck[x - 1])
			if step > worst_step then worst_step = step end
		end
	end
	assert(worst_step <= 1, "the east avenue steps " .. worst_step ..
		" nodes in one column")

	local digest = common.hex(common.new_sha256()(
		table.concat(digest_parts, "\n")))
	say("lethariel_overlay", #runs, overlay_cells, road_cells, edge_cells,
		#names, worst_step, union_count, digest)
	say("lethariel_edge", grove.HALF, grove.BELT, grove.HEDGE,
		grove.GATE_PASSAGE, grove.RISE, table.concat(edge_rows, ","))

	return table.concat(report)
end
