-- The game's migration steps (Round 43; the hosting platform's migration
-- contract, docs/technical/upgrade-contract.md). A step converts a stopped
-- world of the previous version offline: the tool `python3 tools/migrate.py
-- --world <dir>` runs its file `tools/migration/steps/v<major>_<minor>_<patch>.py`.
-- A step that leaves online work writes markers, and the game finishes them
-- (grug_core/world_version.lua):
--   the world part:    mod storage of grug_core, key "migrate_world:<version>",
--                      at the next load, once every mod has loaded (so after
--                      every map-reset clear);
--   a character part:  player meta "grug_core:migrate:<version>", at that
--                      character's next join, before any other join callback.
-- Pending markers run in step order; each is deleted only after its handler
-- succeeded. A failing world handler stops the load; a failing character
-- handler disconnects that character with the marker kept, so the next load or
-- join runs the handler again: a handler must be safe to run again over what
-- the failed attempt and the game's own load or join left.
--
-- This file lives in the runtime tree, which a managed server keeps without
-- tools/ (the start guard cannot read tools/web_data/upgrade.json there).
-- The handlers sit above the registry, one section per step.

--
-- 0.45.0, the character part. The online part of the migration step 0.45.0 (Round 45, the crafting
-- rework; tools/migration/steps/v0_45_0.py, docs/technical/upgrade-contract.md
-- §5.8). The offline step deleted the mixtures, moved the engine craft grid
-- into empty inventory slots and pinned the 0.44.0 item level on unmodified
-- gear; at the character's next join, before every other join callback
-- (grug_core/world_version.lua), this handler
--   1. hands over what the craft grid and the engine's craftresult list still
--      hold (round45-plan.md ruling 6): the give helper, then the crafting
--      output area, then the character's feet; the grid shrinks at the same
--      join (grug_jobs/craft_list.lua), craftresult stays empty;
--   2. rewrites the tool capabilities of every weapon whose damage no longer
--      matches its item level: an unmodified first-tier weapon read its
--      damage from the definition, which the item level ladder lowered, and
--      the pinned level alone does not restore it (a broken one keeps them
--      for the repair);
--   3. rebuilds the tooltips of the character's gear in every list.
-- It does not notify the equipment change itself: grug_inventory's own join
-- callback drops the equipment caches and notifies right after this one
-- (equipment.lua), when every consumer's join setup has run.
-- Safe to run again: a stack leaves the grid only once it is placed, and the
-- refresh and the rebuild write only what differs.
-- The mods it calls load after grug_core; their APIs are looked up at the
-- join.

local CRAFT_LISTS = {"craft", "craftresult"}
local OUTPUT = "grug_craft_out"
local BROKEN = 65535

local function hand_over(player, inv, list)
	for index = 1, inv:get_size(list) do
		local stack = inv:get_stack(list, index)
		if not stack:is_empty() then
			-- After each placement the list keeps exactly what is left.
			stack = grug_inventory.give(player, stack)
			inv:set_stack(list, index, stack)
			if not stack:is_empty() then
				grug_jobs.ensure_output_area(player)
				stack = inv:add_item(OUTPUT, stack)
				inv:set_stack(list, index, stack)
			end
			if not stack:is_empty() then
				assert(core.add_item(player:get_pos(), stack),
					"no room for " .. stack:to_string() .. " and it could not be dropped")
				inv:set_stack(list, index, ItemStack(""))
			end
		end
	end
end

-- The damage a weapon stack deals now: its own capabilities, or for a broken
-- stack those kept for the repair.
local function current_damage(stack)
	local caps
	if stack:get_wear() >= BROKEN then
		caps = core.deserialize(stack:get_meta():get_string("_grug_repair_caps"))
	else
		caps = stack:get_tool_capabilities()
	end
	return type(caps) == "table" and type(caps.damage_groups) == "table" and
		caps.damage_groups.fleshy or nil
end

local function refresh_capabilities(stack)
	if core.get_item_group(stack:get_name(), "grug_equip_weapon") <= 0 then return false end
	local _, described = grug_gear.describe_stack_base(stack, grug_items.effective_ilvl(stack))
	local damage = described and described.damage
	if type(damage) ~= "number" or damage == current_damage(stack) then return false end
	grug_items.refresh_capabilities(stack)
	return true
end

local function character_0_45_0(player)
	local inv = player:get_inventory()
	for _, list in ipairs(CRAFT_LISTS) do
		if inv:get_size(list) > 0 and not inv:is_empty(list) then
			hand_over(player, inv, list)
		end
	end
	for listname, stacks in pairs(inv:get_lists()) do
		for index, stack in ipairs(stacks) do
			local family = not stack:is_empty() and grug_items.family_for(stack)
			if family and family ~= "tool" then
				local changed = refresh_capabilities(stack)
				changed = grug_items.regenerate_description(stack, player) or changed
				if changed then inv:set_stack(listname, index, stack) end
			end
		end
	end
end

--
-- 0.47.0, the character part. The online part of the migration step 0.47.0
-- (Round 47 lane OR; tools/migration/steps/v0_47_0.py, which only sets the
-- marker on every character). Round 47 shifted the pick level scale by one
-- (Iron behind the Bronze pick, plan ruling 7): every pick's definition has
-- a new maxlevel, new times and a new `grug_pick_level` capability. A
-- crafted gathering tool carries a copy of its definition's capabilities in
-- its item meta (grug_quality `crafted_output`), a broken one the copy kept
-- for the repair (`_grug_repair_caps`, also written by grug_repair when a
-- plain tool breaks); those copies still hold the old scale, so an old Iron
-- pick could not dig T2 rock any more. At the character's next join, before
-- every other join callback, this handler rebuilds them from the current
-- definition (`grug_items.refresh_capabilities`, the craft path's own
-- rebuild) for every tool stack (grug_quality family "tool": picks, axes,
-- shovels, hoes) that carries either copy, in every list of the player's
-- inventory: main with the hotbar, the bags' content lists, the crafting
-- output area and every other list. A tool without a copy already reads its
-- definition and is not touched. Safe to run again: a rebuild over a rebuilt
-- stack writes the same values, and a stack is written back only when a copy
-- changed.

local function character_0_47_0(player)
	local inv = player:get_inventory()
	for listname, stacks in pairs(inv:get_lists()) do
		for index, stack in ipairs(stacks) do
			if not stack:is_empty() and grug_items.family_for(stack) == "tool" then
				local meta = stack:get_meta()
				local caps = meta:get_string("tool_capabilities")
				local kept = meta:get_string("_grug_repair_caps")
				if caps ~= "" or kept ~= "" then
					grug_items.refresh_capabilities(stack)
					if meta:get_string("tool_capabilities") ~= caps or
							meta:get_string("_grug_repair_caps") ~= kept then
						inv:set_stack(listname, index, stack)
					end
				end
			end
		end
	end
end

--
-- 0.48.0, the character part. The online part of the migration step 0.48.0
-- (Round 48 lane BAGS; tools/migration/steps/v0_48_0.py, which only sets
-- the marker on every character; sell-fuel-daytime-plan.md §3.7). Every bag
-- holds half as much (4 / 8 / 12 / 16 slots instead of 8 / 16 / 24 / 32),
-- and the bags' join callback sizes each content list from its bag, so at
-- the character's next join, before every other join callback, this
-- handler
--   1. sorts main[9..] and the bags into the new sizes through the one
--      sort path (grug_inventory.sort with target sizes); the hotbar is not
--      touched; soulbound and bound items keep a cell; the sort leaves what
--      does not fit (the end of its order) in the cells beyond the new
--      sizes;
--   2. sends those leftovers as "npc" letters from "Lost and Found", four
--      stacks each (grug_mail.send_system with stacks, round48-plan.md
--      §3.2); a stack leaves its cell only once its letter is sent;
--   3. shrinks the content lists, now empty beyond the new sizes;
--   4. once the join has finished and letters were sent, one feed line.
-- A character without bags only loses the marker. Safe to run again: a
-- failed send raises with the unsent stacks still beyond the new sizes,
-- which the bags' join callback then keeps (grug_inventory/bags.lua); the
-- next join sorts again and sends only what is still there. The marker
-- goes only when every leftover is in a letter. grug_inventory and grug_mail
-- load after grug_core; their APIs are looked up at the join.

local LETTER_STACKS = 4
local LOST_AND_FOUND = {
	kind = "npc",
	from = "Lost and Found",
	subject = "Your bags got smaller",
	body = "Bags in the realm now hold half as much as before. Everything still fit " ..
		"where it could; the items that no longer did are attached to this letter.\n\n" ..
		"Make room in your bags, then use Take all to collect them. Like every " ..
		"letter, this one is deleted 30 days after it arrived, attachments too.",
}

local function character_0_48_0(player)
	local inv = player:get_inventory()
	local sizes, bags = {}, false
	for i = 1, grug_inventory.BAG_COUNT do
		local list = grug_inventory.content_list(i)
		local size = grug_inventory.bag_slots_of(inv:get_stack(grug_inventory.bag_list(i), 1))
		sizes[list] = size
		bags = bags or size > 0 or inv:get_size(list) > 0
	end
	if not bags then return end
	local _, leftovers = grug_inventory.sort(player, sizes)
	local name = player:get_player_name()
	local mail = rawget(_G, "grug_mail")
	if #leftovers > 0 and not (mail and mail.send_system) then
		error("grug_mail.send_system is missing; " .. #leftovers .. " stacks wait", 0)
	end
	local letters = 0
	for first = 1, #leftovers, LETTER_STACKS do
		local cells, stacks = {}, {}
		for index = first, math.min(first + LETTER_STACKS - 1, #leftovers) do
			cells[#cells + 1] = leftovers[index]
			stacks[#stacks + 1] = leftovers[index].stack:to_string()
		end
		local sent, err = mail.send_system(name, LOST_AND_FOUND.kind,
			LOST_AND_FOUND.from, LOST_AND_FOUND.subject, LOST_AND_FOUND.body, stacks)
		if not sent then
			error(("the letter with %s was not sent: %s"):format(
				table.concat(stacks, ", "), tostring(err)), 0)
		end
		for _, cell in ipairs(cells) do
			inv:set_stack(cell.list, cell.index, ItemStack(""))
		end
		letters = letters + 1
	end
	for list, size in pairs(sizes) do
		if inv:get_size(list) > size then inv:set_size(list, size) end
	end
	if letters > 0 then
		core.log("action", ("[grug_core] migration 0.48.0: %d stacks of %s in %d letters")
			:format(#leftovers, name, letters))
		core.after(0, function()
			local online = core.get_player_by_name(name)
			if online then
				grug_core.feed(online, "notice", ("Your bags got smaller: %d %s from " ..
					"Lost and Found hold%s what no longer fit. Read them at a mailbox.")
					:format(letters, letters == 1 and "letter" or "letters",
						letters == 1 and "s" or ""), "migrate_0_48_0")
			end
		end)
	end
end

grug_core.migrations = {
	-- The declaration's `migrate` list, ascending: the guard refuses a world
	-- whose record lies before one of them. tools/check_upgrade.py proves this
	-- list equal to tools/web_data/upgrade.json's `migrate` list.
	versions = {
		"0.44.0", -- mount items and skills outside the hotbar removed; offline only
		"0.45.0", -- mixtures deleted, craft grid emptied, item level pinned; a join part
		"0.47.0", -- gathering tools' stored capabilities rebuilt; a join part
		"0.48.0", -- bags halved, what no longer fits mailed; a join part
	},
	-- Online work, only for a step that leaves some:
	--   handlers["x.y.z"] = {
	--     world = function(marker) end,             -- marker: the stored value
	--     character = function(player, marker) end,
	--   }
	handlers = {
		["0.45.0"] = {character = character_0_45_0},
		["0.47.0"] = {character = character_0_47_0},
		["0.48.0"] = {character = character_0_48_0},
	},
}
