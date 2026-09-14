-- Compact real-code regression for WP45's safe character-creation flow.

local repo = arg[1] or "."

local callbacks = {
	newplayer = {},
	joinplayer = {},
	leaveplayer = {},
	receive_fields = {},
	respawnplayer = {},
	globalstep = {},
}
local after_queue = {}
local emerge_requests = {}
local online = {}
local mods_loaded = {}
local chats = {}
local clock = 0
local class_sets = 0
local chatcommands = {}

local function assert_equal(actual, expected, context)
	if actual ~= expected then
		error((context or "value") .. ": expected " .. tostring(expected) ..
			", got " .. tostring(actual), 2)
	end
end

local function assert_contains(value, needle, context)
	if not value or not value:find(needle, 1, true) then
		error((context or "text") .. ": missing " .. needle, 2)
	end
end

local function copy_table(source)
	local result = {}
	for key, value in pairs(source or {}) do result[key] = value end
	return result
end

vector = {}
function vector.offset(pos, x, y, z)
	return {x = pos.x + x, y = pos.y + y, z = pos.z + z}
end

local in_callback = false
core = {
	EMERGE_GENERATED = 1,
	EMERGE_FROM_MEMORY = 2,
	EMERGE_FROM_DISK = 3,
	EMERGE_CANCELLED = 4,
	EMERGE_ERRORED = 5,
	formspec_escape = function(value) return value end,
	colorize = function(_, value) return value end,
	log = function() end,
	check_player_privs = function() return true end,
	get_player_by_name = function(name) return online[name] end,
	register_chatcommand = function(name, def) chatcommands[name] = def end,
	register_on_punchplayer = function() end,
	register_on_newplayer = function(fn)
		callbacks.newplayer[#callbacks.newplayer + 1] = fn
	end,
	register_on_joinplayer = function(fn)
		callbacks.joinplayer[#callbacks.joinplayer + 1] = fn
	end,
	register_on_leaveplayer = function(fn)
		callbacks.leaveplayer[#callbacks.leaveplayer + 1] = fn
	end,
	register_on_player_receive_fields = function(fn)
		callbacks.receive_fields[#callbacks.receive_fields + 1] = fn
	end,
	register_on_respawnplayer = function(fn)
		callbacks.respawnplayer[#callbacks.respawnplayer + 1] = fn
	end,
	register_globalstep = function(fn)
		callbacks.globalstep[#callbacks.globalstep + 1] = fn
	end,
	after = function(_, fn)
		after_queue[#after_queue + 1] = fn
	end,
	show_formspec = function(name, formname, formspec)
		local player = online[name]
		assert(player, "show_formspec player is online")
		player.formname = formname
		player.formspec = formspec
		player.formspec_sends = (player.formspec_sends or 0) + 1
	end,
	close_formspec = function(name, formname)
		local player = online[name]
		if player and player.formname == formname then
			player.formname = nil
			player.formspec = nil
		end
	end,
	chat_send_player = function(name, message)
		chats[#chats + 1] = name .. "=" .. message
	end,
	emerge_area = function(pos1, pos2, callback)
		-- HARD RULE (shared with starts_preload_kat): the engine self-deadlocks
		-- when a block is enqueued from inside an emerge completion callback
		-- (src/emerge.cpp:302 vs :494-508); every enqueue must come from a
		-- scheduled job. `in_callback` is raised by finish_emerge below.
		assert(not in_callback,
			"core.emerge_area called from inside an emerge callback")
		emerge_requests[#emerge_requests + 1] = {
			pos1 = copy_table(pos1), pos2 = copy_table(pos2), callback = callback,
		}
	end,
	register_on_mods_loaded = function(fn)
		mods_loaded[#mods_loaded + 1] = fn
	end,
	get_us_time = function()
		clock = clock + 250000
		return clock
	end,
}

-- The six authenticated start anchors. start_position() below is exactly
-- anchor.y + 1, as in the production authority.
local START_ANCHORS = {
	{race_id = "dwarf", faction_id = "accord", x = -550, y = 40, z = -900},
	{race_id = "human", faction_id = "accord", x = 10, y = 30, z = -900},
	{race_id = "elf", faction_id = "accord", x = 560, y = 35, z = -900},
	{race_id = "undead", faction_id = "throng", x = -550, y = 20, z = 900},
	{race_id = "orc", faction_id = "throng", x = 10, y = 35, z = 900},
	{race_id = "troll", faction_id = "throng", x = 560, y = 25, z = 900},
}

grug_core = {
	factions = {
		accord = {name = "Accord", color = "#2266CC"},
		throng = {name = "Throng", color = "#CC3322"},
	},
	zone_authority_installed = function() return true end,
	start_identities = function()
		local result = {}
		for index = 1, #START_ANCHORS do
			local row = START_ANCHORS[index]
			result[index] = {
				race_id = row.race_id,
				faction_id = row.faction_id,
				anchor = {x = row.x, y = row.y, z = row.z},
			}
		end
		return result
	end,
	start_position = function(faction, race)
		for index = 1, #START_ANCHORS do
			local row = START_ANCHORS[index]
			if row.race_id == race then
				if row.faction_id ~= faction then return nil end
				return {x = row.x, y = row.y + 1, z = row.z}
			end
		end
		return nil
	end,
}

-- The startup preload's still-open emerge request for one start, found by the
-- envelope it asked for (grug_core/starts_preload.lua: anchor +- 64).
local function preload_request(race_id)
	local anchor
	for index = 1, #START_ANCHORS do
		if START_ANCHORS[index].race_id == race_id then
			anchor = START_ANCHORS[index]
		end
	end
	assert(anchor, "unknown start race " .. tostring(race_id))
	for index = #emerge_requests, 1, -1 do
		local request = emerge_requests[index]
		if not request.finished and request.pos1.x == anchor.x - 64 and
				request.pos1.z == anchor.z - 64 then
			return request
		end
	end
	error("no open preload request for " .. race_id)
end

local Meta = {}
Meta.__index = Meta
function Meta:get_string(key) return self.strings[key] or "" end
function Meta:set_string(key, value) self.strings[key] = value end
function Meta:get_int(key) return self.ints[key] or 0 end
function Meta:set_int(key, value) self.ints[key] = value end

local function new_meta()
	return setmetatable({strings = {}, ints = {}}, Meta)
end

local function new_player(name, meta, options)
	options = options or {}
	local player = {
		name = name,
		meta = meta or new_meta(),
		pos = copy_table(options.pos or {x = 0, y = 80, z = 0}),
		velocity = copy_table(options.velocity or {x = 0, y = -3, z = 0}),
		physics = copy_table(options.physics or {
			speed = 1.25, jump = 0.9, gravity = 0.8, speed_climb = 1.5,
		}),
		armor = copy_table(options.armor or {fleshy = 100, custom = 7}),
		hp = options.hp == nil and 20 or options.hp,
		teleports = 0,
		items = {},
	}
	function player:get_player_name() return self.name end
	function player:get_meta() return self.meta end
	function player:get_inventory()
		local owner = self
		return {add_item = function(_, _, item)
			owner.items[#owner.items + 1] = item
		end}
	end
	function player:set_nametag_attributes(value) self.nametag = value end
	function player:get_physics_override() return copy_table(self.physics) end
	function player:set_physics_override(value)
		for key, child in pairs(value) do self.physics[key] = child end
	end
	function player:get_armor_groups() return copy_table(self.armor) end
	function player:set_armor_groups(value) self.armor = copy_table(value) end
	function player:get_velocity() return copy_table(self.velocity) end
	function player:add_velocity(value)
		self.velocity.x = self.velocity.x + value.x
		self.velocity.y = self.velocity.y + value.y
		self.velocity.z = self.velocity.z + value.z
	end
	function player:set_pos(value)
		self.pos = copy_table(value)
		self.teleports = self.teleports + 1
	end
	function player:get_hp() return self.hp end
	function player:set_hp(value, reason)
		self.hp = value
		self.hp_reason = reason
	end
	return player
end

local function run_after()
	while #after_queue > 0 do
		local pending = after_queue
		after_queue = {}
		for index = 1, #pending do pending[index]() end
	end
end

local function join(player, is_new)
	online[player.name] = player
	if is_new then
		for index = 1, #callbacks.newplayer do
			callbacks.newplayer[index](player)
		end
	end
	for index = 1, #callbacks.joinplayer do
		callbacks.joinplayer[index](player)
	end
end

local function leave(player)
	for index = 1, #callbacks.leaveplayer do
		callbacks.leaveplayer[index](player)
	end
	online[player.name] = nil
end

local function receive(player, formname, fields)
	if fields.quit then
		player.formname = nil
		player.formspec = nil
	end
	for index = #callbacks.receive_fields, 1, -1 do
		if callbacks.receive_fields[index](player, formname, fields) then
			return
		end
	end
end

local function run_globalsteps(dtime)
	for index = 1, #callbacks.globalstep do
		callbacks.globalstep[index](dtime)
	end
end

local function respawn(player)
	for index = #callbacks.respawnplayer, 1, -1 do
		if callbacks.respawnplayer[index](player) then return true end
	end
	return false
end

local function finish_emerge(request, actions)
	request.finished = true
	in_callback = true
	for index = 1, #actions do
		request.callback({x = index, y = 0, z = 0}, actions[index],
			#actions - index)
	end
	in_callback = false
end

-- Completes the pending arrival emerge (creation's second gate: the player's
-- OWN start blocks must be loaded right now, not merely generated once) and
-- runs the scheduled jobs its callback defers to.
local function finish_arrival(context)
	local request = emerge_requests[#emerge_requests]
	assert(request and not request.finished,
		"an arrival emerge is pending: " .. (context or "?"))
	finish_emerge(request, {core.EMERGE_FROM_DISK})
	run_after()
	return request
end

-- Blocks of a request that is not finished yet (calls_remaining > 0).
local function partial_emerge(request, blocks)
	for index = 1, blocks do
		request.callback({x = index, y = 0, z = 0}, core.EMERGE_GENERATED,
			blocks - index + 1)
	end
end

dofile(repo .. "/mods/PLAYER/grug_factions/init.lua")

grug_classes = {
	registered_races = {
		human = {id = "human", name = "Human", faction = "accord"},
		dwarf = {id = "dwarf", name = "Dwarf", faction = "accord"},
		orc = {id = "orc", name = "Orc", faction = "throng"},
	},
	race_ids = {accord = {"human", "dwarf"}, throng = {"orc"}},
	registered_classes = {
		warrior = {id = "warrior", name = "Warrior"},
		mage = {id = "mage", name = "Mage"},
		priest = {id = "priest", name = "Priest"},
	},
	class_ids = {"warrior", "mage", "priest"},
}
function grug_classes.get_race(player)
	local id = player:get_meta():get_string("grug_classes:race")
	local def = grug_classes.registered_races[id]
	return def and def.faction == grug_factions.get_faction(player) and id or nil
end
function grug_classes.get_race_def(player)
	return grug_classes.registered_races[grug_classes.get_race(player)]
end
function grug_classes.set_race(player, id)
	local def = grug_classes.registered_races[id]
	if not def or def.faction ~= grug_factions.get_faction(player) then
		return false
	end
	player:get_meta():set_string("grug_classes:race", id)
	return true
end
function grug_classes.get_class(player)
	local id = player:get_meta():get_string("grug_classes:class")
	return grug_classes.registered_classes[id] and id or nil
end
function grug_classes.get_class_def(player)
	return grug_classes.registered_classes[grug_classes.get_class(player)]
end
function grug_classes.set_class(player, id)
	if not grug_classes.registered_classes[id] then return false end
	player:get_meta():set_string("grug_classes:class", id)
	class_sets = class_sets + 1
	return true
end
function grug_classes.get_attributes()
	return {str = 10, int = 10, dex = 10}
end
function grug_classes.get_max_hp() return 30 end
function grug_classes.get_max_mana() return 20 end
function grug_classes.get_melee_bonus() return 0 end
function grug_classes.get_spell_power_bonus() return 0 end
function grug_classes.get_crit_chance() return 0 end
function grug_classes.get_dodge_chance() return 0 end

grug_core.get_player_race = function(name)
	local player = online[name]
	return player and grug_classes.get_race(player) or nil
end
grug_xp = {get_level = function() return 1 end}

dofile(repo .. "/mods/CORE/grug_core/starts_preload.lua")
dofile(repo .. "/mods/PLAYER/grug_classes/selection.lua")

-- A later dependent mod resets old slows on join. The after(0) creation pass
-- must reassert speed=0 without waiting for a normal server step.
core.register_on_joinplayer(function(player)
	player:set_physics_override({speed = 1})
end)

local function assert_locked(player, context)
	assert_equal(player.physics.speed, 0, context .. " speed")
	assert_equal(player.physics.jump, 0, context .. " jump")
	assert_equal(player.physics.gravity, 0, context .. " gravity")
	assert_equal(player.armor.immortal, 1, context .. " immortal")
	assert_equal(player.velocity.x, 0, context .. " velocity x")
	assert_equal(player.velocity.y, 0, context .. " velocity y")
	assert_equal(player.velocity.z, 0, context .. " velocity z")
end

local function assert_dark_form(player, formname, context)
	assert_equal(player.formname, formname, context .. " form")
	assert_contains(player.formspec, "no_prepend[]", context .. " prepend")
	assert_contains(player.formspec, "bgcolor[#080808FF;both;#000000FF]",
		context .. " background")
end

--
-- Server start: grug_core emerges ALL SIX start areas, two at a time, before
-- any player can finish character creation (user decision 2026-09-14).
--
for index = 1, #mods_loaded do mods_loaded[index]() end
run_after()
assert_equal(#emerge_requests, 2, "startup emerges two start areas at a time")
assert_equal(select(2, grug_core.starts_ready()), 6, "six start areas")

-- Fresh character: lock before the first position send, reopen a closed
-- faction form, defer class persistence, wait for all six starts, commit once.
local fresh = new_player("fresh")
join(fresh, true)
assert_equal(fresh.physics.gravity, 0, "newplayer gravity lock")
assert_equal(fresh.armor.immortal, 1, "newplayer immortal lock")
assert_equal(fresh.physics.speed, 1, "later join reset is observable")
run_after()
assert_locked(fresh, "fresh join")
assert_dark_form(fresh, "grug_factions:select", "faction")

-- A status-effect writer may run after join and after its punch is rejected
-- by immortality. The throttled guard restores the complete lock.
fresh:set_physics_override({speed = 0.6, jump = 0.4, gravity = 1.5})
fresh.velocity = {x = 1, y = -2, z = 0.5}
run_globalsteps(0.1)
assert_locked(fresh, "runtime physics writer")

receive(fresh, "grug_factions:select", {quit = true})
assert_equal(fresh.formname, nil, "closed faction form")
run_after()
assert_dark_form(fresh, "grug_factions:select", "reopened faction")

local requests_before_fresh = #emerge_requests
receive(fresh, "grug_factions:select", {choose_accord = true})
assert_equal(grug_factions.get_faction(fresh), "accord", "chosen faction")
assert_dark_form(fresh, "grug_classes:race", "race")

receive(fresh, "grug_classes:race", {choose_human = true})
assert_equal(grug_classes.get_race(fresh), "human", "chosen race")
assert_dark_form(fresh, "grug_classes:class", "class")
assert_equal(fresh.teleports, 0, "no pre-class teleport")
assert_equal(#emerge_requests, requests_before_fresh,
	"character creation emerges nothing of its own")

receive(fresh, "grug_classes:class", {choose_mage = true})
assert_equal(grug_classes.get_class(fresh), nil, "class waits for the preload")
assert_dark_form(fresh, "grug_classes:loading", "loading")
assert_contains(fresh.formspec, "(0 of 6)", "loading progress text")
assert_locked(fresh, "pending preload")

-- Progress is sent on change only: a partial emerge callback changes nothing
-- and must not produce a formspec packet.
local sends_before = fresh.formspec_sends
partial_emerge(preload_request("dwarf"), 2)
run_after()
assert_equal(fresh.formspec_sends, sends_before, "partial emerge sends nothing")
finish_emerge(preload_request("dwarf"), {core.EMERGE_FROM_MEMORY})
run_after()
assert_equal(grug_core.starts_ready(), 1, "one start ready")
assert_equal(fresh.formspec_sends, sends_before + 1, "one send per change")
assert_contains(fresh.formspec, "(1 of 6)", "updated progress text")
assert_equal(fresh.teleports, 0, "another race's start does not release")

-- Closing the progress form (Esc) must re-send it: it is gone from the
-- screen, so the send-on-change memo may not suppress the next send.
local sends_before_close = fresh.formspec_sends
receive(fresh, "grug_classes:loading", {quit = true})
assert_equal(fresh.formname, nil, "closed loading form")
run_after()
assert_dark_form(fresh, "grug_classes:loading", "reopened loading")
assert_contains(fresh.formspec, "(1 of 6)", "reopened progress text")
assert_equal(fresh.formspec_sends, sends_before_close + 1,
	"closing re-sends the same text exactly once")

-- The player's OWN start being ready is deliberately not enough.
finish_emerge(preload_request("human"), {core.EMERGE_GENERATED})
run_after()
assert_equal(grug_core.start_ready("human"), true, "own start ready")
assert_equal(fresh.teleports, 0, "own start ready still waits")
assert_contains(fresh.formspec, "(2 of 6)", "own-start progress text")

-- A second player reaches the class click inside the same waiting window.
-- Its class is deliberately transient: a disconnect before the one commit
-- must leave nothing persisted and resume at exactly that step.
local waiting_meta = new_meta()
local waiting = new_player("waiting", waiting_meta)
join(waiting, true)
run_after()
receive(waiting, "grug_factions:select", {choose_accord = true})
receive(waiting, "grug_classes:race", {choose_dwarf = true})
receive(waiting, "grug_classes:class", {choose_priest = true})
assert_dark_form(waiting, "grug_classes:loading", "waiting loading")
assert_contains(waiting.formspec, "(2 of 6)", "waiting progress text")
assert_equal(grug_classes.get_class(waiting), nil, "waiting class is pending")
leave(waiting)
assert_equal(waiting_meta:get_string("grug_classes:class"), "",
	"pending class not persisted")

local waiting_races = {"elf", "undead", "troll"}
for index = 1, #waiting_races do
	finish_emerge(preload_request(waiting_races[index]),
		{core.EMERGE_GENERATED})
	run_after()
end
assert_equal(grug_core.starts_ready(), 5, "five starts ready")
assert_equal(fresh.teleports, 0, "five of six still waits")

-- The sixth start keeps failing: after its bounded attempts the wait turns
-- into the existing retryable failure state instead of an endless wait.
for _ = 1, 3 do
	finish_emerge(preload_request("orc"), {core.EMERGE_ERRORED})
	run_after()
end
run_after()
assert_equal(grug_core.starts_preload_failed(), true, "preload failure state")
assert_dark_form(fresh, "grug_classes:loading", "failed loading")
assert_contains(fresh.formspec, "retry_spawn", "retry button")
assert_equal(fresh.teleports, 0, "failed preload does not teleport")
assert_locked(fresh, "failed preload")

local requests_before_retry = #emerge_requests
receive(fresh, "grug_classes:loading", {retry_spawn = true})
assert_equal(#emerge_requests, requests_before_retry + 1, "retry re-requests")
finish_emerge(preload_request("orc"), {core.EMERGE_GENERATED})
run_after()
assert_equal(grug_core.starts_ready(), 6, "all six start areas ready")

-- Gate two: 6/6 proves the starts were generated, not that they are still
-- loaded. The one teleport still happens only after this player's own
-- arrival emerge succeeded.
assert_equal(fresh.teleports, 0, "6/6 alone does not teleport")
local fresh_arrival = emerge_requests[#emerge_requests]
assert_equal(fresh_arrival.pos1.x, 10 - 16, "arrival envelope min x")
assert_equal(fresh_arrival.pos2.x, 10 + 16, "arrival envelope max x")
assert_equal(grug_classes.get_class(fresh), nil, "class waits for the arrival")
finish_emerge(fresh_arrival, {core.EMERGE_FROM_MEMORY, core.EMERGE_GENERATED})
run_after()

assert_equal(grug_classes.get_class(fresh), "mage", "class commit")
assert_equal(fresh.teleports, 1, "one final teleport")
assert_equal(fresh.pos.x, 10, "fresh spawn x")
assert_equal(fresh.pos.y, 31, "fresh spawn y")
assert_equal(fresh.pos.z, -900, "fresh spawn z")
assert_equal(fresh.physics.speed, 1.25, "restore speed")
assert_equal(fresh.physics.jump, 0.9, "restore jump")
assert_equal(fresh.physics.gravity, 0.8, "restore gravity")
assert_equal(fresh.physics.speed_climb, 1.5, "preserve unrelated physics")
assert_equal(fresh.armor.immortal, nil, "restore immortality")
assert_equal(fresh.armor.custom, 7, "preserve armor group")
assert_equal(fresh.formname, nil, "close loading form")
finish_emerge(fresh_arrival, {core.EMERGE_FROM_DISK})
run_after()
assert_equal(fresh.teleports, 1, "duplicate callback cannot re-teleport")

-- The player that disconnected while waiting resumes at the class step and
-- commits exactly once, at its own race start.
local resumed = new_player("waiting", waiting_meta)
join(resumed, false)
run_after()
assert_locked(resumed, "resumed waiting player")
assert_dark_form(resumed, "grug_classes:class", "resumed class")
receive(resumed, "grug_classes:class", {choose_priest = true})
finish_arrival("resumed")
assert_equal(resumed.teleports, 1, "resumed final teleport")
assert_equal(resumed.pos.x, -550, "resumed dwarf spawn x")
assert_equal(grug_classes.get_class(resumed), "priest", "resumed class commit")

-- With every start prepared the class click commits immediately and no
-- loading form is ever shown.
local prefetched = new_player("prefetched")
join(prefetched, true)
run_after()
local requests_before_prefetched = #emerge_requests
receive(prefetched, "grug_factions:select", {choose_accord = true})
receive(prefetched, "grug_classes:race", {choose_human = true})
-- With every start prepared, race selection prefetches the arrival area
-- behind the class dialog, exactly as WP45 intended.
finish_arrival("prefetched")
assert_equal(prefetched.teleports, 0, "prepared start waits for class")
assert_equal(grug_classes.get_class(prefetched), nil, "prefetch class absent")
assert_dark_form(prefetched, "grug_classes:class", "prefetched class")
receive(prefetched, "grug_classes:class", {choose_mage = true})
assert_equal(prefetched.teleports, 1, "prefetched immediate teleport")
assert_equal(prefetched.formname, nil, "prefetched form closes")
assert_equal(#emerge_requests, requests_before_prefetched + 1,
	"exactly one arrival emerge per player, none for the starts")

-- The committed position belongs to the exact faction/race identity at commit
-- time: an admin race change before the class click moves the destination.
local changed = new_player("changed")
join(changed, true)
run_after()
receive(changed, "grug_factions:select", {choose_accord = true})
receive(changed, "grug_classes:race", {choose_human = true})
finish_arrival("changed human")
local changed_requests = #emerge_requests
local changed_ok = chatcommands.race.func("admin", "changed dwarf")
assert(changed_ok, "admin race change")
assert_equal(#emerge_requests, changed_requests + 1,
	"identity change starts a replacement arrival emerge")
assert_equal(changed.teleports, 0, "admin race change does not teleport")
receive(changed, "grug_classes:class", {choose_warrior = true})
assert_equal(changed.teleports, 0, "stale ready spawn not committed")
finish_arrival("changed dwarf")
assert_equal(changed.pos.x, -550, "changed race spawn x")
assert_equal(changed.teleports, 1, "changed identity final teleport")

-- The faction admin path joins the coordinator instead of launching an
-- independent early teleport, and a first admin-picked class stays transient
-- until that one commit.
local administered = new_player("administered")
join(administered, true)
run_after()
receive(administered, "grug_factions:select", {choose_accord = true})
receive(administered, "grug_classes:race", {choose_human = true})
local administered_requests = #emerge_requests
local faction_ok = chatcommands.faction.func("admin", "administered accord")
assert(faction_ok, "admin faction set")
assert_equal(#emerge_requests, administered_requests,
	"admin faction reuses the coordinator load")
assert_equal(administered.teleports, 0, "admin faction no early teleport")
local class_ok = chatcommands.class.func("admin", "administered priest")
assert(class_ok, "admin class set")
assert_equal(grug_classes.get_class(administered), nil,
	"admin first class remains transient")
assert_dark_form(administered, "grug_classes:loading", "admin class loading")
finish_arrival("administered")
assert_equal(administered.teleports, 1, "admin faction one final teleport")
assert_equal(grug_classes.get_class(administered), "priest",
	"admin class commits once")

-- Disconnect after choosing a race but before the class commit: the pending
-- class is transient, and the reconnect resumes at exactly that step.
local shared_meta = new_meta()
local old = new_player("rejoin", shared_meta)
join(old, true)
run_after()
receive(old, "grug_factions:select", {choose_accord = true})
receive(old, "grug_classes:race", {choose_dwarf = true})
leave(old)
assert_equal(grug_classes.get_class(old), nil, "no class persisted on leave")

local rejoined = new_player("rejoin", shared_meta)
join(rejoined, false)
run_after()
assert_locked(rejoined, "rejoin")
assert_dark_form(rejoined, "grug_classes:class", "rejoin class")
receive(rejoined, "grug_classes:class", {choose_priest = true})
finish_arrival("rejoined")
assert_equal(rejoined.teleports, 1, "rejoined session teleport")
assert_equal(rejoined.pos.x, -550, "rejoined dwarf spawn x")
assert_equal(grug_classes.get_class(rejoined), "priest", "rejoined class commit")

-- A persisted dead, incomplete character cannot take the eager respawn path;
-- completion revives it at the prepared start instead of leaving it dead
-- behind the replaced builtin death form.
local dead_meta = new_meta()
dead_meta:set_string("grug_factions:faction", "accord")
dead_meta:set_string("grug_classes:race", "human")
local dead = new_player("dead", dead_meta, {hp = 0})
join(dead, false)
run_after()
assert_locked(dead, "dead incomplete")
local dead_teleports = dead.teleports
assert(respawn(dead), "creation owns dead respawn")
assert_equal(dead.teleports, dead_teleports, "dead respawn no eager teleport")
receive(dead, "grug_classes:class", {choose_mage = true})
finish_arrival("dead")
assert_equal(dead.teleports, dead_teleports + 1, "dead final teleport")
assert_equal(dead.hp, 30, "dead character revived at full class HP")
assert_equal(dead.hp_reason.type, "set_hp", "dead revive reason")

-- A complete returning character is never locked, emerged or repositioned.
local complete_meta = new_meta()
complete_meta:set_string("grug_factions:faction", "accord")
complete_meta:set_string("grug_classes:race", "human")
complete_meta:set_string("grug_classes:class", "mage")
local complete = new_player("complete", complete_meta, {
	velocity = {x = 1, y = 2, z = 3},
	physics = {speed = 1, jump = 1, gravity = 1},
})
local requests_before_complete = #emerge_requests
join(complete, false)
run_after()
assert_equal(complete.armor.immortal, nil, "complete character immortality")
assert_equal(complete.physics.gravity, 1, "complete character gravity")
assert_equal(complete.velocity.y, 2, "complete character velocity")
assert_equal(complete.formname, nil, "complete character form")
assert_equal(complete.teleports, 0, "complete character teleport")
assert_equal(#emerge_requests, requests_before_complete,
	"complete character emerge")

-- The ordinary respawn wrapper still emerges its destination itself: long
-- after the startup preload the start blocks may have been unloaded again.
local traveler = new_player("traveler", complete_meta)
online.traveler = traveler
local start_count = #emerge_requests
assert(grug_factions.teleport_to_spawn(traveler))
finish_emerge(emerge_requests[start_count + 1], {core.EMERGE_CANCELLED})
assert_equal(traveler.teleports, 0, "cancelled ordinary teleport")
assert(grug_factions.teleport_to_spawn(traveler))
finish_emerge(emerge_requests[start_count + 2], {core.EMERGE_FROM_MEMORY})
assert_equal(traveler.teleports, 1, "successful ordinary teleport")

print(table.concat({
	"wp45_character_creation_v3",
	"emerge_requests=" .. #emerge_requests,
	"fresh_teleports=" .. fresh.teleports,
	"prefetched_teleports=" .. prefetched.teleports,
	"rejoin_teleports=" .. rejoined.teleports,
	"class_sets=" .. class_sets,
	"chats=" .. #chats,
}, "|"))
