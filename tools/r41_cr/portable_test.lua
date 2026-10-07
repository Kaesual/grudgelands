-- Round 41 lane CR portable fixture (LuaJIT): the production mapgen crash.
--
--   luajit tools/r41_cr/portable_test.lua REPO
--
-- On the real runtime of the production realm's seed (tools/seed_fleet/
-- runtime.lua) and its crash candidate (22,-1,-32), whose plan is a fill-void
-- band y -37..-33 under the anchor_003 grade:
-- 1. grug_core:water_barrier in the chunk's top layer (y -33), the content
--    the water guard leaves there before the chunk is generated, over cave
--    air (the liquid neighbour scan) and in rock: the writer fills it like
--    air.
-- 2. A foreign node and an unknown content id there: the writer still fails
--    (what the seed fleet and the fixtures see), naming the voxel; through
--    the engine path (wp40/degrade.lua) the chunk keeps the engine's
--    terrain, one [GRUG-SEVERE] line is logged, and the chat message reaches
--    the players once per chunk through gen_notify (grug_core/severe.lua).
-- 3. A failure after the first VoxelManip setter puts the engine's bytes
--    back; the next chunk still writes.
-- 4. The severe helper in the main environment: one log line per report, the
--    red chat message once per key.
-- Prints "R41 CR PORTABLE PASS checks=<n>" or raises.
local repo = assert(arg and arg[1], "usage: luajit portable_test.lua REPO")
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
	print("ok   " .. label)
end

local SEED = "3684797457838814663"
local MINP = {x = 1728, y = -112, z = -2592}
local MAXP = {x = 1807, y = -33, z = -2513}
local TOP = -33

-- Two Lua environments as the engine has them: the mapgen one (log and
-- save_gen_notify, no chat) and the main one (log, chat, gen_notify relay).
local logs, chats, notify, generated = {}, {}, {}, {}
local mapgen_core = {
	log = function(level, text) logs[#logs + 1] = {level, text} end,
	save_gen_notify = function(id, data)
		local copy = {}
		for key, value in pairs(data) do copy[key] = value end
		notify[id] = copy
		return true
	end,
}
local requested
local main_core = {
	log = mapgen_core.log,
	colorize = function(color, text) return "(c@" .. color .. ")" .. text end,
	chat_send_all = function(text) chats[#chats + 1] = text end,
	set_gen_notify = function(flags, _, custom) requested = {flags, custom} end,
	register_on_generated = function(fn) generated[#generated + 1] = fn end,
	get_mapgen_object = function(kind)
		assert(kind == "gennotify")
		return {custom = notify}
	end,
}
local function in_env(env, fn, ...)
	local saved = rawget(_G, "core")
	_G.core = env
	local results = {pcall(fn, ...)}
	_G.core = saved
	if not results[1] then error(results[2], 0) end
	return unpack(results, 2)
end
local severe_path = repo .. "/mods/CORE/grug_core/severe.lua"
local severe_mapgen = in_env(mapgen_core, dofile, severe_path)
local severe_main = in_env(main_core, dofile, severe_path)
in_env(main_core, severe_main.install_main)
check(requested and requested[1].custom == true and
	requested[2][1] == "grug_core:severe" and #generated == 1,
	"install_main requests the gen_notify entry and relays from on_generated")
-- The main environment's on_generated after a chunk (the engine clears the
-- custom data after every chunk).
local function main_on_generated()
	in_env(main_core, generated[1], MINP, MAXP, 0)
	notify = {}
end
local function severe_lines()
	local count, last = 0, nil
	for _, entry in ipairs(logs) do
		if entry[1] == "error" and entry[2]:sub(1, 13) == "[GRUG-SEVERE]" then
			count, last = count + 1, entry[2]
		end
	end
	return count, last
end

local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, SEED)
local session, writer, fake = R.built.session, R.built.writer, R.fake
local barrier = fake.get_content_id("grug_core:water_barrier")
local stone = fake.get_content_id("default:stone")
local air = fake.CONTENT_AIR
local foreign = fake.get_content_id("default:cobble")
local UNKNOWN_CID = 999
check(fake.registered_nodes["grug_core:water_barrier"].groups.grug_air == 1,
	"the fleet runtime carries the real water barrier (group grug_air)")

local function index_at(x, y, z)
	return (z - (MINP.z - 16)) * 12544 + (y - (MINP.y - 16)) * 112 +
		(x - (MINP.x - 16)) + 1
end
-- Two neighbouring rock columns of the top layer, A and B = A + (1, 0, 0).
-- A gets an opening (air at y -33, as cave or flooded air there): the band
-- fills it first, and its neighbour scan reaches B, as in the production
-- trace (final_neighbor). A stays off the chunk's -x edge: there the scan
-- ends at the first face, outside the owner.
local probe = R.new_vm(MINP)
local column_a
for z = MINP.z + 1, MAXP.z do
	for x = MINP.x + 1, MAXP.x - 1 do
		if not column_a and probe.native.data[index_at(x, TOP, z)] == stone and
				probe.native.data[index_at(x + 1, TOP, z)] == stone and
				probe.native.data[index_at(x, TOP - 1, z)] == stone and
				probe.native.data[index_at(x + 1, TOP - 1, z)] == stone then
			column_a = {x, z}
		end
	end
end
check(column_a ~= nil, "the chunk has two neighbouring rock columns in its top layer")
local column_b = {column_a[1] + 1, column_a[2]}

-- The fake VoxelManip with top-layer voxels replaced ({column, cid,
-- walkable}); a node that is not walkable lowers the column's heightmap entry
-- as v7's findGroundLevel would (the harness's ground is its stone).
local function vm_with(edits)
	local vm = R.new_vm(MINP)
	local heightmap = fake.get_mapgen_object("heightmap")
	for _, edit in ipairs(edits) do
		local x, z = edit[1][1], edit[1][2]
		vm.native.data[index_at(x, TOP, z)] = edit[2]
		if not edit[3] then
			local ground = -31007
			for y = TOP - 1, MINP.y, -1 do
				if vm.native.data[index_at(x, y, z)] == stone then ground = y break end
			end
			heightmap[(z - MINP.z) * 80 + (x - MINP.x) + 1] = ground
		end
	end
	return vm
end
local function write(vm)
	local plan, generation = session.plan_slice(MINP, MAXP)
	return writer.apply(vm, MINP, MAXP, plan, generation)
end

-- 1. The barrier is filled like air.
for _, case in ipairs({
		{"alone in rock", {{column_b, barrier, false}}},
		{"beside an opening", {{column_a, air, false}, {column_b, barrier, false}}},
		{"in an opening", {{column_a, barrier, false}, {column_b, air, false}}}}) do
	local vm = vm_with(case[2])
	local ok, result = pcall(write, vm)
	local filled = ok and vm.written.data ~= nil
	for _, edit in ipairs(case[2]) do
		local final = filled and vm.written.data[index_at(edit[1][1], TOP, edit[1][2])]
		filled = filled and final ~= barrier and final ~= air
	end
	check(ok and type(result) == "string" and filled,
		"a barrier in the top layer " .. case[1] .. " is filled like air (" ..
		tostring(result) .. ")")
end

-- 2. A foreign node and an unknown content id: the writer fails; the engine
-- path degrades and reports once.
local degrade = in_env(mapgen_core, dofile,
	repo .. "/mods/MAPGEN/grug_mapgen/wp40/degrade.lua")
local run = degrade(severe_mapgen, fake.get_name_from_content_id)
local function refine(vm, minp, maxp)
	local plan, generation = session.plan_slice(minp, maxp)
	writer.apply(vm, minp, maxp, plan, generation)
end
for _, case in ipairs({{foreign, "foreign", "default:cobble"},
		{UNKNOWN_CID, "unknown", nil}}) do
	local cid, class, name = case[1], case[2], case[3]
	local where = ("at (%d,%d,%d)"):format(column_b[1], TOP, column_b[2])
	local edits = {{column_a, air, false}, {column_b, cid, true}}
	local ok, err = pcall(write, vm_with(edits))
	err = tostring(err)
	check(not ok and err:find("fail_replace_policy", 1, true) and
		err:find(where, 1, true) and err:find("class=" .. class, 1, true) and
		err:find("policy=fill_void", 1, true) and err:find("opcode=21", 1, true) and
		err:find("feature=anchor_003", 1, true) and
		err:find("final_neighbor", 1, true),
		"a " .. class .. " node fails the writer (fleet and fixtures), named " ..
		"through the neighbour scan")
	logs, chats = {}, {}
	local vm = vm_with(edits)
	local degraded = in_env(mapgen_core, run, refine, vm, MINP, MAXP)
	local count, line = severe_lines()
	check(degraded == false and vm.written.data == nil and vm.written.param2 == nil,
		"the engine path keeps the engine's terrain for the " .. class .. " node")
	check(count == 1 and line:find("minp=(1728,-112,-2592) maxp=(1807,-33,-2513)",
			1, true) and line:find(where, 1, true) and
		line:find("class=" .. class, 1, true) and
		(name == nil or line:find("node=" .. name, 1, true)),
		"one [GRUG-SEVERE] line names chunk, voxel, class and node (" .. class .. ")")
	check(#chats == 0 and notify["grug_core:severe"] ~= nil,
		"the mapgen environment hands the chat part to gen_notify")
	local saved = notify["grug_core:severe"]
	main_on_generated()
	if class == "foreign" then
		check(#chats == 1 and chats[1]:find("(c@#ff4040)", 1, true) and
			chats[1]:find("(1728,-112,-2592)", 1, true),
			"every player sees one red chat message for the failing chunk")
		-- The same report relayed again shows nothing new.
		notify["grug_core:severe"] = saved
		main_on_generated()
		check(#chats == 1, "a second relay of the same chunk adds no chat message")
	else
		-- The same chunk failing again (here with other content) logs again
		-- but shows no second chat message.
		check(#chats == 0, "a later failure of the same chunk adds no chat message")
	end
end

-- 3. A failure after the first setter restores the engine's bytes; the next
-- chunk still writes.
do
	local vm = R.new_vm(MINP)
	local native_hash = R.written_hash(vm)
	vm.update_liquids = function() error("engine refused", 0) end
	local ok, err = pcall(write, vm)
	check(not ok and tostring(err):find("update_liquids failed", 1, true) and
		vm.written.data ~= nil and R.written_hash(vm) == native_hash,
		"a late writer failure puts the engine's content and param2 back")
	local next_ok, next_result = pcall(R.chunk, {x = 1888, y = -112, z = -2592})
	check(next_ok and type(next_result.result) == "string",
		"the next chunk writes after the failures (" ..
		tostring(next_ok and next_result.result or next_result) .. ")")
end

-- 4. The helper in the main environment.
do
	logs, chats = {}, {}
	local line = in_env(main_core, severe_main.report, "test", "a summary",
		"a=1\nb=2", "key")
	in_env(main_core, severe_main.report, "test", "a summary", "a=1", "key")
	in_env(main_core, severe_main.report, "test", "another", nil, "other key")
	local count = severe_lines()
	check(line == "[GRUG-SEVERE] test: a summary | a=1 | b=2" and count == 3,
		"every report is one [GRUG-SEVERE] error line (newlines folded)")
	check(#chats == 2, "the red chat message shows once per key")
end

print("R41 CR PORTABLE PASS checks=" .. checks)
