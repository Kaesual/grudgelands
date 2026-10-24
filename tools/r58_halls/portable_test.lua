-- Round 58 lanes HALLS and HALLS2 portable test: the Miner's Guild house in
-- the six capitals (docs/design/settlements.md "The Miner's Guild houses").
--   A. each capital builds exactly one guild house: its roster places
--      `<capital>_miners_guild` once, as the district plot `miners_guild` of
--      the district settlements.md names (HALLS2: out of the civic core,
--      which publishes no hall socket any more), and every planned seed
--      places that plot in every capital (the capital planner through
--      tools/r26_capitals/world.lua, as a world's first boot plans it; a
--      required plot, r7_capitals.lua) -- the seed fleet plans many more;
--   B. the hall socket contract (capital_services.lua M.GUILD_HALL): the
--      leader on a `quest` socket, the exchange counter on an inhabited
--      `idle` socket tagged `work` (the shape a service socket takes over,
--      grug_core.assign_service_socket), three inhabited residents, each id
--      once, every contract id the plot's own id prefixed by the plot
--      (`<plot>/<id>`, r7_settlement.lua M.sockets); the template carries
--      the same points;
--   C. the points are reachable: a walk over the finished plot (the node
--      registry's `walkable`, doors passable, the standing rule of
--      building-template-format.md §3.4) from the plot's arrival reaches the
--      house's door and every hall socket;
--   D. the template file is make_halls.py's output (the header says so),
--      lists the placing race and carries the picked guild art (its banner
--      and emblem nodes), the headframe and the ore yard.
--
-- Usage (repo root): luajit tools/r58_halls/portable_test.lua [REPO] [SEEDS]
-- SEEDS: a comma list of seeds to plan (default 1,7,58; "none" skips the
-- planner, about 17 s a seed).
local repo = arg[1] or "."
_G.core = _G.core or {}
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local BASE = repo .. "/mods/MAPGEN/grug_mapgen/building_templates"
local services = dofile(wp13 .. "/capital_services.lua")
local templates = dofile(wp13 .. "/templates.lua")(wp13)
local capital = dofile(wp40 .. "/r7_capital_blueprint.lua")
local HALL = services.GUILD_HALL
local CAPITALS = {
	{key = "highcourt", race = "human", district = "highcourt_market", guild = "charter"},
	{key = "dur_brannoc", race = "dwarf", district = "dur_brannoc_forge", guild = "charter"},
	{key = "lethariel", race = "elf", district = "lethariel_market", guild = "charter"},
	{key = "nhal_veyr", race = "undead", district = "nhal_veyr_market", guild = "oathdelvers"},
	{key = "gor_drazhak", race = "orc", district = "gor_drazhak_bazaar", guild = "oathdelvers"},
	{key = "kezamba", race = "troll", district = "shore", guild = "oathdelvers"},
}
local SEEDS = {}
for seed in (arg[2] or "1,7,58"):gmatch("[^,]+") do
	if seed ~= "none" then SEEDS[#SEEDS + 1] = tonumber(seed) end
end

-- The node registry's walkability (nodes.json: one node per line).
local walkable = {}
do
	local f = assert(io.open(repo .. "/tools/building_templates/nodes.json", "rb"))
	for line in f:lines() do
		local name, rest = line:match('^"([^"]+)":(%b{})')
		if name then
			walkable[name] = rest:match('"walkable":(%a+)') == "true"
		end
	end
	f:close()
end
check(walkable["default:stone"] == true and walkable["default:torch"] == false,
	"the node registry reads")

-- B. the contract constants --------------------------------------------------
check(HALL.plot == "miners_guild" and
	HALL.leader == "miners_guild/miners_guild_leader" and
	HALL.exchange == "miners_guild/miners_guild_exchange" and
	#HALL.residents == 3 and
	HALL.residents[1] == "miners_guild/miners_guild_clerk" and
	HALL.residents[2] == "miners_guild/miners_guild_sorter" and
	HALL.residents[3] == "miners_guild/miners_guild_porter",
	"capital_services.GUILD_HALL")
-- the plot's own socket id of a contract id (the settlement prefixes a
-- plot's sockets with `<plot id>/`)
local function own(id)
	local prefix = HALL.plot .. "/"
	check(id:sub(1, #prefix) == prefix, id .. ": prefixed by the plot id")
	return id:sub(#prefix + 1)
end

for _, cap in ipairs(CAPITALS) do
	local key = cap.key
	local name = key .. "_miners_guild"
	-- A. the roster places the house once ---------------------------------------
	local roster = templates.capital(key).roster
	local count = 0
	for _, use in ipairs(roster.uses) do
		if use.template:find("_miners_guild$") then
			check(use.template == name and use.count == 1,
				key .. ": the roster places " .. name .. " once")
			count = count + 1
		end
	end
	check(count == 1, key .. ": one guild house line in the roster")
	-- D. the template file
	local path = BASE .. "/templates/" .. name .. ".tpl"
	local f = assert(io.open(path, "rb"))
	local text = f:read("*a")
	f:close()
	check(text:find("tools/r58_halls/make_halls.py", 1, true) ~= nil,
		name .. ": written by make_halls.py")
	check(text:find("\nraces " .. cap.race .. "\n", 1, true) ~= nil,
		name .. ": races " .. cap.race)
	for _, id in ipairs({"leader", "exchange", "clerk", "sorter", "porter"}) do
		check(text:find("id={id}_" .. id .. " ", 1, true) ~= nil,
			name .. ": the point {id}_" .. id)
	end

	for _, entry in ipairs({"node grug_mapgen:guild_banner_" .. cap.guild,
			"node grug_mapgen:guild_emblem_" .. cap.guild, "node grug_mapgen:mine_rail",
			"node grug_mapgen:mine_cart", "node grug_decor:cottages_wagon_wheel",
			"node grug_decor:darkage_iron_grille"}) do
		check(text:find(" " .. entry, 1, true) ~= nil, name .. ": " .. entry)
	end
	check(not text:find("node wool:", 1, true), name .. ": no wool placeholder")

	-- A. the district plot, and only it, publishes the hall ------------------
	local kit = capital.kit(key)
	for _, socket in ipairs(kit.core.build().landmarks.sockets or {}) do
		check(not socket.id:find("miners_guild", 1, true),
			key .. ": no hall socket in the civic core (" .. socket.id .. ")")
	end
	local hall_plot
	for _, plot in ipairs(kit.plots) do
		if plot.id == HALL.plot then
			check(hall_plot == nil, key .. ": one plot " .. HALL.plot)
			hall_plot = plot
		else
			for _, socket in ipairs(plot.build().landmarks.sockets or {}) do
				check(not socket.id:find("miners_guild", 1, true),
					key .. " " .. plot.id .. ": no hall socket in another plot")
			end
		end
	end
	check(hall_plot and hall_plot.district == cap.district and hall_plot.kind == "plot",
		key .. ": the plot " .. HALL.plot .. " in the district " .. cap.district)
	local bp = hall_plot.build()
	local by_id, seen = {}, {}
	for _, socket in ipairs(bp.landmarks.sockets) do
		check(not seen[socket.id], key .. ": socket " .. socket.id .. " once")
		seen[socket.id] = true
		by_id[socket.id] = socket
	end
	-- B. the contract on the built plot
	local leader = by_id[own(HALL.leader)]
	check(leader and leader.role == "quest" and leader.spawn ~= false,
		key .. ": the leader stands on a quest socket")
	local exchange = by_id[own(HALL.exchange)]
	check(exchange and exchange.role == "idle" and exchange.spawn ~= false and
		exchange.tags and exchange.tags[1] == "work",
		key .. ": the exchange counter is an inhabited idle socket tagged work")
	for _, id in ipairs(HALL.residents) do
		local socket = by_id[own(id)]
		check(socket and socket.role == "idle" and socket.spawn ~= false,
			key .. ": the resident " .. id)
	end
	local hall_sockets, places = 0, 0
	for id, socket in pairs(by_id) do
		if id:find("^miners_guild_") then
			if socket.role == "quest_place" then places = places + 1 else hall_sockets = hall_sockets + 1 end
		end
	end
	-- the five, and the gate spot every plot publishes (`<plot>_gate_idle`);
	-- Round 60 CAPITALS: Nhal Veyr's plot also holds chapter 2's town place,
	-- a quest_place socket nobody stands on (settlements.md "Chapter 2's
	-- town place").
	check(hall_sockets == 3 + #HALL.residents, key .. ": six hall plot sockets (" ..
		hall_sockets .. ")")
	check(places == (key == "nhal_veyr" and 1 or 0), key .. ": the hall plot's town places (" .. places .. ")")
	local destination
	for _, spot in ipairs(bp.landmarks.destinations) do
		if spot.id == HALL.plot then destination = spot end
	end
	check(destination ~= nil, key .. ": the house is a destination")
	local door
	for _, d in ipairs(bp.landmarks.doors) do
		if d.id == HALL.plot then
			check(door == nil, key .. ": the house has one door")
			door = d
		end
	end
	check(door ~= nil, key .. ": the house's door")

	-- C. reachability over the finished plot -------------------------------------
	local by = {}
	for _, cell in ipairs(bp.cells) do by[cell.x .. "," .. cell.y .. "," .. cell.z] = cell.name end
	local b = bp.bounds
	local function passable(x, y, z)
		local n = by[x .. "," .. y .. "," .. z]
		if n == nil or n == "air" then return true end
		if n:sub(1, 6) == "doors:" then return true end
		local w = walkable[n]
		if w == nil then check(false, key .. ": " .. n .. " is in the node registry") end
		return not w
	end
	local function stand(x, y, z)
		if x < b.min.x or x > b.max.x or z < b.min.z or z > b.max.z then return false end
		return passable(x, y, z) and passable(x, y + 1, z) and not passable(x, y - 1, z)
	end
	local a = bp.landmarks.arrival
	check(stand(a.x, a.y, a.z), key .. ": the arrival is a standing cell")
	local reached = {[a.x .. "," .. a.y .. "," .. a.z] = true}
	local queue, head = {{a.x, a.y, a.z}}, 1
	while head <= #queue do
		local q = queue[head]
		head = head + 1
		for _, m in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
			for _, dy in ipairs({0, 1, -1}) do
				local x, y, z = q[1] + m[1], q[2] + dy, q[3] + m[2]
				local k = x .. "," .. y .. "," .. z
				-- a step up needs headroom over the cell it starts from
				if not reached[k] and stand(x, y, z) and
						(dy ~= 1 or passable(q[1], q[2] + 2, q[3])) then
					reached[k] = true
					queue[#queue + 1] = {x, y, z}
				end
			end
		end
	end
	local function reachable(p) return reached[p.x .. "," .. p.y .. "," .. p.z] == true end
	check(reachable(door), key .. ": the house's door is reachable from the arrival")
	check(reachable(destination), key .. ": the house's inside spot is reachable")
	check(reachable(leader), key .. ": the leader is reachable")
	check(reachable(exchange), key .. ": the exchange counter is reachable")
	for _, id in ipairs(HALL.residents) do
		check(reachable(by_id[own(id)]), key .. ": " .. id .. " is reachable")
	end
	check(reachable(by_id[HALL.plot .. "_gate_idle"]), key .. ": the plot's gate spot is reachable")
end

-- A. every planned seed places the house in every capital --------------------
if #SEEDS > 0 then
	local W = dofile(repo .. "/tools/r26_capitals/world.lua")(repo)
	for _, seed in ipairs(SEEDS) do
		local run = W.plan(seed)
		for _, cap in ipairs(CAPITALS) do
			local plan = run.plans[cap.key]
			check(plan ~= nil, seed .. " " .. cap.key .. ": planned")
			local placed
			for _, p in ipairs(plan.plots) do
				if p.id == HALL.plot then
					check(placed == nil, seed .. " " .. cap.key .. ": the house placed once")
					placed = p
				end
			end
			check(placed ~= nil and not placed.stand_in and placed.required == true,
				seed .. " " .. cap.key .. ": the house placed, a required plot")
			print(("seed %s %-11s miners_guild at %d,%d turns %d quadrant %d%s%s"):format(
				seed, cap.key, placed.x, placed.z, placed.turns, placed.quadrant,
				placed.overflow and " (overflow)" or "", placed.relaxed and " (relaxed)" or ""))
		end
	end
end

print(("r58_halls portable test: %d checks passed"):format(checks))
