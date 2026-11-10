-- Focused geometry regression for live table builders; no engine or world.
local repo = arg[1] or "."
local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local parts = dofile(wp13 .. "/parts.lua")
local palettes = dofile(wp13 .. "/palette.lua")
local dressing = dofile(wp13 .. "/dressing.lua")(wp13)
local decor = dofile(wp13 .. "/decor_kit.lua")(wp13)
local count = 0
local function check(ok, name)
	count = count + 1
	assert(ok, name)
end
local function name(buf, x, y, z)
	local cell = buf:at(x, y, z)
	return cell and cell.name
end
local function table_nodes(buf)
	local found = {}
	for _, cell in ipairs(buf.order) do
		if cell.name == "grug_decor:xdecor_table" then found[#found + 1] = cell end
	end
	return found
end
local function digest(buf)
	local output = {}
	for _, c in ipairs(buf.order) do
		output[#output + 1] = table.concat({c.x,c.y,c.z,c.name,c.param2 or 0}, ":")
	end
	return table.concat(output, "\n")
end
for _, race in ipairs({"human", "dwarf", "elf", "orc", "undead", "troll"}) do
	local p = palettes.new(race)
	local one = parts.buffer()
	one:put(-2, 4, 3, p.node("storage"))
	parts.table_cell(one, p, -2, 3, 3)
	check(name(one,-2,3,3) == "grug_decor:xdecor_table", race .. " table on arbitrary feet course")
	check(name(one,-2,4,3) == p.node("storage"), race .. " existing upper prop retained")
	check(#one.order == 2, race .. " no unrelated writes")
	for _, axis in ipairs({"x", "z"}) do
		local counter = parts.buffer()
		dressing.counter(counter, p, -3, 4, 4, axis)
		check(#table_nodes(counter) == 4 and #counter.order == 4, race .. " counter owns only four feet cells")
		for i = 0, 3 do
			local x, z = axis == "x" and -3+i or -3, axis == "z" and 4+i or 4
			check(name(counter,x,1,z) == "grug_decor:xdecor_table", race .. " counter axis position")
			check(name(counter,x,2,z) == nil, race .. " no elevated slab")
		end
	end
	for face = 0, 3 do
		local booth, replay = parts.buffer(), parts.buffer()
		dressing.stall(booth, p, -2, -2, face)
		dressing.stall(replay, p, -2, -2, face)
		check(digest(booth) == digest(replay), race .. " booth deterministic ordered writes")
		check(#table_nodes(booth) == 3, race .. " booth three supported tables")
		check(name(booth,-1,1,-2) == p.node("storage"), race .. " booth goods retained")
		check(name(booth,-2,3,-2) == p.node("post"), race .. " canopy post retained")
		check(name(booth,-1,4,-1) == p.node("roof_slab"), race .. " canopy retained")
		local craft = parts.buffer()
		decor.piece(decor.brush(craft,race,p), "craft", 0, 0, face)
		local found = table_nodes(craft)
		check(#found == 1 and found[1].y == 1, race .. " rotated crafting table")
		check(name(craft,found[1].x,2,found[1].z) == nil, race .. " crafting top clear")
		local stores = parts.buffer()
		decor.piece(decor.brush(stores,race,p), "stores", 0, 0, face)
		local tops = 0
		for _, c in ipairs(stores.order) do
			if c.name == p.node("table_top") and c.y == 2 then
				tops = tops + 1
				check(name(stores,c.x,1,c.z) == p.node("storage"), race .. " slab still supported by barrel")
			end
		end
		check(tops == 1 and #table_nodes(stores) == 0, race .. " barrel board unchanged")
	end
end
print("runtime table builders: " .. count .. " PASS")
