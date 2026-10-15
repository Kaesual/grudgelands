-- Round 49 lane SKIP engine probe (disposable, never shipped): generates a
-- fixed list of mapchunks one at a time on seed 12345, after the starts
-- preload, so the patched refinement (tools/r49_skip/verify_patch.py) logs one
-- "[r49skip] chunk" line per chunk: the untouched-chunk decision, the full
-- writer's result and, for a chunk a test would skip, the VoxelManip
-- difference the writer made. Then it shuts the server down.
--
-- The chunk origins (chunksize 5: -32 + 80k) were picked with the portable
-- runtime of seed 12345 (tools/r49_skip/portable_test.lua prints the same
-- facts): under settlement anchors of several kinds, under the highest
-- mountain of a 32-node grid (y 521), a dragon channel and a deep ocean
-- column, the two mgprof corpus columns at their underground heights, and
-- column A's surface and sky chunks for the air test.
local PREFIX = "[r49skip_probe] "
local GAP = 1.0
local function log(message) core.log("action", PREFIX .. message) end

local CHUNKS = {
	{"start dawnmere", -32, -192, -2592}, {"start dawnmere", -32, -112, -2592},
	{"capital highcourt", -32, -192, -1552}, {"capital highcourt", -32, -112, -1552},
	{"capital dur_brannoc", -1872, -192, -1552},
	{"village goldmead", -352, -192, -2112},
	{"mine r20_anchor_062", -1072, -192, -1312},
	{"dragon r20_anchor_087", -3312, -192, -112},
	{"highest mountain", -1952, -192, -672}, {"highest mountain", -1952, -512, -672},
	{"dragon channel", -2912, -192, -352},
	{"deep ocean", -3712, -192, -3392},
	{"corpus A", 368, -192, -2352}, {"corpus A", 368, -512, -2352},
	{"corpus A", 368, -1072, -2352},
	{"corpus B", 528, -192, -2192}, {"corpus B", 528, -1072, -2192},
	{"corpus A surface", 368, 48, -2352}, {"corpus A sky", 368, 128, -2352},
	{"corpus A sky", 368, 208, -2352},
}

local function finish(ok, message)
	log(("RESULT %s %s"):format(ok and "PASS" or "FAIL", message))
	core.request_shutdown("r49skip probe done", false, 0)
end

local function run()
	local index = 0
	local function step()
		index = index + 1
		local row = CHUNKS[index]
		if not row then
			core.after(GAP, function() finish(true, #CHUNKS .. " chunks") end)
			return
		end
		local p = {x = row[2] + 8, y = row[3] + 8, z = row[4] + 8}
		log(("request %s minp=%d,%d,%d"):format(row[1], row[2], row[3], row[4]))
		core.emerge_area(p, p, function(_, action, remaining)
			if remaining ~= 0 then return end
			local fresh = action == core.EMERGE_GENERATED
			log(("done %s minp=%d,%d,%d action=%d%s"):format(row[1], row[2], row[3], row[4],
				action, fresh and "" or " NOT_FRESH"))
			if not fresh then
				finish(false, "chunk " .. row[1] .. " was not generated fresh")
				return
			end
			core.after(GAP, step)
		end)
	end
	step()
end

local waited = 0
local function wait_ready()
	local status = grug_core.world_preparation_status()
	if status.failed then return finish(false, "world preparation failed") end
	if status.ready then
		log(("preparation ready after %d s"):format(waited))
		core.after(GAP, run)
		return
	end
	waited = waited + 1
	core.after(1, wait_ready)
end
core.after(1, wait_ready)
