-- Character creation flow: faction (grug_factions) -> race -> class, all
-- mandatory, all final. Closing a dialog without choosing re-opens it.

local RACE_FORM = "grug_classes:race"
local CLASS_FORM = "grug_classes:class"

local function options_formspec(title, subtitle, options)
	local parts = {
		"formspec_version[4]",
		"size[10.5," .. (2.2 + #options * 1.5) .. "]",
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

-- Shows the next missing creation step, if any.
local function continue_creation(player)
	if not grug_factions.get_faction(player) then
		return -- grug_factions owns this step
	end
	if not grug_classes.get_race(player) then
		show_race_selection(player)
	elseif not grug_classes.get_class(player) then
		show_class_selection(player)
	end
end

-- Re-open after 1 s unless the step got completed in the meantime.
local function reopen_later(player)
	local name = player:get_player_name()
	core.after(1, function()
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
		show_class_selection(player)
		return true
	elseif formname == CLASS_FORM then
		if grug_classes.get_class(player) or
				not grug_classes.set_class(player, chosen_id(fields) or "") then
			reopen_later(player)
			return true
		end
		core.close_formspec(player:get_player_name(), CLASS_FORM)
		local def = grug_classes.get_class_def(player)
		core.chat_send_player(player:get_player_name(),
			core.colorize("#ffd100",
				"You are now a " .. def.name .. ". Your journey begins!"))
		return true
	end
end)

grug_factions.register_on_faction_chosen(function(player, faction_id)
	continue_creation(player)
end)

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	core.after(1, function()
		local p = core.get_player_by_name(name)
		if p then
			continue_creation(p)
		end
	end)
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
				if not setter(target, id) then
					return false, "Invalid " .. cmd .. ": " .. id
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
