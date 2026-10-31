-- Round 68 follow-up INSTALL portable test (LuaJIT): the picked bar,
-- setting, gem and block icons (tools/r68_icons/INSTALL.md; the user's
-- picks of 2026-10-31: bars and metal blocks A, settings B, gems D).
--
--   luajit tools/r68_install/portable_test.lua REPO
--
-- Runs the shipped grug_materials/ores.lua and grug_artisans/goldsmith.lua
-- against small engine stubs and checks:
--   I  each of the 47 ids in INSTALL.md's table draws its own file, named
--      as the table's destination, with no texture modifier; the shipped
--      file is byte-identical to its candidate; a cut gem's image is not
--      derived from its raw image; no listed registration still names a
--      `default_*_ingot.png`, `default_diamond.png` or `default_*_block.png`;
--   K  what keeps its look: the Silver lump, Emberglass and its block,
--      Anthracite and every ore tile;
--   G  an unknown bar material still fails loudly at registration.
-- Prints "R68 INSTALL PORTABLE PASS checks=<n>" or raises.
local repo = assert(arg and arg[1], "usage: luajit portable_test.lua REPO")
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if ok then print("ok   " .. label) else failures = failures + 1; print("FAIL " .. label) end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", want " .. tostring(expected) .. ")")
end
local function read(path)
	local handle = io.open(repo .. "/" .. path, "rb")
	if not handle then return nil end
	local text = handle:read("*a")
	handle:close()
	return text
end

-- ---------------------------------------------------------------------------
-- Engine stubs and the two files, loaded fresh per run
-- ---------------------------------------------------------------------------
local function load_game(edit_materials)
	local nodes, items = {}, {}
	core = {
		registered_nodes = nodes, registered_items = items,
		get_modpath = function() return nil end,
		register_node = function(name, def)
			def.name = name
			nodes[name], items[name] = def, def
		end,
		register_craftitem = function(name, def)
			def.name = name
			items[name] = def
		end,
	}
	default = {
		node_sound_stone_defaults = function() return {} end,
		node_sound_metal_defaults = function() return {} end,
		node_sound_glass_defaults = function() return {} end,
		register_mesepost = function() end,
		LIGHT_MAX = 14,
	}
	grug_materials = {}
	dofile(repo .. "/mods/ITEMS/grug_materials/registry.lua")
	-- ores.lua names two helpers of mining.lua.
	grug_materials.resource_ore_description = function(resource)
		return resource.name .. " Ore"
	end
	assert(loadstring(read("mods/ITEMS/grug_materials/mining.lua"):match(
		"(function grug_materials%.set_gate_groups.-\nend)")))()
	if edit_materials then edit_materials(grug_materials) end
	local ok, err = pcall(dofile, repo .. "/mods/ITEMS/grug_materials/ores.lua")
	if not ok then return nil, err end

	-- goldsmith.lua in its own environment: register_item as init.lua has it.
	local A = {
		register_ingredient = function() end,
		register_recipe = function() end,
		register_item = function(name, description, image, groups)
			core.register_craftitem(name, {description = description,
				inventory_image = image, groups = groups})
			return name
		end,
	}
	local env = setmetatable({
		grug_artisans = A,
		grug_materials = setmetatable({register_on_harvest = function() end},
			{__index = grug_materials}),
		grug_gear = {trinket_item = function(key, tier) return "trinket:" .. key .. tier end},
		grug_jobs = {has = function() return true end,
			DURATIONS = {gear = 3, material = 1},
			ingredient_list = function(tokens)
				local list = {}
				for _, token in ipairs(tokens) do list[#list + 1] = {item = token, n = 1} end
				return list
			end},
		grug_items = {mastery_band = function() return 1 end},
	}, {__index = _G})
	env.core = setmetatable({register_craft = function() end, add_item = function() end},
		{__index = core})
	local chunk = assert(loadfile(repo .. "/mods/ITEMS/grug_artisans/goldsmith.lua"))
	setfenv(chunk, env)
	chunk()
	return items
end

local items = assert(load_game())
local function image_of(id)
	local def = items[id]
	if not def then return nil end
	return def.tiles and def.tiles[1] or def.inventory_image
end

-- ---------------------------------------------------------------------------
-- I. The 47 picked icons
-- ---------------------------------------------------------------------------
local install = assert(read("tools/r68_icons/INSTALL.md"), "INSTALL.md")
local rows = {}
for candidate, id, dest in install:gmatch(
		"\n| %[(candidates/[%w_/]+%.png)%]%([^)]+%) | `([%w_:]+)` | `([%w_/%.]+)` |") do
	rows[#rows + 1] = {candidate = candidate, id = id, dest = dest}
end
eq(#rows, 47, "I INSTALL.md lists 47 icons")
local OLD = {"default_[%w_]*_ingot%.png", "default_diamond%.png", "default_[%w_]*_block%.png"}
local seen_files = {}
for _, row in ipairs(rows) do
	local file = row.dest:match("([^/]+)$")
	local image = image_of(row.id)
	eq(image, file, "I " .. row.id .. " draws its own file")
	check(image ~= nil and not image:find("^", 1, true), "I " .. row.id .. " has no modifier")
	for _, pattern in ipairs(OLD) do
		check(image ~= nil and not image:find(pattern), "I " .. row.id .. " not " .. pattern)
	end
	local def = items[row.id]
	if def and def.tiles then
		eq(#def.tiles, 1, "I " .. row.id .. " one tile for all six faces")
	end
	local shipped = read("mods/ITEMS/" .. row.dest)
	local source = read("tools/r68_icons/" .. row.candidate)
	check(shipped ~= nil and source ~= nil and shipped == source,
		"I " .. row.dest .. " is " .. row.candidate .. " byte for byte")
	check(not seen_files[file], "I " .. file .. " used once")
	seen_files[file] = true
end

-- Cut gems no longer derive from the raw image.
local cuts = 0
for _, resource in ipairs(grug_materials.RESOURCES) do
	if resource.cut_item then
		cuts = cuts + 1
		local raw, cut = image_of(resource.raw_item), image_of(resource.cut_item)
		check(cut ~= raw and not cut:find(raw, 1, true),
			"I " .. resource.cut_item .. " does not derive from " .. tostring(raw))
		check(image_of(resource.block_node) ~= raw,
			"I " .. resource.block_node .. " is not the raw image")
	end
end
eq(cuts, 6, "I six cut gems")

-- ---------------------------------------------------------------------------
-- K. What keeps its look
-- ---------------------------------------------------------------------------
eq(image_of("grug_materials:silver_lump"), "default_iron_lump.png^[colorize:#e8edf2:200",
	"K Silver lump unchanged")
eq(image_of("grug_materials:emberglass"), "default_mese_crystal.png^[colorize:#ff7a2e:45",
	"K Emberglass unchanged")
eq(image_of("grug_materials:emberglass_block"),
	"default_mese_crystal.png^[colorize:#ff7a2e:45", "K Emberglass Block unchanged")
eq(image_of("grug_materials:anthracite"), "grug_materials_anthracite_lump.png",
	"K Anthracite unchanged")
eq(image_of("grug_materials:emberglass_shard"),
	"default_mese_crystal_fragment.png^[colorize:#ff7a2e:45", "K Emberglass Shard unchanged")
local ores = 0
for _, resource in ipairs(grug_materials.RESOURCES) do
	local node = items[resource.natural_node]
	if resource.natural_node:match("^grug_materials:") then
		ores = ores + 1
		eq(node and node.tiles[1], "default_stone.png^grug_materials_mineral_" ..
			resource.key .. ".png", "K " .. resource.natural_node .. " ore tile unchanged")
	end
end
eq(ores, 11, "K eleven grug_materials ores")

-- ---------------------------------------------------------------------------
-- G. An unknown material still fails loudly
-- ---------------------------------------------------------------------------
local broken, err = load_game(function(M)
	M.PROCESSED_MATERIALS[#M.PROCESSED_MATERIALS + 1] = {key = "pewter",
		name = "Pewter", kind = "bar", item = "grug_materials:pewter_bar",
		block_node = "grug_materials:pewter_block"}
end)
check(broken == nil and tostring(err):find("missing processed visual for pewter", 1, true),
	"G an unknown bar material fails: " .. tostring(err))

if failures > 0 then
	error(("R68 INSTALL PORTABLE FAIL %d of %d checks"):format(failures, checks))
end
print(("R68 INSTALL PORTABLE PASS checks=%d"):format(checks))
