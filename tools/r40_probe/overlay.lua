-- Round 40 lane V4: the cooldown overlay on the real hotbar (round40-plan.md
-- §3.1, rulings §2.1, §2.9). Fake cooldowns on hotbar slots: per slot one
-- image element (the pie frame at 50 % black, clearing clockwise) and the
-- number (HUD text, HUD text with a shadow element, or image digits that
-- scale with the icon). One throttled pass writes only on a visible change
-- (frame or number); the layout follows the engine's slot arithmetic
-- (hudmath.lua) and is redone when the window, the scaling or the item
-- count changes.

return function(P)
local MOD, hudmath = P.MOD, P.hudmath
local overlay = {}
P.overlay = overlay

local US = core.get_us_time
local INTERVAL = 0.1 -- the pass: at most ten writes per element and second
local PIE_PX = 96
local GLYPH_W, GLYPH_H, GLYPH_GAP = 24, 32, -2 -- the 2 px outlines overlap
local GLYPHS = {}
for _, c in ipairs({"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "m"}) do
	GLYPHS[c] = {file = MOD .. "_digit_" .. c .. ".png", w = GLYPH_W}
end
local POSITION = {x = 0.5, y = 1} -- the builtin hotbar's (builtin/game/hud.lua:270-277)

-- The window information; the bench swaps it for a stand-in.
overlay.window_info = core.get_player_window_information

local players = {} -- name -> st
overlay.players = players

local function settings_for(name)
	local st = players[name]
	if not st then
		st = {cds = {}, layout_mode = "exact", number = "text", textsize = 1,
			digitsize = 0.45, gui = 1, maxwidth = hudmath.MAX_WIDTH,
			writes = 0, passes = 0, pass_us = 0, pass_max = 0}
		players[name] = st
	end
	return st
end
overlay.settings_for = settings_for

local function pie(frame)
	return ("%s_pie_%02d.png"):format(MOD, frame)
end

-- What the layout depends on right now: a key that changes whenever any
-- input does, and the inputs (built only when the key changed).
local function layout_inputs(player, st)
	local count = math.min(player:hud_get_hotbar_itemcount(),
		player:get_inventory():get_size("main"))
	local info = st.layout_mode == "exact" and overlay.window_info(player:get_player_name())
	if info and info.size and info.real_hud_scaling then
		local key = table.concat({"exact", info.size.x, info.size.y, info.real_hud_scaling,
			info.real_gui_scaling, count, st.gui, st.maxwidth}, " ")
		return key, function()
			local density = info.real_gui_scaling / st.gui
			return {width = info.size.x, height = info.size.y, density = density,
				hud_scaling = info.real_hud_scaling / density, count = count,
				max_width = st.maxwidth}
		end, info
	end
	return "plain " .. count, function() return {count = count} end, nil
end

local function remove_elements(player, cd)
	for _, k in ipairs({"pie", "num", "shadow"}) do
		if cd[k] then player:hud_remove(cd[k]) cd[k] = nil end
	end
end

local function number_def(st, L, text)
	if st.number == "image" then
		local tex = hudmath.digit_texture(text, GLYPHS, GLYPH_H, GLYPH_GAP)
		local scale = st.digitsize * L.px / (GLYPH_H * L.sf)
		return {type = "image", position = POSITION, alignment = {x = 0, y = 0},
			offset = L.centre, scale = {x = scale, y = scale}, text = tex, z_index = 3}
	end
	return {type = "text", position = POSITION, alignment = {x = 0, y = 0},
		offset = L.centre, text = text, number = 0xFFFFFF,
		size = {x = st.textsize, y = 0}, style = 1, z_index = 3}
end

local function add_elements(player, st, slot, cd)
	local L = st.layout[slot]
	if not L then return end
	cd.pie = player:hud_add({type = "image", position = POSITION,
		alignment = {x = 1, y = 1}, offset = L.cover, scale = {x = L.scale, y = L.scale},
		text = pie(cd.frame), z_index = 1})
	if st.number == "none" then return end
	if st.number == "shadow" then
		local def = number_def(st, L, cd.text)
		-- Two pixels down and right, whatever the scaling.
		def.offset = {x = L.centre.x + 2 / L.sf, y = L.centre.y + 2 / L.sf}
		def.number, def.z_index = 0x000000, 2
		cd.shadow = player:hud_add(def)
	end
	cd.num = player:hud_add(number_def(st, L, cd.text))
	st.writes = st.writes + (cd.shadow and 3 or 2)
end

local function relayout(player, st)
	local key, inputs, info = layout_inputs(player, st)
	if key == st.layout_key then return end
	local lay, geo = hudmath.layout(info and "exact" or "plain", inputs(), PIE_PX)
	st.layout_key, st.layout, st.geo, st.info = key, lay, geo, info
	for slot, cd in pairs(st.cds) do
		remove_elements(player, cd)
		if lay[slot] then add_elements(player, st, slot, cd) end
	end
end

-- One pass for one player at time `now` (seconds).
function overlay.pass(player, st, now)
	local c0 = US()
	relayout(player, st)
	for slot, cd in pairs(st.cds) do
		local elapsed = now - cd.start
		if elapsed >= cd.duration then
			remove_elements(player, cd)
			st.cds[slot] = nil
			st.writes = st.writes + 1
		else
			local frame = hudmath.frame_index(elapsed, cd.duration)
			if frame ~= cd.frame and cd.pie then
				cd.frame = frame
				player:hud_change(cd.pie, "text", pie(frame))
				st.writes = st.writes + 1
			end
			local text = hudmath.cooldown_text(cd.duration - elapsed)
			if text ~= cd.text then
				cd.text = text
				if cd.num then
					local value = text
					if st.number == "image" then
						value = hudmath.digit_texture(text, GLYPHS, GLYPH_H, GLYPH_GAP)
					end
					player:hud_change(cd.num, "text", value)
					st.writes = st.writes + 1
				end
				if cd.shadow then
					player:hud_change(cd.shadow, "text", text)
					st.writes = st.writes + 1
				end
			end
		end
	end
	local c = US() - c0
	st.passes, st.pass_us = st.passes + 1, st.pass_us + c
	if c > st.pass_max then st.pass_max = c end
end

function overlay.start(player, slot, seconds, now)
	local st = settings_for(player:get_player_name())
	relayout(player, st)
	if not st.layout[slot] then
		return false, ("slot %d is not on the hotbar (%d items)"):format(slot, #st.layout)
	end
	local cd = st.cds[slot]
	if cd then remove_elements(player, cd) end
	cd = {start = now or US() / 1e6, duration = seconds, frame = 0,
		text = hudmath.cooldown_text(seconds)}
	st.cds[slot] = cd
	add_elements(player, st, slot, cd)
	return true
end

function overlay.clear(player)
	local st = players[player:get_player_name()]
	if not st then return end
	for slot, cd in pairs(st.cds) do
		remove_elements(player, cd)
		st.cds[slot] = nil
	end
end

-- Re-add every element (a number variant or size changed).
function overlay.refresh(player)
	local st = settings_for(player:get_player_name())
	st.layout_key = nil
	relayout(player, st)
end

local acc = 0
core.register_globalstep(function(dtime)
	acc = acc + dtime
	if acc < INTERVAL then return end
	acc = 0
	local now = US() / 1e6
	for name, st in pairs(players) do
		if next(st.cds) then
			local player = core.get_player_by_name(name)
			if player then overlay.pass(player, st, now) end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	players[player:get_player_name()] = nil
end)

-- What the probe knows about the player's hotbar, for /pcd info.
function overlay.describe(player)
	local st = settings_for(player:get_player_name())
	st.layout_key = nil
	relayout(player, st)
	local lines = {}
	local info = st.info
	if info then
		lines[#lines + 1] = ("window %dx%d, real_hud_scaling %g, real_gui_scaling %g (density %g assuming gui_scaling %g, hud_scaling %g), hud_hotbar_max_width assumed %g")
			:format(info.size.x, info.size.y, info.real_hud_scaling, info.real_gui_scaling,
				info.real_gui_scaling / st.gui, st.gui,
				info.real_hud_scaling * st.gui / info.real_gui_scaling, st.maxwidth)
	elseif st.layout_mode == "exact" then
		lines[#lines + 1] = "no window information from this client (needs 5.7+): plain layout"
	end
	local g = st.geo
	lines[#lines + 1] = ("layout %s: %d slots, slot %d px, padding %s, pitch %s, %d row(s), number %s")
		:format(info and "exact" or "plain", #st.layout, g.size, g.pad or "4", g.pitch or "56",
			g.rows, st.number)
	if g.slots and g.slots[1] then
		lines[#lines + 1] = ("slot 1 top left at %d,%d px; slot %d at %d,%d px")
			:format(g.slots[1].x, g.slots[1].y, #g.slots, g.slots[#g.slots].x, g.slots[#g.slots].y)
	end
	if st.passes > 0 then
		lines[#lines + 1] = ("%d passes, avg %.1f us, max %d us; %d HUD writes so far")
			:format(st.passes, st.pass_us / st.passes, st.pass_max, st.writes)
	end
	return table.concat(lines, "\n")
end
end
