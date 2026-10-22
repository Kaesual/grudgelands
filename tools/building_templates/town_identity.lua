-- What the start towns build, as two digests per town (Round 56 lane
-- FREEZE-TOWNS): the settlement identity SHA-256 `r7_settlement.prepare`
-- publishes (schema, bounds, palette and every cell) and a POINT DIGEST of
-- everything the identity bytes leave out (the blueprint without its cells:
-- landmarks, sockets, doorways, rooms, inside points, destinations, boxes and
-- so the building peaks, lights and counts), SHA-256 over a canonical
-- serialisation with sorted keys.
--
-- The six capitals print one line each as well (Round 56 lane
-- FREEZE-CAPITALS): an IDENTITY digest over the settlement identity SHA-256
-- of the core and of every district plot as `r7_settlement` computes them,
-- the cell count, a POINT DIGEST over every one of those blueprints without
-- its cells, a BUILD digest over their whole blueprints (cells included,
-- canonical serialisation) and the blueprint count, so a change of what a
-- capital builds shows too.
--
-- Usage: luajit tools/building_templates/town_identity.lua <repo> [<tree>] [--load]
--   <tree> is the checkout whose `mods/MAPGEN/grug_mapgen` is built (default:
--   the repo itself; `tools/check_upgrade.py` passes an extracted earlier
--   release). Prints one line per town: key, identity, cells, point digest.
--   --load adds the construction numbers: the median CPU seconds of five
--   constructions (loading the composition and building it; a capital: its
--   kit, its core and every district plot, median of three) and the KB the
--   Lua heap allocates during one (collector stopped).
--
-- The tool itself is LuaJIT (SHA-256 through tools/wp40/r6/common.lua).

local repo = arg[1] or "."
local tree, load_numbers = repo, false
for index = 2, #arg do
	if arg[index] == "--load" then load_numbers = true else tree = arg[index] end
end
local wp40 = tree .. "/mods/MAPGEN/grug_mapgen/wp40"
_G.core = _G.core or {}
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local sha = common.new_sha256()

local function canonical(value, out)
	local kind = type(value)
	if kind == "table" then
		local keys = {}
		for key in pairs(value) do keys[#keys + 1] = key end
		table.sort(keys, function(a, b)
			if type(a) ~= type(b) then return type(a) < type(b) end
			return a < b
		end)
		out[#out + 1] = "{"
		for _, key in ipairs(keys) do
			canonical(key, out)
			out[#out + 1] = "="
			canonical(value[key], out)
			out[#out + 1] = ";"
		end
		out[#out + 1] = "}"
	elseif kind == "number" then
		out[#out + 1] = string.format("n%.17g", value)
	elseif kind == "string" then
		out[#out + 1] = string.format("%q", value)
	elseif kind == "boolean" then
		out[#out + 1] = value and "T" or "F"
	else
		error("point digest: a " .. kind .. " in the blueprint")
	end
	return out
end

local function point_digest(blueprint)
	local copy = {}
	for key, value in pairs(blueprint) do
		if key ~= "cells" then copy[key] = value end
	end
	return common.hex(sha(table.concat(canonical(copy, {}))))
end

for _, profile in ipairs(settlement.roster) do
	if profile.slot == "start" then
		local path = wp40 .. "/" .. profile.blueprint_file
		local blueprint = dofile(path)()
		local prepared = settlement.prepare(profile, blueprint, sha)
		local identity = prepared.blueprints[1].identity
		local line = {profile.key, identity.sha256, identity.cell_count,
			point_digest(blueprint)}
		if load_numbers then
			local times = {}
			for run = 1, 5 do
				collectgarbage("collect")
				local started = os.clock()
				dofile(path)()
				times[run] = os.clock() - started
			end
			table.sort(times)
			collectgarbage("collect")
			collectgarbage("stop")
			local before = collectgarbage("count")
			local kept = dofile(path)()
			local allocated = collectgarbage("count") - before
			collectgarbage("restart")
			kept = nil
			line[#line + 1] = string.format("%.3f", times[3])
			line[#line + 1] = string.format("%.0f", allocated)
		end
		print(table.concat(line, "\t"))
	end
end

local capital = dofile(wp40 .. "/r7_capital_blueprint.lua")
local profiles = {}
for _, profile in ipairs(settlement.roster) do profiles[profile.key] = profile end
local function build_capital(key)
	local kit = capital.kit(key)
	local list = {{id = "core", schema = kit.core.schema, blueprint = kit.core.build()}}
	for _, plot in ipairs(kit.plots) do
		list[#list + 1] = {id = plot.id, schema = plot.schema, blueprint = plot.build()}
	end
	return list
end
for _, key in ipairs({"highcourt", "dur_brannoc", "lethariel", "nhal_veyr",
		"gor_drazhak", "kezamba"}) do
	local profile = profiles[key]
	local list = build_capital(key)
	local identities, points, digests, cells = {}, {}, {}, 0
	for index, entry in ipairs(list) do
		local blueprint = entry.blueprint
		cells = cells + #blueprint.cells
		local prepared
		if index == 1 then
			-- the core through the anchor path every start takes: the same
			-- bounds and schemas as the capital's own core descriptor
			prepared = settlement.prepare(profile, blueprint, sha).blueprints[1]
		else
			prepared = settlement.prepare_plot(profile, {id = entry.id, schema = entry.schema,
				build = function() return blueprint end}, sha)
		end
		identities[#identities + 1] = entry.id .. ":" .. prepared.identity.sha256
		points[#points + 1] = entry.id .. ":" .. point_digest(blueprint)
		digests[#digests + 1] = (index == 1 and "core" or entry.id) .. ":" ..
			common.hex(sha(table.concat(canonical(blueprint, {}))))
	end
	local line = {key, common.hex(sha(table.concat(identities, "\n"))), cells,
		common.hex(sha(table.concat(points, "\n"))),
		common.hex(sha(table.concat(digests, "\n"))), #digests}
	if load_numbers then
		local times = {}
		for run = 1, 3 do
			collectgarbage("collect")
			local started = os.clock()
			capital = dofile(wp40 .. "/r7_capital_blueprint.lua")
			build_capital(key)
			times[run] = os.clock() - started
		end
		table.sort(times)
		collectgarbage("collect")
		collectgarbage("stop")
		local before = collectgarbage("count")
		capital = dofile(wp40 .. "/r7_capital_blueprint.lua")
		local kept = build_capital(key)
		local allocated = collectgarbage("count") - before
		collectgarbage("restart")
		kept = nil
		line[#line + 1] = string.format("%.3f", times[2])
		line[#line + 1] = string.format("%.0f", allocated)
	end
	print(table.concat(line, "\t"))
end
