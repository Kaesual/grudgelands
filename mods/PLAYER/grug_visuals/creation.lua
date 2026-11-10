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

-- Generated together with the native backdrops; fixes the model viewport,
-- camera inclination and projection contract in one reproducible asset build.
local camera = grug_classes.creation_camera

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

local function preview(race, look, x, y, w, h)
	local appearance = grug_visuals.compose({race = race, look = look})
	local mh = h * camera.height_fraction * appearance.stature
	local mw = mh * camera.aspect
	return ("style[look_preview;bgcolor=#00000000]" ..
		"model[%.4f,%.4f;%.4f,%.4f;look_preview;character.b3d;%s;%.3f,160;false;true;0,79;30]"):
		format(x + (w - mw) / 2, y + (h - mh) / 2, mw, mh,
			esc(appearance.textures[1]), -camera.pitch)
end

local function formspec(race, look, x, y, w, h, scale)
	local def = grug_visuals.LOOKS[race]
	if not def then return "" end
	look = grug_visuals.normalize_look(race, look)
	local fs = {grug_core.ui.fonts(scale or 1)}
	local row = (h - 0.55) / #CATEGORIES
	for index, category in ipairs(CATEGORIES) do
		local yy = y + (index - 1) * row
		local label = category_label(race, category)
		fs[#fs + 1] = ("label[%.3f,%.3f;%s]"):format(x, yy + 0.1, esc(label))
		fs[#fs + 1] = ("button[%.3f,%.3f;0.45,0.4;look_prev_%s;<]"):format(x, yy + 0.25, category)
		fs[#fs + 1] = ("button[%.3f,%.3f;0.45,0.4;look_next_%s;>]"):format(x + w - 0.45, yy + 0.25, category)
		local colour = category ~= "style" and category ~= "feature" and def.options[category][look[category]] or nil
		local tx = x + 0.65
		if colour then
			fs[#fs + 1] = ("box[%.3f,%.3f;0.3,0.3;%s]"):format(tx, yy + 0.29, colour)
			tx = tx + 0.45
		end
		fs[#fs + 1] = ("label[%.3f,%.3f;%s]"):format(tx, yy + 0.44, esc(option_text(def, category, look[category])))
		fs[#fs + 1] = "tooltip[look_prev_" .. category .. ";" .. esc("Previous " .. label:lower()) .. "]"
		fs[#fs + 1] = "tooltip[look_next_" .. category .. ";" .. esc("Next " .. label:lower()) .. "]"
	end
	fs[#fs + 1] = ("button[%.3f,%.3f;%.3f,0.5;look_random;Random]"):format(x, y + h - 0.5, w)
	fs[#fs + 1] = "tooltip[look_random;Roll a random look.]"
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
	preview = preview,
	act = act,
	store = grug_visuals.set_look,
}
grug_classes.register_look_panel(grug_visuals.creation_panel)
