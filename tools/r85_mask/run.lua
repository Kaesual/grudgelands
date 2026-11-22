-- Round 85 MASK: the claim mask of one seed on the seed fleet's runtime (no
-- engine), its cost, and its tables for the check against the capacity
-- study (tools/r85_mask/compare.py).
--
--   luajit tools/r85_mask/run.lua <repo> <seed> <outdir>
--
-- Builds the mask twice: cold (every column scan made, as a world's first
-- start) and warm (the scans of the first build handed in, as a later start
-- with the cache file), then the fingerprints of the map's snapshot, and
-- writes into <outdir>:
--   meta.tsv          seed, CPU seconds of every step, counts
--   mask.tsv          faction, cx, cz of every claim-ground chunk
--   reasons.tsv       faction, reason, chunks (every chunk of the world plan)
--   kinds.tsv         kind id, cells, ground, limit
--   columns.tsv       faction, cx, cz, kind id, columns (claim-ground chunks)
--   grug_claim_mask.txt, grug_claim_ground.txt   the two world-folder files
--                     as the game writes them (header values of this tool)
local repo, seed, out = arg[1], arg[2], arg[3]
assert(repo and seed and out, "usage: run.lua <repo> <seed> <outdir>")
arg = {repo}

local t0 = os.clock()
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local t_runtime = os.clock() - t0
t0 = os.clock()
local W = dofile(repo .. "/tools/r85_mask/world.lua")(repo, R)
local t_world = os.clock() - t0
local CM = dofile(repo .. "/mods/PLAYER/grug_housing/claim_mask.lua")
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local sha = common.new_sha256()
local function sha256(bytes) return common.hex(sha(bytes)) end

local scans = {}
t0 = os.clock()
local mask = CM.build(W.world, scans)
local t_cold = os.clock() - t0
t0 = os.clock()
local warm = CM.build(W.world, scans)
local t_warm = os.clock() - t0
assert(warm.new_scans == 0, "the warm build scanned again")
t0 = os.clock()
local rows = CM.fingerprints(mask, W.world, sha256)
local t_fp = os.clock() - t0

local function open(name)
	return assert(io.open(out .. "/" .. name, "wb"))
end
local f = open("mask.tsv")
for _, fac in ipairs(CM.FACTIONS) do
	for _, c in ipairs(mask.list(fac)) do f:write(fac, "\t", c[1], "\t", c[2], "\n") end
	-- the warm build is the same mask
	local a, b = mask.list(fac), warm.list(fac)
	assert(#a == #b, "warm mask differs")
	for n = 1, #a do assert(a[n][1] == b[n][1] and a[n][2] == b[n][2], "warm mask differs") end
end
f:close()
f = open("reasons.tsv")
local rg = mask.range
for _, fac in ipairs(CM.FACTIONS) do
	local count, names = {}, {}
	for cz = rg.min_cz, rg.max_cz do
		for cx = rg.min_cx, rg.max_cx do
			local ok, why = mask.ground(fac, cx, cz)
			why = ok and "ground" or why
			if not count[why] then count[why] = 0 names[#names + 1] = why end
			count[why] = count[why] + 1
		end
	end
	table.sort(names)
	for _, why in ipairs(names) do f:write(fac, "\t", why, "\t", count[why], "\n") end
end
f:close()
f = open("kinds.tsv")
for _, k in ipairs(mask.kinds) do
	f:write(k.id, "\t", k.cells, "\t", k.ground, "\t", k.limit, "\n")
end
f:close()
f = open("columns.tsv")
for _, fac in ipairs(CM.FACTIONS) do
	for _, c in ipairs(mask.list(fac)) do
		for _, row in ipairs(mask.kind_columns(c[1], c[2])) do
			f:write(fac, "\t", c[1], "\t", c[2], "\t", row[1], "\t", row[2], "\n")
		end
	end
end
f:close()

local store = dofile(repo .. "/mods/PLAYER/grug_housing/claim_mask_store.lua")({
	sha256 = sha256,
	read = function(path)
		local h = io.open(path, "rb")
		if not h then return nil end
		local t = h:read("*a")
		h:close()
		return t
	end,
	write = function(path, bytes)
		local h = assert(io.open(path, "wb"))
		h:write(bytes)
		h:close()
		return true
	end})
local header = {{"game", "tool"}, {"seed", seed}, {"map_reset", 0}, {"chunk", CM.CHUNK},
	{"origin", CM.ORIGIN}, {"strip", CM.STRIP}, {"step", CM.STEP}}
local ok, snapshot_bytes = store.store_snapshot(out, header, rows)
assert(ok)
local back = assert(store.load_snapshot(out))
assert(#back.rows == #rows, "snapshot read back differs")
local ok2, cache_bytes = store.store_cache(out, {{"seed", seed}}, scans)
assert(ok2)
local back_scans = assert(store.load_cache(out, {{"seed", seed}}))
local n_scans = 0
for k, s in pairs(scans) do
	n_scans = n_scans + 1
	assert(back_scans[k] and back_scans[k].code == s.code and back_scans[k].cap == s.cap,
		"cache read back differs")
end

local m = open("meta.tsv")
local st = mask.stats
m:write(table.concat({
	"seed\t" .. seed,
	("runtime_s\t%.1f"):format(t_runtime),
	("world_s\t%.1f"):format(t_world),
	("regions_s\t%.1f"):format(W.seconds.regions),
	("mask_cold_s\t%.2f"):format(t_cold),
	("mask_warm_s\t%.2f"):format(t_warm),
	("fingerprints_s\t%.2f"):format(t_fp),
	"sampled_columns\t" .. st.sampled_columns,
	"candidates\t" .. st.candidates,
	"scanned\t" .. st.scanned,
	"scans\t" .. n_scans,
	"accord\t" .. st.accord,
	"throng\t" .. st.throng,
	"kinds\t" .. #mask.kinds,
	"wall_chunks\t" .. #mask.wall_chunks,
	"snapshot_bytes\t" .. snapshot_bytes,
	"cache_bytes\t" .. cache_bytes,
}, "\n"), "\n")
m:close()
print(("seed %s: accord %d, throng %d chunks; mask cold %.2f s, warm %.2f s, " ..
	"fingerprints %.2f s; %d scans"):format(seed, st.accord, st.throng, t_cold, t_warm,
	t_fp, n_scans))
