local repo = assert(arg[1], "repository root required")
local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local catalog = dofile(dir .. "/world_content_catalog.lua")

local names, cids = {}, {}
for index = 1, 12 do names[index] = "fixture:" .. index; cids[index] = index end
for index, name in ipairs(catalog.names) do
	names[index + 12] = name
	cids[index + 12] = index + 12
end
local water_cid, sand_cid = 1001, 1002
local support_cids = {}
for _, plant in ipairs(catalog.plants) do
	for _, host_names in pairs(plant.hosts) do
		for _, name in ipairs(host_names) do
			if not support_cids[name] then
				support_cids[name] = name == "default:sand" and sand_cid or 1100 + #names
				names[#names + 1] = name
				cids[#cids + 1] = support_cids[name]
			end
		end
	end
end
local contract = {
	content_names = names,
	content_cids = cids,
	r5 = {resolve = function() return 1 end},
	ordinary_water_family_id = 9,
	classify = function(cid)
		if cid == water_cid then return nil, 9, 1 end
		return nil, 0, 0
	end,
}
local content = {
	content_contract = function() return contract end,
}
local p9g = {
	content_names = names,
	resolve_p9g = function(ref) return cids[ref] end,
}
local habitat = {initial_denominator = function() return 999999 end}
local config = dofile(dir .. "/world_content.lua")(catalog, p9g, habitat)

local function sample(water_class, denied)
	local plan, writes = {}, {}
	local tail = config.new({
		content = content,
		full_seed_string = "4151598227737528026",
		zones_session = {surface_mob_level_at = function() return 1 end},
	})
	tail.bind(plan, 1)
	local ctx = {
		plan = plan, generation = 1, call_mode = "evidence_fixture",
		min_y = -5, max_y = 1,
	}
	function ctx.inside_owner(x, y, z)
		return x == ctx.min_x and z == ctx.min_z and y >= -5 and y <= 1
	end
	function ctx.column_values_at()
		return water_class, 1, "fixture_zone", "fixture_biome", "neutral", -4, 0
	end
	function ctx.exclusion_at() return denied end
	function ctx.housing_excluded_at() return false end
	function ctx.settled_at(_, y)
		if y == -4 then return sand_cid, 0, 0, 1 end
		if y > 0 then return 1, 0, 0, 0 end
		return water_cid, 0, 0, 0
	end
	function ctx.production_content(name)
		assert(name == "default:sand" or name == "default:gravel" or
			name == "default:stone")
		return 1, name == "default:sand" and sand_cid or 2000
	end
	function ctx.write_p9g(x, y, z, cid, param2, ref)
		writes[#writes + 1] = {x = x, y = y, z = z, cid = cid,
			param2 = param2, ref = ref}
	end
	for z = 0, 255 do
		for x = 0, 255 do
			ctx.min_x, ctx.max_x, ctx.min_z, ctx.max_z = x, x, z, z
			tail.settle(ctx)
		end
	end
	return writes
end

local reef = sample("coastal_shelf", false)
assert(#reef > 100 and #reef < 1500, "bounded reef density")
local refs, rows, columns = {}, {}, {}
for _, row in ipairs(reef) do
	assert(row.ref >= 28 and row.ref <= 34 and row.y == -4)
	refs[row.ref] = true; rows[row.z] = true; columns[row.x] = true
end
local ref_count = 0
for ref = 28, 34 do if refs[ref] then ref_count = ref_count + 1 end end
assert(ref_count == 7, "reef palette coverage")
local row_count, column_count = 0, 0
for _ in pairs(rows) do row_count = row_count + 1 end
for _ in pairs(columns) do column_count = column_count + 1 end
assert(row_count > 20 and column_count > 20, "reef collapsed into strips")

local fresh = sample("planned_water", false)
assert(#fresh > 300 and #fresh < 1800, "bounded freshwater density")
local weeds, lilies = 0, 0
for _, row in ipairs(fresh) do
	if row.ref == 36 then
		assert(row.param2 == 48 and row.y == -4); weeds = weeds + 1
	elseif row.ref == 35 then
		assert(row.param2 >= 0 and row.param2 <= 3 and row.y == 1); lilies = lilies + 1
	else error("unexpected freshwater ref") end
end
assert(weeds > 200 and lilies > 100, "freshwater variants absent")
assert(#sample("planned_water", true) == 0, "excluded freshwater decoration")
assert(#sample("immutable_dragon_channel", false) == 0, "functional channel decoration")

print("r21_aquatic_world_content_kat\tpass\t" .. #reef .. "\t" .. weeds .. "\t" .. lilies)
