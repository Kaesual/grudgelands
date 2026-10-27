local huds = {}

-- Text can carry translation escapes ("\27(T@mobs)Raw Meat\27E"). Resolve
-- them to the game's English text first, so a cut never lands inside an
-- escape and the width counts only visible characters.
local plain = grug_core.plain_text

local function objective_text(objective)
	local subject = objective.description
	if not subject or subject == "Defeat named threat" or objective.type ~= "kill" then
		subject = grug_quests.objective_action(objective)
	end
	return ("%d/%d %s"):format(objective.count, objective.required, subject)
end

-- Cut to one HUD line of at most `width` bytes, never inside a UTF-8
-- sequence, with "..." marking the cut.
local function one_line(text, width)
	text = (plain(text):match("^[^\n]*") or ""):gsub("%s+$", "")
	if #text <= width then return text end
	local cut = math.max(1, width - 3)
	while cut > 1 do
		local byte = text:byte(cut + 1)
		if not byte or byte < 0x80 or byte >= 0xC0 then break end
		cut = cut - 1
	end
	return text:sub(1, cut):gsub("%s+$", "") .. "..."
end

-- The objective line of a tracked quest's box (Round 24 ruling 23's line;
-- since Round 65 under the quest's title): the objective, or "Return to
-- <turn-in NPC>" once the quest is ready. A
-- travel quest reads "Travel to <NPC>" throughout (Round 28 ruling 39);
-- several objectives share one compact line, "Wood Axe 0/1, Wood Pickaxe
-- 0/1" (ruling 41). A shared quest returns to the turn-in of the variant
-- the player took (Round 57, the journal's `npc`). A system quest (no NPC,
-- no objectives; Round 48) reads its turn-in text. Two quests with the
-- same objective may read the same (accepted).
function grug_quests.hud_line(quest, width)
	local text
	local npc = grug_quests.registered_npcs[quest.npc]
	if quest.turnin_text then
		text = quest.turnin_text
	elseif quest.travel then
		text = "Travel to " .. (npc and npc.title or tostring(quest.npc))
	elseif quest.ready then
		text = "Return to " .. (npc and npc.title or tostring(quest.npc))
	elseif #quest.objectives > 1 then
		text = grug_quests.compact_text(quest)
	else
		text = objective_text(quest.objectives[1])
	end
	return one_line(text, width)
end

-- The tracked quests as the tracker's boxes (Round 65 ruling 4, replacing
-- Round 24 ruling 23's objective-only lines): the title, cut so the level
-- label keeps its room; the label "[Lv N]" of the quest level (`def.level`,
-- the number the quest log shows) in its difficulty colour for a player of
-- `player_level` (grug_xp.con_color, the target frame's gradient); the
-- objective line (hud_line). Sorted by quest level, ties by title, then id,
-- so easy and hard quests read at a glance. `width` is the line width in
-- characters (hud_layout.side_text_width). Empty while the HUD is off.
function grug_quests.hud_entries(journal, player_level, width)
	local entries = {}
	if not journal.hud_enabled then return entries end
	local by_id = {}
	for _, quest in ipairs(journal.quests) do by_id[quest.id] = quest end
	for _, id in ipairs(journal.tracked) do
		local quest = by_id[id]
		if quest and #entries < grug_quests.MAX_TRACKED then
			local level = grug_quests.registered_quests[id].level
			local label = ("[Lv %d]"):format(level)
			entries[#entries + 1] = {id = id, level = level, label = label,
				color = grug_xp.con_color(level, player_level),
				title = one_line(quest.title, width - #label - 1),
				line = grug_quests.hud_line(quest, width),
				order = plain(quest.title):lower()}
		end
	end
	table.sort(entries, function(a, b)
		if a.level ~= b.level then return a.level < b.level end
		if a.order ~= b.order then return a.order < b.order end
		return a.id < b.id
	end)
	return entries
end

-- Every objective as "<subject> <count>/<required>", joined by ", "
-- ("Barrow Piglet 3/8, Light Leather 0/2").
function grug_quests.compact_text(quest)
	local parts = {}
	for _, objective in ipairs(quest.objectives) do
		parts[#parts + 1] = ("%s %d/%d"):format(grug_quests.objective_subject(objective),
			objective.count, objective.required)
	end
	return table.concat(parts, ", ")
end

-- One feed line per quest (Round 28 ruling 20): the compact text, cut like a
-- tracker line at the widest tracker width (QUEST_WRAP characters).
function grug_quests.feed_text(quest)
	return one_line(grug_quests.compact_text(quest), grug_core.hud_layout.QUEST_WRAP)
end

-- player name -> quest id -> {objective counts last seen}. A quest seen for
-- the first time (accepted, or the first pass after join) only records its
-- counts; afterwards any objective count that ROSE -- a kill credit, an item
-- gained, a conversation -- posts the quest's line to the feed under the key
-- "quest:<id>", so a quest's newer line replaces its older one. Falling item
-- counts (used, dropped) update silently.
local seen = {}

function grug_quests.progress_changes(previous, journal)
	local current, changed = {}, {}
	for _, quest in ipairs(journal.quests) do
		local counts, before, rose = {}, previous and previous[quest.id], false
		for index, objective in ipairs(quest.objectives) do
			counts[index] = objective.count
			if before and objective.count > (before[index] or 0) then rose = true end
		end
		current[quest.id] = counts
		if rose then changed[#changed + 1] = quest end
	end
	return current, changed
end

local function post_progress(player, journal)
	local name = player:get_player_name()
	local current, changed = grug_quests.progress_changes(seen[name], journal)
	seen[name] = current
	for _, quest in ipairs(changed) do
		grug_core.feed(player, "quest", grug_quests.feed_text(quest), "quest:" .. quest.id)
	end
end

-- The tracker's look (Round 65 ruling 4, coordinator defaults): the box in
-- the UI theme's dark panel colour at 30 % opacity (the box only, never the
-- text), the title in the theme's light text colour, the objective in the
-- quest yellow. Read from grug_core.ui on first use.
local OBJECTIVE_COLOR = 0xffe080
local box_texture, title_color
local function theme()
	if not box_texture then
		local colors = grug_core.ui.colors
		box_texture = ("[fill:1x1:%s4d"):format(colors.panel:sub(1, 7))
		title_color = tonumber(colors.text:sub(2, 7), 16)
	end
end

-- One HUD element at the tracker's anchor and the values last sent to it:
-- added with `text`, `number`, the offset x/y and (images) the scale sx/sy
-- when `e` is nil, else sent only what changed (`hud_change` sends a packet
-- on every call, hud_layout.lua bar_fill). Text and images are placed by
-- their top edge, `align` -1 by the right edge and 1 by the left.
local function put(player, e, kind, align, text, number, x, y, sx, sy)
	if not e then
		return {id = player:hud_add({type = kind, text = text, number = number,
			position = grug_core.hud_layout.anchors.quest_list.position,
			alignment = {x = align, y = 1}, offset = {x = x, y = y},
			scale = sx and {x = sx, y = sy}, z_index = kind == "image" and 0 or 1}),
			text = text, number = number, x = x, y = y, sx = sx, sy = sy}
	end
	if e.text ~= text then player:hud_change(e.id, "text", text); e.text = text end
	if e.number ~= number then player:hud_change(e.id, "number", number); e.number = number end
	if e.x ~= x or e.y ~= y then
		player:hud_change(e.id, "offset", {x = x, y = y}); e.x, e.y = x, y
	end
	if e.sx ~= sx or e.sy ~= sy then
		player:hud_change(e.id, "scale", {x = sx, y = sy}); e.sx, e.sy = sx, sy
	end
	return e
end

-- Whether the minimap's "Now playing" box shows (grug_map depends on this
-- mod, so it is read at run time); the boxes stay clear of it.
local function now_playing(name)
	local map = rawget(_G, "grug_map")
	local minimap = map and map.minimap
	return minimap and minimap.now_playing and minimap.now_playing(name) or false
end

-- Lays the boxes out (hud_layout.quest_boxes) and sends what changed:
-- elements are added or removed only when the box count or the "+N more"
-- line comes or goes, everything else is a hud_change of a changed value.
local function draw(player, row)
	theme()
	local layout = grug_core.hud_layout
	local entries = grug_quests.hud_entries(row.journal, row.level,
		layout.side_text_width(row.window))
	local g = layout.quest_boxes(row.window, #entries, row.playing)
	local right = layout.anchors.quest_list.offset.x
	local left = right - g.width + g.pad
	for i = 1, g.shown do
		local entry, top = entries[i], g.tops[i]
		local box = row.boxes[i] or {}
		row.boxes[i] = box
		box.box = put(player, box.box, "image", -1, box_texture, nil, right, top,
			g.width, g.height)
		box.title = put(player, box.title, "text", 1, entry.title, title_color, left,
			top + g.pad)
		box.label = put(player, box.label, "text", -1, entry.label, entry.color,
			right - g.pad, top + g.pad)
		box.line = put(player, box.line, "text", 1, entry.line, OBJECTIVE_COLOR, left,
			top + g.pad + g.line)
	end
	for i = #row.boxes, g.shown + 1, -1 do
		for _, key in ipairs({"box", "title", "label", "line"}) do
			player:hud_remove(row.boxes[i][key].id)
		end
		row.boxes[i] = nil
	end
	if g.more > 0 then
		row.more = put(player, row.more, "text", -1, ("+%d more"):format(g.more),
			title_color, right - g.pad, g.more_top)
	elseif row.more then
		player:hud_remove(row.more.id)
		row.more = nil
	end
end

-- The journal is built only when its key (Q.journal_key: the raw quest
-- state and the counts of held objective items) changed, and the boxes
-- drawn only when the journal, the window (size and scalings) or the "Now
-- playing" box did (Round 30, perf review #5), or the level (below).
local function refresh(player)
	local name = player:get_player_name()
	local row = huds[name]
	if not row then return end
	local raw, held, counts = grug_quests.journal_key(player)
	local window = core.get_player_window_information(name)
	local playing = now_playing(name)
	local size = window and window.size
	local key = size and ("%d %d %s %s %s"):format(size.x, size.y, window.real_hud_scaling,
		window.real_gui_scaling, tostring(playing)) or tostring(playing)
	local fresh = raw ~= row.raw or held ~= row.held
	-- Held objective items changed under an unchanged state (picked up,
	-- dropped, used): an NPC's marker may turn ready or back. A state change
	-- has told the markers already.
	if raw == row.raw and held ~= row.held then grug_quests.markers_changed(player) end
	if not fresh and key == row.key then return end
	if fresh then
		row.journal, row.raw, row.held = grug_quests.journal(player, counts), raw, held
		post_progress(player, row.journal)
	end
	row.key, row.window, row.playing = key, window, playing
	draw(player, row)
end

-- Each player is polled every SLOTS x SLOT_PERIOD = 0.5 s, in one of SLOTS
-- phases by join order, so many players never refresh in the same step
-- (the pattern of grug_core/atmosphere_zones.lua).
local SLOTS, SLOT_PERIOD = 5, 0.1
local slot_of, joined, accumulator, current_slot = {}, 0, 0, 0

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	huds[name] = {boxes = {}, level = grug_xp.get_level(player)}
	joined = joined + 1
	slot_of[name] = joined % SLOTS + 1
	refresh(player)
end)
core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	huds[name], seen[name], slot_of[name] = nil, nil, nil
end)
grug_quests.register_on_change(refresh)
-- The level labels' colours follow the player's level.
grug_xp.register_on_level_change(function(player, _, level)
	local row = huds[player:get_player_name()]
	if row and row.journal and row.level ~= level then
		row.level = level
		draw(player, row)
	end
end)
core.register_on_player_inventory_action(function(player) refresh(player) end)
core.register_globalstep(function(dtime)
	accumulator = accumulator + dtime
	if accumulator < SLOT_PERIOD then return end
	-- A stall longer than one period collapses to a single slot.
	accumulator = accumulator - SLOT_PERIOD
	if accumulator > SLOT_PERIOD then accumulator = 0 end
	current_slot = current_slot % SLOTS + 1
	for name, slot in pairs(slot_of) do
		if slot == current_slot then
			local player = core.get_player_by_name(name)
			if player then refresh(player) end
		end
	end
end)
