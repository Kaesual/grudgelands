-- Runtime-only timed player statuses and their first-pass text HUD.
-- Effects intentionally disappear on relog. Persistent mechanics, such as
-- the potion cooldown, keep their own authoritative storage and are mirrored
-- here only while the player is online.

local STATUS_HUD_LIMIT = 8
local STATUS_STEP = 1
local POTION_STATUS_ID = "potion_cooldown"

local statuses = {} -- player name -> id -> record
local huds = {} -- player name -> {id = HUD id, text = last sent text}
local sequence = 0
local accumulator = 0

local function player_name(player)
	if not player or not player.is_player or not player:is_player() then
		return nil
	end
	return player:get_player_name()
end

local function remove_status(player, id, expired)
	local name = player_name(player)
	local per_player = name and statuses[name]
	local record = per_player and per_player[id]
	if not record then
		return nil
	end
	per_player[id] = nil
	if next(per_player) == nil then
		statuses[name] = nil
	end
	if expired and record.on_expire then
		record.on_expire(player, record)
	end
	return record
end

function grug_core.set_status(player, id, definition)
	local name = player_name(player)
	if not name or type(id) ~= "string" or id == "" or
			type(definition) ~= "table" then
		return nil
	end
	local kind = definition.kind or "buff"
	if kind ~= "buff" and kind ~= "debuff" then
		return nil
	end
	local now = core.get_us_time()
	local expiry = tonumber(definition.expiry_us)
	if not expiry then
		local duration = tonumber(definition.duration)
		if not duration or duration <= 0 then
			return nil
		end
		expiry = now + duration * 1e6
	end
	if expiry <= now then
		return nil
	end
	local interval = tonumber(definition.interval)
	if interval and (interval <= 0 or type(definition.on_tick) ~= "function") then
		return nil
	end
	sequence = sequence + 1
	local record = {
		id = id,
		label = tostring(definition.label or id),
		expiry_us = expiry,
		value = definition.value,
		kind = kind,
		on_tick = definition.on_tick,
		interval = interval,
		on_expire = definition.on_expire,
		sequence = sequence,
	}
	if interval then
		record.next_tick_us = now + interval * 1e6
	end
	statuses[name] = statuses[name] or {}
	statuses[name][id] = record
	return record
end

function grug_core.clear_status(player, id)
	return remove_status(player, id, false) ~= nil
end

function grug_core.get_status(player, id)
	local name = player_name(player)
	local record = name and statuses[name] and statuses[name][id]
	if record and core.get_us_time() >= record.expiry_us then
		remove_status(player, id, true)
		return nil
	end
	return record
end

local function status_order(a, b)
	if a.kind ~= b.kind then
		return a.kind == "buff"
	end
	local a_label = string.lower(a.label)
	local b_label = string.lower(b.label)
	if a_label ~= b_label then
		return a_label < b_label
	end
	if a.id ~= b.id then
		return a.id < b.id
	end
	return a.sequence < b.sequence
end

function grug_core.each_status(player, callback)
	local name = player_name(player)
	local per_player = name and statuses[name]
	local ordered = {}
	if per_player then
		local now = core.get_us_time()
		local expired = {}
		for id, record in pairs(per_player) do
			if now >= record.expiry_us then
				expired[#expired + 1] = id
			else
				ordered[#ordered + 1] = record
			end
		end
		for index = 1, #expired do
			remove_status(player, expired[index], true)
		end
	end
	table.sort(ordered, status_order)
	if callback then
		for index = 1, #ordered do
			callback(ordered[index])
		end
	end
	return ordered
end

local function duration_text(remaining_us)
	local seconds = math.max(0, math.ceil(remaining_us / 1e6))
	if seconds < 600 then
		return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
	elseif seconds < 3600 then
		return math.ceil(seconds / 60) .. "m"
	elseif seconds < 172800 then
		return math.ceil(seconds / 3600) .. "h"
	end
	return math.ceil(seconds / 86400) .. "d"
end

function grug_core.status_text(player)
	local now = core.get_us_time()
	local ordered = grug_core.each_status(player)
	local lines = {}
	for index = 1, math.min(#ordered, STATUS_HUD_LIMIT) do
		local record = ordered[index]
		local value = record.value
		if type(value) == "function" then
			value = value(player, record)
		end
		if value ~= false then
			local label = record.label
			if value ~= nil then
				label = label .. " " .. tostring(math.max(0,
					math.floor(tonumber(value) or 0)))
			end
			lines[#lines + 1] = label .. "  " ..
				duration_text(record.expiry_us - now)
		end
	end
	return table.concat(lines, "\n")
end

local function refresh_hud(player)
	local name = player_name(player)
	local hud = name and huds[name]
	if not hud then
		return
	end
	local text = grug_core.status_text(player)
	if text ~= hud.text then
		player:hud_change(hud.id, "text", text)
		hud.text = text
	end
end

local function clear_runtime_statuses(player)
	local name = player_name(player)
	if name then
		statuses[name] = nil
	end
end

local function mirror_potion_cooldown(player)
	local traders = rawget(_G, "grug_traders")
	if type(traders) ~= "table" or
			type(traders.potion_cooldown_left) ~= "function" then
		return
	end
	local left = traders.potion_cooldown_left(player)
	if left > 0 then
		if not grug_core.get_status(player, POTION_STATUS_ID) then
			grug_core.set_status(player, POTION_STATUS_ID, {
				label = "Potion",
				duration = left,
				kind = "debuff",
			})
		end
	else
		grug_core.clear_status(player, POTION_STATUS_ID)
	end
end

local function advance_statuses(player, now)
	local ordered = grug_core.each_status(player)
	for index = 1, #ordered do
		local record = ordered[index]
		if record.on_tick and now >= record.next_tick_us then
			record.on_tick(player, record)
			local interval_us = record.interval * 1e6
			local skipped = math.floor((now - record.next_tick_us) /
				interval_us) + 1
			record.next_tick_us = record.next_tick_us + skipped * interval_us
		end
	end
	grug_core.each_status(player)
end

core.register_on_joinplayer(function(player)
	local anchor = grug_core.hud_layout.anchors.status_list
	local id = player:hud_add({
		type = "text",
		position = {x = anchor.position.x, y = anchor.position.y},
		offset = {x = anchor.offset.x, y = anchor.offset.y},
		alignment = {x = anchor.alignment.x, y = anchor.alignment.y},
		text = "",
		number = 0xffffff,
		z_index = 1,
	})
	huds[player:get_player_name()] = {id = id, text = ""}
end)

core.register_on_dieplayer(clear_runtime_statuses)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	local hud = huds[name]
	if hud then
		player:hud_remove(hud.id)
	end
	huds[name] = nil
	statuses[name] = nil
end)

core.register_globalstep(function(dtime)
	accumulator = accumulator + dtime
	if accumulator < STATUS_STEP then
		return
	end
	accumulator = accumulator % STATUS_STEP
	local now = core.get_us_time()
	for _, player in ipairs(core.get_connected_players()) do
		mirror_potion_cooldown(player)
		advance_statuses(player, now)
		refresh_hud(player)
	end
end)
