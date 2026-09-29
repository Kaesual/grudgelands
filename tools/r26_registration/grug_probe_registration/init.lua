-- Round 26 Lane R engine probe (disposable, never shipped).
--
-- On the first server step, with every registration final, asks the live
-- engine registry:
--   * every craft recipe (all registered items and every alias as output):
--     the output and each named input resolve to a registered item, directly
--     or through an alias; each group input has at least one member;
--   * every trader stock and profession-shelf item, every quest item
--     objective and reward, and every registered entity's drops resolve;
--   * the eight mobs_redo utility items are unknown, the silver-sandstone
--     family has no recipe, the twelve old `default:` tool names are aliases
--     of registered `grug_materials:` tools, and every tool with a tier group
--     lives in `grug_materials:`.
-- Logs one line per finding and ends the server itself; "RESULT PASS" is
-- the verdict line.

local TAG = "[r26_registration_probe] "
local function log(message) core.log("action", TAG .. message) end

local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		log("FAIL " .. label)
	end
end

local function resolve(name)
	return core.registered_aliases[name] or name
end
local function known(name)
	name = name:match("^(%S+)") or name
	if name == "" then return true end
	local group = name:match("^group:(.+)$")
	if group then
		-- Group membership (possibly comma-joined): any item in all groups.
		local parts = {}
		for part in group:gmatch("[^,]+") do parts[#parts + 1] = part end
		for _, def in pairs(core.registered_items) do
			local all = true
			for i = 1, #parts do
				if not (def.groups and (def.groups[parts[i]] or 0) ~= 0) then
					all = false
					break
				end
			end
			if all then return true end
		end
		return false
	end
	return rawget(core.registered_items, resolve(name)) ~= nil
end

local function recipe_names(items, out)
	for _, value in pairs(items or {}) do
		if type(value) == "string" then out[#out + 1] = value
		elseif type(value) == "table" then recipe_names(value, out) end
	end
	return out
end

local function audit()
	-- 1. Every craft recipe the engine holds.
	local outputs = {}
	for name in pairs(core.registered_items) do outputs[#outputs + 1] = name end
	for name in pairs(core.registered_aliases) do outputs[#outputs + 1] = name end
	table.sort(outputs)
	local recipes = 0
	for _, output in ipairs(outputs) do
		for _, recipe in ipairs(core.get_all_craft_recipes(output) or {}) do
			recipes = recipes + 1
			local out_name = (recipe.output or output):match("^(%S+)") or output
			check(known(out_name), "recipe output unknown: " .. out_name)
			check(rawget(core.registered_items, out_name) ~= nil,
				"recipe output is an alias, not the canonical name: " .. out_name)
			for _, input in ipairs(recipe_names(recipe.items, {})) do
				check(known(input), "recipe for " .. out_name .. " names unknown " .. input)
				check(not core.registered_aliases[input:match("^(%S+)") or input],
					"recipe for " .. out_name .. " names the alias " .. input)
			end
		end
	end
	log("recipes checked: " .. recipes)

	-- 2. Trades, quests, drops.
	local trades = 0
	for _, row in ipairs(grug_traders.stock or {}) do
		trades = trades + 1
		check(known(row.item), "trader stock names unknown " .. tostring(row.item))
	end
	for kind, shelf in pairs(grug_traders.profession_stock or {}) do
		for _, row in ipairs(shelf) do
			trades = trades + 1
			check(known(row.item), kind .. " shelf names unknown " .. tostring(row.item))
		end
	end
	local quest_items = 0
	for id, quest in pairs(grug_quests.registered_quests or {}) do
		for _, objective in ipairs(quest.objectives or {}) do
			if objective.type == "item" then
				quest_items = quest_items + 1
				check(known(objective.item), id .. " objective names unknown " ..
					tostring(objective.item))
			end
		end
		for _, item in ipairs((quest.rewards or {}).items or {}) do
			quest_items = quest_items + 1
			check(known(ItemStack(item):get_name()), id .. " reward names unknown " ..
				tostring(item))
		end
	end
	local drops = 0
	for name, def in pairs(core.registered_entities) do
		if type(def.drops) == "table" then
			for _, drop in ipairs(def.drops) do
				drops = drops + 1
				check(type(drop.name) == "string" and known(drop.name),
					name .. " drops unknown " .. tostring(drop.name))
			end
		end
	end
	log(("trades %d, quest items %d, entity drops %d"):format(trades, quest_items, drops))

	-- 3. Removed items and the tool namespace.
	for _, name in ipairs(grug_materials.REMOVED_MOBS_UTILITIES) do
		check(not core.registered_items[name], "removed mobs utility registered: " .. name)
		check(not core.get_all_craft_recipes(name), "removed mobs utility has a recipe: " .. name)
	end
	for _, name in ipairs(grug_materials.REMOVED_SILVER_SANDSTONE_OUTPUTS) do
		check(not core.get_all_craft_recipes(name), "silver-sandstone recipe remains: " .. name)
	end
	local aliases = 0
	for old, new in pairs(grug_materials.TOOL_ALIASES) do
		aliases = aliases + 1
		check(rawget(core.registered_items, old) == nil, old .. " still registered")
		check(core.registered_aliases[old] == new and
			rawget(core.registered_tools, new) ~= nil, old .. " -> " .. new)
		check(ItemStack(old):get_name() == new, "ItemStack(" .. old .. ") resolves")
	end
	local tier_tools = 0
	for name, def in pairs(core.registered_tools) do
		local groups = def.groups or {}
		if groups.grug_pick_tier or groups.grug_axe_tier or groups.grug_shovel_tier then
			tier_tools = tier_tools + 1
			check(name:sub(1, 15) == "grug_materials:", "tier tool outside namespace: " .. name)
		end
	end
	log(("aliases %d, tier tools %d"):format(aliases, tier_tools))
	check(aliases == 12 and tier_tools == 24, "12 aliases and 24 tier tools")
end

core.after(0, function()
	local ok, err = pcall(audit)
	check(ok, "audit raised: " .. tostring(err))
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("r26 registration probe done", false, 0)
end)
