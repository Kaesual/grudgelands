-- Exercise actual palette support and planner eligibility, including mixed soils.
return function(repo, expanded)
	local _, content = dofile(repo .. "/tools/wp40/quality/surface_fixture.lua")(repo)
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40/"
	-- Bounded deterministic digest provider: this tests caller ordering and
	-- thinning, not SHA-256. Production framing/budget arithmetic remain real.
	local function raw(bytes)
		local value = 71
		for i = 1, #bytes do value = (value * 131 + bytes:byte(i)) % 65521 end
		local out = {}
		for i = 1, 32 do
			value = (value * 48271) % 16777213
			out[i] = string.char(value % 256)
		end
		return table.concat(out)
	end
	local hash = dofile(wp40 .. "r6_hash.lua")(raw)
	local decorations = content.decorations()
	local checks, fertile, gravel = 0, 0, 0
	local forbidden = {"default:stone", "default:water_source", "air"}
	local biome = "grug_pine_hills"
	local function columns()
		return "land", 1, "fixture", biome, "dwarf", 30
	end
	local source = {schema = "grug_wp40_r5_planner_source_v1",
		column_values_at = columns, surface_cave_run_at = function() return nil end,
		surface_cave_candidate_at_cell = function() return nil end,
		coast_profile_at = function() return nil end,
		coast_material_at = function() return nil end,
		primary_relief_at = function() return nil end,
		landmark_excluded_at = function() return false end}
	local select_surface = content.new_surface_selector("cover-fixture", source)
	for _, base in ipairs(content.surfaces()) do
		biome = base.id
		for _, row in ipairs(decorations) do
			local allowed = false
			for _, id in ipairs(row.biomes) do if id == biome then allowed = true end end
			for _, name in ipairs(forbidden) do
				assert(content.decoration_cover(row.id, biome, content.content_ref(name)) == 0)
				checks = checks + 1
			end
			for z = -64, 64, 8 do
				for x = -64, 64, 8 do
					local surface = select_surface(biome, x, z, nil, 30)
					local cover = content.decoration_cover(row.id, biome, surface.top_ref)
					if not allowed then assert(cover == 0)
					elseif surface.top == "default:stone" then assert(cover == 0)
					elseif surface.top == "default:gravel" and row.host ~= surface.top then
						assert(cover == (row.settlement_class == 4 and 4 or 0))
						gravel = gravel + 1
					else assert(cover == 1); fertile = fertile + 1 end
					checks = checks + 1
				end
			end
		end
	end
	assert(fertile > 0 and gravel > 0)
	biome = "grug_pine_hills"
	-- Current catalog/selector/cover, with cultural/resource catalogs suppressed
	-- so this fixture owns only cosmetic vegetation eligibility.
	local wrapper = {}
	for _, name in ipairs({"surfaces", "new_surface_selector", "decorations",
		"content_ref", "decoration_cover"}) do wrapper[name] = content[name] end
	function wrapper.resources() return {} end
	function wrapper.cultural() return {} end
	local _, planner = dofile(wp40 .. "r6_planner.lua").new_runtime({
		full_seed_string = "cover-fixture", planner_source = source,
		r5_planner = {plan_slice = function() error("unused fixture writer") end},
		horizontal = {static_exclusion_values_at = function() return nil end},
		content = wrapper, templates = {maximum_footprint = function() return 1, 1, 1 end},
		hash = hash, source = {zones = {{id = "fixture", race_region = "dwarf"}},
			race_regions = {"dwarf"}, hydrology_profiles = {}, hydrology = {}, hydrology_interfaces = {}},
		construction_identity = {value = {}},
		counting_allocator = dofile(wp40 .. "counting_allocator.lua").new("grug_wp40_r6_planner_allocator_v1"),
	})
	local variant_trees, variant_small, thinned, candidate_rows = 0, 0, 0, {}
	local radius = expanded and 8 or 2
	for cz = -radius, radius - 1 do
		for cx = -radius, radius - 1 do
			local _, candidates, groups = planner.build_cell(cx, cz)
			local expected = {}
			for catalog, row in ipairs(decorations) do
				local count = 0
				for z = cz * 16, cz * 16 + 15 do
					for x = cx * 16, cx * 16 + 15 do
						local surface = select_surface(biome, x, z, nil, 30)
						local cover = content.decoration_cover(row.id, biome, surface.top_ref)
						if cover > 0 then
							local digest = hash.digest("decoration_candidate_rank_v1", "cover-fixture",
								{row.id, cx, cz, x, z})
							if digest:byte(1) % cover == 0 then count = count + 1
							elseif cover > 1 then thinned = thinned + 1 end
						end
					end
				end
				expected[catalog] = count
			end
			for _, group in ipairs(groups) do
				assert(group.kind == 2 and group.eligible == expected[group.catalog])
				checks = checks + 1
			end
			for _, candidate in ipairs(candidates) do
				local row = decorations[candidate.catalog]
				local top = select_surface(biome, candidate.x, candidate.z, nil, 30).top
				assert(content.decoration_cover(row.id, biome, content.content_ref(top)) > 0)
				if top ~= row.host then
					if row.kind == "template" then variant_trees = variant_trees + 1
					else variant_small = variant_small + 1 end
				end
				candidate_rows[#candidate_rows + 1] = row.id .. "/" .. candidate.x .. "/" .. candidate.z .. "/" .. top
			end
		end
	end
	assert(variant_trees > 0 and variant_small > 0, "alternate soils still produce empty vegetation plans")
	if expanded then assert(thinned > 0, "gravel thinning was not exercised") end
	table.sort(candidate_rows)
	return "schema\tgrug_wp40_biome_cover_fixture_v1\nchecks\t" .. checks ..
		"\nvariant_templates\t" .. variant_trees .. "\nvariant_simple\t" .. variant_small ..
		"\nthinned\t" .. thinned .. "\ncandidates_sha256\t" ..
		common.hex(common.new_sha256()(table.concat(candidate_rows, "\n"))) .. "\n"
end
