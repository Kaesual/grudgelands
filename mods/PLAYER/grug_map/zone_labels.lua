-- Zone names on the map window's Zones layer (Round 47 lane ML,
-- docs/design/world_map.md "Map window"; the work package's ruling 7): one
-- label per zone, its name on the first line and its level band on the
-- second, with a translucent box behind it. The placement is Round 28 M1's
-- (commit 42c1f418, removed in Round 44): each zone's label sits at the land
-- cell of that zone farthest from its border and coast (the pole of
-- inaccessibility on a GRID_STEP grid), nudged clear of the labels placed
-- before it and of the baked region names. Placed once per start from the
-- world authority's zone queries; the formspec draws it at every zoom with
-- a constant text size, so at 1x small zones may still collide.
-- PURE Lua: the zone queries come in as arguments, so the portable fixture
-- runs the real file.
local Z = {}

Z.GRID_STEP = 32
-- The label's geometry in formspec units: a label[] without a size centres
-- its line on its y (guiFormSpecMenu.cpp parseLabel, real coordinates) and
-- would space a second line 0.5 units apart, much more than a line of text
-- at 1080p, so each line is a label[] of its own, one line height apart;
-- the box adds PAD_X and PAD_Y round the text. Text width is not known on
-- the server: CHAR_EM em per character of the client's font (font_size 16
-- by default, times its real GUI scaling), LINE_EM em per line of text.
Z.PAD_X, Z.PAD_Y = 0.08, 0.03
Z.CHAR_EM, Z.LINE_EM, Z.FONT_PX = 0.52, 1.2, 16
Z.BOX = "#1a1208a0"

-- "Levels 1–10", or "Level 60" for a single-level zone ("" without a band).
function Z.band(record)
	local low, high = record.level_min, record.level_max
	if type(low) ~= "number" or type(high) ~= "number" then return "" end
	if low == high then return ("Level %d"):format(low) end
	return ("Levels %d–%d"):format(low, high)
end

-- The text metrics {char, line} in formspec units for a client window
-- information table (core.get_player_window_information) or nil: the
-- client's pixels per unit are its size over max_formspec_size; without
-- them a 1920x1080 window at GUI scale 1 (72 px per unit).
function Z.metrics(info)
	local px, scale = 72, 1
	local size, max = type(info) == "table" and info.size, type(info) == "table" and
		info.max_formspec_size
	if type(size) == "table" and type(max) == "table" and type(size.x) == "number" and
			type(max.x) == "number" and max.x > 0 and size.x > 0 then
		px = size.x / max.x
	end
	if type(info) == "table" and type(info.real_gui_scaling) == "number" and
			info.real_gui_scaling > 0 then
		scale = info.real_gui_scaling
	end
	local font = Z.FONT_PX * scale
	return {char = font * Z.CHAR_EM / px, line = font * Z.LINE_EM / px}
end

-- The UTF-8 characters of `text` (the en dash counts once).
local function length(text)
	local _, extra = text:gsub("[\128-\191]", "")
	return #text - extra
end

-- The label box of a zone {w, h, dy} in units for `metrics`: dy is the box
-- top relative to the label's centre point (the box is centred on it).
function Z.box(name, band, metrics)
	local chars = math.max(length(name), length(band or ""))
	local lines = (band and band ~= "") and 2 or 1
	local w = chars * metrics.char + 2 * Z.PAD_X
	local h = lines * metrics.line + 2 * Z.PAD_Y
	return {w = w, h = h, dy = -h / 2}
end

-- The formspec elements of one label centred at sx/sy (units), kept inside
-- a map of max_w x max_h units (the scroll container clips what lies
-- outside): the box, then a label[] per line. `esc` is
-- core.formspec_escape.
function Z.elements(list, sx, sy, name, band, metrics, esc, max_w, max_h)
	local box = Z.box(name, band, metrics)
	local x0, y0 = sx - box.w / 2, sy + box.dy
	if max_w then x0 = math.max(0, math.min(max_w - box.w, x0)) end
	if max_h then y0 = math.max(0, math.min(max_h - box.h, y0)) end
	list[#list + 1] = ("box[%.3f,%.3f;%.3f,%.3f;%s]"):format(x0, y0, box.w, box.h, Z.BOX)
	local y = y0 + Z.PAD_Y + metrics.line / 2
	list[#list + 1] = ("label[%.3f,%.3f;%s]"):format(x0 + Z.PAD_X, y, esc(name))
	if band and band ~= "" then
		list[#list + 1] = ("label[%.3f,%.3f;%s]"):format(x0 + Z.PAD_X, y + metrics.line, esc(band))
	end
	return box
end

-- The land of every zone on a GRID_STEP grid over `view`: `water_class(x,
-- z)` and `zone_id(x, z)` are the world authority's queries
-- (grug_zones.water_class_at, id_at). Returns the grid {nx, nz, step,
-- min_x, max_z, cells} (cells[gz * nx + gx + 1] the zone id of the land at
-- the cell's centre, false for water; gz grows southward) and the set of
-- zone ids seen.
function Z.sample(view, water_class, zone_id)
	local step = Z.GRID_STEP
	local nx = math.ceil((view.max_x - view.min_x) / step)
	local nz = math.ceil((view.max_z - view.min_z) / step)
	local cells, seen = {}, {}
	for gz = 0, nz - 1 do
		local z = math.floor(view.max_z - (gz + 0.5) * step)
		for gx = 0, nx - 1 do
			local x = math.floor(view.min_x + (gx + 0.5) * step)
			local id = false
			if water_class(x, z) == "land" then
				id = zone_id(x, z) or false
				if id then seen[id] = true end
			end
			cells[gz * nx + gx + 1] = id
		end
	end
	return {nx = nx, nz = nz, step = step, min_x = view.min_x, max_z = view.max_z,
		cells = cells}, seen
end

-- Each land cell's chamfer distance (3 per straight, 4 per diagonal step)
-- to the nearest cell that is not its own zone's land, or the grid edge; 0
-- for water.
function Z.depths(grid)
	local nx, nz, cells = grid.nx, grid.nz, grid.cells
	local depth = {}
	local function relax(gx, gz, dx, dz, weight, own)
		local x, z = gx + dx, gz + dz
		if x < 0 or x >= nx or z < 0 or z >= nz then return weight end
		local other = z * nx + x + 1
		if cells[other] ~= own then return weight end
		return depth[other] + weight
	end
	for gz = 0, nz - 1 do
		for gx = 0, nx - 1 do
			local index = gz * nx + gx + 1
			local own = cells[index]
			if own then
				local d = math.huge
				d = math.min(d, relax(gx, gz, -1, 0, 3, own))
				d = math.min(d, relax(gx, gz, -1, -1, 4, own))
				d = math.min(d, relax(gx, gz, 0, -1, 3, own))
				d = math.min(d, relax(gx, gz, 1, -1, 4, own))
				depth[index] = d
			else
				depth[index] = 0
			end
		end
	end
	for gz = nz - 1, 0, -1 do
		for gx = nx - 1, 0, -1 do
			local index = gz * nx + gx + 1
			local own = cells[index]
			if own then
				local d = depth[index]
				d = math.min(d, relax(gx, gz, 1, 0, 3, own))
				d = math.min(d, relax(gx, gz, 1, 1, 4, own))
				d = math.min(d, relax(gx, gz, 0, 1, 3, own))
				d = math.min(d, relax(gx, gz, -1, 1, 4, own))
				depth[index] = d
			end
		end
	end
	return depth
end

-- How clear a label of half extents rx/rz at x/z is of `obstacles` ({x, z,
-- rx, rz, soft}: a placed label, or with `soft` a region name): the
-- smallest max(|dx| / (rx + o.rx), |dz| / (rz + o.rz)) over the labels and
-- over the names, each capped at 1 (1 = clear of all).
local function clearance(x, z, rx, rz, obstacles)
	local hard, soft = 1, 1
	for index = 1, #obstacles do
		local o = obstacles[index]
		local score = math.max(math.abs(x - o.x) / (rx + o.rx), math.abs(z - o.z) / (rz + o.rz))
		if o.soft then
			if score < soft then soft = score end
		elseif score < hard then
			hard = score
		end
	end
	return hard, soft
end

-- One label per zone of `rows` ({id, rx, rz}: half its box in nodes), in
-- that order, at the deepest land cell of its zone that is clear of every
-- label placed before it and of `obstacles`; if no cell is, the one
-- clearest of labels, then of names, then the deepest. Ties go to the lower
-- cell index. A zone without land in the grid gets no label. Returns zone
-- id -> {x, z}.
function Z.place(grid, rows, obstacles)
	local depth = Z.depths(grid)
	local nx, step, cells = grid.nx, grid.step, grid.cells
	local by_zone = {}
	for index = 1, #cells do
		local id = cells[index]
		if id then
			local list = by_zone[id]
			if not list then
				list = {}
				by_zone[id] = list
			end
			list[#list + 1] = index
		end
	end
	local function centre(index)
		local gx, gz = (index - 1) % nx, math.floor((index - 1) / nx)
		return grid.min_x + (gx + 0.5) * step, grid.max_z - (gz + 0.5) * step
	end
	local placed, result = {}, {}
	for _, row in ipairs(rows) do
		local list = by_zone[row.id]
		if list then
			table.sort(list, function(a, b)
				if depth[a] ~= depth[b] then return depth[a] > depth[b] end
				return a < b
			end)
			-- Only obstacles that can reach the zone's cells matter.
			local min_x, max_x, min_z, max_z = math.huge, -math.huge, math.huge, -math.huge
			for _, index in ipairs(list) do
				local x, z = centre(index)
				min_x, max_x = math.min(min_x, x), math.max(max_x, x)
				min_z, max_z = math.min(min_z, z), math.max(max_z, z)
			end
			local near = {}
			for _, set in ipairs({obstacles, placed}) do
				for _, o in ipairs(set) do
					if o.x + o.rx + row.rx > min_x and o.x - o.rx - row.rx < max_x and
							o.z + o.rz + row.rz > min_z and o.z - o.rz - row.rz < max_z then
						near[#near + 1] = o
					end
				end
			end
			local best, best_hard, best_soft = list[1], -1, -1
			for _, index in ipairs(list) do
				local x, z = centre(index)
				local hard, soft = clearance(x, z, row.rx, row.rz, near)
				if hard > best_hard or (hard == best_hard and soft > best_soft) then
					best, best_hard, best_soft = index, hard, soft
				end
				if hard >= 1 and soft >= 1 then break end
			end
			local x, z = centre(best)
			result[row.id] = {x = x, z = z}
			placed[#placed + 1] = {x = x, z = z, rx = row.rx, rz = row.rz}
		end
	end
	return result
end

-- How many pairs of the placed labels ({x, z, rx, rz}) overlap each other,
-- and how many labels overlap a region name of `names` (same shape): the
-- report's collision count at the reference size.
function Z.overlaps(labels, names)
	local function hit(a, b)
		return math.abs(a.x - b.x) < a.rx + b.rx and math.abs(a.z - b.z) < a.rz + b.rz
	end
	local pairs_, on_names = 0, 0
	for i = 1, #labels do
		for j = i + 1, #labels do
			if hit(labels[i], labels[j]) then pairs_ = pairs_ + 1 end
		end
		for _, name in ipairs(names) do
			if hit(labels[i], name) then
				on_names = on_names + 1
				break
			end
		end
	end
	return pairs_, on_names
end

return Z
