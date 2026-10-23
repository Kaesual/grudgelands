-- Round 58 lane GUILDSPEC portable fixture (LuaJIT): the Miner's Guild
-- catalogue (mods/PLAYER/grug_guild/catalog.lua) and its contract.
--
--   luajit tools/r58_guildspec/portable_test.lua REPO
--
-- A. The catalogue's shape: every tunable number in VALUES and used, ten
--    rising ranks whose steps never shrink (the last ones hardest), both
--    kinds in all six tiers with the ruled use levels (1, 11, ..., 51) and
--    purchase ranks (1..6), rising prices, Remains worth more deeper, Ore
--    Sense's targets the resources of its harvest tier (gem first), the
--    Remains' rock, bar and gem the tier's own (grug_materials registry),
--    the accessors, and validate() refusing a broken catalogue.
-- B. Round 58 §2a on the real game (the r57_details harness and Round 57's
--    source index, grug_jobs/sources.lua): no exchanged item has a vendor
--    source; each is registered and has a source of its own (mining, digging,
--    a drop); a `pending` row is exactly an item a vendor still sells (the
--    mason's Cobblestone and Gravel until lane REP takes them off the shelf
--    and deletes the field); no made goods (bars, blocks, bricks, cut gems);
--    every mined resource is exchanged. grug_guild loads, publishes its API
--    (the stubs answer rank 0) and registers no item yet.
-- C. No copper loop: a vendor pays for a consumable at most what the
--    materials behind its price would have sold for (the cheapest copper per
--    point of the exchange; stone and sand at prices.lua's bulk value), and
--    no Remains loot is an exchanged item (Treasure Hunt cannot feed
--    reputation).
-- D. The spec's generated model tables are current (write_doc.lua) and the
--    tuning page builds with every catalogue key (build_page.lua).
-- Prints "R58 GUILDSPEC PORTABLE PASS checks=<n>" or raises.

local repo = assert(arg and arg[1], "usage: luajit portable_test.lua REPO")
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
end
local function eq(actual, expected, label)
	check(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local CATALOG = repo .. "/mods/PLAYER/grug_guild/catalog.lua"
local C = dofile(CATALOG)
local model = dofile(repo .. "/tools/r58_guildspec/model.lua")
local data = model.data(repo)
local materials = data.materials

------------------------------------------------------------------------------
-- A. The catalogue's shape.
------------------------------------------------------------------------------
check(C.validate(), "A validate() accepts the shipped catalogue")

-- Every VALUES key is one the tables read, and every read key exists.
local expected = {}
for rank = 1, C.MAX_RANK do expected["rank." .. rank] = true end
for _, row in ipairs(C.EXCHANGE) do
	expected["exchange." .. row.item .. ".points"] = true
	expected["exchange." .. row.item .. ".lot"] = true
end
for _, kind in ipairs(C.KINDS) do
	for tier = 1, 6 do expected[kind .. ".t" .. tier .. ".price"] = true end
end
for tier = 1, 6 do expected["consumable.t" .. tier .. ".sell_copper"] = true end
for _, key in ipairs({"duration", "range", "interval_min", "interval_max", "marker_seconds"}) do
	expected["ore_sense." .. key] = true
end
for _, key in ipairs({"duration", "place_min", "place_max", "marker_range", "remove_distance",
		"respawn_seconds", "check_seconds"}) do
	expected["treasure_hunt." .. key] = true
end
for tier = 1, 6 do
	for _, key in ipairs({"copper_min", "copper_max", "bars_min", "bars_max", "gem_chance"}) do
		expected["remains.t" .. tier .. "." .. key] = true
	end
end
local value_count = 0
for key, number in pairs(C.VALUES) do
	value_count = value_count + 1
	check(expected[key], "A VALUES key is read by the catalogue: " .. key)
	check(type(number) == "number" and number >= 0 and number == math.floor(number),
		"A VALUES number is a whole number: " .. key)
end
for key in pairs(expected) do check(C.VALUES[key] ~= nil, "A VALUES has " .. key) end
-- The apply script's line pattern finds every key once.
local lines = 0
for key in read("mods/PLAYER/grug_guild/catalog.lua"):gmatch('\n\t%["([^"]+)"%] = %d+,') do
	lines = lines + 1
	check(expected[key], "A VALUES line names a catalogue key: " .. key)
end
eq(lines, value_count, "A every VALUES entry sits on its own line (apply_tuning.py)")

-- Ranks: rising, with steps that never shrink.
eq(#C.RANKS, 10, "A ten ranks")
local step = 0
for rank = 1, 10 do
	local this = C.RANKS[rank] - (C.RANKS[rank - 1] or 0)
	check(this > 0 and this >= step, "A rank " .. rank .. " rises by at least the step before")
	step = this
end
eq(C.rank_for(0), 0, "A rank_for(0)")
eq(C.rank_for(C.RANKS[1] - 1), 0, "A rank_for just below rank 1")
eq(C.rank_for(C.RANKS[1]), 1, "A rank_for at rank 1")
eq(C.rank_for(C.RANKS[6] + 1), 6, "A rank_for above rank 6")
eq(C.rank_for(2147483647), 10, "A rank_for at the clamp")
eq(C.threshold(0), 0, "A threshold(0)")
eq(C.threshold(10), C.RANKS[10], "A threshold(10)")
eq(C.threshold(11), nil, "A threshold beyond the last rank")

-- The consumables.
eq(#C.CONSUMABLES, 12, "A twelve consumables")
for _, kind in ipairs(C.KINDS) do
	local last_price, last_sell = 0, -1
	for tier = 1, 6 do
		local row = C.consumable(kind, tier)
		check(row ~= nil, "A " .. kind .. " tier " .. tier .. " exists")
		if row then
			eq(row.item, "grug_guild:" .. kind .. "_t" .. tier, "A item id")
			eq(C.consumable_by_item(row.item), row, "A consumable_by_item " .. row.item)
			eq(row.use_level, 10 * tier - 9, "A use level of " .. row.item .. " (ruling)")
			eq(row.rank, tier, "A purchase rank of " .. row.item .. " (ruling)")
			check(row.price > last_price, "A " .. row.item .. " costs more than the tier below")
			check(row.sell_copper > last_sell, "A " .. row.item .. " sells for more than the tier below")
			eq(row.variant, C.STATUS.variants[kind], "A " .. row.item .. " variant")
			last_price, last_sell = row.price, row.sell_copper
		end
	end
end
eq(C.STATUS.id, "mining_sense", "A the effect slot's status id")
check(C.STATUS.id ~= "elixir", "A the effect slot is not the elixir's")
local sense = C.consumable("ore_sense", 1)
check(sense.interval_min == 60 and sense.interval_max == 120 and sense.marker_seconds == 5,
	"A Ore Sense keeps the ruled 60-120 s and 5 s")

-- Ore Sense targets: the resources of the item's harvest tier, gem first.
for tier = 1, 6 do
	local targets, want = C.ORE_SENSE_TARGETS[tier], {}
	for _, resource in ipairs(materials.RESOURCES) do
		if resource.harvest_tier == tier then want[resource.key] = resource end
	end
	local seen = 0
	for index, key in ipairs(targets) do
		check(want[key] ~= nil, "A Ore Sense T" .. tier .. " target " .. key .. " is of harvest tier " .. tier)
		if index == 1 then check(want[key] and want[key].gem, "A Ore Sense T" .. tier .. " looks for its gem first") end
		seen = seen + 1
	end
	local count = 0
	for _ in pairs(want) do count = count + 1 end
	eq(seen, count, "A Ore Sense T" .. tier .. " targets every resource of its tier")
end

-- The Remains: the tier's rock, bar and gem; worth more deeper.
local bars, gems = model.loot_copper(data)
local last_value = 0
for tier = 1, 6 do
	local row = C.remains(tier)
	eq(row.node, "grug_guild:miners_remains_t" .. tier, "A Remains node id " .. tier)
	eq(row.host, materials.TIERS[tier].node, "A Remains T" .. tier .. " sits in the tier rock")
	eq(row.bar, materials.TIERS[tier].bar_item, "A Remains T" .. tier .. " gives the tier's bar")
	local gem
	for _, resource in ipairs(materials.RESOURCES) do
		if resource.gem and resource.harvest_tier == tier then gem = resource.cut_item end
	end
	eq(row.gem, gem, "A Remains T" .. tier .. " gives the tier's cut gem")
	local worth = (row.copper_min + row.copper_max) / 2 + (row.bars_min + row.bars_max) / 2 * bars[tier] +
		gems[tier] / row.gem_chance
	check(worth > last_value, "A Remains T" .. tier .. " is worth more than the tier above")
	last_value = worth
end

-- The guilds.
eq(C.guild("accord").name, "The Charter of Stone", "A The Accord's guild")
eq(C.guild("throng").name, "The Oathdelvers", "A The Throng's guild")
eq(C.guild(nil), nil, "A no guild without a faction")

-- validate() refuses a broken catalogue.
do
	local broken = dofile(CATALOG)
	broken.RANKS[5] = broken.RANKS[4]
	check(not pcall(broken.validate), "A validate() refuses a rank that does not rise")
	broken = dofile(CATALOG)
	broken.consumable("treasure_hunt", 2).remove_distance = 0
	check(not pcall(broken.validate), "A validate() refuses a Remains that vanishes inside its marker range")
end

------------------------------------------------------------------------------
-- B. Round 58 §2a on the real game.
------------------------------------------------------------------------------
local game = dofile(repo .. "/tools/r57_details/game_harness.lua")(repo)
for _, line in ipairs(game.failures) do
	check(not line:find("grug_guild", 1, true), "B grug_guild loads in the harness: " .. line)
end
local S = grug_jobs.sources
local index = S.build(S.game_data())
local OWN = {mining = true, dig = true, drop = true, gather = true, fishing = true}
local made = {"_bar$", "_block$", "brick", "^grug_materials:cut_", "stair", "slab"}
for _, row in ipairs(C.EXCHANGE) do
	check(game.items[row.item] ~= nil, "B " .. row.item .. " is registered")
	local vendors, own = {}, false
	for _, source in ipairs(index.sources(row.item)) do
		if source.kind == "vendor" then vendors[#vendors + 1] = source.label end
		if OWN[source.kind] then own = true end
	end
	check(own, "B " .. row.item .. " has a source of its own (mining, digging, a drop)")
	if row.pending then
		check(#vendors > 0, "B pending " .. row.item .. " still has a vendor source (else delete `pending`)")
		print("note " .. row.item .. ": sold by " .. table.concat(vendors, ", ") ..
			"; joins the exchange when lane REP takes it off the shelf")
		eq(C.exchange_rate(row.item), nil, "B a pending row is not exchanged yet")
	else
		check(#vendors == 0, "B " .. row.item .. " has no vendor source (" .. table.concat(vendors, ", ") .. ")")
		eq(C.exchange_rate(row.item), row, "B exchange_rate " .. row.item)
	end
	for _, pattern in ipairs(made) do
		check(not row.item:find(pattern), "B " .. row.item .. " is no made good (" .. pattern .. ")")
	end
end
for _, resource in ipairs(materials.RESOURCES) do
	check(C.EXCHANGE_BY_ITEM[resource.raw_item] ~= nil, "B every mined resource is exchanged: " .. resource.raw_item)
end
eq(C.exchange_rate("grug_materials:iron_bar"), nil, "B a bar is not exchanged")
eq(C.exchange_rate("default:stonebrick"), nil, "B a brick is not exchanged")

-- grug_guild in the game: its API, the stubs at rank 0, no item yet.
check(type(grug_guild) == "table" and grug_guild.catalog ~= nil, "B grug_guild publishes its catalogue")
for _, name in ipairs({"rank_for", "threshold", "exchange_rate", "consumable", "consumable_by_item",
		"remains", "guild", "lifetime", "balance", "rank", "add", "spend", "register_on_change",
		"register_on_rank_change", "trade_in_rows", "trade_in", "active_effect", "start_effect",
		"stop_effect", "remains_loot", "vendor_rows", "buy"}) do
	check(type(grug_guild[name]) == "function", "B grug_guild." .. name .. " is published")
end
eq(grug_guild.rank({}), 0, "B the store stub answers rank 0")
eq(select(2, grug_guild.spend({}, 1)), "insufficient", "B the store stub refuses a spend")
local rows = grug_guild.vendor_rows({})
eq(#rows, 6, "B the vendor stub lists six rows")
check(not rows[1].unlocked and rows[6].items[2].item == "grug_guild:treasure_hunt_t6",
	"B the vendor stub's rows are locked and hold both kinds")
for name in pairs(game.items) do
	check(not name:find("^grug_guild:"), "B the skeleton registers no item yet: " .. name)
end

------------------------------------------------------------------------------
-- C. No copper loop.
------------------------------------------------------------------------------
local bulk = {}
local prices_lua = read("mods/ENTITIES/grug_traders/prices.lua")
for list, value in prices_lua:gmatch("ipairs%((%b{})%) do%s+BULK%[name%] = (%d+)") do
	for item in list:gmatch('"([%w_]+:[%w_]+)"') do bulk[item] = tonumber(value) end
end
local resource_by_item = {}
for _, resource in ipairs(materials.RESOURCES) do resource_by_item[resource.raw_item] = resource end
local cheapest = math.huge
for _, row in ipairs(C.EXCHANGE) do
	local copper
	local resource = resource_by_item[row.item]
	if resource then
		copper = data.prices.payout(resource.gem and "gem" or "raw", resource.harvest_tier)
	else
		check(bulk[row.item] == 20, "C " .. row.item .. " sells at prices.lua's 20 mc (1c per 50)")
		copper = (bulk[row.item] or 0) / 1000
	end
	cheapest = math.min(cheapest, copper * row.lot / row.points)
end
check(cheapest > 0 and cheapest < math.huge, "C a cheapest copper per point exists (" .. cheapest .. "c)")
for _, row in ipairs(C.CONSUMABLES) do
	check(row.sell_copper <= row.price * cheapest,
		"C " .. row.item .. " sells for at most the copper behind its price (" .. row.sell_copper ..
		"c <= " .. row.price * cheapest .. "c)")
end
for tier = 1, 6 do
	local row = C.remains(tier)
	eq(C.EXCHANGE_BY_ITEM[row.bar], nil, "C the Remains' bar is not exchanged (T" .. tier .. ")")
	eq(C.EXCHANGE_BY_ITEM[row.gem], nil, "C the Remains' cut gem is not exchanged (T" .. tier .. ")")
end

------------------------------------------------------------------------------
-- D. The spec's model tables and the tuning page.
------------------------------------------------------------------------------
local doc = dofile(repo .. "/tools/r58_guildspec/write_doc.lua")
local _, stale = doc.render(repo)
check(not stale, "D docs/design/miners_guild.md's model tables are current (write_doc.lua)")
local page = dofile(repo .. "/tools/r58_guildspec/build_page.lua")
local names = {}
for item, def in pairs(game.items) do names[item] = (def.description or ""):match("^[^\n]*") end
local html = page.build(repo, names)
for key in pairs(C.VALUES) do
	check(html:find('"' .. key .. '":', 1, true), "D the page carries " .. key)
end
check(not html:find("__DATA__", 1, true), "D the page's data is filled in")
check(not html:find("<script src", 1, true), "D the page loads no external script")
for url in html:gmatch('href="(https?://[^"]+)"') do
	check(url:find("^https://fonts%.googleapis%.com/"), "D the page links only Google Fonts: " .. url)
end
check(html:find('db.doc("picks/tuning")', 1, true), "D the page saves to picks/tuning")
local result = model.run(repo)
for tier = 1, 6 do
	check(result.tiers[tier].rep > (result.tiers[tier - 1] or {rep = 0}).rep,
		"D the model: an hour deeper earns more reputation (T" .. tier .. ")")
end

if failures > 0 then
	error("R58 GUILDSPEC PORTABLE FAIL " .. failures .. " of " .. checks)
end
print(string.format("R58 GUILDSPEC model: reputation per hour %.0f / %.0f / %.0f / %.0f / %.0f / %.0f, rank 10 after %.1f h",
	result.tiers[1].rep, result.tiers[2].rep, result.tiers[3].rep, result.tiers[4].rep,
	result.tiers[5].rep, result.tiers[6].rep, result.ranks[10].cumulative))
print("R58 GUILDSPEC PORTABLE PASS checks=" .. checks)
