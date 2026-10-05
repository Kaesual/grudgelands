-- Round 36 lane W2 portable test (the user's playtest of 2026-10-05: the
-- benches before the capital houses faced the houses): every bench in every
-- composition faces where someone would sit looking out.
--
-- Which way a seat looks: a seat is a stair (the race's `seat`), a cottages
-- bench or an xdecor chair, upright (param2 0-3). Its raised half -- the
-- backrest -- points along the facedir of its param2 (the stairs node box
-- has its upper half at +z for param2 0; measured in the engine by
-- tools/r36_w2/engine.sh: the raised half of all 91 Highcourt seats lay along
-- `core.facedir_to_dir(param2)`), so the sitter looks along facedir
-- param2 + 2, which is what `parts.seat(face)` and the decor kit write.
--
--   A. over every composition the game builds (every settlement roster
--      profile but the capitals and the starts, the six starts, every
--      capital core and district plot), bench by bench (a run of seats that
--      look the same way, along its length):
--        * a bench with a fire (the race's hearth, a fire pit's char) or a
--          well (an open shaft ringed by low walls) behind it within four
--          nodes needs something to look at ahead within four (a fire, a
--          well, a table, board, workbench or counter, a raised bed);
--        * without anything ahead, a bench never faces a wall it could have
--          its back to: a wall ahead within three nodes -- before the knees
--          anything solid three wide at the seat's height, further on a wall
--          five wide at seat and eye height (a house, not a lamp pillar or a
--          stall) -- with no wall behind it at least as near;
--      and a resident who sits on a seat (`activity = "sit"`) faces where the
--      seat looks.
--   B. the rule itself: a bench that faces a wall, one that turns its back
--      on a fire and a sitter facing the backrest fail; their turned twins
--      pass.
--
-- Usage (repo root): luajit tools/r36_w2/portable_test.lua [REPO]
local repo = arg[1] or "."
_G.core = _G.core or {}
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local palettes = dofile(wp13 .. "/palette.lua")
local parts = dofile(wp13 .. "/parts.lua")
local RACES = {"dwarf", "human", "elf", "undead", "orc", "troll"}

-- The nodes ------------------------------------------------------------------
local SEAT = {["grug_decor:cottages_bench"] = true, ["grug_decor:xdecor_chair"] = true}
local FIRE = {["default:coalblock"] = true}
local TABLE = {["grug_decor:cottages_table"] = true, ["grug_decor:xdecor_table"] = true}
local TABLE_LEG, TABLE_TOP, LOW_WALL = {}, {}, {}
for _, race in ipairs(RACES) do
	local p = palettes.new(race)
	SEAT[p.node("seat")] = true
	FIRE[p.node("hearth")] = true
	for _, role in ipairs({"workbench", "board_table"}) do
		local name = p.maybe(role)
		if name then TABLE[name] = true end
	end
	TABLE_LEG[p.node("table_leg")] = true
	TABLE_TOP[p.node("table_top")] = true
	LOW_WALL[p.node("low_wall")] = true
end
local function open(name) return name == nil or name == "air" end
local function stair(name) return name ~= nil and name:find("stairs:stair", 1, true) ~= nil end
-- Solid to sit against or to look at: anything but air, plants, pots, mats
-- and lights.
local function solid(name)
	return not open(name) and not name:find("potted_", 1, true) and
		not name:find("torch", 1, true) and not name:find("grass_", 1, true) and
		not name:find("fern_", 1, true) and name ~= "default:junglegrass" and
		name ~= "default:dry_shrub" and name ~= "grug_decor:cottages_straw_mat" and
		name ~= "grug_decor:xdecor_candle"
end

-- The rule over one built composition: a list of failures.
local function benches(label, bp)
	local fails = {}
	local by = {}
	for _, c in ipairs(bp.cells) do by[c.x .. "," .. c.y .. "," .. c.z] = c end
	local function at(x, y, z)
		local c = by[x .. "," .. y .. "," .. z]
		return c and c.name or nil
	end
	-- A seat: open above, on a floor, not a step of a stairway (the next
	-- stair one up on its raised side), and a stair only with room for feet
	-- beside it (a roof's stairs have none).
	local function is_seat(c)
		if not SEAT[c.name] or (c.param2 or 0) >= 4 then return false end
		local below = at(c.x, c.y - 1, c.z)
		if not open(at(c.x, c.y + 1, c.z)) or open(below) or stair(below) then return false end
		if not stair(c.name) then return true end
		local ux, uz = parts.facedir_step(c.param2 or 0)
		if stair(at(c.x + ux, c.y + 1, c.z + uz)) then return false end
		for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			local x, z = c.x + d[1], c.z + d[2]
			local floor = at(x, c.y - 1, z)
			if open(at(x, c.y, z)) and open(at(x, c.y + 1, z)) and
					((floor == nil and c.y == 1) or (not open(floor) and not stair(floor))) then
				return true
			end
		end
		return false
	end
	-- Wells: an open shaft ringed by low walls; the ring is the well.
	local well = {}
	for _, c in ipairs(bp.cells) do
		if LOW_WALL[c.name] then
			for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				local sx, sz = c.x + d[1], c.z + d[2]
				if open(at(sx, c.y, sz)) and open(at(sx, c.y + 1, sz)) then
					local ring = 0
					for _, e in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
						if LOW_WALL[at(sx + e[1], c.y, sz + e[2])] then ring = ring + 1 end
					end
					if ring == 4 then
						for dz = -1, 1 do for dx = -1, 1 do
							well[(sx + dx) .. "," .. c.y .. "," .. (sz + dz)] = true
						end end
					end
				end
			end
		end
	end
	-- The column (x, z) at the seat's height y and the one above: "fire",
	-- "table", "wall" (solid at both), "low" (solid at the seat's height
	-- only) or nil.
	local function kind(x, y, z)
		local lo, hi = at(x, y, z), at(x, y + 1, z)
		if FIRE[lo] or FIRE[hi] or well[x .. "," .. y .. "," .. z] then return "fire" end
		if TABLE[lo] or TABLE[hi] or (TABLE_LEG[lo] and TABLE_TOP[hi]) then return "table" end
		if SEAT[lo] then return nil end
		-- a raised bed: plants on a kerb or on soil
		if solid(lo) and not open(hi) and not solid(hi) and not hi:find("torch", 1, true) then
			return "table"
		end
		if solid(lo) and solid(hi) then return "wall" end
		if solid(lo) then return "low" end
		return nil
	end
	-- One seat: the nearest wall, feature and fire ahead (sgn 1) or behind
	-- (sgn -1). Features count in the seat's own lane and the two beside it,
	-- unless a wall in that lane stands nearer.
	local function look(c)
		local p2 = c.param2 or 0
		local fx, fz = parts.facedir_step(p2 + 2)
		local rx, rz = parts.facedir_step(p2 + 3)
		local function scan(sgn)
			local wall, feature, fire
			local shut = {}
			for k = 1, 4 do
				local kinds = {}
				for j = -2, 2 do
					kinds[j] = kind(c.x + sgn * k * fx + j * rx, c.y, c.z + sgn * k * fz + j * rz)
				end
				for j = -1, 1 do
					local what = kinds[j]
					if (what == "table" or what == "fire") and not shut[j] then
						feature = feature or k
						if what == "fire" then fire = fire or k end
					end
				end
				for j = -1, 1 do
					if kinds[j] == "wall" then shut[j] = true end
				end
				if not wall and k <= 3 then
					local closed = true
					for j = (k == 1) and -1 or -2, (k == 1) and 1 or 2 do
						local what = kinds[j]
						if what ~= "wall" and not (k == 1 and what == "low") then closed = false end
					end
					if closed then wall = k end
				end
				if shut[-1] and shut[0] and shut[1] then break end
			end
			return wall, feature, fire
		end
		local fw, ff = scan(1)
		local bw, _, bfire = scan(-1)
		return {fw = fw, ff = ff, bw = bw, bfire = bfire, look = {fx, fz}, right = {rx, rz}}
	end
	local seat_at = {}
	for _, c in ipairs(bp.cells) do
		if is_seat(c) then seat_at[c.x .. "," .. c.y .. "," .. c.z] = c end
	end
	for _, s in ipairs(bp.landmarks and bp.landmarks.sockets or {}) do
		local c = seat_at[s.x .. "," .. (s.y - 1) .. "," .. s.z]
		if c and s.activity == "sit" and s.dir then
			local l = look(c).look
			if s.dir.x ~= l[1] or s.dir.z ~= l[2] then
				fails[#fails + 1] = ("%s: %s sits on the seat at %d,%d,%d facing %d,%d, the seat looks %d,%d")
					:format(label, s.id, c.x, c.y, c.z, s.dir.x, s.dir.z, l[1], l[2])
			end
		end
	end
	local done, count = {}, 0
	for _, c in ipairs(bp.cells) do
		local key = c.x .. "," .. c.y .. "," .. c.z
		if seat_at[key] and not done[key] then
			local first = look(c)
			local run = {c}
			done[key] = true
			for _, sgn in ipairs({1, -1}) do
				local k = 1
				while true do
					local nk = (c.x + sgn * k * first.right[1]) .. "," .. c.y .. "," ..
						(c.z + sgn * k * first.right[2])
					local n = seat_at[nk]
					if not n or done[nk] or (n.param2 or 0) ~= (c.param2 or 0) then break end
					run[#run + 1] = n
					done[nk] = true
					k = k + 1
				end
			end
			count = count + 1
			local ahead, fire_behind, wall
			for _, s in ipairs(run) do
				local j = look(s)
				ahead = ahead or j.ff
				fire_behind = fire_behind or j.bfire
				if j.fw and (not j.bw or j.fw < j.bw) then wall = wall or j end
			end
			local why
			if not ahead and fire_behind then
				why = "turns its back on a fire or a well " .. fire_behind .. " behind"
			elseif not ahead and wall then
				why = "faces a wall " .. wall.fw .. " ahead" ..
					(wall.bw and (" (" .. wall.bw .. " behind)") or " with open ground behind")
			end
			if why then
				fails[#fails + 1] = ("%s: the bench of %d at %d,%d,%d looking %d,%d %s"):format(label, #run,
					c.x, c.y, c.z, first.look[1], first.look[2], why)
			end
		end
	end
	return fails, count
end

-- A. every composition ---------------------------------------------------
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local sha = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()
local options = {raw_sha256 = sha, full_seed = "42"}
local comps = {}
for _, profile in ipairs(settlement.roster) do
	if profile.slot ~= "capital" and profile.slot ~= "start" then
		local bp = dofile(wp40 .. "/" .. profile.blueprint_file)(options, profile)
		if type(bp) == "function" then bp = bp(options) end
		comps[#comps + 1] = {profile.key, bp}
	end
end
for _, name in ipairs({"dawnmere", "hearthpine", "kapok", "silverleaf", "stillgrave", "sunscar"}) do
	local bp = dofile(wp40 .. "/r7_" .. name .. "_blueprint.lua")
	if type(bp) == "function" then bp = bp() end
	comps[#comps + 1] = {name, bp}
end
local capital = dofile(wp40 .. "/r7_capital_blueprint.lua")
for _, key in ipairs({"highcourt", "dur_brannoc", "lethariel", "nhal_veyr", "gor_drazhak", "kezamba"}) do
	local kit = capital.kit(key)
	comps[#comps + 1] = {key .. "/core", kit.core.build()}
	for _, plot in ipairs(kit.plots) do comps[#comps + 1] = {key .. "/" .. plot.id, plot.build()} end
end
check(#comps > 400, "compositions built (" .. #comps .. ")")
local all, total = {}, 0
for _, c in ipairs(comps) do
	local fails, count = benches(c[1], c[2])
	total = total + count
	for _, f in ipairs(fails) do all[#all + 1] = f end
end
check(total > 1000, "benches found (" .. total .. ")")
for _, f in ipairs(all) do print(f) end
check(#all == 0, #all .. " benches face the wrong way")

-- B. the rule itself -----------------------------------------------------
do
	local p = palettes.new("human")
	-- A house wall along z = 3 (x -4..4, three courses), ground round it, a
	-- hearth at (0, 1, -3); a bench of three seats at z = 2 and one at z = 0,
	-- param2 as given, and optionally a sitter on (0, 2, 2).
	local function scene(wall_bench, fire_bench, sitter)
		local cells = {}
		local function put(x, y, z, name, param2)
			cells[#cells + 1] = {x = x, y = y, z = z, name = name, param2 = param2 or 0}
		end
		local taken = {}
		local function mark(x, y, z) taken[x .. "," .. y .. "," .. z] = true end
		for x = -4, 4 do for y = 1, 3 do put(x, y, 3, p.node("wall")); mark(x, y, 3) end end
		put(0, 1, -3, p.node("hearth")); mark(0, 1, -3)
		for x = -1, 1 do
			put(x, 1, 2, p.node("seat"), wall_bench); mark(x, 1, 2)
			put(x, 1, 0, p.node("seat"), fire_bench); mark(x, 1, 0)
		end
		for z = -6, 6 do for x = -6, 6 do
			put(x, 0, z, p.node("ground"))
			for y = 1, 3 do
				if not taken[x .. "," .. y .. "," .. z] then put(x, y, z, "air") end
			end
		end end
		local sockets = {}
		if sitter then
			sockets[1] = {id = "sitter", x = 0, y = 2, z = 2, activity = "sit", dir = sitter}
		end
		return {cells = cells, landmarks = {sockets = sockets}}
	end
	-- param2 0: the backrest at +z (against the wall), the sitter looks -z
	local fails = benches("scene", scene(0, 0, {x = 0, z = -1}))
	check(#fails == 0, "the right benches pass: " .. table.concat(fails, "; "))
	fails = benches("scene", scene(2, 0))
	check(#fails == 1 and fails[1]:find("faces a wall 1 ahead", 1, true) ~= nil,
		"a bench facing the house wall fails: " .. table.concat(fails, "; "))
	fails = benches("scene", scene(0, 2))
	check(#fails == 1 and fails[1]:find("back on a fire", 1, true) ~= nil,
		"a bench with its back to the fire fails: " .. table.concat(fails, "; "))
	fails = benches("scene", scene(0, 0, {x = 0, z = 1}))
	check(#fails == 1 and fails[1]:find("sits on the seat", 1, true) ~= nil,
		"a sitter facing the backrest fails: " .. table.concat(fails, "; "))
end

print(("r36_w2 portable test: %d checks passed (%d compositions, %d benches)"):format(checks, #comps, total))
