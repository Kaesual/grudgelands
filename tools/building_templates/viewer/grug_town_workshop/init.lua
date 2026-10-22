-- Town workshop: a dev-only world mod for rebuilding a start town by hand in
-- a local Luanti world and handing the result to the blueprint diff
-- (tools/building_templates/viewer/diff_town.py). Never shipped: it lives under tools/ and
-- is copied into one world's `worldmods/` only.
--
-- On join every player gets the building rights (creative inventory, fly,
-- fast, noclip, teleport, protection bypass, peaceful mobs).
--
--   /town_go <town>              teleport above the town's anchor
--   /town_export <town> [label]  write the town square to
--                                <world>/town_exports/<town>-<label>.tsv
--
-- A file `prepare.txt` next to this init.lua (one town key per line) turns
-- the mod into the world preparer instead: on the first start it generates
-- each listed town, writes its "baseline" export and shuts the server down.
-- The preparing copy is staged with `PROBE=` of tools/luanti_headless.sh;
-- the copy that goes into the world has no prepare.txt.

local MODPATH = core.get_modpath(core.get_current_modname())
local WORLD = core.get_worldpath()
local PREFIX = "[town_workshop] "

-- Start-town anchors, as in mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua.
local TOWNS = {
	hearthpine = {x = -1800, z = -2550},
	dawnmere = {x = 0, z = -2550},
	silverleaf = {x = 1800, z = -2550},
	stillgrave = {x = -1800, z = 2550},
	sunscar = {x = 0, z = 2550},
	kapok = {x = 1800, z = 2550},
}
-- The blueprints span x/z [-63, 63]; one node of margin on each side.
local HALF = 64
-- The search column for the ground at the anchor, and the export window
-- around it (the blueprints span local y [-2, 24]).
local SEARCH_LOW, SEARCH_HIGH = -64, 192
local BELOW, ABOVE = 24, 48

local STORAGE = core.get_mod_storage()

local function log(message) core.log("action", PREFIX .. message) end

-- ------------------------------------------------------------------ rights

local RIGHTS = {"interact", "shout", "creative", "fly", "fast", "noclip",
	"teleport", "protection_bypass", "peaceful_player", "home"}

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local privs = core.get_player_privs(name)
	for _, priv in ipairs(RIGHTS) do
		if core.registered_privileges[priv] then privs[priv] = true end
	end
	core.set_player_privs(name, privs)
	core.chat_send_player(name, "Town workshop: building rights granted. " ..
		"/town_go dawnmere, then /town_export dawnmere when done.")
end)

-- Immortal builders. Re-applied every few seconds: character creation
-- (grug_classes) restores the armor groups it found on join when it closes.
local function shield_all()
	for _, player in ipairs(core.get_connected_players()) do
		local groups = player:get_armor_groups()
		if groups.immortal ~= 1 then
			groups.immortal = 1
			player:set_armor_groups(groups)
		end
	end
	core.after(3, shield_all)
end
core.after(1, shield_all)

-- No fast hand: grug_materials' startup audit refuses any rock-digging
-- capability outside the pick ladder, the hand included. The creative
-- inventory holds the top pick.

-- --------------------------------------------------------------- the town

local function window_around(anchor, y0, y1)
	return {x = anchor.x - HALF, y = y0, z = anchor.z - HALF},
		{x = anchor.x + HALF, y = y1, z = anchor.z + HALF}
end

-- Emerge the whole search volume of a town, then call `done(surface_y)`.
local function with_town(key, done)
	local anchor = TOWNS[key]
	local minp, maxp = window_around(anchor, SEARCH_LOW, SEARCH_HIGH)
	local started = core.get_us_time()
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		log(("emerged %s in %.1f s"):format(key, (core.get_us_time() - started) / 1e6))
		local surface
		for y = SEARCH_HIGH, SEARCH_LOW, -1 do
			local name = core.get_node({x = anchor.x, y = y, z = anchor.z}).name
			local def = core.registered_nodes[name]
			if name ~= "air" and name ~= "ignore" and def and def.walkable ~= false then
				surface = y
				break
			end
		end
		done(surface)
	end)
end

-- The export window hangs off the ground height found for the first export
-- (the baseline) and keeps it, so building at the anchor later (a well, a
-- statue) cannot shift the window between baseline and after.
local function window_surface(key, found)
	local stored = tonumber(STORAGE:get_string("surface_" .. key))
	if stored then return stored end
	if found then STORAGE:set_string("surface_" .. key, tostring(found)) end
	return found
end

local function export(key, label, surface)
	local anchor = TOWNS[key]
	local minp, maxp = window_around(anchor, surface - BELOW, surface + ABOVE)
	local vm = VoxelManip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	local data, param2 = vm:get_data(), vm:get_param2_data()
	local c_air, c_ignore = core.get_content_id("air"), core.get_content_id("ignore")
	local names = {}
	local lines = {
		("#town\t%s"):format(key),
		("#label\t%s"):format(label),
		("#anchor\t%d\t%d"):format(anchor.x, anchor.z),
		("#surface\t%d"):format(surface),
		("#window\t%d\t%d\t%d\t%d\t%d\t%d"):format(minp.x, minp.y, minp.z, maxp.x, maxp.y, maxp.z),
		("#time\t%s"):format(os.date("!%Y-%m-%dT%H:%M:%SZ")),
	}
	local count = 0
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			local i = area:index(minp.x, y, z)
			for x = minp.x, maxp.x do
				local id = data[i]
				if id ~= c_air and id ~= c_ignore then
					local name = names[id]
					if not name then name = core.get_name_from_content_id(id); names[id] = name end
					count = count + 1
					lines[#lines + 1] = ("%d\t%d\t%d\t%s\t%d"):format(x, y, z, name, param2[i])
				end
				i = i + 1
			end
		end
	end
	core.mkdir(WORLD .. "/town_exports")
	local path = ("%s/town_exports/%s-%s.tsv"):format(WORLD, key, label)
	local ok = core.safe_file_write(path, table.concat(lines, "\n") .. "\n")
	log(("export %s: %d nodes -> %s (%s)"):format(key, count, path, ok and "ok" or "FAILED"))
	return ok and path or nil, count
end

-- ---------------------------------------------------------------- commands

local function town_arg(param)
	local key, rest = param:match("^%s*(%S+)%s*(.-)%s*$")
	if not key or not TOWNS[key] then
		local keys = {}
		for k in pairs(TOWNS) do keys[#keys + 1] = k end
		table.sort(keys)
		return nil, "Name a town: " .. table.concat(keys, ", ")
	end
	return key, rest
end

core.register_chatcommand("town_go", {
	params = "<town>",
	description = "Teleport above a start town's anchor",
	privs = {teleport = true},
	func = function(name, param)
		local key, err = town_arg(param)
		if not key then return false, err end
		core.chat_send_player(name, "Generating " .. key .. " if needed ...")
		with_town(key, function(surface)
			local player = core.get_player_by_name(name)
			if not player then return end
			local anchor = TOWNS[key]
			player:set_pos({x = anchor.x, y = (surface or 40) + 12, z = anchor.z})
			core.chat_send_player(name, "Above " .. key .. ". Fly down with the sneak key.")
		end)
		return true
	end,
})

core.register_chatcommand("town_export", {
	params = "<town> [label]",
	description = "Write the town square to <world>/town_exports/<town>-<label>.tsv",
	privs = {interact = true},
	func = function(name, param)
		local key, label = town_arg(param)
		if not key then return false, label end
		label = (label ~= "" and label or os.date("%Y%m%d-%H%M%S")):gsub("[^%w_-]", "_")
		with_town(key, function(found)
			local surface = window_surface(key, found)
			if not surface then
				core.chat_send_player(name, "No ground found at the anchor of " .. key .. ".")
				return
			end
			local path, count = export(key, label, surface)
			core.chat_send_player(name, path and
				("Exported %d nodes to %s"):format(count, path) or "Export failed, see the log.")
		end)
		return true
	end,
})

-- ---------------------------------------------------------------- prepare

local prepare = {}
local file = io.open(MODPATH .. "/prepare.txt", "r")
if file then
	for line in file:lines() do
		local key = line:match("^%s*(%S+)")
		if key and TOWNS[key] then prepare[#prepare + 1] = key end
	end
	file:close()
end

if #prepare > 0 then
	core.after(1, function()
		local i = 0
		local function next_town()
			i = i + 1
			local key = prepare[i]
			if not key then
				log("PREPARE DONE")
				core.request_shutdown("town workshop prepared", false, 0)
				return
			end
			with_town(key, function(found)
				local surface = window_surface(key, found)
				if surface then export(key, "baseline", surface)
				else core.log("error", PREFIX .. "no ground at " .. key) end
				next_town()
			end)
		end
		next_town()
	end)
end
