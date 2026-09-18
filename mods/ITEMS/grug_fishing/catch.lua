-- Zone-level fishing tables. The catch position is resolved through the
-- installed world difficulty authority; salt and fresh water deliberately use
-- the same table for a given level band.

local TABLES = {
	[1] = {
		{name = "grug_mobs:raw_fish", count = 1, weight = 78},
		{name = "default:stick", count = 1, weight = 12},
		{name = "default:papyrus", count = 1, weight = 10},
	},
	[2] = {
		{name = "grug_fishing:silver_trout", count = 1, weight = 78},
		{name = "default:stick", count = 1, weight = 12},
		{name = "default:papyrus", count = 1, weight = 10},
	},
	[3] = {
		{name = "grug_fishing:mire_carp", count = 1, weight = 78},
		{name = "default:stick", count = 1, weight = 12},
		{name = "default:papyrus", count = 1, weight = 10},
	},
	[4] = {
		{name = "grug_fishing:frostfin", count = 1, weight = 78},
		{name = "default:stick", count = 1, weight = 12},
		{name = "default:papyrus", count = 1, weight = 10},
	},
	[5] = {
		{name = "grug_fishing:ember_eel", count = 1, weight = 78},
		{name = "default:stick", count = 1, weight = 12},
		{name = "default:papyrus", count = 1, weight = 10},
	},
	[6] = {
		{name = "grug_fishing:storm_tuna", count = 1, weight = 78},
		{name = "default:stick", count = 1, weight = 12},
		{name = "default:papyrus", count = 1, weight = 10},
	},
}

local TOTAL = 100

grug_fishing.CATCH_TABLES = TABLES
grug_fishing.CATCH_TOTAL = TOTAL

function grug_fishing.band_for_level(level)
	level = math.floor(tonumber(level) or 1)
	if level < 1 then level = 1 end
	if level > 60 then level = 60 end
	return math.floor((level - 1) / 10) + 1
end

function grug_fishing.table_for(pos)
	local level = grug_core.mob_level_at(pos)
	return TABLES[grug_fishing.band_for_level(level)]
end

function grug_fishing.catch_at(catch_table, roll)
	local seen = 0
	for _, entry in ipairs(catch_table) do
		seen = seen + entry.weight
		if roll < seen then return entry end
	end
	return catch_table[#catch_table]
end

local MIN_WAIT = 3
local WAIT_SPREAD = 7

grug_fishing.MIN_WAIT = MIN_WAIT
grug_fishing.MAX_WAIT = MIN_WAIT + WAIT_SPREAD
grug_fishing.WAIT_SPREAD = WAIT_SPREAD

function grug_fishing.wait_for(roll)
	if roll < 0 then
		roll = 0
	elseif roll > WAIT_SPREAD then
		roll = WAIT_SPREAD
	end
	return MIN_WAIT + roll
end
