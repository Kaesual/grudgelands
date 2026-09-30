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

local function render(player)
	return grug_quests.hud_text(grug_quests.journal(player),
		core.get_player_window_information(player:get_player_name()))
end

local function refresh(player)
	local row = huds[player:get_player_name()]
	if not row then return end
	local text = render(player)
	if row.text ~= text then player:hud_change(row.id, "text", text); row.text = text end
end

core.register_on_joinplayer(function(player)
	local anchor = grug_core.hud_layout.anchors.quest_list
	huds[player:get_player_name()] = {text = "", id = player:hud_add({type = "text",
		position = anchor.position, offset = anchor.offset, alignment = anchor.alignment,
		text = "", number = 0xffe080, z_index = 1})}
	refresh(player)
end)
core.register_on_leaveplayer(function(player) huds[player:get_player_name()] = nil end)
grug_quests.register_on_change(refresh)
core.register_on_player_inventory_action(function(player) refresh(player) end)
core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < 0.5 then return end
	elapsed = elapsed % 0.5
	for _, player in ipairs(core.get_connected_players()) do refresh(player) end
end)
