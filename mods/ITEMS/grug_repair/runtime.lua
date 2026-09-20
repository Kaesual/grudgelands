local WEAR_REMAINDER = "_grug_wear_remainder"
local ACTION_LIMIT = 256
local settled = {}
local ITEM_ID = "_grug_repair_item_id"
local storage = core.get_mod_storage()

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
	local def = stack:get_definition() or {}
	local tier = tonumber(def._grug_bracket or def._grug_tier) or 1
	return ({1000, 1500, 2000, 2500, 3000, 4000})[tier] or 4000
end

local function wear_stack(player, list, index)
	if creative(player) then return false end
	local inv = player:get_inventory()
	local stack = inv:get_stack(list, index)
	if not grug_repair.eligible(stack) or grug_core.equipment_is_broken(stack) then
		return false
	end
	local meta = stack:get_meta()
	local lifetime = combat_lifetime(stack)
	local amount = meta:get_int(WEAR_REMAINDER) + 65535
	local whole = math.floor(amount / lifetime)
	meta:set_int(WEAR_REMAINDER, amount % lifetime)
	stack:set_wear(math.min(65535, stack:get_wear() + whole))
	disable_broken_operation(stack)
	inv:set_stack(list, index, stack)
	if grug_inventory.is_equipment_list(list) then
		grug_inventory.equipment_changed(player, list, "durability_metadata")
	end
	return true
end

-- Captured projectiles carry a stable string id; synchronous accepted actions
-- use their opaque table itself, shared by damage/heal/absorb/cleave results.
local function remember(player, action_id)
	local key = type(action_id) == "table" and (action_id.id or action_id) or action_id
	if key == nil then return false end
	local name = player:get_player_name()
	local state = settled[name]
	if not state then state = {order = {}, ids = {}}; settled[name] = state end
	if state.ids[key] then return false end
	state.ids[key] = true
	state.order[#state.order + 1] = key
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
	local rows = type(action_id) == "table" and action_id.item_ids or nil
	if rows then
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

end

function grug_repair.capture_action(player, action_id)
	assert(type(action_id) == "string" and action_id ~= "",
		"captured durability action requires a string id")
	local rows = {}
	local inv = player:get_inventory()
	for _, list in ipairs({"grug_weapon"}) do
		local stack = inv:get_stack(list, 1)
		local allowed = grug_repair.eligible(stack)
		if allowed then
			local meta = stack:get_meta()
			local id = meta:get_string(ITEM_ID)
			if id == "" then
				local serial = tonumber(storage:get_string("item_serial")) or 0
				serial = serial + 1
				storage:set_string("item_serial", tostring(serial))
				id = "repair:" .. tostring(serial)
				meta:set_string(ITEM_ID, id)
				inv:set_stack(list, 1, stack)
				grug_inventory.equipment_changed(player, list,
					"durability_metadata")
			end
			rows[#rows + 1] = id
		end
	end
	return {id = action_id, item_ids = rows}
end

function grug_repair.cancel_action(player, action_id)
	-- Capture receipts are inert values until settlement.
end

function grug_repair.settle_captured_action(player, receipt, kind)
	grug_core.run_settled_outgoing_action(player, receipt, kind)
end

grug_core.register_on_settled_outgoing_action(function(player, action_id, kind)
	if kind == "absorb" then return end
	grug_repair.wear_outgoing(player, action_id)
end)

grug_core.register_on_settled_incoming_hit(function(player)
	if creative(player) then return end
	local candidates = {}
	local inv = player:get_inventory()
	for _, list in ipairs({"grug_head", "grug_chest", "grug_legs", "grug_feet", "grug_offhand"}) do
		local stack = inv:get_stack(list, 1)
		if grug_repair.eligible(stack) and not grug_core.equipment_is_broken(stack) then
			candidates[#candidates + 1] = list
		end
	end
	if #candidates > 0 then wear_stack(player, candidates[math.random(#candidates)], 1) end
end)

core.register_on_leaveplayer(function(player)
	settled[player:get_player_name()] = nil
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
				local on_use = def.on_use
				if on_use then
					core.override_item(name, {on_use = function(stack, user, pointed)
						if grug_core.equipment_is_broken(stack) then return stack end
						return on_use(stack, user, pointed) or stack
					end})
				end
				local original = def.after_use
				core.override_item(name, {after_use = function(stack, user, node, digparams)
					if grug_core.equipment_is_broken(stack) then return stack end
					if original then
						stack = original(stack, user, node, digparams) or stack
					elseif not core.is_creative_enabled(user:get_player_name()) then
						local uses = def._grug_tool_uses
						if uses and (digparams.wear or 0) > 0 then
							local meta = stack:get_meta()
							local amount = meta:get_int(WEAR_REMAINDER) + 65535
							meta:set_int(WEAR_REMAINDER, amount % uses)
							stack:set_wear(math.min(65535, stack:get_wear() + math.floor(amount / uses)))
						else
							stack:set_wear(math.min(65535,
								stack:get_wear() + (digparams.wear or 0)))
						end
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
