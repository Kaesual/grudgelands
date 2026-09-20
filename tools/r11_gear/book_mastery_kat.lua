return function(repo)
	local level, learned, station_access = 1, true, true
	local recipes = {
		{profession = "goldsmith", tier = 1, mastery_required = 2,
			station = "jewellers_bench", inputs = {"test:bar"},
			output = "test:book", output_name = "test:book", hint = "Book"},
	}
	_G.core = {
		registered_items = {["test:book"] = {description = "Test Book"}},
		registered_nodes = {}, formspec_escape = function(s) return s end,
		register_on_player_receive_fields = function() end,
		register_on_leaveplayer = function() end,
	}
	_G.grug_xp = {get_level = function() return level end}
	_G.sfinv = {override_page = function() end}
	_G.grug_jobs = {
		PROFESSIONS = {goldsmith = {name = "Goldsmith", class = "primary"}},
		station_handler = function()
			return {can_use = function() return station_access, "Closed station" end}
		end,
		recipes_for = function() return recipes end,
		_item_name = function(s) return s end,
	}
	local meta = {
		get_string = function(_, key)
			return learned and key == "grug_jobs:primary:1" and "goldsmith" or ""
		end,
		get_int = function() return 1 end,
	}
	local player = {get_meta = function() return meta end}
	dofile(repo .. "/mods/PLAYER/grug_jobs/state.lua")
	dofile(repo .. "/mods/PLAYER/grug_jobs/ui.lua")
	local function outputs()
		local _, _, _, result = grug_jobs.book_formspec(player, "goldsmith")
		return result
	end
	assert(not grug_jobs.can_craft_recipe(player, recipes[1]))
	assert(#outputs() == 0, "book revealed a Journeyman recipe at level 1")
	level = 15
	assert(#outputs() == 0)
	level = 16
	assert(grug_jobs.can_craft_recipe(player, recipes[1]) and #outputs() == 1)
	station_access = false
	assert(not grug_jobs.can_craft_recipe(player, recipes[1]))
	assert(#outputs() == 1, "book progression depends on unrelated station access")
	learned = false
	assert(not grug_jobs.can_craft_recipe(player, recipes[1]) and #outputs() == 0)
	return "books\tmastery-15/16\tshared-craft-authority\tstation-independent\n"
end
