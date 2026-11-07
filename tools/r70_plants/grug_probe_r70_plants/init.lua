-- Disposable probe (Round 70 lane PLANTS, tools/r70_plants): the placements
-- of the fixture on the real engine, on a stone floor in the sky. The
-- protection is the probe's own table, so a spot is refused on demand. Every
-- failed check logs an error, so tools/luanti_headless.sh fails the run.
local checks, failed = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failed = failed + 1
		core.log("error", "[r70 plants probe] FAIL " .. label)
	end
end
local function P(x, y, z) return vector.new(x, y, z) end
local given = {}
local protected = {}
local function hash(pos) return core.hash_node_position(pos) end

-- A stand-in player: enough for builtin's place and dig.
local digger = {
	is_player = function() return true end,
	get_player_name = function() return "probe" end,
	get_player_control = function() return {sneak = false} end,
	get_wielded_item = function() return ItemStack("") end,
	set_wielded_item = function() return true end,
	get_pos = function() return P(0, 0, 0) end,
	get_look_dir = function() return P(0, -1, 0) end,
	get_look_horizontal = function() return 0 end,
	get_inventory = function() return nil end,
	get_meta = function() return nil end,
}

local function name_at(pos) return core.get_node(pos).name end
local function dig(pos)
	return core.node_dig(pos, core.get_node(pos), digger)
end
local function on_place(item, under, above)
	local stack = ItemStack(item .. " 5")
	local pointed = {type = "node", under = under, above = above or vector.offset(under, 0, 1, 0)}
	local result = core.registered_items[item].on_place(stack, digger, pointed)
	return result or stack
end
local function count_given(item)
	local n = 0
	for _, entry in ipairs(given) do
		if ItemStack(entry):get_name() == item then n = n + ItemStack(entry):get_count() end
	end
	return n
end

local function run(y)
	core.is_protected = function(pos) return protected[hash(pos)] == true end
	core.handle_node_drops = function(_, drops)
		for _, item in ipairs(drops) do given[#given + 1] = item end
	end
	local floor_y, stone = y, {name = "default:stone"}
	for x = 0, 12 do
		for z = -1, 1 do core.set_node(P(x, floor_y, z), stone) end
	end
	local function ground(x) return P(x, floor_y, 0) end
	local function above(x, n) return P(x, floor_y + (n or 1), 0) end

	-- ferns: the engine's item_place, every variant dropping the first
	local left = on_place("default:fern_1", ground(0))
	check(left:get_count() == 4 and left:get_name() == "default:fern_1", "a fern is spent")
	check(name_at(above(0)):find("^default:fern_") ~= nil, "a fern stands: " .. name_at(above(0)))
	given = {}
	check(dig(above(0)), "the fern digs")
	check(count_given("default:fern_1") == 1, "the fern drops the first fern")

	-- lichen
	left = on_place("grug_nodes:lichen_carpet", ground(1))
	check(left:get_count() == 4, "a lichen is spent")
	check(name_at(above(1)):find("^grug_nodes:lichen_carpet") ~= nil, "a lichen lies")
	given = {}
	dig(above(1))
	check(count_given("grug_nodes:lichen_carpet") == 1, "the lichen drops the first lichen")

	-- foliage: placed leaves carry param2 1
	local stack = ItemStack("grug_trees:swamp_leaves 5")
	local placed = select(2, core.item_place(stack, digger, {type = "node", under = ground(2), above = above(2)}))
	check(placed ~= nil, "swamp leaves place")
	check(core.get_node(above(2)).param2 == 1, "placed leaves never decay")
	given = {}
	dig(above(2))
	check(count_given("grug_trees:swamp_leaves") == 1, "swamp leaves drop themselves")

	-- the lily
	local LILY = "grug_mapgen:freshwater_waterlily"
	check(ItemStack(LILY):get_definition().liquids_pointable == true, "the lily points at liquids")
	core.set_node(ground(3), {name = "default:water_source"})
	left = on_place(LILY, ground(3))
	check(left:get_count() == 4 and name_at(above(3)) == LILY, "the lily floats on source water")
	check(core.get_node(above(3)).param2 <= 3, "turned as the generator does")
	check(name_at(ground(3)) == "default:water_source", "the water stays")
	given = {}
	dig(above(3))
	check(count_given(LILY) == 1, "the lily drops itself")
	core.set_node(ground(4), {name = "default:river_water_source"})
	protected[hash(above(4))] = true
	check(on_place(LILY, ground(4)):get_count() == 5, "protected water refuses the lily")
	protected = {}
	check(on_place(LILY, ground(4)):get_count() == 4, "river water takes the lily")

	-- the rooted plants, the engine holding the height
	local WEED = "grug_mapgen:freshwater_waterweed"
	local bed = ground(5)
	core.set_node(bed, {name = "default:sand"})
	for dy = 1, 4 do core.set_node(vector.offset(bed, 0, dy, 0), {name = "default:water_source"}) end
	left = on_place(WEED, bed)
	local weed = core.get_node(bed)
	check(left:get_count() == 4 and weed.name == WEED, "the weed replaces the bed")
	check(weed.param2 % 16 == 0 and weed.param2 >= 16 and weed.param2 <= 48, "weed height " .. weed.param2)
	given = {}
	dig(bed)
	check(name_at(bed) == "default:sand", "digging the weed leaves the sand bed: " .. name_at(bed))
	check(count_given(WEED) == 1, "the weed drops itself")
	check(count_given("default:sand") == 0, "and no sand")
	left = on_place("grug_mapgen:seagrass_1", bed)
	check(left:get_count() == 4 and name_at(bed):find("^grug_mapgen:seagrass_") ~= nil, "seagrass roots")
	given = {}
	dig(bed)
	check(name_at(bed) == "default:sand", "digging seagrass leaves the sand bed")
	check(count_given("grug_mapgen:seagrass_1") == 1, "seagrass drops the first")

	-- the liana
	local LIANA, STRAND = "grug_trees:liana", "grug_trees:liana_strand"
	local top = P(8, floor_y + 12, 0)
	core.set_node(top, {name = "default:jungleleaves"})
	local function hang(n) return vector.offset(top, 0, -n, 0) end
	left = on_place(LIANA, top, hang(1))
	check(left:get_count() == 4 and name_at(hang(1)) == LIANA, "a liana hangs under leaves")
	check(core.get_node(hang(1)).param2 == 1, "a placed piece never decays")
	on_place(LIANA, hang(1), vector.offset(hang(1), 1, 0, 0))
	on_place(LIANA, hang(1), vector.offset(hang(1), 1, 0, 0))
	check(name_at(hang(1)) == STRAND and name_at(hang(2)) == STRAND and name_at(hang(3)) == LIANA,
		"strands above one end")
	given = {}
	dig(hang(2))
	check(name_at(hang(1)) == LIANA and name_at(hang(2)) == "air" and name_at(hang(3)) == "air",
		"the end moves up and the piece below falls")
	check(count_given(LIANA) == 2, "both pieces give a liana: " .. count_given(LIANA))

	-- leaf decay drops nothing, the engine's timers aside
	local added = 0
	local add_item = core.add_item
	core.add_item = function(...) added = added + 1 end
	for x, name in ipairs({"grug_trees:swamp_leaves", "grug_trees:gravewood_leaves",
			"grug_nodes:jungle_bush_leaves", "grug_nodes:withered_bush_leaves",
			"grug_trees:swamp_hanging_moss", "grug_trees:liana_strand"}) do
		local pos = P(x, floor_y + 20, 0)
		core.set_node(pos, {name = name})
		core.registered_nodes[name].on_timer(pos)
		check(name_at(pos) == "air", name .. " decays")
	end
	core.add_item = add_item
	check(added == 0, "decay added " .. added .. " items")

	-- a flower goes with its ground
	local flower = core.registered_items["grug_nodes:flower_ruby_fan"]
	stack = ItemStack("grug_nodes:flower_ruby_fan 5")
	flower.on_place(stack, digger, {type = "node", under = ground(9), above = above(9)})
	check(name_at(above(9)) == "grug_nodes:flower_ruby_fan", "a flower stands")

	core.log("action", "[r70 plants probe] done checks=" .. checks .. " failed=" .. failed)
	local handle = io.open(core.get_worldpath() .. "/r70_plants_probe.txt", "w")
	handle:write("checks=" .. checks .. " failed=" .. failed .. "\n")
	handle:close()
end

core.register_on_mods_loaded(function()
	core.after(3, function()
		local pos = P(40, 300, 40)
		core.emerge_area(vector.offset(pos, -16, -16, -16), vector.offset(pos, 32, 48, 16),
			function(_, _, remaining)
				if remaining == 0 then
					local ok, err = pcall(run, pos.y)
					if not ok then core.log("error", "[r70 plants probe] " .. tostring(err)) end
				end
			end)
	end)
end)
