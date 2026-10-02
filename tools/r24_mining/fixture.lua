-- Round 24 Lane A portable fixture (LuaJIT): mining tiers without an engine.
--
--   luajit tools/r24_mining/fixture.lua "$PWD"
--
-- Loads the real `default` node/tool sources, grug_trees, the complete
-- grug_materials mod (registry, mining, tier/decorative rocks, ores,
-- overrides, tools, curation, lifetimes, audit) and grug_nodes under a stub
-- `core` whose `get_dig_params` is a line-by-line port of Luanti
-- src/tool.cpp getDigParams (+ ToolGroupCap's default maxlevel 1), then:
--   1. runs the startup audit (register_on_mods_loaded) as the engine would;
--   2. checks a table-driven matrix: every pick x tier rock x resource x
--      decorative rock x loose ground, the hand, shovels and axes, and the
--      dig-time orderings of rulings 4-6;
--   3. drives the mining transaction, punch hints and a refused dig;
--   4. checks grug_core.protection_reason / protection_hint categories and
--      the R7 functional-anchor overlay's `hard_protection_kind_at`;
--   5. proves the mapgen pin changes are the rename: the live WP43
--      projection hashes to the new pin, and the same graph with the five old
--      stratum names and the retired `max_depth` field restored hashes to the
--      old pin; the native allowlist bytes likewise.
-- Prints "R24 MINING FIXTURE PASS checks=<n>" or raises.

local repo = assert(arg and arg[1], "usage: luajit fixture.lua REPO")
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

-- ---------------------------------------------------------------------------
-- The engine's getDigParams (src/tool.cpp:367-421), ported.
-- ---------------------------------------------------------------------------
local function get_dig_params(groups, caps, wear)
	groups = groups or {}
	caps = caps or {}
	local groupcaps = caps.groupcaps or {}
	if not groupcaps.dig_immediate then
		local immediate = groups.dig_immediate or 0
		if immediate == 2 then return {diggable = true, time = 0.5, wear = 0} end
		if immediate == 3 then return {diggable = true, time = 0, wear = 0} end
	end
	local diggable, result_time = false, 0
	local level = groups.level or 0
	for name, cap in pairs(groupcaps) do
		local leveldiff = (cap.maxlevel or 1) - level
		if leveldiff >= 0 then
			local rating = groups[name] or 0
			local time = cap.times and cap.times[rating]
			if time then
				if leveldiff > 1 then time = time / leveldiff end
				if not diggable or time < result_time then
					result_time, diggable = time, true
				end
			end
		end
	end
	return {diggable = diggable, time = result_time, wear = diggable and 1 or 0}
end

-- ---------------------------------------------------------------------------
-- Stub engine
-- ---------------------------------------------------------------------------
local function deep_copy(value, seen)
	if type(value) ~= "table" then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local out = {}
	seen[value] = out
	for k, v in pairs(value) do out[deep_copy(k, seen)] = deep_copy(v, seen) end
	return out
end
table.copy = table.copy or deep_copy

local items, nodes, tools, craftitems, aliases = {}, {}, {}, {}, {}
local mods_loaded, punch_callbacks = {}, {}
local current_mod = "?"
local now_us = 0
local chat = {}
local world = {}
local protected_at = {}
local MODPATHS = {
	default = repo .. "/mods/BASE/default",
	grug_trees = repo .. "/mods/ITEMS/grug_trees",
	grug_materials = repo .. "/mods/ITEMS/grug_materials",
	grug_nodes = repo .. "/mods/ITEMS/grug_nodes",
	doors = repo .. "/mods/BASE/doors",
	grug_decor = repo .. "/mods/ITEMS/grug_decor",
}

local function register(kind, name, def)
	name = name:gsub("^:", "")
	def = def or {}
	def.name, def.type = name, kind
	def.groups = def.groups or {}
	def.mod_origin = current_mod
	items[name] = def
	if kind == "node" then
		if def.diggable == nil then def.diggable = true end
		nodes[name] = def
	elseif kind == "tool" then tools[name] = def
	elseif kind == "craft" then craftitems[name] = def end
end

local noop = function() end
local core_stub = {
	registered_items = items, registered_nodes = nodes,
	registered_tools = tools, registered_craftitems = craftitems,
	registered_aliases = aliases, registered_ores = {},
	settings = {get_bool = function(_, _, fallback) return fallback end,
		get = function() return nil end},
}
function core_stub.register_node(name, def) register("node", name, def) end
function core_stub.register_tool(name, def) register("tool", name, def) end
function core_stub.register_craftitem(name, def) register("craft", name, def) end
function core_stub.register_item(name, def) register(def.type or "none", name, def) end
function core_stub.override_item(name, redef)
	local def = assert(items[name], "override of missing item " .. name)
	for k, v in pairs(redef) do def[k] = v end
end
function core_stub.unregister_item(name)
	items[name], nodes[name], tools[name], craftitems[name] = nil, nil, nil, nil
end
function core_stub.register_alias(old, new) aliases[old] = new end
function core_stub.get_modpath(name) return MODPATHS[name] end
function core_stub.get_current_modname() return current_mod end
function core_stub.get_translator() return function(s) return s end end
function core_stub.register_on_mods_loaded(fn) mods_loaded[#mods_loaded + 1] = fn end
function core_stub.register_on_punchnode(fn) punch_callbacks[#punch_callbacks + 1] = fn end
function core_stub.get_dig_params(groups, caps, wear) return get_dig_params(groups, caps, wear) end
function core_stub.get_us_time() return now_us end
function core_stub.chat_send_player(name, message) chat[#chat + 1] = {name, message} end
function core_stub.log() end
function core_stub.read_schematic() return {size = {x = 1, y = 1, z = 1}} end
function core_stub.register_schematic() return "stub-schematic" end
-- A small craft registry (Round 26 Lane R reads it through the harness):
-- enough of the engine's by-output and fuel-by-name behaviour for the
-- registration code paths; group matching is not modelled.
local crafts = {}
local function craft_name(value) return (tostring(value or ""):match("^(%S+)")) end
function core_stub.register_craft(def)
	crafts[#crafts + 1] = {type = def.type or "normal",
		output = craft_name(def.output), recipe = def.recipe,
		burntime = def.burntime, mod = current_mod}
end
function core_stub.clear_craft(def)
	local kept, removed = {}, 0
	for _, craft in ipairs(crafts) do
		local hit
		if def.output then
			hit = craft.type ~= "fuel" and craft.output == craft_name(def.output)
		else
			hit = craft.type == def.type and craft.recipe == def.recipe
		end
		if hit then removed = removed + 1 else kept[#kept + 1] = craft end
	end
	crafts = kept
	return removed > 0
end
function core_stub.get_all_craft_recipes(name)
	local list = {}
	for _, craft in ipairs(crafts) do
		if craft.type ~= "fuel" and craft.output == name then list[#list + 1] = craft end
	end
	return #list > 0 and list or nil
end
function core_stub.get_craft_result(input)
	if input and input.method == "fuel" then
		local stack = input.items and input.items[1]
		local name = stack and stack.get_name and stack:get_name() or stack
		for _, craft in ipairs(crafts) do
			if craft.type == "fuel" and craft.recipe == name then
				return {time = craft.burntime or 1, replacements = {}}
			end
		end
	end
	return {time = 0, replacements = {}}
end
function core_stub.is_creative_enabled() return false end
function core_stub.check_player_privs() return false end
local function key(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end
function core_stub.get_node(pos) return world[key(pos)] or {name = "air"} end
core_stub.get_node_or_nil = core_stub.get_node
function core_stub.dir_to_facedir() return 0 end
function core_stub.set_node(pos, node) world[key(pos)] = {name = node.name} end
function core_stub.is_protected(pos) return protected_at[key(pos)] == true end
local violations = 0
local violation_callbacks = {}
function core_stub.register_on_protection_violation(fn)
	violation_callbacks[#violation_callbacks + 1] = fn
end
-- builtin/game/misc.lua record_protection_violation.
function core_stub.record_protection_violation(pos, name)
	violations = violations + 1
	for _, fn in ipairs(violation_callbacks) do fn(pos, name) end
end
local function actor(object)
	return object and object.get_player_name and object:get_player_name() or ""
end
-- builtin/game/item.lua core.node_dig: protection refusal, else remove.
function core_stub.node_dig(pos, _, digger)
	if core.is_protected(pos, actor(digger)) then
		core.record_protection_violation(pos, actor(digger))
		return false
	end
	world[key(pos)] = nil
	return true
end
-- builtin core.node_punch: run the punchnode callbacks.
function core_stub.node_punch(pos, node, puncher, pointed)
	for _, fn in ipairs(punch_callbacks) do fn(pos, node, puncher, pointed) end
end
-- builtin core.item_place_node, reduced to its protection refusal.
function core_stub.item_place_node(itemstack, placer, pointed)
	if core.is_protected(pointed.above, actor(placer)) then
		core.record_protection_violation(pointed.above, actor(placer))
		return itemstack, nil
	end
	core.set_node(pointed.above, {name = itemstack:get_name()})
	return itemstack, pointed.above
end
-- Online players: every name except the "offline-" ones.
function core_stub.get_player_by_name(name)
	if type(name) == "string" and name ~= "" and not name:find("^offline%-") then
		return {name = name}
	end
	return nil
end
setmetatable(core_stub, {__index = function(t, k) rawset(t, k, noop) return noop end})

_G.core, _G.minetest = core_stub, core_stub
_G.vector = {
	new = function(x, y, z)
		if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
		return {x = x, y = y, z = z}
	end,
	copy = function(p) return {x = p.x, y = p.y, z = p.z} end,
	offset = function(p, x, y, z) return {x = p.x + x, y = p.y + y, z = p.z + z} end,
	add = function(a, b) return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z} end,
	subtract = function(a, b) return {x = a.x - b.x, y = a.y - b.y, z = a.z - b.z} end,
	equals = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end,
}
local stack_meta = {}
stack_meta.__index = stack_meta
function stack_meta:get_name() return self.name end
function stack_meta:is_empty() return self.name == "" end
function stack_meta:get_count() return self.name == "" and 0 or 1 end
function stack_meta:get_wear() return self.wear end
function stack_meta:get_definition() return items[self.name] end
function stack_meta:get_tool_capabilities()
	-- A broken stack carries empty meta capabilities (grug_repair/grug_quality).
	if self.wear >= 65535 then return {groupcaps = {}} end
	local def = items[self.name]
	return (def and def.tool_capabilities) or items[""].tool_capabilities
end
stack_meta.add_wear_by_uses = noop
_G.ItemStack = function(value)
	if type(value) == "table" then
		return setmetatable({name = value.name, wear = value.wear}, stack_meta)
	end
	return setmetatable({name = value or "", wear = 0}, stack_meta)
end
_G.PseudoRandom = function() return {next = function() return 0 end} end

-- builtin air (placement code reads its buildable_to).
register("node", "air", {buildable_to = true, walkable = false, diggable = false,
	pointable = false})
-- The builtin hand before default overrides it.
register("none", "", {tool_capabilities = {full_punch_interval = 1,
	groupcaps = {}}})

local function run(mod, files, seed)
	current_mod = mod
	if seed then rawset(_G, mod, seed) end
	for _, file in ipairs(files) do
		local chunk = assert(loadfile(MODPATHS[mod] .. "/" .. file))
		chunk()
	end
end

run("default", {"functions.lua", "trees.lua", "nodes.lua", "tools.lua",
	"craftitems.lua", "torch.lua"}, {get_translator = function(s) return s end, LIGHT_MAX = 14,
	get_hotbar_bg = function() return "" end, gui_survival_form = ""})
run("grug_trees", {"init.lua"})
run("grug_materials", {"init.lua"})
run("grug_nodes", {"init.lua"})
-- Round 24 playtest fix: the real door placement code and the capital
-- service dressing (undiggable, inert on_punch).
run("doors", {"init.lua"})
run("grug_decor", {"capital.lua"})
current_mod = "?"
for _, fn in ipairs(mods_loaded) do fn() end
check(true, "startup audit passed under the ported getDigParams")
local M = grug_materials

-- Round 24 Lane F: tools/r24_density_xp/tool_gate_fixture.lua reuses this
-- loaded harness (real default + grug_materials under the ported engine rule)
-- instead of copying it.
if rawget(_G, "R24_MINING_HARNESS") then
	return {items = items, nodes = nodes, tools = tools, core = core_stub,
		aliases = aliases, crafts = function() return crafts end,
		get_dig_params = get_dig_params, world = world, key = key,
		punch_callbacks = punch_callbacks,
		set_time = function(us) now_us = us end,
		chat = function() return chat end,
		clear_chat = function() chat = {} end,
		checks = function() return checks end}
end

-- ---------------------------------------------------------------------------
-- 2. Matrix
-- ---------------------------------------------------------------------------
local function caps(name) return ItemStack(name):get_tool_capabilities() end
local HAND = caps("")
local function dig(node_name, tool_caps)
	return get_dig_params(nodes[node_name].groups, tool_caps)
end
-- The engine's full rule: tool first, then the hand.
local function dig_with(node_name, item)
	local params = dig(node_name, caps(item))
	if not params.diggable then params = dig(node_name, HAND) end
	return params
end
local function ladder(family, tier)
	return "grug_materials:" ..
		family .. "_" .. M.TIERS[tier].key
end

local picks = {{"grug_materials:pick_wood", 1}, {"grug_materials:pick_stone", 1}}
for tier = 1, 6 do picks[#picks + 1] = {ladder("pick", tier), tier} end
local loose = {}
for _, name in ipairs(M.NATURAL_GROUND_NODES) do
	if name ~= "default:stone" then loose[#loose + 1] = name end
end

for _, pick in ipairs(picks) do
	local name, tier = pick[1], pick[2]
	check(items[name].groups.grug_pick_tier == tier, name .. " tier group")
	for _, row in ipairs(M.TIERS) do
		check(dig_with(row.node, name).diggable == (tier >= row.id),
			name .. " on " .. row.node)
	end
	for _, resource in ipairs(M.RESOURCES) do
		check(dig_with(resource.natural_node, name).diggable ==
			(tier >= resource.harvest_tier), name .. " on " .. resource.natural_node)
	end
	for _, rock in ipairs(M.DECORATIVE_ROCKS) do
		check(dig_with(rock.node, name).diggable, name .. " on " .. rock.node)
		check(nodes[rock.node].drop == rock.node, rock.node .. " drops itself")
	end
	for _, node_name in ipairs(loose) do
		check(dig_with(node_name, name).diggable, name .. " on " .. node_name)
		check(dig(node_name, caps(name)).time <= dig(node_name, HAND).time,
			name .. " never slower than the hand on " .. node_name)
	end
end
for _, name in ipairs({"grug_materials:shovel_wood", "grug_materials:shovel_stone"}) do
	for _, node_name in ipairs(loose) do
		check(dig(node_name, caps(name)).time <= dig(node_name, HAND).time,
			name .. " never slower than the hand on " .. node_name)
	end
end
-- The hand (and every non-pick through the hand fallback): loose only.
for _, item in ipairs({"", "grug_materials:shovel_steel", "grug_materials:axe_abyssal_steel"}) do
	for _, row in ipairs(M.TIERS) do
		check(not dig_with(row.node, item).diggable, "'" .. item .. "' on " .. row.node)
	end
	for _, resource in ipairs(M.RESOURCES) do
		check(not dig_with(resource.natural_node, item).diggable,
			"'" .. item .. "' on " .. resource.natural_node)
	end
	for _, rock in ipairs(M.DECORATIVE_ROCKS) do
		check(not dig_with(rock.node, item).diggable, "'" .. item .. "' on " .. rock.node)
	end
	for _, node_name in ipairs(loose) do
		check(dig_with(node_name, item).diggable, "'" .. item .. "' on " .. node_name)
	end
end
-- A deep T1 resource is still T1: groups carry no y at all.
check(nodes["default:stone_with_coal"].groups.level == nil and
	nodes["default:stone_with_iron"].groups.level == nil, "T1 ores carry no level")
check(nodes["grug_materials:abyssal_crystal_ore"].groups.level == 4, "T5 ore level 4")
for i = 2, 6 do
	check(nodes[M.TIERS[i].node].groups.level == i - 1, M.TIERS[i].node .. " level")
	check(nodes[M.TIERS[i].node].drop == "default:cobble", M.TIERS[i].node .. " drop")
end
for _, node_name in ipairs(loose) do
	local groups = nodes[node_name].groups
	check((groups.level or 0) == 0 and groups.grug_loose == groups.crumbly and
		groups.grug_loose > 0, node_name .. " is loose ground")
	check(not groups.cracky, node_name .. " is not rock")
end

-- Orderings.
for rock = 1, 6 do
	for tier = rock + 1, 6 do
		check(dig(M.TIERS[rock].node, caps(ladder("pick", tier))).time <
			dig(M.TIERS[rock].node, caps(ladder("pick", tier - 1))).time,
			"T" .. tier .. " pick faster than T" .. (tier - 1) .. " on T" .. rock)
	end
end
for _, node_name in ipairs(loose) do
	for tier = 1, 6 do
		local shovel = dig(node_name, caps(ladder("shovel", tier)))
		local pick = dig(node_name, caps(ladder("pick", tier)))
		check(shovel.time < pick.time, "T" .. tier .. " shovel beats pick on " .. node_name)
		if tier > 1 then
			check(shovel.time < dig(node_name, caps(ladder("shovel", tier - 1))).time,
				"T" .. tier .. " shovel faster than T" .. (tier - 1) .. " on " .. node_name)
		end
	end
	for _, material in ipairs({"wood", "stone"}) do
		check(dig(node_name, caps("grug_materials:shovel_" .. material)).time <
			dig(node_name, caps("grug_materials:pick_" .. material)).time,
			material .. " shovel beats " .. material .. " pick on " .. node_name)
	end
end
for tier = 1, 6 do
	check(items[ladder("axe", tier)].groups.grug_axe_tier == tier, "axe tier group")
	check(items[ladder("shovel", tier)].groups.grug_shovel_tier == tier, "shovel tier group")
	if tier > 1 then
		check(dig("default:tree", caps(ladder("axe", tier))).time <
			dig("default:tree", caps(ladder("axe", tier - 1))).time,
			"T" .. tier .. " axe faster on tree")
	end
end
check(M.tool_tier_for_stack(ItemStack("grug_materials:axe_silversteel"), "axe") == 4,
	"axe tier resolves (concentrated cultural rule)")
check(select(2, M.tool_tier_for_stack(ItemStack("grug_materials:pick_steel"), "axe")) ==
	"wrong_family", "a pick is not an axe")

-- ---------------------------------------------------------------------------
-- 3. Transaction and hints
-- ---------------------------------------------------------------------------
local function player(name, item, wear)
	local stack = ItemStack(item)
	stack.wear = wear or 0
	return {is_player = function() return true end,
		get_player_name = function() return name end,
		get_wielded_item = function() return ItemStack(stack) end}
end
local origin = {x = 0, y = -200, z = 0}
local function place(name)
	core.set_node(origin, {name = name})
	return core.get_node(origin)
end
local cases = {
	{"grug_materials:t2_stone", "grug_materials:pick_bronze", false, "Requires a T2 pick"},
	{"grug_materials:t2_stone", "grug_materials:pick_iron", true, nil},
	{"grug_materials:t5_stone", "grug_materials:pick_steel", false, "Requires a T5 pick"},
	{"default:stone_with_gold", "grug_materials:pick_wood", false, "Requires a T2 pick"},
	{"default:stone_with_iron", "grug_materials:pick_wood", true, nil},
	{"grug_materials:stone_with_sapphire", "grug_materials:pick_silversteel", true, nil},
	{"grug_materials:stone_with_diamond", "grug_materials:pick_silversteel", false,
		"Requires a T6 pick"},
	{"grug_materials:stone_with_diamond", "grug_materials:pick_abyssal_steel", true, nil},
	{"default:stone", "", false, "Requires a T1 pick"},
	{"default:dirt", "", true, nil},
	{"grug_nodes:mesa_clay", "", true, nil},
	{"grug_materials:basalt", "grug_materials:pick_wood", true, nil},
}
for _, case in ipairs(cases) do
	local node = place(case[1])
	local p = player("miner", case[2])
	local decision = M.mining_decision(origin, node, p)
	check(decision.allowed == case[3], case[1] .. " with " .. case[2] .. " allowed")
	check(M.punch_hint(origin, node, p) == case[4], case[1] .. " with " .. case[2] .. " hint")
end
-- No hint for a selected skill or a broken pick.
register("tool", "grug_abilities:strike", {groups = {grug_ability = 1},
	tool_capabilities = {groupcaps = {dig_immediate = {times = {[2] = 0.3, [3] = 0.3},
		maxlevel = 0}}}})
local node = place("grug_materials:t3_stone")
check(M.punch_hint(origin, node, player("miner", "grug_abilities:strike")) == nil,
	"skill: no hint")
_G.grug_core = {equipment_is_broken = function(stack) return stack:get_wear() >= 65535 end}
check(M.punch_hint(origin, node, player("miner", "grug_materials:pick_bronze", 65535)) ==
	"Your pick is broken – repair it", "broken pick: repair hint")
check(M.punch_hint(origin, node, player("miner", "grug_materials:shovel_bronze", 65535)) ==
	"Requires a T3 pick", "broken shovel on rock: tier hint")
node = place("default:stone")
check(M.punch_hint(origin, node, player("miner", "grug_materials:pick_wood", 65535)) ==
	"Your pick is broken – repair it", "broken starter pick on stone: repair hint")
node = place("grug_materials:t3_stone")
-- Refused real dig: node kept, one line; rate limit and repeat suppression.
chat = {}
now_us = 10000000
check(core.node_dig(origin, node, player("miner", "grug_materials:pick_bronze")) == false and
	core.get_node(origin).name == "grug_materials:t3_stone", "refused dig keeps node")
check(#chat == 1 and chat[1][2] == "Requires a T3 pick", "refusal hint line")
for _, fn in ipairs(punch_callbacks) do fn(origin, node, player("miner", "grug_materials:pick_bronze")) end
check(#chat == 1, "same line within the 1.5 s flash lifetime is not repeated")
now_us = now_us + 1600000
for _, fn in ipairs(punch_callbacks) do fn(origin, node, player("miner", "grug_materials:pick_bronze")) end
check(#chat == 2, "same line again once the flash has expired")
now_us = now_us + 100000
check(not M.emit_hint("miner", "Other line") and #chat == 2,
	"a different line within 0.25 s waits")
now_us = now_us + 200000
check(M.emit_hint("miner", "Other line") and #chat == 3,
	"a different line after 0.25 s replaces the flash at once")
-- With grug_core's flash available the line goes to the screen, not chat.
do
	local flashed
	_G.grug_core = {FLASH_COLOR = {notice = 0xf0e6c8, error = 0xff4444},
		flash = function(_, message, color) flashed = {message, color} return true end}
	local online = core_stub.get_player_by_name
	core_stub.get_player_by_name = function(name) return {name = name} end
	chat, now_us = {}, now_us + 10000000
	check(M.emit_hint("miner", "Requires a T3 pick") and #chat == 0 and flashed and
		flashed[1] == "Requires a T3 pick" and flashed[2] == 0xf0e6c8,
		"hint uses the neutral screen flash")
	core_stub.get_player_by_name = online
	_G.grug_core = nil
end
-- Allowed dig of a resource settles the harvest callbacks.
local harvested
M.register_on_harvest(function(event) harvested = event end)
node = place("grug_materials:stone_with_silver")
check(core.node_dig(origin, node, player("miner", "grug_materials:pick_steel")) == true and
	harvested and harvested.resource_key == "silver" and harvested.harvest_tier == 3,
	"allowed resource dig settles the harvest")
-- Round 24 ruling 29 (Lane F): the tool level gate is part of the decision;
-- the full matrix is tools/r24_density_xp/tool_gate_fixture.lua.
do
	_G.grug_core = {get_player_level = function(p) return p.level end}
	local function leveled(item, level)
		local p = player("miner", item)
		p.level = level
		return p
	end
	node = place("grug_materials:t2_stone")
	check(M.mining_decision(origin, node, leveled("grug_materials:pick_iron", 4)).reason ==
		"too_low_level", "iron pick at level 4 refused")
	check(M.mining_decision(origin, node, leveled("grug_materials:pick_iron", 5)).allowed,
		"iron pick at level 5 allowed")
	check(M.punch_hint(origin, node, leveled("grug_materials:pick_iron", 4)) ==
		"Iron Pickaxe requires level 5", "iron pick at level 4: level hint")
end
-- Protected: refused, violation recorded, protection line.
_G.grug_core = nil
protected_at[key(origin)] = true
chat, violations, now_us = {}, 0, now_us + 10000000
node = place("default:dirt")
check(core.node_dig(origin, node, player("miner", "")) == false and violations == 1 and
	#chat == 1 and chat[1][2] == "Protected", "protected dig refused with one line")
chat, now_us = {}, now_us + 10000000
check(core.node_dig(origin, node, player("offline-miner", "")) == false and
	#chat == 0, "offline actor: violation without a line")
core.record_protection_violation(origin, "")
check(#chat == 0, "non-player violation (explosion): no line")
check(M.punch_hint(origin, node, player("miner", "grug_materials:pick_bronze")) == "Protected",
	"protected punch hint")
protected_at[key(origin)] = nil

-- ---------------------------------------------------------------------------
-- 3b. Round 24 playtest fix: the protection line for every refused dig and
-- place in a protected town, independent of node type and wielded item.
-- Each case replays the engine: the punch (INTERACT_START_DIGGING calls the
-- node's on_punch), then the completed dig when the client would complete it
-- (tool or hand can dig) through the node's on_dig -- with a skill through
-- grug_abilities' on_dig wrapper, which refuses a protected node and records
-- the violation -- and a place attempt through item_place_node.
-- Exactly one line, the protection line, per refused action.
-- ---------------------------------------------------------------------------
do
	register("node", "fixture:custom_punch", {groups = {cracky = 3, oddly_breakable_by_hand = 1},
		on_punch = function() end})
	register("craft", "fixture:plain_item", {})
	_G.grug_core = {protection_hint = function(pos)
		return protected_at[key(pos)] and "Town – protected" or nil
	end, equipment_is_broken = function() return false end}
	local function on_punch(def)
		return def.on_punch or core.node_punch
	end
	local function on_dig(def)
		return def.on_dig or core.node_dig
	end
	local base = {x = 100, y = 10, z = 100}
	local nodes_under_test = {"default:dirt", "default:torch", "default:wood",
		"grug_materials:slate", "fixture:custom_punch", "default:tree"}
	local wields = {"", "grug_abilities:strike", "grug_materials:pick_bronze",
		"fixture:plain_item"}
	local serial = 0
	for _, node_name in ipairs(nodes_under_test) do
		for _, wield in ipairs(wields) do
			serial = serial + 1
			local name = "town" .. serial
			local p = player(name, wield)
			local pos = vector.offset(base, serial, 0, 0)
			core.set_node(pos, {name = node_name})
			protected_at[key(pos)] = true
			local node = core.get_node(pos)
			local def = nodes[node_name]
			chat, now_us = {}, now_us + 10000000
			on_punch(def)(pos, node, p, {type = "node", under = pos, above = pos})
			local stack = ItemStack(wield)
			local skill = ((items[wield] or {}).groups or {}).grug_ability
			if M.stack_can_dig(stack, def) then
				if skill then
					-- grug_abilities input.lua on_dig wrapper: M.can_dig refuses a
					-- protected node for the skill hand and records the violation.
					if core.is_protected(pos, name) then
						core.record_protection_violation(pos, name)
					end
				else
					on_dig(def)(pos, node, p)
				end
			end
			local label = node_name .. " with '" .. wield .. "'"
			check(core.get_node(pos).name == node_name, label .. ": node kept")
			check(#chat == 1 and chat[1][1] == name and chat[1][2] == "Town – protected",
				label .. ": exactly one protection line (" .. #chat .. ")")
			-- A second attempt within the flash lifetime adds nothing.
			now_us = now_us + 500000
			on_punch(def)(pos, node, p, {type = "node", under = pos, above = pos})
			check(#chat == 1, label .. ": repeat within 1.5 s keeps the line")
		end
	end
	-- Placing into a protected town: every wield that places reports once.
	for _, item in ipairs({"default:dirt", "default:wood", "default:torch",
			"grug_materials:slate"}) do
		serial = serial + 1
		local name = "town" .. serial
		local pos = vector.offset(base, serial, 1, 0)
		protected_at[key(pos)] = true
		chat, now_us = {}, now_us + 10000000
		local _, placed = core.item_place_node(ItemStack(item), player(name, item),
			{type = "node", under = vector.offset(pos, 0, -1, 0), above = pos})
		check(placed == nil and core.get_node(pos).name == "air",
			"place " .. item .. " refused")
		check(#chat == 1 and chat[1][2] == "Town – protected",
			"place " .. item .. ": one protection line")
	end
	-- Review fixes. (1) Door placement: the real doors on_place reports the
	-- refused placement (GRUG PATCH) -- right-click, so no punch covers it.
	for _, door in ipairs({"doors:door_wood", "doors:door_steel"}) do
		serial = serial + 1
		local name = "town" .. serial
		local pos = vector.offset(base, serial, 1, 0)
		protected_at[key(pos)] = true
		core.set_node(vector.offset(pos, 0, -1, 0), {name = "default:stone"})
		chat, now_us = {}, now_us + 10000000
		local placer = player(name, door)
		placer.get_player_control = function() return {} end
		placer.get_look_dir = function() return {x = 0, y = 0, z = 1} end
		items[door].on_place(ItemStack(door), placer,
			{type = "node", under = vector.offset(pos, 0, -1, 0), above = pos})
		check(core.get_node(pos).name == "air", door .. " placement refused")
		check(#chat == 1 and chat[1][2] == "Town – protected",
			door .. " placement: one protection line (" .. #chat .. ")")
	end
	-- (2) A press that cast a skill gives no protection line on its punch;
	-- a press that did not cast (swing skill, no valid target) keeps it, and
	-- the skill hand's refused dig reports it either way.
	local cast = {}
	_G.grug_abilities = {input = {cast_this_press = function(p)
		return cast[p:get_player_name()] == true
	end}}
	local dirt = vector.offset(base, 0, 7, 0)
	core.set_node(dirt, {name = "default:dirt"})
	protected_at[key(dirt)] = true
	for _, row in ipairs({{"cast", true, 0}, {"nocast", false, 1}}) do
		serial = serial + 1
		local name = "town" .. serial
		cast[name] = row[2]
		chat, now_us = {}, now_us + 10000000
		local p = player(name, "grug_abilities:strike")
		core.node_punch(dirt, core.get_node(dirt), p, {type = "node"})
		check(#chat == row[3], "skill press " .. row[1] .. ": " .. row[3] ..
			" protection line(s) on the punch")
		now_us = now_us + 10000000
		core.record_protection_violation(dirt, name) -- the skill hand's refused dig
		check(#chat == row[3] + 1 and chat[#chat][2] == "Town – protected",
			"skill press " .. row[1] .. ": refused dig still reports")
	end
	check(M.punch_hint(dirt, core.get_node(dirt), player("town-hand", "")) ==
		"Town – protected", "bare hand ignores the skill cast flag")
	_G.grug_abilities = nil
	-- (3) Undiggable town dressing: only the protection line, never a tier or
	-- level line; the capital props' own on_punch reaches the shared hint.
	register("node", "fixture:camp_display", {diggable = false,
		groups = {not_in_creative_inventory = 1}})
	for _, node_name in ipairs({"fixture:camp_display", "grug_decor:capital_counter",
			"grug_decor:capital_anvil"}) do
		local def = nodes[node_name]
		check(def and def.diggable == false, node_name .. " stays undiggable")
		for _, protected in ipairs({true, false}) do
			serial = serial + 1
			local name = "town" .. serial
			local pos = vector.offset(base, serial, 2, 0)
			core.set_node(pos, {name = node_name})
			protected_at[key(pos)] = protected or nil
			chat, now_us = {}, now_us + 10000000
			on_punch(def)(pos, core.get_node(pos), player(name, "grug_materials:pick_wood"),
				{type = "node"})
			check(#chat == (protected and 1 or 0) and
				(not protected or chat[1][2] == "Town – protected"),
				node_name .. (protected and " protected: one line" or
					" unprotected: silent"))
		end
		check(def.on_rightclick == nil or node_name == "fixture:camp_display" or
			def.on_rightclick(vector.new(0, 0, 0)) == nil,
			node_name .. " right-click unchanged (inert)")
	end
	-- The tier line stays suppressed for a skill on unprotected rock.
	local pos = vector.offset(base, 0, 5, 0)
	core.set_node(pos, {name = "grug_materials:t3_stone"})
	check(M.punch_hint(pos, core.get_node(pos), player("skill", "grug_abilities:strike")) == nil,
		"skill on unprotected T3 rock: no tier line")
	check(M.punch_hint(pos, core.get_node(pos), player("hand", "")) ==
		"Requires a T3 pick", "hand on unprotected T3 rock: tier line")
	_G.grug_core = nil
end

-- ---------------------------------------------------------------------------
-- 4. Protection reasons
-- ---------------------------------------------------------------------------
do
	local zones = {}
	local function at(pos) return zones[key(pos)] or {} end
	_G.grug_zones = {
		territory_rule_at = function(pos) return at(pos).rule or "contested_land" end,
		hard_protection_kind_at = function(pos) return at(pos).kind end,
	}
	local factions = {}
	_G.grug_core = {
		zone_authority_installed = function() return true end,
		get_player_faction = function(name) return factions[name] end,
		-- Round 25 road/POI protection: none in this stub world.
		world_feature_at = function() return nil end,
		world_protected_for_faction = function(pos, faction)
			local rule = at(pos).rule or "contested_land"
			if faction ~= "accord" and faction ~= "throng" then return true end
			if at(pos).kind or rule == "immutable" then return true end
			if rule == "accord_home" then return faction ~= "accord" end
			if rule == "throng_home" then return faction ~= "throng" end
			return false
		end,
	}
	core_stub.is_protected = function() return false end
	assert(loadfile(repo .. "/mods/CORE/grug_core/protection.lua"))()
	factions.a, factions.t = "accord", "throng"
	local function spot(x, rule, kind)
		local pos = {x = x, y = 10, z = 0}
		zones[key(pos)] = {rule = rule, kind = kind}
		return pos
	end
	local expectations = {
		{spot(1, "accord_home", "town"), "t", "Town – protected"},
		{spot(1, "accord_home", "town"), "a", "Town – protected"},
		{spot(2, "contested_land", "landmark"), "a", "Landmark – protected"},
		{spot(3, "accord_home"), "t", "Accord home territory – protected"},
		{spot(3, "accord_home"), "a", nil},
		{spot(4, "throng_home"), "a", "Throng home territory – protected"},
		{spot(4, "throng_home"), "t", nil},
		{spot(5, "immutable"), "a", "Open sea – protected"},
		{spot(6, "contested_land"), "a", nil},
		{spot(6, "contested_land"), "nobody", "Protected – choose a faction first"},
	}
	for _, row in ipairs(expectations) do
		check(grug_core.protection_hint(row[1], row[2]) == row[3],
			"protection hint at x=" .. row[1].x .. " for " .. row[2])
	end
	check(grug_core.protection_hint(spot(1, "accord_home", "town"), "") == "Protected",
		"empty actor: plain line")
	-- The functional-anchor overlay answers "landmark" on its 36 columns.
	local rows = {}
	for index = 1, 42 do
		rows[index] = {id = "a" .. index,
			family = index <= 6 and "start" or (index <= 30 and "outpost" or "bandit"),
			x = index * 100, y = 20, z = 7}
	end
	local session = {
		territory_rule_at = function() return "contested_land" end,
		-- Round 24 ruling 30: protected from the placement height - 100 up.
		protection_floor_y = function(placement_y) return placement_y - 100 end,
		hard_protection_kind_at = function(pos) return pos.x == 50 and "town" or nil end,
		compatibility = {world_protected_for_faction = function() return false end},
	}
	local overlay = assert(loadfile(repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/r7_zone_overlay.lua"))()(session,
		{schema = "grug_wp40_r7_anchor_roster_v1", rows = rows, sha256 = "x"})
	check(overlay.hard_protection_kind_at({x = 800, y = 0, z = 7}) == "landmark",
		"overlay: outpost column is a landmark")
	check(overlay.hard_protection_kind_at({x = 800, y = -80, z = 7}) == "landmark",
		"overlay: landmark down to 100 below the placement")
	check(overlay.hard_protection_kind_at({x = 800, y = -81, z = 7}) == nil,
		"overlay: no landmark below 100 under the placement")
	check(overlay.hard_protection_kind_at({x = 50, y = 0, z = 0}) == "town",
		"overlay delegates to the session")
end

-- ---------------------------------------------------------------------------
-- 5. Mapgen pins are the rename
-- ---------------------------------------------------------------------------
local ok_ffi, ffi = pcall(require, "ffi")
if ok_ffi then
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local raw_sha256 = common.new_sha256()
	local canonical = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/canonical.lua")
	-- typed_graph as in r7_manifest.lua (its graph_digest seam).
	local function typed_graph(value)
		local kind = type(value)
		if kind == "string" then return canonical.bytes(value) end
		if kind == "boolean" then return canonical.boolean(value) end
		if kind == "number" then
			if value < 0 then return canonical.signed(value) end
			return canonical.unsigned(value)
		end
		local count, array, key_count = #value, true, 0
		for k in pairs(value) do
			key_count = key_count + 1
			if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > count then
				array = false
			end
		end
		if key_count ~= count then array = false end
		if array then
			local children = {}
			for index = 1, count do children[index] = typed_graph(value[index]) end
			return canonical.array(children)
		end
		local pairs_array = {}
		for k, child in pairs(value) do
			pairs_array[#pairs_array + 1] = {typed_graph(k), typed_graph(child)}
		end
		return canonical.map(pairs_array)
	end
	local function digest(graph)
		return canonical.hex(canonical.checksum(typed_graph(graph), raw_sha256))
	end
	local handoff = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp43_handoff.lua")
	local projection = handoff.project(M)
	handoff.validate_public(M, projection)
	local manifest_source = common.read_file(repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/r7_manifest.lua")
	local pinned = manifest_source:match(
		"frozen%.wp43_projection ~=%s*\"(%x+)\"")
	local live = digest(projection)
	check(live == pinned, "WP43 projection digest matches its pin: " .. live)
	local OLD = {nil, "slate", "basalt", "granite", "emberrock", "abyssal_rock"}
	-- Native allowlist canonical bytes (r7_native.lua canonical_native_bytes).
	local function native(names)
		local rows = {"grug_wp40_r7_native_allowlist_v1\n",
			"blob|grug_mapgen:native_gravel_blob_v1|ore=default:gravel|wherein=" ..
			"default:stone|clust_scarcity=4096|clust_num_ores=1|clust_size=5|" ..
			"y_min=-31000|y_max=31000|noise_threshold=0|noise=0.5,0.2,5,5,5,766,1,0,2," ..
			"defaults\n"}
		local keys = {"iron", "steel", "silversteel", "embersteel", "abyssal_steel"}
		for index = 1, 5 do
			local tier = M.TIERS[index + 1]
			rows[#rows + 1] = "stratum|grug_mapgen:native_stratum_" .. keys[index] ..
				"_v1|ore=" .. names[index] .. "|wherein=default:stone|clust_scarcity=1|" ..
				"y_min=" .. tier.y_min .. "|y_max=" .. tier.y_max .. "\n"
		end
		return common.hex(raw_sha256(table.concat(rows)))
	end
	local old_names, new_names = {}, {}
	for index = 1, 5 do
		old_names[index] = "grug_materials:" .. OLD[index + 1]
		new_names[index] = M.TIERS[index + 1].node
	end
	check(native(old_names) ==
		"d1fe4ac1c7cbe5525af65bde48cc4309870c01e4d474785f2cf0cda3d2639480",
		"old native allowlist bytes reproduce the old pin")
	check(native(new_names) ==
		"c29c9c6c5eadb0f3ba22cb10a5cd717e5ddec4041aad19df166c025d97b5e2ab",
		"renamed native allowlist bytes give the new pin")
else
	print("note: no ffi, pin section skipped")
end

print("R24 MINING FIXTURE PASS checks=" .. checks)
