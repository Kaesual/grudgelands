-- Universal reagents (Round 28 ruling 28, design frame §4.5): a few crafted
-- enchant inputs anyone can make on the crafting grid or in a furnace, from
-- data/reagents.json. A missing file means no reagents.

local P = grug_professions
P.REAGENTS = {}

-- Stand-in until the reagent's own icon `<mod>_<name>.png` ships in its mod.
local PLACEHOLDER = "default_paper.png^[colorize:#9a86b8:125"

local function inventory_image(id)
	local mod, name = id:match("^([^:]+):(.+)$")
	local path = core.get_modpath(mod)
	local file = mod .. "_" .. name .. ".png"
	for _, entry in ipairs(path and core.get_dir_list(path .. "/textures", false) or {}) do
		if entry == file then return file end
	end
	return PLACEHOLDER
end

-- Mods a reagent id may live in: this mod and its hard dependencies (read
-- from mod.conf, so the list cannot drift).
local ALLOWED_MODS = {grug_professions = true}
do
	local file = io.open(core.get_modpath("grug_professions") .. "/mod.conf", "r")
	local text = file and file:read("*a") or ""
	if file then file:close() end
	local depends = text:match("\ndepends%s*=%s*([^\n]*)") or ""
	for mod in depends:gmatch("[%w_]+") do ALLOWED_MODS[mod] = true end
end

function P.register_reagents(rows)
	rows = P.enchant_data.validate_reagents(rows)
	P.enchant_data.check_reagent_ids(rows, ALLOWED_MODS, core.registered_items)
	for index = 1, #rows do
		local row = rows[index]
		-- The leading ":" allows an id in another mod's namespace (frame §4.5).
		core.register_craftitem(":" .. row.id, {
			description = row.name,
			inventory_image = inventory_image(row.id),
			groups = {grug_reagent = 1},
			_grug_tier = row.tier,
		})
		grug_jobs.register_ingredient_tier(row.id, row.tier)
		local output = row.output_count > 1 and (row.id .. " " .. row.output_count) or row.id
		local route = {output = row.id, width = 0, owner = "general",
			main_material = row.inputs[1]}
		if row.method == "grid" then
			core.register_craft({type = "shapeless", output = output, recipe = row.inputs})
			route.station, route.method, route.shapeless = "grid", "normal", true
			route.inputs = row.inputs
		else
			core.register_craft({type = "cooking", output = output, recipe = row.inputs[1]})
			route.station, route.method, route.shapeless = "furnace", "cooking", false
			route.inputs = {row.inputs[1]}
		end
		grug_jobs.basics_presentation.declare(route)
		P.REAGENTS[#P.REAGENTS + 1] = row
	end
end

P.register_reagents(P.read_json("reagents.json"))

core.register_on_mods_loaded(function()
	for _, row in ipairs(P.REAGENTS) do
		if core.get_item_group(row.id, "grug_reagent") ~= 1 then
			error("grug_professions: reagent " .. row.id .. " was overridden", 0)
		end
	end
	local offences = P.enchant_data.unregistered_reagent_inputs(P.REAGENTS, core.registered_items)
	if #offences > 0 then
		error("grug_professions: " .. table.concat(offences, "\n"), 0)
	end
end)
