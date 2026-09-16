--
-- The central player movement aggregator (user ruling 2026-09-16;
-- docs/design/skill_trees.md §3.9 + rulings 11 and 26,
-- docs/research/mob-pressure-task-card.md §4b).
--
-- Ruling 11, verbatim: "effects overlap freely with independent durations;
-- the design is one central aggregator in grug_core where each system
-- registers a named modifier with its own duration; a root is a hard flag
-- (speed 0 regardless of modifiers), never a '-1000 %'; mounts stay outside
-- the aggregator."
--
-- Ruling 26, verbatim: "The movement aggregator combines additively, per
-- axis, with one clamp. clamp(1 + Sum, 0.1, 1.5) for speed and for jump; a
-- root or an exclusive hold takes precedence over the sum."
--
-- THIS FILE IS THE ONLY WRITER OF `physics_override` IN THE GAME.
-- `grep -rn set_physics_override mods/` must find exactly one call site, the
-- one in `write` below. Before this file there were three writers (mob webs
-- in grug_mobs/verbs.lua, the PvP snare chain in grug_abilities/kits.lua and
-- the character-creation freeze in grug_classes/selection.lua) and they
-- clobbered each other: each restored to `speed = 1` when its own effect
-- ended, so the first restore lifted every overlapping effect, and the
-- creation freeze additionally restored a SNAPSHOT taken when creation
-- began -- a slow running at that moment was written back permanently.
--
-- What is deliberately NOT here:
--   * mounts and boats. Their speed is the mount/boat ENTITY's velocity
--     (mounts.md §3, boats.md §5), never a physics override, so they never
--     enter the sum and a dismount can never be cancelled by a running slow.
--   * gravity as an axis. No effect in the design scales gravity; the only
--     gravity writer the game ever had is the character-creation freeze,
--     which is an exclusive HOLD here, not a modifier. A hold writes
--     gravity 0 and its release writes gravity 1, and nothing else in this
--     file touches the field.
--   * mob speed. Mobs are entities with their own run_velocity/walk_velocity
--     and their own root/slow countdowns in grug_mobs (init.lua, ticked in
--     do_custom because a mob can unload mid-timer). This aggregator is for
--     PLAYERS only.
--
-- Everything expires on a monotonic clock read at USE time, so there is no
-- core.after chain to orphan, no generation counter, and a relog cannot
-- leave a stale timer behind: leaveplayer drops the whole record.
--

local SPEED_MIN = 0.1
local SPEED_MAX = 1.5
local JUMP_MIN = 0.1
local JUMP_MAX = 1.5

-- One recompute per player per this many seconds of server time, so an
-- expiry is written back to the engine even when nothing else calls in.
-- AGENTS.md: "Always throttle register_globalstep with a dtime accumulator."
local STEP_INTERVAL = 0.1

-- player name -> {
--   mods  = {name -> {speed = delta, jump = delta, expiry = t or nil}},
--   root  = expiry or nil,
--   immune = expiry or nil,
--   holds = {name -> true},
--   n_holds = count,
--   last  = {speed = n, jump = n, gravity = n or nil},  -- last values WRITTEN
-- }
local state = {}

local function now()
	return grug_core.mono_time()
end

local function record(name)
	local rec = state[name]
	if not rec then
		rec = {mods = {}, holds = {}, n_holds = 0, last = {}}
		state[name] = rec
	end
	return rec
end

local function clamp(value, low, high)
	if value < low then return low end
	if value > high then return high end
	return value
end

-- Drop everything whose expiry has passed. Called before every read and
-- every write, so "expired" and "cleared" are the same state everywhere.
local function prune(rec, t)
	local mods = rec.mods
	local dead
	for key, entry in pairs(mods) do
		if entry.expiry and entry.expiry <= t then
			dead = dead or {}
			dead[#dead + 1] = key
		end
	end
	if dead then
		for index = 1, #dead do
			mods[dead[index]] = nil
		end
	end
	if rec.root and rec.root <= t then
		rec.root = nil
	end
	if rec.immune and rec.immune <= t then
		rec.immune = nil
	end
end

-- Is this record still worth a globalstep and a table entry?
local function idle(rec)
	if rec.root or rec.immune or rec.n_holds > 0 then
		return false
	end
	return next(rec.mods) == nil
end

--
-- The combination rule (ruling 26), as a pure function of the record.
--
-- Precedence, highest first:
--   1. an exclusive HOLD   -> speed 0, jump 0, gravity 0
--   2. a ROOT (hard flag)  -> speed 0, jump 0
--   3. clamp(1 + Sum, 0.1, 1.5) per axis
--
-- Immunity "discards negatives and roots": while it runs, a root cannot be
-- set and any running one is dropped (set_root/set_move_immunity below), and
-- negative modifier deltas are skipped in the sum. Positive ones (a sprint)
-- still count -- immunity protects, it does not suppress your own buffs.
-- A slow applied during immunity is not refused; it is simply inert, and it
-- expires on its own clock, so a 3 s immunity does not swallow a 7 s web.
local function combine(rec, t)
	if rec.n_holds > 0 then
		return 0, 0, 0
	end
	local immune = rec.immune ~= nil and rec.immune > t
	if rec.root and not immune then
		return 0, 0, nil
	end
	local speed_sum, jump_sum = 0, 0
	for _, entry in pairs(rec.mods) do
		local s, j = entry.speed, entry.jump
		if not (immune and s < 0) then
			speed_sum = speed_sum + s
		end
		if not (immune and j < 0) then
			jump_sum = jump_sum + j
		end
	end
	return clamp(1 + speed_sum, SPEED_MIN, SPEED_MAX),
		clamp(1 + jump_sum, JUMP_MIN, JUMP_MAX), nil
end

--
-- The single engine write.
--
-- `force` re-reads the player's ACTUAL override and compares against that
-- instead of against what we last wrote -- that is what the character
-- creation watchdog needs (grug_classes/selection.lua): it exists precisely
-- because some other code may have written the field behind our back.
-- Ordinary calls compare against the cached last write and skip the engine
-- round trip, which matters because the globalstep below runs over every
-- player with live state.
--
-- `gravity` is nil except while a hold is active or has just been released;
-- set_physics_override is a partial update (l_object.cpp), so leaving it out
-- keeps the field untouched.
local function write(player, rec, force)
	local t = now()
	prune(rec, t)
	local speed, jump, gravity = combine(rec, t)
	local last = rec.last
	if gravity == nil and last.gravity ~= nil then
		gravity = 1 -- the hold ended: hand gravity back exactly once
	end
	-- `last.gravity` means "this file currently owns the field". It is 0
	-- while a hold runs and nil again the moment gravity 1 is handed back,
	-- so a settled player holds no state at all.
	local owned = (gravity ~= nil and gravity ~= 1) and gravity or nil
	if not force and last.speed == speed and last.jump == jump
			and gravity == nil then
		return speed, jump
	end
	if force then
		local live = player:get_physics_override() or {}
		if live.speed == speed and live.jump == jump
				and (gravity == nil or live.gravity == gravity) then
			last.speed, last.jump, last.gravity = speed, jump, owned
			return speed, jump
		end
	end
	local override = {speed = speed, jump = jump}
	if gravity ~= nil then
		override.gravity = gravity
	end
	player:set_physics_override(override)
	last.speed, last.jump, last.gravity = speed, jump, owned
	return speed, jump
end

-- Recompute and write, then forget the player entirely if nothing is left.
local function settle(player, name, rec)
	write(player, rec, false)
	if idle(rec) then
		state[name] = nil
	end
end

local function resolve(player)
	if not player or not core.is_player(player) then
		return nil, nil
	end
	local name = player:get_player_name()
	return name, record(name)
end

--
-- Public API
--
-- Every duration is in SECONDS and is measured from the moment of the call.
-- A nil duration means "until something clears it" (there is no consumer of
-- that today; every shipped effect is time-limited).
--

-- Register or replace the named modifier `name` on `player`.
-- `effect` carries fractional DELTAS per axis: -0.40 is "40 % slower",
-- +0.25 is "25 % faster". A missing axis is 0, i.e. untouched.
-- Re-registering the same name replaces that entry (refresh); two different
-- names overlap freely and add up, which is the ruling.
function grug_core.set_move_modifier(player, name, effect, duration)
	local pname, rec = resolve(player)
	if not pname or not name then
		return
	end
	local t = now()
	rec.mods[name] = {
		speed = tonumber(effect and effect.speed) or 0,
		jump = tonumber(effect and effect.jump) or 0,
		expiry = duration and (t + duration) or nil,
	}
	settle(player, pname, rec)
end

function grug_core.clear_move_modifier(player, name)
	local pname, rec = resolve(player)
	if not pname or not name then
		return
	end
	rec.mods[name] = nil
	settle(player, pname, rec)
end

-- What is currently registered under `name`, or nil. `remaining` is seconds
-- (nil for an endless entry). Callers that need "the stronger effect wins"
-- semantics for their OWN name do that merge here, in their own file, rather
-- than pushing a stacking policy into the aggregator (grug_mobs.slow_player
-- is the one such caller today).
function grug_core.get_move_modifier(player, name)
	local pname, rec = resolve(player)
	if not pname or not name then
		return nil
	end
	local t = now()
	prune(rec, t)
	local entry = rec.mods[name]
	if not entry then
		return nil
	end
	return {
		speed = entry.speed,
		jump = entry.jump,
		remaining = entry.expiry and (entry.expiry - t) or nil,
	}
end

-- The hard flag of ruling 11: speed 0 and jump 0 for `duration` seconds,
-- regardless of every modifier. Refused outright while a root/slow immunity
-- runs.
function grug_core.set_root(player, duration)
	local pname, rec = resolve(player)
	if not pname then
		return false
	end
	local t = now()
	prune(rec, t)
	if rec.immune then
		return false -- immune: the root is discarded, not queued
	end
	rec.root = t + (duration or 0)
	settle(player, pname, rec)
	return true
end

function grug_core.clear_root(player)
	local pname, rec = resolve(player)
	if not pname then
		return
	end
	rec.root = nil
	settle(player, pname, rec)
end

-- Root/slow immunity for `duration` seconds: drops a running root and makes
-- every negative modifier inert while it lasts (see `combine`). This is the
-- seam WP11's Hold Ground and Shake Loose are specified against
-- (skill_trees.md §3.9); nothing calls it yet.
function grug_core.set_move_immunity(player, duration)
	local pname, rec = resolve(player)
	if not pname then
		return
	end
	rec.immune = now() + (duration or 0)
	rec.root = nil
	settle(player, pname, rec)
end

function grug_core.clear_move_immunity(player)
	local pname, rec = resolve(player)
	if not pname then
		return
	end
	rec.immune = nil
	settle(player, pname, rec)
end

-- An EXCLUSIVE hold: the player does not move at all, and gravity is off
-- too, until every holder has released. It outranks the sum and the root
-- flag both, it is not timed, and it releases exactly (no snapshot is taken
-- and none is restored -- releasing returns the player to whatever the
-- modifiers say at that moment, which is the whole point of ruling 11).
function grug_core.hold_movement(player, name)
	local pname, rec = resolve(player)
	if not pname or not name then
		return
	end
	if not rec.holds[name] then
		rec.holds[name] = true
		rec.n_holds = rec.n_holds + 1
	end
	-- force: the hold is a watchdog as well as a state, so it re-asserts
	-- itself against any write that happened behind our back.
	write(player, rec, true)
end

function grug_core.release_movement(player, name)
	local pname, rec = resolve(player)
	if not pname or not name then
		return
	end
	if rec.holds[name] then
		rec.holds[name] = nil
		rec.n_holds = rec.n_holds - 1
	end
	write(player, rec, false)
	if idle(rec) then
		state[pname] = nil
	end
end

function grug_core.is_movement_held(player, name)
	local pname, rec = resolve(player)
	if not pname then
		return false
	end
	if name then
		return rec.holds[name] == true
	end
	return rec.n_holds > 0
end

-- Introspection for KATs, HUDs and diagnostics. Never returns nil for a
-- connected player: with no effects at all the baseline is 1/1.
function grug_core.get_move_state(player)
	local pname, rec = resolve(player)
	if not pname then
		return nil
	end
	local t = now()
	prune(rec, t)
	local speed, jump = combine(rec, t)
	local count = 0
	for _ in pairs(rec.mods) do
		count = count + 1
	end
	return {
		speed = speed,
		jump = jump,
		rooted = rec.root ~= nil,
		immune = rec.immune ~= nil,
		held = rec.n_holds > 0,
		modifiers = count,
	}
end

-- Drop every effect and write the baseline back. Used by the join reset and
-- available to anything that has to clean a player up (death, admin).
function grug_core.clear_movement(player)
	local pname, rec = resolve(player)
	if not pname then
		return
	end
	rec.mods = {}
	rec.root = nil
	rec.immune = nil
	rec.holds = {}
	rec.n_holds = 0
	write(player, rec, true)
	state[pname] = nil
end

-- Re-assert the computed override against the player's LIVE physics, for
-- code that knows something else may have written the field. One engine
-- read, and a write only on a mismatch.
function grug_core.reassert_movement(player)
	local pname, rec = resolve(player)
	if not pname then
		return
	end
	write(player, rec, true)
end

--
-- Lifecycle
--
-- Physics overrides are not persisted by the engine, so a join starts from
-- 1/1/1 whatever ran before the relog. Dropping the record is therefore the
-- complete reset: there is no timer to cancel (see the header).
--

core.register_on_joinplayer(function(player)
	state[player:get_player_name()] = nil
end)

core.register_on_leaveplayer(function(player)
	state[player:get_player_name()] = nil
end)

--
-- Expiry. Nothing else drives it: a modifier that runs out while the player
-- does nothing still has to reach the engine. The loop only walks players
-- who currently have state, and `write` skips the engine call when the
-- numbers did not move, so an idle server pays one table walk per 0.1 s.
--

local step_accumulator = 0

core.register_globalstep(function(dtime)
	step_accumulator = step_accumulator + dtime
	if step_accumulator < STEP_INTERVAL then
		return
	end
	step_accumulator = 0
	if next(state) == nil then
		return
	end
	local names
	for name in pairs(state) do
		names = names or {}
		names[#names + 1] = name
	end
	for index = 1, #names do
		local name = names[index]
		local rec = state[name]
		local player = rec and core.get_player_by_name(name)
		if player then
			settle(player, name, rec)
		elseif rec then
			state[name] = nil
		end
	end
end)
