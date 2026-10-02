-- Round 30 Lane P2 portable test (LuaJIT): mob pathing, allocation and
-- spawn ABMs (round30-plan.md §2, perf review 2026-10 #4 #6 #11 #13 #17).
--
--   luajit tools/r30_p2/portable_test.lua [REPO]
--
-- A. mobs/grug_obstacle.lua, the real file: the negative path cache (waits of
--    1, 2, 4 s for the same two nodes; a moved mob lifts the wait, a moved
--    target restarts the count; the third failure's wait ends in "give_up";
--    a found path forgets everything; the patrol nudge's variant without
--    give-up grows to 8 s and stays there), the per-step A* time budget
--    (direct claims while the step has time, the queue granted at the next
--    step, the spare-budget test of the once-a-second nudge) and the
--    collision boxes (the mob field, the per-step player cache), and the
--    path ends (a target on a slab, stair or snow aimed at from above; an end
--    still walkable is no search).
-- B. general_attack, cut out of the vendored api.lua: the mob's eye stays at
--    its own position + 1 for every candidate and its position is not moved.
-- C. the privilege cache, cut out of api.lua: one lookup per player and
--    privilege, dropped on grant, revoke and leave.
-- D. spawn_abms.lua, the real file, on a fake engine: rows of one node set
--    merge into one ABM whose trigger rate times each row's probability is
--    the row's own rate; a row runs only on its own nodes, in its own y range
--    and with its own neighbours; one roll picks at most one row per
--    trigger, the probabilities adding up to at most 1; a retired row
--    registers nothing.
-- E. spawn_policy.lua, the real file: which rows stay (underground, Kraken /
--    Angelfish, the recipes' critters, the Rift Spawn's surface row; a
--    palette zone keeps all), and the Rift Spawn's surface row keeps its
--    stated chance and cap.
-- F. aggro.lua give_up_target: an ordinary mob runs the leash reset, a king
--    or no-leash actor only drops the target, a given-up player is ignored
--    until they move; the dragons only ever wait (api.lua).
-- Prints "R30 P2 PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end

-- ---------------------------------------------------------------------------
-- A. grug_obstacle.lua
-- ---------------------------------------------------------------------------
local O = dofile(repo .. "/mods/ENTITIES/mobs/grug_obstacle.lua")
do
	local temp = {}
	local target = {}
	local mob = {x = 0, y = 5, z = 0}
	local goal = {x = 10.2, y = 5, z = 3.4}
	check(O.no_path_gate(temp, 0, target, mob, goal) == "search", "A1 fresh: search")
	O.note_search_result(temp, 0, target, mob, goal, false)
	check(O.no_path_gate(temp, 0.5, target, mob, goal) == "wait", "A1 wait 1 s")
	check(O.no_path_gate(temp, 1.0, target, mob, goal) == "search", "A1 after 1 s")
	O.note_search_result(temp, 1.0, target, mob, goal, false)
	check(O.no_path_gate(temp, 2.9, target, mob, goal) == "wait", "A1 wait 2 s")
	-- A mob on another node is another search; the count goes on.
	local moved = {x = 1.6, y = 5, z = 0}
	check(O.no_path_gate(temp, 2.9, target, moved, goal) == "search",
		"A1 a moved mob lifts the wait")
	O.note_search_result(temp, 3.0, target, moved, goal, false)
	check(temp.grug_no_path.fails == 3, "A1 the count goes on for a moved mob")
	check(O.no_path_gate(temp, 6.9, target, moved, goal) == "wait", "A1 wait 4 s")
	check(O.no_path_gate(temp, 7.0, target, moved, goal) == "give_up",
		"A1 the third failure's wait ends in give_up")
	check(temp.grug_no_path == nil, "A1 give_up forgets the state")
	-- A target that moves restarts the count.
	O.note_search_result(temp, 10, target, mob, goal, false)
	O.note_search_result(temp, 11, target, mob, goal, false)
	local goal2 = {x = 12, y = 5, z = 3}
	check(O.no_path_gate(temp, 11.5, target, mob, goal2) == "search",
		"A2 a moved target searches at once")
	check(temp.grug_no_path == nil, "A2 a moved target restarts the count")
	O.note_search_result(temp, 12, target, mob, goal2, false)
	check(temp.grug_no_path.fails == 1, "A2 counted from one again")
	-- Another target object restarts too; a found path forgets.
	check(O.no_path_gate(temp, 12.1, {}, mob, goal2) == "search", "A2 other target")
	O.note_search_result(temp, 13, target, mob, goal2, false)
	O.note_search_result(temp, 14, target, mob, goal2, true)
	check(temp.grug_no_path == nil, "A2 a found path forgets")
	-- The nudge variant: no give-up, the waits grow to 8 s and stay there.
	local now = 0
	local waits = {}
	for i = 1, 6 do
		O.note_search_result(temp, now, "nudge", mob, goal, false)
		local t = now
		while O.no_path_gate(temp, t, "nudge", mob, goal, true) == "wait" do
			t = t + 0.25
		end
		check(O.no_path_gate(temp, t, "nudge", mob, goal, true) == "search",
			"A3 nudge searches again " .. i)
		waits[i] = t - now
		now = t
	end
	check(table.concat(waits, ",") == "1,2,4,8,8,8", "A3 nudge waits " ..
		table.concat(waits, ","))
	check(O.give_up_after == 3 and O.close_searchdistance == 8,
		"A4 give up after 3, close search box 8")
end

-- Path ends: a target on a slab, a stair or snow dust stands in a walkable
-- node; the search aims at the node above. An end still walkable is no search.
do
	local solid = {}
	local function at(x, y, z) return x .. "," .. y .. "," .. z end
	local function walkable(p) return solid[at(p.x, p.y, p.z)] == true end
	solid[at(5, 3, 5)] = true -- slab, stair step or snow dust under the player
	local dest = {x = 5, y = 3, z = 5}
	check(O.fit_path_ends({x = 0, y = 3, z = 0}, dest, walkable) and dest.y == 4,
		"A8 a target in a walkable node: aimed one node up")
	dest = {x = 6, y = 3, z = 5}
	check(O.fit_path_ends({x = 0, y = 3, z = 0}, dest, walkable) and dest.y == 3,
		"A8 an ordinary target stays")
	solid[at(5, 4, 5)] = true -- a full block above too: a buried target
	dest = {x = 5, y = 3, z = 5}
	check(not O.fit_path_ends({x = 0, y = 3, z = 0}, dest, walkable),
		"A8 a buried target: no search")
	check(not O.fit_path_ends({x = 5, y = 4, z = 5}, {x = 9, y = 3, z = 9}, walkable),
		"A8 a mob inside a walkable node: no search")
end

-- Time budget.
do
	O.begin_server_step()
	local a, b, c = {}, {}, {}
	check(O.claim_path_budget(a) == true, "A5 first claim")
	O.note_path_cost(2500)
	check(O.claim_path_budget(b) == true, "A5 time left: second claim")
	O.note_path_cost(2500)
	check(O.claim_path_budget(c) == false, "A5 budget spent: queued")
	check(O.spare_path_budget() == false, "A5 no spare budget while queued")
	O.begin_server_step()
	check(O.claim_path_budget(c) == true, "A5 the queued request is granted next step")
	O.note_path_cost(100)
	check(O.spare_path_budget() == true, "A5 spare budget after a cheap search")
	O.begin_server_step()
	-- Grants follow the cost estimate: expensive searches grant fewer.
	for _ = 1, 8 do O.note_path_cost(2800) end
	O.begin_server_step()
	local q = {}
	for i = 1, 4 do q[i] = {} end
	O.note_path_cost(3000) -- the step is spent: the next claims queue
	for i = 1, 4 do check(O.claim_path_budget(q[i]) == false, "A6 queued " .. i) end
	O.begin_server_step()
	local granted = 0
	for i = 1, 4 do
		if O.claim_path_budget(q[i]) then granted = granted + 1 end
	end
	check(granted == 2, "A6 about 3 ms of 2.8 ms searches granted: " .. granted)
end

-- Collision boxes.
do
	local calls = 0
	local box = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}
	local function object(is_player, ent)
		return {
			get_properties = function() calls = calls + 1; return {collisionbox = box} end,
			get_luaentity = function() return ent end,
			is_player = function() return is_player end,
		}
	end
	local field = {-0.5, -1, -0.5, 0.5, 1, 0.5}
	local mob = {_grug_cbox = field, object = object(false)}
	check(O.mob_cbox(mob) == field and calls == 0, "A7 the mob field, no get_properties")
	local bare = {object = object(false)}
	check(O.mob_cbox(bare) == box and calls == 1, "A7 fallback without the field")
	check(O.object_cbox(object(false, {_grug_cbox = field})) == field and calls == 1,
		"A7 another mob's field")
	local player = object(true)
	O.begin_server_step()
	check(O.object_cbox(player) == box and O.object_cbox(player) == box and calls == 2,
		"A7 a player's box read once per step")
	O.begin_server_step()
	O.object_cbox(player)
	check(calls == 3, "A7 read again in the next step")
end

-- ---------------------------------------------------------------------------
-- B. general_attack eye height (cut out of api.lua)
-- ---------------------------------------------------------------------------
do
	local api = read("mods/ENTITIES/mobs/api.lua")
	local body = api:match("\nfunction mob_class:general_attack%(%)\n(.-)\nend\n")
	check(body ~= nil, "B general_attack found")
	local env = {
		damage_enabled = true, creatura = false,
		is_player = function(o) return o.player end,
		is_invisible = function() return false end,
		is_peaceful_player = function() return false end,
		check_for = function() return false end,
		random = function() return 100 end,
		pairs = pairs,
	}
	function env.get_distance(a, b)
		local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(x * x + y * y + z * z)
	end
	local src = "local mob_class = {}\nfunction mob_class:general_attack()\n" ..
		body .. "\nend\nreturn mob_class"
	local chunk = assert(loadstring(src))
	setfenv(chunk, setmetatable(env, {__index = _G}))
	local GA = chunk().general_attack
	local mob_pos = {x = 0, y = 10, z = 0}
	local eyes, distances = {}, {}
	local function candidate(x, z)
		return {player = true,
			get_pos = function() return {x = x, y = 10, z = z} end,
			get_player_name = function() return "p" .. x end,
			get_luaentity = function() return nil end}
	end
	-- Farthest first: a candidate is looked at only when it is closer.
	local cands = {candidate(-5, 0), candidate(0, 4), candidate(3, 0)}
	local self = {
		view_range = 16, attack_players = true, attack_chance = 0,
		state = "stand",
		day_docile = function() return false end,
		object = {get_pos = function() return mob_pos end},
		line_of_sight = function(_, a, b)
			eyes[#eyes + 1] = a.y
			distances[#distances + 1] = b.y
			return true
		end,
		do_attack = function(s, target) s.target = target end,
	}
	env.core = {get_objects_inside_radius = function() return cands end}
	GA(self)
	check(#eyes == 3, "B three candidates looked at")
	check(eyes[1] == 11 and eyes[2] == 11 and eyes[3] == 11,
		"B the eye stays at y + 1: " .. table.concat(eyes, ","))
	check(mob_pos.y == 10, "B the mob's position is not moved")
	check(self.target == cands[3], "B the closest candidate is attacked")
end

-- ---------------------------------------------------------------------------
-- C. privilege cache (cut out of api.lua)
-- ---------------------------------------------------------------------------
do
	local api = read("mods/ENTITIES/mobs/api.lua")
	local block = api:match("\n(local grug_priv_cache = {}.-\nfunction mobs.is_creative%(name%).-\nend\n)")
	check(block ~= nil, "C privilege cache block found")
	local lookups = 0
	local privs = {anna = {peaceful_player = true}}
	local grants, revokes, leaves = {}, {}, {}
	local env = {
		creative_cache = false,
		mobs = {},
		core = {
			check_player_privs = function(name, priv)
				lookups = lookups + 1
				return (privs[name] or {})[priv] == true
			end,
			register_on_priv_grant = function(f) grants[#grants + 1] = f end,
			register_on_priv_revoke = function(f) revokes[#revokes + 1] = f end,
			register_on_leaveplayer = function(f) leaves[#leaves + 1] = f end,
		},
	}
	local chunk = assert(loadstring(block))
	setfenv(chunk, setmetatable(env, {__index = _G}))
	chunk()
	local M = env.mobs
	check(M.has_priv("anna", "peaceful_player") == true, "C first answer")
	check(M.has_priv("anna", "peaceful_player") == true and lookups == 1,
		"C second answer from the cache")
	check(M.has_priv("bert", "peaceful_player") == false and lookups == 2,
		"C another player looks up")
	check(M.is_creative("bert") == false and M.is_creative("bert") == false
		and lookups == 3, "C creative cached too")
	privs.bert = {creative = true}
	check(grants[1]("bert", "admin", "creative") == true,
		"C the grant callback returns true (later callbacks still run)")
	check(M.is_creative("bert") == true and lookups == 4, "C a grant drops the cache")
	privs.anna = {}
	revokes[1]("anna", "admin", "peaceful_player")
	check(M.has_priv("anna", "peaceful_player") == false, "C a revoke drops the cache")
	local n = lookups
	leaves[1]({get_player_name = function() return "anna" end})
	M.has_priv("anna", "peaceful_player")
	check(lookups == n + 1, "C leaving drops the cache")
end

-- ---------------------------------------------------------------------------
-- D. spawn_abms.lua on a fake engine
-- ---------------------------------------------------------------------------
local GROUPS = {["default:stone"] = {stone = 1}, ["grug_materials:t2_stone"] = {grug_stratum = 1},
	["grug_materials:t6_stone"] = {grug_stratum = 1}}
local function fake_engine()
	local abms, loaded = {}, {}
	_G.core = {
		register_abm = function(spec) abms[#abms + 1] = spec end,
		register_on_mods_loaded = function(f) loaded[#loaded + 1] = f end,
		log = function() end,
		get_item_group = function(name, group)
			return GROUPS[name] and GROUPS[name][group] or 0
		end,
		find_node_near = function() return nil end,
	}
	_G.mobs = {}
	return abms, loaded
end
do
	local abms, loaded = fake_engine()
	local kept_ask = {}
	_G.grug_mobs = {spawn_row_kept = function(name, max_y)
		kept_ask[#kept_ask + 1] = name
		return name ~= "retired"
	end}
	-- spawn_abms.lua keeps math.random as a local: a scripted roll first.
	local seq = {}
	local real_random = math.random
	math.random = function() return table.remove(seq, 1) or 0 end
	dofile(repo .. "/mods/ENTITIES/grug_mobs/spawn_abms.lua")
	math.random = real_random
	local ran = {}
	local function row(name, nodes, neighbors, interval, chance, min_y, max_y)
		mobs.register_spawn_abm({nodenames = nodes, neighbors = neighbors,
			interval = interval, chance = chance, min_y = min_y, max_y = max_y,
			action = function(pos, node)
				ran[#ran + 1] = name .. "@" .. node.name .. "@" .. pos.y
				pos.y = pos.y + 1 -- spawn_action moves its position
			end}, name)
	end
	row("bat", {"default:stone", "group:grug_stratum"}, {"air"}, 20, 2200, -31000, -40)
	row("golem", {"default:stone", "group:grug_stratum"}, {"air"}, 30, 9000, -31000, -40)
	row("mite", {"group:grug_stratum"}, {"air"}, 20, 2000, -31000, -700)
	row("kraken", {"default:water_source"}, {"air"}, 60, 9231, -10, 4)
	row("angelfish", {"default:water_source"}, {"default:sand"}, 30, 4000, -30, 600)
	row("rabbit", {"default:dirt_with_grass"}, {"air"}, 20, 1385, 0, 600)
	row("retired", {"default:dirt_with_grass"}, {"air"}, 20, 1000, 0, 600)
	check(#abms == 0, "D nothing registered before mods_loaded")
	loaded[1]()
	check(#abms == 3, "D three merged ABMs: " .. #abms)
	local by_label = {}
	for _, spec in ipairs(abms) do by_label[spec.label] = spec end
	local under = by_label["grug_mobs underground spawning"]
	local water = by_label["grug_mobs water spawning"]
	local surface = by_label["grug_mobs surface spawning"]
	check(under and water and surface, "D one ABM per node set")
	-- C = floor(1 / sum(I / (c x i))): bat 1/2200, golem 20/(9000*30),
	-- mite 1/2000 -> 1 / 0.0010286 = 972.
	check(under.interval == 20 and under.chance == 972 and under.catch_up == false,
		"D underground interval 20, chance 972: " .. under.chance)
	check(under.min_y == -31000 and under.max_y == -40, "D underground y hull")
	check(water.interval == 30 and water.min_y == -30 and water.max_y == 600,
		"D water interval and y hull")
	local nb = table.concat(water.neighbors, ",")
	check(nb == "air,default:sand" or nb == "default:sand,air", "D water neighbours: " .. nb)
	-- Rates: merged trigger rate x row probability = the row's own rate, and
	-- the probabilities of one group add up to at most 1.
	local D = grug_mobs.merge_spawn_rates
	for _, rows in ipairs({
		{{chance = 2200, interval = 20}, {chance = 9000, interval = 30},
			{chance = 2000, interval = 20}},
		{{chance = 1600, interval = 20}, {chance = 1800, interval = 20},
			{chance = 9000, interval = 30}, {chance = 2400, interval = 20},
			{chance = 5000, interval = 30}, {chance = 2200, interval = 20}},
		{{chance = 9231, interval = 60}, {chance = 4000, interval = 30}},
	}) do
		local interval, chance = D(rows)
		local sum = 0
		for _, r in ipairs(rows) do
			local merged = r.p / (chance * interval)
			local own = 1 / (r.chance * r.interval)
			check(math.abs(merged - own) / own < 1e-9, "D rate kept for chance " .. r.chance)
			sum = sum + r.p
		end
		check(sum <= 1 and sum > 0.99, "D probabilities add up to at most 1: " .. sum)
	end
	-- Dispatch: one roll picks at most one row by cumulative p among the rows
	-- hosted on the node; the picked row runs only in its own y range and
	-- with its own neighbours.
	local P = {}
	for _, spec in ipairs(abms) do P[spec.label] = spec end
	local function run(spec, roll, pos, node_name)
		ran = {}
		seq[1] = roll
		for i = #seq, 2, -1 do seq[i] = nil end
		spec.action(pos, {name = node_name}, 0, 0)
		return table.concat(ran, " ")
	end
	-- Underground p: bat 972/2200 = 0.442, golem 972*20/270000 = 0.072,
	-- mite 0.486 (on strata only).
	check(run(under, 0.0, {x = 1, y = -100, z = 2}, "default:stone") ==
		"bat@default:stone@-100", "D low roll on stone: the bat")
	check(run(under, 0.45, {x = 1, y = -100, z = 2}, "default:stone") ==
		"golem@default:stone@-100", "D next band on stone: the golem")
	check(run(under, 0.6, {x = 1, y = -100, z = 2}, "default:stone") == "",
		"D past the stone rows' sum: nothing (the mite never on stone)")
	check(run(under, 0.6, {x = 1, y = -800, z = 2}, "grug_materials:t2_stone") ==
		"mite@grug_materials:t2_stone@-800", "D the mite on strata at -800")
	check(run(under, 0.6, {x = 1, y = -100, z = 2}, "grug_materials:t2_stone") == "",
		"D the picked mite above its y range: nothing, no other row")
	-- At most one row per trigger over many rolls.
	local most = 0
	for k = 0, 99 do
		local r = run(under, k / 100, {x = 1, y = -800, z = 2}, "grug_materials:t2_stone")
		local n = 0
		for _ in r:gmatch("%S+") do n = n + 1 end
		if n > most then most = n end
	end
	check(most == 1, "D at most one row per trigger")
	-- Neighbours: the angelfish needs sand, the kraken air. Water p:
	-- kraken 0.178, angelfish 0.822 (C = 3287).
	local near = {}
	core.find_node_near = function(_, _, list)
		for _, n in ipairs(list) do if near[n] then return {} end end
	end
	near = {air = true}
	check(run(water, 0.1, {x = 0, y = 1, z = 0}, "default:water_source") ==
		"kraken@default:water_source@1", "D water by air: the kraken")
	check(run(water, 0.9, {x = 0, y = 1, z = 0}, "default:water_source") == "",
		"D water by air, angelfish picked: nothing")
	near = {["default:sand"] = true}
	check(run(water, 0.9, {x = 0, y = -5, z = 0}, "default:water_source") ==
		"angelfish@default:water_source@-5", "D water by sand: the angelfish")
	check(#surface.nodenames == 1, "D the retired row adds no node")
	local errored = not pcall(row, "late", {"default:stone"}, {"air"}, 20, 100, -31000, -40)
	check(errored, "D a row after the merge is an error")
end

-- ---------------------------------------------------------------------------
-- E. spawn_policy.lua: kept rows and the Rift Spawn's exact surface row
-- ---------------------------------------------------------------------------
do
	local critters = {zone_a = {rabbit = true}}
	local recipe = {zone_a = true, zone_b = true}
	local function load_policy()
		_G.grug_mobs = {spawn_regions = {
			fallback_palettes = function() return {}, {}, {} end,
			zone_ids = function()
				local ids = {}
				for id in pairs(recipe) do ids[#ids + 1] = id end
				table.sort(ids)
				return ids
			end,
			zone_has_recipe = function(id) return recipe[id] == true end,
			zone_critter = function(id, name)
				return critters[id] and critters[id][name:gsub("^grug_mobs:", "")] or false
			end,
		}}
		_G.grug_core = {DAY_PHASE_START = 0.1875, DAY_PHASE_END = 0.8125}
		_G.grug_zones = {}
		_G.core = {log = function() end}
		dofile(repo .. "/mods/ENTITIES/grug_mobs/spawn_policy.lua")
		return grug_mobs
	end
	local G = load_policy()
	check(G.spawn_row_kept("grug_mobs:cave_bat", -40), "E underground kept")
	check(G.spawn_row_kept("grug_mobs:kraken", 4), "E Kraken kept")
	check(G.spawn_row_kept("grug_mobs:reed_angelfish", 600), "E Angelfish kept")
	check(G.spawn_row_kept("grug_mobs:rift_spawn", 600), "E Rift Spawn surface kept")
	check(G.spawn_row_kept("grug_mobs:rabbit", 600), "E a recipe's critter kept")
	check(not G.spawn_row_kept("grug_mobs:wolf", 600), "E a surface hunter retired")
	check(not G.spawn_row_kept("grug_mobs:shore_crab", 20), "E the shore crab retired")
	check(not G.spawn_row_kept("grug_mobs:stone_golem", 300),
		"E a surface golem row retired")
	recipe.zone_b = false
	check(G.spawn_row_kept("grug_mobs:wolf", 600), "E a palette zone keeps every row")
	recipe.zone_b = true
	-- The Rift Spawn's surface row keeps its stated chance and cap; an
	-- ordinary ambient night row still gets the Round 16 scaling.
	G.register_spawn_role("grug_mobs:rift_spawn", {clock = "night", type = "monster",
		_grug_tier = "normal"})
	G.register_spawn_role("grug_mobs:kraken", {clock = "any", type = "monster",
		_grug_tier = "normal"})
	local rift = G.prepare_spawn_row({name = "grug_mobs:rift_spawn", chance = 4000,
		active_object_count = 3, min_height = 0, max_height = 600})
	check(rift.chance == 4000 and rift.active_object_count == 3,
		"E Rift Spawn row exact: " .. rift.chance .. " / " .. rift.active_object_count)
	check(rift.max_light == 5 and rift.day_toggle == false, "E Rift Spawn night clock")
	local kraken = G.prepare_spawn_row({name = "grug_mobs:kraken", chance = 12000,
		active_object_count = 1, min_height = -10, max_height = 4})
	check(kraken.chance == 9231 and kraken.active_object_count == 1,
		"E Kraken keeps the Round 16 scaling: " .. kraken.chance)
	check(G.zone_density_cast == nil and G.density_budgeted == nil,
		"E the palette budget is gone")
end

-- ---------------------------------------------------------------------------
-- F. aggro.lua give_up_target (cut out): who resets and who only drops
-- ---------------------------------------------------------------------------
do
	local src = read("mods/ENTITIES/grug_mobs/aggro.lua")
	local block = src:match("\n(local function node_of%(pos%).-\nfunction grug_mobs.gave_up_on%(self, player%).-\nend\n)")
	check(block ~= nil, "F give_up_target block found")
	local resets = 0
	local env = {grug_mobs = {leash_reset = function() resets = resets + 1 end},
		core = {is_player = function(o) return o.player == true end}}
	local chunk = assert(loadstring(block))
	setfenv(chunk, setmetatable(env, {__index = _G}))
	chunk()
	local G = env.grug_mobs
	local function mob(fields)
		local m = {stopped = 0, attack = {player = true,
			get_pos = function() return {x = 1.2, y = 7, z = -3.6} end,
			get_player_name = function() return "anna" end}}
		function m:stop_attack() self.stopped = self.stopped + 1 end
		for k, v in pairs(fields or {}) do m[k] = v end
		return m
	end
	local plain = mob()
	G.give_up_target(plain)
	check(resets == 1 and plain.stopped == 0, "F an ordinary mob runs the leash reset")
	local king = mob({_grug_royal_king = true, _grug_boss_id = "king:human"})
	G.give_up_target(king)
	check(resets == 1 and king.stopped == 1, "F a king only drops the target")
	local royal = mob({_grug_no_leash = true})
	G.give_up_target(royal)
	check(resets == 1 and royal.stopped == 1, "F a no-leash actor only drops the target")
	local player = {get_player_name = function() return "anna" end,
		get_pos = function() return {x = 1.4, y = 7.2, z = -3.9} end}
	check(G.gave_up_on(plain, player), "F the same node stays ignored")
	player.get_pos = function() return {x = 2.6, y = 7, z = -3.6} end
	check(not G.gave_up_on(plain, player) and plain.temp.grug_gave_up == nil,
		"F a moved player is a target again")
	-- The dragons never reach give_up_target: api.lua passes keep_flying as
	-- the gate's no-give-up flag.
	local api = read("mods/ENTITIES/mobs/api.lua")
	check(api:find("self.attack, s, target_pos, self.keep_flying == true)", 1, true) ~= nil,
		"F flying actors (dragons, whelps) only wait")
end

print("R30 P2 PORTABLE PASS checks=" .. checks)
