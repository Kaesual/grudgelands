local METALS = {"bronze", "iron", "steel", "silversteel", "embersteel", "abyssal_steel"}
local WOODS = {"seasoned", "polished", "hardened", "inlaid", "lacquered", "heartwood"}
local SETTINGS = {"tin", "iron", "copper_inlaid_steel", "gold",
	"gold_filigreed_embersteel", "gold_filigreed_abyssal_steel"}
local woods, fittings, settings, staves, bows, books = {}, {}, {}, {}, {}, {}
for tier = 1, 6 do
	woods[tier] = "grug_artisans:" .. WOODS[tier] .. "_wood"
	fittings[tier] = "grug_professions:metal_fittings_" .. METALS[tier]
	settings[tier] = "grug_artisans:setting_" .. SETTINGS[tier]
	staves[tier] = "grug_gear:staff_" .. METALS[tier]
	bows[tier] = "grug_gear:bow_" .. METALS[tier]
	books[tier] = "grug_gear:spellbook_" .. METALS[tier]
end
grug_professions.register_enchants("woodcarver", "carving_bench", "caster_weapon",
	woods, staves, fittings)
grug_professions.register_enchants("woodcarver", "carving_bench", "bow", woods, bows, fittings)
grug_professions.register_enchants("goldsmith", "jewellers_bench", "spellbook", settings, books)
