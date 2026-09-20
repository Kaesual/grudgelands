-- Quoting is read-only. Each quote is server-owned and single-use, bound to
-- an exact provider and exact ItemStacks (including all metadata and wear).
local provider_types = {}
local live_quotes = setmetatable({}, {__mode = "k"})

function grug_repair.eligible(stack)
	if not stack or stack:is_empty() then return false end
	local groups = (stack:get_definition() or {}).groups or {}
	for _, group in ipairs({"grug_equip_weapon", "grug_shield", "grug_spellbook", "grug_quiver",
		"grug_equip_head", "grug_equip_chest", "grug_equip_legs", "grug_equip_feet",
		"pickaxe", "axe", "shovel", "hoe"}) do
		if (groups[group] or 0) > 0 then return true end
	end
	return false
end

function grug_repair.cost(stack)
	if not grug_repair.eligible(stack) then return nil end
	local price = grug_gear.reference_purchase_price(stack)
	if not price or price <= 0 then return nil, "This item's repair price is unavailable." end
	return math.ceil(price * stack:get_wear() / (5 * 65535))
end

-- Future Housing registers a station provider here. Merely placing a
-- crafting station does not grant access to a city repair service.
function grug_repair.register_provider(kind, permitted)
	assert(type(kind) == "string" and not provider_types[kind])
	assert(type(permitted) == "function")
	provider_types[kind] = permitted
end

function grug_repair.provider_permitted(player, provider)
	if not player or not player:is_player() or player:get_hp() <= 0 or
			type(provider) ~= "table" then return false end
	local validate = provider_types[provider.kind]
	return validate and validate(player, provider) == true or false
end

local function owned_lists()
	local lists = {"main"}
	for _, slot in ipairs(grug_inventory.equipment_slots) do
		lists[#lists + 1] = slot.list
	end
	for i = 1, grug_inventory.BAG_COUNT do
		lists[#lists + 1] = grug_inventory.content_list(i)
	end
	return lists
end

function grug_repair.quote(player, provider, only_list, only_index)
	if not grug_repair.provider_permitted(player, provider) then
		return nil, "The repair service is no longer available."
	end
	local quote = {owner = player:get_player_name(), provider = provider,
		items = {}, total = 0}
	local inv = player:get_inventory()
	for _, list in ipairs(owned_lists()) do
		if not only_list or only_list == list then
			for index, stack in ipairs(inv:get_list(list) or {}) do
				if (not only_index or only_index == index) and
						grug_repair.eligible(stack) and stack:get_wear() > 0 then
					local price, reason = grug_repair.cost(stack)
					if not price then return nil, reason end
					quote.items[#quote.items + 1] = {list = list, index = index,
						expected = ItemStack(stack), price = price}
					quote.total = quote.total + price
				end
			end
		end
	end
	live_quotes[quote] = true
	return quote
end

function grug_repair.apply(player, quote)
	if not quote or not live_quotes[quote] then return false, "Request a new repair quote." end
	-- Consume before any money/equipment callback can re-enter the service.
	live_quotes[quote] = nil
	if quote.owner ~= player:get_player_name() or
			not grug_repair.provider_permitted(player, quote.provider) then
		return false, "The repair service is no longer available."
	end
	local changes, equipment = {}, false
	for _, row in ipairs(quote.items) do
		local stack = ItemStack(row.expected)
		stack:set_wear(0)
		local meta = stack:get_meta()
		meta:set_int("_grug_wear_remainder", 0)
		local encoded = meta:get_string("_grug_repair_caps")
		local saved = encoded ~= "" and core.deserialize(encoded) or nil
		if encoded ~= "" and meta.set_tool_capabilities then
			meta:set_tool_capabilities(type(saved) == "table" and saved or nil)
		end
		meta:set_string("_grug_repair_caps", "")
		changes[#changes + 1] = {list = row.list, index = row.index,
			expected = row.expected, replacement = stack}
		if grug_inventory.is_equipment_list(row.list) then equipment = true end
	end
	local ok, reason = grug_money.take_with_inventory(player, quote.total, changes)
	if not ok then return false, reason end
	if equipment then grug_inventory.equipment_changed(player) end
	return true, #changes == 0 and "Nothing needs repair." or
		("Repaired " .. #changes .. " item(s) for " .. grug_money.format(quote.total) .. ".")
end

function grug_repair.single_quote(quote, index)
	if not live_quotes[quote] or not quote.items[index] then return nil end
	local row = quote.items[index]
	local single = {owner = quote.owner, provider = quote.provider,
		items = {row}, total = row.price}
	live_quotes[single] = true
	return single
end
