-- EXHAUSTIVE 1-D bound for the capital step band, in RELIEF space.
--
-- Two adjacent band outputs are decided by 2 * radius + 2 columns of relief, so
-- for radius = step - 1 every relief profile over that window whose per-column
-- move is at most SLOPE can be enumerated. With the translation-invariant
-- quantiser the band commutes with adding a constant to the relief, so only the
-- `step` phases of the window against the lattice have to be tried, not every
-- absolute height.
--
-- THE TWO NUMBERS THAT MATTER.
--
--   gentle  the worst |output step| over pairs whose RELIEF step is at most 1.
--           This is the property the playtest is about: on ground a player
--           could already walk, the band must not build a wall.
--   excess  the worst (|output step| - |relief step|) over ALL pairs. At most
--           zero means the band never makes ground worse than it found it; a
--           positive number is how much worse it can make a cliff.
--
--   luajit tools/wp13/evidence/20260915-capital-terrain/measurements/band-bound.lua <slope>
-- The repository root, so this runs from anywhere: the directory four levels
-- above this file.
local here = debug.getinfo(1, "S").source:sub(2)
local repo = here:gsub("/tools/wp13/evidence/[^/]+/measurements/[^/]+$", "")
if repo == here then repo = "." end
local deterministic = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/deterministic.lua")
local round_ratio, floor_div = deterministic.round_ratio, deterministic.floor_div

local SLOPE = tonumber(arg[1] or "5")

local function bin_shipped(v, step) return round_ratio(v, step) end
local function bin_uniform(v, step) return floor_div(2 * v + step, 2 * step) end
local function mid_shipped(sum) return round_ratio(sum, 2) end
local function mid_uniform(sum) return floor_div(sum + 1, 2) end

local VARIANTS = {
	{"shipped quantiser, limit", bin_shipped, mid_shipped, true},
	{"uniform quantiser, limit", bin_uniform, mid_uniform, true},
	{"uniform quantiser, no limit", bin_uniform, mid_uniform, false},
}

io.write("Exhaustive 1-D relief sweep, per-column move at most ", SLOPE, ".\n")
io.write("gentle = worst output step where the relief step is <= 1\n")
io.write("excess = worst (output step - relief step) over all pairs\n")
io.write("deviation = worst |output - plain terrace|\n\n")
io.write("step\tvariant\tgentle\texcess\tdeviation\tgentle_witness\n")
for step = 2, 4 do
	local radius = step - 1
	local width = 2 * radius + 2
	local centre_index = radius + 1
	local span = 2 * SLOPE + 1
	local total = span ^ (width - 1)
	for variant_index = 1, #VARIANTS do
		local name, bin, mid, limit = VARIANTS[variant_index][1],
			VARIANTS[variant_index][2], VARIANTS[variant_index][3],
			VARIANTS[variant_index][4]
		-- The shipped quantiser is NOT translation invariant, so it needs every
		-- phase against an absolute base as well.
		local bases = (variant_index == 1) and {-8, -1, 0, 1, 8, 40, 100, 101}
			or {0}
		local gentle, gentle_witness = 0, ""
		local excess, deviation = -99, 0
		local relief, levels = {}, {}
		for code = 0, total - 1 do
			local rest = code
			relief[1] = 0
			for i = 2, width do
				relief[i] = relief[i - 1] + (rest % span) - SLOPE
				rest = math.floor(rest / span)
			end
			for _, base in ipairs(bases) do
				for phase = 0, step - 1 do
					for i = 1, width do
						levels[i] = base + step * bin(relief[i] + phase - base, step)
					end
					local out = {}
					for _, c in ipairs({centre_index, centre_index + 1}) do
						local centre = levels[c]
						local erosion, dilation = centre, centre
						for d = -radius, radius do
							local dist = d < 0 and -d or d
							local t = levels[c + d]
							local offset = t - centre
							if (not limit) or (offset <= step and offset >= -step) then
								if t + dist < erosion then erosion = t + dist end
								if t - dist > dilation then dilation = t - dist end
							end
						end
						out[#out + 1] = mid(erosion + dilation)
					end
					local ds = out[2] - out[1]
					if ds < 0 then ds = -ds end
					local dr = relief[centre_index + 1] - relief[centre_index]
					if dr < 0 then dr = -dr end
					if dr <= 1 and ds > gentle then
						gentle = ds
						gentle_witness = table.concat(relief, ",") .. " phase " .. phase
					end
					if ds - dr > excess then excess = ds - dr end
					local off = out[1] - levels[centre_index]
					if off < 0 then off = -off end
					if off > deviation then deviation = off end
				end
			end
		end
		io.write(step, "\t", name, "\t", gentle, "\t", excess, "\t", deviation,
			"\t", gentle_witness, "\n")
		io.flush()
	end
end
