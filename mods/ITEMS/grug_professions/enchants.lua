local P = grug_professions
local data = P.enchant_data
local METALS = {"bronze", "iron", "steel", "silversteel", "embersteel", "abyssal_steel"}

-- Round 28 ruling 28: enchant inputs come from data/enchants.json. Each
-- operation costs the family's own material of its tier, the tier's loot item
-- for the stat and the tier's input for the family; no profession needs
-- another profession's product (checked below once every mod has loaded).

local rows = P.read_json("enchants.json")
if rows == nil then error("grug_professions: data/enchants.json is missing", 0) end
P.ENCHANT_DATA = data.validate_enchants(rows, grug_items.POOLS)

local registered_families = {}

-- One book/selector entry for each legal family, channel, stat and enchant tier.
-- The representative item is display-only; any same-family item at or above
-- the enchant tier is eligible. Materials never depend on the target tier.
function P.register_enchants(profession, station, family, materials, representatives)
	if registered_families[family] then
		error("grug_professions: enchant family " .. family .. " registered twice", 0)
	end
	registered_families[family] = profession
	for tier = 1, 6 do
		for _, channel in ipairs({"prefix", "suffix"}) do
			for _, stat in ipairs(grug_items.enchant_pool(family, channel)) do
				local definition = grug_items.AFFIXES[stat]
				local value = grug_items.enchant_value(stat, tier)
				local material_inputs = data.operation_inputs(P.ENCHANT_DATA, family, stat,
					tier, materials[tier])
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

local bars, shields, metal_armor = {}, {}, {}
local leathers, leather_armor, bolts, cloth_armor = {}, {}, {}, {}
local LEATHER_KEYS = {"light", "cured", "heavy", "scaled", "sleek", "nightscale"}
local LEATHERS = {"grug_mobs:light_leather", "grug_professions:cured_leather",
	"grug_mobs:heavy_leather", "grug_mobs:scaled_hide", "grug_professions:sleek_leather",
	"grug_professions:nightscale_leather"}
local CLOTH_KEYS = {"patch", "woven", "heavy", "silkweave", "silk", "stormweave"}
for tier = 1, 6 do
	local metal = METALS[tier]
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
	P.register_enchants("weaponsmith", "forge", family, bars, representatives)
end
P.register_enchants("armorsmith", "forge", "metal_armor", bars, metal_armor)
P.register_enchants("armorsmith", "forge", "shield", bars, shields)
P.register_enchants("leatherworker", "tanning_rack", "leather_armor", leathers, leather_armor)
P.register_enchants("tailor", "tailor_bench", "cloth_armor", bolts, cloth_armor)

-- Which profession's recipes make each item. Station operations work in place
-- on the equipment and make nothing new.
function P.profession_products()
	local products = {}
	for index = 1, #grug_jobs.recipes do
		local recipe = grug_jobs.recipes[index]
		products[recipe.output_name] = recipe.profession
	end
	return products
end

core.register_on_mods_loaded(function()
	local families = data.families_and_stats(grug_items.POOLS)
	for _, family in ipairs(families) do
		if not registered_families[family] then
			error("grug_professions: no profession registers enchants for family " .. family, 0)
		end
	end
	for _, ref in ipairs(data.referenced_items(P.ENCHANT_DATA)) do
		if not core.registered_items[ref.item] then
			error("grug_professions: " .. ref.where .. " names unregistered item " .. ref.item, 0)
		end
	end
	-- Goal 3: every profession recipe and enchant operation uses only its own
	-- profession's products; universal reagents use none.
	local checked = {}
	for index = 1, #grug_jobs.recipes do
		local recipe = grug_jobs.recipes[index]
		checked[#checked + 1] = {profession = recipe.profession, inputs = recipe.flat_inputs,
			label = recipe.output_name}
	end
	for _, operation in ipairs(grug_jobs.station_operations()) do
		checked[#checked + 1] = {profession = operation.profession,
			inputs = operation.flat_inputs, label = operation.id}
	end
	-- No operation input may be declared above the enchant tier, the rule
	-- profession recipes follow at registration.
	local operations = {}
	for _, operation in ipairs(grug_jobs.station_operations()) do
		operations[#operations + 1] = {tier = operation.tier, inputs = operation.flat_inputs,
			label = operation.id}
	end
	local too_high = data.over_tier_inputs(operations, grug_jobs.ingredient_tier)
	if #too_high > 0 then
		error("grug_professions: enchant inputs above their tier:\n" ..
			table.concat(too_high, "\n"), 0)
	end
	local offences = data.foreign_inputs(P.profession_products(), checked, P.REAGENTS)
	if #offences > 0 then
		error("grug_professions: cross-profession inputs:\n" ..
			table.concat(offences, "\n"), 0)
	end
end)
