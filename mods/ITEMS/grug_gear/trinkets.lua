-- The six core trinket identities, materialized once per tier by the Round 9
-- ruling. Mechanics consume the authored fields below; quality owns affix meta.

local ILVLS = {3, 10, 20, 30, 40, 50}
local TIER_NAMES = {"Tin", "Iron", "Steel", "Gold", "Embersteel",
	"Abyssal Steel"}

local identities = {
	{key = "manawell", name = "Manawell Pendant", form = "amulet",
		kind = "mana_regen", values = {0.05, 0.10, 0.15, 0.25, 0.35, 0.50},
		stacking = "additive", cap = 1.00,
		line = function(value) return string.format("+%.2f Mana per second", value) end,
		image = "default_mese_crystal_fragment.png^[colorize:#4a8bd8:150"},
	{key = "last_light", name = "Last Light Locket", form = "amulet",
		kind = "last_light_absorb", values = {3, 4, 5, 6, 8, 10},
		stacking = "highest", cooldown = 120,
		line = function(value) return value .. "% maximum-HP Last Light absorb" end,
		image = "default_mese_crystal_fragment.png^[colorize:#f0d36a:155"},
	{key = "battlebeat", name = "Battlebeat Band", form = "ring",
		kind = "battlebeat_rage", values = {0.25, 0.50, 0.75, 1.00, 1.50, 2.00},
		stacking = "additive", cap = 4,
		line = function(value) return string.format("+%.2f Rage per accepted hit", value) end,
		image = "default_gold_ingot.png^[colorize:#b84532:115"},
	{key = "apothecary_loop", name = "Apothecary Loop", form = "ring",
		kind = "potion_amount", values = {2.5, 5, 7.5, 10, 12.5, 15},
		stacking = "additive", cap = 30,
		line = function(value) return string.format("+%.1f%% instant potion amount", value) end,
		image = "default_gold_ingot.png^[colorize:#59a45c:125"},
	{key = "mercy_seal", name = "Mercy Seal", form = "medallion",
		kind = "outgoing_healing", values = {1, 2, 3, 4, 5, 6},
		stacking = "additive", cap = 12,
		line = function(value) return "+" .. value .. "% outgoing healing" end,
		image = "default_gold_ingot.png^[colorize:#e7edf5:130"},
	{key = "reclaimers_mark", name = "Reclaimer's Mark", form = "medallion",
		kind = "reclaimer", values = {1, 1.5, 2, 2.5, 3, 4},
		rage = {1, 2, 3, 4, 5, 6}, stacking = "highest", cooldown = 10,
		line = function(value, tier)
			return string.format("Restore %.1f%% maximum HP/Mana or %d Rage on kill",
				value, tier)
		end,
		image = "default_gold_ingot.png^[colorize:#785b9e:135"},
}

grug_gear.TRINKETS = identities

function grug_gear.trinket_item(identity, tier)
	if type(identity) ~= "string" or type(tier) ~= "number" or tier % 1 ~= 0 or
			tier < 1 or tier > 6 then
		return nil
	end
	return "grug_gear:" .. identity .. "_t" .. tier
end

for identity_index = 1, #identities do
	local identity = identities[identity_index]
	for tier = 1, 6 do
		local value = identity.values[tier]
		local rage = identity.rage and identity.rage[tier] or nil
		local special = identity.line(value, rage)
		core.register_craftitem(grug_gear.trinket_item(identity.key, tier), {
			description = TIER_NAMES[tier] .. " " .. identity.name ..
				"\nItem level " .. ILVLS[tier] .. "\n" ..
				core.colorize("#9aa0a6", special),
			inventory_image = identity.image,
			groups = {grug_gear = 1, grug_equip_trinket = 1},
			stack_max = 1,
			_grug_ilvl = ILVLS[tier],
			_grug_bracket = tier,
			_grug_quality = 1,
			_grug_quality_family = "trinket",
			_grug_trinket_identity = identity.key,
			_grug_trinket_form = identity.form,
			_grug_trinket_kind = identity.kind,
			_grug_trinket_value = value,
			_grug_trinket_rage = rage,
			_grug_trinket_stacking = identity.stacking,
			_grug_trinket_cap = identity.cap,
			_grug_trinket_cooldown = identity.cooldown,
			_grug_trinket_special = special,
		})
	end
end
