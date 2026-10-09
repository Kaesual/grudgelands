-- Round 44 lane CH: the Character page's formspec bytes per mode, for a
-- Scout with four 32-slot bags, three active effects, a home and 181 arrows
-- in the quiver (comparisons, never targets). Runs against any tree with the
-- harness of this branch, so the same command measures before and after:
--   luajit tools/r44_ch/bytes.lua [repo]   (default: this checkout)
-- The tree before Round 44's Character page has no "3d" mode: that row
-- shows its default (Stats); since Round 45 the "professions" row shows the
-- default (3D), the overview being on the Crafting tab; since the Round 45
-- playtest "3d" and "professions" show the default, the one Stats mode.

local here = (arg and arg[0] or ""):match("^(.*)/[^/]*$") or "."
local repo = arg and arg[1] or "."
local H = dofile(here .. "/harness.lua")(repo)

H.status_effects = {
	{id = "food", name = "Hearty Stew", texture = "grug_food_stew.png",
		detail = "+2% HP/5s", remaining_us = 600000000},
	{id = "elixir", name = "Elixir of Vigor", texture = "grug_alchemy_vigor.png",
		detail = "+6% HP pool", remaining_us = 1200000000},
	{id = "sprint", name = "Sprint", texture = "grug_abilities_sprint.png",
		detail = "", remaining_us = 4000000},
}
local scout = H.player("scout", "scout", {32, 32, 32, 32})
H.put(scout, "grug_quiver_content", 1, "grug_gear:arrow 100")
H.put(scout, "grug_quiver_content", 2, "grug_gear:arrow 81")
H.put(scout, "grug_weapon", 1, "grug_gear:bow_bronze")
for _, mode in ipairs({"3d", "stats", "effects", "achievements", "professions"}) do
	print(("bytes: Character page, %-12s %6d"):format(mode, #H.page(scout, mode)))
end
