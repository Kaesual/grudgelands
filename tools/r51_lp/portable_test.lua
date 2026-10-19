-- Round 51 lane LP portable test (LuaJIT): the land plants on the real
-- sources, the real mapgen runtime of one seed (tools/seed_fleet/runtime.lua,
-- built as the engine builds it, main's vegetation authority included) and
-- the real renewal:
--   A. the plants: drawtype, alpha, not walkable, nothing glows, drops
--      nothing (ferns and marram too), the picked art byte for byte, the
--      bush foliage and the lianas decay with their wood, the liana pair;
--   B. the rows: every LP row's biomes, kind, node, density, rule and class
--      (the viewer's guide densities), no swamp papyrus pedestal row, and the
--      authority's palettes: each simple row grows on its hosts at the row's
--      density and nowhere else;
--   C. written chunks of the seed (a jungle, an elf forest, crags, a warm
--      beach): papyrus a plain stack of 2-4 on sand with water beside it,
--      marram on sand with no water within 3, lichen on gravel or stone in
--      a patch, flowers and alpine plants on their hosts, lianas strands
--      above one end hanging from their jungle tree (most whole, with air
--      below: interleaved crowns and slopes cut a few);
--   D. regrowth: at a column where the generator placed each plant, the
--      authority's ground-cover category holds it at its row's density
--      (papyrus as a shore stack, lichen in its patch) and renewal, on that
--      spot of an empty box, places it;
--   E. the lianas of this world's jungle and kapok templates and grown trees:
--      strands above one end, 2-6 long, under leaves, two nodes clear of the
--      ground, within the leaf decay reach of wood; no other species;
--   F. the closed node roster: 173 rows (LK's kit and LP's 17), LP's with the
--      decoration role.
--
-- Usage (repo root): luajit tools/r51_lp/portable_test.lua [REPO]
local repo = arg and arg[1] or "."
local SEED = "12345"
local checks, failures = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function read(path)
	local handle = io.open(path, "rb")
	if not handle then return nil end
	local data = handle:read("*a")
	handle:close()
	return data
end
local function set(list)
	local result = {}
	for _, value in ipairs(list) do result[value] = true end
	return result
end

local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, SEED, "emerge")
local nodes = R.fake.registered_nodes
local density = R.authority.vegetation
local zones = R.built.zones_session
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"

-- A. the plants -----------------------------------------------------------------
local ART = repo .. "/tools/r51_land/plants/"
local NODES_TEX = repo .. "/mods/ITEMS/grug_nodes/textures/"
local TREES_TEX = repo .. "/mods/ITEMS/grug_trees/textures/"
-- name, drawtype, shipped texture, ARTL file
local PLANTS = {
	{"grug_nodes:flower_ruby_fan", "plantlike", NODES_TEX .. "grug_nodes_flower_ruby_fan.png", "flower_ruby_fan.png"},
	{"grug_nodes:flower_ember_star", "plantlike", NODES_TEX .. "grug_nodes_flower_ember_star.png", "flower_ember_star.png"},
	{"grug_nodes:flower_violet_fan", "plantlike", NODES_TEX .. "grug_nodes_flower_violet_fan.png", "flower_violet_fan.png"},
	{"grug_nodes:flower_blush_star", "plantlike", NODES_TEX .. "grug_nodes_flower_blush_star.png", "flower_blush_star.png"},
	{"grug_nodes:flower_lilac_bells", "plantlike", NODES_TEX .. "grug_nodes_flower_lilac_bells.png", "flower_lilac_bells.png"},
	{"grug_nodes:flower_cream_cups", "plantlike", NODES_TEX .. "grug_nodes_flower_cream_cups.png", "flower_cream_cups.png"},
	{"grug_nodes:alpine_cushion", "plantlike", NODES_TEX .. "grug_nodes_alpine_cushion.png", "alpine_cushion.png"},
	{"grug_nodes:alpine_windshrub", "plantlike", NODES_TEX .. "grug_nodes_alpine_windshrub.png", "alpine_windshrub.png"},
	{"grug_nodes:lichen_carpet", "nodebox", NODES_TEX .. "grug_nodes_lichen_carpet_top.png", "lichen_carpet_top.png"},
	{"grug_nodes:lichen_carpet_b", "nodebox", NODES_TEX .. "grug_nodes_lichen_carpet_top_b.png", "lichen_carpet_top_b.png"},
	{"grug_nodes:jungle_bush_leaves", "allfaces_optional", NODES_TEX .. "grug_nodes_jungle_bush_leaves.png", "jungle_bush_leaves.png"},
	{"grug_nodes:withered_bush_leaves", "allfaces_optional", NODES_TEX .. "grug_nodes_withered_bush_leaves.png", "withered_bush_leaves.png"},
	{"grug_trees:liana", "plantlike", TREES_TEX .. "grug_trees_liana.png", "liana_end.png"},
	{"grug_trees:liana_strand", "plantlike", TREES_TEX .. "grug_trees_liana_strand.png", "liana_strand.png"},
}
for _, row in ipairs(PLANTS) do
	local name, drawtype, shipped, art = row[1], row[2], row[3], row[4]
	local def = rawget(nodes, name)
	if check(def ~= nil, name .. " is registered") then
		check(def.drawtype == drawtype, name .. " is " .. drawtype)
		check(def.drop == "", name .. " drops nothing")
		check((def.light_source or 0) == 0, name .. " does not glow")
		check(def.is_ground_content == false, name .. " is no ground content")
		if drawtype ~= "allfaces_optional" then
			check(def.walkable == false, name .. " is not walkable")
		end
		local file = shipped:match("([%w_]+%.png)$")
		check(def.tiles[1] == file, name .. " wears " .. file)
		local a, b = read(shipped), read(ART .. art)
		check(a ~= nil and a == b, file .. " is the picked " .. art .. " byte for byte")
	end
end
for _, name in ipairs({"grug_nodes:lichen_carpet", "grug_nodes:lichen_carpet_b"}) do
	local def = nodes[name]
	check(def.use_texture_alpha == "clip" and def.groups.attached_node == 3 and def.buildable_to and
		def.node_box.fixed[5] == -7 / 16, name .. ": a 1/16 carpet, alpha clip, attached below")
end
for i = 1, 3 do
	check(nodes["default:fern_" .. i].drop == "", "default:fern_" .. i .. " drops nothing")
	check(nodes["default:marram_grass_" .. i].drop == "", "default:marram_grass_" .. i .. " drops nothing")
end
-- decay with the wood: the stems' after_destruct and the leaves' timers
for _, pair in ipairs({{"default:bush_stem", "grug_nodes:jungle_bush_leaves", "default:bush_leaves"},
		{"default:acacia_bush_stem", "grug_nodes:withered_bush_leaves", "default:acacia_bush_leaves"},
		{"default:jungletree", "grug_trees:liana", "default:jungleleaves"},
		{"default:jungletree", "grug_trees:liana_strand", "default:jungleleaves"}}) do
	check(type(nodes[pair[1]].after_destruct) == "function" and type(nodes[pair[2]].on_timer) == "function" and
		type(nodes[pair[3]].on_timer) == "function", pair[2] .. " decays with " .. pair[1] ..
		" (and " .. pair[3] .. " still does)")
end
check(grug_trees.hanging.pair("grug_trees:liana_strand").tip == "grug_trees:liana" and
	grug_trees.hanging.pair("grug_trees:liana").strand == "grug_trees:liana_strand" and
	type(nodes["grug_trees:liana"].after_dig_node) == "function",
	"the liana end and strand are one hanging pair")
-- no plant shares a name or a texture with a gathering source (ruling 11)
local catalog = dofile(repo .. "/mods/ITEMS/grug_gathering/catalog.lua")
local source_tex = {}
for _, source in ipairs(catalog.p9g_sources()) do
	local def = rawget(nodes, source.source_node)
	for _, tile in ipairs(def and def.tiles or {}) do
		source_tex[type(tile) == "table" and tile.name or tile] = source.source_node
	end
end
for _, row in ipairs(PLANTS) do
	check(source_tex[nodes[row[1]].tiles[1]] == nil, row[1] .. " looks like no gathering source")
end

-- B. the rows ------------------------------------------------------------------------
local J = {"grug_deep_jungle", "grug_jungle_edge", "grug_jungle_fringe"}
local E = {"grug_deep_forest", "grug_elf_forest"}
local C = {"grug_crags", "grug_pine_hills"}
local WARM = {"grug_badlands", "grug_badlands_east", "grug_deep_jungle", "grug_jungle_edge",
	"grug_jungle_fringe", "grug_savanna"}
local SAND = {"grug_badlands", "grug_badlands_east", "grug_beach", "grug_blight", "grug_bone_forest",
	"grug_crags", "grug_crags_snowy", "grug_deep_forest", "grug_deep_jungle", "grug_elf_forest",
	"grug_jungle_edge", "grug_jungle_fringe", "grug_meadows", "grug_pine_hills", "grug_savanna"}
local SOIL = "soil"
local ALPINE = {"default:dirt_with_coniferous_litter", "default:dirt_with_grass", "default:gravel",
	"grug_nodes:dirt_with_forest_litter"}
-- id: biomes, kind, node or asset, denominator, rule, class, hosts
local ROWS = {
	jungle_flower_ruby_fan = {J, "simple", "grug_nodes:flower_ruby_fan", 300, "none", 4, SOIL},
	jungle_flower_ember_star = {J, "simple", "grug_nodes:flower_ember_star", 300, "none", 4, SOIL},
	jungle_flower_violet_fan = {J, "simple", "grug_nodes:flower_violet_fan", 300, "none", 4, SOIL},
	elf_flower_blush_star = {E, "simple", "grug_nodes:flower_blush_star", 300, "none", 4, SOIL},
	elf_flower_lilac_bells = {E, "simple", "grug_nodes:flower_lilac_bells", 300, "none", 4, SOIL},
	elf_flower_cream_cups = {E, "simple", "grug_nodes:flower_cream_cups", 300, "none", 4, SOIL},
	jungle_fern_1 = {J, "simple", "default:fern_1", 75, "one_entry_per_variant", 4, SOIL},
	jungle_fern_2 = {J, "simple", "default:fern_2", 75, "one_entry_per_variant", 4, SOIL},
	jungle_fern_3 = {J, "simple", "default:fern_3", 75, "one_entry_per_variant", 4, SOIL},
	crags_alpine_cushion = {C, "simple", "grug_nodes:alpine_cushion", 80, "none", 4, ALPINE},
	crags_alpine_windshrub = {C, "simple", "grug_nodes:alpine_windshrub", 80, "none", 4, ALPINE},
	crags_lichen_a = {C, "simple", "grug_nodes:lichen_carpet", 14, "rock_patch", 4,
		{"default:gravel", "default:stone"}},
	crags_lichen_b = {C, "simple", "grug_nodes:lichen_carpet_b", 14, "rock_patch", 4,
		{"default:gravel", "default:stone"}},
	beach_papyrus = {WARM, "simple", "default:papyrus", 5, "surface_y_1_to_4", 3, {"default:sand"}},
	beach_marram_1 = {SAND, "simple", "default:marram_grass_1", 27, "shore_dry", 4, {"default:sand"}},
	beach_marram_2 = {SAND, "simple", "default:marram_grass_2", 27, "shore_dry", 4, {"default:sand"}},
	beach_marram_3 = {SAND, "simple", "default:marram_grass_3", 27, "shore_dry", 4, {"default:sand"}},
	jungle_bush = {J, "template", "bush.mts", 250, "center_xz;quarter_turn_rotation", 2},
	badlands_withered_bush = {{"grug_badlands", "grug_badlands_east"}, "template", "acacia_bush.mts", 150,
		"center_xz;quarter_turn_rotation", 2},
}
-- the fertile palettes (r6_content.lua) a "soil" row takes, per biome
local FERTILE = {
	grug_deep_jungle = {"grug_nodes:dirt_with_canopy_litter", "default:dirt_with_rainforest_litter", "grug_nodes:mud"},
	grug_jungle_fringe = {"grug_nodes:dirt_with_canopy_litter", "default:dirt_with_rainforest_litter", "grug_nodes:mud"},
	grug_jungle_edge = {"default:dirt_with_rainforest_litter", "grug_nodes:dirt_with_canopy_litter", "grug_nodes:mud"},
	grug_elf_forest = {"grug_nodes:dirt_with_silver_litter", "grug_nodes:dirt_with_moss", "default:dirt_with_grass"},
	grug_deep_forest = {"grug_nodes:dirt_with_forest_litter", "default:dirt_with_coniferous_litter",
		"default:dirt_with_grass"},
}
local manifest = dofile(wp40 .. "/r7_r6_manifest.lua")()
local by_id, seen = {}, 0
for index, row in ipairs(manifest.decorations) do
	by_id[row.id] = row
	if index > 1 then check(manifest.decorations[index - 1].id < row.id, "the catalog is sorted at " .. row.id) end
	check(row.asset_or_node ~= "papyrus_on_dirt.mts", row.id .. " is no papyrus pedestal")
end
check(by_id.swamp_papyrus == nil, "the swamp papyrus pedestal row is gone")
check(#manifest.decorations == 99, "the catalog holds 99 rows (" .. #manifest.decorations .. ")")
-- The authority's ground-cover palette rows of one row at a biome and support.
local function weight_at(id, biome, support)
	local total
	for _, row in ipairs(density.palette("cover", biome, support)) do
		if row.id == id then total = (total or 0) + row.weight end
	end
	return total
end
local ALL_SUPPORTS = {"default:sand", "default:gravel", "default:stone", "grug_nodes:mud",
	"grug_nodes:dirt_with_canopy_litter", "default:dirt_with_rainforest_litter",
	"grug_nodes:dirt_with_silver_litter", "grug_nodes:dirt_with_moss", "default:dirt_with_grass",
	"grug_nodes:dirt_with_forest_litter", "default:dirt_with_coniferous_litter",
	"grug_nodes:mesa_clay", "default:dry_dirt_with_dry_grass", "grug_nodes:blight_dirt"}
local not_renewed = density.not_renewed()
for id, want in pairs(ROWS) do
	local row = by_id[id]
	seen = seen + 1
	if check(row ~= nil, id .. " is a row") then
		local biomes = {}
		for _, b in ipairs(row.biomes) do biomes[#biomes + 1] = b end
		table.sort(biomes)
		check(table.concat(biomes, ";") == table.concat(want[1], ";"), id .. " grows in its biomes")
		check(row.kind == want[2] and row.asset_or_node == want[3] and row.numerator == 1 and
			row.denominator == want[4] and row.rule == want[5] and row.settlement_class == want[6],
			id .. ": " .. want[2] .. " " .. want[3] .. " 1/" .. want[4] .. " " .. want[5] .. " class " .. want[6])
		if row.kind == "simple" then
			for _, biome in ipairs(row.biomes) do
				local hosts = want[7] == SOIL and set(FERTILE[biome]) or set(want[7])
				for _, support in ipairs(ALL_SUPPORTS) do
					local w = weight_at(id, biome, support)
					if hosts[support] then
						check(w ~= nil and math.abs(w - 1 / want[4]) < 1e-12,
							id .. " grows on " .. support .. " in " .. biome .. " at 1/" .. want[4])
					else
						check(w == nil, id .. " does not grow on " .. support .. " in " .. biome)
					end
				end
			end
		else
			check(type(not_renewed[id]) == "string", id .. " is a decorative bush with no sapling (" ..
				tostring(not_renewed[id]) .. ")")
		end
	end
end
local natural = density.natural_vegetation()
for _, name in ipairs({"grug_nodes:jungle_bush_leaves", "grug_nodes:withered_bush_leaves",
		"grug_trees:liana", "grug_trees:liana_strand", "grug_nodes:lichen_carpet",
		"grug_nodes:flower_ruby_fan", "default:marram_grass_1", "default:papyrus"}) do
	check(natural[name], name .. " is natural vegetation (the bushes wear their foliage)")
end

-- C. written chunks ----------------------------------------------------------------------
-- The first `n` surface chunks of the grid whose centre and four quarter
-- points are dry land of `biomes` (`shore`: land of `biomes` at the centre
-- and the sea or a lake at a quarter point, no dragon channel).
local function chunks_of(biomes, shore, n)
	local result = {}
	for z = -3200, 3120, 160 do
		for x = -3600, 3520, 160 do
			local ox, oz = R.origin(x), R.origin(z)
			local cx, cz = ox + 40, oz + 40
			if #result < n and biomes[zones.biome_at(cx, cz) or ""] and
					zones.water_class_at(cx, cz) == "land" then
				local ok, wet = true, false
				for _, p in ipairs({{20, 20}, {60, 20}, {20, 60}, {60, 60}}) do
					local px, pz = ox + p[1], oz + p[2]
					local class = zones.water_class_at(px, pz)
					if class == "land" and not biomes[zones.biome_at(px, pz) or ""] then ok = false end
					if class == "immutable_dragon_channel" or (not shore and class ~= "land") then ok = false end
					if class ~= "land" then wet = true end
				end
				if ok and (not shore or wet) then
					result[#result + 1] = {x = ox, y = R.origin(R.ground_at(cx, cz)), z = oz}
				end
			end
		end
	end
	return result
end
local CHUNKS = {}
for _, spec in ipairs({{set(J), false, 1}, {set(E), false, 1}, {set(C), false, 1}, {set(WARM), true, 3}}) do
	for _, minp in ipairs(chunks_of(spec[1], spec[2], spec[3])) do CHUNKS[#CHUNKS + 1] = minp end
end
check(#CHUNKS == 6, "six sample chunks (" .. #CHUNKS .. ")")
local column_values_at = R.authority.planner_source.column_values_at
-- the world's vegetation rule (its seed phase), for the shore and patch tests
local rule = dofile(wp40 .. "/habitat_registry.lua").vegetation_rule(R.authority.full_seed)
local WATCH = set({"default:papyrus", "default:marram_grass_1", "default:marram_grass_2",
	"default:marram_grass_3", "grug_nodes:lichen_carpet", "grug_nodes:lichen_carpet_b",
	"grug_nodes:flower_ruby_fan", "grug_nodes:flower_ember_star", "grug_nodes:flower_violet_fan",
	"grug_nodes:flower_blush_star", "grug_nodes:flower_lilac_bells", "grug_nodes:flower_cream_cups",
	"grug_nodes:alpine_cushion", "grug_nodes:alpine_windshrub", "default:fern_1", "default:fern_2",
	"default:fern_3", "grug_trees:liana"})
local ALPINE_SET = set(ALPINE)
-- placed plants (the lowest node of each): name -> list of {x, y, z, support}
local placed, stacks, liana_runs, liana_clear, bad = {}, {}, 0, 0, {}
local JUNGLE_TREE = set({"default:jungleleaves", "default:jungletree", "grug_trees:jungle_quarter",
	"grug_trees:jungle_base", "grug_trees:jungle_branch", "grug_trees:jungle_twig"})
local function judge(at, name, x, y, z, support)
	if name == "default:papyrus" then
		local h = 1
		while at(x, y + h, z) == name do h = h + 1 end
		stacks[h] = (stacks[h] or 0) + 1
		local _, _, _, _, _, ground = column_values_at(x, z)
		return support == "default:sand" and h >= 2 and h <= 4 and
			rule.water_beside(column_values_at, x, z, ground)
	elseif name:find("marram", 1, true) then
		return support == "default:sand" and rule.dry_shore(column_values_at, x, z)
	elseif name:find("lichen", 1, true) then
		return (support == "default:gravel" or support == "default:stone") and rule.rock_patch(x, z)
	elseif name == "grug_trees:liana" then
		-- the end: strands above it up to its jungle tree (trees interleave,
		-- so a neighbour's leaf or wood may take a cell of a run, and on a
		-- slope the ground may rise under its end: the template rules are E's)
		local n, top = 1, y + 1
		while at(x, top, z) == "grug_trees:liana_strand" do n, top = n + 1, top + 1 end
		liana_runs = liana_runs + 1
		if at(x, y - 1, z) == "air" and n >= 2 then liana_clear = liana_clear + 1 end
		return JUNGLE_TREE[at(x, top, z)] == true and n <= 6
	elseif name:find("alpine", 1, true) then
		return ALPINE_SET[support] == true
	elseif name:find("flower", 1, true) then
		local fertile = FERTILE[zones.biome_at(x, z) or ""]
		return fertile ~= nil and set(fertile)[support] == true
	end
	return true
end
for _, minp in ipairs(CHUNKS) do
	local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
	local vm = R.new_vm(minp)
	local plan, generation = R.built.session.plan_slice(minp, maxp)
	R.built.writer.apply(vm, minp, maxp, plan, generation)
	local data = vm.written.data or vm.native.data
	local function at(x, y, z)
		return R.fake.get_name_from_content_id(data[(z - minp.z + 16) * 12544 +
			(y - minp.y + 16) * 112 + (x - minp.x + 16) + 1])
	end
	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			for y = minp.y, maxp.y do
				local name = at(x, y, z)
				if WATCH[name] and at(x, y - 1, z) ~= name then
					local support = at(x, y - 1, z)
					placed[name] = placed[name] or {}
					local list = placed[name]
					list[#list + 1] = {x = x, y = y, z = z, support = support}
					if not judge(at, name, x, y, z, support) then
						local kind = name:match(":([a-z]+)")
						bad[kind] = (bad[kind] or 0) + 1
					end
				end
			end
		end
	end
end
local function count(name) return #(placed[name] or {}) end
for _, name in ipairs({"default:papyrus", "default:marram_grass_1", "grug_nodes:lichen_carpet",
		"grug_nodes:flower_ruby_fan", "grug_nodes:flower_blush_star", "grug_nodes:alpine_cushion",
		"default:fern_1", "grug_trees:liana"}) do
	check(count(name) > 0, name .. " stands in the sampled chunks (" .. count(name) .. ")")
end
for _, kind in ipairs({"papyrus", "marram", "lichen", "liana", "alpine", "flower", "fern"}) do
	check((bad[kind] or 0) == 0, kind .. " stands where its row says (" .. (bad[kind] or 0) .. " not)")
end
check(liana_runs > 0 and liana_clear >= 0.85 * liana_runs,
	"most world lianas hang whole and clear of the ground (" .. liana_clear .. " of " .. liana_runs .. ")")
check(next(stacks) ~= nil and (stacks[1] or 0) == 0 and (stacks[5] or 0) == 0,
	"papyrus stands in plain stacks of 2-4 (2: " .. (stacks[2] or 0) .. ", 3: " .. (stacks[3] or 0) ..
		", 4: " .. (stacks[4] or 0) .. ")")

-- D. regrowth ------------------------------------------------------------------------------
-- A fake world for renewal at one site: open supports under air all round,
-- no plant present (a full deficit), full light.
local function renewal_at(site, support)
	local state = 12345
	local api = {
		density = density,
		planner = {hard_row_at = function() return nil end},
		get_node_or_nil = function(pos)
			if pos.x == site.x and pos.z == site.z and pos.y == site.y - 1 then return {name = support} end
			return {name = "air"}
		end,
		set_node = function() end,
		get_natural_light = function() return 15 end,
		find_nodes_in_area = function(_, _, _, grouped) return grouped and {} or {} end,
		find_nodes_in_area_under_air = function(minp, maxp)
			local list = {}
			for x = minp.x, maxp.x do
				for z = minp.z, maxp.z do list[#list + 1] = {x = x, y = site.y - 1, z = z} end
			end
			return list
		end,
		get_item_group = function() return 0 end,
		natural_ground_alterable = function() return true end,
		random = function()
			state = (state * 16807) % 2147483647
			return state / 2147483647
		end,
		trees = false,
		non_natural = {},
	}
	return dofile(repo .. "/mods/ITEMS/grug_farming/renewal.lua")(api)
end
local REGROW = {
	{"default:papyrus", "beach_papyrus", 5},
	{"default:marram_grass_2", "beach_marram_2", 27},
	{"grug_nodes:lichen_carpet", "crags_lichen_a", 14},
	{"grug_nodes:lichen_carpet_b", "crags_lichen_b", 14},
	{"grug_nodes:flower_ruby_fan", "jungle_flower_ruby_fan", 300},
	{"grug_nodes:flower_ember_star", "jungle_flower_ember_star", 300},
	{"grug_nodes:flower_violet_fan", "jungle_flower_violet_fan", 300},
	{"grug_nodes:flower_blush_star", "elf_flower_blush_star", 300},
	{"grug_nodes:flower_lilac_bells", "elf_flower_lilac_bells", 300},
	{"grug_nodes:flower_cream_cups", "elf_flower_cream_cups", 300},
	{"grug_nodes:alpine_cushion", "crags_alpine_cushion", 80},
	{"grug_nodes:alpine_windshrub", "crags_alpine_windshrub", 80},
	{"default:fern_3", "jungle_fern_3", 75},
}
local far = {{x = 1e6, y = 0, z = 1e6}}
for _, spec in ipairs(REGROW) do
	local name, id, den = spec[1], spec[2], spec[3]
	-- a column where the generator placed it, of the row's own biome
	local site
	for _, p in ipairs(placed[name] or {}) do
		local biomes = set(by_id[id].biomes)
		if not site and biomes[zones.biome_at(p.x, p.z) or ""] then site = p end
	end
	-- the jungle fern also grows in other rows' biomes: any jungle one
	if check(site ~= nil, name .. ": a generated one to regrow") then
		local categories = density.categories(site.x, site.y, site.z, site.support, 15)
		local cover
		for _, category in ipairs(categories or {}) do
			if category.class == "cover" then cover = category end
		end
		local w
		for _, species in ipairs(cover and cover.species or {}) do
			if species.id == id then w = species.weight end
		end
		check(w ~= nil and math.abs(w - 1 / den) < 1e-12,
			name .. ": renewal's target holds it at its row's 1/" .. den .. " (" .. tostring(w) .. ")")
		if name == "default:papyrus" then
			check(cover and cover.shore and cover.stacked, "papyrus counts as a shore stack")
		elseif name:find("lichen", 1, true) then
			check(cover and cover.patch_area == 25, name .. " counts within its patch of 25")
		else
			check(cover and not cover.shore and not cover.patch_area and not cover.stacked,
				name .. " counts as plain ground cover")
		end
		local renewal = renewal_at(site, site.support)
		local got = false
		for _ = 1, 400 do
			local result, node = renewal.evaluate({x = site.x, y = site.y - 1, z = site.z}, far,
				{left = renewal.constants.VOLUME_BUDGET}, 0, "cover")
			if result == "placed" and node == name then got = true break end
		end
		check(got, name .. ": renewal places it on an empty box")
	end
end

-- E. the lianas of the templates -----------------------------------------------------------------
local trees = dofile(wp40 .. "/tree_templates.lua")(dofile(wp40 .. "/treegen.lua"))
local L = trees.LIANAS
local runs, cells, ok_runs = 0, 0, true
for _, key in ipairs({"jungle", "kapok"}) do
	local row = trees.BY_KEY[key]
	check(set(trees.names(key))["grug_trees:liana"] and set(trees.names(key))["grug_trees:liana_strand"],
		key .. " places the liana end and strand")
	for seed = 1, 24 do
		local cell_sets = {}
		local v = trees.variant(key, seed * 104729)
		local list = {}
		for i = 1, v.count do list[i] = {x = v.x[i], y = v.y[i], z = v.z[i], name = v.name[i]} end
		cell_sets[1] = list
		cell_sets[2] = (trees.tree(key, seed * 104729))
		for _, cellist in ipairs(cell_sets) do
			local by, wood = {}, {}
			for _, c in ipairs(cellist) do
				by[c.x .. "," .. c.y .. "," .. c.z] = c.name
				if c.name == row.trunk or c.name == row.quarter or c.name == row.base or
						c.name == row.branch or c.name == row.twig then
					wood[#wood + 1] = c
				end
			end
			for _, c in ipairs(cellist) do
				if c.name == row.liana_strand or c.name == row.liana then
					cells = cells + 1
					local near = false
					for _, w in ipairs(wood) do
						if math.abs(w.x - c.x) <= L.REACH and math.abs(w.y - c.y) <= L.REACH and
								math.abs(w.z - c.z) <= L.REACH then near = true end
					end
					if not near or c.y < L.LOWEST then ok_runs = false end
				end
				if c.name == row.liana then
					runs = runs + 1
					local n, top = 1, c.y + 1
					while by[c.x .. "," .. top .. "," .. c.z] == row.liana_strand do n, top = n + 1, top + 1 end
					if by[c.x .. "," .. top .. "," .. c.z] ~= row.leaves or n < L.SHORTEST or n > L.LONGEST or
							by[c.x .. "," .. (c.y - 1) .. "," .. c.z] ~= nil then
						ok_runs = false
					end
				elseif c.name == row.liana_strand then
					local below = by[c.x .. "," .. (c.y - 1) .. "," .. c.z]
					if below ~= row.liana_strand and below ~= row.liana then ok_runs = false end
				end
			end
		end
	end
end
check(ok_runs, "every liana is strands above one end, 2-6 long, under leaves, clear of the ground, near wood")
check(runs > 0, "jungle and kapok hang lianas (" .. runs .. " runs, " .. cells .. " cells)")
for _, row in ipairs(trees.SPECIES) do
	if row.key ~= "jungle" and row.key ~= "kapok" then
		check(not set(trees.names(row.key))["grug_trees:liana"], row.key .. " hangs no liana")
	end
end

-- F. the closed node roster ---------------------------------------------------------------------------
local content = read(wp40 .. "/r7_content.lua")
local roster = content:match("local ACCEPTED_R6_ROWS = (%b{})")
local total, mask = 0, {}
for name, m in roster:gmatch('{"([^"]+)", (%d+)}') do
	total = total + 1
	mask[name] = tonumber(m)
end
check(total == 173 and content:find("#ACCEPTED_R6_ROWS ~= 173", 1, true) ~= nil,
	"the roster holds 173 rows and checks that count (" .. total .. ")")
for _, name in ipairs({"default:marram_grass_1", "default:marram_grass_2", "default:marram_grass_3",
		"grug_nodes:alpine_cushion", "grug_nodes:alpine_windshrub", "grug_nodes:flower_blush_star",
		"grug_nodes:flower_cream_cups", "grug_nodes:flower_ember_star", "grug_nodes:flower_lilac_bells",
		"grug_nodes:flower_ruby_fan", "grug_nodes:flower_violet_fan", "grug_nodes:jungle_bush_leaves",
		"grug_nodes:lichen_carpet", "grug_nodes:lichen_carpet_b", "grug_nodes:withered_bush_leaves",
		"grug_trees:liana", "grug_trees:liana_strand"}) do
	check(mask[name] == 8, name .. " is a decoration row of the roster")
end

if failures > 0 then
	error(("%d FAILURES of %d checks"):format(failures, checks))
end
local parts = {}
for _, name in ipairs({"default:papyrus", "default:marram_grass_1", "grug_nodes:lichen_carpet",
		"grug_nodes:flower_ruby_fan", "grug_nodes:alpine_cushion", "grug_trees:liana"}) do
	parts[#parts + 1] = name:match(":(.+)$") .. " " .. count(name)
end
print(("PASS r51_lp: %d checks; sampled chunks: %s; papyrus stacks 2/3/4: %d/%d/%d; " ..
	"world lianas whole %d of %d; template lianas: %d runs"):format(checks, table.concat(parts, ", "),
	stacks[2] or 0, stacks[3] or 0, stacks[4] or 0, liana_clear, liana_runs, runs))
