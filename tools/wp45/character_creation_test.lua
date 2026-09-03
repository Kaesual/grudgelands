-- Compact real-code regression for WP45's safe character-creation flow.

local repo = arg[1] or "."

local callbacks = {
	newplayer = {},
	joinplayer = {},
	leaveplayer = {},
	receive_fields = {},
	respawnplayer = {},
}
local after_queue = {}
local emerge_requests = {}
local online = {}
local chats = {}
local class_sets = 0

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
	register_chatcommand = function() end,
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
	after = function(_, fn)
		after_queue[#after_queue + 1] = fn
	end,
	show_formspec = function(name, formname, formspec)
		local player = online[name]
		assert(player, "show_formspec player is online")
		player.formname = formname
		player.formspec = formspec
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
		emerge_requests[#emerge_requests + 1] = {
			pos1 = copy_table(pos1), pos2 = copy_table(pos2), callback = callback,
		}
	end,
}

grug_core = {
	factions = {
		accord = {name = "Accord", color = "#2266CC"},
		throng = {name = "Throng", color = "#CC3322"},
	},
	zone_authority_installed = function() return true end,
	start_position = function(faction, race)
		local positions = {
			human = {faction = "accord", x = 10, y = 31, z = -900},
			dwarf = {faction = "accord", x = -550, y = 41, z = -900},
			orc = {faction = "throng", x = 10, y = 36, z = 900},
		}
		local row = positions[race]
		if not row or row.faction ~= faction then return nil end
		return {x = row.x, y = row.y, z = row.z}
	end,
}

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
	function player:get_hp() return 20 end
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
	for index = 1, #callbacks.receive_fields do
		callbacks.receive_fields[index](player, formname, fields)
	end
end

local function finish_emerge(request, actions)
	for index = 1, #actions do
		request.callback({x = index, y = 0, z = 0}, actions[index],
			#actions - index)
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
function grug_classes.get_max_hp() return 20 end
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

-- Fresh character: lock before the first position send, reopen a closed
-- faction form, prepare after race, defer class persistence, then commit once.
local fresh = new_player("fresh")
join(fresh, true)
assert_equal(fresh.physics.gravity, 0, "newplayer gravity lock")
assert_equal(fresh.armor.immortal, 1, "newplayer immortal lock")
assert_equal(fresh.physics.speed, 1, "later join reset is observable")
run_after()
assert_locked(fresh, "fresh join")
assert_dark_form(fresh, "grug_factions:select", "faction")

receive(fresh, "grug_factions:select", {quit = true})
assert_equal(fresh.formname, nil, "closed faction form")
run_after()
assert_dark_form(fresh, "grug_factions:select", "reopened faction")

receive(fresh, "grug_factions:select", {choose_accord = true})
assert_equal(grug_factions.get_faction(fresh), "accord", "chosen faction")
assert_dark_form(fresh, "grug_classes:race", "race")
assert_equal(#emerge_requests, 0, "no faction-only emerge")

receive(fresh, "grug_classes:race", {choose_human = true})
assert_equal(grug_classes.get_race(fresh), "human", "chosen race")
assert_dark_form(fresh, "grug_classes:class", "class")
assert_equal(#emerge_requests, 1, "race starts one emerge")
assert_equal(fresh.teleports, 0, "no pre-class teleport")

receive(fresh, "grug_classes:class", {choose_mage = true})
assert_equal(grug_classes.get_class(fresh), nil, "class waits for emerge")
assert_dark_form(fresh, "grug_classes:loading", "loading")
assert_locked(fresh, "pending load")

finish_emerge(emerge_requests[1], {
	core.EMERGE_FROM_MEMORY, core.EMERGE_GENERATED,
})
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
finish_emerge(emerge_requests[1], {core.EMERGE_FROM_DISK})
assert_equal(fresh.teleports, 1, "duplicate callback cannot re-teleport")

-- The intended fast path hides all generation behind the class decision: an
-- early emerge completion keeps the player in stasis until the click, then
-- that click commits immediately without a loading form.
local prefetched = new_player("prefetched")
join(prefetched, true)
run_after()
receive(prefetched, "grug_factions:select", {choose_accord = true})
receive(prefetched, "grug_classes:race", {choose_human = true})
local prefetched_request = emerge_requests[#emerge_requests]
finish_emerge(prefetched_request, {core.EMERGE_FROM_MEMORY})
assert_equal(prefetched.teleports, 0, "prefetch waits for class")
assert_equal(grug_classes.get_class(prefetched), nil, "prefetch class absent")
assert_dark_form(prefetched, "grug_classes:class", "prefetched class")
receive(prefetched, "grug_classes:class", {choose_mage = true})
assert_equal(prefetched.teleports, 1, "prefetched immediate teleport")
assert_equal(prefetched.formname, nil, "prefetched form closes")

-- Any failed block fails closed. The explicit retry gets a new request and a
-- successful second attempt performs the same single commit.
local retrying = new_player("retrying")
join(retrying, true)
run_after()
receive(retrying, "grug_factions:select", {choose_throng = true})
receive(retrying, "grug_classes:race", {choose_orc = true})
receive(retrying, "grug_classes:class", {choose_warrior = true})
local failed_request = emerge_requests[#emerge_requests]
finish_emerge(failed_request, {
	core.EMERGE_ERRORED, core.EMERGE_FROM_DISK,
})
assert_equal(grug_classes.get_class(retrying), nil, "failed class remains pending")
assert_equal(retrying.teleports, 0, "failed emerge does not teleport")
assert_locked(retrying, "failed emerge")
assert_dark_form(retrying, "grug_classes:loading", "failed loading")
assert_contains(retrying.formspec, "retry_spawn", "retry button")

local requests_before_retry = #emerge_requests
receive(retrying, "grug_classes:loading", {retry_spawn = true})
assert_equal(#emerge_requests, requests_before_retry + 1, "retry request")
finish_emerge(emerge_requests[#emerge_requests], {core.EMERGE_GENERATED})
assert_equal(grug_classes.get_class(retrying), "warrior", "retry class commit")
assert_equal(retrying.teleports, 1, "retry final teleport")

-- Disconnect after choosing a class but before emerge: the pending class is
-- transient. A stale callback may observe the new ObjectRef but cannot release
-- its new session; the player chooses again and only the new emerge commits.
local shared_meta = new_meta()
local old = new_player("rejoin", shared_meta)
join(old, true)
run_after()
receive(old, "grug_factions:select", {choose_accord = true})
receive(old, "grug_classes:race", {choose_dwarf = true})
receive(old, "grug_classes:class", {choose_priest = true})
local stale_request = emerge_requests[#emerge_requests]
leave(old)
assert_equal(grug_classes.get_class(old), nil, "pending class not persisted")

local rejoined = new_player("rejoin", shared_meta)
join(rejoined, false)
run_after()
assert_locked(rejoined, "rejoin")
assert_dark_form(rejoined, "grug_classes:class", "rejoin class")
local current_request = emerge_requests[#emerge_requests]
receive(rejoined, "grug_classes:class", {choose_priest = true})
finish_emerge(stale_request, {core.EMERGE_GENERATED})
assert_equal(rejoined.teleports, 0, "stale session cannot teleport")
assert_equal(grug_classes.get_class(rejoined), nil, "stale session cannot commit")
assert_locked(rejoined, "after stale callback")
finish_emerge(current_request, {core.EMERGE_FROM_DISK})
assert_equal(rejoined.teleports, 1, "current session teleport")
assert_equal(grug_classes.get_class(rejoined), "priest", "current class commit")

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

-- The ordinary public teleport wrapper still waits for a successful emerge.
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
	"wp45_character_creation_v1",
	"fresh_teleports=" .. fresh.teleports,
	"prefetched_teleports=" .. prefetched.teleports,
	"retry_teleports=" .. retrying.teleports,
	"rejoin_teleports=" .. rejoined.teleports,
	"class_sets=" .. class_sets,
	"chats=" .. #chats,
}, "|"))
