-- palettes.lua -- the game's palettes and node predicates for the template
-- gallery (build_gallery.py), straight from the mapgen's own Lua.
--
-- Plain Lua 5.1 / LuaJIT, no engine; run from the repository root:
--
--     luajit tools/building_templates/viewer/palettes.lua palettes NAMES
--         JSON on stdout: the declared roles (required, optional, families),
--         every race's bindings (wp13/palette.lua), the Kezamba override
--         tables (wp13/troll_palette.lua), and for every node name listed in
--         the file NAMES (one per line) the wp13/parts.lua predicates the
--         template stamp uses: param2_kind, place_param2, is_pane,
--         pane_connects.
--     luajit tools/building_templates/viewer/palettes.lua panes
--         reads cells "x y z name param2" from stdin, runs
--         parts.resolve_panes over them and prints the cells back in the
--         same order (the reference for the Python port's test).

local MODE, NAMES = ...
local WP13 = "mods/MAPGEN/grug_mapgen/wp13/"
local palette = dofile(WP13 .. "palette.lua")
local parts = dofile(WP13 .. "parts.lua")

-- A small JSON writer: sorted object keys, arrays for 1..n tables.
local function encode(value, out)
	local kind = type(value)
	if kind == "string" then
		out[#out + 1] = string.format("%q", value):gsub("\\\n", "\\n")
	elseif kind == "number" or kind == "boolean" then
		out[#out + 1] = tostring(value)
	elseif kind == "nil" then
		out[#out + 1] = "null"
	elseif kind == "table" then
		if #value > 0 or next(value) == nil then
			out[#out + 1] = "["
			for index = 1, #value do
				if index > 1 then out[#out + 1] = "," end
				encode(value[index], out)
			end
			out[#out + 1] = "]"
		else
			local keys = {}
			for key in pairs(value) do keys[#keys + 1] = tostring(key) end
			table.sort(keys)
			out[#out + 1] = "{"
			for index, key in ipairs(keys) do
				if index > 1 then out[#out + 1] = "," end
				encode(key, out)
				out[#out + 1] = ":"
				encode(value[key], out)
			end
			out[#out + 1] = "}"
		end
	else
		error("palettes.lua: cannot encode a " .. kind, 0)
	end
	return out
end

if MODE == "palettes" then
	if not NAMES then error("usage: palettes.lua palettes NAMES", 0) end
	local races = {}
	for race, bindings in pairs(palette.races) do
		-- Through palette.new, so an invalid palette fails here as it would
		-- at a town's construction; the bindings are then read as declared.
		palette.new(race)
		races[race] = bindings
	end
	local overrides = {}
	local handles = dofile(WP13 .. "troll_palette.lua")()
	for key, value in pairs(handles) do
		if type(value) == "table" then
			palette.new("troll", value)
			overrides[key] = value
		end
	end
	local nodes = {}
	for name in io.lines(NAMES) do
		if name ~= "" then
			nodes[name] = {
				kind = parts.param2_kind(name),
				place = parts.place_param2(name),
				pane = parts.is_pane(name),
				connects = parts.pane_connects(name),
			}
		end
	end
	io.write(table.concat(encode({
		required = palette.required,
		optional = palette.optional,
		families = palette.prefix_roles,
		races = races,
		troll_overrides = overrides,
		nodes = nodes,
	}, {})), "\n")
elseif MODE == "panes" then
	local buf = parts.buffer()
	for line in io.lines() do
		local x, y, z, name, param2 = line:match("^(%S+) (%S+) (%S+) (%S+) (%S+)$")
		if x then
			buf:put(tonumber(x), tonumber(y), tonumber(z), name, tonumber(param2))
		end
	end
	parts.resolve_panes(buf)
	local order, count = buf:cells()
	for index = 1, count do
		local cell = order[index]
		io.write(cell.x, " ", cell.y, " ", cell.z, " ", cell.name, " ",
			cell.param2, "\n")
	end
else
	error("usage: palettes.lua palettes NAMES | panes", 0)
end
