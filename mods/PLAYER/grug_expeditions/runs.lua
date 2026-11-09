-- Runs: the live Expeditions (Round 71). Nothing here is saved: a restart ends
-- every run. init.lua's header is the public contract.
local catalogue, preparation = ...
local M = grug_expeditions

local slots = {}          -- slot -> its live run
local by_player = {}      -- owner's name -> a player-owned run
local by_party = {}       -- party id -> a party-owned run
local inside_of = {}      -- name -> the run the player stands in
local next_id = 0
local hooks = {ready = {}, ended = {}, entered = {}, left = {}, closing = {}}
-- Saved player meta: the waystone of the last way in (a capital's at the registrar),
-- for a login or a respawn that outlives the run; and a pending logout death
-- (packs.lua).
local META_ORIGIN = "grug_expeditions:origin"
M.LOGOUT_DEATH = "grug_expeditions:logout_death"
-- And since Round 72.1 the end of a Deserter's Mark: the wall clock's os.time(), so
-- the mark runs on through a logout and a restart.
M.DESERTER_META = "grug_expeditions:deserter_until"

local function fire(event, ...)
	for _, callback in ipairs(hooks[event]) do callback(...) end
end

function M.register_on_ready(callback) hooks.ready[#hooks.ready + 1] = callback end
function M.register_on_end(callback) hooks.ended[#hooks.ended + 1] = callback end
function M.register_on_enter(callback) hooks.entered[#hooks.entered + 1] = callback end
function M.register_on_leave(callback) hooks.left[#hooks.left + 1] = callback end
-- Round 72.2: Finish or Cancel started the countdown (callback(run, reason, by)).
function M.register_on_close(callback) hooks.closing[#hooks.closing + 1] = callback end

local function name_of(player)
	return type(player) == "string" and player or player:get_player_name()
end

local function notice(player, text)
	grug_core.feed(player, "notice", text, "expedition")
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
	if type(bonus) ~= "number" or bonus % 1 ~= 0 or bonus < 0 or bonus > def.max_level - def.level then
		return nil, "That is not a level of this Expedition."
	end
	return def.level + bonus, def
end

function M.offered_levels(player, id)
	local def = catalogue.definition(id)
	local result = {}
	if not def then return result end
	local level = grug_xp.get_level(player)
	for bonus = 0, def.max_level - def.level do
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

-- ---- The Deserter's Mark (Round 72.1) ------------------------------------------------
-- Whoever cancels an Expedition, or leaves one unfinished for a foreign party, can
-- neither open nor enter one for catalogue.DESERTER_SECONDS. name -> its end in
-- os.time(), read from the meta at a join: the rules below ask no meta.
local marks = {}

-- The whole seconds the player's mark still runs, or nil.
function M.deserter_left(player)
	local name = name_of(player)
	local ends = marks[name]
	if not ends then return nil end
	local left = ends - os.time()
	if left > 0 then return left end
	marks[name] = nil
end

local function deserter_text(left)
	return ("Deserter's Mark: no Expeditions for %d:%02d."):format(math.floor(left / 60), left % 60)
end

local function mark_deserter(name)
	local ends = os.time() + catalogue.DESERTER_SECONDS
	marks[name] = ends
	local player = core.get_player_by_name(name)
	if not player then return end
	player:get_meta():set_string(M.DESERTER_META, tostring(ends))
	grug_core.feed(player, "notice", deserter_text(catalogue.DESERTER_SECONDS), "expedition_mark")
end

local function free_slot()
	for slot = 1, catalogue.SLOTS do
		if not slots[slot] then return slot end
	end
end

function M.can_create(player, id, bonus)
	local level, def = run_level(id, bonus)
	if not level then return false, def end
	local marked = M.deserter_left(player)
	if marked then return false, deserter_text(marked) end
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

-- The seconds until a closing run ends (Round 72.1), rounded up: 0 only at its end.
local function remaining(run)
	return (run.closing.ends_at - core.get_us_time()) / 1e6
end
function M.closing_left(run)
	if not run.closing then return nil end
	return math.max(0, math.ceil(remaining(run)))
end

-- The run's own rules, whatever the player's state: owner, the Deserter's Mark,
-- state, closing, level and places. What the Expeditions tab lists (entry.lua);
-- can_enter adds the player's state.
function M.may_enter(player, run)
	run = run or M.run_of(player)
	if not run then return false, "You have no Expedition." end
	local name = name_of(player)
	if run.state == "ended" then return false, "This Expedition has ended." end
	if not belongs(run, name) then return false, "This Expedition belongs to someone else." end
	local marked = M.deserter_left(player)
	if marked then return false, deserter_text(marked) end
	if run.state == "preparing" then return false, "Your Expedition is still being prepared." end
	if run.closing then
		if run.closing.reason == "cancelled" then return false, "This Expedition was cancelled." end
		if M.closing_left(run) <= catalogue.CLOSED_SECONDS then
			return false, "This Expedition is closing."
		end
	end
	local needed = catalogue.entry_level(run.level)
	if grug_xp.get_level(player) < needed then
		return false, "This Expedition needs level " .. needed .. "."
	end
	if not run.entered[name] and count(run.entered) >= run.max_players then
		return false, "This Expedition is full."
	end
	return true
end

function M.can_enter(player, run)
	local ok, why = M.may_enter(player, run)
	if not ok then return false, why end
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

-- ---- The countdown of a closing run (Round 72.1) -----------------------------------
-- The banner line, once a second to everyone inside: each call replaces the text
-- and restarts its clear, so it stands for the whole countdown.

local function seconds_text(left)
	return left == 1 and "1 second" or (left .. " seconds")
end

local function show_countdown(run, name, left)
	local player = core.get_player_by_name(name)
	if not player then return end
	local text = run.closing.reason == "cancelled" and "This Expedition was cancelled. It ends in %s." or
		"This Expedition ends in %s."
	grug_core.banner(player, text:format(seconds_text(left)))
end

-- ---- Who stands inside ----------------------------------------------------------

local function mark_inside(run, name)
	run.inside[name] = true
	inside_of[name] = run
	if run.state == "ready" then run.state = "running" end
	stop_clock(run)
	-- Whoever arrives during a countdown sees it from their arrival on.
	if run.closing then show_countdown(run, name, M.closing_left(run)) end
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

-- The capital this player last came in from: a value that outlives the run.
function M.saved_origin(player)
	local origin = player:get_meta():get_string(META_ORIGIN)
	return origin ~= "" and origin or nil
end

-- `name` holds no place any more; out of the box when inside. Offline, the login
-- rule sends them out.
local function expel(run, name)
	run.entered[name] = nil
	local origin = run.origins[name]
	run.origins[name] = nil
	if inside_of[name] ~= run then return end
	mark_left(run, name, "expelled")
	local player = core.get_player_by_name(name)
	if player then send_out(player, origin) end
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
		if player then send_out(player, origin) end
	end
	fire("ended", run, reason)
end

-- ---- Finish and Cancel (Round 72.1) ----------------------------------------------
-- One closing path for both: run.closing = {reason, by, ends_at}, the end after
-- catalogue.CLOSING_SECONDS through end_run, and one core.after a second while it
-- counts down (each when the shown number drops). The owner still holds the run until then; the release clock goes on
-- as before, and whichever end comes first wins.

local function countdown(run)
	if run.state == "ended" then return end
	local rest = remaining(run)
	if rest <= 0 then return M.end_run(run, run.closing.reason) end
	local left = math.ceil(rest)
	for name in pairs(run.inside) do show_countdown(run, name, left) end
	-- The next call when the number drops, so a late step skips none.
	core.after(rest - (left - 1), function() countdown(run) end)
end

-- The online players of the owner outside the box hear it once; those inside see
-- the countdown.
local function close(run, reason, by)
	run.closing = {reason = reason, by = by,
		ends_at = core.get_us_time() + catalogue.CLOSING_SECONDS * 1e6}
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		if not run.inside[name] and belongs(run, name) then
			notice(player, ("%s %s the Expedition. It ends in %s."):format(
				name == by and "You" or by, reason, seconds_text(catalogue.CLOSING_SECONDS)))
		end
	end
	countdown(run)
	if run.state ~= "ended" then fire("closing", run, reason, by) end
end

-- Only the party's current leader, or the solo owner.
local function leads(run, name)
	if run.owner.kind == "player" then return run.owner.name == name end
	local party = party_of(name)
	return party ~= nil and party.id == run.owner.id and party.leader == name
end

-- What Finish and Cancel both ask: the player's run, led by them, ready or under way
-- and not closing yet. The run, or nil and why.
local function closable(player, run, verb)
	run = run or M.run_of(player)
	if not run or run.state == "ended" then return nil, "You have no Expedition." end
	if not leads(run, name_of(player)) then
		return nil, "Only your party leader can " .. verb .. " the Expedition."
	end
	if run.state == "preparing" then
		return nil, "Your Expedition is still being prepared. Wait until it is ready."
	end
	if run.closing then return nil, "This Expedition is already closing." end
	return run
end

-- Finish: once the boss is dead, or the template has none.
function M.can_finish(player, run)
	local why
	run, why = closable(player, run, "finish")
	if not run then return false, why end
	if not M.rewards_open(run) then
		return false, "The Expedition can be finished once its boss is dead."
	end
	return true
end

-- Cancel: any run that cannot be finished, ready and never entered too.
function M.can_cancel(player, run)
	local why
	run, why = closable(player, run, "cancel")
	if not run then return false, why end
	if M.rewards_open(run) then return false, "The boss is dead: finish the Expedition instead." end
	return true
end

-- What Cancel's confirmation says first.
M.CANCEL_CONFIRM = ("Cancel this Expedition? You cannot open or enter an Expedition for %d minutes.")
	:format(catalogue.DESERTER_SECONDS / 60)

function M.finish(player)
	local ok, why = M.can_finish(player)
	if not ok then return false, why end
	close(M.run_of(player), "finished", name_of(player))
	return true
end

-- The canceller alone gets the Deserter's Mark, at the click. With nobody inside the
-- run ends at once.
function M.cancel(player)
	local ok, why = M.can_cancel(player)
	if not ok then return false, why end
	local run, name = M.run_of(player), name_of(player)
	mark_deserter(name)
	if next(run.inside) then
		close(run, "cancelled", name)
	else
		M.end_run(run, "cancelled")
	end
	return true
end

-- What a run's owner reads about its state: the registrar's window and the
-- Expeditions tab.
local PREPARING = "Your Expedition is being prepared..."
function M.state_text(run)
	if run.state == "preparing" then
		local status = M.preparation(run)
		local ahead = status and status.waiting or 0
		if ahead > 0 then return ("%s %d ahead in the queue."):format(PREPARING, ahead) end
		return PREPARING
	end
	if run.closing then
		return ("%s It ends in %s."):format(run.closing.reason == "cancelled" and "Cancelled." or
			"Finished.", seconds_text(M.closing_left(run)))
	end
	if run.state == "ready" then
		return ("Ready. It waits %d minutes for you."):format(catalogue.RESERVE_SECONDS / 60)
	end
	return "Under way."
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
	marks[name] = nil
	local run = inside_of[name]
	if run then mark_left(run, name, "logout") end
end)

-- The login rule: in a box without a live run that holds this player's place, the
-- run is over (a restart ended it, or the slot has a new run): back in the capital
-- they came from, whose id is the one saved value (a restart forgets run.origins),
-- else home. A dead player's respawn asks the same (guard.lua), and so does a
-- pending logout death's, which runs after this (packs.lua).
core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	-- A Deserter's Mark still running is the rules' again; a spent one goes.
	local meta = player:get_meta()
	local ends = tonumber(meta:get_string(M.DESERTER_META))
	if ends and ends > os.time() then
		marks[name] = ends
	elseif ends then
		meta:set_string(M.DESERTER_META, "")
	end
	local pos = player:get_pos()
	if not catalogue.slot_at(pos) then return end
	local run = M.run_at(pos)
	if run and run.entered[name] then return mark_inside(run, name) end
	core.after(0, function()
		local p = core.get_player_by_name(name)
		if not p or p:get_hp() <= 0 then return end
		notice(p, "Your Expedition has ended.")
		if p:get_meta():get_string(M.LOGOUT_DEATH) == "" then send_out(p, M.saved_origin(p)) end
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
	expel(run, name)
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
		-- A run left unfinished marks its owner (Round 72.1): not one the boss of is
		-- dead, nor one already finished or cancelled.
		local deserted = not run.closing and not M.rewards_open(run)
		M.end_run(run, "joined_party")
		if deserted then mark_deserter(name) end
	end
end)

-- `capital`: the waystone the way back leads to (a registrar's capital, or since
-- Round 72 the waystone of the Expeditions tab). `still(player)`, when given, is one
-- more condition asked on the trip's step (the tab's: still at the stone).
function M.enter(player, capital, still)
	local ok, reason = M.can_enter(player)
	if not ok then return false, reason end
	if not grug_home.waystone_pos(capital) then return false, "That is no way in." end
	local name = name_of(player)
	local run = M.run_of(player)
	local started = grug_home.travel(player, {
		pos = run.places.arrival,
		unavailable = "The way into the Expedition could not be prepared.",
		check = function(p)
			local stands, why = M.can_enter(p, run)
			if stands and still and not still(p) then stands, why = false, "Travel canceled." end
			if not stands then notice(p, why) end
			return stands
		end,
		arrival = function()
			local arrival = grug_home.safe_arrival(M.start_arrival(run))
			if arrival then
				run.entered[name] = true
				run.origins[name] = capital
				player:get_meta():set_string(META_ORIGIN, capital)
			end
			return arrival
		end})
	if not started then return false, "Travel is already being prepared." end
	return true
end

-- The way back to the capital the player came from, no cooldown, through the same
-- travel path. Round 71's stones; since Round 72 they open the waystone window
-- (entry.lua) and this stays the scripted way out.
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

preparation.init(catalogue, function(player)
	-- Nobody belongs in a box being cleared.
	grug_home.respawn(player)
end)
