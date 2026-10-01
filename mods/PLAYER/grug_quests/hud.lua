local huds = {}
local elapsed = 0

-- Text can carry translation escapes ("\27(T@mobs)Raw Meat\27E"). Resolve
-- them to the game's English text first, so a cut never lands inside an
-- escape and the width counts only visible characters.
local plain = grug_core.plain_text

local function objective_text(objective)
	local subject = objective.description
	if objective.type == "item" then
		subject = "Bring " .. grug_core.item_name(objective.item)
	elseif objective.type == "talk" then
		local npc = grug_quests.registered_npcs[objective.npc]
		subject = "Speak with " .. (npc and npc.title or objective.npc)
	elseif not subject or subject == "Defeat named threat" then
		local names = {}
		for _, name in ipairs(objective.mobs or {}) do
			local def = core.registered_entities[name]
			local label = def and def.description
			if not label or label == "" then label = (name:match("[^:]+$") or name):gsub("_", " ") end
			names[#names + 1] = label
		end
		subject = "Defeat " .. table.concat(names, " or ")
	end
	return ("%d/%d %s"):format(objective.count, objective.required, subject or "Objective")
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
-- no quest title, or "Return to <turn-in NPC>" once the quest is ready.
-- Two quests with the same objective may read the same (accepted).
function grug_quests.hud_line(quest, width)
	local text
	if quest.ready then
		local npc = grug_quests.registered_npcs[quest.npc]
		text = "Return to " .. (npc and npc.title or tostring(quest.npc))
	else
		local parts = {}
		for _, objective in ipairs(quest.objectives) do parts[#parts + 1] = objective_text(objective) end
		text = table.concat(parts, "; ")
	end
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

-- The short subject of an objective for the message feed: the mob, item or
-- NPC name alone ("Small Boar", "Light Leather", "Elder Maren").
local function feed_subject(objective)
	if objective.type == "item" then return grug_core.item_name(objective.item) end
	if objective.type == "talk" then
		local npc = grug_quests.registered_npcs[objective.npc]
		return npc and npc.title or tostring(objective.npc)
	end
	local names = {}
	for _, name in ipairs(objective.mobs or {}) do
		local def = core.registered_entities[name]
		local label = def and def.description
		if not label or label == "" then
			label = (name:match("[^:]+$") or name):gsub("_", " ")
				:gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end)
		end
		names[#names + 1] = plain(label)
	end
	return table.concat(names, " or ")
end

-- One feed line per quest (Round 28 ruling 20): every objective as
-- "<subject> <count>/<required>", joined by ", " ("Small Boar 3/10"), cut
-- like a tracker line at the widest tracker width (QUEST_WRAP characters).
function grug_quests.feed_text(quest)
	local parts = {}
	for _, objective in ipairs(quest.objectives) do
		parts[#parts + 1] = ("%s %d/%d"):format(feed_subject(objective),
			objective.count, objective.required)
	end
	return one_line(table.concat(parts, ", "), grug_core.hud_layout.QUEST_WRAP)
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

local function refresh(player)
	local row = huds[player:get_player_name()]
	if not row then return end
	local journal = grug_quests.journal(player)
	post_progress(player, journal)
	local text = grug_quests.hud_text(journal,
		core.get_player_window_information(player:get_player_name()))
	if row.text ~= text then player:hud_change(row.id, "text", text); row.text = text end
end

core.register_on_joinplayer(function(player)
	local anchor = grug_core.hud_layout.anchors.quest_list
	huds[player:get_player_name()] = {text = "", id = player:hud_add({type = "text",
		position = anchor.position, offset = anchor.offset, alignment = anchor.alignment,
		text = "", number = 0xffe080, z_index = 1})}
	refresh(player)
end)
core.register_on_leaveplayer(function(player)
	huds[player:get_player_name()] = nil
	seen[player:get_player_name()] = nil
end)
grug_quests.register_on_change(refresh)
core.register_on_player_inventory_action(function(player) refresh(player) end)
core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < 0.5 then return end
	elapsed = elapsed % 0.5
	for _, player in ipairs(core.get_connected_players()) do refresh(player) end
end)
