-- sfinv pages: Inventory (the homepage) and Character (the Help page is
-- registered by help.lua; the frame, the tab order and the inventory views
-- live in ui.lua). Character's content is in legacy coordinates and ends
-- before y=7.0; the Inventory tab is drawn in real coordinates.

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
-- Character page
--

-- Equipment column layout (weapon-slot design B5). The four armor pieces keep
-- their own column at x = 6; the second column leads with WEAPON and OFFHAND
-- so the pair reads as "hands", with the two trinkets below them. Positions
-- only — the slot list, its order and its label come from
-- grug_inventory.equipment_slots (the two hands' label and ghost from the
-- class rules, grug_inventory.HAND_RULES), so a new slot is one entry there
-- plus one row here. The Scout's quiver sits left of the armor column.
local SLOT_POS = {
	grug_head = {8.3, 1.85},
	grug_chest = {8.3, 3.05},
	grug_legs = {8.3, 4.25},
	grug_feet = {8.3, 5.45},
	grug_weapon = {9.3, 1.85},
	grug_offhand = {9.3, 3.05},
	grug_trinket1 = {9.3, 4.25},
	grug_trinket2 = {9.3, 5.45},
}
local QUIVER_POS = {7.3, 1.85}
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

-- A tooltip[] rect of "1,1" does NOT cover one inventory cell in legacy
-- coordinates, it covers one grid CELL INCLUDING its gutters: both elements
-- share getElementBasePos (guiFormSpecMenu.cpp:257-265) so the origins do
-- coincide, but list[] sizes a slot as `imgsize` (:490-495) while tooltip[]
-- multiplies its geometry by `spacing` (:2566-2567), and legacy `spacing` is
-- (imgsize·5/4, imgsize·15/13) (:3340). A "1,1" rect would therefore be 25 %
-- wider and 15 % taller than the slot and tile the gaps between our slots, so
-- the label of a neighbour shows while the pointer sits between two of them.
-- These two factors are exactly imgsize/spacing.
local TOOLTIP_W = 4 / 5
local TOOLTIP_H = 13 / 15

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
-- list (above 100 arrows showing the true total, Round 41), the arrow total
-- beside it, and the shift-click ring main <-> quiver.
local function quiver_content(player)
	local inv = player:get_inventory()
	local total = grug_inventory.quiver_count(player)
	local x, y = QUIVER_POS[1], QUIVER_POS[2]
	local fs = {
		("label[%.1f,1.25;Quiver]"):format(x),
		("list[current_player;%s;%.1f,%.1f;1,1;]"):format(
			grug_inventory.QUIVER_LIST, x, y),
		("tooltip[%.1f,%.1f;%.4f,%.4f;%s]"):format(x, y, TOOLTIP_W, TOOLTIP_H,
			esc("Quiver — up to " .. grug_inventory.quiver_capacity() ..
				" arrows. Drag or shift-click arrows in; click to take up to " ..
				"100. Shots draw from here first.")),
		("label[%.1f,%.2f;%s]"):format(x, y + 1.0,
			esc(total .. "/" .. grug_inventory.quiver_capacity())),
		"listring[current_player;main]",
		("listring[current_player;%s]"):format(grug_inventory.QUIVER_LIST),
	}
	local first = inv:get_stack(grug_inventory.QUIVER_LIST, 1)
	if first:is_empty() then
		fs[#fs + 1] = ("image[%.1f,%.1f;1,1;%s]"):format(x, y, QUIVER_GHOST)
	elseif total > first:get_stack_max() then
		-- Above one stack the slot shows the true total (Round 41 ruling 6):
		-- drawn after the list[], so clicks still reach the cell (inventory
		-- clicks are found by position, guiFormSpecMenu.cpp getItemAtPos, and
		-- image / item_image are click-through elements, visible only while
		-- drawn, so the list keeps its hover highlight and item tooltip; only
		-- the cover paints over the highlight in its corner); a
		-- cover hides the engine's count corner, then an item_image of the
		-- same item and slot rect draws the total with the list's own font
		-- and corner (guiItemImage.cpp draw -> drawItemStack). The count in an
		-- item_image string is undocumented engine behaviour
		-- (docs/technical/upstream-workarounds.md §4).
		-- Legacy layout: a position counts in spacing units, a size in slot
		-- units (guiFormSpecMenu.cpp getElementBasePos, parseImage), so the
		-- cover's offset into the cell is (1 - size) slots, times imgsize /
		-- spacing (TOOLTIP_W, TOOLTIP_H). The cell is where the list[] above
		-- draws it, after its %.1f rounding. The engine truncates position and
		-- size to pixels, so the position is rounded down and the cover is
		-- QUIVER_COVER_OVER larger: at most about a pixel past the slot, onto
		-- its border (listcolors' #141318), never short of the count.
		local cx, cy = tonumber(("%.1f"):format(x)), tonumber(("%.1f"):format(y))
		local cover_w, cover_h = quiver_cover_size(player)
		fs[#fs + 1] = ("image[%.3f,%.3f;%.2f,%.2f;%s]"):format(
			math.floor((cx + (1 - cover_w) * TOOLTIP_W) * 1000) / 1000,
			math.floor((cy + (1 - cover_h) * TOOLTIP_H) * 1000) / 1000,
			cover_w + QUIVER_COVER_OVER, cover_h + QUIVER_COVER_OVER, QUIVER_COVER)
		fs[#fs + 1] = ("item_image[%.1f,%.1f;1,1;%s %d]"):format(x, y,
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
local function home_button_text(player)
	local home_mod = rawget(_G, "grug_home")
	local home = home_mod and home_mod.get(player)
	if not home then return nil end
	local remaining = home_mod.remaining(player)
	local state = home_mod.is_pending(player) and "Preparing arrival" or
		(remaining > 0 and ("%d min"):format(math.ceil(remaining / 60)) or "Ready")
	return ("Return home: %s (%s)"):format(home.label, state)
end

local function character_content(player, context)
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

	local mesh, textures = preview_model(player)
	local fs = {
		("model[0,1.4;2.4,4.8;grug_preview;%s;%s;0,160]"):format(
			esc(mesh), esc_texture_list(textures)),
		("label[2.75,1.25;Maximum HP: %d]"):format(hp.final),
		("label[2.75,1.70;%s]"):format(esc(mana and
			("Maximum mana: " .. mana.final) or "Maximum rage: 100")),
		("label[2.75,2.15;Armor: %.1f]"):format(armor.result),
		("label[2.75,2.60;Damage reduction: %.1f%%]"):format(armor_reduction),
		-- Round 28 ruling 21. A legacy label[] is centred on (y + 7/30) and
		-- 0.7 spacing units tall, and tooltip[] works in spacing units from
		-- the same origin (see TOOLTIP_W above), so this rect covers exactly
		-- this one line and none of its neighbours 0.45 above or below.
		("tooltip[2.75,%.3f;3.6,0.45;%s]"):format(2.60 + 7 / 30 - 0.225,
			esc(grug_inventory.wrap_text(DAMAGE_REDUCTION_TOOLTIP, 48))),
		("label[2.75,3.05;Crit: %.1f%%]"):format(crit),
		("label[2.75,3.50;Dodge: %.1f%%]"):format(dodge),
		("label[2.75,3.95;Money: %s]"):format(esc(grug_money.format(grug_money.get(player)))),
		"label[8.3,1.25;Armor]label[9.3,1.25;Gear]",
	}
	-- The Bag of Coins (Round 34): Withdraw beside the balance opens
	-- grug_money's dialog and shares the money line's centre. The deposit
	-- slot is on the Inventory tab (Round 44).
	fs[#fs + 1] = "button[5.6,3.83;1.55,0.7;grug_money_withdraw;Withdraw]"
	-- Claim Stone status (Round 25 ruling 14). Neither mod depends on the
	-- other, so grug_housing is read at build time; it returns "" until the
	-- player has received a stone and keeps the cached page current itself.
	local housing = rawget(_G, "grug_housing")
	if housing and housing.character_status_formspec then
		fs[#fs + 1] = housing.character_status_formspec(
			player:get_player_name(), 2.75, 4.55)
	end
	-- Below the at most three status lines, above the main inventory. The
	-- text shown is kept in the context for the countdown poll below.
	local home_text = home_button_text(player)
	context.grug_home_text = home_text
	if home_text then
		fs[#fs + 1] = ("button[2.75,6.25;5.55,0.7;grug_character_home;%s]"):format(esc(home_text))
	end

	-- The cloak picker under the model (Round 33, §2.10): grug_achievements
	-- depends on this mod, so it is read at build time like grug_jobs.
	local achievements = rawget(_G, "grug_achievements")
	if achievements then
		fs[#fs + 1] = achievements.cloak_dropdown(player, 0, 6.3, 2.6)
	end

	local class_id = grug_classes.get_class(player)
	if grug_inventory.has_quiver(player) then
		fs[#fs + 1] = quiver_content(player)
	end
	for _, slot in ipairs(grug_inventory.equipment_slots) do
		local pos = SLOT_POS[slot.list]
		if pos then
			table.insert(fs, ("list[current_player;%s;%.1f,%.1f;1,1;]"):format(
				slot.list, pos[1], pos[2]))
			-- The area tooltip is the slot's label: eight one-unit cells have no
			-- room for eight text labels, and without one nothing distinguishes
			-- the weapon slot from the offhand or a trinket.
			--
			-- It shows on EMPTY slots only, which is what we want — a slot with
			-- an item in it should describe the item. That falls out of the draw
			-- order rather than out of any option: guiFormSpecMenu.cpp:3672-3682
			-- runs the tooltip-RECT loop before the children are drawn, and
			-- :3714-3717 lets the hovered ITEM tooltip overwrite the very same
			-- m_tooltip_element afterwards, which is only painted at :3856.
			local slot_label = grug_inventory.slot_label(class_id, slot.list) or
				slot.label
			if slot.list == "grug_weapon" then
				slot_label = slot_label ..
					" — equip here, then use a combat skill from the hotbar"
			end
			table.insert(fs, ("tooltip[%.1f,%.1f;%.4f,%.4f;%s]"):format(
				pos[1], pos[2], TOOLTIP_W, TOOLTIP_H, esc(slot_label)))
			-- The ghost is drawn AFTER the list[] and only for empty slots,
			-- never before it to fake a transparent cell: listcolors[] is
			-- per-formspec and this page also carries sfinv's main inventory,
			-- so a page-wide transparent slot cell would strip the main
			-- inventory's cells too (inventory_equipment.md §1). One inventory
			-- read per slot per formspec build; the build is a rare event —
			-- it happens on navigation and on the refresh hooks below, never
			-- in a step or on a hover.
			if player:get_inventory():get_stack(slot.list, 1):is_empty() then
				table.insert(fs, ("image[%.1f,%.1f;1,1;%s]"):format(
					pos[1], pos[2], grug_inventory.slot_ghost(class_id, slot.list) or
					GHOST_TEXTURE[slot.list]))
			end
		end
	end
	return table.concat(fs)
end

--
-- Character page tabs (Round 26): "Stats" is the view above, "Effects" lists
-- every active effect of the status icon row with its name, detail and
-- remaining time -- the text the row itself has no room for. Same pattern as
-- the Help page: a button row at y = 0, the selected one styled, the body
-- below it, the choice kept in the sfinv context. "Professions" (Round 28
-- ruling 23) shows each known profession's tier and progress; grug_jobs
-- builds that body (it depends on this mod, so it is read at build time).
-- "Achievements" (Round 33) lists the character's achievements and the cloak
-- each unlocks; grug_achievements builds it the same way.
--

local CHARACTER_PAGE = "grug_inventory:character"
local TABS = {
	{id = "stats", label = "Stats", x = 0.0, w = 1.5},
	{id = "effects", label = "Effects", x = 1.5, w = 1.5},
	{id = "achievements", label = "Achievements", x = 3.0, w = 2.2},
	{id = "professions", label = "Professions", x = 5.2, w = 2.0},
}
local TAB_Y, TAB_H = 0.0, 0.7
-- Two columns of six rows fit between the tab row and the inventory at 7.0.
local EFFECT_X = {0.2, 5.3}
local EFFECT_Y, EFFECT_STEP, EFFECT_ROWS = 0.95, 0.95, 6
local EFFECT_ICON = 0.8
local NAME_CHARS, DETAIL_CHARS = 28, 34
local TIME_COLOR = "#f0c75e"

local function selected_tab(context)
	for _, tab in ipairs(TABS) do
		if context.grug_character_tab == tab.id then return tab.id end
	end
	return "stats"
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
		return "label[0.2,1.0;" .. esc("No active effects. Food, elixirs, " ..
			"skills, talents and hostile attacks show up here.") .. "]"
	end
	local fs = {}
	local capacity = EFFECT_ROWS * #EFFECT_X
	for index = 1, math.min(#effects, capacity) do
		local effect = effects[index]
		local column = math.floor((index - 1) / EFFECT_ROWS) + 1
		local x = EFFECT_X[column]
		local y = EFFECT_Y + ((index - 1) % EFFECT_ROWS) * EFFECT_STEP
		local name, time, detail = effect_lines(effect)
		fs[#fs + 1] = ("image[%.2f,%.2f;%.2f,%.2f;%s]"):format(x, y,
			EFFECT_ICON, EFFECT_ICON, esc(effect.texture))
		fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(x + 0.95, y - 0.05,
			esc(name .. "  " .. core.colorize(TIME_COLOR, time)))
		if detail ~= "" then
			fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(x + 0.95, y + 0.37,
				esc(detail))
		end
	end
	if #effects > capacity then
		fs[#fs + 1] = ("label[5.3,6.65;%s]"):format(
			esc(("... and %d more"):format(#effects - capacity)))
	end
	return table.concat(fs)
end

local function achievements_content(player, context)
	local achievements = rawget(_G, "grug_achievements")
	if achievements then
		return achievements.character_achievements_formspec(player, context)
	end
	return ""
end

local function professions_content(player)
	local jobs = rawget(_G, "grug_jobs")
	if jobs and jobs.character_professions_formspec then
		return jobs.character_professions_formspec(player)
	end
	return ""
end

-- Re-sends the cached inventory form only when the Character page shows tab
-- `tab` (grug_jobs calls this after a counted craft).
function grug_inventory.refresh_character_tab(player, tab)
	local context = sfinv.contexts[player:get_player_name()]
	if context and context.page == CHARACTER_PAGE and selected_tab(context) == tab then
		sfinv.set_player_inventory_formspec(player, context)
	end
end

local function tab_row(selected)
	local fs = {}
	for _, tab in ipairs(TABS) do
		local field = "grug_character_" .. tab.id
		fs[#fs + 1] = grug_inventory.selected_button_style(field, tab.id == selected)
		fs[#fs + 1] = ("button[%.2f,%.2f;%.2f,%.2f;%s;%s]"):format(
			tab.x, TAB_Y, tab.w, TAB_H, field, esc(tab.label))
	end
	return table.concat(fs)
end

sfinv.register_page(CHARACTER_PAGE, {
	title = "Character",
	get = function(self, player, context)
		local tab = selected_tab(context)
		local body
		if tab == "effects" then
			body = effects_content(player, context)
		elseif tab == "achievements" then
			body = achievements_content(player, context)
		elseif tab == "professions" then
			body = professions_content(player)
		else
			body = character_content(player, context)
		end
		return sfinv.make_formspec(player, context, tab_row(tab) .. body, true)
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
		for _, tab in ipairs(TABS) do
			if fields["grug_character_" .. tab.id] then
				context.grug_character_tab = tab.id
				sfinv.set_page(player, CHARACTER_PAGE)
				return true
			end
		end
	end,
})

-- The cached inventory formspec is only re-sent when the Effects tab is the
-- selected view AND its printed text changed: an effect came or went, a
-- shield value moved, or a coarse remaining time ticked (whole minutes, so
-- about once a minute). On the Stats tab it is re-sent when the Return home
-- text changed: once a minute of a running cooldown, when an arrival starts
-- or ends, and once when it becomes Ready. Nothing is re-sent for other
-- pages.
local effects_elapsed = 0
core.register_globalstep(function(dtime)
	effects_elapsed = effects_elapsed + dtime
	if effects_elapsed < 1 then return end
	effects_elapsed = effects_elapsed % 1
	for _, player in ipairs(core.get_connected_players()) do
		local context = sfinv.contexts[player:get_player_name()]
		if context and context.page == CHARACTER_PAGE then
			local tab = selected_tab(context)
			if (tab == "effects" and grug_inventory.effects_key(player) ~= context.grug_effects_key) or
					(tab == "stats" and home_button_text(player) ~= context.grug_home_text) then
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
local POTION_BELT = "grug_potion_belt"
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
	fs[#fs + 1] = ("list[current_player;%s;%.2f,%.2f;4,1;]"):format(POTION_BELT,
		BELT_X, TOP_SLOT_Y)
	fs[#fs + 1] = ("tooltip[%.2f,%.2f;%.2f,1;%s]"):format(BELT_X, TOP_SLOT_Y,
		4 * PITCH - 0.25, esc("Potion belt — potions and elixirs only"))
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

-- Re-send a cached Character page (any tab) and nothing else: the stat and
-- money hooks below use it; the quiver total uses
-- refresh_character_tab(player, "stats").
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
