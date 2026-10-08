-- The quest boxes of the map window (Round 44, the UI rework spec ruling
-- 14; until then the Quests tab, grug_quests/ui.lua): right of the map, the
-- quest list (active count, the Quest HUD switch, the list, Track on HUD,
-- Abandon with a confirmation) and below it the selected quest's text. The
-- window (window.lua) draws them in real coordinates into its right column
-- and passes their fields here; the selected quest also picks the map's
-- quest targets (targets.lua). State lives in the window's session:
-- quest_selected, quest_abandon (the quest whose confirmation is shown),
-- quest_notice and quest_rows (list row -> quest id).
local M = {}

local function esc(value)
	return core.formspec_escape(tostring(value or ""))
end

local function tracked(journal, id)
	for _, candidate in ipairs(journal.tracked) do
		if candidate == id then return true end
	end
	return false
end

-- One line per objective (ruling 41): "Bring Wood Axe: 0/1", with the
-- targets' level range (Lane Q0): "Defeat Barrow Piglet: 0/8 (level 1–2)".
local function objective_label(objective)
	return ("%s: %d/%d%s"):format(grug_quests.objective_action(objective),
		objective.count, objective.required, grug_quests.objective_levels_text(objective))
end

-- The selected quest of the journal and its row, or the first quest when
-- none (or a gone one) is selected.
function M.selected(journal, session)
	for index, quest in ipairs(journal.quests) do
		if quest.id == session.quest_selected then return quest, index end
	end
	local quest = journal.quests[1]
	session.quest_selected = quest and quest.id or nil
	return quest, quest and 1 or nil
end

-- Description, objective lines and the reward line, separated by an empty
-- line each like the quest-offer dialogue (Round 32: one text field, so it
-- scrolls only when everything together does not fit). No hard wrap: the
-- textarea wraps at its own width.
local function detail_text(quest)
	local objectives = {}
	for _, objective in ipairs(quest.objectives) do
		objectives[#objectives + 1] = objective_label(objective)
	end
	local rewards = {}
	if quest.reward_xp > 0 then rewards[#rewards + 1] = quest.reward_xp .. " XP" end
	if quest.rewards.copper > 0 then rewards[#rewards + 1] = grug_money.format(quest.rewards.copper) end
	for _, item in ipairs(quest.rewards.items) do
		local stack = ItemStack(item)
		rewards[#rewards + 1] = stack:get_count() .. " × " .. grug_core.item_name(stack)
	end
	return quest.description .. "\n\n" ..
		table.concat(objectives, "\n") .. "\n\nRewards: " .. table.concat(rewards, ", ")
end

-- "Level 9 · Dawnmere Fields": the quest's level and its zone's name.
local function level_line(quest)
	local def = grug_quests.registered_quests[quest.id]
	if not def then return "" end
	local zone = def.zone and grug_zones.get(def.zone)
	local name = zone and zone.display_name
	return "Level " .. def.level .. (name and (" · " .. name) or "")
end

-- Geometry inside the column (real coordinates): the list box takes
-- LIST_SHARE of the column's height (at least LIST_MIN), the text box the
-- rest below a GAP. Labels and checkboxes are placed by their vertical
-- centre, buttons by their top.
local PAD, GAP, ROW_H, BUTTON_H = 0.2, 0.25, 0.45, 0.6
local LIST_SHARE, LIST_MIN = 0.42, 3.6
local ABANDON_W, CONFIRM_W, CANCEL_W, BUTTON_GAP = 1.8, 2.6, 1.5, 0.15
local HUD_W = 2.3 -- the Quest HUD checkbox with its label
local PANEL = "#00000040"

-- The two boxes for `journal` inside `rect` {x, y, w, h}.
function M.content(session, journal, rect)
	local quest, selected_index = M.selected(journal, session)
	local x, y, w = rect.x, rect.y, rect.w
	local list_h = math.max(LIST_MIN, rect.h * LIST_SHARE)
	local right = x + w - PAD
	local rows = {}
	session.quest_rows = {}
	for index, row in ipairs(journal.quests) do
		session.quest_rows[index] = row.id
		rows[#rows + 1] = grug_quests.list_entry((tracked(journal, row.id) and "* " or "") .. row.title,
			row.ready and "ready" or "active", row.repeatable)
	end
	local row_y = y + list_h - PAD - BUTTON_H
	local fs = {
		("box[%.2f,%.2f;%.2f,%.2f;%s]"):format(x, y, w, list_h, PANEL),
		("label[%.2f,%.2f;Active quests: %d/20]"):format(x + PAD, y + PAD + ROW_H / 2, #journal.quests),
		("checkbox[%.2f,%.2f;grug_quest_hud;Quest HUD;%s]"):format(right - HUD_W,
			y + PAD + ROW_H / 2, journal.hud_enabled and "true" or "false"),
		("textlist[%.2f,%.2f;%.2f,%.2f;grug_quest_list;%s;%d;false]"):format(x + PAD,
			y + PAD + ROW_H + 0.1, w - 2 * PAD, row_y - (y + PAD + ROW_H + 0.1) - 0.15,
			table.concat(rows, ","), selected_index or 1),
		("tooltip[grug_quest_list;%s]"):format(grug_quests.status_tooltip({"active", "ready"})),
	}
	local text_y = y + list_h + GAP
	local text_h = rect.h - list_h - GAP
	fs[#fs + 1] = ("box[%.2f,%.2f;%.2f,%.2f;%s]"):format(x, text_y, w, text_h, PANEL)
	if not quest then
		fs[#fs + 1] = ("textarea[%.2f,%.2f;%.2f,%.2f;;;%s]"):format(x + PAD, text_y + PAD,
			w - 2 * PAD, text_h - 2 * PAD, "Your quest log is empty. Talk to a quest giver to begin.")
		return table.concat(fs)
	end
	-- While the abandon confirmation is shown, its two buttons take the row
	-- alone (at a large GUI scale "Track on HUD" would run into them).
	if session.quest_abandon == quest.id then
		local cancel_x = right - CANCEL_W
		fs[#fs + 1] = ("button[%.2f,%.2f;%.2f,%.2f;grug_quest_confirm;Confirm abandon]")
			:format(cancel_x - BUTTON_GAP - CONFIRM_W, row_y, CONFIRM_W, BUTTON_H)
		fs[#fs + 1] = ("button[%.2f,%.2f;%.2f,%.2f;grug_quest_cancel;Cancel]")
			:format(cancel_x, row_y, CANCEL_W, BUTTON_H)
	else
		fs[#fs + 1] = ("checkbox[%.2f,%.2f;grug_quest_track;Track on HUD;%s]")
			:format(x + PAD, row_y + BUTTON_H / 2, tracked(journal, quest.id) and "true" or "false")
		fs[#fs + 1] = ("button[%.2f,%.2f;%.2f,%.2f;grug_quest_abandon;Abandon]")
			:format(right - ABANDON_W, row_y, ABANDON_W, BUTTON_H)
	end
	fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(x + PAD, text_y + PAD + ROW_H / 2,
		esc(quest.title .. (quest.repeatable and " (Repeatable)" or "")))
	fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(x + PAD, text_y + PAD + ROW_H * 1.5,
		esc(level_line(quest)))
	-- The status line at the bottom: where to hand in, or the last notice.
	local status
	if quest.ready then
		local npc = grug_quests.registered_npcs[quest.npc]
		status = (quest.travel and "Travel to " or "Ready to return to ") ..
			(npc and npc.title or quest.npc) .. "."
	else
		status = session.quest_notice
	end
	local area_y = text_y + PAD + ROW_H * 2 + 0.1
	local area_bottom = text_y + text_h - PAD - (status and ROW_H or 0)
	fs[#fs + 1] = ("textarea[%.2f,%.2f;%.2f,%.2f;;;%s]"):format(x + PAD, area_y,
		w - 2 * PAD, area_bottom - area_y, esc(detail_text(quest)))
	if status then
		fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(x + PAD, text_y + text_h - PAD - ROW_H / 2,
			esc(status))
	end
	return table.concat(fs)
end

-- Applies the boxes' fields; true when one of them changed something the
-- window shows (the caller sends the window again).
function M.handle(player, session, fields)
	local journal = grug_quests.journal(player)
	local changed = false
	if fields.grug_quest_list then
		local event = core.explode_textlist_event(fields.grug_quest_list)
		local rows = session.quest_rows or {}
		if event.type == "CHG" and rows[event.index] then
			if session.quest_selected ~= rows[event.index] then
				session.quest_selected = rows[event.index]
				session.quest_abandon, session.quest_notice = nil, nil
				changed = true
			end
		end
	end
	local id = session.quest_selected
	if fields.grug_quest_hud and
			(fields.grug_quest_hud == "true") ~= journal.hud_enabled then
		grug_quests.set_hud_enabled(player, fields.grug_quest_hud == "true")
		changed = true
	end
	if fields.grug_quest_track and id and
			(fields.grug_quest_track == "true") ~= tracked(journal, id) then
		local ok, message = grug_quests.set_tracked(player, id,
			fields.grug_quest_track == "true")
		session.quest_notice = ok and nil or message
		changed = true
	end
	if fields.grug_quest_abandon and id then
		session.quest_abandon = id
		changed = true
	end
	if fields.grug_quest_cancel then
		session.quest_abandon = nil
		changed = true
	end
	if fields.grug_quest_confirm and id and session.quest_abandon == id then
		grug_quests.abandon(player, id)
		session.quest_selected, session.quest_abandon = nil, nil
		changed = true
	end
	return changed
end

return M
