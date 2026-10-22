-- The game's own loader over the building template files, for the validator
-- (Round 56 lane FREEZE-CAPITALS, building-template-format.md §6): check.py's
-- Python parser and `wp13/templates.lua` must accept the same files, so the
-- gate runs the game's loader too.
--
--   luajit tools/building_templates/loader_check.lua <repo> <building_templates dir> [build]
--
-- reads the file names (`templates/<name>.tpl`, `layouts/<town>.layout`,
-- `layouts/<capital>.roster`) on stdin, from <building_templates dir> (the
-- repository's own, or a copy with the editor's unsaved files), and prints:
--   error <file> <reason>      a file the game's loader refuses
-- With `build`, it also builds every start town and capital the way the game
-- does, from those files, and prints
--   error <town> <reason>      a town or capital that does not build
--   use <capital> <count> <use key>   how often the capital's code placed
--                                     each template and palette combination
-- Plain Lua 5.1 under LuaJIT (no engine).

local repo, dir, build = arg[1], arg[2], arg[3] == "build"
assert(repo and dir, "usage: loader_check.lua <repo> <building_templates dir> [build]")
_G.core = _G.core or {}
local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"

local out = {}
local function say(...) out[#out + 1] = table.concat({...}, " ") end
local function one_line(message)
	return (tostring(message):gsub("%s*\n%s*", " | "))
end

-- Every loader the game makes reads from `dir`, and every capital it makes
-- is remembered, so its placements can be counted.
local capitals = {}
local saved_dofile = dofile
_G.dofile = function(path)
	local chunk = saved_dofile(path)
	if path:match("/templates%.lua$") then
		return function(directory)
			local loader = chunk(directory)
			loader.ROOT = dir
			local capital = loader.capital
			loader.capital = function(id)
				local made = capital(id)
				capitals[id] = capitals[id] or {}
				table.insert(capitals[id], made)
				return made
			end
			return loader
		end
	end
	return chunk
end

local templates = dofile(wp13 .. "/templates.lua")(wp13)
local towns, rosters = {}, {}
for name in io.read("*a"):gmatch("%S+") do
	local path = dir .. "/" .. name
	local file = io.open(path, "rb")
	local text = file and file:read("*a")
	if file then file:close() end
	local base = name:match("^templates/([%w_]+)%.tpl$")
	local town = name:match("^layouts/([%w_]+)%.layout$")
	local capital = name:match("^layouts/([%w_]+)%.roster$")
	local ok, err = true, nil
	if not text then
		ok, err = false, "the file is missing"
	elseif base then
		ok, err = pcall(templates.parse_template, text, name, base)
	elseif town then
		ok, err = pcall(templates.town, town)
		towns[#towns + 1] = town
	elseif capital then
		ok, err = pcall(templates.capital, capital)
		rosters[#rosters + 1] = capital
	else
		ok, err = false, "not a building template file"
	end
	if not ok then say("error", name, one_line(err)) end
end

if build then
	-- the start towns through their blueprint files, the capitals through
	-- their kits (the core and every district plot), as the mapgen builds them
	local settlement = dofile(wp40 .. "/r7_settlement.lua")
	for _, profile in ipairs(settlement.roster) do
		if profile.slot == "start" then
			local ok, err = pcall(function()
				return dofile(wp40 .. "/" .. profile.blueprint_file)()
			end)
			if not ok then say("error", profile.key, one_line(err)) end
		end
	end
	local capital_source = dofile(wp40 .. "/r7_capital_blueprint.lua")
	for _, key in ipairs(rosters) do
		capitals[key] = {}
		local ok, err = pcall(function()
			local kit = capital_source.kit(key)
			kit.core.build()
			for _, plot in ipairs(kit.plots) do plot.build() end
		end)
		if not ok then
			say("error", key, one_line(err))
		else
			local counts, keys = {}, {}
			for _, made in ipairs(capitals[key]) do
				for use, count in pairs(made.used) do
					if not counts[use] then keys[#keys + 1] = use end
					counts[use] = (counts[use] or 0) + count
				end
			end
			table.sort(keys)
			for _, use in ipairs(keys) do say("use", key, counts[use], use) end
		end
	end
end
print(table.concat(out, "\n"))
