-- Loaded as the disposable WP40 profiler's cases.lua, never shipped in-game.
--
-- Covers EVERY WP13 start in the R7 settlement roster: the profiler emerges
-- each settlement's owners, and on shutdown every authored cell of every
-- settlement is compared against the map, name and param2, in both owner
-- orders and after a disk-only reload.
local reverse = true -- The WP13 runner changes only this switch in its copy.
local wp40 = core.get_modpath("grug_mapgen") .. "/wp40"
-- The STARTS of the settlement roster. This corpus is the six-start digest
-- gate, so it is deliberately bounded to the rows whose slot is "start": a
-- capital owns several blueprints of three kinds, two of which have no cells at
-- all until a height query answers, and pulling it in here would change the
-- digests this file exists to keep. The capital's own engine pass is
-- `tools/wp13/run_highcourt.sh`.
local roster = {}
for index = 1, #dofile(wp40 .. "/r7_settlement.lua").roster do
	local profile = dofile(wp40 .. "/r7_settlement.lua").roster[index]
	if profile.slot == "start" then roster[#roster + 1] = profile end
end
assert(#roster >= 2, "the WP13 settlement roster lost a start")

local starts = {}
for index = 1, #roster do
	local profile = roster[index]
	local blueprint = dofile(wp40 .. "/" .. profile.blueprint_file)()
	local anchor = assert(grug_zones.anchor(profile.zone_id, profile.slot))
	assert(anchor.id == profile.anchor_id and anchor.x == profile.x and
		anchor.z == profile.z, "WP13 start anchor moved")
	starts[index] = {key = profile.key, blueprint = blueprint, anchor = anchor}
end

local function origin(value) return math.floor((value + 32) / 80) * 80 - 32 end
local owners, seen = {}, {}
local function add(x, y, z)
	local ox, oy, oz = origin(x), origin(y), origin(z)
	local key = ox .. ":" .. oy .. ":" .. oz
	if seen[key] then return end
	seen[key] = true
	owners[#owners + 1] = {id = "owner_" .. key, x = ox + 40, y = oy + 40, z = oz + 40}
end
for _, start in ipairs(starts) do
	for _, cell in ipairs(start.blueprint.cells) do
		add(start.anchor.x + cell.x, start.anchor.y + cell.y,
			start.anchor.z + cell.z)
	end
end
-- The corpus is bounded by the roster and the authorized volume, not by the
-- seed. A start is 127 nodes wide and deep, and an 80-node owner grid cuts a
-- 127-node span into at most ceil((127 + 79) / 80) = 3 columns whatever the
-- anchor's offset is; the authorized y range is 27 nodes, which is at most 2
-- levels: 3 x 3 x 2 = eighteen per roster row is the structural ceiling.
--
-- The bound before this one was a flat sixteen, derived as "two starts, two
-- owners per horizontal axis and two vertically". Two per axis is wrong for
-- a 127-node span on an 80-node grid however the anchor falls; it held for
-- the first two starts by accident of their offsets and refused the corpus
-- the moment the third start fitted across an owner floor.
assert(#owners <= 18 * #roster, "profile corpus exceeds the bounded structure owners")
-- This seed puts the Stillgrave start's fitted surface at y=48, just above
-- the generated owner's ceiling, which is why the lower owner is named here:
-- it exercises filler restoration when the matching top opcode belongs to a
-- different owner. Since the fourth increment the Stillgrave settlement is
-- itself in the roster, so that owner is already in the list and the call is
-- a statement of intent rather than an addition; the node witness below is
-- the settlement's own subsoil course, which is `default:dirt` exactly as the
-- biome filler is. Filler painting OUTSIDE any blueprint is proved separately
-- by the three apron soil witnesses in the shutdown handler.
local filler_boundary = core.settings:get("grug_wp40_profile_seed") == "8675309"
if filler_boundary then add(-1863, 47, 2528) end
-- Adjacent non-structure owners as controls: they must receive no authored
-- byte at all, which the per-cell comparison below proves from the other
-- side. TWO of them, added unconditionally.
--
-- The first version padded the owner list up to a threshold -- fourteen, then
-- seven per start -- and by the time the roster reached six starts the
-- structure owners already exceeded any such threshold, so the loop ran zero
-- times and the corpus carried no controls at all while still claiming to. A
-- control is not padding: it is a named part of the corpus, so it is added
-- outright and counted in the bound.
local CONTROLS = 2
for index = 1, CONTROLS do
	add(starts[1].anchor.x + index * 80, starts[1].anchor.y - 80,
		starts[1].anchor.z)
end
-- The filler-boundary seed names one more owner above, which is already in
-- the list on every seed since the fourth increment but is counted here so
-- the bound holds even if it ever is not.
assert(#owners <= 18 * #roster + 1 + CONTROLS,
	"WP13 control population is unbounded")
table.sort(owners, function(a, b) return a.id < b.id end)
if reverse then
	local reordered = {}
	for index = #owners, 1, -1 do reordered[#reordered + 1] = owners[index] end
	owners = reordered
end

core.register_on_shutdown(function()
	local phase = core.settings:get("grug_wp40_profile_phase")
	-- Check the shared authoritative apron, including its half-open edges
	-- and deep contested override. These queries do not emerge other starts.
	for _, sx in ipairs({-1800, 0, 1800}) do
		for _, sz in ipairs({-2550, 2550}) do
			for _, edge in ipairs({-74, 73}) do
				local pos = {x = sx + edge, y = -700, z = sz + edge}
				assert(grug_zones.territory_rule_at(pos) == "hard_protected",
					"WP13 protected apron missing")
				pos.y = -701
				assert(grug_zones.territory_rule_at(pos) == "contested_land",
					"WP13 deep override missing")
			end
			for _, edge in ipairs({-75, 74}) do
				assert(grug_zones.territory_rule_at({x = sx + edge, y = 0,
					z = sz + edge}) ~= "hard_protected", "WP13 apron too wide")
			end
		end
	end
	if filler_boundary then
		assert(grug_zones.terrain_height_at(-1863, 2528) == 48,
			"WP13 vertical boundary witness moved")
		assert(core.get_node({x = -1863, y = 47, z = 2528}).name == "default:dirt",
			"WP13 filler-only owner retained stone instead of biome soil")
	end

	local fields, combined = {}, {}
	for _, start in ipairs(starts) do
		local anchor, blueprint = start.anchor, start.blueprint
		-- These witnesses are outside authored blueprint cells but inside the
		-- generated owners: the fitted apron must receive actual biome ground.
		local soil_witnesses = 0
		for _, offset in ipairs({{-70, 0}, {-70, -40}, {40, -70}}) do
			local x, z = anchor.x + offset[1], anchor.z + offset[2]
			local y = grug_zones.terrain_height_at(x, z)
			local name = core.get_node({x = x, y = y, z = z}).name
			assert(name ~= "ignore", "WP13 apron witness is not generated")
			if core.get_item_group(name, "soil") > 0 then
				soil_witnesses = soil_witnesses + 1
			end
		end
		assert(soil_witnesses > 0, "WP13 apron remained entirely unpainted stone")

		-- Round B: the blend ring outside the protected footprint carries biome
		-- decorations again, while the pad and its ten-node apron stay clear. Only
		-- columns this corpus actually emerged are counted -- the ring reaches
		-- past the owners the roster names -- so `sampled` is reported beside
		-- `cover` and an `ignore` column is neither.
		local apron_sampled, apron_cover, ring_sampled, ring_cover = 0, 0, 0, 0
		local wild_sampled, wild_cover = 0, 0
		for dz = -190, 190, 3 do
			for dx = -190, 190, 3 do
				local chebyshev = math.max(math.abs(dx), math.abs(dz))
				if chebyshev >= 64 then
					local x, z = anchor.x + dx, anchor.z + dz
					local y = grug_zones.terrain_height_at(x, z)
					local name = core.get_node({x = x, y = y + 1, z = z}).name
					local definition = core.registered_nodes[name]
					local cover = name ~= "air" and name ~= "ignore" and
						definition ~= nil and definition.liquidtype == "none"
					if name ~= "ignore" then
						if chebyshev <= 73 then
							apron_sampled = apron_sampled + 1
							if cover then apron_cover = apron_cover + 1 end
						elseif chebyshev <= 127 then
							ring_sampled = ring_sampled + 1
							if cover then ring_cover = ring_cover + 1 end
						else
							-- Outside the blend envelope: untouched biome, the reference
							-- the ring's own cover is compared against.
							wild_sampled = wild_sampled + 1
							if cover then wild_cover = wild_cover + 1 end
						end
					end
				end
			end
		end

		-- The persistence canary is one deliberate server-side edit, made at
		-- the first start only and excluded from that start's digest.
		local canary = (start.key == starts[1].key)
		-- Which node names are this start's lights is a palette question --
		-- the timber starts burn torches, the Hollow burns candles, the Glade
		-- hangs lanterns -- so the census is taken from the blueprint's own
		-- light landmarks instead of from hard-coded torch names, which
		-- `tools/wp13/blueprint_kat.lua` proves equal to the set of light
		-- cells in the cell list.
		local light_at = {}
		for _, pos in ipairs(blueprint.landmarks.lights) do
			light_at[pos.x .. ":" .. pos.y .. ":" .. pos.z] = true
		end
		local parts, torch_count, lit = {}, 0, 0
		local edited_cell_seen = false
		for _, cell in ipairs(blueprint.cells) do
			local pos = {x = anchor.x + cell.x, y = anchor.y + cell.y,
				z = anchor.z + cell.z}
			local node = core.get_node(pos)
			local edited = canary and cell.x == 5 and cell.y == 2 and cell.z == 0
			local expected = edited and phase == "disk" and "default:glass" or
				cell.name
			if edited then
				assert(cell.name == "air" and cell.param2 == 0)
				edited_cell_seen = true
			end
			assert(node.name == expected, "WP13 node differs " ..
				core.pos_to_string(pos) .. ": " .. node.name .. " expected " ..
				cell.name)
			assert(node.param2 == cell.param2,
				"WP13 param2 differs " .. core.pos_to_string(pos))
			-- Compare unedited structure bytes across orders/reloads; the one
			-- deliberate edit is independently checked above instead of hidden
			-- in this digest.
			if not edited then
				parts[#parts + 1] = table.concat({cell.x, cell.y, cell.z,
					node.name, node.param2}, ":")
			end
			if light_at[cell.x .. ":" .. cell.y .. ":" .. cell.z] then
				torch_count = torch_count + 1
				if (core.get_node_light(pos, 0) or 0) > 0 then lit = lit + 1 end
			end
		end
		assert(not canary or edited_cell_seen,
			"persistence canary outside authored cells")
		assert(torch_count >= 8 and lit == torch_count, "WP13 night lighting differs")
		for _, pos in ipairs(blueprint.landmarks.destinations) do
			local feet = {x = anchor.x + pos.x, y = anchor.y + pos.y,
				z = anchor.z + pos.z}
			assert((core.get_node_light(feet, 0) or 0) > 0,
				"WP13 dark interior " .. start.key .. "/" .. pos.id)
			for y = pos.y, pos.y + 1 do
				local name = core.get_node({x = anchor.x + pos.x,
					y = anchor.y + y, z = anchor.z + pos.z}).name
				assert(core.registered_nodes[name].walkable == false,
					"WP13 blocked interior " .. start.key .. "/" .. pos.id)
			end
		end
		-- The lit five-wide route. Its extent, and with it its direction, is
		-- the blueprint's own `main_street` landmark: the Elandor starts
		-- leave their pad toward +z, the Kragmar starts toward -z.
		local street = assert(blueprint.landmarks.main_street,
			"WP13 start has no main street landmark")
		for z = street.min.z, street.max.z do
			for x = street.min.x, street.max.x do
				local foot = {x = anchor.x + x, y = anchor.y + 1, z = anchor.z + z}
				assert((core.get_node_light(foot, 0) or 0) > 0,
					"WP13 dark main route " .. start.key .. " at " .. x .. "," .. z)
				assert(core.registered_nodes[core.get_node(foot).name].walkable
					== false)
				foot.y = foot.y + 1
				assert(core.registered_nodes[core.get_node(foot).name].walkable
					== false)
			end
		end
		local digest = core.sha256(table.concat(parts, "\n"), false)
		fields[#fields + 1] = start.key .. "_cells=" .. #blueprint.cells
		fields[#fields + 1] = start.key .. "_torches=" .. lit
		fields[#fields + 1] = start.key .. "_soil=" .. soil_witnesses
		fields[#fields + 1] = start.key .. "_apron=" .. apron_cover .. "/" ..
			apron_sampled
		fields[#fields + 1] = start.key .. "_ring=" .. ring_cover .. "/" ..
			ring_sampled
		fields[#fields + 1] = start.key .. "_wild=" .. wild_cover .. "/" ..
			wild_sampled
		fields[#fields + 1] = start.key .. "_anchor=" .. anchor.x .. "," ..
			anchor.y .. "," .. anchor.z
		fields[#fields + 1] = start.key .. "_digest=" .. digest
		combined[#combined + 1] = start.key .. ":" .. digest
	end

	if phase == "cold" then
		-- Simulate an authorized server-side edit after the profiler's
		-- snapshots. This disposable test coordinate is not one of its
		-- sampled positions.
		core.set_node({x = starts[1].anchor.x + 5, y = starts[1].anchor.y + 2,
			z = starts[1].anchor.z}, {name = "default:glass", param2 = 0})
	end
	core.log("action", "GRUG_WP13_ENGINE phase=" .. phase ..
		" starts=" .. #starts .. " owners=" .. #owners ..
		" edit_canary=" .. (phase == "cold" and "placed" or "preserved") ..
		" digest_excluded_cells=1" ..
		" filler_boundary=" .. tostring(filler_boundary) ..
		" " .. table.concat(fields, " ") ..
		" digest=" .. core.sha256(table.concat(combined, "\n"), false))
end)
return owners
