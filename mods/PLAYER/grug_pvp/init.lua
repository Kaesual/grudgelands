-- Geographic PvP (WP41, docs/planning/pvp-plan.md §2 and §4).
--
-- One small record per online player: the location flag, the button timer
-- and the last PvP contact. Two enemy players can hurt each other only while
-- both are flagged; combat code asks the gate (can_harm/can_support) and
-- never changes PvP state, so a hit costs one comparison. The location is
-- sampled once a second, never on the combat path. Pure rules: rules.lua.
--
-- Public API (the contract for the other lanes):
--   grug_pvp.flagged(player)                 -> bool
--   grug_pvp.can_harm(attacker, target)      -> enemy player pair, both flagged
--   grug_pvp.can_support(helper, target)     -> not (target flagged, helper not)
--   grug_pvp.contact(dealer, receiver)       after hostile damage landed
--   grug_pvp.support_contact(helper, target) after effective support
--   grug_pvp.flag_now(player)                the button
--   grug_pvp.state(player)   -> {flagged, reason, seconds_left, pvp_combat}
--     reason: "location_contested" | "location_enemy" | "button" | "contact"
--     | nil; seconds_left only for button and contact.
--   grug_pvp.stats(player)   -> copy of {kills, killing_blows, deaths, guards,
--     captains, generals, kings}
--   grug_pvp.register_on_change(fn(player, state)): whenever `flagged`,
--     `reason` or `pvp_combat` changes, and once at join. `state` is shared
--     by the callbacks: read it, never write it.
--   grug_pvp.count_npc_kill(player, kind): kind "guard" | "captain" |
--     "general" | "king"; enemy guards, royal guards and kings are counted
--     here already (grug_mobs' eligible-kill hook).
--
-- Persistence (player meta): the location flag on change and at leave, the
-- button on press, the contact at leave, the logout death at leave, the
-- counters on every kill and death.

grug_pvp = {}

local R = dofile(core.get_modpath(core.get_current_modname()) .. "/rules.lua")
grug_pvp.rules = R

local META_LOC = "grug_pvp:loc"
local META_BUTTON = "grug_pvp:button_until"
local META_CONTACT = "grug_pvp:contact_at"
local META_LOGOUT_DEATH = "grug_pvp:logout_death"
local META_STAT = "grug_pvp:stat_"

-- Location sampling period (s); grug_map/location.lua samples at the same
-- once-a-second cadence.
local TICK = 1

local records = {} -- player name -> rules record (online players)
local reported = {} -- player name -> the state the callbacks saw last
-- victim name -> {attacker name -> time of the last landed hit}; runtime only.
local damagers = {}
local change_callbacks = {}
local shutting_down = false

-- Comparison figures for the report: location samples and their summed cost.
grug_pvp.tick_stats = {samples = 0, us = 0}

-- Whole seconds of real time: the timers keep running while a player is
-- offline (pvp-plan §4).
local function now()
	return os.time()
end

local function record_of(player)
	return player and records[player:get_player_name()]
end

local function save_timers(player, rec)
	local meta = player:get_meta()
	meta:set_string(META_LOC, rec.loc or "")
	meta:set_string(META_BUTTON, rec.button_until > 0 and
		tostring(rec.button_until) or "")
	meta:set_string(META_CONTACT, rec.contact_at > 0 and
		tostring(rec.contact_at) or "")
end

local function load_record(player)
	local meta = player:get_meta()
	local loc = meta:get_string(META_LOC)
	return {
		loc = (loc == "contested" or loc == "enemy") and loc or false,
		button_until = tonumber(meta:get_string(META_BUTTON)) or 0,
		contact_at = tonumber(meta:get_string(META_CONTACT)) or 0,
	}
end

local function notify(player)
	local name = player:get_player_name()
	local rec = records[name]
	if not rec then
		return
	end
	local state = R.state(rec, now())
	if R.same_state(reported[name], state) then
		return
	end
	reported[name] = state
	for index = 1, #change_callbacks do
		change_callbacks[index](player, state)
	end
end

function grug_pvp.register_on_change(func)
	change_callbacks[#change_callbacks + 1] = func
end

function grug_pvp.flagged(player)
	local rec = record_of(player)
	return rec ~= nil and R.flagged(rec, now())
end

function grug_pvp.can_harm(attacker, target)
	if not (attacker and target and attacker:is_player() and target:is_player())
			or not grug_factions.hostile(attacker, target) then
		return false
	end
	local a, t = record_of(attacker), record_of(target)
	return a ~= nil and t ~= nil and R.can_harm(a, t, now())
end

function grug_pvp.can_support(helper, target)
	local t = target and target:is_player() and record_of(target)
	if not t then
		return true
	end
	local h = helper and helper:is_player() and record_of(helper)
	if not h then
		return not R.flagged(t, now())
	end
	return R.can_support(h, t, now())
end

-- Ruling 7a for both sides, ruling 8 (10 s PvP combat), and the damage
-- record the kill credit reads.
function grug_pvp.contact(dealer, receiver)
	local d, r = record_of(dealer), record_of(receiver)
	if not d or not r then
		return
	end
	local t = now()
	R.contact(d, t)
	R.contact(r, t)
	local receiver_name = receiver:get_player_name()
	local hits = damagers[receiver_name]
	if not hits then
		hits = {}
		damagers[receiver_name] = hits
	end
	hits[dealer:get_player_name()] = t
	grug_core.mark_in_combat(dealer, grug_core.PVP_COMBAT_TIMEOUT)
	grug_core.mark_in_combat(receiver, grug_core.PVP_COMBAT_TIMEOUT)
	notify(dealer)
	notify(receiver)
end

-- Ruling 7b: heal, shield or Renew on an own-faction player in PvP combat is
-- contact for the helper.
function grug_pvp.support_contact(helper, target)
	if helper == target then
		return
	end
	local h, t = record_of(helper), record_of(target)
	if not h or not t or not R.pvp_combat(t, now()) or
			not grug_factions.same_faction(helper, target) then
		return
	end
	R.contact(h, now())
	grug_core.mark_in_combat(helper, grug_core.PVP_COMBAT_TIMEOUT)
	notify(helper)
end

function grug_pvp.flag_now(player)
	local rec = record_of(player)
	if not rec then
		return false
	end
	R.press_button(rec, now())
	save_timers(player, rec)
	notify(player)
	return true
end

function grug_pvp.state(player)
	local rec = record_of(player)
	if not rec then
		return {flagged = false, pvp_combat = false}
	end
	return R.state(rec, now())
end

function grug_pvp.stats(player)
	local meta = player:get_meta()
	local copy = {}
	for _, key in ipairs(R.STAT_KEYS) do
		copy[key] = meta:get_int(META_STAT .. key)
	end
	return copy
end

local function add_stat(player, key)
	local meta = player:get_meta()
	meta:set_int(META_STAT .. key, meta:get_int(META_STAT .. key) + 1)
end

function grug_pvp.count_npc_kill(player, kind)
	local key = R.NPC_COUNTER[kind]
	if key and player and player:is_player() then
		add_stat(player, key)
	end
end

-- The seam grug_core's combat code asks (grug_core/combat.lua).
grug_core.pvp_can_harm = grug_pvp.can_harm
grug_core.pvp_hit_landed = function(attacker, target)
	if grug_factions.hostile(attacker, target) then
		grug_pvp.contact(attacker, target)
	end
end

--
-- Location (rulings 2 and 3)
--

local function sample(player, rec)
	local zones = rawget(_G, "grug_zones")
	local pos = player:get_pos()
	local own = grug_factions.get_faction(player)
	if not zones or not pos or not own then
		return
	end
	local rule = zones.pvp_rule_at(pos)
	local here = rule == "peaceful" and zones.faction_at(pos) or nil
	local loc = R.location(rec.loc, rule, here, own)
	if loc ~= rec.loc then
		rec.loc = loc
		player:get_meta():set_string(META_LOC, loc or "")
	end
end

-- Dead players keep their record untouched until the respawn (death cleared
-- it); players in character creation stand at the engine spawn.
local function samplable(player)
	return player:get_hp() > 0 and not (grug_core.player_in_creation_stasis and
		grug_core.player_in_creation_stasis(player:get_player_name()))
end

-- One pass: sample every player, then report expired timers and flag
-- changes. A second of lag at a border is harmless: for that moment the
-- player can neither hit nor be hit by the side that differs.
function grug_pvp.location_tick()
	local stats = grug_pvp.tick_stats
	for _, player in ipairs(core.get_connected_players()) do
		local rec = records[player:get_player_name()]
		if rec then
			if samplable(player) then
				local started = core.get_us_time()
				sample(player, rec)
				stats.samples = stats.samples + 1
				stats.us = stats.us + (core.get_us_time() - started)
			end
			notify(player)
		end
	end
end

local elapsed = 0
core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < TICK then
		return
	end
	elapsed = 0
	grug_pvp.location_tick()
end)

--
-- Kill credit and death (rulings 9, 10, 16)
--

-- Every enemy player online who landed damage on the victim in the last
-- 15 s gets a kill; the lethal hit's owner also the killing blow. The victim
-- counts a death to players when anyone got the kill.
local function settle_death(victim, killer)
	local victim_name = victim:get_player_name()
	local killer_name = killer and killer:is_player() and
		killer:get_player_name() or nil
	local credited = 0
	for _, name in ipairs(R.credited(damagers[victim_name], now())) do
		local player = core.get_player_by_name(name)
		if player and grug_factions.hostile(player, victim) then
			credited = credited + 1
			add_stat(player, "kills")
			if name == killer_name then
				add_stat(player, "killing_blows")
			end
		end
	end
	if credited > 0 then
		add_stat(victim, "deaths")
	end
	damagers[victim_name] = nil
end

core.register_on_dieplayer(function(player, reason)
	local rec = record_of(player)
	if not rec then
		return
	end
	-- A logout death was settled when the player left (below).
	if not (reason and reason.custom_type == grug_core.LOGOUT_DEATH_CUSTOM_TYPE) then
		local killer = reason and reason.type == "punch" and
			grug_core.damage_source(reason.object) or nil
		settle_death(player, killer)
	end
	R.clear(rec)
	save_timers(player, rec)
	notify(player)
end)

-- Ruling 9: leaving (or a disconnect) in PvP combat while flagged is death.
-- The kill is credited now and announced; the character starts dead at the
-- next join. The engine's leave callback is no place to kill, and a server
-- shutdown is no logout.
local function logout_death(player, rec)
	local name = player:get_player_name()
	settle_death(player, nil)
	local _, message = grug_core.death_message(name,
		{type = "set_hp", custom_type = grug_core.LOGOUT_DEATH_CUSTOM_TYPE})
	core.chat_send_all(message)
	player:get_meta():set_string(META_LOGOUT_DEATH, "1")
	R.clear(rec)
end

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local rec = load_record(player)
	records[name] = rec
	reported[name] = nil
	local meta = player:get_meta()
	if meta:get_string(META_LOGOUT_DEATH) == "1" then
		meta:set_string(META_LOGOUT_DEATH, "")
		R.clear(rec)
		save_timers(player, rec)
		-- After every join callback: the death then runs the ordinary
		-- respawn path (the bound innkeeper).
		core.after(0, function()
			local p = core.get_player_by_name(name)
			if p and p:get_hp() > 0 then
				p:set_hp(0, {type = "set_hp",
					custom_type = grug_core.LOGOUT_DEATH_CUSTOM_TYPE})
			end
		end)
	elseif samplable(player) then
		-- The location from the position; deep ocean keeps the stored value.
		sample(player, rec)
	end
	notify(player)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	local rec = records[name]
	if rec then
		if not shutting_down and player:get_hp() > 0 and
				R.logout_death(rec, now()) then
			logout_death(player, rec)
		end
		save_timers(player, rec)
	end
	records[name], reported[name], damagers[name] = nil, nil, nil
end)

-- The players are saved before they are kicked at shutdown, so the timers
-- are written here; the leave callbacks that follow do nothing else.
core.register_on_shutdown(function()
	shutting_down = true
	for _, player in ipairs(core.get_connected_players()) do
		local rec = record_of(player)
		if rec then
			save_timers(player, rec)
		end
	end
end)

--
-- NPC counters (ruling 16): enemy guards, royal guards and kings killed, for
-- every enemy player the kill credits (grug_mobs' eligible set: online and
-- within 40 m). Captains and generals call count_npc_kill or carry
-- `_grug_pvp_kind` on their entity.
--

local function npc_kind(ent)
	if ent._grug_pvp_kind then
		return ent._grug_pvp_kind
	end
	local name = ent.name or ""
	if name == "grug_mobs:guard_accord" or name == "grug_mobs:guard_throng" or
			name:find("^grug_mobs:royal_guard_") then
		return "guard"
	end
	if name:find("^grug_mobs:king_") then
		return "king"
	end
	return nil
end

if core.global_exists("grug_mobs") and grug_mobs.register_on_eligible_kill then
	grug_mobs.register_on_eligible_kill(function(player, ent)
		local kind = npc_kind(ent)
		if kind and ent._grug_faction and grug_factions.get_faction(player) ==
				grug_core.opposing_faction(ent._grug_faction) then
			grug_pvp.count_npc_kill(player, kind)
		end
	end)
end

--
-- Admin help for the two-client test (pvp-plan §8). Level and position use
-- the existing /xp give and /teleport.
--

local function describe(name)
	local player = core.get_player_by_name(name)
	local rec = records[name]
	if not player or not rec then
		return nil
	end
	local t = now()
	local state = R.state(rec, t)
	local lines = {name .. ": " .. (state.flagged and
		("flagged (" .. state.reason .. (state.seconds_left and
			(", " .. state.seconds_left .. " s left") or "") .. ")") or "safe") ..
		(state.pvp_combat and ", in PvP combat" or "")}
	lines[#lines + 1] = "location " .. (rec.loc or "none") ..
		", button " .. math.max(0, rec.button_until - t) .. " s" ..
		", last contact " .. (rec.contact_at > 0 and
			((t - rec.contact_at) .. " s ago") or "never")
	local stats = grug_pvp.stats(player)
	local parts = {}
	for _, key in ipairs(R.STAT_KEYS) do
		parts[#parts + 1] = key .. " " .. stats[key]
	end
	lines[#lines + 1] = table.concat(parts, ", ")
	return table.concat(lines, "\n")
end

core.register_chatcommand("pvpstate", {
	params = "[<player>]",
	description = "Show a player's PvP flag, timers and statistics",
	privs = {server = true},
	func = function(name, param)
		local target = param:trim() ~= "" and param:trim() or name
		local text = describe(target)
		if not text then
			return false, "Player '" .. target .. "' is not online."
		end
		return true, text
	end,
})
