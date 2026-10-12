-- Round 46 lane CK: the Cooking recipes each race's zones can make from their
-- own ingredients (locality.lua holds the rules).
--
--   luajit tools/r46_ck/cook_local.lua [REPO] [--before OLD_REPO] [--all]
--   luajit tools/r46_ck/cook_local.lua [REPO] --recipes
--
-- --recipes lists every recipe instead: its inputs with their ingredient
-- tiers and the zones where each input and the whole recipe are local.
--
-- REPO defaults to the current directory. --before prints the recipes of an
-- older checkout (for example a `git archive` of the base commit) next to
-- them. By default only the start (1-10) and home (11-20) zones are listed;
-- --all lists every zone. A recipe whose thinnest input grows on less than
-- 10 % of the zone (its host biomes' share) is marked with that share.

local root, before_root, all, by_recipe = ".", nil, false, false
local args = arg or {}
local index = 1
while index <= #args do
	local value = args[index]
	if value == "--before" then
		index = index + 1
		before_root = args[index]
	elseif value == "--all" then
		all = true
	elseif value == "--recipes" then
		by_recipe = true
	else
		root = value
	end
	index = index + 1
end

local locality = dofile(root .. "/tools/r46_ck/locality.lua")
local after = locality.load(root)
local before = before_root and locality.load(before_root)

local RACES = {"dwarf", "human", "elf", "undead", "orc", "troll"}

local function names(world, zone_id)
	local out = {}
	for _, row in ipairs(locality.cookable(world, zone_id)) do
		local text = "T" .. row.recipe.tier .. " " .. row.recipe.name
		if row.recipe.role == "plain" then text = text .. " (plain)" end
		if row.share < 10 then text = text .. (" [thin %d%%]"):format(row.share) end
		out[#out + 1] = text
	end
	return #out > 0 and table.concat(out, ", ") or "none"
end

local function short(zone)
	return zone.display_name:gsub("^The ", ""):match("^%S+")
end

if by_recipe then
	for _, recipe in ipairs(after.recipes) do
		local parts, whole = {}, {}
		for _, token in ipairs(recipe.inputs) do
			local zones = {}
			for _, zone in ipairs(after.zones) do
				if locality.source(after, zone.id, token) then zones[#zones + 1] = short(zone) end
			end
			local name = token:gsub("^group:", "group "):gsub("^[%w_]+:", "")
			parts[#parts + 1] = ("  %s (T%s): %s"):format(name,
				tostring(after.tiers[token]), #zones == #after.zones and "every zone" or
				(#zones > 0 and table.concat(zones, " ") or "nowhere"))
		end
		for _, zone in ipairs(after.zones) do
			for _, row in ipairs(locality.cookable(after, zone.id)) do
				if row.recipe == recipe then whole[#whole + 1] = short(zone) end
			end
		end
		print(("T%d %s (%s): local in %s"):format(recipe.tier, recipe.name, recipe.role,
			#whole > 0 and table.concat(whole, " ") or "no single zone"))
		print(table.concat(parts, "\n"))
	end
	return
end

for _, race in ipairs(RACES) do
	print("## " .. race)
	for _, zone in ipairs(after.zones) do
		if zone.race_region == race and (all or zone.level_max <= 20) then
			print(("%s (L%d-%d)"):format(zone.display_name, zone.level_min, zone.level_max))
			if before then print("  before: " .. names(before, zone.id)) end
			print("  " .. (before and "after:  " or "") .. names(after, zone.id))
		end
	end
	print("")
end
