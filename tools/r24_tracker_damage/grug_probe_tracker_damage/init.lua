-- Disposable engine probe (Round 24 Lane E). Never shipped:
-- tools/r24_tracker_damage/run.sh stages it through tools/luanti_headless.sh.
--
-- The engine runs player hp-change modifiers only for real players, and a
-- headless server has none, so the probe calls the registered modifiers in
-- builtin's own order (last registered first) with a player stand-in.

local P = "[tracker_damage_probe] "
local failures, checks = 0, 0
local function log(msg) core.log("action", P .. msg) end
local function check(ok, msg)
	checks = checks + 1
	if ok then
		log("ok   " .. msg)
	else
		failures = failures + 1
		core.log("error", P .. "FAIL " .. msg)
	end
end

local function stand_in(hp_max)
	local p = {}
	function p:get_player_name() return "probe_" .. hp_max end
	function p:get_properties() return {hp_max = hp_max} end
	function p:get_pos() return vector.new(0, 0, 0) end
	function p:is_player() return true end
	function p:get_hp() return hp_max end
	-- No race or class stored: the Dwarf fall perk does not apply.
	function p:get_meta()
		return {get_string = function() return "" end, get_int = function() return 0 end}
	end
	return p
end

local function modified(player, change, reason)
	local modifiers = core.registered_on_player_hpchanges.modifiers
	for i = #modifiers, 1, -1 do
		local last
		change, last = modifiers[i](player, change, reason)
		if last then break end
	end
	return change
end

local function run()
	log("modifiers registered: " .. #core.registered_on_player_hpchanges.modifiers)
	local damaging = {}
	for name, def in pairs(core.registered_nodes) do
		if (def.damage_per_second or 0) > 0 then
			damaging[#damaging + 1] = ("%s dps=%d lava=%d"):format(name,
				def.damage_per_second, core.get_item_group(name, "lava"))
		end
	end
	table.sort(damaging)
	log("damaging nodes: " .. table.concat(damaging, ", "))
	for _, hp_max in ipairs({20, 100, 325, 1234}) do
		local player = stand_in(hp_max)
		for _, node in ipairs({"default:lava_source", "default:lava_flowing"}) do
			local def = core.registered_nodes[node]
			local got = modified(player, -def.damage_per_second,
				{type = "node_damage", from = "engine", node = node,
					node_pos = vector.new(0, 0, 0)})
			check(got == -math.ceil(hp_max * 20 / 100),
				("%s at hp_max %d: %d"):format(node, hp_max, got))
		end
		local water = core.registered_nodes["default:water_source"]
		check(modified(player, -water.drowning, {type = "drown", from = "engine",
			node = "default:water_source"}) == 0,
			"engine drown tick cancelled at hp_max " .. hp_max)
		local drown = grug_core.drowning_damage(hp_max)
		check(drown == math.ceil(hp_max * 10 / 100), "drowning share at " .. hp_max)
		check(modified(player, -drown, {type = "drown", from = "mod",
			custom_type = grug_core.DROWNING_CUSTOM_TYPE}) == -drown,
			"mod drowning passes at hp_max " .. hp_max)
		-- Shield on the stand-in: lava/drowning/fall leave it untouched.
		grug_core.add_absorb(player, "probe", 50, 60, player)
		modified(player, -8, {type = "node_damage", from = "engine",
			node = "default:lava_source"})
		modified(player, -drown, {type = "drown", from = "mod",
			custom_type = grug_core.DROWNING_CUSTOM_TYPE})
		modified(player, -3, {type = "fall", from = "engine"})
		check(grug_core.get_absorb(player) == math.min(50, hp_max),
			"shield untouched at hp_max " .. hp_max)
	end

	-- Tracker lines from the real registry.
	local Q = grug_quests
	check(Q.MAX_TRACKED == 10, "tracker cap 10")
	local ids = {}
	for id in pairs(Q.registered_quests) do ids[#ids + 1] = id end
	table.sort(ids)
	local shown = 0
	for _, id in ipairs(ids) do
		local def = Q.registered_quests[id]
		local objectives = {}
		for index, objective in ipairs(def.objectives) do
			objectives[index] = {type = objective.type, item = objective.item,
				mobs = objective.mobs, npc = objective.npc, count = 0,
				required = objective.count, description = objective.description}
		end
		local line = Q.hud_line({ready = false, objectives = objectives}, 38)
		local ready = Q.hud_line({ready = true, npc = def.turnin_npc, objectives = objectives}, 38)
		check(#line <= 38 and not line:find("\n", 1, true) and
			not line:find("\27", 1, true) and
			not line:find(def.title, 1, true), "line " .. id .. ": " .. line)
		check(ready == ("Return to " .. Q.registered_npcs[def.turnin_npc].title):sub(1, #ready) and
			#ready <= 38, "ready " .. id .. ": " .. ready)
		shown = shown + 1
		if shown >= 12 then break end
	end
	log(("RESULT %s (%d checks, %d failures)"):format(failures == 0 and "PASS" or "FAIL",
		checks, failures))
	core.request_shutdown("probe done", false, 0)
end

core.register_on_mods_loaded(function() core.after(1, run) end)
