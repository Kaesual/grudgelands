-- Disposable headless probe for WP13 playtest round 3, lane 2: the census of
-- FLOATING decorations around the six starts. Staged into a throwaway game copy
-- by `tools/wp13/run_bush_probe.sh` (PROBE= of `tools/luanti_headless.sh`);
-- never shipped with the game, never loaded by a normal server.
--
-- The user reported bushes hovering one node above the ground in the terrain
-- ring around the dwarf start. This probe answers, from the map rather than
-- from the source:
--
--   1. WHICH node types float, WHERE, and HOW MANY, per start and per distance
--      band (pad 0-63, apron 64-73, blend ring 74-127, wild 128+ -- the bands
--      round B's ring census already uses).
--   2. WHETHER the defect lives only in round B's new blend-ring vegetation or
--      in the untouched wild terrain as well. That is the whole point of
--      censusing all six starts AND the band outside the blend envelope.
--
-- WHAT COUNTS AS FLOATING. A decoration's ROOT nodes are the nodes of its
-- lowest occupied layer: the trunk of a tree, the stem of a bush, the single
-- leaf layer of a blueberry bush, the node of a simple decoration. A correctly
-- planted decoration always has solid ground directly under every root node.
-- Only names that can never be anything but a root are gated -- see the
-- `gated` table below for why a trunk or a canopy name cannot be.
--
-- The root vocabulary is not hard-coded: it is derived at load time from the
-- production decoration catalog (`wp40/r7_r6_manifest.lua`) by reading each
-- template's own schematic through the engine, exactly the way the R6 template
-- expander does. Root nodes that are also a surface material of some biome
-- (the mud/dirt base course of `swamp_papyrus`) are dropped, because such a
-- node is indistinguishable from ordinary ground in a census.
--
-- Plain Lua 5.1.

local BOOT = "1"
local storage = core.get_mod_storage()
BOOT = tostring((tonumber(storage:get_string("boots")) or 0) + 1)
storage:set_string("boots", BOOT)

-- All three are rewritten by the runner before the probe is staged.
local RADIUS = 128
local STARTS = "1,2,3,4,5,6"
-- Render mode instead of the census: "<start index>,<dx>,<dz>,<half width>".
-- The probe emerges that one box around the start's anchor and logs every
-- non-air node in it as a render TSV row, which is what
-- `tools/wp13/render_blueprint.py` draws. Empty means "census".
local DUMP = ""

-- How far above and below the reported terrain height a column is scanned. A
-- floating root sits one node higher than a planted one, so two nodes of slack
-- below and ten above cover every catalog template without scanning the sky.
local SCAN_BELOW = 2
local SCAN_ABOVE = 10

local function log(fields)
	local parts = {"GRUG_WP13_BUSH", "boot=" .. BOOT}
	for index = 1, #fields do parts[#parts + 1] = fields[index] end
	core.log("action", table.concat(parts, " "))
end

local modpath = assert(core.get_modpath("grug_mapgen"))
local wp40 = modpath .. "/wp40"
local default_path = assert(core.get_modpath("default"))
local trees_path = assert(core.get_modpath("grug_trees"))

--
-- The root vocabulary, out of the production catalog.
--
local manifest = dofile(wp40 .. "/r7_r6_manifest.lua")()
local template_source = dofile(wp40 .. "/r7_template_source.lua")(
	core, default_path .. "/schematics", trees_path .. "/schematics")

local surface_material = {}
for index = 1, #manifest.surfaces do
	local row = manifest.surfaces[index]
	surface_material[row.top] = true
	surface_material[row.filler] = true
	surface_material[row.shore] = true
	surface_material[row.bed] = true
	if row.dust ~= "" and row.dust ~= "-" then surface_material[row.dust] = true end
end

-- decoration id -> {roots = {name -> true}, lowest = <lowest occupied local y>,
-- size_y = ...}. `lowest` is the measurement the fix turns on: Luanti anchors a
-- schematic ON the surface node, so its bush schematics carry an all-air bottom
-- layer, while WP40 anchors a template one node ABOVE the surface.
local catalog = {}
local root_names, upper_names = {}, {}
for index = 1, #manifest.decorations do
	local row = manifest.decorations[index]
	local entry = {id = row.id, kind = row.kind, rule = row.rule,
		roots = {}, lowest = 0, size_y = 1}
	if row.kind == "simple" then
		entry.roots[row.asset_or_node] = true
	else
		local schematic = template_source.read(row.asset_or_node)
		local sx, sy, sz = schematic.size.x, schematic.size.y, schematic.size.z
		entry.size_y = sy
		local lowest = nil
		for y = 0, sy - 1 do
			for z = 0, sz - 1 do
				for x = 0, sx - 1 do
					local cell = schematic.data[z * sy * sx + y * sx + x + 1]
					if cell.name ~= "air" and lowest == nil then lowest = y end
				end
			end
			if lowest ~= nil then break end
		end
		entry.lowest = lowest or 0
		for y = 0, sy - 1 do
			for z = 0, sz - 1 do
				for x = 0, sx - 1 do
					local cell = schematic.data[z * sy * sx + y * sx + x + 1]
					if cell.name ~= "air" then
						if y == entry.lowest then entry.roots[cell.name] = true
						else upper_names[cell.name] = true end
					end
				end
			end
		end
	end
	catalog[#catalog + 1] = entry
	for name in pairs(entry.roots) do
		if not surface_material[name] then root_names[name] = true end
	end
end

-- Which names the census GATES on, and why the obvious wider rule does not work.
--
-- The first calibration run gated every root name and reported 679 floating
-- `default:tree` of 2,624 at Dawnmere. Those are not floating decorations: an
-- apple tree's BRANCHES are `default:tree` as well, they stick out sideways five
-- nodes up, and of course they have air beneath them. The same goes for the
-- bushes' own leaf ring, which is both a root cell and a canopy cell.
--
-- A name is therefore gated only where it can never be anything BUT a root: it
-- occurs in the lowest occupied slice of some decoration and in no higher slice
-- of any decoration. That keeps the three bush stems, the blueberry bush's
-- single leaf layer and every simple decoration -- exactly the vocabulary whose
-- node below must be solid ground -- and drops trunks, branches and canopies,
-- which are reported separately as `canopy_floating` so nothing is hidden.
local gated = {}
for name in pairs(root_names) do
	if not upper_names[name] then gated[name] = true end
end

--
-- The six starts, read the way `tools/wp13/engine_cases.lua` reads them.
--
local roster = dofile(wp40 .. "/r7_settlement.lua").roster
local starts = {}
for index = 1, #roster do
	local profile = roster[index]
	if profile.slot == "start" then
		local anchor = assert(grug_zones.anchor(profile.zone_id, profile.slot))
		starts[#starts + 1] = {key = profile.key, anchor = anchor}
	end
end

local wanted = {}
for text in (STARTS .. ","):gmatch("([^,]+),") do
	wanted[assert(tonumber(text))] = true
end

local function check_dump(condition, message)
	if not condition then error("WP13 bush probe: " .. message, 0) end
	return condition
end

local function band_of(chebyshev)
	if chebyshev <= 63 then return "pad" end
	if chebyshev <= 73 then return "apron" end
	if chebyshev <= 127 then return "ring" end
	return "wild"
end

local BANDS = {"pad", "apron", "ring", "wild"}

--
-- Programme: for each start, walk a grid of tiles; emerge a tile and census it
-- IMMEDIATELY. Censusing only after the whole start had been emerged read
-- `ignore` out of nine per cent of its columns on the first calibration run --
-- a server with no player unloads mapblocks again while the next tiles are
-- still generating, and an unloaded column would silently leave its plants out
-- of the count.
--
local queue = {}
for index = 1, #starts do
	if wanted[index] then queue[#queue + 1] = starts[index] end
end

-- `core.emerge_area` queues every mapblock of its box at once and the engine's
-- emerge queue is bounded (`emergequeue_limit_total`, 1024 blocks by default);
-- a whole 381-wide start would exceed it and the surplus would come back
-- cancelled rather than generated. 64-node tiles stay well inside the bound.
local TILE = 64

local function accumulator()
	local state = {floating = {}, planted = {}, canopy_floating = 0, canopy = {},
		overhang = 0, ignored = 0, columns = 0, band_floating = {},
		band_planted = {}, band_columns = {}, samples = {}, sampled = {}}
	for index = 1, #BANDS do
		local band = BANDS[index]
		state.band_floating[band] = 0
		state.band_planted[band] = 0
		state.band_columns[band] = 0
	end
	return state
end

-- A decoration wider than one column can legitimately hang over a step in the
-- ground: the blueberry bush is a single 3x3 layer of leaf nodes, so on a slope
-- its outer cells sit over the neighbouring column's lower surface while the
-- cell it is anchored on rests on soil. Luanti's own decoration placement does
-- exactly the same, and refusing it would be a placement rule of its own.
--
-- So an unsupported root node is only counted as FLOATING when no node of the
-- same name in its own eight neighbours, at its own height, is supported. A
-- one-column decoration -- every bush stem, every simple plant -- has no such
-- neighbour and is therefore counted exactly as before; the patch of a wide one
-- is counted floating only when the WHOLE patch hangs, which is what the defect
-- under test does.
local NEIGHBOUR_DX = {-1, -1, -1, 0, 0, 1, 1, 1}
local NEIGHBOUR_DZ = {-1, 0, 1, -1, 1, -1, 0, 1}

local function census_tile(start, state, minp, maxp)
	local anchor = start.anchor
	local pos, below = {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0}
	local probe_pos, probe_below = {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0}
	local function patch_is_supported(x, y, z, name)
		for index = 1, 8 do
			probe_pos.x, probe_pos.y = x + NEIGHBOUR_DX[index], y
			probe_pos.z = z + NEIGHBOUR_DZ[index]
			if core.get_node(probe_pos).name == name then
				probe_below.x, probe_below.y, probe_below.z =
					probe_pos.x, y - 1, probe_pos.z
				local under = core.get_node(probe_below).name
				local definition = core.registered_nodes[under]
				if under ~= "air" and under ~= "ignore" and definition ~= nil and
						definition.walkable ~= false then
					return true
				end
			end
		end
		return false
	end
	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			local chebyshev = math.max(math.abs(x - anchor.x), math.abs(z - anchor.z))
			local band = band_of(chebyshev)
			local y0 = grug_zones.terrain_height_at(x, z)
			pos.x, pos.z, below.x, below.z = x, z, x, z
			local column_ignored = false
			for y = y0 - SCAN_BELOW, y0 + SCAN_ABOVE do
				pos.y = y
				local name = core.get_node(pos).name
				if name == "ignore" then column_ignored = true end
				if root_names[name] then
					below.y = y - 1
					local under = core.get_node(below).name
					local definition = core.registered_nodes[under]
					local unsupported = under == "air" or under == "ignore" or
						(definition ~= nil and definition.walkable == false)
					if not gated[name] then
						if unsupported then
							state.canopy_floating = state.canopy_floating + 1
							local key = name .. "~" .. band
							state.canopy[key] = (state.canopy[key] or 0) + 1
						end
					elseif unsupported and patch_is_supported(x, y, z, name) then
						state.overhang = state.overhang + 1
						local key = name .. "~" .. band
						state.planted[key] = (state.planted[key] or 0) + 1
						state.band_planted[band] = state.band_planted[band] + 1
					elseif unsupported then
						local key = name .. "~" .. band
						state.floating[key] = (state.floating[key] or 0) + 1
						state.band_floating[band] = state.band_floating[band] + 1
						if not state.sampled[name] or state.sampled[name] < 3 then
							state.sampled[name] = (state.sampled[name] or 0) + 1
							state.samples[#state.samples + 1] = name .. "@" .. x .. "," ..
								y .. "," .. z .. "/edge" .. (chebyshev - 64) ..
								"/under:" .. under
						end
					else
						local key = name .. "~" .. band
						state.planted[key] = (state.planted[key] or 0) + 1
						state.band_planted[band] = state.band_planted[band] + 1
					end
				end
			end
			if column_ignored then state.ignored = state.ignored + 1 end
			state.band_columns[band] = state.band_columns[band] + 1
			state.columns = state.columns + 1
		end
	end
end

local function report(start, state, seconds)
	local keys = {}
	for key in pairs(state.floating) do keys[key] = true end
	for key in pairs(state.planted) do keys[key] = true end
	local ordered = {}
	for key in pairs(keys) do ordered[#ordered + 1] = key end
	table.sort(ordered)
	local total_floating, total_planted, rows = 0, 0, {}
	for index = 1, #ordered do
		local key = ordered[index]
		local float_count = state.floating[key] or 0
		local plant_count = state.planted[key] or 0
		total_floating = total_floating + float_count
		total_planted = total_planted + plant_count
		rows[#rows + 1] = key .. "=" .. float_count .. "/" ..
			(float_count + plant_count)
	end
	local band_fields = {}
	for index = 1, #BANDS do
		local band = BANDS[index]
		band_fields[#band_fields + 1] = band .. "=" .. state.band_floating[band] ..
			"/" .. (state.band_floating[band] + state.band_planted[band]) ..
			"@" .. state.band_columns[band]
	end
	log({"event=census", "start=" .. start.key,
		"anchor=" .. start.anchor.x .. "," .. start.anchor.y .. "," ..
			start.anchor.z,
		"radius=" .. RADIUS, "columns=" .. state.columns,
		"ignored_columns=" .. state.ignored,
		"floating=" .. total_floating, "rooted=" .. total_planted,
		"canopy_floating=" .. state.canopy_floating,
		"patch_overhang=" .. state.overhang,
		"seconds=" .. string.format("%.1f", seconds),
		"bands=" .. table.concat(band_fields, ";"),
		"names=" .. (#rows > 0 and table.concat(rows, ";") or "-"),
		"canopy=" .. (function()
			local list = {}
			for key, count in pairs(state.canopy) do
				list[#list + 1] = key .. "=" .. count
			end
			table.sort(list)
			return #list > 0 and table.concat(list, ";") or "-"
		end)(),
		"samples=" .. (#state.samples > 0 and
			table.concat(state.samples, ";") or "-")})
	return total_floating
end

local function tiles_for(start)
	local anchor = start.anchor
	local low, high = nil, nil
	for dz = -RADIUS, RADIUS, 4 do
		for dx = -RADIUS, RADIUS, 4 do
			local y = grug_zones.terrain_height_at(anchor.x + dx, anchor.z + dz)
			if low == nil or y < low then low = y end
			if high == nil or y > high then high = y end
		end
	end
	local y_min, y_max = low - SCAN_BELOW - 8, high + SCAN_ABOVE + 8
	local list = {}
	local dz = -RADIUS
	while dz <= RADIUS do
		local dx = -RADIUS
		while dx <= RADIUS do
			list[#list + 1] = {
				{x = anchor.x + dx, y = y_min, z = anchor.z + dz},
				{x = anchor.x + math.min(dx + TILE - 1, RADIUS), y = y_max,
					z = anchor.z + math.min(dz + TILE - 1, RADIUS)}}
			dx = dx + TILE
		end
		dz = dz + TILE
	end
	return list, y_min, y_max
end

local step, total = 1, 0
local run_next

local function walk_tiles(start, state, list, index, started)
	if index > #list then
		total = total + report(start, state,
			(core.get_us_time() - started) / 1000000)
		step = step + 1
		run_next()
		return
	end
	local tile = list[index]
	core.emerge_area(tile[1], tile[2], function(_, _, remaining)
		if remaining ~= 0 then return end
		census_tile(start, state, tile[1], tile[2])
		if index % 6 == 0 or index == #list then
			log({"event=progress", "start=" .. start.key,
				"tile=" .. index .. "/" .. #list, "seconds=" ..
				string.format("%.1f", (core.get_us_time() - started) / 1000000)})
		end
		walk_tiles(start, state, list, index + 1, started)
	end)
end

function run_next()
	if #queue == 0 then
		log({"event=complete", "starts=" .. (step - 1),
			"floating_total=" .. total, "radius=" .. RADIUS})
		core.request_shutdown("WP13 bush probe complete", false, 1)
		return
	end
	local start = table.remove(queue, 1)
	local list, y_min, y_max = tiles_for(start)
	log({"event=emerge_start", "start=" .. start.key, "index=" .. step,
		"tiles=" .. #list, "y=" .. y_min .. ".." .. y_max})
	walk_tiles(start, accumulator(), list, 1, core.get_us_time())
end

local function run_dump()
	local fields = {}
	for text in (DUMP .. ","):gmatch("([^,]+),") do
		fields[#fields + 1] = assert(tonumber(text))
	end
	check_dump(#fields == 4, "DUMP must be start,dx,dz,half")
	local start = check_dump(starts[fields[1]], "DUMP names no start") and
		starts[fields[1]]
	local cx, cz = start.anchor.x + fields[2], start.anchor.z + fields[3]
	local half = fields[4]
	local cy = grug_zones.terrain_height_at(cx, cz)
	local minp = {x = cx - half, y = cy - 6, z = cz - half}
	local maxp = {x = cx + half, y = cy + 12, z = cz + half}
	log({"event=dump_start", "start=" .. start.key,
		"centre=" .. cx .. "," .. cy .. "," .. cz,
		"minp=" .. core.pos_to_string(minp), "maxp=" .. core.pos_to_string(maxp)})
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining ~= 0 then return end
		local pos, rows = {x = 0, y = 0, z = 0}, 0
		for z = minp.z, maxp.z do
			for y = minp.y, maxp.y do
				for x = minp.x, maxp.x do
					pos.x, pos.y, pos.z = x, y, z
					local node = core.get_node(pos)
					if node.name ~= "air" and node.name ~= "ignore" then
						-- Rendered coordinates are relative to the box corner, which is
						-- what the blueprint renderer expects.
						core.log("action", "GRUG_WP13_BUSHCELL\t" .. (x - minp.x) ..
							"\t" .. (y - minp.y) .. "\t" .. (z - minp.z) .. "\t" ..
							node.name .. "\t" .. node.param2)
						rows = rows + 1
					end
				end
			end
		end
		log({"event=complete", "starts=0", "floating_total=0",
			"radius=" .. RADIUS, "dump_rows=" .. rows})
		core.request_shutdown("WP13 bush dump complete", false, 1)
	end)
end

core.after(2, function()
	if DUMP ~= "" then
		log({"event=begin", "mode=dump", "dump=" .. DUMP})
		run_dump()
		return
	end
	local list = {}
	for name in pairs(gated) do list[#list + 1] = name end
	table.sort(list)
	log({"event=begin", "starts=" .. #queue, "radius=" .. RADIUS,
		"gated_roots=" .. table.concat(list, ";")})
	run_next()
end)
