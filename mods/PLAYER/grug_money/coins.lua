-- The Bag of Coins (Round 34 ruling 4; BACKLOG "Money withdraw and
-- deposit"): money taken out of the balance into an item, so players can
-- give money to each other. Withdraw on the Character page through a small
-- dialog; a deposit slot on the Inventory page destroys a bag and credits it.
-- The amount lives in the item's meta, one bag per stack. Traders neither
-- sell it nor buy it (it has no price class, so grug_traders pays 0 and the
-- sell path refuses it). No log line for transfers (user ruling); a dropped
-- bag despawns like any item.

local BAG = "grug_money:bag_of_coins"
local AMOUNT_KEY = "grug_money:bag_copper"
local DEPOSIT_LIST = "deposit"
local WITHDRAW_FORM = "grug_money:withdraw"
grug_money.BAG = BAG

local COPPER_PER_SILVER = 100
local COPPER_PER_GOLD = 100 * COPPER_PER_SILVER

core.register_craftitem(BAG, {
	description = "Bag of Coins",
	inventory_image = "grug_money_bag_of_coins.png",
	stack_max = 1,
	groups = {not_in_creative_inventory = 1},
})

-- A Bag of Coins holding `copper` (a whole number of at least 1).
function grug_money.make_bag(copper)
	local stack = ItemStack(BAG)
	local meta = stack:get_meta()
	meta:set_int(AMOUNT_KEY, copper)
	meta:set_string("description", "Bag of Coins\nContains " .. grug_money.format(copper))
	return stack
end

-- The copper a stack holds: 0 for anything that is not a filled bag.
function grug_money.bag_amount(stack)
	if not stack or stack:get_name() ~= BAG then return 0 end
	return math.max(0, stack:get_meta():get_int(AMOUNT_KEY))
end

-- The withdraw dialog's three fields as copper, or nil and a reason. Each
-- field is empty or a whole number of at least 0; the sum is at least 1.
function grug_money.parse_amount(gold, silver, copper)
	local total = 0
	for _, row in ipairs({{gold, COPPER_PER_GOLD}, {silver, COPPER_PER_SILVER},
			{copper, 1}}) do
		local text = tostring(row[1] or ""):trim()
		if text ~= "" then
			if not text:match("^%d+$") then
				return nil, "Enter whole numbers of gold, silver and copper."
			end
			total = total + tonumber(text) * row[2]
		end
	end
	if total < 1 then return nil, "Enter an amount of at least 1 copper." end
	return total
end

-- Takes `copper` from the balance and puts one bag with it into the first
-- empty main slot, in one transaction (grug_money.take_with_inventory).
-- Returns true, or false and a reason.
function grug_money.withdraw(player, copper)
	if type(copper) ~= "number" or copper ~= copper or copper % 1 ~= 0 or copper < 1 then
		return false, "Enter an amount of at least 1 copper."
	end
	if copper > grug_money.get(player) then
		return false, "You do not have that much money."
	end
	local inventory = player:get_inventory()
	for index = 1, inventory:get_size("main") do
		local current = inventory:get_stack("main", index)
		if current:is_empty() then
			local ok = grug_money.take_with_inventory(player, copper, {{list = "main",
				index = index, expected = current, replacement = grug_money.make_bag(copper)}})
			if ok then return true end
			return false, "The inventory changed. Try again."
		end
	end
	return false, "Your inventory is full."
end

-- How much of `stack` the deposit slot accepts from `player`: 1 for a bag
-- whose amount fits the balance, else 0 and a reason.
function grug_money.deposit_allowed(player, stack)
	if not stack or stack:get_name() ~= BAG then
		return 0, "Only a Bag of Coins can be deposited."
	end
	local copper = grug_money.bag_amount(stack)
	if copper < 1 then return 0, "This Bag of Coins is empty." end
	if grug_money.get(player) + copper > grug_money.MAX then
		return 0, "You cannot carry that much money."
	end
	return 1
end

--
-- The deposit slot: one detached list per player, shown only to that
-- player. A bag put there is destroyed and credited at once, so the list is
-- always empty and nothing can be taken from it.
--

local function deposit_name(name) return "grug_money_deposit_" .. name end

-- The list[] location of the player's deposit slot, for the Inventory page.
function grug_money.deposit_location(player)
	return "detached:" .. deposit_name(player:get_player_name()), DEPOSIT_LIST
end

core.register_on_joinplayer(function(player)
	local owner = player:get_player_name()
	local inventory = core.create_detached_inventory(deposit_name(owner), {
		allow_put = function(_, _, _, stack, actor)
			if not actor or actor:get_player_name() ~= owner then return 0 end
			local count, reason = grug_money.deposit_allowed(actor, stack)
			if count == 0 then grug_core.feed(actor, "notice", reason, "grug_money_bag") end
			return count
		end,
		allow_take = function() return 0 end,
		allow_move = function() return 0 end,
		on_put = function(inv, listname, index, stack, actor)
			local copper = grug_money.bag_amount(stack)
			inv:set_stack(listname, index, ItemStack(""))
			grug_money.add(actor, copper)
			grug_sounds.play("money", actor)
			grug_core.feed(actor, "notice", "Deposited " .. grug_money.format(copper) .. ".",
				"grug_money_bag")
		end,
	}, owner)
	inventory:set_size(DEPOSIT_LIST, 1)
end)

core.register_on_leaveplayer(function(player)
	core.remove_detached_inventory(deposit_name(player:get_player_name()))
end)

--
-- The withdraw dialog
--

local function esc(text) return core.formspec_escape(tostring(text or "")) end

function grug_money.show_withdraw(player, fields, message)
	fields = fields or {}
	local fs = {
		"size[6.4,4.3]",
		"label[0.3,0.2;Withdraw into a Bag of Coins]",
		("label[0.3,0.7;Balance: %s]"):format(esc(grug_money.format(grug_money.get(player)))),
		("field[0.6,1.9;1.7,0.8;grug_money_gold;Gold;%s]"):format(esc(fields.grug_money_gold)),
		("field[2.4,1.9;1.7,0.8;grug_money_silver;Silver;%s]"):format(esc(fields.grug_money_silver)),
		("field[4.2,1.9;1.7,0.8;grug_money_copper;Copper;%s]"):format(esc(fields.grug_money_copper)),
		"field_close_on_enter[grug_money_gold;false]",
		"field_close_on_enter[grug_money_silver;false]",
		"field_close_on_enter[grug_money_copper;false]",
		"button[0.3,3.3;2.2,0.7;grug_money_confirm;Withdraw]",
		"button[2.7,3.3;1.6,0.7;grug_money_cancel;Cancel]",
	}
	if message then
		fs[#fs + 1] = ("label[0.3,2.55;%s]"):format(esc(core.colorize("#ff9a7a", message)))
	end
	core.show_formspec(player:get_player_name(), WITHDRAW_FORM, table.concat(fs))
end

local function back_to_inventory(player)
	local name = player:get_player_name()
	core.show_formspec(name, "", player:get_inventory_formspec())
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= WITHDRAW_FORM then return false end
	if fields.grug_money_cancel then
		back_to_inventory(player)
	elseif fields.grug_money_confirm or fields.key_enter then
		local copper, reason = grug_money.parse_amount(fields.grug_money_gold,
			fields.grug_money_silver, fields.grug_money_copper)
		local ok = false
		if copper then ok, reason = grug_money.withdraw(player, copper) end
		if ok then
			grug_core.feed(player, "notice", "Withdrew " .. grug_money.format(copper) ..
				" into a Bag of Coins.", "grug_money_bag")
			back_to_inventory(player)
		else
			grug_money.show_withdraw(player, fields, reason)
		end
	end
	return true
end)
