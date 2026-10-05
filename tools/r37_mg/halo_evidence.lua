-- Round 37 lane MG (audit MGT-02): the decoration halo's before/after
-- evidence without the engine (LuaJIT). Builds the real runtime of seed 1 as
-- main and emerge build it (tools/seed_fleet/runtime.lua, emerge mode) from the
-- tree given as REPO, then plans and writes, chunk column by chunk column,
-- every chunk from the lowest planned ground of the column to 40 nodes above
-- its highest, over three areas of 131 chunk columns (the audit's sample
-- size): 9 x 9 columns of Hearthpine forest west of the start, 5 x 5 round
-- the Dawnmere start (anchor_005) and 5 x 5 over the east edge of Highcourt
-- (anchor_008).
--
--   luajit tools/r37_mg/halo_evidence.lua REPO OUT.tsv
--
-- OUT.tsv: one line per chunk (area, origin, writer result, the SHA-256 of
-- its owner-root decoration rows, the written-chunk hash, plan seconds), then
-- "#" summary lines per area: chunks, plan_slice seconds (all and the first
-- chunk of each column), the share of profiler samples inside the column
-- source (zones.lua and the height, field and water modules under it) and
-- the planner's column-cache misses. Run it on the tree before and after a
-- change: the chunk lines (all fields but the seconds) must be identical.
local repo, out_path = arg[1], arg[2]
assert(repo and out_path, "usage: halo_evidence.lua REPO OUT.tsv")
-- The harness of this checkout (the tree under test may predate it).
local here = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")
local R = dofile(here .. "/../seed_fleet/runtime.lua")(repo, "1", "emerge")
local profile = require("jit.profile")

local AREAS = {
	{name = "forest", x = -2600, z = -2100, half = 4},
	{name = "start", x = 0, z = 2550, half = 2},
	{name = "capital", x = 352, z = -1500, half = 2},
}
local SOURCE_FILES = {"zones.lua", "height.lua", "simple_map.lua", "zone_field.lua",
	"terrain_field.lua", "water_layout.lua"}

local samples, source_samples = 0, 0
local function on_sample(thread)
	samples = samples + 1
	local stack = profile.dumpstack(thread, "pl|", 60)
	for _, name in ipairs(SOURCE_FILES) do
		if stack:find("/wp40/" .. name .. ":", 1, true) then
			source_samples = source_samples + 1
			return
		end
	end
end

local out = assert(io.open(out_path, "w"))
out:write("# halo evidence, repo ", repo, ", main ", ("%.1f"):format(R.seconds.main),
	" s, build ", ("%.1f"):format(R.seconds.build), " s\n")
local function misses()
	local m = R.built.session.metrics().planner
	return m.runtime_column_cache_misses
end
for _, area in ipairs(AREAS) do
	local ox, oz = R.origin(area.x), R.origin(area.z)
	local chunks, plan_all, plan_first = 0, 0, 0
	samples, source_samples = 0, 0
	local misses_before = misses()
	for cz = -area.half, area.half do
		for cx = -area.half, area.half do
			local x0, z0 = ox + cx * 80, oz + cz * 80
			local low, high = math.huge, -math.huge
			for z = z0, z0 + 79, 8 do
				for x = x0, x0 + 79, 8 do
					local y = R.ground_at(x, z)
					if y < low then low = y end
					if y > high then high = y end
				end
			end
			local first = true
			for y0 = R.origin(low - 1), R.origin(high + 40), 80 do
				local c = R.chunk({x = x0, y = y0, z = z0}, {
					before_plan = function() profile.start("i1", on_sample) end,
					after_plan = profile.stop})
				chunks = chunks + 1
				plan_all = plan_all + c.plan_seconds
				if first then plan_first, first = plan_first + c.plan_seconds, false end
				out:write(table.concat({area.name, x0 .. "," .. y0 .. "," .. z0, c.result,
					R.fake.sha256(c.candidates, false), c.data_hash,
					("%.4f"):format(c.plan_seconds)}, "\t"), "\n")
			end
		end
	end
	local line = ("# %s: %d columns, %d chunks, plan_slice %.2f s (first chunk of a " ..
		"column %.2f s), column source %.0f %% of %d samples, column-cache misses %d")
		:format(area.name, (2 * area.half + 1) * (2 * area.half + 1), chunks, plan_all, plan_first,
			samples > 0 and 100 * source_samples / samples or 0, samples,
			misses() - misses_before)
	out:write(line, "\n")
	print(line)
end
out:close()
