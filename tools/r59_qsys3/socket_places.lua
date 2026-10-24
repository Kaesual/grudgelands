-- Round 59 lane QSYS3: the authored sockets of named settlements, built
-- from their templates and blueprints the way the mapgen builds them,
-- without a world (quests.md "Use at a place", the town place kind). The
-- quest tools read it to check a town place, `socket:<settlement key>/<socket
-- id>`, where the game asks its settlement socket registry
-- (grug_quests/labels.lua Q.use_place).
--
-- What is built, by the settlement's roster row (wp40/r7_settlement.lua):
--   * a capital: its kit (wp40/r7_capital_blueprint.lua), the core and every
--     district plot; a plot's sockets carry the plot id as their prefix
--     (`<plot id>/<socket id>`, r7_settlement.lua M.sockets). A socket is
--     `required` when every world builds it: the core's and those of the
--     plots the capital planner always places (the inn, the service plots
--     and the Miner's Guild house, wp13/capital_services.lua; r7_capitals.lua
--     required_of). Another plot stands on some worlds only;
--   * every other settlement (a start town, a village, an outpost, a camp, a
--     POI): its blueprint file with the start's civic dressing, one
--     anchor-relative blueprint whose socket ids are the registry's.
-- A blueprint that rolls per world (a camp's race) is built with a fixed
-- seed: socket ids and roles do not depend on it.
--
-- As a module (portable quest harnesses):
--   local places = dofile(REPO .. "/tools/r59_qsys3/socket_places.lua")
--   local found = places.sockets(REPO, {"highcourt"}, {templates = DIR})
--   found.highcourt = {key, label, slot, race, zone_id,
--     sockets = {{id, role, x, y, z, dir, tags, required}, ...}} (nil: no
--     such settlement); places.parse_ref(ref) -> key, socket id (or nil).
--   places.registry(found) -> settlement_socket_settlements and
--     settlement_sockets_at stand-ins over `found` (anchor 0,0,0).
-- As a command (tools/r28_design/validate.py):
--   luajit tools/r59_qsys3/socket_places.lua REPO [--templates DIR] KEY...
--   prints "settlement <key> <slot> <zone id>" and "socket <key> <id> <role>
--   <required 0|1>" lines, or "unknown <key>"; `--templates DIR` builds from
--   a building_templates copy (a test's).
-- Plain Lua 5.1 / LuaJIT, no engine.

local M = {}
M.PREFIX = "socket:"

-- "socket:<settlement key>/<socket id>" -> key, socket id; nil otherwise.
function M.parse_ref(ref)
	if type(ref) ~= "string" or ref:sub(1, #M.PREFIX) ~= M.PREFIX then return nil end
	local key, id = ref:sub(#M.PREFIX + 1):match("^([a-z][a-z0-9_]*)/([a-z][a-z0-9_/]*[a-z0-9_])$")
	return key, id
end

local function copy_socket(socket, id, required)
	local tags
	if type(socket.tags) == "table" then
		tags = {}
		for i, tag in ipairs(socket.tags) do tags[i] = tag end
	end
	return {id = id, role = socket.role, x = socket.x, y = socket.y, z = socket.z,
		dir = type(socket.dir) == "table" and {x = socket.dir.x, z = socket.dir.z} or nil,
		tags = tags, required = required}
end

local function landmark_sockets(blueprint)
	local landmarks = type(blueprint) == "table" and blueprint.landmarks
	return type(landmarks) == "table" and type(landmarks.sockets) == "table" and landmarks.sockets or {}
end

-- {key -> settlement} for `keys` (opts.templates: a building_templates
-- directory to build from instead of the repository's).
function M.sockets(repo, keys, opts)
	opts = opts or {}
	rawset(_G, "core", rawget(_G, "core") or {})
	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
	local saved_dofile = dofile
	if opts.templates then
		-- Every template loader the mapgen makes reads from that directory
		-- (tools/building_templates/loader_check.lua's seam).
		rawset(_G, "dofile", function(path)
			local chunk = saved_dofile(path)
			if path:match("/templates%.lua$") then
				return function(directory)
					local loader = chunk(directory)
					loader.ROOT = opts.templates
					return loader
				end
			end
			return chunk
		end)
	end
	local ok, result = pcall(function()
		local settlement = dofile(wp40 .. "/r7_settlement.lua")
		local services = dofile(wp13 .. "/capital_services.lua")
		local common = dofile(repo .. "/tools/wp40/r6/common.lua")
		local options = {full_seed = 1, raw_sha256 = common.new_sha256()}
		local by_key = {}
		for _, profile in ipairs(settlement.roster) do by_key[profile.key] = profile end
		local out = {}
		for _, key in ipairs(keys) do
			local profile = by_key[key]
			if profile and not out[key] then
				local row = {key = key, label = profile.label, slot = profile.slot, race = profile.race,
					zone_id = profile.zone_id, sockets = {}}
				if profile.slot == "capital" then
					local required = {[services.GUILD_HALL.plot] = true, [services.INNS[key]] = true}
					for _, plot in pairs(services.PLOTS[key] or {}) do required[plot] = true end
					local kit = dofile(wp40 .. "/r7_capital_blueprint.lua").kit(key)
					for _, socket in ipairs(landmark_sockets(kit.core.build())) do
						row.sockets[#row.sockets + 1] = copy_socket(socket, socket.id, true)
					end
					for _, plot in ipairs(kit.plots) do
						for _, socket in ipairs(landmark_sockets(plot.build())) do
							row.sockets[#row.sockets + 1] = copy_socket(socket, plot.id .. "/" .. socket.id,
								required[plot.id] == true)
						end
					end
				else
					local source = dofile(wp40 .. "/" .. profile.blueprint_file)(options, profile)
					if type(source) == "function" then source = source(options) end
					if profile.slot == "start" then source = dofile(wp40 .. "/r20_civic.lua")(source, profile) end
					for _, socket in ipairs(landmark_sockets(source)) do
						row.sockets[#row.sockets + 1] = copy_socket(socket, socket.id, true)
					end
				end
				out[key] = row
			end
		end
		return out
	end)
	rawset(_G, "dofile", saved_dofile)
	if not ok then error(result, 0) end
	return result
end

-- The two registry queries over `found` (each settlement at anchor 0,0,0,
-- so a socket's world position is its own x, y, z), as fresh copies.
function M.registry(found)
	local keys = {}
	for key in pairs(found) do keys[#keys + 1] = key end
	table.sort(keys)
	local reg = {}
	function reg.settlement_socket_settlements()
		local out = {}
		for _, key in ipairs(keys) do
			local row = found[key]
			out[#out + 1] = {key = key, display_name = row.label, slot = row.slot, race_id = row.race,
				anchor = {x = 0, y = 0, z = 0}}
		end
		return out
	end
	function reg.settlement_sockets_at(key)
		local out = {}
		for _, socket in ipairs(found[key] and found[key].sockets or {}) do
			local row = copy_socket(socket, socket.id, socket.required)
			row.pos = {x = socket.x, y = socket.y, z = socket.z}
			out[#out + 1] = row
		end
		return out
	end
	return reg
end

-- The command.
if select("#", ...) > 0 then
	local args = {...}
	local repo, templates, keys = args[1], nil, {}
	local i = 2
	while args[i] do
		if args[i] == "--templates" then
			templates, i = args[i + 1], i + 2
		else
			keys[#keys + 1], i = args[i], i + 1
		end
	end
	local found = M.sockets(repo, keys, {templates = templates})
	local lines = {}
	for _, key in ipairs(keys) do
		local row = found[key]
		if not row then
			lines[#lines + 1] = "unknown " .. key
		else
			lines[#lines + 1] = ("settlement %s %s %s"):format(key, row.slot, row.zone_id)
			for _, socket in ipairs(row.sockets) do
				lines[#lines + 1] = ("socket %s %s %s %d"):format(key, socket.id, tostring(socket.role),
					socket.required and 1 or 0)
			end
		end
	end
	print(table.concat(lines, "\n"))
end
return M
