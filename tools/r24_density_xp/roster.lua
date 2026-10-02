-- Round 24 Lane F: portable spawn-roster loader (LuaJIT).
--
--   local roster = dofile(repo .. "/tools/r24_density_xp/roster.lua")(repo)
--
-- Loads the real grug_mobs spawn_policy.lua and every mob file init.lua
-- loads, under a permissive stub environment. Only the two seams the density
-- budget reads are real: grug_mobs.register_spawn_role (spawn_policy.lua,
-- called for every def exactly as the register_mob wrapper does) and the
-- installed mobs:spawn clock wrapper, whose prepared rows are captured.
-- Everything else a mob file calls at load time (verbs, arrows, visuals,
-- engine registration) is an inert stub, so this reproduces the registered
-- spawn rows and roles, not mob behaviour.
return function(repo)
	local dir = repo .. "/mods/ENTITIES/grug_mobs"
	local stub
	local function stub_fn() return stub end
	stub = setmetatable({}, {
		__index = function() return stub end,
		__call = stub_fn,
		__concat = function() return "" end,
		__add = function() return 0 end, __sub = function() return 0 end,
		__mul = function() return 0 end, __div = function() return 0 end,
		__unm = function() return 0 end,
	})
	local function permissive(t)
		return setmetatable(t, {__index = function() return stub_fn end})
	end

	local saved = {}
	for _, name in ipairs({"core", "minetest", "mobs", "grug_mobs", "grug_core",
			"grug_zones", "vector", "ItemStack", "grug_factions", "grug_xp",
			"default", "player_api", "grug_visuals", "grug_materials"}) do
		saved[name] = rawget(_G, name)
	end

	local rows, defs = {}, {}
	local core_stub = permissive({
		get_modpath = function() return dir end,
		get_current_modname = function() return "grug_mobs" end,
		registered_entities = setmetatable({}, {__index = function() return stub end}),
		registered_items = {}, registered_nodes = {},
		settings = permissive({}),
		get_translator = function() return function(s) return s end end,
		global_exists = function() return false end,
		colorize = function(_, s) return s end,
	})
	_G.core, _G.minetest = core_stub, core_stub
	_G.mobs = permissive({mob_class = permissive({}), spawning_mobs = {},
		spawn = function(_, def) rows[#rows + 1] = def end})
	_G.grug_mobs = permissive({})
	_G.grug_core = permissive({DAY_PHASE_START = 0.1875, DAY_PHASE_END = 0.8125})
	_G.grug_zones = permissive({})
	_G.grug_factions = permissive({})
	_G.grug_xp = permissive({})
	_G.default = permissive({})
	_G.player_api = permissive({})
	_G.grug_materials = permissive({})
	_G.vector = permissive({new = function(x, y, z)
		if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
		return {x = x or 0, y = y or 0, z = z or 0}
	end})
	_G.ItemStack = stub_fn

	-- Round 28: the palettes are data (spawn_regions.lua), loaded first.
	dofile(repo .. "/tools/r28_b1/load_spawn_areas.lua")(repo)
	dofile(dir .. "/spawn_policy.lua")
	dofile(dir .. "/density.lua")
	local gm = _G.grug_mobs
	gm._spawn_clock_wrapper_installed = false
	gm.install_spawn_clock_wrapper()
	-- The raw row as the mob file wrote it, before the clock wrapper prepares
	-- it: the pre-Round-24 rule is recomputed from these.
	local raw_rows = {}
	local prepared_spawn = _G.mobs.spawn
	_G.mobs.spawn = function(self, def)
		local copy = {}
		for key, value in pairs(def) do copy[key] = value end
		raw_rows[#raw_rows + 1] = copy
		return prepared_spawn(self, def)
	end
	gm.CALM_WALK_MAX = 2.5
	gm.storage = permissive({})
	local spawn_domains, spawn_checks = {}, {}
	gm.register_mob = function(name, def)
		defs[name] = def
		gm.register_spawn_role(name, def)
		if def._grug_spawn_domains then
			spawn_domains[name] = gm.compile_spawn_domains(def._grug_spawn_domains, name)
		end
		spawn_checks[name] = def._grug_spawn_check
	end
	-- init.lua spawn_allowed, verbatim in behaviour: policy, domain, check.
	local function spawn_allowed(name, pos)
		if not gm.spawn_policy_allows(name, pos) then return false end
		local domains = spawn_domains[name]
		if domains and not gm.spawn_domains_allow(domains, pos) then return false end
		local check = spawn_checks[name]
		if check and not check(pos) then return false end
		return true
	end
	gm.atlas_textures = function(texture, slots)
		local list = {}
		for i = 1, slots or 1 do list[i] = texture end
		return list
	end

	local source = assert(io.open(dir .. "/init.lua")):read("*a")
	local files = {}
	for file in source:gmatch('dofile%(modpath %.%. "/([%w_]+%.lua)"%)') do
		if file ~= "spawn_policy.lua" and file ~= "density.lua" and
				file ~= "spawn_regions.lua" then
			files[#files + 1] = file
		end
	end
	local failed = {}
	for _, file in ipairs(files) do
		local chunk = assert(loadfile(dir .. "/" .. file))
		local ok, err = pcall(chunk)
		if not ok then failed[#failed + 1] = file .. ": " .. tostring(err) end
	end

	local result = {rows = rows, raw_rows = raw_rows, defs = defs, files = files, failed = failed,
		grug_mobs = gm, spawn_allowed = spawn_allowed}
	for name, value in pairs(saved) do rawset(_G, name, value) end
	return result
end
