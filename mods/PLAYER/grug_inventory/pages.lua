-- sfinv pages: Character (new homepage) and Bags. sfinv uses legacy
-- formspec coordinates; shared content ends before y=7.0.

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
	grug_head = {8.3, 1.1},
	grug_chest = {8.3, 2.3},
	grug_legs = {8.3, 3.5},
	grug_feet = {8.3, 4.7},
	grug_weapon = {9.3, 1.1},
	grug_offhand = {9.3, 2.3},
	grug_trinket1 = {9.3, 3.5},
	grug_trinket2 = {9.3, 4.7},
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
-- `static.sh` in this round's evidence directory now scans every `.png` literal
-- under `mods/*/grug_*` against the real texture pool, so the next deleted
-- sprite is a failing gate instead of an untextured slot.
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

	local lines = {
		("HP %d=B%dxC%.2fx(100+G%g+T%g+S%g)%%"):format(
			hp.final, hp.base, hp.class_factor, hp.gear_percent,
			hp.talent_percent, hp.status_percent),
		mana and
			("Mana %d=B%dxC%.2fx(100+G%g+T%g+S%g)%%"):format(
				mana.final, mana.base, mana.class_factor, mana.gear_percent,
				mana.talent_percent, mana.status_percent)
			or "Rage 100=fixed; no C/G/T scaling",
		("Armor %.1f x %.2f + %.1f = %.1f; own-level %.1f%%"):format(
			armor.base, armor.multiplier, armor.emergency,
			armor.result, armor_reduction),
	}

	local mesh, textures = preview_model(player)
	local fs = {
		("model[0,0.85;2.4,5.4;grug_preview;%s;%s;0,160]"):format(
			esc(mesh), esc_texture_list(textures)),
		("label[2.75,0.50;Maximum HP: %d]"):format(hp.final),
		("label[2.75,0.95;%s]"):format(esc(mana and
			("Maximum mana: " .. mana.final) or "Maximum rage: 100")),
		("label[2.75,1.40;Armor: %.1f]"):format(armor.result),
		("label[2.75,1.85;Own-level reduction: %.1f%%]"):format(armor_reduction),
		"label[2.75,2.45;Pool and armor details]",
		"textarea[2.90,2.85;4.95,3.5;;;" .. esc(table.concat(lines, "\n\n")) .. "]",
		"label[8.3,0.50;Armor]label[9.3,0.50;Gear]",
	}

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
			table.insert(fs, ("tooltip[%.1f,%.1f;%.4f,%.4f;%s]"):format(
				pos[1], pos[2], TOOLTIP_W, TOOLTIP_H, esc(slot.label)))
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

sfinv.register_page("grug_inventory:character", {
	title = "Character",
	get = function(self, player, context)
		return sfinv.make_formspec(player, context,
			character_content(player), true)
	end,
})

-- Player-facing formula reference. It deliberately explains only stable
-- rules and points back to the live Character page for the player's numbers.
sfinv.register_page("grug_inventory:help", {
	title = "Help",
	get = function(self, player, context)
		local text = table.concat({
			"Welcome to Grudgelands",
			"Gather wood, stone and useful materials around your starting area. Open Crafting > Basics to inspect starter recipes, then craft a weapon and equip it on the Character page.",
			"Put a combat skill on your hotbar and use it to fight nearby creatures. Your weapon belongs in the Weapon equipment slot; skills use that weapon. Recover between fights and use food for a five-minute buff.",
			"Basics shows starter recipes immediately. Finding a recipe's main material reveals further recipes, even when it is carried in a bag. This only reveals instructions: crafting itself has no character-level requirement.",
			"Open Skills to recover an unlocked skill or purchased mount by dragging its icon into your inventory. An icon already in your inventory or a bag cannot be copied. Drop unused skill icons to remove them safely; their unlocks remain available in Skills.",
			"Visit city profession trainers for specialized crafts and equipment repair. Riding trainers in capital stables teach riding. Cooking has its own recipe book; new profession recipes stay in their profession's book.",
			"Character formulas",
			"Base pool = 20 + 5 x level + 0.66 x level squared (rounded).",
			"The Character pool lines read maximum = B x C x (100 + G + T + S)%, where B is the base pool, C the class factor, G the gear percentage, T the talent percentage and S the active status percentage.",
			"Caster mana uses the neutral base pool, then adds mana percentages. Rage is always 0-100.",
			"Strength adds floor(Strength / 10) as flat melee damage.",
			"Intelligence adds floor(Intelligence / 10) as spell power: flat spell damage and a percentage bonus to healing and absorbs.",
			"Dexterity adds 0.1 percentage point each of Crit and Dodge per point; Crit starts at 5%.",
			"The Talents header shows effective/raw Crit and Dodge with their caps, plus raw Armor rating, its active Unbroken multiplier and same-level reduction.",
			"Crit multiplies damage by 1.5.",
			"Dodge avoids the hit entirely.",
			"Armor is a rating resolved against the attacker's level; only the final reduction is capped at 70%.",
			"Item level is counted once, in the weapon's base damage; your character level applies the shared damage fit; there is no separate item-level multiplier.",
			"At level 60, an item-level 70 weapon gives about 9% more effective swing damage than item level 60, while item level 50 gives about 7% less, before enchants.",
			"Healing and absorbs are percentages of the caster's neutral base pool; spell power is a percentage bonus.",
			"Mana costs are percentages of the unmodified neutral base pool. Enchants and talents do not make a spell cost more.",
			"Mana regeneration is 1 + 0.15 x level per second out of combat. The Troll multiplier applies only out of combat. In combat you regenerate the larger of one quarter of that rate and 0.25% of your maximum mana per second; Cold Focus multiplies that combat rate.",
			"A food's instant heal and regeneration wait until you are out of combat. Its pool, Crit, armor and spell-damage bonuses remain active.",
			"The Character page keeps only the live HP and class-resource derivations beside the model and equipment.",
		}, "\n\n")
		return sfinv.make_formspec(player, context,
			"textarea[0.2,0.25;10.0,6.5;;;" .. esc(text) .. "]", true)
	end,
})

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
		table.insert(fs, ("list[current_player;%s;%.1f,0.35;1,1;]"):format(
			grug_inventory.bag_list(i), x))
		local marker = (i == selected) and "> Bag " .. i or "Bag " .. i
		table.insert(fs, ("button[%.1f,1.35;1.5,0.7;grug_open_%d;%s]"):format(
			x - 0.25, i, esc(marker)))
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
