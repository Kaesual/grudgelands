-- Mining tiers, dig transaction and punch hints (WP43, Round 24 rulings 1-7).
--
-- Tier rock and resources are gated by the ENGINE: a node that needs a pick
-- of tier N carries `level = N - 1` (registry.lua `level_for_tier`), a tier-t
-- pick carries `maxlevel = t - 1` on `cracky` and `grug_resource`. The client
-- predicts that from the definitions alone, so a too-weak pick shows no
-- cracks and cannot dig at all (Luanti src/tool.cpp getDigParams: a groupcap
-- whose maxlevel is below the node level is skipped; a higher pick divides
-- the time by the level difference). There is no depth limit per pick and no
-- dig-without-drop path any more. Loose ground has no level and no tool gate.
--
-- Server protection stays authoritative (builtin core.node_dig); this file
-- adds a server-side re-check of the same engine rule for natural nodes, the
-- harvest callbacks and rate-limited one-line hints.

local TIER_COUNT = #grug_materials.TIERS
local HARVEST_TIER_COUNT = 5

-- Provisional WP43 profiles. They make all six progression tiers mechanically
-- complete without registering WP29's final gear catalog. WP22 owns the later
-- speed/durability calibration; consumers should build capabilities from this
-- table instead of copying its values. `cracky_times` and `ordinary_time` are
-- the times at level difference 0 and 1; the engine divides them by the level
-- difference when a pick digs rock two or more tiers below its own.
grug_materials.PICK_PROFILES = {
	[1] = {tier = 1, key = "bronze", ordinary_time = 0.45, uses = 300,
		punch_attack_uses = 180,
		cracky_times = {[1] = 2.25, [2] = 0.90, [3] = 0.45}},
	[2] = {tier = 2, key = "iron", ordinary_time = 0.425, uses = 600,
		punch_attack_uses = 180,
		cracky_times = {[1] = 2.125, [2] = 0.85, [3] = 0.425}},
	[3] = {tier = 3, key = "steel", ordinary_time = 0.40, uses = 1000,
		punch_attack_uses = 180,
		cracky_times = {[1] = 2.00, [2] = 0.80, [3] = 0.40}},
	[4] = {tier = 4, key = "silversteel", ordinary_time = 0.35, uses = 1500,
		punch_attack_uses = 240,
		cracky_times = {[1] = 1.75, [2] = 0.70, [3] = 0.35}},
	[5] = {tier = 5, key = "embersteel", ordinary_time = 0.30, uses = 2000,
		punch_attack_uses = 300,
		cracky_times = {[1] = 1.50, [2] = 0.60, [3] = 0.30}},
	[6] = {tier = 6, key = "abyssal_steel", ordinary_time = 0.25, uses = 3000,
		punch_attack_uses = 360,
		cracky_times = {[1] = 1.25, [2] = 0.50, [3] = 0.25}},
}

local function exact_tier(value)
	local tier = tonumber(value)
	if not tier or tier ~= math.floor(tier) or tier < 1 or tier > TIER_COUNT then
		return nil
	end
	return tier
end

local function copy_times(times)
	local result = {}
	for rating, seconds in pairs(times or {}) do
		result[rating] = seconds
	end
	return result
end

-- One ordinary time for every resource rating. Whether the pick may dig a
-- resource at all is the level gate, not a missing time entry.
local function resource_times(ordinary_time)
	local times = {}
	for harvest_tier = 1, HARVEST_TIER_COUNT do
		times[harvest_tier] = ordinary_time
	end
	return times
end

-- Build a fresh capability table. `values` exists for the three deliberately
-- weaker T1 starter picks; omitting it selects the published tier profile.
function grug_materials.build_pick_capabilities(tier, values)
	tier = exact_tier(tier)
	if not tier then
		error("grug_materials: invalid pick tier")
	end
	local profile = grug_materials.PICK_PROFILES[tier]
	values = values or {}
	local ordinary_time = tonumber(values.ordinary_time or profile.ordinary_time)
	local uses = tonumber(values.uses or profile.uses)
	local punch_attack_uses = tonumber(values.punch_attack_uses) or
		profile.punch_attack_uses
	local max_drop_level = tonumber(values.max_drop_level)
	if max_drop_level == nil then
		max_drop_level = tonumber(profile.max_drop_level) or 0
	end
	if not ordinary_time or ordinary_time <= 0 or not uses or uses <= 0 or
			not punch_attack_uses or punch_attack_uses <= 0 then
		error("grug_materials: invalid pick capability values")
	end
	local maxlevel = grug_materials.level_for_tier(tier)
	return {
		full_punch_interval = values.full_punch_interval or
			profile.full_punch_interval or 1.0,
		max_drop_level = max_drop_level,
		punch_attack_uses = punch_attack_uses,
		groupcaps = {
			cracky = {times = copy_times(values.cracky_times or
				profile.cracky_times), uses = uses,
				maxlevel = maxlevel},
			grug_loose = {times = copy_times(values.loose_times), uses = uses,
				maxlevel = tonumber(values.loose_maxlevel) or 0},
			grug_resource = {times = resource_times(ordinary_time),
				uses = uses, maxlevel = maxlevel},
		},
		damage_groups = table.copy(values.damage_groups or profile.damage_groups or
			{fleshy = 4}),
	}
end

-- Keep the material taxonomy separate from `crumbly`: that upstream group
-- also contains solid sandstone. The engine selects the fastest matching
-- groupcap, so a dedicated group makes the shovel surface explicit and gives
-- picks one slower route: a pick digs loose ground at twice the time of the
-- shovel of its tier (ruling 5).
function grug_materials.build_loose_times(shovel_times)
	local times = {}
	for rating, seconds in pairs(shovel_times or {}) do
		times[rating] = seconds * 2
	end
	return times
end

function grug_materials.pick_tier_for_stack(stack)
	if not stack or stack:is_empty() then
		return nil
	end
	local def = stack:get_definition()
	return exact_tier(def and (def.groups or {}).grug_pick_tier)
end

local TOOL_FAMILY_GROUPS = {
	pick = {membership = "pickaxe", tier = "grug_pick_tier"},
	axe = {membership = "axe", tier = "grug_axe_tier"},
	shovel = {membership = "shovel", tier = "grug_shovel_tier"},
}

-- Tier-neutral natural-source authority. Every pick, axe and shovel of the
-- ladder carries its tier group (overrides.lua, tools.lua); a matching family
-- without one reports unavailable tier authority instead of borrowing
-- another family's taxonomy.
function grug_materials.tool_tier_for_stack(stack, family)
	local groups = TOOL_FAMILY_GROUPS[family]
	if not groups then
		error("grug_materials: unknown tool family " .. tostring(family), 0)
	end
	if not stack or type(stack.is_empty) ~= "function" or stack:is_empty() or
			type(stack.get_definition) ~= "function" then
		return nil, "wrong_family"
	end
	local definition = stack:get_definition()
	local item_groups = definition and definition.groups or {}
	local membership = item_groups[groups.membership]
	if type(membership) ~= "number" or membership ~= membership or
			membership <= 0 then
		return nil, "wrong_family"
	end
	local tier_value = item_groups[groups.tier]
	local tier = type(tier_value) == "number" and exact_tier(tier_value) or nil
	if not tier then
		return nil, "tier_unavailable"
	end
	return tier, "ok"
end

function grug_materials.tier_rock_description(tier)
	return "Stone\nRequires a T" .. tier .. " pick"
end

function grug_materials.resource_ore_description(resource)
	return resource.name .. " Ore\nRequires a T" .. resource.harvest_tier ..
		" pick"
end

function grug_materials.is_natural_node(node_name, def)
	def = def or core.registered_nodes[node_name]
	if not def or node_name == "air" or node_name == "ignore" or
		def.diggable == false or (def.liquidtype and def.liquidtype ~= "none") then
		return false
	end
	local groups = def.groups or {}
	return groups.grug_natural == 1 or groups.grug_resource ~= nil or
		groups.grug_stratum ~= nil
end

-- The pick tier a natural node needs: its stratum tier (default:stone is 1)
-- or its resource harvest tier. Loose ground and decorative rock need none.
function grug_materials.required_pick_tier(node_name, def)
	def = def or core.registered_nodes[node_name]
	local groups = def and def.groups or {}
	return exact_tier(groups.grug_stratum) or exact_tier(groups.grug_resource)
end

local function hand_capabilities()
	return ItemStack(""):get_tool_capabilities()
end

-- The engine's own dig rule for this stack: its capabilities first, then the
-- hand (src/client/game.cpp handleDigging, serverpackethandler.cpp
-- INTERACT_DIGGING_COMPLETED "If can't dig, try hand").
function grug_materials.stack_can_dig(stack, def)
	local groups = def and def.groups or {}
	if stack and not stack:is_empty() then
		local params = core.get_dig_params(groups, stack:get_tool_capabilities(),
			stack:get_wear())
		if params and params.diggable then return true end
	end
	local params = core.get_dig_params(groups, hand_capabilities())
	return params ~= nil and params.diggable == true
end

local function digger_name(digger)
	if digger and digger.is_player and digger:is_player() then
		return digger:get_player_name()
	end
	return ""
end

local function is_player(object)
	return object ~= nil and type(object.is_player) == "function" and
		object:is_player()
end

-- The full public decision is read-only. The authoritative dig wrapper owns
-- the one protection-violation record on an actual refused transaction.
function grug_materials.mining_decision(pos, node, digger)
	node = node or core.get_node(pos)
	local def = node and core.registered_nodes[node.name] or nil
	local result = {
		allowed = true,
		reason = "not_natural",
		natural = false,
		protected = false,
		protection_checked = false,
		node_name = node and node.name or nil,
		y = pos and pos.y or nil,
	}
	if not pos or not node or not grug_materials.is_natural_node(node.name, def) then
		return result
	end

	result.natural = true
	result.protection_checked = true
	local name = digger_name(digger)
	if core.is_protected(pos, name) then
		result.allowed = false
		result.reason = "protected"
		result.protected = true
		return result
	end

	local stack = digger and digger.get_wielded_item and digger:get_wielded_item()
	result.pick_tier = stack and grug_materials.pick_tier_for_stack(stack) or nil
	result.required_tier = grug_materials.required_pick_tier(node.name, def)
	local harvest_tier = exact_tier((def.groups or {}).grug_resource)
	if harvest_tier and harvest_tier > HARVEST_TIER_COUNT then
		harvest_tier = nil
	end
	result.resource_harvest_tier = harvest_tier
	if is_player(digger) and not grug_materials.stack_can_dig(stack, def) then
		result.allowed = false
		result.reason = result.required_tier and "too_hard" or "not_diggable"
		return result
	end
	result.reason = "allowed"
	return result
end

local harvest_callbacks = {}

function grug_materials.register_on_harvest(callback)
	if type(callback) ~= "function" then
		error("grug_materials.register_on_harvest expects a function")
	end
	harvest_callbacks[#harvest_callbacks + 1] = callback
end

local function settle_harvest(pos, node, digger, decision)
	local resource = grug_materials.resource_for_node(node.name)
	local event = {
		pos = vector.copy(pos),
		node = {name = node.name, param1 = node.param1, param2 = node.param2},
		digger = digger,
		player_name = digger_name(digger),
		resource = resource,
		resource_key = resource and resource.key or nil,
		raw_item = resource and resource.raw_item or nil,
		pick_tier = decision.pick_tier,
		harvest_tier = decision.resource_harvest_tier,
	}
	for _, callback in ipairs(harvest_callbacks) do
		callback(event)
	end
end

-- One-line hints (ruling 7). At most one line per player every 1.5 s, and the
-- same line at most every 5 s while a player keeps punching.
local HINT_INTERVAL_US = 1500000
local SAME_HINT_INTERVAL_US = 5000000
local last_hint = {}

local function hint_ready(name, now)
	local last = last_hint[name]
	return not last or now - last.at >= HINT_INTERVAL_US
end

function grug_materials.emit_hint(name, message)
	if not name or name == "" or not message then return false end
	local now = core.get_us_time()
	local last = last_hint[name]
	if last and (now - last.at < HINT_INTERVAL_US or
			(last.message == message and now - last.at < SAME_HINT_INTERVAL_US)) then
		return false
	end
	last_hint[name] = {at = now, message = message}
	core.chat_send_player(name, message)
	return true
end

-- The protection line names the reason when grug_core can tell it
-- (town, landmark, home territory); otherwise a plain "Protected".
function grug_materials.protection_hint(pos, name)
	local owner = rawget(_G, "grug_core")
	if owner and type(owner.protection_hint) == "function" then
		return owner.protection_hint(pos, name)
	end
	if core.is_protected(pos, name) then return "Protected" end
	return nil
end

function grug_materials.too_hard_hint(required_tier)
	return "Requires a T" .. required_tier .. " pick"
end

function grug_materials.emit_mining_failure(pos, digger, decision)
	local name = digger_name(digger)
	local message
	if decision.reason == "protected" then
		message = grug_materials.protection_hint(pos, name) or "Protected"
	elseif decision.reason == "too_hard" then
		message = grug_materials.too_hard_hint(decision.required_tier)
	end
	return grug_materials.emit_hint(name, message)
end

local function wields_skill(stack)
	local def = stack and stack:get_definition()
	return def ~= nil and ((def.groups or {}).grug_ability or 0) > 0
end

local function wields_broken(stack)
	local owner = rawget(_G, "grug_core")
	return stack ~= nil and owner ~= nil and
		type(owner.equipment_is_broken) == "function" and
		owner.equipment_is_broken(stack) == true
end

-- The hint a punch earns, or nil. A selected skill makes LMB on a node the
-- hand cannot dig a cast (classes.md 2b), so skills never produce a hint.
function grug_materials.punch_hint(pos, node, puncher)
	if not is_player(puncher) or not node then return nil end
	local def = core.registered_nodes[node.name]
	if not def or def.diggable == false then return nil end
	local stack = puncher:get_wielded_item()
	if wields_skill(stack) then return nil end
	local name = puncher:get_player_name()
	local protected = grug_materials.protection_hint(pos, name)
	if protected then return protected end
	local required = grug_materials.required_pick_tier(node.name, def)
	if required and not wields_broken(stack) and
			not grug_materials.stack_can_dig(stack, def) then
		return grug_materials.too_hard_hint(required)
	end
	return nil
end

-- The client sends a punch (INTERACT_START_DIGGING) when it starts digging a
-- node even if it predicts the node as undiggable (game.cpp handleDigging),
-- so the server can answer both a protected and a too-hard node here.
core.register_on_punchnode(function(pos, node, puncher)
	if not is_player(puncher) then return end
	local name = puncher:get_player_name()
	if not hint_ready(name, core.get_us_time()) then return end
	local message = grug_materials.punch_hint(pos, node, puncher)
	if message then grug_materials.emit_hint(name, message) end
end)

core.register_on_leaveplayer(function(player)
	last_hint[player:get_player_name()] = nil
end)

local builtin_node_dig = core.node_dig

local function node_dig(pos, node, digger)
	local def = node and core.registered_nodes[node.name] or nil
	if not node or not grug_materials.is_natural_node(node.name, def) then
		return builtin_node_dig(pos, node, digger)
	end
	local decision = grug_materials.mining_decision(pos, node, digger)
	if not decision.allowed then
		if decision.reason == "protected" then
			core.record_protection_violation(pos, digger_name(digger))
		end
		grug_materials.emit_mining_failure(pos, digger, decision)
		return false
	end
	local dug = builtin_node_dig(pos, node, digger)
	if dug and decision.resource_harvest_tier then
		settle_harvest(pos, node, digger, decision)
	end
	return dug
end

grug_materials.node_dig_wrapper = node_dig
core.node_dig = node_dig
