-- dump_blueprint.lua -- print a settlement blueprint as TSV (x, y, z, name, param2).
--
-- Plain Lua 5.1. Runs without the Luanti engine:
--
--     luajit tools/wp13/dump_blueprint.lua mods/MAPGEN/grug_mapgen/wp40/r7_hearthpine_blueprint.lua
--     tools/bin/lua51 tools/wp13/dump_blueprint.lua <blueprint.lua> > cells.tsv
--
-- The blueprint chunk may return either the cell table itself or a factory
-- function returning it. Optional inert stubs for `core`/`minetest`/`vector`
-- are installed so that blueprints which merely *touch* those globals still
-- load; a blueprint that actually calls into the engine fails loudly with the
-- name of the entry point it wanted, rather than emitting wrong geometry.

local args = {...}
local path = args[1]
if not path then
	io.stderr:write("usage: dump_blueprint.lua <blueprint.lua> [--meta]\n")
	os.exit(2)
end
local want_meta = false
for i = 2, #args do
	if args[i] == "--meta" then want_meta = true end
end

local function make_stub(name)
	local t = {}
	setmetatable(t, {
		__index = function(_, key)
			return make_stub(name .. "." .. tostring(key))
		end,
		__call = function()
			error("blueprint needs the engine: " .. name .. "() was called", 2)
		end,
		__tostring = function() return "<stub " .. name .. ">" end,
	})
	return t
end

if rawget(_G, "core") == nil then _G.core = make_stub("core") end
if rawget(_G, "minetest") == nil then _G.minetest = _G.core end
if rawget(_G, "vector") == nil then _G.vector = make_stub("vector") end

local chunk, err = loadfile(path)
if not chunk then
	io.stderr:write("load error: " .. tostring(err) .. "\n")
	os.exit(1)
end

local ok, result = pcall(chunk)
if not ok then
	io.stderr:write("run error: " .. tostring(result) .. "\n")
	os.exit(1)
end

if type(result) == "function" then
	local ok2, res2 = pcall(result)
	if not ok2 then
		io.stderr:write("blueprint error: " .. tostring(res2) .. "\n")
		os.exit(1)
	end
	result = res2
end

if type(result) ~= "table" then
	io.stderr:write("blueprint returned " .. type(result) .. ", expected table\n")
	os.exit(1)
end

local cells = result.cells or result
if type(cells) ~= "table" then
	io.stderr:write("blueprint has no cells array\n")
	os.exit(1)
end

local out = {}
local n = 0
local function emit(s)
	n = n + 1
	out[n] = s
	if n >= 4096 then
		io.write(table.concat(out))
		out = {}
		n = 0
	end
end

if want_meta then
	local b = result.bounds
	if b and b.min and b.max then
		emit(string.format("#bounds\t%d\t%d\t%d\t%d\t%d\t%d\n",
			b.min.x, b.min.y, b.min.z, b.max.x, b.max.y, b.max.z))
	end
	if type(result.landmarks) == "table" then
		for group, list in pairs(result.landmarks) do
			if type(list) == "table" then
				for _, p in ipairs(list) do
					if type(p) == "table" and p.x then
						emit(string.format("#landmark\t%s\t%d\t%d\t%d\n",
							tostring(group), p.x, p.y or 0, p.z))
					end
				end
			end
		end
	end
end

for i = 1, #cells do
	local c = cells[i]
	local x = c.x or c[1]
	local y = c.y or c[2]
	local z = c.z or c[3]
	local name = c.name or c[4]
	local param2 = c.param2 or c[5] or 0
	if x and y and z and name then
		emit(string.format("%d\t%d\t%d\t%s\t%d\n", x, y, z, name, param2))
	end
end

io.write(table.concat(out))
