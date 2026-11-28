-- sfinv pages: Inventory (the homepage) and Character (the Help page is
-- registered by help.lua; the frame, the tab order and the inventory views
-- live in ui.lua). Both are drawn in real coordinates above the frame's
-- inventory view.

local function esc(text)
	return core.formspec_escape(text)
end

-- hypertext[] markup escapes; the whole element is formspec-escaped after.
local function ht(text)
	return (tostring(text):gsub("[\\<>]", "\\%0"))
end

-- model[] takes a COMMA-SEPARATED texture list, so the list separators must
-- stay raw while each texture name is escaped on its own.
-- Trap: core.formspec_escape() escapes commas too (builtin/common/
-- misc_helpers.lua:304-315 maps "," -> "\\,"), so escaping the already
-- joined string turns the whole list into ONE texture literally named
-- `character.png\,character_back.png` -> client "generateImagePart" error
-- and an untextured model. Never escape a joined list.
local function esc_texture_list(textures)
	local escaped = {}
	for i, texture in ipairs(textures) do
		escaped[i] = esc(texture)
	end
	return table.concat(escaped, ",")
end

-- The player model as it should be previewed: mesh and texture list.
--
-- Round 54: grug_visuals' preview seam answers first (plan §3): the player
-- model with {skin, cloak, armor, weapon}, the weapon slot carrying the main
-- hand's image on the model's weapon card (transparent in the world, where
-- the wield entity shows the weapon). model[] applies no bone overrides, so
-- the head-look turn and the attached wield entity never show here; the card
-- is what makes the weapon visible. grug_visuals is an optional dependency,
-- and loads before this mod when present, so its equipment-change pass has
-- run before the page refresh below asks again.
--
-- Without the seam (grug_visuals absent): the live properties.
--
-- Race: sfinv builds the inventory formspec in its own register_on_joinplayer
-- (sfinv/api.lua:149-153) and player_api applies the model in its own
-- (player_api/init.lua:24-26). Both are dependency-free BASE mods, so their
-- callback order is nondeterministic and the page can render before the model
-- exists. get_properties() then returns the engine PlayerSAO defaults
-- (src/server/player_sao.cpp:32-36): visual "upright_sprite" with textures
-- {"player.png", "player_back.png"} -- NON-empty, so emptiness checks miss it.
-- `visual ~= "mesh"` is the reliable "player_api has not run yet" signal.
-- (grug_inventory's dependency-ordered equipment join hook fires the page's
-- one equipment-change refresh consumer, which closes the race for real.)
local DEFAULT_MODEL = "character.b3d"

local function preview_model(player)
	local visuals = rawget(_G, "grug_visuals")
	if visuals and visuals.preview then
		local view = visuals.preview(player)
		return view.mesh, view.textures
	end
	local props = player:get_properties()
	if props.visual == "mesh" and props.mesh and props.mesh ~= "" and
			props.textures and #props.textures > 0 then
		return props.mesh, props.textures
	end
	-- Fall back to what player_api will apply moments later, read from its
	-- own registry instead of hardcoding the texture name.
	local model = player_api.registered_models[DEFAULT_MODEL]
	return DEFAULT_MODEL, (model and model.textures) or {"character.png"}
end

--
-- Character page (Round 44, spec ruling 6 and §3.3, wireframe v1), in real
-- coordinates: equipment, the model and the cloak picker (Round 88) on the
-- left, Stats, Effects and Achievements on the right; the professions
-- overview remains on Crafting. Both share the Scout's quiver and Return
-- home, and below them the frame's short inventory view. Both boxes end a
-- gap above the view's Inventory box.
--

local CHARACTER_PAGE = "grug_inventory:character"
local BOX_BOTTOM = grug_inventory.VIEW_GEOMETRY.top - 0.1
local MODE_BOX = {x = 9.8, y = 0.2, w = 9.8, h = BOX_BOTTOM - 0.2}
local GEAR_BOX = {x = 0.2, y = 0.2, w = 9.3, h = BOX_BOTTOM - 0.2}
-- The mode body's area inside the mode box, below the mode buttons; the
-- Achievements body is drawn into it by its mod.
local MODE_AREA = {x = 10.0, y = 1.25, w = 9.3, h = BOX_BOTTOM - 0.15 - 1.25}
local MODES = {
	{id = "stats", label = "Stats"},
	{id = "effects", label = "Effects"},
	{id = "achievements", label = "Achievements"},
}
local MODE_PAD, MODE_GAP = 0.2, 0.1
local MODE_W = (MODE_BOX.w - 2 * MODE_PAD - (#MODES - 1) * MODE_GAP) / #MODES
for index, mode in ipairs(MODES) do
	mode.x = MODE_BOX.x + MODE_PAD + (index - 1) * (MODE_W + MODE_GAP)
	mode.w = MODE_W
end
local MODE_Y, MODE_H = 0.35, 0.7

-- Equipment surrounds the model; native list slots retain their size and
-- routing. Labels sit below the slots so no text runs through the preview.
local SLOT_POS = {
	grug_head = {0.5, 1.05}, grug_chest = {0.5, 2.4},
	grug_legs = {0.5, 3.75}, grug_feet = {0.5, 5.1},
	grug_weapon = {8.05, 1.05}, grug_offhand = {8.05, 2.4},
	grug_trinket1 = {8.05, 3.75}, grug_trinket2 = {8.05, 5.1},
}
local QUIVER_POS = {0.5, 6.7}
-- Round 88 (the user): beside a quiver, the Home line moves up onto the
-- quiver's row, right-aligned to the gear box's inner right edge (where the
-- Return home button ends) in a box that starts right of the widest quiver
-- total ("Quiver 500/500"): a name too long for one line wraps inside the
-- box instead of reaching the total.
local QUIVER_HOME = {x = 4.1, h = 0.9}
local QUIVER_GHOST = "grug_inventory_quiver.png^[resize:64x64^[multiply:#666666"
local HOME_LABEL_Y, HOME_BUTTON_Y = BOX_BOTTOM - 1.1, BOX_BOTTOM - 0.8
-- A 40% larger viewport keeps the figure near the equipment columns' height,
-- centred between the columns. Since Round 88 (STATS, ruling 8) the cloak
-- picker sits under it, between the columns, so the figure is lower and the
-- picker ends above the Scout's quiver row (its rule at QUIVER_POS y - 0.25).
local MODEL = {x = 2.675, y = 0.285, w = 4.2, h = 5.55}
local CLOAK = {label_x = 1.7, x = 2.95, y = 5.85, w = 3.9, h = 0.56}
-- The engine provides mouse rotation; no preview timer or separate input.
local MODEL_VIEW = "0,130"

-- Ghost icon per slot: drawn under an EMPTY slot's item (inventory_equipment.md
-- §1). Reused grug_gear art for the five slots with a natural match, dimmed by
-- one multiply — the two new silhouettes are authored dim already. Keep every
-- modifier exact: a malformed one is a client-side generateImagePart error and
-- an untextured icon, with nothing in the server log. The same is true of a
-- name that no longer exists, which is exactly what the weapon row was between
-- WP13's round-2 art commit and this one: weapons went from one sprite per
-- family to one per family AND material, so `grug_gear_item_sword.png` is gone
-- and the row names the Steel one. Steel rather than any other tier because the
-- ghost is dimmed grey anyway and a grey source dims cleanly.
--
-- That round's evidence scanned every `.png` literal under `mods/*/grug_*`
-- against the real texture pool once (its `static.sh` was retired in Round 22);
-- there is no standing gate for a deleted sprite.
local GHOST_TEXTURE = {
	grug_head = "grug_gear_item_head_metal.png^[multiply:#666666",
	grug_chest = "grug_gear_item_chest_metal.png^[multiply:#666666",
	grug_legs = "grug_gear_item_legs_metal.png^[multiply:#666666",
	grug_feet = "grug_gear_item_feet_metal.png^[multiply:#666666",
	grug_weapon = "grug_gear_item_sword_steel.png^[multiply:#666666",
	grug_offhand = "grug_inventory_ghost_offhand.png",
	grug_trinket1 = "grug_inventory_ghost_trinket.png",
	grug_trinket2 = "grug_inventory_ghost_trinket.png",
}

-- A slot without a position would silently not be drawn at all — and an
-- equipment slot the player cannot see is an item sink. Load-time check, one
-- loop, because equipment.lua is dofile'd before this file.
for _, slot in ipairs(grug_inventory.equipment_slots) do
	if not SLOT_POS[slot.list] then
		core.log("error", ("[grug_inventory] equipment slot %q has no position " ..
			"in the character page and is not drawn"):format(slot.list))
	end
	if not GHOST_TEXTURE[slot.list] then
		core.log("error", ("[grug_inventory] equipment slot %q has no ghost " ..
			"texture in the character page"):format(slot.list))
	end
end

-- The Scout's quiver slot (Round 28 ruling 26): the first cell of the quiver
-- list with its native stack count, its name and the true arrow total
-- beside it, one line on the slot's middle (Round 88). No opaque cover or
-- item-image overlay captures the slot hover.
local function quiver_content(player)
	local inv = player:get_inventory()
	local total = grug_inventory.quiver_count(player)
	local x, y = QUIVER_POS[1], QUIVER_POS[2]
	local fs = {
		("box[%.2f,%.2f;%.2f,0.03;#ffffff30]"):format(x, y - 0.25,
			GEAR_BOX.x + GEAR_BOX.w - 0.2 - x),
		("list[current_player;%s;%.2f,%.2f;1,1;]"):format(
			grug_inventory.QUIVER_LIST, x, y),
		("tooltip[%.2f,%.2f;1,1;%s]"):format(x, y,
			esc("Quiver — up to " .. grug_inventory.quiver_capacity() ..
				" arrows. Drag or shift-click arrows in; click to take up to " ..
				"100. Shots draw from here first.")),
		("label[%.2f,%.2f;%s]"):format(x + 1.15, y + 0.5,
			esc("Quiver " .. total .. "/" .. grug_inventory.quiver_capacity())),
	}
	local first = inv:get_stack(grug_inventory.QUIVER_LIST, 1)
	if first:is_empty() then
		fs[#fs + 1] = ("image[%.2f,%.2f;1,1;%s]"):format(x, y, QUIVER_GHOST)
	end
	return table.concat(fs)
end

-- Return home (Round 30 ruling, moved here from the Map tab): the travel
-- home's name and the cooldown in whole minutes, rounded up ("30 min" ..
-- "1 min"), "Preparing arrival" while a return is under way, else "Ready";
-- nil without grug_home or a home. Minutes, not m:ss (Round 33): the poll
-- below re-sends the page whenever this text changes, and a re-send every
-- second would close an open dropdown (the cloak picker) each second.
-- grug_home does not depend on this mod, so it is read at build time.
local function home_state(player)
	local home_mod = rawget(_G, "grug_home")
	local home = home_mod and home_mod.get(player)
	if not home then return nil end
	local remaining = home_mod.remaining(player)
	local state = home_mod.is_pending(player) and "Preparing arrival" or
		(remaining > 0 and ("%d min"):format(math.ceil(remaining / 60)) or "Ready")
	return home.label, state
end
-- The quickbar (grug_quickbar) shows the same name and state.
grug_inventory.home_state = home_state

-- The text the poll compares: the home line and the button together.
local function home_text(player)
	local label, state = home_state(player)
	return label and ("Return home: %s (%s)"):format(label, state) or nil
end

-- The blocked offhand (Round 66 ruling 2): the equipped two-hander, or nil.
-- Its image is the stack's own (enchant colours, cracks) or the item's, and
-- BLOCKED_DIM takes it further down than a ghost's one multiply.
local BLOCKED_DIM = "^[multiply:#666666^[opacity:140"
local function blocking_weapon(inv)
	local weapon = inv:get_stack("grug_weapon", 1)
	if not weapon:is_empty() and grug_inventory.hands_of(weapon) >= 2 then
		return weapon
	end
	return nil
end
local function item_image(stack)
	local image = stack:get_meta():get_string("inventory_image")
	if image == "" then
		local def = core.registered_items[stack:get_name()]
		image = def and type(def.inventory_image) == "string" and def.inventory_image or ""
	end
	return image ~= "" and image or "grug_inventory_ghost_offhand.png"
end

-- The equip notice (Round 66): the open window covers the message feed, so
-- an equip refusal (equipment.lua, after its throttle) also shows on the
-- page, in place of the gear box's heading, for NOTICE_US. Runtime context
-- only; the poll below clears it.
local NOTICE_US = 6000000
local NOTICE_COLOR = "#f0e6c8" -- the feed's notice colour (grug_core.FEED_COLOR)

local function equip_notice(context)
	local notice = context.grug_equip_notice
	return notice and core.get_us_time() < notice.expires and notice.text or nil
end

function grug_inventory.show_equip_notice(player, text)
	local context = sfinv.contexts[player:get_player_name()]
	if not context or context.page ~= CHARACTER_PAGE then return end
	context.grug_equip_notice = {text = text, expires = core.get_us_time() + NOTICE_US}
	sfinv.set_player_inventory_formspec(player, context)
end

-- A read-only textarea wraps the line to the box at the font's own line
-- height (a multi-line label would space its lines half a slot apart).
local function notice_content(player, text)
	return ("box[%.2f,%.2f;%.2f,0.75;#0a1017e6]"):format(GEAR_BOX.x + 0.1,
		GEAR_BOX.y + 0.1, GEAR_BOX.w - 0.2) ..
		grug_core.ui.prose(GEAR_BOX.x + 0.2, GEAR_BOX.y + 0.12, GEAR_BOX.w - 0.4, 0.7,
			core.colorize(NOTICE_COLOR, text), false, grug_core.ui.text_growth(player),
			0.9 * grug_core.ui.text_scale(player))
end

-- The gear box: the slots with their names, tooltips and ghosts, the
-- quiver, Return home. The shift-click ring sends every drawn list to the
-- routing list (equipment.lua SHIFT_LIST), which moves gear between the
-- inventory and its slot and arrows into or out of the quiver.
local function gear_content(player, context)
	local inv = player:get_inventory()
	local class_id = grug_classes.get_class(player)
	local route = ("listring[current_player;%s]"):format(grug_inventory.SHIFT_LIST)
	local growth = grug_core.ui.text_growth(player)
	local notice = equip_notice(context)
	local fs = {
		grug_core.ui.panel(GEAR_BOX.x, GEAR_BOX.y, GEAR_BOX.w, GEAR_BOX.h),
		-- The notice is drawn last instead, over the model's top edge.
		notice and "" or grug_core.ui.heading(0.5, 0.6, "Equipment", growth),
	}
	local mesh, textures = preview_model(player)
	fs[#fs + 1] = ("model[%.2f,%.2f;%.2f,%.2f;grug_preview;%s;%s;%s]"):format(
		MODEL.x, MODEL.y, MODEL.w, MODEL.h, esc(mesh), esc_texture_list(textures), MODEL_VIEW)
	local function ring(list)
		fs[#fs + 1] = ("listring[current_player;%s]"):format(list) .. route
	end
	ring("main")
	for i = 1, grug_inventory.BAG_COUNT do
		local list = grug_inventory.content_list(i)
		if inv:get_size(list) > 0 then ring(list) end
	end
	for _, slot in ipairs(grug_inventory.equipment_slots) do
		local pos = SLOT_POS[slot.list]
		if pos then
			ring(slot.list)
			fs[#fs + 1] = ("list[current_player;%s;%.2f,%.2f;1,1;]"):format(
				slot.list, pos[1], pos[2])
			local name = grug_inventory.slot_label(class_id, slot.list) or slot.label
			fs[#fs + 1] = ("style_type[label;font_size=%s]label[%.2f,%.2f;%s]" ..
				"style_type[label;font_size=%s]"):format(grug_core.ui.font_size(0.75, growth), pos[1], pos[2] + 1.16,
				esc(name == "Caster offhand" and "Offhand" or name), grug_core.ui.font_size(nil, growth))
			-- The area tooltip repeats the slot's name over the cell. It shows
			-- on EMPTY slots only, which is what we want — a slot with an item in
			-- it should describe the item: guiFormSpecMenu.cpp:3672-3682 runs the
			-- tooltip-RECT loop before the children are drawn, and :3714-3717
			-- lets the hovered ITEM tooltip overwrite the very same
			-- m_tooltip_element afterwards, which is only painted at :3856.
			local tip = name
			if slot.list == "grug_weapon" then
				tip = tip .. " — equip here, then use a combat skill from the hotbar"
			end
			local empty = inv:get_stack(slot.list, 1):is_empty()
			local blocking = empty and slot.list == "grug_offhand" and blocking_weapon(inv)
			if blocking then
				tip = "Blocked: " .. grug_inventory.piece_name(blocking) .. " is two-handed"
			end
			fs[#fs + 1] = ("tooltip[%.2f,%.2f;1,1;%s]"):format(pos[1], pos[2], esc(tip))
			-- The ghost is drawn AFTER the list[] and only for empty slots,
			-- never before it to fake a transparent cell: listcolors[] is
			-- per-formspec and this page also carries the inventory view, so a
			-- page-wide transparent slot cell would strip the inventory's cells
			-- too (inventory_equipment.md §1). One inventory read per slot per
			-- formspec build; the build is a rare event — it happens on
			-- navigation and on the refresh hooks below, never in a step or on
			-- a hover. A blocked offhand shows the two-hander instead, dimmed
			-- further than a ghost (Round 66 ruling 2).
			if blocking then
				fs[#fs + 1] = ("image[%.2f,%.2f;1,1;%s]"):format(pos[1], pos[2],
					esc(item_image(blocking) .. BLOCKED_DIM))
			elseif empty then
				fs[#fs + 1] = ("image[%.2f,%.2f;1,1;%s]"):format(pos[1], pos[2],
					grug_inventory.slot_ghost(class_id, slot.list) or
					GHOST_TEXTURE[slot.list])
			end
		end
	end
	if grug_inventory.has_quiver(player) then
		ring(grug_inventory.QUIVER_LIST)
		fs[#fs + 1] = quiver_content(player)
	end
	-- The text shown is kept in the context for the countdown poll below.
	local label, state = home_state(player)
	context.grug_home_text = home_text(player)
	if label then
		local x = SLOT_POS.grug_head[1]
		local right = GEAR_BOX.x + GEAR_BOX.w - 0.15
		if grug_inventory.has_quiver(player) then
			fs[#fs + 1] = ("hypertext[%.2f,%.2f;%.2f,%.2f;;%s]"):format(QUIVER_HOME.x,
				QUIVER_POS[2] + 0.5 - QUIVER_HOME.h / 2, right - QUIVER_HOME.x, QUIVER_HOME.h,
				esc(("<global margin=0 valign=middle halign=right color=%s size=%d>%s"):format(
					grug_core.ui.colors.text, math.floor(16 * grug_core.ui.text_growth(player) + 0.5),
					ht("Home: " .. label))))
		else
			fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(x, HOME_LABEL_Y, esc("Home: " .. label))
		end
		fs[#fs + 1] = ("button[%.2f,%.2f;%.2f,0.65;grug_character_home;%s]"):format(
			x, HOME_BUTTON_Y, right - x,
			esc(("Return home (%s)"):format(state)))
	end
	-- The cloak picker (Round 88: from the Stats mode to under the model, in
	-- every mode). grug_achievements depends on this mod, so it is read at
	-- build time.
	local achievements = rawget(_G, "grug_achievements")
	if achievements then
		fs[#fs + 1] = ("label[%.2f,%.2f;Cloak]"):format(CLOAK.label_x, CLOAK.y + CLOAK.h / 2)
		fs[#fs + 1] = achievements.cloak_dropdown(player, CLOAK.x, CLOAK.y, CLOAK.w, CLOAK.h)
		fs[#fs + 1] = "tooltip[grug_cloak;" .. esc("Cloaks unlock through achievements.") .. "]"
	end
	if notice then fs[#fs + 1] = notice_content(player, notice) end
	return table.concat(fs)
end

-- The Stats mode (Round 88 STATS, plan ruling 8): a list column of the stats
-- (name left, value right; a row is a button) and the selected stat's detail
-- box beside it. The list's foot keeps the Miner's Guild and the Claim Stone
-- status. The selection is runtime context (the sfinv context) like the
-- mode, reset to Maximum HP whenever the page opens (on_enter, and at the
-- window's close, see the page below); never stored.
local LIST_X, LIST_Y, LIST_W = 10.0, 1.3, 4.35
local ROW_H, GAP_H = 0.5, 0.15
local DETAIL = {x = 14.5, y = 1.3, w = 4.85, h = BOX_BOTTOM - 0.15 - 1.3}
local STAT_FIELD = "grug_stat_"
local DEFAULT_STAT = "hp"
local SELECTED_VALUE_COLOR = "#f3e2b8"
local SOURCE_COLOR, RULE_COLOR = "#c9ccc4", "#8f948c"
local GAP_COLOR = "#d4b77d26"
local DETAIL_BG = "#0a1017a8"
local PLAIN_STEP = 0.4

local function selected_stat(context, sheet)
	local wanted = context.grug_stat or DEFAULT_STAT
	for _, entry in ipairs(sheet) do
		if entry ~= "gap" and entry.id == wanted then return entry end
	end
	return sheet[1]
end

-- The number column of the detail: a hypertext line cannot hold two
-- alignments, so each number is padded on the left with no-break spaces to
-- the widest number of its section. The client font (Arimo, Arial's
-- metrics, the same advance in bold) gives a digit two spaces' width; the
-- pad is exact for digits and within a third of a space otherwise.
local NBSP = "\194\160"
local ADVANCE = {["."] = 1, [","] = 1, [" "] = 1, ["%"] = 3.2, ["+"] = 2.1}
local function advance(text)
	local width = 0
	for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		width = width + (ADVANCE[char] or 2)
	end
	return width
end
local function number_column(rows)
	local widest = 0
	for _, row in ipairs(rows) do widest = math.max(widest, advance(row[1])) end
	return function(text)
		return NBSP:rep(math.floor(widest - advance(text) + 0.5)) .. ht(text)
	end
end

local function detail_markup(entry, growth)
	local function size(px) return math.floor(px * growth + 0.5) end
	local colors = grug_core.ui.colors
	local out = {("<global margin=6 valign=top color=%s size=%d>"):format(colors.text, size(15)),
		("<style color=%s size=%d>%s</style>"):format(colors.muted, size(13), ht(entry.what)),
		("<style color=%s size=%d><b>EFFECT</b></style>"):format(colors.accent, size(13))}
	if entry.effects_note then out[#out + 1] = ht(entry.effects_note) end
	local pad = number_column(entry.effects)
	for _, row in ipairs(entry.effects) do
		out[#out + 1] = ("<b>%s</b>  %s"):format(pad(row[1]), ht(row[2]))
	end
	out[#out + 1] = ("<style color=%s size=%d><b>WHERE IT COMES FROM</b></style>"):format(
		colors.muted, size(12))
	local rows = {}
	for _, row in ipairs(entry.sources) do rows[#rows + 1] = row end
	rows[#rows + 1] = entry.total
	pad = number_column(rows)
	for index, row in ipairs(rows) do
		if index == #rows then
			out[#out + 1] = ("<style size=%d><b>%s</b>  %s</style>"):format(size(13),
				pad(row[1]), ht(row[2]))
		else
			out[#out + 1] = ("<style color=%s size=%d>%s  </style><style color=%s size=%d>%s</style>")
				:format(SOURCE_COLOR, size(13), pad(row[1]), colors.muted, size(13), ht(row[2]))
		end
	end
	out[#out + 1] = ("<style color=%s size=%d>%s</style>"):format(RULE_COLOR, size(12), ht(entry.rule))
	return table.concat(out, "\n")
end

local function detail_content(entry, growth)
	local colors = grug_core.ui.colors
	local d = DETAIL
	return table.concat({
		("box[%.2f,%.2f;%.2f,%.2f;%s]"):format(d.x, d.y, d.w, d.h, DETAIL_BG),
		("style_type[label;font_size=%s]"):format(grug_core.ui.font_size(1.1, growth)),
		("label[%.2f,%.2f;%s]"):format(d.x + 0.2, d.y + 0.35, esc(entry.name)),
		("style_type[label;font_size=%s]"):format(grug_core.ui.font_size(nil, growth)),
		("hypertext[%.2f,%.2f;%.2f,0.7;;%s]"):format(d.x + 2.0, d.y, d.w - 2.15,
			esc(("<global valign=middle halign=right color=%s size=%d>%s"):format(
				colors.accent, math.floor(22 * growth + 0.5), ht(entry.value)))),
		("hypertext[%.2f,%.2f;%.2f,%.2f;;%s]"):format(d.x + 0.05, d.y + 0.7,
			d.w - 0.1, d.h - 0.75, esc(detail_markup(entry, growth))),
	})
end

-- One list row: the name and the value under a clear button, which takes
-- the hover, the click and an attribute's tooltip (labels and hypertext
-- drawn after it would take them instead); the navigation textures are
-- translucent, so the text shows through.
local function row_content(entry, y, selected, growth)
	local colors = grug_core.ui.colors
	local field = STAT_FIELD .. entry.id
	local fs = {
		("label[%.2f,%.2f;%s]"):format(LIST_X + 0.2, y + ROW_H / 2,
			esc(core.colorize(selected and colors.accent or colors.muted, entry.name))),
		("hypertext[%.2f,%.2f;%.2f,%.2f;;%s]"):format(LIST_X + 1.8, y, LIST_W - 1.95, ROW_H,
			esc(("<global margin=0 valign=middle halign=right color=%s size=%d>%s"):format(
				selected and SELECTED_VALUE_COLOR or colors.text,
				math.floor(16 * growth + 0.5), ht(entry.value)))),
		grug_core.ui.navigation_style(field, selected, LIST_X, y, LIST_W, ROW_H, true),
		("button[%.2f,%.2f;%.2f,%.2f;%s;]"):format(LIST_X, y, LIST_W, ROW_H, field),
	}
	if entry.tip then
		fs[#fs + 1] = ("tooltip[%s;%s]"):format(field, esc(entry.tip))
	end
	return table.concat(fs)
end

local function stats_content(player, context)
	local growth = grug_core.ui.text_growth(player)
	local sheet = grug_inventory.stat_sheet.sheet(player)
	local selected = selected_stat(context, sheet)
	local fs = {}
	local y = LIST_Y
	for _, entry in ipairs(sheet) do
		if entry == "gap" then
			fs[#fs + 1] = ("box[%.2f,%.2f;%.2f,0.015;%s]"):format(LIST_X + 0.15,
				y + GAP_H / 2, LIST_W - 0.3, GAP_COLOR)
			y = y + GAP_H
		else
			fs[#fs + 1] = row_content(entry, y, entry == selected, growth)
			y = y + ROW_H
		end
	end
	fs[#fs + 1] = detail_content(selected, growth)
	-- The Miner's Guild (Round 58): the own guild's rank and the balance, two
	-- lines under the list. grug_guild depends on this mod, so it is read at
	-- build time; it re-sends the cached page on every change itself.
	fs[#fs + 1] = ("style_type[label;font_size=%s]"):format(grug_core.ui.font_size(0.85, growth))
	local x, line_y = LIST_X + 0.2, y + 0.3
	local guild = rawget(_G, "grug_guild")
	local view = guild and guild.summary(player)
	if view then
		fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(x, line_y,
			esc(("%s: Rank %d"):format(guild.catalog.UI_NAME, view.rank)))
		fs[#fs + 1] = ("tooltip[%.2f,%.2f;%.2f,%.2f;%s]"):format(LIST_X,
			line_y - PLAIN_STEP / 2, LIST_W, 2 * PLAIN_STEP,
			esc("Lifetime reputation " .. guild.format_points(view.lifetime)))
		fs[#fs + 1] = guild.reputation_formspec(x, line_y + PLAIN_STEP, view.balance)
		line_y = line_y + 2 * PLAIN_STEP
	end
	fs[#fs + 1] = ("style_type[label;font_size=%s]"):format(grug_core.ui.font_size(nil, growth))
	-- Claim Stone status (Round 25 ruling 14), wrapped to the column by a
	-- read-only textarea. Neither mod depends on the other, so grug_housing
	-- is read at build time; it has no status until the player has received
	-- a stone and keeps the cached page current itself.
	local housing = rawget(_G, "grug_housing")
	local status = housing and housing.character_status and
		housing.character_status(player:get_player_name())
	if status then
		local top = line_y - 0.2
		fs[#fs + 1] = grug_core.ui.prose(LIST_X + 0.05, top, LIST_W - 0.05,
			DETAIL.y + DETAIL.h - top, status.color and core.colorize(status.color,
				status.text) or status.text, false, growth,
			0.85 * growth)
	end
	return table.concat(fs)
end

-- Effects (Round 26): every active effect of the status icon row with its
-- name, detail and remaining time -- the text the row itself has no room
-- for. One column in the mode box.
local EFFECT_X, EFFECT_Y, EFFECT_STEP, EFFECT_ROWS = 10.1, 1.3, 0.85, 8
local EFFECT_ICON = 0.8
local NAME_CHARS, DETAIL_CHARS = 25, 32
local TIME_COLOR = "#f0c75e"

local function selected_mode(context)
	for _, mode in ipairs(MODES) do
		if context.grug_character_tab == mode.id then return mode.id end
	end
	return MODES[1].id
end

local function clip(text, limit)
	if #text <= limit then return text end
	return text:sub(1, limit - 2) .. ".."
end

-- One effect's printed lines; also the rebuild key (see the globalstep below).
local function effect_lines(effect)
	local detail = effect.detail or ""
	if effect.value ~= nil then
		detail = (detail ~= "" and detail .. ": " or "") .. effect.caption .. " left"
	end
	local time = grug_core.status_icons.remaining_text(effect.remaining_us,
		effect.untimed)
	return clip(effect.name, NAME_CHARS), time,
		clip(detail, DETAIL_CHARS)
end

function grug_inventory.effects_key(player)
	local parts = {}
	for _, effect in ipairs(grug_core.status_effects(player)) do
		local name, time, detail = effect_lines(effect)
		parts[#parts + 1] = effect.id .. "|" .. name .. "|" .. time .. "|" .. detail
	end
	return table.concat(parts, "\n")
end

local function effects_content(player, context)
	local effects = grug_core.status_effects(player)
	context.grug_effects_key = grug_inventory.effects_key(player)
	if #effects == 0 then
		return ("textarea[%.2f,1.45;9.0,1.7;;;%s]"):format(EFFECT_X, esc("No active effects. " ..
			"Food, elixirs, skills, talents and hostile attacks show up here."))
	end
	local growth = grug_core.ui.text_growth(player)
	local fs = {"style_type[label;font_size=" .. grug_core.ui.font_size(0.85, growth) .. "]"}
	-- A full box keeps its last row for the "more" line.
	local shown = #effects > EFFECT_ROWS and EFFECT_ROWS - 1 or #effects
	for index = 1, shown do
		local effect = effects[index]
		local y = EFFECT_Y + (index - 1) * EFFECT_STEP
		local name, time, detail = effect_lines(effect)
		fs[#fs + 1] = grug_core.ui.panel(EFFECT_X - 0.05, y - 0.02, 9.0, 0.8)
		local full_detail = effect.detail or ""
		if effect.value ~= nil then
			full_detail = full_detail .. (full_detail ~= "" and ": " or "") ..
				effect.caption .. " left"
		end
		fs[#fs + 1] = ("tooltip[%.2f,%.2f;9.0,0.8;%s]"):format(EFFECT_X, y,
			esc(effect.name .. "\n" .. full_detail .. "\n" .. time))
		fs[#fs + 1] = ("image[%.2f,%.2f;%.2f,%.2f;%s]"):format(EFFECT_X, y,
			EFFECT_ICON, EFFECT_ICON, esc(effect.texture))
		fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(EFFECT_X + 0.95, y + 0.2,
			esc(name .. "  " .. core.colorize(TIME_COLOR, time)))
		if detail ~= "" then
			fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(EFFECT_X + 0.95, y + 0.6,
				esc(detail))
		end
	end
	if shown < #effects then
		fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(EFFECT_X + 0.95,
			EFFECT_Y + shown * EFFECT_STEP + 0.4,
			esc(("... and %d more"):format(#effects - shown)))
	end
	fs[#fs + 1] = "style_type[label;font_size=" .. grug_core.ui.font_size(nil, growth) .. "]"
	return table.concat(fs)
end

-- Achievements (Round 33): the character's achievements and the cloak each
-- unlocks; grug_achievements builds the body into the mode area.
local function achievements_content(player, context)
	local achievements = rawget(_G, "grug_achievements")
	if achievements then
		return achievements.character_achievements_formspec(player, context,
			MODE_AREA)
	end
	return ""
end

-- Re-sends the cached inventory form only when the Character page shows mode
-- `tab` (grug_achievements calls this on progress).
function grug_inventory.refresh_character_tab(player, tab)
	local context = sfinv.contexts[player:get_player_name()]
	if context and context.page == CHARACTER_PAGE and selected_mode(context) == tab then
		sfinv.set_player_inventory_formspec(player, context)
	end
end

-- The mode box: its background, the mode buttons (the selected one styled),
-- the body. The choice is runtime context (the sfinv context), never stored.
local function mode_content(player, context, selected)
	local fs = {
		-- The selected mode's button takes the focus at every send (0.45.1):
		-- otherwise the engine focuses the last button, Return home, which
		-- Space or Enter would press. Re-selecting the mode changes nothing.
		-- Forced: unforced, it would not apply when the inventory key opens
		-- the window.
		("set_focus[grug_character_%s;true]"):format(selected),
		grug_core.ui.panel(MODE_BOX.x, MODE_BOX.y, MODE_BOX.w, MODE_BOX.h),
	}
	for _, mode in ipairs(MODES) do
		local field = "grug_character_" .. mode.id
		fs[#fs + 1] = grug_core.ui.navigation_style(field, mode.id == selected, mode.x, MODE_Y, mode.w, MODE_H)
		fs[#fs + 1] = ("style[%s;font_size=*%.3f]"):format(field,
			0.85 * grug_core.ui.text_scale(player))
		fs[#fs + 1] = ("button[%.2f,%.2f;%.2f,%.2f;%s;%s]"):format(
			mode.x, MODE_Y, mode.w, MODE_H, field, esc(mode.label))
	end
	if selected == "effects" then
		fs[#fs + 1] = effects_content(player, context)
	elseif selected == "achievements" then
		fs[#fs + 1] = achievements_content(player, context)
	else
		fs[#fs + 1] = stats_content(player, context)
	end
	return table.concat(fs)
end

sfinv.register_page(CHARACTER_PAGE, {
	title = "Character",
	get = function(self, player, context)
		local selected = selected_mode(context)
		return sfinv.make_formspec(player, context, "real_coordinates[true]" ..
			mode_content(player, context, selected) .. gear_content(player, context),
			"short")
	end,
	-- Maximum HP is selected whenever the page opens (Round 88 ruling 8):
	-- entering it from another tab (a mode button re-enters it too) ...
	on_enter = function(self, player, context)
		context.grug_stat = nil
	end,
	on_player_receive_fields = function(self, player, context, fields)
		-- ... and closing the window, whose cached form the client shows
		-- again at the next open: re-sent only when another stat was shown.
		if fields.quit and context.grug_stat then
			context.grug_stat = nil
			sfinv.set_player_inventory_formspec(player, context)
		end
		for field in pairs(fields) do
			local id = type(field) == "string" and field:match("^" .. STAT_FIELD .. "(%w+)$")
			if id then
				context.grug_stat = id ~= DEFAULT_STAT and id or nil
				sfinv.set_player_inventory_formspec(player, context)
				return true
			end
		end
		local achievements = rawget(_G, "grug_achievements")
		if achievements then
			-- A new cloak redraws the character first, then the page, whose
			-- preview reads the cloak the character now wears.
			if fields.grug_cloak and
					achievements.choose_cloak_by_name(player, fields.grug_cloak) then
				sfinv.set_player_inventory_formspec(player, context)
				return true
			end
			if achievements.handle_tab_fields(player, context, fields) then
				return true
			end
		end
		if fields.grug_character_home then
			local home_mod = rawget(_G, "grug_home")
			if home_mod then home_mod.return_home(player) end
			sfinv.set_player_inventory_formspec(player, context)
			return true
		end
		for _, mode in ipairs(MODES) do
			if fields["grug_character_" .. mode.id] then
				context.grug_character_tab = mode.id
				sfinv.set_page(player, CHARACTER_PAGE)
				return true
			end
		end
	end,
})

-- The cached inventory formspec is re-sent while the Character page is the
-- selected page: in the Effects mode when its printed text changed (an
-- effect came or went, a shield value moved, or a coarse remaining time
-- ticked: whole minutes, so about once a minute), and in every mode when the
-- Return home text changed: once a minute of a running cooldown, when an
-- arrival starts or ends, and once when it becomes Ready; and once when an
-- equip notice ran out (Round 66). Nothing is re-sent for other pages.
-- Every player once a second, one join slot at a time (Round 81 PASSES;
-- audit X4-05).
grug_core.register_player_pass(1, function(player)
	local context = sfinv.contexts[player:get_player_name()]
	if context and context.grug_equip_notice and not equip_notice(context) then
		context.grug_equip_notice = nil
		if context.page == CHARACTER_PAGE then
			sfinv.set_player_inventory_formspec(player, context)
		end
	elseif context and context.page == CHARACTER_PAGE then
		if (selected_mode(context) == "effects" and
				grug_inventory.effects_key(player) ~= context.grug_effects_key) or
				home_text(player) ~= context.grug_home_text then
			sfinv.set_player_inventory_formspec(player, context)
		end
	end
end)

-- The Help page lives in help.lua (dofile'd by init.lua before this file).

--
-- Inventory page: the full eight-column bag grid on the left; Bags,
-- Potion belt, Money and Trash stacked on the right. The common hotbar is
-- centered under both columns. Native list IDs, deposit, sorting and transfer
-- routes remain unchanged; no listring because this is one inventory.
--

local INVENTORY_PAGE = "grug_inventory:inventory"
local PITCH = 1.25
-- The money row's buttons span two slot columns and are as tall as a slot.
-- Sort ignores clicks for this long after one it ran (spec ruling 5): no
-- countdown, no resend; the lists the sort changed reach the client on their
-- own. The chests' Sort button (default/containers.lua) shares it.
grug_inventory.SORT_COOLDOWN_US = 2500000
local SORT_COOLDOWN_US = grug_inventory.SORT_COOLDOWN_US

local function inventory_content(player)
	local deposit, deposit_list = grug_money.deposit_location(player)
	local layout = grug_inventory.LAYOUT
	local half_w = layout.side_w
	local bags_box_x, belt_box_x = layout.side_x, layout.side_x
	local bags_x, belt_x = bags_box_x + layout.pad, belt_box_x + layout.pad
	local slot_y = layout.top_y + layout.label_h
	local belt_y = slot_y + layout.slot_box_h + layout.gap
	local growth = grug_core.ui.text_growth(player)
	local fs = {
		"real_coordinates[true]",
		-- An invisible button with no action takes the focus at every send
		-- (0.45.1): otherwise the engine focuses the last button, Sort, which
		-- Space or Enter would press (Withdraw opens a dialog). Forced:
		-- unforced, it would not apply when the inventory key opens the window.
		"set_focus[grug_inv_focus;true]button[0,0;0,0;grug_inv_focus;]",
		grug_inventory.area_box(bags_box_x, layout.top_y, half_w, layout.slot_box_h,
			"Bags", nil, growth),
		grug_inventory.area_box(belt_box_x, layout.top_y + layout.slot_box_h + layout.gap, half_w, layout.slot_box_h,
			"Potion belt", nil, growth),
	}
	for i = 1, grug_inventory.BAG_COUNT do
		fs[#fs + 1] = ("list[current_player;%s;%.3f,%.3f;1,1;]"):format(
			grug_inventory.bag_list(i), bags_x + (i - 1) * PITCH, slot_y)
	end
	fs[#fs + 1] = ("tooltip[%.3f,%.3f;%.2f,1;%s]"):format(bags_x, slot_y,
		grug_inventory.BAG_COUNT * PITCH - 0.25,
		esc("Bag slots — a bag here adds its slots to the inventory below"))
	local belt = grug_inventory.POTION_BELT_SIZE
	fs[#fs + 1] = ("list[current_player;%s;%.3f,%.3f;%d,1;]"):format(
		grug_inventory.POTION_BELT, belt_x, belt_y, belt)
	fs[#fs + 1] = ("tooltip[%.3f,%.3f;%.2f,1;%s]"):format(belt_x, belt_y,
		belt * PITCH - 0.25, esc("Potion belt — potions and elixirs only"))
	-- Money actions stay in the right utility column. Sorting belongs to
	-- the inventory heading on the left.
	local row_y, x = layout.money_y, layout.side_x + layout.pad
	fs[#fs + 1] = grug_inventory.area_box(layout.side_x, row_y,
		layout.side_w, layout.money_h, "Money", nil, growth)
	fs[#fs + 1] = ("label[%.3f,%.3f;%s]"):format(x, row_y + 0.85,
		esc(grug_money.format(grug_money.get(player))))
	fs[#fs + 1] = ("button[%.3f,%.3f;2.5,0.65;grug_money_withdraw;Withdraw]"):format(x, row_y + 1.35)
	local deposit_y = row_y + 2.3
	fs[#fs + 1] = ("list[%s;%s;%.3f,%.3f;1,1;]"):format(deposit, deposit_list, x, deposit_y)
	fs[#fs + 1] = ("image[%.3f,%.3f;1,1;grug_money_bag_of_coins.png^[multiply:#666666]"):format(x, deposit_y)
	fs[#fs + 1] = ("tooltip[%.3f,%.3f;1,1;%s]"):format(x, deposit_y,
		esc("Deposit — put a Bag of Coins here to add its money to your balance"))
	fs[#fs + 1] = ("checkbox[%.3f,%.3f;grug_money_auto_deposit;Auto deposit;%s]"):format(
		x + 1.3, deposit_y + 0.5, tostring(grug_money.auto_deposit(player)))
	fs[#fs + 1] = ("button[%.3f,%.3f;2.2,0.55;grug_inv_sort;Sort]"):format(
		layout.full_x + layout.box_w - layout.pad - 2.2, layout.inventory_y + 0.10)
	fs[#fs + 1] = "tooltip[grug_inv_sort;Sort the inventory and the bags. The hotbar stays as it is.]"
	fs[#fs + 1] = grug_inventory.area_box(layout.side_x, layout.trash_y, layout.side_w,
		layout.slot_box_h, "Trash", nil, growth)
	fs[#fs + 1] = grug_inventory.trash_content(player, x, layout.trash_y + layout.label_h,
		layout.side_w - 2 * layout.pad, growth)
	return table.concat(fs)
end

sfinv.register_page(INVENTORY_PAGE, {
	title = "Inventory",
	get = function(self, player, context)
		return sfinv.make_formspec(player, context, inventory_content(player),
			"full")
	end,
	on_player_receive_fields = function(self, player, context, fields)
		if fields.grug_trash_undo then
			grug_inventory.trash_undo(player)
			return true
		end
		if fields.grug_money_withdraw then
			grug_money.show_withdraw(player)
			return true
		end
		if fields.grug_money_auto_deposit then
			grug_money.set_auto_deposit(player, fields.grug_money_auto_deposit == "true")
			-- The stored window must carry the new tick, or reopening the
			-- inventory would show the old one; only this toggle resends.
			sfinv.set_player_inventory_formspec(player, context)
			return true
		end
		if fields.grug_inv_sort then
			local now = core.get_us_time()
			if now >= (context.grug_inv_sort_ready or 0) then
				context.grug_inv_sort_ready = now + SORT_COOLDOWN_US
				grug_inventory.sort(player)
			end
			return true
		end
	end,
})

--
-- Homepage: the Inventory tab (spec ruling 1; the tab order is ui.lua's).
--

-- Deliberate override (not a wrapper): the Inventory page is the homepage
-- for everyone, including creative players. grug_inventory optionally
-- depends on creative so the load order — and thus this override — is
-- deterministic (creative wraps this function; we load after it).
function sfinv.get_homepage_name(player)
	return INVENTORY_PAGE
end

--
-- Refresh hooks. refresh() re-renders an open page that shows an inventory
-- view (its grid follows the bag lists' sizes) or the Character page; a bag
-- change calls it (bags.lua). The stat hooks below re-render only the
-- Character page. The list contents themselves update live anyway.
--

function grug_inventory.refresh(player, force)
	local context = sfinv.get_or_create_context(player)
	if force or context.page == CHARACTER_PAGE or context.grug_inv_view then
		sfinv.set_page(player, context.page)
	end
end

-- Re-send a cached Character page (any mode) and nothing else: the stat
-- hooks below use it, and so does the quiver total (bags.lua), which
-- the gear box shows in every mode. True when the page was re-sent.
function grug_inventory.refresh_character(player)
	local context = sfinv.contexts[player:get_player_name()]
	if context and context.page == CHARACTER_PAGE then
		sfinv.set_player_inventory_formspec(player, context)
		return true
	end
	return false
end

grug_xp.register_on_level_change(function(player, old_level, new_level)
	if old_level ~= nil then
		grug_inventory.refresh_character(player)
	end
end)

-- Ghost icons mirror slot occupancy, so an equipment change re-renders an
-- open Character page (inventory_equipment.md §1). Rare event; nothing is
-- re-sent for any other page. Pure wear changes nothing the page shows (the
-- slots' wear bars and tooltips update with the list itself).
grug_core.register_on_equipment_change(function(player, listname, reason)
	if reason == "durability_metadata" then return end
	grug_inventory.refresh_character(player)
end)

grug_core.register_on_status_modifiers_changed(function(player)
	grug_inventory.refresh_character(player)
end)

-- Join needs no second callback here. grug_inventory depends on both sfinv
-- and player_api, so their join callbacks run first. equipment.lua's later
-- join callback sizes the slots and calls equipment_changed, which reaches
-- the equipment-change refresh consumer above after the model and sfinv
-- context exist.

-- Re-send a cached Inventory page and nothing else.
function grug_inventory.refresh_inventory_page(player)
	local context = sfinv.contexts[player:get_player_name()]
	if context and context.page == INVENTORY_PAGE then
		sfinv.set_player_inventory_formspec(player, context)
	end
end

-- Keep the cached Inventory form current even while the window is closed, so
-- opening it shows the latest balance (the money row). Other selected pages
-- need no rebuild.
grug_money.register_on_change(grug_inventory.refresh_inventory_page)
