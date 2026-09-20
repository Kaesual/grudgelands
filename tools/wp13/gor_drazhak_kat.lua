-- Architectural acceptance for Gor Drazhak, the orc capital.
--
-- `blueprint_kat.lua` holds the six START blueprints to the invariants of
-- docs/research/wp13-settlement-pipeline.md section 5, and `library_kat.lua`
-- holds the parts. A capital is a different shape -- one core, a list of
-- terrain-relative district plots, and an overlay that has no cells until a
-- surface is handed to it -- so this file is its equivalent, in the shape
-- `highcourt_kat.lua` and `dur_brannoc_kat.lua` established, against
-- docs/research/wp13-capitals-pois-contract.md (section 2.1 envelopes, 2.3
-- budgets, 2.4 the orc race line) and
-- docs/research/wp13-npc-sockets-contract.md (section 2 the socket field,
-- section 8 work sockets, profession vendors and the 80/20 rule).
--
-- WHAT IT ADDS TO THE TWO CAPITAL KATS BEFORE IT, and each one is a way this
-- capital in particular can break:
--
--   * section 4, THE RAMPART. Gor Drazhak's city wall is not a masonry curtain
--     but a stake palisade on a dug bank (`wp13/orc_palisade.lua`), so the
--     wall rules are asked of a different section: the five constants it
--     shares with `wp13/wall.lua` are asserted EQUAL rather than assumed, no
--     cell of any piece leaves the seam's activation band, no column has a gap
--     between its footing and its walk, the walk never changes by more than a
--     node and every change is a tread, the gate passage is clear through the
--     whole thickness, and the piece cut at every column of a representative
--     stretch unions to the whole run cell for cell.
--   * section 6, THE WORK SOCKETS. The sockets contract's section 8.1 says a
--     `work` socket faces the feature its activity works, within three nodes,
--     and section 8.5 says the placing lane's own KAT checks it. Gor Drazhak
--     places thirteen of the fifteen activities, including ALL SIX wave-2
--     ones, so this is where that rule is measured.
--   * section 7, THE QUADRANTS. One authored lot grid turned four times, with
--     seven measured repairs; the KAT holds every lot inside its own quarter
--     and off every street run, and walks the seeded permutation.
--
-- Plain Lua 5.1; the same bytes must run under LuaJIT and PUC 5.1.

return function(repo)
	local public_socket=dofile(repo.."/tools/r10_cap/public_socket_oracle.lua")
	local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
	local parts = dofile(wp13 .. "/parts.lua")
	local palettes = dofile(wp13 .. "/palette.lua")
	local avenue = dofile(wp13 .. "/avenue.lua")(wp13)
	local wall = dofile(wp13 .. "/wall.lua")(wp13)
	local palisade = dofile(wp13 .. "/orc_palisade.lua")(wp13)
	local capital = dofile(wp13 .. "/gor_drazhak.lua")(wp13)
	local quadrants = dofile(wp13 .. "/gor_drazhak_quadrants.lua")()
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
	-- unregisters.
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
	-- `builtin_shared.check_attached_node`.
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

	local orc = palettes.new("orc")
	local LIGHT = {}
	for _, role in ipairs({"light_wall", "light_post", "light_indoor"}) do
		LIGHT[orc.node(role)] = true
	end
	local LEAF = {}
	for _, name in ipairs(orc.names("door")) do LEAF[name] = true end
	local HIDDEN = orc.node("door_hidden")

	-- Nodes an ordinary walk passes through. Everything else counts as solid,
	-- which keeps the route check conservative; a door counts as passable
	-- because a player opens it.
	local PASSABLE = {["air"] = true, [HIDDEN] = true}
	for name in pairs(LEAF) do PASSABLE[name] = true end
	for _, name in ipairs({"default:torch", "default:torch_wall",
			"default:dry_grass_3", "default:dry_grass_5", "default:dry_shrub",
			"grug_decor:cottages_straw_mat"}) do
		PASSABLE[name] = true
	end

	-- ------------------------------------------------------------------
	-- the shared body: every rule a finished WP13 composition has to pass
	-- ------------------------------------------------------------------
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
			local definition=world.nodes[cell.name]
			assert(not definition or not definition.liquidtype or
				definition.liquidtype=="none", label .. " writes a liquid")
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
		local function node(x, y, z)
			local cell = at(x, y, z)
			if cell then return cell.name end
			return (y <= spec.ground) and "default:stone" or "air"
		end
		local function solid(x, y, z) return not PASSABLE[node(x, y, z)] end
		local function stand(x, y, z)
			return solid(x, y - 1, z) and not solid(x, y, z) and
				not solid(x, y + 1, z)
		end

		-- Every name against the real registry, the authored tables of
		-- `parts.lua` in both directions, the two shape rules, the settled
		-- panes, the attachment ratings and the torch rule.
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
				end
				if (groups.pane or 0) > 0 then panes = panes + 1 end
				local dx, dy, dz = attach_step(def, cell.param2)
				if dx ~= nil then
					attached = attached + 1
					local support = at(cell.x + dx, cell.y + dy, cell.z + dz)
					local name = support and support.name or
						((cell.y + dy <= spec.ground) and "default:stone" or
							"air")
					assert(registry.is_opaque_full(world, name) or
							walkable(name),
						label .. ": the attached " .. cell.name .. " at " ..
							cell.x .. "," .. cell.y .. "," .. cell.z ..
							" hangs on " .. name)
				end
				if LIGHT[cell.name] and def.paramtype2 == "wallmounted" then
					torches = torches + 1
					local step = WALL_DIR[cell.param2]
					assert(step, label .. ": a torch carries the wallmounted " ..
						"value " .. cell.param2)
					local support = at(cell.x + step[1], cell.y + step[2],
						cell.z + step[3])
					local name = support and support.name or
						((cell.y + step[2] <= spec.ground) and "default:stone"
							or "air")
					assert(registry.is_opaque_full(world, name),
						label .. ": the torch at " .. cell.x .. "," .. cell.y ..
							"," .. cell.z .. " is carried by " .. name)
				end
			end
		end

		-- Every doorway passable, with a walkable step on both sides.
		local doors = blueprint.landmarks.doors or {}
		for _, door in ipairs(doors) do
			local dir = FACEDIR_DIR[door.face % 4]
			for _, side in ipairs({1, -1}) do
				local x = door.x + dir[1] * side
				local z = door.z + dir[2] * side
				assert(stand(x, door.y, z), label ..
					": the doorway of " .. tostring(door.id) .. " at " ..
					door.x .. "," .. door.y .. "," .. door.z ..
					" has no standing room on the side " .. side)
			end
		end

		-- Every socket a place somebody can stand.
		local sockets = blueprint.landmarks.sockets or {}
		local seen = {}
		for _, entry in ipairs(sockets) do
			assert(type(entry.id) == "string" and entry.id ~= "",
				label .. " has a socket with no id")
			assert(seen[entry.id] == nil,
				label .. " publishes the socket " .. entry.id .. " twice")
			seen[entry.id] = true
			assert(type(entry.dir) == "table" and
					(math.abs(entry.dir.x) + math.abs(entry.dir.z)) == 1,
				label .. ": the socket " .. entry.id .. " has no unit dir")
			local dir = FACEDIR_DIR[entry.face % 4]
			assert(dir[1] == entry.dir.x and dir[2] == entry.dir.z,
				label .. ": the socket " .. entry.id ..
					" has a dir that is not its own facedir")
			assert(public_socket(entry,node(entry.x,entry.y,entry.z)) or
				stand(entry.x, entry.y, entry.z), label ..
				": the socket " .. entry.id .. " at " .. entry.x .. "," ..
				entry.y .. "," .. entry.z .. " is not a standing position")
		end

		return {index = index, at = at, node = node, solid = solid,
			stand = stand, cells = #cells, solids = solids, lights = lights,
			panes = panes, attached = attached, torches = torches,
			sockets = sockets, doors = doors}
	end

	-- ------------------------------------------------------------------
	-- 1. THE CORE
	-- ------------------------------------------------------------------
	local core = capital.core()
	local core_view = check_composition("gor_drazhak core", core,
		{reach = 49, ymin = -2, ymax = 40, budget = 150000, ground = 0,
			min_lights = 30})
	local L = core.landmarks

	-- The ground course is flat at y = 0 by construction: every column the
	-- composition lays ground on carries it at y = 0 and nowhere else.
	do
		local ground_names = {}
		for _, role in ipairs({"ground", "ground_patch", "ground_bare",
				"subsoil", "path", "plaza", "plaza_edge"}) do
			ground_names[orc.node(role)] = true
		end
		local off_course = 0
		for _, cell in ipairs(core.cells) do
			if ground_names[cell.name] and cell.y ~= 0 and cell.y ~= -1 then
				off_course = off_course + 1
			end
		end
		-- The bank, the outcrops and the platform deliberately carry ground
		-- material above the course; everything else may not, and a hundred is
		-- the order of magnitude those three account for.
		assert(off_course < 1400, "the core lays " .. off_course ..
			" ground cells off its own course")
	end

	-- The four gate openings walk end to end.
	for _, gate in ipairs({"gate_south", "gate_north", "gate_east",
			"gate_west"}) do
		local spot = assert(L[gate], "the core has no " .. gate .. " landmark")
		assert(core_view.stand(spot.x, spot.y, spot.z),
			gate .. " is not a standing position")
	end
	do
		-- Walk the throne approach from the south gate to the hall's forecourt
		-- on the carriageway itself.
		local blocked = 0
		for z = -47, 5 do
			if not core_view.stand(0, 1, z) then blocked = blocked + 1 end
		end
		assert(blocked == 0, "the throne approach is blocked in " .. blocked ..
			" of its columns")
		for x = -47, 47 do
			if not core_view.stand(x, 1, 0) then
				assert(false, "the great east-west avenue is blocked at " .. x)
			end
		end
	end

	-- The identity pieces of the contract's orc line, each counted.
	assert(L.corner_towers == 4, "the precinct has " ..
		tostring(L.corner_towers) .. " corner towers")
	assert(L.bank_columns == 312, "the precinct bank has " ..
		tostring(L.bank_columns) .. " columns, not 312")
	assert(L.bank_stakes >= 90, "the precinct stockade carries only " ..
		tostring(L.bank_stakes) .. " stakes")
	assert(L.deck_rings == 4, "only " .. tostring(L.deck_rings) ..
		" flat decks carry a breastwork")
	assert(L.platform_cells > 200, "the fighting platform is " ..
		tostring(L.platform_cells) .. " cells")
	assert(L.acacias >= 5 and L.outcrops >= 4,
		"the open ground carries neither trees nor rock")

	-- THE FIGHTING PLATFORM is reachable and stood on. Its deck is walkable
	-- from the flight that climbs to it, and the two guard posts stand on it.
	do
		local deck = L.fighting_platform
		local top = deck.min.y
		local stood = 0
		for z = deck.min.z + 1, deck.max.z - 1 do
			for x = deck.min.x + 1, deck.max.x - 1 do
				if core_view.stand(x, 5, z) then stood = stood + 1 end
			end
		end
		assert(stood > 20, "the fighting platform has " .. stood ..
			" standing cells on its deck")
		assert(top == 0, "the platform landmark does not start at the ground")
		-- The flight: four treads climbing away from the platform's east face.
		local treads = 0
		for step = 0, 3 do
			local cell = core_view.at(deck.max.x + 1 + step, 4 - step,
				deck.max.z - 2)
			if cell and (world.nodes[cell.name].groups or {}).stair then
				treads = treads + 1
			end
		end
		assert(treads == 4, "the platform's flight has " .. treads ..
			" treads, not four")
	end

	say("gor_drazhak_core", core_view.cells, core_view.solids,
		core_view.lights, core_view.panes, core_view.attached,
		core_view.torches, #core_view.doors, #core_view.sockets,
		L.bank_columns, L.bank_stakes, L.corner_towers, L.deck_rings,
		L.acacias, L.outcrops, L.platform_cells, L.nave_floor)

	-- The king on his throne, looking down his own hall.
	do
		local king
		for _, entry in ipairs(core_view.sockets) do
			if entry.role == "king" then king = entry end
		end
		assert(king, "the core publishes no king socket")
		local hall = L.warlord_hall
		assert(king.x >= hall.min.x and king.x <= hall.max.x and
				king.z >= hall.min.z and king.z <= hall.max.z,
			"the king does not stand in his own hall")
		assert(king.dir.z == -1,
			"the king does not look down the approach his door opens on")
		say("gor_drazhak_throne", king.x, king.y, king.z, king.dir.x,
			king.dir.z)
	end

	-- ------------------------------------------------------------------
	-- 2. EVERY DISTRICT PLOT
	-- ------------------------------------------------------------------
	local plots = capital.district.plots
	assert(#plots == 52, "the four districts carry " .. #plots ..
		" plots, not 52")
	local plot_cells, plot_sockets = 0, {}
	local biggest, biggest_id = 0, "-"
	local built = {}
	for index = 1, #plots do
		local entry = plots[index]
		local blueprint = entry.build()
		built[index] = blueprint
		local view = check_composition("plot " .. entry.id, blueprint,
			{reach = 15, ymin = -6, ymax = 24, budget = 12000, ground = 0,
				min_lights = 2})
		plot_cells = plot_cells + view.cells
		if view.cells > biggest then
			biggest, biggest_id = view.cells, entry.id
		end
		for _, socket in ipairs(view.sockets) do
			plot_sockets[#plot_sockets + 1] = socket
		end

		-- The lot envelope is two nodes tighter than the contract's plot
		-- volume, which is what lets any district stand in any quadrant.
		local bounds = blueprint.bounds
		assert(bounds.min.x >= -13 and bounds.max.x <= 13 and
				bounds.min.z >= -13 and bounds.max.z <= 13,
			entry.id .. " leaves the lot envelope of +-13")
		-- The reference column is the plot origin.
		assert(blueprint.reference.x == 0 and blueprint.reference.z == 0,
			entry.id .. " does not level to the ground under its own centre")
		-- The foundation skirt reaches the contract's floor on the perimeter.
		local floor_columns = 0
		for _, cell in ipairs(blueprint.cells) do
			if cell.y == -6 then floor_columns = floor_columns + 1 end
		end
		assert(floor_columns >= 30, entry.id .. " carries only " ..
			floor_columns .. " columns of skirt at the contract's floor")
		-- The cleared airspace is published and is real.
		local clear_to = assert(blueprint.clear_to,
			entry.id .. " publishes no clear_to")
		assert(clear_to >= 8, entry.id .. " clears only " .. clear_to)
		local air_at_clear = 0
		for _, cell in ipairs(blueprint.cells) do
			if cell.y == clear_to and cell.name == "air" then
				air_at_clear = air_at_clear + 1
			end
		end
		assert(air_at_clear > 0, entry.id ..
			" publishes a clear_to it did not cut")
	end
	assert(plot_cells + core_view.cells <= 400000,
		"the capital writes " .. (plot_cells + core_view.cells) ..
			" cells, over the contract's 400 000")
	say("gor_drazhak_district", #plots, plot_cells,
		plot_cells + core_view.cells, biggest_id, biggest)

	-- ------------------------------------------------------------------
	-- 3. THE SOCKET CONTRACT over the whole capital
	-- ------------------------------------------------------------------
	local all = {}
	for _, entry in ipairs(core_view.sockets) do all[#all + 1] = entry end
	for _, entry in ipairs(plot_sockets) do all[#all + 1] = entry end

	local ROLES = {trainer=true,riding_trainer=true,mount_display=true,gear_display=true,public_station=true,king = true, vendor = true, quest = true, waypoint = true,
		guard_post = true, guard_patrol = true, idle = true, work = true}
	local ACTIVITIES = {smith = true, fish = true, farm = true, chop = true,
		tend = true, pray = true, stall = true, sit = true, sweep = true,
		mine = true, brew = true, carve = true, mourn = true, spar = true,
		forage = true}
	local KINDS = {race = true, general = true, butcher = true, smith = true,
		fishmonger = true, baker = true, tailor = true, mason = true,
		brewer = true, bowyer = true, herbalist = true, armourer = true,
		tanner = true, embalmer = true}

	local roles, kinds, activities, loops = {}, {}, {}, {}
	local ids = {}
	local idle_spawn, spare, work_count = 0, 0, 0
	for _, entry in ipairs(all) do
		assert(ROLES[entry.role],
			"the socket " .. entry.id .. " has the unknown role " ..
				tostring(entry.role))
		assert(ids[entry.id] == nil,
			"the capital publishes the socket id " .. entry.id .. " twice")
		ids[entry.id] = true
		roles[entry.role] = (roles[entry.role] or 0) + 1
		if entry.role == "vendor" then
			assert(KINDS[entry.kind], "the vendor " .. entry.id ..
				" has the unknown kind " .. tostring(entry.kind))
			assert(kinds[entry.kind] == nil,
				"the capital carries two vendors of the kind " .. entry.kind)
			kinds[entry.kind] = entry.id
		end
		if entry.role == "work" then
			work_count = work_count + 1
			assert(ACTIVITIES[entry.activity], "the work socket " .. entry.id ..
				" names the unknown activity " .. tostring(entry.activity))
			activities[entry.activity] =
				(activities[entry.activity] or 0) + 1
		end
		if entry.role == "idle" then
			if entry.spawn == false then
				spare = spare + 1
				assert(entry.tags == nil,
					"the spare " .. entry.id .. " carries a tag")
			else
				idle_spawn = idle_spawn + 1
			end
		end
		assert(entry.spawn == nil or entry.spawn == false or
				entry.role == "idle",
			"only an idle socket may be spare, not " .. entry.id)
		if entry.group then
			loops[entry.group] = loops[entry.group] or {}
			local loop = loops[entry.group]
			assert(loop[entry.order] == nil, "the loop " .. entry.group ..
				" has two waypoints of order " .. tostring(entry.order))
			loop[entry.order] = entry.id
		end
	end
	assert(roles.king == 1, "the capital has " .. tostring(roles.king) ..
		" kings")
	assert(roles.waypoint == 1, "the capital has " ..
		tostring(roles.waypoint) .. " travel waypoints")
	assert(roles.quest == 2, "the capital has " .. tostring(roles.quest) ..
		" quest shells")
	assert(kinds.race and kinds.general,
		"the capital has lost one of the two royal vendor families")

	-- Every loop's orders are 1..n with no gap and no repeat.
	local loop_names = {}
	for name in pairs(loops) do loop_names[#loop_names + 1] = name end
	table.sort(loop_names)
	for _, name in ipairs(loop_names) do
		local loop = loops[name]
		local count = 0
		for _ in pairs(loop) do count = count + 1 end
		for order = 1, count do
			assert(loop[order], "the loop " .. name ..
				" has no waypoint of order " .. order)
		end
		assert(count >= 2, "the loop " .. name .. " has " .. count ..
			" waypoints")
	end

	-- The 80/20 rule of the sockets contract's section 8.3: the walker share
	-- has to land inside 10..30 %, and at least one idle spawn socket per work
	-- socket is what keeps it there.
	local residents = idle_spawn + work_count
	local walkers = math.ceil(idle_spawn / 5)
	assert(idle_spawn >= work_count, "the capital has " .. work_count ..
		" work sockets against " .. idle_spawn .. " idle spawn sockets")
	assert(walkers * 10 >= residents and walkers * 10 <= residents * 3,
		"the walker share is " .. walkers .. " of " .. residents)
	assert(spare >= 20, "the capital carries only " .. spare .. " spare spots")

	local activity_names = {}
	for name in pairs(activities) do
		activity_names[#activity_names + 1] = name
	end
	table.sort(activity_names)
	local kind_names = {}
	for name in pairs(kinds) do kind_names[#kind_names + 1] = name end
	table.sort(kind_names)
	say("gor_drazhak_sockets", #all, roles.work, roles.vendor, roles.idle,
		idle_spawn, spare, roles.guard_post, roles.guard_patrol,
		#loop_names, residents, walkers,
		table.concat(activity_names, ","), table.concat(kind_names, ","))

	-- ------------------------------------------------------------------
	-- 4. THE RAMPART
	-- ------------------------------------------------------------------
	--
	-- (0) The five constants the terrain tool and the seam share with
	-- `wall.lua`. `tools/wp13/capital_wall.lua` loads ITS constants from that
	-- module and measures the ground under THESE runs, so the day one of them
	-- moves the other must move with it or the measurement is of the wrong
	-- rule. This is the row that says so.
	assert(palisade.HALF == wall.HALF, "the rampart's activation band is " ..
		palisade.HALF .. " and the curtain's " .. wall.HALF)
	assert(palisade.RISE == wall.RISE, "the rampart's rise differs")
	assert(palisade.FOOTING == wall.FOOTING, "the rampart's footing differs")
	assert(palisade.REACH == wall.REACH, "the rampart's look-around differs")
	assert(palisade.GATE_PASSAGE == wall.GATE_PASSAGE,
		"the rampart's gate passage differs")

	local WALL_LANES = palisade.HALF
	local wall_by_id = {}
	for _, spec in ipairs(capital.wall) do wall_by_id[spec.id] = spec end
	assert(#capital.wall == 4, "the rampart has " .. #capital.wall .. " runs")
	for _, id in ipairs({"wall_west", "wall_east"}) do
		local plan = capital.wall_plan[id]
		assert(#plan.cross_towers == 2,
			id .. " does not carry the two corner towers")
		assert(wall_by_id[id].to >= 256 + palisade.TOWER_HALF,
			id .. " ends before its own corner tower does")
	end
	for _, id in ipairs({"wall_south", "wall_north"}) do
		local plan = capital.wall_plan[id]
		assert(#plan.cross_towers == 0, id .. " claims a corner tower")
		assert(wall_by_id[id].to <= 256 - WALL_LANES,
			id .. " reaches into the corner tower of the run it meets")
	end

	-- THE SYNTHETIC GROUND IS TWO-DIMENSIONAL, and it has to be.
	--
	-- The first version of this fixture gave every run the same profile as a
	-- function of its own axis, which is exactly the shape that CANNOT expose
	-- the corner defect: the two runs that meet at a corner then sample the
	-- same numbers and agree by accident. The real mesa does not, and the
	-- nine-seed sweep found the two runs' walks four nodes apart at one corner
	-- on the user's own world seed.
	--
	-- So the field below terraces along x and along z INDEPENDENTLY, with
	-- different step positions on the two axes and a cross fall over one
	-- stretch, which puts every corner between two different staircases.
	local function wall_field(x, z)
		local y = 110
		if x > -200 then y = y - 4 end
		if x > -100 then y = y - 4 end
		if x > -99 then y = y - 4 end
		if x > 40 then y = y + 4 end
		if x > 150 then y = y - 4 end
		if z > -230 then y = y + 4 end
		if z > -60 then y = y - 4 end
		if z > 20 then y = y - 4 end
		if z > 90 then y = y + 4 end
		if z > 200 then y = y - 4 end
		-- A cross fall over one stretch of the east run's own thickness.
		if x > 250 and z > -20 and z < 60 then y = y - 4 end
		-- TWO SHOULDERS PLACED TO BREAK THE CORNERS, one each way. A terraced
		-- field alone is not enough to make two perpendicular runs disagree --
		-- a shoulder has to stand inside ONE run's look-around and outside the
		-- other's, which is exactly the shape the real mesa has and the first
		-- version of this fixture did not:
		--
		--   * on the east run's own seven lanes, four columns short of the
		--     north-east corner tower, so the Z run's envelope is raised there
		--     and the X run's (whose lanes are z 253..259) is not;
		--   * on the south run's own seven lanes, three columns short of its
		--     west end, so the X run's envelope is raised and the Z run's
		--     (whose lanes are x -259..-253) is not.
		--
		-- Without `orc_palisade.lua` section 1b the two corners then differ by
		-- four and five nodes and section 4g goes red, which is the point.
		if x > 252 and x < 260 and z > 245 and z < 253 then y = y + 8 end
		if x > -250 and x < -242 and z > -260 and z < -252 then y = y + 8 end
		return y
	end
	local function wall_ground(p) return p end
	local function wall_surface()
		return wall_field
	end

	local WALL_NAMES = {}
	for _, name in ipairs(palisade.palette_names(orc)) do
		WALL_NAMES[name] = true
	end

	local wall_digest_rows, wall_cells, wall_columns = {}, 0, 0
	local wall_gaps, wall_steps, wall_treads, wall_passage = 0, 0, 0, 0
	local wall_stakes = 0
	-- Every run's walk height, column by column, read back out of the cells it
	-- wrote. Section 4g compares the four corners out of this.
	local walk_of = {}
	for _, spec in ipairs(capital.wall) do
		local plan = capital.wall_plan[spec.id]
		local surface = wall_surface()
		local piece = palisade.run(orc, {id = spec.id, axis = spec.axis,
			at = spec.at, from = spec.from, to = spec.to, width = avenue.WIDTH,
			lamp_spacing = avenue.LAMP_SPACING, lamp_phase = spec.from,
			reach = avenue.REACH}, surface, plan)
		wall_cells = wall_cells + #piece.cells
		wall_columns = wall_columns + piece.columns
		wall_stakes = wall_stakes + piece.stakes

		local at_cell = {}
		for _, cell in ipairs(piece.cells) do
			assert(WALL_NAMES[cell.name], spec.id .. " writes " .. cell.name ..
				", which is outside the rampart's own palette")
			local p, lane
			if spec.axis == "x" then
				p, lane = cell.x, cell.z - spec.at
			else
				p, lane = cell.z, cell.x - spec.at
			end
			-- (a) THE ACTIVATION BAND.
			assert(lane >= -WALL_LANES and lane <= WALL_LANES,
				spec.id .. " writes a cell " .. lane ..
					" lanes from its centre line, outside the " .. WALL_LANES ..
					" the seam activates the run on")
			at_cell[p .. ":" .. lane .. ":" .. cell.y] = cell.name
			wall_digest_rows[#wall_digest_rows + 1] =
				table.concat({p, lane, cell.y, cell.name, cell.param2 or 0},
					":")
		end

		-- The walk of a column, read back out of the piece and NOT out of the
		-- module that wrote it: the highest cell of the centre lane that is
		-- solid and carries AUTHORED AIR directly above it.
		local function deck_of(p)
			for y = 200, 70, -1 do
				local here = at_cell[p .. ":0:" .. y]
				local above = at_cell[p .. ":0:" .. (y + 1)]
				if here ~= nil and here ~= parts.AIR and above == parts.AIR then
					return y
				end
			end
			return nil
		end

		local gate_from, gate_to = -palisade.GATE_PASSAGE,
			palisade.GATE_PASSAGE
		local previous_deck
		walk_of[spec.id] = {}
		for p = spec.from, spec.to do
			local deck = deck_of(p)
			assert(deck, spec.id .. ": the column " .. p ..
				" has no walk at all")
			walk_of[spec.id][p] = deck
			local in_gate = p >= gate_from and p <= gate_to
			if in_gate then
				-- (d) THE GATE IS OPEN: no fill under the walk anywhere across
				-- the thickness.
				for lane = -WALL_LANES, WALL_LANES do
					local gx, gz
					if spec.axis == "x" then
						gx, gz = p, spec.at + lane
					else
						gx, gz = spec.at + lane, p
					end
					for y = wall_field(gx, gz) + 1, deck - 1 do
						local name = at_cell[p .. ":" .. lane .. ":" .. y]
						assert(name == nil or name == parts.AIR,
							spec.id .. ": the gate passage at " .. p .. "," ..
								lane .. "," .. y .. " is " .. name)
					end
					wall_passage = wall_passage + 1
				end
			else
				-- (b) NO GAP: the five body lanes are solid from the footing
				-- to the walk.
				for lane = -2, 2 do
					local ground = surface(
						spec.axis == "x" and p or spec.at + lane,
						spec.axis == "x" and spec.at + lane or p)
					local lowest
					for y = ground, 70, -1 do
						if at_cell[p .. ":" .. lane .. ":" .. y] == nil then
							lowest = y + 1
							break
						end
					end
					assert(lowest and lowest <= ground, spec.id ..
						": the bank at " .. p .. "," .. lane ..
						" does not reach its own ground")
					for y = lowest, deck do
						local name = at_cell[p .. ":" .. lane .. ":" .. y]
						if name == nil or name == parts.AIR then
							wall_gaps = wall_gaps + 1
						end
					end
				end
			end
			-- (c) THE WALK: at most one node of change per column, and a change
			-- is always a tread.
			if previous_deck ~= nil then
				local step = deck - previous_deck
				assert(math.abs(step) <= 1, spec.id ..
					": the walk changes by " .. step .. " nodes at column " ..
					p)
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
	assert(wall_gaps == 0, "the rampart has " .. wall_gaps ..
		" cells of hole between its footing and its walk")
	assert(wall_steps >= 20, "the test profile did not exercise the walk: " ..
		wall_steps .. " one-node steps")
	assert(wall_treads >= wall_steps - 8, "only " .. wall_treads ..
		" of the walk's " .. wall_steps .. " steps are treads")
	assert(wall_stakes >= 2000, "the stockade carries only " .. wall_stakes ..
		" stakes over four runs")

	-- (g) THE FOUR CORNERS AGREE, which is what makes the walk one circuit
	-- rather than four stretches.
	--
	-- A z-run's walk arrives at its own corner tower's centre column and an
	-- x-run's stops four columns earlier, at the tower's city-face opening.
	-- The two compute their envelopes from two different neighbourhoods, so
	-- without the reconciliation of `orc_palisade.lua` section 1b they land at
	-- two different heights -- and the tower's opening is three courses, so a
	-- disagreement of three is a walk that stops there. This asserts the step
	-- is ZERO, which the reconciliation makes it by construction; on the
	-- authored profile above, which is deliberately different along x and along
	-- z, the raw envelopes differ and the clamp is what closes them.
	local corner_steps = {}
	for _, spec in ipairs(capital.wall) do
		for _, corner in ipairs(capital.wall_plan[spec.id].corners or {}) do
			local other
			for _, peer in ipairs(capital.wall) do
				if peer.axis == corner.axis and peer.at == corner.at then
					other = peer.id
				end
			end
			assert(other, spec.id .. ": the corner at " .. corner.p ..
				" names no run of this capital")
			local mine = walk_of[spec.id][corner.p]
			local theirs = walk_of[other][corner.other_p]
			assert(mine and theirs, spec.id .. "/" .. other ..
				": a corner column carries no walk")
			assert(mine == theirs, spec.id .. " walks at " .. mine ..
				" where " .. other .. " walks at " .. theirs ..
				" (corner " .. corner.p .. ")")
			corner_steps[#corner_steps + 1] = math.abs(mine - theirs)
		end
	end
	assert(#corner_steps == 8, "the four corners are named " ..
		#corner_steps .. " times, not eight")

	-- (e) A PIECE OF A RUN IS EXACTLY THAT STRETCH OF THE WHOLE RUN: the
	-- rampart is cut at every column of a representative stretch and the union
	-- of the two pieces compared with the whole, cell for cell. That is what
	-- lets the successor call it per mapchunk.
	-- The stretch is chosen to CROSS A CORNER (z = 256 on the east run): the
	-- reconciliation of section 1b raises one column of the envelope, and this
	-- is what proves that raise is a property of the surface and not of where
	-- the mapchunk border happened to fall.
	local cut_spec = {id = "wall_east", axis = "z", at = 256, from = 210,
		to = 261, width = avenue.WIDTH, lamp_spacing = avenue.LAMP_SPACING,
		lamp_phase = 210, reach = avenue.REACH}
	local cut_plan = capital.wall_plan.wall_east
	local cut_surface = wall_surface()
	local whole_wall = palisade.run(orc, cut_spec, cut_surface, cut_plan)
	local whole_index = {}
	for _, cell in ipairs(whole_wall.cells) do
		whole_index[cell.x .. ":" .. cell.y .. ":" .. cell.z] =
			cell.name .. ":" .. (cell.param2 or 0)
	end
	local wall_splits = 0
	for cut = cut_spec.from, cut_spec.to - 1 do
		local left = palisade.run(orc, {id = cut_spec.id, axis = "z", at = 256,
			from = cut_spec.from, to = cut, width = cut_spec.width,
			lamp_spacing = cut_spec.lamp_spacing,
			lamp_phase = cut_spec.lamp_phase, reach = cut_spec.reach},
			cut_surface, cut_plan)
		local right = palisade.run(orc, {id = cut_spec.id, axis = "z", at = 256,
			from = cut + 1, to = cut_spec.to, width = cut_spec.width,
			lamp_spacing = cut_spec.lamp_spacing,
			lamp_phase = cut_spec.lamp_phase, reach = cut_spec.reach},
			cut_surface, cut_plan)
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

	-- (f) NO AVENUE LAMP STANDARD IN A GATE PIER. A lamp stands on the verge,
	-- one node outside the carriageway, and inside a gate that verge is a
	-- column of the gate tower. The passage is seven columns -- the carriageway
	-- plus both verges -- for exactly this reason.
	assert((avenue.WIDTH - 1) / 2 + 1 <= palisade.GATE_PASSAGE,
		"the avenue's verge is outside the gate passage, so a standard " ..
		"stands in a pier")

	say("gor_drazhak_rampart", #capital.wall, wall_columns, wall_cells,
		wall_stakes, wall_steps, wall_treads, wall_passage, wall_splits,
		common.hex(common.new_sha256()(table.concat(wall_digest_rows, "\n"))))

	-- ------------------------------------------------------------------
	-- 5. THE AVENUES, THE RING, THE LANES AND THE CAUSEWAY RAIL
	-- ------------------------------------------------------------------
	local runs = capital.overlay_runs()
	assert(#runs == 20, "the overlay carries " .. #runs .. " runs, not 20")
	do
		-- The order is load bearing: the roads run first and the rampart
		-- yields the cells of the road it lets through its gate.
		for index = 1, 4 do
			assert(runs[index].id:sub(1, 7) == "avenue_",
				"run " .. index .. " is not an avenue")
		end
		for index = 17, 20 do
			assert(runs[index].id:sub(1, 5) == "wall_",
				"run " .. index .. " is not a rampart run")
		end
	end

	-- THE VIADUCT on a profile that falls two nodes per column, which is what
	-- the blend band does and what the pillars and the rail exist for.
	--
	-- This capital used to add a parapet of its own to the piece the road
	-- module returned. Playtest 5 (2026-09-16) ruled that a street raised
	-- artificially may not be a wall at all: it stands on PILLARS with open air
	-- beneath, and its plank walk and rail stand on the two VERGE lanes rather
	-- than on the carriageway's outermost one. The road module does it for every
	-- capital now, so what is checked here is that the orc capital gets it.
	local function ramp_surface(x, z)
		local p = (math.abs(x) > math.abs(z)) and math.abs(x) or math.abs(z)
		if p <= 48 then return 120 end
		if p >= 88 then return 120 - 80 end
		return 120 - 2 * (p - 48)
	end
	local rail_cells, pillar_cells, road_cells, open_columns = 0, 0, 0, 0
	local half = (avenue.WIDTH - 1) / 2
	local verge = half + 1
	local RAIL = orc.node("railing")
	local PILLAR = orc.maybe("signature") or orc.node("wall_accent")
	for _, spec in ipairs({capital.avenues[4], capital.avenues[1]}) do
		local piece = capital.overlay_run(avenue, orc,
			{id = spec.id, axis = spec.axis, at = spec.at, from = spec.from,
				to = spec.to, width = avenue.WIDTH,
				lamp_spacing = avenue.LAMP_SPACING, lamp_phase = spec.from,
				reach = avenue.REACH}, ramp_surface)
		road_cells = road_cells + #piece.cells
		rail_cells = rail_cells + piece.street.rails
		pillar_cells = pillar_cells + piece.street.piers
		-- Every rail and every pillar stands on a VERGE lane, never in the
		-- carriageway, and every raised carriageway column is open at the
		-- ground.
		local index, top_of = {}, {}
		for _, cell in ipairs(piece.cells) do
			index[cell.x .. ":" .. cell.y .. ":" .. cell.z] = true
			local along = (spec.axis == "x") and cell.x or cell.z
			local across = ((spec.axis == "x") and cell.z or cell.x) - spec.at
			if math.abs(across) <= half then
				if top_of[along] == nil or cell.y > top_of[along] then
					top_of[along] = cell.y
				end
			end
			if cell.name == RAIL or cell.name == PILLAR then
				assert(math.abs(across) == verge, "a " .. cell.name ..
					" stands at lane " .. across .. ", not on a verge")
			end
		end
		for p = spec.from, spec.to do
			for lane = -half, half do
				local x, z
				if spec.axis == "x" then x, z = p, spec.at + lane
				else x, z = spec.at + lane, p end
				local ground = ramp_surface(x, z)
				if top_of[p] ~= nil and top_of[p] - ground >= avenue.MIN_CLEAR then
					assert(not index[x .. ":" .. ground .. ":" .. z],
						"the column " .. x .. "," .. z .. " is raised " ..
							(top_of[p] - ground) ..
							" and still filled: a wall, not a viaduct")
					open_columns = open_columns + 1
				end
			end
		end
	end
	assert(rail_cells > 0, "the viaduct rail never fired on a profile that " ..
		"falls two nodes per column")
	assert(pillar_cells > 0, "the viaduct stands on no pillars")
	assert(open_columns > 0, "no column of this profile is a viaduct")
	say("gor_drazhak_avenue", road_cells, rail_cells, pillar_cells,
		open_columns)

	-- ------------------------------------------------------------------
	-- 6. THE WORK SOCKETS AND THEIR FEATURES (sockets contract section 8.1)
	-- ------------------------------------------------------------------
	--
	-- A `work` socket faces the feature its activity works, within three
	-- nodes, and the feature search stops at the first solid node on the
	-- socket's own course, so a feature behind a wall does not count.
	--
	-- THE LIST IS TRANSCRIBED FROM THE CONTRACT'S SECTION 8.1 AND 8.2 TABLES
	-- AND FROM NOTHING ELSE, with the contract's own words over each entry. A
	-- list looser than the contract makes this KAT read stricter than it is,
	-- and that is not hypothetical: with `default:desert_stone_block` in the
	-- `tend` list -- a planter's own stone KERB, which is neither a plant nor a
	-- flower -- all six `tend` sockets passed, and with it gone four of them
	-- faced a kerb that blocked their own course and two faced no plant at all.
	-- `smith` carried a cauldron, `mine` gravel and `pray`/`mourn` plain
	-- cobble on the same terms; nothing relied on those three, which is exactly
	-- why they went unnoticed.
	local FEATURE = {
		-- "an anvil or furnace"
		smith = {"grug_decor:cottages_anvil", "default:furnace"},
		-- "a log or tree"
		chop = {"default:acacia_tree", "default:acacia_leaves"},
		-- "a cauldron, barrel or a cooking pot node"
		brew = {"grug_decor:xdecor_cauldron", "grug_decor:xdecor_barrel",
			"grug_decor:cottages_barrel"},
		-- "a log, a totem/statue part or a stone block"
		carve = {"default:acacia_tree", "default:acacia_wood",
			"default:desert_stone_block", "grug_decor:darkage_adobe",
			"grug_decor:darkage_ors_block", "default:desert_stonebrick"},
		-- "a stone, ore or cobble node at head or chest height"
		mine = {"default:desert_stone_block", "default:desert_stonebrick",
			"default:desert_cobble"},
		-- "a grave marker, a coffin or a candle"
		mourn = {"walls:desertcobble"},
		-- "the chapel's door, an altar, a candle or a grave marker"
		pray = {"walls:desertcobble", "default:torch", "default:torch_wall",
			"doors:door_wood_a", "doors:door_wood_b"},
		-- "a plant or a flower"
		tend = {"default:dry_grass_3", "default:dry_grass_5",
			"default:dry_shrub"},
		-- "a mushroom, a bush, a plant, a vine or leaves"
		forage = {"default:dry_shrub", "default:acacia_leaves",
			"default:dry_grass_3", "default:dry_grass_5"},
		-- "a counter (any solid node at waist height)"
		stall = {"grug_decor:capital_counter", "grug_decor:cottages_table", "stairs:slab_acacia_wood",
			"default:fence_acacia_wood", "grug_decor:cottages_shelf",
			"grug_decor:xdecor_barrel"},
	}
	-- `sit` needs nothing under its dir (it sits on the ground it stands on),
	-- `sweep` moves and needs nothing, and `spar`'s feature is its partner.
	local NO_FEATURE = {sit = true, sweep = true}

	local function feature_check(label, blueprint, sockets)
		local index = {}
		for _, cell in ipairs(blueprint.cells) do
			index[cell.x .. ":" .. cell.y .. ":" .. cell.z] = cell.name
		end
		local spar = {}
		for _, entry in ipairs(sockets) do
			if entry.role == "work" and entry.activity == "spar" then
				spar[entry.x .. ":" .. entry.z] = true
			end
		end
		local checked = 0
		for _, entry in ipairs(sockets) do
			if entry.role == "work" and not NO_FEATURE[entry.activity] then
				local wanted = FEATURE[entry.activity]
				local found = false
				for step = 1, 3 do
					local x = entry.x + entry.dir.x * step
					local z = entry.z + entry.dir.z * step
					if entry.activity == "spar" and spar[x .. ":" .. z] then
						found = true
						break
					end
					for _, level in ipairs({entry.y, entry.y + 1,
							entry.y - 1}) do
						local name = index[x .. ":" .. level .. ":" .. z]
						for _, want in ipairs(wanted or {}) do
							if name == want then found = true end
						end
					end
					if found then break end
					-- The search stops at the first solid node on the socket's
					-- own course: a feature behind a wall does not count.
					local here = index[x .. ":" .. entry.y .. ":" .. z]
					if here ~= nil and here ~= "air" and
							registry.is_opaque_full(world, here) then
						break
					end
				end
				assert(found, label .. ": the work socket " .. entry.id ..
					" (" .. entry.activity .. ") faces no feature within " ..
					"three nodes")
				checked = checked + 1
			end
		end
		return checked
	end

	local features = feature_check("core", core, core_view.sockets)
	for index = 1, #plots do
		features = features + feature_check("plot " .. plots[index].id,
			built[index], built[index].landmarks.sockets)
	end
	say("gor_drazhak_work", work_count, features, #activity_names)

	-- ------------------------------------------------------------------
	-- 7. THE QUADRANTS
	-- ------------------------------------------------------------------
	--
	-- One authored grid turned four times, with the measured repairs applied.
	-- The lots are held to their own quarter and off every street run, which is
	-- what makes any district able to stand in any quadrant.
	local ENVELOPE, CORE_CLEAR, GATE_CORRIDOR = 250, 48, 16
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
	for _, list in ipairs({capital.avenues, capital.ring, capital.lanes}) do
		for index = 1, #list do
			add_run(list[index], (avenue.WIDTH - 1) / 2 + 1)
		end
	end
	for index = 1, #capital.wall do
		add_run(capital.wall[index], palisade.HALF)
	end
	local function overlaps(a1, a2, b1, b2) return a1 <= b2 and b1 <= a2 end

	local SIGN = {southeast = {1, -1}, northeast = {1, 1},
		northwest = {-1, 1}, southwest = {-1, -1}}
	local lot_count = 0
	for _, name in ipairs(quadrants.QUADRANTS) do
		local sign = SIGN[name]
		local boxes = {}
		for _, lot in ipairs(quadrants.LOTS[name]) do
			boxes[#boxes + 1] = {x = lot.x, z = lot.z,
				reach = quadrants.LOT.reach, lane = quadrants.LOT.lane}
		end
		for _, lot in ipairs(quadrants.FILL_LOTS[name]) do
			boxes[#boxes + 1] = {x = lot.x, z = lot.z, reach = lot.reach,
				lane = quadrants.FILL.lane}
		end
		assert(#boxes == 13, name .. " carries " .. #boxes .. " lots")
		for index = 1, #boxes do
			local box = boxes[index]
			lot_count = lot_count + 1
			local min_x, max_x = box.x - box.reach - 2, box.x + box.reach + 2
			local min_z, max_z = box.z - box.reach - 2, box.z + box.reach + 2
			assert(min_x >= -ENVELOPE and max_x <= ENVELOPE and
					min_z >= -ENVELOPE and max_z <= ENVELOPE,
				name .. " lot " .. index .. " leaves the envelope")
			assert(not (overlaps(min_x, max_x, -CORE_CLEAR, CORE_CLEAR) and
					overlaps(min_z, max_z, -CORE_CLEAR, CORE_CLEAR)),
				name .. " lot " .. index .. " stands on the core")
			assert(not overlaps(min_z, max_z, -GATE_CORRIDOR, GATE_CORRIDOR),
				name .. " lot " .. index .. " stands in a gate corridor")
			assert(not overlaps(min_x, max_x, -GATE_CORRIDOR, GATE_CORRIDOR),
				name .. " lot " .. index .. " stands in a gate corridor")
			assert(sign[1] * box.x > 0 and sign[2] * box.z > 0,
				name .. " lot " .. index .. " is not in its own quarter")
			for _, run in ipairs(street_runs) do
				assert(not (overlaps(min_x, max_x, run.min_x, run.max_x) and
						overlaps(min_z, max_z, run.min_z, run.max_z)),
					name .. " lot " .. index .. " stands on " .. run.id)
			end
			for other = 1, #boxes do
				if other ~= index then
					local peer = boxes[other]
					local gap = box.reach + peer.reach +
						math.min(box.lane, peer.lane)
					assert(math.abs(box.x - peer.x) >= gap or
							math.abs(box.z - peer.z) >= gap,
						name .. " lots " .. index .. " and " .. other ..
							" stand less than a lane apart")
				end
			end
		end
	end
	assert(lot_count == 52, "the four quarters carry " .. lot_count .. " lots")

	-- The permutation is a bijection for every seed the fixture set carries,
	-- and the canonical assignment is the identity.
	local seeds = {"531802985935182545", "8675309", "15912857179583385436",
		"0", "1", "2", "42", "12345", "999999999"}
	local sha = common.new_sha256()
	local seen_permutation = {}
	for _, seed in ipairs(seeds) do
		local permutation = quadrants.permutation(seed, sha)
		quadrants.check_permutation(permutation)
		seen_permutation[table.concat(permutation, "")] = true
	end
	local distinct = 0
	for _ in pairs(seen_permutation) do distinct = distinct + 1 end
	assert(distinct >= 2, "the quadrant hash gives every seed the same city")
	for index = 1, 4 do
		assert(quadrants.canonical()[index] == index,
			"the canonical assignment is not the authored order")
	end
	-- The repairs name real lots and really moved them off the turn.
	local moved = 0
	for _, row in ipairs(quadrants.LOT_REPAIRS) do
		local turned_x, turned_z = quadrants.rotate(
			quadrants.AUTHORED[row[2]].x, quadrants.AUTHORED[row[2]].z,
			(function()
				for index = 1, #quadrants.QUADRANTS do
					if quadrants.QUADRANTS[index] == row[1] then
						return index - 1
					end
				end
			end)())
		assert(turned_x ~= row[3] or turned_z ~= row[4],
			"the repair of " .. row[1] .. " lot " .. row[2] ..
				" moves nothing")
		moved = moved + 1
	end
	say("gor_drazhak_quadrants", lot_count, #quadrants.LOT_REPAIRS,
		#quadrants.FILL_REPAIRS, moved, distinct,
		table.concat(quadrants.permutation(seeds[1], sha), ""))

	return table.concat(report)
end
