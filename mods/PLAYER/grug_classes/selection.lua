-- Character creation flow: faction (grug_factions) -> race -> class, all
-- mandatory, all final. Closing a dialog without choosing re-opens it. While
-- the flow is incomplete the player remains frozen and engine-immortal; the
-- selected race start loads behind the class/loading UI and is committed once.

local RACE_FORM = "grug_classes:race"
local CLASS_FORM = "grug_classes:class"
local LOADING_FORM = "grug_classes:loading"
local REOPEN_DELAY = 0.1
local STASIS_CHECK_INTERVAL = 0.1
local DARK_BACKGROUND = "no_prepend[]" ..
	"bgcolor[#080808FF;both;#000000FF]"

-- Per-session only. Persistent faction/race/class meta remains the source of
-- truth: a disconnect before the final teleport deliberately loses a pending
-- class choice and resumes at that step on the next join.
local creation_sessions = {}

local continue_creation
local start_spawn_load
local finish_if_ready

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

local function reassert_player_lock(player)
	local physics = player:get_physics_override() or {}
	if physics.speed ~= 0 or physics.jump ~= 0 or physics.gravity ~= 0 then
		player:set_physics_override({speed = 0, jump = 0, gravity = 0})
	end
	stop_velocity(player)
	local armor = copy_table(player:get_armor_groups())
	if armor.immortal ~= 1 then
		armor.immortal = 1
		player:set_armor_groups(armor)
	end
end

local function lock_player(player)
	if character_complete(player) then
		return nil
	end
	local name = player:get_player_name()
	local session = creation_sessions[name]
	if not session then
		local physics = player:get_physics_override() or {}
		local armor = player:get_armor_groups() or {}
		session = {
			physics = {
				speed = physics.speed or 1,
				jump = physics.jump or 1,
				gravity = physics.gravity or 1,
			},
			previous_immortal = armor.immortal,
		}
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
	player:set_physics_override(session.physics)
	local armor = copy_table(player:get_armor_groups())
	armor.immortal = session.previous_immortal
	player:set_armor_groups(armor)
	creation_sessions[name] = nil
	core.close_formspec(name, CLASS_FORM)
	core.close_formspec(name, LOADING_FORM)
	return true
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

local function show_race_selection(player)
	local faction_id = grug_factions.get_faction(player)
	if not faction_id then
		return
	end
	local options = {}
	for _, id in ipairs(grug_classes.race_ids[faction_id] or {}) do
		table.insert(options, grug_classes.registered_races[id])
	end
	core.show_formspec(player:get_player_name(), RACE_FORM,
		options_formspec("Choose your race!",
			"Where in the " .. grug_core.factions[faction_id].name ..
			" lands do you come from? This decision is final.", options))
end

local function show_class_selection(player)
	local options = {}
	for _, id in ipairs(grug_classes.class_ids) do
		table.insert(options, grug_classes.registered_classes[id])
	end
	core.show_formspec(player:get_player_name(), CLASS_FORM,
		options_formspec("Choose your class!",
			"How will you fight? This decision is final.", options))
end

local function loading_formspec(failed)
	local parts = {
		"formspec_version[4]",
		"size[8.6,3.3]",
		DARK_BACKGROUND,
		"label[0.6,0.8;" .. core.formspec_escape(
			"Preparing your starting area...") .. "]",
	}
	if failed then
		parts[#parts + 1] = "label[0.6,1.5;" .. core.formspec_escape(
			"The area could not be loaded. You remain safe here.") .. "]"
		parts[#parts + 1] = "button[2.7,2.1;3.2,0.8;retry_spawn;Try again]"
	else
		parts[#parts + 1] = "label[0.6,1.5;" .. core.formspec_escape(
			"Your journey will begin as soon as it is ready.") .. "]"
	end
	return table.concat(parts)
end

local function show_loading(player, failed)
	core.show_formspec(player:get_player_name(), LOADING_FORM,
		loading_formspec(failed))
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
	session.loading = true
	session.load_generation = (session.load_generation or 0) + 1
	local generation = session.load_generation
	local name = player:get_player_name()
	local started = grug_factions.prepare_spawn(player,
		function(p, spawn, failure)
			local current = creation_sessions[name]
			if current ~= session or current.load_generation ~= generation then
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
				current.load_failed = failure or "spawn_unavailable"
				if current.pending_class_id or character_complete(p) then
					show_loading(p, true)
				end
				return
			end
			current.spawn_ready = true
			current.spawn_pos = spawn
			finish_if_ready(p)
		end)
	if not started then
		session.loading = false
		session.load_failed = "spawn_unavailable"
		return false
	end
	return true
end

finish_if_ready = function(player)
	local name = player:get_player_name()
	local session = creation_sessions[name]
	if not session then
		return false
	end
	local class_id = grug_classes.get_class(player) or session.pending_class_id
	local key = identity_key(player)
	if not key or not class_id then
		return false
	end
	if session.spawn_key ~= key then
		-- An admin may change race/faction after a prefetch completed. Retire the
		-- cached position and its callback generation before loading the new one.
		session.load_generation = (session.load_generation or 0) + 1
		session.spawn_key = nil
		session.spawn_ready = false
		session.spawn_pos = nil
		session.load_failed = nil
		session.loading = false
		start_spawn_load(player)
		show_loading(player, session.load_failed ~= nil)
		return false
	end
	if not session.spawn_ready then
		if not session.loading and not session.load_failed then
			start_spawn_load(player)
		end
		if creation_sessions[name] ~= session then
			return true
		end
		show_loading(player, session.load_failed ~= nil)
		return false
	end

	-- Position first, then persist the final identity. A disconnect before the
	-- asynchronous load completes therefore cannot leave a fully-created
	-- character behind at the unsafe engine spawn.
	player:set_pos(session.spawn_pos)
	stop_velocity(player)
	if not grug_classes.get_class(player) and
			not grug_classes.set_class(player, class_id) then
		session.load_failed = "class_unavailable"
		show_loading(player, true)
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

-- Shows the next missing creation step, if any.
continue_creation = function(player)
	local session = creation_sessions[player:get_player_name()]
	if session then
		reassert_player_lock(player)
	else
		session = lock_player(player)
	end
	if not session then
		return
	end
	if not grug_factions.get_faction(player) then
		return -- grug_factions owns this step
	end
	if not grug_classes.get_race(player) then
		show_race_selection(player)
		return
	end
	start_spawn_load(player)
	if session.pending_class_id or grug_classes.get_class(player) then
		finish_if_ready(player)
	else
		show_class_selection(player)
	end
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

-- Re-open on the next visible beat unless the step completed meanwhile.
local function reopen_later(player)
	local name = player:get_player_name()
	core.after(REOPEN_DELAY, function()
		local p = core.get_player_by_name(name)
		if p then
			continue_creation(p)
		end
	end)
end

local function chosen_id(fields, prefix)
	for field in pairs(fields) do
		local id = field:match("^choose_(.+)$")
		if id then
			return id
		end
	end
	return nil
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname == RACE_FORM then
		if grug_classes.get_race(player) or
				not grug_classes.set_race(player, chosen_id(fields) or "") then
			reopen_later(player)
			return true
		end
		local def = grug_classes.get_race_def(player)
		core.chat_send_player(player:get_player_name(),
			"You are a " .. def.name .. ".")
		start_spawn_load(player)
		show_class_selection(player)
		return true
	elseif formname == CLASS_FORM then
		local session = creation_sessions[player:get_player_name()]
		local id = chosen_id(fields) or ""
		if grug_classes.get_class(player) or not session or
				session.pending_class_id or
				not grug_classes.registered_classes[id] then
			reopen_later(player)
			return true
		end
		session.pending_class_id = id
		finish_if_ready(player)
		return true
	elseif formname == LOADING_FORM then
		local session = creation_sessions[player:get_player_name()]
		if fields.retry_spawn and session and session.load_failed then
			session.spawn_key = nil
			session.load_failed = nil
			show_loading(player, false)
			start_spawn_load(player)
			if creation_sessions[player:get_player_name()] == session and
					session.load_failed then
				show_loading(player, true)
			end
		else
			reopen_later(player)
		end
		return true
	end
end)

grug_factions.register_on_faction_chosen(function(player, faction_id)
	continue_creation(player)
end)

core.register_on_joinplayer(function(player)
	if not lock_player(player) then
		return
	end
	local name = player:get_player_name()
	-- Run after every mod's join callback. grug_mobs deliberately resets a
	-- stale slow to speed=1 later in load order; this reasserts the creation
	-- lock before the first ordinary server step.
	core.after(0, function()
		local p = core.get_player_by_name(name)
		if p and not character_complete(p) then
			lock_player(p)
			continue_creation(p)
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
					-- Keep an admin-picked first class transient too. Persisting it
					-- before the prepared teleport would reopen the reconnect hole.
					session.pending_class_id = id
					finish_if_ready(target)
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

register_set_command("class", grug_classes.set_class, grug_classes.get_class_def,
	function(id) return grug_classes.registered_classes[id] ~= nil end)
register_set_command("race", grug_classes.set_race, grug_classes.get_race_def,
	function(id) return grug_classes.registered_races[id] ~= nil end)
