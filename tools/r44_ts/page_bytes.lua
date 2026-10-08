-- Round 44 lane TS: the formspec bytes of the talent and skill pages, a
-- comparison (never a target). Renders, through the harness's real sfinv
-- frame, every page of `repo` among the Talents (& Skills) page
-- grug_classes:talents and the old Skills page grug_skills:skills, for a
-- level-30 Scout with 15 ranks spent (Strong Draw 5/5, Cold Eye 4/4, Twin
-- Shot 3/3, Quiver 3/5; Twin Shot selected) and an empty inventory, and
-- prints one line per page. Works on the tree before lane TS (two pages)
-- and after (one page):
--
--   luajit tools/r44_ts/page_bytes.lua [repo]
--   (before: git archive 5d2905cd mods | tar -x -C <dir>; then <dir> as repo)

local repo = arg and arg[1] or "."
local here = (arg and arg[0] or ""):match("^(.*)/[^/]*$") or "."
local H = dofile(here .. "/harness.lua")(repo)

local player = H.make_player("scout", "scout", 30,
	"strong_draw=5,cold_eye=4,twin_shot=3,quiver=3")
H.join(player)
local context = sfinv.get_or_create_context(player)
context.grug_talent_selected = "twin_shot"
for _, name in ipairs({"grug_classes:talents", "grug_skills:skills"}) do
	if sfinv.pages[name] then
		local fs = H.render(player, name)
		print(("%-22s %-18s %6d bytes"):format(name, sfinv.pages[name].title, #fs))
	end
end
