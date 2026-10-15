-- Round 49 lane JIT: one seed of the seed fleet with the written chunks'
-- bytes (LuaJIT). Runs TREE's own tools/seed_fleet/seed.lua unchanged and
-- prints, before its OK/FAIL line, one line per chunk it writes:
--   CHUNK <seed> <minp x,y,z> <data hash> <writer result>
-- (the fake VoxelManip's content and param2 after the transaction, the
-- seed fleet runtime's own hash). Run it on two trees (e.g. this branch and
-- an export of main) and compare the outputs: a refactor that must keep the
-- world byte-identical shows the same lines.
--
--   luajit tools/r49_jit/fleet_digest.lua TREE SEED [perturb]
--
-- perturb: the fake VoxelManip's ground (v7's stand-in) lies up to about
-- 13 nodes off the planned terrain, so the writer cuts and fills far more
-- voxels than on the plain harness (the plan itself is unchanged).
local tree, seed, mode = arg[1], arg[2], arg[3]
assert(tree and seed, "usage: fleet_digest.lua TREE SEED [perturb]")
local real_dofile = dofile
local wrapped = false
dofile = function(path, ...)
	local value = real_dofile(path, ...)
	if not wrapped and type(path) == "string" and
			path:match("tools/seed_fleet/runtime%.lua$") then
		wrapped = true
		local factory = value
		return function(...)
			local R = factory(...)
			if mode == "perturb" then
				local zones = R.built.zones_session
				local terrain_height_at = zones.terrain_height_at
				zones.terrain_height_at = function(x, z)
					return terrain_height_at(x, z) +
						math.floor(10 * math.sin(x * 0.05) * math.cos(z * 0.04) + 3)
				end
			end
			local chunk = R.chunk
			R.chunk = function(minp, hooks)
				local out = chunk(minp, hooks)
				print(("CHUNK %s %d,%d,%d %s %s"):format(seed, minp.x, minp.y, minp.z,
					out.data_hash, tostring(out.result)))
				return out
			end
			return R
		end
	end
	return value
end
arg = {[0] = tree .. "/tools/seed_fleet/seed.lua", tree, seed}
real_dofile(tree .. "/tools/seed_fleet/seed.lua")
