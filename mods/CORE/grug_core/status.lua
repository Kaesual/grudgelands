-- Runtime-only player statuses and their HUD icon row. Most statuses are
-- timed; `untimed = true` is restricted to modifier-free lifecycle UI state.
-- Effects intentionally disappear on relog. Cooldowns are never statuses
-- (Round 26 ruling 21), with one exception (Round 78 ruling 2): the shared
-- potion cooldown keeps its own storage and refusal message and shows on the
-- row through a status source (grug_traders potion.lua).
-- on_tick and a positive interval are an optional pair; definitions that
-- provide only one of them are rejected.
--
-- Picture and frame come from grug_core.status_icons (status_icons.lua):
-- a registered id always gets its registered frame kind, whatever the caller
-- passes. `variant` picks one of the id's registered pictures (elixir
-- family, mount mode); `icon` is an explicit picture (a food item's image).
-- `label` and `detail` are what the Character page's Effects tab prints
-- (name line and detail line); the registry supplies defaults for both.
--
-- Effects whose single authority lives elsewhere and that end on several
-- paths (movement flags, shield-borne talent modifiers) are not copied into
-- this table: their owner registers a status SOURCE, read at display time,
-- so the icon can never outlive the effect.
--
-- Each slot of the row is three HUD elements: the icon, its caption (the
-- countdown, or a shield's points) and, since Round 89 (ruling 1), the
-- duration cover over the icon, which darkens clockwise as a timed effect's
-- time runs (status_icons.lua cover_step; untimed effects show none).

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
	statuses[name] = statuses[name] or {}
	local old_record = statuses[name][id]
	local record = {
		id = id,
		label = tostring(definition.label or id),
		detail = type(definition.detail) == "string" and definition.detail or nil,
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
	-- When the effect began, for the icon's duration cover (Round 89): a
	-- set with a new expiry (a refresh) starts it again; a repeated set of
	-- the running effect with the same expiry keeps it.
	if not untimed then
		record.started_us = old_record and old_record.expiry_us == expiry and
			old_record.started_us or now
	end
	if interval then
		record.next_tick_us = now + interval * 1e6
	end
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

local function keep_order(a, b)
	if a.kind ~= b.kind then
		return icons.KEEP_RANK[a.kind] < icons.KEEP_RANK[b.kind]
	end
	return a.id < b.id
end

-- The active statuses in row order, after removing the expired ones (their
-- on_expire runs); the second result is true when any expired.
local function sweep(player)
	local name = player_name(player)
	local per_player = name and statuses[name]
	local ordered = {}
	local any_expired = false
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
		any_expired = #expired > 0
	end
	table.sort(ordered, status_order)
	return ordered, any_expired
end

function grug_core.each_status(player, callback)
	local ordered = sweep(player)
	if callback then
		for index = 1, #ordered do
			callback(ordered[index])
		end
	end
	return ordered
end

-- The sum of `key` over the active statuses (Round 81 HOT; audit C1-03: it
-- runs in every crit roll, armour rating and spell-damage read). Expired
-- records go as in each_status, without building and sorting the whole
-- list: only two or more records that carry `key` are sorted, so the float
-- sum adds in each_status' order, the same answer to the last bit.
function grug_core.status_modifier_sum(player, key)
	if not MODIFIER_KEYS[key] then
		return 0
	end
	local name = player_name(player)
	local per_player = name and statuses[name]
	if not per_player then
		return 0
	end
	local now = core.get_us_time()
	local expired, first, carriers
	for id, record in pairs(per_player) do
		if should_expire(record, now) then
			expired = expired or {}
			expired[#expired + 1] = id
		elseif record.modifiers[key] then
			if not first then
				first = record
			else
				carriers = carriers or {first}
				carriers[#carriers + 1] = record
			end
		end
	end
	if expired then
		for index = 1, #expired do
			remove_status(player, expired[index], true)
		end
	end
	if carriers then
		table.sort(carriers, status_order)
		local total = 0
		for index = 1, #carriers do
			total = total + carriers[index].modifiers[key]
		end
		return total
	end
	return first and 0 + first.modifiers[key] or 0
end

-- A status source reports effects owned elsewhere, for display only.
-- `fn(player, now_us)` returns nil or a list of entries
-- {id = registered id, expiry_us = t | untimed = true, value, variant, icon,
--  label, detail}.
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
					label = entry.label, detail = entry.detail,
					untimed = entry.untimed == true,
					expiry_us = expiry,
				}
			end
		end
	end
end

-- Every active, visible effect in row order: stored statuses and source
-- entries. A value function returning false hides its status (Sprint cleared
-- early, an empty shield). Each entry: {id, kind, texture, caption, name,
-- detail, value, untimed, remaining_us, expiry_us, started_us}; only a stored
-- status knows when it began (`started_us`), a source entry does not.
-- `ordered` (optional) is each_status'
-- list from the caller's own sweep in this step (the status pass); a record
-- that has expired since sends it through each_status again.
function grug_core.status_effects(player, ordered)
	local now = core.get_us_time()
	if ordered then
		for index = 1, #ordered do
			if should_expire(ordered[index], now) then
				ordered = nil
				break
			end
		end
	end
	ordered = ordered or grug_core.each_status(player)
	local entries, taken = {}, {}
	for index = 1, #ordered do
		entries[index] = ordered[index]
		taken[ordered[index].id] = true
	end
	if player_name(player) then
		source_entries(player, now, taken, entries)
	end
	local visible = {}
	for index = 1, #entries do
		local record = entries[index]
		local value = record.value
		if type(value) == "function" then
			value = value(player, record)
		end
		if value ~= false then
			local def = icons.STATUS[record.id] or {}
			local remaining = record.untimed and nil or
				(record.expiry_us or now) - now
			local label = record.label
			if not label or label == record.id then
				label = def.name or record.id
			end
			visible[#visible + 1] = {
				id = record.id,
				kind = record.kind,
				texture = icons.texture(record.id, record.variant, record.icon),
				caption = icons.caption(value, record.untimed, remaining),
				name = label,
				detail = record.detail or def.detail or "",
				value = value,
				untimed = record.untimed == true,
				remaining_us = remaining,
				expiry_us = remaining and record.expiry_us or nil,
				started_us = remaining and record.started_us or nil,
			}
		end
	end
	table.sort(visible, status_order)
	return visible
end

-- What the icon row shows, in row order and at most STATUS_LIMIT long.
-- `ordered` as in status_effects.
function grug_core.status_display(player, ordered)
	local visible = grug_core.status_effects(player, ordered)
	-- More statuses than slots: debuffs are kept first, then neutral states,
	-- then buffs -- what harms the player must never fall off the row.
	if #visible > layout.STATUS_LIMIT then
		table.sort(visible, keep_order)
		for index = #visible, layout.STATUS_LIMIT + 1, -1 do
			visible[index] = nil
		end
	end
	table.sort(visible, status_order)
	return visible
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

-- One pass for a player: expire, run the due ticks, and sweep again only
-- when a tick ran or a record went (a final tick lets its record expire; an
-- on_tick or on_expire may set or clear statuses), until a sweep changes
-- nothing (Round 81 PASSES; audit C1-02, X4-14: the pass swept three times
-- per player). Returns the last sweep's list for the icon row.
local function advance_statuses(player, now)
	local ordered, changed = sweep(player)
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
			changed = true
		end
	end
	while changed do
		ordered, changed = sweep(player)
	end
	return ordered
end

local ICON_SCALE = layout.STATUS_ICON / 64
-- The cover frames are COVER_PX square; a quarter pixel more keeps the
-- engine's truncated size at STATUS_ICON px, the icon's own (hud.cpp:496).
local COVER_SCALE = (layout.STATUS_ICON + 0.25) / icons.COVER_PX
-- A source entry's expiry is read afresh at every display, and where it
-- counts whole seconds of another clock (the potion cooldown, the
-- Deserter's Mark) it moves by up to a second between reads: only an expiry
-- later by more than this is a refresh that starts a new cover.
local REFRESH_SLACK_US = 1.5e6

-- The texture of an entry's duration cover (Round 89 ruling 1): "" for an
-- untimed effect or a heartbeat (status_icons has_cover). A stored status
-- knows when it began; a source entry's whole duration is what the row saw
-- when it first showed that effect (id and expiry), kept in `seen` and
-- copied into `kept` while it shows, so a cover follows its effect when the
-- row reorders, never its slot.
local function cover_of(entry, seen, kept)
	if not entry.remaining_us or not entry.expiry_us or not icons.has_cover(entry.id) then
		return ""
	end
	local total = entry.started_us and entry.expiry_us - entry.started_us
	if not total then
		local first = seen and seen[entry.id]
		if not first or entry.expiry_us > first.expiry_us + REFRESH_SLACK_US then
			first = {expiry_us = entry.expiry_us, total_us = entry.remaining_us}
		end
		kept[entry.id] = first
		total = first.total_us
	end
	return icons.cover_texture(icons.cover_step(entry.remaining_us, total))
end

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
-- `ordered` as in status_effects.
local function refresh_hud(player, ordered)
	local name = player_name(player)
	local hud = name and huds[name]
	if not hud then
		return
	end
	local shown = grug_core.status_display(player, ordered)
	local window = #shown > 0 and core.get_player_window_information and
		core.get_player_window_information(name) or nil
	local kept = {}
	for index = 1, #hud.slots do
		local slot = hud.slots[index]
		local entry = shown[index]
		local cover = entry and cover_of(entry, hud.seen, kept) or ""
		if entry then
			local icon_offset, caption_offset = layout.status_slot(index, #shown,
				window)
			change(player, slot, "icon_offset", slot.icon, "offset", icon_offset)
			change(player, slot, "caption_offset", slot.caption, "offset",
				caption_offset)
			-- An empty cover is not drawn: its place is written when it shows.
			if cover ~= "" then
				change(player, slot, "cover_offset", slot.cover, "offset", icon_offset)
			end
		end
		change(player, slot, "texture", slot.icon, "text",
			entry and entry.texture or "")
		change(player, slot, "text", slot.caption, "text",
			entry and entry.caption or "")
		change(player, slot, "cover_text", slot.cover, "text", cover)
	end
	hud.seen = kept
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
			-- The duration cover over the icon (Round 89 ruling 1), drawn above it.
			cover = player:hud_add({
				type = "image",
				position = {x = anchor.position.x, y = anchor.position.y},
				offset = icon_offset,
				alignment = {x = 0, y = 0},
				scale = {x = COVER_SCALE, y = COVER_SCALE},
				text = "",
				z_index = 2,
			}),
			icon_offset = icon_offset,
			caption_offset = caption_offset,
			cover_offset = icon_offset,
			texture = "",
			text = "",
			cover_text = "",
		}
	end
	-- `seen`: id -> {expiry_us, total_us}, the source entries' first sight.
	huds[player:get_player_name()] = {slots = slots, seen = {}}
end)

core.register_on_dieplayer(clear_runtime_statuses)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	huds[name] = nil
	statuses[name] = nil
end)

-- Every player every STATUS_STEP, one join slot at a time (Round 81 PASSES;
-- audit X4-05, C1-02): no step handles every player.
grug_core.register_player_pass(STATUS_STEP, function(player)
	refresh_hud(player, advance_statuses(player, core.get_us_time()))
end)
