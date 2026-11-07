-- A realistic stand-in for an Expedition template, built in Lua: hull, rock
-- with some variety, two floors of rooms, corridors, doors, ore, torches,
-- lamps, chests, a lava basin. Flat arrays in VoxelManip order
-- (index = z * h * w + y * w + x + 1), so a writer copies any part of it.
local M = {}

local function cid(name, fallback)
	if core.registered_nodes[name] then return core.get_content_id(name) end
	core.log("warning", "[r71spike] node missing: " .. name)
	return core.get_content_id(fallback or "default:stone")
end

function M.build(w, h, d, seed)
	local t0 = core.get_us_time()
	local rng = PcgRandom(seed)
	local AIR = core.CONTENT_AIR
	local HULL, ROCK, COBBLE, GRAVEL = cid("default:stonebrick"), cid("default:stone"),
		cid("default:cobble"), cid("default:gravel")
	local ORE1, ORE2 = cid("default:stone_with_iron"), cid("default:stone_with_coal")
	local FLOOR1, FLOOR2 = cid("default:desert_stonebrick"), cid("default:sandstonebrick")
	local TORCH, LAMP, CHEST = cid("default:torch_wall"), cid("default:torch_ceiling"), cid("default:chest")
	local LAVA = cid("default:lava_source")
	local DOOR, DOOR_TOP = cid("doors:door_wood_a"), cid("doors:hidden")
	local data, param2 = {}, {}
	local rows = w * h
	local function index(x, y, z) return z * rows + y * w + x + 1 end

	-- the solid mass with the hull round it
	local counts = {}
	local i = 0
	for z = 0, d - 1 do
		for y = 0, h - 1 do
			for x = 0, w - 1 do
				i = i + 1
				local c
				if x < 2 or y < 2 or z < 2 or x >= w - 2 or y >= h - 2 or z >= d - 2 then
					c = HULL
				else
					local r = rng:next(0, 999)
					if r < 8 then c = ORE1 elseif r < 14 then c = ORE2
					elseif r < 40 then c = COBBLE elseif r < 60 then c = GRAVEL else c = ROCK end
				end
				data[i] = c
				param2[i] = 0
			end
		end
	end

	local function carve_room(x0, x1, y0, y1, z0, z1)
		for z = z0, z1 do
			for y = y0, y1 do
				for x = x0, x1 do data[index(x, y, z)] = AIR end
			end
		end
		for z = z0, z1 do
			for x = x0, x1 do
				data[index(x, y0 - 1, z)] = (x + z) % 5 == 0 and FLOOR2 or FLOOR1
			end
		end
	end

	-- wall torches every 6 nodes, a ceiling lamp, pillars in the large rooms
	local function dress_room(x0, x1, y0, y1, z0, z1)
		for x = x0 + 2, x1 - 2, 6 do
			for _, wall in ipairs({{z0, 4}, {z1, 5}}) do
				local at = index(x, y0 + 3, wall[1])
				data[at], param2[at] = TORCH, wall[2]
			end
		end
		for z = z0 + 2, z1 - 2, 6 do
			for _, wall in ipairs({{x0, 2}, {x1, 3}}) do
				local at = index(wall[1], y0 + 3, z)
				data[at], param2[at] = TORCH, wall[2]
			end
		end
		data[index(math.floor((x0 + x1) / 2), y1 + 1, math.floor((z0 + z1) / 2))] = LAMP
		if x1 - x0 >= 14 and z1 - z0 >= 14 then
			for _, p in ipairs({{x0 + 4, z0 + 4}, {x1 - 4, z0 + 4}, {x0 + 4, z1 - 4}, {x1 - 4, z1 - 4}}) do
				for y = y0, y1 do data[index(p[1], y, p[2])] = HULL end
			end
		end
	end

	local CELL = 24
	local spawn
	local rooms = 0
	for floor = 0, math.floor((h - 16) / 18) do
		local y0 = 6 + floor * 18
		local cells = {}
		for cz = 0, math.floor((d - 8) / CELL) - 1 do
			for cx = 0, math.floor((w - 8) / CELL) - 1 do
				local x0 = 4 + cx * CELL + rng:next(1, 3)
				local z0 = 4 + cz * CELL + rng:next(1, 3)
				local x1 = 4 + (cx + 1) * CELL - rng:next(3, 5)
				local z1 = 4 + (cz + 1) * CELL - rng:next(3, 5)
				local y1 = y0 + rng:next(5, 9)
				carve_room(x0, x1, y0, y1, z0, z1)
				dress_room(x0, x1, y0, y1, z0, z1)
				cells[cz * 100 + cx] = {x0, x1, y0, y1, z0, z1}
				rooms = rooms + 1
				spawn = spawn or {x = math.floor((x0 + x1) / 2), y = y0 + 1, z = math.floor((z0 + z1) / 2)}
				if rooms % 7 == 0 then
					local mx, mz = math.floor((x0 + x1) / 2), math.floor((z0 + z1) / 2)
					for z = mz - 2, mz + 2 do
						for x = mx - 2, mx + 2 do data[index(x, y0 - 1, z)] = LAVA end
					end
				end
				if rooms % 3 == 0 then data[index(x0 + 1, y0, z0 + 1)] = CHEST end
			end
		end
		-- a corridor with a door to the right and to the next row
		for key, room in pairs(cells) do
			local east = cells[key + 1]
			if east then
				local mz = math.floor((room[5] + room[6]) / 2)
				for x = room[2] + 1, east[1] - 1 do
					for z = mz - 1, mz + 1 do
						data[index(x, y0 - 1, z)] = FLOOR2
						for y = y0, y0 + 3 do data[index(x, y, z)] = AIR end
					end
				end
				local at = index(room[2] + 1, y0, mz)
				data[at], param2[at] = DOOR, 1
				at = index(room[2] + 1, y0 + 1, mz)
				data[at], param2[at] = DOOR_TOP, 1
			end
			local north = cells[key + 100]
			if north then
				local mx = math.floor((room[1] + room[2]) / 2)
				for z = room[6] + 1, north[5] - 1 do
					for x = mx - 1, mx + 1 do
						data[index(x, y0 - 1, z)] = FLOOR2
						for y = y0, y0 + 3 do data[index(x, y, z)] = AIR end
					end
				end
				local at = index(mx, y0, room[6] + 1)
				data[at], param2[at] = DOOR, 0
				at = index(mx, y0 + 1, room[6] + 1)
				data[at], param2[at] = DOOR_TOP, 0
			end
		end
	end

	local air = 0
	for n = 1, #data do
		if data[n] == AIR then air = air + 1 end
	end
	local tpl = {w = w, h = h, d = d, seed = seed, data = data, param2 = param2, spawn = spawn,
		rows = rows, rooms = rooms}
	core.log("action", ("[r71spike] TEMPLATE %dx%dx%d seed %d: %d nodes, %d air (%.0f%%), %d rooms, " ..
		"built in %.0f ms"):format(w, h, d, seed, #data, air, 100 * air / #data, rooms,
		(core.get_us_time() - t0) / 1000))
	return tpl
end

-- A template as it would come from a file: per mapblock one compressed string
-- of 16-bit palette indices plus one of param2. Returns the packed form and its
-- byte size. Only for block-aligned sizes.
function M.pack(tpl)
	local t0 = core.get_us_time()
	local palette, ids = {}, {}
	local blocks, bytes = {}, 0
	local char = string.char
	for bz = 0, tpl.d / 16 - 1 do
		for by = 0, tpl.h / 16 - 1 do
			for bx = 0, tpl.w / 16 - 1 do
				local parts, parts2 = {}, {}
				local n = 0
				for z = bz * 16, bz * 16 + 15 do
					for y = by * 16, by * 16 + 15 do
						local i = z * tpl.rows + y * tpl.w + bx * 16 + 1
						for x = 0, 15 do
							local c = tpl.data[i + x]
							local id = ids[c]
							if not id then
								id = #palette + 1
								palette[id] = c
								ids[c] = id
							end
							n = n + 1
							parts[n] = char(id)
							parts2[n] = char(tpl.param2[i + x])
						end
					end
				end
				local a = core.compress(table.concat(parts), "zstd")
				local b = core.compress(table.concat(parts2), "zstd")
				bytes = bytes + #a + #b
				blocks[bz * 10000 + by * 100 + bx] = {a, b}
			end
		end
	end
	core.log("action", ("[r71spike] PACK %dx%dx%d seed %d: %d bytes, palette %d, %.0f ms"):format(
		tpl.w, tpl.h, tpl.d, tpl.seed, bytes, #palette, (core.get_us_time() - t0) / 1000))
	return {blocks = blocks, palette = palette, bytes = bytes}
end

-- The light of a sealed template, as a tool would compute it: a breadth-first
-- spread from the light sources, one level per node, through the nodes that
-- let light pass. No sunlight reaches inside the hull, so day and night bank
-- are equal. Returns the flat param1 array.
function M.light(tpl)
	local t0 = core.get_us_time()
	local w, h, d, rows = tpl.w, tpl.h, tpl.d, tpl.rows
	local data = tpl.data
	local source, passes = {}, {}
	local function props(c)
		local def = core.registered_nodes[core.get_name_from_content_id(c)]
		source[c] = def and def.light_source or 0
		passes[c] = def ~= nil and def.paramtype == "light"
	end
	local light = {}
	local buckets = {}
	for level = 1, 14 do buckets[level] = {} end
	local total = #data
	for i = 1, total do
		local c = data[i]
		if source[c] == nil then props(c) end
		local l = source[c]
		light[i] = l
		if l > 0 then
			local bucket = buckets[l]
			bucket[#bucket + 1] = i
		end
	end
	local offsets = {1, -1, w, -w, rows, -rows}
	for level = 14, 2, -1 do
		local bucket = buckets[level]
		local lower = buckets[level - 1]
		for b = 1, #bucket do
			local i = bucket[b]
			if light[i] == level then
				local at = i - 1
				local x = at % w
				local z = math.floor(at / rows)
				local y = math.floor((at - z * rows) / w)
				for k = 1, 6 do
					local fits = (k == 1 and x < w - 1) or (k == 2 and x > 0) or
						(k == 3 and y < h - 1) or (k == 4 and y > 0) or
						(k == 5 and z < d - 1) or (k == 6 and z > 0)
					if fits then
						local n = i + offsets[k]
						if passes[data[n]] and light[n] < level - 1 then
							light[n] = level - 1
							lower[#lower + 1] = n
						end
					end
				end
			end
		end
	end
	for i = 1, total do light[i] = light[i] * 17 end
	core.log("action", ("[r71spike] LIGHT %dx%dx%d seed %d computed in %.0f ms"):format(w, h, d, tpl.seed,
		(core.get_us_time() - t0) / 1000))
	return light
end

return M
