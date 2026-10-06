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
-- that cut the title off; a repeatable quest ends in a short "(R)". The quest
-- giver's dialog and the quest log share the colours and the legend.
Q.STATUS_COLORS = {available = "#ffd24a", ready = "#7ee06a", active = "#8fc1ff", locked = "#9a9a9a"}
local STATUS_ORDER = {"available", "ready", "active", "locked"}
local STATUS_NAMES = {available = {"Available", "gold"}, ready = {"Ready to complete", "green"},
	active = {"In progress", "blue"}, locked = {"Locked", "grey"}}
function Q.list_entry(title, status, repeatable)
	return Q.STATUS_COLORS[status] .. core.formspec_escape(title .. (repeatable and " (R)" or ""))
end
-- The legend as one coloured line, and as the list's tooltip (escaped).
function Q.status_legend(statuses)
	local parts = {}
	for _, status in ipairs(statuses or STATUS_ORDER) do
		parts[#parts + 1] = core.colorize(Q.STATUS_COLORS[status], STATUS_NAMES[status][1])
	end
	return core.formspec_escape(table.concat(parts, "   ") .. "   (R) Repeatable")
end
function Q.status_tooltip(statuses)
	local lines = {}
	for _, status in ipairs(statuses or STATUS_ORDER) do
		lines[#lines + 1] = STATUS_NAMES[status][1] .. ": " .. STATUS_NAMES[status][2]
	end
	lines[#lines + 1] = "(R): repeatable"
	return core.formspec_escape(table.concat(lines, "\n"))
end

-- The dialog is wide enough for the longest quest title in the list at a
-- full-HD window (the title column is 7 of 16 units).
function Q.open_npc(player, entity, selected, notice)
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
	local esc, entries = core.formspec_escape, {}
	for _, row in ipairs(rows) do
		entries[#entries + 1] = Q.list_entry(row.title, row.status, row.repeatable)
	end
	-- The first open of the dialog plays its cue; a redraw (another quest
	-- chosen, after Accept or Complete) does not.
	local redraw = selected ~= nil
	selected = math.min(math.max(tonumber(selected) or 1, 1), #rows)
	local row = rows[selected]
	local def = Q.registered_quests[row.id]
	local detail = Q.quest_text(def, id == def.npc) .. "\n\n"
	if def.repeatable then
		detail = detail .. ("Repeatable (every %s)\n"):format(Q.cooldown_text(def.repeatable.cooldown))
	end
	-- One line per objective (ruling 41), with its targets' level range
	-- (Lane Q0): "Defeat Barrow Piglet × 8 (level 1–2)".
	for _, objective in ipairs(def.objectives) do
		detail = detail .. (objective.description or Q.objective_action(objective)) ..
			" × " .. objective.count .. Q.objective_levels_text(objective) .. "\n"
	end
	detail = detail .. "\nRewards: " .. Q.reward_xp(def) .. " XP, " .. grug_money.format(def.rewards.copper)
	for _, item in ipairs(def.rewards.items) do
		local stack = ItemStack(item)
		detail = detail .. "\n" .. grug_core.item_name(stack) .. " × " .. stack:get_count()
	end
	-- The description is a read-only text (no field name).
	local form = "formspec_version[6]size[16,9.4]label[0.4,0.4;" .. esc(npc.title or id) .. "]" ..
		"textlist[0.4,0.9;7,6;quests;" .. table.concat(entries, ",") .. ";" .. selected .. ";false]" ..
		"tooltip[quests;" .. Q.status_tooltip() .. "]" ..
		"label[0.4,7.3;" .. Q.status_legend() .. "]" ..
		"textarea[7.8,0.9;7.8,6;;;" .. esc(detail) .. "]" ..
		"label[0.4,7.9;" .. esc(notice or row.reason or "") .. "]button_exit[13.3,8.4;2.3,0.7;close;Close]"
	if row.status == "available" then form = form .. "button[7.8,8.4;2,0.7;accept;Accept]" end
	if row.status == "ready" then form = form .. "button[7.8,8.4;2,0.7;turnin;Complete]" end
	sessions[player:get_player_name()] = {entity = entity, npc = id, rows = rows, selected = selected}
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
	if fields.quests then
		local event = core.explode_textlist_event(fields.quests)
		if event.index and session.rows[event.index] then
			if event.index ~= session.selected then grug_sounds.play("quest_page", player) end
			Q.open_npc(player, session.entity, event.index)
		end
		return true
	end
	local row = session.rows[session.selected]
	local def = row and Q.registered_quests[row.id]
	local ok, message
	if fields.accept and def and def.npc == session.npc then ok, message = Q.accept(player, row.id)
	elseif fields.turnin and def and def.turnin_npc == session.npc then ok, message = Q.turn_in(player, row.id) end
	if ok ~= nil then
		sessions[name] = nil
		if not Q.open_npc(player, session.entity, session.selected, message or "Quest updated.") then
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
local symbols = {ready = "question", available = "exclamation", active = "question", locked = "exclamation"}
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
	for state, symbol in pairs(symbols) do
		local child = children[state]
		if partitions[state] and (not child or not child:is_valid()) then
			child = core.add_entity(parent:get_pos(), "grug_quests:marker")
			if child then
				child:set_attach(parent, "", {x = 0, y = MARKER_Y, z = 0}, {x = 0, y = 0, z = 0})
				child:set_properties({mesh = "grug_quests_" .. symbol .. ".obj", textures = {
					(state == "ready" or state == "available") and "[fill:16x16:#ffd700" or "[fill:16x16:#c0c0c0"}})
				children[state] = child
			end
		end
		if child and child:is_valid() then child:set_observers(partitions[state] or {}) end
	end
end)
