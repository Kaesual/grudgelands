local WEAR_REMAINDER = "_grug_wear_remainder"
local ACTION_LIMIT = 256
local settled = {}
local captured = {}
local item_serial = 0
local ITEM_ID = "_grug_repair_item_id"

local function disable_broken_operation(stack)
	if stack:get_wear() < 65535 then return end
	local meta = stack:get_meta()
	if meta:get_string("_grug_repair_caps") == "" then
		meta:set_string("_grug_repair_caps",
			core.serialize(stack:get_tool_capabilities()))
	end
	meta:set_tool_capabilities({full_punch_interval = 1.4,
		damage_groups = {fleshy = 0}, groupcaps = {}, punch_attack_uses = 0})
end

local function creative(player)
	return core.is_creative_enabled(player:get_player_name())
end

local function combat_lifetime(stack)
	return stack:get_meta():get_int("grug_refined") == 1 and 6000 or 3000
end

local function wear_stack(player, list, index)
	if creative(player) then return false end
	local inv = player:get_inventory()
	local stack = inv:get_stack(list, index)
	if not grug_repair.eligible(stack) or grug_core.equipment_is_broken(stack) then
		return false
	end
	local meta = stack:get_meta()
	local amount = tonumber(meta:get_string(WEAR_REMAINDER)) or 0
	amount = amount + 65535 / combat_lifetime(stack)
	local whole = math.floor(amount)
	meta:set_string(WEAR_REMAINDER, tostring(amount - whole))
	stack:set_wear(math.min(65535, stack:get_wear() + whole))
	disable_broken_operation(stack)
	inv:set_stack(list, index, stack)
	if grug_inventory.is_equipment_list(list) then
		grug_inventory.equipment_changed(player, list)
	end
	return true
end

local function remember(player, action_id)
	local name = player:get_player_name()
	local state = settled[name]
	if not state then state = {order = {}, ids = {}}; settled[name] = state end
	if state.ids[action_id] then return false end
	state.ids[action_id] = true
	state.order[#state.order + 1] = action_id
	if #state.order > ACTION_LIMIT then
		state.ids[table.remove(state.order, 1)] = nil
	end
	return true
end

-- Current synchronous actions wear the concrete equipped slots. Delayed
-- projectiles must publish one shared action id before allowing a weapon swap;
-- SCOUT uses capture_action/settle_captured_action below for that case.
function grug_repair.wear_outgoing(player, action_id)
	if not remember(player, action_id) then return false end
	local by_player = captured[player:get_player_name()]
	local rows = by_player and by_player[action_id]
	if rows then
		by_player[action_id] = nil
		local inv = player:get_inventory()
		local lists = {"grug_weapon", "grug_offhand", "main"}
		for bag = 1, grug_inventory.BAG_COUNT do
			lists[#lists + 1] = grug_inventory.content_list(bag)
		end
		for _, row in ipairs(rows) do
			local found = false
			for _, list in ipairs(lists) do
				for index, stack in ipairs(inv:get_list(list) or {}) do
					if stack:get_meta():get_string(ITEM_ID) == row then
						wear_stack(player, list, index)
						found = true
						break
					end
				end
				if found then break end
			end
		end
		return true
	end
	wear_stack(player, "grug_weapon", 1)
	local offhand = player:get_inventory():get_stack("grug_offhand", 1)
	if core.get_item_group(offhand:get_name(), "grug_spellbook") > 0 then
		wear_stack(player, "grug_offhand", 1)
	end
	return true
end

function grug_repair.capture_action(player, action_id)
	local rows = {}
	local inv = player:get_inventory()
	for _, list in ipairs({"grug_weapon", "grug_offhand"}) do
		local stack = inv:get_stack(list, 1)
		local allowed = list == "grug_weapon" and grug_repair.eligible(stack) or
			core.get_item_group(stack:get_name(), "grug_spellbook") > 0
		if allowed then
			local meta = stack:get_meta()
			local id = meta:get_string(ITEM_ID)
			if id == "" then
				item_serial = item_serial + 1
				id = player:get_player_name() .. ":" .. tostring(item_serial)
				meta:set_string(ITEM_ID, id)
				inv:set_stack(list, 1, stack)
				grug_inventory.equipment_changed(player, list)
			end
			rows[#rows + 1] = id
		end
	end
	local name = player:get_player_name()
	captured[name] = captured[name] or {}
	local state = captured[name]
	state[action_id] = rows
	local count = 0
	for id in pairs(state) do
		count = count + 1
		if count > ACTION_LIMIT then state[id] = nil; break end
	end
end

function grug_repair.cancel_action(player, action_id)
	local state = captured[player:get_player_name()]
	if state then state[action_id] = nil end
end

grug_core.register_on_settled_outgoing_action(function(player, action_id)
	grug_repair.wear_outgoing(player, action_id)
end)

grug_core.register_on_effective_heal(function(healer, target, amount)
	if healer and healer:is_player() and amount > 0 and
			grug_core.in_combat(healer) then
		grug_core.run_settled_outgoing_action(healer, {}, "heal")
	end
end)

grug_core.register_on_effective_absorb(function(source, target, amount)
	if source and source:is_player() and amount > 0 and
			grug_core.in_combat(source) then
		grug_core.run_settled_outgoing_action(source, {}, "absorb")
	end
end)

grug_core.register_on_settled_incoming_hit(function(player)
	if creative(player) then return end
	for _, list in ipairs({"grug_head", "grug_chest", "grug_legs", "grug_feet"}) do
		wear_stack(player, list, 1)
	end
	local offhand = player:get_inventory():get_stack("grug_offhand", 1)
	if core.get_item_group(offhand:get_name(), "grug_shield") > 0 then
		wear_stack(player, "grug_offhand", 1)
	end
end)

core.register_on_leaveplayer(function(player)
	settled[player:get_player_name()] = nil
	captured[player:get_player_name()] = nil
end)

core.register_on_mods_loaded(function()
	local missing = {}
	for name, def in pairs(core.registered_items) do
		local probe = ItemStack(name)
		if grug_repair.eligible(probe) then
			if not grug_gear.reference_purchase_price(probe) then
				missing[#missing + 1] = name
			end
			if def.type == "tool" then
				local original = def.after_use
				core.override_item(name, {after_use = function(stack, user, node, digparams)
					if grug_core.equipment_is_broken(stack) then return stack end
					if original then
						stack = original(stack, user, node, digparams) or stack
					elseif not core.is_creative_enabled(user:get_player_name()) then
						stack:set_wear(math.min(65535,
							stack:get_wear() + (digparams.wear or 0)))
					end
					disable_broken_operation(stack)
					return stack
				end})
			end
		end
	end
	table.sort(missing)
	assert(#missing == 0, "repair price catalog missing: " .. table.concat(missing, ", "))
end)
