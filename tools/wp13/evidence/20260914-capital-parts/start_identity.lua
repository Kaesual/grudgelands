-- Scratch: print each start blueprint's identity digest (schema, bounds,
-- palette, cells) exactly the way r7_settlement computes it, so two trees can
-- be compared byte for byte.
local repo = arg[1]
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local settlement = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua")
local roster = settlement.roster
local out = {}
for _, profile in ipairs(roster) do
	-- The STARTS only. Since the seam generalisation a roster row may be a
	-- capital, whose blueprint file returns a source declaring several
	-- blueprints of three kinds rather than one table with `bounds` and
	-- `cells` -- this scratch comparison is about the six starts and would
	-- otherwise crash on the first capital it met.
	if profile.slot == "start" then
	local bp = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/" ..
		profile.blueprint_file)()
	local rows = {}
	rows[#rows + 1] = tostring(bp.schema)
	local b = bp.bounds
	rows[#rows + 1] = table.concat({b.min.x, b.min.y, b.min.z,
		b.max.x, b.max.y, b.max.z}, ",")
	for _, name in ipairs(bp.palette) do rows[#rows + 1] = name end
	for _, c in ipairs(bp.cells) do
		rows[#rows + 1] = c.x .. "," .. c.y .. "," .. c.z .. "," .. c.name ..
			"," .. (c.param2 or 0)
	end
	local text = table.concat(rows, "\n")
	out[#out + 1] = string.format("%-12s cells=%6d palette=%3d sha=%s",
		profile.key, #bp.cells, #bp.palette,
		common.hex(common.new_sha256()(text)))
	end
end
table.sort(out)
print(table.concat(out, "\n"))
