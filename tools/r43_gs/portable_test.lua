-- Round 43 lane GS portable test: the game side of world migrations
-- (round43-plan.md §4.1, the platform's migration contract R6 and R7). Loads
-- the REAL grug_core/migrations.lua and grug_core/world_version.lua (and, for
-- the relocation order, the real grug_core/map_reset.lua) under minimal
-- `core` stubs:
--
--   A. the guard's decision: a newer world, a step between, a compatible
--      move, a new world, the baseline of a missing record, a bad record;
--   B. the record at load: refused starts raise and write nothing, the record
--      is written only at the first server step after every mod loaded, a new
--      world is stamped, an equal record is left alone;
--   C. new-world recognition: each saved-state signal alone makes a world
--      existing, auth and the engine's world files do not;
--   D. the runner: world markers after every mod's load in step order,
--      deleted after success, a failure stops the load and keeps its marker;
--      character markers at a join in step order, a failure holds the
--      character (severe report, disconnect, marker kept), the next join
--      retries;
--   E. the relocation order: the character work is the first join callback,
--      before the map reset's relocation reads the character;
--   F. the test hook: inert without its setting, its steps join the guard
--      and the runner with it; the registry's own rules.
--
-- Usage (repo root): luajit tools/r43_gs/portable_test.lua [repo]
local repo = arg and arg[1] or "."
local CORE = repo .. "/mods/CORE/grug_core"
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function has(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) ~= nil,
		label .. " (" .. tostring(text) .. " lacks " .. part .. ")")
end

-- A mod storage / player meta on a plain table ("" deletes, like the engine).
local function new_store(t)
	t = t or {}
	local s = {data = t}
	function s.get_string(_, k) return t[k] or "" end
	function s.set_string(_, k, v)
		if v == "" then t[k] = nil else t[k] = v end
	end
	function s.get_int(_, k) return math.floor(tonumber(t[k]) or 0) end
	function s.set_int(_, k, v) t[k] = tostring(v) end
	function s.get_keys()
		local keys = {}
		for k in pairs(t) do keys[#keys + 1] = k end
		return keys
	end
	return s
end

local function new_player(name, fields)
	local meta = new_store(fields)
	return {
		meta = meta,
		get_meta = function() return meta end,
		get_player_name = function() return name end,
	}
end

local real_dofile = dofile
local WORLD = "/worlds/test"

-- One start of the game's grug_core part under fresh stubs. opts: record,
-- storage (table), files, dirs, game, registry, test_setting, test_steps,
-- joins_before (callbacks registered by mods loading before grug_core),
-- map_reset (also load the real map_reset.lua). Returns the run.
local function boot(opts)
	opts = opts or {}
	local run = {logs = {}, after = {}, mods_loaded = {}, joins = {}, severe = {},
		disconnected = {}, hook_read = false}
	local data = opts.storage or {}
	if opts.record then data.world_version = opts.record end
	run.storage = new_store(data)
	for _, fn in ipairs(opts.joins_before or {}) do run.joins[#run.joins + 1] = fn end
	core = {
		log = function(level, text) run.logs[#run.logs + 1] = level .. " " .. text end,
		get_mod_storage = function() return run.storage end,
		get_game_info = function() return {path = "/games/grudgelands"} end,
		get_worldpath = function() return WORLD end,
		get_dir_list = function(path, dirs)
			assert(path == WORLD)
			return dirs and (opts.dirs or {}) or (opts.files or {"world.mt", "map_meta.txt"})
		end,
		settings = {
			get_bool = function(_, key, default)
				if key == "grug_test_migrations" then return opts.test_setting == true end
				return default
			end,
			get = function(_, key)
				if key == "grug_reset_world" then return opts.reset_setting end
				return nil
			end,
		},
		register_on_mods_loaded = function(fn) run.mods_loaded[#run.mods_loaded + 1] = fn end,
		after = function(_, fn) run.after[#run.after + 1] = fn end,
		registered_on_joinplayers = run.joins,
		register_on_joinplayer = function(fn)
			-- The engine profiler (profiler.load) stores a wrapper instead.
			if opts.wrap_register then
				local inner = fn
				fn = function(...) return inner(...) end
			end
			run.joins[#run.joins + 1] = fn
		end,
		register_on_newplayer = function() end,
		disconnect_player = function(name, reason)
			run.disconnected[#run.disconnected + 1] = name .. ": " .. reason
		end,
	}
	Settings = function(path)
		assert(path == "/games/grudgelands/game.conf")
		return {get = function(_, key)
			if key == "version" then return opts.game or "0.43.0" end
		end}
	end
	grug_core = {severe = {report = function(source, summary, details, key)
		run.severe[#run.severe + 1] = {source = source, summary = summary,
			details = details, key = key}
	end}}
	dofile = function(path)
		if path == WORLD .. "/grug_test_migrations.lua" then
			run.hook_read = true
			return opts.test_steps or {}
		end
		return real_dofile(path)
	end
	real_dofile(CORE .. "/migrations.lua")
	if opts.registry then grug_core.migrations = opts.registry end
	local ok, err = pcall(real_dofile, CORE .. "/world_version.lua")
	if ok and opts.map_reset then
		ok, err = pcall(real_dofile, CORE .. "/map_reset.lua")
	end
	dofile = real_dofile
	run.ok, run.err = ok, err
	run.M = grug_core.world_version
	return run
end

-- The rest of a start: every on_mods_loaded callback, then the first step.
local function finish_load(run)
	for _, fn in ipairs(run.mods_loaded) do
		local ok, err = pcall(fn)
		if not ok then return false, err end
	end
	local jobs = run.after
	run.after = {}
	for _, fn in ipairs(jobs) do fn() end
	return true
end

local function join(run, player)
	for _, fn in ipairs(run.joins) do fn(player) end
end

local function step(version, world, character)
	return {version = version, world = world, character = character}
end

--
-- A. The guard's decision (pure).
--
do
	local r = boot()
	assert(r.ok, r.err)
	local M = r.M
	local steps = M.collect({versions = {"0.44.0", "0.46.0"}, handlers = {}})
	local from, err = M.decide("0.45.0", false, "0.44.0", steps, WORLD)
	eq(from, nil, "A a newer world is refused")
	has(err, "0.45.0", "A the newer refusal names the world's version")
	has(err, "0.44.0", "A ...and the game's")
	has(err, "downgrade to 0.45.0 to continue", "A ...and says the contract's words")
	from, err = M.decide("0.43.0", false, "0.44.0", steps, WORLD)
	eq(from, nil, "A a step between refuses")
	has(err, "step 0.44.0", "A the step refusal names the step")
	has(err, "back up the world and run the tool", "A ...says to back up and run the tool")
	has(err, "python3 tools/migrate.py --world " .. WORLD, "A ...with its command line")
	from, err = M.decide("0.43.0", false, "0.46.0", steps, WORLD)
	has(err, "steps 0.44.0, 0.46.0", "A every due step is named, in step order")
	eq(M.decide("0.44.0", false, "0.45.0", steps, WORLD), "0.44.0",
		"A a step at the record is not crossed: compatible")
	eq(M.decide("0.42.0", false, "0.43.0", steps, WORLD), "0.42.0", "A a compatible move starts")
	eq(M.decide("0.44.0", false, "0.44.0", steps, WORLD), "0.44.0", "A no move starts")
	eq(M.decide("", false, "0.43.0", steps, WORLD), "0.41.0",
		"A a missing record on an existing world is 0.41.0")
	from, err = M.decide("", false, "0.44.0", steps, WORLD)
	has(err, "at version 0.41.0", "A ...so a missing record before a step refuses")
	eq(M.decide("", true, "0.46.0", steps, WORLD), "0.46.0",
		"A a new world is the game's version: no step is due")
	eq(M.decide("", false, "0.41.0", M.collect({versions = {"0.41.0"}, handlers = {}}), WORLD),
		"0.41.0", "A a step at the baseline is never due for a missing record")
	from, err = M.decide("0.43", false, "0.43.0", steps, WORLD)
	has(err, "restore the world from its backup", "A a malformed record refuses")
	from, err = M.decide("0.10.0", false, "0.9.0", {}, WORLD)
	has(err, "downgrade to 0.10.0", "A versions compare numerically")
	from, err = M.decide("0.43.0", false, nil, {}, WORLD)
	has(err, "game.conf names no", "A a game without a version refuses")
end

--
-- B. The record at load.
--
do
	-- Compatible: 0.42.0 -> 0.43.0, no step.
	local r = boot({record = "0.42.0", storage = {world_preparation = "x"}})
	check(r.ok, "B a compatible world loads: " .. tostring(r.err))
	eq(r.storage:get_string("world_version"), "0.42.0", "B the record waits during the load")
	eq(#r.after, 0, "B ...and during the mods' load")
	assert(finish_load(r))
	eq(r.storage:get_string("world_version"), "0.43.0", "B the first step records the game")

	-- A world from before the records (0.41.0, 0.42.0, or 0.40.0 with the reset).
	r = boot({storage = {world_preparation = "x"}})
	check(r.ok and r.M.from == "0.41.0" and r.M.new_world == false,
		"B no record on an existing world starts as 0.41.0")
	assert(finish_load(r))
	eq(r.storage:get_string("world_version"), "0.43.0", "B ...and takes the game's version")

	-- Newer: refused, nothing written, no callback registered.
	r = boot({record = "0.44.0", storage = {world_preparation = "x"}})
	check(not r.ok, "B a newer world does not load")
	has(r.err, "downgrade to 0.44.0 to continue", "B ...with the newer message")
	eq(r.storage:get_string("world_version"), "0.44.0", "B ...its record untouched")
	eq(#r.mods_loaded + #r.after, 0, "B ...and nothing scheduled")

	-- A step between: refused.
	r = boot({record = "0.43.0", game = "0.44.0", storage = {world_preparation = "x"},
		registry = {versions = {"0.44.0"}, handlers = {}}})
	check(not r.ok, "B a world crossing a step does not load")
	has(r.err, "step 0.44.0", "B ...with the step message")

	-- After the tool: the record at the step, the game one patch later.
	r = boot({record = "0.44.0", game = "0.44.1", storage = {world_preparation = "x"},
		registry = {versions = {"0.44.0"}, handlers = {}}})
	check(r.ok, "B a migrated world loads")
	assert(finish_load(r))
	eq(r.storage:get_string("world_version"), "0.44.1", "B ...and records the game")

	-- A new world is stamped at once, even when steps lie before the game's
	-- version, so a first start that fails later keeps the stamp.
	r = boot({game = "0.45.0", registry = {versions = {"0.44.0"}, handlers = {}}})
	check(r.ok and r.M.new_world == true, "B a new world loads past every step")
	eq(r.storage:get_string("world_version"), "0.45.0", "B ...and is stamped at the guard")
	r.storage:set_string("world_preparation", "x")
	r.mods_loaded[#r.mods_loaded + 1] = function() error("a later mod fails") end
	check(not finish_load(r), "B its first load fails later")
	local again = boot({game = "0.45.0", registry = {versions = {"0.44.0"}, handlers = {}},
		storage = r.storage.data})
	check(again.ok and again.M.from == "0.45.0", "B ...and the next start still loads it")

	-- An equal record is left alone.
	r = boot({record = "0.43.0", storage = {world_preparation = "x"}})
	local writes = 0
	local set = r.storage.set_string
	r.storage.set_string = function(...) writes = writes + 1; return set(...) end
	assert(finish_load(r))
	eq(writes, 0, "B an equal record is not rewritten")

	-- A failing later on_mods_loaded callback: no record (the load failed).
	r = boot({record = "0.42.0", storage = {world_preparation = "x"}})
	r.mods_loaded[#r.mods_loaded + 1] = function() error("a later mod fails") end
	check(not finish_load(r), "B a failing later callback stops the load")
	eq(r.storage:get_string("world_version"), "0.42.0", "B ...and the record is not written")
end

--
-- C. New-world recognition (conservative: in doubt, existing).
--
do
	local r = boot()
	local new = r.M.is_new_world
	eq(new({}, {"world.mt", "map_meta.txt"}, {}), true,
		"C only the engine's world files: new")
	eq(new({}, {"world.mt", "map_meta.txt", "auth.sqlite", "ipban.txt", "mod_storage.sqlite"}, {}),
		true, "C auth entries, the ban list and an empty mod storage do not count")
	eq(new({"world_preparation"}, {"world.mt"}, {}), false, "C a grug_core storage key: existing")
	eq(new({}, {"world.mt", "env_meta.txt"}, {}), false, "C env_meta.txt: existing")
	eq(new({}, {"world.mt", "players.sqlite"}, {}), false, "C players.sqlite: existing")
	eq(new({}, {"world.mt"}, {"players"}), false, "C a players directory: existing")
	eq(new({}, {"world.mt"}, {"worldmods"}), true, "C other directories do not count")
	-- At load, through the stubs.
	r = boot({files = {"world.mt", "env_meta.txt"}, game = "0.45.0",
		registry = {versions = {"0.44.0"}, handlers = {}}})
	check(not r.ok, "C an existing world without characters but with saved state is not new")
	r = boot({storage = {}, files = {"world.mt", "auth.sqlite"}})
	eq(r.M.new_world, true, "C a world with only auth entries is new")
	r = boot({record = "0.42.0", files = {"world.mt"}})
	eq(r.M.new_world, false, "C a world with a record is never taken for new")
end

--
-- D. The runner.
--
do
	local order = {}
	local registry = {versions = {"0.44.0", "0.45.0"}, handlers = {
		["0.45.0"] = {
			world = function(marker) order[#order + 1] = "w45:" .. marker end,
			character = function(player, marker)
				order[#order + 1] = "c45:" .. player:get_player_name() .. ":" .. marker
			end,
		},
		["0.44.0"] = {
			world = function(marker) order[#order + 1] = "w44:" .. marker end,
			character = function(player, marker)
				order[#order + 1] = "c44:" .. player:get_player_name() .. ":" .. marker
				player:get_meta():set_string("repaired", "yes")
			end,
		},
	}}
	local r = boot({record = "0.45.0", game = "0.45.1", registry = registry,
		storage = {world_preparation = "x", ["migrate_world:0.45.0"] = "b",
			["migrate_world:0.44.0"] = "a"}})
	assert(r.ok, r.err)
	eq(#order, 0, "D nothing runs during the mods' load")
	assert(finish_load(r))
	eq(table.concat(order, " "), "w44:a w45:b", "D world markers run in step order with their values")
	eq(r.storage:get_string("migrate_world:0.44.0") .. r.storage:get_string("migrate_world:0.45.0"),
		"", "D ...and are deleted after success")
	eq(r.storage:get_string("world_version"), "0.45.1", "D the record follows the online work")

	order = {}
	local hero = new_player("hero", {["grug_core:migrate:0.45.0"] = "2",
		["grug_core:migrate:0.44.0"] = "1"})
	local plain = new_player("plain", {level = "3"})
	join(r, hero)
	join(r, plain)
	eq(table.concat(order, " "), "c44:hero:1 c45:hero:2",
		"D a character's markers run in step order; an unaffected one runs nothing")
	eq(hero.meta:get_string("grug_core:migrate:0.44.0") ..
		hero.meta:get_string("grug_core:migrate:0.45.0"), "", "D ...and are deleted")
	eq(plain.meta:get_string("level"), "3", "D the unaffected character is unchanged")
	join(r, hero)
	eq(#order, 2, "D a finished marker never runs again")

	-- A failing world handler stops the load and keeps its marker; later
	-- markers wait.
	order = {}
	local failing = {versions = {"0.44.0", "0.45.0"}, handlers = {
		["0.44.0"] = {world = function() error("broken data") end},
		["0.45.0"] = {world = function() order[#order + 1] = "w45" end},
	}}
	r = boot({record = "0.45.0", game = "0.45.0", registry = failing,
		storage = {world_preparation = "x", ["migrate_world:0.44.0"] = "1",
			["migrate_world:0.45.0"] = "1"}})
	assert(r.ok, r.err)
	local ok, err = finish_load(r)
	check(not ok, "D a failing world handler stops the load")
	has(err, "migration 0.44.0", "D ...naming the step")
	has(err, "broken data", "D ...and the handler's error")
	eq(r.storage:get_string("migrate_world:0.44.0"), "1", "D ...its marker kept")
	eq(r.storage:get_string("migrate_world:0.45.0"), "1", "D ...later markers wait")
	eq(#order, 0, "D ...and do not run")
	eq(#r.after, 0, "D ...and no record is written")
	-- A marker without a handler for its part also stops the load.
	r = boot({record = "0.45.0", game = "0.45.0",
		registry = {versions = {"0.45.0"}, handlers = {}},
		storage = {world_preparation = "x", ["migrate_world:0.45.0"] = "1"}})
	ok, err = finish_load(r)
	check(not ok, "D a world marker without a world handler stops the load")
	has(err, "no world handler", "D ...saying so")

	-- A failing character handler holds that character; the next join retries.
	local attempts = 0
	local flaky = {versions = {"0.44.0", "0.45.0"}, handlers = {
		["0.44.0"] = {character = function(player)
			attempts = attempts + 1
			if attempts == 1 then error("bad inventory") end
			player:get_meta():set_string("fixed", "1")
		end},
		["0.45.0"] = {character = function(player) player:get_meta():set_string("later", "1") end},
	}}
	r = boot({record = "0.45.0", game = "0.45.0", registry = flaky,
		storage = {world_preparation = "x"}})
	assert(finish_load(r))
	local p = new_player("unlucky", {["grug_core:migrate:0.44.0"] = "1",
		["grug_core:migrate:0.45.0"] = "1"})
	join(r, p)
	eq(#r.disconnected, 1, "D a failing character handler disconnects the character")
	has(r.disconnected[1], "unlucky: Your character could not be updated",
		"D ...with a short message")
	eq(#r.severe, 1, "D ...and reports a severe error")
	has(r.severe[1] and r.severe[1].summary, "Migration 0.44.0", "D ...naming the step")
	has(r.severe[1] and r.severe[1].details, "bad inventory", "D ...with the handler's error")
	eq(p.meta:get_string("grug_core:migrate:0.44.0"), "1", "D ...its marker kept")
	eq(p.meta:get_string("grug_core:migrate:0.45.0"), "1", "D ...the later marker waits")
	eq(p.meta:get_string("later"), "", "D ...and does not run")
	join(r, p)
	eq(p.meta:get_string("fixed") .. p.meta:get_string("later"), "11", "D the next join retries")
	eq(p.meta:get_string("grug_core:migrate:0.44.0") ..
		p.meta:get_string("grug_core:migrate:0.45.0"), "", "D ...and finishes both")
	eq(#r.disconnected, 1, "D ...without another disconnect")
end

--
-- E. The relocation order: the character work runs first.
--
do
	local seen = {}
	local before_core = function(player)
		seen[#seen + 1] = "base:" .. player:get_meta():get_string("repaired")
	end
	local registry = {versions = {"0.45.0"}, handlers = {["0.45.0"] = {
		character = function(player) player:get_meta():set_string("repaired", "yes") end,
	}}}
	local r = boot({record = "0.45.0", game = "0.45.0", registry = registry,
		storage = {world_preparation = "x", reset_world = "0"}, reset_setting = "1",
		joins_before = {before_core}, map_reset = true})
	assert(r.ok, r.err)
	-- The relocation's own join callback (grug_classes/selection.lua lock_player)
	-- registers later still; it reads the character.
	r.joins[#r.joins + 1] = function(player)
		seen[#seen + 1] = "relocate:" .. tostring(grug_core.map_reset.needs_relocation(player)) ..
			":" .. player:get_meta():get_string("repaired")
	end
	assert(finish_load(r))
	eq(r.joins[1] ~= before_core, true, "E the character work is the first join callback")
	local p = new_player("veteran", {["grug_classes:race"] = "orc",
		["grug_core:migrate:0.45.0"] = "1"})
	join(r, p)
	eq(table.concat(seen, " "), "base:yes relocate:true:yes",
		"E every join callback, the relocation's included, reads the repaired character")
	eq(r.storage:get_string("reset_world"), "1", "E the map reset applied in the same start")
	-- With the engine profiler's wrapped registrations the start still works.
	local wrapped = boot({record = "0.45.0", game = "0.45.0", registry = registry,
		storage = {world_preparation = "x"}, joins_before = {before_core}, wrap_register = true})
	check(wrapped.ok, "E a wrapped join registration loads: " .. tostring(wrapped.err))
	eq(wrapped.joins[2], before_core, "E ...and its entry moves first")
end

--
-- F. The test hook and the registry's rules.
--
do
	local r = boot({record = "0.42.0", storage = {world_preparation = "x"},
		test_steps = {step("0.42.5")}})
	check(r.ok and not r.hook_read, "F without its setting the hook file is never read")
	eq(#r.M.steps, 0, "F ...and adds no step")

	local done = {}
	r = boot({record = "0.42.0", storage = {world_preparation = "x"}, test_setting = true,
		test_steps = {step("0.42.5")}})
	check(not r.ok and r.hook_read, "F with its setting a test step joins the guard")
	has(r.err, "step 0.42.5", "F ...which names it")

	r = boot({record = "0.42.5", storage = {world_preparation = "x",
		["migrate_world:0.42.5"] = "1", ["migrate_world:0.42.3"] = "1"}, test_setting = true,
		test_steps = {
			step("0.42.5", function() done[#done + 1] = "w5" end),
			step("0.42.3", function() done[#done + 1] = "w3" end,
				function(player) done[#done + 1] = "c3:" .. player:get_player_name() end),
		}})
	check(r.ok, "F after the tool the world loads: " .. tostring(r.err))
	eq(r.M.steps[1].version .. " " .. r.M.steps[2].version, "0.42.3 0.42.5",
		"F test steps are sorted into step order")
	assert(finish_load(r))
	eq(table.concat(done, " "), "w3 w5", "F test steps' world work runs")
	join(r, new_player("tester", {["grug_core:migrate:0.42.3"] = "1"}))
	eq(done[3], "c3:tester", "F ...and their character work")
	has(table.concat(r.logs, "\n"), "grug_test_migrations is set", "F the hook is logged")

	r = boot({record = "0.42.0", storage = {world_preparation = "x"}, test_setting = true,
		registry = {versions = {"0.42.5"}, handlers = {}}, test_steps = {step("0.42.5")}})
	has(r.err, "listed twice", "F a test step may not repeat a declared one")
	r = boot({registry = {versions = {"0.44"}, handlers = {}}})
	has(r.err, "no major.minor.patch", "F a malformed step version stops the load")
	r = boot({registry = {versions = {}, handlers = {["0.44.0"] = {}}}})
	has(r.err, "no listed step", "F handlers for an unlisted version stop the load")

	-- The shipped registry: empty, and the shipped configuration never sets
	-- the hook (settingtypes.txt and minetest.conf do not name it).
	grug_core = {}
	real_dofile(CORE .. "/migrations.lua")
	eq(#grug_core.migrations.versions, 0, "F the shipped registry declares no step")
	for _, name in ipairs({"/minetest.conf", "/settingtypes.txt", "/game.conf"}) do
		local f = assert(io.open(repo .. name, "rb"))
		local text = f:read("*a")
		f:close()
		check(not text:find("grug_test_migrations", 1, true), "F " .. name .. " never sets the hook")
	end
end

if failures > 0 then
	error(("R43 GS PORTABLE FAIL failures=%d checks=%d"):format(failures, checks), 0)
end
print(("R43 GS PORTABLE PASS checks=%d"):format(checks))
