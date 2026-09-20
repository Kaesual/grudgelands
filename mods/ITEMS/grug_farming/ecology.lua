-- Exact-baseline, bounded renewal for generated natural plants.
return function()
	local CELL, PASS_SECONDS = 64, 10
	local MAX_CELLS, MAX_READS, MAX_PLACEMENTS = 8, 64, 2
	local FIRST_MIN, FIRST_SPAN = 14400, 14400
	local RETRY_MIN, RETRY_SPAN = 1800, 1800
	local PLAYER_MARK = "grug_player_placed_plant"
	local storage = core.get_mod_storage()
	local state = core.deserialize(storage:get_string("ecology_v1"))
	if type(state) ~= "table" or state.schema ~= "grug_farming_ecology_v1" or
			type(state.cells) ~= "table" then
		state = {schema = "grug_farming_ecology_v1", cells = {}}
	end
	local sources, source_names = {}, {}
	local ready, elapsed, cell_cursor = false, 0, 1

	local function save()
		storage:set_string("ecology_v1", core.serialize(state))
	end

	local function pos_key(pos)
		return pos.x .. "," .. pos.y .. "," .. pos.z
	end

	local function cell_key(species, pos)
		return species .. "|" .. math.floor(pos.x / CELL) .. "|" ..
			math.floor(pos.z / CELL)
	end

	local function random_delay(minimum, span)
		return minimum + math.random(0, span)
	end

	local function count_positions(cell)
		local count = 0
		for _ in pairs(cell.positions) do count = count + 1 end
		return count
	end

	local function observe(pos, name)
		local source = sources[name]
		if not source or core.get_meta(pos):get_int(PLAYER_MARK) == 1 then return false end
		local mapgen = rawget(_G, "grug_mapgen")
		local query = mapgen and mapgen.wp40 and mapgen.wp40.ecology_at
		if type(query) ~= "function" then return false end
		local _, _, _, static, housing, functional, hard =
			query(pos.x, pos.y, pos.z)
		if static or housing or functional or hard then return false end
		local key = cell_key(source.species, pos)
		local cell = state.cells[key]
		if not cell then
			cell = {species = source.species, positions = {}, debt = 0, due = 0,
				cursor = 1}
			state.cells[key] = cell
		end
		local key_at = pos_key(pos)
		if cell.positions[key_at] then return false end
		local below = core.get_node({x = pos.x, y = pos.y - 1, z = pos.z})
		cell.positions[key_at] = {x = pos.x, y = pos.y, z = pos.z,
			name = name, present = true, support = below.name,
			support_param2 = below.param2 or 0}
		return true
	end

	local function deplete(pos, name)
		local source = sources[name]
		if not source then return end
		local cell = state.cells[cell_key(source.species, pos)]
		local row = cell and cell.positions[pos_key(pos)] or nil
		if not row or not row.present then return end
		row.present = false
		cell.debt = math.min(cell.debt + 1, count_positions(cell))
		if cell.due == 0 then
			cell.due = os.time() + random_delay(FIRST_MIN, FIRST_SPAN)
		end
		save()
	end

	local function set(values)
		local result = {}
		for index = 1, #(values or {}) do result[values[index]] = true end
		return result
	end

	local function add_source(name, species, row, kind)
		if sources[name] then error("grug_farming: duplicate ecology source " .. name, 0) end
		local source = {name = name, species = species, row = row, kind = kind,
			zones = set(row.zones), hosts = {}}
		if kind == "world" then
			for biome, values in pairs(row.hosts) do
				source.hosts[biome == "any" and "*" or biome] = set(values)
			end
		elseif kind == "p9g" then
			for index = 1, #row.hosts do
				local host = row.hosts[index]
				local biome = source.hosts[host.biome] or {}
				local support = biome[host.support] or {}
				support[host.zone or "*"] = true
				biome[host.support] = support
				source.hosts[host.biome] = biome
			end
		end
		sources[name], source_names[#source_names + 1] = source, name
	end

	local function shore_ok(source, pos, reads)
		local shore = source.row.shore or source.row.shore_predicate or "none"
		if shore == "none" then return true, reads end
		local offsets = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
		local found = false
		for index = 1, 4 do
			if reads >= MAX_READS then return false, reads end
			local node = core.get_node_or_nil({x = pos.x + offsets[index][1],
				y = pos.y - 1, z = pos.z + offsets[index][2]})
			reads = reads + 1
			if not node then return false, reads end
			if core.get_item_group(node.name, "water") > 0 then found = true end
		end
		return found, reads
	end

	local function habitat_ok(source, pos, reads)
		local mapgen = rawget(_G, "grug_mapgen")
		local query = mapgen and mapgen.wp40 and mapgen.wp40.ecology_at
		local support_pos = {x = pos.x, y = pos.y - 1, z = pos.z}
		if type(query) ~= "function" or not grug_core.world_alterable(pos) or
				not grug_core.world_alterable(support_pos) then
			return false, reads
		end
		local zone, analytic_biome, terrain_y, static, housing, functional, hard =
			query(pos.x, pos.y, pos.z)
		if static or housing or functional or hard then return false, reads end
		local node = core.get_node_or_nil(pos)
		reads = reads + 1
		if not node or node.name ~= "air" then return false, reads end
		local below = core.get_node_or_nil(support_pos)
		reads = reads + 1
		if not below or below.name == grug_farming.SOIL_DRY or
				below.name == grug_farming.SOIL_WET then return false, reads end
		if below.name ~= pos.support or (below.param2 or 0) ~= pos.support_param2 then
			return false, reads
		end
		if core.get_meta(support_pos):get_int(PLAYER_MARK) == 1 then return false, reads end
		local row = source.row
		if source.kind == "world" then
			if pos.y < row.min or pos.y > row.max or
					(#row.zones > 0 and not source.zones[zone]) then return false, reads end
			local data = core.get_biome_data(pos)
			local biome = data and core.get_biome_name(data.biome) or analytic_biome
			local supports = source.hosts[biome] or source.hosts[analytic_biome] or
				source.hosts["*"] or source.hosts.stone
			if not supports or not supports[below.name] then return false, reads end
			if row.mode == "surface" and pos.y ~= terrain_y + 1 then return false, reads end
		elseif source.kind == "p9g" then
			if not source.zones[zone] then return false, reads end
			local biome = source.hosts[analytic_biome]
			local zones = biome and biome[below.name]
			if not zones or not (zones[zone] or zones["*"]) then return false, reads end
		else
			-- Reused fruit positions renew only while their original tree/bush
			-- support remains. Air, farm soil and liquids are never accepted.
			local def = core.registered_nodes[below.name]
			local groups = def and def.groups or {}
			if below.name == "air" or (groups.water or 0) > 0 or
					(groups.liquid or 0) > 0 then
				return false, reads
			end
		end
		return shore_ok(source, pos, reads)
	end

	local function visible_debts()
		local result, seen = {}, {}
		for _, player in ipairs(core.get_connected_players()) do
			local pos = player:get_pos()
			local cx, cz = math.floor(pos.x / CELL), math.floor(pos.z / CELL)
			for dz = -1, 1 do for dx = -1, 1 do
				local suffix = "|" .. (cx + dx) .. "|" .. (cz + dz)
				for key, cell in pairs(state.cells) do
					if cell.debt > 0 and key:sub(-#suffix) == suffix and not seen[key] then
						seen[key], result[#result + 1] = true, key
					end
				end
			end end
		end
		table.sort(result)
		return result
	end

	local function service()
		if not ready then return end
		local keys = visible_debts()
		if #keys == 0 then return end
		if cell_cursor > #keys then cell_cursor = 1 end
		local now, reads, placements, dirty = os.time(), 0, 0, false
		local cell_count = math.min(MAX_CELLS, #keys)
		for offset = 0, cell_count - 1 do
			local key = keys[((cell_cursor + offset - 1) % #keys) + 1]
			local cell = state.cells[key]
			if cell.debt > 0 and cell.due <= now then
				local candidates = {}
				for _, pos in pairs(cell.positions) do candidates[#candidates + 1] = pos end
				table.sort(candidates, function(a, b)
					if a.z ~= b.z then return a.z < b.z end
					if a.x ~= b.x then return a.x < b.x end
					return a.y < b.y
				end)
				local attempts = math.min(8, #candidates)
				local attempted = 0
				for step = 1, attempts do
					-- Reserve the worst case: current node, candidate, support and four
					-- cardinal shore reads. This keeps the advertised global cap exact.
					if reads > MAX_READS - 7 or placements >= MAX_PLACEMENTS then break end
					attempted = attempted + 1
					local index = ((cell.cursor + step - 2) % #candidates) + 1
					local pos = candidates[index]
					local current = core.get_node_or_nil(pos)
					reads = reads + 1
					if current and pos.present and current.name ~= pos.name then
						pos.present = false
						cell.debt = math.min(cell.debt + 1, #candidates)
						dirty = true
					end
					if current and not pos.present and current.name == pos.name and
							core.get_meta(pos):get_int(PLAYER_MARK) ~= 1 then
						pos.present = true
						cell.debt = math.max(0, cell.debt - 1)
						dirty = true
					end
					if not pos.present then
						local okay
						okay, reads = habitat_ok(sources[pos.name], pos, reads)
						if okay then
							core.set_node(pos, {name = pos.name})
							pos.present, cell.debt = true, cell.debt - 1
							placements, dirty = placements + 1, true
						end
					end
				end
				cell.cursor = #candidates > 0 and
					((cell.cursor + attempted - 1) % #candidates) + 1 or 1
				if attempted > 0 then
					cell.due = cell.debt > 0 and
						now + random_delay(RETRY_MIN, RETRY_SPAN) or 0
					dirty = true
				end
			end
		end
		cell_cursor = ((cell_cursor + cell_count - 1) % #keys) + 1
		if dirty then save() end
	end

	local mapgen_path = core.get_modpath("grug_mapgen")
	if not mapgen_path then error("grug_farming: mapgen ecology authority missing", 0) end
	local world = dofile(mapgen_path .. "/wp40/world_content_catalog.lua")
	for index = 1, #world.plants do
		local row = world.plants[index]
		if row.key ~= "salt_crust" then add_source(row.node, row.key, row, "world") end
	end
	local gathering = dofile(core.get_modpath("grug_gathering") .. "/catalog.lua")
	for _, row in ipairs(gathering.p9g_sources()) do
		if row.key ~= "rock_salt" then add_source(row.source_node, row.key, row, "p9g") end
	end
	add_source("default:apple", "apple", {zones = {}, hosts = {}}, "reuse")
	add_source("default:blueberry_bush_leaves_with_berries", "blueberry",
		{zones = {}, hosts = {}}, "reuse")

	core.register_on_mods_loaded(function()
		for index = 1, #source_names do
			local name = source_names[index]
			local definition = core.registered_nodes[name]
			if not definition then error("grug_farming: ecology source missing " .. name, 0) end
			local previous = definition.after_destruct
			core.override_item(name, {after_destruct = function(pos, oldnode)
				deplete(pos, oldnode.name)
				if previous then previous(pos, oldnode) end
			end})
		end
		ready = true
	end)

	core.register_on_generated(function(minp, maxp)
		if not ready then return end
		local changed = false
		for _, pos in ipairs(core.find_nodes_in_area(minp, maxp, source_names)) do
			if observe(pos, core.get_node(pos).name) then changed = true end
		end
		if changed then save() end
	end)

	core.register_on_placenode(function(pos, newnode)
		core.get_meta(pos):set_int(PLAYER_MARK, 1)
	end)

	core.register_lbm({label = "Observe natural renewable plants",
		name = "grug_farming:observe_natural_sources", nodenames = source_names,
		run_at_every_load = true, action = function(pos, node)
			if observe(pos, node.name) then save() end
		end})

	core.register_globalstep(function(dtime)
		elapsed = elapsed + dtime
		if elapsed < PASS_SECONDS then return end
		elapsed = elapsed % PASS_SECONDS
		service()
	end)

	grug_farming.ECOLOGY_LIMITS = {cell = CELL, cells_per_pass = MAX_CELLS,
		node_reads_per_pass = MAX_READS, candidates_per_cell = 8,
		placements_per_pass = MAX_PLACEMENTS, pass_seconds = PASS_SECONDS,
		first_min = FIRST_MIN, first_max = FIRST_MIN + FIRST_SPAN,
		retry_min = RETRY_MIN, retry_max = RETRY_MIN + RETRY_SPAN}
end
