--
-- The look step of character creation (round31-plan.md §2.1.5): after the
-- class, the last step before the arrival teleport. One page: previous/next
-- per category, a random button, a rotating full-body preview and one
-- confirm that stores the look for good (apply.lua `set_look`).
--
-- grug_classes owns the creation flow and asks this step whether it is done,
-- for its dialog and to act on its fields (`register_look_step`). The choice
-- in progress is a per-session draft; it is stored only on confirm, so a
-- player who leaves half-way starts the step again with a fresh draft.
--

local esc = core.formspec_escape
local CATEGORIES = grug_visuals.LOOK_CATEGORIES

local LABEL = {tone = "Skin tone", hair = "Hair colour", style = "Hairstyle",
	eyes = "Eyes"}
local FEATURE_LABEL = {human = "Beard", dwarf = "Beard", elf = "Ears",
	orc = "Tusks", troll = "Tusks", undead = "Face"}

-- player name -> draft look (indices), until confirmed or the player leaves
local drafts = {}

local function draft(player)
	local name = player:get_player_name()
	local race = grug_classes.get_race(player)
	local look = drafts[name]
	if not look then
		-- A random start, so the confirm button never hands out a default
		-- every careless player shares.
		look = grug_visuals.roll_look(race) or {}
		drafts[name] = look
	end
	-- Normalized against the race each time: an admin may change it.
	look = grug_visuals.normalize_look(race, look)
	drafts[name] = look
	return look, race
end

local function option_text(def, category, index)
	local option = def.options[category][index]
	if type(option) == "table" then
		return option.name
	end
	return index .. " / " .. #def.options[category]
end

local function formspec(player, background)
	local look, race = draft(player)
	local def = grug_visuals.LOOKS[race]
	local texture = grug_visuals.compose({race = race, look = look}).textures[1]
	local fs = {
		"formspec_version[4]",
		"size[11,8.4]",
		background,
		"label[0.5,0.6;Choose your appearance!]",
		"label[0.5,1.1;" .. esc("Your look is set once, here. It cannot be " ..
			"changed later.") .. "]",
		-- Rotating, standing: `continuous` turns the model, frames 0..79 are
		-- player_api's stand animation of character.b3d.
		("model[0.4,1.5;3.8,6.6;look_preview;character.b3d;%s;0,180;true;false;0,79;30]")
			:format(esc(texture)),
	}
	for index, category in ipairs(CATEGORIES) do
		local y = 1.6 + (index - 1) * 0.9
		local label = LABEL[category]
		if category == "eyes" and race == "undead" then
			label = "Eye glow"
		elseif category == "feature" then
			label = FEATURE_LABEL[race] or "Feature"
		end
		fs[#fs + 1] = ("label[4.6,%.2f;%s]"):format(y + 0.35, esc(label))
		fs[#fs + 1] = ("button[6.6,%.2f;0.7,0.7;look_prev_%s;<]"):format(y, category)
		local colour = category ~= "style" and category ~= "feature" and
			def.options[category][look[category]] or nil
		if colour then
			fs[#fs + 1] = ("box[7.5,%.2f;0.5,0.5;%s]"):format(y + 0.1, colour)
		end
		fs[#fs + 1] = ("label[%.1f,%.2f;%s]"):format(colour and 8.15 or 7.5,
			y + 0.35, esc(option_text(def, category, look[category])))
		fs[#fs + 1] = ("button[9.9,%.2f;0.7,0.7;look_next_%s;>]"):format(y, category)
	end
	fs[#fs + 1] = "button[4.6,6.3;6,0.8;look_random;Random]"
	fs[#fs + 1] = "button[4.6,7.3;6,0.8;look_confirm;" ..
		esc("Confirm \226\128\148 cannot be changed later") .. "]"
	return table.concat(fs)
end

local function handles(fields)
	if fields.look_random or fields.look_confirm then
		return true
	end
	for field in pairs(fields) do
		if field:match("^look_prev_") or field:match("^look_next_") then
			return true
		end
	end
	return false
end

local function act(player, fields)
	local look, race = draft(player)
	local name = player:get_player_name()
	if fields.look_confirm then
		if grug_visuals.set_look(player, look) then
			drafts[name] = nil
		end
		return
	end
	if fields.look_random then
		drafts[name] = grug_visuals.roll_look(race)
		return
	end
	local def = grug_visuals.LOOKS[race]
	for _, category in ipairs(CATEGORIES) do
		local count = #def.options[category]
		if fields["look_prev_" .. category] then
			look[category] = (look[category] - 2) % count + 1
		elseif fields["look_next_" .. category] then
			look[category] = look[category] % count + 1
		end
	end
	drafts[name] = look
end

-- Kept on the mod table too, so an engine probe can drive the step.
grug_visuals.creation_step = {
	done = grug_visuals.has_look,
	formspec = formspec,
	handles = handles,
	act = act,
}
grug_classes.register_look_step(grug_visuals.creation_step)

core.register_on_leaveplayer(function(player)
	drafts[player:get_player_name()] = nil
end)
