-- Round 74 lane MOUNT measurement (LuaJIT, not a fixture): how far the
-- flyable coastal strip reaches from the shore, and the flight rule's cost
-- per call before (the base's flight.lua, given as a file) and after.
--
--   luajit tools/r74_mount/coast.lua REPO OLD_FLIGHT_LUA [SEED ...]
--
-- Builds the zones session of each seed as tools/r57_fix56 does (about 10 s
-- a seed). Rays from the world's centre in 64 directions: along each, the
-- shore (the last land or planned-water column before the sea) and the open
-- sea or channel beyond it; the belt between is the strip that now takes the
-- zone's rule. Prints per seed the strip widths (min, median, max) and the
-- territory rule of the zones the strips belong to, then the rule's cost per
-- call on land, planned water, belt and open-sea columns, old and new.
local repo, old_flight = arg[1] or ".", arg[2]
local seeds = {}
for i = 3, #arg do seeds[#seeds + 1] = arg[i] end
if #seeds == 0 then seeds = {"12345", "42"} end

local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
rawset(_G, "core", rawget(_G, "core") or {})
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local A = dofile(dir .. "/world_assembly.lua")(dir, common.new_sha256())
local holder = {}
rawset(_G, "grug_zones", setmetatable({}, {__index = function(_, key)
	return holder.session[key]
end}))
-- Each version keeps its own grug_mounts table (its column query reads the
-- global at call time), swapped in before it is timed.
local function load_rule(path)
	local mounts = {}
	rawset(_G, "grug_mounts", mounts)
	dofile(path)
	return mounts
end
local new_rule = load_rule(repo .. "/mods/PLAYER/grug_mounts/flight.lua")
local old_rule = old_flight and load_rule(old_flight)
local clock = os.clock

local SEA = {deep_ocean = true, immutable_dragon_channel = true}
local SHORE = {land = true, planned_water = true}
for _, seed in ipairs(seeds) do
	local W = A.world(seed)
	local session = W.zones().new_with_planner_source_runtime(seed, 1)
	holder.session = session
	local widths, rules = {}, {}
	local samples = {land = {}, planned_water = {}, coastal_shelf = {}, deep_ocean = {}}
	for index = 0, 63 do
		local angle = index * math.pi / 32
		local dx, dz = math.cos(angle), math.sin(angle)
		local shore, sea
		for r = 0, 6000 do
			local x, z = math.floor(dx * r + 0.5), math.floor(dz * r + 0.5)
			local class = session.water_class_at(x, z)
			local list = samples[class]
			if list and #list < 2000 and r % 3 == 0 then list[#list + 1] = {x, z} end
			if SHORE[class] then
				shore, sea = r, nil
			elseif SEA[class] and shore and not sea then
				sea = r
				local bx, bz = math.floor(dx * (r - 1) + 0.5), math.floor(dz * (r - 1) + 0.5)
				local id = session.id_at(bx, bz)
				local zone = id and session.get(id)
				local rule = zone and zone.territory_rule or "none"
				rules[rule] = (rules[rule] or 0) + 1
				if r - shore > 1 then widths[#widths + 1] = r - shore - 1 end
			end
		end
	end
	table.sort(widths)
	local list = {}
	for rule, count in pairs(rules) do list[#list + 1] = rule .. "=" .. count end
	table.sort(list)
	print(("seed %s: %d rays reach the sea over a belt; strip width min %d, median %d, max %d nodes; zones %s")
		:format(seed, #widths, widths[1] or -1, widths[math.ceil(#widths / 2)] or -1,
			widths[#widths] or -1, table.concat(list, " ")))
	for _, class in ipairs({"land", "planned_water", "coastal_shelf", "deep_ocean"}) do
		local columns = samples[class]
		if #columns > 0 then
			local line = ("  %-14s %4d columns:"):format(class, #columns)
			for _, pair in ipairs({{"old", old_rule}, {"new", new_rule}}) do
				local mounts = pair[2]
				rawset(_G, "grug_mounts", mounts)
				local rule = mounts and mounts.column_flight_state
				if rule then
					local rounds = math.max(1, math.floor(200000 / #columns))
					for _, c in ipairs(columns) do rule("accord", c[1], c[2]) end
					local started = clock()
					for _ = 1, rounds do
						for i = 1, #columns do
							local c = columns[i]
							rule("accord", c[1], c[2])
						end
					end
					line = line .. (" %s %.2f us"):format(pair[1],
						(clock() - started) * 1e6 / (rounds * #columns))
				end
			end
			print(line)
		end
	end
end
