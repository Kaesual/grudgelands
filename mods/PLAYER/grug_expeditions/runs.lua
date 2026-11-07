-- Runs: the live Expeditions (Round 71). Nothing here is saved: a restart ends
-- every run. init.lua's header is the public contract.
local catalogue, preparation = ...
local M = grug_expeditions

local slots = {}          -- slot -> its live run
local by_player = {}      -- owner's name -> a player-owned run
local by_party = {}       -- party id -> a party-owned run
local inside_of = {}      -- name -> the run the player stands in
local next_id = 0
local hooks = {ready = {}, ended = {}, entered = {}, left = {}}

local function fire(event, ...)
	for _, callback in ipairs(hooks[event]) do callback(...) end
end

function M.register_on_ready(callback) hooks.ready[#hooks.ready + 1] = callback end
function M.register_on_end(callback) hooks.ended[#hooks.ended + 1] = callback end
function M.register_on_enter(callback) hooks.entered[#hooks.entered + 1] = callback end
function M.register_on_leave(callback) hooks.left[#hooks.left + 1] = callback end

local function name_of(player)
	return type(player) == "string" and player or player:get_player_name()
end

local function party_of(name)
	return grug_parties.view(name)
end

local function count(set)
	local n = 0
	for _ in pairs(set) do n = n + 1 end
	return n
end

local function belongs(run, name)
	if run.owner.kind == "player" then return run.owner.name == name end
	local party = party_of(name)
	return party ~= nil and party.id == run.owner.id
end

local function bind_owner(run)
	if run.owner.kind == "player" then
		by_player[run.owner.name] = run
	else
		by_party[run.owner.id] = run
	end
end

local function unbind_owner(run)
	if run.owner.kind == "player" then
		by_player[run.owner.name] = nil
	else
		by_party[run.owner.id] = nil
	end
end

-- ---- Reading ----------------------------------------------------------------

M.catalogue = catalogue
M.slot_at = catalogue.slot_at
M.slot_box = catalogue.slot_box
M.entry_level = catalogue.entry_level
M.definition = catalogue.definition
M.list = catalogue.list

function M.run_at(pos)
	local slot = catalogue.slot_at(pos)
	return slot and slots[slot] or nil
end

function M.run_of(player)
	local name = name_of(player)
	local party = party_of(name)
	if party then return by_party[party.id] end
	return by_player[name]
end

function M.run_inside(player)
	return inside_of[name_of(player)]
end

function M.belongs(run, player)
	return belongs(run, name_of(player))
end

function M.places(run) return run.places end
function M.encounters(run) return run.encounters end
function M.preparation(run) return preparation.status(run) end

-- Where a player stands on arrival and on a respawn: standing on the floor below
-- the template's `arrival` cell, beside the start waystone.
function M.start_arrival(run)
	local cell = run.places.arrival
	return {x = cell.x, y = cell.y - 0.49, z = cell.z}
end

-- ---- Eligibility -------------------------------------------------------------

local function run_level(id, bonus)
	local def = catalogue.definition(id)
	if not def then return nil, "That Expedition does not exist." end
	if type(bonus) ~= "number" or bonus % 1 ~= 0 or bonus < 0 or bonus > catalogue.MAX_BONUS then
		return nil, "That is not a level of this Expedition."
	end
	return def.level + bonus, def
end

function M.offered_levels(player, id)
	local def = catalogue.definition(id)
	local result = {}
	if not def then return result end
	local level = grug_xp.get_level(player)
	for bonus = 0, catalogue.MAX_BONUS do
		local run = def.level + bonus
		if level >= catalogue.entry_level(run) then
			result[#result + 1] = {bonus = bonus, level = run}
		end
	end
	return result
end

function M.eligibility(player, id, bonus)
	local level = run_level(id, bonus)
	local rows = {}
	if not level then return rows end
	local needed = catalogue.entry_level(level)
	local function row(name, player_level, online)
		rows[#rows + 1] = {name = name, level = player_level, online = online,
			eligible = player_level >= needed,
			reason = player_level < needed and ("Needs level " .. needed .. ".") or nil}
	end
	local party = party_of(name_of(player))
	if party then
		for _, member in ipairs(party.members) do row(member.name, member.level, member.online) end
	else
		row(name_of(player), grug_xp.get_level(player), true)
	end
	return rows
end

local function free_slot()
	for slot = 1, catalogue.SLOTS do
		if not slots[slot] then return slot end
	end
end

function M.can_create(player, id, bonus)
	local level, def = run_level(id, bonus)
	if not level then return false, def end
	local name = name_of(player)
	local party = party_of(name)
	if party and party.leader ~= name then
		return false, "Only your party leader can open an Expedition."
	end
	if M.run_of(player) then
		return false, party and "Your party already has an Expedition." or
			"You already have an Expedition."
	end
	local needed = catalogue.entry_level(level)
	if grug_xp.get_level(player) < needed then
		return false, "This level of the Expedition needs level " .. needed .. "."
	end
	if not free_slot() then return false, "Every Expedition site is taken. Try again soon." end
	return true
end

function M.can_enter(player, run)
	run = run or M.run_of(player)
	if not run then return false, "You have no Expedition." end
	local name = name_of(player)
	if run.state == "ended" then return false, "This Expedition has ended." end
	if not belongs(run, name) then return false, "This Expedition belongs to someone else." end
	if run.state == "preparing" then return false, "Your Expedition is still being prepared." end
	local needed = catalogue.entry_level(run.level)
	if grug_xp.get_level(player) < needed then
		return false, "This Expedition needs level " .. needed .. "."
	end
	if not run.entered[name] and count(run.entered) >= run.max_players then
		return false, "This Expedition is full."
	end
	if player:get_hp() <= 0 then return false, "You cannot travel now." end
	if grug_core.in_combat(player) then return false, "Cannot travel in combat." end
	return true
end

-- ---- The release clock --------------------------------------------------------
-- One core.after per stretch nobody of the owner is inside, from ready on: no
-- polling. A later stretch makes an earlier timer a no-op.

local function start_clock(run)
	run.clock = run.clock + 1
	local stretch = run.clock
	core.after(catalogue.RESERVE_SECONDS, function()
		if run.clock == stretch then M.end_run(run, "empty") end
	end)
end

local function stop_clock(run)
	run.clock = run.clock + 1
end

-- ---- Who stands inside ----------------------------------------------------------

local function mark_inside(run, name)
	run.inside[name] = true
	inside_of[name] = run
	if run.state == "ready" then run.state = "running" end
	stop_clock(run)
	fire("entered", run, name)
end

local function mark_left(run, name, reason)
	run.inside[name] = nil
	inside_of[name] = nil
	if run.state ~= "ended" and not next(run.inside) then start_clock(run) end
	fire("left", run, name, reason)
end

-- A forced way out, whatever the player's combat: to the capital they came from,
-- else home by the respawn path, which always ends somewhere. A dead player stays:
-- their respawn finds no run of theirs and goes home.
local function send_out(player, origin)
	if player:get_hp() <= 0 then return end
	grug_home.cancel(player)
	local way = origin and grug_home.waystone_pos(origin)
	if not way then return grug_home.respawn(player) end
	grug_home.travel(player, {
		pos = way,
		unavailable = "The way back could not be prepared.",
		check = function(p) return p:get_hp() > 0 end,
		arrival = function() return grug_home.waystone_arrival(origin) end,
		fallback = grug_home.respawn})
end

-- `name` holds no place any more; out of the box when inside. Offline, the login
-- rule sends them home.
local function expel(run, name, notice)
	run.entered[name] = nil
	local origin = run.origins[name]
	run.origins[name] = nil
	if inside_of[name] ~= run then return end
	mark_left(run, name, "expelled")
	local player = core.get_player_by_name(name)
	if player then
		core.chat_send_player(name, notice)
		send_out(player, origin)
	end
end

-- ---- Life of a run --------------------------------------------------------------

function M.end_run(run, reason)
	if run.state == "ended" then return end
	preparation.cancel(run)
	run.state = "ended"
	stop_clock(run)
	unbind_owner(run)
	slots[run.slot] = nil
	local names = {}
	for name in pairs(run.inside) do names[#names + 1] = name end
	table.sort(names)
	for _, name in ipairs(names) do
		local origin = run.origins[name]
		mark_left(run, name, "ended")
		local player = core.get_player_by_name(name)
		if player then
			core.chat_send_player(name, "Your Expedition has ended.")
			send_out(player, origin)
		end
	end
	fire("ended", run, reason)
end

local function prepared(run, ok)
	if run.state ~= "preparing" then return end
	if not ok then
		core.log("error", "[grug_expeditions] slot " .. run.slot .. " could not be prepared")
		return M.end_run(run, "failed")
	end
	run.state = "ready"
	start_clock(run)
	fire("ready", run)
end

local function absolute(minp, cell)
	return {x = minp.x + cell.x, y = minp.y + cell.y, z = minp.z + cell.z}
end

function M.create(player, id, bonus)
	local ok, reason = M.can_create(player, id, bonus)
	if not ok then return nil, reason end
	local def = catalogue.definition(id)
	local name = name_of(player)
	local party = party_of(name)
	local slot = free_slot()
	local minp, maxp = catalogue.slot_box(slot)
	local tpl = M.templates[def.template]
	next_id = next_id + 1
	local run = {id = next_id, slot = slot, expedition = id, level = def.level + bonus,
		bonus = bonus, max_players = def.max_players, creator = name, minp = minp, maxp = maxp,
		owner = party and {kind = "party", id = party.id} or {kind = "player", name = name},
		state = "preparing", entered = {}, inside = {}, origins = {}, places = {}, encounters = {},
		clock = 0}
	for place, cell in pairs(tpl.places) do run.places[place] = absolute(minp, cell) end
	for index, row in ipairs(tpl.encounters) do
		run.encounters[index] = {room = row.room, mob = row.mob, count = row.count,
			tier = row.tier, pos = absolute(minp, row.pos)}
	end
	slots[slot] = run
	bind_owner(run)
	preparation.enqueue(run, tpl, function(done) prepared(run, done) end)
	return run
end

-- The one place that learns where a player went: every teleport of the game ends
-- in grug_home's travel.lua, which reports here.
grug_home.register_on_teleport(function(player)
	local name = player:get_player_name()
	local was = inside_of[name]
	local run = M.run_at(player:get_pos())
	local now = run and run.entered[name] and run or nil
	if was == now then return end
	if was then mark_left(was, name, "travel") end
	if now then mark_inside(now, name) end
end)

-- An offline member does not count as inside.
core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	local run = inside_of[name]
	if run then mark_left(run, name, "logout") end
end)

-- The login rule: in a box without a live run that holds this player's place, the
-- run is over (a restart ended it, or the slot has a new run): straight home.
-- Nothing is stored for this: the saved position is all it needs. A dead player's
-- respawn goes home by itself.
core.register_on_joinplayer(function(player)
	local pos = player:get_pos()
	if not catalogue.slot_at(pos) then return end
	local name = player:get_player_name()
	local run = M.run_at(pos)
	if run and run.entered[name] then return mark_inside(run, name) end
	core.after(0, function()
		local p = core.get_player_by_name(name)
		if not p or p:get_hp() <= 0 then return end
		core.chat_send_player(name, "Your Expedition has ended.")
		grug_home.respawn(p)
	end)
end)

-- ---- Changes of owner -----------------------------------------------------------

-- A member left the party, whoever made them. The place goes with them. A party
-- fallen to one member leaves its Expedition to that member.
grug_parties.register_on_member_left(function(name, party_id, last)
	local run = by_party[party_id]
	if not run then return end
	if last then
		unbind_owner(run)
		run.owner = {kind = "player", name = last}
		bind_owner(run)
	end
	expel(run, name, "You left the party, and so its Expedition.")
end)

-- A solo owner in a party now: leading it (they invited someone), the Expedition
-- becomes the party's; a member of a foreign one, it ends and stays ended.
grug_parties.register_on_change(function(name, reason)
	local run = by_player[name]
	if not run or reason ~= "membership" then return end
	local party = party_of(name)
	if not party then return end
	if party.leader == name then
		unbind_owner(run)
		run.owner = {kind = "party", id = party.id}
		bind_owner(run)
	else
		M.end_run(run, "joined_party")
	end
end)

function M.enter(player, capital)
	local ok, reason = M.can_enter(player)
	if not ok then return false, reason end
	if not grug_home.waystone_pos(capital) then return false, "That is no way in." end
	local name = name_of(player)
	local run = M.run_of(player)
	local started = grug_home.travel(player, {
		pos = run.places.arrival,
		unavailable = "The way into the Expedition could not be prepared.",
		check = function(p)
			local still, why = M.can_enter(p, run)
			if not still then core.chat_send_player(name, why) end
			return still
		end,
		arrival = function()
			local arrival = grug_home.safe_arrival(M.start_arrival(run))
			if arrival then
				run.entered[name] = true
				run.origins[name] = capital
			end
			return arrival
		end})
	if not started then return false, "Travel is already being prepared." end
	return true
end

-- The way out of both waystones: to the capital the player came from, no
-- cooldown, through the same travel path.
function M.leave(player)
	local name = name_of(player)
	local run = inside_of[name]
	local origin = run and run.origins[name]
	if not origin then return false, "You are not in an Expedition." end
	if player:get_hp() <= 0 then return false, "You cannot travel now." end
	if grug_core.in_combat(player) then return false, "Cannot travel in combat." end
	local started = grug_home.travel(player, {
		pos = grug_home.waystone_pos(origin),
		unavailable = "The way back could not be prepared.",
		check = function(p) return p:get_hp() > 0 end,
		arrival = function() return grug_home.waystone_arrival(origin) end})
	if not started then return false, "Travel is already being prepared." end
	return true
end

function M.use_waystone(player)
	local ok, reason = M.leave(player)
	if not ok then core.chat_send_player(player:get_player_name(), reason) end
end

preparation.init(catalogue, function(player)
	-- Nobody belongs in a box being cleared.
	grug_home.respawn(player)
end)
