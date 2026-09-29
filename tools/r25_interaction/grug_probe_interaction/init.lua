-- Round 25 Lane B engine probe (disposable, never shipped): the generic
-- interaction guard over the real registered nodes (ruling 18).
--
-- 1. Reports the installed guard: node counts by kind, the right-click and
--    node-form names by mod, and the exceptions.
-- 2. Fakes one active claim (owner r25bowner, r25bfriend with "interact")
--    on Accord home ground found next to an Accord start, and a Lane A style
--    core.is_protected for it (edits protected from all but the owner and
--    "everything").
-- 3. Sweeps EVERY registered node but the exceptions: right-click (where the
--    node has one), put, take, move and form fields (where it has a form)
--    by the non-permitted r25bstranger inside the claim must all be refused
--    before the node's own callback runs, each with one protection violation.
-- 4. Real nodes placed in the claim: a chest, a wooden door and a furnace (a
--    grug_jobs station). The stranger's right-click and put are refused; the
--    friend opens the chest, opens the door and puts into the furnace
--    (through the station's own gate, grug_core.interaction_protected).
--    Then the same with the claim expired (stranger allowed) and outside it.
-- 5. Hint texts: the claim reason and the world reason for an enemy player.
-- Ends the server itself; "RESULT PASS" is the verdict line.

local PREFIX = "[r25_interaction_probe] "
local checks, failures = 0, 0
local function log(message) core.log("action", PREFIX .. message) end
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		core.log("error", PREFIX .. "FAIL " .. label)
	end
	return ok
end

local OWNER, FRIEND, STRANGER, ENEMY = "r25bowner", "r25bfriend", "r25bstranger", "r25benemy"
local FACTION = {[OWNER] = "accord", [FRIEND] = "accord", [STRANGER] = "accord",
	[ENEMY] = "throng"}

local violations = {}
core.register_on_protection_violation(function(_, name)
	violations[name] = (violations[name] or 0) + 1
end)
local function violation_count(name) return violations[name] or 0 end

local previous_faction = grug_core.get_player_faction
grug_core.get_player_faction = function(name)
	return FACTION[name] or previous_faction(name)
end

local function fake_player(name, at)
	local wielded = ItemStack("")
	return {
		is_player = function() return true end,
		get_player_name = function() return name end,
		get_pos = function() return vector.new(at) end,
		get_hp = function() return 20 end,
		get_wielded_item = function() return ItemStack(wielded) end,
		set_wielded_item = function() return true end,
		get_inventory = function() return nil end,
		get_player_control = function() return {} end,
	}
end

local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("r25 interaction probe done", false, 0)
end

-- Accord home ground: walk out from the first Accord start until the
-- territory is accord_home without hard protection.
local function accord_home_spot()
	for _, start in ipairs(grug_core.start_identities()) do
		if start.faction_id == "accord" then
			local a = start.anchor
			for radius = 200, 1600, 100 do
				for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
					local pos = {x = a.x + d[1] * radius, y = 60, z = a.z + d[2] * radius}
					if grug_zones.territory_rule_at(pos) == "accord_home" and
							grug_zones.hard_protection_kind_at(pos) == nil and
							not grug_core.world_protected_for_faction(pos, "accord") then
						return vector.new(pos), start
					end
				end
			end
		end
	end
end

local function report_install()
	local report = grug_housing.interaction_guard_report
	if not check(report ~= nil, "guard installed") then return nil end
	local total = 0
	for _ in pairs(core.registered_nodes) do total = total + 1 end
	log(("GUARD registered nodes=%d: node inventory %d, right-click %d, node form %d"):format(
		total, report.nodes, #report.rightclick, #report.fields))
	log("EXCEPTIONS " .. table.concat(report.exceptions, ", "))
	check(report.nodes + #report.exceptions == total, "every other node inventory-guarded")
	local function by_mod(label, names)
		local groups, mods = {}, {}
		for _, name in ipairs(names) do
			local mod = name:match("^([^:]+):") or name
			if not groups[mod] then groups[mod] = {} mods[#mods + 1] = mod end
			table.insert(groups[mod], (name:gsub("^[^:]+:", "")))
		end
		table.sort(mods)
		for _, mod in ipairs(mods) do
			log(("%s %s (%d): %s"):format(label, mod, #groups[mod],
				table.concat(groups[mod], " ")))
		end
	end
	by_mod("RIGHT-CLICK", report.rightclick)
	by_mod("FORM", report.fields)
	-- Every node with a right-click or a node form is listed or an exception.
	local listed, missing = {}, {}
	for _, name in ipairs(report.rightclick) do listed[name] = true end
	for _, name in ipairs(report.fields) do listed[name] = true end
	for name, def in pairs(core.registered_nodes) do
		if (type(def.on_rightclick) == "function" or
				type(def.on_receive_fields) == "function") and not listed[name] and
				not grug_housing.INTERACTION_EXCEPTIONS[name] then
			missing[#missing + 1] = name
		end
	end
	check(#missing == 0, "unguarded interactive nodes: " .. table.concat(missing, " "))
	check(listed["default:chest"] and listed["doors:door_wood_a"] and
		listed["default:furnace"], "chest, door and furnace guarded")
	return report
end

-- 3. Every guarded node refuses the stranger before its own callback runs.
local function sweep(report, pos)
	local stranger = fake_player(STRANGER, pos)
	local expected, refused, bad = 0, 0, {}
	local before = violation_count(STRANGER)
	local names = {}
	for name in pairs(core.registered_nodes) do
		if not grug_housing.INTERACTION_EXCEPTIONS[name] then names[#names + 1] = name end
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local def = core.registered_nodes[name]
		local item = ItemStack("default:dirt 3")
		if def.on_rightclick then
			expected = expected + 1
			local ok, result = pcall(def.on_rightclick, pos, {name = name}, stranger,
				item, {type = "node", under = pos, above = pos})
			if ok and result == item then refused = refused + 1
			else bad[#bad + 1] = name .. ":rightclick" end
		end
		for _, call in ipairs({
			{"put", function() return def.allow_metadata_inventory_put(pos, "main", 1, item, stranger) end},
			{"take", function() return def.allow_metadata_inventory_take(pos, "main", 1, item, stranger) end},
			{"move", function() return def.allow_metadata_inventory_move(pos, "main", 1, "main", 2, 3, stranger) end},
		}) do
			expected = expected + 1
			local ok, result = pcall(call[2])
			if ok and result == 0 then refused = refused + 1
			else bad[#bad + 1] = name .. ":" .. call[1] end
		end
		if def.on_receive_fields then
			expected = expected + 1
			local ok = pcall(def.on_receive_fields, pos, "probe", {probe = "1"}, stranger)
			if ok then refused = refused + 1 else bad[#bad + 1] = name .. ":fields" end
		end
	end
	local recorded = violation_count(STRANGER) - before
	log(("SWEEP %d guarded nodes: %d calls, %d refused, %d violations recorded%s"):format(
		#names, expected, refused, recorded,
		#bad > 0 and (", bad: " .. table.concat(bad, " ")) or ""))
	check(refused == expected and #bad == 0, "sweep: every call refused")
	check(recorded == expected, "sweep: one violation per refused call")
end

local function place(pos, name, param2)
	core.set_node(pos, {name = name, param2 = param2 or 0})
	return core.get_node(pos).name == name
end

-- 4. Chest, door and furnace for one player; returns the outcomes.
local function interact(base, player_name, label)
	local chest = vector.offset(base, 0, 0, 0)
	local door = vector.offset(base, 3, 0, 0)
	local furnace = vector.offset(base, 6, 0, 0)
	core.set_node(vector.offset(chest, 0, 1, 0), {name = "air"})
	check(place(chest, "default:chest"), label .. ": chest placed")
	check(place(door, "doors:door_wood_a"), label .. ": door placed")
	core.set_node(vector.offset(door, 0, 1, 0), {name = "doors:hidden"})
	check(place(furnace, "default:furnace"), label .. ": furnace placed")
	local player = fake_player(player_name, base)
	local before = violation_count(player_name)
	local defs = core.registered_nodes
	local item = ItemStack("default:dirt")
	defs["default:chest"].on_rightclick(chest, core.get_node(chest), player, item,
		{type = "node", under = chest, above = chest})
	local chest_after = core.get_node(chest).name
	local chest_put = defs[core.get_node(chest).name].allow_metadata_inventory_put(
		chest, "main", 1, ItemStack("default:dirt 5"), player)
	-- The default chest has no allow_take of its own.
	local chest_take = defs[core.get_node(chest).name].allow_metadata_inventory_take(
		chest, "main", 1, ItemStack("default:dirt 2"), player)
	defs["doors:door_wood_a"].on_rightclick(door, core.get_node(door), player, item,
		{type = "node", under = door, above = door})
	local door_after = core.get_node(door).name
	local furnace_put = defs["default:furnace"].allow_metadata_inventory_put(
		furnace, "src", 1, ItemStack("default:iron_lump 4"), player)
	local out = {
		chest = chest_after == "default:chest_open" and "opened" or
			(chest_after == "default:chest" and "closed" or chest_after),
		chest_put = chest_put, chest_take = chest_take,
		door = door_after ~= "doors:door_wood_a" and "opened" or "closed",
		furnace_put = furnace_put, violations = violation_count(player_name) - before,
		hint = grug_core.protection_hint(chest, player_name),
	}
	log(("%s %s: chest right-click %s, chest put %d, chest take %d, door %s (%s), " ..
		"furnace put %d, violations %d, hint %s"):format(label, player_name, out.chest,
		out.chest_put, out.chest_take, out.door, door_after, out.furnace_put,
		out.violations, tostring(out.hint)))
	return out
end

core.after(2, function()
	local report = report_install()
	local base, start = accord_home_spot()
	if not check(report ~= nil and base ~= nil, "install report and Accord home spot") then
		return finish()
	end
	log(("CLAIM centre %s (Accord start %s): territory %s"):format(
		core.pos_to_string(base), core.pos_to_string(start.anchor),
		grug_zones.territory_rule_at(base)))

	-- The fake claim and a Lane A style edit protection for it.
	local active = true
	local claim = {id = 1, owner = OWNER, center = vector.new(base), placed_at = 0,
		paid_until = 0}
	local outside
	for _, d in ipairs({{200, 0}, {-200, 0}, {0, 200}, {0, -200}}) do
		local pos = vector.offset(base, d[1], 0, d[2])
		if not outside and grug_zones.territory_rule_at(pos) == "accord_home" and
				grug_zones.hard_protection_kind_at(pos) == nil then
			outside = pos
		end
	end
	if not check(outside ~= nil, "Accord home spot outside the claim") then
		return finish()
	end
	grug_housing.claim_at = function(pos)
		if math.abs(pos.x - base.x) <= 50 and math.abs(pos.z - base.z) <= 50 and
				pos.y >= -100 then
			return claim
		end
	end
	grug_housing.is_active = function() return active end
	grug_housing.permission = function(_, name)
		if name == OWNER then return "owner" end
		if name == FRIEND then return "interact" end
		return nil
	end
	local world_is_protected = core.is_protected
	core.is_protected = function(pos, name)
		if world_is_protected(pos, name) then return true end
		local c = grug_housing.claim_at(pos)
		if not c or not grug_housing.is_active(c) then return false end
		local level = grug_housing.permission(c, name)
		return level ~= "owner" and level ~= "everything"
	end

	local started = core.get_us_time()
	core.emerge_area(vector.offset(base, -8, -8, -8), vector.offset(base, 16, 8, 8),
			function(_, _, remaining)
		if remaining > 0 then return end
		core.emerge_area(vector.offset(outside, -8, -8, -8),
				vector.offset(outside, 16, 8, 8), function(_, _, left)
			if left > 0 then return end
			log(("EMERGED in %.1f s"):format((core.get_us_time() - started) / 1000000))
			local ok, err = pcall(function()
				sweep(report, base)
				local HOME = "Home of " .. OWNER .. " – protected"
				local s = interact(base, STRANGER, "ACTIVE")
				check(s.chest == "closed" and s.chest_put == 0 and s.chest_take == 0 and
					s.door == "closed" and s.furnace_put == 0, "active claim: stranger refused")
				check(s.violations == 5, "active claim: stranger gets 5 violations")
				check(s.hint == HOME, "active claim: claim hint for the stranger")
				local f = interact(base, FRIEND, "ACTIVE")
				check(f.chest == "opened" and f.chest_put == 5 and f.chest_take == 2 and
					f.door == "opened" and f.furnace_put == 4,
					"active claim: interact player allowed")
				check(f.violations == 0, "active claim: friend has no violation")
				check(f.hint == HOME, "active claim: interact may not build (claim hint)")
				check(grug_core.interaction_protected(base, STRANGER) == true and
					grug_core.interaction_protected(base, FRIEND) == false and
					grug_core.interaction_protected(base, OWNER) == false,
					"station gate: stranger refused, friend and owner allowed")
				local enemy_hint = grug_core.protection_hint(base, ENEMY)
				log("ENEMY hint in the claim: " .. tostring(enemy_hint))
				check(enemy_hint == "Accord home territory – protected",
					"world reason wins for the enemy faction")
				check(grug_core.protection_hint(base, OWNER) == nil, "owner: no hint")
				active = false
				local e = interact(base, STRANGER, "EXPIRED")
				check(e.chest == "opened" and e.chest_put == 5 and e.chest_take == 2 and
					e.door == "opened" and
					e.furnace_put == 4 and e.violations == 0 and e.hint == nil,
					"expired claim: stranger allowed")
				active = true
				local o = interact(outside, STRANGER, "OUTSIDE")
				check(o.chest == "opened" and o.chest_put == 5 and o.chest_take == 2 and
					o.door == "opened" and
					o.furnace_put == 4 and o.violations == 0 and o.hint == nil,
					"outside the claim: stranger allowed")
			end)
			check(ok, "scenario ran (" .. tostring(err) .. ")")
			finish()
		end)
	end)
end)
