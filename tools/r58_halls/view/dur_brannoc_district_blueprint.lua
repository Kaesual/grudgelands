-- The Miner's Guild house of dur_brannoc in its district, for the town viewer
-- (Round 58 lane HALLS2): the district's plots as one seed's plan placed
-- them (build_pages.py writes the plan with plan_layout.lua and names it in
-- R58_HALLS_LAYOUT):
--   R58_HALLS_LAYOUT=layout.lua python3 tools/building_templates/viewer/build_viewer.py tools/r58_halls/view/dur_brannoc_district_blueprint.lua -o out.html
local info = debug.getinfo(1, "S")
local here = info.source:sub(2):match("^(.*)[/\\][^/\\]*$")
local layout = dofile(assert(os.getenv("R58_HALLS_LAYOUT"), "R58_HALLS_LAYOUT names no plan"))
return dofile(here .. "/capital.lua")(here .. "/../../..", "dur_brannoc", layout, "district")
