-- THE HEADLINE RESULT OF LANE S, and the independent reviewer's own tool
-- (2026-09-16), committed here unchanged but for this header because the number
-- it produces is the one that says whether the rulings worked.
--
--     luajit tools/wp13/evidence/20260916-streets/walkability.lua \
--         <repo> <seed> [<capital key>]
--
-- It builds a capital's road the way the SEAM does -- every street run in the
-- composition's own order, first run wins a shared cell -- and then counts
-- NEIGHBOURING ROAD COLUMNS WHOSE WALKING LEVEL DIFFERS BY TWO OR MORE, which
-- is a step no player can climb. Every other measurement in this package is
-- per run; this one is the city a player actually walks.
--
-- It runs unchanged on `main` and on this branch: the runs it asks the
-- composition for carry the junctions on one tree and not on the other, and
-- that is exactly the difference being measured.
--
-- The capital's road as the seam actually writes it: every street run, in the
-- composition's own order, first run wins a shared cell. Then: is any two
-- neighbouring road columns' walking level more than one node apart?
local repo = assert(arg[1])
local seed = assert(arg[2])
local only = arg[3]
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local source = dofile(wp40 .. "/source/simple_map.lua")
local schemas = dofile(wp40 .. "/schemas.lua")
local canonical = dofile(wp40 .. "/canonical.lua")
local deterministic = dofile(wp40 .. "/deterministic.lua")
local raw_sha256 = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()
local horizontal = dofile(wp40 .. "/simple_map.lua")({source = source,
	schemas = schemas, canonical = canonical, deterministic = deterministic,
	raw_sha256 = raw_sha256}).new(seed)
local height = dofile(wp40 .. "/height.lua")({source = source,
	canonical = canonical, deterministic = deterministic,
	raw_sha256 = raw_sha256, horizontal_session = horizontal,
	coupled_grade = dofile(wp40 .. "/coupled_grade.lua")()}).new_runtime(seed)
local palettes = dofile(wp13 .. "/palette.lua")
local elf_parts = dofile(wp13 .. "/elf_parts.lua")(wp13)
local avenue = dofile(wp13 .. "/avenue.lua")(wp13)
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local KEYS = {"highcourt", "dur_brannoc", "gor_drazhak", "lethariel",
	"kezamba", "nhal_veyr"}
for _, key in ipairs(KEYS) do
	if only == nil or only == key then
		local prof
		for i = 1, #settlement.roster do
			if settlement.roster[i].key == key then prof = settlement.roster[i] end
		end
		local palette = (key == "lethariel") and elf_parts.handles().elf
			or palettes.new(prof.race)
		local blueprint = dofile(wp40 .. "/r7_" .. key .. "_blueprint.lua")()
		local ax, az = prof.x, prof.z
		local function surf(x, z)
			local t = height.terrain_height_at(ax + x, az + z)
			local w = height.water_surface_at(ax + x, az + z)
			if type(w) == "number" and w > t then return w end
			return t
		end
		local function wet(x, z)
			local t = height.terrain_height_at(ax + x, az + z)
			local w = height.water_surface_at(ax + x, az + z)
			return type(w) == "number" and w > t
		end
		local function over(x, z)
			local kind, fy = height.functional_surface_values_at(ax + x, az + z)
			if kind ~= "bridge_deck" then return nil end
			return fy
		end
		local PAVING = palette.maybe("castle_paving") or palette.node("plaza")
		local KERB = palette.node("plaza_edge")
		local TREAD = palette.maybe("castle_wall_stair") or
			palette.node("roof_stair")
		local ROAD = {[PAVING] = true, [KERB] = true, [TREAD] = true}
		local half = (avenue.WIDTH - 1) / 2
		local RAIL = palette.node("railing")
		local POST = palette.node("post")
		local LIGHT = palette.node("light_post")
		local ABOVE = {[RAIL] = true, [POST] = true, [LIGHT] = true,
			["air"] = true}
		local owner, top, taken = {}, {}, {}
		for _, run in ipairs(blueprint.overlay.runs) do
			if not (run.id:match("^wall_") or run.id:match("^edge_") or
					run.id:match("^gate_")) then
				local spec = {id = run.id, axis = run.axis, at = run.at,
					from = run.from, to = run.to,
					width = blueprint.overlay.width,
					lamp_spacing = blueprint.overlay.lamp_spacing,
					lamp_phase = run.from, reach = blueprint.overlay.reach,
					overhead = over, wet = wet, junctions = run.junctions}
				local piece = blueprint.overlay.run(spec, surf)
				local dx = (spec.axis == "x") and 1 or 0
				for _, c in ipairs(piece.cells) do
					local ck = c.x .. ":" .. c.y .. ":" .. c.z
					local lane = ((dx == 1) and c.z or c.x) - spec.at
					-- The WALKING surface of a column: the highest cell any
					-- street run writes there that is not a rail, a post, a
					-- torch or an air cell. Arbitration only decides WHICH
					-- run's material lands, never the height.
					if not ABOVE[c.name] and lane >= -half and lane <= half then
						local k = c.x .. ":" .. c.z
						if top[k] == nil or c.y > top[k] then
							top[k] = c.y
							owner[k] = run.id
						end
					end
					taken[ck] = true
				end
			end
		end
		local jumps, worst, example = 0, 0, ""
		for k, y in pairs(top) do
			local x, z = k:match("^(-?%d+):(-?%d+)$")
			x, z = tonumber(x), tonumber(z)
			for _, d in ipairs({{1, 0}, {0, 1}}) do
				local nk = (x + d[1]) .. ":" .. (z + d[2])
				local ny = top[nk]
				if ny then
					local step = y - ny
					if step < 0 then step = -step end
					if step >= 2 then
						jumps = jumps + 1
						if step > worst then
							worst = step
							example = string.format(
								"%d,%d(%s,y=%d) vs %d,%d(%s,y=%d)",
								ax + x, az + z, owner[k], y,
								ax + x + d[1], az + z + d[2], owner[nk], ny)
						end
					end
				end
			end
		end
		print(string.format("COMPOSITE %-12s seed %-22s unwalkable_pairs=%-5d " ..
			"worst=%d  %s", key, seed, jumps, worst, example))
	end
end
