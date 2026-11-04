-- Round 69 lane QUESTMAP engine probe (disposable, staged with PROBE=; never
-- shipped): the real target index and lookups of a booted world. For every
-- variant of every quest with a sourced item objective, seen with nothing
-- carried: its rings and crosshairs through the window's own quest_targets,
-- its quest log and tracker lines; then the same with the objectives
-- finished; and the item objectives without a source, none of which may mark.
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

local function run()
	local Q, W = grug_quests, grug_map.window
	local box = dofile(core.get_modpath("grug_map") .. "/quest_box.lua")
	local targets = dofile(core.get_modpath("grug_map") .. "/targets.lua")
	local index, lookup = grug_map.quest_targets.index(), W.target_lookup
	local ids = {}
	for id in pairs(Q.registered_quests) do ids[#ids + 1] = id end
	table.sort(ids)
	local quests, variants, missing, left, plain, plain_marked = 0, 0, 0, 0, 0, 0
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
			end
		end
	end
	log(("quests %d, variants %d, without a target %d, marks left when finished %d; " ..
		"plain item objectives %d, marked %d"):format(quests, variants, missing, left, plain, plain_marked))
	log((quests == 14 and missing == 0 and left == 0 and plain_marked == 0) and "RESULT ok" or "RESULT FAILED")
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
