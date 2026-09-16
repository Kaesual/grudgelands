-- dump_part.lua -- print ONE part of a per-race WP13 module as TSV.
--
-- `tools/wp13/dump_capital_part.lua` is the shared library's dumper and only
-- reaches `wp13/capitals.lua`'s generators with a plain race palette. The two
-- parts this lane had to look at are neither: the elf bough house lives in
-- `wp13/elf_parts.lua` and Kezamba's king's hall is built with the BASALT
-- palette handle of `wp13/troll_palette.lua`, not with the plain troll one.
-- So this evidence directory carries its own dumper rather than changing a
-- shared tool for one render.
--
--     luajit dump_part.lua <repo> <module> <generator> [key=value ...] \
--         [--turns N] [--handle NAME]
--
-- `module` is `capitals`, `elf`, `troll` or `buildings`; `--handle` names a
-- palette handle (`elf`/`pale` for the elf module, `basalt`/`water` for the
-- troll one) and defaults to the module's plain race palette.
--
-- Plain Lua 5.1, no engine.

local args = {...}
local repo = args[1]
local module_name = args[2]
local name = args[3]
if not repo or not module_name or not name then
	io.stderr:write("usage: dump_part.lua <repo> <module> <generator> " ..
		"[key=value ...] [--turns N] [--handle NAME]\n")
	os.exit(2)
end

local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local parts = dofile(wp13 .. "/parts.lua")
local palettes = dofile(wp13 .. "/palette.lua")

local spec, turns, handle = {}, 0, nil
local index = 4
while args[index] do
	local token = args[index]
	if token == "--turns" then
		index = index + 1
		turns = tonumber(args[index]) or 0
	elseif token == "--handle" then
		index = index + 1
		handle = args[index]
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

local module, palette
if module_name == "elf" then
	module = dofile(wp13 .. "/elf_parts.lua")(wp13)
	palette = module.handles()[handle or "elf"]
elseif module_name == "troll" or module_name == "capitals" or
		module_name == "buildings" then
	local troll = dofile(wp13 .. "/troll_palette.lua")()
	if module_name == "troll" then
		module = dofile(wp13 .. "/troll_parts.lua")(wp13)
	elseif module_name == "capitals" then
		module = dofile(wp13 .. "/capitals.lua")(wp13)
	else
		module = dofile(wp13 .. "/buildings.lua")(wp13)
	end
	if handle == "basalt" then
		palette = palettes.new("troll", troll.BASALT)
	elseif handle == "water" then
		palette = palettes.new("troll", troll.WATER)
	elseif handle then
		palette = palettes.new(handle)
	else
		palette = palettes.new("troll")
	end
else
	io.stderr:write("no such module: " .. module_name .. "\n")
	os.exit(2)
end

local generator = module[name]
if type(generator) ~= "function" then
	io.stderr:write("no such generator: " .. module_name .. "." .. name .. "\n")
	os.exit(2)
end

local part = generator(palette, spec)
local target = parts.buffer()
parts.stamp(target, part, 0, 0, 0, turns)
parts.resolve_panes(target)

local out = {}
local order, count = target:cells()
for step = 1, count do
	local cell = order[step]
	out[#out + 1] = string.format("%d\t%d\t%d\t%s\t%d\n",
		cell.x, cell.y, cell.z, cell.name, cell.param2)
end
io.write(table.concat(out))
io.stderr:write(string.format("%s.%s handle=%s turn %d: %d cells, w %d d %d " ..
	"peak %d\n", module_name, name, tostring(handle), turns, count, part.w,
	part.d, part.peak))
