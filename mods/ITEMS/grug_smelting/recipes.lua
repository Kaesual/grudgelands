-- Every WP26 recipe registration, and the startup self-audit that proves the
-- surface is exactly the one the task card names (§3.2-§3.5, gates 1 and 5).
--
-- INPUT-FORM RULE (task card §3.1, binding): an alloy input is the material's
-- BAR where a bar exists; mined Coal, Emberglass and Abyssal Crystal enter as
-- their mined items, because no bar form of them exists or may be invented.
-- `grug_materials.PROCESSED_MATERIALS` already encodes that distinction --
-- `item` is the nine-unit storage input for all twelve rows, `bar_item` exists
-- only on the ten `kind = "bar"` rows -- so the storage family is derived from
-- the registry rather than repeated here.
--
-- COOK TIMES ARE CALIBRATION, NOT CONTRACT. The task card's §1 non-goal "No
-- number freezing" is binding: the literals below are WP26's own first
-- calibration (the six-tier ladder made monotone, the T1 alloy deliberately
-- close to the normal furnace's 3 s so the first station upgrade does not feel
-- slower), measured once in the engine and documented in
-- `docs/research/wp26-implementation.md`. Nothing reads them as a design
-- number and no other work package inherits them.

local PROCESSED = grug_materials.PROCESSED_MATERIALS

--
-- §3.2 -- the normal furnace: one lump, one bar
--
-- The complete family. Quartz and every gem are never smelted (WP10 owns gem
-- processing); Emberglass and Abyssal Crystal are mined items, never cooked.
--
local SMELTS = {
	{"grug_materials:copper_bar", "default:copper_lump"},
	{"grug_materials:tin_bar", "default:tin_lump"},
	{"grug_materials:iron_bar", "default:iron_lump"},
	{"grug_materials:silver_bar", "grug_materials:silver_lump"},
	{"grug_materials:gold_bar", "default:gold_lump"},
}

-- The engine's own default is 3 s; it is spelled out because it is a number
-- WP26 chose, not one it inherited.
local SMELT_TIME = 3

for _, row in ipairs(SMELTS) do
	core.register_craft({
		type = "cooking",
		output = row[1],
		recipe = row[2],
		cooktime = SMELT_TIME,
	})
end

--
-- §3.3 -- the dual furnace: two materials, either order, one of each
--
-- Mined Coal occupies a MATERIAL slot for Steel; Coal or Charcoal burning in
-- the fuel slot never substitutes for it (§3.0.2). The node's fuel-slot filter
-- and the matcher together are what make that true (`node.lua`).
--
local ALLOYS = {
	{"grug_materials:bronze_bar",
		"grug_materials:copper_bar", "grug_materials:tin_bar", 4},
	{"grug_materials:steel_bar",
		"grug_materials:iron_bar", "default:coal_lump", 6},
	{"grug_materials:silversteel_bar",
		"grug_materials:steel_bar", "grug_materials:silver_bar", 8},
	{"grug_materials:embersteel_bar",
		"grug_materials:silversteel_bar", "grug_materials:emberglass", 10},
	{"grug_materials:abyssal_steel_bar",
		"grug_materials:embersteel_bar", "grug_materials:abyssal_crystal", 12},
}

for _, row in ipairs(ALLOYS) do
	grug_smelting.register_alloy(row[1], row[2], row[3], row[4])
end

--
-- §3.4 -- storage pack/unpack, both directions, all twelve processed rows
--
-- Including the two `kind = "resource"` rows (Emberglass, Abyssal Crystal),
-- whose storage input is the mined item itself, and the Gold Block sentence of
-- §3.0.1. Rough gems cannot pack and cut-gem blocks belong to WP10, so no gem
-- appears here; `grug_materials:emberglass_shard` is a WP43 migration target
-- and deliberately gets no recipe.
--
for _, material in ipairs(PROCESSED) do
	core.register_craft({
		output = material.block_node,
		recipe = {
			{material.item, material.item, material.item},
			{material.item, material.item, material.item},
			{material.item, material.item, material.item},
		},
	})
	core.register_craft({
		output = material.item .. " 9",
		recipe = {{material.block_node}},
	})
end

--
-- §3.5 -- the dual furnace's own craft recipe
--
-- One normal furnace plus the first alloy's two metals, in LotT's
-- T-arrangement (decided 2026-08-13, `items_crafting.md` §3.0.2). LotT's own
-- steel-tier original (`lottblocks/crafting.lua:271-277`) would deadlock this
-- ladder: Steel is T3 here and needs the dual furnace to exist first.
--
core.register_craft({
	output = grug_smelting.NODE,
	recipe = {
		{"", "grug_materials:copper_bar", ""},
		{"grug_materials:copper_bar", "default:furnace",
			"grug_materials:tin_bar"},
	},
})

--
-- Startup self-audit (gates 1 and 5)
--
-- Gate 1 is recipe-surface EXACTNESS, which a registration loop cannot prove
-- about itself: it has to be compared against the itemstrings §3 names. The
-- two tables above are that comparison's left-hand side, so what is left to
-- prove at startup is that the engine and the registry agree with them -- every
-- input and output really registered, every alloy really in `RECIPES`, and no
-- regional, cultural or trophy material anywhere in the surface.
--

local function fail(message)
	error("grug_smelting startup audit: " .. message)
end

-- Gate 5's runtime half: the ids no universal bar may ever consume.
local function forbidden_inputs()
	local set = {}
	for _, resource in ipairs(grug_materials.RESOURCES) do
		if resource.scope == "regional" then
			set[resource.raw_item] = "regional gem"
			if resource.cut_item then
				set[resource.cut_item] = "regional gem"
			end
			if resource.block_node then
				set[resource.block_node] = "regional gem"
			end
		end
	end
	for _, material in pairs(grug_materials.CULTURAL_MATERIALS) do
		set[material.item] = "cultural material"
	end
	return set
end

core.register_on_mods_loaded(function()
	local forbidden = forbidden_inputs()
	local function check_item(itemname, role)
		if not core.registered_items[itemname] then
			fail("unregistered " .. role .. ": " .. itemname)
		end
		if forbidden[itemname] then
			fail(forbidden[itemname] .. " used as " .. role .. ": " .. itemname)
		end
		if itemname:find("trophy", 1, true) or
				itemname:find("crown", 1, true) then
			fail("trophy used as " .. role .. ": " .. itemname)
		end
	end

	-- §3.2: every cooking recipe is the engine's answer for its input.
	for _, row in ipairs(SMELTS) do
		check_item(row[1], "smelt output")
		check_item(row[2], "smelt input")
		local cooked = core.get_craft_result({method = "cooking", width = 1,
			items = {ItemStack(row[2])}})
		if cooked.time ~= SMELT_TIME or
				cooked.item:get_name() ~= row[1] or
				cooked.item:get_count() ~= 1 then
			fail("the engine does not cook " .. row[2] .. " into one " ..
				row[1] .. " in " .. SMELT_TIME .. " s")
		end
	end

	-- §3.3: `RECIPES` is exactly the five rows above, in order, and the
	-- matcher answers in both slot orders.
	if #grug_smelting.RECIPES ~= #ALLOYS then
		fail(#grug_smelting.RECIPES .. " alloy recipes registered, not " ..
			#ALLOYS)
	end
	for index, row in ipairs(ALLOYS) do
		local recipe = grug_smelting.RECIPES[index]
		if recipe.output ~= row[1] or recipe.inputs[1] ~= row[2] or
				recipe.inputs[2] ~= row[3] or recipe.time ~= row[4] then
			fail("alloy " .. index .. " is not the registered " .. row[1])
		end
		check_item(row[1], "alloy output")
		check_item(row[2], "alloy input")
		check_item(row[3], "alloy input")
		if grug_smelting.match(row[2], row[3]) ~= recipe or
				grug_smelting.match(row[3], row[2]) ~= recipe then
			fail("alloy " .. row[1] .. " does not match in both slot orders")
		end
	end

	-- §3.4: twelve pack/unpack pairs, and the engine really has both shapes.
	for _, material in ipairs(PROCESSED) do
		check_item(material.item, "storage item")
		check_item(material.block_node, "storage block")
		local packed = core.get_craft_result({method = "normal", width = 3,
			items = {
				ItemStack(material.item), ItemStack(material.item),
				ItemStack(material.item), ItemStack(material.item),
				ItemStack(material.item), ItemStack(material.item),
				ItemStack(material.item), ItemStack(material.item),
				ItemStack(material.item),
			}})
		if packed.item:get_name() ~= material.block_node or
				packed.item:get_count() ~= 1 then
			fail("nine " .. material.item .. " do not pack into " ..
				material.block_node)
		end
		local unpacked = core.get_craft_result({method = "normal", width = 1,
			items = {ItemStack(material.block_node)}})
		if unpacked.item:get_name() ~= material.item or
				unpacked.item:get_count() ~= 9 then
			fail(material.block_node .. " does not unpack into nine " ..
				material.item)
		end
	end

	-- §3.5: the station itself is craftable from a normal furnace.
	local station = core.get_craft_result({method = "normal", width = 3,
		items = {
			ItemStack(""), ItemStack("grug_materials:copper_bar"), ItemStack(""),
			ItemStack("grug_materials:copper_bar"), ItemStack("default:furnace"),
			ItemStack("grug_materials:tin_bar"),
		}})
	if station.item:get_name() ~= grug_smelting.NODE or
			station.item:get_count() ~= 1 then
		fail("the T-arrangement does not craft " .. grug_smelting.NODE)
	end

	core.log("action", "[grug_smelting] recipe audit passed: " .. #SMELTS ..
		" cooking, " .. #grug_smelting.RECIPES .. " dualfurn, " ..
		#PROCESSED .. " storage pairs, 1 station")
end)
