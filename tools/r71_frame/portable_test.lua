-- Round 71 lane FRAME portable test (LuaJIT). Prints "R71 FRAME PORTABLE PASS
-- checks=<n>".
--
--   luajit tools/r71_frame/portable_test.lua [REPO]
--
-- A-D. The catalogue and the template reader as they ship.
-- E. The chunks of a preparation, for all 100 slots.
-- F. The shipped mod on a fake engine whose map generates whole chunks the way
--    emerge.cpp does: the preparation's order, its budget per step, refused
--    emerges, the gate, one at a time, a run ended mid-way.
-- G. Create, enter and their refusals (concept section 4).
-- H. Changes of owner and who is teleported out.
-- I. The 10-minute release.
-- J. The login rule.
-- K. Both waystones and Return Home.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local C = dofile(repo .. "/mods/PLAYER/grug_expeditions/catalogue.lua")

-- A. Slots: 100, mapblock aligned, apart, found again by arithmetic.
check(C.SLOTS == 100, "A 100 slots")
local minp, maxp = C.slot_box(1)
check(minp.x == 8064 and minp.y == -112 and minp.z == -1616, "A the first corner")
check(maxp.x == 8191 and maxp.y == -49 and maxp.z == -1489, "A the first box is 128 x 64 x 128")
minp, maxp = C.slot_box(100)
check(minp.x == 8064 + 320 * 9 and minp.z == -1616 + 320 * 9, "A the last corner")
for slot = 1, C.SLOTS do
	local a, b = C.slot_box(slot)
	check(a.x % 16 == 0 and a.y % 16 == 0 and a.z % 16 == 0, "A aligned " .. slot)
	check(C.slot_at(a) == slot and C.slot_at(b) == slot, "A corners of " .. slot)
	check(C.slot_at({x = a.x + 0.4, y = a.y + 3.2, z = b.z}) == slot, "A a float position")
	check(not C.slot_at({x = a.x - 1, y = a.y, z = a.z}), "A west of " .. slot)
	check(not C.slot_at({x = b.x + 1, y = a.y, z = a.z}), "A east of " .. slot)
	check(not C.slot_at({x = a.x, y = a.y - 1, z = a.z}), "A below " .. slot)
	check(not C.slot_at({x = a.x, y = b.y + 1, z = a.z}), "A above " .. slot)
	check(not C.slot_at({x = a.x, y = a.y, z = b.z + 1}), "A north of " .. slot)
end
check(not C.slot_at({x = 0, y = -80, z = 0}), "A the map holds no slot")
check(not C.slot_at({x = 8064 + 3200, y = -80, z = -1616}), "A beyond the grid")

-- B. The entry level.
check(C.entry_level(20) == 18 and C.entry_level(21) == 19 and C.entry_level(22) == 20, "B below 60")
check(C.entry_level(60) == 58 and C.entry_level(61) == 59, "B 60 and 61")
for level = 62, 69 do check(C.entry_level(level) == 60, "B the ceiling at " .. level) end

-- C. The catalogue's rows.
for _, row in ipairs(C.EXPEDITIONS) do
	check(row.id and row.name and row.level and row.max_players and row.template, "C row " .. row.id)
	check(row.max_level and row.max_level >= row.level, "C a level range in " .. row.id)
end
check(C.definition("test_vault").max_players == 3, "C the test row")
for _, row in ipairs(C.list()) do check(not row.hidden, "C list leaves hidden rows out") end

-- D. The template reader, on the shipped test template through zlib.
local T = dofile(repo .. "/mods/PLAYER/grug_expeditions/template.lua")
local _, ffi = pcall(require, "ffi")
ffi.cdef[[int uncompress(uint8_t *dest, unsigned long *destLen, const uint8_t *src, unsigned long srcLen);]]
local zlib = ffi.load("z")
local function inflate(bytes)
	local out, size = ffi.new("uint8_t[?]", 4194304), ffi.new("unsigned long[1]", 4194304)
	assert(zlib.uncompress(out, size, bytes, #bytes) == 0)
	return ffi.string(out, size[0])
end
local file = assert(io.open(repo .. "/mods/PLAYER/grug_expeditions/templates/test_vault.exp", "rb"))
local text = file:read("*a")
file:close()
local tpl = T.parse(text, inflate, "test_vault")
T.check_fits(tpl, C.BOX, {"arrival", "start_waystone", "end_waystone"}, "test_vault")
check(tpl.name == "test_vault" and tpl.size.x == 48 and tpl.size.y == 32 and tpl.size.z == 48, "D the head")
-- Three markers since lane MOBS added the test boss.
check(tpl.places.start_waystone.x == 8 and #tpl.encounters == 3, "D places and markers")
check(tpl.encounters[1].mob == "grug_mobs:giant_spider" and tpl.encounters[1].count == 2 and
	tpl.encounters[2].tier == "elite" and tpl.encounters[2].room == "hall", "D a marker's fields")
local function cell(pos)
	local at = pos.z * tpl.size.y * tpl.size.x + pos.y * tpl.size.x + pos.x + 1
	return tpl.nodes[tpl.cells:byte(at) + 1]
end
check(cell(tpl.places.start_waystone) == "grug_expeditions:waystone", "D the stone's cell")
check(cell(tpl.places.arrival) == "air" and cell({x = 0, y = 0, z = 0}) == "default:stonebrick", "D cells")

local function refused(head, needle)
	local ok, message = pcall(T.parse, head, inflate, "bad")
	check(not ok and message:find(needle, 1, true), "D refused: " .. needle .. " got " .. tostring(message))
end
refused("nonsense\n", "not a version 1")
refused("grudgelands-expedition-template 1\nname x\n", "data line")
refused("grudgelands-expedition-template 1\nsize 1 2\ndata 0\n", "malformed")
refused("grudgelands-expedition-template 1\ndata 9\nabc", "cut short")
local big = {size = {x = 144, y = 16, z = 16}, places = {}, encounters = {}}
check(not pcall(T.check_fits, big, C.BOX, {}, "big"), "D too wide")
big.size = {x = 20, y = 16, z = 16}
check(not pcall(T.check_fits, big, C.BOX, {}, "big"), "D not on mapblocks")
big.size = {x = 16, y = 16, z = 16}
check(not pcall(T.check_fits, big, C.BOX, {"arrival"}, "big"), "D a required place")

-- E. Chunks: 8 for every slot, everything round the box covered, and every chunk
-- holding a block of the box asked by a block of the box.
local function chunk_min(v) return 80 * math.floor((v + 32) / 80) - 32 end
for slot = 1, C.SLOTS do
	local a, b = C.slot_box(slot)
	local chunks = C.chunks_of(slot)
	check(#chunks == 8, "E eight chunks in " .. slot)
	local seen = {}
	for _, at in ipairs(chunks) do
		check((at.x + 32) % 80 == 40 and (at.y + 32) % 80 == 40 and (at.z + 32) % 80 == 40, "E a centre")
		seen[chunk_min(at.x) .. "," .. chunk_min(at.y) .. "," .. chunk_min(at.z)] = at
	end
	for x = a.x - 16, b.x + 16, 16 do
		for y = a.y - 16, b.y + 16, 16 do
			for z = a.z - 16, b.z + 16, 16 do
				local key = chunk_min(x) .. "," .. chunk_min(y) .. "," .. chunk_min(z)
				local at = seen[key]
				check(at, "E covers " .. key)
				if x >= a.x and x <= b.x and y >= a.y and y <= b.y and z >= a.z and z <= b.z then
					check(C.slot_at(at) == slot, "E the centre of a box chunk is in the box " .. key)
				end
			end
		end
	end
end

-- F-K. The shipped mod on a fake engine.
local chat, feeds, afters, emerges, objects = {}, {}, {}, {}, {}
local map, op_log, step_ops = {}, {}, {}
local tick_count, clock = 0, 0
local refuse_emerges, fail_all = 0, false
local players = {}
local function block_key(pos)
	local x, y, z = math.floor(pos.x / 16), math.floor(pos.y / 16), math.floor(pos.z / 16)
	return x .. "," .. y .. "," .. z
end
local function generate_chunk(pos)
	local x0, y0, z0 = chunk_min(pos.x), chunk_min(pos.y), chunk_min(pos.z)
	for x = 0, 64, 16 do
		for y = 0, 64, 16 do
			for z = 0, 64, 16 do
				map[block_key({x = x0 + x, y = y0 + y, z = z0 + z})] = true
			end
		end
	end
end
vector = {
	new = function(a, b, c)
		if type(a) == "table" then return {x = a.x, y = a.y, z = a.z} end
		return {x = a, y = b, z = c}
	end,
	offset = function(p, x, y, z) return {x = p.x + x, y = p.y + y, z = p.z + z} end,
}
function VoxelManip()
	local vm = {}
	function vm:read_from_map(a) self.at = a end
	function vm:set_data() end
	function vm:set_param2_data() end
	function vm:write_to_map(light)
		check(light == true, "F the engine's light")
		op_log[#op_log + 1] = {"write", self.at}
		step_ops.write = (step_ops.write or 0) + 1
		check(map[block_key(self.at)], "F a write on a generated block")
	end
	return vm
end
local deleted = 0
local callbacks = {}
core = {
	EMERGE_CANCELLED = 0, EMERGE_ERRORED = 1, EMERGE_FROM_MEMORY = 2, EMERGE_FROM_DISK = 3,
	EMERGE_GENERATED = 4,
	settings = {get = function() return nil end},
	registered_nodes = setmetatable({}, {__index = function() return {} end}),
	get_current_modname = function() return "grug_expeditions" end,
	get_modpath = function() return repo .. "/mods/PLAYER/grug_expeditions" end,
	log = function() end,
	get_content_id = function() return 7 end,
	decompress = function(bytes) return inflate(bytes) end,
	pos_to_string = function(p) return p.x .. "," .. p.y .. "," .. p.z end,
	chat_send_player = function(name, text) chat[#chat + 1] = {name, text} end,
	get_player_by_name = function(name) return players[name] and players[name].online and players[name] end,
	after = function(delay, fn) afters[#afters + 1] = {at = clock + delay, fn = fn} end,
	emerge_area = function(p1, p2, fn) emerges[#emerges + 1] = {p1, p2, fn} end,
	delete_area = function(a, b)
		check(b.x - a.x == 15 and b.y - a.y == 15 and b.z - a.z == 15, "F one mapblock a call")
		map[block_key(a)] = nil
		deleted = deleted + 1
		step_ops.delete = (step_ops.delete or 0) + 1
		op_log[#op_log + 1] = {"delete", a}
		return true
	end,
	objects_in_area = function()
		local i = 0
		return function()
			i = i + 1
			return objects[i]
		end
	end,
	register_node = function(name, def) core.registered_nodes[name] = def; rawset(core.registered_nodes, name, def) end,
	register_on_mods_loaded = function(fn) callbacks.loaded = fn end,
	register_on_joinplayer = function(fn) callbacks.join = fn end,
	register_on_leaveplayer = function(fn) callbacks.leave = fn end,
}
default = {node_sound_stone_defaults = function() return {} end}
grug_xp = {get_level = function(player) return player.level end}
grug_core = {in_combat = function(player) return player.combat end,
	feed = function(player, kind, text, key)
		feeds[#feeds + 1] = {name = player:get_player_name(), kind = kind, text = text, key = key}
		return true
	end}

-- Parties: register_on_member_left and the emit after it, as grug_parties does.
local party_left, party_change, parties, party_of_name, next_party = {}, {}, {}, {}, 0
local function view(name)
	local id = party_of_name[name]
	if not id then return nil end
	local group = parties[id]
	local rows = {}
	for i, member in ipairs(group.members) do
		rows[i] = {name = member, level = players[member].level, online = players[member].online}
	end
	return {id = id, leader = group.leader, members = rows}
end
grug_parties = {
	view = view,
	register_on_member_left = function(fn) party_left[#party_left + 1] = fn end,
	register_on_change = function(fn) party_change[#party_change + 1] = fn end,
}
local function emit(names)
	for _, name in ipairs(names) do
		for _, fn in ipairs(party_change) do fn(name, "membership") end
	end
end
local function join(leader, member)
	local id = party_of_name[leader]
	if not id then
		next_party = next_party + 1
		id = tostring(next_party)
		parties[id] = {leader = leader, members = {leader}}
		party_of_name[leader] = id
	end
	table.insert(parties[id].members, member)
	party_of_name[member] = id
	emit(parties[id].members)
end
local function leave_party(name)
	local id = party_of_name[name]
	local group = parties[id]
	local names = {}
	for i, member in ipairs(group.members) do names[i] = member end
	for i, member in ipairs(group.members) do
		if member == name then table.remove(group.members, i); break end
	end
	party_of_name[name] = nil
	local last
	if #group.members == 1 then
		last = group.members[1]
		party_of_name[last] = nil
		parties[id] = nil
	elseif group.leader == name then
		group.leader = group.members[1]
	end
	for _, fn in ipairs(party_left) do fn(name, id, last) end
	emit(names)
end

-- grug_home: a trip lands on the next step, every teleport reports.
local teleports, home, travels = {}, {}, {}
local capital_open = true
local function teleport(player, pos)
	player.pos = pos
	player.moves = (player.moves or 0) + 1
	for _, fn in ipairs(teleports) do fn(player) end
end
local CAPITAL = {x = 100, y = 10, z = 100}
local windows = {} -- Round 72: the waystone windows the inner stones open
grug_home = {
	register_on_teleport = function(fn) teleports[#teleports + 1] = fn end,
	register_expedition_tab = function() end,
	show_waystones = function(player, origin) windows[#windows + 1] = {player = player, origin = origin} end,
	safe_arrival = function(pos) return pos end,
	waystone_pos = function(id) return id == "highcourt" and CAPITAL or nil end,
	waystone_arrival = function() return capital_open and CAPITAL or nil end,
	cancel = function(player) player.trip = nil end,
	respawn = function(player)
		player.trip = nil
		home[#home + 1] = player.name
		teleport(player, {x = 1, y = 10, z = 1})
		return true
	end,
	return_home = function(player) teleport(player, {x = 1, y = 10, z = 1}) end,
	travel = function(player, trip)
		if player.trip then return false end
		player.trip = trip
		travels[#travels + 1] = trip
		core.after(0, function()
			if player.trip ~= trip then return end
			player.trip = nil
			if not trip.check(player) then return end
			local arrival = trip.arrival(player)
			if arrival then
				teleport(player, arrival)
			elseif trip.fallback then
				trip.fallback(player)
			end
		end)
		return true
	end,
}

local function tick(dt)
	tick_count = tick_count + 1
	clock = clock + (dt or 0.09)
	step_ops = {}
	local waiting = emerges
	emerges = {}
	for _, ask in ipairs(waiting) do
		local list = {}
		for x = math.floor(ask[1].x / 16) * 16, ask[2].x, 16 do
			for y = math.floor(ask[1].y / 16) * 16, ask[2].y, 16 do
				for z = math.floor(ask[1].z / 16) * 16, ask[2].z, 16 do
					list[#list + 1] = {x = x, y = y, z = z}
				end
			end
		end
		for index, pos in ipairs(list) do
			local action
			if refuse_emerges > 0 or fail_all then
				refuse_emerges = refuse_emerges - 1
				action = core.EMERGE_CANCELLED
			elseif map[block_key(pos)] then
				action = core.EMERGE_FROM_MEMORY
			else
				generate_chunk(pos)
				action = core.EMERGE_GENERATED
			end
			ask[3](pos, action, #list - index)
		end
	end
	local due = {}
	local rest = {}
	for _, row in ipairs(afters) do
		if row.at <= clock then due[#due + 1] = row else rest[#rest + 1] = row end
	end
	afters = rest
	for _, row in ipairs(due) do row.fn() end
	check((step_ops.write or 0) <= C.BLOCKS_PER_STEP, "F writes per step")
	check((step_ops.delete or 0) <= C.BLOCKS_PER_STEP, "F deletes per step")
end
local function advance(seconds)
	local stop = clock + seconds
	while clock < stop do tick(1) end
end
local function until_state(run, state)
	for _ = 1, 2000 do
		if run.state == state then return end
		tick()
	end
	error("FAIL " .. state .. " never came, " .. run.state)
end

local function new_player(name, level)
	local p = {name = name, level = level or 20, hp = 20, online = true, pos = {x = 0, y = 10, z = 0}}
	function p:get_player_name() return self.name end
	function p:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
	function p:get_hp() return self.hp end
	function p:is_player() return true end
	p.meta = {}
	function p:get_meta()
		local meta = self.meta
		return {get_string = function(_, key) return meta[key] or "" end,
			set_string = function(_, key, value) meta[key] = value end}
	end
	players[name] = p
	return p
end
local function feed_to(name)
	for i = #feeds, 1, -1 do
		if feeds[i].name == name then return feeds[i].text end
	end
end

-- The sister lanes' parts of the mod have their own fixtures (r71_guard, r71_ui,
-- r71_mobs; traps.lua: r72_traps) and need more of the game than this harness fakes.
local load_file = dofile
local SISTERS = {["guard.lua"] = true, ["registrar.lua"] = true, ["encounters.lua"] = true,
	["chest.lua"] = true, ["loot.lua"] = true, ["traps.lua"] = true}
_G.dofile = function(file)
	if not SISTERS[file:match("[^/]+$")] then return load_file(file) end
end
dofile(repo .. "/mods/PLAYER/grug_expeditions/init.lua")
_G.dofile = load_file
local E = grug_expeditions
callbacks.loaded()
local events = {}
E.register_on_ready(function(run) events[#events + 1] = "ready " .. run.id end)
E.register_on_end(function(run, why) events[#events + 1] = "end " .. run.id .. " " .. why end)
E.register_on_enter(function(run, name) events[#events + 1] = "enter " .. name end)
E.register_on_leave(function(run, name, why) events[#events + 1] = "left " .. name .. " " .. why end)
local function saw(text)
	for _, row in ipairs(events) do
		if row == text then return true end
	end
	return false
end
local function go_in(player, run)
	assert(E.enter(player, "highcourt"))
	tick()
	check(E.run_inside(player) == run, "enter lands " .. player.name)
end

-- F. Preparing.
do
	local solo = new_player("solo")
	local stale = {is_player = function() return false end, removed = false}
	function stale:remove() self.removed = true end
	function stale.get_attach() end
	local stranger = new_player("stranger")
	stranger.pos = {x = 8070, y = -100, z = -1610}
	-- A player still in the box keeps what hangs on them: the name tag.
	local tag = {is_player = function() return false end, removed = false}
	function tag:remove() self.removed = true end
	function tag.get_attach() return stranger end
	objects = {stale, tag, stranger}
	local run = assert(E.create(solo, "test_vault", 0))
	check(run.state == "preparing" and run.slot == 1, "F starts preparing in the first slot")
	check(E.preparation(run).waiting == 0, "F waiting for its first step")
	-- the box was in use: some of it stands, as after a run
	for z = run.minp.z, run.maxp.z, 16 do map[block_key({x = run.minp.x, y = run.minp.y, z = z})] = true end
	refuse_emerges = 2
	until_state(run, "ready")
	objects = {}
	check(stale.removed and home[#home] == "stranger", "F objects out, a player sent away")
	check(not tag.removed, "F a player's name tag stays on them")
	check(deleted == 256, "F all 256 blocks deleted one by one: " .. deleted)
	local first_write
	local last_delete
	for index, row in ipairs(op_log) do
		if row[1] == "write" and not first_write then first_write = index end
		if row[1] == "delete" then last_delete = index end
	end
	check(first_write and first_write > last_delete, "F no write before the last delete")
	-- 256 for the clearing pass, 18 for the template (3 x 2 x 3 mapblocks)
	local writes = 0
	for _, row in ipairs(op_log) do
		if row[1] == "write" then writes = writes + 1 end
	end
	check(writes == 256 + 18, "F clearing pass and template: " .. writes)
	check(saw("ready " .. run.id), "F the ready hook")
	local margin_ok = true
	local a, b = run.minp, run.maxp
	for x = a.x - 16, b.x + 16, 16 do
		for y = a.y - 16, b.y + 16, 16 do
			for z = a.z - 16, b.z + 16, 16 do
				margin_ok = margin_ok and map[block_key({x = x, y = y, z = z})] == true
			end
		end
	end
	check(margin_ok, "F every block round the box generated")
	E.end_run(run, "test")
	check(E.run_at(run.minp) == nil and not E.run_of(solo), "F end_run frees")

	-- A centre that kept its block regenerates nothing: the gate must catch the rest.
	-- (The real catalogue has none; the fake map shows the gate holds on its own.)
	local gate_run = assert(E.create(solo, "test_vault", 0))
	local real_delete = core.delete_area
	local spared = {x = 8088, y = -72, z = -1592}
	core.delete_area = function(p, q)
		if block_key(p) == block_key(spared) then return true end
		return real_delete(p, q)
	end
	until_state(gate_run, "ready")
	core.delete_area = real_delete
	local all = true
	for x = 8064, 8191, 16 do
		for y = -112, -49, 16 do
			for z = -1616, -1489, 16 do all = all and map[block_key({x = x, y = y, z = z})] == true end
		end
	end
	check(all, "F the gate made the chunk whole")
	E.end_run(gate_run, "test")

	-- One at a time; a second waits; the first ended mid-way frees the queue.
	local a_player, b_player = new_player("first"), new_player("second")
	local one = assert(E.create(a_player, "test_vault", 0))
	local two = assert(E.create(b_player, "test_vault", 0))
	check(one.slot == 1 and two.slot == 2, "F the first free slots")
	tick() tick() tick()
	check(E.preparation(one).phase and E.preparation(two).waiting == 1, "F one at a time")
	E.end_run(one, "test")
	check(E.preparation(one) == nil, "F an ended run has no preparation")
	until_state(two, "ready")
	E.end_run(two, "test")

	-- A map that never answers fails cleanly and frees the slot.
	fail_all = true
	local failing = assert(E.create(a_player, "test_vault", 0))
	for _ = 1, 500 do tick() end
	fail_all = false
	check(failing.state == "ended" and saw("end " .. failing.id .. " failed"), "F a failed preparation ends")
	check(not E.run_of(a_player), "F and frees the owner")
	emerges = {}
end

-- G. Create and enter.
local function ready_run(owner, bonus)
	local run = assert(E.create(owner, "test_vault", bonus or 0))
	until_state(run, "ready")
	return run
end
do
	local low = new_player("low", 19)
	local levels = E.offered_levels(low, "test_vault")
	check(#levels == 2 and levels[1].level == 20 and levels[2].bonus == 1, "G the dropdown")
	check(#E.offered_levels(new_player("high", 60), "test_vault") == 10, "G all ten")
	check(not E.can_create(low, "test_vault", 2), "G creator below the level")
	check(not E.can_create(low, "nothing", 0), "G an unknown id")
	check(not E.can_create(low, "test_vault", 10) and not E.can_create(low, "test_vault", 0.5), "G bad bonus")

	local leader, member, weak = new_player("leader", 22), new_player("member", 22), new_player("weak", 19)
	join("leader", "member")
	join("leader", "weak")
	local ok, why = E.can_create(member, "test_vault", 0)
	check(not ok and why:find("leader", 1, true), "G a member cannot create")
	check(#E.eligibility(leader, "test_vault", 2) == 3, "G a row per member")
	local rows = E.eligibility(leader, "test_vault", 2)
	check(rows[1].eligible and rows[2].eligible and not rows[3].eligible and rows[3].reason, "G warns")
	local run = assert(E.create(leader, "test_vault", 2))
	check(run.owner.kind == "party" and run.level == 22, "G the party owns it")
	ok, why = E.can_enter(member)
	check(not ok and why:find("prepared", 1, true), "G nobody before ready")
	ok, why = E.create(leader, "test_vault", 0)
	check(not ok and why:find("already", 1, true), "G one per owner")
	until_state(run, "ready")
	ok, why = E.enter(weak, "highcourt")
	check(not ok and why:find("level", 1, true), "G the hard gate at 19 for level 22")
	check(not E.enter(member, "nowhere"), "G a capital that does not exist")
	local stranger = new_player("outsider", 22)
	ok, why = E.can_enter(stranger, run)
	check(not ok and why:find("someone else", 1, true), "G a stranger")
	member.combat = true
	check(not E.enter(member, "highcourt"), "G in combat")
	member.combat = nil
	member.hp = 0
	check(not E.enter(member, "highcourt"), "G dead")
	member.hp = 20
	go_in(member, run)
	check(run.state == "running" and run.entered.member and run.inside.member, "G a place taken")
	check(saw("enter member"), "G the enter hook")
	go_in(leader, run)
	weak.level = 20
	go_in(weak, run)
	local fourth = new_player("fourth", 22)
	join("leader", "fourth")
	ok, why = E.can_enter(fourth)
	check(not ok and why:find("full", 1, true), "G the fourth is refused")
	-- leaving by waystone keeps the place, leaving the party frees it
	assert(E.leave(member))
	tick()
	check(E.run_inside(member) == nil and run.entered.member, "G the place stays")
	check(not E.can_enter(fourth), "G still full")
	go_in(member, run)
	leave_party("member")
	check(not run.entered.member and E.can_enter(fourth), "G leaving the party frees it")
	go_in(fourth, run)
	-- a trip already under way when the place went
	E.end_run(run, "test")
	tick()
	leave_party("fourth") leave_party("weak")
	check(not party_of_name.leader, "G the party is gone")
	-- no slot free
	local blockers = {}
	for i = 1, 100 do blockers[i] = assert(E.create(new_player("b" .. i), "test_vault", 0)) end
	ok, why = E.can_create(new_player("late"), "test_vault", 0)
	check(not ok and why:find("taken", 1, true), "G no slot free")
	for _, row in ipairs(blockers) do E.end_run(row, "test") end
	for _ = 1, 3 do tick() end
end

-- H. Changes of owner.
do
	local owner, friend = new_player("owner"), new_player("friend")
	local run = ready_run(owner)
	go_in(owner, run)
	join("owner", "friend")
	check(run.owner.kind == "party" and E.run_of(friend) == run, "H inviting makes it the party's")
	check(run.state == "running" and E.run_inside(owner) == run, "H and nobody moves")
	go_in(friend, run)
	-- falling to one: the leaver goes, the last member owns it
	leave_party("friend")
	check(run.owner.kind == "player" and run.owner.name == "owner", "H the last member owns it")
	check(E.run_inside(friend) == nil and not run.entered.friend and not E.run_of(friend), "H the leaver is out")
	tick()
	check(friend.pos.x == CAPITAL.x, "H teleported to the capital")
	check(E.run_inside(owner) == run, "H the last member stays")
	-- the leader falling away leaves the other member as owner
	join("owner", "friend")
	check(run.owner.kind == "party", "H a party again")
	go_in(friend, run)
	leave_party("owner")
	check(run.owner.name == "friend" and E.run_inside(friend) == run, "H the leader left, the member owns it")
	tick()
	check(E.run_inside(owner) == nil and owner.pos.x == CAPITAL.x, "H the old leader is out")
	E.end_run(run, "test")
	tick()

	-- joining a foreign party ends it, and no way back
	local solo2, host, guest = new_player("solo2"), new_player("host"), new_player("guest")
	join("host", "guest")
	local gone = ready_run(solo2)
	go_in(solo2, gone)
	solo2.combat = true
	join("host", "solo2")
	check(gone.state == "ended" and saw("end " .. gone.id .. " joined_party"), "H a foreign party ends it")
	tick()
	check(solo2.pos.x == CAPITAL.x, "H the owner is out, in combat too")
	solo2.combat = nil
	leave_party("solo2")
	check(E.run_of(solo2) == nil and E.run_at(gone.minp) == nil, "H no way back")

	-- a capital that cannot take them: home
	local keep, shy = new_player("keep"), new_player("shy")
	join("keep", "shy")
	local run3 = ready_run(keep)
	go_in(shy, run3)
	capital_open = false
	leave_party("shy")
	tick()
	capital_open = true
	check(home[#home] == "shy" and shy.pos.x == 1, "H the fallback goes home")

	-- an offline leaver holds no place, and the login rule sends them home
	local run4 = run3
	join("keep", "shy")
	go_in(shy, run4)
	callbacks.leave(shy)
	shy.online = false
	check(E.run_inside(shy) == nil and run4.entered.shy, "H offline keeps the place")
	leave_party("shy")
	check(not run4.entered.shy, "H offline leaver loses it")
	shy.online = true
	callbacks.join(shy)
	tick()
	tick()
	check(shy.pos.x == CAPITAL.x, "H and stands in the capital they came from at login")
	E.end_run(run4, "test")
	tick()
	leave_party("guest")
end

-- I. The release.
do
	local p = new_player("clocked")
	local run = ready_run(p)
	advance(599)
	check(run.state == "ready", "I reserved for 10 minutes")
	advance(2)
	check(run.state == "ended" and saw("end " .. run.id .. " empty"), "I never entered: released")
	check(E.run_at(run.minp) == nil, "I the slot is free")

	local second = ready_run(p)
	advance(300)
	go_in(p, second)
	advance(1000)
	check(second.state == "running", "I inside, no clock")
	assert(E.leave(p))
	tick()
	advance(599)
	check(second.state == "running", "I counted from the last one out")
	go_in(p, second)
	advance(30)
	check(second.state == "running", "I back in stops it")
	callbacks.leave(p)
	p.online = false
	advance(599)
	check(second.state == "running", "I offline counts as out")
	p.online = true
	callbacks.join(p)
	check(E.run_inside(p) == second, "I a login inside is inside")
	advance(1000)
	check(second.state == "running", "I and stops the clock")
	callbacks.leave(p)
	p.online = false
	advance(601)
	check(second.state == "ended", "I offline ended it")
	check(not E.run_of(p), "I nobody owns it any more")
end

-- J. The login rule.
do
	local p = players.clocked
	p.online = true
	p.pos = {x = 8070, y = -100, z = -1610}
	local before = #home
	callbacks.join(p)
	tick()
	tick()
	check(#home == before and p.pos.x == CAPITAL.x and feed_to("clocked") == "Your Expedition has ended.",
		"J a run gone: the capital they came from, by the saved value alone")
	-- a stone that cannot be reached, or no saved value: home (the login's fallback)
	p.pos = {x = 8070, y = -100, z = -1610}
	capital_open = false
	callbacks.join(p)
	tick()
	tick()
	capital_open = true
	check(#home == before + 1 and p.pos.x == 1, "J no arrival at the capital: home")
	local fresh = new_player("fresh")
	fresh.pos = {x = 8070, y = -100, z = -1610}
	callbacks.join(fresh)
	tick()
	tick()
	check(#home == before + 2 and fresh.pos.x == 1, "J no saved value: home")
	before = before + 1
	-- a logout death pending: the respawn decides, nothing travels
	fresh.pos = {x = 8070, y = -100, z = -1610}
	fresh.meta[E.LOGOUT_DEATH] = "1"
	callbacks.join(fresh)
	tick()
	tick()
	check(fresh.pos.x == 8070 and #home == before + 1, "J a pending logout death leaves it to the respawn")
	-- a new run in the same slot is not theirs
	local other = new_player("other")
	local run = ready_run(other)
	check(run.slot == 1, "J the same slot")
	p.pos = {x = 8070, y = -100, z = -1610}
	callbacks.join(p)
	tick()
	tick()
	check(p.pos.x == CAPITAL.x, "J another run's box")
	-- not even when it is the same owner's next run
	go_in(other, run)
	E.end_run(run, "test")
	tick()
	local next_run = ready_run(other)
	other.pos = {x = 8070, y = -100, z = -1610}
	callbacks.leave(other)
	callbacks.join(other)
	tick()
	tick()
	check(other.pos.x == CAPITAL.x, "J the owner's next run holds no place for them")
	-- dead at login: the respawn does it
	p.pos = {x = 8070, y = -100, z = -1610}
	p.hp = 0
	p.moves = 0
	callbacks.join(p)
	tick()
	tick()
	check(p.moves == 0, "J a dead player waits for the respawn")
	p.hp = 20
	E.end_run(next_run, "test")
	-- outside any box nothing happens
	p.pos = {x = 0, y = 10, z = 0}
	p.moves = 0
	callbacks.join(p)
	tick()
	tick()
	check(p.moves == 0, "J the map is none of this")
end

-- K. The way out.
do
	local p = new_player("walker")
	local run = ready_run(p)
	check(E.start_arrival(run).x == run.places.arrival.x and
		E.start_arrival(run).y == run.places.arrival.y - 0.49, "K the arrival stands on the floor")
	check(not E.leave(p), "K nothing to leave")
	-- Round 72: the stones open the ordinary waystone window (grug_home, whose rules
	-- tools/r29_w and tools/r72_waytab test); leave stays the scripted way back.
	E.use_waystone(p, run.places.start_waystone)
	check(#windows == 0 and feed_to("walker") == "You are not in an Expedition.", "K a stone outside a run")
	go_in(p, run)
	core.registered_nodes["grug_expeditions:waystone"].on_rightclick(run.places.end_waystone, nil, p)
	local window = windows[#windows]
	check(window and window.player == p and window.origin.label == E.definition(run.expedition).name and
		window.origin.pos.x == run.places.end_waystone.x, "K the stone opens the waystone window")
	check(E.run_inside(p) == run, "K opening it moves nobody")
	p.combat = true
	local refused, why = E.leave(p)
	check(not refused and why == "Cannot travel in combat.", "K the way back refuses in combat")
	p.combat = nil
	check(E.leave(p), "K the way back")
	tick()
	check(p.pos.x == CAPITAL.x and E.run_inside(p) == nil, "K it leads to the capital")
	check(saw("left walker travel"), "K the leave hook")
	go_in(p, run)
	grug_home.return_home(p)
	check(E.run_inside(p) == nil and run.entered.walker, "K Return Home leaves, the place stays")
	check(p.trip == nil, "K no trip left over")
	local still = run.state
	check(still == "running", "K the run stays")
	-- Combat on the way in: the check of the trip refuses, in the feed.
	check(E.enter(p, "highcourt"), "K a trip in")
	p.combat = true
	feeds = {}
	tick()
	check(E.run_inside(p) == nil and feed_to("walker") == "Cannot travel in combat.",
		"K the trip's check refuses in the feed")
	p.combat = nil
	E.end_run(run, "test")
	check(#chat == 0, "K no personal notice in chat")
end

print("R71 FRAME PORTABLE PASS checks=" .. checks)
