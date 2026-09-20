-- Independent oracle for the accepted universal Basics equipment grids.
-- Shapes are transcribed from the pinned sources cited in r10-equipment.md;
-- production recipe tables are deliberately not reused here.
return function(repo)
	local saved = {core=core, grug_professions=grug_professions, grug_gear=grug_gear}
	local crafts, yields, items, clears = {}, {}, {}, {}
	core = {registered_items = {["grug_farming:hoe"]={}}}
	function core.clear_craft(def) clears[def.output]=(clears[def.output] or 0)+1 end
	function core.register_craft(def)
		local output, count=def.output:match("^([^%s]+)%s*(%d*)$")
		crafts[output]=crafts[output] or {}; yields[output]=yields[output] or {}
		crafts[output][#crafts[output]+1]=def.recipe
		yields[output][#yields[output]+1]=tonumber(count) or 1
	end
	grug_professions={register_item=function(name) items[name]=true return name end}
	grug_gear={BRACKET_TINT={"a","b","c","d","e","f"}, MATERIALS={
		{metal={name="Bronze"}},{metal={name="Iron"}},{metal={name="Steel"}},
		{metal={name="Silversteel"}},{metal={name="Embersteel"}},
		{metal={name="Abyssal Steel"}},}}
	local ok, problem=pcall(dofile,repo.."/mods/ITEMS/grug_professions/base_recipes.lua")
	if not ok then
		core,grug_professions,grug_gear=saved.core,saved.grug_professions,saved.grug_gear
		error(problem,0)
	end
	local function fail(message)
		core,grug_professions,grug_gear=saved.core,saved.grug_professions,saved.grug_gear
		error("r10 base recipes: "..message,0)
	end
	local function signature(recipe)
		if type(recipe[1]) == "string" then return table.concat(recipe, "|") end
		local rows={}
		for row=1,#recipe do rows[row]=table.concat(recipe[row],"|") end
		return table.concat(rows,"/")
	end
	local function shape(material,mask)
		local recipe={}
		for row=1,#mask do
			recipe[row]={}
			for column=1,#mask[row] do
				recipe[row][column]=mask[row][column]==1 and material or ""
			end
		end
		return recipe
	end
	local checked=0
	local function expect(output,expected,amounts)
		local actual=crafts[output]
		if not actual or #actual~=#expected then fail(output.." route count differs") end
		for index=1,#expected do
			if signature(actual[index])~=signature(expected[index]) then
				fail(output.." route "..index.." 2D shape differs")
			end
			if yields[output][index]~=(amounts and amounts[index] or 1) then
				fail(output.." route "..index.." output count differs")
			end
		end
		checked=checked+1
	end
	local masks={head={{1,1,1},{1,0,1}},chest={{1,0,1},{1,1,1},{1,1,1}},
		legs={{1,1,1},{1,0,1},{1,0,1}},feet={{1,0,1},{1,0,1}}}
	local metals={"bronze","iron","steel","silversteel","embersteel","abyssal_steel"}
	local cloth={"patch","woven","heavy","silkweave","silk","stormweave"}
	local leather={"light","cured","heavy","scaled","sleek","nightscale"}
	local woods={"seasoned","polished","hardened","inlaid","lacquered","heartwood"}
	local picks={"default:pick_bronze","grug_materials:pick_iron","default:pick_steel",
		"grug_materials:pick_silversteel","grug_materials:pick_embersteel",
		"grug_materials:pick_abyssal_steel"}
	local axes={"default:axe_bronze","grug_materials:axe_iron","default:axe_steel",
		"grug_materials:axe_silversteel","grug_materials:axe_embersteel",
		"grug_materials:axe_abyssal_steel"}
	local shovels={"default:shovel_bronze","grug_materials:shovel_iron",
		"default:shovel_steel","grug_materials:shovel_silversteel",
		"grug_materials:shovel_embersteel","grug_materials:shovel_abyssal_steel"}
	local hides={"grug_mobs:light_leather","grug_professions:cured_leather",
		"grug_mobs:heavy_leather","grug_mobs:scaled_hide",
		"grug_professions:sleek_leather","grug_professions:nightscale_leather"}
	expect("default:stick",{{{"group:wood"},{"group:wood"}}},{4})
	if clears["default:stick"]~=1 then fail("old stick route was not cleared") end
	for tier=1,6 do
		local metal=metals[tier]; local bar="grug_materials:"..metal.."_bar"
		local rod="grug_professions:metal_rod_"..metal; local stick="group:stick"
		if not items[rod] then fail("missing rod "..rod) end
		expect(rod,{{{bar},{bar}}},{4})
		expect("grug_gear:sword_"..metal,{{{bar},{bar},{stick}},{{bar},{bar},{rod}}})
		expect(picks[tier],{{{bar,bar,bar},{"",stick,""},{"",stick,""}}})
		expect(shovels[tier],{{{bar},{stick},{stick}}})
		expect(axes[tier],{{{bar,bar},{bar,stick},{"",stick}},
			{{bar,bar},{stick,bar},{stick,""}}})
		local materials={metal={key=metal,item=bar},
			cloth={key=cloth[tier],item="grug_professions:bolt_"..cloth[tier]},
			leather={key=leather[tier],item=hides[tier]}}
		for line,material in pairs(materials) do
			for slot,mask in pairs(masks) do
				expect("grug_gear:"..slot.."_"..line.."_"..material.key,
					{shape(material.item,mask)})
			end
		end
		local wood="grug_artisans:"..woods[tier].."_wood"
		expect("grug_gear:dagger_"..metal,{{{"",bar,""},{"",stick,""}},
			{{"",bar,""},{"",rod,""}}})
		expect("grug_gear:greataxe_"..metal,{{{bar,bar,bar},{bar,stick,bar},{"",stick,""}},
			{{bar,bar,bar},{bar,rod,bar},{"",rod,""}}})
		expect("grug_gear:wand_"..metal,{{{"",wood,""},{"",stick,""}},
			{{"",wood,""},{"",rod,""}}})
		expect("grug_gear:staff_"..metal,{{{"",wood,""},{"",wood,""},{"",wood,""}}})
		expect("grug_gear:bow_"..metal,{{{"",wood,"grug_professions:thread"},
			{wood,"","grug_professions:thread"},{"",wood,"grug_professions:thread"}},
			{{"grug_professions:thread",wood,""},{"grug_professions:thread","",wood},
			{"grug_professions:thread",wood,""}}})
		expect("grug_gear:shield_"..metal,{{{"group:wood",bar,"group:wood"},
			{"group:wood","group:wood","group:wood"},{"","group:wood",""}}})
		if crafts["grug_gear:scepter_"..metal] or crafts["grug_gear:orb_"..metal] then
			fail("retired caster family retained a recipe")
		end
	end
	expect("grug_gear:arrow",{{"grug_materials:iron_bar","group:stick","group:stick",
		"group:stick","group:stick","grug_mobs:sharp_feather","grug_mobs:sharp_feather",
		"grug_mobs:sharp_feather","grug_mobs:sharp_feather"}},{20})
	expect("grug_farming:hoe",{
		{{"group:wood","group:wood",""},{"","default:stick",""},{"","default:stick",""}},
		{{"","group:wood","group:wood"},{"","default:stick",""},{"","default:stick",""}},})
	core,grug_professions,grug_gear=saved.core,saved.grug_professions,saved.grug_gear
	return "r10_base_recipes\t6 tiers\t"..checked.." exact outputs\t2D+yields\tPASS\n"
end
