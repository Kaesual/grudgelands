local root = assert(arg[1], "usage: lattice_audit.lua REPOSITORY_ROOT")

local function read(relative)
	local handle = assert(io.open(root .. "/" .. relative, "rb"))
	local contents = assert(handle:read("*a"))
	handle:close()
	return contents
end

local function floor_div(value, divisor)
	return math.floor(value / divisor)
end

local block_size = 16
local chunksize = 5
local emerge_border_blocks = 1
local water_level = 1
local relief_min_offset = 2
local ordinary_max_cut = 24
local native_displacement = 16
local repair_allowance = 16
local exterior_depth_max = 32
local bed_seal_layers = 3
local tunnel_route_max_cut = 8
local tunnel_backing = 2
local foundation_backing = 3
local dungeon_ymin = -31000
local dungeon_ymax = -193

local relief_min = water_level + relief_min_offset
local target_min = relief_min - ordinary_max_cut
local broad_content_y_min = math.min(
	relief_min - native_displacement,
	target_min
) - repair_allowance
assert(broad_content_y_min == -37, "unexpected broad-content lower bound")

local exterior_floor = water_level - exterior_depth_max - bed_seal_layers
local tunnel_floor = relief_min - tunnel_route_max_cut - tunnel_backing
local foundation_floor = relief_min - tunnel_route_max_cut - foundation_backing
assert(exterior_floor == -34 and exterior_floor >= broad_content_y_min,
	"exterior water exceeds broad-content lower bound")
assert(tunnel_floor == -7 and tunnel_floor >= broad_content_y_min,
	"tunnel backing exceeds broad-content lower bound")
assert(foundation_floor == -8 and foundation_floor >= broad_content_y_min,
	"named foundation backing exceeds broad-content lower bound")

-- Audit the current T2 catalog without executing it. Every authored hydrology
-- row is expressed as mapgen water level + offset, depth, then three bed seals.
local catalog = read("mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua")
local world_zones = read("docs/design/world_zones.md")
local pipe = string.char(124)
local relief_bands = {
	{"wetland_delta", 2, 24},
	{"lowland", 8, 56},
	{"rolling_hills", 24, 96},
	{"plateau", 56, 144},
	{"highland", 96, 224},
	{"mountain", 160, 360},
}
for i = 1, #relief_bands do
	local band = relief_bands[i]
	local line = pipe .. " `" .. band[1] .. "` " .. pipe .. " +" ..
		band[2] .. "..+" .. band[3] .. " " .. pipe
	assert(world_zones:find(line, 1, true), "missing relief-band bound: " .. line)
end

local observed_max_cut = 0
local observed_max_fill = 0
for cut in catalog:gmatch("max_cut=(%d+)") do
	observed_max_cut = math.max(observed_max_cut, tonumber(cut))
end
for cut in catalog:gmatch("max_cut = (%d+)") do
	observed_max_cut = math.max(observed_max_cut, tonumber(cut))
end
for fill in catalog:gmatch("max_fill=(%d+)") do
	observed_max_fill = math.max(observed_max_fill, tonumber(fill))
end
for fill in catalog:gmatch("max_fill = (%d+)") do
	observed_max_fill = math.max(observed_max_fill, tonumber(fill))
end
assert(observed_max_cut == ordinary_max_cut, "current template max cut changed")
assert(observed_max_fill == 16, "current template max fill changed")
assert(catalog:find("inner_radius=72,depth=12,rim_width=24", 1, true),
	"current troll-basin depth changed")
assert(catalog:find("surface_width=32,backing_depth=3", 1, true),
	"current named foundation backing changed")

local hydrology_count = 0
local hydrology_floor = nil
local hydrology_min_offset = nil
local hydrology_max_depth = 0
for offset, depth in catalog:gmatch(
	'hydro%([^\n]-"[^\n]-",([%-]?%d+),(%d+),%{%{') do
	hydrology_count = hydrology_count + 1
	local numeric_offset = tonumber(offset)
	local numeric_depth = tonumber(depth)
	local floor = water_level + numeric_offset - numeric_depth - bed_seal_layers
	if not hydrology_min_offset or numeric_offset < hydrology_min_offset then
		hydrology_min_offset = numeric_offset
	end
	hydrology_max_depth = math.max(hydrology_max_depth, numeric_depth)
	if not hydrology_floor or floor < hydrology_floor then
		hydrology_floor = floor
	end
end
assert(hydrology_count == 22, "expected all 22 current hydrology reaches")
assert(hydrology_min_offset == 8, "current hydrology minimum offset changed")
assert(hydrology_max_depth == 12, "current hydrology maximum depth changed")
assert(hydrology_floor == -2,
	"current hydrology floor changed; re-derive the manifest bound")
assert(hydrology_floor >= broad_content_y_min,
	"planned hydrology exceeds broad-content lower bound")

local function slice(k)
	local block_min = -floor_div(chunksize, 2) + chunksize * k
	local block_max = block_min + chunksize - 1
	return {
		k = k,
		central_min = block_min * block_size,
		central_max = (block_max + 1) * block_size - 1,
		full_min = (block_min - emerge_border_blocks) * block_size,
		full_max = (block_max + emerge_border_blocks + 1) * block_size - 1,
	}
end

local function owner_k(y)
	local block_y = floor_div(y, block_size)
	return floor_div(block_y + floor_div(chunksize, 2), chunksize)
end

local broad_k = owner_k(broad_content_y_min)
local first_broad = slice(broad_k)
assert(broad_k == -1, "unexpected first broad-content owner slice")
assert(first_broad.central_min == -112 and first_broad.central_max == -33,
	"unexpected first broad-content central slice")
assert(first_broad.full_min == -128 and first_broad.full_max == -17,
	"unexpected first broad-content full VM")

local highest_dungeon = nil
for k = -1000, 1000 do
	local current = slice(k)
	local eligible = current.central_min <= dungeon_ymax and
		current.central_max >= dungeon_ymin
	if eligible then
		highest_dungeon = current
		assert(current.full_max < first_broad.full_min,
			"eligible dungeon VM reaches a broad-content callback collar")
	end
	if current.full_max >= first_broad.full_min then
		assert(not eligible,
			"dungeon eligibility overlaps a broad-content callback collar")
	end
end

assert(highest_dungeon and highest_dungeon.k == -3,
	"unexpected highest eligible dungeon slice")
assert(highest_dungeon.central_min == -272 and
	highest_dungeon.central_max == -193,
	"unexpected highest eligible dungeon central slice")
assert(highest_dungeon.full_min == -288 and highest_dungeon.full_max == -177,
	"unexpected highest eligible dungeon full VM")

local disabled_boundary = slice(-2)
assert(disabled_boundary.central_min == -192 and
	disabled_boundary.central_min > dungeon_ymax,
	"the first disabled dungeon slice is not excluded at its lower boundary")

local function overlap_size(left, right)
	local low = math.max(left.full_min, right.full_min)
	local high = math.min(left.full_max, right.full_max)
	if high < low then
		return 0
	end
	return high - low + 1
end

-- Enumerate the complete transition matrix around the cutoff. Adjacent
-- vertical VMs overlap by two mapblocks (32 nodes), but k=-2 is dungeon-
-- ineligible and broad-content-free. The dungeon k=-3 and broad k=-1 VMs are
-- strictly disjoint in both callback orders.
local boundary_cases = {
	[-3] = {central_min = -272, central_max = -193,
		full_min = -288, full_max = -177, dungeon = true, broad = false},
	[-2] = {central_min = -192, central_max = -113,
		full_min = -208, full_max = -97, dungeon = false, broad = false},
	[-1] = {central_min = -112, central_max = -33,
		full_min = -128, full_max = -17, dungeon = false, broad = true},
}
local boundary_order_count = 0
for from_k = -3, -1 do
	local from = slice(from_k)
	local expected = boundary_cases[from_k]
	assert(from.central_min == expected.central_min and
		from.central_max == expected.central_max and
		from.full_min == expected.full_min and from.full_max == expected.full_max,
		"wrong explicit cutoff-boundary slice")
	local dungeon = from.central_min <= dungeon_ymax and
		from.central_max >= dungeon_ymin
	assert(dungeon == expected.dungeon, "wrong explicit dungeon eligibility")
	assert((from_k == broad_k) == expected.broad,
		"wrong explicit broad-owner classification")
	for to_k = -3, -1 do
		local to = slice(to_k)
		local distance = math.abs(from_k - to_k)
		local expected_overlap = distance == 0 and 112 or
			(distance == 1 and 32 or 0)
		for order = 1, 2 do
			boundary_order_count = boundary_order_count + 1
			local first = order == 1 and from or to
			local second = order == 1 and to or from
			assert(overlap_size(first, second) == expected_overlap,
				"wrong vertical callback-collar overlap")
			if (from_k == -3 and to_k == -1) or
					(from_k == -1 and to_k == -3) then
				assert(expected_overlap == 0,
					"dungeon and broad callback collars overlap")
			end
		end
	end
end
assert(boundary_order_count == 18,
	"incomplete k=-3/-2/-1 callback-order matrix")

-- Same-y horizontal neighbor collars are enumerated for all eight neighbors,
-- all three cutoff slices and both request orders. An adjacent axis overlaps
-- by 32 nodes; an unchanged axis spans the complete 112-node full VM.
local horizontal_order_count = 0
local function horizontal_full_range(owner)
	local block_min = -floor_div(chunksize, 2) + chunksize * owner
	local block_max = block_min + chunksize - 1
	return {
		min = (block_min - emerge_border_blocks) * block_size,
		max = (block_max + emerge_border_blocks + 1) * block_size - 1,
	}
end

local function axis_overlap_size(left, right)
	local low = math.max(left.min, right.min)
	local high = math.min(left.max, right.max)
	if high < low then
		return 0
	end
	return high - low + 1
end

for k = -3, -1 do
	local y_slice = slice(k)
	local origin_x = horizontal_full_range(0)
	local origin_z = horizontal_full_range(0)
	for dz = -1, 1 do
		for dx = -1, 1 do
			if dx ~= 0 or dz ~= 0 then
				local neighbor_x = horizontal_full_range(dx)
				local neighbor_z = horizontal_full_range(dz)
				local x_overlap = axis_overlap_size(origin_x, neighbor_x)
				local z_overlap = axis_overlap_size(origin_z, neighbor_z)
				local expected_x = dx == 0 and 112 or 32
				local expected_z = dz == 0 and 112 or 32
				for order = 1, 2 do
					horizontal_order_count = horizontal_order_count + 1
					local first_x = order == 1 and origin_x or neighbor_x
					local second_x = order == 1 and neighbor_x or origin_x
					local first_z = order == 1 and origin_z or neighbor_z
					local second_z = order == 1 and neighbor_z or origin_z
					assert(axis_overlap_size(first_x, second_x) == expected_x and
						axis_overlap_size(first_z, second_z) == expected_z and
						x_overlap == expected_x and z_overlap == expected_z,
						"wrong same-y horizontal callback-collar overlap")
					assert(y_slice.full_max - y_slice.full_min + 1 == 112,
						"same-y horizontal neighbor changed its y collar")
				end
			end
		end
	end
end
assert(horizontal_order_count == 48,
	"incomplete same-y horizontal-neighbor/order matrix")

-- Executable deep typed-operation fixtures. The resource operation recognizes
-- one exact final stratum host and has no param2/light/liquid side effects.
-- Its registered output remains ground content, so native DungeonGen wins
-- whether the typed write runs before it or sees its result afterward.
local exact_host = "grug_materials:slate"
local resource_output = "grug_materials:stone_with_citrine"
local dungeon_output = "default:cobble"
local ground_content = {
	[exact_host] = true,
	[resource_output] = true,
	["default:stone_with_coal"] = true,
	[dungeon_output] = true,
}
local function typed_resource(node)
	if node == exact_host then
		return {
			content = resource_output,
			changed = true,
			reason = "eligible_host",
			param2 = false,
			light = false,
			liquid = false,
		}
	end
	return {
		content = node,
		changed = false,
		reason = "typed_skip",
		param2 = false,
		light = false,
		liquid = false,
	}
end
local function dungeon_writer(node)
	if ground_content[node] then
		return dungeon_output
	end
	return node
end
local function resource_then_dungeon(node)
	return dungeon_writer(typed_resource(node).content)
end
local function dungeon_then_resource(node)
	return typed_resource(dungeon_writer(node)).content
end

local host_result = typed_resource(exact_host)
assert(host_result.changed and host_result.content == resource_output and
	host_result.reason == "eligible_host", "exact deep host was not replaced")
assert(ground_content[resource_output] == true,
	"authored resource output is not DungeonGen-compatible ground")
assert(not host_result.param2 and not host_result.light and not host_result.liquid,
	"deep typed host replacement requested a forbidden side effect")
assert(resource_then_dungeon(exact_host) == dungeon_output and
	dungeon_then_resource(exact_host) == dungeon_output,
	"native dungeon did not win both exact-host callback orders")
assert(resource_then_dungeon(resource_output) == dungeon_output and
	dungeon_then_resource(resource_output) == dungeon_output,
	"native dungeon did not win both output-ground callback orders")

local skip_fixtures = {
	{category = "generic_ore", node = "default:stone_with_coal"},
	{category = "air", node = "air"},
	{category = "liquid", node = "default:water_source"},
	{category = "dungeon", node = dungeon_output},
	{category = "ignore", node = "ignore"},
	{category = "unknown", node = "unknown:missing"},
	{category = "foreign", node = "foreign_mod:structure"},
}
local skip_order_count = 0
for i = 1, #skip_fixtures do
	local fixture = skip_fixtures[i]
	local skipped = typed_resource(fixture.node)
	assert(not skipped.changed and skipped.content == fixture.node and
		skipped.reason == "typed_skip",
		"deep typed operation changed skip category " .. fixture.category)
	assert(not skipped.param2 and not skipped.light and not skipped.liquid,
		"deep typed skip requested a side effect for " .. fixture.category)
	local first = resource_then_dungeon(fixture.node)
	local second = dungeon_then_resource(fixture.node)
	assert(first == second,
		"deep resource/native-dungeon order differs for " .. fixture.category)
	skip_order_count = skip_order_count + 2
end
assert(skip_order_count == 14,
	"incomplete deep typed skip-category/order fixtures")

assert(highest_dungeon.full_max + 1 == -176)
assert(first_broad.full_min - 1 == -129)
assert(first_broad.full_min - highest_dungeon.full_max - 1 == 48,
	"unexpected callback-collar gap")

print("WP40 dungeon lattice audit: PASS")
print("- water_level=1; H_min=W+2=" .. relief_min)
print("- broad_content_y_min=" .. broad_content_y_min ..
	"; exterior_floor=" .. exterior_floor ..
	"; planned_water_floor=" .. hydrology_floor ..
	"; tunnel_floor=" .. tunnel_floor ..
	"; foundation_floor=" .. foundation_floor)
print("- first broad owner central=[-112,-33], full=[-128,-17]")
print("- mgv7_dungeon_ymax=-193; highest dungeon central=[-272,-193], full=[-288,-177]")
print("- callback influence gap=[-176,-129] (48 nodes)")
print("- cutoff matrix: 18 vertical-order + 48 same-y horizontal-neighbor/order cases")
print("- deep typed fixtures: host/output-ground both orders + 7 skip categories/14 order cases")
