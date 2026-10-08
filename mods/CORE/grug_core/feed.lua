-- The message feed and the level-up banner (Round 28 ruling 20).
--
-- Why: messages in the top-left chat were easy to miss. Gains the player
-- just earned (XP, loot, quest progress, a catch) now appear in a short feed
-- near their own bars, above the status icon row (hud_layout.anchors.feed),
-- and none of them is copied to chat.
--
-- API (later lanes call these; every one returns false for a player without
-- a feed, e.g. before join):
--
--   grug_core.feed(player, kind, text, key)
--     One line. `kind` picks the colour (grug_core.FEED_COLOR: "xp", "loot",
--     "quest", "fish", "combat"; anything else is the neutral notice colour). `key` is
--     optional: a new line with the key of a line still shown REPLACES that
--     line (one line per quest: key "quest:<id>").
--   grug_core.feed_xp(player, amount)
--     "+N XP"; gains within FEED_XP_MERGE seconds of the previous one are
--     summed into the same line ("+130 XP"). grug_xp.add_xp calls this for
--     every positive grant unless its caller passes `quiet`.
--   grug_core.feed_item(player, item, count)
--     "+3 Light Leather"; `item` is an item name or ItemStack. Pickups of the
--     same item are summed while its line is still shown.
--   grug_core.banner(player, text, color)
--     The large centre announcement (level-up). Not a feed line.
--
-- Behaviour: at most FEED_LINES lines, the newest at the bottom; each line
-- lives FEED_SECONDS and is drawn darker for its last FEED_DARK seconds (HUD
-- text has no alpha fade on every client, so the colour is dimmed instead).
-- A replaced or merged line moves to the bottom and starts its time anew.
--
-- Item pickups are reported here too: the item entity's on_punch is wrapped
-- once all mods are loaded, so every stack a player takes off the ground
-- (mob drops, dropped items) reports exactly the count that entered the
-- inventory.

local FEED_LINES = grug_core.hud_layout.FEED_LINES
local FEED_SECONDS = 2.5
local FEED_DARK = 0.5
local FEED_XP_MERGE = 1.5
local BANNER_SECONDS = 3
-- The expiry pass: only players with lines are visited, and an element is
-- written only when its text or colour changed.
local TICK = 0.1

grug_core.FEED_COLOR = {
	xp = 0xaa66ff,
	loot = 0xffffff,
	quest = 0xffe080,
	fish = 0x8fd9f2,
	-- Combat notices ("You dodge!", "Dismount before attacking.").
	combat = 0xaaaaaa,
	notice = 0xf0e6c8,
}

-- Each channel scaled to 45 %: clearly dimmer, still readable.
local function darker(color)
	local r = math.floor(color / 65536) % 256
	local g = math.floor(color / 256) % 256
	local b = color % 256
	return math.floor(r * 0.45) * 65536 + math.floor(g * 0.45) * 256 +
		math.floor(b * 0.45)
end
grug_core.feed_darker = darker

local function now_seconds()
	return core.get_us_time() / 1000000
end

-- player name -> {ids = {slot -> hud id}, shown = {slot -> {text, color}},
-- lines = {oldest .. newest}, banner_id, banner_token}
local feeds = {}
-- player name -> true while that player has at least one line
local active = {}

local function window_of(name)
	return core.get_player_window_information and
		core.get_player_window_information(name) or nil
end

-- Writes what changed: slot 1 is the lowest line and shows the newest one.
local function render(player, rec, now, replace)
	local window = replace and window_of(player:get_player_name()) or nil
	for slot = 1, FEED_LINES do
		local line = rec.lines[#rec.lines - slot + 1]
		local text, color = "", grug_core.FEED_COLOR.notice
		if line then
			text = line.text
			color = line.color
			if now >= line.expires - FEED_DARK then color = darker(color) end
		end
		local shown = rec.shown[slot]
		if shown.text ~= text then
			shown.text = text
			player:hud_change(rec.ids[slot], "text", text)
		end
		if text ~= "" and shown.color ~= color then
			shown.color = color
			player:hud_change(rec.ids[slot], "number", color)
		end
		if replace then
			local offset = grug_core.hud_layout.feed_line_offset(slot, window)
			if shown.y ~= offset.y then
				shown.y = offset.y
				player:hud_change(rec.ids[slot], "offset", offset)
			end
		end
	end
end

local function record_of(player)
	local name = player and player.get_player_name and player:get_player_name()
	return name and feeds[name], name
end

-- Appends `line` as the newest line, dropping the oldest beyond the limit.
local function push(player, rec, name, line, now)
	line.expires = now + FEED_SECONDS
	rec.lines[#rec.lines + 1] = line
	while #rec.lines > FEED_LINES do table.remove(rec.lines, 1) end
	active[name] = true
	render(player, rec, now, true)
end

local function remove_line(rec, index)
	return table.remove(rec.lines, index)
end

function grug_core.feed(player, kind, text, key)
	local rec, name = record_of(player)
	if not rec or type(text) ~= "string" or text == "" then return false end
	local now = now_seconds()
	if key ~= nil then
		for index = #rec.lines, 1, -1 do
			if rec.lines[index].key == key then remove_line(rec, index) end
		end
	end
	push(player, rec, name, {kind = kind, key = key, text = text,
		color = grug_core.FEED_COLOR[kind] or grug_core.FEED_COLOR.notice}, now)
	return true
end

-- The newest shown line carrying `merge`, when it may still absorb a gain
-- (`window` seconds since its last gain, or while shown when nil).
local function merge_target(rec, merge, window, now)
	for index = #rec.lines, 1, -1 do
		local line = rec.lines[index]
		if line.merge == merge then
			if window == nil or now - line.merged_at <= window then
				return index
			end
			return nil
		end
	end
	return nil
end

local function feed_amount(player, kind, merge, amount, window, format)
	local rec, name = record_of(player)
	if not rec or type(amount) ~= "number" or amount <= 0 then return false end
	local now = now_seconds()
	local index = merge_target(rec, merge, window, now)
	local total = amount
	if index then total = remove_line(rec, index).amount + amount end
	push(player, rec, name, {kind = kind, merge = merge, amount = total,
		merged_at = now, text = format(total),
		color = grug_core.FEED_COLOR[kind] or grug_core.FEED_COLOR.notice}, now)
	return true
end

function grug_core.feed_xp(player, amount)
	amount = type(amount) == "number" and math.floor(amount) or 0
	return feed_amount(player, "xp", "xp", amount, FEED_XP_MERGE,
		function(total) return "+" .. total .. " XP" end)
end

-- The one-line display name of a stack: its own metadata name (quality gear,
-- owner-bound items) or else the registered item's name.
local function stack_label(item)
	if type(item) ~= "string" and item and item.get_short_description then
		local label = grug_core.plain_text(item:get_short_description() or "")
			:match("^[^\n]*"):match("^%s*(.-)%s*$")
		if label ~= "" then return label end
	end
	return grug_core.item_name(item)
end

function grug_core.feed_item(player, item, count)
	count = type(count) == "number" and math.floor(count) or 0
	if not item then return false end
	local label = stack_label(item)
	return feed_amount(player, "loot", "loot:" .. label, count, nil,
		function(total) return "+" .. total .. " " .. label end)
end

function grug_core.banner(player, text, color)
	local rec, name = record_of(player)
	if not rec then return false end
	color = color or grug_core.FEED_COLOR.notice
	rec.banner_token = rec.banner_token + 1
	local token = rec.banner_token
	player:hud_change(rec.banner_id, "number", color)
	player:hud_change(rec.banner_id, "text", text)
	core.after(BANNER_SECONDS, function()
		local p = core.get_player_by_name(name)
		local r = feeds[name]
		if p and r and r.banner_token == token then
			p:hud_change(r.banner_id, "text", "")
		end
	end)
	return true
end

core.register_on_joinplayer(function(player)
	local layout = grug_core.hud_layout
	local name = player:get_player_name()
	local rec = {ids = {}, shown = {}, lines = {}, banner_token = 0}
	local window = window_of(name)
	for slot = 1, FEED_LINES do
		local offset = layout.feed_line_offset(slot, window)
		rec.ids[slot] = player:hud_add({type = "text",
			position = {x = layout.anchors.feed.position.x,
				y = layout.anchors.feed.position.y},
			offset = offset, alignment = {x = 0, y = 0},
			text = "", number = grug_core.FEED_COLOR.notice, z_index = 1})
		rec.shown[slot] = {text = "", color = grug_core.FEED_COLOR.notice,
			y = offset.y}
	end
	rec.banner_id = player:hud_add(layout.text_element("banner", {
		number = grug_core.FEED_COLOR.notice, text = "", size = {x = 2, y = 0},
		style = 1, z_index = 2}))
	feeds[name] = rec
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	feeds[name] = nil
	active[name] = nil
end)

local elapsed = 0
core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < TICK then return end
	elapsed = 0
	if next(active) == nil then return end
	local now = now_seconds()
	for name in pairs(active) do
		local rec = feeds[name]
		local player = rec and core.get_player_by_name(name)
		if not player then
			active[name] = nil
		else
			for index = #rec.lines, 1, -1 do
				if now >= rec.lines[index].expires then remove_line(rec, index) end
			end
			render(player, rec, now, false)
			if #rec.lines == 0 then active[name] = nil end
		end
	end
end)

-- How many items of `before` (an item string) left the ground: all of them
-- when the entity is now empty, else the difference.
function grug_core.picked_up_count(before, after)
	local was = ItemStack(before)
	local rest = ItemStack(after or "")
	if rest:is_empty() or rest:get_name() ~= was:get_name() then
		return was:get_count()
	end
	return math.max(0, was:get_count() - rest:get_count())
end

-- Registered here, before any later mod's mods-loaded hook, so a wrapper
-- installed later (grug_abilities' contextual input) delegates to this one.
core.register_on_mods_loaded(function()
	local item = core.registered_entities["__builtin:item"]
	local pickup = item and item.on_punch
	if type(pickup) ~= "function" then return end
	item.on_punch = function(self, hitter, ...)
		local before = self.itemstring
		local result = pickup(self, hitter, ...)
		if before and before ~= "" and hitter and hitter.is_player and
				hitter:is_player() then
			local taken = grug_core.picked_up_count(before, self.itemstring)
			if taken > 0 then grug_core.feed_item(hitter, ItemStack(before), taken) end
		end
		return result
	end
end)
