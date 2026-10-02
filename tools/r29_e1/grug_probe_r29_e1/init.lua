-- Round 29 Lane E1 probe (never shipped): prints, from the REAL resolved
-- payouts (grug_traders.sell_price), the median expected payout of one kill
-- per level band over the drop families of grug_mobs/data/drops.json, next to
-- the economy plan's target of three copper times the tier factor (§3.2).
-- A family's kill value is the sum over its band rows of
-- payout × mean count / chance (mobs_redo: 1 in `chance`); leader bonus
-- rows are left out (leaders are rare). Then a short list of payouts for the
-- record. Ends with "RESULT PASS" when every band has families.

local function log(text)
	core.log("action", "[r29_e1_probe] " .. text)
end

local SAMPLE = {
	"mobs:meat_raw", "grug_mobs:light_leather", "grug_mobs:heavy_leather",
	"grug_mobs:scaled_hide", "grug_mobs:sleek_pelt", "grug_professions:sleek_leather",
	"grug_professions:nightscale_leather", "grug_mobs:linen_cloth",
	"grug_mobs:spider_silk", "grug_professions:bolt_silk",
	"grug_mobs:boar_tusk", "grug_mobs:last_pay_talisman",
	"default:copper_lump", "default:coal_lump", "grug_materials:bronze_bar",
	"grug_materials:iron_bar", "grug_materials:steel_bar",
	"grug_materials:silversteel_bar", "grug_materials:embersteel_bar",
	"grug_materials:abyssal_steel_bar", "grug_materials:quartz",
	"grug_materials:rough_citrine", "grug_materials:rough_diamond",
	"grug_materials:cut_diamond", "grug_gathering:gravemoss",
	"grug_gathering:stormkelp", "grug_fishing:storm_tuna", "default:stick",
	"grug_gear:sword_bronze", "grug_gear:dagger_iron", "grug_gear:sword_abyssal_steel",
	"grug_gear:chest_metal_abyssal_steel", "grug_gear:arrow",
	"grug_traders:potion_healing_weak", "grug_inventory:bag_small",
	"grug_professions:thread", "grug_professions:parchment",
	"default:apple", "grug_cooking:bread", "mobs:meat", "grug_materials:gravesalt",
	"grug_materials:emberglass_shard", "grug_mobs:war_trophy", "grug_mobs:stolen_purse",
	"grug_gear:sword_iron", "grug_gear:sword_steel", "grug_gear:chest_cloth_silk",
	"grug_materials:pick_wood",
}

core.register_on_mods_loaded(function()
	local factor = grug_traders.price_rules.TIER_FACTOR
	local drops = grug_mobs.read_data_json("drops.json") or {}
	local ok = true
	log("class values: trash " .. grug_traders.price_rules.CLASS_VALUE.trash ..
		", raw " .. grug_traders.price_rules.CLASS_VALUE.raw ..
		", generic " .. grug_traders.price_rules.CLASS_VALUE.generic ..
		", signature " .. grug_traders.price_rules.CLASS_VALUE.signature ..
		", gem " .. grug_traders.price_rules.CLASS_VALUE.gem)
	log("band | target | median kill | range over families | families")
	for band = 1, 6 do
		local values = {}
		for _, family in ipairs(drops.drops or drops) do
			local rows = family.bands and family.bands[tostring(band)]
			if rows and #rows > 0 then
				local value = 0
				for _, row in ipairs(rows) do
					local mean = ((row.min or 1) + (row.max or 1)) / 2
					value = value + grug_traders.sell_price(row.item) * mean / row.chance
				end
				values[#values + 1] = {value = value, family = family.family}
			end
		end
		table.sort(values, function(a, b) return a.value < b.value end)
		local n = #values
		if n == 0 then
			ok = false
			log(band .. " | no family")
		else
			local median = n % 2 == 1 and values[(n + 1) / 2].value or
				(values[n / 2].value + values[n / 2 + 1].value) / 2
			local target = 3 * factor[band]
			local over = {}
			for _, v in ipairs(values) do
				if v.value > 4 * target then
					over[#over + 1] = ("%s %.0f"):format(v.family, v.value)
				end
			end
			log(("%d | %.0fc | %.1fc | %.1f (%s) - %.1f (%s) | %d%s"):format(band,
				target, median, values[1].value, values[1].family, values[n].value,
				values[n].family, n, #over > 0 and
				("; above 4x target: " .. table.concat(over, ", ")) or ""))
		end
	end
	for _, item in ipairs(SAMPLE) do
		log(("payout %s = %dc"):format(item, grug_traders.sell_price(item)))
	end
	log(ok and "RESULT PASS" or "RESULT FAIL")
end)
