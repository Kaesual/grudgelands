-- Join slots for per-player periodic passes (Round 81 HOT; audit X4-05,
-- AGENTS.md "No pass handles every player or zone in one step").
--
-- grug_core.register_player_pass(period, fn) calls fn(player, elapsed) for
-- every connected player once per `period` seconds, spread over SLOTS
-- slots: the pass ticks every period / SLOTS seconds and visits the players
-- of one slot, so each player still comes up once per period. A player
-- joins the slot holding the fewest players (the lowest of equals) and keeps
-- it until leaving, so the slots stay even however players come and go.
-- `elapsed` is the game time since this pass last visited the player (since
-- the join on the first visit): a pass that adds up over time (regeneration,
-- damage per second) keeps its sums. A server step serves every tick its
-- time has reached, at most MAX_TICKS of them, so a tick shorter than the
-- server step keeps the period (the 0.5 s passes tick every 1/16 s against
-- 0.09 s steps: one or two slots per step, each player every 0.5 s). Time
-- beyond MAX_TICKS ticks is dropped: a server stall collapses to MAX_TICKS
-- ticks, never a burst of catch-up ticks (as atmosphere_zones.lua); the next
-- visit's `elapsed` covers the gap. Only a period shorter than
-- SLOTS / MAX_TICKS server steps (0.36 s at 0.09 s) stretches. Each pass
-- starts on another slot than the pass registered before it, so passes
-- of the same period mostly visit different players on the same step (on
-- a step that serves two ticks, neighbouring passes may share one slot;
-- the work per step stays the same). A player who
-- leaves during a tick may make one other player of that slot miss this
-- tick (never a second visit); that player's next `elapsed` covers it.

local SLOTS = 8
local MAX_TICKS = 2 -- slots one pass serves per server step at most
grug_core.PLAYER_PASS_SLOTS = SLOTS

local members, counts = {}, {} -- slot -> list of names; slot -> #list
for slot = 1, SLOTS do
	members[slot], counts[slot] = {}, 0
end
local slot_of, index_of, refs, joined_at = {}, {}, {}, {} -- by player name
local passes = {}
local clock = 0 -- game time, the sum of the server steps' dtime

-- Run fn(player, elapsed) for every player once per `period` seconds, one
-- slot of players per period / SLOTS seconds (the 0.5 s status pass: one
-- slot every 1/16 s). At load time.
function grug_core.register_player_pass(period, fn)
	assert(type(period) == "number" and period > 0, "player pass: period")
	assert(type(fn) == "function", "player pass: function")
	passes[#passes + 1] = {tick = period / SLOTS, fn = fn, acc = 0,
		slot = #passes % SLOTS, last = {}}
end

-- The slot a player's passes visit (nil while offline); for fixtures and
-- probes.
function grug_core.player_pass_slot(name)
	return slot_of[name]
end

local function visit(pass)
	local list, last, fn = members[pass.slot], pass.last, pass.fn
	local i = 1
	while list[i] do
		local name = list[i]
		local player = refs[name]
		local elapsed = clock - (last[name] or joined_at[name])
		last[name] = clock
		fn(player, elapsed)
		i = i + 1
	end
end

core.register_globalstep(function(dtime)
	clock = clock + dtime
	for p = 1, #passes do
		local pass = passes[p]
		local tick = pass.tick
		local acc = pass.acc + dtime
		local served = 0
		while acc >= tick and served < MAX_TICKS do
			acc = acc - tick
			served = served + 1
			pass.slot = pass.slot % SLOTS + 1
			visit(pass)
		end
		if acc >= tick then acc = acc % tick end
		pass.acc = acc
	end
end)

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local best = 1
	for slot = 2, SLOTS do
		if counts[slot] < counts[best] then best = slot end
	end
	local list = members[best]
	list[#list + 1] = name
	counts[best] = #list
	slot_of[name], index_of[name], refs[name], joined_at[name] = best, #list, player, clock
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	local slot = slot_of[name]
	if not slot then return end
	local list, i = members[slot], index_of[name]
	local moved = list[#list]
	list[i], index_of[moved] = moved, i
	list[#list] = nil
	counts[slot] = #list
	slot_of[name], index_of[name], refs[name], joined_at[name] = nil, nil, nil, nil
	for p = 1, #passes do
		passes[p].last[name] = nil
	end
end)
