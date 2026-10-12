-- Round 46 lane ID: the cost of ×N (grug_jobs crafts_from_counts) with a
-- chosen kind per group ingredient, next to tools/r46_ck/bench_count.lua
-- (the same harness, the same three inventories). Numbers are comparisons,
-- never targets.
--
--   luajit tools/r46_id/bench_picks.lua [REPO] [ROUNDS]
--
-- Per inventory: one Sweetroot Mash count with Automatic, with the root on
-- cassava, and with both groups on cassava (one merged item entry).

local root = arg and arg[1] or "."
local rounds = tonumber(arg and arg[2]) or 200
local H = dofile(root .. "/tools/r46_ck/jobs_harness.lua")(root)
local mash = grug_jobs.recipes_for_output("grug_cooking:sweetroot_mash")[1]

local function fill(first, rest, firsts)
	local list = {}
	for index = 1, 128 do
		list[index] = (index <= firsts and first or rest) .. " 99"
	end
	return list
end
local worst = {}
for index = 1, 128 do
	worst[index] = (index % 2 == 1 and "grug_cooking:cassava" or "grug_cooking:wild_grain") .. " 99"
end
local search = fill("grug_cooking:cassava", "grug_cooking:wild_grain", 8)
local mixed = {"grug_cooking:carrot 23", "grug_cooking:wild_grain 17", "grug_cooking:cassava 40",
	"grug_gathering:potato 5", "grug_cooking:wild_grain 30", "grug_cooking:carrot 7",
	"grug_cooking:cassava 99", "grug_cooking:wild_grain 4", "grug_cooking:cassava 5"}

local CHOICES = {
	{"Automatic", nil},
	{"root=cassava", {grug_cooking_root = "grug_cooking:cassava"}},
	{"both=cassava", {grug_cooking_root = "grug_cooking:cassava",
		grug_cooking_staple = "grug_cooking:cassava"}},
}
local function bench(label, list, bag)
	local counts = grug_jobs.ingredient_counts(H.player_with(list, bag))
	for _, choice in ipairs(CHOICES) do
		local started = os.clock()
		local n
		for _ = 1, rounds do
			counts.groups = {}
			n = grug_jobs.crafts_from_counts(counts, mash, choice[2])
		end
		print(("%-10s %-13s Sweetroot Mash x%d: %.4f ms"):format(label, choice[1], n,
			(os.clock() - started) / rounds * 1000))
	end
end

print(("jit %s, %d rounds"):format(jit and jit.status() and "on" or "off", rounds))
bench("worst", worst, 64)
bench("search", search, 64)
bench("mixed", mixed, 3)
