-- Round 69 lane QUESTMAP engine probe (disposable, staged with PROBE=; never
-- shipped): the real target index and lookups of a booted world. For every
-- variant of every quest with a sourced item objective, seen with nothing
-- carried: its rings and crosshairs through the window's own quest_targets,
-- its quest log and tracker lines; then the same with the objectives
-- finished; and the item objectives without a source, none of which may mark.
-- Then the offer dialogue at the first giver of each of those variants (Round
-- 69 follow-up): the real form holds that variant's line with its levels.
-- Lines start "[r69qm]"; "RESULT ok" ends a clean run.
-- Run: PROBE=tools/r69_questmap/grug_probe_r69_questmap SEED=42 LC_ALL=C \
--      tools/luanti_headless.sh 300
local function log(text) core.log("action", "[r69qm] " .. text) end

local function rows_of(variant, finished)
	local rows = {}
	for k, o in ipairs(variant.objectives) do
		rows[k] = {type = o.type, item = o.item, group = o.group, mobs = o.mobs, names = o.names,
			npc = o.npc, count = finished and o.count or 0, required = o.count, levels = o.levels,
			label = o.label, place_name = o.place_name, source = o.source}
	end
	return rows
end

local player = {get_pos = function() return {x = 0, y = 10, z = 0} end}

-- The objective lines the giver's dialogue shows for `variant`, offered by its
-- first giver to a stand-in reader; the offer's rows and service gate stubbed
-- for the call. Returns the lines wrong in the form and the longest line.
local function offer_lines(Q, id, variant)
	local npc = variant.givers[1]
	local def, form = Q.registered_quests[id], nil
	local rows, serves, show = Q.npc_quests, grug_factions.serves, core.show_formspec
	Q.npc_quests = function() return {{id = id, title = def.title, status = "available", level = def.level}} end
	grug_factions.serves = function() return true end
	core.show_formspec = function(_, _, text) form = text end
	local meta = {get_string = function() return "" end, get_int = function() return 0 end}
	local reader = {get_player_name = function() return "r69_probe_reader" end,
		is_player = function() return true end, get_hp = function() return 20 end,
		get_pos = function() return {x = 0, y = 0, z = 0} end, get_meta = function() return meta end,
		get_inventory = function() return {get_list = function() return {} end, get_size = function() return 0 end,
			get_stack = function() return ItemStack("") end} end}
	Q.npc_by_socket["r69_probe/" .. npc] = npc
	local ok, err = pcall(Q.open_npc, reader, {_grug_start = "r69_probe", _grug_socket = npc, object = {
		is_valid = function() return true end, get_pos = function() return {x = 0, y = 0, z = 0} end}}, id)
	Q.npc_by_socket["r69_probe/" .. npc] = nil
	Q.npc_quests, grug_factions.serves, core.show_formspec = rows, serves, show
	if not ok then return 1, tostring(err) end
	local wrong, longest = 0, ""
	for _, o in ipairs(variant.objectives) do
		local line = Q.objective_action(o) .. " \195\151 " .. o.count ..
			(o.source and " (from " .. o.source .. ")" or "") .. Q.objective_levels_text(o)
		if #line > #longest then longest = line end
		if not (form or ""):find("\n" .. core.formspec_escape(line) .. "\n", 1, true) then wrong = wrong + 1 end
	end
	return wrong, longest
end

local function run()
	local Q, W = grug_quests, grug_map.window
	local box = dofile(core.get_modpath("grug_map") .. "/quest_box.lua")
	local targets = dofile(core.get_modpath("grug_map") .. "/targets.lua")
	local index, lookup = grug_map.quest_targets.index(), W.target_lookup
	local ids = {}
	for id in pairs(Q.registered_quests) do ids[#ids + 1] = id end
	table.sort(ids)
	local quests, variants, missing, left, plain, plain_marked = 0, 0, 0, 0, 0, 0
	local offers_wrong, widest = 0, ""
	for _, id in ipairs(ids) do
		local def = Q.registered_quests[id]
		local counted = false
		for _, key in ipairs(def.variant_order) do
			local variant = def.variant_by_key[key]
			local sourced = false
			for _, o in ipairs(variant.objectives) do
				if o.type == "item" then
					if o.sources then
						sourced = true
					else
						plain = plain + 1
						local found = targets.targets(index, {objectives = {o}, zone = variant.zone}, nil,
							{x = 0, z = 0}, lookup)
						if #found.crosshairs + #found.rings > 0 then plain_marked = plain_marked + 1 end
					end
				end
			end
			if sourced then
				if not counted then quests, counted = quests + 1, true end
				variants = variants + 1
				local rows = rows_of(variant)
				local found = W.quest_targets(player, {id = id, variant = key, objectives = rows})
				local marks = #found.crosshairs + #found.rings
				if marks == 0 then missing = missing + 1 end
				local gone = W.quest_targets(player, {id = id, variant = key, objectives = rows_of(variant, true)})
				left = left + #gone.crosshairs + #gone.rings
				local lines = {}
				for k, row in ipairs(rows) do lines[k] = box.objective_label(row) end
				log(("%s/%s: %d crosshairs, %d rings | %s | HUD %s"):format(id, key, #found.crosshairs,
					#found.rings, table.concat(lines, " + "), Q.hud_line({objectives = rows}, 38)))
				local wrong, line = offer_lines(Q, id, variant)
				offers_wrong = offers_wrong + wrong
				if #line > #widest then widest = line end
				log(("offer %s/%s: %s, %d wrong"):format(id, key, line, wrong))
			end
		end
	end
	log(("quests %d, variants %d, without a target %d, marks left when finished %d; " ..
		"plain item objectives %d, marked %d"):format(quests, variants, missing, left, plain, plain_marked))
	log(("offers: %d lines wrong, widest %d bytes: %s"):format(offers_wrong, #widest, widest))
	log((quests == 14 and missing == 0 and left == 0 and plain_marked == 0 and offers_wrong == 0) and
		"RESULT ok" or "RESULT FAILED")
end

local clock, done = 0, false
core.register_globalstep(function(dtime)
	if done then return end
	clock = clock + dtime
	if clock < 2 then return end
	done = true
	local ok, err = pcall(run)
	if not ok then log("RESULT FAILED: " .. tostring(err)) end
	core.request_shutdown("r69 questmap probe done", false, 0)
end)
