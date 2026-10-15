-- Round 47 lane OR portable test (LuaJIT): the lower-half rule and the
-- Bronze gate (plan §3 and §4.5, rulings 6 and 7).
--
--   luajit tools/r47_or/portable_test.lua REPO
--
--   1. The level scale: Wood and Stone picks maxlevel 0, a metal pick of
--      tier t maxlevel t, tier-N nodes level N (none at tier 1), Iron Ore
--      level 1; the tooltips and hints name the Bronze pick for Iron.
--   2. Dig times kept: every pick, axe and shovel on every node the Round 24
--      mining harness registers digs exactly as in the engine's matrix of
--      main before this lane (evidence/dig_matrix_before.tsv, written by
--      run_dig.sh through core.get_dig_params), except Iron Ore with the
--      Wood and Stone picks, which no longer dig it.
--   3. The WP43 projection: the live graph hashes to the pin in
--      r7_manifest.lua (tools/r24_mining checks that too), and the same
--      graph without this lane's two fields hashes to the old pin, so
--      nothing else moved.
--   4. The rows: Iron, Silver, Emberglass and Abyssal Crystal carry
--      `lower_half_of` (T1, T3, T4, T5), nothing else does; the real R6
--      content module accepts them and refuses a row without, a row with an
--      extra one and a band without its half boundary.
--   5. The generator (Round 49): the native scatter rows of a lower-half
--      resource end at their band's half, a whole-band ore spans the band,
--      and the writer's fill ores put T1 Iron only below T1's half.
-- Prints "R47 OR PORTABLE PASS checks=<n>" or raises.

local repo = assert(arg and arg[1], "usage: luajit portable_test.lua REPO")
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

_G.R24_MINING_HARNESS = true
local H = dofile(repo .. "/tools/r24_mining/fixture.lua")
_G.R24_MINING_HARNESS = nil
local M = grug_materials

-- 1. The level scale --------------------------------------------------------
local METAL = {"bronze", "iron", "steel", "silversteel", "embersteel", "abyssal_steel"}
local function caps(name) return H.items[name].tool_capabilities end
for _, row in ipairs({{"wood", 0}, {"stone", 0}}) do
	for _, group in ipairs({"cracky", "grug_resource", "grug_pick_level"}) do
		check(caps("grug_materials:pick_" .. row[1]).groupcaps[group].maxlevel == row[2],
			row[1] .. " pick " .. group .. " maxlevel 0")
	end
end
for tier, key in ipairs(METAL) do
	for _, group in ipairs({"cracky", "grug_resource", "grug_pick_level"}) do
		check(caps("grug_materials:pick_" .. key).groupcaps[group].maxlevel == tier,
			key .. " pick " .. group .. " maxlevel " .. tier)
	end
end
for tier = 1, 6 do
	local level = H.nodes[M.TIERS[tier].node].groups.level
	check((level or 0) == (tier > 1 and tier or 0), "T" .. tier .. " rock level")
end
local LEVEL_BY_KEY = {coal = 0, copper = 0, tin = 0, quartz = 0, citrine = 0, iron = 1,
	gold = 2, jade = 2, silver = 3, garnet = 3, emberglass = 4, sapphire = 4,
	abyssal_crystal = 5, ruby = 5, diamond = 6,
	anthracite = 2} -- Round 47 lane AN: Anthracite needs the Iron pick
for _, resource in ipairs(M.RESOURCES) do
	local groups = H.nodes[resource.natural_node].groups
	check((groups.level or 0) == LEVEL_BY_KEY[resource.key] and
		(groups.grug_pick_level or 0) == LEVEL_BY_KEY[resource.key] and
		M.resource_level(resource) == LEVEL_BY_KEY[resource.key],
		resource.key .. " level " .. LEVEL_BY_KEY[resource.key])
end
check(M.RESOURCE_BY_KEY.iron.harvest_tier == 1, "Iron stays a T1 resource")
check(M.pick_requirement(0) == "Requires a T1 pick" and
	M.pick_requirement(1) == "Requires a Bronze pick" and
	M.pick_requirement(4) == "Requires a T4 pick", "pick requirement lines")
check(H.nodes["default:stone_with_iron"].description == "Iron Ore\nRequires a Bronze pick",
	"Iron Ore tooltip")
check(H.nodes["default:stone_with_gold"].description == "Gold Ore\nRequires a T2 pick" and
	H.nodes["grug_materials:t3_stone"].description == "Stone\nRequires a T3 pick" and
	H.nodes["default:stone"].description == "Stone\nRequires a T1 pick",
	"the other tooltips keep their line")

-- 2. Dig times kept ---------------------------------------------------------
local function read(path)
	local file = assert(io.open(path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end
local header, compared, changed = nil, 0, {}
local HAND = H.items[""].tool_capabilities
for line in read(repo .. "/tools/r47_or/evidence/dig_matrix_before.tsv"):gmatch("[^\n]+") do
	local cells = {}
	for cell in (line .. "\t"):gmatch("([^\t]*)\t") do cells[#cells + 1] = cell end
	if not header then
		header = cells
	elseif H.nodes[cells[1]] and not H.nodes[cells[1]].groups.dig_immediate then
		-- dig_immediate nodes (torches, saplings) bypass every tool
		-- capability; the game retunes some of them after the harness's mods.
		local groups = H.nodes[cells[1]].groups
		for column = 9, #header do
			local tool = H.items[header[column]]
			check(tool ~= nil, "tool " .. header[column] .. " registered")
			local params = H.get_dig_params(groups, tool.tool_capabilities)
			local before = cells[column] ~= "-" and tonumber(cells[column]) or nil
			local now = params.diggable and params.time or nil
			compared = compared + 1
			if (before == nil) ~= (now == nil) or
					(before and math.abs(before - now) > 0.00051) then
				changed[#changed + 1] = cells[1] .. " " .. header[column] .. " " ..
					tostring(before) .. " -> " .. tostring(now)
			end
		end
		local hand = H.get_dig_params(groups, HAND)
		check((cells[8] == "-") == not hand.diggable, cells[1] .. " hand unchanged")
	end
end
table.sort(changed)
local EXPECTED_CHANGES = {
	"default:stone_with_iron grug_materials:pick_stone 1 -> nil",
	"default:stone_with_iron grug_materials:pick_wood 1.6 -> nil",
}
check(compared > 3000, "dig pairs compared: " .. compared)
check(#changed == #EXPECTED_CHANGES, "changed pairs (" .. #changed .. "): " ..
	table.concat(changed, "; ", 1, math.min(#changed, 12)))
for index, label in ipairs(EXPECTED_CHANGES) do
	check(changed[index] == label, "changed pair " .. label)
end
print(("dig times: %d pairs compared, %d changed"):format(compared, #changed))

-- 3. The WP43 projection pin moves by this lane's two fields only -------------
local ok_ffi = pcall(require, "ffi")
if ok_ffi then
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local raw_sha256 = common.new_sha256()
	local canonical = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/canonical.lua")
	local function typed_graph(value)
		local kind = type(value)
		if kind == "string" then return canonical.bytes(value) end
		if kind == "boolean" then return canonical.boolean(value) end
		if kind == "number" then
			if value < 0 then return canonical.signed(value) end
			return canonical.unsigned(value)
		end
		local count, array, key_count = #value, true, 0
		for k in pairs(value) do
			key_count = key_count + 1
			if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > count then array = false end
		end
		if key_count ~= count then array = false end
		if array then
			local children = {}
			for index = 1, count do children[index] = typed_graph(value[index]) end
			return canonical.array(children)
		end
		local pairs_array = {}
		for k, child in pairs(value) do
			pairs_array[#pairs_array + 1] = {typed_graph(k), typed_graph(child)}
		end
		return canonical.map(pairs_array)
	end
	local function digest(graph)
		return canonical.hex(canonical.checksum(typed_graph(graph), raw_sha256))
	end
	local handoff = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp43_handoff.lua")
	local projection = handoff.project(M)
	handoff.validate_public(M, projection)
	local pinned = read(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_manifest.lua"):match(
		"frozen%.wp43_projection ~=%s*\"(%x+)\"")
	check(digest(projection) == pinned, "live projection matches its pin")
	for _, tier in ipairs(projection.tiers) do tier.lower_half_y_max = nil end
	for _, resource in ipairs(projection.resources) do resource.pick_level = nil end
	-- Round 47 lane AN adds the Anthracite row; without it the rest is unchanged.
	for index = #projection.resources, 1, -1 do
		if projection.resources[index].key == "anthracite" then
			table.remove(projection.resources, index)
		end
	end
	-- Round 47 lane SW adds the swamp's three new grounds to the natural
	-- ground list; without them the rest is unchanged.
	local SWAMP = {["grug_nodes:mud_dry"] = true, ["grug_nodes:mud_mottled"] = true,
		["grug_nodes:mud_with_wet_grass"] = true}
	for index = #projection.natural_ground_nodes, 1, -1 do
		if SWAMP[projection.natural_ground_nodes[index]] then
			table.remove(projection.natural_ground_nodes, index)
		end
	end
	check(digest(projection) ==
		"dccd68e9032403bcea294efd2035165501043ab1aa008561cad5547eb2e2c7c7",
		"the projection without lower_half_y_max, pick_level and Anthracite is the Round 46 pin")
else
	print("note: no ffi, pin section skipped")
end

-- 4. The rows and the R6 content checks -----------------------------------------
local HALF = {iron = 1, silver = 3, emberglass = 4, abyssal_crystal = 5,
	anthracite = 2} -- Round 47 lane AN: Anthracite in T2's lower half
local manifest = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_r6_manifest.lua")()
for _, row in ipairs(manifest.resources) do
	check(row.lower_half_of == HALF[row.key], row.key .. " lower half " ..
		tostring(HALF[row.key]))
end
local half_y = {-50, -201, -401, -601, -851}
for tier = 1, 6 do
	check(M.TIERS[tier].lower_half_y_max == half_y[tier], "T" .. tier .. " half boundary")
end
local B = dofile(repo .. "/tools/r23_tree_line/harness.lua").new(repo)
check(pcall(B.content), "R6 content accepts the lower-half rows")
local by_key = {}
for _, row in ipairs(B.manifest.resources) do by_key[row.key] = row end
local function refused(mutate, restore, label)
	mutate()
	local ok, err = pcall(B.content)
	restore()
	check(not ok and tostring(err):find("resource", 1, true) ~= nil,
		label .. " (got " .. (ok and "no error" or tostring(err)) .. ")")
end
refused(function() by_key.iron.lower_half_of = nil end,
	function() by_key.iron.lower_half_of = 1 end, "Iron without its lower half is refused")
refused(function() by_key.copper.lower_half_of = 1 end,
	function() by_key.copper.lower_half_of = nil end, "Copper in a lower half is refused")
refused(function() by_key.silver.lower_half_of = 4 end,
	function() by_key.silver.lower_half_of = 3 end, "Silver halved in the wrong band is refused")
refused(function() B.projection.tiers[4].lower_half_y_max = nil end,
	function() B.projection.tiers[4].lower_half_y_max = -601 end,
	"a band without its half boundary is refused")
refused(function() B.projection.tiers[1].lower_half_y_max = 0 end,
	function() B.projection.tiers[1].lower_half_y_max = -50 end,
	"a half boundary at the band's top is refused")
check(pcall(B.content), "R6 content accepts the restored rows")

-- 5. The half boundaries in the generator ---------------------------------------
-- Round 49 (lane ORE): native v7 places the ores of native rock, so the rule
-- lives in the native scatter rows (r7_native.lua): a lower-half row ends at
-- its band's half, a whole-band row spans the band; the writer's fill ores
-- (r6_settlement.lua r49_fill_ores_new, T1 only) keep T1's half too. (Until
-- Round 49 this section ran the writer across the four half chunks.)
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local sha = common.new_sha256()
local saved_core = rawget(_G, "core")
_G.core = {sha256 = function(bytes) return common.hex(sha(bytes)) end}
local rows = dofile(wp40 .. "/r7_native.lua").population(wp40,
	dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp43_handoff.lua").project(M))
_G.core = saved_core
local function band_rows(key, tier)
	local node, found = M.RESOURCE_BY_KEY[key].natural_node, {}
	for _, row in ipairs(rows) do
		if row.ore == node and row.wherein == M.TIERS[tier].node then
			found[#found + 1] = row
		end
	end
	return found
end
local WHOLE = {[1] = "copper", [2] = "gold", [3] = "gold", [4] = "gold", [5] = "silver"}
for key, tier in pairs(HALF) do
	local found = band_rows(key, tier)
	check(#found == 1 and found[1].y_max == M.TIERS[tier].lower_half_y_max and
		found[1].y_min == M.TIERS[tier].y_min, key .. " only in the T" .. tier .. " lower half")
	local whole = band_rows(WHOLE[tier], tier)
	check(#whole == 1 and whole[1].y_min == M.TIERS[tier].y_min and
		whole[1].y_max == M.TIERS[tier].y_max, WHOLE[tier] .. " spans T" .. tier)
end
local fill_ore_at = dofile(wp40 .. "/r6_settlement.lua").r49_fill_ores_new(
	manifest.resources, M.TIERS[1], "12345")
local iron_index
for index, row in ipairs(manifest.resources) do
	if row.key == "iron" then iron_index = index end
end
local iron_upper, iron_lower, copper_upper = 0, 0, 0
for x = 0, 63 do
	for z = 0, 63 do
		for y = -100, -1 do
			local index = fill_ore_at(x, y, z)
			if index == iron_index then
				if y > M.TIERS[1].lower_half_y_max then iron_upper = iron_upper + 1
				else iron_lower = iron_lower + 1 end
			elseif index and manifest.resources[index].key == "copper" and y > -50 then
				copper_upper = copper_upper + 1
			end
		end
	end
end
print(("fill ores T1: iron upper %d lower %d, copper upper %d"):format(iron_upper,
	iron_lower, copper_upper))
check(iron_upper == 0 and iron_lower > 0, "fill iron only in the T1 lower half")
check(copper_upper > 0, "fill copper above the T1 half")

print("R47 OR PORTABLE PASS checks=" .. checks)
