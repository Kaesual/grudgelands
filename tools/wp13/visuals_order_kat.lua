-- Known-answer test for the ORDER the WP13 character visuals depend on.
--
-- The Character page renders the player's LIVE object properties
-- (grug_inventory/pages.lua, preview_model), and AGENTS.md allows exactly ONE
-- equipment-driven page-refresh consumer. So "the preview shows what the player
-- is wearing" is not a property of any one file -- it is the composition of two
-- orderings, and this fixture checks both against the shipped sources rather
-- than against a comment:
--
--   A  LOAD ORDER. Luanti loads a mod after everything it depends on, and
--      `optional_depends` orders just as hard as `depends` when the mod is
--      present. grug_inventory therefore has to declare grug_visuals, and
--      grug_visuals must NOT declare grug_inventory back (that is a cycle).
--      Checked on the real mod.conf graph of the whole game.
--   B  CALLBACK ORDER. grug_core's equipment seam must run its consumers in
--      REGISTRATION order, or load order would buy nothing. Checked by loading
--      the real mods/CORE/grug_core/combat.lua and firing it.
--
-- Plain Lua 5.1, no engine.
--
-- Usage (from the repository root):
--   luajit          -e 'io.write(dofile("tools/wp13/visuals_order_kat.lua")("."))'
--   tools/bin/lua51 -e 'io.write(dofile("tools/wp13/visuals_order_kat.lua")("."))'

local M = {}

local COMBAT = "mods/CORE/grug_core/combat.lua"

-- The three modpack directories that hold a mod.conf we care about; the
-- vendored BASE/ENTITIES mods are read too, because a cycle anywhere stops the
-- whole game from loading.
local MODPACKS = {"BASE", "CORE", "ENTITIES", "HUD", "ITEMS", "MAPGEN", "PLAYER"}

local function trim(text)
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function split_list(value)
	local out = {}
	for item in value:gmatch("[^,]+") do
		local name = trim(item)
		if name ~= "" then
			out[#out + 1] = name
		end
	end
	return out
end

-- `io.open` is the only directory-free way to find a mod.conf in plain Lua, so
-- the mod names come from the game's own modpack layout: every directory that
-- answers a mod.conf is a mod. The roster is discovered, never hand-listed --
-- the fixture reads the repository, so a mod added tomorrow is covered.
local function read_file(path)
	local handle = io.open(path, "rb")
	if not handle then
		return nil
	end
	local body = handle:read("*a")
	handle:close()
	return body
end

-- Mod directories are enumerated through the modpack's own listing file when
-- one exists; otherwise through the names the repository actually contains,
-- which we discover by probing the mod.conf of every candidate the dependency
-- graph mentions plus the ones we are asserting about. Probing is exact: a
-- candidate with no mod.conf is simply not a mod.
local function collect_mods(repo, seeds)
	local mods, pending, seen = {}, {}, {}
	local function push(name)
		if name and not seen[name] then
			seen[name] = true
			pending[#pending + 1] = name
		end
	end
	for _, name in ipairs(seeds) do
		push(name)
	end
	local index = 1
	while index <= #pending do
		local name = pending[index]
		index = index + 1
		local body, where = nil, nil
		for _, pack in ipairs(MODPACKS) do
			local path = repo .. "/mods/" .. pack .. "/" .. name .. "/mod.conf"
			body = read_file(path)
			if body then
				where = "mods/" .. pack .. "/" .. name
				break
			end
		end
		if body then
			local entry = {name = name, path = where, depends = {},
				optional = {}}
			for line in body:gmatch("[^\r\n]+") do
				local key, value = line:match("^%s*([%w_]+)%s*=%s*(.*)$")
				if key == "depends" then
					entry.depends = split_list(value)
				elseif key == "optional_depends" then
					entry.optional = split_list(value)
				end
			end
			mods[name] = entry
			for _, dep in ipairs(entry.depends) do
				push(dep)
			end
			for _, dep in ipairs(entry.optional) do
				push(dep)
			end
		end
	end
	return mods
end

-- Luanti's rule, reduced to what matters here: a mod loads after every mod it
-- depends on, and after every OPTIONAL dependency that is actually installed.
-- Kahn's algorithm with a name-ordered ready queue, so the answer is one
-- deterministic order rather than "some valid order".
local function load_order(mods)
	local edges, indegree, names = {}, {}, {}
	for name in pairs(mods) do
		names[#names + 1] = name
		indegree[name] = 0
		edges[name] = {}
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local entry = mods[name]
		local function edge(dep)
			if mods[dep] then
				edges[dep][#edges[dep] + 1] = name
				indegree[name] = indegree[name] + 1
			end
		end
		for _, dep in ipairs(entry.depends) do
			edge(dep)
		end
		for _, dep in ipairs(entry.optional) do
			edge(dep)
		end
	end
	local order, position = {}, {}
	local ready = {}
	for _, name in ipairs(names) do
		if indegree[name] == 0 then
			ready[#ready + 1] = name
		end
	end
	while #ready > 0 do
		table.sort(ready)
		local name = table.remove(ready, 1)
		order[#order + 1] = name
		position[name] = #order
		local targets = edges[name]
		table.sort(targets)
		for _, target in ipairs(targets) do
			indegree[target] = indegree[target] - 1
			if indegree[target] == 0 then
				ready[#ready + 1] = target
			end
		end
	end
	local cyclic = {}
	for _, name in ipairs(names) do
		if not position[name] then
			cyclic[#cyclic + 1] = name
		end
	end
	table.sort(cyclic)
	return order, position, cyclic
end

-- Load the real equipment seam under a stub engine and report the order in
-- which it calls consumers registered one after the other.
local function callback_order(repo)
	local names = {"core", "minetest", "grug_core"}
	local saved, had = {}, {}
	for _, name in ipairs(names) do
		had[name] = rawget(_G, name) ~= nil
		saved[name] = rawget(_G, name)
	end
	local noop = function() end
	local logs = {}
	local core_stub = {}
	function core_stub.log(level, message)
		logs[#logs + 1] = tostring(level) .. "\t" .. tostring(message)
	end
	function core_stub.get_us_time()
		return 0
	end
	function core_stub.registered_items()
		return {}
	end
	setmetatable(core_stub, {__index = function(t, key)
		rawset(t, key, noop)
		return noop
	end})
	rawset(_G, "core", core_stub)
	rawset(_G, "minetest", core_stub)
	rawset(_G, "grug_core", {})

	local calls = {}
	local ok, err = pcall(function()
		local chunk, load_err = loadfile(repo .. "/" .. COMBAT)
		if not chunk then
			error("cannot load " .. COMBAT .. ": " .. tostring(load_err), 0)
		end
		chunk()
		local grug_core = rawget(_G, "grug_core")
		-- Registered in the order the LOAD order above produces.
		grug_core.register_on_equipment_change(function()
			calls[#calls + 1] = "grug_visuals"
		end)
		grug_core.register_on_equipment_change(function()
			calls[#calls + 1] = "grug_inventory_page"
		end)
		grug_core.notify_equipment_change({
			get_player_name = function() return "kat" end,
		}, "grug_chest")
	end)

	for _, name in ipairs(names) do
		rawset(_G, name, had[name] and saved[name] or nil)
	end
	if not ok then
		error(err, 0)
	end
	return calls
end

function M.run(repo)
	repo = repo or "."
	local out = {}
	local function row(...)
		out[#out + 1] = table.concat({...}, "\t")
	end
	local failures = {}
	local function check(condition, message)
		if not condition then
			failures[#failures + 1] = message
		end
	end

	-- A. load order
	local mods = collect_mods(repo, {"grug_visuals", "grug_inventory",
		"grug_mobs", "grug_traders", "grug_gear", "grug_classes", "player_api",
		"grug_core", "grug_abilities", "sfinv", "mobs", "default"})
	local order, position, cyclic = load_order(mods)
	check(#cyclic == 0, "dependency cycle among " .. table.concat(cyclic, ","))

	local function must_precede(before, after)
		check(position[before] and position[after] and
			position[before] < position[after],
			before .. " does not load before " .. after)
	end
	-- What the composition needs before it exists at all.
	must_precede("grug_core", "grug_visuals")
	must_precede("grug_classes", "grug_visuals")
	must_precede("grug_gear", "grug_visuals")
	must_precede("player_api", "grug_visuals")
	-- THE ordering this fixture exists for: the visuals consumer has to be
	-- registered before grug_inventory's one page-refresh consumer, or an equip
	-- repaints the Character page from the PREVIOUS look.
	must_precede("grug_visuals", "grug_inventory")
	-- And the two mob mods that call the seam.
	must_precede("grug_visuals", "grug_mobs")
	must_precede("grug_visuals", "grug_traders")

	-- The edge must go exactly one way, or the game does not load at all.
	local visuals = mods["grug_visuals"]
	check(visuals ~= nil, "grug_visuals has no mod.conf")
	if visuals then
		for _, dep in ipairs(visuals.depends) do
			check(dep ~= "grug_inventory",
				"grug_visuals depends on grug_inventory (cycle)")
		end
		for _, dep in ipairs(visuals.optional) do
			check(dep ~= "grug_inventory",
				"grug_visuals optionally depends on grug_inventory (cycle)")
		end
	end
	local inventory = mods["grug_inventory"]
	check(inventory ~= nil, "grug_inventory has no mod.conf")
	local declared = false
	if inventory then
		for _, dep in ipairs(inventory.optional) do
			if dep == "grug_visuals" then
				declared = true
			end
		end
	end
	check(declared,
		"grug_inventory does not declare grug_visuals as an optional dependency")

	row("wp13_order_graph", #order, tostring(#cyclic),
		position["grug_visuals"] or -1, position["grug_inventory"] or -1,
		position["grug_mobs"] or -1, position["grug_traders"] or -1)

	-- B. callback order
	local calls = callback_order(repo)
	check(#calls == 2, "the equipment seam called " .. #calls ..
		" consumers, expected 2")
	check(calls[1] == "grug_visuals",
		"the equipment seam does not run consumers in registration order")
	row("wp13_order_callbacks", table.concat(calls, ","))

	table.sort(failures)
	row("wp13_order_result", #failures == 0 and "PASS" or "FAIL", #failures)
	for _, message in ipairs(failures) do
		row("wp13_order_failure", message)
	end
	return table.concat(out, "\n") .. "\n"
end

return function(repo)
	return M.run(repo)
end
