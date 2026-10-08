-- Key edges (Round 44, the UI rework spec §3.5 and §3.6): the server sees
-- only the movement keys, aux1, sneak, dig, place and zoom
-- (lua_api.md get_player_control_bits). This mod reports the moment a
-- player presses zoom (Z, the map window) or aux1 (E, the quickbar): one
-- control read per online player per server step, compared with the last
-- step's. Input belongs neither to the map nor to the quickbar, so both
-- register here. No "menu open" check is needed: the client releases every
-- key while a menu or the chat is open (client/game.cpp), so a key cannot
-- rise there.
--
-- grug_keys.register_on_press(key, callback): key is "zoom" or "aux1";
-- callback(player) runs on the step the key goes from up to down (its
-- rising edge), never while it is held. A player's first step after
-- joining only records the keys, so a key held while joining does not
-- count.
grug_keys = {}

-- The control bits (lua_api.md get_player_control_bits): aux1 bit 5, zoom
-- bit 9.
grug_keys.BITS = {aux1 = 32, zoom = 512}
-- Zoom field of view for every player (the user, 2026-10-08): with a
-- zoom_fov of 0 (the survival default) the client answers Z with "Zoom
-- currently disabled by game or mod" (client/game.cpp checkZoomEnabled).
-- 72 degrees is the client's default field of view, so at that setting a
-- held Z changes nothing visibly; at 72 degrees the server sends and
-- generates no farther than without zoom (util/numeric.cpp adjustDist only
-- widens below half the default field of view).
grug_keys.ZOOM_FOV = 72

local callbacks = {}
local watched = 0 -- the bits of every key with a callback
local held = {} -- player name -> the watched bits down on the last step

function grug_keys.register_on_press(key, callback)
	local bit_value = grug_keys.BITS[key]
	assert(bit_value and type(callback) == "function",
		"[grug_keys] register_on_press(key, callback): unknown key " .. tostring(key))
	if not callbacks[key] then
		callbacks[key] = {}
		watched = watched + bit_value
	end
	local list = callbacks[key]
	list[#list + 1] = callback
end

-- The keys that went down between `before` and `now` (watched bits), as a
-- list of key names in BITS order; pure, for the fixture.
local ORDER = {"zoom", "aux1"}
function grug_keys.rising(before, now)
	local result = {}
	for _, key in ipairs(ORDER) do
		local value = grug_keys.BITS[key]
		if bit.band(now, value) ~= 0 and bit.band(before, value) == 0 then
			result[#result + 1] = key
		end
	end
	return result
end

-- Every step, not throttled: an edge is one step long, so an accumulator
-- would miss short presses. The step reads one integer per player and does
-- nothing else unless a watched key rose.
core.register_globalstep(function()
	if watched == 0 then return end
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local now = bit.band(player:get_player_control_bits(), watched)
		local before = held[name]
		held[name] = now
		if before and now ~= before then
			for _, key in ipairs(grug_keys.rising(before, now)) do
				for _, callback in ipairs(callbacks[key] or {}) do callback(player) end
			end
		end
	end
end)

core.register_on_joinplayer(function(player)
	player:set_properties({zoom_fov = grug_keys.ZOOM_FOV})
end)

core.register_on_leaveplayer(function(player)
	held[player:get_player_name()] = nil
end)
