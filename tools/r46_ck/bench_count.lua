-- Round 46 lane CK: the cost of the Crafting tab's ×N (grug_jobs
-- crafts_from_counts) per page view, on the real jobs.lua and cooking
-- catalog (jobs_harness.lua). Numbers are comparisons, never targets.
--
--   luajit tools/r46_ck/bench_count.lua [REPO] [ROUNDS]
--   luajit -joff tools/r46_ck/bench_count.lua [REPO] [ROUNDS]
--
-- Three inventories: the review's worst case (128 bag and main slots, half
-- Cassava 99, half Wild Grain 99; Sweetroot Mash then reads ×2112 or the
-- cap), a case whose count needs the search (below), and a realistic one (a
-- start-zone cook's 30 mixed stacks). Per
-- inventory it prints the mean time of one Sweetroot Mash count and of one
-- page view (one ingredient_counts pass plus the count of all 24 Cooking
-- recipes), and the counts.

local root = arg and arg[1] or "."
local rounds = tonumber(arg and arg[2]) or 200
local H = dofile(root .. "/tools/r46_ck/jobs_harness.lua")(root)
local mash = grug_jobs.recipes_for_output("grug_cooking:sweetroot_mash")[1]

local worst = {}
for index = 1, 128 do
	worst[index] = (index % 2 == 1 and "grug_cooking:cassava" or "grug_cooking:wild_grain") .. " 99"
end
-- The search itself: 8 of 128 slots Cassava 99, the rest Wild Grain 99, so
-- the true count (264) lies below both the per-entry total and the cap.
local search = {}
for index = 1, 128 do
	search[index] = (index <= 8 and "grug_cooking:cassava" or "grug_cooking:wild_grain") .. " 99"
end
local realistic = {
	"grug_cooking:cassava 23", "grug_cooking:wild_grain 17", "mobs:meat_raw 12",
	"grug_cooking:fire_pepper 6", "grug_mobs:raw_fish 9", "grug_gathering:corn 4",
	"grug_cooking:carrot 3", "default:apple 5", "grug_cooking:sugar_cane 8",
	"grug_cooking:cassava 40", "grug_cooking:wild_onion 2", "grug_cooking:bamboo_shoot 3",
	"grug_cooking:pumpkin 1", "default:blueberries 6", "grug_fishing:silver_trout 2",
	"grug_cooking:wild_grain 30", "mobs:meat_raw 20", "grug_cooking:cave_cap 1",
	"grug_gathering:potato 2", "grug_cooking:fire_pepper 10", "grug_mobs:raw_fish 3",
	"grug_cooking:carrot 7", "grug_cooking:cassava 99", "grug_cooking:wild_grain 4",
	"default:apple 2", "mobs:meat_raw 3", "grug_cooking:sugar_cane 1",
	"grug_gathering:corn 9", "grug_cooking:wild_onion 1", "grug_cooking:cassava 5",
}

local function bench(label, list, bag)
	local player = H.player_with(list, bag)
	local counts = grug_jobs.ingredient_counts(player)
	local started = os.clock()
	local n
	for _ = 1, rounds do
		counts.groups = {}
		n = grug_jobs.crafts_from_counts(counts, mash)
	end
	local one = (os.clock() - started) / rounds
	started = os.clock()
	local total
	for _ = 1, rounds do
		local view = grug_jobs.ingredient_counts(player)
		total = 0
		for _, recipe in ipairs(H.recipes) do
			total = total + grug_jobs.crafts_from_counts(view, recipe)
		end
	end
	local page = (os.clock() - started) / rounds
	print(("%-10s Sweetroot Mash x%d: %.3f ms; page view (24 recipes, sum x%d): %.3f ms"):format(
		label, n, one * 1000, total, page * 1000))
end

print(("jit %s, %d rounds"):format(jit and jit.status() and "on" or "off", rounds))
bench("worst", worst, 64)
bench("search", search, 64)
bench("realistic", realistic, 12)
