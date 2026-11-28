-- Disposable engine probe (Round 89 lane UI): the status row's duration
-- covers and the Waystones tab with the longest home names, for
-- screenshots. Never shipped: tools/r89_ui/capture.sh stages it through
-- tools/luanti_headless.sh and connects one real client. The driver
-- (character creation, SHOT / ack handshake) follows tools/r88_stats' probe.
--
-- A timeline from the moment the character stands ready (t = 0):
--   0 s  poisoned (30 s), food (100 s), a shield of 120 points (200 s) and a
--        mount (untimed) as stored statuses;
--   10 s the potion cooldown (30 s; a status source, first seen by the row);
--   25.5 s Sidestep (30 s), fresh;
--   then SHOT row_a (SETTLE later): a fresh (Sidestep), an almost-run-out
--        (poisoned, about 2 s left), a half-run (the potion), a quarter-run (food), a
--        shield (its points as the caption) and an untimed effect (mount);
--   then SHOT row_b about 8 s later (poisoned gone, the others on);
--   then the Waystones tab of a stone with the Claim Stone entry named
--        24 W (list_w24) and a 20-letter player's default (list_default27).
-- Before each row shot the row's entries are logged with their remaining
-- and whole time and the cover step the row draws.

local P = "[r89ui] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r89ui_settle") or "") or 2

local function log(msg) core.log("action", P .. msg) end

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r89ui_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local icons = grug_core.status_icons
local function log_row(player)
	local now = core.get_us_time()
	for _, entry in ipairs(grug_core.status_display(player)) do
		local total = entry.started_us and entry.expiry_us and entry.expiry_us - entry.started_us
		local step = total and icons.cover_step(entry.remaining_us, total)
		log(("ROW %s caption=%q left=%s total=%s step=%s"):format(entry.id, entry.caption,
			entry.remaining_us and ("%.1f"):format(entry.remaining_us / 1e6) or "-",
			total and ("%.1f"):format(total / 1e6) or "(first seen)",
			step and tostring(step) or "-"))
	end
	log(("ROW at %.1f"):format(now / 1e6))
end

local function list_with(player, label)
	local faction = grug_factions.get_faction(player)
	local pos = vector.round(player:get_pos())
	grug_home.claim_waypoint = function()
		return {id = "claim:999", claim = "999", faction = faction, label = label,
			pos = vector.new(pos), arrival = vector.new(pos)}
	end
	grug_home.show_waystones(player, {id = "r89ui_probe", label = "Probe", pos = pos})
end

local TIMELINE = {
	{at = 0, run = function(player)
		grug_core.set_status(player, "poisoned", {duration = 30, label = "Poisoned"})
		grug_core.set_status(player, "food", {duration = 100})
		grug_core.set_status(player, "shield", {duration = 200, label = "Shield",
			value = function() return 120 end})
		grug_core.set_status(player, "mount", {untimed = true, variant = "land"})
	end},
	{at = 10, run = function(player) grug_traders.start_potion_cooldown(player) end},
	{at = 25.5, run = function(player)
		grug_core.set_status(player, "sidestep", {duration = 30, label = "Sidestep"})
	end},
	{at = 25.5, shot = "row_a", run = log_row},
	{at = 32, shot = "row_b", run = log_row},
	{at = 33, shot = "list_w24", run = function(player) list_with(player, ("W"):rep(24)) end},
	{at = 34, shot = "list_default27", run = function(player)
		list_with(player, ("W"):rep(20) .. "'s Home")
	end},
}

local state = {phase = "wait", clock = 0, t = 0, index = 1}

core.register_globalstep(function(dtime)
	state.clock = state.clock + dtime
	if state.clock < 0.25 then return end
	local step = state.clock
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if state.phase == "wait" then
		if not grug_core.world_preparation_status().ready then return end
		if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
		if not grug_classes.get_class(player) then
			submit(player, "", {faction_accord = "Accord"})
			submit(player, "", {race_dwarf = "Dwarf"})
			submit(player, "", {class_warrior = "Warrior"})
			submit(player, "", {create_character = "Create"})
			return
		end
		core.close_formspec(NAME, "")
		grug_xp.set_xp(player, grug_xp.xp_for_level(20))
		player:set_physics_override({gravity = 0, speed = 0, jump = 0})
		log("READY")
		state.phase = "run"
		return
	end
	if state.phase ~= "run" then return end
	state.t = state.t + step
	local item = TIMELINE[state.index]
	if not item then
		state.phase = "done"
		log("shutdown")
		core.request_shutdown("probe done", false, 0)
		return
	end
	if not item.ran then
		if state.t < item.at then return end
		item.ran = true
		item.run(player)
		log(("ran %s at %.1f"):format(item.shot or ("step " .. state.index), state.t))
		item.waited = 0
		if not item.shot then state.index = state.index + 1 end
		return
	end
	item.waited = item.waited + step
	if not item.logged and item.waited >= SETTLE then
		item.logged = true
		if item.shot:sub(1, 4) == "row_" then log_row(player) end
		log("SHOT " .. item.shot)
	elseif item.logged and read_ack() == item.shot then
		state.index = state.index + 1
	end
end)
