-- Round 47 lane NZ: the NPC facing check (round47-plan.md ruling 20, §4.9).
-- LuaJIT, no engine. An NPC must not stand with its face to a wall: over
-- every composition the game builds that carries NPC sockets -- the six
-- starts (with their civic additions and start trainers), every Round 14
-- village, outpost and bandit camp (one per race), every Round 20 POI, the
-- Round 31 PvP fortresses and camps (a camp in every race of its faction,
-- since its race is rolled per world), every capital core and district plot
-- -- a socket fails when, looking along its facing, the first thing within
-- two nodes at head height is a solid wall node and no work feature stands
-- before it.
--
-- The rule, exactly:
--   * NPC sockets are the roles that place a standing NPC with an authored
--     facing (NPC_ROLES). A patrol waypoint turns with its route; displays,
--     stations and waypoints are no NPCs.
--   * The facing is the one the NPC gets: `dir`, turned round when a tag is
--     `door` (grug_mobs/start_npcs.lua `socket_face_yaw`).
--   * Distance 1, then 2: a work feature at feet or head height there passes
--     the socket; otherwise a solid node at head height (socket y + 1) fails
--     it. Something at feet height only (a low wall, a bench, a crate) does
--     not hide the NPC's face and is no wall. A `stall`'s counter is any
--     solid node at waist height with open air over it (a wall course under
--     a window is a wall, not a counter).
--   * Work features: the furniture and stations any NPC may face
--     (FEATURE_PATTERNS, plus the palette roles in FEATURE_ROLES), and per
--     work activity the feature the sockets contract names
--     (docs/research/wp13-npc-sockets-contract.md §8.1/8.2: a log for
--     `chop` and for `spar`'s drill posts, rock for `mine`, a grave marker
--     or a shrine's masonry for `pray`, ...). A cell the composition does
--     not write is open (terrain or a street).
--
--   luajit tools/r47_nz/facing.lua [REPO]   prints every failing socket
-- As a module: `dofile(path)` returns {compositions = fn(repo) -> list,
-- check = fn(composition, palettes) -> failure lines, run = fn(repo),
-- look, facing, grid, NPC_ROLES}.
local M = {}

M.NPC_ROLES = {guard_post = true, idle = true, work = true, quest = true,
	king = true, vendor = true, trainer = true, riding_trainer = true,
	shipwright = true, general = true, bodyguard = true, captain = true}

local RACES = {"dwarf", "human", "elf", "undead", "orc", "troll"}

-- Open at head height: nothing a face looks into. Plants, lights, fences,
-- leaves, and the half shapes (a slab or stair at head height is a
-- shelf, a counter top or a roof edge, never a wall).
local function open(name)
	if name == nil or name == "air" then return true end
	return name:find("^default:grass_") or name:find("^default:fern_") or
		name:find("^default:dry_grass_") or name == "default:dry_shrub" or
		name == "default:junglegrass" or name == "default:papyrus" or
		name:find("^flowers:") or name:find("torch") or name:find("lantern") or
		name:find("fence") or name:find("^stairs:") or name:find("_slab$") or
		name:find("_stair$") or name:find("_stair_") or name:find("leaves$") or
		name:find("needles$") or name:find("_ivy$") or name:find("vine") or
		name:find("cobweb") or name:find("rope") or name:find("straw_mat") or
		name:find("candle") or name:find("potted_") or name:find("stonepath") or
		name:find("rubble") or name:find("^default:water_") or
		name:find("^default:river_water_") or
		name:find("^farming:") ~= nil
end

-- Furniture and stations any NPC may stand at.
local FEATURE_PATTERNS = {"cauldron", "barrel", "anvil", "furnace",
	"brewing_stand", "^grug_jobs:", "counter", "workbench", "table", "shelf",
	"^beds:", "wagon_wheel", "straw_bale", "bone_pile", "chest", "bookshelf",
	"coalblock", "chair", "throne", "^grug_mapgen:poi_display_"}
local FEATURE_ROLES = {"workbench", "board_table", "hearth", "storage",
	"shelf", "shelf_vessels", "bale", "cargo", "wheel", "throne", "table_top"}

local function stone(name)
	return name:find("stone") or name:find("cobble") or name:find("brick") or
		name:find("^default:ore") or name:find("ore_") or name:find("_ore") or
		name:find("darkage_") or name:find("marble") or name:find("basalt") or
		name:find("obsidian") or name:find("block$") ~= nil
end
local function trunk(name)
	return name:find("tree$") ~= nil or name:find("_log") ~= nil
end
local function plant(name)
	return open(name) and name ~= "air" or name:find("leaves") ~= nil or
		name:find("hedge") ~= nil or name:find("mushroom") ~= nil or
		name:find("bush") ~= nil
end

-- The feature a work activity names (contract §8.1/8.2).
local ACTIVITY = {
	chop = trunk,
	carve = function(name) return trunk(name) or stone(name) end,
	mine = stone,
	smith = function(name) return name:find("anvil") or name:find("furnace") or
		name:find("iron_block") ~= nil end,
	fish = function(name) return name:find("water") ~= nil end,
	farm = function(name) return name:find("^farming:") or name:find("soil") or
		name:find("crop") ~= nil end,
	tend = plant, forage = plant,
	-- an altar or shrine is masonry, so rock counts as for `mine`
	pray = function(name) return name:find("^walls:") or name:find("^doors:") or
		name:find("candle") or name:find("altar") or stone(name) end,
	-- (Round 51 lane LK: the graves' markers are the gravestone blocks)
	mourn = function(name) return name:find("^walls:") or name:find("candle") or
		name:find("coffin") or name:find("bone") or name:find("gravestone") ~= nil end,
	-- the drill posts (`dressing.drill_post`) are logs
	spar = function(name) return name:find("fence") or name:find("^wool:") or
		trunk(name) end,
	-- `stall` is in `M.look`: a counter is any solid node at waist height
}

local function feature_set(palettes)
	local set = {}
	for _, race in ipairs(RACES) do
		local p = palettes.new(race)
		for _, role in ipairs(FEATURE_ROLES) do
			local name = p.maybe(role)
			if name then set[name] = true end
		end
	end
	return set
end

-- What a socket sees along (dx, dz) within `reach` nodes: "feature" or
-- "wall" with its distance, or "open". `at` maps "x:y:z" to a node name.
function M.look(at, s, dx, dz, reach, palettes)
	local features = M.features or feature_set(palettes)
	M.features = features
	local function is_feature(n)
		if n == nil or n == "air" then return false end
		if features[n] then return true end
		for _, pattern in ipairs(FEATURE_PATTERNS) do
			if n:find(pattern) then return true end
		end
		local own = s.role == "work" and ACTIVITY[s.activity]
		return own and own(n) and true or false
	end
	for d = 1, reach do
		local x, z = s.x + dx * d, s.z + dz * d
		local feet = at[x .. ":" .. s.y .. ":" .. z]
		local head = at[x .. ":" .. (s.y + 1) .. ":" .. z]
		if is_feature(head) then return "feature", d, head end
		if is_feature(feet) then return "feature", d, feet end
		if not open(head) then return "wall", d, head end
		-- `stall`: any solid node at waist height, under open air, is the counter
		if s.activity == "stall" and not open(feet) then return "feature", d, feet end
	end
	return "open", reach
end

-- The facing the NPC gets: `dir`, turned round by a `door` tag.
function M.facing(s)
	for _, tag in ipairs(s.tags or {}) do
		if tag == "door" then return -s.dir.x, -s.dir.z, true end
	end
	return s.dir.x, s.dir.z, false
end

function M.grid(comp)
	local at = {}
	for _, c in ipairs(comp.cells or {}) do at[c.x .. ":" .. c.y .. ":" .. c.z] = c.name end
	return at
end

-- One composition: {label, cells, sockets}; returns a list of failure lines.
function M.check(comp, palettes)
	local at = M.grid(comp)
	local fails = {}
	for _, s in ipairs(comp.sockets or {}) do
		if M.NPC_ROLES[s.role] then
			local dx, dz, door = M.facing(s)
			local what, d, node = M.look(at, s, dx, dz, 2, palettes)
			if what == "wall" then
				fails[#fails + 1] = ("%s\t%s\t%s\tfaces %s at %d (dir %d,%d%s)"):format(
					comp.label, s.id, s.role, node, d, s.dir.x, s.dir.z,
					door and ", door" or "")
			end
		end
	end
	return fails
end

-- Every composition with NPC sockets, in a fixed order.
function M.compositions(repo)
	_G.core = _G.core or {}
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local settlement = dofile(wp40 .. "/r7_settlement.lua")
	local list = {}
	local function add(label, bp, sockets)
		list[#list + 1] = {label = label, cells = bp.cells,
			sockets = sockets or (bp.landmarks and bp.landmarks.sockets) or {}}
	end
	local function copy(t)
		local out = {}
		for k, v in pairs(t) do out[k] = v end
		return out
	end
	local pvp_catalog = dofile(wp40 .. "/r31_pvp_catalog.lua")
	for _, profile in ipairs(settlement.roster) do
		local file = profile.blueprint_file
		if file == "r31_pvp_poi_blueprint.lua" then
			local races = profile.art.kind == "pvp_fortress" and {false} or
				pvp_catalog.FACTION_RACES[profile.art.faction]
			for _, race in ipairs(races) do
				local p = copy(profile)
				p.art = copy(profile.art)
				if race then p.art.race = race end
				add(profile.key .. (race and (":" .. race) or ""),
					dofile(wp40 .. "/" .. file)({}, p))
			end
		elseif profile.slot ~= "capital" then
			local bp = dofile(wp40 .. "/" .. file)({}, profile)
			if type(bp) == "function" then bp = bp({}) end
			if profile.slot == "start" then
				-- the start as the runtime builds it: its civic additions and
				-- the start trainers `r7_settlement.sockets` appends
				bp = dofile(wp40 .. "/r20_civic.lua")(bp, profile)
				local prepared = {schema = "grug_wp13_settlement_prepared_v1",
					profile = profile, blueprints = {{descriptor = {kind = "cells",
					id = "core"}, landmarks = bp.landmarks}}}
				add(profile.key, bp, settlement.sockets(prepared, {x = 0, y = 0, z = 0}))
			else
				add(profile.key, bp)
			end
		end
	end
	local capital = dofile(wp40 .. "/r7_capital_blueprint.lua")
	for _, key in ipairs({"highcourt", "dur_brannoc", "lethariel", "nhal_veyr",
			"gor_drazhak", "kezamba"}) do
		local kit = capital.kit(key)
		add(key .. "/core", kit.core.build())
		for _, plot in ipairs(kit.plots) do add(key .. "/" .. plot.id, plot.build()) end
	end
	return list
end

function M.run(repo)
	local palettes = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp13/palette.lua")
	local all, sockets = {}, 0
	local comps = M.compositions(repo)
	for _, comp in ipairs(comps) do
		for _, s in ipairs(comp.sockets) do
			if M.NPC_ROLES[s.role] then sockets = sockets + 1 end
		end
		for _, line in ipairs(M.check(comp, palettes)) do all[#all + 1] = line end
	end
	return all, #comps, sockets
end

if arg and arg[0] and arg[0]:match("facing%.lua$") then
	local fails, comps, sockets = M.run(arg[1] or ".")
	for _, line in ipairs(fails) do print(line) end
	io.stderr:write(("%d compositions, %d NPC sockets, %d facing a wall\n"):format(
		comps, sockets, #fails))
end
return M
