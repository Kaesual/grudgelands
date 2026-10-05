-- Character creation (round35-plan.md §2.9): faction, race, class and look in
-- one window, all final. While a character is unfinished the player remains
-- frozen and engine-immortal (creation stasis). The window waits for the
-- selected server-wide preparation plan. Existing characters reconnecting
-- during preparation wait without changing position.
--
-- The choices are a DRAFT that lives only in this session (a Lua table):
-- nothing is written to the player before "Create character", and a
-- disconnect starts over. Create stores faction, race, look and class at once
-- and marks the character as arriving (META_ARRIVING); only then does this
-- player's arrival area load, and its single teleport clears the mark. A
-- reconnect while the mark is set resumes that wait.
--
-- Creation can always be paused (Round 24 ruling 32). Esc really closes the
-- window (and the waiting screen) and nothing here re-opens it by itself, so
-- the next Esc reaches the native game menu. The current window is always the
-- player's inventory formspec (sfinv is suspended meanwhile), so the inventory
-- key continues with the draft as it was; a HUD hint says so while no window
-- is open.

local CREATE_FORM = "grug_classes:create"
local LOADING_FORM = "grug_classes:loading"
-- Set by "Create character", cleared by the arrival teleport: the character
-- is stored but has not arrived yet, so a reconnect resumes the arrival.
local META_ARRIVING = "grug_classes:arriving"
local STASIS_CHECK_INTERVAL = 0.1
-- no_prepend drops the formspec prepend, so the click style comes along.
local DARK_BACKGROUND = "no_prepend[]" .. grug_sounds.CLICK_STYLE ..
	"bgcolor[#080808FF;both;#000000FF]"

local CREATION_FORMS = {
	[CREATE_FORM] = true,
	[LOADING_FORM] = true,
}

--
-- THE LOOK PANEL: the look part of the window. Its options and its storage
-- belong to grug_visuals, which depends on this mod and therefore registers
-- the panel here instead of being called. Without it creation has no look.
-- Its fields are named "look_*".
--   panel.roll(race)                       a random look for the race
--   panel.formspec(race, look, x, y, w, h) its elements in that area: the
--                                          preview on the left, the selectors
--                                          top right; the bottom 1.2 of the
--                                          right part stays free (Create)
--   panel.act(race, look, fields)          the changed look, or nil
--   panel.store(player, look)              store it for good (after the race)
--
local look_panel = nil

function grug_classes.register_look_panel(panel)
	assert(type(panel) == "table" and type(panel.roll) == "function" and
		type(panel.formspec) == "function" and type(panel.act) == "function" and
		type(panel.store) == "function", "grug_classes.register_look_panel: incomplete panel")
	look_panel = panel
end

-- The screen hint while no creation dialog is open.
local HINT = {
	paused = "Character creation paused \226\128\147 press I to continue",
	ready = "World ready \226\128\147 press I to continue",
	failed = "The area could not be loaded \226\128\147 press I to try again",
	-- An existing character reconnecting while the world is still prepared.
	waiting = "Preparing the world \226\128\147 press I to see progress",
}

-- Per-session state; the persistent faction/race/class/arriving meta is the
-- source of truth once the character is created. Session fields:
--   draft            {faction, race, class, look} before "Create character"
--   committing       Create is storing the draft (its own callbacks wait)
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
local current_step

local function copy_table(source)
	local result = {}
	for key, value in pairs(source or {}) do
		result[key] = value
	end
	return result
end

local function arriving(player)
	return player:get_meta():get_string(META_ARRIVING) ~= ""
end

local function character_complete(player)
	return grug_factions.get_faction(player) ~= nil and
		grug_classes.get_race(player) ~= nil and
		grug_classes.get_class(player) ~= nil and
		not arriving(player)
end

-- The start identity of a created character that has not arrived yet, or nil
-- (still drafting, or an admin broke the stored identity meanwhile).
local function arrival_key(player)
	if not arriving(player) or not grug_classes.get_class(player) then
		return nil
	end
	local faction = grug_factions.get_faction(player)
	local race = grug_classes.get_race(player)
	if not faction or not race then
		return nil
	end
	return faction .. ":" .. race
end

-- The name this file holds the movement aggregator under. One name, released
-- exactly (grug_core/movement.lua): holds are counted, so an unbalanced
-- release can never free a player another holder is still freezing.
local MOVEMENT_HOLD = "class_creation"

-- The creation freeze is an EXCLUSIVE HOLD on the grug_core movement
-- aggregator (ruling 11, 2026-09-16; skill_trees.md §3.9), not a physics
-- write of its own. `hold_movement` is idempotent AND re-asserting: it
-- compares against the player's live override and rewrites it on a mismatch,
-- which is exactly the watchdog this function used to be -- some later mod
-- may write the field after join, and a frozen player must not drift loose.
-- No velocity derived from get_velocity() is added here or at the final
-- placement: that server-side value can be stale (a dead or attached
-- player's), and cancelling it launched players (Round 28 ruling 16).
local function reassert_player_lock(player)
	grug_core.hold_movement(player, MOVEMENT_HOLD)
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
			draft = {},
			dismissed = false}
		creation_sessions[name] = session
		-- The inventory is the current window from the first moment on, not
		-- only from the deferred join dialog: no server step with the old one.
		local _, _, form = current_step(player, session)
		session.inventory_form = form
		player:set_inventory_formspec(form)
	end
	reassert_player_lock(player)
	return session
end

local function release_player(player, session)
	local name = player:get_player_name()
	if creation_sessions[name] ~= session then
		return false
	end
	grug_core.release_movement(player, MOVEMENT_HOLD)
	local armor = copy_table(player:get_armor_groups())
	armor.immortal = session.previous_immortal
	player:set_armor_groups(armor)
	creation_sessions[name] = nil
	if session.hint_id then
		player:hud_remove(session.hint_id)
	end
	core.close_formspec(name, CREATE_FORM)
	core.close_formspec(name, LOADING_FORM)
	-- Hand the inventory back to sfinv; its suspension ended with the session.
	if sfinv.enabled then
		sfinv.set_player_inventory_formspec(player)
	end
	return true
end

-- While a creation session exists, the inventory formspec is the current
-- creation window (see the GRUG PATCH in mods/BASE/sfinv/api.lua).
local sfinv_inventory_suspended = sfinv.inventory_suspended
function sfinv.inventory_suspended(player)
	return creation_sessions[player:get_player_name()] ~= nil or
		sfinv_inventory_suspended(player)
end

--
-- THE WINDOW (BACKLOG "Character creation in one window"): the faction row on
-- top; below it a narrow race column on the left and, on the right, the class
-- row with the look panel under it and "Create character" at the bottom
-- right. Real coordinates, 15 x 10.6: never taller than the inventory
-- (10.4 x 11.1), so it is drawn at least at the inventory's scale on a small
-- or wide screen.
--
local esc = core.formspec_escape
local WIDTH, HEIGHT = 15, 10.6
local LEFT, RIGHT_EDGE = 0.4, 14.6
local RACE_W = 3.0
local SIDE_X = 3.8 -- the right part
local ROW_Y = 2.5 -- race and class buttons
local LOOK_Y = 4.7
local CREATE_X, CREATE_Y, CREATE_W, CREATE_H = 11.0, 9.4, 3.6, 0.8
-- A chosen race or class; a chosen faction keeps its own colour and the other
-- one is dimmed.
local CHOSEN = "#8a6a1e"
local HINT_COLOUR = "#b8b0a0"

local function dimmed(colour)
	local r, g, b = colour:match("^#(%x%x)(%x%x)(%x%x)")
	if not r then
		return colour
	end
	return ("#%02x%02x%02x"):format(math.floor(tonumber(r, 16) * 0.4),
		math.floor(tonumber(g, 16) * 0.4), math.floor(tonumber(b, 16) * 0.4))
end

local function one_line(text)
	return (text or ""):gsub("\n", " ")
end

local function button(fs, x, y, w, h, field, label, tooltip, bgcolor, chosen)
	if bgcolor or chosen then
		fs[#fs + 1] = ("style[%s;bgcolor=%s%s]"):format(field, bgcolor or CHOSEN,
			chosen and ";font=bold" or "")
	end
	fs[#fs + 1] = ("button[%.2f,%.2f;%.2f,%.2f;%s;%s]"):format(x, y, w, h, field,
		esc(label))
	fs[#fs + 1] = ("tooltip[%s;%s]"):format(field, esc(tooltip))
end

local function faction_tooltip(id)
	local races = {}
	for _, race in ipairs(grug_classes.race_ids[id] or {}) do
		races[#races + 1] = grug_classes.registered_races[race].name
	end
	return grug_factions.display_name(id) .. "\nRaces: " ..
		table.concat(races, ", ") .. "\nYour race decides where you start."
end

local function create_button(fs, ready)
	-- Two short lines, so a large font (a phone) still ends before the button.
	fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(SIDE_X + 3.7, CREATE_Y + 0.15,
		esc(core.colorize(HINT_COLOUR, "This choice\nis final.")))
	if ready then
		button(fs, CREATE_X, CREATE_Y, CREATE_W, CREATE_H, "create_character",
			"Create character", "Store faction, race, class and look for good " ..
			"and travel to your starting settlement.", "#2f6a2a")
		return
	end
	-- Inactive: not a button at all, so there is nothing to click.
	fs[#fs + 1] = ("box[%.2f,%.2f;%.2f,%.2f;#2a2a2aff]"):format(CREATE_X, CREATE_Y,
		CREATE_W, CREATE_H)
	fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(CREATE_X + 0.55, CREATE_Y + 0.4,
		esc(core.colorize("#808080", "Create character")))
	fs[#fs + 1] = ("tooltip[%.2f,%.2f;%.2f,%.2f;%s]"):format(CREATE_X, CREATE_Y,
		CREATE_W, CREATE_H, esc("Choose a faction, race and class first."))
end

local function valid_race(faction, race)
	local def = grug_classes.registered_races[race or ""]
	return def ~= nil and def.faction == faction
end

-- Every choice a client sends is checked again here, at Create.
local function draft_ready(draft)
	return grug_core.factions[draft.faction or ""] ~= nil and
		valid_race(draft.faction, draft.race) and
		grug_classes.registered_classes[draft.class or ""] ~= nil
end

local function create_formspec(draft)
	local fs = {
		"formspec_version[4]",
		("size[%s,%s]"):format(WIDTH, HEIGHT),
		DARK_BACKGROUND,
		"label[0.4,0.45;Create your character]",
	}
	local faction_w = (RIGHT_EDGE - LEFT - 0.2) / #grug_core.faction_ids
	for index, id in ipairs(grug_core.faction_ids) do
		local def = grug_core.factions[id]
		local colour = def.color
		if draft.faction and draft.faction ~= id then
			colour = dimmed(colour)
		end
		button(fs, LEFT + (index - 1) * (faction_w + 0.2), 0.85, faction_w, 0.9,
			"faction_" .. id, grug_factions.display_name(id), faction_tooltip(id),
			colour, draft.faction == id)
	end
	if not draft.faction then
		fs[#fs + 1] = ("label[%.2f,2.4;%s]"):format(LEFT, esc(core.colorize(HINT_COLOUR,
			"Choose your faction to begin.")))
		return table.concat(fs)
	end

	-- The race column with the chosen race's description under it.
	local races = grug_classes.race_ids[draft.faction] or {}
	fs[#fs + 1] = ("label[%.2f,2.2;Race]"):format(LEFT)
	for index, id in ipairs(races) do
		local def = grug_classes.registered_races[id]
		button(fs, LEFT, ROW_Y + (index - 1) * 0.9, RACE_W, 0.8, "race_" .. id,
			def.name, def.description or def.name, nil, draft.race == id)
	end
	local text_y = ROW_Y + #races * 0.9 + 0.1
	local race_def = draft.race and grug_classes.registered_races[draft.race]
	fs[#fs + 1] = ("textarea[%.2f,%.2f;%.2f,%.2f;;;%s]"):format(LEFT, text_y, RACE_W,
		HEIGHT - 0.4 - text_y, esc(race_def and race_def.description or
		"Choose your race."))

	if not race_def then
		fs[#fs + 1] = ("label[%.2f,2.9;%s]"):format(SIDE_X, esc(core.colorize(HINT_COLOUR,
			"Choose your race to see your character.")))
		create_button(fs, false)
		return table.concat(fs)
	end

	-- The class row, the chosen class's description in one line under it.
	local classes = grug_classes.class_ids
	local class_w = (RIGHT_EDGE - SIDE_X - (#classes - 1) * 0.2) / #classes
	fs[#fs + 1] = ("label[%.2f,2.2;Class]"):format(SIDE_X)
	for index, id in ipairs(classes) do
		local def = grug_classes.registered_classes[id]
		button(fs, SIDE_X + (index - 1) * (class_w + 0.2), ROW_Y, class_w, 0.8,
			"class_" .. id, def.name, def.description or def.name, nil,
			draft.class == id)
	end
	local class_def = draft.class and grug_classes.registered_classes[draft.class]
	fs[#fs + 1] = ("textarea[%.2f,%.2f;%.2f,1.2;;;%s]"):format(SIDE_X, ROW_Y + 0.9,
		RIGHT_EDGE - SIDE_X, esc(class_def and one_line(class_def.description) or
		"Choose your class."))

	if look_panel then
		fs[#fs + 1] = look_panel.formspec(draft.race, draft.look, SIDE_X, LOOK_Y,
			RIGHT_EDGE - SIDE_X, HEIGHT - 0.4 - LOOK_Y)
	end
	create_button(fs, draft_ready(draft))
	return table.concat(fs)
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

-- The current window: "create" (the draft), "waiting" (shared preparation or
-- this player's arrival area) or "failed" (with retry), plus its form name and
-- formspec. The draft is only offered once the selected world preparation is
-- complete.
current_step = function(player, session)
	local status = grug_core.world_preparation_status()
	if not status.ready then
		return status.failed and "failed" or "waiting", LOADING_FORM,
			loading_formspec(status, status.failed)
	end
	if not session.preparation_only and not arrival_key(player) then
		return "create", CREATE_FORM, create_formspec(session.draft)
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

-- Renders the current window everywhere it lives: always as the inventory
-- formspec, as the dialog only while one is open (never re-opened here), and
-- as the hint while none is. `open` = the player acted (join, a choice, a
-- retry): show the window as a dialog again. Every write is send-on-change, so
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
	local key = arrival_key(player)
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
				if arrival_key(p) ~= key then
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

-- Binds the created start identity. The arrival load above may only start
-- once the selected world preparation is complete: before that it
-- would compete with the startup preload for the same mapgen threads.
start_spawn_load = function(player)
	local session = creation_sessions[player:get_player_name()]
	local key = arrival_key(player)
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
	local key = arrival_key(player)
	if not key then
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
		-- An admin may change race/faction while the arrival loads. Retire
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

	-- Position first, then clear the arriving mark. A disconnect before the
	-- asynchronous load completes therefore cannot leave a finished character
	-- behind at the unsafe engine spawn.
	grug_core.invalidate_combat_identity(player)
	player:set_pos(session.spawn_pos)
	player:get_meta():set_string(META_ARRIVING, "")
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

-- Continues creation: the window while drafting, the arrival once created.
-- `open` shows the window as a dialog even when the player had dismissed it
-- (join); otherwise only an already open dialog changes.
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
	if session.preparation_only or arrival_key(player) then
		finish_if_ready(player)
		return
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

local function chosen_id(fields, prefix)
	for field in pairs(fields) do
		local id = field:match("^" .. prefix .. "(.+)$")
		if id then
			return id
		end
	end
	return nil
end

-- Whether submitted fields belong to the window at all.
local function window_fields(fields)
	if fields.create_character then
		return true
	end
	for field in pairs(fields) do
		if field:match("^faction_") or field:match("^race_") or
				field:match("^class_") or field:match("^look_") then
			return true
		end
	end
	return false
end

-- "Create character": the whole draft is stored at once, then the arrival
-- area loads. Refused (nothing stored) unless faction, race and class form a
-- valid character.
local function create_character(player, session)
	local draft = session.draft
	if not draft_ready(draft) then
		return false
	end
	if look_panel and not draft.look then
		draft.look = look_panel.roll(draft.race)
	end
	player:get_meta():set_string(META_ARRIVING, "1")
	-- set_faction runs the faction-chosen callbacks, this file's among them;
	-- the draft is stored completely before creation continues.
	session.committing = true
	grug_factions.set_faction(player, draft.faction)
	grug_classes.set_race(player, draft.race)
	if look_panel then
		-- A look stored earlier (an admin repair) stays: set_look refuses.
		look_panel.store(player, draft.look)
	end
	-- Only a character without a class gets one; there are no class changes.
	if not grug_classes.get_class(player) then
		grug_classes.set_class(player, draft.class)
	end
	session.committing = false
	session.draft = {}
	local def = grug_core.factions[draft.faction]
	core.chat_send_player(player:get_player_name(),
		core.colorize(def.color, "Welcome to the " .. def.name .. "!"))
	continue_creation(player)
	return true
end

-- Applies one submission to the draft. Form fields are client input: every
-- choice is checked against the registries and the draft before it counts.
local function act_on_draft(player, session, fields)
	local draft = session.draft
	if fields.create_character then
		create_character(player, session)
		return
	end
	local id = chosen_id(fields, "faction_")
	if id then
		-- A new faction clears race and look; every class is open to every
		-- race, so the class stays.
		if grug_core.factions[id] and id ~= draft.faction then
			draft.faction = id
			draft.race = nil
			draft.look = nil
		end
		return
	end
	id = chosen_id(fields, "race_")
	if id then
		-- A new race rolls a new look.
		if valid_race(draft.faction, id) and id ~= draft.race then
			draft.race = id
			draft.look = look_panel and look_panel.roll(id) or nil
		end
		return
	end
	id = chosen_id(fields, "class_")
	if id then
		if draft.race and grug_classes.registered_classes[id] then
			draft.class = id
		end
		return
	end
	if draft.race and look_panel then
		local look = look_panel.act(draft.race, draft.look, fields)
		if look then
			draft.look = look
		end
	end
end

-- Named creation dialogs and the inventory formspec ("") during creation.
-- The inventory formspec always shows the current window; a named dialog
-- only answers for the window it shows, so a late click on a replaced dialog
-- is ignored. Nothing is committed for a window that is not current (e.g.
-- before world preparation is ready, or a second Create while the arrival
-- loads).
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
		acts = step == "create" and window_fields(fields)
	end
	if current and acts then
		-- The player acts: the window is shown as a dialog again, also when
		-- the choice came from the inventory formspec.
		session.dismissed = false
		session.ready_notice = false
		if step == "create" then
			act_on_draft(player, session, fields)
		else
			session.spawn_key = nil
			session.load_failed = nil
			-- Retry the failed preparation unit without resetting its cursor,
			-- then retry a new character's separate arrival load if needed.
			grug_core.request_starts_preload()
			if not session.preparation_only then start_spawn_load(player) end
			finish_if_ready(player)
		end
		present(player)
	elseif fields.quit then
		-- Esc closed it. Stasis and the draft stay; nothing re-opens it, so
		-- the next Esc reaches the native game menu.
		dismiss(player, session)
	end
	return true
end)

-- An admin `/faction` while the arrival loads re-binds the start identity.
grug_factions.register_on_faction_chosen(function(player)
	local session = creation_sessions[player:get_player_name()]
	if not (session and session.committing) then
		continue_creation(player)
	end
end)

-- The scheduler supplies one throttled progress stream for either plan.
-- Progress and failures update an open dialog or the hint, never force a
-- dialog open. Readiness replaces an open waiting screen with the window;
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
	-- what `hold_movement` re-asserts against. A join opens the current
	-- window as a dialog.
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

-- The draft goes with the session: a disconnect starts over.
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
			"HP %d/%d, mana %d | melee +%.1f, spell +%.1f, crit %.1f%%, dodge %.1f%%"):format(
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
			-- Single token: a valid id means "set my own" (e.g. /race orc).
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
				if not setter(target, id) then
					return false, "Invalid " .. cmd .. ": " .. id
				end
				continue_creation(target)
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
-- character's class. `/race` is untouched.
register_set_command("race", grug_classes.set_race, grug_classes.get_race_def,
	function(id) return grug_classes.registered_races[id] ~= nil end)
