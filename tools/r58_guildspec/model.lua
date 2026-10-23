-- Round 58 lane GUILDSPEC: the mining yield model behind the Miner's Guild
-- numbers (docs/design/miners_guild.md §9). A MODEL, not a measurement: no
-- measured mining yield exists. It reads the game's own data and states
-- every assumption it adds.
--
--   local model = dofile(REPO .. "/tools/r58_guildspec/model.lua")
--   local result = model.run(REPO[, values][, assumptions])
--
-- Inputs from the repository (never copied here):
--   the catalogue (mods/PLAYER/grug_guild/catalog.lua VALUES, or `values`);
--   the ore rows (grug_mapgen wp40/r7_r6_manifest.lua: host nodes per ore by
--   band, the vein cap);
--   the resources' items and harvest tiers (grug_materials registry.lua);
--   the pick dig times (grug_materials mining.lua PICK_PROFILES, the tier
--   pick on its own tier rock);
--   the vendor payouts (grug_traders price_rules.lua: class value x tier
--   factor; stone and sand 20 milli-copper each, economy.md §2).
-- The income per band is economy.md §3's table (copied below, the one
-- number set the docs own rather than the code).
--
-- The model, per tier t (a player mining around the camp's room, which lies
-- in the band's lower half, so the "½" rows count at their full rate):
--   nodes dug per hour  = 3600 * active / (dig time of the tier pick + overhead)
--   rock seen per hour  = nodes dug * exposure (a tunnel shows its walls;
--                         every resource seen is dug)
--   resource r per hour = rock seen / host nodes per ore of r in band t
--   reputation per hour = sum of r * points / lot, plus the stone carried
--                         (nodes dug * stone_carried) at Cobblestone's rate
--   copper per hour     = the same goods sold to a vendor instead
-- Rank n is earned by mining at tier min(n, 6) (the tier whose consumables
-- it unlocks; ranks 7-10 at T6).

local M = {}

M.ASSUMPTIONS = {
	-- Share of a mining hour spent digging; the rest is the lift, walking,
	-- searching, sorting, trading and fights.
	active = 0.5,
	-- Seconds per dug node beside the dig itself: stepping, aiming, pickup.
	overhead = 0.35,
	-- Rock nodes seen per node dug (a 1x2 tunnel shows its walls, floor and
	-- ceiling; clusters run on past the wall).
	exposure = 3,
	-- Share of the dug stone the player carries back to trade.
	stone_carried = 0.25,
	-- Share of Ore Sense's marked deposits the player would not have found.
	sense_extra = 0.5,
	-- Seconds from a Miner's Remains appearing to its loot in the bag.
	hunt_reach = 30,
}

-- economy.md §3: net solo income per hour, copper, bands 1-10 ... 51-60.
M.INCOME = {172, 428, 911, 2440, 6448, 14764}

-- The bars and cut gems of the Remains, by the processed-goods rule
-- (economy.md §2: a bar pays its smelting inputs, a cut gem its rough gem).
-- Bronze = Copper Bar + Tin Bar; Iron = Iron Lump; Steel = Iron Bar +
-- Anthracite; the alloys above = Steel + Silver, Emberglass, Abyssal
-- Crystal (Round 57 ruling 25).

local function load_in(path, env)
	local chunk = assert(loadfile(path))
	setfenv(chunk, env)
	return chunk()
end

local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

-- The game data the model reads, loaded once per repository.
local cache = {}
function M.data(repo)
	if cache[repo] then return cache[repo] end
	local data = {}
	local env = {grug_materials = {}, core = {get_modpath = function() return nil end},
		table = table, ipairs = ipairs, pairs = pairs, error = error, math = math,
		tostring = tostring, tonumber = tonumber, type = type, string = string}
	load_in(repo .. "/mods/ITEMS/grug_materials/registry.lua", env)
	data.materials = env.grug_materials
	data.resources = {}
	for _, resource in ipairs(data.materials.RESOURCES) do
		data.resources[resource.key] = resource
	end
	data.ore_rows = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_r6_manifest.lua")().resources
	data.dig = {}
	local mining = read(repo .. "/mods/ITEMS/grug_materials/mining.lua")
	for tier, seconds in mining:gmatch("%[(%d)%] = {tier = %d, key = \"[%w_]+\", ordinary_time = ([%d%.]+)") do
		data.dig[tonumber(tier)] = tonumber(seconds)
	end
	data.prices = dofile(repo .. "/mods/ENTITIES/grug_traders/price_rules.lua")
	data.catalog = dofile(repo .. "/mods/PLAYER/grug_guild/catalog.lua")
	cache[repo] = data
	return data
end

-- The vendor payout of a raw resource item (copper).
local function resource_copper(data, resource)
	return data.prices.payout(resource.gem and "gem" or "raw", resource.harvest_tier)
end

-- Copper of the Remains' bar and cut gem per tier.
function M.loot_copper(data)
	local raw = function(key) return resource_copper(data, data.resources[key]) end
	local iron_bar = raw("iron")
	local steel = iron_bar + raw("anthracite")
	local bars = {raw("copper") + raw("tin"), iron_bar, steel, steel + raw("silver"),
		steel + raw("emberglass"), steel + raw("abyssal_crystal")}
	local gems = {}
	for _, resource in ipairs(data.materials.RESOURCES) do
		if resource.gem then gems[resource.harvest_tier] = resource_copper(data, resource) end
	end
	return bars, gems
end

-- The deposit size of a vein cap (r7_native.lua's shapes: cap 8 a 3-cube of
-- 8 ores, cap 4 a 2-cube of 4, cap 2 a 2-cube of one).
local DEPOSIT = {[8] = 8, [4] = 4, [2] = 1}

function M.run(repo, values, assumptions)
	local data = M.data(repo)
	local V = {}
	for key, number in pairs(data.catalog.VALUES) do V[key] = number end
	for key, number in pairs(values or {}) do V[key] = number end
	local A = {}
	for key, number in pairs(M.ASSUMPTIONS) do A[key] = number end
	for key, number in pairs(assumptions or {}) do A[key] = number end
	local function rate(item)
		return (V["exchange." .. item .. ".points"] or 0) / (V["exchange." .. item .. ".lot"] or 1)
	end

	local result = {assumptions = A, values = V, tiers = {}, ranks = {}, consumables = {}}
	for tier = 1, 6 do
		local stats = {tier = tier, dig = data.dig[tier], found = {}}
		stats.nodes = 3600 * A.active / (stats.dig + A.overhead)
		stats.seen = stats.nodes * A.exposure
		stats.rep_ores, stats.copper, stats.resources = 0, 0, 0
		for _, row in ipairs(data.ore_rows) do
			local denominator = row.denominators[tier]
			if denominator then
				local resource = data.resources[row.key]
				local count = stats.seen / denominator
				stats.found[row.key] = count
				stats.resources = stats.resources + count
				stats.rep_ores = stats.rep_ores + count * rate(resource.raw_item)
				stats.copper = stats.copper + count * resource_copper(data, resource)
			end
		end
		stats.stone = stats.nodes * A.stone_carried
		stats.rep_stone = stats.stone * rate("default:cobble")
		stats.copper = stats.copper + stats.stone * 0.02
		stats.rep = stats.rep_ores + stats.rep_stone
		stats.income = M.INCOME[tier]
		result.tiers[tier] = stats
	end

	local cumulative, previous = 0, 0
	for rank = 1, 10 do
		local at = V["rank." .. rank]
		local tier = math.min(rank, 6)
		local hours = (at - previous) / result.tiers[tier].rep
		cumulative = cumulative + hours
		result.ranks[rank] = {rank = rank, at = at, tier = tier, hours = hours,
			cumulative = cumulative, hours_t6 = at / result.tiers[6].rep}
		previous = at
	end

	local bars, gems = M.loot_copper(data)
	for tier = 1, 6 do
		local stats = result.tiers[tier]
		local row = {tier = tier}
		-- Ore Sense: the marks of one use on the first target's deposits.
		local sense_price = V["ore_sense.t" .. tier .. ".price"]
		local marks = V["ore_sense.duration"] /
			((V["ore_sense.interval_min"] + V["ore_sense.interval_max"]) / 2)
		local target = data.resources[data.catalog.ORE_SENSE_TARGETS[tier][1]]
		local cap
		for _, ore in ipairs(data.ore_rows) do
			if ore.key == target.key then cap = ore.max_nodes_per_vein end
		end
		row.sense_marks = marks
		row.sense_extra = marks * DEPOSIT[cap] * A.sense_extra * rate(target.raw_item)
		row.sense_share = row.sense_extra / sense_price
		row.sense_per_hour = stats.rep / sense_price
		-- Treasure Hunt: the Remains of one use and their loot.
		local hunt_price = V["treasure_hunt.t" .. tier .. ".price"]
		local prefix = "remains.t" .. tier .. "."
		row.hunt_remains = V["treasure_hunt.duration"] /
			(V["treasure_hunt.respawn_seconds"] + A.hunt_reach)
		row.remains_copper = (V[prefix .. "copper_min"] + V[prefix .. "copper_max"]) / 2 +
			(V[prefix .. "bars_min"] + V[prefix .. "bars_max"]) / 2 * bars[tier] +
			gems[tier] / V[prefix .. "gem_chance"]
		row.hunt_copper = row.hunt_remains * row.remains_copper
		row.hunt_income_share = row.hunt_copper / (stats.income / 2)
		row.hunt_per_hour = stats.rep / hunt_price
		result.consumables[tier] = row
	end
	return result
end

-- The doc's generated tables (markdown), from a run.
local function fmt(number, places)
	return string.format("%." .. (places or 0) .. "f", number)
end

local function money(copper)
	copper = math.floor(copper + 0.5)
	local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	if gold > 0 then return gold .. "g " .. silver .. "s " .. rest .. "c" end
	if silver > 0 then return silver .. "s " .. rest .. "c" end
	return rest .. "c"
end
M.money = money

function M.markdown(result)
	local lines = {}
	local function add(line) lines[#lines + 1] = line end
	local A = result.assumptions
	add("Assumptions: digging " .. fmt(A.active * 100) .. " % of the hour, " ..
		fmt(A.overhead, 2) .. " s per node beside the dig, " .. fmt(A.exposure) ..
		" rock nodes seen per node dug, " .. fmt(A.stone_carried * 100) ..
		" % of the stone carried back; Ore Sense finds " .. fmt(A.sense_extra * 100) ..
		" % of its marks extra; a Remains takes " .. fmt(A.hunt_reach) .. " s to reach.")
	add("")
	add("| Tier | Dig s | Nodes dug/h | Resources/h | Reputation/h (stone) | Copper/h if sold | Income/h of the band |")
	add("|---:|---:|---:|---:|---:|---:|---:|")
	for _, stats in ipairs(result.tiers) do
		add("| " .. stats.tier .. " | " .. fmt(stats.dig, 3) .. " | " .. fmt(stats.nodes) .. " | " ..
			fmt(stats.resources) .. " | " .. fmt(stats.rep) .. " (" .. fmt(stats.rep_stone) .. ") | " ..
			money(stats.copper) .. " | " .. money(stats.income) .. " |")
	end
	add("")
	add("| Rank | Lifetime | Mined at | Hours for this rank | Hours in total | Hours at T6 alone |")
	add("|---:|---:|---:|---:|---:|---:|")
	for _, rank in ipairs(result.ranks) do
		add("| " .. rank.rank .. " | " .. rank.at .. " | T" .. rank.tier .. " | " ..
			fmt(rank.hours, 1) .. " | " .. fmt(rank.cumulative, 1) .. " | " .. fmt(rank.hours_t6, 1) .. " |")
	end
	add("")
	add("| Tier | Price | Uses an hour of the tier buys | Ore Sense marks | Ore Sense extra reputation (share of price) | Treasure Hunt Remains | Remains loot each | Loot per use (share of half an hour's income) |")
	add("|---:|---:|---:|---:|---:|---:|---:|---:|")
	for tier, row in ipairs(result.consumables) do
		add("| " .. tier .. " | " .. result.values["ore_sense.t" .. tier .. ".price"] .. " / " ..
			result.values["treasure_hunt.t" .. tier .. ".price"] .. " | " ..
			fmt(row.sense_per_hour, 2) .. " / " .. fmt(row.hunt_per_hour, 2) .. " | " ..
			fmt(row.sense_marks) .. " | " .. fmt(row.sense_extra) .. " (" .. fmt(row.sense_share * 100) ..
			" %) | " .. fmt(row.hunt_remains) .. " | " .. money(row.remains_copper) .. " | " ..
			money(row.hunt_copper) .. " (" .. fmt(row.hunt_income_share * 100) .. " %) |")
	end
	return table.concat(lines, "\n")
end

return M
