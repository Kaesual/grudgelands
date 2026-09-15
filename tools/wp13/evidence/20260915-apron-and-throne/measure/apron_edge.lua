-- The jagged inner treeline of a start's protection apron, measured per ray.
--
-- A start's hard square is the 148 x 148 of world.md section 2 R1: the 128-node
-- build envelope plus a ten-node apron. Since playtest round 1 a VEGETATION
-- query is let through the apron outside a seed-deterministic jittered
-- boundary. This walks one ray per perimeter column of all four sides, outward
-- from the first column past the envelope, and records the excess at which the
-- vegetation rule first stops refusing -- 1 means the treeline starts on the
-- very first apron ring, 10 on the last, and `blocked` means the ray never
-- opens at all, which is what a road corridor crossing the apron does.
--
-- Written as a distribution per start plus the raw per-ray profile, so the
-- outline can be compared between seeds and between runs rather than believed.
local repo, seed, output = assert(arg[1]), assert(arg[2]), assert(arg[3])
local directory = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local src = dofile(directory .. "/source/simple_map.lua")
local canonical = dofile(directory .. "/canonical.lua")
local deterministic = dofile(directory .. "/deterministic.lua")
local raw_sha256 = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()
local horizontal = dofile(directory .. "/simple_map.lua")({source = src,
	schemas = dofile(directory .. "/schemas.lua"), canonical = canonical,
	deterministic = deterministic, raw_sha256 = raw_sha256}).new(seed)

-- The half-open geometry of the shapes themselves: the envelope reaches
-- centre-64 .. centre+63, the hard square centre-74 .. centre+73, so the apron
-- is exactly excess 1..10 of the envelope on every side.
local ENVELOPE_HALF = 64
local APRON = 10
local BLOCKED = APRON + 1

local function first_open(anchor, fx, fz)
	for excess = 1, APRON do
		local x = anchor.position.x + fx(excess)
		local z = anchor.position.z + fz(excess)
		if horizontal.static_exclusion_values_at(x, z, "vegetation") == nil then
			return excess
		end
	end
	return BLOCKED
end

local file = assert(io.open(output, "wb"))
file:write("seed\t", seed, "\n")
file:write("# inner_radius is the Chebyshev excess of the 128-node envelope at\n")
file:write("# which the vegetation rule first lets a host through, per ray.\n")
-- `envelope_open` is the invariant the whole carve stands on and is expected to
-- be 0 for ever: not one column of the 128-node build envelope may host,
-- whatever the jitter says. `apron_columns` is 148^2 - 128^2 by construction.
file:write("start\trays\tblocked\tmin\tmax\t" ..
	"apron_columns\tapron_open\tenvelope_open\t" ..
	"e1\te2\te3\te4\te5\te6\te7\te8\te9\te10\n")
local profile = {}
for anchor_index = 1, 6 do
	local anchor = src.anchors[anchor_index]
	if anchor.slot_id ~= "start" then error("anchor " .. anchor.id .. " is not a start") end
	local histogram, blocked, minimum, maximum, rays = {}, 0, nil, nil, 0
	for value = 1, APRON do histogram[value] = 0 end
	local rows = {}
	for side = -ENVELOPE_HALF, ENVELOPE_HALF - 1 do
		-- east, west, south, north, in that fixed order per perimeter column.
		local ray_values = {
			first_open(anchor, function(e) return ENVELOPE_HALF - 1 + e end,
				function() return side end),
			first_open(anchor, function(e) return -ENVELOPE_HALF - e end,
				function() return side end),
			first_open(anchor, function() return side end,
				function(e) return ENVELOPE_HALF - 1 + e end),
			first_open(anchor, function() return side end,
				function(e) return -ENVELOPE_HALF - e end),
		}
		for index = 1, #ray_values do
			local value = ray_values[index]
			rays = rays + 1
			if value == BLOCKED then
				blocked = blocked + 1
			else
				histogram[value] = histogram[value] + 1
				minimum = minimum and math.min(minimum, value) or value
				maximum = math.max(maximum or value, value)
			end
			rows[#rows + 1] = value
		end
	end
	-- The same square the shapes use, half-open on both axes: the envelope
	-- reaches -64 .. +63 and the hard square -74 .. +73.
	local apron_columns, apron_open, envelope_open = 0, 0, 0
	for dz = -ENVELOPE_HALF - APRON, ENVELOPE_HALF + APRON - 1 do
		for dx = -ENVELOPE_HALF - APRON, ENVELOPE_HALF + APRON - 1 do
			local inside = dx >= -ENVELOPE_HALF and dx < ENVELOPE_HALF and
				dz >= -ENVELOPE_HALF and dz < ENVELOPE_HALF
			local open = horizontal.static_exclusion_values_at(
				anchor.position.x + dx, anchor.position.z + dz, "vegetation") == nil
			if inside then
				if open then envelope_open = envelope_open + 1 end
			else
				apron_columns = apron_columns + 1
				if open then apron_open = apron_open + 1 end
			end
		end
	end
	local line = {anchor.id, rays, blocked, minimum or "-", maximum or "-",
		apron_columns, apron_open, envelope_open}
	for value = 1, APRON do line[#line + 1] = histogram[value] end
	file:write(table.concat(line, "\t"), "\n")
	profile[#profile + 1] = anchor.id .. "\t" .. table.concat(rows, ",")
end
file:write("# raw per-ray profile, east/west/south/north per perimeter column\n")
for index = 1, #profile do file:write(profile[index], "\n") end
assert(file:close())
print("apron_edge\tok\t" .. output)
