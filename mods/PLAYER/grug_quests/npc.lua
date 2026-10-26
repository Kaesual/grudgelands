local Q = grug_quests
local sessions, markers = {}, {}
local FORM = "grug_quests:dialogue"
local function npc_id(entity)
	if not entity or not entity._grug_start or not entity._grug_socket then return nil end
	if not entity.object or not entity.object:is_valid() then return nil end
	return Q.npc_by_socket[entity._grug_start .. "/" .. entity._grug_socket]
end
local function in_reach(player, entity)
	if not player or not player:is_player() or player:get_hp() <= 0 then return false end
	local pos = entity.object:get_pos()
	local pp = player:get_pos()
	return pos and pp and vector.distance(pos, pp) <= 6
end
-- A quest list row (Round 35): the status is the entry's colour, not a text
-- that cut the title off. The quest giver's dialog and the quest log share
-- the colours and the legend.
Q.STATUS_COLORS = {available = "#ffd24a", ready = "#7ee06a", active = "#8fc1ff", locked = "#9a9a9a"}
-- The story accent (Round 57 ruling 13): the "Story" category of the quest
-- lists and the story markers (the map icons, tools/r57_qsys/render_story_icons.py).
Q.STORY_COLOR = "#c69cff"
local STATUS_ORDER = {"available", "ready", "active", "locked"}
local STATUS_NAMES = {available = {"Available", "gold"}, ready = {"Ready to complete", "green"},
	active = {"In progress", "blue"}, locked = {"Locked", "grey"}}
-- `indent` (a list with categories) sets the title in by two spaces.
function Q.list_entry(title, status, indent)
	return Q.STATUS_COLORS[status] .. core.formspec_escape((indent and "  " or "") .. title)
end
-- The legend as one coloured line, and as the list's tooltip (escaped).
function Q.status_legend(statuses)
	local parts = {}
	for _, status in ipairs(statuses or STATUS_ORDER) do
		parts[#parts + 1] = core.colorize(Q.STATUS_COLORS[status], STATUS_NAMES[status][1])
	end
	return core.formspec_escape(table.concat(parts, "   "))
end
function Q.status_tooltip(statuses)
	local lines = {}
	for _, status in ipairs(statuses or STATUS_ORDER) do
		lines[#lines + 1] = STATUS_NAMES[status][1] .. ": " .. STATUS_NAMES[status][2]
	end
	return core.formspec_escape(table.concat(lines, "\n"))
end
-- A quest list with its categories (Round 57 ruling 13): once a story quest
-- is listed, a "Story" header in the story accent above the story quests
-- and a "Side quests" header above the others, their titles set in; the
-- status stays each entry's colour. `entry(row, indent)` makes an entry.
-- Returns the textlist entries and, per entry, the row index (nil on a
-- header), and per row its entry index.
function Q.category_list(rows, entry)
	local story, side = {}, {}
	for index, row in ipairs(rows) do
		if row.story then story[#story + 1] = index else side[#side + 1] = index end
	end
	local entries, row_of, entry_of = {}, {}, {}
	local function add(text, index)
		entries[#entries + 1] = text
		row_of[#entries] = index
		if index then entry_of[index] = #entries end
	end
	if #story == 0 then
		for index, row in ipairs(rows) do add(entry(row, false), index) end
		return entries, row_of, entry_of
	end
	add(Q.STORY_COLOR .. core.formspec_escape("Story"))
	for _, index in ipairs(story) do add(entry(rows[index], true), index) end
	if #side > 0 then
		add("#b8b8b8" .. core.formspec_escape("Side quests"))
		for _, index in ipairs(side) do add(entry(rows[index], true), index) end
	end
	return entries, row_of, entry_of
end

-- The row a dialog opens on (0.45.1): the first quest ready to complete,
-- else the first one to accept, else `fallback` (default the first row), so
-- a player with several finished quests just clicks "Complete" again and
-- again, and one accepting several just clicks "Accept". Story quests are
-- listed first (Q.npc_quests), so they come first here too.
local function preselect(rows, fallback)
	local available
	for index, row in ipairs(rows) do
		if row.status == "ready" then return index end
		if row.status == "available" and not available then available = index end
	end
	return available or fallback or 1
end
Q.npc_preselect = preselect

-- A reward choice as the player would get it: the stack made as the
-- turn-in makes it (its item level and fixed enchants, the receiver's
-- tooltip), or the plain stack without grug_quality (fixtures).
local function choice_stack(player, def, choice)
	local items_api = rawget(_G, "grug_items")
	local stack = items_api and items_api.make_stack and
		items_api.make_stack(choice.item, def.level, choice.affixes, player)
	return stack or ItemStack(choice.item)
end

-- Its tooltip: grug_quality's own tooltip text (item buttons show only the
-- definition's description).
local function choice_tooltip(player, def, choice)
	local items_api = rawget(_G, "grug_items")
	local stack = choice_stack(player, def, choice)
	if not (items_api and items_api.tooltip_text) then return grug_core.item_name(stack) end
	return items_api.tooltip_text(stack, player)
end

-- The tooltip's lines as plain text (the quality colour and the stat
-- colours dropped): what the dialog's text area shows.
local function plain_lines(text)
	local out = {}
	for line in (grug_core.plain_text(text) .. "\n"):gmatch("(.-)\n") do
		if line ~= "" then out[#out + 1] = line end
	end
	return out
end

-- A choice as one line of the reward text (Round 57 follow-up, the user:
-- the enchants readable without hovering): the made stack's name (with its
-- enchant words, as the inventory shows it), its count and its enchant
-- lines.
local function choice_line(player, def, choice)
	local lines = plain_lines(choice_tooltip(player, def, choice))
	local stack = ItemStack(choice.item)
	local enchants = {}
	for _, line in ipairs(lines) do
		if line:find("^Prefix: ") or line:find("^Suffix: ") then enchants[#enchants + 1] = line end
	end
	return (lines[1] or grug_core.item_name(stack)) .. (stack:get_count() > 1 and " × " .. stack:get_count() or "") ..
		(#enchants > 0 and " (" .. table.concat(enchants, ", ") .. ")" or "")
end

-- The reward lines of a quest: its XP, copper and items, then its choice,
-- one choice per line (`player`: the reader, whose tooltip the made stacks
-- carry).
function Q.reward_lines(def, player)
	local lines = {"Rewards: " .. Q.reward_xp(def) .. " XP, " .. grug_money.format(def.rewards.copper)}
	for _, item in ipairs(def.rewards.items) do
		local stack = ItemStack(item)
		lines[#lines + 1] = grug_core.item_name(stack) .. " × " .. stack:get_count()
	end
	if #def.rewards.choices > 0 then
		lines[#lines + 1] = "and one of:"
		for _, choice in ipairs(def.rewards.choices) do
			lines[#lines + 1] = "  " .. choice_line(player, def, choice)
		end
	end
	return lines
end

-- The picked reward's whole tooltip, for the text area at the turn-in.
local function picked_lines(player, def, picked)
	local choice = picked and def.rewards.choices[picked]
	if not choice then return nil end
	return plain_lines(choice_tooltip(player, def, choice))
end

-- The choice row (Round 57 ruling 15) under the text: item icons with
-- their tooltips; at the turn-in buttons, the picked one framed, above the
-- Complete button; in the offer and while active, icons to read only.
local CHOICE_X, CHOICE_Y, CHOICE_SIZE, CHOICE_STEP = 6.5, 8.75, 0.9, 1.2
local function choice_row(player, def, ready, picked)
	local esc, out = core.formspec_escape, {}
	out[#out + 1] = ("label[%.2f,%.2f;%s]"):format(CHOICE_X, CHOICE_Y - 0.35,
		esc(ready and "Choose your reward:" or "You will choose one reward:"))
	for index, choice in ipairs(def.rewards.choices) do
		local x = CHOICE_X + (index - 1) * CHOICE_STEP
		local stack = ItemStack(choice.item)
		local name, count = stack:get_name(), stack:get_count()
		local tip = esc(choice_tooltip(player, def, choice))
		if ready then
			if picked == index then
				out[#out + 1] = ("box[%.2f,%.2f;%.2f,%.2f;#7ee06a]"):format(x - 0.08, CHOICE_Y - 0.08,
					CHOICE_SIZE + 0.16, CHOICE_SIZE + 0.16)
			end
			out[#out + 1] = ("item_image_button[%.2f,%.2f;%.2f,%.2f;%s;choice_%d;%s]"):format(x, CHOICE_Y,
				CHOICE_SIZE, CHOICE_SIZE, esc(name), index, count > 1 and tostring(count) or "")
			out[#out + 1] = ("tooltip[choice_%d;%s]"):format(index, tip)
		else
			out[#out + 1] = ("item_image[%.2f,%.2f;%.2f,%.2f;%s]"):format(x, CHOICE_Y, CHOICE_SIZE, CHOICE_SIZE,
				esc(name))
			if count > 1 then
				out[#out + 1] = ("label[%.2f,%.2f;%d]"):format(x + CHOICE_SIZE - 0.3, CHOICE_Y + CHOICE_SIZE - 0.2, count)
			end
			out[#out + 1] = ("tooltip[%.2f,%.2f;%.2f,%.2f;%s]"):format(x, CHOICE_Y, CHOICE_SIZE, CHOICE_SIZE, tip)
		end
	end
	-- The name the made stack shows (its enchant words); its whole tooltip
	-- heads the text area above (Round 57 follow-up).
	local chosen = ready and picked_lines(player, def, picked)
	out[#out + 1] = ("label[%.2f,%.2f;%s]"):format(CHOICE_X, CHOICE_Y + CHOICE_SIZE + 0.35,
		esc(chosen and ("Chosen: " .. chosen[1] .. " (see above)") or
			(ready and "Pick an item to see its enchantments above, or hover it." or
				"Hover an item to see its tooltip.")))
	return table.concat(out)
end

-- The narrow categorized list shares the dialog with a separate detail pane;
-- the selected quest's full title is repeated there. `selected` is the row
-- to show: an index (a click in the list), a quest id (that quest's row if
-- it is still listed, else the preselection), {after = quest id} (the
-- preselection, else that quest's row) or nil (the preselection). `notice`
-- marks a redraw after Accept or Complete; `picked` the reward chosen at
-- the turn-in (a redraw after a click on a choice).
function Q.open_npc(player, entity, selected, notice, picked)
	local id = npc_id(entity)
	if not id or not in_reach(player, entity) then return false end
	-- Ruling 13 (Round 31): a quest giver serves only its own faction.
	local npc = Q.registered_npcs[id]
	if not grug_factions.serves(npc.faction, player) then
		grug_factions.refuse(player, npc.title or id, npc.faction)
		return true
	end
	local rows = Q.npc_quests(player, id)
	if #rows == 0 then return false end
	-- The first open of the dialog plays its cue; a redraw (another quest
	-- chosen, after Accept or Complete) does not.
	local redraw = selected ~= nil or notice ~= nil
	local listed
	if type(selected) == "string" or type(selected) == "table" then
		local quest_id = type(selected) == "table" and selected.after or selected
		for index, row in ipairs(rows) do
			if row.id == quest_id then listed = index end
		end
		selected = type(selected) == "string" and listed or nil
	end
	selected = selected and math.min(math.max(selected, 1), #rows) or preselect(rows, listed)
	-- State markers and story categories survive the larger two-line rows.
	local category_entries, row_of = Q.category_list(rows, function(r) return r.title end)
	local entries = {}
	for index, category in ipairs(category_entries) do
		local row_index = row_of[index]
		local r = row_index and rows[row_index]
		entries[index] = r and {
			title = r.title, subtitle = STATUS_NAMES[r.status][1],
			icon = "grug_map_quest_" .. (r.story and "story_" or "") .. r.status .. ".png",
			tooltip = r.title .. "\n" .. (r.story and "Story · " or "") .. STATUS_NAMES[r.status][1],
			selected = row_index == selected,
		} or {title = category:gsub("^#[%x]+", ""), header = true}
	end
	local name = player:get_player_name()
	local previous = sessions[name]
	local session = {entity = entity, npc = id, rows = rows, selected = selected, row_of = row_of}
	-- Reopening another giver starts at the top; redraws keep the client scroll.
	if previous and previous.entity == entity and previous.npc == id then
		session._ui_rows = previous._ui_rows
	end
	local row = rows[selected]
	local previous_row = previous and previous.rows[previous.selected]
	local reveal_selected = not session._ui_rows or (notice ~= nil and
		(not previous_row or previous_row.id ~= row.id))
	local def = Q.registered_quests[row.id]
	local active = Q.active_entry(player, row.id)
	-- The giver's own text where it gives the quest, else the text of the
	-- variant and giver the player took it from (Round 57); at the turn-in
	-- the completion paragraph (ruling 14) in its place, when there is one.
	local at_giver = def.giver_variant[id] ~= nil and not active
	local source = active or {giver = def.giver_variant[id] and id or nil}
	local completion = row.status == "ready" and Q.completion_text(def, active)
	local detail = (completion or Q.quest_text(def, at_giver or (active and active.giver == id), source)) .. "\n\nOBJECTIVES\n"
	-- One line per objective (ruling 41), with its targets' level range
	-- (Lane Q0): "Defeat Barrow Piglet × 8 (level 1–2)".
	for _, objective in ipairs(Q.variant_of(def, source).objectives) do
		detail = detail .. (objective.description or Q.objective_action(objective)) ..
			" × " .. objective.count .. Q.objective_levels_text(objective) .. "\n"
	end
	local rewards = table.concat(Q.reward_lines(def, player), "\n")
	local choices = #def.rewards.choices > 0
	if not (row.status == "ready" and def.rewards.choices[picked or 0]) then picked = nil end
	-- At the turn-in the picked reward's whole tooltip (item level, stats,
	-- enchants) is readable without hovering, at the top of the text, where
	-- it needs no scrolling at the web client's size (Round 57 follow-up).
	local chosen = picked_lines(player, def, picked)
	if chosen then detail = "Chosen:\n" .. table.concat(chosen, "\n") .. "\n\n" .. detail end
	-- The description is a read-only text (no field name).
	local UI = grug_core.ui
	local scale = UI.text_scale(player)
	local form = UI.frame(18.8, 12.2, nil, nil, player) .. UI.service_header(18.8, npc.title or id,
		row.story and "STORY" or "QUESTS", "grug_ui_icon_map.png", scale) ..
		UI.panel(0.35, 1.6, 5.6, 9.3) .. UI.panel(6.15, 1.6, 12.3, 9.3) ..
		"style_type[textarea;border=false]" ..
		UI.button_style("accept", "selected", scale) .. UI.button_style("turnin", "selected", scale) ..
		UI.rows(session, {name = "quests", x = 0.5, y = 1.85, w = 5.25, h = 8.8,
			rows = entries, scale = scale, reveal_selected = reveal_selected}) ..
		UI.prose(6.5, 1.85, 11.55, 0.85, row.title, false, scale, 1.2 * scale) ..
		UI.prose(6.5, 2.9, 11.55, choices and 3.95 or 6.1, detail, false, scale, 1.05 * scale) ..
		("box[6.5,%.2f;11.55,0.02;#d1c09a2b]"):format(choices and 6.95 or 9.15) ..
		UI.prose(6.5, choices and 7.1 or 9.3, 11.55, choices and 1.2 or 1.25, rewards, false, scale) ..
		(choices and choice_row(player, def, row.status == "ready", picked) or "") ..
		UI.prose(3.0, 11.2, 10, 0.7, notice or row.reason or STATUS_NAMES[row.status][1], false, scale) ..
		"set_focus[close;true]button_exit[0.5,11.25;2.2,0.65;close;Close]"
	if row.status == "available" then form = form .. "button[15.9,11.25;2.2,0.65;accept;Accept]" end
	if row.status == "ready" then form = form .. "button[15.9,11.25;2.2,0.65;turnin;Complete]" end

	session.picked = picked
	sessions[name] = session
	if not redraw then grug_sounds.play("npc_quest", player) end
	core.show_formspec(player:get_player_name(), FORM, form)
	return true
end
core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORM then return end
	local name = player:get_player_name()
	local session = sessions[name]
	if fields.quit then sessions[name] = nil; return true end
	if not session or npc_id(session.entity) ~= session.npc or not in_reach(player, session.entity) or
			not grug_factions.serves(Q.registered_npcs[session.npc].faction, player) then
		sessions[name] = nil
		return true
	end
	local clicked = grug_core.ui.rows_event(session, "quests", fields)
	local index = clicked and session.row_of[clicked]
	if index and session.rows[index] then
		if index ~= session.selected then grug_sounds.play("quest_page", player) end
		Q.open_npc(player, session.entity, index, nil, index == session.selected and session.picked or nil)
		return true
	end
	local row = session.rows[session.selected]
	local def = row and Q.registered_quests[row.id]
	-- A click on a reward choice (Round 57): it is the picked one.
	for index in ipairs(def and def.rewards.choices or {}) do
		if fields["choice_" .. index] then
			if index ~= session.picked then grug_sounds.play("quest_page", player) end
			Q.open_npc(player, session.entity, session.selected, nil, index)
			return true
		end
	end
	local ok, message
	if fields.accept and def and def.giver_variant[session.npc] then
		ok, message = Q.accept(player, row.id, session.npc)
	elseif fields.turnin and def and Q.turns_in_at(player, row.id, session.npc) then
		ok, message = Q.turn_in(player, row.id, session.picked)
	end
	if ok ~= nil then
		-- After a Complete the dialog preselects again; after an Accept it
		-- preselects too and stays on the accepted quest only when nothing
		-- is ready or acceptable (the user, 2026-10-10); a failed Accept or
		-- Complete stays on that quest while it is listed here (a refused
		-- Complete keeps the chosen reward).
		local target = row.id
		if ok and fields.turnin then target = nil
		elseif ok then target = {after = row.id} end
		if not Q.open_npc(player, session.entity, target, message or "Quest updated.",
				not ok and session.picked or nil) then
			sessions[name] = nil
			core.close_formspec(name, FORM)
		end
	end
	return true
end)
core.register_on_leaveplayer(function(player) sessions[player:get_player_name()] = nil end)

-- Both authored OBJ meshes have y=-0.30..0.54. Mesh coordinates and
-- attachment translations use engine units (10 per node), and both inherit
-- the same parent mesh scale. 24.84 + 5*0.54 == 27 + 0.54 for every race.
local MARKER_SCALE = 5
local MARKER_Y = 27 - (MARKER_SCALE - 1) * 0.54
-- Marker value -> {symbol, colour} (Round 57 ruling 13: a story quest's
-- marker keeps the status's symbol and brightness in the story accent).
local MARKERS = {}
for _, status in ipairs({"ready", "available", "active", "locked"}) do
	local symbol = (status == "ready" or status == "active") and "question" or "exclamation"
	local bright = status == "ready" or status == "available"
	MARKERS[status] = {symbol = symbol, color = bright and "#ffd700" or "#c0c0c0"}
	MARKERS["story_" .. status] = {symbol = symbol, color = bright and "#b46bff" or "#a99bc4"}
end
core.register_entity("grug_quests:marker", {
	initial_properties = {physical = false, collide_with_objects = false, pointable = false,
		visual = "mesh", mesh = "grug_quests_question.obj",
		visual_size = {x = MARKER_SCALE, y = MARKER_SCALE, z = MARKER_SCALE}, textures = {"[fill:16x16:#ffd700"}, glow = 8,
		static_save = false, nametag = "", selectionbox = {0,0,0,0,0,0}},
	on_activate = function(self) self.object:set_observers({}) end,
})
local function clear_markers(parent)
	local children = markers[parent]
	if not children then return end
	for _, child in pairs(children) do if child:is_valid() then child:remove() end end
	markers[parent] = nil
end
-- Called each second for every observed tag carrier's parent, mobs included,
-- and once when a carrier's observer set changes (grug_core tag_carrier.lua):
-- a parent without a settlement socket (every mob) costs two field reads and
-- allocates nothing (Round 30, perf review #10). Socket NPCs without quests
-- (villagers, guards) still build their "start/socket" key on each call.
grug_core.register_tag_visibility(function(parent, observers, removed)
	if removed then clear_markers(parent); return end
	local id = npc_id(parent:get_luaentity())
	if not id then clear_markers(parent); return end
	-- Ruling 13 (Round 31): the other faction never sees a quest marker here.
	local faction, partitions = Q.registered_npcs[id].faction, {}
	for name in pairs(observers) do
		local player = core.get_player_by_name(name)
		local state = player and grug_factions.serves(faction, player) and
			Q.marker_states(player)[id]
		if state then partitions[state] = partitions[state] or {}; partitions[state][name] = true end
	end
	local children = markers[parent] or {}
	markers[parent] = children
	for state, look in pairs(MARKERS) do
		local child = children[state]
		if partitions[state] and (not child or not child:is_valid()) then
			child = core.add_entity(parent:get_pos(), "grug_quests:marker")
			if child then
				child:set_attach(parent, "", {x = 0, y = MARKER_Y, z = 0}, {x = 0, y = 0, z = 0})
				child:set_properties({mesh = "grug_quests_" .. look.symbol .. ".obj",
					textures = {"[fill:16x16:" .. look.color}})
				children[state] = child
			end
		end
		if child and child:is_valid() then child:set_observers(partitions[state] or {}) end
	end
end)
