-- Round 59 lane QSYS3 portable test (LuaJIT): the quest-system contract the
-- band and chapter lanes build on (round59-plan.md §2a, §4 QSYS3;
-- quests.md "Story and free play" and "Objectives"):
--   A. the settlement socket registry takes the town place role
--      `quest_place` (grug_core settlement_sockets.lua);
--   B. tools/r59_qsys3/socket_places.lua builds a settlement's sockets from
--      its templates and blueprints as the mapgen does: a capital plot's
--      socket carries its plot id, a required plot's is built on every
--      world, another plot's not; a fixture socket in a template copy
--      (Highcourt's Miner's Guild house and lore shrine) appears;
--   C. the town place `socket:<settlement key>/<socket id>` resolves through
--      the registry (labels.lua Q.use_place): its name, its standing cell;
--      refused: no such settlement, no such socket, another role, a plot
--      not built on every world, a malformed ref;
--   D. the quest object stands in the socket's own cell (use.lua): under a
--      roof as in a yard, no column search; the n-th act on its ring offset
--      when that cell is free, else in the socket's cell; a filled cell
--      gives no stand, an unloaded one waits; the per-player pass adds it at
--      the socket for a player within reach;
--   E. the load check refuses a bad town place (E-use-place) and accepts a
--      good one; the label reads "<act> at <settlement>";
--   F. E-free-follow-ups per faction (validate.lua V.free_follow_ups): one
--      follow-up per faction passes, two of one faction do not, a
--      follow-up of both factions counts in each, a giver of no faction
--      for both.
--
--   luajit tools/r59_qsys3/portable_test.lua [REPO]
-- Prints "R59 QSYS3 PORTABLE PASS checks=<n>" or the failures (exit 1).
local ROOT = arg and arg[1] or "."

local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. ("%q"):format(tostring(actual)) ..
		", expected " .. ("%q"):format(tostring(expected)) .. ")")
end
local function has(text, part, label)
	return check(type(text) == "string" and text:find(part, 1, true) ~= nil,
		label .. " (missing " .. ("%q"):format(part) .. " in " .. ("%q"):format(tostring(text)) .. ")")
end

------------------------------------------------------------------------------
-- Engine surface.
------------------------------------------------------------------------------
local nodes = {} -- "x,y,z" -> node name; unset: air; `unloaded`: nil
local unloaded = false
local logged, added = {}, {}
local entities = {}
local terrain_asked = 0
local globalsteps, changes = {}, {}
core = {
	registered_nodes = {["default:stone"] = {walkable = true}, ["default:wood"] = {walkable = true},
		air = {walkable = false}, ["default:water_source"] = {walkable = false, liquidtype = "source"}},
	registered_entities = entities,
	get_modpath = function(name)
		return ({grug_quests = ROOT .. "/mods/PLAYER/grug_quests",
			grug_mapgen = ROOT .. "/mods/MAPGEN/grug_mapgen"})[name]
	end,
	get_current_modname = function() return "grug_quests" end,
	parse_json = function(text)
		return dofile(ROOT .. "/tools/r28_b4_quests/json.lua").decode(text)
	end,
	get_us_time = function() return 0 end,
	log = function(level, text) logged[#logged + 1] = level .. " " .. text end,
	get_item_group = function() return 0 end,
	dir_to_yaw = function(dir) return math.atan2(-dir.x, dir.z) end,
	get_node_or_nil = function(pos)
		if unloaded then return nil end
		return {name = nodes[pos.x .. "," .. pos.y .. "," .. pos.z] or "air"}
	end,
	register_entity = function(name, def) entities[name] = def end,
	add_entity = function(pos, name)
		local object = {pos = pos, valid = true, props = {}}
		local ent = setmetatable({object = object}, {__index = entities[name]})
		function object:is_valid() return self.valid end
		function object:get_pos() return self.pos end
		function object:remove() self.valid = false end
		function object:get_luaentity() return ent end
		function object:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
		function object:set_observers(o) self.observers = o end
		added[#added + 1] = object
		return object
	end,
	register_on_player_hpchange = function() end,
	register_on_dieplayer = function() end,
	register_on_joinplayer = function() end,
	register_on_leaveplayer = function() end,
	register_globalstep = function(fn) globalsteps[#globalsteps + 1] = fn end,
}
vector = {
	new = function(x, y, z)
		if type(x) == "table" then return {x = x.x, y = x.y, z = x.z} end
		return {x = x, y = y, z = z}
	end,
	distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end,
}
grug_zones = {
	id_at = function() return "elandor_highcourt" end,
	terrain_height_at = function() terrain_asked = terrain_asked + 1; return 0 end,
}
grug_mobs = {spawn_regions = {LEADER_RANGE = 48, clash_site = function() return nil end,
	zone_place = function() return nil end, place_spot = function() return nil end}}

------------------------------------------------------------------------------
-- A. The registry takes the town place role.
------------------------------------------------------------------------------
grug_core = {plain_text = function(text) return text end}
dofile(ROOT .. "/mods/CORE/grug_core/settlement_sockets.lua")
do
	local ok, err = pcall(grug_core.register_settlement_sockets, "r59_fixture_yard", "human", {x = 0, y = 0, z = 0},
		{{id = "crate_yard", role = "quest_place", x = 1, y = 1, z = 2, dir = {x = 0, z = 1}}}, "Fixture Yard")
	check(ok, "A the registry takes a quest_place socket: " .. tostring(err))
	local socket = grug_core.settlement_sockets_at("r59_fixture_yard")[1]
	eq(socket and socket.role, "quest_place", "A ... and keeps its role")
	ok = pcall(grug_core.register_settlement_sockets, "r59_fixture_bad", "human", {x = 0, y = 0, z = 0},
		{{id = "x", role = "quest_spot", x = 1, y = 1, z = 2, dir = {x = 0, z = 1}}})
	check(not ok, "A an unknown role still fails the registration")
end
local registry_core = grug_core

------------------------------------------------------------------------------
-- B. The settlements' sockets from their templates (socket_places.lua).
------------------------------------------------------------------------------
local PLACES = dofile(ROOT .. "/tools/r59_qsys3/socket_places.lua")
eq(PLACES.PREFIX, "socket:", "B the ref prefix")
do
	local key, id = PLACES.parse_ref("socket:highcourt/miners_guild/miners_guild_cellar")
	eq(key .. "|" .. id, "highcourt|miners_guild/miners_guild_cellar", "B a ref names the settlement and socket")
	check(PLACES.parse_ref("socket:cellar") == nil and PLACES.parse_ref("highcourt/cellar") == nil,
		"B ... and nothing else is one")
end
local found = PLACES.sockets(ROOT, {"highcourt", "goldmead_village"})
local function socket_of(rows, key, id)
	for _, socket in ipairs(rows[key] and rows[key].sockets or {}) do
		if socket.id == id then return socket end
	end
end
do
	local leader = socket_of(found, "highcourt", "miners_guild/miners_guild_leader")
	check(leader and leader.role == "quest" and leader.required, "B Highcourt's guild leader socket: a plot " ..
		"socket with its plot id, built on every world")
	local shrine = socket_of(found, "highcourt", "lore_shrine/lore_shrine_quest")
	check(shrine and not shrine.required, "B the lore shrine's socket: a plot not every world builds")
	check(socket_of(found, "goldmead_village", "quest_steward") ~= nil, "B a village's blueprint sockets")
	eq(found.goldmead_village.label, "Goldmead Village", "B ... and its name")
	local shipped = 0
	for _, socket in ipairs(found.highcourt.sockets) do
		if socket.role == "quest_place" then shipped = shipped + 1 end
	end
	eq(shipped, 0, "B no shipped Highcourt socket is a town place yet (the content lanes add them)")
end
-- A template copy with two fixture sockets: read through io.open, as the
-- game's template loader reads (wp13/templates.lua).
local FIXTURE_SOCKETS = {
	["highcourt_miners_guild.tpl"] = "sockets 3 1 12 face=1 id={id}_cellar role=quest_place",
	["highcourt_lore_shrine.tpl"] = "sockets 6 1 10 face=2 id={id}_vault role=quest_place",
}
local real_open = io.open
io.open = function(path, mode)
	local name = type(path) == "string" and path:match("/templates/([%w_]+%.tpl)$")
	if name and FIXTURE_SOCKETS[name] then
		local handle = real_open(path, mode)
		local text = handle:read("*a")
		handle:close()
		local head, tail = text:match("^(.*\n)end\n(.-)$")
		text = head .. FIXTURE_SOCKETS[name] .. "\nend\n" .. tail
		return {read = function() return text end, close = function() end}
	end
	return real_open(path, mode)
end
local town = PLACES.sockets(ROOT, {"highcourt"})
-- A harness's stand-in extended by the town places a quest file names.
local stub = {settlement_sockets_at = function() return {{id = "hall_quest", role = "quest"}} end}
local QUEST_FILE = ROOT .. "/r59_fixture_zones/r59_fixture.quests.json"
local fixture_open = io.open
io.open = function(path, mode)
	if path == QUEST_FILE then
		local text = '{"quests": [{"objectives": [{"type": "use", "place": "socket:highcourt/miners_guild/' ..
			'miners_guild_cellar"}]}]}'
		return {read = function() return text end, close = function() end}
	end
	return fixture_open(path, mode)
end
PLACES.extend(stub, ROOT, ROOT .. "/r59_fixture_zones", function() return {"r59_fixture.quests.json", "x.txt"} end)
io.open = real_open
do
	local listed, roles = {}, {}
	for _, row in ipairs(stub.settlement_socket_settlements()) do
		listed[#listed + 1] = row.key .. "=" .. row.display_name
	end
	for _, row in ipairs(stub.settlement_sockets_at("highcourt")) do
		roles[#roles + 1] = row.id .. "=" .. row.role
	end
	eq(table.concat(listed, ","), "highcourt=Highcourt", "B a harness's stand-in gains the named settlement")
	eq(table.concat(roles, ","), "hall_quest=quest,miners_guild/miners_guild_cellar=quest_place," ..
		"lore_shrine/lore_shrine_vault=quest_place",
		"B ... and its town places beside its own sockets")
	local empty = {}
	PLACES.extend(empty, ROOT, ROOT .. "/r59_fixture_zones", function() return {} end)
	check(empty.settlement_sockets_at == nil, "B ... and nothing changes when no file names one")
end
do
	local cellar = socket_of(town, "highcourt", "miners_guild/miners_guild_cellar")
	check(cellar and cellar.role == "quest_place" and cellar.required, "B a template's quest_place socket " ..
		"in the guild house: listed, built on every world")
	local vault = socket_of(town, "highcourt", "lore_shrine/lore_shrine_vault")
	check(vault and vault.role == "quest_place" and not vault.required, "B ... and one in the lore shrine: not")
end

------------------------------------------------------------------------------
-- C. The town place through the registry (labels.lua).
------------------------------------------------------------------------------
grug_core = PLACES.registry(town)
grug_core.plain_text = function(text) return text end
grug_core.feed = function() return true end
grug_quests = {register_on_change = function(fn) changes[#changes + 1] = fn end}
local Q = grug_quests
dofile(ROOT .. "/mods/PLAYER/grug_quests/labels.lua")
dofile(ROOT .. "/mods/PLAYER/grug_quests/use.lua")
eq(Q.TOWN_PLACE_PREFIX, "socket:", "C the game's ref prefix is the tool's")
eq(Q.TOWN_PLACE_ROLE, "quest_place", "C the socket role")
local CELLAR = "socket:highcourt/miners_guild/miners_guild_cellar"
local cellar_socket = socket_of(town, "highcourt", "miners_guild/miners_guild_cellar")
do
	local place, reason = Q.use_place(CELLAR, "elandor_goldmead_vale")
	check(place ~= nil, "C the guild house's cellar resolves: " .. tostring(reason))
	eq(place and place.ref, CELLAR, "C ... its canonical ref is the ref (no zone is added)")
	eq(place and place.name, "Highcourt", "C ... its name is the settlement's")
	eq(place and place.zone, "elandor_highcourt", "C ... its zone the settlement's")
	check(place and place.town and place.pos.x == cellar_socket.x and place.pos.y == cellar_socket.y and
		place.pos.z == cellar_socket.z, "C ... and it carries the socket's standing cell")
	for _, case in ipairs({
		{"socket:no_such_town/cellar", "no settlement no_such_town", "an unknown settlement"},
		{"socket:highcourt/miners_guild/miners_guild_attic", "has no socket", "an unknown socket"},
		{"socket:highcourt/miners_guild/miners_guild_leader", "is a quest socket, not a quest_place",
			"a quest giver's socket"},
		{"socket:highcourt/lore_shrine/lore_shrine_vault", "is not built on every world",
			"a plot not every world builds"},
		{"socket:Highcourt/cellar", "a town place is socket:", "a malformed ref"},
	}) do
		local refused, why = Q.use_place(case[1])
		check(refused == nil, "C refused: " .. case[3])
		has(why, case[2], "C ... with its reason")
	end
end

------------------------------------------------------------------------------
-- D. The quest object stands in the socket's cell (use.lua).
------------------------------------------------------------------------------
local xz = Q.use_place_xz(CELLAR)
check(xz and xz.town and xz.x == cellar_socket.x and xz.y == cellar_socket.y and xz.z == cellar_socket.z,
	"D the map's place lookup gives the standing cell")
local function set(x, y, z, name) nodes[x .. "," .. y .. "," .. z] = name end
local cx, cy, cz = xz.x, xz.y, xz.z
-- A cellar: a floor under every cell, a ceiling two nodes up, a wall east.
for dx = -3, 3 do
	for dz = -3, 3 do
		set(cx + dx, cy - 1, cz + dz, "default:stone")
		set(cx + dx, cy + 2, cz + dz, "default:wood")
	end
end
set(cx + 2, cy, cz, "default:stone")
do
	local pos = Q._use_town_stand(xz, {0, 0})
	check(pos and pos.x == cx and pos.y == cy and pos.z == cz, "D under a roof: the socket's own cell")
	pos = Q._use_town_stand(xz, {2, 0})
	check(pos and pos.x == cx and pos.z == cz, "D the second act's ring cell is a wall: the socket's cell")
	pos = Q._use_town_stand(xz, {0, 2})
	check(pos and pos.x == cx and pos.z == cz + 2 and pos.y == cy, "D ... a free ring cell: there, at its height")
	set(cx, cy, cz, "default:stone")
	pos = Q._use_town_stand(xz, {0, 0})
	check(pos == nil, "D a filled socket cell gives no stand")
	set(cx, cy, cz, nil)
	set(cx, cy, cz, "default:water_source")
	check(Q._use_town_stand(xz, {0, 0}) == nil, "D ... nor does water")
	set(cx, cy, cz, nil)
	unloaded = true
	local none, why = Q._use_town_stand(xz, {0, 0})
	check(none == nil and why == "unloaded", "D an unloaded cell waits")
	unloaded = false
end
-- The per-player pass: a player within reach who still needs the act.
local objective = {type = "use", place = CELLAR, object = "toll_box", label = "Search the cellar", hold = 3,
	count = 1, place_name = "Highcourt"}
Q.use_key = function(o) return o.place .. "|" .. o.object .. "|" .. o.label end
Q.use_needs = function() return {objective} end
local player = {}
function player:get_player_name() return "ann" end
function player:get_hp() return 20 end
function player:get_pos() return {x = cx + 20, y = cy + 6, z = cz - 10} end
terrain_asked = 0
Q.use_pass(player)
local object = added[#added]
local size = Q.use_objects.toll_box.size
check(object and object.pos.x == cx and object.pos.z == cz and object.pos.y == cy - 0.5 + size / 2,
	"D the pass adds the object in the socket's cell")
eq(object and object.props.nametag, "Search the cellar", "D ... named by the act")
check(object and object.observers and object.observers.ann, "D ... seen by the player who needs it")
eq(terrain_asked, 0, "D ... with no column search (no terrain height asked)")
eq(Q.objective_action(objective), "Search the cellar at Highcourt", "E the act reads \"<act> at <settlement>\"")

------------------------------------------------------------------------------
-- E. The load check.
------------------------------------------------------------------------------
dofile(ROOT .. "/mods/PLAYER/grug_quests/validate.lua")
local V = Q.validate
local function files_with(place)
	return {{name = "elandor_highcourt.quests.json", zone = "elandor_highcourt", front = false, data = {
		zone = "elandor_highcourt", quests = {{id = "r59_cellar", line = "chapter", giver = "r59_leader",
			turnin = "r59_leader", min_level = 20, level = 20, title = "The Cellar",
			text = "Search the cellar. Then come back.",
			objectives = {{type = "use", place = place, object = "toll_box", label = "Search the cellar",
				hold = 3}}, rewards = {weight = 1}}}}}}
end
local world = setmetatable({use_place = Q.use_place, npc_faction = function() return "accord" end,
	npc_race = function() return "human" end, capital = function() return true end},
	{__index = function() return function() return nil end end})
local function world_codes(place)
	local found_errors = V.world(files_with(place), world)
	return table.concat(found_errors, " | ")
end
eq(world_codes(CELLAR), "", "E a town place in the guild house passes the load check")
has(world_codes("socket:highcourt/miners_guild/miners_guild_leader"), "[E-use-place]",
	"E a quest giver's socket is refused")
has(world_codes("socket:highcourt/lore_shrine/lore_shrine_vault"), "is not built on every world;",
	"E ... and so is a plot not every world builds")

------------------------------------------------------------------------------
-- F. E-free-follow-ups per faction.
------------------------------------------------------------------------------
local FACTION = {accord_giver = "accord", throng_giver = "throng"}
local function quest(id, requires, givers)
	local row = {id = id, requires = requires}
	if givers then
		row.variants = {{zone = "z", givers = givers}}
	else
		row.giver = "accord_giver"
	end
	return row
end
local function follow_ups(quests)
	local file = {name = "z.quests.json", zone = "z", data = {reworked = true, quests = quests}}
	local errors = {}
	V.free_follow_ups(errors, V.each_quest({file}), function(npc) return FACTION[npc] end)
	return table.concat(errors, " | ")
end
eq(follow_ups({quest("a"), quest("b", {"a"}, {"accord_giver"}), quest("c", {"a"}, {"throng_giver"})}), "",
	"F one follow-up per faction passes")
has(follow_ups({quest("a"), quest("b", {"a"}), quest("c", {"a"}, {{role = "foreman", faction = "accord"}})}),
	"not 2 for The Accord (b, c); only story quests chain [E-free-follow-ups]", "F two of one faction do not")
has(follow_ups({quest("a"), quest("b", {"a"}), quest("c", {"a"}, {"accord_giver", "throng_giver"})}),
	"not 2 for The Accord", "F a follow-up of both factions counts in each")
has(follow_ups({quest("a"), quest("b", {"a"}, {"throng_giver"}), quest("c", {"a"}, {"nobody"})}),
	"not 2 for The Throng", "F a giver of no faction counts for both")
eq(follow_ups({quest("a"), quest("b", {"a"}), quest("c", {"a"})}):find("Throng", 1, true), nil,
	"F ... and the faction named is the one that has two")

if failures > 0 then
	error(("R59 QSYS3 PORTABLE FAIL %d of %d checks"):format(failures, checks), 0)
end
print(("R59 QSYS3 PORTABLE PASS checks=%d"):format(checks))
