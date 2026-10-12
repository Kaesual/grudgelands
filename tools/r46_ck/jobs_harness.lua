-- Round 46 lane CK: the real grug_jobs registry.lua and jobs.lua and the real
-- cooking catalog under a small stub engine, for the craft-count checks of
-- portable_test.lua (part D) and bench_count.lua (portable LuaJIT, never
-- shipped). Sets the engine and mod globals it needs.
--
--   local H = dofile(ROOT .. "/tools/r46_ck/jobs_harness.lua")(ROOT)
--   H.player_with({"grug_cooking:cassava 4", ...}[, bag_stacks]), H.recipes,
--   H.items

return function(root)
	local items = {}
	core = setmetatable({
		registered_items = items,
		get_item_group = function(name, group)
			local def = items[name]
			return def and def.groups and def.groups[group] or 0
		end,
		register_craftitem = function(name, def)
			def.groups = def.groups or {}
			items[name] = def
		end,
		override_item = function(name, def)
			items[name] = items[name] or {groups = {}}
			for key, value in pairs(def) do items[name][key] = value end
		end,
		get_us_time = function() return 0 end,
		log = function() end,
	}, {__index = function(_, key)
		if type(key) == "string" and key:match("^register_") then return function() end end
	end})
	local Stack = {}
	Stack.__index = Stack
	function ItemStack(value)
		if type(value) == "table" then
			return setmetatable({name = value.name, count = value.count}, Stack)
		end
		local name, count = tostring(value or ""):match("^(%S*)%s*(%d*)")
		return setmetatable({name = name, count = name == "" and 0 or tonumber(count) or 1}, Stack)
	end
	function Stack:get_name() return self.count > 0 and self.name or "" end
	function Stack:get_count() return self.count end
	function Stack:is_empty() return self.count <= 0 end
	function Stack:get_stack_max() return 99 end
	function Stack:get_meta() return {get_keys = function() return {} end} end
	function Stack:take_item(n)
		n = math.min(n, self.count)
		self.count = self.count - n
		return setmetatable({name = self.name, count = n}, Stack)
	end
	function Stack:add_item(other)
		if self.name == other.name then
			self.count = self.count + other.count
			return ItemStack("")
		end
		return other
	end
	function Stack:to_string() return self.name .. " " .. self.count end
	grug_inventory = {BAG_COUNT = 1, content_list = function() return "bag1" end,
		carried_lists = function() return {"main", "bag1"} end}
	-- A player whose bag holds the first `bag` stacks (default 2) and main the
	-- rest (the take reads the bag first).
	local function player_with(list, bag)
		bag = bag or 2
		local lists = {bag1 = {}, main = {}}
		for index, entry in ipairs(list) do
			local into = index <= bag and lists.bag1 or lists.main
			into[#into + 1] = ItemStack(entry)
		end
		for _ = #lists.main + 1, 8 do lists.main[#lists.main + 1] = ItemStack("") end
		local inv = {}
		function inv:get_size(name) return #(lists[name] or {}) end
		function inv:get_list(name)
			local out = {}
			for i, stack in ipairs(lists[name] or {}) do out[i] = ItemStack(stack) end
			return out
		end
		function inv:set_stack(name, i, stack) lists[name][i] = ItemStack(stack) end
		return {get_inventory = function() return inv end}
	end

	grug_jobs = {}
	dofile(root .. "/mods/PLAYER/grug_jobs/registry.lua")
	dofile(root .. "/mods/PLAYER/grug_jobs/jobs.lua")
	grug_classes = {register_on_arrival = function() end}
	grug_food = {register_item = function() return true end}
	grug_cooking = nil
	for _, name in ipairs({"mobs:meat_raw", "grug_mobs:raw_fish", "grug_gathering:potato",
			"grug_gathering:corn", "grug_gathering:mushroom", "grug_gathering:melon",
			"grug_gathering:marshbloom", "grug_gathering:stormkelp", "grug_gathering:rock_salt",
			"grug_gathering:wild_cocoa", "default:apple", "default:blueberries"}) do
		core.register_craftitem(name, {description = name})
	end
	for _, name in ipairs({"grug_mobs:raw_fish", "grug_fishing:silver_trout",
			"grug_fishing:mire_carp", "grug_fishing:frostfin", "grug_fishing:ember_eel",
			"grug_fishing:storm_tuna"}) do
		core.register_craftitem(name, {description = name, groups = {food_fish_raw = 1}})
	end
	dofile(root .. "/mods/ITEMS/grug_cooking/init.lua")
	local recipes = {}
	for _, recipe in ipairs(grug_jobs.recipes) do
		if recipe.area == "cooking" then recipes[#recipes + 1] = recipe end
	end
	return {player_with = player_with, recipes = recipes, items = items}
end
