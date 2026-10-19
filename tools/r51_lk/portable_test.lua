-- Round 51 lane LK portable test (the land kit; round51-plan.md §1 LK, land
-- plan rulings 7-9 and 12-14):
--   A. every prop node against its prop.json (tools/r51_land/props): node
--      boxes (v / 16), tiles in the format's order, alpha clip, facedir,
--      the drop; nothing in the creative inventory; the bone pile is the
--      scattered long bones (ruling 9) and drops nothing; the stone cairn
--      shapes (ruling 13, variant B) drop cobblestone;
--   B. every block the kit places drops a default block or nothing (a bone
--      piece), ruling 7;
--   C. the kit rows of r7_r6_manifest.lua: host, biomes and density are the
--      land viewer's (tools/r47_sw/land.js ITEMS, `den`), and no bone pile
--      row is left;
--   D. the kit's variants: bounded (the generated-template box), every run
--      filled, the first run required and on the root, the same bytes for
--      the same seed, other variants for another world, and the bone finds
--      all different pictures;
--   E. the closed node roster: 156 rows, every kit node with the decoration
--      role;
--   F. the town side: the bone pile's uses draw from the skeleton set
--      (dressing.bone_piece, the decor kit's lair pieces, the undead
--      undergrowth) and every graveyard caller's composition (Stillgrave,
--      Nhal Veyr, Kezamba, Highcourt, Gor Drazhak, and the graves of Dur
--      Brannoc and Lethariel) builds with the gravestone blocks;
--   G. the world: one seed's real runtime writes kit chunks (undead, dwarf,
--      orc, elves, jungle, beach) and no kit cell floats: each stands on ground,
--      on another cell of its structure, or lies sunk in the ground.
--
-- Usage (repo root): luajit tools/r51_lk/portable_test.lua [REPO]
local repo = arg[1] or "."
local checks, failed = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failed = failed + 1
		print("FAIL " .. label)
	end
end

local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local json = dofile(repo .. "/tools/r28_b4_quests/json.lua")
local function read(path)
	local handle = assert(io.open(path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

-- The real node registrations (default, grug_trees, grug_materials,
-- grug_nodes) under the mining harness.
_G.R24_MINING_HARNESS = true
local H = dofile(repo .. "/tools/r24_mining/fixture.lua")
_G.R24_MINING_HARNESS = nil
local nodes = H.nodes

-- A. props ---------------------------------------------------------------
local PROPS = repo .. "/tools/r51_land/props"
-- (the props of gen_props.py's data; every one must have its prop.json)
local prop_list = {}
for _, row in ipairs(dofile(repo .. "/mods/ITEMS/grug_nodes/props_data.lua")) do
	prop_list[#prop_list + 1] = row.prop
end
check(#prop_list == 19, "nineteen props")
local FACES = {"top", "bottom", "right", "left", "back", "front"}
for _, prop in ipairs(prop_list) do
	local spec = json.decode(read(PROPS .. "/" .. prop .. "/prop.json"))
	local node = prop == "bones_scattered" and "bone_pile" or
		(prop == "gravestone_slab" and "gravestone_stele" or prop)
	local def = nodes["grug_nodes:" .. node]
	check(def ~= nil, prop .. " is registered")
	if def then
		check(def.drawtype == "nodebox" and def.node_box.type == "fixed", prop .. " is a node box")
		local fixed = def.node_box.fixed
		check(#fixed == #spec.boxes, prop .. " has every box")
		for index, box in ipairs(spec.boxes) do
			for k = 1, 6 do
				check(fixed[index] and fixed[index][k] == box[k] / 16,
					prop .. " box " .. index .. " value " .. k)
			end
		end
		check(#def.tiles == 6, prop .. " has six tiles")
		for index = 1, 6 do
			check(spec.tiles[index] == prop .. "_" .. FACES[index] .. ".png" and
				def.tiles[index] == "grug_nodes_" .. node .. "_" .. FACES[index] .. ".png",
				prop .. " tile " .. index .. " in the format's order")
			local copy = read(repo .. "/mods/ITEMS/grug_nodes/textures/" .. def.tiles[index])
			check(copy == read(PROPS .. "/" .. prop .. "/" .. spec.tiles[index]),
				prop .. " tile " .. index .. " is ARTL's file")
		end
		check(def.use_texture_alpha == (spec.alpha == "clip" and "clip" or "opaque"),
			prop .. " alpha")
		check((spec.rotate ~= false) == (def.paramtype2 == "facedir"), prop .. " facedir")
		check(def.drop == spec.drop, prop .. " drops " .. tostring(spec.drop))
		check(def.groups.not_in_creative_inventory == 1, prop .. " is not in creative")
	end
end
local bone_pile = nodes["grug_nodes:bone_pile"]
check(bone_pile.drawtype == "nodebox" and bone_pile.drop == "" and
	bone_pile.tiles[1] == "grug_nodes_bone_pile_top.png" and bone_pile.walkable == false,
	"the bone pile is the scattered long bones and drops nothing")
for _, shape in ipairs({"base", "branch", "twig"}) do
	local def = nodes["grug_nodes:cairn_" .. shape]
	check(def and def.node_box.type == "connected" and def.drop == "default:cobble" and
		def.tiles[1] == "default_stone.png", "cairn " .. shape .. " is stone and drops cobble")
end

-- B, D. the kit's variants --------------------------------------------------
local treegen = dofile(wp40 .. "/treegen.lua")
local trees = dofile(wp40 .. "/tree_templates.lua")(treegen)
local kit = dofile(wp40 .. "/kit_templates.lua")(treegen, trees)
local DEFAULT_DROP = {["default:cobble"] = true, ["default:stone"] = true,
	["default:silver_sandstone"] = true, ["default:wood"] = true, ["default:stick"] = true}
local kit_names = {}
for _, species in ipairs(kit.SPECIES) do
	for _, name in ipairs(kit.names(species.key)) do kit_names[name] = true end
end
for name in pairs(kit_names) do
	local def = nodes[name]
	check(def ~= nil, name .. " is registered")
	if def and name:match("^grug_nodes:") and name ~= "grug_nodes:moss_carpet" then
		-- a bone piece or the moss carpet: walked through, drops nothing
		local flat = def.walkable == false
		check(flat and def.drop == "" or DEFAULT_DROP[def.drop] == true,
			name .. " drops a default block (bones nothing)")
	elseif def and name:match("^grug_trees:") then
		check(def.drop == nil or tostring(def.drop):match("tree$") ~= nil, name .. " drops its log")
	elseif def and name ~= "grug_nodes:moss_carpet" then
		check(name:match("^default:") ~= nil, name .. " is a default block")
	end
end
for _, species in ipairs(kit.SPECIES) do
	local seen_bytes = {}
	for seed = 1, species.count do
		local v = kit.variant(species.key, seed * 7919)
		local ok = true
		for index = 1, v.count do
			if math.abs(v.x[index]) > 8 or math.abs(v.z[index]) > 8 or v.y[index] < -1 or
					v.y[index] > 63 then ok = false end
		end
		for index = 1, v.root_count do
			if math.abs(v.rx[index]) > 8 or math.abs(v.rz[index]) > 8 or v.ry[index] < -1 or
					v.ry[index] > 63 then ok = false end
		end
		check(ok, species.key .. " variant within the template box")
		for _, run in ipairs(v.runs) do
			check(run.last >= run.first and run.parent < #v.runs + 1, species.key .. " run filled")
		end
		if species.key ~= "dead_pine" then
			local first, on_root = v.runs[1], false
			for index = first and first.first or 1, first and first.last or 0 do
				if v.rx[index] == 0 and v.rz[index] == 0 then on_root = true end
			end
			check(first and first.required and on_root,
				species.key .. " starts with a required run on the root")
		else
			check(v.count > 0, "a dead pine has its tree")
			for index = 1, v.count do
				check(v.name[index] ~= "default:pine_needles", "a dead pine has no needles")
			end
		end
		check(kit.variant(species.key, seed * 7919).bytes == v.bytes,
			species.key .. " is deterministic")
		seen_bytes[v.bytes] = true
	end
	local distinct = 0
	for _ in pairs(seen_bytes) do distinct = distinct + 1 end
	if species.key == "bones" or species.key == "graveyard" then
		check(distinct >= species.count * 3 / 4, species.key .. " variants differ (" .. distinct .. ")")
	end
end

-- C. the kit rows ---------------------------------------------------------
local manifest = dofile(wp40 .. "/r7_r6_manifest.lua")()
local rows = {}
for _, row in ipairs(manifest.decorations) do
	rows[row.id] = row
	check(row.asset_or_node ~= "grug_nodes:bone_pile", "no bone pile row is left: " .. row.id)
end
local land = read(repo .. "/tools/r47_sw/land.js")
local function viewer_den(key)
	local line = land:match("{key: '" .. key:gsub("%.", "%%.") .. "'[^\n]*")
	return tonumber(line and line:match("den: (%d+)"))
end
local U = "grug_blight;grug_bone_forest"
local D = "grug_crags;grug_crags_snowy;grug_pine_hills"
local E = "grug_elf_forest;grug_deep_forest"
-- (the driftwood: the viewer's 1/120 counts the sand columns near the
-- water, about a third of the beach; the row's 1/360 counts every beach
-- column, `scale` 3)
local KIT_ROWS = {
	kit_beach_driftwood = {"beach.driftwood", "grug_beach", "driftwood", "default:sand", 3},
	kit_dwarf_boulder = {"dwarf.boulder", D, "boulder", "default:gravel"},
	kit_dwarf_cairn_blocks = {"dwarf.cairn.blocks", D, "cairn_blocks", "default:gravel"},
	kit_dwarf_cairn_branches = {"dwarf.cairn.branches", D, "cairn_branches", "default:gravel"},
	kit_dwarf_dead_pine = {"dwarf.dead_pine", "grug_crags_snowy", "dead_pine", "default:snowblock"},
	kit_elves_log = {"elves.log", E, "silver_log", "grug_nodes:dirt_with_silver_litter"},
	kit_elves_ruin = {"elves.ruin", E, "ruin_elves", "grug_nodes:dirt_with_silver_litter"},
	kit_elves_statue = {"elves.statue", E, "statue_elves", "grug_nodes:dirt_with_silver_litter"},
	kit_jungle_log = {"jungle.log", "grug_deep_jungle;grug_jungle_fringe;grug_jungle_edge",
		"kapok_log", "grug_nodes:dirt_with_canopy_litter"},
	kit_orc_bones = {"orc.bones", "grug_badlands;grug_badlands_east", "bones", "grug_nodes:mesa_clay"},
	kit_undead_bones = {"undead.bones", U, "bones"},
	kit_undead_crypt = {"undead.crypt", U, "crypt"},
	kit_undead_grave_mound = {"undead.grave_mound", U, "grave_mound"},
	kit_undead_graveyard = {"undead.graveyard", U, "graveyard"},
	kit_undead_log = {"undead.log", U, "gravewood_log"},
	kit_undead_obelisk = {"undead.obelisk", U, "obelisk"},
	kit_undead_ruin = {"undead.ruin", U, "ruin_undead"},
	kit_undead_ruin_arch = {"undead.ruin.arch", U, "ruin_arch"},
	kit_undead_ruin_column = {"undead.ruin.column", U, "ruin_column"},
	kit_undead_ruin_corner = {"undead.ruin.corner", U, "ruin_corner"},
	kit_undead_statue = {"undead.statue", U, "statue_undead"},
	kit_undead_stump = {"undead.stump", U, "gravewood_stump"},
}
local kit_rows = 0
for _, row in ipairs(manifest.decorations) do
	if row.id:match("^kit_") then kit_rows = kit_rows + 1 end
end
check(kit_rows == 22, "22 kit rows")
for id, want in pairs(KIT_ROWS) do
	local row = rows[id]
	check(row ~= nil, id .. " exists")
	if row then
		check(table.concat(row.biomes, ";") == want[2], id .. " biomes")
		check(row.kind == "template" and row.asset_or_node == "kitgen:" .. want[3], id .. " asset")
		check(row.host == (want[4] or "grug_nodes:blight_dirt"), id .. " host")
		local den = viewer_den(want[1])
		check(den ~= nil and row.numerator == 1 and row.denominator == den * (want[5] or 1),
			id .. " density 1/" .. tostring(den) .. " as the viewer's " .. want[1])
		check(row.settlement_class == nil and kit.BY_KEY[want[3]] ~= nil, id .. " computes its class")
	end
end

-- E. the closed roster ----------------------------------------------------
local roster_source = read(wp40 .. "/r7_content.lua")
local roster = {}
local roster_count = 0
for name, mask in roster_source:match("local ACCEPTED_R6_ROWS = (%b{})"):gmatch('{"([^"]+)", (%d+)}') do
	roster[name] = tonumber(mask)
	roster_count = roster_count + 1
end
check(roster_count == 156, "156 production rows")
for name in pairs(kit_names) do
	local mask = roster[name]
	check(mask ~= nil and math.floor(mask / 8) % 2 == 1, name .. " has the decoration role")
end

-- F. the town side ----------------------------------------------------------
_G.core = _G.core or {}
local dressing = dofile(wp13 .. "/dressing.lua")(wp13)
local palettes = dofile(wp13 .. "/palette.lua")
local SET = {["grug_nodes:bone_pile"] = true, ["grug_nodes:bones_fragments"] = true,
	["grug_nodes:skull_human"] = true, ["grug_nodes:skull_horned"] = true,
	["grug_nodes:ribcage_human"] = true, ["grug_nodes:spine_animal"] = true}
local pieces, turns = {}, {}
for x = -40, 40 do
	for z = -40, 40 do
		local name, turn = dressing.bone_piece(x, z)
		check(SET[name] == true and turn >= 0 and turn <= 3, "a bone piece of the set")
		pieces[name] = (pieces[name] or 0) + 1
		turns[turn] = true
	end
end
local kinds = 0
for _ in pairs(pieces) do kinds = kinds + 1 end
check(kinds == 6 and turns[0] and turns[3], "the set's six pieces, turned")
check(pieces["grug_nodes:bone_pile"] > (81 * 81) / 2, "mostly the scattered bones")
check(palettes.new("undead").node("undergrowth") == "grug_nodes:bone_pile",
	"the undead undergrowth is the bone pile, drawn from the set")
local decor_source = read(wp13 .. "/decor_kit.lua")
check(not decor_source:find("put%([^\n]*N%.bones"), "the decor kit's lairs draw from the set")
check(read(wp40 .. "/vegetation_density.lua"):find('"grug_nodes:bone_pile"', 1, true) == nil,
	"vegetation density keeps no bone pile row")
-- A buffer stand-in: graves and a graveyard on open ground.
local function buffer()
	local cells = {}
	local buf = {cells = cells}
	function buf:put(x, y, z, name, param2) cells[x .. "," .. y .. "," .. z] = {name = name, param2 = param2} end
	function buf:at(x, y, z) return cells[x .. "," .. y .. "," .. z] end
	return buf
end
local undead = palettes.new("undead")
local buf = buffer()
for x = -6, 6 do for z = -6, 6 do buf:put(x, 0, z, "grug_nodes:blight_dirt") end end
local set = dressing.graveyard(buf, undead, -6, -6, 6, 6)
local stones, crosses = 0, 0
for _, c in pairs(buf.cells) do
	if c.name == "grug_nodes:gravestone_stele" then stones = stones + 1 end
	if c.name == "grug_nodes:gravestone_cross" then crosses = crosses + 1 end
	check(c.name ~= undead.node("low_wall"), "no low wall marks a grave")
end
check(set > 0 and stones == set and crosses > 0 and crosses < stones,
	"a graveyard: a gravestone per grave, the older crowned with the cross")
-- Every graveyard caller's composition.
local function count_graves(bp)
	local n = 0
	for _, c in ipairs(bp.cells or {}) do
		if c.name == "grug_nodes:gravestone_stele" then n = n + 1 end
	end
	return n
end
local stillgrave = dofile(wp40 .. "/r7_stillgrave_blueprint.lua")
if type(stillgrave) == "function" then stillgrave = stillgrave() end
check(count_graves(stillgrave) > 0, "Stillgrave's graves are gravestones")
local capital = dofile(wp40 .. "/r7_capital_blueprint.lua")
for _, key in ipairs({"nhal_veyr", "kezamba", "highcourt", "gor_drazhak", "dur_brannoc",
		"lethariel"}) do
	local k = capital.kit(key)
	local n = count_graves(k.core.build())
	for _, plot in ipairs(k.plots) do n = n + count_graves(plot.build()) end
	check(n > 0, key .. "'s graves are gravestones (" .. n .. ")")
end

-- G. the world --------------------------------------------------------------
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, "12345")
local zones = R.built.zones_session
local KIT_BIOMES = {grug_blight = true, grug_bone_forest = true, grug_crags = true,
	grug_crags_snowy = true, grug_pine_hills = true, grug_badlands = true,
	grug_elf_forest = true, grug_deep_jungle = true, grug_beach = true}
local chunks, seen, per = {}, {}, {}
for z = -3300, 3300, 96 do
	for x = -3700, 3700, 96 do
		local biome = zones.biome_at(x, z)
		if biome and KIT_BIOMES[biome] and (per[biome] or 0) < 2 and
				zones.water_class_at(x, z) == "land" and R.ground_at(x, z) > 3 then
			local minp = {x = R.origin(x), y = R.origin(R.ground_at(x, z)), z = R.origin(z)}
			local key = minp.x .. "," .. minp.y .. "," .. minp.z
			if not seen[key] then
				seen[key], per[biome] = true, (per[biome] or 0) + 1
				chunks[#chunks + 1] = minp
			end
		end
	end
end
local cid_kit, air = {}, R.fake.CONTENT_AIR
for name in pairs(kit_names) do
	if name:match("^grug_nodes:") then cid_kit[R.fake.get_content_id(name)] = name end
end
local placed, floating = 0, 0
for _, minp in ipairs(chunks) do
	local vm = R.new_vm(minp)
	local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
	local plan, generation = R.built.session.plan_slice(minp, maxp)
	R.built.writer.apply(vm, minp, maxp, plan, generation)
	local data = vm.written.data
	for z = 16, 95 do
		for y = 17, 95 do
			for x = 16, 95 do
				local cid = data[z * 12544 + y * 112 + x + 1]
				if cid_kit[cid] then
					placed = placed + 1
					local below = data[z * 12544 + (y - 1) * 112 + x + 1]
					if below == air then floating = floating + 1 end
				end
			end
		end
	end
end
local m = R.built.session.metrics().settlement.templates or {}
local accepted = 0
for id, t in pairs(m) do if id:match("^kit_") then accepted = accepted + t.accepted end end
print(("world: %d chunks, %d kit structures, %d prop cells, %d floating"):format(#chunks,
	accepted, placed, floating))
check(accepted > 20 and placed > 20, "the kit stands in the world")
check(floating == 0, "no kit cell floats")

if failed > 0 then error(("R51 LK FIXTURE FAIL %d of %d checks"):format(failed, checks), 0) end
print("R51 LK FIXTURE PASS checks=" .. checks)
