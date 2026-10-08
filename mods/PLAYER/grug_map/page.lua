-- The Map tab (Round 44, the UI rework spec ruling 10): it opens the map
-- window (window.lua), which Z opens too. The tab's own page is only a
-- note with a button, shown if the window cannot open; the inventory goes
-- back to its homepage (Inventory) on the next step, so the next "i" opens
-- Inventory as after closing the old Map tab.
local PAGE = "grug_map:atlas"

-- The map's width at zoom 1 in the old Map tab's window, the reference size
-- the zone markers' spacing was tuned for (location.lua); the region names'
-- rows (bake.lua). The map window sizes its map per player (window.lua).
local UI = grug_inventory.UI
local PAGE_W = (UI.width - 1) * 5 / 4 + 1.75
local PAGE_H = (UI.height - 1) * 15 / 13 + 1.75 + 7 / 26
local MAP_W = math.min(PAGE_W - 0.8 - 0.33, (PAGE_H - 0.85 - 1.5) * 9 / 8)
grug_map.page_layout = {map_w = MAP_W,
	region_labels = dofile(core.get_modpath("grug_map") .. "/bake.lua").REGION_LABELS}

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
	title = "Map",
	on_enter = function(self, player)
		-- The window replaces the inventory at once; this page's form, sent
		-- right after by sfinv, only updates the stored inventory form.
		grug_map.window.open(player)
		core.after(0, back_home, player:get_player_name())
	end,
	get = function(self, player, context)
		return sfinv.make_formspec(player, context,
			"label[0.2,0.3;The map opens in its own window (key Z).]" ..
			"button[0.2,0.9;3.5,0.8;grug_map_open;Open the map]", false)
	end,
	on_player_receive_fields = function(self, player, context, fields)
		if fields.grug_map_open then
			grug_map.window.open(player)
			return true
		end
	end,
})
