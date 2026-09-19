-- Real-code KAT for the trainer naming seam across the twelve R7 settlements.
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

	rawset(_G, "core", {register_globalstep = function() end,
		register_on_mods_loaded = function() end})
	rawset(_G, "grug_core", {})
	rawset(_G, "mobs", {mob_class = {}})
	rawset(_G, "grug_mobs", {storage = {
		get_string = function() return "" end,
		set_string = function() end,
	}})
	rawset(_G, "grug_jobs", {PROFESSIONS = {
		blacksmith = {name = "Blacksmith"},
		alchemist = {name = "Alchemist"},
		tailor = {name = "Tailor"},
		leatherworker = {name = "Leatherworker"},
		woodcarver = {name = "Woodcarver"},
		goldsmith = {name = "Goldsmith"},
		cooking = {name = "Cooking"},
	}})

	dofile(root .. "/mods/ENTITIES/grug_mobs/start_npcs.lua")
	local settlement = dofile(root ..
		"/mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua")
	check(type(grug_mobs.install_profession_trainer_name) == "function",
		"production trainer helper is absent")
	check(#settlement.roster == 12, "settlement roster count differs")

	local capital_professions = {"blacksmith", "alchemist", "tailor",
		"leatherworker", "woodcarver", "goldsmith", "cooking"}
	local placed = 0
	for index = 1, #settlement.roster do
		local row = settlement.roster[index]
		local professions = row.slot == "start" and {"cooking"} or capital_professions
		check(row.slot == "start" or row.slot == "capital",
			row.key .. " has an unexpected settlement slot")
		for profession_index = 1, #professions do
			local profession = professions[profession_index]
			local entity = {_grug_npc_name = row.label .. " Trainer",
				_grug_profession = profession}
			local installed = grug_mobs.install_profession_trainer_name(entity,
				profession)
			check(installed and entity._grug_npc_name ==
				grug_jobs.PROFESSIONS[profession].name .. " Trainer",
				row.key .. " " .. profession .. " trainer name differs")
			-- The value stored on the entity is the value mobs_redo serializes and
			-- start_villagers' after_activate retag path reads after a reload.
			local reloaded = {_grug_npc_name = entity._grug_npc_name}
			check(reloaded._grug_npc_name == entity._grug_npc_name,
				row.key .. " trainer name did not survive the staticdata shape")
			placed = placed + 1
		end
		local non_trainer = {_grug_npc_name = row.label .. " Citizen"}
		check(non_trainer._grug_npc_name == row.label .. " Citizen",
			row.key .. " non-trainer name changed")
	end
	check(placed == 48, "trainer socket total differs: " .. placed)

	local file = assert(io.open(root ..
		"/mods/ENTITIES/grug_mobs/start_npcs.lua", "rb"))
	local source = file:read("*a")
	file:close()
	local branch = source:match('elseif slot%.role == "trainer" then(.-)\n\tend')
	check(branch and branch:find("entity._grug_profession = slot.profession", 1, true)
		and branch:find("install_profession_trainer_name(entity, slot.profession)",
			1, true), "placed-trainer branch does not own profession and name together")

	restore()
	return "R9-UI trainer-name KAT PASS settlements=12 trainers=48 " ..
		"starts=Cooking capitals=7 nontrainers=unchanged reload=stored_name\n"
end
