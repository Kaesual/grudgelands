-- Real-code KAT for the settlement NPC socket registry
-- (`mods/CORE/grug_core/settlement_sockets.lua`, the seam of
-- docs/research/wp13-npc-sockets-contract.md section 3).
--
-- Drives the production file against a stub `core`/`vector`: the world-space
-- conversion against the published fitted anchor, the yaw the four axis
-- facings produce, the promise that every query returns COPIES (the guard
-- mechanism writes runtime state onto the entries it is handed), and every
-- validation the registry refuses authored data with.
--
-- The `core.dir_to_yaw` stub is the engine's own one line, cited, so "yaw
-- comes from dir" is checked against the engine's formula and not against a
-- second copy of the registry's arithmetic; the stub also records its
-- argument, because passing a facing with a y component would be a different
-- (and silently wrong) call.
--
-- Plain Lua 5.1; returns one canonical report.

return function(repo)
	local report = {}
	local function line(...)
		report[#report + 1] = table.concat({...}, "\t") .. "\n"
	end

	local saved_core = rawget(_G, "core")
	local saved_vector = rawget(_G, "vector")
	local saved_grug_core = rawget(_G, "grug_core")

	local yaw_calls = {}
	rawset(_G, "core", {
		-- reference_projects/luanti/builtin/common/item_s.lua:153-155
		dir_to_yaw = function(dir)
			yaw_calls[#yaw_calls + 1] = dir
			return -math.atan2(dir.x, dir.z)
		end,
	})
	rawset(_G, "vector", {
		new = function(x, y, z) return {x = x, y = y, z = z} end,
	})
	rawset(_G, "grug_core", {})
	local grug_core = rawget(_G, "grug_core")
	dofile(repo .. "/mods/CORE/grug_core/settlement_sockets.lua")

	local function restore()
		rawset(_G, "core", saved_core)
		rawset(_G, "vector", saved_vector)
		rawset(_G, "grug_core", saved_grug_core)
	end
	local function finish(err)
		restore()
		error(err, 0)
	end
	local function check(condition, message)
		if not condition then finish("wp13 socket registry: " .. message) end
	end

	local ANCHOR = {x = -1800, y = 37, z = -2550}
	local SOCKETS = {
		{id = "gate_west", role = "guard_post", x = -4, y = 1, z = 59,
			dir = {x = 0, z = 1}},
		{id = "gate_east", role = "guard_post", x = 4, y = 1, z = 59,
			dir = {x = 0, z = -1}},
		{id = "watch_a", role = "guard_patrol", group = "vale", order = 1,
			x = 0, y = 1, z = 52, dir = {x = 1, z = 0}},
		{id = "watch_b", role = "guard_patrol", group = "vale", order = 2,
			x = 0, y = 2, z = 24, dir = {x = -1, z = 0}},
		{id = "market", role = "vendor", kind = "race", x = 7, y = 1, z = -5,
			dir = {x = -1, z = 0}},
		{id = "bench", role = "idle", tags = {"bench", "shade"}, x = 7, y = 1,
			z = 1, dir = {x = 1, z = 0}},
		{id = "hall", role = "quest", x = -28, y = 1, z = 26,
			dir = {x = 0, z = 1}},
	}

	local count = grug_core.register_settlement_sockets("hearthpine", "dwarf",
		ANCHOR, SOCKETS)
	check(count == #SOCKETS, "registration count differs")
	line("registered", "hearthpine", "dwarf", count)

	-- The stub saw exactly one horizontal facing per socket.
	check(#yaw_calls == #SOCKETS, "dir_to_yaw call count differs")
	for index = 1, #yaw_calls do
		check(yaw_calls[index].y == 0, "dir_to_yaw got a vertical facing")
	end

	local list = grug_core.settlement_sockets("dwarf")
	check(#list == #SOCKETS, "start list length differs")
	for index = 1, #list do
		local entry, source = list[index], SOCKETS[index]
		check(entry.id == source.id, "authored order differs at " .. index)
		check(entry.pos.x == ANCHOR.x + source.x and
			entry.pos.y == ANCHOR.y + source.y and
			entry.pos.z == ANCHOR.z + source.z, "world position differs: " ..
			entry.id)
		check(entry.x == source.x and entry.y == source.y and
			entry.z == source.z, "local coordinates differ: " .. entry.id)
		check(entry.dir.x == source.dir.x and entry.dir.z == source.dir.z,
			"facing differs: " .. entry.id)
		line("socket", entry.id, entry.role, tostring(entry.group),
			tostring(entry.order), tostring(entry.kind),
			entry.tags and table.concat(entry.tags, ",") or "-",
			entry.pos.x, entry.pos.y, entry.pos.z,
			string.format("%.6f", entry.yaw))
	end

	-- Yaw, per axis facing, against the engine's own formula. +z is 0, -x is
	-- a quarter turn, -z a half, +x three quarters -- i.e. the yaw an entity
	-- set to `core.dir_to_yaw(dir)` really looks along.
	local function yaw_of(id)
		for _, entry in ipairs(list) do
			if entry.id == id then return entry.yaw end
		end
		finish("wp13 socket registry: no socket " .. id)
	end
	local function close(a, b) return math.abs(a - b) < 1e-9 end
	check(close(yaw_of("gate_west"), 0), "+z yaw differs")
	check(close(yaw_of("gate_east"), -math.pi), "-z yaw differs")
	check(close(yaw_of("watch_a"), -math.pi / 2), "+x yaw differs")
	check(close(yaw_of("watch_b"), math.pi / 2), "-x yaw differs")
	line("yaw", "axis_facings", "pass")

	-- Copies, not references, in both directions.
	list[1].pos.x = 0
	list[1].dir.x = 99
	list[1].tags = nil
	list[6].tags[1] = "mutated"
	local again = grug_core.settlement_sockets("dwarf")
	check(again[1].pos.x == ANCHOR.x - 4, "a consumer moved a stored socket")
	check(again[1].dir.x == 0, "a consumer turned a stored socket")
	check(again[6].tags[1] == "bench", "a consumer rewrote a stored tag")
	check(again[1] ~= list[1], "two queries share one entry table")
	check(again[6].tags ~= list[6].tags, "two queries share one tag table")
	-- And the authored table the caller handed over is no longer read.
	SOCKETS[1].x = 500
	SOCKETS[6].tags[1] = "authored_mutation"
	local third = grug_core.settlement_sockets("dwarf")
	check(third[1].x == -4 and third[1].pos.x == ANCHOR.x - 4,
		"the registry kept the caller's table")
	check(third[6].tags[1] == "bench", "the registry kept the caller's tags")
	line("copies", "queries_and_source", "pass")

	-- The key-addressed query, the anchor accessor and the empty answers.
	local at = grug_core.settlement_sockets_at("hearthpine")
	check(#at == #SOCKETS, "key query length differs")
	check(at[1].id == "gate_west", "key query order differs")
	local anchor = grug_core.settlement_socket_anchor("hearthpine")
	check(anchor.x == ANCHOR.x and anchor.y == ANCHOR.y and
		anchor.z == ANCHOR.z, "published anchor differs")
	anchor.y = 0
	check(grug_core.settlement_socket_anchor("hearthpine").y == ANCHOR.y,
		"the anchor accessor returns a reference")
	check(#grug_core.settlement_sockets("orc") == 0,
		"an unregistered race is not empty")
	check(#grug_core.settlement_sockets_at("sunscar") == 0,
		"an unregistered settlement is not empty")
	check(grug_core.settlement_socket_anchor("sunscar") == nil,
		"an unregistered settlement has an anchor")
	local settlements = grug_core.settlement_socket_settlements()
	check(#settlements == 1, "settlement roster length differs")
	check(settlements[1].key == "hearthpine" and
		settlements[1].race_id == "dwarf" and
		settlements[1].anchor.y == ANCHOR.y, "settlement roster row differs")
	settlements[1].anchor.y = 0
	check(grug_core.settlement_socket_settlements()[1].anchor.y == ANCHOR.y,
		"the settlement roster returns references")
	line("queries", "by_key_and_missing", "pass")

	-- Everything the registry refuses. Authored data, so each of these is a
	-- build error and not a settlement that quietly has no guards.
	local function refuses(label, key, race, anchor_in, sockets_in)
		local ok, err = pcall(grug_core.register_settlement_sockets, key, race,
			anchor_in, sockets_in)
		check(not ok, "accepted " .. label)
		check(type(err) == "string" and err:find("settlement sockets", 1, true),
			"refusal of " .. label .. " is not this module's")
		line("refused", label)
	end
	local function one(overrides)
		local socket = {id = "s", role = "idle", x = 0, y = 1, z = 0,
			dir = {x = 0, z = 1}}
		for field, value in pairs(overrides) do
			if value == "\0nil" then socket[field] = nil else socket[field] = value end
		end
		return {socket}
	end
	refuses("a second registration of one settlement", "hearthpine", "elf",
		ANCHOR, one({}))
	refuses("a second start for one race", "kapok", "dwarf", ANCHOR, one({}))
	refuses("an empty settlement key", "", "elf", ANCHOR, one({}))
	refuses("an empty race id", "kapok", "", ANCHOR, one({}))
	refuses("a fractional anchor", "kapok", "elf", {x = 0, y = 1.5, z = 0},
		one({}))
	refuses("a missing socket list", "kapok", "elf", ANCHOR, nil)
	refuses("an unknown role", "kapok", "elf", ANCHOR, one({role = "mayor"}))
	refuses("a fractional coordinate", "kapok", "elf", ANCHOR, one({y = 1.5}))
	refuses("a diagonal facing", "kapok", "elf", ANCHOR,
		one({dir = {x = 1, z = 1}}))
	refuses("a zero facing", "kapok", "elf", ANCHOR, one({dir = {x = 0, z = 0}}))
	refuses("a missing facing", "kapok", "elf", ANCHOR, one({dir = "\0nil"}))
	refuses("an empty socket id", "kapok", "elf", ANCHOR, one({id = ""}))
	refuses("a patrol waypoint without a loop", "kapok", "elf", ANCHOR,
		one({role = "guard_patrol", order = 1}))
	refuses("a patrol waypoint without an order", "kapok", "elf", ANCHOR,
		one({role = "guard_patrol", group = "loop"}))
	refuses("a loop on a non-patrol socket", "kapok", "elf", ANCHOR,
		one({group = "loop"}))
	refuses("a vendor without a kind", "kapok", "elf", ANCHOR,
		one({role = "vendor"}))
	refuses("an unknown vendor kind", "kapok", "elf", ANCHOR,
		one({role = "vendor", kind = "fence"}))
	refuses("a kind on a non-vendor socket", "kapok", "elf", ANCHOR,
		one({kind = "race"}))
	refuses("an empty tag list", "kapok", "elf", ANCHOR, one({tags = {}}))
	refuses("a numeric tag", "kapok", "elf", ANCHOR, one({tags = {7}}))
	local duplicate = one({})
	duplicate[2] = {id = "s", role = "idle", x = 1, y = 1, z = 0,
		dir = {x = 0, z = 1}}
	refuses("a duplicate socket id", "kapok", "elf", ANCHOR, duplicate)

	-- A refused registration leaves nothing behind.
	check(#grug_core.settlement_sockets("elf") == 0,
		"a refused registration was kept")
	check(#grug_core.settlement_sockets_at("kapok") == 0,
		"a refused settlement was kept")
	check(#grug_core.settlement_socket_settlements() == 1,
		"a refused registration reached the settlement roster")
	line("refusals", "left_no_state", "pass")

	restore()
	return table.concat(report)
end
