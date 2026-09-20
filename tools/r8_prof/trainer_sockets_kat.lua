-- Real-code KAT for the twelve projected profession-trainer socket rosters.

return function(repo)
	local saved = {core = rawget(_G, "core"), vector = rawget(_G, "vector"),
		grug_core = rawget(_G, "grug_core")}
	core = {dir_to_yaw = function() return 0 end}
	vector = {new = function(x, y, z) return {x = x, y = y, z = z} end}
	grug_core = {}
	dofile(repo .. "/mods/CORE/grug_core/settlement_sockets.lua")
	local sample = {id = "trainer_alchemist", role = "trainer",
		profession = "alchemist", x = 1, y = 1, z = -12,
		dir = {x = -1, z = 0}}
	local registered = grug_core.register_settlement_sockets("trainer_test",
		"trainer_race", {x = 10, y = 20, z = 30}, {sample})
	local copy = grug_core.settlement_sockets_at("trainer_test")[1]
	local bad = {id = "bad_trainer", role = "trainer", profession = "fishing",
		x = 0, y = 1, z = 0, dir = {x = 1, z = 0}}
	local bad_ok = pcall(grug_core.register_settlement_sockets, "bad_trainer_test",
		"bad_trainer_race", {x = 0, y = 0, z = 0}, {bad})
	rawset(_G, "core", saved.core)
	rawset(_G, "vector", saved.vector)
	rawset(_G, "grug_core", saved.grug_core)
	if registered ~= 1 or copy.profession ~= "alchemist" or bad_ok then
		error("r8 trainer sockets: socket registry validation differs", 0)
	end

	local settlement = dofile(repo ..
		"/mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua")
	local starts = {"hearthpine", "dawnmere", "silverleaf", "stillgrave",
		"sunscar", "kapok"}
	local capitals = {"highcourt", "dur_brannoc", "lethariel", "gor_drazhak",
		"kezamba", "nhal_veyr"}
	local professions = {weaponsmith = true, armorsmith = true, alchemist = true, tailor = true,
		leatherworker = true, woodcarver = true, goldsmith = true, cooking = true}
	local mutation = tonumber(os.getenv("R8_PROF_SOCKET_MUTATION") or "") or 0
	local report = {"registry\ttrainer accepted\tprofession copied\tunknown refused\n"}
	local function check(value, message)
		if not value then error("r8 trainer sockets: " .. message, 0) end
	end
	local profiles = {}
	for index = 1, #settlement.roster do
		profiles[settlement.roster[index].key] = settlement.roster[index]
	end
	local function projected(key)
		local profile = profiles[key]
		local path = repo .. "/mods/MAPGEN/grug_mapgen/wp40/" ..
			profile.blueprint_file
		local source = dofile(path)()
		local descriptors = settlement.descriptors(profile, source)
		local blueprints = {}
		for index = 1, #descriptors do
			local descriptor = descriptors[index]
			if descriptor.kind ~= "overlay" then
				local blueprint = descriptor.build()
				blueprints[#blueprints + 1] = {descriptor = descriptor,
					landmarks = blueprint.landmarks, reference = blueprint.reference}
			end
		end
		local prepared = {schema = "grug_wp13_settlement_prepared_v1",
			profile = profile, blueprints = blueprints}
		return settlement.sockets(prepared, {x = 0, y = 20, z = 0},
			function() return 20 end)
	end
	local function trainer_rows(rows)
		local result = {}
		for index = 1, #rows do
			if rows[index].role == "trainer" then result[#result + 1] = rows[index] end
		end
		return result
	end
	local function check_duplicate_positions(key, rows)
		if mutation == 2 and key == "hearthpine" then
			local trainers = trainer_rows(rows)
			trainers[1].x, trainers[1].y, trainers[1].z =
				rows[1].x, rows[1].y, rows[1].z
		end
		-- Existing patrol waypoints may intentionally share a resident's position;
		-- the regression under test is a trainer sharing ANY projected socket.
		local occupied = {}
		for index = 1, #rows do
			local row = rows[index]
			local position = row.x .. ":" .. row.y .. ":" .. row.z
			local previous = occupied[position]
			check(not previous or
					(previous.role ~= "trainer" and row.role ~= "trainer"),
				key .. " repeats trainer socket position " .. position .. " (" ..
					tostring(previous and previous.id) .. ", " .. row.id .. ")")
			occupied[position] = row
		end
		return #rows
	end
	local function authored_cells(key)
		local profile = profiles[key]
		local path = repo .. "/mods/MAPGEN/grug_mapgen/wp40/" ..
			profile.blueprint_file
		local source = dofile(path)
		if type(source) == "function" then source = source() end
		local cells = {}
		for _,descriptor in ipairs(settlement.descriptors(profile,source)) do
			if descriptor.kind~="overlay" then
				local blueprint=descriptor.build();local offset=descriptor.offset or {x=0,z=0}
				for _,cell in ipairs(blueprint.cells) do
					cells[(cell.x+offset.x)..":"..cell.y..":"..(cell.z+offset.z)]=cell.name
				end
			end
		end
		return cells
	end
	local function check_ground(key, cells, row)
		local prefix = row.x .. ":"
		local suffix = ":" .. row.z
		local ground = cells[prefix .. "0" .. suffix]
		check(ground ~= nil and ground ~= "air", key .. " trainer lacks ground")
		check(cells[prefix .. "1" .. suffix] == "air" and
			cells[prefix .. "2" .. suffix] == "air",
			key .. " trainer lacks two nodes of headroom")
	end
	for index = 1, #starts do
		local all_rows = projected(starts[index])
		local rows = trainer_rows(all_rows)
		if mutation == 1 and index == 1 then rows[1] = nil end
		check(#rows == 1, starts[index] .. " does not have exactly one trainer")
		local row = rows[1]
		check(row.role == "trainer" and row.profession == "cooking",
			starts[index] .. " trainer differs")
		check(row.y == 1 and math.abs(row.x) <= 2 and math.abs(row.z) == 10,
			starts[index] .. " trainer left the five-wide main street")
		check_ground(starts[index], authored_cells(starts[index]), row)
		local total = check_duplicate_positions(starts[index], all_rows)
		report[#report + 1] = table.concat({"start", starts[index], row.profession,
			row.x, row.y, row.z, "ground+headroom",
			"trainer_unique_against=" .. total}, "\t") .. "\n"
	end
	for index = 1, #capitals do
		local all_rows = projected(capitals[index])
		local rows = trainer_rows(all_rows)
		local cells = authored_cells(capitals[index])
		local riding, stations = 0, 0
		for _, row in ipairs(all_rows) do
			if row.role == "riding_trainer" then
				riding = riding + 1
				check_ground(capitals[index], cells, row)
			elseif row.role == "public_station" then stations = stations + 1 end
		end
		check(riding == 1 and stations == 7, capitals[index] .. " Riding/public station roster differs")
		check(#rows == 8, capitals[index] .. " does not have eight trainers")
		local seen = {}
		for row_index = 1, #rows do
			local row = rows[row_index]
			check(row.role == "trainer" and professions[row.profession],
				capitals[index] .. " has an invalid trainer")
			check(not seen[row.profession], capitals[index] .. " repeats a trainer")
			seen[row.profession] = true
			check(row.y == 1 and row.id:find("/",1,true) and
				(math.abs(row.x)>49 or math.abs(row.z)>49),
				capitals[index] .. " trainer is not in an outer plot")
			check_ground(capitals[index], cells, row)
		end
		local alchemist
		for row_index = 1, #rows do
			if rows[row_index].profession == "alchemist" then alchemist = rows[row_index] end
		end
		check(alchemist~=nil, capitals[index] .. " alchemist missing")
		local total = check_duplicate_positions(capitals[index], all_rows)
		report[#report + 1] = table.concat({"capital", capitals[index],
			"trainers=8+riding=1+stations=7", "outerplots+ground+headroom", "trainer_unique_against=" .. total}, "\t") .. "\n"
	end
	return table.concat(report)
end
