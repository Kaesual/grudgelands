-- Round 82 lane LOADER portable test: one shared WP13 loader context per
-- build (`wp13/templates.lua`, `wp13/dressing.lua`) cannot make a
-- blueprint depend on the order the build's blueprints are built in.
--
--   A. per capital (all six), with its kit's context: every template and
--      roster file is parsed once (as many `parse_template` calls as
--      templates in `context.parsed`);
--   B. the shared tables are only read: the parsed files (`context.parsed`)
--      digest the same after the kit loads, after every blueprint is built
--      and after a second build in reverse order, and the town tree pools
--      (`context.tree_pools`) the same after both builds;
--   C. order: every blueprint (whole, canonically) is the same built
--      forward, built again in reverse order, and built in reverse order
--      first from a new kit (so the pools grow in another order);
--   D. a start town (Kapok Hollow, whose layout, dressing and templates
--      share its context) builds the same with a context of its own as
--      with the one its caller hands it, and leaves its pools there.
--
-- Prints the template parses and tree generations per capital kit build
-- (a before/after comparison, never a gate). The capitals' identity
-- against the round's base is `tools/r82_capital`; every blueprint's,
-- `tools/r82_boot/dump.lua`.
-- Usage (repo root): luajit tools/r82_loader/portable_test.lua [REPO]
local repo = arg[1] or "."
_G.core = _G.core or {}
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local sha = common.new_sha256()
local canonical = dofile(repo .. "/tools/r82_capital/dump.lua").canonical
local function digest(value) return common.hex(sha(table.concat(canonical(value, {})))) end

local counts = {parse = 0, tree = 0}
local real_dofile = dofile
rawset(_G, "dofile", function(path)
	local result = real_dofile(path)
	if path:match("/templates%.lua$") then
		return function(...)
			local M = result(...)
			local parse = M.parse_template
			M.parse_template = function(...) counts.parse = counts.parse + 1 return parse(...) end
			return M
		end
	elseif path:match("/tree_templates%.lua$") then
		return function(...)
			local T = result(...)
			local tree = T.tree
			T.tree = function(...) counts.tree = counts.tree + 1 return tree(...) end
			return T
		end
	end
	return result
end)

local source = dofile(wp40 .. "/r7_capital_blueprint.lua")
local function builds(kit)
	local list = {kit.core.build}
	for _, plot in ipairs(kit.plots) do list[#list + 1] = plot.build end
	return list
end
local function build_all(list, reverse)
	local out = {}
	for step = 1, #list do
		local index = reverse and #list - step + 1 or step
		out[index] = digest(list[index]())
	end
	return out
end
local function same(a, b)
	if #a ~= #b then return false end
	for index = 1, #a do if a[index] ~= b[index] then return false end end
	return true
end

for _, key in ipairs({"highcourt", "dur_brannoc", "lethariel", "nhal_veyr", "gor_drazhak",
		"kezamba"}) do
	counts.parse, counts.tree = 0, 0
	local context = {}
	local kit = source.kit(key, context)
	local templates, rosters = 0, 0
	for path in pairs(context.parsed) do
		if path:match("%.tpl$") then templates = templates + 1
		elseif path:match("%.roster$") then rosters = rosters + 1 end
	end
	check(counts.parse == templates and rosters == 1,
		key .. ": each file parsed once (" .. counts.parse .. " parses, " .. templates ..
		" templates, " .. rosters .. " roster)")
	local parsed = digest(context.parsed)
	local list = builds(kit)
	local forward = build_all(list)
	local pools = digest(context.tree_pools or {})
	local parses, trees = counts.parse, counts.tree
	check(digest(context.parsed) == parsed, key .. ": the parsed files are unchanged by a build")
	check(same(build_all(list, true), forward), key .. ": a reverse build answers the same")
	check(digest(context.parsed) == parsed and digest(context.tree_pools or {}) == pools,
		key .. ": the parsed files and the tree pools are unchanged by a second build")
	check(same(build_all(builds(source.kit(key)), true), forward),
		key .. ": a new kit built in reverse order first answers the same")
	print(string.format("  %-12s %d blueprints, %d template parses, %d tree generations",
		key, #list, parses, trees))
end

do
	local library = dofile(wp40 .. "/r7_wp13_library.lua")
	local own = digest(library.composition("kapok")())
	local context = {}
	local handed = digest(library.composition("kapok", context)())
	check(own == handed, "kapok: the same with its own context and a handed one")
	local species = 0
	for _ in pairs(context.tree_pools or {}) do species = species + 1 end
	check(species > 0 and context.tree_templates ~= nil and next(context.parsed) ~= nil,
		"kapok: its pools, tree generator and parsed templates are the context's")
end

rawset(_G, "dofile", real_dofile)
print("r82_loader portable test: PASS (" .. checks .. " checks)")
