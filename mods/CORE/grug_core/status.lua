-- Runtime-only player statuses and their HUD icon row. Most statuses are
-- timed; `untimed = true` is restricted to modifier-free lifecycle UI state.
-- Effects intentionally disappear on relog. Cooldowns are never statuses
-- (Round 26 ruling 21): the potion cooldown keeps its own storage and its
-- own refusal message.
-- on_tick and a positive interval are an optional pair; definitions that
-- provide only one of them are rejected.
--
-- Picture and frame come from grug_core.status_icons (status_icons.lua):
-- a registered id always gets its registered frame kind, whatever the caller
-- passes. `variant` picks one of the id's registered pictures (elixir
-- family, mount mode); `icon` is an explicit picture (a food item's image).
--
-- Effects whose single authority lives elsewhere and that end on several
-- paths (movement flags, shield-borne talent modifiers) are not copied into
-- this table: their owner registers a status SOURCE, read at display time,
-- so the icon can never outlive the effect.

local MODIFIER_KEYS = {
	hp_pool_percent = true,
	mana_pool_percent = true,
	crit_percent = true,
	armor = true,
	spell_damage_percent = true,
}
local KINDS = {buff = true, debuff = true, neutral = true}
local icons = grug_core.status_icons
local layout = grug_core.hud_layout
-- Half a second: a 1.5 s stun or scorch must not appear a second late.
-- Captions change once per second at most, and only changes are sent.
local STATUS_STEP = 0.5

local statuses = {} -- player name -> id -> record
local huds = {} -- player name -> {slots = {{icon, caption, ...last sent}}}
local modifier_callbacks = {}
local sources = {}
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
	local kind = icons.kind_of(id) or definition.kind or "buff"
	if not KINDS[kind] then
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
		variant = definition.variant,
		icon = definition.icon,
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
		return icons.KIND_RANK[a.kind] < icons.KIND_RANK[b.kind]
	end
	if a.id ~= b.id then
		return a.id < b.id
	end
	return (a.sequence or 0) < (b.sequence or 0)
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

-- A status source reports effects owned elsewhere, for display only.
-- `fn(player, now_us)` returns nil or a list of entries
-- {id = registered id, expiry_us = t | untimed = true, value, variant, icon}.
-- A stored status with the same id wins over a source entry.
function grug_core.register_status_source(fn)
	if type(fn) ~= "function" then
		return false
	end
	sources[#sources + 1] = fn
	return true
end

local function source_entries(player, now, taken, out)
	for index = 1, #sources do
		local entries = sources[index](player, now)
		for _, entry in ipairs(entries or {}) do
			local id = entry.id
			local kind = type(id) == "string" and
				(icons.kind_of(id) or entry.kind) or nil
			local expiry = tonumber(entry.expiry_us)
			local live = entry.untimed == true or (expiry and expiry > now)
			if kind and KINDS[kind] and live and not taken[id] then
				taken[id] = true
				out[#out + 1] = {
					id = id, kind = kind, value = entry.value,
					variant = entry.variant, icon = entry.icon,
					untimed = entry.untimed == true,
					expiry_us = expiry,
				}
			end
		end
	end
end

-- What the icon row shows, in row order and at most STATUS_LIMIT long:
-- {id, kind, texture, caption}. A value function returning false hides its
-- status without taking a slot (Sprint cleared early, an empty shield).
function grug_core.status_display(player)
	local now = core.get_us_time()
	local ordered = grug_core.each_status(player)
	local entries, taken = {}, {}
	for index = 1, #ordered do
		entries[index] = ordered[index]
		taken[ordered[index].id] = true
	end
	if player_name(player) then
		source_entries(player, now, taken, entries)
	end
	table.sort(entries, status_order)
	local shown = {}
	for index = 1, #entries do
		local record = entries[index]
		local value = record.value
		if type(value) == "function" then
			value = value(player, record)
		end
		if value ~= false then
			shown[#shown + 1] = {
				id = record.id,
				kind = record.kind,
				texture = icons.texture(record.id, record.variant, record.icon),
				caption = icons.caption(value, record.untimed,
					(record.expiry_us or now) - now),
			}
			if #shown >= layout.STATUS_LIMIT then
				break
			end
		end
	end
	return shown
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

local ICON_SCALE = layout.STATUS_ICON / 64

local function change(player, slot, key, id, property, value)
	local previous = slot[key]
	local same
	if type(value) == "table" then
		same = previous and previous.x == value.x and previous.y == value.y
	else
		same = previous == value
	end
	if not same then
		player:hud_change(id, property, value)
		slot[key] = value
	end
end

-- Every slot exists from join on; an unused one has an empty texture and
-- caption, which the engine skips without drawing (src/client/hud.cpp:489).
-- Only changed fields are written: hud_change sends a packet on every call.
local function refresh_hud(player)
	local name = player_name(player)
	local hud = name and huds[name]
	if not hud then
		return
	end
	local shown = grug_core.status_display(player)
	for index = 1, #hud.slots do
		local slot = hud.slots[index]
		local entry = shown[index]
		if entry then
			local icon_offset, caption_offset = layout.status_slot(index, #shown)
			change(player, slot, "icon_offset", slot.icon, "offset", icon_offset)
			change(player, slot, "caption_offset", slot.caption, "offset",
				caption_offset)
		end
		change(player, slot, "texture", slot.icon, "text",
			entry and entry.texture or "")
		change(player, slot, "text", slot.caption, "text",
			entry and entry.caption or "")
	end
end

grug_core.refresh_status_hud = refresh_hud

core.register_on_joinplayer(function(player)
	local anchor = layout.anchors.status_row
	local slots = {}
	for index = 1, layout.STATUS_LIMIT do
		local icon_offset, caption_offset = layout.status_slot(index,
			layout.STATUS_LIMIT)
		slots[index] = {
			icon = player:hud_add({
				type = "image",
				position = {x = anchor.position.x, y = anchor.position.y},
				offset = icon_offset,
				alignment = {x = 0, y = 0},
				scale = {x = ICON_SCALE, y = ICON_SCALE},
				text = "",
				z_index = 1,
			}),
			caption = player:hud_add({
				type = "text",
				position = {x = anchor.position.x, y = anchor.position.y},
				offset = caption_offset,
				alignment = {x = 0, y = 1},
				text = "",
				number = 0xffffff,
				z_index = 1,
			}),
			icon_offset = icon_offset,
			caption_offset = caption_offset,
			texture = "",
			text = "",
		}
	end
	huds[player:get_player_name()] = {slots = slots}
end)

core.register_on_dieplayer(clear_runtime_statuses)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
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
		advance_statuses(player, now)
		refresh_hud(player)
	end
end)
