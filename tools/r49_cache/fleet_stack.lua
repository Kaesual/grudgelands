-- Round 49 lane CACHE: one seed of the seed fleet with every written chunk's
-- bytes, its sampled chunks generated together with the chunks above and
-- below them (LuaJIT). Runs TREE's own tools/seed_fleet/seed.lua unchanged;
-- every chunk it writes is followed by the chunk 80 nodes above and the one
-- 80 nodes below in the same column, so a column's later chunks reuse what
-- its first chunk kept (P9G's 2-D roots, the column tuples). Prints, before
-- the OK/FAIL line, one line per chunk:
--   CHUNK <seed> <minp x,y,z> <data hash> <writer result>
-- Run it on this branch and on a tree without the caches (main before Round
-- 49 lane CACHE) and compare the outputs: they must be the same lines.
--
--   luajit tools/r49_cache/fleet_stack.lua TREE SEED [perturb]
--
-- perturb: the fake VoxelManip's ground lies up to about 13 nodes off the
-- planned terrain (as tools/r49_jit/fleet_digest.lua).
local tree, seed, mode = arg[1], arg[2], arg[3]
assert(tree and seed, "usage: fleet_stack.lua TREE SEED [perturb]")
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
			local function one(minp, hooks)
				local out = chunk(minp, hooks)
				print(("CHUNK %s %d,%d,%d %s %s"):format(seed, minp.x, minp.y, minp.z,
					out.data_hash, tostring(out.result)))
				return out
			end
			R.chunk = function(minp, hooks)
				local out = one(minp, hooks)
				one({x = minp.x, y = minp.y + 80, z = minp.z})
				one({x = minp.x, y = minp.y - 80, z = minp.z})
				return out
			end
			return R
		end
	end
	return value
end
arg = {[0] = tree .. "/tools/seed_fleet/seed.lua", tree, seed}
real_dofile(tree .. "/tools/seed_fleet/seed.lua")
