-- What the start towns build, as two digests per town (Round 56 lane
-- FREEZE-TOWNS): the settlement identity SHA-256 `r7_settlement.prepare`
-- publishes (schema, bounds, palette and every cell) and a POINT DIGEST of
-- everything the identity bytes leave out (the blueprint without its cells:
-- landmarks, sockets, doorways, rooms, inside points, destinations, boxes and
-- so the building peaks, lights and counts), SHA-256 over a canonical
-- serialisation with sorted keys.
--
-- The six capitals print one line each as well: a digest over their core's
-- and every district plot's whole blueprint (cells included, canonical
-- serialisation) and the cell count, so a change of what a capital builds
-- shows too.
--
-- Usage: luajit tools/building_templates/town_identity.lua <repo> [<tree>] [--load]
--   <tree> is the checkout whose `mods/MAPGEN/grug_mapgen` is built (default:
--   the repo itself; `tools/check_upgrade.py` passes an extracted earlier
--   release). Prints one line per town: key, identity, cells, point digest.
--   --load adds the construction numbers: the median CPU seconds of five
--   constructions (loading the composition and building it) and the KB the
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
for _, key in ipairs({"highcourt", "dur_brannoc", "lethariel", "nhal_veyr",
		"gor_drazhak", "kezamba"}) do
	local kit = capital.kit(key)
	local digests, cells = {}, 0
	local core = kit.core.build()
	cells = cells + #core.cells
	digests[#digests + 1] = "core:" .. common.hex(sha(table.concat(canonical(core, {}))))
	for _, plot in ipairs(kit.plots) do
		local built = plot.build()
		cells = cells + #built.cells
		digests[#digests + 1] = plot.id .. ":" ..
			common.hex(sha(table.concat(canonical(built, {}))))
	end
	print(table.concat({key, common.hex(sha(table.concat(digests, "\n"))), cells,
		#digests}, "\t"))
end
