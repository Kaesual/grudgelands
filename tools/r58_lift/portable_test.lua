-- Round 58 lane LIFT portable test (LuaJIT): the Miner's Guild lift
-- (grug_guild/lift.lua over grug_mapgen:guild_lift) and the picked drop 02
-- art.
--
--   luajit tools/r58_lift/portable_test.lua REPO
--
-- A. The registration on the whole game's load (tools/r57_details/
--    game_harness.lua): the lift's static fields (nodebox with the picked
--    node box, a full-node selection box, paramtype light, 4dir, light 3,
--    not floodable, no ground content, none of the digest's groups), its six
--    faces in the tile order +Y, -Y, +X, -X, +Z, -Z, the right-click
--    grug_guild's; the shipped art byte-identical to the picks
--    (tools/r58_lift/art/picks.txt); the reputation icon in its seam; the
--    map window's markers for mining camps and camps under construction
--    while the baked minimap keeps the kinds' 6 px icons.
-- B. The lift on a fake engine with the real modules (the camp module, the
--    room module over a placement table, grug_home/travel.lua, the faction
--    service line, the settlement socket registry fed by the real camp
--    blueprints): the override touches only on_rightclick (the semantic
--    digest's fields stay as main and emerge read them); the camp found from
--    its surface lift and from every room lift (36 camps, 148 rooms), the
--    list the surface plus levels 1..tier with the current one marked; own
--    faction travels, the enemy (in a room too) and a character without a
--    faction get the refusal line; every room's arrival is safe and every
--    camp's surface arrival is the deck cell in front of its lift, never a
--    built cell; the front follows param2 (0 -z, 1 -x, 2 +z, 3 +x), then the
--    back, then nothing; the waystones' rules (alive, out of combat, at the
--    lift, one trip at a time, combat during the emerge cancels, no
--    cooldown, the mount left behind); a T4 camp and a T6 war camp ridden to
--    every level and back; nothing written to player meta.
-- Prints "R58 LIFT PORTABLE PASS checks=<n>" or raises on the first failure.

local repo = assert(arg and arg[1], "usage: luajit portable_test.lua REPO")
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. ": expected " .. tostring(expected) ..
		", got " .. tostring(actual))
end
local function read(path)
	local handle = io.open(path, "rb")
	if not handle then return nil end
	local data = handle:read("*a")
	handle:close()
	return data
end
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local sha = common.new_sha256()
local LIFT = "grug_mapgen:guild_lift"
local MAPGEN = repo .. "/mods/MAPGEN/grug_mapgen"
local WP40 = MAPGEN .. "/wp40"

------------------------------------------------------------------------------
-- A. The registration and the art.
------------------------------------------------------------------------------
local game = dofile(repo .. "/tools/r57_details/game_harness.lua")(repo)
for _, line in ipairs(game.failures) do
	check(not (line:find("grug_guild", 1, true) or line:find("grug_mapgen", 1, true) or
		line:find("grug_map/", 1, true)), "A the mods load in the harness: " .. line)
end
local nodes, aliases = game.nodes, game.aliases
local def = nodes[LIFT]
check(def ~= nil, "A the lift is registered")
eq(def.drawtype, "nodebox", "A drawtype")
eq(def.paramtype, "light", "A paramtype")
eq(def.paramtype2, "4dir", "A paramtype2 4dir")
eq(def.light_source, 3, "A light source")
eq(def.floodable, false, "A not floodable")
eq(def.is_ground_content, false, "A no ground content")
eq(def.sunlight_propagates, nil, "A no sunlight propagation")
eq(def.liquidtype, nil, "A no liquid")
eq(def.diggable, false, "A not diggable")
check(def.groups.grug_natural == nil and def.groups.grug_air == nil, "A none of the digest's groups")
local FACES = {"top", "bottom", "right", "left", "back", "front"}
eq(#def.tiles, 6, "A six faces")
for index, face in ipairs(FACES) do
	eq(def.tiles[index], "grug_mapgen_guild_lift_" .. face .. ".png", "A tile " .. index)
	check(read(MAPGEN .. "/textures/" .. def.tiles[index]) ~= nil, "A " .. face .. " face shipped")
end
-- The drop's notes (guild-art drop 02 P1): the node box, unchanged.
local BOX = {
	{-0.5, -0.5, -0.4375, 0.5, -0.3125, 0.4375},
	{-0.4375, -0.3125, 0.0625, -0.25, 0.3125, 0.25},
	{0.25, -0.3125, 0.0625, 0.4375, 0.3125, 0.25},
	{-0.5, 0.3125, 0, 0.5, 0.5, 0.3125},
	{-0.25, 0, 0.0625, 0.25, 0.25, 0.3125},
	{-0.3125, -0.0625, 0, -0.1875, 0.3125, 0.375},
	{0.1875, -0.0625, 0, 0.3125, 0.3125, 0.375},
	{-0.0625, -0.3125, 0.125, 0.0625, 0, 0.25},
	{0.375, -0.0625, -0.125, 0.5, 0.125, 0.125},
}
eq(def.node_box.type, "fixed", "A a fixed node box")
eq(#def.node_box.fixed, #BOX, "A the picked node box's nine boxes")
for index, box in ipairs(BOX) do
	for k = 1, 6 do
		eq(def.node_box.fixed[index][k], box[k], "A box " .. index .. " value " .. k)
	end
end
local sel = def.selection_box
check(sel and sel.type == "fixed" and sel.fixed[1] == -0.5 and sel.fixed[2] == -0.5 and
	sel.fixed[3] == -0.5 and sel.fixed[4] == 0.5 and sel.fixed[5] == 0.5 and sel.fixed[6] == 0.5,
	"A a full-node selection box")
eq(type(def.on_rightclick), "function", "A the right-click is grug_guild's")

-- The shipped art is the picked files, byte for byte.
local shipped = 0
for line in read(repo .. "/tools/r58_lift/art/picks.txt"):gmatch("[^\n]+") do
	local digest, _, target = line:match("^(%x+)%s+(%S+)%s+(%S+)$")
	if digest then
		local data = read(repo .. "/" .. target)
		check(data ~= nil, "A shipped " .. target)
		eq(common.hex(sha(data)), digest, "A " .. target .. " is the pick")
		shipped = shipped + 1
	end
end
eq(shipped, 9, "A nine picked files")

-- The reputation icon goes through REP's one seam.
eq(grug_guild.REPUTATION_ICON, "grug_guild_reputation.png", "A the reputation icon")
check(grug_guild.reputation_formspec(1, 2, 120):find("image[1.00,1.77;0.45,0.45;grug_guild_reputation.png]",
	1, true) ~= nil, "A the balance is drawn with the icon")

-- The map: the window's markers, the baked kinds unchanged.
do
	local icons = dofile(repo .. "/mods/PLAYER/grug_map/settlement_icons.lua")
	eq(icons.marker("mining_camp"), "mining_camp", "A a mining camp's marker")
	eq(icons.marker("camp_construction"), "camp_construction", "A a camp under construction's marker")
	eq(icons.kind("mining_camp"), "mine", "A the minimap bakes a mining camp as a mine")
	eq(icons.kind("camp_construction"), "war_camp", "A the minimap bakes a camp under construction as a war camp")
	eq(icons.marker("mine"), "mine", "A other slots keep their kind's marker")
	eq(icons.marker("pvp_accord_low"), "war_camp", "A a war camp keeps its marker")
	for _, marker in ipairs({"mining_camp", "camp_construction"}) do
		check(read(repo .. "/mods/PLAYER/grug_map/textures/grug_map_" .. marker .. ".png") ~= nil,
			"A grug_map_" .. marker .. ".png shipped")
	end
	check(read(repo .. "/mods/PLAYER/grug_map/layers.lua"):find("texture(icons.marker(row.slot))",
		1, true) ~= nil, "A the window's settlement rows draw the marker")
end

------------------------------------------------------------------------------
-- B. The lift on a fake engine.
------------------------------------------------------------------------------
-- The room nodes (the harness loads only world_nodes.lua of grug_mapgen).
dofile(MAPGEN .. "/guild_room_nodes.lua")({
	get_modpath = function() return MAPGEN end,
	registered_nodes = nodes,
	register_node = function(name, d) nodes[name] = d end}, grug_materials)
-- The engine's air (builtin) and the defaults the travel path reads (a node
-- is walkable unless it says otherwise).
nodes.air = nodes.air or {drawtype = "airlike", walkable = false, pointable = false,
	buildable_to = true, floodable = true}
for _, d in pairs(nodes) do
	if d.walkable == nil then d.walkable = true end
end

local vmeta = {}
local function vnew(x, y, z)
	if type(x) == "table" then return setmetatable({x = x.x, y = x.y, z = x.z}, vmeta) end
	return setmetatable({x = x, y = y, z = z}, vmeta)
end
local function round(n) return math.floor(n + 0.5) end
rawset(_G, "vector", {new = vnew,
	offset = function(p, x, y, z) return vnew(p.x + x, p.y + y, p.z + z) end,
	round = function(p) return vnew(round(p.x), round(p.y), round(p.z)) end,
	distance = function(a, b)
		local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end})

-- The camps of a placement table (anchor id -> {x, z}: a 12 x 12 grid 400
-- nodes apart) and their rooms, as grug_mapgen publishes them.
local source = dofile(WP40 .. "/source/simple_map.lua")
local layout = {}
for index, a in ipairs(source.anchors) do
	layout[a.id] = {x = ((index - 1) % 12) * 400 - 2200, z = math.floor((index - 1) / 12) * 400 - 2200}
end
local C = dofile(WP40 .. "/r58_camps.lua")
local R = dofile(WP40 .. "/guild_rooms.lua")
local camps = C.index(layout)
local rooms = R.index(C.camps(layout), C.ROOM_FLOOR_Y)
eq(#camps.camps, 36, "B 36 camps with a lift")
eq(#rooms.list, 148, "B 148 rooms")

-- The world: each camp's real blueprint cells round its anchor at y 10
-- (the ground course), ground up to y 10, air above; the rooms as the room
-- step writes them; stone elsewhere below.
local GROUND = 10
local cells = {}
local function key(x, y, z) return x .. "," .. y .. "," .. z end
local resolve = function(name) return aliases[name] or name end
local settlement = dofile(WP40 .. "/r7_settlement.lua")
local profile_of = {}
for _, profile in ipairs(settlement.roster) do profile_of[profile.key] = profile end
local blueprints = {}

local callbacks = {fields = {}, leave = {}, die = {}, join = {}}
local after, emerge, chat, shown = {}, {}, {}, {}
local override_name, override_def, override_calls = nil, nil, 0
local players, us = {}, 0
rawset(_G, "core", {
	registered_nodes = nodes,
	override_item = function(name, d)
		override_calls = override_calls + 1
		override_name, override_def = name, d
	end,
	register_on_player_receive_fields = function(fn) callbacks.fields[#callbacks.fields + 1] = fn end,
	register_on_leaveplayer = function(fn) callbacks.leave[#callbacks.leave + 1] = fn end,
	register_on_dieplayer = function(fn) callbacks.die[#callbacks.die + 1] = fn end,
	register_on_joinplayer = function(fn) callbacks.join[#callbacks.join + 1] = fn end,
	show_formspec = function(name, formname, fs) shown[name] = {formname = formname, fs = fs} end,
	close_formspec = function(name) shown[name] = nil end,
	chat_send_player = function(name, message) chat[#chat + 1] = {name = name, text = message} end,
	formspec_escape = function(s) return s end,
	get_player_by_name = function(name) return players[name] end,
	get_us_time = function() us = us + 3000000; return us end,
	after = function(delay, fn) after[#after + 1] = {delay = delay, fn = fn} end,
	emerge_area = function(minp, maxp, fn)
		emerge[#emerge + 1] = {fn = fn, center = vnew((minp.x + maxp.x) / 2,
			(minp.y + maxp.y) / 2, (minp.z + maxp.z) / 2)}
	end,
	EMERGE_CANCELLED = 1, EMERGE_ERRORED = 2,
	load_area = function() end,
	dir_to_yaw = function() return 0 end,
	-- builtin/common/item_s.lua: the direction of param2's back (+Z face)
	fourdir_to_dir = function(p2)
		return ({[0] = vnew(0, 0, 1), vnew(1, 0, 0), vnew(0, 0, -1), vnew(-1, 0, 0)})[p2 % 4]
	end,
	get_node_or_nil = function(pos)
		local x, y, z = round(pos.x), round(pos.y), round(pos.z)
		local cell = cells[key(x, y, z)]
		if cell then return {name = resolve(cell.name), param2 = cell.param2 or 0} end
		if y < -40 then
			local room = rooms.room_at({x = x, y = y, z = z})
			local kind = room and R.cell(room, x, y, z)
			if kind == "lift" then return {name = LIFT, param2 = R.NODES.lift_param2} end
			if kind == "mantle" or kind == "plug" then return {name = R.NODES[kind][room.tier], param2 = 0} end
			if kind then return {name = R.NODES[kind], param2 = 0} end
			return {name = "default:stone", param2 = 0}
		end
		return {name = y <= GROUND and "default:dirt" or "air", param2 = 0}
	end,
})
local dismounts = 0
rawset(_G, "grug_core", {
	in_combat = function(p) return p.combat == true end,
	invalidate_combat_identity = function() end,
	hold_movement = function() end, release_movement = function() end,
	get_player_race = function() return "human" end,
	start_position = function() return nil end,
})
dofile(repo .. "/mods/CORE/grug_core/settlement_sockets.lua")
rawset(_G, "grug_mounts", {dismount = function() dismounts = dismounts + 1 end})
rawset(_G, "grug_sounds", {play = function() return false end})
rawset(_G, "grug_factions", {get_faction = function(p) return p.faction end,
	display_name = function(id) return id == "accord" and "The Accord" or "The Throng" end})
dofile(repo .. "/mods/PLAYER/grug_factions/service.lua")
rawset(_G, "grug_home", {})
dofile(repo .. "/mods/PLAYER/grug_home/travel.lua")
local home = grug_home
local guild_catalog = grug_guild.catalog
rawset(_G, "grug_guild", {catalog = guild_catalog})
rawset(_G, "grug_mapgen", {mining_camps = camps, guild_rooms = rooms})

-- Every camp's blueprint: its cells into the world, its sockets into the
-- registry (as the settlement build registers them).
local options = {raw_sha256 = sha, full_seed = "42"}
for _, camp in ipairs(camps.camps) do
	local profile = assert(profile_of[camp.id], "no profile for " .. camp.id)
	local bp = dofile(WP40 .. "/" .. profile.blueprint_file)(options, profile)
	blueprints[camp.id] = bp
	for _, cell in ipairs(bp.cells) do
		cells[key(camp.anchor.x + cell.x, GROUND + cell.y, camp.anchor.z + cell.z)] =
			{name = cell.name, param2 = cell.param2}
	end
	grug_core.register_settlement_sockets(camp.id, camp.race or "human",
		{x = camp.anchor.x, y = GROUND, z = camp.anchor.z}, bp.landmarks.sockets, camp.label)
end

dofile(repo .. "/mods/PLAYER/grug_guild/lift.lua")
eq(override_calls, 1, "B one override")
eq(override_name, LIFT, "B the override is the lift's")
do
	local keys = {}
	for k in pairs(override_def) do keys[#keys + 1] = k end
	check(#keys == 1 and keys[1] == "on_rightclick",
		"B the override sets only on_rightclick (the digest's static fields stay world_nodes.lua's)")
end

-- Players.
local function new_player(name, faction)
	local data = {}
	local p = {name = name, faction = faction, hp = 20, pos = vnew(0, 11, 0), combat = false,
		data = data}
	function p:get_player_name() return self.name end
	function p:is_player() return true end
	function p:get_hp() return self.hp end
	function p:get_pos() return self.pos end
	function p:set_pos(pos) self.pos = vnew(pos) end
	function p:get_meta()
		return {get_string = function(_, k) return data[k] or "" end,
			set_string = function(_, k, v) data[k] = v end}
	end
	players[name] = p
	return p
end
local function deferred()
	local tasks = after
	after = {}
	for _, task in ipairs(tasks) do
		if task.delay == 0 then task.fn() else after[#after + 1] = task end
	end
end
local function finish(action)
	local job = table.remove(emerge, 1)
	assert(job, "no pending emerge")
	job.fn(nil, action or 0, 0)
	deferred()
	return job
end
local function drop_timeouts()
	local kept = {}
	for _, t in ipairs(after) do if t.delay ~= 30 then kept[#kept + 1] = t end end
	after = kept
end
local function last_chat(name)
	for i = #chat, 1, -1 do if chat[i].name == name then return chat[i].text end end
	return ""
end
local function click(player, pos)
	shown[player.name] = nil
	override_def.on_rightclick(pos, {name = LIFT}, player)
	return shown[player.name]
end
local function send(player, values)
	local form = shown[player.name]
	local formname = form and form.formname or "grug_guild:lift:0"
	for _, fn in ipairs(callbacks.fields) do
		if fn(player, formname, values) then return end
	end
end
local function near(a, b) return math.abs(a.x - b.x) < 1e-9 and math.abs(a.y - b.y) < 1e-9 and
	math.abs(a.z - b.z) < 1e-9 end
local function surface_lift(camp)
	for _, s in ipairs(grug_core.settlement_sockets_at(camp.id)) do
		if s.id == "lift" then return vnew(s.pos) end
	end
end
-- The front of a 4dir lift: param2 0 -z, 1 -x, 2 +z, 3 +x.
local FRONT = {[0] = {0, -1}, {-1, 0}, {0, 1}, {1, 0}}

-- The camp from its lifts.
for _, camp in ipairs(camps.camps) do
	local lift = surface_lift(camp)
	check(lift and lift.x == camp.lift.x and lift.z == camp.lift.z and lift.y == GROUND + 1,
		"B " .. camp.id .. " the lift socket at the lift column")
	local found = grug_guild.lift_at(lift)
	check(found and found.camp.id == camp.id and found.level == 0, "B " .. camp.id .. " found from its surface lift")
	eq(#found.levels, camp.tier + 1, "B " .. camp.id .. " the surface and levels 1..tier")
	eq(found.levels[1].label, "Surface", "B " .. camp.id .. " the surface first")
	for level = 1, camp.tier do
		local entry = found.levels[level + 1]
		eq(entry.level, level, "B " .. camp.id .. " level " .. level)
		eq(entry.label, ("Level %d (%d)"):format(level, C.ROOM_FLOOR_Y[level]), "B " .. camp.id .. " label " .. level)
	end
	for _, room in ipairs(rooms.rooms_for_camp(camp.id)) do
		local from_room = grug_guild.lift_at(room.lift_cell)
		check(from_room and from_room.camp.id == camp.id and from_room.level == room.tier and
			#from_room.levels == camp.tier + 1, "B " .. camp.id .. " found from its room lift " .. room.tier)
		-- The room's arrival: beside the lift, in front of it (param2 2: +z).
		local front = FRONT[R.NODES.lift_param2]
		check(room.arrival.x == room.lift_cell.x + front[1] and room.arrival.z == room.lift_cell.z + front[2],
			"B " .. camp.id .. " room " .. room.tier .. " arrival in front of the lift")
		local arrival = home.safe_arrival(room.arrival)
		check(arrival and near(arrival, room.arrival), "B " .. camp.id .. " room " .. room.tier .. " arrival safe")
	end
	-- The surface lift faces the gate (the blueprint's param2), and the cell
	-- in front of it is the deck: open, with headroom, never a built cell.
	local node = core.get_node_or_nil(lift)
	eq(node.name, LIFT, "B " .. camp.id .. " the lift node at its socket")
	local front = FRONT[node.param2]
	local fx, fz = lift.x + front[1], lift.z + front[2]
	check(cells[key(fx, GROUND, fz)] ~= nil, "B " .. camp.id .. " the deck in front of the lift")
	for dy = 1, 2 do
		local c = cells[key(fx, GROUND + dy, fz)]
		check(c == nil or c.name == "air", "B " .. camp.id .. " nothing built in front of the lift " .. dy)
	end
	local surface = home.safe_arrival(vnew(fx, GROUND + 0.51, fz))
	check(surface ~= nil, "B " .. camp.id .. " the surface arrival is safe")
end
check(grug_guild.lift_at(vnew(camps.camps[1].lift.x + 1, GROUND + 1, camps.camps[1].lift.z)) == nil,
	"B no camp one node off the lift column")
check(grug_guild.lift_at(vnew(5000, GROUND + 1, 5000)) == nil, "B no camp elsewhere")
check(grug_guild.lift_at(nil) == nil, "B no position, no camp")

-- Pick a T4 mining camp and a T6 war camp.
local t4, t6
for _, camp in ipairs(camps.camps) do
	if not t4 and camp.kind == "mining_camp" and camp.tier == 4 then t4 = camp end
	if not t6 and camp.kind == "war_camp" and camp.tier == 6 then t6 = camp end
end
assert(t4 and t6)
local function enemy_of(faction) return faction == "accord" and "throng" or "accord" end

-- The list and the refusals.
local own = new_player("own", t4.faction)
local foe = new_player("foe", enemy_of(t4.faction))
local nobody = new_player("nobody", nil)
local lift4 = surface_lift(t4)
own.pos = vnew(lift4.x, lift4.y, lift4.z - 2)
local form = click(own, lift4)
check(form and form.formname:find("^grug_guild:lift:") ~= nil, "B own faction: the list opens")
local fs = form.fs
check(fs:find("label[0.4,0.5;Miner's Guild Lift]", 1, true) and fs:find(t4.label, 1, true),
	"B the list's title and the camp")
check(fs:find("label[0.4,1.70;Surface]", 1, true) and fs:find("label[4.2,1.70;You are here]", 1, true),
	"B the surface marked as here")
check(not fs:find("go_0", 1, true), "B no button for the current level")
for level = 1, 4 do
	check(fs:find(("label[0.4,%.2f;Level %d (%d)]"):format(1.0 + 0.7 * (level + 1), level,
		C.ROOM_FLOOR_Y[level]), 1, true) and fs:find("go_" .. level .. ";Travel]", 1, true),
		"B level " .. level .. " listed with Travel")
end
check(not fs:find("go_5", 1, true), "B no level below the camp's tier")
local refusal = "<Miner's Guild Lift> I serve only " .. grug_factions.display_name(t4.faction) .. "."
foe.pos = vnew(lift4)
check(click(foe, lift4) == nil and last_chat("foe") == refusal, "B the enemy gets the refusal line")
nobody.pos = vnew(lift4)
check(click(nobody, lift4) == nil and last_chat("nobody") == refusal, "B no faction: the refusal line")
own.hp = 0
check(click(own, lift4) == nil, "B a dead character gets no list")
own.hp = 20

-- A forged button from another player's form changes nothing.
form = click(own, lift4)
for _, fn in ipairs(callbacks.fields) do fn(foe, form.formname, {go_4 = "Travel"}) end
eq(#emerge, 0, "B a form of another player is ignored")
-- A level the camp does not have.
send(own, {go_5 = "Travel"})
check(last_chat("own") == "This lift does not go there." and #emerge == 0, "B a level beyond the tier refused")
-- Combat, distance.
own.combat = true
send(own, {go_4 = "Travel"})
check(last_chat("own") == "Cannot travel in combat." and #emerge == 0, "B combat refused")
own.combat = false
own.pos = vnew(lift4.x + 20, lift4.y, lift4.z)
send(own, {go_4 = "Travel"})
check(last_chat("own") == "Stand at the lift to travel." and #emerge == 0, "B away from the lift refused")
own.pos = vnew(lift4.x, lift4.y, lift4.z - 2)
-- A faction change after the list opened.
own.faction = enemy_of(t4.faction)
send(own, {go_4 = "Travel"})
check(last_chat("own") == refusal and #emerge == 0, "B a faction change refuses the trip")
own.faction = t4.faction

-- Ride the T4 camp down to every level and back, and the T6 war camp.
local function ride(player, camp, level, origin_pos)
	local found = grug_guild.lift_at(origin_pos)
	assert(found, "no lift at the origin")
	check(click(player, origin_pos) ~= nil, "B the list at " .. camp.id .. " level " .. found.level)
	local before = dismounts
	send(player, {["go_" .. level] = "Travel"})
	check(shown[player.name] == nil, "B the list closes when the trip starts")
	check(home.is_pending(player), "B the trip is pending while the destination emerges")
	local job = finish()
	drop_timeouts()
	local room = level > 0 and rooms.rooms_for_camp(camp.id)[level]
	local target = room and room.lift_cell or surface_lift(camp)
	check(job.center.x == target.x and job.center.y == target.y and job.center.z == target.z,
		"B " .. camp.id .. " emerges level " .. level)
	if room then
		check(near(player.pos, room.arrival), "B " .. camp.id .. " arrives at level " .. level)
	else
		local node = core.get_node_or_nil(target)
		local front = FRONT[node.param2]
		check(near(player.pos, vnew(target.x + front[1], target.y - 0.49, target.z + front[2])),
			"B " .. camp.id .. " arrives in front of the surface lift")
	end
	eq(dismounts, before + 1, "B the mount is left behind")
	return room and room.lift_cell or target
end
for _, camp in ipairs({t4, t6}) do
	local rider = new_player("rider_" .. camp.id, camp.faction)
	local at = surface_lift(camp)
	rider.pos = vnew(at.x, at.y, at.z - 1)
	for level = 1, camp.tier do
		at = ride(rider, camp, level, at)
		-- From the room to the surface and back down to the next level.
		at = ride(rider, camp, 0, at)
	end
	-- Level to level: from the deepest to the first.
	at = ride(rider, camp, camp.tier, at)
	at = ride(rider, camp, 1, at)
	at = ride(rider, camp, 0, at)
	eq(next(rider.data), nil, "B " .. camp.id .. " nothing written to player meta")
end

-- The enemy in a room: may stand there, never use the lift.
local room4 = rooms.rooms_for_camp(t4.id)[4]
foe.pos = vnew(room4.arrival)
check(click(foe, room4.lift_cell) == nil and last_chat("foe") == refusal, "B the enemy in a room is refused")

-- One trip at a time; combat during the emerge cancels; no cooldown.
own.pos = vnew(room4.arrival)
click(own, room4.lift_cell)
send(own, {go_2 = "Travel"})
click(own, room4.lift_cell)
send(own, {go_3 = "Travel"})
check(last_chat("own") == "Travel is already being prepared." and #emerge == 1, "B a second trip refused")
own.combat = true
finish()
drop_timeouts()
own.combat = false
check(near(own.pos, room4.arrival) and last_chat("own") == "Travel canceled.", "B combat during the emerge cancels")
click(own, room4.lift_cell)
send(own, {go_2 = "Travel"})
finish()
drop_timeouts()
check(near(own.pos, rooms.rooms_for_camp(t4.id)[2].arrival), "B travel again at once (no cooldown)")
-- A failed emerge leaves the player where they are.
local room2 = rooms.rooms_for_camp(t4.id)[2]
click(own, room2.lift_cell)
send(own, {go_1 = "Travel"})
finish(core.EMERGE_ERRORED)
drop_timeouts()
check(near(own.pos, room2.arrival) and last_chat("own"):find("cannot reach Level 1", 1, true),
	"B a failed emerge stays with a message")

-- The surface arrival follows the lift's facing, then its back.
do
	local lift = surface_lift(t4)
	local saved = cells[key(lift.x, lift.y, lift.z)]
	for p2 = 0, 3 do
		cells[key(lift.x, lift.y, lift.z)] = {name = LIFT, param2 = p2}
		local front = FRONT[p2]
		-- the front and the back on open ground
		for _, d in ipairs({{front[1], front[2]}, {-front[1], -front[2]}}) do
			cells[key(lift.x + d[1], GROUND, lift.z + d[2])] = {name = "default:wood"}
			for dy = 1, 2 do cells[key(lift.x + d[1], GROUND + dy, lift.z + d[2])] = {name = "air"} end
		end
		click(own, room2.lift_cell)
		send(own, {go_0 = "Travel"})
		finish()
		drop_timeouts()
		check(near(own.pos, vnew(lift.x + front[1], lift.y - 0.49, lift.z + front[2])),
			"B param2 " .. p2 .. ": the arrival in front of the lift")
		cells[key(lift.x + front[1], GROUND + 1, lift.z + front[2])] = {name = "default:stone"}
		own.pos = vnew(lift.x - front[1], lift.y, lift.z - front[2])
		click(own, lift)
		send(own, {go_2 = "Travel"})
		finish()
		drop_timeouts()
		click(own, room2.lift_cell)
		send(own, {go_0 = "Travel"})
		finish()
		drop_timeouts()
		check(near(own.pos, vnew(lift.x - front[1], lift.y - 0.49, lift.z - front[2])),
			"B param2 " .. p2 .. ": the front blocked, the back")
		cells[key(lift.x + front[1], GROUND + 1, lift.z + front[2])] = {name = "air"}
		own.pos = vnew(lift.x, lift.y, lift.z)
		click(own, lift)
		send(own, {go_2 = "Travel"})
		finish()
		drop_timeouts()
	end
	-- Every side blocked: the player stays in the room with a message.
	for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
		cells[key(lift.x + d[1], GROUND + 1, lift.z + d[2])] = {name = "default:stone"}
	end
	click(own, room2.lift_cell)
	send(own, {go_0 = "Travel"})
	finish()
	drop_timeouts()
	check(near(own.pos, room2.arrival) and last_chat("own"):find("cannot reach Surface", 1, true),
		"B no free side: stays with a message")
	cells[key(lift.x, lift.y, lift.z)] = saved
end
eq(next(own.data), nil, "B nothing written to player meta")

-- Leave and death drop an open list.
click(own, room2.lift_cell)
for _, fn in ipairs(callbacks.leave) do fn(own) end
send(own, {go_1 = "Travel"})
eq(#emerge, 0, "B a list from before a leave does nothing")

print("R58 LIFT PORTABLE PASS checks=" .. checks)
