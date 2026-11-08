-- What an Expedition's chest holds (Round 71): one table per catalogue id, rolled
-- once for each player. Pure: no engine calls, so tools/r71_mobs/portable_test.lua
-- runs it as it ships; chest.lua turns a plan into stacks.
--
-- A table: `gear` {quality, chance} rows (quality 1 white, 2 blue, 3 gold, at the run's
-- level as the item level), `coin_bags` {factor, chance} rows (a bag of `factor`
-- times a kill's coin bag at the run's level), `materials` {item, min, max, chance}
-- rows, with `level = {lo, hi}` when a row holds only for some run levels.
-- `chance` is percent, 100 when left out. Ores and gems never: nodes are their
-- only source (concept section 7); M.check refuses them at load.
local M = {}

M.TABLES = {
	-- The hidden test row: proves the mechanism, no player reaches it.
	test_vault = {
		gear = {{quality = 2}, {quality = 3, chance = 25}},
		coin_bags = {{factor = 2}},
		materials = {
			{item = "grug_mobs:spider_silk", min = 2, max = 4},
			{item = "grug_mobs:coarse_spider_silk", min = 1, max = 2, level = {21, 30}},
		},
	},
	-- Level 20-69. Priced by tools/r71_l20/balance.py: the coins are about a quarter
	-- hour of the band's income, the length of a run. The materials are what its
	-- spiders drop in each mob band (grug_mobs data/drops.json, bands of ten levels
	-- from 21; 61-69 drop as band 6): Raw Silk and Venom Glands at every level (the
	-- silk is the Tailor's T4-T6 bolt input), each band's signature silk, and Venom
	-- Sacs where the band has no silk of its own.
	stilled_seam = {
		gear = {{quality = 2}, {quality = 3, chance = 25}},
		coin_bags = {{factor = 10}},
		materials = {
			{item = "grug_mobs:spider_silk", min = 3, max = 5},
			{item = "grug_mobs:coarse_spider_silk", min = 1, max = 2, level = {21, 30}},
			{item = "grug_mobs:venom_gland", min = 1, max = 2, chance = 50},
			{item = "grug_mobs:layered_spider_web", min = 1, max = 2, level = {31, 40}},
			{item = "grug_mobs:venom_sac", min = 1, max = 2, chance = 50, level = {31, 40}},
			{item = "grug_mobs:venom_sac", min = 1, max = 2, level = {41, 50}},
			{item = "grug_mobs:glass_spider_silk", min = 1, max = 2, level = {51, 69}},
		},
	},
	-- Round 72 SHIFT, level 40-69 (round72-second-shift.md "Ore and rewards"): the Seam's
	-- gear and coins (tools/r72_shift/balance.py prices them), and its raiders' and
	-- miners' signature bone and flesh by the run's tier: T4 at 40-49, T5 at 50-59, T6 at
	-- 60-69.
	second_shift = {
		gear = {{quality = 2}, {quality = 3, chance = 25}},
		coin_bags = {{factor = 10}},
		materials = {
			{item = "grug_mobs:marching_bone", min = 3, max = 5, level = {40, 49}},
			{item = "grug_mobs:leathery_flesh", min = 1, max = 2, level = {40, 49}},
			{item = "grug_mobs:siege_bone", min = 3, max = 5, level = {50, 59}},
			{item = "grug_mobs:scorched_flesh", min = 1, max = 2, level = {50, 59}},
			{item = "grug_mobs:unquiet_bone", min = 3, max = 5, level = {60, 69}},
			{item = "grug_mobs:salt_cured_flesh", min = 1, max = 2, level = {60, 69}},
		},
	},
}

-- The chest's slots: at least this, in full rows of 8 when a plan is longer.
M.MIN_SLOTS = 8

function M.slots(plan)
	return math.max(M.MIN_SLOTS, 8 * math.ceil(#plan / 8))
end

-- Every ore and gem the game knows as an item set: what a resource row yields,
-- raw and cut, and the shard a few mobs drop. `resources` is
-- grug_materials.RESOURCES.
function M.ore_items(resources)
	local set = {["grug_materials:emberglass_shard"] = true}
	for _, row in ipairs(resources) do
		set[row.raw_item] = true
		if row.cut_item then set[row.cut_item] = true end
	end
	return set
end

-- Refuses a table that names an ore or gem; `ores` from M.ore_items.
function M.check(ores)
	for id, tbl in pairs(M.TABLES) do
		for _, row in ipairs(tbl.materials or {}) do
			if ores[row.item] then
				error("[grug_expeditions] loot table " .. id .. " names " .. row.item, 0)
			end
		end
	end
end

local function hit(row, random)
	return random(1, 100) <= (row.chance or 100)
end

-- One player's contents at `level`: a list of {quality = n}, {copper = n} and
-- {item = name, count = n}. `random(lo, hi)` is the dice, `coin_range` the {lo, hi}
-- of a kill's coin bag at this level.
function M.plan(tbl, level, random, coin_range)
	local out = {}
	for _, row in ipairs(tbl.gear or {}) do
		if hit(row, random) then out[#out + 1] = {quality = row.quality} end
	end
	for _, row in ipairs(tbl.coin_bags or {}) do
		if hit(row, random) then
			out[#out + 1] = {copper = random(coin_range[1], coin_range[2]) * row.factor}
		end
	end
	for _, row in ipairs(tbl.materials or {}) do
		local fits = not row.level or (level >= row.level[1] and level <= row.level[2])
		if fits and hit(row, random) then
			out[#out + 1] = {item = row.item, count = random(row.min, row.max)}
		end
	end
	return out
end

return M
