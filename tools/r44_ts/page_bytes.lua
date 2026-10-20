-- Round 44 lane TS: the formspec bytes of the Talents & Skills page, a
-- comparison (never a target). Renders, through the harness's real sfinv
-- frame, grug_classes:talents for a level-30 Scout with 15 ranks spent and an
-- empty inventory, one node selected, and prints one line. Since Round 53
-- the page draws the graph trees (Quarry: Bowcraft 4/4, True Draw, Quiver
-- 3/3, Firm Aim 2/3 selected, Snare Shot, Measured Breath 3/3, Long View
-- 1/3); the Round 52 page drew the old trees for the same 15 ranks (Strong
-- Draw 5/5, Cold Eye 4/4, Twin Shot 3/3 selected, Quiver 3/5): 7138 bytes at
-- main 681913a9, measured with that commit's harness.
--
--   luajit tools/r44_ts/page_bytes.lua [repo]

local repo = arg and arg[1] or "."
local here = (arg and arg[0] or ""):match("^(.*)/[^/]*$") or "."
local H = dofile(here .. "/harness.lua")(repo)

local player = H.make_player("scout", "scout", 30,
	"quarry_bowcraft=4,quarry_true_draw=1,quarry_quiver=3,quarry_firm_aim=2," ..
	"quarry_snare_shot=1,quarry_measured_breath=3,quarry_long_view=1")
H.join(player)
local context = sfinv.get_or_create_context(player)
context.grug_talent_selected = "quarry_firm_aim"
local name = "grug_classes:talents"
local fs = H.render(player, name)
print(("%-22s %-18s %6d bytes (%d ranks)"):format(name, sfinv.pages[name].title, #fs,
	grug_classes.talent_points_spent(player)))
