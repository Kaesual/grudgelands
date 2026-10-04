-- One seed of the seed fleet (tools/seed_fleet/run.sh): the portable world
-- of tools/r28_zone_atlas/world.lua (inland water, roads, capitals, the zones
-- session and the R7 anchor roster, as main builds them at load).
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
local seconds = ("%.1f"):format(os.clock() - t0)
if ok then
	print("OK", seed, seconds, world.roster.sha256)
else
	print("FAIL", seed, seconds, (tostring(world):gsub("[\t\n]", " ")))
	error("seed " .. seed .. " failed", 0)
end
