-- sfinv pages: Inventory (the homepage) and Character (the Help page is
-- registered by help.lua; the frame, the tab order and the inventory views
-- live in ui.lua). Both are drawn in real coordinates above the frame's
-- inventory view.

local function esc(text)
	return core.formspec_escape(text)
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

-- The player model as it should be previewed.
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
-- coordinates: the mode box top left (3D with the cloak picker, Stats,
-- Effects, Achievements; the professions overview moved to the Crafting tab
-- in Round 45), the
-- gear box top right (eight equipment slots, the Scout's quiver, Return
-- home), and below them the frame's short inventory view. Both boxes end
-- above the view's grid.
--

local CHARACTER_PAGE = "grug_inventory:character"
local BOX_BOTTOM = 9.2
local MODE_BOX = {x = 0.2, y = 0.2, w = 7.9, h = BOX_BOTTOM - 0.2}
local GEAR_BOX = {x = 8.3, y = 0.2, w = 5.0, h = BOX_BOTTOM - 0.2}
local BOX_COLOR = "#00000040"
-- The mode body's area inside the mode box, below the mode buttons; the
-- Achievements body is drawn into it by its mod.
local MODE_AREA = {x = 0.4, y = 1.25, w = 7.5, h = BOX_BOTTOM - 0.15 - 1.25}
local MODES = {
	{id = "3d", label = "3D", x = 0.35, w = 0.8},
	{id = "stats", label = "Stats", x = 1.25, w = 1.2},
	{id = "effects", label = "Effects", x = 2.55, w = 1.4},
	{id = "achievements", label = "Achievements", x = 4.05, w = 2.1},
}
local MODE_Y, MODE_H = 0.35, 0.7

-- The gear box (weapon-slot design B5): the four armor pieces in the left
-- column, the two hands and the two trinkets in the right one, each slot's
-- name beside it. Positions only -- the slot list, its order and its label
-- come from grug_inventory.equipment_slots (the two hands' label and ghost
-- from the class rules, grug_inventory.HAND_RULES), so a new slot is one
-- entry there plus one row here. The Scout's quiver sits below the grid.
local SLOT_POS = {
	grug_head = {8.5, 0.95},
	grug_chest = {8.5, 2.2},
	grug_legs = {8.5, 3.45},
	grug_feet = {8.5, 4.7},
	grug_weapon = {10.9, 0.95},
	grug_offhand = {10.9, 2.2},
	grug_trinket1 = {10.9, 3.45},
	grug_trinket2 = {10.9, 4.7},
}
local LABEL_DX = 1.1 -- a slot's name starts this far right of the slot
local LABEL_CHARS = 8 -- and wraps at this width ("Caster offhand")
local QUIVER_POS = {8.5, 6.1}
local QUIVER_GHOST = "grug_inventory_quiver.png^[resize:64x64^[multiply:#666666"
-- The cover over the quiver cell's count corner (Round 41 ruling 6): the
-- slot's colour as drawn, default's listcolors slot #00000069 over the
-- #343434 of gui_formbg.png, approximately (accepted). Generated, no texture
-- file.
local QUIVER_COVER = "[fill:8x8:#1f1f1f"
-- Slot units the cover reaches past its size, about one pixel (see its use).
local QUIVER_COVER_OVER = 0.02
-- The engine's count "100" in the default font (font_size 16 times display
-- density and gui_scaling, fontengine.cpp getFontSize; window information
-- reports that product as real_gui_scaling), in pixels per unit of that
-- scale, with room to spare: the font's digits are about 0.56 em wide, its
-- line about 1.12 em high.
local COUNT_W_PX, COUNT_H_PX = 30, 20
-- Return home at the foot of the gear box, in every mode.
local HOME_LABEL_Y, HOME_BUTTON_Y = 7.6, 8.0

-- The cover's size in slot units for this player's window, so the count is
-- hidden at any GUI scale and window size. The slot is the engine's imgsize
-- (guiFormSpecMenu.cpp calculateImgsize): the preferred size, which window
-- information gives unpadded as size / max_formspec_size (the 5 % padding on
-- each side lowers it by at most 10 %), capped so the inventory form (a
-- real-coordinate size, Round 44) fits the padded window. Slot and count both
-- grow with gui_scaling, so the ratio changes mainly where that cap holds (a
-- small window, a large scale). Without window information (a page built
-- right at join) the cover takes most of the cell.
local function quiver_cover_size(player)
	local info = core.get_player_window_information(player:get_player_name())
	if not (info and info.size and info.max_formspec_size and
			info.real_gui_scaling) then
		return 0.9, 0.65
	end
	local width, height = info.size.x * 0.9, info.size.y * 0.9
	local slot = math.min(0.9 * info.size.x / info.max_formspec_size.x,
		width / grug_inventory.UI.frame_w, height / grug_inventory.UI.frame_h)
	-- Rounded up to the formspec's two decimals, never below the count.
	local function units(px)
		return math.min(1, math.ceil(px * info.real_gui_scaling / slot * 100) / 100)
	end
	return units(COUNT_W_PX), units(COUNT_H_PX)
end

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

local DAMAGE_REDUCTION_TOOLTIP = "Armor reduction against an enemy of your " ..
	"level. Higher against lower-level enemies, lower against higher-level ones."

-- The Scout's quiver slot (Round 28 ruling 26): the first cell of the quiver
-- list (above 100 arrows showing the true total, Round 41), its name and the
-- arrow total beside it.
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
		("label[%.2f,%.2f;%s]"):format(x + LABEL_DX, y + 0.25,
			esc("Quiver\n" .. total .. "/" .. grug_inventory.quiver_capacity())),
	}
	local first = inv:get_stack(grug_inventory.QUIVER_LIST, 1)
	if first:is_empty() then
		fs[#fs + 1] = ("image[%.2f,%.2f;1,1;%s]"):format(x, y, QUIVER_GHOST)
	elseif total > first:get_stack_max() then
		-- Above one stack the slot shows the true total (Round 41 ruling 6):
		-- drawn after the list[]. Clicks still reach the cell (inventory
		-- clicks are found by position, guiFormSpecMenu.cpp getItemAtPos).
		-- The hover does not: since the frame's formspec_version 6 (Round 44)
		-- elements stack in definition order, mouse moves go to the topmost
		-- element under the pointer (:4410-4422), here the full-cell
		-- item_image, so the cell loses its hover highlight and item tooltip
		-- while the overlay is shown (the same holds for the ghost images
		-- over empty equipment, quiver and deposit slots: no highlight). A
		-- cover hides the engine's count corner, then an item_image of the
		-- same item and slot rect draws the total with the list's own font
		-- and corner (guiItemImage.cpp draw -> drawItemStack). The count in an
		-- item_image string is undocumented engine behaviour
		-- (docs/technical/upstream-workarounds.md §4).
		-- Real coordinates: positions and sizes are both slot units, so the
		-- cover's offset into the cell is (1 - size). The engine truncates
		-- position and size to pixels, so the position is rounded down and
		-- the cover is QUIVER_COVER_OVER larger: at most about a pixel past
		-- the slot, onto its border (listcolors' #141318), never short of the
		-- count.
		local cover_w, cover_h = quiver_cover_size(player)
		fs[#fs + 1] = ("image[%.3f,%.3f;%.2f,%.2f;%s]"):format(
			math.floor((x + 1 - cover_w) * 1000) / 1000,
			math.floor((y + 1 - cover_h) * 1000) / 1000,
			cover_w + QUIVER_COVER_OVER, cover_h + QUIVER_COVER_OVER, QUIVER_COVER)
		fs[#fs + 1] = ("item_image[%.2f,%.2f;1,1;%s %d]"):format(x, y,
			first:get_name(), total)
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

-- The gear box: the slots with their names, tooltips and ghosts, the
-- quiver, Return home. The shift-click ring sends every drawn list to the
-- routing list (equipment.lua SHIFT_LIST), which moves gear between the
-- inventory and its slot and arrows into or out of the quiver.
local function gear_content(player, context)
	local inv = player:get_inventory()
	local class_id = grug_classes.get_class(player)
	local route = ("listring[current_player;%s]"):format(grug_inventory.SHIFT_LIST)
	local fs = {
		("box[%.2f,%.2f;%.2f,%.2f;%s]"):format(GEAR_BOX.x, GEAR_BOX.y, GEAR_BOX.w,
			GEAR_BOX.h, BOX_COLOR),
		("label[%.2f,0.55;Gear]"):format(SLOT_POS.grug_head[1]),
	}
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
			fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(pos[1] + LABEL_DX,
				pos[2] + (#name > LABEL_CHARS and 0.25 or 0.5),
				esc(grug_inventory.wrap_text(name, LABEL_CHARS)))
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
			fs[#fs + 1] = ("tooltip[%.2f,%.2f;1,1;%s]"):format(pos[1], pos[2], esc(tip))
			-- The ghost is drawn AFTER the list[] and only for empty slots,
			-- never before it to fake a transparent cell: listcolors[] is
			-- per-formspec and this page also carries the inventory view, so a
			-- page-wide transparent slot cell would strip the inventory's cells
			-- too (inventory_equipment.md §1). One inventory read per slot per
			-- formspec build; the build is a rare event — it happens on
			-- navigation and on the refresh hooks below, never in a step or on
			-- a hover.
			if inv:get_stack(slot.list, 1):is_empty() then
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
		fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(x, HOME_LABEL_Y,
			esc("Home: " .. label))
		fs[#fs + 1] = ("button[%.2f,%.2f;%.2f,0.8;grug_character_home;%s]"):format(
			x, HOME_BUTTON_Y, GEAR_BOX.x + GEAR_BOX.w - 0.15 - x,
			esc(("Return home (%s)"):format(state)))
	end
	return table.concat(fs)
end

-- 3D: the player model and, beside it, the cloak picker (Round 33, §2.10):
-- grug_achievements depends on this mod, so it is read at build time.
local function model_content(player)
	local mesh, textures = preview_model(player)
	local fs = {
		("model[0.4,1.35;3.3,7.6;grug_preview;%s;%s;0,160]"):format(
			esc(mesh), esc_texture_list(textures)),
	}
	local achievements = rawget(_G, "grug_achievements")
	if achievements then
		fs[#fs + 1] = "label[3.95,1.65;Cloak]"
		fs[#fs + 1] = achievements.cloak_dropdown(player, 3.95, 2.0, 3.8)
		fs[#fs + 1] = "label[3.95,3.35;" ..
			esc("Cloaks unlock through\nachievements.") .. "]"
	end
	return table.concat(fs)
end

-- Stats: the pools, armor, crit and dodge, the balance with Withdraw, the
-- Claim Stone status.
local STAT_X, STAT_Y, STAT_STEP = 0.4, 1.6, 0.5
local function stats_content(player)
	local class = grug_classes.get_class_def(player)
	local hp = grug_classes.get_pool_breakdown(player, "hp")
	local mana = class and class.resource == "mana"
		and grug_classes.get_pool_breakdown(player, "mana") or nil
	local armor = grug_core.get_armor_rating_breakdown and
		grug_core.get_armor_rating_breakdown(player) or {
			base = grug_core.get_armor_rating(player), multiplier = 1,
			result = grug_core.get_armor_rating(player), emergency = 0}
	local armor_reduction = grug_core.armor_reduction(armor.result,
		grug_core.get_player_level(player), 0.70) * 100
	local crit = grug_classes.get_crit_chance(player) * 100
	local dodge = grug_classes.get_dodge_chance(player) * 100
	local lines = {
		("Maximum HP: %d"):format(hp.final),
		mana and ("Maximum mana: " .. mana.final) or "Maximum rage: 100",
		("Armor: %.1f"):format(armor.result),
		("Damage reduction: %.1f%%"):format(armor_reduction),
		("Crit: %.1f%%"):format(crit),
		("Dodge: %.1f%%"):format(dodge),
		"Money: " .. grug_money.format(grug_money.get(player)),
	}
	local fs = {}
	for index, line in ipairs(lines) do
		fs[index] = ("label[%.2f,%.2f;%s]"):format(STAT_X,
			STAT_Y + (index - 1) * STAT_STEP, esc(line))
	end
	-- Round 28 ruling 21: the tooltip covers exactly the Damage reduction
	-- line (a real-coordinate label is centred on its y).
	fs[#fs + 1] = ("tooltip[%.2f,%.2f;5.0,%.2f;%s]"):format(STAT_X,
		STAT_Y + 3 * STAT_STEP - STAT_STEP / 2, STAT_STEP,
		esc(grug_inventory.wrap_text(DAMAGE_REDUCTION_TOOLTIP, 48)))
	-- The Bag of Coins (Round 34): Withdraw beside the balance opens
	-- grug_money's dialog and shares the money line's centre. The deposit
	-- slot is on the Inventory tab (Round 44).
	fs[#fs + 1] = ("button[5.6,%.2f;1.9,0.7;grug_money_withdraw;Withdraw]"):format(
		STAT_Y + 6 * STAT_STEP - 0.35)
	-- Claim Stone status (Round 25 ruling 14). Neither mod depends on the
	-- other, so grug_housing is read at build time; it returns "" until the
	-- player has received a stone and keeps the cached page current itself.
	local housing = rawget(_G, "grug_housing")
	if housing and housing.character_status_formspec then
		fs[#fs + 1] = housing.character_status_formspec(
			player:get_player_name(), STAT_X, STAT_Y + 7.5 * STAT_STEP)
	end
	return table.concat(fs)
end

-- Effects (Round 26): every active effect of the status icon row with its
-- name, detail and remaining time -- the text the row itself has no room
-- for. One column in the mode box.
local EFFECT_X, EFFECT_Y, EFFECT_STEP, EFFECT_ROWS = 0.4, 1.3, 0.95, 8
local EFFECT_ICON = 0.8
local NAME_CHARS, DETAIL_CHARS = 28, 34
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
		return ("label[%.2f,1.6;%s]"):format(EFFECT_X, esc("No active effects. " ..
			"Food, elixirs, skills, talents\nand hostile attacks show up here."))
	end
	local fs = {}
	-- A full box keeps its last row for the "more" line.
	local shown = #effects > EFFECT_ROWS and EFFECT_ROWS - 1 or #effects
	for index = 1, shown do
		local effect = effects[index]
		local y = EFFECT_Y + (index - 1) * EFFECT_STEP
		local name, time, detail = effect_lines(effect)
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
		("box[%.2f,%.2f;%.2f,%.2f;%s]"):format(MODE_BOX.x, MODE_BOX.y, MODE_BOX.w,
			MODE_BOX.h, BOX_COLOR),
	}
	for _, mode in ipairs(MODES) do
		local field = "grug_character_" .. mode.id
		fs[#fs + 1] = grug_inventory.selected_button_style(field, mode.id == selected)
		fs[#fs + 1] = ("button[%.2f,%.2f;%.2f,%.2f;%s;%s]"):format(
			mode.x, MODE_Y, mode.w, MODE_H, field, esc(mode.label))
	end
	if selected == "stats" then
		fs[#fs + 1] = stats_content(player)
	elseif selected == "effects" then
		fs[#fs + 1] = effects_content(player, context)
	elseif selected == "achievements" then
		fs[#fs + 1] = achievements_content(player, context)
	else
		fs[#fs + 1] = model_content(player)
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
	on_player_receive_fields = function(self, player, context, fields)
		local achievements = rawget(_G, "grug_achievements")
		if achievements then
			-- A new cloak redraws the character first, then the page, whose
			-- preview reads the live model.
			if fields.grug_cloak and
					achievements.choose_cloak_by_name(player, fields.grug_cloak) then
				sfinv.set_player_inventory_formspec(player, context)
				return true
			end
			if achievements.handle_tab_fields(player, context, fields) then
				return true
			end
		end
		if fields.grug_money_withdraw then
			grug_money.show_withdraw(player)
			return true
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
-- arrival starts or ends, and once when it becomes Ready. Nothing is re-sent
-- for other pages.
local effects_elapsed = 0
core.register_globalstep(function(dtime)
	effects_elapsed = effects_elapsed + dtime
	if effects_elapsed < 1 then return end
	effects_elapsed = effects_elapsed % 1
	for _, player in ipairs(core.get_connected_players()) do
		local context = sfinv.contexts[player:get_player_name()]
		if context and context.page == CHARACTER_PAGE then
			if (selected_mode(context) == "effects" and
					grug_inventory.effects_key(player) ~= context.grug_effects_key) or
					home_text(player) ~= context.grug_home_text then
				sfinv.set_player_inventory_formspec(player, context)
			end
		end
	end
end)

-- The Help page lives in help.lua (dofile'd by init.lua before this file).

--
-- Inventory page (Round 44, spec §3.2, wireframe v1): the four bag slots,
-- the potion belt, the Bag of Coins deposit and Sort along the top, the full
-- inventory view (main[9..] and every equipped bag as one scrolling grid, the
-- hotbar below) under them. Real coordinates; no listring, so shift-click
-- does nothing here (one inventory has no "other side").
--

local INVENTORY_PAGE = "grug_inventory:inventory"
local TOP_LABEL_Y, TOP_SLOT_Y = 0.3, 0.55
local BAGS_X, BELT_X, COINS_X = 0.4, 5.55, 10.7
local SORT_X, SORT_W = 11.95, 1.15
local PITCH = 1.25
-- Sort ignores clicks for this long after one it ran (spec ruling 5): no
-- countdown, no resend; the lists the sort changed reach the client on their
-- own.
local SORT_COOLDOWN_US = 2500000

local function inventory_content(player)
	local deposit, deposit_list = grug_money.deposit_location(player)
	local fs = {
		"real_coordinates[true]",
		("label[%.2f,%.2f;Bags]"):format(BAGS_X, TOP_LABEL_Y),
		("label[%.2f,%.2f;Potion belt]"):format(BELT_X, TOP_LABEL_Y),
		("label[%.2f,%.2f;Coins]"):format(COINS_X, TOP_LABEL_Y),
	}
	for i = 1, grug_inventory.BAG_COUNT do
		fs[#fs + 1] = ("list[current_player;%s;%.2f,%.2f;1,1;]"):format(
			grug_inventory.bag_list(i), BAGS_X + (i - 1) * PITCH, TOP_SLOT_Y)
	end
	fs[#fs + 1] = ("tooltip[%.2f,%.2f;%.2f,1;%s]"):format(BAGS_X, TOP_SLOT_Y,
		grug_inventory.BAG_COUNT * PITCH - 0.25,
		esc("Bag slots — a bag here adds its slots to the inventory below"))
	local belt = grug_inventory.POTION_BELT_SIZE
	fs[#fs + 1] = ("list[current_player;%s;%.2f,%.2f;%d,1;]"):format(
		grug_inventory.POTION_BELT, BELT_X, TOP_SLOT_Y, belt)
	fs[#fs + 1] = ("tooltip[%.2f,%.2f;%.2f,1;%s]"):format(BELT_X, TOP_SLOT_Y,
		belt * PITCH - 0.25, esc("Potion belt — potions and elixirs only"))
	-- The Bag of Coins deposit (Round 34, moved here from the Character page
	-- in Round 44): a bag put here is credited at once, so the slot is always
	-- empty and always shows its ghost.
	fs[#fs + 1] = ("list[%s;%s;%.2f,%.2f;1,1;]"):format(deposit, deposit_list,
		COINS_X, TOP_SLOT_Y)
	fs[#fs + 1] = ("image[%.2f,%.2f;1,1;grug_money_bag_of_coins.png^[multiply:#666666]")
		:format(COINS_X, TOP_SLOT_Y)
	fs[#fs + 1] = ("tooltip[%.2f,%.2f;1,1;%s]"):format(COINS_X, TOP_SLOT_Y,
		esc("Deposit — put a Bag of Coins here to add its money to your balance"))
	fs[#fs + 1] = ("button[%.2f,%.2f;%.2f,1;grug_inv_sort;Sort]"):format(SORT_X,
		TOP_SLOT_Y, SORT_W)
	fs[#fs + 1] = ("tooltip[grug_inv_sort;%s]"):format(esc("Sort the inventory " ..
		"and the bags. The hotbar stays as it is."))
	return table.concat(fs)
end

sfinv.register_page(INVENTORY_PAGE, {
	title = "Inventory",
	get = function(self, player, context)
		return sfinv.make_formspec(player, context, inventory_content(player),
			"full")
	end,
	on_player_receive_fields = function(self, player, context, fields)
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

-- Re-send a cached Character page (any mode) and nothing else: the stat and
-- money hooks below use it, and so does the quiver total (bags.lua), which
-- the gear box shows in every mode.
function grug_inventory.refresh_character(player)
	local context = sfinv.contexts[player:get_player_name()]
	if context and context.page == CHARACTER_PAGE then
		sfinv.set_player_inventory_formspec(player, context)
	end
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

-- Keep the cached Character form current even while inventory is closed, so
-- opening it shows the latest balance. Other selected pages need no rebuild.
grug_money.register_on_change(function(player)
	grug_inventory.refresh_character(player)
end)
