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
function core_stub.get_craft_result() return {time = 0, replacements = {}} end
function core_stub.is_creative_enabled() return false end
function core_stub.check_player_privs() return false end
local function key(pos) return pos.x .. "," .. pos.y .. "," .. pos.z end
function core_stub.get_node(pos) return world[key(pos)] or {name = "air"} end
function core_stub.set_node(pos, node) world[key(pos)] = {name = node.name} end
function core_stub.is_protected(pos) return protected_at[key(pos)] == true end
local violations = 0
function core_stub.record_protection_violation() violations = violations + 1 end
-- The builtin dig: remove the node, report success.
function core_stub.node_dig(pos) world[key(pos)] = nil return true end
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
	"craftitems.lua"}, {get_translator = function(s) return s end, LIGHT_MAX = 14,
	get_hotbar_bg = function() return "" end, gui_survival_form = ""})
run("grug_trees", {"init.lua"})
run("grug_materials", {"init.lua"})
run("grug_nodes", {"init.lua"})
current_mod = "?"
for _, fn in ipairs(mods_loaded) do fn() end
check(true, "startup audit passed under the ported getDigParams")
local M = grug_materials

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
	return ((tier == 1 or tier == 3) and "default:" or "grug_materials:") ..
		family .. "_" .. M.TIERS[tier].key
end

local picks = {{"default:pick_wood", 1}, {"default:pick_stone", 1}}
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
for _, name in ipairs({"default:shovel_wood", "default:shovel_stone"}) do
	for _, node_name in ipairs(loose) do
		check(dig(node_name, caps(name)).time <= dig(node_name, HAND).time,
			name .. " never slower than the hand on " .. node_name)
	end
end
-- The hand (and every non-pick through the hand fallback): loose only.
for _, item in ipairs({"", "default:shovel_steel", "grug_materials:axe_abyssal_steel"}) do
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
		check(dig(node_name, caps("default:shovel_" .. material)).time <
			dig(node_name, caps("default:pick_" .. material)).time,
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
check(select(2, M.tool_tier_for_stack(ItemStack("default:pick_steel"), "axe")) ==
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
	{"grug_materials:t2_stone", "default:pick_bronze", false, "Requires a T2 pick"},
	{"grug_materials:t2_stone", "grug_materials:pick_iron", true, nil},
	{"grug_materials:t5_stone", "default:pick_steel", false, "Requires a T5 pick"},
	{"default:stone_with_gold", "default:pick_wood", false, "Requires a T2 pick"},
	{"default:stone_with_iron", "default:pick_wood", true, nil},
	{"grug_materials:stone_with_diamond", "grug_materials:pick_silversteel", true, nil},
	{"default:stone", "", false, "Requires a T1 pick"},
	{"default:dirt", "", true, nil},
	{"grug_nodes:mesa_clay", "", true, nil},
	{"grug_materials:basalt", "default:pick_wood", true, nil},
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
check(M.punch_hint(origin, node, player("miner", "default:pick_bronze", 65535)) ==
	"Your pick is broken – repair it", "broken pick: repair hint")
check(M.punch_hint(origin, node, player("miner", "default:shovel_bronze", 65535)) ==
	"Requires a T3 pick", "broken shovel on rock: tier hint")
node = place("default:stone")
check(M.punch_hint(origin, node, player("miner", "default:pick_wood", 65535)) ==
	"Your pick is broken – repair it", "broken starter pick on stone: repair hint")
node = place("grug_materials:t3_stone")
-- Refused real dig: node kept, one line; rate limit and repeat suppression.
chat = {}
now_us = 10000000
check(core.node_dig(origin, node, player("miner", "default:pick_bronze")) == false and
	core.get_node(origin).name == "grug_materials:t3_stone", "refused dig keeps node")
check(#chat == 1 and chat[1][2] == "Requires a T3 pick", "refusal hint line")
for _, fn in ipairs(punch_callbacks) do fn(origin, node, player("miner", "default:pick_bronze")) end
check(#chat == 1, "punch within 1.5 s is rate-limited")
now_us = now_us + 2000000
for _, fn in ipairs(punch_callbacks) do fn(origin, node, player("miner", "default:pick_bronze")) end
check(#chat == 1, "same line within 5 s is suppressed")
now_us = now_us + 4000000
for _, fn in ipairs(punch_callbacks) do fn(origin, node, player("miner", "default:pick_bronze")) end
check(#chat == 2, "same line again after 5 s")
-- With grug_core's flash available the line goes to the screen, not chat.
do
	local flashed
	_G.grug_core = {FLASH_COLOR = {notice = 0xf0e6c8, error = 0xff4444},
		flash = function(_, message, color) flashed = {message, color} return true end}
	core_stub.get_player_by_name = function(name) return {name = name} end
	chat, now_us = {}, now_us + 10000000
	check(M.emit_hint("miner", "Requires a T3 pick") and #chat == 0 and flashed and
		flashed[1] == "Requires a T3 pick" and flashed[2] == 0xf0e6c8,
		"hint uses the neutral screen flash")
	core_stub.get_player_by_name = noop
	_G.grug_core = nil
end
-- Allowed dig of a resource settles the harvest callbacks.
local harvested
M.register_on_harvest(function(event) harvested = event end)
node = place("grug_materials:stone_with_silver")
check(core.node_dig(origin, node, player("miner", "default:pick_steel")) == true and
	harvested and harvested.resource_key == "silver" and harvested.harvest_tier == 3,
	"allowed resource dig settles the harvest")
-- Protected: refused, violation recorded, protection line.
_G.grug_core = nil
protected_at[key(origin)] = true
chat, violations, now_us = {}, 0, now_us + 10000000
node = place("default:dirt")
check(core.node_dig(origin, node, player("miner", "")) == false and violations == 1 and
	chat[1] and chat[1][2] == "Protected", "protected dig refused with its line")
check(M.punch_hint(origin, node, player("miner", "default:pick_bronze")) == "Protected",
	"protected punch hint")
protected_at[key(origin)] = nil

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
			x = index * 100, z = 7}
	end
	local session = {
		territory_rule_at = function() return "contested_land" end,
		hard_protection_kind_at = function(pos) return pos.x == 50 and "town" or nil end,
		compatibility = {world_protected_for_faction = function() return false end},
	}
	local overlay = assert(loadfile(repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/r7_zone_overlay.lua"))()(session,
		{schema = "grug_wp40_r7_anchor_roster_v1", rows = rows, sha256 = "x"})
	check(overlay.hard_protection_kind_at({x = 800, y = 0, z = 7}) == "landmark",
		"overlay: outpost column is a landmark")
	check(overlay.hard_protection_kind_at({x = 800, y = -701, z = 7}) == nil,
		"overlay: below -700 no landmark")
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
	local reverted = deep_copy(projection)
	for index, tier in ipairs(reverted.tiers) do
		if OLD[index] then tier.node = "grug_materials:" .. OLD[index] end
		tier.max_depth = tier.y_min
	end
	check(digest(reverted) ==
		"77e5b5b14c98f17250b03c5aeb817db332f85b5414311defe1f4945174f1f8bf",
		"reverting only the rename and max_depth reproduces the old pin")
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
