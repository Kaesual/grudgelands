-- Round 58 lane HALLS portable test: the Miner's Guild house in the six
-- capitals (docs/design/settlements.md "The Miner's Guild houses").
--   A. each capital builds exactly one guild house: its roster places
--      `<capital>_miners_guild` once, the civic core publishes the hall's
--      sockets and no district plot does. The house stands in the core,
--      which is anchor-relative and the same in every world: the capital
--      planner only places the kit's district plots round it, so every
--      seed's plan has this one house (the seed fleet builds the capitals
--      per seed);
--   B. the hall socket contract (capital_services.lua M.GUILD_HALL): the
--      leader on a `quest` socket, the exchange counter on an inhabited
--      `idle` socket tagged `work` (the shape a service socket takes over,
--      grug_core.assign_service_socket), three inhabited residents, each id
--      once; the template carries the same points;
--   C. the points are reachable: a walk over the finished core (the node
--      registry's `walkable`, doors passable, the standing rule of
--      building-template-format.md §3.4) from the core's arrival reaches the
--      house's door and every hall socket;
--   D. the template file is make_halls.py's output (the header says so) and
--      lists the placing race.
--
-- Usage (repo root): luajit tools/r58_halls/portable_test.lua [REPO]
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
	{key = "highcourt", race = "human"}, {key = "dur_brannoc", race = "dwarf"},
	{key = "lethariel", race = "elf"}, {key = "nhal_veyr", race = "undead"},
	{key = "gor_drazhak", race = "orc"}, {key = "kezamba", race = "troll"},
}

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
check(HALL.plot == "miners_guild" and HALL.leader == "miners_guild_leader" and
	HALL.exchange == "miners_guild_exchange" and #HALL.residents == 3,
	"capital_services.GUILD_HALL")

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

	-- A. only the core publishes the hall --------------------------------------
	local kit = capital.kit(key)
	for _, plot in ipairs(kit.plots) do
		for _, socket in ipairs(plot.build().landmarks.sockets or {}) do
			check(not socket.id:find("miners_guild", 1, true),
				key .. " " .. plot.id .. ": no hall socket in a district plot")
		end
	end
	local bp = kit.core.build()
	local by_id, seen = {}, {}
	for _, socket in ipairs(bp.landmarks.sockets) do
		check(not seen[socket.id], key .. ": socket " .. socket.id .. " once")
		seen[socket.id] = true
		by_id[socket.id] = socket
	end
	-- B. the contract on the built core
	local leader = by_id[HALL.leader]
	check(leader and leader.role == "quest" and leader.spawn ~= false,
		key .. ": the leader stands on a quest socket")
	local exchange = by_id[HALL.exchange]
	check(exchange and exchange.role == "idle" and exchange.spawn ~= false and
		exchange.tags and exchange.tags[1] == "work",
		key .. ": the exchange counter is an inhabited idle socket tagged work")
	for _, id in ipairs(HALL.residents) do
		local socket = by_id[id]
		check(socket and socket.role == "idle" and socket.spawn ~= false,
			key .. ": the resident " .. id)
	end
	local hall_sockets = 0
	for id in pairs(by_id) do
		if id:find("^miners_guild_") then hall_sockets = hall_sockets + 1 end
	end
	check(hall_sockets == 2 + #HALL.residents, key .. ": five hall sockets (" ..
		hall_sockets .. ")")
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

	-- C. reachability over the finished core -------------------------------------
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
		check(reachable(by_id[id]), key .. ": " .. id .. " is reachable")
	end
end

print(("r58_halls portable test: %d checks passed"):format(checks))
