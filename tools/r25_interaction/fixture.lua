-- Round 25 Lane B portable fixture (LuaJIT): interaction protection in
-- claims (ruling 18) and the claim reason of the protection hint.
--
--   luajit tools/r25_interaction/fixture.lua "$PWD"
--
-- Loads the real grug_core/protection.lua and grug_housing/{api,interaction}.lua
-- against a fake `core`, replaces the claim contract stubs with fake claims
-- and a fake Lane A core.is_protected (an active claim protects edits from
-- everyone but the owner and "everything"), registers sample nodes, runs the
-- mods-loaded phase and the first server step, then checks:
--   1. the install: which nodes are guarded, by kind, and the exceptions;
--   2. every permission level against right-click, put, take, move and node
--      form fields in an active claim, an expired claim and outside claims;
--   3. the exceptions (sign reading, the Claim Stone) stay unguarded;
--   4. the hint text through the violation callback, the claim reason for
--      digging, and world-reason precedence (enemy faction, a town/road
--      stand-in inside the claim);
--   5. grug_core.interaction_protected (the station gate): claim permission
--      plus the unchanged world rule;
--   6. cost outside claims: one claim_at call per guarded callback, nothing
--      else.
-- Prints "R25 INTERACTION FIXTURE PASS checks=<n>" or raises on the first
-- failure.
local repo = assert(arg[1], "usage: fixture.lua <repo>")

local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end

-- ---------------------------------------------------------------------------
-- Fake engine
-- ---------------------------------------------------------------------------
local mods_loaded, after_jobs, violations, log_lines = {}, {}, {}, {}
local bypass = {admin = true}
local privilege_lookups = 0

core = {
	registered_nodes = {},
	log = function(_, message) log_lines[#log_lines + 1] = message end,
	register_on_mods_loaded = function(fn) mods_loaded[#mods_loaded + 1] = fn end,
	after = function(_, fn, ...) after_jobs[#after_jobs + 1] = {fn, {...}} end,
	check_player_privs = function(name, privs)
		privilege_lookups = privilege_lookups + 1
		return privs.protection_bypass == true and bypass[name] == true
	end,
	-- The previous handler protection.lua captures: builtin (nothing).
	is_protected = function() return false end,
}
-- grug_materials' violation callback: the hint line for the player.
function core.record_protection_violation(pos, name)
	violations[#violations + 1] = {pos = pos, name = name,
		hint = grug_core.protection_hint(pos, name) or "Protected"}
end

local function stack(count)
	return {get_count = function() return count end}
end

-- ---------------------------------------------------------------------------
-- Fake world: x < 0 is an Accord town (hard protected); everything else is
-- Accord home territory. The node x = 50, z = 50 inside claim A stands in for
-- a road corridor (Lane E): hard protected for everyone, owner included.
-- ---------------------------------------------------------------------------
grug_core = {}
local function road_spot(pos) return pos.x == 50 and pos.z == 50 end
grug_zones = {
	hard_protection_kind_at = function(pos)
		if pos.x < 0 or road_spot(pos) then return "town" end
		return nil
	end,
	territory_rule_at = function(pos)
		if pos.x < 0 or road_spot(pos) then return "hard_protected" end
		return "accord_home"
	end,
}
function grug_core.zone_authority_installed() return true end
function grug_core.world_protected_for_faction(pos, faction)
	if faction ~= "accord" and faction ~= "throng" then return true end
	local territory = grug_zones.territory_rule_at(pos)
	if territory == "hard_protected" then return true end
	return faction ~= "accord"
end
local factions = {olaf = "accord", ivy = "accord", eve = "accord",
	sam = "accord", admin = "accord", thor = "throng"}
function grug_core.get_player_faction(name) return factions[name] end

dofile(repo .. "/mods/CORE/grug_core/protection.lua")

-- ---------------------------------------------------------------------------
-- grug_housing with fake claims
-- ---------------------------------------------------------------------------
grug_housing = {}
dofile(repo .. "/mods/PLAYER/grug_housing/api.lua")

local NOW = 1000000
local claims = {
	{id = 1, owner = "olaf", center = {x = 50, y = 10, z = 50},
		paid_until = NOW + 3600, perms = {ivy = "interact", eve = "everything"}},
	{id = 2, owner = "olaf", center = {x = 250, y = 10, z = 50},
		paid_until = NOW - 1, perms = {ivy = "interact", eve = "everything"}},
}
local calls = {claim_at = 0, is_active = 0, permission = 0}
function grug_housing.claim_at(pos)
	calls.claim_at = calls.claim_at + 1
	for _, claim in ipairs(claims) do
		if math.abs(pos.x - claim.center.x) <= grug_housing.RADIUS and
				math.abs(pos.z - claim.center.z) <= grug_housing.RADIUS and
				pos.y >= grug_housing.MIN_Y then
			return claim
		end
	end
	return nil
end
function grug_housing.is_active(claim)
	calls.is_active = calls.is_active + 1
	return claim.paid_until > NOW
end
function grug_housing.permission(claim, name)
	calls.permission = calls.permission + 1
	if name == claim.owner then return "owner" end
	return claim.perms[name]
end

-- Lane A's core.is_protected, as the contract describes it.
local world_is_protected = core.is_protected
function core.is_protected(pos, name)
	if world_is_protected(pos, name) then return true end
	if name ~= "" and core.check_player_privs(name, {protection_bypass = true}) then
		return false
	end
	local claim = grug_housing.claim_at(pos)
	if not claim or not grug_housing.is_active(claim) then return false end
	local level = grug_housing.permission(claim, name)
	return level ~= "owner" and level ~= "everything"
end

dofile(repo .. "/mods/PLAYER/grug_housing/interaction.lua")

-- ---------------------------------------------------------------------------
-- Sample nodes (registered before the mods-loaded phase)
-- ---------------------------------------------------------------------------
local reached = {}
local function mark(key) reached[#reached + 1] = key end
local function recorder(key, result)
	return function(...)
		mark(key)
		if type(result) == "function" then return result(...) end
		return result
	end
end
local original = {}
-- As builtin register_item: a registered definition silently ignores NEW
-- keys (__newindex); only rawset (core.override_item) adds one.
local function node(name, def)
	original[name] = {}
	for key, value in pairs(def) do original[name][key] = value end
	setmetatable(def, {__index = {}, __newindex = function() end})
	core.registered_nodes[name] = def
end
-- A chest: right-click and loggers, no allow callbacks (default chest).
node("default:chest", {
	on_rightclick = recorder("chest:rightclick", function(_, _, _, itemstack)
		return itemstack end),
	on_metadata_inventory_put = recorder("chest:logged"),
})
node("doors:door_wood_a", {
	on_rightclick = recorder("door:rightclick", function(_, _, _, itemstack)
		return itemstack end),
})
-- A station: its own allow callbacks (half of a put) and a form.
node("default:furnace", {
	on_rightclick = recorder("furnace:rightclick"),
	allow_metadata_inventory_put = recorder("furnace:put", function(_, _, _, s)
		return math.floor(s:get_count() / 2) end),
	allow_metadata_inventory_take = recorder("furnace:take", function(_, _, _, s)
		return s:get_count() end),
	allow_metadata_inventory_move = recorder("furnace:move", function(...)
		return select(6, ...) end),
	on_receive_fields = recorder("furnace:fields"),
})
-- A form without inventory (the mob spawner's settings).
node("mobs:spawner", {
	on_rightclick = recorder("spawner:rightclick"),
	on_receive_fields = recorder("spawner:fields"),
})
node("default:sign_wall_wood", {
	on_rightclick = recorder("sign:rightclick"),
	on_receive_fields = recorder("sign:fields"),
})
node("grug_housing:claim_stone", {
	on_rightclick = recorder("stone:rightclick"),
	allow_metadata_inventory_put = recorder("stone:put", function(_, _, _, s)
		return s:get_count() end),
})
node("default:stone", {})

-- A mods-loaded callback registered after grug_housing's replaces a node's
-- callbacks outright (grug_jobs installs stations this way); the guard must
-- still cover it.
core.register_on_mods_loaded(function()
	local def = core.registered_nodes["default:furnace"]
	def.on_rightclick = recorder("furnace:rightclick")
	original["default:furnace"].on_rightclick = def.on_rightclick
end)
-- grug_skills' bound-item guard: allow put/move chained onto EVERY node.
core.register_on_mods_loaded(function()
	for name, def in pairs(core.registered_nodes) do
		local put, move = def.allow_metadata_inventory_put, def.allow_metadata_inventory_move
		rawset(def, "allow_metadata_inventory_put", function(...)
			if put then return put(...) end
			return select(4, ...):get_count()
		end)
		rawset(def, "allow_metadata_inventory_move", function(...)
			if move then return move(...) end
			return select(6, ...)
		end)
		original[name].allow_metadata_inventory_put = def.allow_metadata_inventory_put
		original[name].allow_metadata_inventory_move = def.allow_metadata_inventory_move
	end
end)

-- Mods-loaded phase, then the first server step.
for _, fn in ipairs(mods_loaded) do fn() end
check(grug_housing.interaction_guard_report == nil, "nothing installed before the first step")
for _, job in ipairs(after_jobs) do job[1](unpack(job[2])) end

-- ---------------------------------------------------------------------------
-- 1. Install
-- ---------------------------------------------------------------------------
local report = grug_housing.interaction_guard_report
check(report ~= nil, "install report")
check(report.nodes == 5, "inventory-guarded nodes 5, got " .. report.nodes)
check(table.concat(report.rightclick, ",") ==
	"default:chest,default:furnace,doors:door_wood_a,mobs:spawner", "right-click names")
check(table.concat(report.fields, ",") == "default:furnace,mobs:spawner", "node form names")
check(table.concat(report.exceptions, ",") ==
	"default:sign_wall_wood,grug_housing:claim_stone", "exceptions present")
for _, name in ipairs({"default:sign_wall_wood", "grug_housing:claim_stone"}) do
	local def = core.registered_nodes[name]
	for key, value in pairs(original[name]) do
		check(def[key] == value, name .. " " .. key .. " untouched")
	end
	check(rawget(def, "allow_metadata_inventory_take") == nil, name .. " gains nothing")
end
check(rawget(core.registered_nodes["default:stone"], "on_rightclick") == nil and
	rawget(core.registered_nodes["default:stone"], "on_receive_fields") == nil,
	"plain node gains no right-click or form")
for _, name in ipairs({"default:chest", "default:furnace", "doors:door_wood_a",
		"mobs:spawner", "default:stone"}) do
	local def = core.registered_nodes[name]
	check(name == "default:stone" or def.on_rightclick ~= original[name].on_rightclick,
		name .. " right-click wrapped")
	for _, field in ipairs({"allow_metadata_inventory_put",
			"allow_metadata_inventory_take", "allow_metadata_inventory_move"}) do
		check(type(rawget(def, field)) == "function" and def[field] ~= original[name][field],
			name .. " " .. field .. " wrapped")
	end
end
check(log_lines[#log_lines]:find("node inventories on 5 nodes, right-click on 4, " ..
	"node form on 2", 1, true) ~= nil, "install log line")

-- ---------------------------------------------------------------------------
-- 2./4. Permission matrix and hints
-- ---------------------------------------------------------------------------
local function player(name)
	return {get_player_name = function() return name end,
		is_player = function() return name ~= "" end}
end
local IN_ACTIVE = {x = 20, y = 5, z = 30}
local IN_EXPIRED = {x = 260, y = 5, z = 40}
local OUTSIDE = {x = 450, y = 5, z = 0}
local ITEM = {}

-- Runs every guarded action at pos for name; returns the outcome per action
-- ("allow"/"refuse") and the hints recorded.
local function run_all(pos, name)
	local actor = player(name)
	local out = {}
	local nodes = core.registered_nodes
	reached, violations = {}, {}
	local r = nodes["default:chest"].on_rightclick(pos, {}, actor, ITEM, {})
	out.chest_rightclick = (#reached == 1 and r == ITEM) and "allow" or
		(#reached == 0 and r == ITEM and "refuse" or "bad")
	reached = {}
	nodes["doors:door_wood_a"].on_rightclick(pos, {}, actor, ITEM, {})
	out.door = #reached == 1 and "allow" or "refuse"
	local put = nodes["default:chest"].allow_metadata_inventory_put(pos, "main", 1, stack(8), actor)
	out.chest_put = put == 8 and "allow" or (put == 0 and "refuse" or "bad")
	local take = nodes["default:chest"].allow_metadata_inventory_take(pos, "main", 1, stack(5), actor)
	out.chest_take = take == 5 and "allow" or (take == 0 and "refuse" or "bad")
	local move = nodes["default:chest"].allow_metadata_inventory_move(pos, "main", 1, "main", 2, 3, actor)
	out.chest_move = move == 3 and "allow" or (move == 0 and "refuse" or "bad")
	-- A node without any callbacks of its own may still hold an inventory.
	local stake = nodes["default:stone"].allow_metadata_inventory_take(pos, "main", 1, stack(2), actor)
	out.stone_take = stake == 2 and "allow" or (stake == 0 and "refuse" or "bad")
	reached = {}
	local fput = nodes["default:furnace"].allow_metadata_inventory_put(pos, "src", 1, stack(8), actor)
	-- The station's own answer (half) must survive the wrapper.
	out.furnace_put = (fput == 4 and #reached == 1) and "allow" or (fput == 0 and #reached == 0 and "refuse" or "bad")
	reached = {}
	local fmove = nodes["default:furnace"].allow_metadata_inventory_move(pos, "src", 1, "fuel", 1, 2, actor)
	out.furnace_move = (fmove == 2 and #reached == 1) and "allow" or (fmove == 0 and #reached == 0 and "refuse" or "bad")
	reached = {}
	nodes["default:furnace"].on_receive_fields(pos, "f", {cook = "1"}, actor)
	out.furnace_fields = #reached == 1 and "allow" or "refuse"
	reached = {}
	nodes["mobs:spawner"].on_receive_fields(pos, "f", {text = "x"}, actor)
	out.spawner_fields = #reached == 1 and "allow" or "refuse"
	reached = {}
	nodes["default:furnace"].on_rightclick(pos, {}, actor, ITEM, {})
	out.furnace_rightclick = #reached == 1 and "allow" or "refuse"
	return out, violations
end

local ACTIONS = {"chest_rightclick", "door", "chest_put", "chest_take",
	"chest_move", "stone_take", "furnace_put", "furnace_move", "furnace_fields",
	"spawner_fields", "furnace_rightclick"}
local HOME = "Home of olaf – protected"
local TERRITORY = "Accord home territory – protected"
local cases = {
	{IN_ACTIVE, "olaf", "allow"}, {IN_ACTIVE, "eve", "allow"},
	{IN_ACTIVE, "ivy", "allow"}, {IN_ACTIVE, "sam", "refuse", HOME},
	{IN_ACTIVE, "thor", "refuse", TERRITORY}, {IN_ACTIVE, "admin", "allow"},
	{IN_ACTIVE, "", "refuse"},
	{IN_EXPIRED, "olaf", "allow"}, {IN_EXPIRED, "ivy", "allow"},
	{IN_EXPIRED, "sam", "allow"}, {IN_EXPIRED, "thor", "allow"},
	{IN_EXPIRED, "", "allow"},
	{OUTSIDE, "sam", "allow"}, {OUTSIDE, "thor", "allow"}, {OUTSIDE, "", "allow"},
}
for _, case in ipairs(cases) do
	local pos, name, expected, hint = case[1], case[2], case[3], case[4]
	local label = ("%s at %d,%d"):format(name == "" and "<none>" or name, pos.x, pos.z)
	local out, hints = run_all(pos, name)
	for _, action in ipairs(ACTIONS) do
		check(out[action] == expected, label .. " " .. action .. " expected " ..
			expected .. " got " .. tostring(out[action]))
	end
	if expected == "refuse" and name ~= "" then
		check(#hints == #ACTIONS, label .. " one violation per refused action")
		for _, v in ipairs(hints) do
			check(v.hint == hint, label .. " hint '" .. tostring(v.hint) .. "'")
		end
	else
		check(#hints == 0, label .. " no violation")
	end
	print(("%-16s %s%s"):format(label, expected, hint and ("  hint: " .. hint) or ""))
end

-- A form submission that only closes refuses silently.
reached, violations = {}, {}
core.registered_nodes["mobs:spawner"].on_receive_fields(IN_ACTIVE, "f", {quit = "true"}, player("sam"))
check(#reached == 0 and #violations == 0, "close-only submission: refused, no hint")

-- ---------------------------------------------------------------------------
-- 3. Exceptions stay free for everyone
-- ---------------------------------------------------------------------------
reached, violations = {}, {}
core.registered_nodes["default:sign_wall_wood"].on_rightclick(IN_ACTIVE, {}, player("sam"), ITEM, {})
core.registered_nodes["grug_housing:claim_stone"].on_rightclick(IN_ACTIVE, {}, player("sam"), ITEM, {})
check(#reached == 2 and #violations == 0, "sign and Claim Stone reach their own callbacks")

-- ---------------------------------------------------------------------------
-- 4. Claim reason for digging, world precedence
-- ---------------------------------------------------------------------------
local ROAD = {x = 50, y = 5, z = 50}
local reasons = {
	{IN_ACTIVE, "sam", "claim", HOME}, {IN_ACTIVE, "ivy", "claim", HOME},
	{IN_ACTIVE, "eve", nil, nil}, {IN_ACTIVE, "olaf", nil, nil},
	{IN_ACTIVE, "thor", "accord_home", TERRITORY},
	{IN_ACTIVE, "admin", nil, nil},
	{ROAD, "olaf", "town", "Town – protected"},
	{ROAD, "sam", "town", "Town – protected"},
	{IN_EXPIRED, "sam", nil, nil}, {IN_EXPIRED, "thor", "accord_home", TERRITORY},
	{OUTSIDE, "sam", nil, nil}, {{x = -10, y = 5, z = 0}, "sam", "town", "Town – protected"},
}
for _, row in ipairs(reasons) do
	local pos, name = row[1], row[2]
	local reason = grug_core.protection_reason(pos, name)
	local hint = grug_core.protection_hint(pos, name)
	check(reason == row[3], ("reason %s at %d,%d: %s"):format(name, pos.x, pos.z, tostring(reason)))
	check(hint == row[4], ("hint %s at %d,%d: %s"):format(name, pos.x, pos.z, tostring(hint)))
end

-- ---------------------------------------------------------------------------
-- 5. The station gate: claim permission plus the unchanged world rule
-- ---------------------------------------------------------------------------
local gate = {
	{IN_ACTIVE, "ivy", false}, {IN_ACTIVE, "eve", false}, {IN_ACTIVE, "olaf", false},
	{IN_ACTIVE, "sam", true}, {IN_ACTIVE, "thor", true}, {IN_ACTIVE, "admin", false},
	{IN_ACTIVE, "", true}, {IN_EXPIRED, "sam", false}, {IN_EXPIRED, "thor", true},
	{OUTSIDE, "sam", false}, {OUTSIDE, "thor", true}, {ROAD, "olaf", true},
	{{x = -10, y = 5, z = 0}, "sam", true},
}
for _, row in ipairs(gate) do
	check(grug_core.interaction_protected(row[1], row[2]) == row[3],
		("interaction_protected %s at %d,%d"):format(row[2], row[1].x, row[1].z))
end
-- Dig/place stays strict for "interact": core.is_protected is unchanged.
check(core.is_protected(IN_ACTIVE, "ivy") == true, "interact may not build")
check(core.is_protected(IN_ACTIVE, "eve") == false, "everything may build")

-- ---------------------------------------------------------------------------
-- 6. Cost outside claims and in expired claims
-- ---------------------------------------------------------------------------
local function cost(pos)
	calls.claim_at, calls.is_active, calls.permission = 0, 0, 0
	privilege_lookups = 0
	local actor = player("sam")
	local nodes = core.registered_nodes
	nodes["default:chest"].on_rightclick(pos, {}, actor, ITEM, {})
	nodes["default:chest"].allow_metadata_inventory_put(pos, "main", 1, stack(1), actor)
	nodes["default:chest"].allow_metadata_inventory_take(pos, "main", 1, stack(1), actor)
	nodes["default:chest"].allow_metadata_inventory_move(pos, "main", 1, "main", 2, 1, actor)
	nodes["default:furnace"].on_receive_fields(pos, "f", {cook = "1"}, actor)
	return calls.claim_at, calls.is_active, calls.permission, privilege_lookups
end
local c, a, p, v = cost(OUTSIDE)
check(c == 5 and a == 0 and p == 0 and v == 0,
	("outside: 5 guarded calls cost claim_at %d is_active %d permission %d privs %d"):format(c, a, p, v))
c, a, p, v = cost(IN_EXPIRED)
check(c == 5 and a == 5 and p == 0 and v == 0,
	("expired: claim_at %d is_active %d permission %d privs %d"):format(c, a, p, v))
print(("cost per guarded callback outside claims: claim_at 1, is_active 0, permission 0, privilege lookups 0"))

print(("exceptions: %s"):format(table.concat(report.exceptions, ", ")))
print(("R25 INTERACTION FIXTURE PASS checks=%d"):format(checks))
