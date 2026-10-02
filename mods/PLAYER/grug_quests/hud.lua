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

-- One HUD line per tracked quest (Round 24 ruling 23): the objective only,
-- no quest title, or "Return to <turn-in NPC>" once the quest is ready. A
-- travel quest reads "Travel to <NPC>" throughout (Round 28 ruling 39);
-- several objectives share one compact line, "Wood Axe 0/1, Wood Pickaxe
-- 0/1" (ruling 41); a repeatable starts with "Repeatable: " (ruling 42).
-- Two quests with the same objective may read the same (accepted).
function grug_quests.hud_line(quest, width)
	local text
	local npc = grug_quests.registered_npcs[quest.npc]
	if quest.travel then
		text = "Travel to " .. (npc and npc.title or tostring(quest.npc))
	elseif quest.ready then
		text = "Return to " .. (npc and npc.title or tostring(quest.npc))
	elseif #quest.objectives > 1 then
		text = grug_quests.compact_text(quest)
	else
		text = objective_text(quest.objectives[1])
	end
	if quest.repeatable then text = "Repeatable: " .. text end
	return one_line(text, width)
end

-- `window` is the player's window information (nil in fixtures).
function grug_quests.hud_text(journal, window)
	if not journal.hud_enabled or #journal.quests == 0 then return "" end
	local by_id, lines = {}, {}
	local width = grug_core.hud_layout.side_text_width(window)
	for _, quest in ipairs(journal.quests) do by_id[quest.id] = quest end
	for _, id in ipairs(journal.tracked) do
		local quest = by_id[id]
		if quest and #lines < grug_quests.MAX_TRACKED then
			lines[#lines + 1] = grug_quests.hud_line(quest, width)
		end
	end
	return table.concat(lines, "\n")
end

-- Every objective as "<subject> <count>/<required>", joined by ", "
-- ("Small Boar 3/10, Light Leather 0/2").
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

-- The journal is built only when its key (Q.journal_key: the raw quest
-- state and the counts of held objective items) changed, and the text only
-- when the journal or the line width did (Round 30, perf review #5).
local function refresh(player)
	local name = player:get_player_name()
	local row = huds[name]
	if not row then return end
	local raw, held, counts = grug_quests.journal_key(player)
	local window = core.get_player_window_information(name)
	local width = grug_core.hud_layout.side_text_width(window)
	local fresh = raw ~= row.raw or held ~= row.held
	if not fresh and width == row.width then return end
	if fresh then
		row.journal, row.raw, row.held = grug_quests.journal(player, counts), raw, held
		post_progress(player, row.journal)
	end
	row.width = width
	local text = grug_quests.hud_text(row.journal, window)
	if row.text ~= text then player:hud_change(row.id, "text", text); row.text = text end
end

-- Each player is polled every SLOTS x SLOT_PERIOD = 0.5 s, in one of SLOTS
-- phases by join order, so many players never refresh in the same step
-- (the pattern of grug_core/atmosphere_zones.lua).
local SLOTS, SLOT_PERIOD = 5, 0.1
local slot_of, joined, accumulator, current_slot = {}, 0, 0, 0

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local anchor = grug_core.hud_layout.anchors.quest_list
	huds[name] = {text = "", id = player:hud_add({type = "text",
		position = anchor.position, offset = anchor.offset, alignment = anchor.alignment,
		text = "", number = 0xffe080, z_index = 1})}
	joined = joined + 1
	slot_of[name] = joined % SLOTS + 1
	refresh(player)
end)
core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	huds[name], seen[name], slot_of[name] = nil, nil, nil
end)
grug_quests.register_on_change(refresh)
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
