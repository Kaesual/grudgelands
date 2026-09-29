-- Character creation flow: faction (grug_factions) -> race -> class, all
-- mandatory, all final. While the flow is incomplete the player remains
-- frozen and engine-immortal (creation stasis). The final teleport waits for
-- the selected server-wide preparation plan. Existing characters reconnecting
-- during preparation wait without changing position.
--
-- Creation can always be paused (Round 24 ruling 32). Esc really closes every
-- creation dialog and nothing here re-opens it by itself, so the next Esc
-- reaches the native game menu. The current step is always the player's
-- inventory formspec (sfinv is suspended meanwhile), so the inventory key
-- continues; a HUD hint says so while no dialog is open. Every choice is
-- written to player meta at once, including the class picked while the
-- arrival area still loads, so a reconnect resumes at the first missing step.

local RACE_FORM = "grug_classes:race"
local CLASS_FORM = "grug_classes:class"
local LOADING_FORM = "grug_classes:loading"
local FACTION_FORM = grug_factions.SELECTION_FORM
-- The class chosen before the arrival area is loaded. Only the final teleport
-- turns it into grug_classes:class, and nothing else reads this key: a pending
-- class never completes a character, never ends stasis and never skips the
-- start teleport.
local META_PENDING_CLASS = "grug_classes:pending_class"
local STASIS_CHECK_INTERVAL = 0.1
local DARK_BACKGROUND = "no_prepend[]" ..
	"bgcolor[#080808FF;both;#000000FF]"

local CREATION_FORMS = {
	[FACTION_FORM] = true,
	[RACE_FORM] = true,
	[CLASS_FORM] = true,
	[LOADING_FORM] = true,
}

-- The screen hint while no creation dialog is open.
local HINT = {
	paused = "Character creation paused \226\128\147 press I to continue",
	ready = "World ready \226\128\147 press I to continue",
	failed = "The area could not be loaded \226\128\147 press I to try again",
	-- An existing character reconnecting while the world is still prepared.
	waiting = "Preparing the world \226\128\147 press I to see progress",
}

-- Per-session state; the persistent faction/race/class/pending-class meta is
-- the source of truth. Session fields:
--   dismissed        the player closed the dialog with Esc; nothing re-opens
--                    it until the player acts (inventory key, a choice)
--   shown_name/form  what the open dialog shows (send-on-change)
--   inventory_form   the player's inventory formspec (send-on-change)
--   ready_notice     preparation became ready while dismissed
--   hint_id/text     the HUD hint
local creation_sessions = {}

local continue_creation
local start_spawn_load
local finish_if_ready
local present

local function copy_table(source)
	local result = {}
	for key, value in pairs(source or {}) do
		result[key] = value
	end
	return result
end

local function character_complete(player)
	return grug_factions.get_faction(player) ~= nil and
		grug_classes.get_race(player) ~= nil and
		grug_classes.get_class(player) ~= nil
end

local function pending_class(player)
	local id = player:get_meta():get_string(META_PENDING_CLASS)
	return grug_classes.registered_classes[id] and id or nil
end

local function set_pending_class(player, id)
	player:get_meta():set_string(META_PENDING_CLASS, id or "")
end

-- The name this file holds the movement aggregator under. One name, released
-- exactly (grug_core/movement.lua): holds are counted, so an unbalanced
-- release can never free a player another holder is still freezing.
local MOVEMENT_HOLD = "class_creation"

local function stop_velocity(player)
	local velocity = player:get_velocity()
	if velocity and (velocity.x ~= 0 or velocity.y ~= 0 or velocity.z ~= 0) then
		player:add_velocity({
			x = -velocity.x,
			y = -velocity.y,
			z = -velocity.z,
		})
	end
end

-- The creation freeze is an EXCLUSIVE HOLD on the grug_core movement
-- aggregator (ruling 11, 2026-09-16; skill_trees.md §3.9), not a physics
-- write of its own. `hold_movement` is idempotent AND re-asserting: it
-- compares against the player's live override and rewrites it on a mismatch,
-- which is exactly the watchdog this function used to be -- some later mod
-- may write the field after join, and a frozen player must not drift loose.
local function reassert_player_lock(player)
	grug_core.hold_movement(player, MOVEMENT_HOLD)
	stop_velocity(player)
	local armor = copy_table(player:get_armor_groups())
	if armor.immortal ~= 1 then
		armor.immortal = 1
		player:set_armor_groups(armor)
	end
end

local function lock_player(player)
	if character_complete(player) and grug_core.world_preparation_status().ready then
		return nil
	end
	local name = player:get_player_name()
	local session = creation_sessions[name]
	if not session then
		local armor = player:get_armor_groups() or {}
		-- NO PHYSICS SNAPSHOT. The old code captured speed/jump/gravity here
		-- and wrote them back in release_player, which meant a slow running
		-- at the moment creation began was captured and restored PERMANENTLY
		-- after the aggregator believed it had expired -- the precise bug
		-- class ruling 11 exists to end (skill_trees.md §3.9). Releasing the
		-- hold hands the player back to whatever the aggregator says at that
		-- moment, which for a fresh character is the 1/1/1 baseline.
		session = {previous_immortal = armor.immortal,
			preparation_only = character_complete(player),
			preparation_ready = grug_core.world_preparation_status().ready,
			dismissed = false}
		creation_sessions[name] = session
	end
	reassert_player_lock(player)
	return session
end

local function release_player(player, session)
	local name = player:get_player_name()
	if creation_sessions[name] ~= session then
		return false
	end
	stop_velocity(player)
	grug_core.release_movement(player, MOVEMENT_HOLD)
	local armor = copy_table(player:get_armor_groups())
	armor.immortal = session.previous_immortal
	player:set_armor_groups(armor)
	creation_sessions[name] = nil
	if session.hint_id then
		player:hud_remove(session.hint_id)
	end
	set_pending_class(player, nil)
	core.close_formspec(name, CLASS_FORM)
	core.close_formspec(name, LOADING_FORM)
	-- Hand the inventory back to sfinv; its suspension ended with the session.
	if sfinv.enabled then
		sfinv.set_player_inventory_formspec(player)
	end
	return true
end

-- While a creation session exists, the inventory formspec is the current
-- creation step (see the GRUG PATCH in mods/BASE/sfinv/api.lua).
local sfinv_inventory_suspended = sfinv.inventory_suspended
function sfinv.inventory_suspended(player)
	return creation_sessions[player:get_player_name()] ~= nil or
		sfinv_inventory_suspended(player)
end

local function options_formspec(title, subtitle, options)
	local parts = {
		"formspec_version[4]",
		"size[10.5," .. (2.2 + #options * 1.5) .. "]",
		DARK_BACKGROUND,
		"label[0.5,0.7;" .. core.formspec_escape(title) .. "]",
		"label[0.5,1.3;" .. core.formspec_escape(subtitle) .. "]",
	}
	for i, opt in ipairs(options) do
		local y = 0.9 + i * 1.5
		table.insert(parts, ("button[0.5,%.1f;2.8,1.2;choose_%s;%s]"):format(
			y, opt.id, core.formspec_escape(opt.name)))
		table.insert(parts, ("label[3.6,%.1f;%s]"):format(
			y + 0.6, core.formspec_escape(opt.description or "")))
	end
	return table.concat(parts)
end

local function race_formspec(faction_id)
	local options = {}
	for _, id in ipairs(grug_classes.race_ids[faction_id] or {}) do
		table.insert(options, grug_classes.registered_races[id])
	end
	return options_formspec("Choose your race!",
		"Where in the " .. grug_core.factions[faction_id].name ..
		" lands do you come from? This decision is final.", options)
end

local function class_formspec()
	local options = {}
	for _, id in ipairs(grug_classes.class_ids) do
		table.insert(options, grug_classes.registered_classes[id])
	end
	return options_formspec("Choose your class!",
		"How will you fight? This decision is final.", options)
end

local function loading_formspec(status, failed)
	local scope = status.mode == "full" and "the world surface" or "the starting areas"
	local eta = "Estimating time remaining..."
	if status.eta_seconds then
		local minutes = math.ceil(status.eta_seconds / 60)
		eta = ("Time remaining: %dh %02dm"):format(math.floor(minutes / 60), minutes % 60)
	end
	local parts = {
		"formspec_version[4]", "size[10.4,3.5]", DARK_BACKGROUND,
		"label[0.6,0.7;" .. core.formspec_escape(
			("Preparing %s: %d%%"):format(scope, math.floor(status.percent))) .. "]",
	}
	if failed then
		parts[#parts + 1] = "label[0.6,1.4;" .. core.formspec_escape(
			"The area could not be loaded. You remain safe here.") .. "]"
		parts[#parts + 1] = "button[3.6,2.1;3.2,0.8;retry_spawn;Try again]"
	elseif status.ready then
		parts[#parts + 1] = "label[0.6,1.4;Preparing your arrival location... ]"
	else
		parts[#parts + 1] = "label[0.6,1.4;" .. core.formspec_escape(eta) .. "]"
		parts[#parts + 1] = "label[0.6,2.2;You may disconnect and return later.]"
	end
	return table.concat(parts)
end

-- The current creation step: "faction", "race", "class", "waiting" (shared
-- preparation or this player's arrival area) or "failed" (with retry), plus
-- its form name and formspec. Choices are only offered once the selected
-- world preparation is complete.
local function current_step(player, session)
	local status = grug_core.world_preparation_status()
	if not status.ready then
		return status.failed and "failed" or "waiting", LOADING_FORM,
			loading_formspec(status, status.failed)
	end
	if not session.preparation_only then
		local faction = grug_factions.get_faction(player)
		if not faction then
			return "faction", FACTION_FORM, grug_factions.selection_formspec()
		end
		if not grug_classes.get_race(player) then
			return "race", RACE_FORM, race_formspec(faction)
		end
		if not grug_classes.get_class(player) and not pending_class(player) then
			return "class", CLASS_FORM, class_formspec()
		end
	end
	local failed = session.load_failed ~= nil or grug_core.starts_preload_failed()
	return failed and "failed" or "waiting", LOADING_FORM,
		loading_formspec(status, failed)
end

local function hint_text(session, step)
	if not session.dismissed then
		return ""
	elseif step == "failed" then
		return HINT.failed
	elseif session.preparation_only then
		return HINT.waiting
	elseif session.ready_notice and step ~= "waiting" then
		return HINT.ready
	end
	return HINT.paused
end

local function update_hint(player, session, text)
	if text == (session.hint_text or "") then
		return
	end
	session.hint_text = text
	if session.hint_id then
		player:hud_change(session.hint_id, "text", text)
	else
		session.hint_id = player:hud_add(grug_core.hud_layout.text_element(
			"creation_hint", {number = grug_core.FLASH_COLOR.notice,
				text = text, style = 1}))
	end
end

-- Renders the current step everywhere it lives: always as the inventory
-- formspec, as the dialog only while one is open (never re-opened here), and
-- as the hint while none is. `open` = the player acted (join, a choice, a
-- retry): show the step as a dialog again. Every write is send-on-change, so
-- throttled progress notifications cost no packet when nothing moved.
present = function(player, open)
	local name = player:get_player_name()
	local session = creation_sessions[name]
	if not session then
		return nil
	end
	if open then
		session.dismissed = false
		session.ready_notice = false
	end
	local step, formname, form = current_step(player, session)
	if session.inventory_form ~= form then
		session.inventory_form = form
		player:set_inventory_formspec(form)
	end
	if not session.dismissed and
			(session.shown_name ~= formname or session.shown_form ~= form) then
		session.shown_name = formname
		session.shown_form = form
		core.show_formspec(name, formname, form)
	end
	update_hint(player, session, hint_text(session, step))
	return step
end

-- Esc closed the dialog (the client already did it). Only the hint changes.
local function dismiss(player, session)
	session.dismissed = true
	session.shown_name = nil
	session.shown_form = nil
	present(player)
end

local function identity_key(player)
	local faction = grug_factions.get_faction(player)
	local race = grug_classes.get_race(player)
	if not faction or not race then
		return nil
	end
	return faction .. ":" .. race
end

-- Read by grug_factions' earlier-registered respawn callback. A dead,
-- incomplete player stays in the one creation transaction instead of taking
-- an eager respawn teleport before the destination is emerged.
function grug_core.player_in_creation_stasis(name)
	return creation_sessions[name] ~= nil
end

-- Loads THIS player's arrival area and caches the position it belongs to.
-- The server-wide startup preload (grug_core/starts_preload.lua) proves the
-- six starts were GENERATED; it does not keep them loaded — blocks unload
-- again after server_unload_unused_data_timeout. A character created an hour
-- after server start would otherwise teleport into unloaded space, so the
-- single teleport still happens only after its own successful emerge. Once
-- the blocks exist on disk this returns almost immediately.
local function start_arrival_load(player)
	local session = creation_sessions[player:get_player_name()]
	local key = identity_key(player)
	if not session or not key then
		return false
	end
	session.loading = true
	session.load_generation = (session.load_generation or 0) + 1
	local generation = session.load_generation
	local name = player:get_player_name()
	local started = grug_factions.prepare_spawn(player,
		function(_, spawn, failure)
			-- Deferred by one step on purpose: on an identity change this
			-- reaction starts a REPLACEMENT emerge, and core.emerge_area must
			-- never be called from inside an emerge completion callback
			-- (the shutdown deadlock documented in starts_preload.lua).
			core.after(0, function()
				local p = core.get_player_by_name(name)
				local current = creation_sessions[name]
				if not p or current ~= session or
						current.load_generation ~= generation then
					return
				end
				current.loading = false
				if identity_key(p) ~= key then
					current.spawn_key = nil
					current.load_failed = nil
					continue_creation(p)
					return
				end
				if not spawn then
					-- Updates an open dialog or the hint; never forces one open.
					current.load_failed = failure or "spawn_unavailable"
					present(p)
					return
				end
				current.spawn_ready = true
				current.spawn_pos = spawn
				finish_if_ready(p)
			end)
		end)
	if not started then
		session.loading = false
		session.load_failed = "spawn_unavailable"
		present(player)
		return false
	end
	return true
end

-- Binds the pending start identity. The arrival load above may only start
-- once the selected world preparation is complete: before that it
-- would compete with the startup preload for the same mapgen threads.
start_spawn_load = function(player)
	local session = creation_sessions[player:get_player_name()]
	local key = identity_key(player)
	if not session or not key then
		return false
	end
	if session.spawn_key == key and
			(session.loading or session.spawn_ready or session.load_failed) then
		return true
	end
	session.spawn_key = key
	session.spawn_ready = false
	session.spawn_pos = nil
	session.load_failed = nil
	session.loading = false
	local ready, total = grug_core.starts_ready()
	if ready < total then
		return true
	end
	return start_arrival_load(player)
end

finish_if_ready = function(player)
	local name = player:get_player_name()
	local session = creation_sessions[name]
	if not session then
		return false
	end
	if not grug_core.world_preparation_status().ready then
		present(player)
		return false
	end
	if session.preparation_only then
		return release_player(player, session)
	end
	-- The class comes from meta: a class chosen in an earlier session (the
	-- player disconnected while the arrival area loaded) is applied here too.
	local class_id = grug_classes.get_class(player) or pending_class(player)
	local key = identity_key(player)
	if not key or not class_id then
		present(player)
		return false
	end
	local ready, total = grug_core.starts_ready()
	if ready < total then
		-- Gate one: the selected shared preparation plan must complete.
		-- Nothing of this player's own is loaded
		-- while the shared preload still runs.
		session.spawn_key = key
		present(player)
		return false
	end
	if session.spawn_key ~= key then
		-- An admin may change race/faction after a prefetch completed. Retire
		-- the cached position and its callback generation before loading the
		-- new one.
		session.load_generation = (session.load_generation or 0) + 1
		session.spawn_key = nil
		session.spawn_ready = false
		session.spawn_pos = nil
		session.load_failed = nil
		session.loading = false
		start_spawn_load(player)
		present(player)
		return false
	end
	-- Gate two: this player's own arrival area is loaded RIGHT NOW.
	if not session.spawn_ready then
		if not session.loading and not session.load_failed then
			start_spawn_load(player)
		end
		if creation_sessions[name] ~= session then
			return true
		end
		present(player)
		return false
	end

	-- Position first, then persist the final identity. A disconnect before the
	-- asynchronous load completes therefore cannot leave a fully-created
	-- character behind at the unsafe engine spawn.
	grug_core.invalidate_combat_identity(player)
	player:set_pos(session.spawn_pos)
	stop_velocity(player)
	if not grug_classes.get_class(player) and
			not grug_classes.set_class(player, class_id) then
		session.load_failed = "class_unavailable"
		present(player)
		return false
	end
	if player:get_hp() <= 0 then
		player:set_hp(grug_classes.get_max_hp(player),
			{type = "set_hp", from = "mod"})
	end
	if not release_player(player, session) then
		return false
	end
	local def = grug_classes.get_class_def(player)
	core.chat_send_player(name, core.colorize("#ffd100",
		"You are now a " .. def.name .. ". Your journey begins!"))
	return true
end

-- Continues at the next missing creation step, if any. `open` shows that step
-- as a dialog even when the player had dismissed it (join); otherwise only an
-- already open dialog changes.
continue_creation = function(player, open)
	local session = creation_sessions[player:get_player_name()]
	if session then
		reassert_player_lock(player)
	else
		session = lock_player(player)
	end
	if not session then
		return
	end
	if open then
		session.dismissed = false
		session.ready_notice = false
	end
	if not grug_core.world_preparation_status().ready then
		present(player)
		return
	end
	if session.preparation_only then
		finish_if_ready(player)
		return
	end
	if grug_factions.get_faction(player) and grug_classes.get_race(player) then
		start_spawn_load(player)
		if grug_classes.get_class(player) or pending_class(player) then
			finish_if_ready(player)
			return
		end
	end
	present(player)
end

-- Status effects and future mods may write physics after the join callbacks.
-- Reassert only active stasis sessions, compare before writing, and throttle
-- the pass so ordinary players pay only the cheap interval/table check.
local stasis_check_elapsed = 0
core.register_globalstep(function(dtime)
	stasis_check_elapsed = stasis_check_elapsed + dtime
	if stasis_check_elapsed < STASIS_CHECK_INTERVAL then
		return
	end
	stasis_check_elapsed = stasis_check_elapsed % STASIS_CHECK_INTERVAL
	for name in pairs(creation_sessions) do
		local player = core.get_player_by_name(name)
		if player then
			reassert_player_lock(player)
		end
	end
end)

local function chosen_id(fields)
	for field in pairs(fields) do
		local id = field:match("^choose_(.+)$")
		if id then
			return id
		end
	end
	return nil
end

-- Applies one submitted choice (or retry) for the current step. Every choice
-- is persisted at once; the class is kept as the pending class until the
-- arrival teleport.
local function act_on_step(player, session, step, fields)
	if step == "faction" then
		-- grug_factions.set_faction runs the faction-chosen callback below.
		grug_factions.choose_from_fields(player, fields)
	elseif step == "race" then
		if grug_classes.set_race(player, chosen_id(fields) or "") then
			local def = grug_classes.get_race_def(player)
			core.chat_send_player(player:get_player_name(),
				"You are a " .. def.name .. ".")
		end
		continue_creation(player)
	elseif step == "class" then
		local id = chosen_id(fields)
		if id and grug_classes.registered_classes[id] then
			set_pending_class(player, id)
		end
		continue_creation(player)
	elseif step == "failed" and fields.retry_spawn then
		session.spawn_key = nil
		session.load_failed = nil
		-- Retry the failed preparation unit without resetting its cursor,
		-- then retry a new character's separate arrival load if needed.
		grug_core.request_starts_preload()
		if not session.preparation_only then start_spawn_load(player) end
		finish_if_ready(player)
	end
end

-- Named creation dialogs and the inventory formspec ("") during creation.
-- The inventory formspec always shows the current step; a named dialog only
-- answers for the step it shows, so a late click on a replaced dialog is
-- ignored. Form fields are client input: nothing is committed for a step that
-- is not current (e.g. before world preparation is ready).
core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "" and not CREATION_FORMS[formname] then
		return
	end
	local session = creation_sessions[player:get_player_name()]
	if not session then
		-- A creation dialog after completion is stale; "" is sfinv's again.
		if formname ~= "" then
			return true
		end
		return
	end
	local step, step_form = current_step(player, session)
	local current = formname == "" or formname == step_form
	local acts
	if step == "failed" then
		acts = fields.retry_spawn ~= nil
	else
		acts = step ~= "waiting" and chosen_id(fields) ~= nil
	end
	if current and acts then
		-- The player acts: the next step replaces this one as a dialog, also
		-- when the choice came from the inventory formspec.
		session.dismissed = false
		session.ready_notice = false
		act_on_step(player, session, step, fields)
		present(player)
	elseif fields.quit then
		-- Esc closed it. Stasis stays; nothing re-opens it, so the next Esc
		-- reaches the native game menu.
		dismiss(player, session)
	end
	return true
end)

grug_factions.register_on_faction_chosen(function(player, faction_id)
	continue_creation(player)
end)

-- The scheduler supplies one throttled progress stream for either plan.
-- Progress and failures update an open dialog or the hint, never force a
-- dialog open. Readiness replaces an open waiting screen with the next step;
-- a dismissed one only changes the hint.
grug_core.register_on_preparation_progress(function(status)
	for name, session in pairs(creation_sessions) do
		local player = core.get_player_by_name(name)
		if player then
			if status.ready then
				if not session.preparation_ready and session.dismissed then
					session.ready_notice = true
				end
				session.preparation_ready = true
				continue_creation(player)
			else
				session.preparation_ready = false
				present(player)
			end
		end
	end
end)

core.register_on_joinplayer(function(player)
	if not lock_player(player) then
		return
	end
	local name = player:get_player_name()
	-- Run after every mod's join callback, and reassert the creation lock
	-- before the first ordinary server step. The reason used to be grug_mobs'
	-- own join reset, which wrote speed = 1 later in load order; that handler
	-- is gone with the movement aggregator (ruling 11), and the aggregator's
	-- own join handler runs FIRST because every consumer declares
	-- `depends = grug_core`. The re-lock stays anyway: this is a watchdog, and
	-- a later mod may still write the field after join -- which is exactly
	-- what `hold_movement` re-asserts against. A join opens the first missing
	-- step as a dialog.
	core.after(0, function()
		local p = core.get_player_by_name(name)
		if p and creation_sessions[name] then
			reassert_player_lock(p)
			continue_creation(p, true)
		end
	end)
end)

-- New-player callbacks run before the server sends the initial position. This
-- prevents even the first gravity/damage tick at the engine-selected spawn.
core.register_on_newplayer(function(player)
	lock_player(player)
end)

core.register_on_leaveplayer(function(player)
	creation_sessions[player:get_player_name()] = nil
end)

--
-- Info/admin commands
--

core.register_chatcommand("char", {
	description = "Show your character (faction, race, class, attributes)",
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then
			return false
		end
		local faction = grug_factions.get_faction_def(player)
		local race = grug_classes.get_race_def(player)
		local class = grug_classes.get_class_def(player)
		local a = grug_classes.get_attributes(player)
		return true, ("%s %s %s, level %d | Str %d Int %d Dex %d | " ..
			"HP %d/%d, mana %d | melee +%d, spell +%d, crit %.1f%%, dodge %.1f%%"):format(
			faction and faction.name or "factionless",
			race and race.name or "raceless",
			class and class.name or "classless",
			grug_xp.get_level(player),
			a.str, a.int, a.dex,
			player:get_hp(), grug_classes.get_max_hp(player),
			grug_classes.get_max_mana(player),
			grug_classes.get_melee_bonus(player),
			grug_classes.get_spell_power_bonus(player),
			grug_classes.get_crit_chance(player) * 100,
			grug_classes.get_dodge_chance(player) * 100)
	end,
})

local function register_set_command(cmd, setter, getter_def, is_id)
	core.register_chatcommand(cmd, {
		params = "[<player>] [<" .. cmd .. ">]",
		description = "Show a player's " .. cmd .. " or (as admin) set it",
		func = function(name, param)
			local target_name, id = param:match("^(%S+)%s+(%S+)$")
			-- Single token: a valid id means "set my own" (e.g. /class mage).
			if not target_name and is_id(param) then
				target_name, id = name, param
			end
			target_name = target_name or (param ~= "" and param) or name

			local target = core.get_player_by_name(target_name)
			if not target then
				return false, "Player '" .. target_name .. "' is not online."
			end
			if id then
				if not core.check_player_privs(name, {server = true}) then
					return false, "You need the 'server' privilege for this."
				end
				local session = creation_sessions[target_name]
				if cmd == "class" and session and
						not grug_classes.get_class(target) and is_id(id) then
					-- An admin-picked first class is a pending class too: writing
					-- grug_classes:class before the prepared teleport would let a
					-- reconnect skip stasis at the unsafe engine spawn.
					set_pending_class(target, id)
					continue_creation(target)
				elseif not setter(target, id) then
					return false, "Invalid " .. cmd .. ": " .. id
				else
					continue_creation(target)
				end
				return true, target_name .. "'s " .. cmd .. " is now " .. id .. "."
			end
			local def = getter_def(target)
			return true, target_name .. ": " .. (def and def.name or "none")
		end,
	})
end

-- `/class` is DELIBERATELY not registered (ruling 20, 2026-09-16,
-- skill_trees.md §1.4/§3.10): class changing is removed from the game
-- entirely, admins included, because equipment would otherwise have to be
-- resolved on every switch. A respec re-spends talents; nothing changes a
-- character's class. The helper above keeps its `cmd == "class"` branch: it
-- is the creation-session path, and only the registration is what ruling 20
-- removes. `/race` is untouched.
register_set_command("race", grug_classes.set_race, grug_classes.get_race_def,
	function(id) return grug_classes.registered_races[id] ~= nil end)
