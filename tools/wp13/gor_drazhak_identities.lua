-- Every blueprint identity Gor Drazhak publishes, in manifest order.
--
--     luajit tools/wp13/gor_drazhak_identities.lua <repo>
--
-- The capital's core, its 36 district plots, its 16 fill dressings and its one
-- overlay each carry their own identity SHA-256 (`r7_settlement.prepare`). This
-- prints them, and it exists for the reason `highcourt_identities.lua` exists:
-- once a playtest has accepted a capital, the digests of the pieces it accepted
-- are what a later lane must not move by accident, and a cell total beside them
-- is what holds the contract's 400 000-cell budget.
--
-- BY KEY AND NOT BY SLOT, the lesson the pilot capital's own copy of this tool
-- records: a tool that took "the last roster entry whose slot is capital"
-- started printing a different capital's identities under its own filename the
-- moment a second one joined the roster, in silence.
--
-- A district's OFFSET is not in any of these -- a plot's identity is its cells,
-- and its cells do not know which quadrant they will stand in -- so this output
-- is the same on every world.
--
-- Plain Lua 5.1.

local repo = assert(arg[1], "repository root required")
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local sha = common.new_sha256()

local profile
for index = 1, #settlement.roster do
	if settlement.roster[index].key == "gor_drazhak" then
		profile = settlement.roster[index]
	end
end
assert(profile, "the roster has no Gor Drazhak")

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
