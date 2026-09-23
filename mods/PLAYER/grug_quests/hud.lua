local huds = {}
local elapsed = 0

local function objective_text(objective)
	local subject = objective.description
	if objective.type == "item" then
		local def = core.registered_items[objective.item]
		local description = def and def.description ~= "" and def.description or objective.item
		subject = "Bring " .. (description:match("^[^\n]+") or objective.item)
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

local function wrapped_lines(text, width, limit)
	local lines = {}
	for line in (grug_inventory.wrap_text(text, width) .. "\n"):gmatch("(.-)\n") do
		lines[#lines + 1] = line
	end
	if #lines > limit then
		lines[limit] = lines[limit]:sub(1, math.max(1, width - 3)) .. "..."
		for i = #lines, limit + 1, -1 do lines[i] = nil end
	end
	return table.concat(lines, "\n")
end

local function render(player)
	local journal = grug_quests.journal(player)
	if not journal.hud_enabled or #journal.quests == 0 then return "" end
	local by_id, lines = {}, {}
	local layout = grug_core.hud_layout
	local width = layout.side_text_width(core.get_player_window_information(player:get_player_name()))
	for _, quest in ipairs(journal.quests) do by_id[quest.id] = quest end
	for _, id in ipairs(journal.tracked) do
		local quest = by_id[id]
		if quest then
			local title = quest.title .. (quest.ready and " [Ready]" or "")
			lines[#lines + 1] = wrapped_lines(title, width, layout.QUEST_TITLE_LINES)
			local parts = {}
			for _, objective in ipairs(quest.objectives) do parts[#parts + 1] = objective_text(objective) end
			local wrapped = wrapped_lines(table.concat(parts, "; "), width, layout.QUEST_OBJECTIVE_LINES)
			for line in (wrapped .. "\n"):gmatch("(.-)\n") do
				lines[#lines + 1] = line
			end
		end
	end
	return table.concat(lines, "\n")
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
