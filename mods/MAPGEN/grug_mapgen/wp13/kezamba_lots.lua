-- The sizes of Kezamba's fifty-two plots: every row is one plot of the
-- district rosters (`kezamba_districts.lua`) with its `reach`, the half width
-- of ground the plot lays (13 for a building, 11, 8 or 5 for a fill dressing),
-- and the district roles in roster order. Where a plot stands and how it is
-- turned is the capital planner's per-world layout (Round 22,
-- `wp40/capital_planner.lua`); the searched lot positions this table carried
-- before are gone with the fixed layout.
--
-- Plain Lua 5.1, pure, no engine calls, no globals.

local function loader()
	local M = {}

	-- Contract section 2.1's district roles, in the order the districts are
	-- resolved and the manifest's fields are written.
	M.ROLES = {"market_trades", "residential_cultural", "martial_garrison",
		"lore_spiritual"}

	-- One row per plot, building plots first, then fill dressings, per district
	-- in roster order.
	local LOTS = {
		{id = "shore_1", kind = "plot", reach = 13},
		{id = "shore_2", kind = "plot", reach = 13},
		{id = "shore_3", kind = "plot", reach = 13},
		{id = "shore_4", kind = "plot", reach = 13},
		{id = "shore_5", kind = "plot", reach = 13},
		{id = "shore_6", kind = "plot", reach = 13},
		{id = "shore_7", kind = "plot", reach = 13},
		{id = "shore_8", kind = "plot", reach = 13},
		{id = "shore_9", kind = "plot", reach = 13},
		{id = "shore_f1", kind = "fill", reach = 11},
		{id = "shore_f2", kind = "fill", reach = 11},
		{id = "shore_f3", kind = "fill", reach = 8},
		{id = "shore_f4", kind = "fill", reach = 5},

		{id = "vine_1", kind = "plot", reach = 13},
		{id = "vine_2", kind = "plot", reach = 13},
		{id = "vine_3", kind = "plot", reach = 13},
		{id = "vine_4", kind = "plot", reach = 13},
		{id = "vine_5", kind = "plot", reach = 13},
		{id = "vine_6", kind = "plot", reach = 13},
		{id = "vine_7", kind = "plot", reach = 13},
		{id = "vine_8", kind = "plot", reach = 13},
		{id = "vine_9", kind = "plot", reach = 13},
		{id = "vine_f1", kind = "fill", reach = 11},
		{id = "vine_f2", kind = "fill", reach = 11},
		{id = "vine_f3", kind = "fill", reach = 8},
		{id = "vine_f4", kind = "fill", reach = 5},

		{id = "canopy_1", kind = "plot", reach = 13},
		{id = "canopy_2", kind = "plot", reach = 13},
		{id = "canopy_3", kind = "plot", reach = 13},
		{id = "canopy_4", kind = "plot", reach = 13},
		{id = "canopy_5", kind = "plot", reach = 13},
		{id = "canopy_6", kind = "plot", reach = 13},
		{id = "canopy_7", kind = "plot", reach = 13},
		{id = "canopy_8", kind = "plot", reach = 13},
		{id = "canopy_9", kind = "plot", reach = 13},
		{id = "canopy_10", kind = "plot", reach = 13},
		{id = "canopy_11", kind = "plot", reach = 13},
		{id = "canopy_f1", kind = "fill", reach = 11},
		{id = "canopy_f2", kind = "fill", reach = 11},
		{id = "canopy_f3", kind = "fill", reach = 8},
		{id = "canopy_f4", kind = "fill", reach = 5},

		{id = "totem_1", kind = "plot", reach = 13},
		{id = "totem_2", kind = "plot", reach = 13},
		{id = "totem_3", kind = "plot", reach = 13},
		{id = "totem_4", kind = "plot", reach = 13},
		{id = "totem_5", kind = "plot", reach = 13},
		{id = "totem_6", kind = "plot", reach = 13},
		{id = "totem_7", kind = "plot", reach = 13},
		{id = "totem_f1", kind = "fill", reach = 11},
		{id = "totem_f2", kind = "fill", reach = 5},
		{id = "totem_f3", kind = "fill", reach = 8},
		{id = "totem_f4", kind = "fill", reach = 5},
	}

	-- The lots of one district, in authored order, building lots first and
	-- then fill lots -- which is the order the district rosters are written in
	-- and the order `kezamba_districts.lua` resolves them in.
	function M.of(key)
		local plots, fill = {}, {}
		for index = 1, #LOTS do
			local lot = LOTS[index]
			if lot.id:sub(1, #key + 1) == key .. "_" then
				if lot.kind == "plot" then plots[#plots + 1] = lot
				else fill[#fill + 1] = lot end
			end
		end
		return plots, fill
	end

	function M.all() return LOTS end

	return M
end

return loader
