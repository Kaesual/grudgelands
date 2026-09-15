-- Every blueprint identity Highcourt publishes, in manifest order.
--
--     luajit tools/wp13/highcourt_identities.lua <repo>
--
-- The capital's core, its 36 district plots, its 16 dressings and its avenue
-- and wall overlay each carry
-- their own identity SHA-256 (`r7_settlement.prepare`). This prints them, and
-- it exists because two of them are things a lane must not move by accident:
-- the CORE, whose digest the playtest round froze, and the nine MARKET plots,
-- which the districts increment was not supposed to rebuild. A district's
-- OFFSET is not in any of these -- a plot's identity is its cells, and its
-- cells do not know which quadrant they will stand in -- so this output is
-- the same on every world.
--
-- Plain Lua 5.1.

local repo = assert(arg[1], "repository root required")
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local sha = common.new_sha256()

-- BY KEY AND NOT BY SLOT. The first version took the last roster entry whose
-- slot was "capital", which was Highcourt while Highcourt was the only one; the
-- moment Dur Brannoc joined the roster this tool started printing Dur Brannoc's
-- identities under a Highcourt filename, in silence. The thing it exists to
-- protect -- the core digest the playtest froze -- is the one it stopped
-- showing.
local profile
for index = 1, #settlement.roster do
	if settlement.roster[index].key == "highcourt" then
		profile = settlement.roster[index]
	end
end
assert(profile, "the roster has no Highcourt")

local source = dofile(wp40 .. "/" .. profile.blueprint_file)()
local prepared = settlement.prepare(profile, source, sha)
local total = 0
for index = 1, #prepared.blueprints do
	local blueprint = prepared.blueprints[index]
	local descriptor = blueprint.descriptor
	local population = blueprint.identity.cell_count or
		blueprint.identity.run_count or 0
	total = total + (blueprint.identity.cell_count or 0)
	io.write(string.format("%-34s %-10s %7d  %s\n", descriptor.id,
		descriptor.kind, population, blueprint.identity.sha256))
end
io.write(string.format("%-34s %-10s %7d\n", "TOTAL CELLS", "-", total))
