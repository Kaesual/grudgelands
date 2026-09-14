--
-- Settlement NPC sockets: the one registry between the blueprint side and
-- the runtime mods (docs/research/wp13-npc-sockets-contract.md section 3).
--
-- A blueprint exports `landmarks.sockets`, anchor-relative named standing
-- positions with a role. `grug_mapgen` fills this registry at load from the
-- six start compositions and their fitted anchors; `grug_mobs`,
-- `grug_traders` and later the quest mod read it and never touch the mapgen
-- mod, so an NPC placement does not depend on mapgen load order, on the
-- mapgen environment or on a hard-coded offset that a blueprint edit would
-- silently invalidate.
--
-- TWO RULES THIS FILE ENFORCES AND CONSUMERS THEREFORE DO NOT REPEAT.
--
-- 1. WORLD SPACE IS COMPUTED ONCE. `pos` is anchor + local, with the
--    published fitted `anchor.y` -- the same y `r7_settlement.lua` projects
--    the cells against, so socket y = 1 is the node above the settlement's
--    own ground course. `yaw` is `core.dir_to_yaw` of the horizontal facing.
--    A consumer that recomputed either would be a second authority.
--
-- 2. EVERY QUERY RETURNS FRESH COPIES, down to `dir`, `tags` and `pos`. A
--    consumer writes its own runtime state onto the entry it is handed (the
--    guard mechanism does exactly that), and one of them mutating the
--    authored table would change what the next consumer -- or the next
--    server step -- reads.
--
-- Registration is authored-data validation, so it FAILS LOUDLY: a settlement
-- that exports a broken socket is a build error, not a settlement that
-- quietly has no guards.
--

local ROLES = {guard_post = true, guard_patrol = true, vendor = true,
	idle = true, quest = true, king = true, waypoint = true}
local VENDOR_KINDS = {race = true, general = true}

-- settlement_key -> record; race_id -> the same record.
local by_key = {}
local by_race = {}

local function fail(message)
	error("grug_core settlement sockets: " .. message, 0)
end

local function integer(value, label)
	if type(value) ~= "number" or value ~= value or value % 1 ~= 0 then
		fail(label .. " differs")
	end
	return value
end

-- One authored socket -> one stored entry in world space. The stored entry is
-- private: every public query copies it again.
local function compile(settlement_key, anchor, socket, seen)
	if type(socket) ~= "table" then fail(settlement_key .. ": socket differs") end
	local id = socket.id
	if type(id) ~= "string" or id == "" or seen[id] then
		fail(settlement_key .. ": socket id differs")
	end
	seen[id] = true
	local where = settlement_key .. " socket " .. id
	if not ROLES[socket.role] then fail(where .. ": role differs") end
	local x = integer(socket.x, where .. ": x")
	local y = integer(socket.y, where .. ": y")
	local z = integer(socket.z, where .. ": z")
	local dir = socket.dir
	if type(dir) ~= "table" or
			not ((dir.x == 0 and (dir.z == 1 or dir.z == -1)) or
				(dir.z == 0 and (dir.x == 1 or dir.x == -1))) then
		fail(where .. ": facing is not one of the four axis vectors")
	end
	if socket.role == "guard_patrol" then
		if type(socket.group) ~= "string" or socket.group == "" then
			fail(where .. ": patrol waypoint without a loop")
		end
		if type(socket.order) ~= "number" or socket.order % 1 ~= 0 or
				socket.order < 1 then
			fail(where .. ": patrol order differs")
		end
	elseif socket.group ~= nil or socket.order ~= nil then
		fail(where .. ": only a patrol waypoint carries a loop")
	end
	if socket.role == "vendor" then
		if not VENDOR_KINDS[socket.kind] then fail(where .. ": vendor kind differs") end
	elseif socket.kind ~= nil then
		fail(where .. ": only a vendor carries a kind")
	end
	local tags
	if socket.tags ~= nil then
		if type(socket.tags) ~= "table" or #socket.tags < 1 then
			fail(where .. ": tags differ")
		end
		tags = {}
		for index = 1, #socket.tags do
			local tag = socket.tags[index]
			if type(tag) ~= "string" or tag == "" then fail(where .. ": tag differs") end
			tags[index] = tag
		end
	end
	return {
		id = id, role = socket.role, x = x, y = y, z = z,
		dir_x = dir.x, dir_z = dir.z,
		group = socket.group, order = socket.order, kind = socket.kind,
		tags = tags,
		-- World space, decided here and nowhere else.
		wx = anchor.x + x, wy = anchor.y + y, wz = anchor.z + z,
		yaw = core.dir_to_yaw({x = dir.x, y = 0, z = dir.z}),
	}
end

local function copy_entry(entry)
	local tags
	if entry.tags then
		tags = {}
		for index = 1, #entry.tags do tags[index] = entry.tags[index] end
	end
	return {
		id = entry.id, role = entry.role,
		x = entry.x, y = entry.y, z = entry.z,
		dir = {x = entry.dir_x, z = entry.dir_z},
		group = entry.group, order = entry.order, kind = entry.kind,
		tags = tags,
		pos = vector.new(entry.wx, entry.wy, entry.wz),
		yaw = entry.yaw,
	}
end

local function copy_list(record)
	local result = {}
	if not record then return result end
	for index = 1, #record.sockets do
		result[index] = copy_entry(record.sockets[index])
	end
	return result
end

--
-- Public API (contract section 3)
--

-- `anchor` is the settlement's published anchor, `sockets` its blueprint's
-- authored array. Both are read, never kept: the caller may reuse its table.
function grug_core.register_settlement_sockets(settlement_key, race_id, anchor,
		sockets)
	if type(settlement_key) ~= "string" or settlement_key == "" then
		fail("settlement key differs")
	end
	if type(race_id) ~= "string" or race_id == "" then
		fail(settlement_key .. ": race id differs")
	end
	if by_key[settlement_key] then
		fail(settlement_key .. " is already registered")
	end
	if by_race[race_id] then
		fail(settlement_key .. ": race " .. race_id .. " is already registered")
	end
	if type(anchor) ~= "table" then fail(settlement_key .. ": anchor differs") end
	integer(anchor.x, settlement_key .. ": anchor x")
	integer(anchor.y, settlement_key .. ": anchor y")
	integer(anchor.z, settlement_key .. ": anchor z")
	if type(sockets) ~= "table" then fail(settlement_key .. ": socket list differs") end
	local compiled, seen = {}, {}
	for index = 1, #sockets do
		compiled[index] = compile(settlement_key, anchor, sockets[index], seen)
	end
	local record = {
		key = settlement_key,
		race_id = race_id,
		anchor = {x = anchor.x, y = anchor.y, z = anchor.z},
		sockets = compiled,
	}
	by_key[settlement_key] = record
	by_race[race_id] = record
	return #compiled
end

-- The sockets of a race's START, in authored order, as world-space copies.
function grug_core.settlement_sockets(race_id)
	return copy_list(by_race[race_id])
end

-- The same by settlement key (capitals register under their own key when the
-- capital core lands).
function grug_core.settlement_sockets_at(settlement_key)
	return copy_list(by_key[settlement_key])
end

-- The anchor a settlement's sockets were registered against, or nil. Its own
-- copy, for the same reason every socket is one.
function grug_core.settlement_socket_anchor(settlement_key)
	local record = by_key[settlement_key]
	if not record then return nil end
	return {x = record.anchor.x, y = record.anchor.y, z = record.anchor.z}
end
