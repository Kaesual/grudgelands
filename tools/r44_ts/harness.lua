-- Round 44 lane TS: the shared stub world of tools/r44_ts. Loads the REAL
-- vendored sfinv (mods/BASE/sfinv/api.lua), grug_inventory/ui.lua (the
-- frame and the views), grug_classes/talents.lua (with scout_talents.lua,
-- the 64 shipped talents), grug_classes/talents_ui.lua and grug_skills
-- (init.lua, bound_items.lua, page.lua) of the repository `repo` under a
-- small `core` stub, the way the mods load in the game. It also works on an
-- older tree that still has separate Talents and Skills pages, so
-- page_bytes.lua can measure before and after with the same stubs.
--
--   local H = dofile("tools/r44_ts/harness.lua")(repo)
--
-- returns {player = make_player(name, class, level, talents), render(player,
-- page), allow (the player-inventory allow callbacks), catalog(name) (the
-- detached catalog: lists and callbacks), abilities (the stub ability list),
-- run_after()}.

return function(repo)
	local H = {}

	local function fs_escape(text)
		return (tostring(text):gsub("\\", "\\\\"):gsub("%]", "\\]"):gsub("%[", "\\[")
			:gsub(";", "\\;"):gsub(",", "\\,"):gsub("%$", "\\$"))
	end

	--
	-- Item stacks: a name, a count and string metadata.
	--
	local stack_methods = {}
	local stack_meta = {__index = stack_methods}
	function ItemStack(value)
		local name, count, fields = "", 0, {}
		if type(value) == "table" and getmetatable(value) == stack_meta then
			name, count = value.name, value.count
			for k, v in pairs(value.fields) do fields[k] = v end
		elseif type(value) == "table" then
			name, count = value.name or "", value.count or 1
		elseif type(value) == "string" and value ~= "" then
			local n, c = value:match("^(%S+)%s*(%d*)$")
			name, count = n, tonumber(c) or 1
		end
		return setmetatable({name = name, count = count, fields = fields}, stack_meta)
	end
	function stack_methods:is_empty() return self.name == "" or self.count <= 0 end
	function stack_methods:get_name() return self.name end
	function stack_methods:get_count() return self.count end
	function stack_methods:set_count(count) self.count = count end
	function stack_methods:get_definition() return core.registered_items[self.name] end
	function stack_methods:get_description()
		local def = core.registered_items[self.name]
		return self.fields.description or def and def.description or self.name
	end
	function stack_methods:get_stack_max()
		local def = core.registered_items[self.name]
		return def and def.stack_max or 99
	end
	function stack_methods:get_meta()
		local fields = self.fields
		return {
			get_string = function(_, key) return fields[key] or "" end,
			set_string = function(_, key, value) fields[key] = value end,
			get_int = function(_, key) return tonumber(fields[key]) or 0 end,
		}
	end
	function stack_methods:to_string()
		if self:is_empty() then return "" end
		return self.count == 1 and self.name or self.name .. " " .. self.count
	end
	function stack_methods:take_item(n)
		n = math.min(n or 1, self.count)
		local taken = ItemStack(self)
		taken.count = n
		self.count = self.count - n
		if self.count <= 0 then self.name, self.count = "", 0 end
		return taken
	end
	function stack_methods:add_item(other)
		other = ItemStack(other)
		if self:is_empty() then
			self.name, self.count = other.name, other.count
			return ItemStack("")
		end
		if other.name ~= self.name then return other end
		local moved = math.min(other.count, self:get_stack_max() - self.count)
		self.count = self.count + moved
		other.count = other.count - moved
		return other:is_empty() and ItemStack("") or other
	end

	-- An inventory over named lists of stacks; `location` for get_location.
	local function make_inventory(location)
		local inv = {lists = {}}
		function inv:get_location() return location end
		function inv:set_size(list, size)
			local old = self.lists[list] or {}
			local new = {}
			for i = 1, size do new[i] = old[i] or ItemStack("") end
			self.lists[list] = new
			return true
		end
		function inv:get_size(list) return self.lists[list] and #self.lists[list] or 0 end
		function inv:get_stack(list, index)
			local l = self.lists[list]
			return ItemStack(l and l[index] or "")
		end
		function inv:set_stack(list, index, stack)
			self.lists[list][index] = ItemStack(stack)
			return true
		end
		function inv:get_list(list)
			if not self.lists[list] then return nil end
			local out = {}
			for i, stack in ipairs(self.lists[list]) do out[i] = ItemStack(stack) end
			return out
		end
		function inv:get_lists()
			local out = {}
			for name in pairs(self.lists) do out[name] = self:get_list(name) end
			return out
		end
		function inv:contains_item(list, item)
			local name = ItemStack(item):get_name()
			for _, stack in ipairs(self.lists[list] or {}) do
				if stack:get_name() == name then return true end
			end
			return false
		end
		function inv:is_empty(list)
			for _, stack in ipairs(self.lists[list] or {}) do
				if not stack:is_empty() then return false end
			end
			return true
		end
		function inv:room_for_item(list, item)
			for _, stack in ipairs(self.lists[list] or {}) do
				if stack:is_empty() then return true end
			end
			return false
		end
		function inv:add_item(list, item)
			local leftover = ItemStack(item)
			for _, stack in ipairs(self.lists[list] or {}) do
				leftover = stack:add_item(leftover)
				if leftover:is_empty() then break end
			end
			return leftover
		end
		return inv
	end
	H.make_inventory = make_inventory

	--
	-- core
	--
	local registered = {mods_loaded = {}, joinplayer = {}, allow = {}, action = {},
		receive = {}, class_chosen = {}, race_chosen = {}, faction_chosen = {},
		level_change = {}, mounts_changed = {}}
	H.registered = registered
	local after_jobs = {}
	local detached = {}
	local players = {}
	local current_mod, current_path = "grug_classes", repo .. "/mods/PLAYER/grug_classes"
	local function noop() end
	local now_us = 0
	core = {
		formspec_escape = fs_escape,
		colorize = function(_, text) return text end,
		get_modpath = function() return current_path end,
		get_current_modname = function() return current_mod end,
		get_us_time = function() return now_us end,
		log = noop,
		chat_send_player = noop,
		register_on_mods_loaded = function(fn) table.insert(registered.mods_loaded, fn) end,
		register_on_joinplayer = function(fn) table.insert(registered.joinplayer, fn) end,
		register_on_leaveplayer = noop,
		register_on_dieplayer = noop,
		register_on_player_hpchange = noop,
		register_chatcommand = noop,
		register_globalstep = noop,
		register_on_player_receive_fields = function(fn)
			table.insert(registered.receive, fn)
		end,
		register_allow_player_inventory_action = function(fn)
			table.insert(registered.allow, fn)
		end,
		register_on_player_inventory_action = function(fn)
			table.insert(registered.action, fn)
		end,
		registered_items = {},
		registered_nodes = {},
		detached_inventories = {},
		override_item = noop,
		is_creative_enabled = function() return false end,
		get_player_window_information = function() return nil end,
		after = function(_, fn, ...)
			after_jobs[#after_jobs + 1] = {fn, {...}}
		end,
		get_player_by_name = function(name) return players[name] end,
		create_detached_inventory = function(name, callbacks, owner)
			local inv = make_inventory({type = "detached", name = name})
			detached[name] = {inv = inv, callbacks = callbacks, owner = owner}
			core.detached_inventories[name] = callbacks
			return inv
		end,
		remove_detached_inventory = function(name)
			detached[name] = nil
			core.detached_inventories[name] = nil
		end,
		global_exists = function(name) return rawget(_G, name) ~= nil end,
	}
	function core.get_item_group(name, group)
		local def = core.registered_items[name]
		return def and def.groups and def.groups[group] or 0
	end
	minetest = core
	dump = function(value) return tostring(value) end
	function H.run_after()
		while #after_jobs > 0 do
			local jobs = after_jobs
			after_jobs = {}
			for _, job in ipairs(jobs) do job[1](unpack(job[2])) end
		end
	end
	function H.catalog(name) return detached["grug_skills_" .. name] end

	--
	-- Neighbour mods, stubbed.
	--
	grug_core = {
		feed = function(player, kind, text)
			player.feed = player.feed or {}
			table.insert(player.feed, text)
			return true
		end,
		clear_move_immunity = noop,
		clear_absorb_modifiers = noop,
		register_on_status_modifiers_changed = noop,
	}
	local combat = assert(io.open(repo .. "/mods/CORE/grug_core/combat.lua")):read("*a")
	local fit = combat:match("(function grug_core%.base_pool%(level%).-\n" ..
		"function grug_core%.level_scale%(level%).-\nend)\n")
	local armor_k = combat:match("(function grug_core%.armor_k%(attacker_level%).-\nend)\n")
	assert(loadstring(assert(fit, "base_pool block in combat.lua")))()
	assert(loadstring(assert(armor_k, "armor_k in combat.lua")))()
	grug_xp = {
		get_level = function(player) return player.level end,
		register_on_level_change = function(fn) table.insert(registered.level_change, fn) end,
	}
	grug_money = {
		format = function(copper) return copper .. "c" end,
		take = function() return true end,
	}
	grug_factions = {register_on_faction_chosen = function(fn)
		table.insert(registered.faction_chosen, fn)
	end}
	grug_classes = {
		registered_classes = {warrior = {name = "Warrior"}, mage = {name = "Mage"},
			priest = {name = "Priest"}, scout = {name = "Scout"}},
		register_on_class_chosen = function(fn) table.insert(registered.class_chosen, fn) end,
		register_on_race_chosen = function(fn) table.insert(registered.race_chosen, fn) end,
		get_class = function(player) return player.class end,
		apply_stats = noop,
		pool_percent_amount = function(player, _, percent)
			return math.floor(grug_core.base_pool(player.level) * percent / 100 + 0.5)
		end,
	}

	-- The ability catalogue: a scout's six, two of them talent-gated.
	local abilities = {
		{id = "strike", name = "Strike"}, {id = "sprint", name = "Sprint"},
		{id = "loose", name = "Loose"}, {id = "snare_shot", name = "Snare Shot"},
		{id = "pinning_shot", name = "Pinning Shot", talent = "pinning_shot"},
		{id = "opening", name = "Opening", talent = "opening"},
	}
	H.abilities = abilities
	local ability_def = {}
	for _, def in ipairs(abilities) do
		def.talent_gated = def.talent ~= nil
		ability_def[def.id] = def
		core.registered_items["grug_abilities:" .. def.id] = {description = def.name,
			stack_max = 1, groups = {grug_ability = 1, grug_bound_skill = 1}}
	end
	core.registered_items["grug_mounts:horse"] = {description = "Horse", stack_max = 1,
		groups = {grug_mount = 1, grug_bound_skill = 1}, _grug_mount_tier = 1}
	core.registered_items["default:torch"] = {description = "Torch", groups = {}}
	core.registered_items["default:apple"] = {description = "Apple", groups = {}}
	grug_abilities = {
		registered = ability_def,
		is_unlocked = function(player, id)
			local def = ability_def[id]
			if not def then return false end
			return not def.talent or grug_classes.talent_rank(player, def.talent) > 0
		end,
	}
	function grug_abilities.unlocked_ids(player)
		local out = {}
		for _, def in ipairs(abilities) do
			if grug_abilities.is_unlocked(player, def.id) then out[#out + 1] = def.id end
		end
		return out
	end
	function grug_abilities.stack_for(player, id)
		if not grug_abilities.is_unlocked(player, id) then return nil end
		local stack = ItemStack("grug_abilities:" .. id)
		stack:get_meta():set_string("description", ability_def[id].name .. " (fresh)")
		return stack
	end
	grug_mounts = {
		owns_tier = function(player, tier) return player.mount_tier and player.mount_tier >= tier end,
		owned_tier_ids = function(player)
			return player.mount_tier and {1} or {}
		end,
		stack_for = function() return ItemStack("grug_mounts:horse") end,
		register_on_owned_tiers_changed = function(fn)
			table.insert(registered.mounts_changed, fn)
		end,
	}

	--
	-- Players.
	--
	function H.make_player(name, class, level, talents)
		local meta = {["grug_classes:talents"] = talents or ""}
		local player = {class = class, level = level, sent = 0}
		local inv = make_inventory({type = "player", name = name})
		inv:set_size("main", 32)
		inv:set_size("craft", 9)
		for i = 1, 4 do
			inv:set_size("grug_bag" .. i, 1)
			inv:set_size("grug_bag" .. i .. "_content", 0)
		end
		inv:set_size("grug_potion_belt", 4)
		function player.is_player() return true end
		function player.get_player_name() return name end
		function player.get_inventory() return inv end
		function player.get_meta()
			return {
				get_string = function(_, key) return meta[key] or "" end,
				set_string = function(_, key, value) meta[key] = value end,
				get_int = function(_, key) return tonumber(meta[key]) or 0 end,
				set_int = function(_, key, value) meta[key] = tostring(value) end,
			}
		end
		function player.set_inventory_formspec(_, fs)
			player.sent = player.sent + 1
			player.formspec = fs
		end
		players[name] = player
		return player
	end

	--
	-- Load the real files in mod order.
	--
	local function load(mod, path, files)
		current_mod, current_path = mod, repo .. "/mods/" .. path
		for _, file in ipairs(files) do dofile(current_path .. "/" .. file) end
	end
	dofile(repo .. "/mods/BASE/sfinv/api.lua")
	grug_inventory = {BAG_COUNT = 4, HOTBAR_SIZE = 8}
	function grug_inventory.content_list(i) return "grug_bag" .. i .. "_content" end
	load("grug_classes", "PLAYER/grug_classes", {"talents.lua", "talents_ui.lua"})
	load("grug_inventory", "PLAYER/grug_inventory", {"ui.lua"})
	load("grug_skills", "PLAYER/grug_skills", {"init.lua"})
	for _, fn in ipairs(registered.mods_loaded) do fn() end

	-- Renders `page` for `player` through sfinv and returns the formspec.
	function H.render(player, page)
		sfinv.set_page(player, page)
		return player.formspec
	end
	-- A join: sfinv's context, the joinplayer hooks, the deferred jobs.
	function H.join(player)
		for _, fn in ipairs(registered.joinplayer) do fn(player) end
		H.run_after()
	end
	-- Runs the player-inventory allow callbacks like the engine (the first
	-- non-nil answer wins; nil means "unconcerned").
	function H.allow(player, action, inventory, info)
		for _, fn in ipairs(registered.allow) do
			local answer = fn(player, action, inventory, info)
			if answer ~= nil then return answer end
		end
		return nil
	end
	return H
end
