-- Round 84 SITE (read-only study): what lies round the map centre on one seed,
-- and what a fixed arena anchor there would move. The real mapgen runtime of
-- the seed fleet (tools/seed_fleet/runtime.lua, LuaJIT, no engine); nothing
-- shipped is changed: the arena variants patch the authored source's text in
-- memory when the runtime loads it.
--
--   luajit tools/r84_site/site.lua <repo> <seed> <outdir> <variant> [step]
--     variant  base      the shipped world
--              arena     plus one fixed anchor at (0, 0): zone 35, a generic
--                        POI profile with a 100-node building core (the
--                        dragon arenas' mechanism: a fixed anchor with its
--                        own levelling); the roads keep their usual reserve
--                        round its core, so the middle road bends round it
--              through   as arena, but the roads get no reserve round it, so
--                        the middle road may run through (ruling 6)
--              nofield   as arena, but hidden from the natural world's
--                        readers of the fixed anchors (the zone field's key
--                        points, the terrain field's bowls, the inland
--                        water's keep-outs and detours): only the placement
--                        gaps, its own levelling and the road reserve see it
--              nofield_through   nofield without the road reserve
--     step     the whole-world grid's spacing in nodes (default 8)
-- Writes into <outdir>: meta.tsv, anchors.tsv, roads.tsv (every centreline
-- point of every road), world.txt (the whole-world grid, one line per x:
-- zone index, height*4, water class code, water depth per z), centre.tsv
-- (every column within 256 of (0, 0): height, zone, water class, depth) and
-- the four layout texts (placement, water, road, capital).
local repo, seed, out, variant, step = arg[1], arg[2], arg[3], arg[4] or "base",
	tonumber(arg[5] or 8)
assert(repo and seed and out, "usage: site.lua <repo> <seed> <outdir> <variant> [step]")
local VARIANTS = {base = true, arena = true, through = true, nofield = true, nofield_through = true}
assert(VARIANTS[variant], "variant")
local NO_RESERVE = variant == "through" or variant == "nofield_through"
local NO_FIELD = variant == "nofield" or variant == "nofield_through"
arg = {repo}

local ARENA_ID = nil
local ARENA_ZONE, ARENA_CORE, ARENA_FIT, ARENA_BLEND = 35, 100, 160, 240

local saved_dofile = dofile
local function read(path)
	local f = assert(io.open(path, "rb"))
	local text = f:read("*a")
	f:close()
	return text
end
local function once(text, pattern, replacement)
	local result, count = text:gsub(pattern, replacement)
	assert(count == 1, "patch pattern matched " .. count .. " times: " .. pattern)
	return result
end
if variant ~= "base" then
	local function patched_source(path)
		local text = read(path)
		-- one more anchor row at the end (anchor_145), fixed at (0, 0)
		text = once(text, '(\t{32,"camp_construction","camp_construction","placed","high",2},\n)}',
			'%1\t{' .. ARENA_ZONE .. ',"arena","arena","authored_fixed",0,0,0},\n}')
		-- its profile: a gentle-grade POI with a 100-node flat core
		text = once(text, '(\t{id="camp_construction",[^\n]*\n)',
			'%1\t{id="arena",shape="gentle_grade",building_core_width=' .. ARENA_CORE ..
			',fitting_width=' .. ARENA_FIT .. ',blend_width=' .. ARENA_BLEND ..
			',force_native_dungeon=false},\n')
		return assert(loadstring(text, "@" .. path .. " (r84 arena patch)"))()
	end
	-- the natural world's readers of the fixed anchors, told to skip the arena
	rawset(_G, "R84_HIDE", function(list)
		local kept = {}
		for _, a in ipairs(list) do
			if a.id ~= ARENA_ID then kept[#kept + 1] = a end
		end
		return kept
	end)
	local FIELD_PATCHES = {
		["/zone_field%.lua$"] = {{"for _, a in ipairs%(source%.fixed_anchors or source%.anchors%) do",
			"for _, a in ipairs(R84_HIDE(source.fixed_anchors or source.anchors)) do"}},
		["/height%.lua$"] = {{"anchors = source%.fixed_anchors or source%.anchors,",
			"anchors = R84_HIDE(source.fixed_anchors or source.anchors),"},
			{"local fixed_anchors = source%.fixed_anchors or source%.anchors\n",
			"local fixed_anchors = R84_HIDE(source.fixed_anchors or source.anchors)\n"}},
	}
	local road_wrapped = {}
	rawset(_G, "dofile", function(path)
		if type(path) == "string" and path:match("/source/simple_map%.lua$") then
			local source = patched_source(path)
			ARENA_ID = source.anchors[#source.anchors].id
			return source
		end
		if NO_FIELD and type(path) == "string" then
			for pattern, patches in pairs(FIELD_PATCHES) do
				if path:match(pattern) then
					local text = read(path)
					for _, patch in ipairs(patches) do text = once(text, patch[1], patch[2]) end
					return assert(loadstring(text, "@" .. path .. " (r84 nofield patch)"))()
				end
			end
		end
		local result = saved_dofile(path)
		if NO_RESERVE and type(path) == "string" and path:match("/road_layout%.lua$") and
				type(result) == "table" and not road_wrapped[result] then
			road_wrapped[result] = true
			local inputs = result.inputs
			result.inputs = function(...)
				local r = inputs(...)
				local kept = {}
				for _, row in ipairs(r.reserved) do
					if row.id ~= ARENA_ID then kept[#kept + 1] = row end
				end
				assert(#kept == #r.reserved - 1, "arena reserve not found")
				r.reserved = kept
				return r
			end
		end
		return result
	end)
end

local t0 = os.clock()
local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
local t_build = os.clock() - t0
-- the wrapper stays installed: anything the runtime loads later sees the same
-- source (the shipped one, or the patched one with the arena)
local Z = R.built.zones_session
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local SOURCE = dofile(wp40 .. "/source/simple_map.lua")
local B = SOURCE.world_bounds
local profile = {}
for _, p in ipairs(SOURCE.anchor_profiles) do profile[p.id] = p end

local function open(name)
	return assert(io.open(out .. "/" .. name, "w"))
end

-- layout texts
for _, k in ipairs({"placement", "water", "road", "capital"}) do
	local f = open(k .. ".txt")
	f:write(R.main[k .. "_layout_text"]() or "")
	f:close()
end

-- anchors (every one, with its world position and fitted y)
local f = open("anchors.tsv")
for _, a in ipairs(SOURCE.anchors) do
	local zr = SOURCE.zones[a.zone_numeric_id]
	local w = Z.anchor(zr.id, a.slot_id)
	local p = profile[a.template_id]
	f:write(table.concat({a.id, a.zone_numeric_id, zr.id, a.slot_id, a.template_id,
		a.placement_mode, w and w.x or "nil", w and w.z or "nil", w and w.y or "nil",
		p.building_core_width or p.civic_width or 0, p.fitting_width or 0}, "\t"), "\n")
end
f:close()

-- roads: every centreline point
local roads = dofile(wp40 .. "/road_layout.lua")
local L = roads.deserialize(R.main.road_layout_text())
f = open("roads.tsv")
for _, r in ipairs(L.roads) do
	for i = 1, #r.X do
		f:write(r.id, "\t", r.kind, "\t", tostring(r.a), "\t", tostring(r.b), "\t",
			("%.2f"):format(r.X[i]), "\t", ("%.2f"):format(r.Z[i]), "\t",
			("%.2f"):format((r.R and r.R[i]) or 0), "\t", tostring(r.hw or ""), "\n")
	end
end
f:close()

-- zone index of an id (0 = none)
local zindex = {}
for i, zr in ipairs(SOURCE.zones) do zindex[zr.id] = i end
local WCODE = {lake = 1, river = 2, bay = 3, belt = 4, channel = 5, open_sea = 6}

-- whole-world grid
local t1 = os.clock()
f = open("world.txt")
f:write(("# step %d min_x %d max_x %d min_z %d max_z %d\n"):format(step, B.min_x, B.max_x,
	B.min_z, B.max_z))
for x = B.min_x, B.max_x, step do
	local buf = {}
	for z = B.min_z, B.max_z, step do
		local h = Z.terrain_height_at(x, z)
		local cls, _, _, _, depth = Z.water_query_at(x, z)
		local id = Z.id_at(x, z)
		buf[#buf + 1] = (id and zindex[id] or 0) .. ":" .. (h and math.floor(h * 4 + 0.5) or "n") ..
			":" .. (cls and WCODE[cls] or 0) .. ":" .. (depth or 0)
	end
	f:write(table.concat(buf, " "), "\n")
end
f:close()
local t_world = os.clock() - t1

-- the centre, every column within 256 nodes
t1 = os.clock()
f = open("centre.tsv")
for z = -256, 256 do
	local buf = {}
	for x = -256, 256 do
		local h = Z.terrain_height_at(x, z)
		local cls, _, _, _, depth = Z.water_query_at(x, z)
		local id = Z.id_at(x, z)
		buf[#buf + 1] = x .. "\t" .. z .. "\t" .. (h and ("%.2f"):format(h) or "nil") .. "\t" ..
			(id and zindex[id] or 0) .. "\t" .. (cls and WCODE[cls] or 0) .. "\t" .. (depth or 0)
	end
	f:write(table.concat(buf, "\n"), "\n")
end
f:close()
local t_centre = os.clock() - t1

f = open("meta.tsv")
f:write("seed\t", seed, "\nvariant\t", variant, "\nstep\t", step, "\narena_id\t",
	tostring(ARENA_ID), "\nbuild_s\t", ("%.1f"):format(t_build), "\nworld_s\t",
	("%.1f"):format(t_world), "\ncentre_s\t", ("%.1f"):format(t_centre), "\n")
f:close()
print("done", seed, variant, ("build %.1f world %.1f centre %.1f"):format(t_build, t_world,
	t_centre))
