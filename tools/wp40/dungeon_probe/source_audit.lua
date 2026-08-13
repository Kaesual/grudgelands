local root = assert(arg[1], "usage: source_audit.lua REPOSITORY_ROOT")

local function read(relative)
	local path = root .. "/" .. relative
	local handle = assert(io.open(path, "rb"))
	local contents = assert(handle:read("*a"))
	handle:close()
	return contents
end

local function require_text(contents, needle, label)
	assert(contents:find(needle, 1, true), "missing source fact: " .. label)
end

local function require_order(contents, first, second, label)
	local first_at = contents:find(first, 1, true)
	local second_at = contents:find(second, 1, true)
	assert(first_at and second_at and first_at < second_at,
		"wrong or missing source order: " .. label)
end

local function count_text(contents, needle)
	local count = 0
	local offset = 1
	while true do
		local at = contents:find(needle, offset, true)
		if not at then
			return count
		end
		count = count + 1
		offset = at + #needle
	end
end

local mapgen_h = read("reference_projects/luanti/src/mapgen/mapgen.h")
local engine_cmake = read("reference_projects/luanti/CMakeLists.txt")
local mapgen_v7 = read("reference_projects/luanti/src/mapgen/mapgen_v7.cpp")
local mapgen_v7_h = read("reference_projects/luanti/src/mapgen/mapgen_v7.h")
local mapgen = read("reference_projects/luanti/src/mapgen/mapgen.cpp")
local emerge = read("reference_projects/luanti/src/emerge.cpp")
local servermap = read("reference_projects/luanti/src/servermap.cpp")
local servermap_h = read("reference_projects/luanti/src/servermap.h")
local constants_h = read("reference_projects/luanti/src/constants.h")
local map_settings_test = read(
	"reference_projects/luanti/src/unittest/test_map_settings_manager.cpp")
local settingtypes = read("reference_projects/luanti/builtin/settingtypes.txt")
local lua_mapgen = read("reference_projects/luanti/src/script/lua_api/l_mapgen.cpp")
local lua_vmanip = read("reference_projects/luanti/src/script/lua_api/l_vmanip.cpp")
local dungeon = read("reference_projects/luanti/src/mapgen/dungeongen.cpp")
local dungeon_h = read("reference_projects/luanti/src/mapgen/dungeongen.h")
local lua_api = read("reference_projects/luanti/doc/lua_api.md")
local biomes = read("mods/MAPGEN/grug_mapgen/biomes.lua")
local mapgen_ores = read("mods/MAPGEN/grug_mapgen/ores.lua")
local material_registry = read("mods/ITEMS/grug_materials/registry.lua")
local material_init = read("mods/ITEMS/grug_materials/init.lua")
local material_ores = read("mods/ITEMS/grug_materials/ores.lua")
local baseline_map_meta = read(
	"tools/wp40/evidence/t0-post-wp43-wp18-wp36/" ..
	"70adabd28401e820ec86e8786bf0da368225c8624e42ed02dd3bce175fd3cafc/" ..
	"raw/run-001.map_meta.txt")

require_text(engine_cmake, "set(VERSION_MAJOR 5)", "pinned engine major version")
require_text(engine_cmake, "set(VERSION_MINOR 17)", "pinned engine minor version")
require_text(engine_cmake, "set(DEVELOPMENT_BUILD TRUE)",
	"pinned engine development class")

local mapgen_enum = assert(mapgen_h:match("enum MapgenObject%s*{(.-)};"),
	"missing MapgenObject enum")
assert(count_text(mapgen_enum, "MGOBJ_") == 6,
	"unexpected MapgenObject count")
require_text(mapgen_h, "MGOBJ_GENNOTIFY", "gennotify is a MapgenObject")
assert(not mapgen_h:find("MGOBJ_DUNGEON", 1, true),
	"unexpected dungeon provenance MapgenObject exists")
require_text(lua_mapgen, "case MGOBJ_GENNOTIFY:", "Lua exports gennotify")
require_text(lua_mapgen, "push_v3s16(L, it->second[j]);", "gennotify exports positions")
require_text(lua_api, "`dungeon`: bottom center position of dungeon rooms",
	"Lua API documents room bottom centers")
require_text(lua_vmanip, "luamethod(LuaVoxelManip, get_data)",
	"VoxelManip exports content data")
require_text(lua_vmanip, "luamethod(LuaVoxelManip, get_node_at)",
	"VoxelManip exports node reads")
require_text(lua_vmanip, "luamethod(LuaVoxelManip, get_param2_data)",
	"VoxelManip exports param2 data")
require_text(lua_vmanip, "luamethod(LuaVoxelManip, get_emerged_area)",
	"VoxelManip exports emerged-area bounds")
require_text(lua_vmanip, "push_v3s16(L, o->vm->m_area.MinEdge);",
	"get_emerged_area returns the VoxelManip minimum edge")
require_text(lua_vmanip, "push_v3s16(L, o->vm->m_area.MaxEdge);",
	"get_emerged_area returns the VoxelManip maximum edge")
require_text(lua_vmanip, "vm->m_data[i].setContent(c);",
	"set_data uploads content separately")
require_text(lua_vmanip, "vm->m_data[i].param2 = param2;",
	"set_param2_data uploads param2 separately")
require_text(lua_vmanip,
	"(vm->m_flags[i] & VOXELFLAG_NO_DATA) ? CONTENT_IGNORE : vm->m_data[i].getContent();",
	"get_data exposes only no-data state through content")
assert(not lua_vmanip:find("luamethod(LuaVoxelManip, get_flags)", 1, true),
	"unexpected VoxelManip flag accessor exists")
assert(not lua_vmanip:find("luamethod(LuaVoxelManip, get_voxel_flags)", 1, true),
	"unexpected VoxelManip voxel-flag accessor exists")
assert(not lua_vmanip:find("luamethod(LuaVoxelManip, get_dungeon_flags)", 1, true),
	"unexpected dungeon flag accessor exists")
local vmanip_methods = assert(lua_vmanip:match(
	"const luaL_Reg LuaVoxelManip::methods%[%] = {(.-){0,0}"),
	"missing LuaVoxelManip method registry")
assert(not vmanip_methods:lower():find("flag", 1, true),
	"unexpected flag-bearing VoxelManip method exists")
assert(not vmanip_methods:lower():find("dungeon", 1, true),
	"unexpected dungeon-bearing VoxelManip method exists")
require_order(mapgen_v7, "placeAllOres(this", "generateDungeons(stone_surface_max_y)",
	"v7 ores precede dungeons")
require_order(mapgen_v7, "generateDungeons(stone_surface_max_y)", "placeAllDecos(this",
	"v7 dungeons precede decorations")
require_order(emerge, "m_mapgen->makeChunk(&bmdata);",
	"m_script->on_generated(&bmdata, m_mapgen->blockseed);",
	"native makeChunk precedes Lua mapgen callback")
require_text(dungeon,
	"VMANIP_FLAG_DUNGEON_INSIDE " .. string.char(124) ..
		" VMANIP_FLAG_DUNGEON_PRESERVE",
	"DungeonGen uses internal VoxelManipulator flags")
require_order(dungeon, "makeRoom(roomsize, roomplace);",
	"gennotify->addEvent(dp.notifytype, room_center);",
	"room write precedes room-center notification")
require_text(dungeon, "gennotify->addEvent(dp.notifytype, room_center);",
	"DungeonGen notifies only the room center")
assert(count_text(dungeon, "gennotify->addEvent") == 1,
	"unexpected additional DungeonGen notification payload exists")
require_text(dungeon, "void DungeonGen::makeCorridor", "DungeonGen builds corridors")
require_text(dungeon, "void DungeonGen::makeHole", "DungeonGen builds door/stair holes")
require_text(dungeon, "if (vm->m_data[i].getContent() == dp.c_wall)",
	"alternative-wall pass selects by content")
require_text(mapgen, "PseudoRandom ps(blockseed + 70033);",
	"MapgenBasic derives dungeon parameters with C++ random state")
require_text(mapgen, "dgen.generate(vm, blockseed, full_node_min, full_node_max);",
	"DungeonGen receives the full emerged VoxelManip range")
require_text(dungeon_h, "PseudoRandom random;", "DungeonGen owns C++ random state")
require_text(biomes, 'node_dungeon = "default:cobble"',
	"current biome dungeon wall registration")
require_text(biomes, 'node_dungeon_alt = "default:mossycobble"',
	"current biome alternate dungeon wall registration")
require_text(biomes, 'node_dungeon_stair = "stairs:stair_cobble"',
	"current biome dungeon stair registration")
assert(count_text(biomes, "node_dungeon = dungeon_nodes.node_dungeon") == 5,
	"not every current biome registration uses the audited dungeon wall")
assert(count_text(biomes, "node_dungeon_alt = dungeon_nodes.node_dungeon_alt") == 5,
	"not every current biome registration uses the audited alternate wall")
assert(count_text(biomes,
	"node_dungeon_stair = dungeon_nodes.node_dungeon_stair") == 5,
	"not every current biome registration uses the audited dungeon stair")

require_text(constants_h, "#define MAP_BLOCKSIZE 16", "mapblock size is 16 nodes")
require_text(emerge, "v3s16 chunk_offset = -chunksize / 2;",
	"containing chunks use the negative half-chunksize offset")
require_text(emerge,
	"return getContainerPos(blockpos - chunk_offset, chunksize)\n\t\t* chunksize + chunk_offset;",
	"containing chunks use the pinned lattice formula")
require_text(map_settings_test,
	"/" .. "/ origin chunk goes from (-2, -2, -2) -> (3, 3, 3) excl",
	"chunksize-five origin lattice fixture")
require_text(map_settings_test,
	"GET(v3s16(0, -3, 0)), v3s16(-2, -7, -2)",
	"chunksize-five negative lattice fixture")
require_text(servermap_h, "constexpr static v3s16 EMERGE_EXTRA_BORDER{1, 1, 1};",
	"mapgen uses a one-mapblock emerge border")
require_text(servermap,
	"const v3s16 full_bpmin = bpmin - EMERGE_EXTRA_BORDER;",
	"full VoxelManip minimum includes the emerge border")
require_text(servermap,
	"const v3s16 full_bpmax = bpmax + EMERGE_EXTRA_BORDER;",
	"full VoxelManip maximum includes the emerge border")
require_text(servermap, "data->vmanip->blitBackAll(changed_blocks);",
	"finishBlockMake blits the complete VoxelManip")
require_text(servermap, "Border blocks are grabbed during",
	"emerged border blocks are not marked generated")
require_text(mapgen_v7, "node_min = blockpos_min * MAP_BLOCKSIZE;",
	"central node minimum formula")
require_text(mapgen_v7,
	"node_max = (blockpos_max + v3s16(1, 1, 1)) * MAP_BLOCKSIZE - v3s16(1, 1, 1);",
	"central node maximum formula")
require_text(mapgen_v7, "full_node_min = (blockpos_min - 1) * MAP_BLOCKSIZE;",
	"full node minimum formula")
require_text(mapgen_v7,
	"full_node_max = (blockpos_max + 2) * MAP_BLOCKSIZE - v3s16(1, 1, 1);",
	"full node maximum formula")
require_text(mapgen,
	"if (node_min.Y > max_stone_y || node_min.Y > dungeon_ymax ||\n\t\t\tnode_max.Y < dungeon_ymin)",
	"dungeon eligibility uses central-slice ymin/ymax")
require_text(mapgen_v7_h, "s16 dungeon_ymin = -31000;",
	"pinned default dungeon minimum")
require_text(mapgen_v7_h, "s16 dungeon_ymax = 31000;",
	"pinned default dungeon maximum")
require_text(mapgen_v7,
	'settings->getS16NoEx("mgv7_dungeon_ymin",           dungeon_ymin);',
	"v7 reads the dungeon minimum setting")
require_text(mapgen_v7,
	'settings->getS16NoEx("mgv7_dungeon_ymax",           dungeon_ymax);',
	"v7 reads the dungeon maximum setting")
require_text(mapgen_v7,
	'settings->getNoiseParams("mgv7_np_dungeons",        np_dungeons);',
	"v7 reads the dungeon noise setting")
require_text(mapgen_v7,
	"np_dungeons          (0.9,   0.5,   v3f(500,  500,  500),  0,     2, 0.8,  2.0)",
	"pinned v7 dungeon-noise default")
require_text(settingtypes,
	"mgv7_dungeon_ymin (Dungeon minimum Y) int -31000 -31000 31000",
	"documented dungeon-minimum range")
require_text(settingtypes,
	"mgv7_dungeon_ymax (Dungeon maximum Y) int 31000 -31000 31000",
	"documented dungeon-maximum range")
require_text(baseline_map_meta, "mgv7_dungeon_ymin = -31000",
	"pre-WP40 baseline dungeon minimum")
require_text(baseline_map_meta, "mgv7_dungeon_ymax = 31000",
	"pre-WP40 baseline dungeon maximum")

local stratum_hosts = {
	"default:stone",
	"grug_materials:slate",
	"grug_materials:basalt",
	"grug_materials:granite",
	"grug_materials:emberrock",
	"grug_materials:abyssal_rock",
}
local dungeon_nodes = {
	"default:cobble",
	"default:mossycobble",
	"stairs:stair_cobble",
}
local host_set = {}
for i = 1, #stratum_hosts do
	local name = stratum_hosts[i]
	host_set[name] = true
	require_text(material_registry, 'node = "' .. name .. '"',
		"WP43 final stratum host " .. name)
end
for i = 1, #dungeon_nodes do
	assert(not host_set[dungeon_nodes[i]],
		"dungeon registration overlaps a final stratum host")
end
require_text(material_init, "is_ground_content = true,",
	"owned stratum nodes remain DungeonGen-compatible ground")
require_text(mapgen_ores, "for i = 2, #grug_materials.TIERS do",
	"all five owned strata are registered in native mapgen")
require_text(mapgen_ores, 'ore_type = "stratum"',
	"owned strata use the engine stratum registration")
require_text(mapgen_ores, 'wherein = "default:stone"',
	"owned strata replace only the tier-one final host")
require_text(material_ores,
	"groups = {grug_natural = 1, grug_resource = resource.harvest_tier}",
	"owned resource nodes carry the natural resource groups")
require_text(material_ores, "is_ground_content = true,",
	"owned resource nodes remain DungeonGen-compatible ground")

print("WP40 dungeon source audit: PASS")
print("- Native v7 runs ores, dungeons, decorations, then Lua on_generated")
print("- Lua MapgenObject surface contains gennotify but no dungeon mask object")
print("- Lua VoxelManip exposes content/node/param2/emerged area but no flag accessor")
print("- DungeonGen uses private VM flags and emits room-center events")
print("- DungeonGen owns its C++ PseudoRandom state")
print("- Current shared dungeon node names cannot establish writer provenance")
print("- chunksize=5 yields the pinned negative-coordinate owner lattice and one-block VM collar")
print("- Dungeon eligibility compares the central slice to configured ymin/ymax, then writes the full VM")
print("- Pinned default and pre-WP40 baseline dungeon limits are audited before the -193 contract")
print("- Current explicit dungeon nodes are disjoint from all six exact WP43 stratum hosts")
