local P = grug_professions
local M = "grug_materials:"

-- The metal bar is the Weaponsmith's and Armorsmith's own enchant material.
local BARS = {"bronze", "iron", "steel", "silversteel", "embersteel", "abyssal_steel"}

for tier = 1, #BARS do
	P.register_ingredient(M .. BARS[tier] .. "_bar", tier)
end
