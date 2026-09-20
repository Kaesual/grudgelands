-- Portable production selector/P9G boundary checks; no world population.
return function(repo)
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local sha = common.new_sha256()
	local _, content = dofile(repo .. "/tools/wp40/quality/surface_fixture.lua")(repo)
	local relief, fresh, profile, distance, excluded = "mountain", false, "cliff", 1, true
	local planner = {
		column_values_at = function() return "land", 1, "fixture", "grug_beach", "orc", 30 end,
		primary_relief_at = function() return relief end,
		coast_profile_at = function()
			if not excluded then return profile, distance, 4, fresh end
		end,
		coast_material_at = function() return profile, distance, 4, fresh end,
	}
	local selector = content.new_surface_selector("4151598227737528026", planner)
	local records = {}
	local function rock(row)
		assert(row.top == "default:stone" or row.top == "default:gravel", "shore has sand/soil")
		assert(row.filler == row.top and row.shore == row.top and row.dust_ref == 0)
		records[#records + 1] = row.top
	end
	for _, x in ipairs({-81, -80, -1, 0, 79, 80}) do
		rock(selector("grug_beach", x, -2458, nil, 30))
	end
	for _, value in ipairs({"plateau", "highland", "mountain"}) do
		relief, fresh, profile = value, true, "beach"
		for _, shielded in ipairs({true, false}) do
			excluded = shielded
			rock(selector("grug_meadows", -71, -2458, nil, 30))
		end
	end
	-- A lowland freshwater beach and submerged natural beds retain their rule.
	relief, fresh, excluded = "lowland", true, false
	assert(selector("grug_meadows", 0, 0, nil, 30).top == "default:sand")
	relief, excluded, distance = "mountain", true, 50
	local dry = selector("grug_beach", 0, 0, nil, 30)
	rock(dry)
	assert(selector("grug_beach", 0, 0, 54, 30).bed == "default:sand")

	local catalog = dofile(repo .. "/mods/ITEMS/grug_gathering/catalog.lua")
	local manifest = catalog.manifest()
	assert(common.hex(sha(manifest.canonical_bytes)) == manifest.sha256)
	local rows, index_by_name, salt_index = catalog.p9g_sources(), {}, nil
	local p9g = {schema = "grug_wp40_r7_p9g_content_v2", content_names = {}, content_cids = {}}
	for index, row in ipairs(rows) do
		p9g.content_names[index], p9g.content_cids[index] = row.source_node, 1000 + index
		index_by_name[row.source_node] = index
		if row.key == "rock_salt" then salt_index = index end
	end
	local world_catalog = dofile(wp40 .. "/world_content_catalog.lua")
	assert(#rows == 12 and #world_catalog.names == 22)
	for offset, name in ipairs(world_catalog.names) do
		local index = offset + 12
		p9g.content_names[index], p9g.content_cids[index] = name, 1000 + index
		index_by_name[name] = index
	end
	assert(#p9g.content_names == 34)
	function p9g.content_ref(name) return index_by_name[name] end
	function p9g.resolve_p9g(index) return 1000 + index, 1, 1, 0, 8 end
	local names = {}
	for index = 1, 90 do names[index] = "fixture:" .. index end
	local production = {schema = "grug_wp40_r7_production_r6_content_v1",
		content_names = names, ignore_cid = 127,
		r5 = {resolve = function() return 0, 0, 0 end}}
	local successor = dofile(wp40 .. "/r7_p9g.lua")(catalog, p9g, sha).new({
		full_seed_string = "0", hash = {budget = function() return 1 end},
		planner_source = {}, horizontal = {}, source = {}, construction_identity = {},
		content = {content_contract = function() return production end},
		zones_session = {surface_mob_level_at = function() return 7 end},
	})
	local refs = {["default:sand"] = 1, ["default:stone"] = 2, ["default:gravel"] = 3}
	local zone, support, actual, neighbor, lower = "front_gravesalt_escarpment", 1, 1, "coastal_shelf", false
	local context = {
		inside_owner = function(_, y) return not lower or y >= 6 end,
		original_at = function() return 0, 0 end,
		settled_at = function(_, y)
			if y == 5 then return actual, 0, 0, 4, 0, 0, (actual - 1) * 256 end
			return 0, 0, 0, 0, 0, 0, 0
		end,
		production_content = function(name) return refs[name], refs[name] end,
		analytic_p7_ref = function() return support end,
		analytic_p7_tuple = function() return actual, 0, 0, 4, 0, 0, (actual - 1) * 256 end,
		exclusion_at = function() return nil end,
		housing_excluded_at = function() return false end,
		column_values_at = function(x, z)
			return x == -80 and z == -1 and "land" or neighbor, 1, zone, "grug_beach", "orc", 5
		end,
	}
	local cases = 0
	for _, endpoint in ipairs({"front_gravesalt_escarpment", "front_stormscale_summit", "front_wyrmglass_crown"}) do
		zone = endpoint
		for ref = 1, 3 do
			support, actual = ref, ref
			for _, boundary in ipairs({false, true}) do
				lower = boundary
				local reason = successor:probe_reason(context, salt_index, -80, 6, -1)
				local allowed = endpoint == "front_gravesalt_escarpment" and ref == 1 or
					endpoint ~= "front_gravesalt_escarpment" and ref ~= 1
				assert(reason == (allowed and "accepted" or "wrong_support"), endpoint .. "/" .. ref .. "/" .. reason)
				cases = cases + 1
			end
		end
	end
	support, actual = 2, 3
	assert(successor:probe_reason(context, salt_index, -80, 6, -1) == "wrong_support", "actual support mismatch accepted")
	actual, neighbor = 2, "land"
	assert(successor:probe_reason(context, salt_index, -80, 6, -1) == "wrong_shore")
	neighbor, zone = "coastal_shelf", "front_skyglass_canopy"
	assert(successor:probe_reason(context, salt_index, -80, 6, -1) == "wrong_zone")
	assert(#rows[salt_index].zones == 3 and #rows[salt_index].hosts == 5)
	return "r10/material_salt\t" .. cases .. "\t" .. common.hex(sha(table.concat(records, "\n"))) .. "\n"
end
