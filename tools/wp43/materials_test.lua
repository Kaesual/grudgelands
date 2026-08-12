-- Plain-Lua-5.1 integration regression for WP43.
--
-- The engine surface below models registration and core.node_dig ordering;
-- all material/depth/harvest decisions come from the unchanged production
-- files loaded by grug_materials/init.lua.

local repo = arg[1] or "."

local function copy_table(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in pairs(value) do
		result[copy_table(key)] = copy_table(child)
	end
	return result
end

table.copy = copy_table

local function assert_equal(actual, expected, context)
	if actual ~= expected then
		error((context or "value") .. ": expected " .. tostring(expected) ..
			", got " .. tostring(actual), 2)
	end
end

local function assert_near(actual, expected, context)
	if math.abs(actual - expected) > 0.000000001 then
		error((context or "value") .. ": expected " .. tostring(expected) ..
			", got " .. tostring(actual), 2)
	end
end

local function assert_contains(value, needle, context)
	if not value:find(needle, 1, true) then
		error((context or "text") .. ": missing " .. needle, 2)
	end
end

vector = {}
function vector.copy(pos)
	return {x = pos.x, y = pos.y, z = pos.z}
end

local callbacks = {mods_loaded = {}, dignode = {}}
local world = {}
local metas = {}
local timers = {}
local protected = false
local trace = {}
local counts = {}
local logs = {}
local current_modname = "grug_materials"

local function reset_counts()
	counts = {
		builtin = 0,
		wear = 0,
		drop_calls = 0,
		drop_items = 0,
		protection_checks = 0,
		protection_violations = 0,
		sounds = 0,
		chats = 0,
		set_nodes = 0,
		timers = 0,
		harvest = 0,
		goldsmith = 0,
		xp = 0,
		quest = 0,
	}
	trace = {}
end

reset_counts()

local function pos_key(pos)
	return pos.x .. ":" .. pos.y .. ":" .. pos.z
end

local Stack = {}
Stack.__index = Stack

function ItemStack(name)
	return setmetatable({name = name or "", wear = 0}, Stack)
end

function Stack:is_empty()
	return self.name == ""
end

function Stack:get_name()
	return self.name
end

function Stack:get_definition()
	trace[#trace + 1] = "stack_definition"
	return core.registered_items[self.name] or {}
end

function Stack:add_wear(amount)
	self.wear = self.wear + amount
	counts.wear = counts.wear + 1
end

local function make_digger(stack, creative)
	local digger = {stack = stack or ItemStack(""), creative = creative == true}
	function digger:is_player()
		return true
	end
	function digger:get_player_name()
		return "tester"
	end
	function digger:get_wielded_item()
		return self.stack
	end
	return digger
end

local default_nodes = {
	["default:stone"] = {description = "Stone", is_ground_content = true,
		groups = {cracky = 3, stone = 1, level = 1}, drop = "default:cobble"},
	["default:stone_with_coal"] = {description = "Coal Ore",
		is_ground_content = true, groups = {cracky = 3, level = 1},
		drop = "default:coal_lump"},
	["default:stone_with_copper"] = {description = "Copper Ore",
		is_ground_content = true, groups = {cracky = 3, level = 1},
		drop = "default:copper_lump"},
	["default:stone_with_tin"] = {description = "Tin Ore",
		is_ground_content = true, groups = {cracky = 3, level = 1},
		drop = "default:tin_lump"},
	["default:stone_with_iron"] = {description = "Iron Ore",
		is_ground_content = true, groups = {cracky = 3, level = 1},
		drop = "default:iron_lump"},
	["default:stone_with_gold"] = {description = "Gold Ore",
		is_ground_content = true, groups = {cracky = 3, level = 2},
		drop = "default:gold_lump"},
}

local simple_nodes = {
	"default:obsidian", "default:obsidianbrick", "default:obsidian_block",
	"default:steelblock", "default:copperblock", "default:tinblock",
	"default:bronzeblock", "default:tree", "default:wood",
	"default:pine_tree", "default:pine_wood", "default:acacia_tree",
	"default:acacia_wood", "default:jungletree", "default:junglewood",
	"grug_trees:silverwood_tree", "grug_trees:silverwood_wood",
	"grug_trees:gravewood_tree", "grug_trees:gravewood_wood",
}
for _, name in ipairs(simple_nodes) do
	default_nodes[name] = {description = name, groups = {cracky = 1, level = 3},
		is_ground_content = false, drop = name}
	if name:find("tree", 1, true) or name:find("wood", 1, true) then
		default_nodes[name].groups.level = nil
	end
end

local default_items = {
	"default:cobble", "default:coal_lump", "default:copper_lump",
	"default:tin_lump", "default:iron_lump", "default:gold_lump",
	"default:mese_crystal", "default:mese_crystal_fragment", "default:mese",
	"default:diamond", "default:mese_block", "default:diamondblock",
	"default:stone_with_mese", "default:stone_with_diamond",
	"default:meselamp", "default:mese_post_light",
	"default:mese_post_light_acacia_wood", "default:mese_post_light_junglewood",
	"default:mese_post_light_pine_wood", "default:mese_post_light_aspen_wood",
	"mese", "MesePick", "steel_ingot", "steelblock",
	"default:copper_ingot", "default:tin_ingot", "default:bronze_ingot",
	"default:steel_ingot", "default:gold_ingot", "default:goldblock",
	"default:shovel_steel", "default:axe_steel", "default:sword_steel",
}

local retired_tools = {
	"default:pick_mese", "default:shovel_mese", "default:axe_mese",
	"default:sword_mese", "default:pick_diamond", "default:shovel_diamond",
	"default:axe_diamond", "default:sword_diamond",
}
for _, name in ipairs(retired_tools) do
	default_items[#default_items + 1] = name
end

core = {
	registered_items = {},
	registered_nodes = {},
	registered_aliases = {},
	registered_ores = {},
	LIGHT_MAX = 14,
}

for name, def in pairs(default_nodes) do
	core.registered_nodes[name] = def
	core.registered_items[name] = def
end
for _, name in ipairs(default_items) do
	if not core.registered_items[name] then
		core.registered_items[name] = {description = name, groups = {}}
	end
end

local base_tool_caps = {
	full_punch_interval = 1,
	max_drop_level = 1,
	groupcaps = {cracky = {times = {[1] = 1, [2] = 1, [3] = 1},
		uses = 10, maxlevel = 3}},
	damage_groups = {fleshy = 2},
}
for _, name in ipairs({"default:pick_wood", "default:pick_stone",
		"default:pick_bronze", "default:pick_steel"}) do
	core.registered_items[name] = {description = name, groups = {},
		tool_capabilities = copy_table(base_tool_caps)}
end

default = {LIGHT_MAX = 14}
function default.node_sound_stone_defaults()
	return {}
end
function default.node_sound_metal_defaults()
	return {}
end
function default.node_sound_glass_defaults()
	return {}
end
function default.register_mesepost(name, def)
	def.groups = def.groups or {cracky = 3}
	def.drop = name
	core.register_node(name, def)
end

function core.get_current_modname()
	return current_modname
end

function core.get_modpath(name)
	if name == "grug_materials" then
		return repo .. "/mods/ITEMS/grug_materials"
	elseif name == "grug_nodes" then
		return repo .. "/mods/ITEMS/grug_nodes"
	elseif name == "grug_mapgen" then
		return repo .. "/mods/MAPGEN/grug_mapgen"
	end
	return nil
end

function core.register_node(name, def)
	core.registered_nodes[name] = def
	core.registered_items[name] = def
end

function core.register_craftitem(name, def)
	core.registered_items[name] = def
end

function core.override_item(name, fields)
	local def = assert(core.registered_items[name], "missing override target " .. name)
	for key, value in pairs(fields) do
		def[key] = value
	end
	if core.registered_nodes[name] then
		core.registered_nodes[name] = def
	end
end

function core.register_alias_force(source, target)
	core.registered_aliases[source] = target
	core.registered_items[source] = nil
	core.registered_nodes[source] = nil
end

function core.clear_craft()
	return true
end

function core.register_ore(def)
	core.registered_ores[#core.registered_ores + 1] = def
end

function core.register_on_mods_loaded(callback)
	callbacks.mods_loaded[#callbacks.mods_loaded + 1] = callback
end

function core.register_on_dignode(callback)
	callbacks.dignode[#callbacks.dignode + 1] = callback
end

function core.log(level, message)
	logs[#logs + 1] = level .. ":" .. message
end

function core.is_protected()
	counts.protection_checks = counts.protection_checks + 1
	trace[#trace + 1] = "protection"
	return protected
end

function core.record_protection_violation()
	counts.protection_violations = counts.protection_violations + 1
	trace[#trace + 1] = "protection_violation"
end

function core.sound_play()
	counts.sounds = counts.sounds + 1
end

function core.chat_send_player()
	counts.chats = counts.chats + 1
end

function core.get_node(pos)
	return world[pos_key(pos)] or {name = "air"}
end

function core.set_node(pos, node)
	world[pos_key(pos)] = {name = node.name, param1 = node.param1, param2 = node.param2}
	counts.set_nodes = counts.set_nodes + 1
end

function core.get_meta(pos)
	local key = pos_key(pos)
	local values = metas[key]
	if not values then
		values = {}
		metas[key] = values
	end
	return {
		get_string = function(_, name)
			return values[name] or ""
		end,
		set_string = function(_, name, value)
			values[name] = value
		end,
	}
end

function core.get_node_timer(pos)
	local key = pos_key(pos)
	return {
		start = function(_, delay)
			timers[key] = delay
			counts.timers = counts.timers + 1
		end,
	}
end

function core.handle_node_drops(_, drops)
	counts.drop_calls = counts.drop_calls + 1
	counts.drop_items = counts.drop_items + #drops
end

-- This is the engine primitive captured by mining.lua before it replaces
-- core.node_dig. It preserves the observable order needed by the real
-- ore-respawn integration: drops, wear, removal, dignode callbacks.
function core.node_dig(pos, node, digger)
	counts.builtin = counts.builtin + 1
	trace[#trace + 1] = "builtin"
	if core.is_protected(pos, digger and digger:get_player_name() or "") then
		return false
	end
	local def = core.registered_nodes[node.name] or {}
	local drop = def.drop
	if drop == nil then
		drop = node.name
	end
	local drops = {}
	if drop ~= "" then
		drops[1] = drop
	end
	core.handle_node_drops(pos, drops, digger)
	local stack = digger and digger:get_wielded_item()
	if stack and not stack:is_empty() and not digger.creative then
		stack:add_wear(1)
	end
	world[pos_key(pos)] = {name = "air"}
	for _, callback in ipairs(callbacks.dignode) do
		callback(pos, node, digger)
	end
	return true
end

local function set_world_node(pos, name)
	world[pos_key(pos)] = {name = name, param1 = 0, param2 = 0}
	metas[pos_key(pos)] = nil
	timers[pos_key(pos)] = nil
end

-- Fresh-world load of the complete owner mod, unchanged.
dofile(repo .. "/mods/ITEMS/grug_materials/init.lua")

-- Load the two current external consumers unchanged. The mapgen file also
-- gives ore_respawn's startup coupling audit the real scatter roster.
current_modname = "grug_mapgen"
dofile(repo .. "/mods/MAPGEN/grug_mapgen/ores.lua")
current_modname = "grug_nodes"
dofile(repo .. "/mods/ITEMS/grug_nodes/ore_respawn.lua")
current_modname = "grug_materials"

-- Hidden harness picks exercise pure profiles without registering WP29 gear.
for tier = 1, 6 do
	local name = "wp43_test:pick_" .. tier
	core.registered_items[name] = {
		description = "WP43 test pick " .. tier,
		groups = {grug_pick_tier = tier, not_in_creative_inventory = 1},
		tool_capabilities = grug_materials.build_pick_capabilities(tier),
	}
end

-- Stand-ins represent all future settlement consumers through the one public
-- callback. A shattered resource must invoke none of them.
grug_materials.register_on_harvest(function()
	counts.harvest = counts.harvest + 1
	counts.goldsmith = counts.goldsmith + 1
	counts.xp = counts.xp + 1
	counts.quest = counts.quest + 1
end)

-- Ordered six-tier registry and every inclusive boundary.
assert_equal(#grug_materials.TIERS, 6, "tier count")
local tier_keys = {"bronze", "iron", "steel", "silversteel", "embersteel",
	"abyssal_steel"}
local caps = {-100, -300, -500, -700, -1000, -31000}
local representatives = {-50, -200, -400, -600, -800, -1200}
for tier = 1, 6 do
	assert_equal(grug_materials.TIERS[tier].key, tier_keys[tier],
		"tier key " .. tier)
	assert_equal(grug_materials.max_depth_for_pick_tier(tier), caps[tier],
		"depth cap " .. tier)
	assert_equal(grug_materials.tier_at(caps[tier]), tier,
		"tier at exact cap " .. tier)
	assert_equal(grug_materials.tier_at(caps[tier] + 1), tier,
		"tier above cap " .. tier)
	assert_equal(grug_materials.tier_at(caps[tier] - 1), math.min(6, tier + 1),
		"tier below cap " .. tier)
	local allowed = grug_materials.can_mine_natural_at(tier, caps[tier])
	assert_equal(allowed, true, "inclusive cap " .. tier)
	allowed = grug_materials.can_mine_natural_at(tier, caps[tier] - 1)
	assert_equal(allowed, false, "one below cap " .. tier)
end
assert_equal(grug_materials.tier_at(-700), 4, "-700 boundary")
assert_equal(grug_materials.tier_at(-701), 5, "-701 boundary")

-- Six profiles by six strata through the full mining decision, plus monotonic
-- timing and retired engine-cap fields.
protected = false
for pick_tier = 1, 6 do
	local stack = ItemStack("wp43_test:pick_" .. pick_tier)
	local digger = make_digger(stack)
	local profile_caps = stack:get_definition().tool_capabilities
	assert_equal(profile_caps.max_drop_level, 0,
		"profile max_drop_level " .. pick_tier)
	assert_equal(profile_caps.groupcaps.cracky.maxlevel, 0,
		"profile cracky maxlevel " .. pick_tier)
	assert_equal(profile_caps.groupcaps.grug_resource.maxlevel, 0,
		"profile resource maxlevel " .. pick_tier)
	for stratum = 1, 6 do
		local node_name = grug_materials.TIERS[stratum].node
		local decision = grug_materials.mining_decision(
			{x = pick_tier, y = representatives[stratum], z = stratum},
			{name = node_name}, digger)
		assert_equal(decision.allowed, stratum <= pick_tier,
			"pick " .. pick_tier .. " / stratum " .. stratum)
		if stratum > pick_tier then
			assert_equal(decision.reason, "depth", "depth reason")
		end
	end
	if pick_tier > 1 then
		local current = grug_materials.PICK_PROFILES[pick_tier]
		local previous = grug_materials.PICK_PROFILES[pick_tier - 1]
		assert(current.ordinary_time <= previous.ordinary_time)
		for rating = 1, 3 do
			assert(current.cracky_times[rating] <= previous.cracky_times[rating])
		end
		local current_caps = grug_materials.build_pick_capabilities(pick_tier)
		local previous_caps = grug_materials.build_pick_capabilities(pick_tier - 1)
		for harvest_tier = 1, 5 do
			assert(current_caps.groupcaps.grug_resource.times[harvest_tier] <=
				previous_caps.groupcaps.grug_resource.times[harvest_tier],
				"higher pick slows on resource tier " .. harvest_tier)
		end
	end
end

-- Every harvest requirement and exact shortfall multiplier is authored by
-- the real capability builder. Also prove that every resource registration
-- agrees with the registry.
local expected_multipliers = {[0] = 1, [1] = 4, [2] = 6, [3] = 8, [4] = 10}
local seen_harvest_tier = {}
for _, resource in ipairs(grug_materials.RESOURCES) do
	local def = assert(core.registered_nodes[resource.natural_node])
	assert_equal(def.groups.grug_resource, resource.harvest_tier,
		"resource group " .. resource.key)
	assert_equal(def.groups.cracky, nil, "competing cracky " .. resource.key)
	seen_harvest_tier[resource.harvest_tier] = true
end
for harvest_tier = 1, 5 do
	assert(seen_harvest_tier[harvest_tier], "missing harvest tier " .. harvest_tier)
	for pick_tier = 1, 6 do
		local built = grug_materials.build_pick_capabilities(pick_tier)
		local shortfall = math.max(0, harvest_tier - pick_tier)
		local multiplier = expected_multipliers[shortfall] or 10
		assert_near(built.groupcaps.grug_resource.times[harvest_tier],
			grug_materials.PICK_PROFILES[pick_tier].ordinary_time * multiplier,
			"resource timing " .. pick_tier .. "/" .. harvest_tier)
	end
end

-- Protection is first and aborts before stack/depth/harvest or any builtin
-- transaction side effect.
local pos = {x = 10, y = -50, z = 10}
set_world_node(pos, "grug_materials:stone_with_emberglass")
reset_counts()
protected = true
local digger = make_digger(ItemStack("wp43_test:pick_1"))
assert_equal(core.node_dig(pos, core.get_node(pos), digger), false,
	"protected result")
assert_equal(trace[1], "protection", "protected order")
assert_equal(trace[2], "protection_violation", "protected record order")
assert_equal(#trace, 2, "protected early return")
assert_equal(counts.builtin, 0, "protected builtin")
assert_equal(counts.wear, 0, "protected wear")
assert_equal(counts.drop_calls, 0, "protected drops")
assert_equal(counts.harvest, 0, "protected settlement")
assert_equal(core.get_node(pos).name, "grug_materials:stone_with_emberglass",
	"protected node remains")

-- Depth refusal follows protection but still precedes the builtin and all
-- irreversible side effects.
set_world_node(pos, "grug_materials:stone_with_quartz")
pos.y = -101
set_world_node(pos, "grug_materials:stone_with_quartz")
reset_counts()
protected = false
digger = make_digger(ItemStack("wp43_test:pick_1"))
assert_equal(core.node_dig(pos, core.get_node(pos), digger), false,
	"depth result")
assert_equal(trace[1], "protection", "depth order protection")
assert_equal(trace[2], "stack_definition", "depth order pick")
assert_equal(counts.builtin, 0, "depth builtin")
assert_equal(counts.wear, 0, "depth wear")
assert_equal(counts.drop_calls, 0, "depth drops")
assert_equal(counts.harvest, 0, "depth settlement")
assert_equal(core.get_node(pos).name, "grug_materials:stone_with_quartz",
	"depth node remains")

-- Sufficient resource harvesting: one builtin dig/use/drop/settlement.
pos = {x = 20, y = -50, z = 20}
set_world_node(pos, "default:stone_with_gold")
reset_counts()
digger = make_digger(ItemStack("wp43_test:pick_2"))
assert_equal(core.node_dig(pos, core.get_node(pos), digger), true,
	"sufficient harvest")
assert_equal(counts.builtin, 1, "sufficient builtin")
assert_equal(counts.wear, 1, "sufficient wear")
assert_equal(counts.drop_calls, 1, "sufficient drop call")
assert_equal(counts.drop_items, 1, "sufficient drop")
assert_equal(counts.harvest, 1, "sufficient settlement")
assert_equal(counts.goldsmith, 1, "sufficient Goldsmith seam")
assert_equal(counts.xp, 1, "sufficient XP seam")
assert_equal(counts.quest, 1, "sufficient quest seam")

-- Shattering still runs the genuine dignode consumer. Observe the public
-- shatter context from inside that callback, then verify the renewable node
-- becomes a timed depleted vein without drops or settlement.
local saw_shatter_in_dignode = false
core.register_on_dignode(function(callback_pos, oldnode, callback_digger)
	if oldnode.name == "grug_materials:stone_with_emberglass" then
		saw_shatter_in_dignode = grug_materials.is_shattering(
			callback_digger, callback_pos)
	end
end)
pos = {x = 30, y = -50, z = 30}
set_world_node(pos, "grug_materials:stone_with_emberglass")
reset_counts()
digger = make_digger(ItemStack("wp43_test:pick_1"))
local shatter_decision = grug_materials.mining_decision(
	pos, core.get_node(pos), digger)
assert_equal(shatter_decision.allowed, true, "shatter allowed")
assert_equal(shatter_decision.shatter, true, "shatter classification")
assert_equal(shatter_decision.multiplier, 8, "shatter multiplier")
assert_equal(core.node_dig(pos, core.get_node(pos), digger), true,
	"shatter transaction")
assert_equal(counts.builtin, 1, "shatter builtin")
assert_equal(counts.wear, 1, "shatter wear")
assert_equal(counts.drop_calls, 0, "shatter drop calls")
assert_equal(counts.drop_items, 0, "shatter drops")
assert_equal(counts.harvest, 0, "shatter settlement")
assert_equal(counts.goldsmith, 0, "shatter Goldsmith")
assert_equal(counts.xp, 0, "shatter XP")
assert_equal(counts.quest, 0, "shatter quest")
assert_equal(counts.sounds, 1, "shatter sound")
assert_equal(counts.chats, 1, "shatter message")
assert_equal(saw_shatter_in_dignode, true, "dignode shatter context")
assert_equal(core.get_node(pos).name, "grug_nodes:depleted_vein",
	"renewable depleted transition")
assert_equal(core.get_meta(pos):get_string("grug_ore"),
		"grug_materials:stone_with_emberglass", "renewable ore meta")
assert_equal(counts.timers, 1, "renewable timer")
assert(timers[pos_key(pos)] >= 900 and timers[pos_key(pos)] <= 1800)
assert_equal(grug_materials.is_shattering(digger, pos), false,
	"shatter context cleanup")

-- Exercise the other exact shatter multipliers as public decisions.
for shortfall, multiplier in pairs({[1] = 4, [2] = 6, [3] = 8, [4] = 10}) do
	local resource_tier = shortfall + 1
	local target
	for _, resource in ipairs(grug_materials.RESOURCES) do
		if resource.harvest_tier == resource_tier then
			target = resource
			break
		end
	end
	local decision = grug_materials.mining_decision(
		{x = shortfall, y = -50, z = 90}, {name = target.natural_node},
		make_digger(ItemStack("wp43_test:pick_1")))
	assert_equal(decision.shortfall, shortfall, "shortfall " .. shortfall)
	assert_equal(decision.multiplier, multiplier, "multiplier " .. shortfall)
end

-- Crafted/storage nodes bypass both gates, while a natural node requires a
-- pick even for a creative player.
pos = {x = 40, y = -2000, z = 40}
set_world_node(pos, "grug_materials:bronze_block")
reset_counts()
digger = make_digger(ItemStack(""))
assert_equal(core.node_dig(pos, core.get_node(pos), digger), true,
	"crafted block exempt")
assert_equal(counts.builtin, 1, "crafted builtin")
assert_equal(counts.drop_items, 1, "crafted self drop")
assert_equal(counts.protection_checks, 1, "crafted engine protection only")

pos = {x = 41, y = -50, z = 41}
set_world_node(pos, "default:stone")
reset_counts()
digger = make_digger(ItemStack(""), true)
assert_equal(core.node_dig(pos, core.get_node(pos), digger), false,
	"creative non-pick refusal")
assert_equal(counts.builtin, 0, "creative refusal builtin")
assert_equal(counts.wear, 0, "creative refusal wear")
assert_equal(counts.drop_calls, 0, "creative refusal drops")

-- Loaded definitions: no non-zero node level, no competing resource cracky,
-- every active Grudgelands pick and every pure profile has zero maxlevel.
for name, def in pairs(core.registered_nodes) do
	local groups = def.groups or {}
	assert(not groups.level or groups.level == 0, "non-zero level on " .. name)
	if groups.grug_resource then
		assert_equal(groups.cracky, nil, "resource cracky on " .. name)
	end
end
for name, def in pairs(core.registered_items) do
	if (def.groups or {}).grug_pick_tier then
		local item_caps = assert(def.tool_capabilities, "pick caps " .. name)
		assert_equal(item_caps.groupcaps.cracky.maxlevel, 0,
			"pick cracky maxlevel " .. name)
		assert_equal(item_caps.groupcaps.grug_resource.maxlevel, 0,
			"pick resource maxlevel " .. name)
	end
end

-- Registry completeness and duplicate identities.
local function unique_rows(rows, fields, label)
	local seen = {}
	for _, row in ipairs(rows) do
		for _, field in ipairs(fields) do
			local value = assert(row[field], label .. " missing " .. field)
			local key = field .. "=" .. tostring(value)
			assert(not seen[key], label .. " duplicate " .. key)
			seen[key] = true
		end
	end
end
unique_rows(grug_materials.TIERS,
	{"id", "key", "node", "bar_item", "block_node"}, "tier")
unique_rows(grug_materials.RESOURCES,
	{"key", "natural_node", "raw_item"}, "resource")
unique_rows(grug_materials.PROCESSED_MATERIALS,
	{"key", "item", "block_node"}, "processed")

local expected_regions = {
	human = {"citrine", "diamond", "sunwax", "oak"},
	dwarf = {"garnet", "sapphire", "runeslate", "mountain_pine"},
	elf = {"jade", "sapphire", "moonresin", "silverwood"},
	orc = {"garnet", "diamond", "red_ochre", "spikethorn_acacia"},
	troll = {"jade", "ruby", "spirit_resin", "kapok"},
	undead = {"citrine", "ruby", "gravesalt", "gravewood"},
}
local race_count = 0
for race, expected in pairs(expected_regions) do
	race_count = race_count + 1
	local row = assert(grug_materials.RACE_REGIONS[race])
	assert_equal(row.g1, expected[1], race .. " G1")
	assert_equal(row.g2, expected[2], race .. " G2")
	assert_equal(row.cultural, expected[3], race .. " culture")
	assert_equal(row.signature_wood, expected[4], race .. " wood")
	assert_equal(grug_materials.resource(row.g1).grade, "G1", race .. " G1 grade")
	assert_equal(grug_materials.resource(row.g2).grade, "G2", race .. " G2 grade")
	assert_contains(grug_materials.CULTURAL_MATERIALS[row.cultural].item,
		"grug_materials:", race .. " culture namespace")
end
assert_equal(race_count, 6, "race region count")
for _, material in ipairs(grug_materials.PROCESSED_MATERIALS) do
	assert_equal(material.item:match("^grug_materials:") ~= nil, true,
		"processed item namespace " .. material.key)
	assert_equal(material.block_node:match("^grug_materials:") ~= nil, true,
		"processed block namespace " .. material.key)
end

-- Alias graph: repeat-safe registration, one hop, concrete targets, and no
-- playable legacy source. Run the real migration file a second time.
dofile(repo .. "/mods/ITEMS/grug_materials/migration.lua")
for source, target in pairs(grug_materials.LEGACY_ALIASES) do
	assert(source ~= target, "self alias " .. source)
	assert_equal(grug_materials.LEGACY_ALIASES[target], nil,
		"multi-hop alias " .. source)
	assert_equal(core.registered_aliases[source], target,
		"registered alias " .. source)
	assert_equal(rawget(core.registered_items, source), nil,
		"legacy registration " .. source)
	assert(rawget(core.registered_items, target), "concrete alias target " .. target)
end

-- Fresh-load diagnostics must all run successfully, including the owner audit
-- and the real mapgen/respawn coupling audit.
for _, callback in ipairs(callbacks.mods_loaded) do
	callback()
end
local audit_passed = false
for _, message in ipairs(logs) do
	if message:find("registry audit passed", 1, true) then
		audit_passed = true
	end
	assert(not message:match("^error:"), message)
end
assert_equal(audit_passed, true, "startup audit log")

-- Focused static audit: external consumers keep their public API seams,
-- production has no leveldiff/retired helper, and old runtime ids occur only
-- in the explicit registry/migration files. Vendored texture filenames are
-- intentionally outside this item-id check.
local function read_file(path)
	local file = assert(io.open(repo .. "/" .. path, "rb"))
	local contents = file:read("*a")
	file:close()
	return contents
end

local mapgen_source = read_file("mods/MAPGEN/grug_mapgen/ores.lua")
assert_contains(mapgen_source, "grug_materials.resource_node", "mapgen resource API")
assert_contains(mapgen_source, "grug_materials.TIERS", "mapgen tier API")
local respawn_source = read_file("mods/ITEMS/grug_nodes/ore_respawn.lua")
assert_contains(respawn_source, "grug_materials.CURRENT_SCATTER_RESOURCES",
	"respawn roster API")
assert_contains(respawn_source, "grug_materials.resource_node", "respawn resource API")
assert_contains(respawn_source, "grug_materials.canonical_name", "respawn migration API")
assert_contains(respawn_source, "grug_materials.stratum_node_for", "respawn stratum API")

local production_files = {
	"mods/ITEMS/grug_materials/init.lua",
	"mods/ITEMS/grug_materials/registry.lua",
	"mods/ITEMS/grug_materials/mining.lua",
	"mods/ITEMS/grug_materials/ores.lua",
	"mods/ITEMS/grug_materials/overrides.lua",
	"mods/ITEMS/grug_materials/migration.lua",
	"mods/ITEMS/grug_materials/audit.lua",
	"mods/MAPGEN/grug_mapgen/ores.lua",
	"mods/ITEMS/grug_nodes/ore_respawn.lua",
	"mods/ENTITIES/grug_mobs/golem.lua",
	"mods/ENTITIES/grug_mobs/zombie.lua",
}
for _, path in ipairs(production_files) do
	local source = read_file(path)
	assert_equal(source:find("level_for_tier", 1, true), nil,
		"retired helper in " .. path)
	assert_equal(source:lower():find("leveldiff", 1, true), nil,
		"leveldiff in " .. path)
	if path ~= "mods/ITEMS/grug_materials/registry.lua" and
			path ~= "mods/ITEMS/grug_materials/migration.lua" then
		assert_equal(source:lower():find("emberstone", 1, true), nil,
			"stale Emberstone in " .. path)
		assert_equal(source:lower():find("grudgesteel", 1, true), nil,
			"stale Grudgesteel in " .. path)
		for _, legacy_id in ipairs({"default:stone_with_mese", "default:mese\"",
				"default:mese_crystal", "default:stone_with_diamond",
				"default:diamond\"", "default:diamondblock"}) do
			assert_equal(source:find(legacy_id, 1, true), nil,
				"legacy id in " .. path)
		end
	end
end

print("WP43 material progression integration tests passed")
