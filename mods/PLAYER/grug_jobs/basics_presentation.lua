-- Explicit presentation policy for profession-free engine recipes. The route
-- itself stays owned by its content mod; this registry never grants crafting.
local M = {declarations = {}}
local MATERIALS = {bronze = 1, iron = 2, steel = 3, silversteel = 4,
	embersteel = 5, abyssal_steel = 6}
local WOODS = {"seasoned", "polished", "hardened", "inlaid", "lacquered", "heartwood"}
local CLOTH = {patch = 1, woven = 2, heavy = 3, silkweave = 4, silk = 5, stormweave = 6}
local LEATHER = {light = 1, cured = 2, heavy = 3, scaled = 4, sleek = 5, nightscale = 6}
local STARTER = {
	["default:stick"] = true, ["default:torch"] = true,
	["default:chest"] = true, ["default:furnace"] = true,
	["grug_farming:hoe"] = true, ["grug_gear:arrow"] = true,
	["default:wood"] = true, ["default:junglewood"] = true,
	["default:pine_wood"] = true, ["default:acacia_wood"] = true,
	["default:aspen_wood"] = true,
	["default:pick_bronze"] = true, ["default:axe_bronze"] = true,
	["default:shovel_bronze"] = true,
	["grug_professions:metal_rod_bronze"] = true,
	["grug_professions:thread"] = true,
	["grug_professions:bolt_patch"] = true,
	["grug_artisans:seasoned_wood"] = true,
}
local AUXILIARY = { ["default:stick"] = true, ["group:stick"] = true,
	["grug_materials:thread"] = true }

local function material_for_gear(output)
	local slot, line, grade = output:match("^grug_gear:([a-z]+)_([a-z]+)_(.+)$")
	if slot and line == "cloth" and CLOTH[grade] then
		return "grug_professions:bolt_" .. grade, CLOTH[grade]
	end
	if slot and line == "leather" and LEATHER[grade] then
		local tier = LEATHER[grade]
		local item = tier == 1 and "grug_mobs:light_leather" or
			(tier == 3 and "grug_mobs:heavy_leather" or
			(tier == 4 and "grug_mobs:scaled_hide" or
			"grug_professions:" .. grade .. "_leather"))
		return item, tier
	end
	local family, material = output:match("^grug_gear:([a-z]+)_(.+)$")
	local tier = material and MATERIALS[material]
	if not tier then return nil end
	if family == "wand" or family == "staff" or family == "bow" then
		return "grug_artisans:" .. WOODS[tier] .. "_wood", tier
	end
	return "grug_materials:" .. material .. "_bar", tier
end

local function explicit_main(recipe)
	local output = recipe.output_name
	if STARTER[output] then return nil, true end
	local main, tier = material_for_gear(output)
	if main then return main, tier == 1 end
	local def = core.registered_items[output] or {}
	local output_tier = tonumber(def._grug_tier)
	-- Content conversions declare their source through the only non-auxiliary
	-- token. This is deterministic route identity data, not input-order choice.
	local candidates, seen = {}, {}
	for _, token in ipairs(recipe.flat_inputs or {}) do
		if token ~= "" and not AUXILIARY[token] and not seen[token] then
			seen[token] = true; candidates[#candidates + 1] = token
		end
	end
	if #candidates == 1 then
		local starter = output_tier == 1 and (output:match("^grug_materials:") ~= nil)
		return candidates[1], starter
	end
	-- Ordinary construction outputs use the defining material token. Multiple
	-- copies collapse above; mixed-material routes must be named here explicitly.
	local priorities = {"group:wood", "group:stone", "group:sand", "group:wool",
		"default:glass", "default:steel_ingot", "default:copper_ingot",
		"default:tin_ingot", "default:gold_ingot", "grug_materials:iron_bar"}
	for _, wanted in ipairs(priorities) do
		if seen[wanted] then return wanted, false end
	end
	return nil, false, "no explicit main material for mixed route"
end

function M.route_key(recipe)
	local signature = table.concat(recipe.display_items or {}, "\1")
	return table.concat({recipe.station, recipe.output_name, recipe.method,
		tostring(recipe.width), tostring(recipe.shapeless), signature}, "\0")
end

function M.bind(records)
	local used = {}
	for _, recipe in ipairs(records) do
		local key = M.route_key(recipe)
		assert(not M.declarations[key], "duplicate Basics route declaration: " .. key)
		local main, starter, err = explicit_main(recipe)
		assert(starter or main, (err or "missing declaration") .. ": " .. key)
		local declaration = starter and {starter = true} or {main_material = main}
		M.declarations[key] = declaration; used[key] = true
		recipe.basics_route_key = key; recipe.basics_presentation = declaration
	end
	for key in pairs(M.declarations) do assert(used[key], "stale Basics declaration: " .. key) end
	return records
end
return M
