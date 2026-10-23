-- The Miner's Guild catalogue (docs/design/miners_guild.md §9): every number
-- of the guild as data, and the pure accessors over it. No engine call, so
-- the mapgen environment, the fixture (tools/r58_guildspec) and the tuning
-- page's generator load exactly these bytes; game code reads its numbers
-- from here, never from literals of its own.
--
-- VALUES holds every tunable number under the key the tuning page uses
-- (`rank.<n>`, `exchange.<item>.points|lot`, `<kind>.t<n>.price`,
-- `<kind>.<parameter>`, `consumable.t<n>.sell_copper`,
-- `remains.t<n>.<field>`). The user's accepted numbers are written into it
-- mechanically (tools/r58_guildspec/apply_tuning.py). The tables after it
-- name the ids and the fixed rules and take their numbers from VALUES.

local M = {}

M.VALUES = {
	-- Ranks: the lifetime reputation each rank needs (spec §4). Built on the
	-- yield model's hours: rank n by mining at tier min(n, 6), the last four
	-- ranks long.
	["rank.1"] = 200,
	["rank.2"] = 900,
	["rank.3"] = 2700,
	["rank.4"] = 9000,
	["rank.5"] = 23000,
	["rank.6"] = 50000,
	["rank.7"] = 90000,
	["rank.8"] = 150000,
	["rank.9"] = 225000,
	["rank.10"] = 350000,

	-- The exchange (spec §5): points per lot of `lot` items. Stone and sand
	-- 1 point per 50; an ore or gem by its class (common 1, precious metal
	-- or crystal 2, gem 4) doubled per harvest tier above the first.
	["exchange.default:cobble.points"] = 1,
	["exchange.default:cobble.lot"] = 50,
	["exchange.default:mossycobble.points"] = 1,
	["exchange.default:mossycobble.lot"] = 50,
	["exchange.default:desert_cobble.points"] = 1,
	["exchange.default:desert_cobble.lot"] = 50,
	["exchange.grug_materials:granite.points"] = 1,
	["exchange.grug_materials:granite.lot"] = 50,
	["exchange.grug_materials:basalt.points"] = 1,
	["exchange.grug_materials:basalt.lot"] = 50,
	["exchange.grug_materials:slate.points"] = 1,
	["exchange.grug_materials:slate.lot"] = 50,
	["exchange.default:gravel.points"] = 1,
	["exchange.default:gravel.lot"] = 50,
	["exchange.default:sand.points"] = 1,
	["exchange.default:sand.lot"] = 50,
	["exchange.default:silver_sand.points"] = 1,
	["exchange.default:silver_sand.lot"] = 50,
	["exchange.default:coal_lump.points"] = 1,
	["exchange.default:coal_lump.lot"] = 1,
	["exchange.default:copper_lump.points"] = 1,
	["exchange.default:copper_lump.lot"] = 1,
	["exchange.default:tin_lump.points"] = 1,
	["exchange.default:tin_lump.lot"] = 1,
	["exchange.default:iron_lump.points"] = 1,
	["exchange.default:iron_lump.lot"] = 1,
	["exchange.grug_materials:quartz.points"] = 1,
	["exchange.grug_materials:quartz.lot"] = 1,
	["exchange.grug_materials:anthracite.points"] = 2,
	["exchange.grug_materials:anthracite.lot"] = 1,
	["exchange.default:gold_lump.points"] = 4,
	["exchange.default:gold_lump.lot"] = 1,
	["exchange.grug_materials:silver_lump.points"] = 8,
	["exchange.grug_materials:silver_lump.lot"] = 1,
	["exchange.grug_materials:emberglass.points"] = 16,
	["exchange.grug_materials:emberglass.lot"] = 1,
	["exchange.grug_materials:abyssal_crystal.points"] = 32,
	["exchange.grug_materials:abyssal_crystal.lot"] = 1,
	["exchange.grug_materials:rough_citrine.points"] = 4,
	["exchange.grug_materials:rough_citrine.lot"] = 1,
	["exchange.grug_materials:rough_jade.points"] = 8,
	["exchange.grug_materials:rough_jade.lot"] = 1,
	["exchange.grug_materials:rough_garnet.points"] = 16,
	["exchange.grug_materials:rough_garnet.lot"] = 1,
	["exchange.grug_materials:rough_sapphire.points"] = 32,
	["exchange.grug_materials:rough_sapphire.lot"] = 1,
	["exchange.grug_materials:rough_ruby.points"] = 64,
	["exchange.grug_materials:rough_ruby.lot"] = 1,
	["exchange.grug_materials:rough_diamond.points"] = 128,
	["exchange.grug_materials:rough_diamond.lot"] = 1,

	-- The consumables (spec §7): prices in reputation, about one hour of
	-- the tier's mining each; a vendor pays 5 % of the price in copper.
	["ore_sense.t1.price"] = 400,
	["ore_sense.t2.price"] = 500,
	["ore_sense.t3.price"] = 900,
	["ore_sense.t4.price"] = 2000,
	["ore_sense.t5.price"] = 3500,
	["ore_sense.t6.price"] = 5000,
	["treasure_hunt.t1.price"] = 400,
	["treasure_hunt.t2.price"] = 500,
	["treasure_hunt.t3.price"] = 900,
	["treasure_hunt.t4.price"] = 2000,
	["treasure_hunt.t5.price"] = 3500,
	["treasure_hunt.t6.price"] = 5000,
	["consumable.t1.sell_copper"] = 20,
	["consumable.t2.sell_copper"] = 25,
	["consumable.t3.sell_copper"] = 45,
	["consumable.t4.sell_copper"] = 100,
	["consumable.t5.sell_copper"] = 175,
	["consumable.t6.sell_copper"] = 250,
	-- Ore Sense: a mark every interval_min..interval_max seconds on the
	-- nearest target deposit within `range` nodes, shown marker_seconds.
	["ore_sense.duration"] = 1800,
	["ore_sense.range"] = 16,
	["ore_sense.interval_min"] = 60,
	["ore_sense.interval_max"] = 120,
	["ore_sense.marker_seconds"] = 5,
	-- Treasure Hunt: one Miner's Remains at a time, place_min..place_max
	-- nodes from the user; marked within marker_range, gone beyond
	-- remove_distance (its timer checks every check_seconds); the next one
	-- respawn_seconds after the last was dug or removed.
	["treasure_hunt.duration"] = 1800,
	["treasure_hunt.place_min"] = 12,
	["treasure_hunt.place_max"] = 24,
	["treasure_hunt.marker_range"] = 32,
	["treasure_hunt.remove_distance"] = 48,
	["treasure_hunt.respawn_seconds"] = 90,
	["treasure_hunt.check_seconds"] = 5,

	-- Miner's Remains (spec §8): a Bag of Coins of copper_min..copper_max,
	-- bars_min..bars_max of the tier's bar and, one time in gem_chance, the
	-- tier's cut gem. About half an hour of the band's income per Treasure
	-- Hunt.
	["remains.t1.copper_min"] = 2,
	["remains.t1.copper_max"] = 5,
	["remains.t1.bars_min"] = 1,
	["remains.t1.bars_max"] = 1,
	["remains.t1.gem_chance"] = 8,
	["remains.t2.copper_min"] = 6,
	["remains.t2.copper_max"] = 12,
	["remains.t2.bars_min"] = 1,
	["remains.t2.bars_max"] = 2,
	["remains.t2.gem_chance"] = 8,
	["remains.t3.copper_min"] = 12,
	["remains.t3.copper_max"] = 24,
	["remains.t3.bars_min"] = 1,
	["remains.t3.bars_max"] = 2,
	["remains.t3.gem_chance"] = 8,
	["remains.t4.copper_min"] = 30,
	["remains.t4.copper_max"] = 70,
	["remains.t4.bars_min"] = 1,
	["remains.t4.bars_max"] = 2,
	["remains.t4.gem_chance"] = 8,
	["remains.t5.copper_min"] = 80,
	["remains.t5.copper_max"] = 180,
	["remains.t5.bars_min"] = 1,
	["remains.t5.bars_max"] = 2,
	["remains.t5.gem_chance"] = 8,
	["remains.t6.copper_min"] = 200,
	["remains.t6.copper_max"] = 450,
	["remains.t6.bars_min"] = 1,
	["remains.t6.bars_max"] = 2,
	["remains.t6.gem_chance"] = 8,
}
local V = M.VALUES

-- Names and ids (spec §2, §10).
M.UI_NAME = "Miner's Guild"
M.GUILDS = {
	accord = {id = "charter_of_stone", name = "The Charter of Stone"},
	throng = {id = "oathdelvers", name = "The Oathdelvers"},
}
M.MAX_RANK = 10
M.TIER_COUNT = 6
M.NUMERALS = {"I", "II", "III", "IV", "V", "VI"}
-- The effect slot: one status id, a variant per kind, so only one of the two
-- runs at a time.
M.STATUS = {id = "mining_sense", variants = {ore_sense = "ore_sense",
	treasure_hunt = "treasure_hunt"}}
M.KINDS = {"ore_sense", "treasure_hunt"}
M.KIND_NAMES = {ore_sense = "Ore Sense", treasure_hunt = "Treasure Hunt"}
-- The nodes of the camps' lifts and rooms (spec §3; registered by the
-- skeleton commit, never by this file).
M.NODES = {lift = "grug_guild:lift", room_fill = "grug_guild:room_fill",
	room_mantle = "grug_guild:room_mantle"}

-- The tier rock each tier's Remains is placed in and looks like
-- (grug_materials.TIERS[t].node), and the loot's bar and cut gem.
local TIER_ROCK = {"default:stone", "grug_materials:t2_stone", "grug_materials:t3_stone",
	"grug_materials:t4_stone", "grug_materials:t5_stone", "grug_materials:t6_stone"}
local TIER_BAR = {"grug_materials:bronze_bar", "grug_materials:iron_bar",
	"grug_materials:steel_bar", "grug_materials:silversteel_bar",
	"grug_materials:embersteel_bar", "grug_materials:abyssal_steel_bar"}
local TIER_GEM = {"grug_materials:cut_citrine", "grug_materials:cut_jade",
	"grug_materials:cut_garnet", "grug_materials:cut_sapphire",
	"grug_materials:cut_ruby", "grug_materials:cut_diamond"}

-- What Ore Sense of a tier looks for (grug_materials resource keys): the
-- resources whose harvest tier is the item's tier, the gem first. A mark
-- goes to the nearest deposit of the first key with one in range.
M.ORE_SENSE_TARGETS = {
	{"citrine", "iron", "quartz", "copper", "tin", "coal"},
	{"jade", "gold", "anthracite"},
	{"garnet", "silver"},
	{"sapphire", "emberglass"},
	{"ruby", "abyssal_crystal"},
	{"diamond"},
}

-- The exchange: only items no vendor sells (round58-plan.md §2a: no bars,
-- blocks, bricks or other made goods). `pending = "rep"` marks the two items
-- the mason still sells: lane REP deletes the field in the change that takes
-- them off the shelf; until then they are not exchanged.
local EXCHANGE_ITEMS = {
	{item = "default:cobble", pending = "rep"},
	{item = "default:mossycobble"},
	{item = "default:desert_cobble"},
	{item = "grug_materials:granite"},
	{item = "grug_materials:basalt"},
	{item = "grug_materials:slate"},
	{item = "default:gravel", pending = "rep"},
	{item = "default:sand"},
	{item = "default:silver_sand"},
	{item = "default:coal_lump"},
	{item = "default:copper_lump"},
	{item = "default:tin_lump"},
	{item = "default:iron_lump"},
	{item = "grug_materials:quartz"},
	{item = "grug_materials:anthracite"},
	{item = "default:gold_lump"},
	{item = "grug_materials:silver_lump"},
	{item = "grug_materials:emberglass"},
	{item = "grug_materials:abyssal_crystal"},
	{item = "grug_materials:rough_citrine"},
	{item = "grug_materials:rough_jade"},
	{item = "grug_materials:rough_garnet"},
	{item = "grug_materials:rough_sapphire"},
	{item = "grug_materials:rough_ruby"},
	{item = "grug_materials:rough_diamond"},
}

local function value(key)
	local number = V[key]
	if type(number) ~= "number" then
		error("grug_guild catalogue: missing value " .. key)
	end
	return number
end

M.RANKS = {}
for rank = 1, M.MAX_RANK do
	M.RANKS[rank] = value("rank." .. rank)
end

M.EXCHANGE = {}
M.EXCHANGE_BY_ITEM = {}
for index, entry in ipairs(EXCHANGE_ITEMS) do
	local row = {item = entry.item, pending = entry.pending,
		points = value("exchange." .. entry.item .. ".points"),
		lot = value("exchange." .. entry.item .. ".lot")}
	M.EXCHANGE[index] = row
	M.EXCHANGE_BY_ITEM[row.item] = row
end

M.CONSUMABLES = {}
M.CONSUMABLE_BY_ITEM = {}
local PARAMETERS = {
	ore_sense = {"duration", "range", "interval_min", "interval_max", "marker_seconds"},
	treasure_hunt = {"duration", "place_min", "place_max", "marker_range",
		"remove_distance", "respawn_seconds", "check_seconds"},
}
for _, kind in ipairs(M.KINDS) do
	for tier = 1, M.TIER_COUNT do
		local row = {kind = kind, tier = tier,
			item = "grug_guild:" .. kind .. "_t" .. tier,
			name = M.KIND_NAMES[kind] .. " " .. M.NUMERALS[tier],
			-- The rulings: level 1, 11, ..., 51 to use; rank 1..6 to buy.
			use_level = 10 * tier - 9, rank = tier,
			price = value(kind .. ".t" .. tier .. ".price"),
			sell_copper = value("consumable.t" .. tier .. ".sell_copper"),
			variant = M.STATUS.variants[kind]}
		for _, parameter in ipairs(PARAMETERS[kind]) do
			row[parameter] = value(kind .. "." .. parameter)
		end
		if kind == "ore_sense" then
			row.targets = M.ORE_SENSE_TARGETS[tier]
		end
		M.CONSUMABLES[#M.CONSUMABLES + 1] = row
		M.CONSUMABLE_BY_ITEM[row.item] = row
	end
end

M.REMAINS = {}
for tier = 1, M.TIER_COUNT do
	local prefix = "remains.t" .. tier .. "."
	M.REMAINS[tier] = {tier = tier, node = "grug_guild:miners_remains_t" .. tier,
		name = "Miner's Remains", host = TIER_ROCK[tier],
		bar = TIER_BAR[tier], gem = TIER_GEM[tier],
		copper_min = value(prefix .. "copper_min"), copper_max = value(prefix .. "copper_max"),
		bars_min = value(prefix .. "bars_min"), bars_max = value(prefix .. "bars_max"),
		gem_chance = value(prefix .. "gem_chance")}
end

-- Accessors (pure; grug_guild publishes them as its catalogue API).

-- The rank a lifetime total reaches: 0 .. MAX_RANK.
function M.rank_for(lifetime)
	lifetime = tonumber(lifetime) or 0
	local rank = 0
	for index = 1, M.MAX_RANK do
		if lifetime >= M.RANKS[index] then rank = index else break end
	end
	return rank
end

-- The lifetime total a rank needs (0 for rank 0), nil beyond the last rank.
function M.threshold(rank)
	if rank == 0 then return 0 end
	return M.RANKS[rank]
end

-- The exchange row of an item ({item, points, lot}), nil for an item the
-- guild does not take (a pending row included).
function M.exchange_rate(item)
	local row = M.EXCHANGE_BY_ITEM[item]
	if not row or row.pending then return nil end
	return row
end

function M.consumable(kind, tier)
	return M.CONSUMABLE_BY_ITEM["grug_guild:" .. tostring(kind) .. "_t" .. tostring(tier)]
end

function M.consumable_by_item(item)
	return M.CONSUMABLE_BY_ITEM[item]
end

function M.remains(tier)
	return M.REMAINS[tier]
end

-- {id, name} of a faction's guild, nil without a faction.
function M.guild(faction)
	return M.GUILDS[faction]
end

-- The catalogue's shape (raises): every rank rising, every tier of both
-- kinds, positive prices, sane ranges. The fixture checks more.
function M.validate()
	local function fail(message) error("grug_guild catalogue: " .. message, 2) end
	for rank = 1, M.MAX_RANK do
		local at = M.RANKS[rank]
		if at ~= math.floor(at) or at <= (M.RANKS[rank - 1] or 0) then
			fail("rank " .. rank .. " does not rise")
		end
	end
	for _, row in ipairs(M.EXCHANGE) do
		if row.points < 1 or row.lot < 1 or row.points ~= math.floor(row.points) or
				row.lot ~= math.floor(row.lot) then
			fail("bad exchange rate for " .. row.item)
		end
	end
	for _, row in ipairs(M.CONSUMABLES) do
		if row.price < 1 or row.price ~= math.floor(row.price) or row.sell_copper < 0 or
				row.duration <= 0 then
			fail("bad consumable " .. row.item)
		end
		if row.kind == "ore_sense" and (row.interval_min <= 0 or
				row.interval_max < row.interval_min or row.marker_seconds <= 0 or row.range < 1) then
			fail("bad Ore Sense timing of " .. row.item)
		end
		if row.kind == "treasure_hunt" and (row.place_min < 2 or row.place_max < row.place_min or
				row.marker_range < row.place_max or row.remove_distance <= row.marker_range or
				row.respawn_seconds < 0 or row.check_seconds <= 0) then
			fail("bad Treasure Hunt distances of " .. row.item)
		end
	end
	for tier = 1, M.TIER_COUNT do
		local row = M.REMAINS[tier]
		if row.copper_min < 0 or row.copper_max < row.copper_min or row.bars_min < 0 or
				row.bars_max < row.bars_min or row.gem_chance < 1 then
			fail("bad Remains loot of tier " .. tier)
		end
	end
	return true
end

M.validate()

return M
