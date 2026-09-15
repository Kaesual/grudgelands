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
	local highcourt = dofile(wp13 .. "/highcourt.lua")(wp13)
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

	-- The human palette's own vocabulary, plus the two families the
	-- composition overrides into it. Used for the walk and the light rules.
	local human = palettes.new("human")
	local LIGHT = {}
	for _, role in ipairs({"light_wall", "light_post", "light_indoor"}) do
		LIGHT[human.node(role)] = true
	end
	-- What a lamp standard may NOT stand on. The road writes none of these, so
	-- the set is the engine's water families rather than a palette role.
	local LIQUID = {["default:water_source"] = true,
		["default:water_flowing"] = true,
		["default:river_water_source"] = true,
		["default:river_water_flowing"] = true}
	local LEAF = {}
	for _, name in ipairs(human.names("door")) do LEAF[name] = true end
	local HIDDEN = human.node("door_hidden")
	local THRONE = human.maybe("throne")

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
			PAVED[human.node(role)] = true
		end
		PAVED[human.node("castle_paving")] = true
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
			if entry.role == "vendor" then
				assert(entry.kind == "race" or entry.kind == "general",
					label .. ": vendor " .. entry.id .. " names no family")
			else
				assert(entry.kind == nil, label .. ": socket " .. entry.id ..
					" carries a vendor family but is no vendor")
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
			sockets = #sockets, spare = spare_count,
			reachable = #queue, panes = panes,
			attached = attached, torches = torches, oriented = oriented,
			loop = loop_length, node = node, at = at, stand = stand,
			index = index}
	end

	-- ------------------------------------------------------------------
	-- 1. the core
	-- ------------------------------------------------------------------
	local core = highcourt.core()
	local CORE = {
		reach = 47, ymin = -2, ymax = 40, budget = 150000,
		min_lights = 40, min_doors = 12, loops = 5,
		-- The four gatehouses' chamber floors (90 cells at y = 6) and their
		-- fighting decks (220 at y = 11). Nothing else in the core is a
		-- floor over air.
		raised = 298, whole_loop = true,
		-- The capital's socket roster, exactly. The three singular roles are
		-- the reason the composition owns a socket policy at all: one
		-- throne, one travel pad for WP17, two vendor families.
		-- 10 waypoints in the city's own loop and 8 in the four gate
		-- towers' own two-waypoint watches.
		-- 30 idle spots the city's citizens live on plus the 10 SPARES of
		-- playtest round 2, which nobody is placed on and every core citizen
		-- may wander to.
		roles = {king = 1, waypoint = 1, quest = 1, vendor = 2,
			guard_post = 12, guard_patrol = 18, idle = 40},
		spare = 10,
	}
	local core_result = check_composition("highcourt core", core, CORE)

	-- The core is FLAT: y = 0 is its ground course everywhere it builds, and
	-- only foundations reach below it (contract section 2.1).
	local FOOTING = {}
	for _, role in ipairs({"foundation", "subsoil"}) do
		FOOTING[human.node(role)] = true
	end
	FOOTING[human.node("castle_wall")] = true
	FOOTING[human.node("signature")] = true
	FOOTING["grug_decor:darkage_marble"] = true
	local footings, ground_cells = 0, 0
	for _, cell in ipairs(core.cells) do
		if cell.y < 0 then
			assert(FOOTING[cell.name], "highcourt core: " .. cell.name ..
				" is buried at y " .. cell.y .. "; only footings go below " ..
				"the flat ground course")
			footings = footings + 1
		elseif cell.y == 0 then
			ground_cells = ground_cells + 1
		end
	end
	assert(ground_cells >= 95 * 95 - 200, "highcourt core: the ground " ..
		"course has " .. ground_cells .. " cells, so the core is not flat " ..
		"ground from edge to edge")

	-- The authored populations, exactly. The floor the composition lays
	-- inside the king's hall, the fruit trees it plants and the hedge it
	-- walks round the pad are all placed by rules that can silently plant
	-- nothing -- a band that finds no paving, a corner with no open ground
	-- -- and the number is what says they did not. Dawnmere lost 22 of 27
	-- props to exactly that shape of code.
	for _, row in ipairs({{"nave_floor", 90}, {"orchard_trees", 11},
			{"hedge_cells", 197}}) do
		assert(core.landmarks[row[1]] == row[2], "the core's " .. row[1] ..
			" population is " .. tostring(core.landmarks[row[1]]) ..
			", not " .. row[2])
	end

	-- The four gate openings and their avenues: five wide, walkable end to
	-- end, and each one really reaching its gate at the core edge.
	local RADIUS = 47
	for _, gate in ipairs({"south", "north", "east", "west"}) do
		local box = assert(core.landmarks["avenue_" .. gate],
			"highcourt core has no avenue_" .. gate)
		local edge = assert(core.landmarks["gate_" .. gate],
			"highcourt core has no gate_" .. gate)
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
	assert(king, "highcourt core publishes no king socket")
	assert(THRONE, "the human palette binds no throne")
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
	say("highcourt_throne", throne_cell.param2, king.face,
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
	local again = highcourt.core()
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

	say("highcourt_core", core.schema, core_result.cells, core_result.solids,
		core_result.palette, core_result.lights, core_result.doors,
		core_result.rooms, core_result.sockets, core_result.spare,
		core_result.loop, core_result.reachable, footings, ground_cells)

	-- ------------------------------------------------------------------
	-- 2. the district plots
	-- ------------------------------------------------------------------
	local PLOT = {
		reach = 15, ymin = -6, ymax = 24, budget = 12000,
		min_lights = 2, min_doors = 0, loops = 1, raised = 0,
	}
	local district = highcourt.district
	assert(district.role == "market_professions",
		"the pilot district is not the market and professions one")
	assert(#district.plots >= 8, "the district has " .. #district.plots ..
		" plots")
	local district_cells, district_loop = 0, {}
	local taken = {}
	for _, entry in ipairs(district.plots) do
		local plot = entry.build()
		local spec = {}
		for key, value in pairs(PLOT) do spec[key] = value end
		-- Every plot publishes the roles its own part publishes, so the
		-- multiset is read off the plot and only its SHAPE is asserted:
		-- at least one flair spot, and no role the contract does not name.
		spec.roles = {}
		for _, socket in ipairs(plot.landmarks.sockets) do
			spec.roles[socket.role] = (spec.roles[socket.role] or 0) + 1
		end
		for role in pairs(spec.roles) do
			assert(role == "guard_post" or role == "guard_patrol" or
				role == "idle" or role == "quest" or role == "vendor",
				entry.id .. " publishes the role " .. role ..
					", which no district plot may own")
		end
		assert((spec.roles.idle or 0) >= 1,
			entry.id .. " publishes no flair spot")
		local result = check_composition("plot " .. entry.id, plot, spec)
		district_cells = district_cells + result.cells

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
				-- Up to the plot's own roof and two courses over it, which
				-- is what the composition clears: checking four courses
				-- would leave the whole upper half of a plot unasserted,
				-- and a terrace shoulder stands wherever the terrain does.
				for y = 1, box.max.y + 2 do
					assert(result.at(x, y, z) ~= nil, entry.id ..
						": the airspace at " .. x .. "," .. y .. "," .. z ..
						" was never cleared, so a terrace shoulder stays " ..
						"in the plot")
				end
				cleared = cleared + 1
			end
		end
		assert(skirted > 0 and cleared > 0, entry.id .. " has no plot box")

		-- The plot's own offset from the capital anchor keeps it clear of
		-- the avenue and of every other plot: two plots that overlap in the
		-- envelope are two plots the writer projects into each other.
		-- No plot may share a column with another plot or with a STREET.
		-- The streets are the runs the overlay will pave -- the four gate
		-- avenues and the four sides of the ring -- and each is five wide,
		-- so the rule is read off the same specs the overlay is given
		-- rather than approximated by the square around the anchor, which
		-- is what let a plot sit on the ring street.
		local STREET_HALF = math.floor(avenue.WIDTH / 2)
		local function on_a_street(x, z)
			local runs = {}
			for _, spec in ipairs(highcourt.avenues) do
				runs[#runs + 1] = spec
			end
			for _, spec in ipairs(highcourt.ring) do
				runs[#runs + 1] = spec
			end
			for _, spec in ipairs(runs) do
				local along = (spec.axis == "x") and x or z
				local across = (spec.axis == "x") and z or x
				if along >= spec.from - STREET_HALF and
						along <= spec.to + STREET_HALF and
						math.abs(across - spec.at) <= STREET_HALF then
					return spec.id
				end
			end
			return nil
		end
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
		-- and no plot reaches into the 32-node gate corridor WP40 keeps
		-- clear on each axis (`capital_gate_width`), which nothing else in
		-- the tree enforces.
		for _, spec in ipairs(highcourt.avenues) do
			local along_min = (spec.axis == "x") and
				(entry.x + plot.bounds.min.x) or (entry.z + plot.bounds.min.z)
			local along_max = (spec.axis == "x") and
				(entry.x + plot.bounds.max.x) or (entry.z + plot.bounds.max.z)
			local across_min = (spec.axis == "x") and
				(entry.z + plot.bounds.min.z) or (entry.x + plot.bounds.min.x)
			local across_max = (spec.axis == "x") and
				(entry.z + plot.bounds.max.z) or (entry.x + plot.bounds.max.x)
			local inside = (along_max >= math.min(spec.from, spec.to)) and
				(along_min <= math.max(spec.from, spec.to))
			if inside then
				assert(across_min > spec.at + 16 or across_max < spec.at - 16,
					entry.id .. " reaches into the 32-node gate corridor of " ..
						spec.id)
			end
		end

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
		end

		say("highcourt_plot", entry.id, entry.x, entry.z, result.cells,
			result.solids, result.palette, result.lights, result.doors,
			result.rooms, result.sockets, result.reachable)
	end
	-- The district's loop is one walk, 1..n, across all its plots.
	local district_length = 0
	for _ in pairs(district_loop) do district_length = district_length + 1 end
	for order = 1, district_length do
		assert(district_loop[order],
			"the district patrol loop has no waypoint at order " .. order)
	end
	assert(district_length >= 8, "the district patrol loop is " ..
		district_length .. " waypoints long")
	assert(district_cells <= 12000 * #district.plots,
		"the district is over its plot budget")
	say("highcourt_district", district.key, #district.plots, district_cells,
		district_length)

	-- ------------------------------------------------------------------
	-- 3. the avenue overlay
	-- ------------------------------------------------------------------
	--
	-- The overlay has no cells of its own until a surface is handed to it, so
	-- it is checked as a function: over profiles worse than the human
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

	-- (a) The pilot profile: a flat approach, a two-node rise (the human
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
	local run = avenue.run(human, avenue_spec, counted_surface)

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
		assert(shaft and shaft.name == human.node("post"),
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
	local twin = avenue.run(human, avenue_spec, surface)
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
			return avenue.run(human, {id = profile.name, axis = "x", at = 0,
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
	for _, spec in ipairs(highcourt.avenues) do
		assert(math.abs(spec.from) == 256 or math.abs(spec.to) == 256,
			"the avenue " .. spec.id .. " does not reach its gate station")
		assert(math.abs(spec.from) >= 48 and math.abs(spec.to) >= 48,
			"the avenue " .. spec.id .. " starts inside the core")
		local ride = avenue.run(human, {id = spec.id, axis = spec.axis,
			at = spec.at, from = spec.from, to = spec.from + 16}, surface)
		assert(#ride.cells > 0, "the avenue " .. spec.id .. " writes nothing")
		runs = runs + 1
	end
	local ring = {}
	for _, spec in ipairs(highcourt.ring) do
		ring[spec.id] = spec
		local ride = avenue.run(human, {id = spec.id, axis = spec.axis,
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

	say("highcourt_avenue", #run.cells, run.pavement, run.treads, run.risers,
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
	for _, spec in ipairs({highcourt.avenues[4], highcourt.avenues[2]}) do
		local built = avenue.run(human, {id = spec.id, axis = spec.axis,
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
	say("highcourt_avenue_built", digest_runs,
		common.hex(common.new_sha256()(table.concat(digest_rows, "\n"))))

	return table.concat(report)
end
