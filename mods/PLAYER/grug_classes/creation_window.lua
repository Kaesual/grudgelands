-- Native character creation. Presentation only; selection.lua owns the draft,
-- validation, persistence and arrival. The scene keeps its authored 11:10 aspect.
local UI = grug_core.ui
grug_classes.creation_camera = dofile(core.get_modpath("grug_classes") .. "/creation_camera.lua")
local function esc(s) return core.formspec_escape(tostring(s or "")) end

function grug_classes.creation_layout(info)
	local max = info and info.max_formspec_size
	local aspect = max and max.x > 0 and max.y > 0 and max.x / max.y or 16 / 9
	local h, w = 14, math.max(22, math.min(38, 14 * aspect))
	local scene_h = 11.7
	local scene_w = scene_h * grug_classes.creation_camera.scene_aspect
	local left = 3.6 + (w - 22) * 0.35
	local right_x = left + 0.6 + scene_w
	local scale = max and math.min(max.x / w, max.y / h) * 0.94 or 1
	return {w = w, h = h, left = left, x = left + 0.35, y = 0.85,
		scene_w = scene_w, scene_h = scene_h, right_x = right_x,
		right_w = w - right_x - 0.3, scale = math.max(0.65, math.min(1.4, scale))}
end

local function image(fs, x, y, w, h, texture)
	fs[#fs + 1] = ("image[%.3f,%.3f;%.3f,%.3f;%s]"):format(x, y, w, h, esc(texture))
end

local function label(fs, x, y, text)
	fs[#fs + 1] = ("label[%.3f,%.3f;%s]"):format(x, y, esc(text))
end

local function opening(fs, g)
	local w, h = g.w - g.x - 0.3, g.scene_h
	-- Static clipping container: preserve the wide render's aspect at every
	-- window size, like cover in the browser study. No scrollbar is bound.
	local iw = math.max(w, h * 16 / 9)
	local ih = iw * 9 / 16
	fs[#fs + 1] = ("scroll_container[%.3f,%.3f;%.3f,%.3f;creation_intro_clip;vertical;0]")
		:format(g.x, g.y, w, h)
	image(fs, (w - iw) / 2, (h - ih) / 2, iw, ih, "grug_creation_intro.png")
	fs[#fs + 1] = "style_type[box;colors=#08101500,#08101500,#081015ef,#081015ef]"
	fs[#fs + 1] = ("box[0,%.3f;%.3f,5.1;]"):format(h - 5.1, w)
	fs[#fs + 1] = "style_type[box;colors=]"
	-- The approved small crest stays inside the opening scene, above its text.
	image(fs, (w - 2) / 2, h - 4.85, 2, 2, "grug_creation_crest.png")
	local function centered(y, height, name, text, size, color)
		local markup = ('<global margin=0 halign=center valign=middle color="%s" size=%d>%s')
			:format(color, math.floor(size * g.scale + 0.5), text)
		fs[#fs + 1] = ("hypertext[0.3,%.3f;%.3f,%.3f;%s;%s]")
			:format(y, w - 0.6, height, name, esc(markup))
	end
	centered(h - 2.55, 0.4, "creation_intro_eyebrow", "TWO FACTIONS · ONE WORLD", 14, "#d4be8f")
	centered(h - 2.1, 1, "creation_intro_title", "Choose your fate", 40, "#f0dfb9")
	centered(h - 1.05, 0.5, "creation_intro_hint", "Choose your people. Begin your story.", 16, "#d1d3c8")
	fs[#fs + 1] = "scroll_container_end[]"
	label(fs, 0.4, 13.3, "Esc: pause creation. Press I to return.")
end

local function choice(fs, name, text, icon, x, y, w, h, selected, scale)
	fs[#fs + 1] = UI.button_style(name, selected and "selected" or "normal", scale)
	-- Same flat selected surface and left marker as the mailbox rows.
	fs[#fs + 1] = ("style[%s;border=false;bgimg=grug_ui_%s.png;bgimg_middle=6;" ..
		"content_offset=0,0;padding=0]style[%s:hovered;bgimg=grug_ui_nav_hover.png]" ..
		"button[%.3f,%.3f;%.3f,%.3f;%s;]"):format(name,
		selected and "nav_selected" or "clear", name, x, y, w, h, name)
	if selected then
		fs[#fs + 1] = ("box[%.3f,%.3f;0.04,%.3f;%s]"):format(x, y, h, UI.colors.accent)
	end
	image(fs, x + 0.12, y + (h - 0.42) / 2, 0.42, 0.42, icon)
	label(fs, x + 0.68, y + h / 2, text)
	fs[#fs + 1] = "tooltip[" .. name .. ";" .. esc(text) .. "]"
end

local function skills(class)
	local rows, seen = {}, {}
	if not core.global_exists("grug_abilities") then return rows end
	local function add(def)
		if def and not seen[def.id] then
			seen[def.id] = true
			rows[#rows + 1] = def
		end
	end
	if class == "warrior" or class == "scout" then add(grug_abilities.registered.strike) end
	for _, def in ipairs(grug_abilities.by_class[class] or {}) do add(def) end
	return rows
end

function grug_classes.creation_formspec(draft, player, look_panel)
	local info = core.get_player_window_information(player:get_player_name())
	local g = grug_classes.creation_layout(info)
	local race = grug_classes.registered_races[draft.race or ""]
	local class = grug_classes.registered_classes[draft.class or "warrior"]
	local fs = {("formspec_version[6]size[%.3f,%.3f]padding[0,0]no_prepend[]"):format(g.w, g.h),
		UI.styles(), "bgcolor[#0b1315;both;#0b1315]", UI.fonts(g.scale),
		UI.title(0.35, 0.4, "Create your character", g.scale, g.scale)}
	local focus = draft.race and ("race_" .. draft.race) or "creation_focus"
	fs[#fs + 1] = "set_focus[" .. focus .. ";true]"
	if not race then
		-- Neutral focus, as in the inventory: no race looks chosen on entry.
		fs[#fs + 1] = "button[0,0;0,0;creation_focus;]"
	end
	for fi, faction in ipairs(grug_core.faction_ids) do
		local y = 1.05 + (fi - 1) * 5.25
		fs[#fs + 1] = UI.panel(0.25, y, g.left - 0.15, 4.9)
		image(fs, 0.4, y + 0.65, 1.05, 2.1, "grug_mapgen_faction_banner_" .. faction .. ".png")
		fs[#fs + 1] = UI.heading(0.45, y + 0.35, grug_factions.display_name(faction), g.scale)
		for ri, id in ipairs(grug_classes.race_ids[faction]) do
			choice(fs, "race_" .. id, grug_classes.registered_races[id].name,
				"grug_race_" .. id .. ".png", 1.55, y + 0.8 + (ri - 1) * 0.85,
				g.left - 1.65, 0.78, draft.race == id, g.scale)
		end
	end
	if not race then
		opening(fs, g)
		return table.concat(fs)
	end
	image(fs, g.x, g.y, g.scene_w, g.scene_h, "grug_creation_" .. draft.race .. ".png")
	if look_panel then
		fs[#fs + 1] = look_panel.preview(draft.race, draft.look, g.x, g.y, g.scene_w, g.scene_h)
	end
	fs[#fs + 1] = "tooltip[look_preview;Drag to turn your character.]"
	-- The heading and class strip are emitted after the model, above it.
	fs[#fs + 1] = UI.heading(g.x + 0.35, g.y + 0.35, grug_factions.display_name(race.faction), g.scale)
	fs[#fs + 1] = UI.title(g.x + 0.35, g.y + 0.85, race.name, g.scale * 1.3, g.scale)
	local cy, cw = g.y + g.scene_h - 1.25, (g.scene_w - 0.55) / 4
	fs[#fs + 1] = ("box[%.3f,%.3f;%.3f,1.25;#0b1315e8]"):format(g.x, cy, g.scene_w)
	for i, id in ipairs(grug_classes.class_ids) do
		choice(fs, "class_" .. id, grug_classes.registered_classes[id].name,
			"grug_class_" .. id .. ".png", g.x + 0.15 + (i - 1) * (cw + 0.08),
			cy + 0.25, cw, 0.75, class and class.id == id, g.scale)
	end
	local rx, rw = g.right_x, g.right_w
	fs[#fs + 1] = UI.panel(rx, 0.85, rw, 4.55)
	fs[#fs + 1] = UI.heading(rx + 0.2, 1.15, "APPEARANCE", g.scale)
	if race and look_panel then
		fs[#fs + 1] = look_panel.formspec(draft.race, draft.look, rx + 0.2, 1.4, rw - 0.4, 3.8, g.scale)
	else
		label(fs, rx + 0.2, 1.9, "Choose a race to customize your look.")
	end
	fs[#fs + 1] = UI.panel(rx, 5.55, rw, 2.1)
	fs[#fs + 1] = UI.heading(rx + 0.2, 5.85, race and race.name or "YOUR PEOPLE", g.scale)
	fs[#fs + 1] = UI.prose(rx + 0.2, 6.1, rw - 0.4, 1.4,
		race and race.description or "Choose a race from either faction.", false, g.scale)
	fs[#fs + 1] = UI.panel(rx, 7.8, rw, 4.75)
	fs[#fs + 1] = UI.heading(rx + 0.2, 8.1, class and class.name or "YOUR CLASS", g.scale)
	fs[#fs + 1] = UI.prose(rx + 0.2, 8.35, rw - 0.4, 1.45,
		(class and class.description or ""):gsub("\n", " "), false, g.scale)
	local rows = skills(class and class.id or "warrior")
	local list_h, row_h = 2.4, 0.48
	local maximum = math.max(0, math.ceil((#rows * row_h - list_h) * 100))
	fs[#fs + 1] = ("scrollbaroptions[min=0;max=%d;smallstep=35;largestep=200;thumbsize=100]"):format(maximum)
	fs[#fs + 1] = ("scrollbar[%.3f,9.9;0.2,%.3f;vertical;creation_skills;0]"):format(rx + rw - 0.35, list_h)
	fs[#fs + 1] = ("scroll_container[%.3f,9.9;%.3f,%.3f;creation_skills;vertical;0.01]"):format(rx + 0.2, rw - 0.65, list_h)
	for i, def in ipairs(rows) do
		image(fs, 0, (i - 1) * row_h, 0.36, 0.36, def._grug_skill_icon)
		label(fs, 0.5, (i - 1) * row_h + 0.18, def.name)
	end
	fs[#fs + 1] = "scroll_container_end[]"
	label(fs, 0.4, 13.3, "Esc: pause creation. Press I to return.")
	label(fs, g.w - 8, 13.3, "This choice is final.")
	if race and class then
		fs[#fs + 1] = UI.button_style("create_character", "selected", g.scale)
		fs[#fs + 1] = ("button[%.3f,12.9;3.7,0.85;create_character;Create character]"):format(g.w - 4)
		fs[#fs + 1] = "tooltip[create_character;Confirm your race and class and appearance.]"
	end
	return table.concat(fs)
end
