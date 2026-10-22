-- What the two freeze exporters share (Round 56, lanes FREEZE-TOWNS and
-- FREEZE-CAPITALS; docs/technical/building-template-format.md §8): the frame
-- of a placement, the template-frame param2, legend entries and their text,
-- point values with `{id}`, and the rendering of one cut building into the
-- body of a template file.
--
-- `lib.parts` is the pre-freeze parts module (the rotation the game runs);
-- the exporter sets it before the first frame or render.
--
-- LuaJIT only; a tool, never shipped.

local lib = {}

function lib.key3(x, y, z) return x .. ":" .. y .. ":" .. z end
local key3 = lib.key3

function lib.sorted_keys(map)
	local keys = {}
	for key in pairs(map) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	return keys
end

-- A pad cell -> the placement's part frame. `pl` carries the anchor
-- (`ox`, `oy`, `oz`), `turns` and the pivot (`w`, `d`).
function lib.to_part_frame(pl, x, y, z)
	local parts = lib.parts
	local w2, d2 = pl.w, pl.d
	if pl.turns % 2 == 1 then w2, d2 = pl.d, pl.w end
	local px, pz = parts.rotate_footprint(x - pl.ox, z - pl.oz, w2, d2,
		(4 - pl.turns) % 4)
	local cx, cz = parts.rotate_footprint(px, pz, pl.w, pl.d, pl.turns)
	assert(cx == x - pl.ox and cz == z - pl.oz, "the frame inverse differs")
	return px, y - pl.oy, pz
end

-- The template-frame param2 that the stamp turns into `param2`.
function lib.unrotate_param2(name, param2, turns)
	local parts = lib.parts
	if turns == 0 then return param2 end
	local kind = parts.param2_kind(name)
	if kind == parts.NONE then return 0 end
	if kind == parts.MESHOPTIONS then return param2 end
	local limit = kind == parts.WALLMOUNTED and 5 or 23
	for value = 0, limit do
		local ok, turned = pcall(parts.rotate_param2, value, kind, turns)
		if ok and turned == param2 then return value end
	end
	for value = 0, limit do
		local ok, turned = pcall(parts.rotate_param2, value, kind, turns)
		if ok and parts.canonical_param2(name, turned) == param2 then return value end
	end
	error("no template param2 for " .. name .. " " .. param2 .. " at " .. turns .. " turns")
end

lib.DIR_FACE = {["0:1"] = 0, ["1:0"] = 1, ["0:-1"] = 2, ["-1:0"] = 3}

function lib.orientation_of(name, param2)
	local parts = lib.parts
	if param2 == parts.place_param2(name) then return nil end
	return parts.param2_kind(name) .. ":" .. param2
end

function lib.entry_text(entry)
	-- air written after planting is a legend entry (format doc §4.2)
	if entry.kind == "air" then return entry.late and "node air" or "." end
	if entry.kind == "node" then
		return "node " .. entry.name .. (entry.o and (" o=" .. entry.o) or "")
	end
	local out = {"role", entry.role}
	if entry.variant then out[#out + 1] = "variant=" .. entry.variant end
	if entry.channel then out[#out + 1] = "channel=" .. entry.channel end
	if entry.o then out[#out + 1] = "o=" .. entry.o end
	if entry.fallback then out[#out + 1] = "else=" .. entry.fallback end
	return table.concat(out, " ")
end
local entry_text = lib.entry_text

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ..
	"!$%&'()*+,-/:;<=>?@[\\]^_`{}~\""

function lib.format_value(value)
	if type(value) == "boolean" then return value and "true" or "false" end
	if type(value) == "number" then
		assert(value % 1 == 0, "a non-integer point value")
		return string.format("%d", value)
	end
	if type(value) == "table" then
		local items = {}
		for index, item in ipairs(value) do items[index] = lib.format_value(item) end
		return "[" .. table.concat(items, ",") .. "]"
	end
	assert(type(value) == "string" and not value:find('["\n]'), "a bad point string")
	local outside = value:gsub("{id}", "")
	if value ~= "" and value:match("^[A-Za-z0-9_:.{}%-]+$") and
			not outside:find("[{}]") and value ~= "true" and value ~= "false" and
			not value:match("^%-?%d+$") then
		return value
	end
	return '"' .. value .. '"'
end
local format_value = lib.format_value

function lib.with_id(value, id)
	if type(value) == "string" then
		local start, stop = value:find(id, 1, true)
		if start then
			return value:sub(1, start - 1) .. "{id}" .. lib.with_id(value:sub(stop + 1), id)
		end
		return value
	elseif type(value) == "table" then
		local copy = {}
		for index, item in ipairs(value) do copy[index] = lib.with_id(item, id) end
		return copy
	end
	return value
end
local with_id = lib.with_id

local GROUP_ORDER = {doors = 1, inside = 2, room_corner = 3, lights = 4, sockets = 5,
	trees = 6}

-- One cut building -> the head (pivot, box, cell width, meta) and the tail
-- (legend, grid, points) of its template file. `pl` carries `content` (the
-- cells by key3, each `{x, y, z, entry}`), `points` (the part's own groups),
-- `moved` (the town points moved into it), `stamp.meta`, `w`, `d` and `id`.
function lib.render(pl)
	-- legend entries: the cells' and their fallbacks'
	local entries, by_text = {}, {}
	local function intern(entry)
		if entry.kind == "air" and not entry.late then return "." end
		if entry.fallback_entry then
			local target = intern(entry.fallback_entry)
			entry.fallback_text = entry_text(entry.fallback_entry)
			entry.fallback_ref = target
		end
		local text = entry_text(entry) .. (entry.fallback_text and
			(" else=<" .. entry.fallback_text .. ">") or "") .. (entry.late and " late" or "")
		if not by_text[text] then
			by_text[text] = entry
			entries[#entries + 1] = text
		end
		return text
	end
	local x1, y1, z1, x2, y2, z2
	local function grow(x, y, z)
		x1 = x1 and math.min(x1, x) or x
		y1 = y1 and math.min(y1, y) or y
		z1 = z1 and math.min(z1, z) or z
		x2 = x2 and math.max(x2, x) or x
		y2 = y2 and math.max(y2, y) or y
		z2 = z2 and math.max(z2, z) or z
	end
	local cell_text = {}
	for key, cell in pairs(pl.content) do
		cell_text[key] = intern(cell.entry)
		grow(cell.x, cell.y, cell.z)
	end
	-- points, in group order
	local groups = {}
	for group in pairs(pl.points) do groups[#groups + 1] = group end
	for _, moved in ipairs(pl.moved) do
		if not pl.points[moved.group] then
			pl.points[moved.group] = {}
			groups[#groups + 1] = moved.group
		end
	end
	table.sort(groups, function(a, b)
		local ra, rb = GROUP_ORDER[a] or 99, GROUP_ORDER[b] or 99
		if ra ~= rb then return ra < rb end
		return a < b
	end)
	local point_lines = {}
	for _, group in ipairs(groups) do
		local list = {}
		for _, point in ipairs(pl.points[group]) do
			local attrs = {}
			for key, value in pairs(point) do
				if key ~= "x" and key ~= "y" and key ~= "z" and key ~= "face" then
					attrs[#attrs + 1] = {key = key, value = value}
				end
			end
			table.sort(attrs, function(a, b) return a.key < b.key end)
			list[#list + 1] = {x = point.x, y = point.y, z = point.z, face = point.face,
				attrs = attrs}
		end
		for _, moved in ipairs(pl.moved) do
			if moved.group == group then list[#list + 1] = moved.point end
		end
		for _, point in ipairs(list) do
			grow(point.x, point.y, point.z)
			local line = {group, point.x, point.y, point.z}
			if point.face then line[#line + 1] = "face=" .. point.face end
			for _, attr in ipairs(point.attrs) do
				line[#line + 1] = attr.key .. "=" .. format_value(with_id(attr.value, pl.id))
			end
			point_lines[#point_lines + 1] = table.concat(line, " ")
		end
	end
	-- keys: entries sorted by their text, keys handed out in that order
	table.sort(entries)
	local cell = #entries <= #ALPHABET and 1 or 2
	local key_of = {}
	for index, text in ipairs(entries) do
		if cell == 1 then
			key_of[text] = ALPHABET:sub(index, index)
		else
			local a = math.floor((index - 1) / #ALPHABET) + 1
			local b = (index - 1) % #ALPHABET + 1
			key_of[text] = ALPHABET:sub(a, a) .. ALPHABET:sub(b, b)
		end
	end
	local legend = {}
	local role_cells, node_cells, cells = 0, 0, 0
	for _, text in ipairs(entries) do
		local entry = by_text[text]
		local line = entry_text(entry)
		if entry.fallback_ref then
			line = line .. " else=" .. (entry.fallback_ref == "." and "air" or
				key_of[entry.fallback_ref])
		end
		if entry.late then line = line .. " late" end
		legend[#legend + 1] = key_of[text] .. " " .. line
	end
	local grid = {}
	local blank, air = string.rep(" ", cell), string.rep(".", cell)
	for y = y1, y2 do
		grid[#grid + 1] = "layer " .. y
		for z = z1, z2 do
			local row = {"|"}
			for x = x1, x2 do
				local text = cell_text[key3(x, y, z)]
				if text == nil then row[#row + 1] = blank
				else
					cells = cells + 1
					if text == "." then row[#row + 1] = air
					else
						row[#row + 1] = key_of[text]
						if by_text[text].kind == "role" then role_cells = role_cells + 1
						else node_cells = node_cells + 1 end
					end
				end
			end
			row[#row + 1] = "|"
			grid[#grid + 1] = table.concat(row)
		end
	end
	local meta = {}
	for _, key in ipairs(lib.sorted_keys(pl.stamp.meta)) do
		local value = pl.stamp.meta[key]
		meta[#meta + 1] = key .. "=" .. format_value(value)
	end
	local body = {}
	body[#body + 1] = "pivot " .. pl.w .. " " .. pl.d
	body[#body + 1] = "origin " .. x1 .. " " .. y1 .. " " .. z1
	body[#body + 1] = "size " .. (x2 - x1 + 1) .. " " .. (y2 - y1 + 1) .. " " .. (z2 - z1 + 1)
	body[#body + 1] = "cell " .. cell
	if #meta > 0 then body[#body + 1] = "meta " .. table.concat(meta, " ") end
	local rest = {"", "legend"}
	for _, line in ipairs(legend) do rest[#rest + 1] = line end
	rest[#rest + 1] = "end"
	rest[#rest + 1] = ""
	for _, line in ipairs(grid) do rest[#rest + 1] = line end
	rest[#rest + 1] = ""
	rest[#rest + 1] = "points"
	for _, line in ipairs(point_lines) do rest[#rest + 1] = line end
	rest[#rest + 1] = "end"
	return {head = table.concat(body, "\n"), tail = table.concat(rest, "\n"),
		cells = cells, legend = #entries, role_cells = role_cells,
		node_cells = node_cells, box = {x1, y1, z1, x2, y2, z2}}
end

function lib.write_file(path, text)
	local file = assert(io.open(path, "wb"))
	file:write(text)
	file:close()
end

-- The cells of a part buffer, `key3` -> "name/param2".
function lib.cells_of(buffer)
	local source, count = buffer:cells()
	local map = {}
	for index = 1, count do
		local cell = source[index]
		map[key3(cell.x, cell.y, cell.z)] = cell.name .. "/" .. cell.param2
	end
	return map
end

return lib
