--
-- The look part of the character-creation window (round35-plan.md §2.9):
-- previous/next per category, a random button and a full-body preview the
-- player turns with the mouse (no auto-rotation, no weapon).
--
-- grug_classes owns the window and the draft, a session-only table, and asks
-- this panel for a random look when the race changes, for its part of the
-- formspec and for what its fields change (`register_look_panel`). The look
-- is stored only by "Create character" (apply.lua `set_look`, once and for
-- good).
--

local esc = core.formspec_escape
local CATEGORIES = grug_visuals.LOOK_CATEGORIES

local LABEL = {tone = "Skin tone", hair = "Hair colour", style = "Hairstyle",
	eyes = "Eyes"}
local FEATURE_LABEL = {human = "Beard", dwarf = "Beard", elf = "Ears",
	orc = "Tusks", troll = "Tusks", undead = "Face"}

-- The panel's geometry inside its area: the preview on the left, then the
-- selector rows (label, ‹, colour, option, ›) and Random.
local MODEL_W = 3.4
local GAP = 0.3
local ROW = 0.75
local LABEL_W = 2.3
local STEP_W = 0.6

local function category_label(race, category)
	if category == "eyes" and race == "undead" then
		return "Eye glow"
	elseif category == "feature" then
		return FEATURE_LABEL[race] or "Feature"
	end
	return LABEL[category]
end

local function option_text(def, category, index)
	local option = def.options[category][index]
	if type(option) == "table" then
		return option.name
	end
	return index .. " / " .. #def.options[category]
end

local function roll(race)
	return grug_visuals.roll_look(race)
end

local function formspec(race, look, x, y, w, h)
	local def = grug_visuals.LOOKS[race]
	if not def then
		return ""
	end
	look = grug_visuals.normalize_look(race, look)
	local texture = grug_visuals.compose({race = race, look = look}).textures[1]
	local fs = {
		-- Standing, turned by the mouse only: frames 0..79 are player_api's
		-- stand animation of character.b3d. The engine rebuilds the model with
		-- every formspec, so a change resets the turn (accepted, BACKLOG).
		("model[%.2f,%.2f;%.2f,%.2f;look_preview;character.b3d;%s;0,160;false;true;0,79;30]")
			:format(x, y, MODEL_W, h, esc(texture)),
		("tooltip[%.2f,%.2f;%.2f,%.2f;%s]"):format(x, y, MODEL_W, h,
			esc("Drag with the mouse to turn your character.")),
	}
	local sx = x + MODEL_W + GAP
	local next_x = x + w - STEP_W
	for index, category in ipairs(CATEGORIES) do
		local row_y = y + (index - 1) * ROW
		local label = category_label(race, category)
		local lower = label:lower()
		fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(sx, row_y + 0.3, esc(label))
		fs[#fs + 1] = ("button[%.2f,%.2f;%.2f,0.6;look_prev_%s;<]"):format(
			sx + LABEL_W, row_y, STEP_W, category)
		fs[#fs + 1] = ("tooltip[look_prev_%s;%s]"):format(category,
			esc("Previous " .. lower))
		local colour = category ~= "style" and category ~= "feature" and
			def.options[category][look[category]] or nil
		local text_x = sx + LABEL_W + STEP_W + 0.1
		if colour then
			fs[#fs + 1] = ("box[%.2f,%.2f;0.45,0.45;%s]"):format(text_x, row_y + 0.08,
				colour)
			text_x = text_x + 0.55
		end
		fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(text_x, row_y + 0.3,
			esc(option_text(def, category, look[category])))
		fs[#fs + 1] = ("button[%.2f,%.2f;%.2f,0.6;look_next_%s;>]"):format(
			next_x, row_y, STEP_W, category)
		fs[#fs + 1] = ("tooltip[look_next_%s;%s]"):format(category,
			esc("Next " .. lower))
	end
	fs[#fs + 1] = ("button[%.2f,%.2f;%.2f,0.7;look_random;Random]"):format(sx,
		y + #CATEGORIES * ROW + 0.1, x + w - sx)
	fs[#fs + 1] = "tooltip[look_random;" .. esc("Roll a random look.") .. "]"
	return table.concat(fs)
end

-- The look after these fields, or nil when none of them is the panel's.
local function act(race, look, fields)
	local def = grug_visuals.LOOKS[race]
	if not def then
		return nil
	end
	if fields.look_random then
		return grug_visuals.roll_look(race)
	end
	look = grug_visuals.normalize_look(race, look)
	for _, category in ipairs(CATEGORIES) do
		local count = #def.options[category]
		if fields["look_prev_" .. category] then
			look[category] = (look[category] - 2) % count + 1
			return look
		elseif fields["look_next_" .. category] then
			look[category] = look[category] % count + 1
			return look
		end
	end
	return nil
end

-- Kept on the mod table too, so an engine probe can drive the panel.
grug_visuals.creation_panel = {
	roll = roll,
	formspec = formspec,
	act = act,
	store = grug_visuals.set_look,
}
grug_classes.register_look_panel(grug_visuals.creation_panel)
