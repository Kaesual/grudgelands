-- Round 24 Lane A engine probe (disposable, never shipped).
--
-- 1. Dig matrix through the engine's own core.get_dig_params for every ladder
--    pick/shovel/axe, the starters and the hand against tier rock, resources,
--    decorative rock and loose ground; logged as one table.
-- 2. Generated tier rock: emerges one mapblock in each of three tier bands
--    and counts the tier stones there.
-- 3. The mining transaction and punch hints with probe diggers (protection
--    bypassed for the probe name only) and one refused real core.node_dig.
-- 4. Protection reasons at a start town, in both home territories and in the
--    contested deep, through grug_core.protection_reason.
-- Ends the server itself; "RESULT PASS" is the verdict line.

local PREFIX = "[r24_mining_probe] "
local checks, failures = 0, 0

local function log(message)
	core.log("action", PREFIX .. message)
end

local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		core.log("error", PREFIX .. "FAIL " .. label)
	end
	return ok
end

local function dig(node_name, caps)
	local def = core.registered_nodes[node_name]
	return core.get_dig_params(def and def.groups or {}, caps)
end

local function caps_of(name)
	return ItemStack(name):get_tool_capabilities()
end

local function ladder(family, tier)
	local key = grug_materials.TIERS[tier].key
	return "grug_materials:" ..
		family .. "_" .. key
end

-- 1. Dig matrix -------------------------------------------------------------

local COLUMNS = {
	{"T1", "default:stone", 1}, {"T2", "grug_materials:t2_stone", 2},
	{"T3", "grug_materials:t3_stone", 3}, {"T4", "grug_materials:t4_stone", 4},
	{"T5", "grug_materials:t5_stone", 5}, {"T6", "grug_materials:t6_stone", 6},
	{"coal", "default:stone_with_coal", 1}, {"iron", "default:stone_with_iron", 1},
	{"gold", "default:stone_with_gold", 2},
	{"silver", "grug_materials:stone_with_silver", 3},
	{"ruby", "grug_materials:stone_with_ruby", 4},
	{"abyss", "grug_materials:abyssal_crystal_ore", 5},
	{"slate", "grug_materials:slate", 0}, {"basalt", "grug_materials:basalt", 0},
	{"granite", "grug_materials:granite", 0},
	{"dirt", "default:dirt", 0}, {"gravel", "default:gravel", 0},
	{"sand", "default:sand", 0}, {"snow", "default:snowblock", 0},
	{"clay", "default:clay", 0}, {"mud", "grug_nodes:mud", 0},
	{"mesa", "grug_nodes:mesa_clay", 0}, {"ash", "grug_nodes:ash_ground", 0},
	{"tree", "default:tree", 0},
}

local function matrix()
	local rows = {{"hand", "", 0, "hand"}, {"pick_wood", "grug_materials:pick_wood", 1, "pick"},
		{"pick_stone", "grug_materials:pick_stone", 1, "pick"}}
	for tier = 1, 6 do
		rows[#rows + 1] = {"pick T" .. tier, ladder("pick", tier), tier, "pick"}
	end
	rows[#rows + 1] = {"shovel_wood", "grug_materials:shovel_wood", 1, "shovel"}
	for tier = 1, 6 do
		rows[#rows + 1] = {"shovel T" .. tier, ladder("shovel", tier), tier, "shovel"}
	end
	for tier = 1, 6 do
		rows[#rows + 1] = {"axe T" .. tier, ladder("axe", tier), tier, "axe"}
	end
	local header = {"tool         "}
	for _, column in ipairs(COLUMNS) do header[#header + 1] = column[1] end
	log("MATRIX " .. table.concat(header, " | "))
	local times = {}
	for _, row in ipairs(rows) do
		local cells = {string.format("%-13s", row[1])}
		local caps = caps_of(row[2])
		times[row[1]] = {}
		for _, column in ipairs(COLUMNS) do
			local params = dig(column[2], caps)
			if not params.diggable then
				params = dig(column[2], caps_of(""))
				params.hand = params.diggable
			end
			times[row[1]][column[1]] = params.diggable and params.time or false
			cells[#cells + 1] = params.diggable and
				string.format("%.3f%s", params.time, params.hand and "h" or "") or "-"
			-- Expectations: rock/resource only by a pick of tier >= required;
			-- decorative rock by any pick; loose ground by everything (hand
			-- fallback included); the tree by everything.
			local required = column[3]
			local expected
			if column[2]:find("stone") or column[2]:find("ore") or
					column[1] == "coal" then
				expected = row[4] == "pick" and row[3] >= required
			elseif column[1] == "slate" or column[1] == "basalt" or
					column[1] == "granite" then
				expected = row[4] == "pick"
			else
				expected = true
			end
			check(params.diggable == expected, row[1] .. " on " .. column[2] ..
				" diggable=" .. tostring(params.diggable))
		end
		log("MATRIX " .. table.concat(cells, " | "))
	end
	-- Orderings: higher pick faster on each rock it reaches; shovel beats
	-- the pick of its tier on loose ground; higher shovel and axe faster.
	for rock = 1, 6 do
		for tier = rock + 1, 6 do
			check(times["pick T" .. tier]["T" .. rock] < times["pick T" .. (tier - 1)]["T" .. rock],
				"pick T" .. tier .. " faster than T" .. (tier - 1) .. " on T" .. rock)
		end
	end
	for _, loose in ipairs({"dirt", "gravel", "sand", "snow", "clay", "mud", "mesa", "ash"}) do
		for tier = 1, 6 do
			check(times["shovel T" .. tier][loose] < times["pick T" .. tier][loose],
				"shovel T" .. tier .. " faster than pick T" .. tier .. " on " .. loose)
			if tier > 1 then
				check(times["shovel T" .. tier][loose] < times["shovel T" .. (tier - 1)][loose],
					"shovel T" .. tier .. " faster than shovel T" .. (tier - 1) ..
					" on " .. loose)
			end
		end
		check(times.shovel_wood[loose] < times.pick_wood[loose],
			"wooden shovel faster than wooden pick on " .. loose)
	end
	for tier = 2, 6 do
		check(times["axe T" .. tier].tree < times["axe T" .. (tier - 1)].tree,
			"axe T" .. tier .. " faster than T" .. (tier - 1) .. " on tree")
	end
end

local function registrations()
	for i = 2, 6 do
		local def = core.registered_nodes["grug_materials:t" .. i .. "_stone"]
		check(def and def.groups.level == i - 1 and def.groups.grug_stratum == i and
			def.drop == "default:cobble" and def.description:find("^Stone\n") ~= nil and
			def.description:find("Requires a T" .. i .. " pick", 1, true) ~= nil,
			"t" .. i .. "_stone registration")
	end
	for _, key in ipairs({"slate", "basalt", "granite"}) do
		local def = core.registered_nodes["grug_materials:" .. key]
		check(def and (def.groups.level or 0) == 0 and not def.groups.grug_stratum and
			def.drop == "grug_materials:" .. key, key .. " is a decorative rock")
	end
	for _, retired in ipairs({"grug_materials:emberrock", "grug_materials:abyssal_rock"}) do
		check(core.registered_nodes[retired] == nil and
			core.registered_aliases[retired] == nil, retired .. " is gone, no alias")
	end
	check(core.registered_nodes["default:stone"].description ==
		"Stone\nRequires a T1 pick", "default:stone tooltip")
end

core.register_on_mods_loaded(function()
	registrations()
	matrix()
end)

-- 3. Transaction and hints ---------------------------------------------------

local PROBE_NAME = "r24probe"

local function probe_player(item)
	local stack = ItemStack(item or "")
	return {
		is_player = function() return true end,
		get_player_name = function() return PROBE_NAME end,
		get_wielded_item = function() return ItemStack(stack) end,
		set_wielded_item = function() return true end,
	}
end

local function with_unprotected_probe(fn)
	local previous = core.is_protected
	core.is_protected = function(pos, name)
		if name == PROBE_NAME then return false end
		return previous(pos, name)
	end
	local ok, err = pcall(fn)
	core.is_protected = previous
	check(ok, "transaction scenario ran (" .. tostring(err) .. ")")
end

local function transaction(base)
	with_unprotected_probe(function()
		local cases = {
			{"grug_materials:t2_stone", "grug_materials:pick_bronze", false, "Requires a T2 pick"},
			{"grug_materials:t2_stone", "grug_materials:pick_iron", true, nil},
			{"grug_materials:t6_stone", "grug_materials:pick_embersteel", false, "Requires a T6 pick"},
			{"grug_materials:t6_stone", "grug_materials:pick_abyssal_steel", true, nil},
			{"default:stone_with_gold", "grug_materials:pick_stone", false, "Requires a T2 pick"},
			{"default:stone_with_coal", "grug_materials:pick_wood", true, nil},
			{"grug_materials:stone_with_silver", "grug_materials:pick_iron", false, "Requires a T3 pick"},
			{"default:stone", "", false, "Requires a T1 pick"},
			{"default:stone", "grug_materials:shovel_steel", false, "Requires a T1 pick"},
			{"default:dirt", "", true, nil},
			{"default:gravel", "grug_materials:pick_wood", true, nil},
			{"grug_materials:slate", "grug_materials:pick_wood", true, nil},
		}
		for index, case in ipairs(cases) do
			local pos = vector.offset(base, index, 0, 0)
			core.set_node(pos, {name = case[1]})
			local player = probe_player(case[2])
			local decision = grug_materials.mining_decision(pos, core.get_node(pos), player)
			local label = case[1] .. " with '" .. case[2] .. "'"
			check(decision.allowed == case[3], label .. " allowed=" ..
				tostring(decision.allowed) .. " reason=" .. tostring(decision.reason))
			local hint = grug_materials.punch_hint(pos, core.get_node(pos), player)
			check(hint == case[4], label .. " hint=" .. tostring(hint))
			log(("CASE %s -> %s%s"):format(label, decision.reason,
				hint and (" / \"" .. hint .. "\"") or ""))
		end
		-- A deep T1 resource stays T1 (ruling 2): coal at the T4 band.
		local deep = {x = base.x, y = -600, z = base.z}
		local deep_node = {name = "default:stone_with_coal"}
		local decision = grug_materials.mining_decision(deep, deep_node,
			probe_player("grug_materials:pick_wood"))
		check(decision.allowed and decision.required_tier == 1,
			"coal at y=-600 needs only a T1 pick")
		-- A broken pick earns the repair line.
		do
			local broken = ItemStack("grug_materials:pick_bronze")
			broken:set_wear(65535)
			local pos = vector.offset(base, 1, 0, 0)
			local hint = grug_materials.punch_hint(pos, core.get_node(pos), {
				is_player = function() return true end,
				get_player_name = function() return PROBE_NAME end,
				get_wielded_item = function() return ItemStack(broken) end,
			})
			check(hint == "Your pick is broken – repair it", "broken pick hint " ..
				tostring(hint))
		end
		local abilities = rawget(_G, "grug_abilities")
		check(type(grug_core.flash) == "function" and
			(abilities == nil or type(abilities.flash) == "function"),
			"shared flash API present")
		-- Skills never produce a hint.
		if core.registered_items["grug_abilities:strike"] then
			local pos = vector.offset(base, 1, 0, 0)
			check(grug_materials.punch_hint(pos, core.get_node(pos),
				probe_player("grug_abilities:strike")) == nil, "no hint with a skill")
		end
		-- One real refused dig: the node stays, one hint line is sent.
		local sent = {}
		local chat = core.chat_send_player
		core.chat_send_player = function(name, message)
			if name == PROBE_NAME then sent[#sent + 1] = message return end
			return chat(name, message)
		end
		local pos = vector.offset(base, 1, 0, 0)
		core.set_node(pos, {name = "grug_materials:t2_stone"})
		local dug = core.node_dig(pos, core.get_node(pos), probe_player("grug_materials:pick_bronze"))
		core.chat_send_player = chat
		check(dug == false and core.get_node(pos).name == "grug_materials:t2_stone",
			"bronze pick dig of T2 stone refused, node kept")
		check(#sent <= 1 and (sent[1] == nil or sent[1] == "Requires a T2 pick"),
			"refusal hint line: " .. tostring(sent[1]))
	end)
end

-- 4. Protection reasons ------------------------------------------------------

local function protection_reasons()
	local previous_faction = grug_core.get_player_faction
	local faction = "accord"
	grug_core.get_player_faction = function(name)
		if name == PROBE_NAME then return faction end
		return previous_faction(name)
	end
	local ok, err = pcall(function()
		local starts = grug_core.start_identities()
		check(#starts == 6, "six start identities")
		for _, start in ipairs(starts) do
			local pos = vector.offset(start.anchor, 0, 1, 0)
			faction = start.faction_id == "accord" and "throng" or "accord"
			local reason = grug_core.protection_reason(pos, PROBE_NAME)
			check(reason == "town", start.race_id .. " start town reason " ..
				tostring(reason))
			log(("REASON %s start (%s player): %s / \"%s\""):format(start.race_id,
				faction, tostring(reason), tostring(grug_core.protection_hint(pos,
					PROBE_NAME))))
			-- Walk out of the town until the home territory answers.
			local found
			for radius = 200, 600, 50 do
				for step = 0, 7 do
					local angle = step * math.pi / 4
					local probe = {x = math.floor(start.anchor.x + radius * math.cos(angle)),
						y = start.anchor.y, z = math.floor(start.anchor.z + radius * math.sin(angle))}
					local rule = grug_zones.territory_rule_at(probe)
					if not found and rule == start.faction_id .. "_home" and
							grug_zones.hard_protection_kind_at(probe) == nil then
						found = probe
					end
				end
			end
			if check(found ~= nil, start.race_id .. " home territory sample found") then
				local expected = start.faction_id .. "_home"
				local reason_home = grug_core.protection_reason(found, PROBE_NAME)
				local hint_home = grug_core.protection_hint(found, PROBE_NAME)
				check(reason_home == expected, start.race_id .. " home reason " ..
					tostring(reason_home))
				log(("REASON %s home %s (%s player): %s / \"%s\""):format(
					start.race_id, core.pos_to_string(found), faction,
					tostring(reason_home), tostring(hint_home)))
				faction = start.faction_id
				check(grug_core.protection_reason(found, PROBE_NAME) == nil,
					start.race_id .. " own home territory is not protected")
			end
		end
		faction = "accord"
		local deep = vector.offset(starts[1].anchor, 300, -900, 300)
		check(grug_core.protection_reason(deep, PROBE_NAME) == nil,
			"contested deep is not protected")
	end)
	grug_core.get_player_faction = previous_faction
	check(ok, "protection scenario ran (" .. tostring(err) .. ")")
end

-- 2. Generated tier rock and the run -----------------------------------------

local SAMPLES = {
	{y = -200, node = "grug_materials:t2_stone"},
	{y = -620, node = "grug_materials:t4_stone"},
	{y = -1100, node = "grug_materials:t6_stone"},
}

local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("r24 mining probe done", false, 0)
end

local function sample(index, done)
	local row = SAMPLES[index]
	if not row then return done() end
	local minp = {x = 0, y = row.y - 8, z = 0}
	local maxp = {x = 15, y = row.y + 7, z = 15}
	local started = core.get_us_time()
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		local _, counts = core.find_nodes_in_area(minp, maxp, {row.node,
			"default:stone", "grug_materials:slate", "grug_materials:basalt",
			"grug_materials:granite"})
		log(("GENERATED y=%d: %s=%d default:stone=%d decorative=%d (%.1f s)"):format(
			row.y, row.node, counts[row.node] or 0, counts["default:stone"] or 0,
			(counts["grug_materials:slate"] or 0) + (counts["grug_materials:basalt"] or 0) +
			(counts["grug_materials:granite"] or 0),
			(core.get_us_time() - started) / 1000000))
		check((counts[row.node] or 0) > 0, "generated " .. row.node .. " at y=" .. row.y)
		core.after(0, function() sample(index + 1, done) end)
	end)
end

core.after(2, function()
	sample(1, function()
		transaction({x = 2, y = -200, z = 2})
		protection_reasons()
		finish()
	end)
end)
