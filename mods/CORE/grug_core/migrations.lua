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

grug_core.migrations = {
	-- The declaration's `migrate` list, ascending: the guard refuses a world
	-- whose record lies before one of them. tools/check_upgrade.py proves this
	-- list equal to tools/web_data/upgrade.json's `migrate` list.
	versions = {
		"0.44.0", -- mount items and skills outside the hotbar removed; offline only
		"0.45.0", -- mixtures deleted, craft grid emptied, item level pinned; a join part
	},
	-- Online work, only for a step that leaves some:
	--   handlers["x.y.z"] = {
	--     world = function(marker) end,             -- marker: the stored value
	--     character = function(player, marker) end,
	--   }
	handlers = {
		["0.45.0"] = {character = character_0_45_0},
	},
}
