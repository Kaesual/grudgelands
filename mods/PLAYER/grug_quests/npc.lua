local Q = grug_quests
local sessions, markers = {}, {}
local FORM = "grug_quests:dialogue"
local function npc_id(entity)
	if not entity or not entity.object or not entity.object:is_valid() then return nil end
	if not entity._grug_start or not entity._grug_socket then return nil end
	return Q.npc_by_socket[entity._grug_start .. "/" .. entity._grug_socket]
end
local function in_reach(player, entity)
	if not player or not player:is_player() or player:get_hp() <= 0 then return false end
	local pos = entity.object:get_pos()
	local pp = player:get_pos()
	return pos and pp and vector.distance(pos, pp) <= 6
end
local priority = {ready = 1, available = 2, active = 3, locked = 4}
function Q.marker_state(player, id)
	local best
	for _, row in ipairs(Q.npc_quests(player, id)) do
		if not best or priority[row.status] < priority[best] then best = row.status end
	end
	return best
end
function Q.open_npc(player, entity, selected, notice)
	local id = npc_id(entity)
	if not id or not in_reach(player, entity) then return false end
	Q.credit_conversation(player, id)
	local rows = Q.npc_quests(player, id)
	if #rows == 0 then return false end
	local esc, entries = core.formspec_escape, {}
	for _, row in ipairs(rows) do entries[#entries + 1] = esc(row.title .. " (" .. row.status .. ")") end
	selected = math.min(math.max(tonumber(selected) or 1, 1), #rows)
	local row = rows[selected]
	local def = Q.registered_quests[row.id]
	local detail = def.description .. "\n\n"
	for _, objective in ipairs(def.objectives) do
		local mob_names = {}
		for _, name in ipairs(objective.mobs or {}) do
			local registered = core.registered_entities[name] or {}
			mob_names[#mob_names + 1] = registered.description or name
		end
		local subject = objective.description
		if not subject then
			if objective.type == "item" then
				subject = "Bring " .. (core.registered_items[objective.item].description or objective.item)
			elseif objective.type == "talk" then
				local destination = Q.registered_npcs[objective.npc]
				subject = "Speak with " .. (destination and destination.title or objective.npc)
			else subject = "Defeat " .. table.concat(mob_names, ", ") end
		end
		detail = detail .. subject .. " × " .. objective.count .. "\n"
	end
	detail = detail .. "\nRewards: " .. def.rewards.xp .. " XP, " .. grug_money.format(def.rewards.copper)
	for _, item in ipairs(def.rewards.items) do
		local stack = ItemStack(item)
		detail = detail .. "\n" .. (stack:get_description()) .. " × " .. stack:get_count()
	end
	local form = "formspec_version[6]size[12,9]label[0.4,0.4;" .. esc(Q.registered_npcs[id].title or id) .. "]" ..
		"textlist[0.4,0.9;4,6;quests;" .. table.concat(entries, ",") .. ";" .. selected .. ";false]" ..
		"textarea[4.7,0.9;6.8,6.4;description;;" .. esc(detail) .. "]" ..
		"label[0.4,7.4;" .. esc(notice or row.reason or "") .. "]button_exit[9.2,8;2.3,0.7;close;Close]"
	if row.status == "available" then form = form .. "button[4.7,8;2,0.7;accept;Accept]" end
	if row.status == "ready" then form = form .. "button[4.7,8;2,0.7;turnin;Complete]" end
	sessions[player:get_player_name()] = {entity = entity, npc = id, rows = rows, selected = selected}
	core.show_formspec(player:get_player_name(), FORM, form)
	return true
end
core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORM then return end
	local name = player:get_player_name()
	local session = sessions[name]
	if fields.quit then sessions[name] = nil; return true end
	if not session or npc_id(session.entity) ~= session.npc or not in_reach(player, session.entity) then
		sessions[name] = nil
		return true
	end
	if fields.quests then
		local event = core.explode_textlist_event(fields.quests)
		if event.index and session.rows[event.index] then Q.open_npc(player, session.entity, event.index) end
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
	for _, child in pairs(markers[parent] or {}) do if child:is_valid() then child:remove() end end
	markers[parent] = nil
end
grug_core.register_tag_visibility(function(parent, observers, removed)
	if removed then clear_markers(parent); return end
	local id = npc_id(parent:get_luaentity())
	if not id then clear_markers(parent); return end
	local partitions = {}
	for name in pairs(observers) do
		local player = core.get_player_by_name(name)
		local state = player and Q.marker_state(player, id)
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
