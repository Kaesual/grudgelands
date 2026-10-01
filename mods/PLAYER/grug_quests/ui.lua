local PAGE = "grug_quests:quests"

local function esc(value)
	return core.formspec_escape(tostring(value or ""))
end

local function tracked(journal, id)
	for _, candidate in ipairs(journal.tracked) do
		if candidate == id then return true end
	end
	return false
end

local function mob_label(name)
	local def = core.registered_entities[name]
	if def and def.description and def.description ~= "" then return def.description end
	local label = name:match("[^:]+$") or name
	return label:gsub("_", " "):gsub("(%a)([%w']*)", function(a, b)
		return a:upper() .. b
	end)
end

local function objective_label(objective)
	local subject
	if objective.type == "item" then
		subject = "Bring " .. grug_core.item_name(objective.item)
	elseif objective.type == "talk" then
		local npc = grug_quests.registered_npcs[objective.npc]
		subject = "Speak with " .. (npc and npc.title or objective.npc)
	else
		local names = {}
		for _, name in ipairs(objective.mobs or {}) do names[#names + 1] = mob_label(name) end
		subject = "Defeat " .. table.concat(names, " or ")
	end
	return ("%s: %d/%d"):format(subject, objective.count, objective.required)
end

local function selected(journal, context)
	for index, quest in ipairs(journal.quests) do
		if quest.id == context.grug_quest_selected then return quest, index end
	end
	local quest = journal.quests[1]
	context.grug_quest_selected = quest and quest.id or nil
	return quest, quest and 1 or nil
end

-- The detail column right of the quest list (Round 28 ruling 22). sfinv uses
-- legacy coordinates: a textarea[] is drawn PADDING (0.3 units) left of its
-- given x (guiFormSpecMenu.cpp parseTextArea: `pos -= padding`), while
-- textlist[], label[], checkbox[] and button[] are not shifted. The list
-- ends at 0.15 + 3.45 = 3.60, so text drawn from TEXT_X keeps a visible
-- DETAIL_GAP from it, and every other element of the column uses COLUMN_X
-- to start at the same edge as the text. The right edge stays where it was.
local PADDING, DETAIL_GAP = 0.3, 0.2
local TEXT_X = 3.60 + PADDING + DETAIL_GAP
local COLUMN_X = TEXT_X - PADDING
local TEXT_W = 6.0

local function content(player, context)
	local journal = grug_quests.journal(player)
	local quest, selected_index = selected(journal, context)
	local rows = {}
	context.grug_quest_rows = {}
	for index, row in ipairs(journal.quests) do
		context.grug_quest_rows[index] = row.id
		rows[#rows + 1] = esc((tracked(journal, row.id) and "* " or "") ..
			row.title .. (row.ready and " [Ready]" or ""))
	end
	local fs = {
		("label[0.15,0.18;Active quests: %d/20]"):format(#journal.quests),
		("checkbox[7.65,0.08;grug_quest_hud;Quest HUD;%s]")
			:format(journal.hud_enabled and "true" or "false"),
		("textlist[0.15,0.65;3.45,5.95;grug_quest_list;%s;%d;false]")
			:format(table.concat(rows, ","), selected_index or 1),
	}
	if not quest then
		fs[#fs + 1] = ("textarea[%.2f,0.65;%.2f,2.0;;;%s]"):format(TEXT_X, TEXT_W + 0.1,
			"Your quest log is empty. Talk to a quest giver to begin.")
		return table.concat(fs)
	end
	fs[#fs + 1] = ("label[%.2f,0.65;%s]"):format(COLUMN_X, esc(quest.title))
	fs[#fs + 1] = ("textarea[%.2f,1.05;%.2f,1.35;;;%s]"):format(TEXT_X, TEXT_W,
		esc(grug_inventory.wrap_text(quest.description, 58)))
	local objectives = {}
	for _, objective in ipairs(quest.objectives) do
		objectives[#objectives + 1] = objective_label(objective)
	end
	fs[#fs + 1] = ("textarea[%.2f,2.35;%.2f,1.55;;;%s]"):format(TEXT_X, TEXT_W,
		esc(table.concat(objectives, "\n")))
	local rewards = {}
	if quest.rewards.xp > 0 then rewards[#rewards + 1] = quest.rewards.xp .. " XP" end
	if quest.rewards.copper > 0 then rewards[#rewards + 1] = grug_money.format(quest.rewards.copper) end
	for _, item in ipairs(quest.rewards.items) do
		local stack = ItemStack(item)
		rewards[#rewards + 1] = stack:get_count() .. " × " .. grug_core.item_name(stack)
	end
	fs[#fs + 1] = ("textarea[%.2f,4.00;%.2f,0.75;;;%s]"):format(TEXT_X, TEXT_W,
		esc("Rewards: " .. table.concat(rewards, ", ")))
	fs[#fs + 1] = ("checkbox[%.2f,4.78;grug_quest_track;Track on HUD;%s]")
		:format(COLUMN_X, tracked(journal, quest.id) and "true" or "false")
	if context.grug_quest_abandon == quest.id then
		fs[#fs + 1] = ("button[%.2f,5.35;2.05,0.65;grug_quest_confirm;Confirm abandon]")
			:format(COLUMN_X)
		fs[#fs + 1] = ("button[%.2f,5.35;1.35,0.65;grug_quest_cancel;Cancel]")
			:format(COLUMN_X + 2.2)
	else
		fs[#fs + 1] = ("button[%.2f,5.35;1.55,0.65;grug_quest_abandon;Abandon]")
			:format(COLUMN_X)
	end
	if quest.ready then
		local npc = grug_quests.registered_npcs[quest.npc]
		fs[#fs + 1] = ("label[%.2f,6.15;%s]"):format(COLUMN_X,
			esc("Ready to return to " .. (npc and npc.title or quest.npc) .. "."))
	elseif context.grug_quest_notice then
		fs[#fs + 1] = ("label[%.2f,6.15;%s]"):format(COLUMN_X,
			esc(context.grug_quest_notice))
	end
	return table.concat(fs)
end

local function refresh(player)
	if sfinv.get_page(player) == PAGE then sfinv.set_page(player, PAGE) end
end

sfinv.register_page(PAGE, {title = "Quests", get = function(_, player, context)
	return sfinv.make_formspec(player, context, content(player, context), true)
end, on_player_receive_fields = function(_, player, context, fields)
	local journal = grug_quests.journal(player)
	if fields.grug_quest_list then
		local event = core.explode_textlist_event(fields.grug_quest_list)
		local rows = context.grug_quest_rows or {}
		if event.type == "CHG" and rows[event.index] then
			context.grug_quest_selected = rows[event.index]
			context.grug_quest_abandon = nil
		end
	end
	local id = context.grug_quest_selected
	if fields.grug_quest_hud and
			(fields.grug_quest_hud == "true") ~= journal.hud_enabled then
		grug_quests.set_hud_enabled(player, fields.grug_quest_hud == "true")
	end
	if fields.grug_quest_track and id and
			(fields.grug_quest_track == "true") ~= tracked(journal, id) then
		local ok, message = grug_quests.set_tracked(player, id,
			fields.grug_quest_track == "true")
		context.grug_quest_notice = ok and nil or message
	end
	if fields.grug_quest_abandon and id then context.grug_quest_abandon = id end
	if fields.grug_quest_cancel then context.grug_quest_abandon = nil end
	if fields.grug_quest_confirm and id and context.grug_quest_abandon == id then
		grug_quests.abandon(player, id)
		context.grug_quest_selected, context.grug_quest_abandon = nil, nil
	end
	refresh(player)
end})

grug_quests.register_on_change(refresh)

core.register_on_mods_loaded(function()
	local page, ordered, inserted = sfinv.pages[PAGE], {}, false
	for _, def in ipairs(sfinv.pages_unordered) do
		if def ~= page then ordered[#ordered + 1] = def end
		if def.name == "grug_skills:skills" then ordered[#ordered + 1] = page; inserted = true end
	end
	if not inserted then ordered[#ordered + 1] = page end
	sfinv.pages_unordered = ordered
end)
