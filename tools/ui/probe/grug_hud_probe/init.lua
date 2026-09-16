-- Round-4 lane H engine probe. DISPOSABLE: staged into a throwaway copy of
-- the game by tools/ui/evidence/20260916-hud-bars/engine.sh, never shipped.
--
-- A headless server has no client, so a HUD cannot be SEEN here. What can be
-- proved is everything up to the packet: that the shipped join callbacks of
-- grug_abilities, grug_xp and grug_money run inside the real engine, against
-- the real `grug_core.hud_layout`, and hand the engine the element
-- definitions they are supposed to -- read back through `hud_get`, not from
-- the mod's own bookkeeping.
--
-- The callbacks are picked by `core.callback_origins`
-- (builtin/common/register.lua:6), so exactly the three mods under test run
-- and the faction/class dialogues of the others do not.

local function log(line)
	core.log("action", "HUDPROBE " .. line)
end

local function fake_player(name, hp, hp_max, breath, breath_max)
	local noop = function() end
	local player = {
		_name = name,
		_hp = hp,
		_props = {hp_max = hp_max, breath_max = breath_max},
		_breath = breath,
		_elements = {},
		_next = 0,
		_writes = 0,
		_flags = nil,
		_meta = {},
	}
	function player:get_player_name()
		return player._name
	end
	function player:is_player()
		return true
	end
	function player:get_hp()
		return player._hp
	end
	function player:get_properties()
		return {hp_max = player._props.hp_max,
			breath_max = player._props.breath_max}
	end
	function player:set_properties(props)
		for key, value in pairs(props) do
			player._props[key] = value
		end
	end
	function player:set_hp(value)
		player._hp = value
	end
	function player:get_breath()
		return player._breath
	end
	function player:hud_add(def)
		player._next = player._next + 1
		local copy = {}
		for key, value in pairs(def) do
			copy[key] = value
		end
		player._elements[player._next] = copy
		return player._next
	end
	function player:hud_change(id, stat, value)
		local element = player._elements[id]
		if not element then
			return false
		end
		element[stat] = value
		player._writes = player._writes + 1
		return true
	end
	function player:hud_get(id)
		return player._elements[id]
	end
	function player:hud_remove(id)
		player._elements[id] = nil
	end
	function player:hud_set_flags(flags)
		player._flags = flags
	end
	function player:get_wield_index()
		return 1
	end
	function player:get_player_control()
		return {}
	end
	function player:get_wielded_item()
		return ItemStack("")
	end
	function player:get_inventory()
		local inv = {}
		function inv.get_lists()
			return {main = {}}
		end
		function inv.get_list()
			return {}
		end
		function inv.get_size()
			return 0
		end
		return setmetatable(inv, {__index = function(t, key)
			rawset(t, key, noop)
			return noop
		end})
	end
	function player:get_meta()
		local meta = {}
		function meta.get_int(_, key)
			return tonumber(player._meta[key]) or 0
		end
		function meta.set_int(_, key, value)
			player._meta[key] = value
		end
		function meta.get_string(_, key)
			return tostring(player._meta[key] or "")
		end
		function meta.set_string(_, key, value)
			player._meta[key] = value
		end
		function meta.get(_, key)
			return player._meta[key]
		end
		return setmetatable(meta, {__index = function(t, key)
			rawset(t, key, noop)
			return noop
		end})
	end
	return setmetatable(player, {__index = function(t, key)
		rawset(t, key, noop)
		return noop
	end})
end

core.register_on_mods_loaded(function()
	local layout = grug_core and grug_core.hud_layout
	if not layout then
		log("FAIL grug_core.hud_layout is missing in the real engine")
		return
	end

	local rows = {}
	for _, id in ipairs(layout.order) do
		local row = layout.rows[id]
		rows[#rows + 1] = ("%s=%d..%d"):format(id, row.top, row.bottom)
	end
	log("rows " .. table.concat(rows, " "))
	log(("geometry width=%d height=%d min_fill=%d texture=%s")
		:format(layout.BAR_WIDTH, layout.BAR_HEIGHT, layout.MIN_FILL,
			layout.BAR_TEXTURE))
	log(("fill 325of325=%d 324of325=%d 1of325=%d 0of325=%d")
		:format(layout.bar_fill(325, 325), layout.bar_fill(324, 325),
			layout.bar_fill(1, 325), layout.bar_fill(0, 325)))

	-- Only the three mods under test.
	local wanted = {grug_abilities = true, grug_xp = true, grug_money = true}
	local player = fake_player("hudprobe", 325, 325, 10, 10)
	local ran = 0
	for _, func in ipairs(core.registered_on_joinplayers) do
		local origin = core.callback_origins[func]
		if origin and wanted[origin.mod] then
			local ok, err = pcall(func, player)
			ran = ran + 1
			if not ok then
				log("FAIL join callback of " .. origin.mod .. ": " ..
					tostring(err))
			end
		end
	end
	log("join_callbacks_run " .. ran)
	log("flags healthbar=" .. tostring(player._flags and
		player._flags.healthbar) .. " breathbar=" ..
		tostring(player._flags and player._flags.breathbar))

	-- Read the elements back through the API the engine would have used.
	local ids = {}
	for id in pairs(player._elements) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local element = player:hud_get(id)
		local scale = element.scale
		log(("element %d type=%s offset=%s,%s align=%s,%s scale=%s,%s z=%s text=%q")
			:format(id, tostring(element.type),
				tostring(element.offset and element.offset.x),
				tostring(element.offset and element.offset.y),
				tostring(element.alignment and element.alignment.x),
				tostring(element.alignment and element.alignment.y),
				tostring(scale and scale.x), tostring(scale and scale.y),
				tostring(element.z_index), tostring(element.text)))
	end
	log("elements " .. #ids .. " writes " .. player._writes)

	-- The texture the bars name must be a real file in the staged game.
	local path = core.get_modpath("grug_core") .. "/textures/" ..
		layout.BAR_TEXTURE
	local handle = io.open(path, "rb")
	log("texture " .. layout.BAR_TEXTURE .. " readable=" ..
		tostring(handle ~= nil))
	if handle then
		handle:close()
	end
	log("DONE")
end)
