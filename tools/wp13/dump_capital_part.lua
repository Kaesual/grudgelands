-- dump_capital_part.lua -- print one capital-library part as TSV.
--
-- The capital generators of `mods/MAPGEN/grug_mapgen/wp13/capitals.lua` are
-- not wired into a settlement yet, so `dump_blueprint.lua` has nothing to
-- load. This builds one part directly and prints the same
-- `x<TAB>y<TAB>z<TAB>name<TAB>param2` stream, which is what
-- `tools/wp13/render_blueprint.py` reads:
--
--     luajit tools/wp13/dump_capital_part.lua . human king_hall >cells.tsv
--     python3 tools/wp13/render_blueprint.py cells.tsv -o hall.png
--
-- Usage: dump_capital_part.lua <repo> <race> <generator> [key=value ...]
--        [--turns N] [--sockets]
--
-- A `key=value` becomes a spec field; `true`/`false` and numbers are
-- converted, everything else stays a string. `--turns` stamps the part at
-- that rotation, which is how a render checks that a part reads correctly
-- turned. `--sockets` prints the published sockets as `#socket` comment
-- lines before the cells, for a reviewer reading the TSV by hand.
--
-- Plain Lua 5.1, no engine.

local args = {...}
local repo = args[1]
local race = args[2]
local name = args[3]
if not repo or not race or not name then
	io.stderr:write("usage: dump_capital_part.lua <repo> <race> <generator> " ..
		"[key=value ...] [--turns N] [--sockets]\n")
	os.exit(2)
end

local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local parts = dofile(wp13 .. "/parts.lua")
local palettes = dofile(wp13 .. "/palette.lua")
local capitals = dofile(wp13 .. "/capitals.lua")(wp13)

local spec = {}
local turns = 0
local want_sockets = false
local index = 4
while args[index] do
	local token = args[index]
	if token == "--sockets" then
		want_sockets = true
	elseif token == "--turns" then
		index = index + 1
		turns = tonumber(args[index]) or 0
	else
		local key, value = token:match("^([%w_]+)=(.*)$")
		if not key then
			io.stderr:write("not a spec assignment: " .. token .. "\n")
			os.exit(2)
		end
		if value == "true" then
			spec[key] = true
		elseif value == "false" then
			spec[key] = false
		elseif tonumber(value) then
			spec[key] = tonumber(value)
		else
			spec[key] = value
		end
	end
	index = index + 1
end
if spec.id == nil then spec.id = name end

local generator = capitals[name]
if type(generator) ~= "function" then
	io.stderr:write("no such capital generator: " .. name .. "\n")
	os.exit(2)
end

local part = generator(palettes.new(race), spec)
-- Stamp into a fresh buffer even at turn 0, so the dump goes through exactly
-- the rotation path a composition uses, and settle the panes the way a
-- composition settles them over the whole pad.
local target = parts.buffer()
local moved = parts.stamp(target, part, 0, 0, 0, turns)
parts.resolve_panes(target)

local out = {}
if want_sockets then
	for _, entry in ipairs(moved.sockets or {}) do
		out[#out + 1] = string.format("#socket\t%s\t%s\t%d\t%d\t%d\t%d\n",
			entry.id, entry.role, entry.x, entry.y, entry.z, entry.face)
	end
end
local order, count = target:cells()
for step = 1, count do
	local cell = order[step]
	out[#out + 1] = string.format("%d\t%d\t%d\t%s\t%d\n",
		cell.x, cell.y, cell.z, cell.name, cell.param2)
end
io.write(table.concat(out))
io.stderr:write(string.format("%s/%s turn %d: %d cells, w %d d %d peak %d, " ..
	"%d sockets\n", name, race, turns, count, part.w, part.d, part.peak,
	#(moved.sockets or {})))
