grug_money = {}

-- Money is ONE integer in copper units in player meta (economy.md §1):
-- 100c = 1s, 100s = 1g. The conversion is display-only, there are no
-- physical coin items.
grug_money.KEY = "grug_money:copper"

-- Upper clamp. PlayerMetaRef stores ints as 32-bit signed values, so
-- anything above this would wrap around on save.
grug_money.MAX = 2147483647

local COPPER_PER_SILVER = 100
local COPPER_PER_GOLD = 100 * COPPER_PER_SILVER

--
-- Helpers
--

-- Invalid/removed ObjectRefs answer false here (engine: l_is_player
-- returns false when the object is gone), so this one check covers nil
-- refs, mob refs and stale player refs alike.
local function is_player(player)
	return player ~= nil and player.is_player ~= nil and player:is_player()
end

-- Sanitizes any input into a storable copper amount: integer, [0, MAX].
local function clamp(copper)
	copper = tonumber(copper)
	if not copper or copper ~= copper then -- nil or NaN
		return 0
	end
	if copper < 0 then
		return 0
	end
	if copper > grug_money.MAX then
		return grug_money.MAX
	end
	return math.floor(copper)
end

--
-- Display
--

-- Leading zero units are omitted, copper is always shown, interior zero
-- units are kept: 5 -> "5c", 100 -> "1s 0c", 10005 -> "1g 0s 5c".
function grug_money.format(copper)
	copper = tonumber(copper)
	if not copper or copper ~= copper or copper < 0 then
		return "0c"
	end
	copper = math.floor(copper)
	local gold = math.floor(copper / COPPER_PER_GOLD)
	local rest = copper - gold * COPPER_PER_GOLD
	local silver = math.floor(rest / COPPER_PER_SILVER)
	local coppers = rest - silver * COPPER_PER_SILVER
	if gold > 0 then
		return ("%dg %ds %dc"):format(gold, silver, coppers)
	elseif silver > 0 then
		return ("%ds %dc"):format(silver, coppers)
	end
	return ("%dc"):format(coppers)
end

--
-- API
--

local change_callbacks = {}

-- func(player, old_copper, new_copper) — called after every actual
-- balance change (not called when a mutation leaves the value untouched).
function grug_money.register_on_change(func)
	if type(func) == "function" then
		table.insert(change_callbacks, func)
	end
end

local hud_update -- forward (defined below)

function grug_money.get(player)
	if not is_player(player) then
		return 0
	end
	return player:get_meta():get_int(grug_money.KEY)
end

function grug_money.set(player, copper)
	if not is_player(player) then
		return
	end
	copper = clamp(copper)
	local meta = player:get_meta()
	local old = meta:get_int(grug_money.KEY)
	if old == copper then
		return
	end
	meta:set_int(grug_money.KEY, copper)
	for _, func in ipairs(change_callbacks) do
		func(player, old, copper)
	end
	hud_update(player)
end

-- Negative amounts subtract; the balance clamps at 0 and at MAX.
-- Returns the new balance.
function grug_money.add(player, copper)
	if not is_player(player) then
		return 0
	end
	copper = tonumber(copper)
	if not copper or copper ~= copper then
		return grug_money.get(player)
	end
	local new_balance = clamp(grug_money.get(player) + math.floor(copper))
	grug_money.set(player, new_balance)
	return new_balance
end

-- Atomic withdrawal: on an insufficient balance nothing changes at all
-- and no callback fires. Returns whether the money was taken.
function grug_money.take(player, copper)
	if not is_player(player) then
		return false
	end
	copper = tonumber(copper)
	if not copper or copper ~= copper or copper < 0 then
		return false
	end
	copper = math.floor(copper)
	local balance = grug_money.get(player)
	if balance < copper then
		return false
	end
	grug_money.set(player, balance - copper)
	return true
end

-- One synchronous purchase of in-place inventory changes. Unlike `take`,
-- callbacks are delayed until BOTH the inventory and ledger are committed.
-- ItemStack:equals compares metadata independently of serialization order
-- (pinned lua_api.md:8650); itemstring equality is not an exact-stack test.
function grug_money.take_with_inventory(player, copper, changes)
	if not is_player(player) or type(copper) ~= "number" or copper ~= copper or
			copper < 0 or copper > grug_money.MAX or copper % 1 ~= 0 or
			type(changes) ~= "table" then return false, "Invalid purchase." end
	local inventory = player:get_inventory()
	local balance = grug_money.get(player)
	if balance < copper then return false, "You do not have enough money." end
	local seen = {}
	for _, row in ipairs(changes) do
		if type(row.list) ~= "string" or type(row.index) ~= "number" or
				row.index % 1 ~= 0 or row.index < 1 or
				row.index > inventory:get_size(row.list) or
				not row.expected or not row.replacement then
			return false, "The inventory changed. Request a new quote."
		end
		local key = row.list .. ":" .. row.index
		if seen[key] or not inventory:get_stack(row.list, row.index):equals(row.expected) then
			return false, "The inventory changed. Request a new quote."
		end
		seen[key] = true
	end
	-- These engine writes do not run inventory-action Lua callbacks. Validated
	-- in-place indices cannot grow, drop, or truncate an inventory list.
	for i, row in ipairs(changes) do
		if not inventory:set_stack(row.list, row.index, row.replacement) then
			for restored = 1, i - 1 do
				local old = changes[restored]
				inventory:set_stack(old.list, old.index, old.expected)
			end
			return false, "The inventory changed. Request a new quote."
		end
	end
	local paid = balance - copper
	if paid ~= balance then
		player:get_meta():set_int(grug_money.KEY, paid)
		for _, func in ipairs(change_callbacks) do func(player, balance, paid) end
		hud_update(player)
	end
	return true
end

--
-- HUD: the money line sits on the "money" row of grug_core.hud_layout,
-- between the skill-name line and the XP line. No z_index, same as those two
-- elements. The offset used to be a hard-coded pixel number here.
--

local hud_ids = {}

hud_update = function(player)
	local id = hud_ids[player:get_player_name()]
	if id then
		player:hud_change(id, "text", grug_money.format(grug_money.get(player)))
	end
end

core.register_on_joinplayer(function(player)
	hud_ids[player:get_player_name()] = player:hud_add(
		grug_core.hud_layout.text_element("money", {
			number = 0xffd966,
			text = grug_money.format(grug_money.get(player)),
		}))
end)

core.register_on_leaveplayer(function(player)
	hud_ids[player:get_player_name()] = nil
end)

--
-- Chat command
--

core.register_chatcommand("money", {
	params = "[give <player> <copper>]",
	description = "Show your money or (as admin) give copper to a player",
	func = function(name, param)
		param = param:trim()

		if param == "" then
			local player = core.get_player_by_name(name)
			if not player then
				return false, "You are not online."
			end
			return true, "You carry " .. grug_money.format(grug_money.get(player)) .. "."
		end

		local target_name, amount_str = param:match("^give%s+(%S+)%s+(%S+)$")
		if not target_name then
			return false, "Usage: /money [give <player> <copper>]"
		end
		if not core.check_player_privs(name, {server = true}) then
			return false, "You need the 'server' privilege for this."
		end

		local amount = tonumber(amount_str)
		if not amount then
			return false, "Not a number: " .. amount_str
		end
		-- NaN fails this test too (nan ~= nan); infinity is caught by the
		-- range check below.
		if amount ~= math.floor(amount) then
			return false, "Copper must be a whole number: " .. amount_str
		end
		if amount > grug_money.MAX or amount < -grug_money.MAX then
			return false, "Copper out of range: " .. amount_str
		end

		local target = core.get_player_by_name(target_name)
		if not target then
			return false, "Player '" .. target_name .. "' is not online."
		end

		local new_balance = grug_money.add(target, amount)
		if target_name ~= name then
			local verb = amount < 0 and "You lost " or "You received "
			core.chat_send_player(target_name, verb ..
				grug_money.format(math.abs(amount)) .. ". You now carry " ..
				grug_money.format(new_balance) .. ".")
		end
		return true, target_name .. " now carries " .. grug_money.format(new_balance) .. "."
	end,
})
