local P = grug_professions
local METALS = {"bronze", "iron", "steel", "silversteel", "embersteel", "abyssal_steel"}
local REAGENTS = {"default:coal_lump", "grug_mobs:venom_gland", "grug_mobs:slime_gel",
	"grug_mobs:croc_tooth", "grug_gathering:stormkelp", "grug_mobs:stone_core"}

-- One book/selector entry for each legal family, channel, stat and enchant tier.
-- The representative item is display-only; any same-family item at or above
-- the enchant tier is eligible. Materials never depend on the target tier.
function P.register_enchants(profession, station, family, materials, representatives, extra)
	for tier = 1, 6 do
		for _, channel in ipairs({"prefix", "suffix"}) do
			for _, stat in ipairs(grug_items.enchant_pool(family, channel)) do
				local definition = grug_items.AFFIXES[stat]
				local value = grug_items.enchant_value(stat, tier)
				local material_inputs = {materials[tier], REAGENTS[tier]}
				if extra then material_inputs[#material_inputs + 1] = extra[tier] end
				local name = definition[channel]
				local label = name .. " — " .. channel .. " T" .. tier ..
					" (+" .. value .. (definition.percent and "% " or " ") ..
					definition.label .. ")"
				grug_jobs.register_station_operation({
					id = "enchant:" .. family .. ":" .. channel .. ":" .. stat .. ":t" .. tier,
					profession = profession, station = station, tier = tier,
					operation = "enchant", family = family,
					enchant_channel = channel, enchant_stat = stat,
					inputs = {material_inputs}, output = representatives[tier], label = label,
					hint = family:gsub("_", " ") .. "; item tier " .. tier ..
						" or higher. Replaces only the selected " .. channel .. ".",
				})
			end
		end
	end
end

local fittings, bars, shields, metal_armor = {}, {}, {}, {}
local leathers, leather_armor, bolts, cloth_armor = {}, {}, {}, {}
local LEATHER_KEYS = {"light", "cured", "heavy", "scaled", "sleek", "nightscale"}
local LEATHERS = {"grug_mobs:light_leather", "grug_professions:cured_leather",
	"grug_mobs:heavy_leather", "grug_mobs:scaled_hide", "grug_professions:sleek_leather",
	"grug_professions:nightscale_leather"}
local CLOTH_KEYS = {"patch", "woven", "heavy", "silkweave", "silk", "stormweave"}
for tier = 1, 6 do
	local metal = METALS[tier]
	fittings[tier] = "grug_professions:metal_fittings_" .. metal
	bars[tier] = "grug_materials:" .. metal .. "_bar"
	shields[tier] = "grug_gear:shield_" .. metal
	metal_armor[tier] = "grug_gear:chest_metal_" .. metal
	leathers[tier] = LEATHERS[tier]
	leather_armor[tier] = "grug_gear:chest_leather_" .. LEATHER_KEYS[tier]
	bolts[tier] = "grug_professions:bolt_" .. CLOTH_KEYS[tier]
	cloth_armor[tier] = "grug_gear:chest_cloth_" .. CLOTH_KEYS[tier]
end
for _, family in ipairs({"sword", "dagger", "greataxe"}) do
	local representatives = {}
	for tier, metal in ipairs(METALS) do
		representatives[tier] = "grug_gear:" .. family .. "_" .. metal
	end
	P.register_enchants("weaponsmith", "forge", family, fittings, representatives)
end
P.register_enchants("armorsmith", "forge", "metal_armor", bars, metal_armor)
P.register_enchants("armorsmith", "forge", "shield", bars, shields)
P.register_enchants("leatherworker", "tanning_rack", "leather_armor", leathers, leather_armor)
P.register_enchants("tailor", "tailor_bench", "cloth_armor", bolts, cloth_armor)
