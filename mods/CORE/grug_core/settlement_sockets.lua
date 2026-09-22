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
	idle = true, quest = true, king = true, waypoint = true, work = true,
	trainer = true, riding_trainer = true, mount_display = true,
	gear_display = true, public_station = true}
local TRAINER_PROFESSIONS = {weaponsmith = true, armorsmith = true, alchemist = true,
	tailor = true, leatherworker = true, woodcarver = true, goldsmith = true,
	cooking = true}
-- Contract section 8.4: the two vendor families plus the professions. The
-- second row is the wave-2 extension (2026-09-15, the four remaining capitals
-- and the Dur Brannoc upgrade); the entity behind each kind is grug_traders'.
local VENDOR_KINDS = {race = true, general = true, butcher = true,
	smith = true, fishmonger = true, baker = true, tailor = true,
	mason = true, brewer = true, bowyer = true, herbalist = true,
	armourer = true, tanner = true, embalmer = true}
-- Contract section 8.2: the closed activity vocabulary of a `work` socket.
-- The second row is the wave-2 extension; an activity the NPC mod does not
-- animate yet is a resident standing still at its workplace, never an error.
local ACTIVITIES = {smith = true, fish = true, farm = true, chop = true,
	tend = true, pray = true, stall = true, sit = true, sweep = true,
	mine = true, brew = true, carve = true, mourn = true, spar = true,
	forage = true}

-- settlement_key -> record; race_id -> the same record; registration order.
local by_key = {}
local by_race = {}
local order = {}

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
	-- A WORKPLACE NAMES ITS ACTIVITY (contract section 8.1). The vocabulary is
	-- closed so a plot table's typo fails here at load, instead of producing a
	-- resident who stands at a forge doing nothing.
	if socket.role == "work" then
		if not ACTIVITIES[socket.activity] then
			fail(where .. ": work activity differs")
		end
	elseif socket.activity ~= nil then
		fail(where .. ": only a work socket carries an activity")
	end
	if socket.role == "trainer" then
		if not TRAINER_PROFESSIONS[socket.profession] then
			fail(where .. ": trainer profession differs")
		end
	elseif socket.profession ~= nil then
		fail(where .. ": only a trainer carries a profession")
	end
	--
	-- A SPARE SOCKET IS A DESTINATION, NOT A HOME (playtest round 2,
	-- 2026-09-15). `spawn = false` says "nobody is placed here"; the socket is
	-- still a real authored standing position and still reaches every consumer,
	-- so a villager's amble has somewhere to go that is not another villager's
	-- doorstep. Without spares a settlement has exactly as many idle spots as
	-- idle NPCs, every spot is permanently occupied, and the amble is four
	-- people swapping four chairs.
	--
	-- Only `idle` may carry it, and that restriction is the loud half: a
	-- `guard_post` with `spawn = false` is a gate nobody mans, written as one
	-- word, and it would read as authored intent rather than as the defect it
	-- is. A future role that wants spares says so here.
	--
	if socket.spawn ~= nil then
		if socket.spawn ~= false then fail(where .. ": spawn differs") end
		if socket.role ~= "idle" then
			fail(where .. ": only an idle socket may be spare")
		end
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
	if socket.role == "mount_display" then
		if not tags or #tags ~= 1 or not ({["1"]=true,["2"]=true,
				["3"]=true,["4"]=true})[tags[1]] then
			fail(where .. ": mount display tier differs")
		end
	elseif socket.role == "gear_display" then
		if not tags or #tags ~= 1 or not ({weapon=true,armor=true,jewel=true})[tags[1]] then
			fail(where .. ": gear display identity differs")
		end
	elseif socket.role == "public_station" then
		local station = tags and tags[1]
		if not tags or #tags ~= 1 or not ({forge=true,brewing_stand=true,
				tailor_bench=true,tanning_rack=true,carving_bench=true,
				jewellers_bench=true,furnace=true})[station] then
			fail(where .. ": public station identity differs")
		end
	end
	return {
		id = id, role = socket.role, x = x, y = y, z = z,
		dir_x = dir.x, dir_z = dir.z,
		group = socket.group, order = socket.order, kind = socket.kind,
		activity = socket.activity, profession = socket.profession,
		-- Normalized to a boolean here, so a consumer reads one field and
		-- never has to spell "nil means true" itself.
		spawn = socket.spawn ~= false,
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
		activity = entry.activity, profession = entry.profession,
		spawn = entry.spawn,
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
	-- THE KEY IS THE IDENTITY; THE RACE IS NOT. Every race has a start AND a
	-- capital (contract section 3: "capitals register under their own key"), so
	-- a race is registered twice over a world's life and only the key is
	-- unique. `settlement_sockets(race_id)` is the START accessor, so the
	-- FIRST registration for a race wins it: grug_mapgen publishes the six
	-- starts from `r7_loader.lua` while the world authority is being
	-- installed, before any other consumer exists, and a capital landing later
	-- reaches its own sockets through `settlement_sockets_at(key)`.
	if not by_race[race_id] then
		by_race[race_id] = record
	end
	order[#order + 1] = record
	return #compiled
end

-- Every registered settlement, in registration order, as copies: key, race
-- and the anchor its sockets were compiled against. This is how a consumer
-- walks the registry without restating the start roster, and how it can
-- cross-check the anchor against the one the rest of grug_core publishes.
function grug_core.settlement_socket_settlements()
	local result = {}
	for index = 1, #order do
		local record = order[index]
		result[index] = {key = record.key, race_id = record.race_id,
			anchor = {x = record.anchor.x, y = record.anchor.y,
				z = record.anchor.z}}
	end
	return result
end

-- The sockets of a race's START, in authored order, as world-space copies.
-- A race also has a capital; this accessor answers with the start, which is
-- the first settlement registered for that race (see the note at the writer).
function grug_core.settlement_sockets(race_id)
	return copy_list(by_race[race_id])
end

-- The same by settlement key. This is the path a capital's consumer uses: a
-- key is unique, a race is not.
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

-- Home services reserve an existing authored resident before mods-loaded NPC
-- placement. Coordinates remain the terrain-resolved socket authority's own.
function grug_core.assign_innkeeper_socket(settlement_key, socket_id)
 local record = by_key[settlement_key]
 if not record then fail("home settlement missing: " .. settlement_key) end
 for _, entry in ipairs(record.sockets) do
  if entry.id == socket_id then
   if entry.role ~= "idle" or not entry.spawn then
    fail(settlement_key .. ": innkeeper must replace an inhabited idle socket")
   end
   entry.role = "innkeeper"
   return copy_entry(entry)
  end
 end
 fail(settlement_key .. ": innkeeper socket missing: " .. socket_id)
end
