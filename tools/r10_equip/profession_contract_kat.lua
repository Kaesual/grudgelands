-- Focused independent contract for the R10 equipment profession catalogs.
return function(repo)
	local saved = {core=core, grug_professions=grug_professions,
		grug_artisans=grug_artisans}
	local function fail(message)
		core, grug_professions, grug_artisans = saved.core, saved.grug_professions,
			saved.grug_artisans
		error("r10 profession contract: " .. message, 0)
	end
	core = {registered_items = {}}
	function core.registered_item() end
	function core.clear_craft() end
	local universal={}
	function core.register_craft(def)
		if def.output then universal[def.output:match("^([^%s]+)")]=true end
	end
	local recipes = {}
	grug_professions = {}
	function grug_professions.register_item(name) core.registered_items[name]={}; return name end
	function grug_professions.register_ingredient() end
	function grug_professions.register_recipe(profession, def)
		recipes[#recipes+1]={profession=profession, def=def}; return def
	end
	function grug_professions.register_refinement(profession,tier,family,base,material)
		recipes[#recipes+1]={profession=profession,def={tier=tier,family=family,
			output=base,material=material,operation="refinement"}}
	end
	function grug_professions.register_add_affix(profession,tier,family,base,material,reagent)
		recipes[#recipes+1]={profession=profession,def={tier=tier,family=family,
			output=base,material=material,reagent=reagent,operation="add_affix"}}
	end
	for _, path in ipairs({"smiths.lua","leatherworker.lua","tailor.lua"}) do
		local ok, problem=pcall(dofile,repo.."/mods/ITEMS/grug_professions/"..path)
		if not ok then fail(problem) end
	end
	grug_artisans={}
	function grug_artisans.register_item(name) core.registered_items[name]={}; return name end
	function grug_artisans.register_ingredient() end
	function grug_artisans.register_recipe(profession,def)
		recipes[#recipes+1]={profession=profession,def=def}; return def
	end
	function grug_artisans.register_refinement(tier,base,material)
		recipes[#recipes+1]={profession="woodcarver",def={tier=tier,family="weapon",
			output=base,material=material,operation="refinement"}}
	end
	function grug_artisans.register_add_affix(tier,base,material,reagent)
		recipes[#recipes+1]={profession="woodcarver",def={tier=tier,family="weapon",
			output=base,material=material,reagent=reagent,operation="add_affix"}}
	end
	local ok,problem=pcall(dofile,repo.."/mods/ITEMS/grug_artisans/woodcarver.lua")
	if not ok then fail(problem) end
	local counts, seen = {}, {}
	for _, row in ipairs(recipes) do
		counts[row.profession]=(counts[row.profession] or 0)+1
		local def=row.def
		if def.operation then
			local key=row.profession..":"..def.output..":"..def.operation
			if seen[key] then fail("duplicate operation "..key) end
			seen[key]=true
			if def.output==def.material then fail("self-only improvement "..key) end
			if def.operation=="add_affix" and not def.reagent then
				fail("missing affix reagent "..key)
			end
		end
	end
	for _, profession in ipairs({"weaponsmith","armorsmith","leatherworker","tailor",
		"woodcarver"}) do
		if not counts[profession] or counts[profession]<12 then
			fail(profession.." catalog is incomplete")
		end
	end
	for _, output in ipairs({"grug_mobs:light_leather",
		"grug_professions:cured_leather", "grug_professions:bolt_patch",
		"grug_artisans:seasoned_wood"}) do
		if not universal[output] then fail("ordinary feedstock is not universal: "..output) end
	end
	if counts.blacksmith then fail("retired blacksmith id remains") end
	for tier=1,6 do
		local metal=({"bronze","iron","steel","silversteel","embersteel","abyssal_steel"})[tier]
		for _, family in ipairs({"sword","dagger","greataxe"}) do
			local base="grug_gear:"..family.."_"..metal
			if not seen["weaponsmith:"..base..":refinement"] or
					not seen["weaponsmith:"..base..":add_affix"] then
				fail("physical weapon operations missing for "..base)
			end
		end
		for _, slot in ipairs({"head","chest","legs","feet"}) do
			local base="grug_gear:"..slot.."_metal_"..metal
			if not seen["armorsmith:"..base..":refinement"] or
					not seen["armorsmith:"..base..":add_affix"] then
				fail("metal armor operations missing for "..base)
			end
		end
	end
	core, grug_professions, grug_artisans = saved.core, saved.grug_professions,
		saved.grug_artisans
	return "r10_professions\tseven primaries\tsplit smiths\towned operations\tPASS\n"
end
