-- Habitat-driven wild vegetation renewal (farming.md "Wild plant renewal").
--
-- Plants come back from their habitat, never from a record of where plants
-- used to be: around each connected player, a fixed number of random spots
-- per step is tested against the natural density the world generator would
-- produce there (vegetation_density.lua, the shared habitat authority). A
-- spot below that density gets a plant with a chance that rises with the
-- local deficit; a spot at or above it gets nothing. Trees return as
-- saplings of the local species and grow through their own node timers.
-- There is no persistent state, no generation callback, no LBM and no ABM.
--
-- `api` injects every engine and authority access, so the same bytes run in
-- the engine (init.lua wires `core`) and in the portable fixture:
--   get_node_or_nil(pos), set_node(pos, node), get_natural_light(pos, tod),
--   find_nodes_in_area(minp, maxp, names[, grouped]),
--   find_nodes_in_area_under_air(minp, maxp, names), get_item_group(name, group)
--   density     the vegetation authority (grug_mapgen.wp40.vegetation)
--   planner     the planner column source (grug_mapgen.wp40.planner_source)
--   natural_ground_alterable(pos)  grug_core's rule for natural change: the
--               territory rule plus the natural renewal guards (nothing
--               regrows inside an active Claim Stone's claim)
--   random()    uniform [0, 1); trees  bool (setting grug_tree_regrowth)
--   non_natural array of node names that are not natural (sapling guard)
return function(api)
	local R = {
		-- Pacing: every connected player is serviced once per STEP_SECONDS,
		-- spread over TICK_SECONDS globalstep slices.
		STEP_SECONDS = 5,
		TICK_SECONDS = 0.5,
		-- Random spots tested per player and step.
		SAMPLES_PER_PLAYER = 4,
		-- A spot is at least this far (3-D) from every connected player, and
		-- at most MAX_SAMPLE_DISTANCE horizontally from the sampling player.
		MIN_PLAYER_DISTANCE = 20,
		MAX_SAMPLE_DISTANCE = 48,
		-- Vertical search for open ground in the sampled column: around the
		-- player's y (caves included), else around the planned terrain surface
		-- when that lies within MAX_TERRAIN_OFFSET of the player.
		SPOT_HALF_HEIGHT = 24,
		TERRAIN_HALF_HEIGHT = 8,
		MAX_TERRAIN_OFFSET = 64,
		-- Counting box around a spot: its radius makes the natural count at
		-- least BOX_TARGET plants where the clamp allows; BOX_HALF_HEIGHT is its
		-- vertical half-size. Woody plants are counted by their trunks from
		-- WOODY_DOWN below to WOODY_UP above the spot.
		BOX_MIN_RADIUS = 4,
		BOX_MAX_RADIUS = 24,
		BOX_TARGET = 1.5,
		BOX_HALF_HEIGHT = 4,
		WOODY_DOWN = 4,
		WOODY_UP = 12,
		-- Shoreline species: eligible supports per box width (a band along the
		-- water line crossing the box), since only shore columns host them.
		SHORE_BAND = 2,
		-- Placement chance at a full deficit, per class; it scales with the
		-- deficit fraction (target - present) / target.
		CHANCE = {resource = 0.05, cover = 0.5, tree = 0.1, shrub = 0.1},
		-- No sapling within this radius of any non-natural node or farm soil.
		SAPLING_GUARD_RADIUS = 10,
		-- Area-query node visits allowed per player and step (spot search,
		-- counting boxes and sapling guard); a sample that would exceed it is
		-- skipped.
		VOLUME_BUDGET = 150000,
	}
	-- Trees and shrubs are separate classes, each counted against its own
	-- natural density (Round 23 Phase 2); both return as saplings.
	local CLASS_ORDER = {"resource", "cover", "tree", "shrub"}
	local WOODY = {tree = true, shrub = true}

	local density, planner = api.density, api.planner
	local random = api.random
	local floor, sqrt, cos, sin, max, min = math.floor, math.sqrt, math.cos,
		math.sin, math.max, math.min
	local stats = {}
	local function count(reason) stats[reason] = (stats[reason] or 0) + 1 end

	local key_hashes = {}
	local function key_hash(key)
		local value = key_hashes[key]
		if not value then
			value = 7
			for index = 1, #key do value = (value * 131 + key:byte(index)) % 1000003 end
			key_hashes[key] = value
		end
		return value
	end
	-- A fixed per-patch fraction in [0, 1): turns a fractional expected count
	-- into the patch's integer natural count without state, so a sparse
	-- species fills sparse patches as often as the generator does.
	local function patch_fraction(key, x, z, width)
		local cx, cz = floor(x / width), floor(z / width)
		local value = (cx * 92821 + cz * 68917 + key_hash(key) * 31337) % 1000003
		value = (value * 7919 + 104729) % 1000003
		return value / 1000003
	end

	local function radius_for(p)
		local radius = math.ceil(sqrt(R.BOX_TARGET / p) / 2)
		return max(R.BOX_MIN_RADIUS, min(R.BOX_MAX_RADIUS, radius))
	end

	local function volume(minp, maxp)
		return (maxp.x - minp.x + 1) * (maxp.y - minp.y + 1) * (maxp.z - minp.z + 1)
	end

	-- Present plants of a category in its counting box.
	local function present(category, pos, radius)
		if not WOODY[category.class] then
			local minp = {x = pos.x - radius, y = pos.y - R.BOX_HALF_HEIGHT,
				z = pos.z - radius}
			local maxp = {x = pos.x + radius, y = pos.y + R.BOX_HALF_HEIGHT,
				z = pos.z + radius}
			return #api.find_nodes_in_area(minp, maxp, category.names), volume(minp, maxp)
		end
		local minp = {x = pos.x - radius, y = pos.y - R.WOODY_DOWN, z = pos.z - radius}
		local maxp = {x = pos.x + radius, y = pos.y + R.WOODY_UP, z = pos.z + radius}
		local grouped = api.find_nodes_in_area(minp, maxp, category.names, true)
		local plants = 0
		local names = {}
		for name in pairs(grouped) do names[#names + 1] = name end
		table.sort(names)
		for n = 1, #names do
			local name = names[n]
			local seen, columns = {}, 0
			local list = grouped[name]
			for index = 1, #list do
				local key = list[index].x * 65536 + list[index].z
				if not seen[key] then seen[key], columns = true, columns + 1 end
			end
			plants = plants + columns / (category.divisor[name] or 1)
		end
		return plants, volume(minp, maxp)
	end

	-- Eligible supports (open host ground) in the counting box.
	local function eligible(category, pos, radius)
		local minp = {x = pos.x - radius, y = pos.y - 1 - R.BOX_HALF_HEIGHT,
			z = pos.z - radius}
		local maxp = {x = pos.x + radius, y = pos.y - 1 + R.BOX_HALF_HEIGHT,
			z = pos.z + radius}
		-- The engine also reads the layer above maxp.
		return #api.find_nodes_in_area_under_air(minp, maxp, category.hosts),
			volume(minp, {x = maxp.x, y = maxp.y + 1, z = maxp.z})
	end

	local function pick_species(category)
		local species = category.species
		if #species == 1 then return species[1] end
		local total = 0
		for index = 1, #species do total = total + species[index].weight end
		local roll = random() * total
		for index = 1, #species do
			roll = roll - species[index].weight
			if roll < 0 then return species[index] end
		end
		return species[#species]
	end

	local function choose_category(categories, only_class)
		local by_class, classes = {}, {}
		for index = 1, #categories do
			local category = categories[index]
			if (not WOODY[category.class] or api.trees) and
					(only_class == nil or category.class == only_class) then
				local list = by_class[category.class]
				if not list then
					list = {}
					by_class[category.class] = list
				end
				list[#list + 1] = category
			end
		end
		for index = 1, #CLASS_ORDER do
			if by_class[CLASS_ORDER[index]] then
				classes[#classes + 1] = by_class[CLASS_ORDER[index]]
			end
		end
		if #classes == 0 then return nil end
		local list = classes[floor(random() * #classes) + 1]
		return list[floor(random() * #list) + 1]
	end

	local function far_from_players(pos, positions)
		local limit = R.MIN_PLAYER_DISTANCE * R.MIN_PLAYER_DISTANCE
		for index = 1, #positions do
			local other = positions[index]
			local dx, dy, dz = pos.x - other.x, pos.y - other.y, pos.z - other.z
			if dx * dx + dy * dy + dz * dz < limit then return false end
		end
		return true
	end

	-- Mutation permission: protected territory (towns, landmarks, immutable
	-- ground) and hard rows never grow renewed plants. The writers' claim
	-- exclusions (settlements, POIs, roads, water; per plant class) and the
	-- ground they keep bare are the habitat's answer (vegetation_density.lua).
	-- An active Claim Stone's claim refuses through natural_ground_alterable
	-- (Round 25 ruling 14); an expired claim renews like any other ground
	-- (ruling 19).
	local function permitted(pos, support_pos)
		if planner.hard_row_at(pos.x, pos.y, pos.z) ~= nil or
				planner.hard_row_at(support_pos.x, support_pos.y, support_pos.z) ~= nil then
			return false, "hard_row"
		end
		if not api.natural_ground_alterable(pos) or
				not api.natural_ground_alterable(support_pos) then
			return false, "protected"
		end
		return true
	end

	-- Test one open support and maybe place a plant above it. `budget` holds
	-- the player's remaining node-visit allowance for this step. Fixtures may
	-- force the roll and restrict the class; the service passes neither.
	-- Returns a reason ("placed" plus the node name and position on success).
	local function evaluate(support_pos, positions, budget, forced_roll, only_class)
		local pos = {x = support_pos.x, y = support_pos.y + 1, z = support_pos.z}
		if not far_from_players(pos, positions) then return "near_player" end
		local node = api.get_node_or_nil(pos)
		if not node then return "unloaded" end
		if node.name ~= "air" then return "occupied" end
		local support = api.get_node_or_nil(support_pos)
		if not support then return "unloaded" end
		if api.get_item_group(support.name, "grug_crop_soil") > 0 then return "farm_soil" end
		local allowed, why = permitted(pos, support_pos)
		if not allowed then return why end
		local categories, reason = density.categories(pos.x, pos.y, pos.z,
			support.name, api.get_natural_light(pos, 0.5) or 0)
		if not categories then return reason end
		local category = choose_category(categories, only_class)
		if not category then return "no_habitat" end
		local radius = radius_for(category.p)
		local cost = (2 * radius + 1) * (2 * radius + 1) * (2 * R.BOX_HALF_HEIGHT + 2) +
			(2 * radius + 1) * (2 * radius + 1) *
				(WOODY[category.class] and (R.WOODY_DOWN + R.WOODY_UP + 1) or
					(2 * R.BOX_HALF_HEIGHT + 1))
		if WOODY[category.class] then
			local side = 2 * R.SAPLING_GUARD_RADIUS + 1
			cost = cost + side * side * side
		end
		if cost > budget.left then return "budget" end
		local plants, used = present(category, pos, radius)
		budget.left = budget.left - used
		local open, used_open = eligible(category, pos, radius)
		budget.left = budget.left - used_open
		local supports = open + plants
		if category.shore then
			supports = min(supports, R.SHORE_BAND * (2 * radius + 1))
		end
		local expected = category.p * supports
		local target = floor(expected)
		if patch_fraction(category.key, pos.x, pos.z, 2 * radius + 1) <
				expected - target then
			target = target + 1
		end
		if plants >= target then return "at_target" end
		local chance = R.CHANCE[category.class] * (target - plants) / target
		local roll = forced_roll or random()
		if roll >= chance then return "roll" end
		local species = pick_species(category)
		if WOODY[category.class] then
			if api.get_item_group(support.name, "soil") == 0 then return "no_soil" end
			local g = R.SAPLING_GUARD_RADIUS
			local minp = {x = pos.x - g, y = pos.y - g, z = pos.z - g}
			local maxp = {x = pos.x + g, y = pos.y + g, z = pos.z + g}
			budget.left = budget.left - volume(minp, maxp)
			if #api.find_nodes_in_area(minp, maxp, api.non_natural) > 0 then
				return "guard"
			end
		end
		api.set_node(pos, {name = species.node, param2 = species.param2})
		return "placed", species.node, pos
	end

	-- A random open support in the ring around one player, or nil.
	local function sample_spot(origin, budget)
		local angle = random() * 2 * math.pi
		local inner, outer = R.MIN_PLAYER_DISTANCE, R.MAX_SAMPLE_DISTANCE
		local distance = sqrt(inner * inner + random() * (outer * outer - inner * inner))
		local x = floor(origin.x + cos(angle) * distance + 0.5)
		local z = floor(origin.z + sin(angle) * distance + 0.5)
		local y = floor(origin.y + 0.5)
		local names = density.support_names()
		local found = api.find_nodes_in_area_under_air(
			{x = x, y = y - R.SPOT_HALF_HEIGHT, z = z},
			{x = x, y = y + R.SPOT_HALF_HEIGHT, z = z}, names)
		budget.left = budget.left - (2 * R.SPOT_HALF_HEIGHT + 2)
		if #found == 0 then
			local _, _, _, _, _, terrain_y = planner.column_values_at(x, z)
			if type(terrain_y) == "number" and
					math.abs(terrain_y - y) <= R.MAX_TERRAIN_OFFSET and
					math.abs(terrain_y - y) > R.SPOT_HALF_HEIGHT then
				found = api.find_nodes_in_area_under_air(
					{x = x, y = terrain_y - R.TERRAIN_HALF_HEIGHT, z = z},
					{x = x, y = terrain_y + R.TERRAIN_HALF_HEIGHT, z = z}, names)
				budget.left = budget.left - (2 * R.TERRAIN_HALF_HEIGHT + 2)
			end
		end
		if #found == 0 then return nil end
		return found[floor(random() * #found) + 1]
	end

	-- Service one player: SAMPLES_PER_PLAYER spots within VOLUME_BUDGET.
	local function service(origin, positions)
		local budget = {left = R.VOLUME_BUDGET}
		local placed = 0
		for _ = 1, R.SAMPLES_PER_PLAYER do
			if budget.left <= 0 then
				count("budget")
				break
			end
			local spot = sample_spot(origin, budget)
			if not spot then
				count("no_ground")
			else
				local result = evaluate(spot, positions, budget)
				count(result)
				if result == "placed" then placed = placed + 1 end
			end
		end
		stats.visits = (stats.visits or 0) + (R.VOLUME_BUDGET - budget.left)
		return placed, R.VOLUME_BUDGET - budget.left
	end

	local module = {constants = R}
	module.evaluate = evaluate
	module.sample_spot = sample_spot
	module.service = service
	function module.stats() return stats end
	function module.non_natural_count() return #api.non_natural end
	function module.reset_stats() stats = {} end

	-- Pacing: the caller's globalstep accumulates TICK_SECONDS and passes the
	-- elapsed time; every player is serviced once per STEP_SECONDS, spread
	-- round-robin over the ticks. Returns the number serviced.
	local credit, cursor = 0, 1
	function module.tick(elapsed, players)
		local total = #players
		if total == 0 then
			credit = 0
			return 0
		end
		credit = min(total, credit + total * elapsed / R.STEP_SECONDS)
		local serviced = floor(credit)
		if serviced == 0 then return 0 end
		credit = credit - serviced
		local positions = {}
		for index = 1, total do positions[index] = players[index]:get_pos() end
		if cursor > total then cursor = 1 end
		for step = 0, serviced - 1 do
			service(positions[((cursor + step - 1) % total) + 1], positions)
		end
		cursor = ((cursor + serviced - 1) % total) + 1
		return serviced
	end
	return module
end
