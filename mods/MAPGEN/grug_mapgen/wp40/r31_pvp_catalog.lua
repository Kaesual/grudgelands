-- Round 31 PvP POIs (pvp-plan rulings 17-22): the two faction fortresses and
-- the sixteen Battlegrounds camps, as rules, never positions. Each row names
-- the zone and the slot of the anchor that carries it; the anchor row in
-- `source/simple_map.lua` (template id = the row's `kind`, whose fitting
-- profile lives there too) owns the position, and `r7_settlement.lua` binds
-- every row to its anchor. The composition is `r31_pvp_poi_blueprint.lua`.
--
-- Camps: per Battlegrounds zone and faction one lower and one higher camp
-- (ruling 19). Their level bands come from the zone's own range
-- (`M.camp_levels`); their race is drawn once per world from the full seed
-- and the anchor number (ruling 20, `M.camp_race`), and the blueprint
-- publishes it as `landmarks.race` so the socket registry carries the camp's
-- real race.
-- Plain Lua 5.1, no globals.
local M = {}

-- The races of a faction in a fixed order (the roll indexes it).
M.FACTION_RACES = {accord = {"dwarf", "elf", "human"}, throng = {"orc", "troll", "undead"}}
-- The race a fortress is built and registered as: the faction's seat race,
-- whose Quartermaster the faction vendor already draws (grug_traders).
M.SEAT_RACE = {accord = "human", throng = "orc"}

local FACTION_NAME = {accord = "Accord", throng = "Throng"}
local BATTLEGROUNDS = {
	{zone_id = "front_gravesalt_escarpment", name = "Gravesalt"},
	{zone_id = "front_broken_causeway", name = "Causeway"},
	{zone_id = "front_shattered_line", name = "Shattered Line"},
	{zone_id = "front_skyglass_canopy", name = "Skyglass"},
}

M.rows = {
	{key = "pvp_fortress_accord", label = "Ashenward Bastion", zone_id = "elandor_ashenward_march",
		slot = "pvp_fortress", kind = "pvp_fortress", faction = "accord"},
	{key = "pvp_fortress_throng", label = "Bannerbreak Warhold", zone_id = "kragmar_bannerbreak_mesa",
		slot = "pvp_fortress", kind = "pvp_fortress", faction = "throng"},
}
for _, zone in ipairs(BATTLEGROUNDS) do
	for _, faction in ipairs({"accord", "throng"}) do
		for _, band in ipairs({"low", "high"}) do
			M.rows[#M.rows + 1] = {
				key = ("pvp_camp_%s_%s_%s"):format(zone.zone_id:gsub("^front_", ""), faction, band),
				label = ("%s %s %s"):format(zone.name, FACTION_NAME[faction],
					band == "low" and "Picket" or "War Camp"),
				zone_id = zone.zone_id, slot = ("pvp_%s_%s"):format(faction, band),
				kind = "pvp_camp_" .. band, faction = faction, band = band}
		end
	end
end

-- A camp's level band inside its zone's range (ruling 19: The Broken
-- Causeway 41-43 and 48-50, the 51-60 zones 51-53 and 58-60).
function M.camp_levels(level_min, level_max, band)
	if band == "low" then return level_min, level_min + 2 end
	return level_max - 2, level_max
end

-- The camp's race: one of its faction's three, fixed by the world seed (a
-- decimal string) and the anchor number through SHA-256 (`raw_sha256` is
-- the blueprint options' seam, the same in main and emerge): the first four
-- digest bytes, mod 3.
function M.camp_race(raw_sha256, full_seed, numeric_id, faction)
	local races = assert(M.FACTION_RACES[faction], "Round 31 PvP faction differs")
	local digest = raw_sha256("grug_r31_camp_race_v1\t" .. tostring(full_seed) .. "\t" ..
		tostring(numeric_id))
	assert(type(digest) == "string" and #digest == 32, "Round 31 PvP SHA-256 seam differs")
	local b1, b2, b3, b4 = digest:byte(1, 4)
	return races[(((b1 * 256 + b2) * 256 + b3) * 256 + b4) % #races + 1]
end

return M
