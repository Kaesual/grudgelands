-- Round 57 lane DETAILS portable test (LuaJIT): the ingredient source index
-- (round57-plan.md ruling 5, §4 DETAILS; mods/PLAYER/grug_jobs/sources.lua).
--
--   luajit tools/r57_details/portable_test.lua [REPO]
--
--   S  the pure build on synthetic data: every kind of source with its
--      fields, a group input, a shelf listing an item twice, the drop
--      tables' bands and leader rows, a sub-type's static drops in the band
--      its table leaves open, a base mob's static drops, herb and cave
--      plant zones and depths, mining tiers and the lower half, fishing and
--      farming, a log from its tree (not from a hidden shape node), a
--      sapling from leaves, natural ground; the order by kind; group
--      members without hidden members; has_source for a group;
--   M  grug_mobs.drop_tables (the new read-only accessor) on the real data:
--      every drops.json family, copies a caller cannot change;
--   R  the index on the real registered data (the whole game under
--      tools/r57_details/game_harness.lua): every recipe ingredient and
--      every enchant input has a source, except the listed gaps; a bar
--      from its furnace and an alloy from the dual furnace; Linen Scrap's
--      drops with level bands and leaders; a herb's zones and Alchemy
--      tier; Thread's vendors; an ore's rock tiers; and prints the gaps
--      and the index's size and build time (comparisons, not targets).
-- Prints "R57 DETAILS PORTABLE PASS checks=<n>" or the failures.

local repo = arg and arg[1] or "."
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function kinds(list)
	local out = {}
	for index, source in ipairs(list) do out[index] = source.kind end
	return table.concat(out, ",")
end
local function find(list, fields)
	for _, source in ipairs(list) do
		local all = true
		for key, value in pairs(fields) do
			if source[key] ~= value then all = false end
		end
		if all then return source end
	end
	return nil
end

------------------------------------------------------------------------------
-- S: the pure build.
------------------------------------------------------------------------------
grug_jobs = {}
local S = dofile(repo .. "/mods/PLAYER/grug_jobs/sources.lua")
check(grug_jobs.sources == S and type(grug_jobs.item_sources) == "function",
	"S the module publishes grug_jobs.sources and item_sources")
grug_jobs = nil

local function node(description, groups, drop)
	return {type = "node", description = description, groups = groups or {}, drop = drop}
end
local function craft(description, groups)
	return {type = "craft", description = description .. "\nsecond line", groups = groups or {}}
end
local items = {
	["t:bar"] = craft("Bar"), ["t:lump"] = craft("Lump"), ["t:alloy"] = craft("Alloy"),
	["t:thread"] = craft("Thread"), ["t:scrap"] = craft("Scrap"),
	["t:herb"] = craft("Herb"), ["t:carrot"] = craft("Carrot"), ["t:moss"] = craft("Moss"),
	["t:ore"] = node("Ore", {grug_natural = 1, grug_resource = 1}, "t:lump"),
	["t:gem"] = craft("Gem"), ["t:fish"] = craft("Fish"), ["t:seed"] = craft("Seed"),
	["t:log"] = node("Log", {tree = 1}),
	["t:log_shape"] = node("Log Shape", {tree = 1, not_in_creative_inventory = 1}, "t:log"),
	["t:leaves"] = node("Leaves", {leaves = 1}, {items = {{items = {"t:sapling"}, rarity = 20},
		{items = {"t:leaves"}}}}),
	["t:sapling"] = node("Sapling", {}),
	["t:clay"] = node("Clay", {grug_natural = 1}, "t:clay_lump 4"),
	["t:clay_lump"] = craft("Clay Lump"),
	["t:bush"] = node("Bush Stem", {}),
	["t:herb_source"] = node("Herb Plant", {grug_gathering_source = 1}, "t:herb"),
	["t:moss_source"] = node("Moss Plant", {grug_gathering_source = 1, grug_healing_herb = 5}, "t:moss"),
	["t:crop_1"] = node("Carrot Crop", {}, "t:carrot"),
	["t:plank_a"] = craft("Plank A", {wood = 1}), ["t:plank_b"] = craft("Plank B", {wood = 1}),
	["t:plank_hidden"] = craft("Plank Hidden", {wood = 1, not_in_creative_inventory = 1}),
	["t:brick"] = node("Brick", {}),
}
local index = S.build({
	items = items,
	recipes = {
		{id = "t:thread|t:scrap*1", output = "t:thread", count = 2, area = "basic", tier = 1,
			ingredients = {{item = "t:scrap", n = 1}}},
		{id = "t:bar|t:thread*1", output = "t:bar", count = 1, area = "tailor",
			profession = "tailor", tier = 2, station = "tailor_bench",
			ingredients = {{item = "t:thread", n = 1}}},
		{id = "t:brick|group:wood*2", output = "t:brick", count = 1, area = "basic", tier = 1,
			ingredients = {{group = "wood", n = 2}}},
	},
	cooking = {{output = "t:bar", count = 1, input = "t:lump"},
		{output = "t:clay_lump", count = 1, input = "group:wood"}},
	alloys = {{output = "t:alloy", inputs = {"t:bar", "t:gem"}, time = 10}},
	shelves = {
		{vendor = "quartermaster", label = "Quartermaster", where = S.WHERE_CORE,
			item = "t:thread", price = 1},
		{vendor = "tailor", label = "Tailor", where = S.WHERE_SHOP, item = "t:thread", price = 2},
		{vendor = "tailor", label = "Tailor", where = S.WHERE_SHOP, item = "t:thread", price = 1},
		{vendor = "tailor", label = "Tailor", where = S.WHERE_SHOP, item = "t:scrap", price = 3},
	},
	drop_tables = {
		outlaw = {bands = {[1] = {{name = "t:scrap", chance = 1, min = 1, max = 2}},
			[3] = {{name = "t:gem", chance = 50, min = 1, max = 1}}},
			leader_bonus = {{name = "t:scrap", chance = 1, min = 2, max = 3}}},
	},
	subtypes = {
		grain_pilferer = {drops = "outlaw", display = "Grain Pilferer", levels = {9, 12}},
		mudlark = {drops = "outlaw", display = "Mudlark", levels = {21, 25}},
		chief = {drops = "outlaw", display = "Bandit Chief", levels = {8, 8}, leader = true},
	},
	entities = {
		["grug_mobs:grain_pilferer"] = {drops = {{name = "t:bar", chance = 4, min = 1, max = 1}}},
		["grug_mobs:mudlark"] = {drops = {{name = "t:fish", chance = 2}}},
		["grug_mobs:cave_bat"] = {description = "Cave Bat\nx", drops = {{name = "t:fish", chance = 3}},
			_grug_min_level = 5, _grug_max_level = 9},
		["grug_mobs:outlaw"] = {drops = {{name = "t:herb", chance = 1}}},
	},
	herbs = {{source_node = "t:herb_source", raw_item = "t:herb",
		zones = {"zone_b", "zone_a"}, harvest_kind = "healing_herb", required_group = 2}},
	plants = {
		{node = "t:moss_source", item = "t:moss", zones = {}, min = -900, max = -701, mode = "cave"},
		{node = "t:crop_1", item = "t:carrot", zones = {"zone_a"}, min = 1, max = 6, mode = "surface"},
	},
	resources = {{key = "gem", name = "Gem", natural_node = "t:ore", raw_item = "t:gem",
		harvest_tier = 2}},
	ore_rows = {gem = {denominators = {false, 512, 1024, false, false, false}, lower_half_of = 2}},
	catch = {[1] = {{name = "t:fish", weight = 90}, {name = "t:bush", weight = 10}}},
	catch_total = 100,
	crops = {{key = "carrot", harvest_item = "t:carrot", seed = "t:seed", stages = {"t:crop_1"}}},
	world_nodes = {"t:bush"},
	zone = function(id) return {display_name = "Zone " .. id} end,
})

local thread = index.sources("t:thread")
eq(kinds(thread), "recipe,vendor,vendor", "S Thread: its recipe, then the Quartermaster and one Tailor")
local recipe = thread[1]
check(recipe.id == "t:thread|t:scrap*1" and recipe.area == "basic" and recipe.count == 2 and
	recipe.tier == 1 and recipe.profession == nil, "S a recipe source: id, area, count, tier, no profession")
check(thread[2].vendor == "quartermaster" and thread[2].where == S.WHERE_CORE and thread[2].price == 1,
	"S the core shelf first: every town and capital, 1c")
check(thread[3].vendor == "tailor" and thread[3].price == 1 and thread[3].where == S.WHERE_SHOP,
	"S a shelf listing an item twice is one source at its lower price")
local bar = index.sources("t:bar")
eq(kinds(bar), "recipe,furnace,drop", "S Bar: recipe, furnace, then the sub-type's static drop")
check(bar[1].station == "tailor_bench" and bar[1].profession == "tailor" and bar[1].tier == 2,
	"S a profession recipe names its station, profession and tier")
check(bar[2].input == "t:lump" and bar[2].count == 1, "S the furnace names its input")
check(bar[3].mob == "grug_mobs:grain_pilferer" and bar[3].label == "Grain Pilferer" and
	bar[3].levels[1] == 11 and bar[3].levels[2] == 12 and bar[3].chance == 4,
	"S a sub-type drops its static drops in the band its table leaves open (11-12)")
check(index.sources("t:clay_lump")[1].input == "group:wood", "S a furnace takes a group input")
local alloy = index.sources("t:alloy")[1]
check(alloy and alloy.kind == "alloy" and alloy.inputs[1] == "t:bar" and alloy.inputs[2] == "t:gem" and
	alloy.time == 10, "S the dual furnace's alloy names both inputs")

local scrap = index.sources("t:scrap")
eq(kinds(scrap), "vendor,drop,drop", "S Scrap: the Tailor, the band-1 drop and the leader drop")
local band = find(scrap, {kind = "drop", band = 1})
check(band and band.key == "outlaw" and band.levels[1] == 1 and band.levels[2] == 10 and
	band.min == 1 and band.max == 2 and table.concat(band.mobs, ",") == "Bandit Chief,Grain Pilferer",
	"S a band drop: its table, levels 1-10, counts, the sub-types of that band by level")
local leader = find(scrap, {kind = "drop", leader = true})
check(leader and leader.band == nil and table.concat(leader.mobs, ",") == "Bandit Chief" and
	leader.min == 2, "S the leader rows name only the family's leaders")
local gem = index.sources("t:gem")
eq(kinds(gem), "drop,mining", "S Gem: the band-3 drop, then mining")
check(gem[1].band == 3 and table.concat(gem[1].mobs, ",") == "Mudlark", "S the band-3 drop names Mudlark")
check(gem[2].resource == "gem" and gem[2].harvest_tier == 2 and table.concat(gem[2].tiers, ",") == "2,3" and
	gem[2].lower_half == 2 and gem[2].pick_level == 0, "S mining: the rock tiers of its row and the lower half")
check(find(index.sources("t:fish"), {mob = "grug_mobs:mudlark"}) == nil,
	"S a sub-type whose table covers its band keeps no static drop")
local bat = find(index.sources("t:fish"), {mob = "grug_mobs:cave_bat"})
check(bat and bat.label == "Cave Bat" and bat.levels[1] == 5 and bat.levels[2] == 9 and bat.chance == 3,
	"S a mob outside every table drops its static drops, with its levels")
check(find(index.sources("t:herb"), {kind = "drop"}) == nil,
	"S a base mob whose role has a table keeps no static drop")
local fishing = find(index.sources("t:fish"), {kind = "fishing"})
check(fishing and fishing.band == 1 and fishing.weight == 90 and fishing.levels[2] == 10,
	"S fishing: band, levels and the share in percent")

local herb = index.sources("t:herb")[1]
check(herb.kind == "gather" and table.concat(herb.zones, ",") == "zone_a,zone_b" and
	herb.alchemy_tier == 2 and herb.node == "t:herb_source", "S a herb: its zones (sorted) and Alchemy tier")
local moss = index.sources("t:moss")[1]
check(moss.kind == "gather" and moss.depth[1] == -900 and moss.depth[2] == -701 and
	moss.levels == nil and moss.alchemy_tier == 5 and #moss.zones == 0,
	"S a cave plant: its depth and the healing herb's tier from its node")
local carrot = index.sources("t:carrot")
eq(kinds(carrot), "gather,farming", "S Carrot: the wild plant, then farming (no dig of its crop node)")
check(carrot[1].levels[1] == 1 and carrot[1].levels[2] == 6 and carrot[1].zones[1] == "zone_a" and
	carrot[2].crop == "carrot" and carrot[2].seed == "t:seed", "S the wild plant's levels and the crop's seed")

eq(kinds(index.sources("t:log")), "tree", "S a log: one tree source (the hidden shape node adds none)")
eq(index.sources("t:log")[1].node, "t:log", "S ...from the log itself")
local sapling = index.sources("t:sapling")[1]
check(sapling and sapling.kind == "tree" and sapling.node == "t:leaves", "S a sapling from the leaves")
local clay = index.sources("t:clay_lump")
check(find(clay, {kind = "dig", node = "t:clay"}) ~= nil, "S natural ground gives what it drops")
check(find(index.sources("t:bush"), {kind = "dig"}) ~= nil, "S a mapgen world node is natural")
check(find(index.sources("t:bush"), {kind = "fishing"}) ~= nil, "S ...and junk is caught")
eq(#index.sources("t:lump"), 0, "S a resource's ore node is no dig source (mining names its item)")
eq(#index.sources("t:brick"), 1, "S a placed block that drops itself is no source of itself")
eq(#index.sources("t:nothing"), 0, "S an unknown item has no source")
eq(table.concat(index.members("wood"), ","), "t:plank_a,t:plank_b", "S group members, hidden left out")
check(not index.has_source("group:wood"), "S a group without a member source has no source")
check(index.has_source("group:tree") and index.has_source("t:thread") and not index.has_source("t:plank_a"),
	"S has_source for a group (any member) and an item")
eq(index.label("t:bar"), "Bar", "S an item's label is its description's first line")
eq(index.label("t:none"), "t:none", "S an unknown item's label is its name")
eq(index.zone("x").display_name, "Zone x", "S zone records come from the data")

------------------------------------------------------------------------------
-- M and R: the real game.
------------------------------------------------------------------------------
local started = os.clock()
local game = dofile(repo .. "/tools/r57_details/game_harness.lua")(repo)
local load_seconds = os.clock() - started
local failed = {}
for _, line in ipairs(game.failures) do failed[#failed + 1] = line:match("^[^:]+") end
eq(table.concat(failed, " "), "mods/PLAYER/grug_quests/loader.lua mods/PLAYER/grug_home/init.lua",
	"R the harness skips only the files that want the world (the quest loader, grug_home)")
check(#grug_jobs.recipes > 600, "R the real recipe registry is loaded (" .. #grug_jobs.recipes .. " recipes)")

local tables = grug_mobs.drop_tables()
local families = 0
for _ in pairs(tables) do families = families + 1 end
local json = dofile(repo .. "/tools/r28_b1/json.lua")
local handle = assert(io.open(repo .. "/mods/ENTITIES/grug_mobs/data/drops.json"))
local drops_json = json.parse(handle:read("*a"))
handle:close()
eq(families, #(drops_json.drops or drops_json), "M drop_tables: every drops.json family")
local zombie_rows = tables.zombie.bands[1]
check(zombie_rows and zombie_rows[1].name and zombie_rows[1].chance, "M a band's rows carry name and chance")
tables.zombie.bands[1] = nil
check(grug_mobs.drop_tables().zombie.bands[1] ~= nil, "M drop_tables answers copies")

started = os.clock()
local real = S.build(S.game_data())
local build_seconds = os.clock() - started

-- Every recipe ingredient and enchant input has a source, except these
-- (each a data question for the user, reported by the lane):
local KNOWN_GAPS = {
	["dye:white"] = "no recipe or source makes White Dye (Wool White needs it)",
	["dye:yellow"] = "no recipe or source makes Yellow Dye",
	["grug_farming:water_bucket"] = "filled at water with the Empty Iron Bucket, an action, not data",
	["xpanes:bar_flat"] = "Steel Bars have no recipe (the steel bar door and trapdoor need them)",
}
local tokens, seen = {}, {}
local function note(token)
	if not seen[token] then
		seen[token] = true
		tokens[#tokens + 1] = token
	end
end
for _, record in ipairs(grug_jobs.recipes) do
	for _, entry in ipairs(record.ingredients) do note(grug_jobs.ingredient_token(entry)) end
end
local enchant_inputs = 0
for _, ref in ipairs(grug_professions.enchant_data.referenced_items(grug_professions.ENCHANT_DATA)) do
	note(ref.item)
	enchant_inputs = enchant_inputs + 1
end
table.sort(tokens)
local gaps = {}
for _, token in ipairs(tokens) do
	if not real.has_source(token) then
		gaps[#gaps + 1] = token
		print("gap  " .. token .. " (" .. real.label(token) .. "): " ..
			(KNOWN_GAPS[token] or "NEW, no source"))
		check(KNOWN_GAPS[token] ~= nil, "R a recipe ingredient without a source is a listed gap: " .. token)
	end
	local group = token:match("^group:(.+)$")
	if group then check(#real.members(group) > 0, "R group " .. group .. " has a member") end
end
for token in pairs(KNOWN_GAPS) do
	check(not real.has_source(token), "R a listed gap still has no source (else drop it): " .. token)
end
check(enchant_inputs > 100, "R the enchant inputs are read (" .. enchant_inputs .. ")")

local iron = real.sources("grug_materials:iron_bar")
check(find(iron, {kind = "furnace", input = "default:iron_lump"}) ~= nil, "R an Iron Bar is smelted from Iron Lump")
check(find(real.sources("grug_materials:bronze_bar"), {kind = "alloy"}) ~= nil, "R Bronze Bar is an alloy")
check(find(real.sources("grug_materials:steel_bar"), {kind = "alloy"}).inputs[2] == "grug_materials:anthracite",
	"R Steel Bar: Iron Bar and Anthracite in the dual furnace")
local lump = find(real.sources("default:iron_lump"), {kind = "mining"})
check(lump and lump.pick_level == 1 and lump.tiers[1] == 1, "R Iron Lump: mined from T1 rock with the Bronze pick")

local linen = real.sources("grug_mobs:linen_scrap")
local outlaw = find(linen, {kind = "drop", key = "outlaw", band = 1})
check(outlaw and outlaw.levels[1] == 1 and outlaw.levels[2] == 10 and #outlaw.mobs > 0,
	"R Linen Scrap drops from outlaws of levels 1-10, with their names")
check(find(linen, {kind = "drop", key = "zombie", band = 1}) ~= nil, "R ...and from zombies of levels 1-10")
check(find(linen, {kind = "drop", key = "goblin", leader = true}) ~= nil, "R ...and from goblin leaders")
check(find(linen, {kind = "drop", mob = "grug_mobs:bog_ooze"}) ~= nil, "R ...and the Bog Ooze's static drops")
check(find(linen, {kind = "vendor", vendor = "tailor"}) ~= nil, "R ...and the Tailor sells it")

local moss = find(real.sources("grug_gathering:gravemoss"), {kind = "gather"})
check(moss and table.concat(moss.zones, ",") == "elandor_copperfell_foothills,kragmar_mournfen" and
	moss.alchemy_tier == 1, "R Gravemoss grows in Copperfell Foothills and Mournfen, Alchemy T1")
eq(real.zone("kragmar_mournfen").display_name, "Mournfen", "R a zone id resolves to its name")
local carrot_wild = find(real.sources("grug_cooking:carrot"), {kind = "gather"})
check(carrot_wild and #carrot_wild.zones == 3 and carrot_wild.levels[2] == 6, "R Carrots grow wild in three start zones")

local thread_real = real.sources("grug_professions:thread")
local shops = 0
for _, source in ipairs(thread_real) do
	if source.kind == "vendor" and source.vendor ~= "quartermaster" then shops = shops + 1 end
end
check(find(thread_real, {kind = "vendor", vendor = "quartermaster", price = 1}) ~= nil and shops >= 10,
	"R Thread: every Quartermaster and " .. shops .. " shops sell it for 1c")
check(find(thread_real, {kind = "vendor", vendor = "culture"}) == nil, "R ...not the Decor Merchant")
eq(find(thread_real, {kind = "vendor", vendor = "smith"}).label, "Blacksmith", "R a shop's label is its nametag")
check(find(thread_real, {kind = "recipe", area = "basic"}) ~= nil, "R ...and its Basic recipe")
local gear = find(real.sources("grug_gear:sword_bronze"), {kind = "vendor"})
check(gear ~= nil, "R the T1 gear shelf is a vendor source (Bronze Sword)")
check(#real.members("wood") > 3, "R group:wood resolves to its members")

local with, total = 0, 0
for _, list in pairs(real.by_item) do
	with = with + 1
	total = total + #list
end
local registered = 0
for _ in pairs(game.items) do registered = registered + 1 end
-- The digest of every source line: the engine probe
-- (grug_probe_r57_details, staged with tools/luanti_headless.sh PROBE=) logs
-- the same one for the real engine.
local digest_text = dofile(repo .. "/tools/r57_details/grug_probe_r57_details/digest.lua")(real)
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
print(("R57 DETAILS index: items=%d recipes=%d with=%d sources=%d tokens=%d gaps=%s digest=%s"):format(
	registered, #grug_jobs.recipes, with, total, #tokens, table.concat(gaps, ","),
	common.hex(common.new_sha256()(digest_text))))
print(("R57 DETAILS times: harness load %.2f s, index build %.3f s (comparisons)"):format(
	load_seconds, build_seconds))
if os.getenv("R57_DETAILS_DUMP") then
	local out = assert(io.open(os.getenv("R57_DETAILS_DUMP"), "w"))
	out:write(digest_text)
	out:close()
end

if failures > 0 then
	error("R57 DETAILS PORTABLE FAIL failures=" .. failures .. " checks=" .. checks, 0)
end
print("R57 DETAILS PORTABLE PASS checks=" .. checks)
