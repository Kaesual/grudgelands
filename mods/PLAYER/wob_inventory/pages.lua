-- sfinv pages: Character (new homepage) and Bags. sfinv uses legacy
-- formspec coordinates; the content area spans roughly y 0.3–5.0.

local function esc(text)
	return core.formspec_escape(text)
end

--
-- Character page
--

local function character_content(player)
	local props = player:get_properties()
	local class = wob_classes.get_class_def(player)
	local race = wob_classes.get_race_def(player)
	local faction = wob_factions.get_faction_def(player)
	local attrs = wob_classes.get_attributes(player)
	local level = wob_xp.get_level(player)

	local mana = wob_classes.get_max_mana(player)
	local resource = class and class.resource == "rage"
		and "Rage (in combat)" or ("Mana " .. mana)

	local lines = {
		player:get_player_name() .. " — Level " .. level ..
			(class and (" " .. class.name) or ""),
		(race and race.name or "No race") .. ", " ..
			(faction and faction.name or "no faction"),
		("Str %d   Int %d   Dex %d"):format(attrs.str, attrs.int, attrs.dex),
		("HP %d / %d   %s"):format(player:get_hp(),
			wob_classes.get_max_hp(player), resource),
		("Melee bonus +%d   Spell power +%d"):format(
			wob_classes.get_melee_bonus(player),
			wob_classes.get_spell_power_bonus(player)),
		("Crit %.1f%%   Dodge %.1f%%"):format(
			wob_classes.get_crit_chance(player) * 100,
			wob_classes.get_dodge_chance(player) * 100),
	}

	local fs = {
		("model[0,0.4;2.4,4.4;wob_preview;%s;%s;0,160]"):format(
			esc(props.mesh or "character.b3d"),
			esc(table.concat(props.textures or {"character.png"}, ","))),
	}
	for i, line in ipairs(lines) do
		table.insert(fs, ("label[2.7,%.2f;%s]"):format(0.35 + i * 0.45, esc(line)))
	end

	table.insert(fs, "label[6.3,0.1;" .. esc("Equipment") .. "]")
	local armor_slots = {"wob_head", "wob_chest", "wob_legs", "wob_feet"}
	for i, list in ipairs(armor_slots) do
		table.insert(fs, ("list[current_player;%s;6,%.1f;1,1;]"):format(list, i - 0.4))
	end
	table.insert(fs, "list[current_player;wob_offhand;7,0.6;1,1;]")
	table.insert(fs, "list[current_player;wob_trinket1;7,1.6;1,1;]")
	table.insert(fs, "list[current_player;wob_trinket2;7,2.6;1,1;]")
	return table.concat(fs)
end

sfinv.register_page("wob_inventory:character", {
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
	local selected = context.wob_bag or 1
	local fs = {}
	for i = 1, wob_inventory.BAG_COUNT do
		local x = (i - 1) * 2 + 0.3
		table.insert(fs, ("list[current_player;%s;%.1f,0.35;1,1;]"):format(
			wob_inventory.bag_list(i), x))
		local marker = (i == selected) and "> Bag " .. i or "Bag " .. i
		table.insert(fs, ("button[%.1f,1.35;1.5,0.7;wob_open_%d;%s]"):format(
			x - 0.25, i, esc(marker)))
	end

	local bag = inv:get_stack(wob_inventory.bag_list(selected), 1)
	local slots = wob_inventory.bag_slots_of(bag)
	if slots > 0 then
		table.insert(fs, ("label[0,2.05;%s]"):format(
			esc(("Bag %d — %s"):format(selected, bag:get_description()))))
		table.insert(fs, ("list[current_player;%s;0,2.35;8,3;]"):format(
			wob_inventory.content_list(selected)))
		table.insert(fs, ("listring[current_player;%s]listring[current_player;main]")
			:format(wob_inventory.content_list(selected)))
	else
		table.insert(fs, ("label[0,2.35;%s]"):format(
			esc(("Bag %d is empty — put a bag into the slot above."):format(selected))))
	end
	return table.concat(fs)
end

sfinv.register_page("wob_inventory:bags", {
	title = "Bags",
	get = function(self, player, context)
		context.wob_bag = context.wob_bag or 1
		return sfinv.make_formspec(player, context,
			bags_content(player, context), true)
	end,
	on_player_receive_fields = function(self, player, context, fields)
		for i = 1, wob_inventory.BAG_COUNT do
			if fields["wob_open_" .. i] then
				context.wob_bag = i
				sfinv.set_page(player, "wob_inventory:bags")
				return true
			end
		end
	end,
})

--
-- Homepage & nav order: Character first, Bags second, Crafting after.
--

function sfinv.get_homepage_name(player)
	return "wob_inventory:character"
end

local nav_order = {"wob_inventory:character", "wob_inventory:bags", "sfinv:crafting"}
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

function wob_inventory.refresh(player)
	local context = sfinv.get_or_create_context(player)
	if context.page == "wob_inventory:character" or
			context.page == "wob_inventory:bags" then
		sfinv.set_page(player, context.page)
	end
end

wob_xp.register_on_level_change(function(player, old_level, new_level)
	if old_level ~= nil then
		wob_inventory.refresh(player)
	end
end)
