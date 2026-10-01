-- Own enchant materials (Round 28 ruling 28): the Woodcarver's graded wood
-- and the Goldsmith's setting of the tier; the other two inputs come from
-- grug_professions/data/enchants.json.
local METALS = {"bronze", "iron", "steel", "silversteel", "embersteel", "abyssal_steel"}
local WOODS = {"seasoned", "polished", "hardened", "inlaid", "lacquered", "heartwood"}
local SETTINGS = {"tin", "iron", "copper_inlaid_steel", "gold",
	"gold_filigreed_embersteel", "gold_filigreed_abyssal_steel"}
local woods, settings, staves, bows, books = {}, {}, {}, {}, {}
for tier = 1, 6 do
	woods[tier] = "grug_artisans:" .. WOODS[tier] .. "_wood"
	settings[tier] = "grug_artisans:setting_" .. SETTINGS[tier]
	staves[tier] = "grug_gear:staff_" .. METALS[tier]
	bows[tier] = "grug_gear:bow_" .. METALS[tier]
	books[tier] = "grug_gear:spellbook_" .. METALS[tier]
end
grug_professions.register_enchants("woodcarver", "carving_bench", "caster_weapon",
	woods, staves)
grug_professions.register_enchants("woodcarver", "carving_bench", "bow", woods, bows)
grug_professions.register_enchants("goldsmith", "jewellers_bench", "spellbook", settings, books)
local trinkets = {}
for tier = 1, 6 do trinkets[tier] = grug_gear.trinket_item("manawell", tier) end
grug_professions.register_enchants("goldsmith", "jewellers_bench", "trinket", settings, trinkets)
