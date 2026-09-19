-- The six core trinket specials (items_crafting.md section 6.2). Equipment is
-- read only when the shared equipment-change seam fires; combat and resource
-- paths consume the resulting scalar cache without touching inventory.

grug_trinkets = {}

local TRINKET_LISTS = {"grug_trinket1", "grug_trinket2"}
local META_COOLDOWN_PREFIX = "grug_trinkets:cooldown:"
local LAST_LIGHT_KIND = "last_light_absorb"
local RECLAIMER_KIND = "reclaimer"
local effects_by_player = {}

local function finite_nonnegative(value)
	value = tonumber(value)
	if not value or value ~= value or value < 0 or value == math.huge then
		return 0
	end
	return value
end

local function add_effect(effects, definition)
	local identity = definition._grug_trinket_identity
	local kind = definition._grug_trinket_kind
	if type(identity) ~= "string" or identity == "" or
			type(kind) ~= "string" or kind == "" or effects.seen[identity] then
		return
	end
	effects.seen[identity] = true
	local value = finite_nonnegative(definition._grug_trinket_value)
	local stacking = definition._grug_trinket_stacking
	local current = effects[kind]
	if stacking == "additive" then
		current = current or {value = 0}
		current.value = current.value + value
		local cap = finite_nonnegative(definition._grug_trinket_cap)
		if cap > 0 then
			current.cap = current.cap and math.min(current.cap, cap) or cap
		end
		if current.cap then
			current.value = math.min(current.value, current.cap)
		end
		effects[kind] = current
	elseif stacking == "highest" then
		local rage = finite_nonnegative(definition._grug_trinket_rage)
		if not current or value > current.value or
				(value == current.value and rage > (current.rage or 0)) then
			effects[kind] = {
				value = value,
				rage = rage,
				cooldown = finite_nonnegative(definition._grug_trinket_cooldown),
			}
		end
	end
end

local function rebuild(player)
	local name = player:get_player_name()
	local effects = {seen = {}}
	local inventory = player:get_inventory()
	if inventory then
		for index = 1, #TRINKET_LISTS do
			local stack = inventory:get_stack(TRINKET_LISTS[index], 1)
			if stack and not stack:is_empty() then
				local definition = core.registered_items[stack:get_name()]
				if definition then add_effect(effects, definition) end
			end
		end
	end
	effects_by_player[name] = effects
end

local function record(player, kind)
	local effects = effects_by_player[player:get_player_name()]
	return effects and effects[kind] or nil
end

local function cooldown_ready(player, kind, seconds)
	seconds = finite_nonnegative(seconds)
	if seconds <= 0 then return false end
	local meta = player:get_meta()
	local key = META_COOLDOWN_PREFIX .. kind
	local now = os.time()
	local expiry = tonumber(meta:get_string(key))
	if expiry and expiry == expiry and expiry > now then
		return false
	end
	-- Player meta strings avoid the 32-bit limit of set_int and keep the shared
	-- cooldown running across reconnects and server restarts.
	meta:set_string(key, tostring(now + math.floor(seconds)))
	return true
end

function grug_trinkets.mana_regen(player)
	local effect = record(player, "mana_regen")
	return effect and effect.value or 0
end

function grug_trinkets.modify_outgoing_heal(player, amount)
	local effect = record(player, "outgoing_healing")
	return finite_nonnegative(amount) * (1 + (effect and effect.value or 0) / 100)
end

function grug_trinkets.modify_instant_potion(player, amount)
	local effect = record(player, "potion_amount")
	return finite_nonnegative(amount) * (1 + (effect and effect.value or 0) / 100)
end

function grug_trinkets.accepted_weapon_hit(player)
	if not grug_core.get_equipped_weapon or
			not grug_core.get_equipped_weapon(player) then
		return
	end
	local effect = record(player, "battlebeat_rage")
	if effect and effect.value > 0 then
		grug_abilities.add_rage(player, effect.value)
	end
end

function grug_trinkets.after_player_hit(player, hp_change, reason)
	if hp_change >= 0 or not reason or reason.type ~= "punch" then return end
	local effect = record(player, LAST_LIGHT_KIND)
	if not effect then return end
	local maximum = finite_nonnegative(player:get_properties().hp_max)
	local after = player:get_hp() + hp_change
	if maximum <= 0 or after <= 0 or after >= maximum * 0.25 then return end
	if not cooldown_ready(player, LAST_LIGHT_KIND, effect.cooldown) then return end
	local amount = math.max(1, math.floor(maximum * effect.value / 100 + 0.5))
	-- Section 6.2 names no separate shield lifetime. The authored 120-second
	-- shared cooldown is therefore also the lifetime of an unconsumed shield.
	grug_core.set_absorb(player, amount, effect.cooldown, player)
end

function grug_trinkets.xp_eligible_kill(player)
	local effect = record(player, RECLAIMER_KIND)
	if not effect or not cooldown_ready(player, RECLAIMER_KIND,
			effect.cooldown) then
		return
	end
	local maximum_hp = finite_nonnegative(grug_classes.get_max_hp(player))
	local hp_amount = math.max(1,
		math.floor(maximum_hp * effect.value / 100 + 0.5))
	player:set_hp(math.min(maximum_hp, player:get_hp() + hp_amount))
	local class = grug_classes.get_class_def(player)
	if class and class.resource == "mana" then
		local maximum_mana = finite_nonnegative(grug_classes.get_max_mana(player))
		local mana_amount = math.max(1,
			math.floor(maximum_mana * effect.value / 100 + 0.5))
		grug_abilities.restore_mana(player, mana_amount)
	elseif class and class.resource == "rage" then
		grug_abilities.add_rage(player, effect.rage or 0)
	end
end

grug_core.register_on_equipment_change(function(player, listname)
	if listname and listname ~= TRINKET_LISTS[1] and
			listname ~= TRINKET_LISTS[2] then
		return
	end
	rebuild(player)
end)

core.register_on_leaveplayer(function(player)
	effects_by_player[player:get_player_name()] = nil
end)

-- Narrow bridges keep lower-level seam owners independent of this player mod.
-- Each production hook is optional when an isolated legacy KAT loads its file.
grug_core.trinket_mana_regen = grug_trinkets.mana_regen
grug_core.trinket_outgoing_heal = grug_trinkets.modify_outgoing_heal
grug_core.trinket_instant_potion = grug_trinkets.modify_instant_potion
grug_core.trinket_weapon_hit = grug_trinkets.accepted_weapon_hit
grug_core.trinket_after_hit = grug_trinkets.after_player_hit
grug_core.trinket_xp_kill = grug_trinkets.xp_eligible_kill
