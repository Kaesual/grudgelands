-- Round 57 lane CHAINDEPTH portable test (LuaJIT): the chain walk
-- (tools/r57_chains/chains.lua, README.md) and its input from the game data.
--
--   luajit tools/r57_chains/portable_test.lua [REPO]
--
-- Checks:
--   S  a synthetic recipe set: a three-deep chain (lump, furnace bar, Basic
--      rod, sword) with its steps and Basic list; a bar/block loop entered
--      by the furnace (rule unpack); a lump/block loop nothing feeds (rule
--      unpack makes the lump raw); a plank/stair/slab loop (rule cut_back);
--      a recolour loop through a group (rule seed: the member used most
--      outside; a loop another stuck loop feeds waits); a one-for-one pair (no cut_back, rule seed); a group ingredient resolving to its cheapest member; two
--      recipes for one item (the shallowest is the source, then the fewest
--      steps); the loops listed with their rules; the longest chain; what an
--      operation consumes; the same result in any step order;
--   R  the real data: the REAL grug_jobs registry and Basic catalog and the
--      REAL grug_smelting alloys and furnace recipes under a stub engine,
--      through steps.lua (the dump's shape): the Bronze Pickaxe reaches its
--      lumps through the Bronze Bar (dual furnace) and a furnace bar; the
--      Copper Block loop is broken by rule unpack and the Cobblestone stair
--      loop by rule cut_back; every step gets a finite depth.
-- Prints "R57 CHAINS PORTABLE PASS checks=<n>" or the failures.

local ROOT = arg and arg[1] or "."
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
local function list_eq(actual, expected, label)
	return eq(table.concat(actual or {}, ","), table.concat(expected, ","), label)
end

local chains = dofile(ROOT .. "/tools/r57_chains/chains.lua")
local steps_from_dump = dofile(ROOT .. "/tools/r57_chains/steps.lua")

------------------------------------------------------------------------------
-- S: the synthetic set.
------------------------------------------------------------------------------
local function I(item, n) return {item = item, n = n or 1} end
local function G(group, n) return {group = group, n = n or 1} end
local SYNTHETIC = {
	-- The three-deep chain.
	{id = "furnace:bar", output = "t:bar", ingredients = {I("t:lump")}},
	{id = "rod", output = "t:rod", count = 2, ingredients = {I("t:bar", 2)}, basic = true},
	{id = "sword", output = "t:sword", ingredients = {I("t:bar", 2), I("t:rod")}},
	-- The bar block: packed from bars, unpacked back (entered by the furnace).
	{id = "block", output = "t:block", ingredients = {I("t:bar", 9)}, basic = true},
	{id = "unblock", output = "t:bar", count = 9, ingredients = {I("t:block")}, basic = true},
	-- A lump block nothing feeds (coal).
	{id = "coalblock", output = "t:coalblock", ingredients = {I("t:coal", 9)}, basic = true},
	{id = "uncoal", output = "t:coal", count = 9, ingredients = {I("t:coalblock")}, basic = true},
	-- Planks from two logs (the group's members), their stair and slab.
	{id = "plank_a", output = "t:plank_a", count = 4, ingredients = {I("t:log_a")}, basic = true},
	{id = "plank_b", output = "t:plank_b", count = 4, ingredients = {I("t:sap")}, basic = true},
	{id = "sap", output = "t:sap", ingredients = {I("t:log_b")}, basic = true},
	{id = "stair", output = "t:stair", count = 8, ingredients = {I("t:plank_a", 6)}, basic = true},
	{id = "slab", output = "t:slab", count = 6, ingredients = {I("t:plank_a", 3)}, basic = true},
	{id = "unstair", output = "t:plank_a", count = 3, ingredients = {I("t:stair", 4)}, basic = true},
	{id = "unslab", output = "t:plank_a", ingredients = {I("t:slab", 2)}, basic = true},
	{id = "handle", output = "t:handle", ingredients = {G("wood", 2)}, basic = true},
	-- Recoloured wool: every colour from a dye and any wool.
	{id = "wool_white", output = "t:wool_white", ingredients = {I("t:dye_white"), G("wool")}, basic = true},
	{id = "wool_red", output = "t:wool_red", ingredients = {I("t:dye_red"), G("wool")}, basic = true},
	{id = "bed", output = "t:bed", ingredients = {I("t:wool_white", 3), G("wood", 3)}, basic = true},
	-- Two items made from each other one for one, nothing else: no rule
	-- before seed applies; the one used outside is the seed.
	{id = "moss_from_rock", output = "t:moss", ingredients = {I("t:rock")}, basic = true},
	{id = "rock_from_moss", output = "t:rock", ingredients = {I("t:moss")}, basic = true},
	{id = "wall", output = "t:wall", ingredients = {I("t:rock", 6)}, basic = true},
	-- Two recipes for the guard: from the sword (deeper) or from a bar.
	{id = "guard_deep", output = "t:guard", ingredients = {I("t:sword")}},
	{id = "guard_flat", output = "t:guard", ingredients = {I("t:bar"), I("t:gem")}},
	-- Two recipes of equal depth for the hilt: the fewer steps win.
	{id = "hilt_rod", output = "t:hilt", ingredients = {I("t:rod"), I("t:block")}},
	{id = "hilt_handle", output = "t:hilt", ingredients = {I("t:handle"), I("t:gem")}},
}
local MEMBERS = {wood = {"t:plank_b", "t:plank_a"}, wool = {"t:wool_red", "t:wool_white"}}

local function analyse(order)
	local list = {}
	for index, position in ipairs(order) do list[index] = SYNTHETIC[position] end
	return chains.analyse(list, MEMBERS)
end
local forward = {}
for index = 1, #SYNTHETIC do forward[index] = index end
local R = analyse(forward)
local S, IT = R.steps, R.items

-- The three-deep chain.
eq(S["furnace:bar"].depth, 1, "S the furnace bar is depth 1")
eq(S.rod.depth, 2, "S the rod is depth 2")
eq(S.sword.depth, 3, "S the sword is depth 3")
eq(S.sword.steps, 3, "S the sword's tree: sword, rod, furnace bar")
list_eq(S.sword.basics, {"rod"}, "S the sword's Basic list")
list_eq(S.rod.basics, {}, "S a Basic recipe leaves itself out")
eq(IT["t:bar"].via, "furnace:bar", "S the bar's source is the furnace")
check(IT["t:lump"] == nil or IT["t:lump"].raw, "S the lump is raw")
local path = chains.path(R, "sword")
local names = {}
for index, link in ipairs(path) do names[index] = link.item end
list_eq(names, {"t:sword", "t:rod", "t:bar", "t:lump"}, "S the longest chain")

-- The bar block loop: entered by the furnace, the unpack is no source.
eq(S.unblock.broken, "unpack", "S bars from the block: rule unpack")
eq(S.block.depth, 2, "S the block is depth 2")
eq(S.unblock.depth, 3, "S bars from the block still get their own depth")
check(not S.unblock.source and S["furnace:bar"].source, "S only the furnace is the bar's source")
-- The coal loop: nothing feeds it; the unpack makes the lump raw.
eq(S.uncoal.broken, "unpack", "S coal from its block: rule unpack")
eq(IT["t:coal"].depth, 0, "S coal is raw")
check(IT["t:coal"].raw and not IT["t:coal"].seeded, "S coal is raw by rule unpack, no seed")
eq(S.coalblock.depth, 1, "S the coal block is depth 1")
-- The stair loop.
eq(S.unstair.broken, "cut_back", "S planks from stairs: rule cut_back")
eq(S.unslab.broken, "cut_back", "S planks from slabs: rule cut_back")
check(S.stair.broken == nil and S.slab.broken == nil, "S stairs and slabs from planks stay")
eq(S.stair.depth, 2, "S the stair is depth 2")
eq(IT["t:plank_a"].via, "plank_a", "S the planks' source is the log")
-- The group: the cheapest member.
eq(R.groups.wood, "t:plank_a", "S group:wood resolves to the shallowest member")
eq(S.handle.depth, 2, "S the handle is depth 2")
eq(S.handle.chosen[1], "t:plank_a", "S the handle names the member it uses")
-- The wool loop: seeded with the member used most outside it (the bed).
list_eq(R.seeded, {"t:rock", "t:wool_white"}, "S the white wool and the rock are the seeds")
eq(IT["t:wool_white"].depth, 0, "S the seed is raw")
eq(S.wool_red.depth, 1, "S red wool: a dye and the seed")
eq(R.groups.wool, "t:wool_white", "S group:wool resolves to the seed")
-- The one-for-one pair: neither cuts the other; the rock is the seed.
check(S.moss_from_rock.broken == nil and S.rock_from_moss.broken == nil,
	"S a one-for-one pair is no cut_back")
eq(IT["t:rock"].depth, 0, "S the rock is the pair's seed")
eq(IT["t:moss"].depth, 1, "S the moss is made from the rock")
-- Two recipes: the shallowest is the source, then the fewer steps.
eq(IT["t:guard"].depth, 2, "S the guard takes its shallowest recipe")
eq(IT["t:guard"].via, "guard_flat", "S the bar recipe is the guard's source")
eq(S.guard_deep.depth, 4, "S the deeper recipe keeps its own depth")
eq(S.guard_deep.alternatives, 2, "S two recipes make the guard")
eq(S.hilt_rod.depth, 3, "S the hilt's rod recipe is depth 3")
eq(S.hilt_handle.depth, 3, "S the hilt's handle recipe is depth 3")
eq(S.hilt_rod.steps, 4, "S the rod recipe's tree: hilt, rod, bar, block")
eq(S.hilt_handle.steps, 3, "S the handle recipe's tree: hilt, handle, planks")
eq(IT["t:hilt"].via, "hilt_handle", "S equal depth: the fewer steps are the source")
list_eq(S.hilt_handle.basics, {"handle", "plank_a"}, "S the Basic list follows the group member")

-- The loops section.
local loop_rules = {}
for _, loop in ipairs(R.loops) do
	for _, entry in ipairs(loop.steps) do loop_rules[entry.id] = entry.rule or "source" end
end
eq(#R.loops, 5, "S five loops: bar, coal, planks, wool, rock")
eq(loop_rules.unblock, "unpack", "S the loop list names rule unpack")
eq(loop_rules.unstair, "cut_back", "S the loop list names rule cut_back")
eq(loop_rules.wool_white, "seed", "S the loop list names rule seed")
eq(loop_rules.block, "source", "S the block is its own source")
eq(loop_rules.wool_red, "source", "S red wool is its own source")
eq(loop_rules.rock_from_moss, "seed", "S the rock's recipe: rule seed")

-- An operation's cost.
local cost = chains.consume(R, {I("t:handle"), G("wood"), I("t:gem")})
eq(cost.depth, 2, "S an operation consumes depth 2")
eq(cost.steps, 2, "S its trees: handle, planks")
list_eq(cost.basics, {"handle", "plank_a"}, "S its Basic list")

-- The order of the steps does not matter.
local backward = {}
for index = #SYNTHETIC, 1, -1 do backward[#backward + 1] = index end
local B = analyse(backward)
local same = true
for id, info in pairs(S) do
	local other = B.steps[id]
	if other.depth ~= info.depth or other.steps ~= info.steps or other.source ~= info.source or
			other.broken ~= info.broken or table.concat(other.basics, ",") ~= table.concat(info.basics, ",") then
		same = false
		print("  differs: " .. id)
	end
end
check(same, "S the reversed step order gives the same steps")
list_eq(B.seeded, R.seeded, "S the reversed step order seeds the same item")
eq(table.concat(B.order, ","), table.concat(R.order, ","), "S the reversed step order sorts the same")

-- Rule seed only seeds a loop no other stuck item feeds: A <-> B has no
-- feed; C <-> D is fed by A (D from A and a gem), so D is made, not seeded.
local FED = chains.analyse({
	{id = "a_from_b", output = "x:a", ingredients = {I("x:b")}},
	{id = "b_from_a", output = "x:b", ingredients = {I("x:a")}},
	{id = "c_from_d", output = "x:c", ingredients = {I("x:d"), I("x:gem")}},
	{id = "d_from_c", output = "x:d", ingredients = {I("x:c"), I("x:gem")}},
	{id = "d_from_a", output = "x:d", ingredients = {I("x:a"), I("x:gem")}},
	{id = "use_d", output = "x:e", ingredients = {I("x:d")}},
	{id = "use_a", output = "x:f", ingredients = {I("x:a")}},
}, {})
list_eq(FED.seeded, {"x:a"}, "S a fed loop is not seeded")
eq(FED.items["x:d"].via, "d_from_a", "S the fed loop's item is made from the seed")
eq(FED.items["x:d"].depth, 1, "S D is depth 1")
eq(FED.items["x:c"].depth, 2, "S C is depth 2")

------------------------------------------------------------------------------
-- R: the real registry, Basic catalog and smelting recipes.
------------------------------------------------------------------------------
local registered, crafts = {}, {}
_G.core = {
	registered_items = registered,
	get_item_group = function(name, group)
		local def = registered[name]
		return def and def.groups and def.groups[group] or 0
	end,
	get_modpath = function() return ROOT .. "/mods/ITEMS/grug_smelting" end,
	get_current_modname = function() return "grug_smelting" end,
	register_on_mods_loaded = function() end,
	register_craftitem = function(name, def) registered[name] = def end,
	register_craft = function(def) crafts[#crafts + 1] = def end,
	log = function() end,
}
_G.grug_jobs = {}
dofile(ROOT .. "/mods/PLAYER/grug_jobs/registry.lua")
grug_jobs.register_basic_catalog(dofile(ROOT .. "/mods/PLAYER/grug_jobs/basic_recipes.lua"))
_G.grug_materials = {PROCESSED_MATERIALS = {}, RESOURCES = {}}
_G.grug_smelting = {}
dofile(ROOT .. "/mods/ITEMS/grug_smelting/alloys.lua")
dofile(ROOT .. "/mods/ITEMS/grug_smelting/recipes.lua")

-- The dump's shape (grug_probe_r57_chains): the engine's furnace routes as
-- the probe reads them back.
local furnace = {}
for _, def in ipairs(crafts) do
	if def.type == "cooking" then
		local name, count = def.output:match("^(%S+)%s*(%d*)$")
		furnace[#furnace + 1] = {output = name, count = tonumber(count) or 1, input = def.recipe}
	end
end
local input = steps_from_dump({registry = grug_jobs.recipes, furnace = furnace,
	alloys = grug_smelting.RECIPES, groups = {}, aliases = {}})
local real = chains.analyse(input.steps, input.members)

check(#furnace >= 6, "R the furnace bars and charcoal are engine cooking routes")
local pick
for _, step in ipairs(input.steps) do
	if step.output == "grug_materials:pick_bronze" then pick = step end
end
if check(pick ~= nil, "R the Bronze Pickaxe is a Basic recipe") then
	local chain = chains.path(real, pick.id)
	local kinds = {}
	for index, link in ipairs(chain) do
		kinds[index] = link.item .. (link.step and ("@" .. input.meta[link.step].area_label) or "")
	end
	local text = table.concat(kinds, " < ")
	check(text:match("^grug_materials:pick_bronze@Basic < grug_materials:bronze_bar@Dual Furnace < " ..
		"grug_materials:%a+_bar@Furnace < default:%a+_lump$") ~= nil,
		"R the Bronze Pickaxe reaches a lump through the Bronze Bar and a furnace bar (" .. text .. ")")
	eq(real.steps[pick.id].depth, 3, "R the Bronze Pickaxe is depth 3")
	eq(real.items["grug_materials:bronze_bar"].via, "alloy:grug_materials:bronze_bar",
		"R the Bronze Bar's source is the dual furnace, not its block")
end
local unpack_copper, cut_cobble
for _, step in ipairs(input.steps) do
	local only = step.ingredients[1]
	if step.output == "grug_materials:copper_bar" and only.item == "grug_materials:copper_block" then
		unpack_copper = real.steps[step.id].broken
	end
	if step.output == "default:cobble" and only.item == "stairs:stair_cobble" then
		cut_cobble = real.steps[step.id].broken
	end
end
eq(unpack_copper, "unpack", "R Copper Bars from the block: rule unpack")
-- Round 67 ruling 11: no route from stairs back to a block in the real
-- catalog any more (the synthetic stair loop above keeps the rule's test).
eq(cut_cobble, nil, "R no Cobblestone from its stair (Round 67)")
local finite = true
for id, info in pairs(real.steps) do
	if info.depth == math.huge then finite = false print("  infinite: " .. id) end
end
check(finite, "R every real step has a finite depth")

if failures > 0 then
	error(("R57 CHAINS PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R57 CHAINS PORTABLE PASS checks=%d"):format(checks))
