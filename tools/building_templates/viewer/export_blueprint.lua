-- export_blueprint.lua -- print a settlement blueprint for the browser viewer.
--
-- Plain Lua 5.1 / LuaJIT, no engine:
--
--     luajit tools/wp13/viewer/export_blueprint.lua <blueprint.lua>
--
-- Output is line based, tab separated:
--
--     #bounds  x1 y1 z1 x2 y2 z2
--     #box     <landmark key> x1 y1 z1 x2 y2 z2   (named min/max landmarks)
--     #point   <landmark key> x y z               (named single points)
--     x y z name param2                           (one line per cell)
--
-- The loading rules are those of `tools/wp13/dump_blueprint.lua`: the chunk
-- may return the payload or a factory, and inert `core`/`minetest`/`vector`
-- stubs make a blueprint that really calls the engine fail loudly. Every
-- failure is a Lua error (exit status 1, the message on stderr).

local path = ...
if not path then
	error("usage: export_blueprint.lua <blueprint.lua>", 0)
end

local function make_stub(name)
	return setmetatable({}, {
		__index = function(_, key) return make_stub(name .. "." .. tostring(key)) end,
		__call = function() error("blueprint needs the engine: " .. name .. "() was called", 2) end,
	})
end
if rawget(_G, "core") == nil then _G.core = make_stub("core") end
if rawget(_G, "minetest") == nil then _G.minetest = _G.core end
if rawget(_G, "vector") == nil then _G.vector = make_stub("vector") end

local chunk, err = loadfile(path)
if not chunk then
	error("load error: " .. tostring(err), 0)
end
local ok, result = pcall(chunk)
if ok and type(result) == "function" then ok, result = pcall(result) end
if not ok then
	error("blueprint error: " .. tostring(result), 0)
end
if type(result) ~= "table" then
	error("blueprint returned " .. type(result) .. ", expected table", 0)
end

local out, n = {}, 0
local function emit(s)
	n = n + 1
	out[n] = s
	if n >= 4096 then
		io.write(table.concat(out))
		out, n = {}, 0
	end
end

local function is_point(p)
	return type(p) == "table" and type(p.x) == "number" and type(p.z) == "number"
end

local b = result.bounds
if type(b) == "table" and is_point(b.min) and is_point(b.max) then
	emit(string.format("#bounds\t%d\t%d\t%d\t%d\t%d\t%d\n",
		b.min.x, b.min.y or 0, b.min.z, b.max.x, b.max.y or 0, b.max.z))
end

if type(result.landmarks) == "table" then
	local keys = {}
	for key in pairs(result.landmarks) do
		if type(key) == "string" then keys[#keys + 1] = key end
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local v = result.landmarks[key]
		if type(v) == "table" and is_point(v.min) and is_point(v.max) then
			emit(string.format("#box\t%s\t%d\t%d\t%d\t%d\t%d\t%d\n", key,
				v.min.x, v.min.y or 0, v.min.z, v.max.x, v.max.y or 0, v.max.z))
		elseif is_point(v) then
			emit(string.format("#point\t%s\t%d\t%d\t%d\n", key, v.x, v.y or 0, v.z))
		end
	end
end

local cells = result.cells or result
for i = 1, #cells do
	local c = cells[i]
	local x, y, z = c.x or c[1], c.y or c[2], c.z or c[3]
	local name = c.name or c[4]
	if x and y and z and name and name ~= "air" then
		emit(string.format("%d\t%d\t%d\t%s\t%d\n", x, y, z, name,
			c.param2 or c[5] or 0))
	end
end
io.write(table.concat(out))
