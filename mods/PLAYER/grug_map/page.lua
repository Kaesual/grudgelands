-- The Map tab (Round 44, the UI rework spec ruling 10): it opens the map
-- window (window.lua), which Z opens too. The tab's stored page is only a
-- heading while the separate window owns input; the inventory goes
-- back to its homepage (Inventory) on the next step, so the next "i" opens
-- Inventory as after closing the old Map tab.
local PAGE = "grug_map:atlas"

-- Settlements, camps, points of interest, kings and dragons are baked into
-- the base image for everyone since Round 44 (bake.lua, ruling 5); they are
-- no markers.
function grug_map.register_marker_provider(name, callback)
	return grug_map.atlas.register_marker_provider(name, callback)
end

local function back_home(name)
	local player = core.get_player_by_name(name)
	if player and sfinv.get_page(player) == PAGE and not sfinv.inventory_suspended(player) then
		sfinv.set_page(player, sfinv.get_homepage_name(player))
	end
end

sfinv.register_page(PAGE, {
	title = "Map & Quests",
	on_enter = function(self, player)
		-- The window replaces the inventory at once; this page's form, sent
		-- right after by sfinv, only updates the stored inventory form.
		grug_map.window.open(player)
		core.after(0, back_home, player:get_player_name())
	end,
	get = function(self, player, context)
		return sfinv.make_formspec(player, context,
			"label[0.2,0.3;Map & Quests]", false)
	end,
})
