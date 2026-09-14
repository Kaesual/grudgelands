-- Loaded as the disposable WP40 profiler's cases.lua, never shipped in-game.
local reverse = false -- The WP13 runner changes only this switch in its copy.
local wp40 = core.get_modpath("grug_mapgen") .. "/wp40"
local blueprint = dofile(wp40 .. "/r7_hearthpine_blueprint.lua")()
local anchor = assert(grug_zones.anchor("elandor_hearthpine_vale", "start"))
assert(anchor.x == -1800 and anchor.z == -2550)
local function origin(value) return math.floor((value + 32) / 80) * 80 - 32 end
local owners, seen = {}, {}
local function add(x, y, z)
	local ox, oy, oz = origin(x), origin(y), origin(z)
	local key = ox .. ":" .. oy .. ":" .. oz
	if seen[key] then return end
	seen[key] = true
	owners[#owners + 1] = {id = "owner_" .. key, x = ox + 40, y = oy + 40, z = oz + 40}
end
for _, cell in ipairs(blueprint.cells) do
	add(anchor.x + cell.x, anchor.y + cell.y, anchor.z + cell.z)
end
assert(#owners <= 12, "profile corpus exceeds bounded twelve structure owners")
-- Include a second start as a control, then adjacent non-structure owners.
local human = assert(grug_zones.anchor("elandor_dawnmere_fields", "start"))
add(human.x, human.y, human.z)
-- This seed puts Stillgrave's fitted surface at y=48, just above the
-- generated owner's ceiling. Emerge only its lower owner to exercise filler
-- restoration when the matching top opcode belongs to a different owner.
local filler_boundary = core.settings:get("grug_wp40_profile_seed") == "8675309"
if filler_boundary then add(-1863, 47, 2528) end
assert(#owners <= 14, "WP13 control population is unbounded")
local extra = 0
while #owners < 10 do
	extra = extra + 1
	add(anchor.x + extra * 80, anchor.y - 80, anchor.z)
end
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
	if filler_boundary then
		assert(grug_zones.terrain_height_at(-1863, 2528) == 48,
			"WP13 vertical boundary witness moved")
		assert(core.get_node({x = -1863, y = 47, z = 2528}).name == "default:dirt",
			"WP13 filler-only owner retained stone instead of biome soil")
	end
	local parts, torch_count, lit = {}, 0, 0
	local edited_cell_seen = false
	for _, cell in ipairs(blueprint.cells) do
		local pos = {x = anchor.x + cell.x, y = anchor.y + cell.y, z = anchor.z + cell.z}
		local node = core.get_node(pos)
		local edited = cell.x == 5 and cell.y == 2 and cell.z == 0
		local expected = edited and phase == "disk" and "default:glass" or cell.name
		if edited then
			assert(cell.name == "air" and cell.param2 == 0)
			edited_cell_seen = true
		end
		assert(node.name == expected, "WP13 node differs " .. core.pos_to_string(pos) ..
			": " .. node.name .. " expected " .. cell.name)
		assert(node.param2 == cell.param2, "WP13 param2 differs " .. core.pos_to_string(pos))
		-- Compare unedited structure bytes across orders/reloads; the one deliberate
		-- edit is independently checked above instead of hidden in this digest.
		if not edited then
			parts[#parts + 1] = table.concat({cell.x, cell.y, cell.z, node.name, node.param2}, ":")
		end
		if (cell.name == "default:torch" or cell.name == "default:torch_wall") then
			torch_count = torch_count + 1
			if (core.get_node_light(pos, 0) or 0) > 0 then lit = lit + 1 end
		end
	end
	assert(edited_cell_seen, "persistence canary outside authored cells")
	assert(torch_count >= 8 and lit == torch_count, "WP13 night lighting differs")
	for _, pos in ipairs(blueprint.landmarks.destinations) do
		local feet = {x = anchor.x + pos.x, y = anchor.y + pos.y, z = anchor.z + pos.z}
		assert((core.get_node_light(feet, 0) or 0) > 0, "WP13 dark interior " .. pos.id)
		for y = pos.y, pos.y + 1 do
			local name = core.get_node({x = anchor.x + pos.x,
				y = anchor.y + y, z = anchor.z + pos.z}).name
			assert(core.registered_nodes[name].walkable == false, "WP13 blocked interior " .. pos.id)
		end
	end
	for z = 0, 63 do
		for x = -2, 2 do
			local foot = {x = anchor.x + x, y = anchor.y + 1, z = anchor.z + z}
			assert((core.get_node_light(foot, 0) or 0) > 0,
				"WP13 dark main route at " .. x .. "," .. z)
			assert(core.registered_nodes[core.get_node(foot).name].walkable == false)
			foot.y = foot.y + 1
			assert(core.registered_nodes[core.get_node(foot).name].walkable == false)
		end
	end
	if phase == "cold" then
		-- Simulate an authorized server-side edit after the profiler's snapshots.
		-- This disposable test coordinate is not one of its sampled positions.
		core.set_node({x = anchor.x + 5, y = anchor.y + 2, z = anchor.z},
			{name = "default:glass", param2 = 0})
	end
	core.log("action", "GRUG_WP13_ENGINE phase=" .. phase ..
		" cells=" .. #blueprint.cells .. " torches=" .. lit ..
		" edit_canary=" .. (phase == "cold" and "placed" or "preserved") ..
		" digest_excluded_cells=1" ..
		" soil_witnesses=" .. soil_witnesses ..
		" filler_boundary=" .. tostring(filler_boundary) ..
		" digest=" .. core.sha256(table.concat(parts, "\n"), false) ..
		" anchor=" .. anchor.x .. "," .. anchor.y .. "," .. anchor.z)
end)
return owners
