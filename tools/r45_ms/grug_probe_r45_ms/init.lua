-- Disposable engine probe (Round 45 lane MS: the migration step 0.45.0 end to
-- end). Never shipped: tools/r45_ms/e2e.py stages it through
-- tools/luanti_headless.sh, under the 0.44.0 game for the setup boot and
-- under this checkout's game after the tool. It asserts nothing: it writes
-- what the game saw to <world>/r43_it_obs.json (Round 43 IT's file names:
-- e2e.py boots through tools/r43_it/it.py) and e2e.py checks it.
--   at load       grug_core.world_version's decision and the registrations
--                 the step's frozen tables concern: every item with an item
--                 level (its _grug_ilvl, _grug_req_level and whether it is
--                 equipment), the mixtures, the bags and their sizes, and the
--                 aliases pointing at any of them;
--   each join     first of all join callbacks (before grug_core's migration
--                 runner): the inventory as loaded; in a "setup" phase
--                 (0.44.0) the character is then built (below); 2.5 s after
--                 the join the inventory as the game left it with every
--                 gear stack's item level, requirement, damage and tooltip,
--                 the equipped armour, whether each equipped piece is
--                 wearable, the character's level and every item dropped
--                 since the join (core.add_item);
--   then          once every character the plan names has left again, it
--                 writes the file and shuts the server down.
-- The plan: <world>/r43_it_plan.json {"phase": "...", "joins": [names]}.
--
-- The setup (0.44.0), one character per join; every placed stack is listed
-- in the observation's `layout` with its role, and e2e.py holds what the
-- step and the join must make of it:
--   smith    a level-10 warrior: unmodified, crafted and rolled gear of
--            several tiers equipped, in main and in a bag, a broken
--            unmodified first-tier bow, mixtures in main, a bag and the
--            craft grid, and a craft grid of which two stacks fit into the
--            two slots the mixtures free and six do not (one merges at the
--            join, four fill the output area, one drops at the feet);
--   scribe   level 1 without a class: an unmodified sword equipped, a
--            trinket in main, a helm left in the shift-click slot, a mixture
--            on the potion belt, a craft grid that fits;
--   sleeper  joins only for the setup (offline afterwards): unmodified gear,
--            a mixture, one craft stack.

local P = "[r45_ms_probe] "
local world = core.get_worldpath()
local wv = grug_core.world_version

local function log(msg) core.log("action", P .. msg) end

local function read(path)
	local f = io.open(path, "r")
	if not f then return nil end
	local text = f:read("*a")
	f:close()
	return text
end

local plan = core.parse_json(read(world .. "/r43_it_plan.json") or "") or {}
local expected = plan.joins or {}
local phase = plan.phase or "?"
local setup = phase:match("^setup") ~= nil

local obs = {
	phase = phase,
	load = {new_world = wv.new_world, from = wv.from, game = wv.game, steps = {}},
	joins = {},
	leaves = 0,
}
for i, step in ipairs(wv.steps) do
	obs.load.steps[i] = step.version
end

local function sorted(set)
	local out = {}
	for name in pairs(set) do out[#out + 1] = name end
	table.sort(out)
	return out
end

-- Every item dropped since the server started, by core.add_item.
local drops = {}
local real_add_item = core.add_item
core.add_item = function(pos, item)
	drops[#drops + 1] = {item = ItemStack(item):to_string(),
		pos = pos and {x = pos.x, y = pos.y, z = pos.z}}
	return real_add_item(pos, item)
end

local function caps_damage(caps)
	return type(caps) == "table" and type(caps.damage_groups) == "table" and
		caps.damage_groups.fleshy or nil
end

-- The facts of one gear stack the checks read.
local function gear_facts(stack)
	if stack:is_empty() or not core.registered_items[stack:get_name()] then return nil end
	local def = stack:get_definition()
	if not def._grug_ilvl and stack:get_meta():get_int("grug_ilvl") <= 0 then return nil end
	local meta = stack:get_meta()
	local req = meta:get_int("grug_req_level")
	return {
		ilvl = grug_items.effective_ilvl(stack),
		req = req > 0 and req or def._grug_req_level,
		damage = caps_damage(stack:get_tool_capabilities()),
		repair_damage = caps_damage(core.deserialize(meta:get_string("_grug_repair_caps"))),
		wear = stack:get_wear(),
		description = meta:get_string("description"),
	}
end

local function inventory(player, details)
	local out = {}
	for listname, list in pairs(player:get_inventory():get_lists()) do
		local stacks, facts = {}, {}
		for i, stack in ipairs(list) do
			stacks[i] = stack:to_string()
			if details then facts[tostring(i)] = gear_facts(stack) end
		end
		out[listname] = {size = #list, stacks = stacks, gear = details and facts or nil}
	end
	return out
end

local function equipment(player)
	local out = {}
	for _, slot in ipairs(grug_inventory.equipment_slots) do
		local stack = player:get_inventory():get_stack(slot.list, 1)
		if not stack:is_empty() then
			out[slot.list] = {item = stack:get_name(),
				wearable = grug_core.can_use_item_level(player, stack) == true,
				fresh_wearable = grug_core.can_use_item_level(player,
					ItemStack(stack:get_name())) == true}
		end
	end
	return out
end

local function state(player)
	return {
		inventory = inventory(player, true),
		equipment = equipment(player),
		armor = grug_inventory.get_equipped_armor(player),
		level = grug_xp.get_level(player),
		meta_seen = player:get_meta():get_string("grug_jobs:seen_items"),
		marker = player:get_meta():get_string("grug_core:migrate:0.45.0"),
	}
end

-- The 0.44.0 character build (a "setup" phase).
local function must(name)
	assert(core.registered_items[name], P .. "not registered: " .. name)
	return name
end

local function place(player, entries, listname, index, stack, role, note)
	stack = ItemStack(stack)
	if stack:is_empty() then error(P .. "no stack for " .. listname .. "[" .. index .. "]") end
	must(stack:get_name())
	player:get_inventory():set_stack(listname, index, stack)
	entries[#entries + 1] = {list = listname, slot = index, item = stack:to_string(),
		role = role, note = note}
end

-- As an acquisition through the 0.44.0 give helper leaves it: the tooltip
-- written, no item level of its own.
local function acquired(player, name)
	local stack = ItemStack(must(name))
	grug_gear.initialize_weapon_tooltip(stack, player)
	return stack
end

local function crafted(player, name)
	local stack = ItemStack(must(name))
	assert(grug_items.crafted_output(stack, player), P .. "crafted_output " .. name)
	return stack
end

local function rolled(name, ilvl, count, seed)
	local stack = ItemStack(must(name))
	assert(grug_items.roll_enchants(stack, ilvl, count, seed), P .. "roll " .. name)
	return stack
end

-- Broken as grug_repair's use leaves it (runtime.lua disable_broken_operation):
-- the usable capabilities kept for the repair, zero capabilities on the stack.
local function broken(player, name)
	local stack = acquired(player, name)
	stack:set_wear(65535)
	local meta = stack:get_meta()
	meta:set_string("_grug_repair_caps", core.serialize(stack:get_tool_capabilities()))
	meta:set_tool_capabilities({full_punch_interval = 1.4,
		damage_groups = {fleshy = 0}, groupcaps = {}, punch_attack_uses = 0})
	return stack
end

local MIX = "grug_alchemy:mixture_"

-- Every list emptied first (sizes kept): the starter kit and whatever the
-- join handed out are not part of the scenario.
local function clear(player)
	local inv = player:get_inventory()
	for name in pairs(inv:get_lists()) do inv:set_list(name, {}) end
	return inv
end

local function fill(player, entries, listname, from, to)
	for index = from, to do
		place(player, entries, listname, index, "default:dirt 99", "plain")
	end
end

local function build_smith(player)
	local factions = sorted(grug_core.factions)
	local faction = factions[1]
	local races = {}
	for id, def in pairs(grug_classes.registered_races) do
		if def.faction == faction then races[id] = true end
	end
	assert(grug_factions.set_faction(player, faction), "set_faction")
	assert(grug_classes.set_race(player, sorted(races)[1]), "set_race")
	assert(grug_classes.set_class(player, "warrior"), "set_class")
	grug_xp.set_xp(player, grug_xp.xp_for_level(10))
	player:get_meta():set_string("grug_jobs:seen_items", core.serialize({"default:dirt"}))
	local inv = clear(player)
	local e = {}
	place(player, e, "main", 1, "default:torch 10", "plain", "the leftover torch merges here")
	fill(player, e, "main", 2, 8)
	place(player, e, "main", 9, ItemStack("grug_gear:dagger_silversteel"), "pin",
		"no meta at all")
	place(player, e, "main", 10, crafted(player, "grug_gear:staff_iron"), "modified")
	place(player, e, "main", 11, rolled("grug_gear:sword_bronze", 7, 1, 11), "modified")
	place(player, e, "main", 12, broken(player, "grug_gear:bow_bronze"), "pin")
	place(player, e, "main", 13, MIX .. "potion_healing_t1 3", "mixture")
	place(player, e, "main", 14, acquired(player, "grug_gear:spellbook_embersteel"), "pin")
	fill(player, e, "main", 15, 32)
	place(player, e, grug_inventory.bag_list(1), 1, "grug_inventory:bag_small", "plain")
	local bag = grug_inventory.content_list(1)
	inv:set_size(bag, 8)
	place(player, e, bag, 1, acquired(player, "grug_gear:chest_cloth_silk"), "pin")
	place(player, e, bag, 2, MIX .. "elixir_focus_t3", "mixture")
	fill(player, e, bag, 3, 8)
	place(player, e, "grug_weapon", 1, acquired(player, "grug_gear:sword_bronze"), "pin")
	place(player, e, "grug_chest", 1, acquired(player, "grug_gear:chest_metal_iron"), "pin")
	place(player, e, "grug_feet", 1, acquired(player, "grug_gear:feet_metal_bronze"), "pin")
	place(player, e, "grug_legs", 1, crafted(player, "grug_gear:legs_leather_cured"), "modified")
	place(player, e, "grug_offhand", 1, acquired(player, "grug_gear:shield_bronze"), "pin")
	place(player, e, "grug_trinket1", 1, acquired(player, "grug_gear:manawell_t2"), "pin")
	place(player, e, "grug_trinket2", 1, rolled("grug_gear:battlebeat_t1", 3, 1, 5), "modified")
	place(player, e, "craft", 1, MIX .. "elixir_vigor_t2", "mixture")
	place(player, e, "craft", 2, acquired(player, "grug_gear:greataxe_bronze"), "craft")
	place(player, e, "craft", 3, "default:cobble 4", "craft")
	place(player, e, "craft", 4, "default:torch 3", "craft")
	place(player, e, "craft", 5, "default:stick 6", "craft")
	place(player, e, "craft", 6, "default:paper 2", "craft")
	place(player, e, "craft", 7, "default:book", "craft")
	place(player, e, "craft", 8, "default:coal_lump 5", "craft")
	place(player, e, "craft", 9, "default:clay_lump 3", "craft")
	grug_inventory.equipment_changed(player)
	return {class = grug_classes.get_class(player), entries = e}
end

local function build_scribe(player)
	clear(player)
	local e = {}
	place(player, e, "main", 1, "default:apple 2", "plain")
	place(player, e, "main", 9, acquired(player, "grug_gear:mercy_seal_t6"), "pin")
	place(player, e, "grug_weapon", 1, ItemStack("grug_gear:sword_bronze"), "pin")
	place(player, e, grug_inventory.POTION_BELT, 1, MIX .. "potion_mana_t2", "mixture")
	place(player, e, grug_inventory.SHIFT_LIST, 1, acquired(player,
		"grug_gear:head_metal_steel"), "pin", "handed back at the join")
	place(player, e, "craft", 1, MIX .. "potion_cave", "mixture")
	place(player, e, "craft", 2, acquired(player, "grug_gear:bow_iron"), "craft")
	place(player, e, "craft", 3, "default:apple 3", "craft")
	grug_inventory.equipment_changed(player)
	return {class = grug_classes.get_class(player) or "", entries = e}
end

local function build_sleeper(player)
	clear(player)
	player:get_meta():set_string("grug_jobs:seen_items", core.serialize({"default:apple"}))
	local e = {}
	place(player, e, "grug_weapon", 1, acquired(player, "grug_gear:wand_steel"), "pin")
	place(player, e, "main", 9, acquired(player, "grug_gear:legs_cloth_stormweave"), "pin")
	place(player, e, "main", 10, MIX .. "potion_antivenom 2", "mixture")
	place(player, e, "craft", 5, "default:apple", "craft")
	grug_inventory.equipment_changed(player)
	return {entries = e}
end

local BUILD = {smith = build_smith, scribe = build_scribe, sleeper = build_sleeper}

local function on_join(player)
	local name = player:get_player_name()
	local entry = {name = name, loaded = inventory(player, false),
		loaded_meta_marker = player:get_meta():get_string("grug_core:migrate:0.45.0")}
	obs.joins[#obs.joins + 1] = entry
	local drops_before = #drops
	log("joined " .. name)
	if setup and BUILD[name] then
		core.after(0.5, function()
			local current = core.get_player_by_name(name)
			if not current then return end
			local ok, result = pcall(BUILD[name], current)
			entry.layout = ok and result or {error = tostring(result)}
			log("built " .. name .. (ok and "" or (": " .. tostring(result))))
			if ok then
				core.after(0.5, function()
					local again = core.get_player_by_name(name)
					if again then entry.built = state(again) end
				end)
			end
		end)
	end
	core.after(2.5, function()
		local current = core.get_player_by_name(name)
		if not current then return end
		entry.settled = state(current)
		entry.drops = {}
		for index = drops_before + 1, #drops do entry.drops[#entry.drops + 1] = drops[index] end
	end)
end
-- First of all join callbacks, before grug_core's migration runner (a
-- registered entry is moved as registered; see world_version.lua).
local joins = core.registered_on_joinplayers
local count = #joins
core.register_on_joinplayer(on_join)
assert(#joins == count + 1)

core.register_on_mods_loaded(function()
	table.insert(joins, 1, table.remove(joins, count + 1))
	local leveled, mixtures, bags = {}, {}, {}
	for name, def in pairs(core.registered_items) do
		if def._grug_ilvl or def._grug_req_level then
			local equip = false
			for group, value in pairs(def.groups or {}) do
				if group:sub(1, 11) == "grug_equip_" and value > 0 then equip = true end
			end
			leveled[name] = {ilvl = def._grug_ilvl, req = def._grug_req_level, equip = equip}
		end
		if name:sub(1, #MIX) == MIX or core.get_item_group(name, "grug_potion_mixture") > 0 then
			mixtures[name] = true
		end
		local slots = core.get_item_group(name, "bagslots")
		if slots > 0 then bags[name] = slots end
	end
	local unleveled_equipment = {}
	for name, def in pairs(core.registered_items) do
		for group, value in pairs(def.groups or {}) do
			if group:sub(1, 11) == "grug_equip_" and value > 0 and not leveled[name] then
				unleveled_equipment[name] = true
			end
		end
	end
	local aliases = {}
	for alias, target in pairs(core.registered_aliases) do
		if (leveled[target] and leveled[target].equip) or mixtures[target] or bags[target] or
				alias:sub(1, #MIX) == MIX then
			aliases[alias] = target
		end
	end
	obs.registrations = {leveled = leveled, mixtures = sorted(mixtures), bags = bags,
		unleveled_equipment = sorted(unleveled_equipment), aliases = aliases,
		hotbar_size = grug_inventory.HOTBAR_SIZE, bag_count = grug_inventory.BAG_COUNT,
		shift_list = grug_inventory.SHIFT_LIST}
end)

local finished = false
local function finish(reason)
	if finished then return end
	finished = true
	obs.finish = reason
	obs.drops = drops
	assert(core.safe_file_write(world .. "/r43_it_obs.json", core.write_json(obs)))
	log("observations written: " .. reason)
	core.after(0.5, function() core.request_shutdown("r45 ms probe done") end)
end

core.register_on_leaveplayer(function(player)
	obs.leaves = obs.leaves + 1
	log("left " .. player:get_player_name())
	if obs.leaves >= #expected then
		core.after(1, finish, "every planned character left")
	end
end)

core.after(0, function()
	if #expected == 0 then
		core.after(3, finish, "no joins planned")
	end
	core.after(150, finish, "timeout: not every planned character joined and left")
end)
