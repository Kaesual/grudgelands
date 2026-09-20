local root = arg[1] or "."
core = {registered_items = {
	["default:torch"] = {}, ["grug_gear:sword_bronze"] = {_grug_ilvl=1},
	["grug_gear:bow_iron"] = {_grug_ilvl=11}, ["test:conversion"] = {_grug_tier=2},
}}
local M = assert(loadfile(root .. "/mods/PLAYER/grug_jobs/basics_presentation.lua"))()
local function rec(output, inputs, station, method, width, shapeless)
	return {output_name=output, flat_inputs=inputs, display_items=inputs,
		station=station or "grid", method=method or "normal", width=width or 0,
		shapeless=shapeless ~= false}
end
local rows = {
	rec("default:torch", {"default:coal_lump","default:stick"}),
	rec("grug_gear:sword_bronze", {"grug_materials:bronze_bar","default:stick"}, "grid", "normal", 1, false),
	rec("grug_gear:bow_iron", {"grug_artisans:polished_wood","grug_professions:thread"}, "grid", "normal", 3, false),
	rec("test:conversion", {"test:ore"}),
}
M.bind(rows)
assert(rows[1].basics_presentation.starter)
assert(rows[2].basics_presentation.starter)
assert(rows[3].basics_presentation.main_material == "grug_artisans:polished_wood")
assert(rows[4].basics_presentation.main_material == "test:ore")
local fresh = assert(loadfile(root .. "/mods/PLAYER/grug_jobs/basics_presentation.lua"))()
local ok = pcall(fresh.bind, {rec("test:bad", {"test:a","test:b"})})
assert(not ok, "ambiguous mixed route passed audit")
print("R12 RECIPES presentation PASS starter+gear+main-material+ambiguous-audit")
