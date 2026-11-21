-- Round 84 lane TRADE: the whole game's registrations (the Round 57 game
-- harness) with fake players and the trade window's field handler, shared by
-- portable_test.lua and page_sizes.lua (LuaJIT, never shipped).
--
--   local W = dofile(TOOLS .. "/world.lua")(REPO)
--   W.player(name, {faction, race, class, copper, main}) -> player
--   W.fill(player, {{list, index, itemstring}, ...})
--   W.count_of(inv, item), W.snapshot(inv), W.open(player, vendor, fields...)
--   W.submit(player, fields), W.shown() -> the last trade formspec
--   W.formname(player), W.submit_as(player, formname, fields)
--
-- The harness's stacks get the engine's stack sizes (builtin/game/item.lua:
-- default_stack_max 99; register.lua: a tool 1; a definition's stack_max)
-- and its add_item (inventory.cpp ItemStack::addItem: an empty slot takes
-- the whole stack, a used one up to the stack size).
return function(repo)
	local game = dofile(repo .. "/tools/r57_details/game_harness.lua")(repo)
	local W = {game = game}
	-- The payouts, as the mods-loaded audit resolves them (the Sell rows).
	W.prices_ok, W.prices_err = pcall(grug_traders.resolve_prices)

	local Stack = getmetatable(ItemStack("default:dirt"))
	local function stack_max(name)
		local def = core.registered_items[name]
		if not def then return 99 end
		return def.stack_max or (def.type == "tool" and 1) or 99
	end
	function Stack:get_stack_max() return stack_max(self.name) end
	function Stack:get_free_space() return stack_max(self.name) - self.count end
	function Stack:add_item(other)
		other = ItemStack(other)
		if other:is_empty() then return other end
		if self:is_empty() then
			self.name, self.count, self.meta = other.name, other.count, other.meta
			return ItemStack("")
		end
		if self.name ~= other.name then return other end
		local into = math.min(stack_max(self.name) - self.count, other.count)
		if into <= 0 then return other end
		self.count = self.count + into
		other.count = other.count - into
		if other.count == 0 then other.name = "" end
		return other
	end
	function Stack:get_description()
		local def = core.registered_items[self.name]
		return def and def.description or self.name
	end

	local function new_meta()
		local data = {}
		return {
			get_int = function(_, key) return math.floor(tonumber(data[key]) or 0) end,
			set_int = function(_, key, value) data[key] = tostring(value) end,
			get_string = function(_, key) return data[key] or "" end,
			set_string = function(_, key, value) data[key] = value end,
			contains = function(_, key) return data[key] ~= nil end,
			data = data,
		}
	end
	W.BAG = grug_inventory.content_list(1)
	W.STORE = grug_inventory.HOTBAR_STORE
	W.BELT = grug_inventory.POTION_BELT
	local function new_inv(main_size)
		local lists = {}
		local sizes = {main = main_size or 32, [W.BAG] = 8, [W.STORE] = 8,
			[W.BELT] = grug_inventory.POTION_BELT_SIZE}
		for list, size in pairs(sizes) do
			lists[list] = {}
			for i = 1, size do lists[list][i] = ItemStack("") end
		end
		local inv = {lists = lists}
		function inv:get_size(list) return lists[list] and #lists[list] or 0 end
		function inv:get_list(list)
			if not lists[list] then return nil end
			local out = {}
			for i, stack in ipairs(lists[list]) do out[i] = ItemStack(stack) end
			return out
		end
		function inv:get_stack(list, i) return ItemStack(lists[list][i]) end
		function inv:set_stack(list, i, stack) lists[list][i] = ItemStack(stack) end
		-- As the engine's: from the end of the list, by name, meta ignored.
		function inv:remove_item(list, stack)
			local want, removed = stack:get_count(), ItemStack(stack:get_name() .. " 1")
			removed.count = 0
			for i = #lists[list], 1, -1 do
				if removed.count >= want then break end
				local slot = lists[list][i]
				if slot:get_name() == stack:get_name() then
					removed.count = removed.count + slot:take_item(want - removed.count):get_count()
				end
			end
			if removed.count == 0 then removed.name = "" end
			return removed
		end
		return inv
	end
	function W.count_of(inv, name)
		local n = 0
		for _, stacks in pairs(inv.lists) do
			for _, stack in ipairs(stacks) do
				if stack:get_name() == name then n = n + stack:get_count() end
			end
		end
		return n
	end
	function W.snapshot(inv)
		local parts = {}
		for _, list in ipairs({"main", W.BAG, W.STORE, W.BELT}) do
			for i, stack in ipairs(inv.lists[list]) do
				parts[#parts + 1] = list .. i .. "=" .. stack:get_name() .. " " .. stack:get_count()
			end
		end
		return table.concat(parts, ";")
	end

	local online = {}
	core.get_player_by_name = function(name) return online[name] end
	function W.player(name, o)
		o = o or {}
		local meta, inv = new_meta(), new_inv(o.main)
		if o.faction then meta:set_string("grug_factions:faction", o.faction) end
		if o.race then meta:set_string("grug_classes:race", o.race) end
		if o.class then meta:set_string("grug_classes:class", o.class) end
		local player = {
			get_player_name = function() return name end,
			is_player = function() return true end,
			get_meta = function() return meta end,
			get_inventory = function() return inv end,
			get_pos = function() return {x = 0, y = 0, z = 0} end,
			meta = meta, inv = inv,
		}
		online[name] = player
		if o.copper and o.copper > 0 then grug_money.add(player, o.copper) end
		return player
	end
	function W.fill(player, slots)
		for _, slot in ipairs(slots) do player.inv:set_stack(slot[1], slot[2], ItemStack(slot[3])) end
	end

	-- The engine's escapes (builtin/common/misc_helpers.lua:312
	-- formspec_escape, :654 colorize, one line), so a page is the page.
	core.formspec_escape = function(text)
		return (tostring(text):gsub("[\\%[%];,$]", function(c) return "\\" .. c end))
	end
	core.colorize = function(color, text)
		return "\27(c@" .. color .. ")" .. text .. "\27(c@#fff)"
	end

	local shown
	core.show_formspec = function(_, formname, formspec)
		if formname:find("^grug_traders:trade") then shown = formspec end
	end
	core.close_formspec = function() shown = nil end
	core.chat_send_player = function() end
	_G.vector = {distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end}
	local handlers = rawget(core, "registered_on_player_receive_fieldss") or {}
	function W.submit(player, fields)
		for _, fn in ipairs(handlers) do
			if fn(player, grug_traders.trade_formname(player:get_player_name()), fields) then return end
		end
	end
	-- The open form's name (a new one per render) and a packet sent under
	-- any name, an older form's included.
	function W.formname(player) return grug_traders.trade_formname(player:get_player_name()) end
	function W.submit_as(player, formname, fields)
		for _, fn in ipairs(handlers) do
			if fn(player, formname, fields) then return end
		end
	end
	function W.shown() return shown end
	local ORIGIN = {x = 0, y = 0, z = 0}
	function W.open(player, vendor, ...)
		shown = nil
		grug_traders.open(player, vendor, ORIGIN, grug_traders.vendor_faction(
			grug_traders.get_vendor(vendor)) or grug_factions.get_faction(player))
		for _, fields in ipairs({...}) do W.submit(player, fields) end
		return shown
	end
	return W
end
