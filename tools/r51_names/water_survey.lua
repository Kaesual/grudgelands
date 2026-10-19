-- Round 51 lane NAMES: which zone belts touch sea water and which touch
-- rivers and lakes, per seed, without the engine (LuaJIT).
--
--   luajit tools/r51_names/water_survey.lua <repo> <seed> > <out.json>
--
-- Builds the analytic world of the seed once (tools/r28_zone_atlas/world.lua,
-- as the game builds it), then per recipe zone runs the game's own region
-- builder (spawn_regions_core.lua) on the shipped recipe and counts, per
-- belt, its land cells and the cells whose terrain type is `shore` (at least
-- 25 % of the cell's land samples within 16 nodes of sea water) or `bank`
-- (the same for rivers and lakes; a cell that is both counts as shore, the
-- builder's first match), and the bank cells whose majority biome is swamp.
-- The types are the terrain's, independent of the recipe's kinds. The page
-- builder (build.py) reads the committed outputs in survey/.
local repo, seed = arg[1], arg[2]
assert(repo and seed, "usage: water_survey.lua <repo> <seed>")

local t0 = os.clock()
local W = dofile(repo .. "/tools/r28_zone_atlas/world.lua")(repo, seed)
local world_seconds = os.clock() - t0
local core = dofile(repo .. "/mods/ENTITIES/grug_mobs/spawn_regions_core.lua")
local json = dofile(repo .. "/tools/r28_b1/json.lua")
local S = W.session

local function read(path)
	local f = assert(io.open(path, "rb"))
	local text = f:read("*a")
	f:close()
	return text
end

local catalogue = {}
do
	local data = json.parse(read(repo .. "/mods/ENTITIES/grug_mobs/data/subtypes.json"))
	if not data[1] then data = data.subtypes end
	for _, row in ipairs(data) do catalogue[row.role] = row end
end

_G.core = _G.core or {}
local settlement = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua")
local labels = {}
for _, row in ipairs(settlement.roster) do
	if row.anchor_id then labels[row.anchor_id] = row.label end
end
local q = core.queries({zones = S, column_values_at = W.planner_source.column_values_at,
	road_polylines = W.wp40.road_polylines, source = W.source})

local zone_ids = {}
for _, row in ipairs(W.source.zones) do zone_ids[#zone_ids + 1] = row.id end

local out = {}
local t1 = os.clock()
for _, zone in ipairs(zone_ids) do
	local record = S.get(zone)
	local data = json.parse(read(repo .. "/mods/ENTITIES/grug_mobs/data/zones/" .. zone .. ".spawns.json"))
	local recipe = core.parse_recipe(zone, data.recipe, {
		band = {record.level_min, record.level_max},
		role_levels = function(role) return catalogue[role] and catalogue[role].levels end,
		leader = function(role) return catalogue[role] ~= nil and catalogue[role].leader == true end,
		pois = function(id) return core.zone_pois(W.source, id, labels) end,
	})
	local map = core.build(zone, q, recipe)
	local belts = {}
	for i, b in ipairs(data.recipe.belts) do
		belts[i] = {id = b.id, levels = b.levels, land = 0, shore = 0, bank = 0, swamp_bank = 0}
	end
	for _, c in ipairs(map.order) do
		local b = belts[c.belt]
		if b then
			b.land = b.land + 1
			if c.type == "shore" then
				b.shore = b.shore + 1
			elseif c.type == "bank" then
				b.bank = b.bank + 1
				if c.biome == "swamp" then b.swamp_bank = b.swamp_bank + 1 end
			end
		end
	end
	out[#out + 1] = {zone = zone, band = {record.level_min, record.level_max}, belts = belts}
end

-- Deterministic JSON by hand (fixed key order).
local function list(t)
	local parts = {}
	for i = 1, #t do parts[i] = tostring(t[i]) end
	return "[" .. table.concat(parts, ",") .. "]"
end
local lines = {}
lines[#lines + 1] = ('{"seed":"%s","world_seconds":%.1f,"regions_seconds":%.1f,"zones":['):format(
	seed, world_seconds, os.clock() - t1)
for zi, z in ipairs(out) do
	local bl = {}
	for i, b in ipairs(z.belts) do
		bl[i] = ('{"id":"%s","levels":%s,"land":%d,"shore":%d,"bank":%d,"swamp_bank":%d}'):format(
			b.id, list(b.levels), b.land, b.shore, b.bank, b.swamp_bank)
	end
	lines[#lines + 1] = (' {"zone":"%s","band":%s,"belts":[%s]}%s'):format(
		z.zone, list(z.band), table.concat(bl, ","), zi < #out and "," or "")
end
lines[#lines + 1] = "]}"
io.write(table.concat(lines, "\n"), "\n")
