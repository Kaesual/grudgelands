-- One seed of the seed fleet (tools/seed_fleet/run.sh): the portable world
-- of tools/r28_zone_atlas/world.lua (inland water, roads, capitals, the zones
-- session and the R7 anchor roster, as main builds them at load), and every
-- tributary's junction stretch at most JOIN_MAX nodes.
--
--   luajit tools/seed_fleet/seed.lua REPO SEED
--
-- Prints one line, "OK <seed> <seconds> <roster sha256>" or
-- "FAIL <seed> <seconds> <error>" and then raises (a non-zero exit).
local repo, seed = arg[1], arg[2]
assert(repo and seed and seed:match("^%d+$"), "usage: seed.lua REPO SEED")
local t0 = os.clock()
local ok, world = pcall(function()
	return dofile(repo .. "/tools/r28_zone_atlas/world.lua")(repo, seed)
end)
-- A tributary's last stretch (its snap onto the parent) stays short: on main
-- before Round 34 F3 the longest over 150 seeds was about 110 nodes; moving
-- the junction past a core adds at most 2 * (core radius + reach + pad) +
-- one step, under 200 for every core but a dragon arena (on the islands), so
-- 320 means the snap went astray (a long straight canyon).
local JOIN_MAX = 320
if ok then
	local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local module = dofile(dir .. "/water_layout.lua")(dofile(dir .. "/terrain_data.lua").water)
	for _, r in ipairs(module.deserialize(world.wp40.water_layout_text).rivers) do
		local n = #r.x
		if r.parent and n > 1 then
			local dx, dz = r.x[n] - r.x[n - 1], r.z[n] - r.z[n - 1]
			local d = math.sqrt(dx * dx + dz * dz)
			if d > JOIN_MAX then
				ok, world = false, ("river %d joins its parent across %.0f nodes (bound %d)")
					:format(r.id, d, JOIN_MAX)
				break
			end
		end
	end
end
local seconds = ("%.1f"):format(os.clock() - t0)
if ok then
	print("OK", seed, seconds, world.roster.sha256)
else
	print("FAIL", seed, seconds, (tostring(world):gsub("[\t\n]", " ")))
	error("seed " .. seed .. " failed", 0)
end
