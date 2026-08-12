-- Server-authoritative natural-depth and resource-harvest transaction (WP43).

local TIER_COUNT = #grug_materials.TIERS
local HARVEST_TIER_COUNT = 5

grug_materials.SHORTFALL_MULTIPLIERS = {
	[0] = 1,
	[1] = 4,
	[2] = 6,
	[3] = 8,
	[4] = 10,
}

-- Provisional WP43 profiles. They make all six progression tiers mechanically
-- complete without registering WP29's final gear catalog. WP22 owns the later
-- speed/durability calibration; consumers should build capabilities from this
-- table instead of copying its values.
grug_materials.PICK_PROFILES = {
	[1] = {tier = 1, key = "bronze", ordinary_time = 0.45, uses = 180,
		cracky_times = {[1] = 2.25, [2] = 0.90, [3] = 0.45}},
	[2] = {tier = 2, key = "iron", ordinary_time = 0.425, uses = 180,
		cracky_times = {[1] = 2.125, [2] = 0.85, [3] = 0.425}},
	[3] = {tier = 3, key = "steel", ordinary_time = 0.40, uses = 180,
		cracky_times = {[1] = 2.00, [2] = 0.80, [3] = 0.40}},
	[4] = {tier = 4, key = "silversteel", ordinary_time = 0.35, uses = 240,
		cracky_times = {[1] = 1.75, [2] = 0.70, [3] = 0.35}},
	[5] = {tier = 5, key = "embersteel", ordinary_time = 0.30, uses = 300,
		cracky_times = {[1] = 1.50, [2] = 0.60, [3] = 0.30}},
	[6] = {tier = 6, key = "abyssal_steel", ordinary_time = 0.25, uses = 360,
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

local function resource_times(pick_tier, ordinary_time)
	local times = {}
	for harvest_tier = 1, HARVEST_TIER_COUNT do
		local shortfall = math.max(0, harvest_tier - pick_tier)
		local multiplier = grug_materials.SHORTFALL_MULTIPLIERS[shortfall] or 10
		times[harvest_tier] = ordinary_time * multiplier
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
	values = values or profile
	local ordinary_time = tonumber(values.ordinary_time)
	local uses = tonumber(values.uses)
	if not ordinary_time or ordinary_time <= 0 or not uses or uses <= 0 then
		error("grug_materials: invalid pick capability values")
	end
	return {
		full_punch_interval = values.full_punch_interval or 1.0,
		max_drop_level = 0,
		groupcaps = {
			cracky = {times = copy_times(values.cracky_times), uses = uses,
				maxlevel = 0},
			grug_resource = {times = resource_times(tier, ordinary_time),
				uses = uses, maxlevel = 0},
		},
		damage_groups = table.copy(values.damage_groups or {fleshy = 4}),
	}
end

function grug_materials.pick_tier_for_stack(stack)
	if not stack or stack:is_empty() then
		return nil
	end
	local def = stack:get_definition()
	return exact_tier(def and (def.groups or {}).grug_pick_tier)
end

function grug_materials.can_mine_natural_at(pick_tier, y)
	pick_tier = exact_tier(pick_tier)
	y = tonumber(y)
	local required_tier = y and grug_materials.tier_at(y) or nil
	local max_depth = pick_tier and
		grug_materials.max_depth_for_pick_tier(pick_tier) or nil
	local allowed = pick_tier ~= nil and y ~= nil and y >= max_depth
	return allowed, {
		allowed = allowed,
		reason = allowed and "allowed" or (pick_tier and "depth" or "no_pick"),
		pick_tier = pick_tier,
		depth_required_tier = required_tier,
		max_depth = max_depth,
		y = y,
	}
end

local function same_pos(a, b)
	return a and b and a.x == b.x and a.y == b.y and a.z == b.z
end

function grug_materials.is_natural_node(node_name, def)
	def = def or core.registered_nodes[node_name]
	if not def or node_name == "air" or node_name == "ignore" or
		def.diggable == false or (def.liquidtype and def.liquidtype ~= "none") then
		return false
	end
	local groups = def.groups or {}
	return groups.grug_natural == 1 or def.is_ground_content == true
end

local function digger_name(digger)
	if digger and digger.is_player and digger:is_player() then
		return digger:get_player_name()
	end
	return ""
end

-- The full public decision is deliberately side-effect free except for the
-- normal protection-violation record required by the engine contract.
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
		shatter = false,
		shortfall = 0,
		multiplier = 1,
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
		core.record_protection_violation(pos, name)
		return result
	end

	local stack = digger and digger.get_wielded_item and digger:get_wielded_item()
	local pick_tier = grug_materials.pick_tier_for_stack(stack)
	local depth_allowed, depth = grug_materials.can_mine_natural_at(
		pick_tier, pos.y)
	result.pick_tier = pick_tier
	result.depth_required_tier = depth.depth_required_tier
	result.max_depth = depth.max_depth
	result.depth_allowed = depth_allowed
	if not pick_tier then
		result.allowed = false
		result.reason = "no_pick"
		return result
	end
	if not depth_allowed then
		result.allowed = false
		result.reason = "depth"
		return result
	end

	local harvest_tier = exact_tier((def.groups or {}).grug_resource)
	if harvest_tier and harvest_tier > HARVEST_TIER_COUNT then
		harvest_tier = nil
	end
	result.resource_harvest_tier = harvest_tier
	if harvest_tier then
		result.shortfall = math.max(0, harvest_tier - pick_tier)
		result.multiplier = grug_materials.SHORTFALL_MULTIPLIERS[result.shortfall] or 10
		result.shatter = result.shortfall > 0
	end
	result.reason = result.shatter and "shatter" or "allowed"
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

function grug_materials.emit_shatter_feedback(pos, digger, decision)
	core.sound_play("default_break_glass", {
		pos = pos,
		gain = 0.7,
		max_hear_distance = 12,
	}, true)
	local name = digger_name(digger)
	if name ~= "" then
		core.chat_send_player(name, "The resource shatters: a tier " ..
			decision.resource_harvest_tier .. " pick is required to recover it.")
	end
end

local active_shatter

function grug_materials.is_shattering(player, pos)
	if not active_shatter then
		return false
	end
	if player and player ~= active_shatter.digger and
		(type(player) ~= "string" or player ~= active_shatter.player_name) then
		return false
	end
	return not pos or same_pos(pos, active_shatter.pos)
end

local builtin_node_dig = core.node_dig

local function call_without_drops(pos, node, digger, decision)
	local previous_handle_node_drops = core.handle_node_drops
	local previous_active_shatter = active_shatter
	local transaction = {
		pos = vector.copy(pos),
		digger = digger,
		player_name = digger_name(digger),
		decision = decision,
	}
	active_shatter = transaction
	core.handle_node_drops = function(drop_pos, drops, drop_digger)
		if same_pos(drop_pos, transaction.pos) and drop_digger == transaction.digger then
			return
		end
		return previous_handle_node_drops(drop_pos, drops, drop_digger)
	end
	local ok, result = pcall(builtin_node_dig, pos, node, digger)
	core.handle_node_drops = previous_handle_node_drops
	active_shatter = previous_active_shatter
	if not ok then
		error(result, 0)
	end
	return result
end

local function node_dig(pos, node, digger)
	local def = node and core.registered_nodes[node.name] or nil
	if not node or not grug_materials.is_natural_node(node.name, def) then
		return builtin_node_dig(pos, node, digger)
	end
	local decision = grug_materials.mining_decision(pos, node, digger)
	if not decision.allowed then
		return false
	end

	local dug
	if decision.shatter then
		dug = call_without_drops(pos, node, digger, decision)
	else
		dug = builtin_node_dig(pos, node, digger)
	end
	if not dug then
		return dug
	end
	if decision.shatter then
		grug_materials.emit_shatter_feedback(pos, digger, decision)
	elseif decision.resource_harvest_tier then
		settle_harvest(pos, node, digger, decision)
	end
	return dug
end

grug_materials.node_dig_wrapper = node_dig
core.node_dig = node_dig
