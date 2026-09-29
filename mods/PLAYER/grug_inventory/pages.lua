-- sfinv pages: Character (new homepage) and Bags, plus the shared nav order
-- (the Help page is registered by help.lua). sfinv uses legacy formspec
-- coordinates; shared content ends before y=7.0.

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
-- grug_inventory.equipment_slots, so a new slot is one entry there plus one
-- row here.
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

local function character_content(player)
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
		("model[0,1.6;2.4,5.2;grug_preview;%s;%s;0,160]"):format(
			esc(mesh), esc_texture_list(textures)),
		("label[2.75,1.25;Maximum HP: %d]"):format(hp.final),
		("label[2.75,1.70;%s]"):format(esc(mana and
			("Maximum mana: " .. mana.final) or "Maximum rage: 100")),
		("label[2.75,2.15;Armor: %.1f]"):format(armor.result),
		("label[2.75,2.60;Own-level reduction: %.1f%%]"):format(armor_reduction),
		("label[2.75,3.05;Crit: %.1f%%]"):format(crit),
		("label[2.75,3.50;Dodge: %.1f%%]"):format(dodge),
		("label[2.75,3.95;Money: %s]"):format(esc(grug_money.format(grug_money.get(player)))),
		"label[8.3,1.25;Armor]label[9.3,1.25;Gear]",
	}
	-- Claim Stone status (Round 25 ruling 14). Neither mod depends on the
	-- other, so grug_housing is read at build time; it returns "" until the
	-- player has received a stone and keeps the cached page current itself.
	local housing = rawget(_G, "grug_housing")
	if housing and housing.character_status_formspec then
		fs[#fs + 1] = housing.character_status_formspec(
			player:get_player_name(), 2.75, 4.55)
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
			local slot_label = slot.list == "grug_weapon" and
				"Weapon — equip here, then use a combat skill from the hotbar" or
				slot.label
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
					pos[1], pos[2], GHOST_TEXTURE[slot.list]))
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
-- below it, the choice kept in the sfinv context.
--

local CHARACTER_PAGE = "grug_inventory:character"
local TABS = {
	{id = "stats", label = "Stats", x = 0.0, w = 1.5},
	{id = "effects", label = "Effects", x = 1.5, w = 1.5},
}
local TAB_Y, TAB_H = 0.0, 0.7
-- Two columns of six rows fit between the tab row and the inventory at 7.0.
local EFFECT_X = {0.2, 5.3}
local EFFECT_Y, EFFECT_STEP, EFFECT_ROWS = 0.95, 0.95, 6
local EFFECT_ICON = 0.8
local NAME_CHARS, DETAIL_CHARS = 28, 34
local TIME_COLOR = "#f0c75e"

local function selected_tab(context)
	return context.grug_character_tab == "effects" and "effects" or "stats"
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
		local body = tab == "effects" and effects_content(player, context) or
			character_content(player)
		return sfinv.make_formspec(player, context, tab_row(tab) .. body, true)
	end,
	on_player_receive_fields = function(self, player, context, fields)
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
-- about once a minute). Nothing is re-sent for the Stats tab or other pages.
local effects_elapsed = 0
core.register_globalstep(function(dtime)
	effects_elapsed = effects_elapsed + dtime
	if effects_elapsed < 1 then return end
	effects_elapsed = 0
	for _, player in ipairs(core.get_connected_players()) do
		local context = sfinv.contexts[player:get_player_name()]
		if context and context.page == CHARACTER_PAGE and
				selected_tab(context) == "effects" and
				grug_inventory.effects_key(player) ~= context.grug_effects_key then
			sfinv.set_player_inventory_formspec(player, context)
		end
	end
end)

-- The Help page lives in help.lua (dofile'd by init.lua before this file).

--
-- Bags page
--

local function bags_content(player, context)
	local inv = player:get_inventory()
	local selected = context.grug_bag or 1
	local fs = {}
	local has_quiver = core.get_item_group(
		inv:get_stack("grug_offhand", 1):get_name(), "grug_quiver") > 0
	if has_quiver then
		table.insert(fs, "label[8.3,0.1;Quiver]list[current_player;grug_quiver_content;8.3,0.35;2,2;]")
		table.insert(fs, "listring[current_player;grug_quiver_content]listring[current_player;main]")
	end
	for i = 1, grug_inventory.BAG_COUNT do
		local x = (i - 1) * 2 + 0.3
		local field = "grug_open_" .. i
		table.insert(fs, ("list[current_player;%s;%.1f,0.35;1,1;]"):format(
			grug_inventory.bag_list(i), x))
		table.insert(fs, grug_inventory.selected_button_style(field, i == selected))
		table.insert(fs, ("button[%.1f,1.35;1.5,0.7;grug_open_%d;%s]"):format(
			x - 0.25, i, esc("Bag " .. i)))
	end

	local bag = inv:get_stack(grug_inventory.bag_list(selected), 1)
	local slots = grug_inventory.bag_slots_of(bag)
	if slots > 0 then
		table.insert(fs, ("label[0,2.05;%s]"):format(
			esc(("Bag %d — %s"):format(selected, bag:get_description()))))
		table.insert(fs, ("list[current_player;%s;0,2.35;8,3;]"):format(
			grug_inventory.content_list(selected)))
		table.insert(fs, ("listring[current_player;%s]listring[current_player;main]")
			:format(grug_inventory.content_list(selected)))
	else
		table.insert(fs, ("label[0,2.35;%s]"):format(
			esc(("Bag %d is empty — put a bag into the slot above."):format(selected))))
	end
	return table.concat(fs)
end

sfinv.register_page("grug_inventory:bags", {
	title = "Bags",
	get = function(self, player, context)
		context.grug_bag = context.grug_bag or 1
		return sfinv.make_formspec(player, context,
			bags_content(player, context), true)
	end,
	on_player_receive_fields = function(self, player, context, fields)
		for i = 1, grug_inventory.BAG_COUNT do
			if fields["grug_open_" .. i] then
				context.grug_bag = i
				sfinv.set_page(player, "grug_inventory:bags")
				return true
			end
		end
	end,
})

--
-- Homepage & nav order: Character first, Bags second, Crafting after.
--

-- Deliberate override (not a wrapper): the Character page is the homepage
-- for everyone, including creative players. grug_inventory optionally
-- depends on creative so the load order — and thus this override — is
-- deterministic (creative wraps this function; we load after it).
function sfinv.get_homepage_name(player)
	return "grug_inventory:character"
end

local nav_order = {"grug_inventory:character", "grug_inventory:bags",
	"grug_inventory:help", "sfinv:crafting"}
local ordered, seen = {}, {}
for _, name in ipairs(nav_order) do
	if sfinv.pages[name] then
		table.insert(ordered, sfinv.pages[name])
		seen[name] = true
	end
end
for _, def in ipairs(sfinv.pages_unordered) do
	if not seen[def.name] then
		table.insert(ordered, def)
	end
end
sfinv.pages_unordered = ordered

--
-- Refresh hooks: an open Character/Bags page re-renders on stat or bag
-- changes (the list contents themselves update live anyway).
--

function grug_inventory.refresh(player, force)
	local context = sfinv.get_or_create_context(player)
	if force or context.page == "grug_inventory:character" or
			context.page == "grug_inventory:bags" then
		sfinv.set_page(player, context.page)
	end
end

grug_xp.register_on_level_change(function(player, old_level, new_level)
	if old_level ~= nil then
		grug_inventory.refresh(player)
	end
end)

-- Ghost icons mirror slot occupancy, so an equipment change re-renders an
-- open Character page (inventory_equipment.md §1). Rare event; refresh()
-- itself no-ops on any other page.
grug_core.register_on_equipment_change(function(player, listname)
	grug_inventory.refresh(player)
end)

grug_core.register_on_status_modifiers_changed(function(player)
	grug_inventory.refresh(player)
end)

-- Join needs no second callback here. grug_inventory depends on both sfinv
-- and player_api, so their join callbacks run first. equipment.lua's later
-- join callback sizes the slots and calls equipment_changed, which reaches
-- the single refresh consumer above after the model and sfinv context exist.

-- Keep the cached Character form current even while inventory is closed, so
-- opening it shows the latest balance. Other selected pages need no rebuild.
grug_money.register_on_change(function(player)
	local context = sfinv.contexts[player:get_player_name()]
	if context and context.page == "grug_inventory:character" then
		sfinv.set_player_inventory_formspec(player, context)
	end
end)
