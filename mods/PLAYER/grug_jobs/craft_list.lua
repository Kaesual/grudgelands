-- The player's engine craft grid is gone (Round 45, round45-plan.md §4.2).
-- The engine re-creates the `craft` list with 9 slots at every load, and its
-- database loaders only resize lists that are stored (player.cpp addList,
-- database-sqlite3.cpp and database-postgresql.cpp load, inventory.cpp
-- addList), so every join sets the size to 0; a stored size-0 list then
-- sticks. Only an empty list is shrunk: stacks a world kept from the grid
-- stay until the 0.45.0 migration's character handler hands them over (lane
-- MS, ruling 6); grug_core/world_version.lua runs that handler before any
-- other join callback.
core.register_on_joinplayer(function(player)
	local inv = player:get_inventory()
	if inv:get_size("craft") > 0 and inv:is_empty("craft") then
		inv:set_size("craft", 0)
	end
end)
