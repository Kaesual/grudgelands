-- Round 89 lane HALLS: the cells of both hall boxes and a ring of two
-- nodes round them, as the arena's model composes them (the field, the
-- shipped hall templates, the waystone), for tools/r89_halls/check_escape.py.
--
--   luajit tools/r89_halls/cells.lua [REPO]
--
-- One line per cell, in the draft's hall frame (tools/r89_balcony_draft/
-- halls.py: u toward the road, y from the floor layer, v):
--   <faction> <u> <y> <v> <name>
-- `air` where the model writes air or has no cell above the field; the
-- field's natural rim ("=") and the ground roles come as @keep, @accent,
-- @base, @path.
local repo = arg[1] or "."
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local B = dofile(wp40 .. "/breach_model.lua")
local model = B.new(wp40)
local RING = 2
local out = {}
for _, faction in ipairs({"accord", "throng"}) do
	local s = faction == "accord" and 1 or -1
	for u = -RING, 20 + RING do
		for v = -15 - RING, 15 + RING do
			local c = model.column(s * (42 - u) + 0, -s * v + 0)
			for y = -1, 18 + RING do
				local value = c and c.cells[y + 7]
				local name = "air"
				if value == B.KEEP then
					name = "@keep"
				elseif value and value > 0 then
					local e = model.entries[value]
					name = e.name or ("@" .. e.role)
				end
				out[#out + 1] = ("%s %d %d %d %s"):format(faction, u, y, v, name)
			end
		end
	end
end
io.write(table.concat(out, "\n"), "\n")
