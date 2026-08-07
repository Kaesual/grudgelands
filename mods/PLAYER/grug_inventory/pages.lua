-- sfinv pages: Character (new homepage) and Bags. sfinv uses legacy
-- formspec coordinates; the content area spans roughly y 0.3–5.0.

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
-- (grug_inventory additionally rebuilds the formspec from its own join
-- callback at the end of this file, which closes the race for real.)
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

local function character_content(player)
	local class = grug_classes.get_class_def(player)
	local race = grug_classes.get_race_def(player)
	local faction = grug_factions.get_faction_def(player)
	local attrs = grug_classes.get_attributes(player)
	local level = grug_xp.get_level(player)

	local mana = grug_classes.get_max_mana(player)
	local resource = class and class.resource == "rage"
		and "Rage (in combat)" or ("Mana " .. mana)

	local lines = {
		player:get_player_name() .. " — Level " .. level ..
			(class and (" " .. class.name) or ""),
		(race and race.name or "No race") .. ", " ..
			(faction and faction.name or "no faction"),
		("Str %d   Int %d   Dex %d"):format(attrs.str, attrs.int, attrs.dex),
		("HP %d / %d   %s"):format(player:get_hp(),
			grug_classes.get_max_hp(player), resource),
		("Melee bonus +%d   Spell power +%d"):format(
			grug_classes.get_melee_bonus(player),
			grug_classes.get_spell_power_bonus(player)),
		("Crit %.1f%%   Dodge %.1f%%"):format(
			grug_classes.get_crit_chance(player) * 100,
			grug_classes.get_dodge_chance(player) * 100),
	}

	local mesh, textures = preview_model(player)
	local fs = {
		("model[0,0.4;2.4,4.4;grug_preview;%s;%s;0,160]"):format(
			esc(mesh), esc_texture_list(textures)),
	}
	for i, line in ipairs(lines) do
		table.insert(fs, ("label[2.7,%.2f;%s]"):format(0.35 + i * 0.45, esc(line)))
	end

	table.insert(fs, "label[6.3,0.1;" .. esc("Equipment") .. "]")
	local armor_slots = {"grug_head", "grug_chest", "grug_legs", "grug_feet"}
	for i, list in ipairs(armor_slots) do
		table.insert(fs, ("list[current_player;%s;6,%.1f;1,1;]"):format(list, i - 0.4))
	end
	table.insert(fs, "list[current_player;grug_offhand;7,0.6;1,1;]")
	table.insert(fs, "list[current_player;grug_trinket1;7,1.6;1,1;]")
	table.insert(fs, "list[current_player;grug_trinket2;7,2.6;1,1;]")
	return table.concat(fs)
end

sfinv.register_page("grug_inventory:character", {
	title = "Character",
	get = function(self, player, context)
		return sfinv.make_formspec(player, context,
			character_content(player), true)
	end,
})

--
-- Bags page
--

local function bags_content(player, context)
	local inv = player:get_inventory()
	local selected = context.grug_bag or 1
	local fs = {}
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

local nav_order = {"grug_inventory:character", "grug_inventory:bags", "sfinv:crafting"}
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

function grug_inventory.refresh(player)
	local context = sfinv.get_or_create_context(player)
	if context.page == "grug_inventory:character" or
			context.page == "grug_inventory:bags" then
		sfinv.set_page(player, context.page)
	end
end

grug_xp.register_on_level_change(function(player, old_level, new_level)
	if old_level ~= nil then
		grug_inventory.refresh(player)
	end
end)

-- Rebuild the inventory formspec once more on join. sfinv already built one
-- from its own join callback, but sfinv and player_api are dependency-free
-- BASE mods whose callback order is undefined, so that first build may have
-- captured the engine's default player appearance (see preview_model above).
-- grug_inventory depends on BOTH (mod.conf), and this file is dofile'd last,
-- so this callback is guaranteed to run after player_api applied the model
-- and after equipment.lua/bags.lua sized their inventory lists.
-- Cheap: exactly one extra formspec build per join, no repeated work.
core.register_on_joinplayer(function(player)
	if sfinv.enabled then
		sfinv.set_player_inventory_formspec(player)
	end
end)
