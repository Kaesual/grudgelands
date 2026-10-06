-- The cooldown overlay on the hotbar (classes.md "The cooldown overlay";
-- Round 40 plan §2.1, §2.9, §2.13). A skill on a running cooldown or charge
-- that sits in a hotbar slot is covered with 50 % black that clears
-- clockwise from twelve o'clock (one of 72 frames), with the remaining time
-- as image digits in the middle. A skill outside the hotbar shows nothing.
--
-- Per shown slot two HUD image elements: the cover and the number (one
-- element for the whole number, a [combine of the glyphs: one write per
-- change instead of one per digit, no re-centring when "10" becomes "9").
-- One throttled pass every INTERVAL visits only players with a running
-- timer, at most PLAYERS_PER_PASS of them (round robin: up to that many
-- keep the 0.1 s cadence, more spread over several passes), and writes only
-- a visible change: a new frame, a new number, an element added or removed.
--
-- The timer records are the callers' own {expiry = us time, duration = s}
-- tables (cooldowns and charges in init.lua), so ending one early
-- (clear_cooldown) shows on the next pass without a second call.
--
-- Arithmetic and the engine's slot geometry: cooldown_math.lua.

return function(ctx)
local M = ctx.math
local ability_of = ctx.ability_of -- item name -> ability id or nil

local H = {}

H.INTERVAL = 0.1        -- the pass (pick U1)
H.PLAYERS_PER_PASS = 100 -- the spread: beyond this many, players take turns
H.LAYOUT_EVERY = 5      -- a player's passes between window/hotbar checks (0.5 s)
H.Z_COVER, H.Z_NUMBER = 1, 2 -- above the builtin hotbar (z 0)
local POSITION = {x = 0.5, y = 1} -- the builtin hotbar's

-- Window information arrives about 0.2 s after a resize and has no callback;
-- the layout check polls it. Swappable for the bench and the fixture.
H.window_info = core.get_player_window_information

-- name -> {player, timers = {[id] = rec}, slots = {[slot] = id},
--          shown = {[slot] = el}, layout, count, check, scan}
-- el = {pie = hud id, num = hud id, frame, text}
local states = {}
local order, index_of = {}, {} -- the active names, for the round robin
local cursor = 1

local function activate(name)
	if index_of[name] then return end
	order[#order + 1] = name
	index_of[name] = #order
end

local function deactivate(name)
	local i = index_of[name]
	if not i then return end
	local last = order[#order]
	order[i], index_of[last] = last, i
	order[#order], index_of[name] = nil, nil
end

local function remove_el(player, el)
	player:hud_remove(el.pie)
	player:hud_remove(el.num)
end

local function add_el(player, L, frame, text)
	return {frame = frame, text = text,
		pie = player:hud_add({type = "image", position = POSITION,
			alignment = {x = 1, y = 1}, offset = L.cover,
			scale = {x = L.cover_scale, y = L.cover_scale},
			text = M.pie_texture(frame), z_index = H.Z_COVER}),
		num = player:hud_add({type = "image", position = POSITION,
			alignment = {x = 0, y = 0}, offset = L.centre,
			scale = {x = L.digit_scale, y = L.digit_scale},
			text = M.digit_texture(text), z_index = H.Z_NUMBER}),
	}
end

local function clear_shown(player, st)
	for slot, el in pairs(st.shown) do
		remove_el(player, el)
		st.shown[slot] = nil
	end
end

-- The window and the hotbar item count; a changed layout re-places every
-- shown element (removed here, added again by the pass).
local function check_layout(player, st)
	local count = math.min(player:hud_get_hotbar_itemcount(),
		player:get_inventory():get_size("main"))
	local info = H.window_info(player:get_player_name())
	if not st.layout or M.layout_key(info, count) ~= st.layout.key then
		clear_shown(player, st)
		st.layout, st.count = M.layout(info, count), count
	end
end

-- Which ability sits in each hotbar slot: one name read per slot, only after
-- an inventory action, a new timer or the periodic check.
local function scan(player, st)
	local inv = player:get_inventory()
	local slots = {}
	for i = 1, st.count do
		slots[i] = ability_of(inv:get_stack("main", i):get_name())
	end
	st.slots = slots
end

-- One player's pass at `now` (us). Returns false once nothing runs (the
-- player then leaves the active set).
function H.update(player, now)
	local name = player:get_player_name()
	local st = states[name]
	if not st then return false end
	st.check = st.check - 1
	if st.check <= 0 or not st.layout then
		st.check = H.LAYOUT_EVERY
		check_layout(player, st)
		st.scan = true
	end
	if st.scan then
		st.scan = false
		scan(player, st)
	end
	local timers = st.timers
	for id, rec in pairs(timers) do
		if rec.expiry <= now then timers[id] = nil end
	end
	local slots, shown = st.layout.slots, st.shown
	for slot = 1, st.count do
		local id = st.slots[slot]
		local rec = id and timers[id]
		local el = shown[slot]
		if rec then
			local remaining = (rec.expiry - now) / 1e6
			local frame = M.frame(rec.duration - remaining, rec.duration)
			local text = M.text(remaining)
			if not el then
				shown[slot] = add_el(player, slots[slot], frame, text)
			else
				if frame ~= el.frame then
					el.frame = frame
					player:hud_change(el.pie, "text", M.pie_texture(frame))
				end
				if text ~= el.text then
					el.text = text
					player:hud_change(el.num, "text", M.digit_texture(text))
				end
			end
		elseif el then
			remove_el(player, el)
			shown[slot] = nil
		end
	end
	if next(timers) == nil then
		clear_shown(player, st)
		states[name] = nil
		deactivate(name)
		return false
	end
	return true
end

-- A cooldown or charge started (or restarted): `rec` = {expiry, duration}.
-- Shown at once; `now` (us) only for the bench and the fixture.
function H.track(player, id, rec, now)
	if not rec or not (rec.duration > 0) then return end
	local name = player:get_player_name()
	local st = states[name]
	local fresh = not st
	if fresh then
		st = {player = player, timers = {}, slots = {}, shown = {}, count = 0,
			check = 0, scan = true}
		states[name] = st
		activate(name)
	end
	st.timers[id] = rec
	-- A restart of a skill already found on the bar needs no new read.
	local known = false
	for _, slot_id in pairs(st.slots) do
		if slot_id == id then known = true break end
	end
	if not known then st.scan = true end
	H.update(player, now or core.get_us_time())
	if fresh then
		-- Spread the periodic checks of many players over the passes.
		st.check = 1 + #order % H.LAYOUT_EVERY
	end
end

function H.forget(name)
	states[name] = nil
	deactivate(name)
end

-- For the fixture and the bench.
function H.state(name) return states[name] end
function H.active_count() return #order end

-- A player's inventory action may move a skill between slots, into or out of
-- the hotbar: read the hotbar again on the next pass.
core.register_on_player_inventory_action(function(player)
	local st = states[player:get_player_name()]
	if st then st.scan = true end
end)

core.register_on_leaveplayer(function(player)
	H.forget(player:get_player_name())
end)

local acc = 0
core.register_globalstep(function(dtime)
	acc = acc + dtime
	if acc < H.INTERVAL then return end
	-- Keep the remainder, so a 0.09 s server step still averages 0.1 s.
	acc = acc - H.INTERVAL
	if acc > H.INTERVAL then acc = 0 end
	H.pass(core.get_us_time())
end)

-- One pass at `now` (us) over at most PLAYERS_PER_PASS active players.
function H.pass(now)
	local n = #order
	if n == 0 then return end
	for _ = 1, math.min(n, H.PLAYERS_PER_PASS) do
		if #order == 0 then break end
		if cursor > #order then cursor = 1 end
		local name = order[cursor]
		-- A removed player leaves the slot to the last one: same cursor.
		if H.update(states[name].player, now) then cursor = cursor + 1 end
	end
end

return H
end
