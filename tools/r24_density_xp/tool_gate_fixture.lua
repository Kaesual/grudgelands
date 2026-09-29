-- Round 24 Lane F portable fixture (LuaJIT): ruling 29, tool level gate.
--
--   luajit tools/r24_density_xp/tool_gate_fixture.lua "$PWD"
--
-- Reuses the Lane A mining harness (tools/r24_mining/fixture.lua: real
-- default, grug_trees, grug_materials and grug_nodes under the ported engine
-- getDigParams) and checks, for every pick, axe and shovel of the ladder:
--   * the required level (T2 5, T3 15, T4 25, T5 35, T6 45; wood, stone and
--     bronze none) and its tooltip line;
--   * the matrix tool x player level on a node the tool digs (T1 stone,
--     tree, dirt, and placed wood planks): refused exactly below the level;
--   * the hand fallback (a gated pick on leaves), a missing level authority,
--     the punch hint and a refused real dig with its one flash line.
-- Prints the matrix and "R24 TOOL GATE FIXTURE PASS checks=<n>" or raises.

local repo = assert(arg and arg[1], "usage: luajit tool_gate_fixture.lua REPO")
_G.R24_MINING_HARNESS = true
local H = dofile(repo .. "/tools/r24_mining/fixture.lua")
_G.R24_MINING_HARNESS = nil
local M = grug_materials
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local REQUIRED = {5, 15, 25, 35, 45}
local function ladder(family, tier)
	return ((tier == 1 or tier == 3) and "default:" or "grug_materials:") ..
		family .. "_" .. M.TIERS[tier].key
end
local FAMILIES = {
	{family = "pick", node = "default:stone"},
	{family = "axe", node = "default:tree"},
	{family = "shovel", node = "default:dirt"},
}

local function player(item, level)
	local stack = ItemStack(item)
	return {level = level, is_player = function() return true end,
		get_player_name = function() return "miner" end,
		get_wielded_item = function() return ItemStack(stack.name) end}
end
_G.grug_core = {get_player_level = function(p) return p.level end}

local origin = {x = 0, y = 5, z = 0}
local function place(name)
	core.set_node(origin, {name = name})
	return core.get_node(origin)
end

local LEVELS = {1, 4, 5, 14, 15, 24, 25, 34, 35, 44, 45, 60}
local header = {}
for _, level in ipairs(LEVELS) do header[#header + 1] = ("%3d"):format(level) end
print(("%-36s req  player level: "):format("tool") .. table.concat(header, " "))
for _, row in ipairs(FAMILIES) do
	local tools = {{"default:" .. row.family .. "_wood", nil},
		{"default:" .. row.family .. "_stone", nil}}
	for tier = 1, 6 do
		tools[#tools + 1] = {ladder(row.family, tier), tier > 1 and REQUIRED[tier - 1] or nil}
	end
	for _, tool in ipairs(tools) do
		local name, required = tool[1], tool[2]
		check(H.items[name], name .. " registered")
		check(M.tool_required_level(name) == required, name .. " required level")
		local description = H.items[name].description
		if required then
			check(description:find("\nRequires level " .. required, 1, true) ~= nil,
				name .. " tooltip line")
		else
			check(not description:find("Requires level", 1, true), name .. " no tooltip line")
		end
		local cells = {}
		for _, level in ipairs(LEVELS) do
			local node = place(row.node)
			local decision = M.mining_decision(origin, node, player(name, level))
			local refused = required ~= nil and level < required
			check(decision.allowed == not refused, name .. " at level " .. level ..
				" on " .. row.node)
			if refused then
				check(decision.reason == "too_low_level" and
					decision.required_level == required, name .. " reason")
			end
			cells[#cells + 1] = refused and "  -" or "  +"
		end
		print(("%-36s %3s  %s"):format(name, required or "-", table.concat(cells, " ")))
	end
end

-- Placed wood planks (not natural) with an axe: still the tool in use.
local node = place("default:wood")
check(M.mining_decision(origin, node, player("grug_materials:axe_iron", 4)).reason ==
	"too_low_level", "iron axe at level 4 on placed planks refused")
check(M.mining_decision(origin, node, player("grug_materials:axe_iron", 5)).allowed,
	"iron axe at level 5 on placed planks allowed")
-- Protection before level: a protected placed node dug with a gated tool is
-- refused as protected, with the violation recorded and the protection line.
do
	local real_protected, real_violation = core.is_protected, core.record_protection_violation
	local violations = 0
	core.is_protected = function() return true end
	core.record_protection_violation = function() violations = violations + 1 end
	node = place("default:wood")
	check(M.mining_decision(origin, node, player("grug_materials:axe_iron", 4)).reason ==
		"protected", "protected planks with a gated axe: protected, not level")
	H.clear_chat()
	H.set_time(50000000)
	check(core.node_dig(origin, node, player("grug_materials:axe_iron", 4)) == false and
		violations == 1 and H.chat()[1] and H.chat()[1][2] == "Protected",
		"protected planks with a gated axe: violation recorded, protection line")
	core.is_protected, core.record_protection_violation = real_protected, real_violation
end
-- Hand fallback: a pick does not dig leaves, the hand does; nothing refused.
node = place("default:leaves")
check(not M.tool_in_use(ItemStack("default:pick_steel"), H.nodes["default:leaves"]),
	"a pick is not in use on leaves")
check(M.mining_decision(origin, node, player("default:pick_steel", 1)).allowed,
	"steel pick at level 1 on leaves: hand fallback allowed")
check(M.punch_hint(origin, node, player("default:pick_steel", 1)) == nil,
	"no level hint where the hand digs")
-- Too hard still wins where the gated tool cannot dig the rock at all.
node = place("grug_materials:t4_stone")
check(M.mining_decision(origin, node, player("default:pick_steel", 1)).reason ==
	"too_hard", "steel pick on T4 rock: too hard, not level")
-- A missing level authority refuses nobody.
_G.grug_core = nil
node = place("default:stone")
check(M.mining_decision(origin, node, player("grug_materials:pick_abyssal_steel", 1)).allowed,
	"no level authority: allowed")
_G.grug_core = {get_player_level = function(p) return p.level end}
-- Hints: punch and a refused real dig, one flash/chat line, node kept.
check(M.punch_hint(origin, node, player("default:pick_steel", 14)) ==
	"Steel Pickaxe requires level 15", "steel pick punch hint")
check(M.punch_hint(origin, node, player("grug_materials:shovel_embersteel", 34)) ==
	"Requires a T1 pick", "a shovel is not in use on stone: the pick-tier hint, not the level")
node = place("default:dirt")
check(M.punch_hint(origin, node, player("grug_materials:shovel_embersteel", 34)) ==
	"Embersteel Shovel requires level 35", "embersteel shovel punch hint")
H.clear_chat()
H.set_time(100000000)
node = place("default:tree")
check(core.node_dig(origin, node, player("grug_materials:axe_silversteel", 24)) == false and
	core.get_node(origin).name == "default:tree", "refused dig keeps the tree")
local chat = H.chat()
check(#chat == 1 and chat[1][2] == "Silversteel Woodcutting Axe requires level 25",
	"refused dig line")
check(core.node_dig(origin, node, player("grug_materials:axe_silversteel", 25)) == true,
	"level 25 digs the tree")

print("R24 TOOL GATE FIXTURE PASS checks=" .. checks)
