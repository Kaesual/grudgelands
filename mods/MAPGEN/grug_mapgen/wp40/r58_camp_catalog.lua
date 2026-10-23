-- Round 58 camps (round58-plan.md §2, §4 CAMPS): the 20 mining camps of the
-- Miner's Guild and the 6 enemy camps under construction, as rules, never
-- positions. Each row names the zone and the slot of the anchor that carries
-- it; the anchor row in `source/simple_map.lua` (template id = the row's
-- `kind`, whose fitting profile lives there too) owns the position, and
-- `r7_settlement.lua` binds every row to its anchor. The composition is
-- `r58_camp_blueprint.lua`; the 16 Battlegrounds war camps
-- (`r31_pvp_catalog.lua`) are mining camps too and keep their own rows.
--
-- Mining camps: one in every level-11-40 zone outside the capital zones
-- (6 T2, 8 T3, 6 T4). A camp's faction is its zone's half of the continent
-- (Elandor The Accord, Kragmar The Throng), its race the zone's race region.
-- Camps under construction: one in each contested T4 zone, built by the
-- other faction, by the race of the zone across the front from it (the
-- Accord-side zones 5, 10 and 16 face 21, 26 and 32).
--
-- The lift points: `LIFT` is the lift node's cell (local x, z at y = 1,
-- unturned) of each composition kind; the blueprints place the node and the
-- `lift` socket there, and `r58_camps.lua` turns the same offset with the
-- composition, so the module and the blueprint agree by construction.
-- Plain Lua 5.1, no globals.
local M = {}

local FACTION_NAME = {accord = "Accord", throng = "Throng"}

-- {zone id, faction, race, short name}
local MINING = {
	{"elandor_copperfell_foothills", "accord", "dwarf", "Copperfell"},
	{"elandor_goldmead_vale", "accord", "human", "Goldmead"},
	{"elandor_starbough_vale", "accord", "elf", "Starbough"},
	{"kragmar_mournfen", "throng", "undead", "Mournfen"},
	{"kragmar_redtusk_savanna", "throng", "orc", "Redtusk"},
	{"kragmar_raincall_basin", "throng", "troll", "Raincall"},
	{"elandor_frostbarrow_shelf", "accord", "dwarf", "Frostbarrow"},
	{"elandor_whitebridge_shire", "accord", "human", "Whitebridge"},
	{"elandor_lorindor", "accord", "elf", "Lorindor"},
	{"elandor_moonfall_wood", "accord", "elf", "Moonfall"},
	{"kragmar_ossuary_reach", "throng", "undead", "Ossuary"},
	{"kragmar_speargrass_reach", "throng", "orc", "Speargrass"},
	{"kragmar_whispering_reedlands", "throng", "troll", "Reedlands"},
	{"kragmar_totemwater_reach", "throng", "troll", "Totemwater"},
	{"elandor_stormvault_heights", "accord", "dwarf", "Stormvault"},
	{"elandor_ashenward_march", "accord", "human", "Ashenward"},
	{"elandor_glassroot_wilds", "accord", "elf", "Glassroot"},
	{"kragmar_blackwind_rise", "throng", "undead", "Blackwind"},
	{"kragmar_bannerbreak_mesa", "throng", "orc", "Bannerbreak"},
	{"kragmar_thunderroot_wilds", "throng", "troll", "Thunderroot"},
}
-- {zone id, builder faction, builder race, short name}
local CONSTRUCTION = {
	{"elandor_stormvault_heights", "throng", "undead", "Stormvault"},
	{"elandor_ashenward_march", "throng", "orc", "Ashenward"},
	{"elandor_glassroot_wilds", "throng", "troll", "Glassroot"},
	{"kragmar_blackwind_rise", "accord", "dwarf", "Blackwind"},
	{"kragmar_bannerbreak_mesa", "accord", "human", "Bannerbreak"},
	{"kragmar_thunderroot_wilds", "accord", "elf", "Thunderroot"},
}

local function short_id(zone_id)
	return (zone_id:gsub("^elandor_", ""):gsub("^kragmar_", ""))
end

M.mining = {}
for _, r in ipairs(MINING) do
	M.mining[#M.mining + 1] = {key = "mining_camp_" .. short_id(r[1]),
		label = r[4] .. " Mining Camp", zone_id = r[1], slot = "mining_camp",
		kind = "mining_camp", faction = r[2], race = r[3]}
end
M.construction = {}
for _, r in ipairs(CONSTRUCTION) do
	M.construction[#M.construction + 1] = {key = "camp_site_" .. short_id(r[1]),
		label = r[4] .. " " .. FACTION_NAME[r[2]] .. " Camp Site", zone_id = r[1],
		slot = "camp_construction", kind = "camp_construction", faction = r[2],
		race = r[3], band = "high"}
end

-- The lift node's cell per composition kind (local, unturned, y = 1).
M.LIFT = {
	mining_camp = {x = 0, z = 6},
	pvp_camp_low = {x = 8, z = 4},
	pvp_camp_high = {x = 9, z = 5},
}

-- The room floors per tier depth (round58-plan.md §2: the tier's lowest y
-- + 50; T6 at -1050). ROOMS owns the room's shape round (lift.x, floor y,
-- lift.z).
M.ROOM_FLOOR_Y = {-50, -250, -450, -650, -950, -1050}

-- A zone's tier: levels 1-10 T1, 11-20 T2, ... 51-60 T6 (the band never
-- changes it: a war camp's tier is its zone's).
function M.tier_of(level_min)
	local tier = math.floor((level_min - 1) / 10) + 1
	if tier < 1 then return 1 end
	if tier > 6 then return 6 end
	return tier
end

return M
