-- Disposable engine probe (Round 44 lane MQ), never shipped. Staged through
--   PROBE=tools/r44_mq/grug_probe_r44_mq SEED=42 tools/luanti_headless.sh 300
-- Two seconds after the server runs it logs, then shuts the server down, for
-- a stand-in viewer of each faction at its start town (a fake ObjectRef
-- with only the methods the pages read) holding seven active quests of its
-- faction (the lowest levels):
--   * before Round 44 MQ (no grug_map.window): the Map tab's formspec bytes
--     at zoom 1x and 8x and the Quests tab's bytes;
--   * after: the map window's bytes at zoom 1x and 8x, at the fallback size
--     and at 85 % of a 1920x1080 screen at GUI scale 1, with no quest
--     selected and with the first kill quest selected, its element counts
--     and drawn targets, and the quest target index's size and build time;
--   * Round 47 (lane ML, grug_map.layers present): the same per marker
--     layer and in quest mode (the first kill quest), with the drawn
--     markers and tooltips; the layers' static rows and the zone labels'
--     placement figures; and how many quest texts overflow the quest text
--     box at 1920x1080 and 1280x720 (an estimate: the text's words wrapped
--     at 0.5 em per character of the default 16 px font, 1.2 em per line).
local P = "[r44mq_probe] "
local function log(text) core.log("action", P .. text) end

local function fake_player(name, faction, pos, quest_state)
	local store = {["grug_factions:faction"] = faction,
		["grug_quests:state"] = core.serialize(quest_state)}
	local meta = {}
	function meta:get_string(key) return store[key] or "" end
	function meta:get_int(key) return tonumber(store[key]) or 0 end
	function meta:get_float(key) return tonumber(store[key]) or 0 end
	function meta:set_string(key, value) store[key] = value ~= "" and value or nil end
	function meta:set_int(key, value) store[key] = tostring(value) end
	function meta:set_float(key, value) store[key] = tostring(value) end
	function meta:contains(key) return store[key] ~= nil end
	function meta:to_table() return {fields = store} end
	local inv = core.create_detached_inventory("r44mq_" .. name, {}, name)
	inv:set_size("main", 32)
	local p = {}
	local M = {}
	function M:is_player() return true end
	function M:is_valid() return true end
	function M:get_player_name() return name end
	function M:get_pos() return vector.copy(pos) end
	function M:get_look_horizontal() return 0 end
	function M:get_meta() return meta end
	function M:get_inventory() return inv end
	function M:get_wield_index() return 1 end
	setmetatable(p, {__index = function(_, key)
		if M[key] then return M[key] end
		return function() return nil end
	end})
	return p
end

local function count(form, pattern)
	local n = 0
	for _ in form:gmatch(pattern) do n = n + 1 end
	return n
end

local function elements(form)
	return ("image_button %d, button %d, image %d, tooltip %d, style %d, textlist %d, " ..
		"label %d, box %d"):format(
		count(form, "image_button%["), count(form, "[^_]button%["),
		count(form, "[^_]image%["), count(form, "tooltip%["), count(form, "style%["),
		count(form, "textlist%["), count(form, "label%["), count(form, "box%["))
end

-- The seven lowest-level quests whose giver is of `faction` (id order on a
-- tie), as a quest state; and the first of them with a kill objective.
local function quest_state(faction)
	local rows = {}
	for id, def in pairs(grug_quests.registered_quests) do
		local npc = grug_quests.registered_npcs[def.npc]
		if npc and npc.faction == faction and #def.prerequisites == 0 then
			rows[#rows + 1] = {id = id, level = def.level}
		end
	end
	table.sort(rows, function(a, b)
		if a.level ~= b.level then return a.level < b.level end
		return a.id < b.id
	end)
	local active, tracked, kill = {}, {}, nil
	for index = 1, math.min(7, #rows) do
		local id = rows[index].id
		active[id] = {}
		tracked[#tracked + 1] = id
		for _, objective in ipairs(grug_quests.registered_quests[id].objectives) do
			if objective.type == "kill" and not kill then kill = id end
		end
	end
	return {active = active, completed = {}, tracked = tracked, hud = true, cooldowns = {}}, kill
end

local function start_of(faction)
	for _, identity in ipairs(grug_core.start_identities()) do
		if identity.faction_id == faction then return identity.anchor end
	end
	return {x = 0, y = 20, z = 0}
end

local function before(faction)
	local state = quest_state(faction)
	local name = "r44mq_" .. faction
	local player = fake_player(name, faction, start_of(faction), state)
	local context = {page = "grug_map:atlas"}
	sfinv.contexts[name] = context
	local page = sfinv.pages["grug_map:atlas"]
	page:on_enter(player, context)
	for _, zoom in ipairs({1, 8}) do
		context.grug_map_zoom = zoom
		local form = sfinv.get_formspec(player, context)
		log(("before %s map tab zoom %dx: %d bytes (%s)"):format(faction, zoom, #form,
			elements(form)))
	end
	page:on_leave(player, context)
	context.page = "grug_quests:quests"
	local form = sfinv.get_formspec(player, context)
	log(("before %s quests tab (7 active): %d bytes"):format(faction, #form))
	sfinv.contexts[name] = nil
end

local SIZES = {{"fallback", nil},
	{"1920x1080", {size = {x = 1920, y = 1080}, max_formspec_size = {x = 1920 / 72, y = 1080 / 72},
		real_gui_scaling = 1}}}

-- Round 47: every layer and quest mode.
local function layers_after(faction)
	local W = grug_map.window
	local state, kill = quest_state(faction)
	local name = "r44mq_" .. faction
	local player = fake_player(name, faction, start_of(faction), state)
	local modes = {}
	for _, layer in ipairs(grug_map.layers.LIST) do modes[#modes + 1] = {layer.id, nil} end
	modes[#modes + 1] = {"quest", kill}
	for _, size in ipairs(SIZES) do
		for _, mode in ipairs(modes) do
			for _, zoom in ipairs({1, 8}) do
				local view = W.new_state()
				view.zoom = zoom
				view.layer = mode[2] and "quests" or mode[1]
				view.quest_selected = mode[2]
				local form = W.formspec(player, view, size[2])
				log(("layers %s %s (%.2fx%.2f, %d button rows) %s zoom %dx: %d bytes (%s; " ..
					"markers %d, targets %d, map tooltips %d)"):format(faction, size[1], view.layout.w,
					view.layout.h, view.layout.buttons.rows, mode[2] and ("quest " .. mode[2]) or mode[1],
					zoom, #form, elements(form), view.marker_count or 0, view.target_count or 0,
					view.tooltip_count or 0))
			end
		end
	end
end

local function layer_rows()
	local L = grug_map.layers
	local counts = {}
	for _, name in ipairs({"settlement", "boss", "poi", "pvp"}) do
		local kinds = {}
		for _, row in ipairs(L.rows[name]) do kinds[row.kind] = (kinds[row.kind] or 0) + 1 end
		local parts = {}
		for kind, n in pairs(kinds) do parts[#parts + 1] = kind .. " " .. n end
		table.sort(parts)
		counts[#counts + 1] = ("%s %d (%s)"):format(name, #L.rows[name], table.concat(parts, ", "))
	end
	log("layer rows: " .. table.concat(counts, "; "))
	local s = L.zone_stats or {}
	log(("zone labels: %d placed, at 1x on 1920x1080 %d overlapping pairs, %d over a region " ..
		"name; grid %.3f s, total %.3f s"):format(s.zones or 0, s.overlapping or 0, s.on_names or 0,
		s.grid_s or 0, s.total_s or 0))
	for _, zone in ipairs(L.zones) do
		log(("zone label %s at %d,%d: %s / %s"):format(zone.id, zone.x, zone.z, zone.name, zone.band))
	end
	for _, name in ipairs({"boss", "pvp"}) do
		for _, row in ipairs(L.rows[name]) do
			log(("row %s %s: %s"):format(name, row.kind, (row.detail or row.label):gsub("\n", " / ")))
		end
	end
end

-- Round 47 §6.1: how many quest texts scroll in the quest text box. The text
-- is quest_box.lua's own (every quest active on one stand-in, each selected
-- in turn); the wrap is estimated.
local function overflow()
	local W = grug_map.window
	local quest_box = dofile(core.get_modpath("grug_map") .. "/quest_box.lua")
	local active = {}
	for id in pairs(grug_quests.registered_quests) do active[id] = {} end
	local player = fake_player("r44mq_text", "accord", {x = 0, y = 10, z = 0},
		{active = active, completed = {}, tracked = {}, hud = true, cooldowns = {}})
	local journal = grug_quests.journal(player)
	local screens = {{"1920x1080", 1920, 1080, 72}, {"1280x720", 1280, 720, 0.5555 * 96}}
	for _, screen in ipairs(screens) do
		local info = {size = {x = screen[2], y = screen[3]},
			max_formspec_size = {x = screen[2] / screen[4], y = screen[3] / screen[4]}}
		local layout = W.layout(W.window_size(info))
		local px = screen[4]
		local scrolling, longest, total = 0, 0, 0
		for _, quest in ipairs(journal.quests) do
			local form = quest_box.content({quest_selected = quest.id}, journal, layout.column)
			local w, h, text = form:match("textarea%[[%d.]+,[%d.]+;([%d.]+),([%d.]+);;;(.-)%]$")
			if not w then w, h, text = form:match("textarea%[[%d.]+,[%d.]+;([%d.]+),([%d.]+);;;(.-)%]label") end
			if w then
				text = text:gsub("\\(.)", "%1")
				local per_line = math.floor(tonumber(w) * px / (16 * 0.5))
				local lines = 0
				for paragraph in (text .. "\n"):gmatch("(.-)\n") do
					local line = 0
					lines = lines + 1
					for word in paragraph:gmatch("%S+") do
						local len = #word:gsub("[\128-\191]", "")
						if line > 0 and line + 1 + len > per_line then
							lines, line = lines + 1, len
						else
							line = line + (line > 0 and 1 or 0) + len
						end
					end
				end
				local visible = math.floor(tonumber(h) * px / (16 * 1.2))
				total = total + 1
				if lines > visible then scrolling = scrolling + 1 end
				if lines > longest then longest = lines end
				if total == 1 then
					log(("quest text box %s: %.2fx%.2f units, about %d characters x %d lines"):format(
						screen[1], tonumber(w), tonumber(h), per_line, visible))
				end
			end
		end
		log(("quest texts %s: %d of %d overflow the text box (longest about %d lines)"):format(
			screen[1], scrolling, total, longest))
	end
end

local function after(faction)
	local W = grug_map.window
	local state, kill = quest_state(faction)
	local name = "r44mq_" .. faction
	local player = fake_player(name, faction, start_of(faction), state)
	local sizes = SIZES
	for _, size in ipairs(sizes) do
		for _, selected in ipairs({false, true}) do
			for _, zoom in ipairs({1, 8}) do
				local view = W.new_state()
				view.zoom = zoom
				view.quest_selected = selected and kill or nil
				local form = W.formspec(player, view, size[2])
				log(("after %s window %s (%.2fx%.2f) zoom %dx, %s: %d bytes (%s; targets %d)"):format(
					faction, size[1], view.layout.w, view.layout.h, zoom,
					"selected " .. tostring(view.quest_selected), #form, elements(form),
					view.target_count or 0))
			end
		end
	end
end

-- Every objective of every quest alone, all open, seen from (0, 0): how
-- many the targets mark, by type, and some kill roles that stay unmarked.
local function coverage()
	local targets = dofile(core.get_modpath("grug_map") .. "/targets.lua")
	local index = grug_map.quest_targets.index()
	local lookup = grug_map.window.target_lookup
	local rows = {kill = {0, 0, 0}, talk = {0, 0, 0}, use = {0, 0, 0}, item = {0, 0, 0}}
	local unmarked, seen = {}, {}
	local ids = {}
	for id in pairs(grug_quests.registered_quests) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local def = grug_quests.registered_quests[id]
		for _, objective in ipairs(def.objectives) do
			local one = {zone = def.zone, objectives = {objective}}
			local found = targets.targets(index, one, nil, {x = 0, z = 0}, lookup)
			local row = rows[objective.type]
			row[1] = row[1] + 1
			if #found.crosshairs > 0 then row[2] = row[2] + 1 end
			if #found.rings > 0 then row[3] = row[3] + 1 end
			if objective.type == "kill" and #found.crosshairs == 0 and #found.rings == 0 then
				local key = table.concat(objective.mobs or {}, "+") .. (objective.area and
					(" @" .. objective.area) or (" in " .. tostring(def.zone)))
				if not seen[key] then
					seen[key] = true
					unmarked[#unmarked + 1] = key
				end
			end
		end
	end
	for _, kind in ipairs({"kill", "talk", "use", "item"}) do
		local row = rows[kind]
		log(("coverage %s objectives: %d, with a crosshair %d, with rings %d"):format(kind,
			row[1], row[2], row[3]))
	end
	log(("unmarked kill objectives (%d distinct): %s"):format(#unmarked,
		table.concat(unmarked, "; ")))
end

local clock, done = 0, false
core.register_globalstep(function(dtime)
	if done then return end
	clock = clock + dtime
	if clock < 2 then return end
	done = true
	local ok, err = pcall(function()
		for _, faction in ipairs(grug_core.faction_ids) do
			if grug_map.layers then
				layers_after(faction)
			elseif grug_map.window then
				after(faction)
			else
				before(faction)
			end
		end
		if grug_map.layers then
			layer_rows()
			overflow()
		end
		if grug_map.window then coverage() end
		if grug_map.quest_targets then
			local stats = grug_map.quest_targets.stats()
			log(("target index: %d roles, %d region entries, %d areas, %d leaders, " ..
				"built in %.1f ms"):format(stats.roles, stats.entries, stats.areas,
				stats.leaders, stats.ms))
		end
	end)
	if not ok then log("failed: " .. tostring(err)) end
	log("done")
	core.request_shutdown("r44 mq probe done", false, 0)
end)
