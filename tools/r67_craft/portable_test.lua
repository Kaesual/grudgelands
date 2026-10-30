-- Round 67 lane CRAFT portable test (LuaJIT; round67-plan.md rulings 9-17,
-- §4 CRAFT, §6 CRAFT): the whole game's registrations under Round 57's
-- game harness (tools/r57_details/game_harness.lua), then
--   N  the Creative category row only on a creative:* page (ruling 9): the
--      layout's row and height with and without the drawn page; the map
--      window's call (no page) shows none;
--   R  fewer recipes (rulings 11-13): no metal rod item, recipe or price
--      group, no route from stairs or slabs back to a block, no recipe from
--      a bush stem; the stems drop one plank of their wood; the outputs
--      that keep several recipes are only dyes, glass fragments and the
--      locked chest (CONTAINERS removes its second one), printed;
--   L  one row per output with the variant switch (ruling 10 and its
--      default): a search for Brown Dye shows one row; it opens on the
--      variant the inventory can make (the second), the switch reads
--      "Recipe 2/2" and steps both ways, wrapping round; an output with one
--      recipe has no switch; under "Craftable only" a row's count and
--      craftability follow the variant it shows (by default the first
--      craftable one; a chosen variant as itself);
--   B  the craft box (rulings 14, 15): plain "Craft", "×2 per craft" left of
--      it (none for a recipe making one), "Details" with its info icon left
--      of the star, which opens the details page;
--   V  favourites belong to the output: the star marks every variant, the
--      meta keeps the output's name, a stored recipe id reads as its output;
--   F  furnace fuel (ruling 17): Coal and Charcoal 40 s, Anthracite 60 s, a
--      log 15 s, leaves 2 s;
--   M  the Materials help page (ruling 16): the list (every item with a
--      source or a recipe ingredient; its size printed), the search through
--      the page's own handler, a result's source lines, the paging, and the
--      page's formspec bytes (printed: comparisons, not targets).
-- Prints "R67 CRAFT PORTABLE PASS checks=<n>" or the failures (exit 1).
--
--   luajit tools/r67_craft/portable_test.lua [REPO]

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
local function has(text, part, label)
	return check(text:find(part, 1, true) ~= nil, label .. " (missing " .. part .. ")")
end
local function lacks(text, part, label)
	return check(text:find(part, 1, true) == nil, label .. " (found " .. part .. ")")
end

local game = dofile(repo .. "/tools/r57_details/game_harness.lua")(repo)
check(#game.failures <= 2, "the harness loads the game (" .. #game.failures .. " files skipped)")

-- What the harness's stub engine leaves out and the Crafting page needs: a
-- stack's add_item (the room check of Max) and core.serialize/deserialize
-- of a list of strings (the favourites).
local Stack = getmetatable(ItemStack(""))
function Stack:add_item(other)
	other = ItemStack(other)
	if other:is_empty() then return other end
	if self:is_empty() then self.name, self.count = other.name, 0 end
	if self.name ~= other.name then return other end
	local moved = math.min(99 - self.count, other.count)
	self.count = self.count + moved
	return ItemStack(other.count > moved and (other.name .. " " .. (other.count - moved)) or "")
end
if type(core.serialize({"a"})) ~= "string" then
	core.serialize = function(list)
		local parts = {}
		for i, value in ipairs(list) do parts[i] = ("%q"):format(value) end
		return "return {" .. table.concat(parts, ", ") .. "}"
	end
	core.deserialize = function(text)
		local chunk = loadstring(text)
		return chunk and chunk() or nil
	end
end

------------------------------------------------------------------------------
-- N: the Creative category row.
------------------------------------------------------------------------------
local function player_named(name)
	local meta = {}
	local meta_object = {
		get_string = function(_, key) return meta[key] or "" end,
		set_string = function(_, key, value) meta[key] = value end,
		get_int = function(_, key) return tonumber(meta[key]) or 0 end,
		set_int = function(_, key, value) meta[key] = value end,
	}
	local empty = {get_list = function() return {} end, get_size = function() return 0 end,
		get_stack = function() return ItemStack("") end, is_empty = function() return true end,
		get_lists = function() return {} end}
	return {get_player_name = function() return name end, is_player = function() return true end,
		get_meta = function() return meta_object end, meta = meta,
		get_inventory = function() return empty end,
		get_pos = function() return {x = 0, y = 0, z = 0} end}
end

do
	local P = player_named("nav")
	local context = {}
	local creative = grug_inventory.navigation_layout(P, context, 20, nil, "creative:all")
	check(#creative.categories > 0, "N the harness has Creative pages")
	check(creative.show_categories and creative.height > grug_inventory.UI.header_h,
		"N a creative:* page shows the category row")
	local other = grug_inventory.navigation_layout(P, context, 20, nil, "sfinv:crafting")
	check(not other.show_categories and other.height == grug_inventory.UI.header_h,
		"N another page: no category row, the one-row header")
	local map = grug_inventory.navigation_layout(P, context, 20, nil)
	check(not map.show_categories and map.height == grug_inventory.UI.header_h,
		"N the map window's call (no page): no category row")
	local fs, height = grug_inventory.navigation(P, context, "sfinv:crafting", 20)
	eq(height, grug_inventory.UI.header_h, "N navigation on Crafting: the one-row height")
	lacks(fs, "grug_ui_tab_" .. creative.categories[1] .. ";", "N ... and no category button")
	has(fs, "grug_ui_creative;Creative]", "N ... the Creative entry stays in the primary row")
	fs, height = grug_inventory.navigation(P, context, "creative:all", 20)
	eq(height, creative.height, "N navigation on a Creative page: the taller header")
	has(fs, "grug_ui_tab_" .. creative.categories[1] .. ";", "N ... with the category buttons")
end

------------------------------------------------------------------------------
-- R: fewer recipes.
------------------------------------------------------------------------------
local METALS = {"bronze", "iron", "steel", "silversteel", "embersteel", "abyssal_steel"}
for _, metal in ipairs(METALS) do
	check(core.registered_items["grug_professions:metal_rod_" .. metal] == nil,
		"R no " .. metal .. " rod item")
end
local rod_recipes, back, stems = 0, 0, 0
for _, recipe in ipairs(grug_jobs.recipes) do
	if recipe.output:match("metal_rod") then rod_recipes = rod_recipes + 1 end
	for _, entry in ipairs(recipe.ingredients) do
		local item = entry.item or ""
		if item:match("metal_rod") then rod_recipes = rod_recipes + 1 end
		if item:match("^stairs:") and not recipe.output:match("^stairs:") then back = back + 1 end
		if item:match("_?bush_stem$") then stems = stems + 1 end
	end
end
eq(rod_recipes, 0, "R no recipe makes or takes a metal rod")
eq(back, 0, "R no route from stairs or slabs back to a block")
eq(stems, 0, "R no recipe takes a bush stem")
for _, item in pairs(core.registered_items) do
	check(((item.groups or {}).grug_metal_rod or 0) == 0, "R no item in the rod group")
end
local stairs = 0
for _, recipe in ipairs(grug_jobs.recipes_in_area("basic")) do
	if recipe.output:match("^stairs:") then stairs = stairs + 1 end
end
eq(stairs, 28 * 4, "R the stairs family keeps its four forward shapes per material")
eq(core.registered_nodes["default:bush_stem"].drop, "default:wood", "R a bush stem drops a plank")
eq(core.registered_nodes["default:acacia_bush_stem"].drop, "default:acacia_wood",
	"R an acacia bush stem drops an acacia plank")
eq(core.registered_nodes["default:pine_bush_stem"].drop, "default:pine_wood",
	"R a pine bush stem drops a pine plank")
for _, sword in ipairs({"grug_gear:sword_iron", "grug_gear:dagger_steel", "grug_gear:greataxe_bronze"}) do
	eq(#grug_jobs.recipes_for_output(sword), 1, "R " .. sword .. ": the stick recipe only")
end
local multi = {}
for _, area in ipairs(grug_jobs.AREAS) do
	local count = {}
	for _, recipe in ipairs(grug_jobs.recipes_in_area(area)) do
		count[recipe.output] = (count[recipe.output] or 0) + 1
	end
	for output, n in pairs(count) do
		if n > 1 then
			multi[#multi + 1] = output .. " " .. n
			check(output:match("^dye:") or output == "vessels:glass_fragments" or
				output == "default:chest_locked",
				"R only dyes, glass fragments and the locked chest keep several recipes: " .. output)
		end
	end
end
table.sort(multi)
print("outputs with several recipes: " .. table.concat(multi, ", "))

------------------------------------------------------------------------------
-- L, B, V: the Crafting page with variants.
------------------------------------------------------------------------------
local function inventory_of(lists)
	local inv = {}
	function inv:get_list(name) return lists[name] end
	function inv:get_size(name) return lists[name] and #lists[name] or 0 end
	function inv:get_stack(name, i) return lists[name] and lists[name][i] or ItemStack("") end
	function inv:is_empty(name)
		for _, stack in ipairs(lists[name] or {}) do if not stack:is_empty() then return false end end
		return true
	end
	function inv:get_lists() return lists end
	return inv
end
local lists = {}
for _, name in ipairs({"main", "craft", grug_jobs.OUTPUT_LIST, grug_jobs.TARGET_LIST}) do
	lists[name] = {}
	for i = 1, 8 do lists[name][i] = ItemStack("") end
end
-- Red and Green make Brown (the second recipe); no Orange is carried.
lists.main[1] = ItemStack("dye:red 4")
lists.main[2] = ItemStack("dye:green 4")
lists.main[3] = ItemStack("default:tree 2")
local P = player_named("crafter")
P.get_inventory = function() return inventory_of(lists) end
-- Every ingredient of both Brown recipes held once (basic_unlock.lua's set).
P.meta[grug_jobs.HELD_KEY] = "1 default:tree dye:black dye:green dye:orange dye:red"
local context = {page = "sfinv:crafting"}
local crafting = sfinv.pages["sfinv:crafting"]
sfinv.set_player_inventory_formspec = function() end
local function page_of()
	local ok, text = pcall(grug_jobs.crafting_page_content, P, context)
	check(ok, "L the Crafting page builds " .. tostring(not ok and text or ""))
	return ok and text or ""
end
local function click(fields)
	local ok, err = pcall(crafting.on_player_receive_fields, crafting, P, context, fields)
	check(ok, "L a click is handled " .. tostring(not ok and err or ""))
end
local CF = grug_jobs.CRAFT_FIELDS
page_of()
local st = context.grug_craft
st.typed, st.search = "brown", "brown"
local page = page_of()
local _, rows = page:gsub(CF.row .. "%d+;", "")
eq(rows, 1, "L one row for Brown Dye (two recipes)")
local browns = grug_jobs.recipes_for_output("dye:brown")
eq(#browns, 2, "L Brown Dye has two recipes")
local ordered = grug_jobs.recipe_variants(P, browns[1])
local craftable = grug_jobs.crafts_from_counts(grug_jobs.ingredient_counts(P), ordered[2]) > 0
check(craftable and grug_jobs.crafts_from_counts(grug_jobs.ingredient_counts(P), ordered[1]) == 0,
	"L the inventory makes only the second variant (Red + Green)")
eq(st.rows[1], ordered[2].id, "L the row opens on the variant the player can craft now")
has(page, "label[6.8," , "L the list row is drawn")
click({[CF.row .. "1"] = ""})
page = page_of()
eq(st.selected, ordered[2].id, "L a click chooses that variant")
has(page, "Recipe 2/2", "L the switch reads Recipe 2/2")
has(page, CF.variant_prev .. ";◀]", "L ... with ◀")
has(page, CF.variant_next .. ";▶]", "L ... and ▶")
click({[CF.variant_next] = "▶"})
page = page_of()
eq(st.selected, ordered[1].id, "L ▶ wraps round to the first variant")
has(page, "Recipe 1/2", "L ... Recipe 1/2")
local _, again = page:gsub(CF.row .. "%d+;", "")
eq(again, 1, "L the list still has one Brown row")
check(page:find(("box[0.2,2.35;6,0.5;"), 1, true) ~= nil, "L the row stays selected on the other variant")
click({[CF.variant_prev] = "◀"})
eq(st.selected, ordered[2].id, "L ◀ steps back (wrapping round)")
-- "Craftable only": count and craftability follow the variant the row
-- shows (the review of Round 67: never a ×0 row beside a craftable sibling).
click({[CF.only] = "true"})
page = page_of()
local _, only_rows = page:gsub(CF.row .. "%d+;", "")
eq(only_rows, 1, "L Craftable only keeps Brown Dye on its chosen, craftable variant")
has(page, "×4]", "L ... with its count (×4)")
st.selected = nil
page = page_of()
_, only_rows = page:gsub(CF.row .. "%d+;", "")
eq(only_rows, 1, "L nothing chosen: the row opens on the craftable variant and stays")
eq(st.rows[1], ordered[2].id, "L ... which is the second")
lacks(page, "×0", "L ... no ×0 row")
st.selected = ordered[1].id
page = page_of()
_, only_rows = page:gsub(CF.row .. "%d+;", "")
eq(only_rows, 0, "L a chosen variant the inventory cannot make leaves Craftable only")
st.selected = ordered[2].id
click({[CF.only] = "false"})

-- B: the craft box.
page = page_of()
has(page, CF.go .. "_" .. st.serial .. ";Craft]", "B the button reads plain Craft")
has(page, "×2 per craft", "B the hint ×2 per craft for a recipe that makes two")
lacks(page, "Craft ×", "B no count on the button")
local star_x = page:match("button%[([%d%.]+),[%d%.]+;0%.6,0%.6;" .. CF.fav .. ";")
local details_x, details_w = page:match("button%[([%d%.]+),[%d%.]+;([%d%.]+),0%.6;" .. CF.details .. ";Details%]")
check(star_x and details_x and tonumber(details_x) + tonumber(details_w) <= tonumber(star_x) + 0.001,
	"B Details sits left of the star (" .. tostring(details_x) .. ", " .. tostring(star_x) .. ")")
has(page, core.formspec_escape("grug_ui_icon_help.png^[multiply:" .. grug_core.ui.colors.accent),
	"B ... with its info icon (the UI help icon, tinted)")
lacks(page, "Recipe details]", "B the old Recipe details button is gone")
click({[CF.details] = "Details"})
check(st.box == "details", "B Details opens the details page")
click({grug_craft_dback = "◀ Back"})
-- A recipe that makes one: no hint, no switch.
st.typed, st.search, st.selected = "", "", nil
local planks = grug_jobs.recipes_for_output("default:wood")
eq(#planks, 1, "B Apple Wood Planks: one recipe left (the stem's is gone)")
st.selected = planks[1].id
page = page_of()
has(page, "×4 per craft", "B planks: ×4 per craft")
lacks(page, "Recipe 1/", "B one recipe: no switch")
local furnace = grug_jobs.recipes_for_output("default:furnace")[1]
st.selected = furnace.id
page = page_of()
lacks(page, " per craft", "B a recipe that makes one: no hint")

-- V: favourites belong to the output.
st.selected = ordered[1].id
page_of()
click({[CF.fav] = "☆"})
check(grug_jobs.is_favorite(P, ordered[1].id) and grug_jobs.is_favorite(P, ordered[2].id) and
	grug_jobs.is_favorite(P, "dye:brown"), "V the star marks the output: both variants")
eq(core.deserialize(P.meta[grug_jobs.FAVORITES_KEY])[1], "dye:brown", "V the meta keeps the output")
st.selected = ordered[2].id
page = page_of()
has(page, CF.fav .. ";★]", "V the other variant shows the gold star")
click({[CF.fav] = "★"})
check(not grug_jobs.is_favorite(P, "dye:brown"), "V a second click unmarks the output")
eq(P.meta[grug_jobs.FAVORITES_KEY], "", "V ... and empties the meta")
local Q = player_named("legacy")
Q.meta[grug_jobs.FAVORITES_KEY] = core.serialize({ordered[1].id, "t:gone|x*1",
	"grug_gear:sword_iron|grug_materials:iron_bar*2+grug_professions:metal_rod_iron*1"})
check(grug_jobs.is_favorite(Q, "dye:brown") and grug_jobs.is_favorite(Q, ordered[2].id),
	"V a stored recipe id (before Round 67) reads as its output")
check(grug_jobs.is_favorite(Q, "grug_gear:sword_iron") and
	grug_jobs.is_favorite(Q, grug_jobs.recipes_for_output("grug_gear:sword_iron")[1].id),
	"V a removed recipe's id (the rod sword) reads as its output too")
grug_jobs.toggle_favorite(Q, planks[1].id)
local saved = core.deserialize(Q.meta[grug_jobs.FAVORITES_KEY])
eq(table.concat(saved, " "), "default:wood dye:brown grug_gear:sword_iron t:gone",
	"V the next change writes outputs (an unknown one by its id's output part)")

------------------------------------------------------------------------------
-- F: furnace fuel.
------------------------------------------------------------------------------
local automatic = dofile(repo .. "/mods/PLAYER/grug_jobs/automatic.lua")
for _, station in ipairs({"furnace", "dual_furnace"}) do
	eq(automatic.fuel_time(station, ItemStack("default:coal_lump")), 40, "F " .. station .. " Coal 40 s")
	eq(automatic.fuel_time(station, ItemStack("grug_smelting:charcoal")), 40,
		"F " .. station .. " Charcoal 40 s")
	eq(automatic.fuel_time(station, ItemStack("grug_materials:anthracite")), 60,
		"F " .. station .. " Anthracite 60 s")
	eq(automatic.fuel_time(station, ItemStack("default:tree")), 15, "F " .. station .. " a log 15 s")
	eq(automatic.fuel_time(station, ItemStack("default:leaves")), 2, "F " .. station .. " leaves 2 s")
end

------------------------------------------------------------------------------
-- M: the Materials help page.
------------------------------------------------------------------------------
local materials = grug_inventory.help_materials(grug_jobs)
local index = grug_jobs.item_sources()
local listed = {}
for _, entry in ipairs(materials) do listed[entry.name] = true end
local missing = 0
for name in pairs(index.by_item) do
	if core.registered_items[name] and not listed[name] then missing = missing + 1 end
end
for _, recipe in ipairs(grug_jobs.recipes) do
	for _, entry in ipairs(recipe.ingredients) do
		if entry.item and not listed[entry.item] then missing = missing + 1 end
	end
end
eq(missing, 0, "M every item with a source and every recipe ingredient is listed")
check(listed["grug_mobs:linen_scrap"] and listed["grug_materials:iron_bar"] and
	listed["default:wood"], "M Linen Scrap, Iron Bar and planks are listed")
check(not listed["grug_professions:metal_rod_iron"], "M no metal rod")
local sorted_ok = true
for i = 2, #materials do
	if materials[i - 1].label > materials[i].label then sorted_ok = false end
end
check(sorted_ok, "M sorted by name")
print("materials listed: " .. #materials)

local help = sfinv.pages["grug_inventory:help"]
sfinv.set_page = function() end
local H = player_named("reader")
local hctx = {grug_help_section = "materials", page = "grug_inventory:help"}
local function help_page()
	local ok, text = pcall(help.get, help, H, hctx)
	check(ok, "M the Help page builds " .. tostring(not ok and text or ""))
	return ok and text or ""
end
local function help_click(fields)
	local ok, handled = pcall(help.on_player_receive_fields, help, H, hctx, fields)
	check(ok and handled, "M a click is handled " .. tostring(handled))
end
local fs = help_page()
has(fs, "grug_help_materials;Materials]", "M the Materials section button")
has(fs, "set_focus[grug_help_materials;true]", "M the section button keeps the focus")
has(fs, "Page 1 of " .. math.ceil(#materials / 20), "M the whole list, paged by 20")
has(fs, "Choose a material from the list.", "M nothing chosen yet")
local bytes_all = #fs
help_click({grug_help_mat_next = ">"})
has(help_page(), "Page 2 of", "M > turns the page")
help_click({grug_help_mat_search = "iron bar", key_enter_field = "grug_help_mat_search"})
fs = help_page()
has(fs, "Iron Bar", "M a search for \"iron bar\" finds the Iron Bar")
has(fs, "Page 1 of 1", "M ... on one page")
local hits = grug_inventory.help_material_results(grug_jobs, "iron bar")
check(#hits >= 1 and #hits <= 20, "M ... with few hits (" .. #hits .. ")")
local row
for i, entry in ipairs(hits) do if entry.name == "grug_materials:iron_bar" then row = i end end
check(row ~= nil, "M Iron Bar is a hit")
help_click({["grug_help_mat_row_" .. (row or 1)] = ""})
fs = help_page()
has(fs, "Where it comes from", "M the chosen material's heading")
has(fs, core.formspec_escape("Furnace: from Iron Lump"), "M ... its furnace source line")
local bytes_chosen = #fs
help_click({grug_help_mat_search = "planks", grug_help_mat_find = "Search"})
local planks_hits = grug_inventory.help_material_results(grug_jobs, "apple wood planks")
eq(#planks_hits, 1, "M one Apple Wood Planks")
help_click({grug_help_mat_search = "apple wood planks", grug_help_mat_find = "Search"})
has(help_page(), "Page 1 of 1", "M one page of planks")
help_click({grug_help_mat_row_1 = ""})
fs = help_page()
has(fs, core.formspec_escape("Dug from: Bush Stem"), "M planks: dug from a bush stem")
help_click({grug_help_mat_search = "zzzz", grug_help_mat_find = "Search"})
has(help_page(), "No material matches.", "M a search without hits says so")
help_click({grug_help_mat_clear = "×"})
has(help_page(), "Page 1 of " .. math.ceil(#materials / 20), "M × shows the whole list again")
print(("bytes: Help Materials page: whole list %d, a material chosen %d"):format(bytes_all,
	bytes_chosen))

print(("R67 CRAFT PORTABLE %s checks=%d failures=%d"):format(failures == 0 and "PASS" or "FAIL",
	checks, failures))
if failures > 0 then error("R67 CRAFT PORTABLE FAIL") end
