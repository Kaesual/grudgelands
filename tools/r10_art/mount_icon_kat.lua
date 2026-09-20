return function(root)
	local function check(value, message)
		if not value then error("R10 mount icon KAT: " .. message, 0) end
		return value
	end

	local registered, callbacks = {}, {}
	local core_mock = {registered_items = registered}
	function core_mock.register_craftitem(name, definition)
		definition.name = name
		registered[name] = definition
	end
	function core_mock.register_allow_player_inventory_action(callback)
		callbacks.allow = callback
	end
	function core_mock.register_on_player_inventory_action(callback)
		callbacks.inventory = callback
	end
	function core_mock.register_on_joinplayer(callback)
		callbacks.join = callback
	end
	function core_mock.get_item_group(stack_name, group)
		local definition = registered[stack_name]
		return definition and (definition.groups or {})[group] or 0
	end
	function core_mock.after() end
	function core_mock.get_player_by_name() return nil end
	function core_mock.chat_send_player() end

	local function item_stack(name)
		local values = {}
		local stack = {}
		function stack:get_name() return name end
		function stack:get_meta()
			return {
				get_string = function(_, key) return values[key] or "" end,
				set_string = function(_, key, value) values[key] = value end,
			}
		end
		return stack
	end

	local faction, race = "accord", "human"
	local factions_mock = {
		get_faction = function() return faction end,
		register_on_faction_chosen = function(callback)
			callbacks.faction = callback
		end,
	}
	local classes_mock = {
		get_race = function() return race end,
		register_on_race_chosen = function(callback)
			callbacks.race = callback
		end,
	}
	local saved_names = {"core", "minetest", "ItemStack", "grug_mounts",
		"grug_factions", "grug_classes", "grug_xp", "grug_money"}
	local saved, present = {}, {}
	for _, name in ipairs(saved_names) do
		present[name] = rawget(_G, name) ~= nil
		saved[name] = rawget(_G, name)
	end
	local function restore()
		for _, name in ipairs(saved_names) do
			rawset(_G, name, present[name] and saved[name] or nil)
		end
	end

	rawset(_G, "core", core_mock)
	rawset(_G, "minetest", core_mock)
	rawset(_G, "ItemStack", item_stack)
	rawset(_G, "grug_mounts", {})
	rawset(_G, "grug_factions", factions_mock)
	rawset(_G, "grug_classes", classes_mock)
	rawset(_G, "grug_xp", {get_level = function() return 60 end})
	rawset(_G, "grug_money", {take = function() return true end})

	local ok, result = pcall(function()
		for _, relative in ipairs({"catalog.lua", "items.lua", "state.lua"}) do
			assert(loadfile(root .. "/mods/PLAYER/grug_mounts/" .. relative))()
		end
		local fallback = {
			"grug_mounts_icon_t1_accord.png", "grug_mounts_icon_human.png",
			"grug_mounts_icon_expert_accord.png",
			"grug_mounts_icon_master_accord.png",
		}
		for tier = 1, 4 do
			local item = grug_mounts.TIERS[tier].item
			check(registered[item], "tier item was not registered: " .. item)
			check(registered[item].inventory_image == fallback[tier],
				"fallback icon differs at tier " .. tier)
		end

		local player_meta = {}
		local player = {
			is_player = function() return true end,
			get_player_name = function() return "IconOwner" end,
			get_meta = function()
				return {
					get_int = function(_, key) return player_meta[key] or 0 end,
					set_int = function(_, key, value) player_meta[key] = value end,
				}
			end,
		}
		local cases = {
			{"accord", "human", 1, "grug_mounts_icon_t1_accord.png"},
			{"accord", "human", 2, "grug_mounts_icon_human.png"},
			{"accord", "human", 3, "grug_mounts_icon_expert_accord.png"},
			{"accord", "human", 4, "grug_mounts_icon_master_accord.png"},
			{"throng", "orc", 1, "grug_mounts_icon_t1_throng.png"},
			{"throng", "orc", 2, "grug_mounts_icon_orc.png"},
			{"throng", "orc", 3, "grug_mounts_icon_expert_throng.png"},
			{"throng", "orc", 4, "grug_mounts_icon_master_throng.png"},
		}
		for _, case in ipairs(cases) do
			faction, race = case[1], case[2]
			local stack = grug_mounts.stack_for(player, case[3])
			local meta = stack:get_meta()
			check(meta:get_string("grug_mounts:owner") == "IconOwner",
				"owner binding differs")
			check(meta:get_string("inventory_image") == case[4],
				"owner icon differs: " .. case[4])
		end
		check(callbacks.allow and callbacks.inventory and callbacks.join and
			callbacks.race and callbacks.faction,
			"mount lifecycle callbacks were not registered")
		return "r10_mount_icons_v1\tcases=8\tfallbacks=4\n"
	end)
	restore()
	if not ok then error(result, 0) end
	return result
end
