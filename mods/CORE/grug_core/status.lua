-- Runtime-only player statuses and their first-pass text HUD. Most statuses are
-- timed; `untimed = true` is restricted to modifier-free lifecycle UI state.
-- Effects intentionally disappear on relog. Persistent mechanics, such as
-- the potion cooldown, keep their own authoritative storage and are mirrored
-- here only while the player is online.
-- on_tick and a positive interval are an optional pair; definitions that
-- provide only one of them are rejected.

local STATUS_HUD_LIMIT = 8
local STATUS_STEP = 1
local POTION_STATUS_ID = "potion_cooldown"
local MODIFIER_KEYS = {
	hp_pool_percent = true,
	mana_pool_percent = true,
	crit_percent = true,
	armor = true,
	spell_damage_percent = true,
}

local statuses = {} -- player name -> id -> record
local huds = {} -- player name -> {id = HUD id, text = last sent text}
local modifier_callbacks = {}
local sequence = 0
local accumulator = 0

local function player_name(player)
	if not player or not player.is_player or not player:is_player() then
		return nil
	end
	return player:get_player_name()
end

local function has_modifiers(record)
	return record and record.modifiers and next(record.modifiers) ~= nil
end

local function notify_modifier_change(player, old_record, new_record)
	if not has_modifiers(old_record) and not has_modifiers(new_record) then
		return
	end
	for index = 1, #modifier_callbacks do
		modifier_callbacks[index](player)
	end
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
	notify_modifier_change(player, record, nil)
	if expired and record.on_expire then
		record.on_expire(player, record)
	end
	return record
end

function grug_core.register_on_status_modifiers_changed(callback)
	if type(callback) ~= "function" then
		return false
	end
	modifier_callbacks[#modifier_callbacks + 1] = callback
	return true
end

function grug_core.status_modifier_sum(player, key)
	if not MODIFIER_KEYS[key] then
		return 0
	end
	local total = 0
	local ordered = grug_core.each_status(player)
	for index = 1, #ordered do
		total = total + (ordered[index].modifiers[key] or 0)
	end
	return total
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
	local untimed = definition.untimed == true
	local expiry = tonumber(definition.expiry_us)
	if untimed then
		if expiry or definition.duration or definition.on_tick or
				definition.interval or definition.on_expire or definition.modifiers then
			return nil
		end
	elseif not expiry then
		local duration = tonumber(definition.duration)
		if not duration or duration <= 0 then
			return nil
		end
		expiry = now + duration * 1e6
	end
	if not untimed and expiry <= now then
		return nil
	end
	local has_tick = definition.on_tick ~= nil
	local has_interval = definition.interval ~= nil
	local interval = tonumber(definition.interval)
	if has_tick ~= has_interval or (has_tick and
			(type(definition.on_tick) ~= "function" or not interval or
			interval <= 0)) then
		return nil
	end
	local modifiers = {}
	if definition.modifiers ~= nil then
		if type(definition.modifiers) ~= "table" then
			return nil
		end
		for key, value in pairs(definition.modifiers) do
			if not MODIFIER_KEYS[key] or type(value) ~= "number" or
					value ~= value or value == math.huge or value == -math.huge then
				return nil
			end
			if value ~= 0 then
				modifiers[key] = value
			end
		end
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
		modifiers = modifiers,
		sequence = sequence,
		untimed = untimed,
	}
	if interval then
		record.next_tick_us = now + interval * 1e6
	end
	statuses[name] = statuses[name] or {}
	local old_record = statuses[name][id]
	statuses[name][id] = record
	notify_modifier_change(player, old_record, record)
	return record
end

function grug_core.clear_status(player, id)
	return remove_status(player, id, false) ~= nil
end

local function should_expire(record, now)
	if record.untimed then return false end
	local pending_tick = record.on_tick and
		record.next_tick_us <= record.expiry_us
	return now >= record.expiry_us and not pending_tick
end

function grug_core.get_status(player, id)
	local name = player_name(player)
	local record = name and statuses[name] and statuses[name][id]
	if record and should_expire(record, core.get_us_time()) then
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
			if should_expire(record, now) then
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
			if record.untimed then
				lines[#lines + 1] = label
			else
				lines[#lines + 1] = label .. "  " ..
					duration_text(record.expiry_us - now)
			end
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
		local per_player = statuses[name]
		statuses[name] = nil
		if per_player then
			for _, record in pairs(per_player) do
				if has_modifiers(record) then
					notify_modifier_change(player, record, nil)
					break
				end
			end
		end
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
		if record.on_tick and record.next_tick_us <= record.expiry_us and
				now >= record.next_tick_us then
			record.on_tick(player, record)
			local interval_us = record.interval * 1e6
			local due_until = math.min(now, record.expiry_us)
			local skipped = math.floor((due_until - record.next_tick_us) /
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
