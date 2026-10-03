-- Round 31 Lane S portable test (LuaJIT): the PvP POI blueprints of stage 1
-- (the fortress per faction and the two camp layouts in all six race
-- palettes, `r31_pvp_poi_blueprint.lua`).
--
--   luajit tools/r31_s/portable_test.lua [REPO]
--
-- For every composition (fortress x 2 factions, camp low/high x 6 races) and
-- every quarter turn 0..3:
--   1. the blueprint passes the settlement validator the bandit camps pass
--      (`r7_settlement.prepare`: schema, byte-sorted palette, canonical
--      z/y/x unique cells inside the authorized box, declared bounds equal
--      the cells', anchor support and an empty root), under a test profile
--      whose box is the composition's own (stage 2 adds the box to
--      `r7_settlement.BOUNDS`); building twice gives the same identity;
--   2. every palette name is a registered node;
--   3. the sockets (`r7_settlement.sockets`): unique ids, the role counts of
--      pvp-plan ruling 17 and its defaults (fortress: 2 gate guards, >= 8
--      inner elites, one General, 2 bodyguards, >= 2 quest givers, one
--      Quartermaster, one waystone, no innkeeper; camps: 4 or 5 guards and
--      one captain), each standing on ground with feet and head air (the
--      waystone socket on its waystone);
--   4. walking on the ground course from outside the gate reaches every
--      socket, and the gate is the footprint's only opening at ground level;
--   5. a turn keeps the cell count and moves the gate with it.
-- Stage 1 changes no game behaviour: nothing registers these blueprints.
-- Prints "R31 S PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

_G.core = _G.core or {}
local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local build = dofile(dir .. "/r31_pvp_poi_blueprint.lua")
local settlement = dofile(dir .. "/r7_settlement.lua")
local sha = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()
local rot = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp13/plot_approach.lua").rot

local function read(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local text = f:read("*a")
	f:close()
	return text
end

-- Registered node names: the static tile index of the wp13 renderer, the
-- loop-registered wool colours, and grug_mapgen's own node file (the
-- waystone) for the rest.
local tiles = read(repo .. "/tools/wp13/node_tiles.json")
local registered_cache = {}
local function registered(name)
	if registered_cache[name] ~= nil then return registered_cache[name] end
	local ok = name == "air" or tiles:find('"' .. name:gsub("%p", "%%%0") .. '": {', 1) ~= nil
	local colour = name:match("^wool:(.+)$")
	if not ok and colour then
		ok = read(repo .. "/mods/BASE/wool/textures/wool_" .. colour .. ".png") ~= nil
	end
	if not ok then
		local source = read(repo .. "/mods/MAPGEN/grug_mapgen/world_nodes.lua") or ""
		ok = source:find('register_node("' .. name .. '"', 1, true) ~= nil
	end
	registered_cache[name] = ok
	return ok
end

local RACES = {human = "accord", dwarf = "accord", elf = "accord",
	orc = "throng", undead = "throng", troll = "throng"}
local compositions = {
	{kind = "pvp_fortress", faction = "accord"}, {kind = "pvp_fortress", faction = "throng"}}
for _, kind in ipairs({"pvp_camp_low", "pvp_camp_high"}) do
	for _, race in ipairs({"human", "dwarf", "elf", "orc", "undead", "troll"}) do
		compositions[#compositions + 1] = {kind = kind, faction = RACES[race], race = race}
	end
end
local GATE_WIDTH = {pvp_fortress = 5, pvp_camp_low = 3, pvp_camp_high = 3}

local function profile_for(c, turns)
	local stem = "grug_r31_test_" .. c.kind .. "_" .. (c.race or c.faction)
	return {key = stem, label = stem, race = c.race or "human", slot = "pvp_test",
		bounds = "r31_" .. c.kind, lazy = true, reserve_anchor_root = true,
		zone_id = "test_zone", anchor_id = "anchor_test", numeric_id = 1, x = 0, z = 0,
		blueprint_file = "r31_pvp_poi_blueprint.lua", blueprint_schema = stem .. "_v1",
		identity_schema = stem .. "_identity_v1", config_schema = stem .. "_config_v1",
		ledger_schema = stem .. "_ledger_v1", metrics_schema = stem .. "_metrics_v1",
		delta_schema = stem .. "_delta_v1",
		art = {kind = c.kind, faction = c.faction, race = c.race, turns = turns}}
end

for _, c in ipairs(compositions) do
	local label0 = c.kind .. " " .. (c.race or c.faction)
	local count0
	for turns = 0, 3 do
		local label = label0 .. " turn " .. turns
		local profile = profile_for(c, turns)
		local bp = build({}, profile)
		local r = bp.bounds.max.x
		settlement.BOUNDS[profile.bounds] = {min = {x = -r, y = 0, z = -r},
			max = {x = r, y = bp.bounds.max.y, z = r}}
		-- 1. the validator, twice for the identity
		local ok, prepared = pcall(settlement.prepare, profile, bp, sha)
		check(ok, label .. ": r7_settlement.prepare: " .. tostring(prepared))
		local again = settlement.prepare(profile, build({}, profile), sha)
		check(again.blueprints[1].identity.sha256 == prepared.blueprints[1].identity.sha256,
			label .. ": identity is deterministic")
		if turns == 0 then count0 = #bp.cells end
		check(#bp.cells == count0, label .. ": a turn keeps the cell count")
		-- 2. registered nodes
		for _, name in ipairs(bp.palette) do
			check(registered(name), label .. ": node " .. name .. " is registered")
		end
		-- the cell grid
		local grid = {}
		for _, cell in ipairs(bp.cells) do grid[cell.x .. ":" .. cell.y .. ":" .. cell.z] = cell.name end
		local function at(x, y, z) return grid[x .. ":" .. y .. ":" .. z] end
		local function standing(x, z)
			local ground = at(x, 0, z)
			return ground ~= nil and ground ~= "air" and at(x, 1, z) == "air" and at(x, 2, z) == "air"
		end
		-- 3. sockets
		local rows = settlement.sockets(prepared, {x = 0, y = 0, z = 0})
		local seen, roles, groups = {}, {}, {}
		for _, s in ipairs(rows) do
			check(not seen[s.id], label .. ": socket id " .. s.id .. " unique")
			seen[s.id] = true
			roles[s.role] = (roles[s.role] or 0) + 1
			if s.group then groups[s.group] = (groups[s.group] or 0) + 1 end
			if s.role == "waypoint" then
				check(at(s.x, 1, s.z) == "grug_mapgen:waystone", label .. ": waystone at its socket")
			else
				check(standing(s.x, s.z), label .. ": socket " .. s.id .. " stands on ground with air above")
			end
		end
		if c.kind == "pvp_fortress" then
			check(groups.gate == 2, label .. ": two gate guards")
			check((groups.inner or 0) >= 8, label .. ": at least 8 inner elites")
			check(roles.guard_post == groups.gate + groups.inner, label .. ": guard groups")
			check(roles.general == 1 and roles.bodyguard == 2, label .. ": General and 2 bodyguards")
			check((roles.quest or 0) >= 2, label .. ": quest givers")
			check(roles.vendor == 1, label .. ": one Quartermaster")
			for _, s in ipairs(rows) do
				if s.role == "vendor" then check(s.kind == "general", label .. ": Quartermaster is the general vendor") end
			end
			check(roles.waypoint == 1 and seen.travel_waypoint, label .. ": one waystone")
			check(roles.innkeeper == nil, label .. ": no innkeeper")
		else
			local guards = c.kind == "pvp_camp_low" and 4 or 5
			check(roles.guard_post == guards and roles.captain == 1,
				label .. ": " .. guards .. " guards and a captain")
			check(groups.gate == 2, label .. ": two of them hold the gate")
		end
		-- 4. walking from outside the gate; the gate is the only way in
		local gx, gz = rot(0, -r, turns)
		check(standing(gx, gz), label .. ": the gate is open at ground level")
		local reached, queue, head = {[gx .. ":" .. gz] = true}, {{gx, gz}}, 1
		while queue[head] do
			local x, z = queue[head][1], queue[head][2]
			head = head + 1
			for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				local nx, nz = x + d[1], z + d[2]
				local k = nx .. ":" .. nz
				if not reached[k] and math.abs(nx) <= r and math.abs(nz) <= r and standing(nx, nz) then
					reached[k] = true
					queue[#queue + 1] = {nx, nz}
				end
			end
		end
		for _, s in ipairs(rows) do
			local near = reached[s.x .. ":" .. s.z]
			if s.role == "waypoint" then
				near = reached[(s.x + 1) .. ":" .. s.z] or reached[(s.x - 1) .. ":" .. s.z] or
					reached[s.x .. ":" .. (s.z + 1)] or reached[s.x .. ":" .. (s.z - 1)]
			end
			check(near, label .. ": socket " .. s.id .. " is reached from the gate")
		end
		local openings = 0
		for x = -r, r do for z = -r, r do
			if math.max(math.abs(x), math.abs(z)) == r and standing(x, z) then
				openings = openings + 1
				-- 5. the opening lies on the turned gate side
				local lx, lz = rot(x, z, (4 - turns) % 4)
				check(lz == -r and math.abs(lx) <= (GATE_WIDTH[c.kind] - 1) / 2,
					label .. ": ground opening only at the gate (" .. x .. "," .. z .. ")")
			end
		end end
		check(openings == GATE_WIDTH[c.kind], label .. ": the gate is " .. GATE_WIDTH[c.kind] .. " wide")
		if turns == 0 then
			print(("  %-26s %2dx%-2d h%-2d %5d cells %3d names, %2d sockets, sha %s"):format(label0,
				2 * r + 1, 2 * r + 1, bp.bounds.max.y, #bp.cells, #bp.palette, #rows,
				prepared.blueprints[1].identity.sha256:sub(1, 12)))
		end
	end
end

-- Stage 1: nothing registers or places these blueprints yet.
for _, profile in ipairs(settlement.roster) do
	check(profile.blueprint_file ~= "r31_pvp_poi_blueprint.lua", "no roster row builds a PvP POI in stage 1")
end
for _, row in ipairs(dofile(dir .. "/r20_poi_catalog.lua")) do
	check(not tostring(row.kind):find("^pvp_"), "no catalogue row is a PvP POI in stage 1")
end
print(("R31 S PORTABLE PASS checks=%d"):format(checks))
