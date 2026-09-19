-- Real-code KAT for trainer names across the twelve projected R7 settlements.
-- Usage: <lua> -e 'io.write(dofile(".../trainer_names_kat.lua")("/abs/repo"))'

return function(root)
	if type(root) ~= "string" or root:sub(1, 1) ~= "/" then
		error("R9-UI trainer-name KAT: absolute repository root required", 0)
	end
	local saved = {core = rawget(_G, "core"), grug_mobs = rawget(_G, "grug_mobs"),
		grug_jobs = rawget(_G, "grug_jobs"), grug_core = rawget(_G, "grug_core"),
		mobs = rawget(_G, "mobs")}
	local function restore()
		rawset(_G, "core", saved.core)
		rawset(_G, "grug_mobs", saved.grug_mobs)
		rawset(_G, "grug_jobs", saved.grug_jobs)
		rawset(_G, "grug_core", saved.grug_core)
		rawset(_G, "mobs", saved.mobs)
	end
	local function fail(message)
		restore()
		error("R9-UI trainer-name KAT: " .. message, 0)
	end
	local function check(value, message) if not value then fail(message) end end

	local settlement = dofile(root ..
		"/mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua")
	check(#settlement.roster == 12, "settlement roster count differs")

	local registered_mobs = {}
	rawset(_G, "core", {
		registered_items = {},
		global_exists = function() return false end,
		log = function() end,
		register_globalstep = function() end,
		register_on_mods_loaded = function() end,
		get_item_group = function() return 0 end,
	})
	rawset(_G, "grug_jobs", {})
	dofile(root .. "/mods/PLAYER/grug_jobs/registry.lua")

	local identities, seen_races = {}, {}
	for index = 1, #settlement.roster do
		local race = settlement.roster[index].race
		if not seen_races[race] then
			seen_races[race] = true
			identities[#identities + 1] = {race_id = race, faction_id = "accord"}
		end
	end
	rawset(_G, "grug_core", {
		start_identities = function() return identities end,
	})
	rawset(_G, "mobs", {
		mob_class = {},
		register_mob = function(_, name, definition)
			registered_mobs[name] = definition
		end,
	})
	rawset(_G, "grug_mobs", {
		storage = {
			get_string = function() return "" end,
			set_string = function() end,
		},
		noncombatant = function(definition) return definition end,
		set_plain_tag = function(entity, text) entity._kat_plain_tag = text end,
		face_yaw = function() end,
		start_npc_claim = function() return true end,
	})
	dofile(root .. "/mods/ENTITIES/grug_mobs/start_villagers.lua")
	dofile(root .. "/mods/ENTITIES/grug_mobs/start_npcs.lua")
	check(type(grug_mobs.install_profession_trainer) == "function",
		"production trainer install seam is absent")
	check(type(grug_mobs.start_npc_retag) == "function",
		"production retag seam is absent")

	local function projected(profile)
		local path = root .. "/mods/MAPGEN/grug_mapgen/wp40/" ..
			profile.blueprint_file
		local source = dofile(path)()
		local descriptors = settlement.descriptors(profile, source)
		local blueprints = {}
		for index = 1, #descriptors do
			local descriptor = descriptors[index]
			if descriptor.kind ~= "overlay" then
				local blueprint = descriptor.build()
				blueprints[#blueprints + 1] = {descriptor = descriptor,
					landmarks = blueprint.landmarks,
					reference = blueprint.reference}
			end
		end
		return settlement.sockets({schema = "grug_wp13_settlement_prepared_v1",
			profile = profile, blueprints = blueprints},
			{x = 0, y = 20, z = 0}, function() return 20 end)
	end

	local placed, starts, capitals = 0, 0, 0
	local report = {}
	for index = 1, #settlement.roster do
		local profile = settlement.roster[index]
		local rows = projected(profile)
		local trainers = 0
		for row_index = 1, #rows do
			local socket = rows[row_index]
			if socket.role == "trainer" then
				trainers = trainers + 1
				local profession = grug_jobs.PROFESSIONS[socket.profession]
				check(profession ~= nil,
					profile.key .. " projected an unknown profession " ..
					tostring(socket.profession))
				local entity = {}
				grug_mobs.install_profession_trainer(entity, socket)
				grug_mobs.start_npc_retag(entity)
				local expected = profession.name .. " Trainer"
				check(entity._grug_profession == socket.profession and
					entity._grug_npc_name == expected and
					entity._kat_plain_tag == expected,
					profile.key .. " " .. socket.profession ..
					" placement/retag differs")

				local definition = registered_mobs["grug_mobs:villager_" ..
					profile.race]
				check(definition and type(definition.after_activate) == "function",
					profile.key .. " villager reload path is absent")
				local reloaded = {_grug_profession = entity._grug_profession,
					_grug_npc_name = entity._grug_npc_name}
				definition.after_activate(reloaded)
				check(reloaded._kat_plain_tag == expected and
					reloaded._grug_npc_tag == expected,
					profile.key .. " " .. socket.profession ..
					" reload did not restore the trainer tag")
				placed = placed + 1
			end
		end
		check(trainers > 0, profile.key .. " has no projected trainer sockets")
		if profile.slot == "start" then starts = starts + 1 end
		if profile.slot == "capital" then capitals = capitals + 1 end
		report[#report + 1] = profile.key .. "=" .. trainers

		local citizen_name = profile.label .. " Citizen"
		local citizen = {_grug_npc_name = citizen_name}
		local definition = registered_mobs["grug_mobs:villager_" .. profile.race]
		definition.after_activate(citizen)
		check(citizen._grug_npc_name == citizen_name and
			citizen._kat_plain_tag == citizen_name,
			profile.key .. " non-trainer name changed on reload")
	end
	check(starts == 6 and capitals == 6,
		"production roster no longer contains six starts and six capitals")

	restore()
	return "R9-UI trainer-name KAT PASS settlements=12 trainers=" .. placed ..
		" rosters=" .. table.concat(report, ",") ..
		" install=real retag=real reload=after_activate nontrainers=unchanged\n"
end
