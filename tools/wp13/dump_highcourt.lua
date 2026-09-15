-- dump_highcourt.lua -- print a piece of the Highcourt capital as TSV.
--
-- The capital is not one blueprint: it is a core, a list of district plots
-- and an avenue overlay that has no cells until a surface is handed to it, so
-- `dump_blueprint.lua` has nothing to load. This builds one of the three and
-- prints the same `x<TAB>y<TAB>z<TAB>name<TAB>param2` stream that
-- `tools/wp13/render_blueprint.py` reads:
--
--     luajit tools/wp13/dump_highcourt.lua . core >core.tsv
--     luajit tools/wp13/dump_highcourt.lua . plot market_granary >plot.tsv
--     luajit tools/wp13/dump_highcourt.lua . avenue >avenue.tsv
--     python3 tools/wp13/render_blueprint.py core.tsv -o core.png
--
-- `--sockets` prints the published sockets as `#socket` comment lines before
-- the cells, for a reviewer reading the TSV by hand; `--list` prints the plot
-- ids. The avenue is rendered over the same synthetic terrace profile the KAT
-- uses, translated so the run starts at y = 0.
--
-- Plain Lua 5.1, no engine.

local args = {...}
local repo = args[1]
local what = args[2]
if not repo or not what then
	-- The three subjects are spelled out in words rather than separated by
	-- the usual vertical bar: the fourth plain-5.1 sweep greps for bitwise
	-- operators, and a bar between two words in a usage string is a hit it
	-- cannot tell from one.
	io.stderr:write("usage: dump_highcourt.lua <repo> " ..
		"[core, plot, avenue or capital] [<plot id or world seed>] " ..
		"[--sockets] [--list]\n")
	os.exit(2)
end

local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local palettes = dofile(wp13 .. "/palette.lua")
local avenue = dofile(wp13 .. "/avenue.lua")(wp13)
local highcourt = dofile(wp13 .. "/highcourt.lua")(wp13)
-- All four districts, thirty-six plots. The offsets the resolver hands back
-- are this world's, and there is no world here, so they are the canonical
-- assignment; a render of one plot does not depend on them.
local districts = dofile(wp13 .. "/highcourt_districts.lua")(wp13)
local quadrants = dofile(wp13 .. "/highcourt_quadrants.lua")()

local want_sockets = false
local plot_id = nil
for index = 3, #args do
	local token = args[index]
	if token == "--sockets" then
		want_sockets = true
	elseif token == "--list" then
		for _, entry in ipairs(districts.resolve()) do
			io.write(entry.id, "\n")
		end
		os.exit(0)
	else
		plot_id = token
	end
end

local cells, sockets, label

if what == "core" then
	local core = highcourt.core()
	cells, sockets = core.cells, core.landmarks.sockets
	label = "core " .. core.schema
elseif what == "plot" then
	local found
	for _, entry in ipairs(districts.resolve()) do
		if entry.id == plot_id then found = entry end
	end
	if not found then
		io.stderr:write("no such plot: " .. tostring(plot_id) .. "\n")
		os.exit(2)
	end
	local plot = found.build()
	cells, sockets = plot.cells, plot.landmarks.sockets
	label = "plot " .. plot.id
elseif what == "avenue" then
	-- The KAT's synthetic profile, raised so the whole run is above y = 0:
	-- a flat approach, a two-node rise, a four-node rise, a three-node drop,
	-- and one node of cross fall on the southern verge.
	local STEPS = {{-40, 4}, {-12, 6}, {5, 10}, {26, 7}}
	local function surface(x, z)
		local height = 4
		for _, step in ipairs(STEPS) do
			if x >= step[1] then height = step[2] end
		end
		if z <= -2 then height = height - 1 end
		return height
	end
	local run = avenue.run(palettes.new("human"),
		{id = "render", axis = "x", at = 0, from = -48, to = 48,
			lamp_phase = -48}, surface)
	-- The ground the road is laid on, so the render shows a road on terraces
	-- and not a ribbon in the air. It is NOT part of the overlay.
	local ground = {}
	for x = -48, 48 do
		for z = -6, 6 do
			for y = surface(x, z) - 2, surface(x, z) do
				ground[#ground + 1] = {x = x, y = y, z = z,
					name = (y == surface(x, z)) and "default:dirt_with_grass"
						or "default:dirt", param2 = 0}
			end
		end
	end
	local paved = {}
	for _, cell in ipairs(run.cells) do
		paved[cell.x .. ":" .. cell.y .. ":" .. cell.z] = true
	end
	cells = {}
	for _, cell in ipairs(ground) do
		if not paved[cell.x .. ":" .. cell.y .. ":" .. cell.z] then
			cells[#cells + 1] = cell
		end
	end
	for _, cell in ipairs(run.cells) do cells[#cells + 1] = cell end
	sockets = {}
	label = "avenue run"
elseif what == "capital" then
	-- THE WHOLE CAPITAL ON ONE FLAT PLANE: the civic core, all 36 district
	-- plots at the offsets this world's permutation gives them, and the eight
	-- street runs. It is the capital AS AUTHORED, not as built -- the ground
	-- is flat, so the terraces the plots really stand on are not in it -- and
	-- that is what makes it readable as a PLAN: which district took which
	-- quadrant, how the nine lots of each sit round the ring street's corner,
	-- and how far out the far lot stands.
	--
	-- The seed is the third argument; without one the canonical assignment is
	-- drawn.
	local options = {}
	if plot_id then
		local common = dofile(repo .. "/tools/wp40/r6/common.lua")
		options.full_seed, options.raw_sha256 = plot_id, common.new_sha256()
	end
	local resolved, assignment = districts.resolve(options)
	local seen = {}
	cells = {}
	local function emit(x, y, z, name, param2)
		local key = x .. ":" .. y .. ":" .. z
		if seen[key] then return end
		seen[key] = true
		cells[#cells + 1] = {x = x, y = y, z = z, name = name,
			param2 = param2 or 0}
	end
	local core = highcourt.core()
	for _, cell in ipairs(core.cells) do
		emit(cell.x, cell.y, cell.z, cell.name, cell.param2)
	end
	for _, entry in ipairs(resolved) do
		for _, cell in ipairs(entry.build().cells) do
			emit(entry.x + cell.x, cell.y, entry.z + cell.z, cell.name,
				cell.param2)
		end
	end
	-- The whole overlay, in the composition's own run order -- avenues, ring,
	-- district lanes, curtain wall -- so the plan shows the wall ring and its
	-- four gates and not just the roads inside it. `emit` keeps the first
	-- writer of a cell, which is the same first-run-wins arbitration the
	-- successor applies, so the avenue rides through the gate here too.
	local road = palettes.new("human")
	local function flat() return 0 end
	for _, spec in ipairs(highcourt.overlay_runs(quadrants.lane_runs())) do
		for _, cell in ipairs(highcourt.overlay_run(avenue, road,
				{id = spec.id, axis = spec.axis, at = spec.at,
					from = spec.from, to = spec.to, lamp_phase = spec.from},
				flat).cells) do
			emit(cell.x, cell.y, cell.z, cell.name, cell.param2)
		end
	end
	-- The ground everything stands on, so the plan reads as a city on a
	-- plain rather than as pieces floating in the dark.
	for z = -250, 250 do
		for x = -250, 250 do
			emit(x, -1, z, "default:dirt_with_grass", 0)
		end
	end
	sockets = {}
	local roles = {}
	for _, role in ipairs(quadrants.ROLES) do
		roles[#roles + 1] = role .. "=" .. assignment[role].quadrant
	end
	label = "capital plan " .. table.concat(roles, " ")
else
	io.stderr:write("unknown subject: " .. what .. "\n")
	os.exit(2)
end

local out = {}
if want_sockets then
	for _, entry in ipairs(sockets) do
		out[#out + 1] = string.format("#socket\t%s\t%s\t%d\t%d\t%d\t%d\t%s\n",
			entry.id, entry.role, entry.x, entry.y, entry.z, entry.face,
			tostring(entry.kind or entry.group or
				(entry.tags and entry.tags[1]) or ""))
	end
end
for _, cell in ipairs(cells) do
	out[#out + 1] = string.format("%d\t%d\t%d\t%s\t%d\n",
		cell.x, cell.y, cell.z, cell.name, cell.param2 or 0)
end
io.write(table.concat(out))
io.stderr:write(string.format("%s: %d cells, %d sockets\n", label, #cells,
	#sockets))
