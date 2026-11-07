-- Round 70 lane GUILD portable fixture (LuaJIT): the Stonewright on the whole
-- game's registrations (the Round 57 game harness), with fake players.
--
--   luajit tools/r70_guild/portable_test.lua REPO
--
-- A. The catalogue: the recipes and ranks of plan §2.6, ranks 9 and 10 empty,
--    no recipe gives more than it takes, one key per number.
-- B. The blocks and machines: five full cubes like cut stone with a tier, no
--    crafting recipe, 20 undiggable machine cells with the art's boxes and
--    tiles, four animated hearth faces at light 8, one furnace loop emitter;
--    every picked PNG ships, Thread wears its icon.
-- C. Prices: an ornamented stone is priced by its recipe, the load audit
--    (output <= inputs) passes, the conversions do not print money; no
--    fee-free route.
-- D. stonewright_rows and stonewright_make: lots, the rest, the fee, rank,
--    money, room (a full bag converts its own stacks; a refusal changes
--    nothing), no faction, malformed amounts.
-- E. The window: one page without modes, rows locked by rank, lots 1 / 5 /
--    10 / All, forged and stale clicks, other vendors have no such fields.
-- F. The socket: the sorter's in all six capitals, a service role, the
--    machines in the six templates in reach of it, one facedir per machine.
-- G. The removed rule: a vendor may sell an exchanged item; no doc keeps it.
--
-- Prints "R70 GUILD PORTABLE PASS checks=<n>" or raises.

local repo = assert(arg and arg[1], "usage: luajit portable_test.lua REPO")
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
	return check(actual == expected, label .. ": expected " .. tostring(expected) ..
		", got " .. tostring(actual))
end
local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

local game = dofile(repo .. "/tools/r57_details/game_harness.lua")(repo)
for _, line in ipairs(game.failures) do
	check(not (line:find("grug_guild", 1, true) or line:find("grug_traders", 1, true)),
		"the mods load in the harness: " .. line)
end
local C = grug_guild.catalog

------------------------------------------------------------------------------
-- A. The catalogue.
------------------------------------------------------------------------------
local COBBLE, GRAVEL, SAND, STONE = "default:cobble", "default:gravel", "default:sand", "default:stone"
local IRON_BAR = "grug_materials:iron_bar"
local RULED = {
	{"cobble_gravel", 1, COBBLE, GRAVEL},
	{"gravel_sand", 2, GRAVEL, SAND},
	{"cobble_sand", 2, COBBLE, SAND},
	{"cobble_stone", 3, COBBLE, STONE},
	{"ornamented_iron", 4, COBBLE, "grug_guild:ornamented_iron", "grug_materials:iron_bar", 2},
	{"ornamented_steel", 5, COBBLE, "grug_guild:ornamented_steel", "grug_materials:steel_bar", 3},
	{"ornamented_silversteel", 6, COBBLE, "grug_guild:ornamented_silversteel",
		"grug_materials:silversteel_bar", 4},
	{"ornamented_embersteel", 7, COBBLE, "grug_guild:ornamented_embersteel",
		"grug_materials:embersteel_bar", 5},
	{"ornamented_abyssal_steel", 8, COBBLE, "grug_guild:ornamented_abyssal_steel",
		"grug_materials:abyssal_steel_bar", 6},
}
eq(#C.STONEWRIGHT, #RULED, "A nine recipes")
eq(#C.ORNAMENTED, 5, "A five ornamented stones")
for index, want in ipairs(RULED) do
	local row = C.STONEWRIGHT[index]
	eq(row.id, want[1], "A recipe " .. index .. "'s id")
	eq(row.rank, want[2], "A " .. want[1] .. "'s rank")
	eq(row.inputs[1].item, want[3], "A " .. want[1] .. "'s stone")
	eq(row.output, want[4], "A " .. want[1] .. "'s output")
	eq(row.inputs[2] and row.inputs[2].item, want[5], "A " .. want[1] .. "'s bar")
	eq(row.tier, want[6], "A " .. want[1] .. "'s tier")
	eq(C.stonewright_recipe(row.id), row, "A the accessor for " .. row.id)
	check(row.fee >= 1, "A " .. row.id .. " takes a fee")
	local taken = 0
	for _, input in ipairs(row.inputs) do taken = taken + input.count end
	check(row.output_count <= taken, "A " .. row.id .. " gives at most what it takes")
	check(game.items[row.output] ~= nil, "A " .. row.output .. " is registered")
	for _, input in ipairs(row.inputs) do
		check(game.items[input.item] ~= nil, "A " .. input.item .. " is registered")
	end
end
for _, row in ipairs(C.STONEWRIGHT) do
	check(row.rank <= 8, "A ranks 9 and 10 unlock no recipe: " .. row.id)
end
for key in pairs(C.VALUES) do
	if key:find("^stonewright%.") then
		local id = key:match("^stonewright%.([%w_]+)%.")
		check(C.stonewright_recipe(id) ~= nil, "A " .. key .. " names a recipe")
	end
end
do
	local saved = C.VALUES["stonewright.cobble_gravel.output"]
	local row = C.stonewright_recipe("cobble_gravel")
	local old = row.output_count
	row.output_count = 11
	check(not pcall(C.validate), "A validate refuses a recipe that gives more than it takes")
	row.output_count = old
	eq(C.VALUES["stonewright.cobble_gravel.output"], saved, "A the value stayed")
end

------------------------------------------------------------------------------
-- B. The blocks and machines.
------------------------------------------------------------------------------
for _, row in ipairs(C.ORNAMENTED) do
	local def = game.items[row.output]
	check(def.type == "node" and (def.drawtype == nil or def.drawtype == "normal"),
		"B " .. row.id .. " is a full cube")
	eq(def.description, row.name, "B " .. row.id .. "'s name")
	eq(#def.tiles, 1, "B " .. row.id .. " wears one image on all six faces")
	eq(def.tiles[1], "grug_guild_" .. row.id .. ".png", "B " .. row.id .. "'s face")
	eq(def.is_ground_content, false, "B " .. row.id .. " is not ground content")
	local stone = game.items["default:stone_block"]
	eq(def.groups.cracky, stone.groups.cracky, "B " .. row.id .. " digs like cut stone")
	eq(def.groups.stone, stone.groups.stone, "B " .. row.id .. "'s stone group")
	eq(def.light_source, nil, "B " .. row.id .. " does not glow")
	eq(def._grug_tier, row.tier, "B " .. row.id .. "'s tier")
	eq(def.groups.not_in_creative_inventory, nil, "B " .. row.id .. " is an ordinary block")
	for _, recipe in ipairs(grug_jobs.recipes) do
		check(recipe.output ~= row.output, "B no crafting recipe makes " .. row.id)
	end
	eq(core.get_all_craft_recipes(row.output), nil, "B no engine recipe makes " .. row.id)
end

local function json_cells(machine)
	local json = dofile(repo .. "/tools/r28_b1/json.lua")
	local text = read("tools/r70_art/candidates/final/" .. machine .. ".json")
	return (json.decode or json.parse)(text).cells
end
local cells = {grinder = json_cells("grinder"), furnace = json_cells("furnace")}
eq(#cells.grinder, 8, "B the grinder has 8 cells")
eq(#cells.furnace, 12, "B the furnace has 12 cells")
local hearth, animated = 0, 0
for machine, list in pairs(cells) do
	for _, cell in ipairs(list) do
		local def = game.items[cell.name]
		check(def ~= nil, "B " .. cell.name .. " is registered")
		if def then
			eq(def.drawtype, "nodebox", "B " .. cell.name .. " is a node box")
			eq(def.paramtype2, "facedir", "B " .. cell.name .. " turns")
			eq(def.diggable, false, "B " .. cell.name .. " cannot be dug")
			eq(def.drop, "", "B " .. cell.name .. " drops nothing")
			eq(def.is_ground_content, false, "B " .. cell.name .. " is no ground content")
			eq(#def.node_box.fixed, #cell.node_box, "B " .. cell.name .. "'s boxes")
			eq(def.light_source, cell.light_source, "B " .. cell.name .. "'s light")
			eq(#def.tiles, 6, "B " .. cell.name .. "'s six tiles")
			if def.light_source == 8 then hearth = hearth + 1 end
			for _, tile in ipairs(def.tiles) do
				eq(tile.align_style, "node", "B " .. cell.name .. " aligns to the node")
				if tile.animation then
					animated = animated + 1
					eq(tile.animation.length, 1.5, "B the fire loop is 1.5 s")
					eq(tile.animation.aspect_h, 16, "B the fire frames are 16 high")
				end
			end
		end
	end
	check(machine ~= "", "B " .. machine)
end
local function shipped(path)
	local handle = io.open(repo .. "/" .. path, "rb")
	if handle then handle:close() end
	return handle ~= nil
end
for _, list in pairs(cells) do
	for _, cell in ipairs(list) do
		for _, tile in ipairs(cell.tiles) do
			check(shipped("mods/PLAYER/grug_guild/textures/" .. tile.name), "B " .. tile.name .. " ships")
		end
	end
end
for _, row in ipairs(C.ORNAMENTED) do
	check(shipped("mods/PLAYER/grug_guild/textures/grug_guild_" .. row.id .. ".png"),
		"B " .. row.id .. "'s face ships")
end
eq(game.items["grug_professions:thread"].inventory_image, "grug_professions_thread.png",
	"B Thread has its own icon")
check(shipped("mods/ITEMS/grug_professions/textures/grug_professions_thread.png"), "B the icon ships")
eq(hearth, 4, "B four hearth cells at light 8")
eq(animated, 4, "B four animated faces")
local ambience = dofile(repo .. "/mods/CORE/grug_ambience/data.lua")
local emitters = 0
for node, kind in pairs(ambience.emitter_nodes) do
	if node:find("^grug_guild:") then
		emitters = emitters + 1
		eq(kind, "furnace", "B the furnace's emitter is the furnace loop")
		check(game.items[node] ~= nil, "B the emitter cell is registered")
	end
end
eq(emitters, 1, "B one emitter cell, so one loop per furnace")

------------------------------------------------------------------------------
-- C. Prices.
------------------------------------------------------------------------------
grug_traders.resolve_prices()
local function mc(item) return grug_traders.sell_value(item) end
for _, row in ipairs(C.ORNAMENTED) do
	local bar = row.inputs[2]
	local stone = row.inputs[1]
	local material = math.floor((grug_traders.material_value(bar.item) * bar.count +
		grug_traders.material_value(stone.item) * stone.count) / row.output_count)
	eq(grug_traders.material_value(row.output), material, "C " .. row.id .. " is priced by its recipe")
	eq(mc(row.output), math.floor(material / 2), "C " .. row.id .. " sells at half its material value")
	check(mc(row.output) > 0, "C " .. row.id .. " sells")
	eq(grug_traders.item_tier(row.output), row.tier, "C " .. row.id .. "'s tier")
	-- A lot of the stones never sells for its inputs and fee.
	local inputs = 0
	for _, input in ipairs(row.inputs) do inputs = inputs + mc(input.item) * input.count end
	check(mc(row.output) * row.output_count <= inputs + row.fee * 1000,
		"C " .. row.id .. " prints no money")
end
for _, id in ipairs({"cobble_gravel", "gravel_sand", "cobble_sand", "cobble_stone"}) do
	local row = C.stonewright_recipe(id)
	eq(mc(row.output), 20, "C " .. id .. ": the output stays a 20 mc bulk good")
	eq(mc(row.inputs[1].item), 20, "C " .. id .. ": the input stays a 20 mc bulk good")
end
local recipes, outputs = 0, {}
for _, row in ipairs(C.STONEWRIGHT) do
	if not outputs[row.output] then
		outputs[row.output] = true
		for _, recipe in ipairs(grug_traders.recipes_for(row.output)) do
			if recipe.method == "stonewright" then
				recipes = recipes + 1
				eq(recipe.count, row.output_count, "C the audit counts " .. row.id .. "'s output")
			end
		end
	end
end
eq(recipes, #C.STONEWRIGHT, "C the audit sees every Stonewright recipe")

------------------------------------------------------------------------------
-- Fake players: as tools/r58_rep. The harness's stacks get the engine's
-- add_item (inventory.cpp ItemStack::addItem: an empty slot takes a whole
-- stack, however large; a used one up to the stack size).
------------------------------------------------------------------------------
local Stack = getmetatable(ItemStack("default:dirt"))
function Stack:add_item(other)
	other = ItemStack(other)
	if other:is_empty() then return other end
	if self:is_empty() then
		self.name, self.count, self.meta = other.name, other.count, other.meta
		return ItemStack("")
	end
	if self.name ~= other.name then return other end
	local into = math.min(99 - self.count, other.count)
	self.count = self.count + into
	other.count = other.count - into
	if other.count == 0 then other.name = "" end
	return other
end
function Stack:get_description()
	local def = core.registered_items[self.name]
	return def and def.description or self.name
end
local function new_meta()
	local data = {}
	return {
		get_int = function(_, key) return math.floor(tonumber(data[key]) or 0) end,
		set_int = function(_, key, value) data[key] = tostring(value) end,
		get_string = function(_, key) return data[key] or "" end,
		set_string = function(_, key, value) data[key] = value end,
		contains = function(_, key) return data[key] ~= nil end,
		data = data,
	}
end
local BAG = grug_inventory.content_list(1)
local STORE = grug_inventory.HOTBAR_STORE
local function new_inv(main_size)
	local lists = {}
	local sizes = {main = main_size or 32, [BAG] = 8, [STORE] = 8}
	for list, size in pairs(sizes) do
		lists[list] = {}
		for i = 1, size do lists[list][i] = ItemStack("") end
	end
	local inv = {lists = lists}
	function inv:get_size(list) return lists[list] and #lists[list] or 0 end
	function inv:get_list(list)
		if not lists[list] then return nil end
		local out = {}
		for i, stack in ipairs(lists[list]) do out[i] = ItemStack(stack) end
		return out
	end
	function inv:get_stack(list, i) return ItemStack(lists[list][i]) end
	function inv:set_stack(list, i, stack) lists[list][i] = ItemStack(stack) end
	return inv
end
local function count_of(inv, name)
	local n = 0
	for _, stacks in pairs(inv.lists) do
		for _, stack in ipairs(stacks) do
			if stack:get_name() == name then n = n + stack:get_count() end
		end
	end
	return n
end
local function no_oversized(inv, label)
	for list, stacks in pairs(inv.lists) do
		for index, stack in ipairs(stacks) do
			check(stack:get_count() <= 99, label .. ": " .. list .. " " .. index .. " holds at most a stack")
		end
	end
end
local function snapshot(inv)
	local parts = {}
	for _, list in ipairs({"main", BAG, STORE}) do
		for i, stack in ipairs(inv.lists[list]) do
			parts[#parts + 1] = list .. i .. "=" .. stack:get_name() .. " " .. stack:get_count()
		end
	end
	return table.concat(parts, ";")
end
local online = {}
local function new_player(name, faction, rank, copper, main_size)
	local meta, inv = new_meta(), new_inv(main_size)
	if faction then meta:set_string("grug_factions:faction", faction) end
	local player = {
		get_player_name = function() return name end,
		is_player = function() return true end,
		get_meta = function() return meta end,
		get_inventory = function() return inv end,
		get_pos = function() return {x = 0, y = 0, z = 0} end,
		meta = meta, inv = inv,
	}
	online[name] = player
	if rank and rank > 0 then grug_guild.add(player, C.RANKS[rank], "test") end
	if copper and copper > 0 then grug_money.add(player, copper) end
	return player
end
core.get_player_by_name = function(name) return online[name] end
local function fill(player, slots)
	for _, slot in ipairs(slots) do player.inv:set_stack(slot[1], slot[2], ItemStack(slot[3])) end
end

------------------------------------------------------------------------------
-- D. Rows and the conversion.
------------------------------------------------------------------------------
local ann = new_player("ann", "accord", 1, 100)
fill(ann, {{"main", 9, "default:cobble 30"}, {BAG, 2, "default:cobble 13"}, {STORE, 1, "default:cobble 2"}})
local rows = grug_guild.stonewright_rows(ann)
eq(#rows, #C.STONEWRIGHT, "D one row per recipe")
eq(rows[1].unlocked, true, "D rank 1 unlocks Cobblestone to Gravel")
eq(rows[2].unlocked, false, "D rank 1 does not unlock Gravel to Sand")
eq(rows[1].lots, 4, "D 45 Cobblestone over three lists: four lots of ten")
eq(rows[1].short, nil, "D nothing stops the first lot")
local before = snapshot(ann.inv)
local made, err = grug_guild.stonewright_make(ann, "gravel_sand")
check(made == nil and err == "rank", "D a locked recipe is refused (rank)")
made, err = grug_guild.stonewright_make(ann, "cobble_sand", 1)
check(made == nil and err == "rank", "D a locked recipe with goods is refused (rank)")
made, err = grug_guild.stonewright_make(ann, "nothing")
check(made == nil and err == "unknown", "D an unknown recipe is refused")
for _, bad in ipairs({0, -1, 1.5, 5, "1"}) do
	made, err = grug_guild.stonewright_make(ann, "cobble_gravel", bad)
	check(made == nil and err == "too_few", "D a bad amount is refused: " .. tostring(bad))
end
eq(snapshot(ann.inv), before, "D a refusal changes nothing")
eq(grug_money.get(ann), 100, "D a refusal takes no copper")
local lifetime, balance = grug_guild.lifetime(ann), grug_guild.balance(ann)
local fee
made, fee = grug_guild.stonewright_make(ann, "cobble_gravel", 2)
eq(made, 20, "D two lots make 20 Gravel")
eq(fee, 2, "D two lots cost two fees")
eq(count_of(ann.inv, COBBLE), 25, "D 20 Cobblestone are gone")
eq(count_of(ann.inv, GRAVEL), 20, "D 20 Gravel arrive")
eq(grug_money.get(ann), 98, "D the fee is paid")
eq(grug_guild.lifetime(ann), lifetime, "D the lifetime stays")
eq(grug_guild.balance(ann), balance, "D the balance stays")
made, fee = grug_guild.stonewright_make(ann, "cobble_gravel")
eq(made, 20, "D omitted means All: whole lots")
eq(fee, 2, "D the fee of All")
eq(count_of(ann.inv, COBBLE), 5, "D the rest stays with the player")
-- More than one stack of output: the slots hold a stack each.
local amy = new_player("amy", "accord", 1, 1000)
fill(amy, {{"main", 9, "default:cobble 99"}, {"main", 10, "default:cobble 99"},
	{"main", 11, "default:cobble 99"}})
made, fee = grug_guild.stonewright_make(amy, "cobble_gravel")
eq(made, 290, "D three stacks convert")
eq(count_of(amy.inv, GRAVEL), 290, "D every piece arrives")
no_oversized(amy.inv, "D the output splits into stacks")
made, err = grug_guild.stonewright_make(ann, "cobble_gravel")
check(made == nil and err == "too_few", "D below one lot")
rows = grug_guild.stonewright_rows(ann)
eq(rows[1].lots, 0, "D no lot left")
eq(rows[1].short.item, COBBLE, "D the row says what is short")

-- Money limits the lots.
local bea = new_player("bea", "accord", 1, 3)
fill(bea, {{"main", 9, "default:cobble 90"}})
eq(grug_guild.stonewright_rows(bea)[1].lots, 3, "D the money limits the lots")
made, fee = grug_guild.stonewright_make(bea, "cobble_gravel")
check(made == 30 and fee == 3 and grug_money.get(bea) == 0, "D All pays what the purse holds")
eq(count_of(bea.inv, COBBLE), 60, "D the unpaid lots stay")
made, err = grug_guild.stonewright_make(bea, "cobble_gravel")
check(made == nil and err == "money", "D no copper (money)")
eq(grug_guild.stonewright_rows(bea)[1].short, "money", "D the row says the money is short")

-- An ornamented lot, with its bars over two lists.
local cal = new_player("cal", "accord", 4, 1000)
fill(cal, {{"main", 9, "default:cobble 99"}, {"main", 10, IRON_BAR .. " 1"}, {BAG, 1, IRON_BAR .. " 2"}})
local row = C.stonewright_recipe("ornamented_iron")
rows = grug_guild.stonewright_rows(cal)
eq(rows[5].lots, 3, "D three bars: three lots")
eq(rows[6].unlocked, false, "D rank 4 does not unlock Steel")
made, fee = grug_guild.stonewright_make(cal, row.id)
eq(made, 3 * row.output_count, "D All makes three lots of stones")
eq(fee, 3 * row.fee, "D the fee of three lots")
eq(count_of(cal.inv, IRON_BAR), 0, "D the bars are gone")
eq(count_of(cal.inv, COBBLE), 99 - 3 * row.inputs[1].count, "D the Cobblestone is gone")
eq(count_of(cal.inv, row.output), 3 * row.output_count, "D the stones arrive")

-- Room: a full inventory converts its own stacks; a bigger output is refused
-- whole, with nothing changed.
local dee = new_player("dee", "accord", 8, 100000, 8)
for list, stacks in pairs(dee.inv.lists) do
	for i in ipairs(stacks) do dee.inv:set_stack(list, i, ItemStack("default:torch 99")) end
end
fill(dee, {{BAG, 1, "default:cobble 90"}})
made, fee = grug_guild.stonewright_make(dee, "cobble_gravel")
eq(made, 90, "D a full inventory converts its own stack")
eq(count_of(dee.inv, GRAVEL), 90, "D the Gravel fits where the Cobblestone was")
eq(count_of(dee.inv, COBBLE), 0, "D the stack is used up")
-- Every slot full: a lot's output needs the slot its inputs free, so the rest
-- of a stack in that slot keeps it out.
local eli = new_player("eli", "accord", 8, 100000, 8)
for list, stacks in pairs(eli.inv.lists) do
	for i in ipairs(stacks) do eli.inv:set_stack(list, i, ItemStack("default:torch 99")) end
end
fill(eli, {{BAG, 1, "default:cobble 99"}, {BAG, 2, "default:gravel 99"}, {BAG, 3, IRON_BAR .. " 2"}})
before = snapshot(eli.inv)
local money_before = grug_money.get(eli)
made, err = grug_guild.stonewright_make(eli, "ornamented_iron", 1)
check(made == nil and err == "full", "D no room for the output: refused (full)")
eq(snapshot(eli.inv), before, "D a full refusal changes nothing")
eq(grug_money.get(eli), money_before, "D a full refusal takes no copper")

-- Without a faction.
local gus = new_player("gus", nil, 0, 100)
fill(gus, {{"main", 9, "default:cobble 50"}})
eq(#grug_guild.stonewright_rows(gus), 0, "D no guild, no rows")
made, err = grug_guild.stonewright_make(gus, "cobble_gravel")
check(made == nil and err == "no_faction", "D no guild (no_faction)")

------------------------------------------------------------------------------
-- E. The window.
------------------------------------------------------------------------------
local shown
core.show_formspec = function(_, _, formspec) shown = formspec end
core.close_formspec = function() shown = nil end
local function has(text) return shown ~= nil and shown:find(text, 1, true) ~= nil end
local FORM = "grug_traders:trade"
core.chat_send_player = function() end
vector = {distance = function(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end}
local handlers = rawget(core, "registered_on_player_receive_fieldss") or {}
check(#handlers > 0, "E the trade window's field handler is registered")
local function submit(player, fields)
	for _, fn in ipairs(handlers) do
		if fn(player, FORM, fields) then return end
	end
end
local WRIGHT = "grug_traders:stonewright"
local ORIGIN = {x = 0, y = 0, z = 0}
local vendor = grug_traders.get_vendor(WRIGHT)
check(vendor ~= nil and vendor.stonewright == true and vendor.nametag == "Stonewright",
	"E the Stonewright is registered")
check(not vendor.guild and not vendor.repairs, "E no trade-in and no repair at it")

local hal = new_player("hal", "accord", 2, 50)
fill(hal, {{"main", 9, "default:cobble 57"}, {"main", 10, "default:gravel 5"}})
grug_traders.open(hal, WRIGHT, ORIGIN, "accord")
check(has("Stonewright") and has("Your money"), "E the header")
check(not has("mode_buy") and not has("mode_sell") and not has("mode_tradein") and not has("repair"),
	"E one page, no modes")
check(has("label[0.6,1.75;Miner's Guild]") and has("Rank 2 of 10"), "E the guild lines")
check(not has("Charter of Stone"), "E no proper name in the interface")
check(has("10 Gravel") and has("10 Cobblestone + 1c"), "E the first row: output and cost")
check(has("stone1_1;1]") and has("stone5_1;5]") and has("stoneall_1;All (50)]"),
	"E the Trade-in's lots: 1, 5, All (50 made)")
check(not has("stone10_1;"), "E only five lots: no 10 button")
check(has("Need 10 Gravel"), "E a row without a lot says what is missing")
check(not has("stone1_2;"), "E that row has no button")
check(has("Reach Reputation Rank 3") and has("Reach Reputation Rank 8"), "E locked rows say their rank")
check(not has("stone1_4;") and not has("stoneall_4;") and not has("stoneall_9;"), "E locked rows have no button")
local old_form = shown
submit(hal, {stone1_1 = "1"})
eq(count_of(hal.inv, GRAVEL), 15, "E one lot made")
eq(count_of(hal.inv, COBBLE), 47, "E one lot taken")
eq(grug_money.get(hal), 49, "E one fee paid")
check(has("Made 10 Gravel for 1c."), "E the status line")
submit(hal, {stoneall_1 = "x"})
eq(count_of(hal.inv, GRAVEL), 55, "E All makes the whole lots")
eq(count_of(hal.inv, COBBLE), 7, "E the rest stays")
check(old_form:find("stoneall_1;", 1, true) ~= nil, "E the old form had the button")
submit(hal, {stoneall_1 = "x"})
eq(count_of(hal.inv, COBBLE), 7, "E a second click from the old form takes nothing")
-- A forged click: a locked row, an unknown index, a row without a lot, an
-- amount no button offers.
local frozen = snapshot(hal.inv)
submit(hal, {stone1_4 = "1"})
submit(hal, {stoneall_9 = "x"})
submit(hal, {stone1_99 = "1"})
submit(hal, {stone1_1 = "1"})
submit(hal, {stone7_2 = "1"})
eq(snapshot(hal.inv), frozen, "E forged clicks change nothing")
-- A stale row: the stack changed between render and click.
fill(hal, {{"main", 11, "default:cobble 20"}})
submit(hal, {stoneall_1 = "x"})
check(has("Your items have changed."), "E a stale row re-renders with the refusal")
eq(count_of(hal.inv, COBBLE), 27, "E a stale row takes nothing")
submit(hal, {stoneall_1 = "x"})
eq(count_of(hal.inv, COBBLE), 7, "E the fresh row makes")
-- The mode fields do nothing here.
submit(hal, {mode_sell = "Sell"})
check(not has("The vendor buys most things"), "E no Sell mode at the Stonewright")
submit(hal, {mode_tradein = "Trade-in"})
check(not has("You carry nothing the guild takes"), "E no Trade-in mode at the Stonewright")
-- Walking away.
hal.get_pos = function() return {x = 100, y = 0, z = 0} end
local far = snapshot(hal.inv)
submit(hal, {stoneall_2 = "x"})
eq(snapshot(hal.inv), far, "E out of range nothing happens")
submit(hal, {quit = "true"})
-- Another faction is refused the window.
local ian = new_player("ian", "throng", 2, 50)
shown = nil
grug_traders.open(ian, WRIGHT, ORIGIN, "accord")
eq(shown, nil, "E the other faction gets no window")
-- The Stonewright's fields count nowhere else.
local jon = new_player("jon", "accord", 3, 50)
fill(jon, {{"main", 9, "default:cobble 50"}})
grug_traders.open(jon, "grug_traders:guild_exchange", ORIGIN, "accord")
submit(jon, {stoneall_1 = "x"})
eq(count_of(jon.inv, COBBLE), 50, "E the exchange counter ignores the Stonewright's fields")
check(has("mode_tradein;Trade-in]"), "E the exchange keeps its modes")
-- A character without a guild sees why.
local kim = new_player("kim", nil, 0, 50)
grug_factions.serves = (function(serves)
	return function(faction, player)
		if player == kim then return true end
		return serves(faction, player)
	end
end)(grug_factions.serves)
grug_traders.open(kim, WRIGHT, ORIGIN, "accord")
check(has("You belong to no guild."), "E no guild: says so")

------------------------------------------------------------------------------
-- F. The socket and the templates.
------------------------------------------------------------------------------
local services = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp13/capital_services.lua")
local HALL = services.GUILD_HALL
eq(HALL.stonewright, "miners_guild/miners_guild_sorter", "F the sorter's socket")
for _, id in ipairs(HALL.residents) do
	check(id ~= HALL.stonewright, "F the socket is no resident's any more")
end
check(read("mods/CORE/grug_core/settlement_sockets.lua"):find("stonewright = true", 1, true) ~= nil,
	"F the service role is declared")
local parts = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp13/parts.lua")
eq(parts.param2_kind("grug_guild:stonewright_furnace_0_0_0"), parts.FACEDIR, "F a furnace cell turns with its house")
eq(parts.param2_kind("grug_guild:stonewright_grinder_1_1_1"), parts.FACEDIR, "F a grinder cell turns with its house")
for key in pairs(services.PLOTS) do
	local text = read("mods/MAPGEN/grug_mapgen/building_templates/templates/" .. key .. "_miners_guild.tpl")
	local legend = {}
	for name, rest in text:gmatch("\n. node (grug_guild:stonewright_[%w_]+)([^\n]*)") do
		legend[name] = rest
	end
	for _, list in pairs(cells) do
		for _, cell in ipairs(list) do
			eq(legend[cell.name], " o=facedir:3", "F " .. key .. ": " .. cell.name .. " faces the hall")
		end
	end
	check(text:find("sockets 3 1 11 face=1 id={id}_sorter role=idle tags=[work]", 1, true) ~= nil,
		"F " .. key .. ": the Stonewright stands between the machines, facing the hall")
end

------------------------------------------------------------------------------
-- G. The removed rule.
------------------------------------------------------------------------------
for _, path in ipairs({"AGENTS.md", "docs/design/miners_guild.md", "docs/design/economy.md",
		"mods/ENTITIES/grug_traders/stock.lua"}) do
	local text = read(path):lower()
	check(not text:find("no copper route", 1, true), "G " .. path .. " drops the rule")
	check(not text:find("copper never buys", 1, true), "G " .. path .. " drops its reason")
end
check(not read("tools/r58_guildspec/portable_test.lua"):find("no vendor source (", 1, true),
	"G the guild spec fixture no longer checks it")
local mason = {}
for _, entry in ipairs(grug_traders.profession_stock.mason or {}) do mason[entry.item] = true end
check(not mason[COBBLE] and not mason[GRAVEL], "G the mason stays as he is")

if failures > 0 then
	error("R70 GUILD PORTABLE FAIL " .. failures .. " of " .. checks)
end
print("R70 GUILD PORTABLE PASS checks=" .. checks)
