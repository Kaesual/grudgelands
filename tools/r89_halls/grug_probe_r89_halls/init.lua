-- Disposable engine probe (Round 89 lane HALLS): the arena Breach Road's
-- halls with the stair, the roofed balcony and the invisible barrier, in the
-- engine, with one real client (tools/r89_halls/capture.sh). Never shipped.
-- The driver (character creation, the SHOT / ack handshake) follows
-- tools/r85_build's probe; the steps run in one coroutine.
--
-- 1. The arena emerged with a margin; the barrier's cells counted in the
--    engine (45 per hall) and its registered fields.
-- 2. Territory: grug_pvp.territory_at on the stair, the deck, the rail,
--    both roofs and in front of the barrier.
-- 3. The barrier, per hall, from the deck and the parapet's top toward the
--    field and back from the air in front (PROOF lines):
--    walk   the client's own movement (velocity pushed through
--           add_velocity, gravity on): walking into it, jumping out from
--           the rail, flying into it from the air in front (gravity off),
--           falling in front of the opening while pressing in;
--    mount  a flying mount (the game's controller, its rider's "forward"
--           control held) out of the balcony and into it from the air;
--    ray    grug_core.combat_ray toward a target on the other side (a
--           player-sized target and a mob with a turned box), a heal ray
--           (`friendly`) from the air in front onto the player on the
--           deck, and the engine's own ray as a client sees it (the
--           barrier "blocking": nothing pointed);
--    shot   grug_projectiles.spawn at a mob on the other side, and a
--           projectile whose target crosses the barrier in flight;
--    area   grug_core.area.anchor from the deck at the field and from the
--           air in front at the deck, area.query from the hall's roof;
--    mob    a bandit archer in front of the balcony: its sight
--           (mobs_redo line_of_sight, core.line_of_sight), its shot lock,
--           eight seconds of its attack on the player on the deck, then
--           the same with the player in its view (the control); its
--           per-viewer nametag's observers;
--    light  the node light on the deck, on the rail, in the barrier and in
--           front of it, by day and at night.
-- 4. The views (SHOT lines) for both halls by day, then at night on the
--    deck and on the parapet; a frozen boar on the road in front shows a
--    nametag through the barrier.
-- Ends the server itself; "RESULT" is the verdict line.

local P = "[r89halls] "
local NAME = "grugcap"
local SETTLE = tonumber(core.settings:get("r89halls_settle") or "") or 4
-- r89halls_shots = false: the proof alone, no views
local SHOTS = core.settings:get_bool("r89halls_shots", true)
local MARGIN = 30
local BARRIER = "grug_mapgen:arena_barrier"
local FACTIONS = {"accord", "throng"}
local SIGN = {accord = 1, throng = -1}

local function log(msg) core.log("action", P .. msg) end

local wp40 = core.get_modpath("grug_mapgen") .. "/wp40"
local L = dofile(wp40 .. "/breach_layout.lua")
local site = L.from_placement(grug_mapgen.wp40.placement_layout_text)
local world = L.world(site)

-- The draft's hall frame (u toward the road, y from the floor layer, v) in
-- world nodes, and back.
local function H(f, u, y, v)
	local s = SIGN[f]
	return vector.new(site.x + s * (42 - u), site.y + 6 + y, site.z - s * v)
end
local function U(f, pos) return 42 - SIGN[f] * (pos.x - site.x) end
local function Y(pos) return pos.y - site.y - 6 end
local function fmt(n) return n and ("%.2f"):format(n) or "nil" end

local verdicts = {pass = 0, fail = 0, finding = 0}
local function proof(f, test, from, result, ok, finding)
	local verdict = finding and "FINDING" or (ok and "PASS" or "FAIL")
	verdicts[finding and "finding" or (ok and "pass" or "fail")] =
		verdicts[finding and "finding" or (ok and "pass" or "fail")] + 1
	log(("PROOF %s | %s | %s | %s | %s"):format(f, test, from, result, verdict))
end

-- Targets: a player-sized box (unturned) for the rays; the probe's own
-- projectile, whose hits are recorded.
local function target_def()
	return {initial_properties = {physical = false, collide_with_objects = false, pointable = true,
		visual = "cube", visual_size = {x = 0.6, y = 1.8},
		textures = {"default_obsidian.png", "default_obsidian.png", "default_obsidian.png",
			"default_obsidian.png", "default_obsidian.png", "default_obsidian.png"},
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3}, selectionbox = {-0.3, 0, -0.3, 0.3, 1.8, 0.3},
		static_save = false},
		on_activate = function(self) self.object:set_armor_groups({immortal = 1}) end}
end
core.register_entity("grug_probe_r89_halls:target", target_def())
local hits = {}
grug_projectiles.register("r89halls_probe", {speed = 12, max_distance = 40,
	on_hit = function(_, target, _, point)
		hits[#hits + 1] = {target = target, point = point and vector.new(point)}
	end})

-- The stand-in caster of the heal ray (no second client): its faction is
-- the Accord's for the relation check (wrapped at the run, after
-- grug_factions has set the function).
local function standin_faction()
	if grug_core._r89halls_wrapped then return end
	local real_faction = grug_core.get_player_faction
	grug_core.get_player_faction = function(name)
		if name == "r89standin" then return "accord" end
		return real_faction(name)
	end
	grug_core._r89halls_wrapped = true
end

local function read_ack()
	local file = io.open(core.get_worldpath() .. "/r89halls_ack", "r")
	if not file then return "" end
	local text = file:read("*l") or ""
	file:close()
	return text
end

local function submit(player, formname, fields)
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		if fn(player, formname, fields) then return end
	end
end

-- coroutine helpers
local function sleep(seconds)
	local t = 0
	while t < seconds do t = t + coroutine.yield() end
end
local function shot(name)
	log("SHOT " .. name)
	while read_ack() ~= name do coroutine.yield() end
end

local function eye_height(player)
	return grug_core.player_body(player).eye_height or 1.47
end
local function look_at(player, eye, to)
	local dx, dy, dz = to.x - eye.x, to.y - eye.y, to.z - eye.z
	player:set_look_horizontal(math.atan2(-dx, dz))
	player:set_look_vertical(math.atan2(-dy, math.sqrt(dx * dx + dz * dz)))
end
-- Stand with the eye at `eye` and look at `to`.
local function view(player, eye, to)
	player:set_pos(vector.offset(eye, 0, -eye_height(player), 0))
	look_at(player, eye, to)
end
local function still(player)
	player:set_physics_override({gravity = 0, speed = 0, jump = 0})
	local v = player:get_velocity()
	if v then player:add_velocity(vector.multiply(v, -1)) end
end
-- The walkable top under a column, searched down from `pos`.
local function ground(pos)
	for y = math.floor(pos.y + 0.5), math.floor(pos.y + 0.5) - 30, -1 do
		local def = core.registered_nodes[core.get_node({x = pos.x, y = y, z = pos.z}).name]
		if def and def.walkable then return vector.new(pos.x, y + 0.5, pos.z) end
	end
	return pos
end
-- A mob that stays where it is put: no step of its own, no motion.
local function freeze(obj)
	local ent = obj and obj:get_luaentity()
	if not ent then return end
	ent.on_step = function() end
	obj:set_velocity({x = 0, y = 0, z = 0})
	obj:set_acceleration({x = 0, y = 0, z = 0})
end
local function centre(obj)
	local pos = obj:get_pos()
	local box = obj:get_properties().selectionbox
	return vector.offset(pos, (box[1] + box[4]) / 2, (box[2] + box[5]) / 2, (box[3] + box[6]) / 2)
end

-- 3. walk ---------------------------------------------------------------------
-- Push the player's own (client) velocity toward `want(t)` along u (and a
-- jump at the start); record the u and y range it reaches. `hover`: the
-- player waits for the client weightless at the start, gravity comes on
-- when the pushing starts (a fall from there).
local function push(player, f, start, seconds, gravity, want_u, jump, band, hover)
	player:set_physics_override({speed = 1, jump = 1, gravity = hover and 0 or gravity})
	player:set_pos(start)
	sleep(1.2)
	if hover then player:set_physics_override({speed = 1, jump = 1, gravity = gravity}) end
	local s = SIGN[f]
	local umin, umax, ymin, ymax = math.huge, -math.huge, math.huge, -math.huge
	local t, acc = 0, 1
	if jump then player:add_velocity({x = 0, y = jump, z = 0}) end
	while t < seconds do
		local dt = coroutine.yield()
		t, acc = t + dt, acc + dt
		local pos = player:get_pos()
		local u, y = U(f, pos), Y(pos)
		if not band or (y >= band[1] and y <= band[2]) then
			umin, umax = math.min(umin, u), math.max(umax, u)
		end
		ymin, ymax = math.min(ymin, y), math.max(ymax, y)
		if acc >= 0.1 then
			acc = 0
			-- +u is -s x in the world
			local vx = -s * want_u(t)
			local v = player:get_velocity() or {x = 0}
			player:add_velocity({x = vx - v.x, y = 0, z = 0})
		end
	end
	still(player)
	return umin, umax, ymin, ymax
end

local function walk_tests(player, f)
	local inner, outer = 19.5 - 0.3, 20.5 + 0.3
	local _, umax, ymin = push(player, f, H(f, 16.5, 8.5, 10), 2.5, 1, function() return 5 end)
	proof(f, "walk into the barrier", "deck, toward the field", ("u max %s (inner face 19.5), y min %s")
		:format(fmt(umax), fmt(ymin)), umax <= inner + 0.02 and ymin >= 8.3)
	local _, umax2, ymin2 = push(player, f, H(f, 19, 9.6, 10), 2.5, 1, function() return 6 end, 6.5)
	proof(f, "jump out from the rail", "parapet's top, toward the field",
		("u max %s, y min %s"):format(fmt(umax2), fmt(ymin2)), umax2 <= inner + 0.02 and ymin2 >= 8.3)
	local umin3 = push(player, f, H(f, 22, 9, 10), 2.5, 0, function() return -5 end)
	proof(f, "fly into the barrier", "air in front, toward the deck",
		("u min %s (outer face 20.5)"):format(fmt(umin3)), umin3 >= outer - 0.02)
	-- in front of the opening under the roof's edge (as after a step off
	-- the balcony's roof), falling while pressing in toward the deck
	local umin4, _, ymin4 = push(player, f, H(f, 21.0, 11.4, 10), 2.5, 1,
		function() return -5 end, nil, {7.6, 12.9}, true)
	proof(f, "fall in front and press in", "air in front under the roof's edge, falling",
		("u min %s while level with the opening, y min %s"):format(fmt(umin4), fmt(ymin4)),
		umin4 >= outer - 0.02 and umin4 < math.huge)
end

-- 3. mount --------------------------------------------------------------------
local methods = nil
local forced
local function force_control(player, control)
	if not methods then
		methods = getmetatable(player)
		local real = methods.get_player_control
		methods.get_player_control = function(self)
			if forced and self:is_player() and self:get_player_name() == NAME then return forced end
			return real(self)
		end
	end
	forced = control
end

local function flight_tier()
	local best
	for id, tier in pairs(grug_mounts.TIERS) do
		if tier.mode == "flight" and (not best or id < best) then best = id end
	end
	return best
end

local function ride(player, f, start, dir_u, seconds)
	still(player)
	player:set_pos(start)
	sleep(0.5)
	local ok, err = grug_mounts.spawn_entity(player, flight_tier(), start)
	if not ok then return nil, err end
	local mount = player:get_attach()
	if not mount then return nil, "not attached" end
	local half = mount:get_properties().collisionbox
	-- face +u (dir_u 1) or -u: +u is -s x
	local s = SIGN[f]
	player:set_look_horizontal(math.atan2(s * dir_u, 0))
	player:set_look_vertical(0)
	sleep(0.3)
	force_control(player, {up = true})
	local umin, umax = math.huge, -math.huge
	local t = 0
	while t < seconds do
		t = t + coroutine.yield()
		local pos = mount:get_pos()
		if pos then
			umin, umax = math.min(umin, U(f, pos)), math.max(umax, U(f, pos))
		end
	end
	force_control(player, nil)
	local width = math.max(math.abs(half[1]), math.abs(half[4]), math.abs(half[3]), math.abs(half[6]))
	grug_mounts.dismount(player, nil, true)
	sleep(0.3)
	still(player)
	return umin, umax, width, half[5] - half[2]
end

local function mount_tests(player, f)
	-- level flight just over the rail's posts (the deck at 8.5, the posts'
	-- tops 9.5): the barrier, not the rail, is what it meets
	local umin, umax, width, height = ride(player, f, H(f, 15, 9.7, 10), 1, 2.5)
	if not umin then
		proof(f, "flying mount out", "deck", "no mount: " .. tostring(umax), false)
	else
		proof(f, "flying mount out", "over the deck, forward toward the field",
			("mount u max %s, half width %s, box height %s (inner face 19.5)"):format(fmt(umax),
			fmt(width), fmt(height)),
			umax + width <= 19.5 + 0.02)
	end
	umin, umax, width = ride(player, f, H(f, 24, 9.7, 10), -1, 2.5)
	if not umin then
		proof(f, "flying mount in", "air in front", "no mount: " .. tostring(umax), false)
	else
		proof(f, "flying mount in", "air in front, forward toward the deck",
			("mount u min %s, half width %s (outer face 20.5)"):format(fmt(umin), fmt(width)),
			umin - width >= 20.5 - 0.02)
	end
end

-- 3. rays, shots, area ------------------------------------------------------------
local function describe(ray)
	if not ray then return "nil" end
	local what = ray.reason
	if ray.node then what = what .. " " .. ray.node end
	if ray.target and ray.target.get_luaentity and ray.target:get_luaentity() then
		what = what .. " " .. ray.target:get_luaentity().name
	elseif ray.target and ray.target.is_player and ray.target:is_player() then
		what = what .. " player " .. ray.target:get_player_name()
	end
	return ray.status .. " " .. what
end

local function ray_tests(player, f)
	standin_faction()
	still(player)
	local deck = H(f, 16.5, 8.5, 10)
	view(player, vector.offset(deck, 0, eye_height(player), 0), H(f, 23.5, 9.4, 10))
	sleep(0.5)
	local eye = grug_core.combat_eye_pos(player)
	-- a player-sized target in the air in front, then on the deck
	local target = core.add_entity(H(f, 23.5, 8.5, 10), "grug_probe_r89_halls:target")
	look_at(player, eye, centre(target))
	local ray = grug_core.combat_ray(player, 30)
	proof(f, "aim ray out (ranged attack)", "deck at a target in the air in front", describe(ray),
		ray.reason == "node" and ray.node == BARRIER)
	target:set_pos(H(f, 18.6, 8.5, 10))
	look_at(player, eye, centre(target))
	ray = grug_core.combat_ray(player, 30)
	proof(f, "aim ray, control", "deck at the target on the deck", describe(ray),
		ray.reason == "object" and ray.target == target)
	target:remove()
	-- a mob (its box turned: the aiming ray's own test) in front
	-- at the deck's eye level, so the ray passes over the rail's top
	local boar = core.add_entity(H(f, 23.5, 9.2, 10), "grug_mobs:boar")
	freeze(boar)
	sleep(0.3)
	look_at(player, eye, centre(boar))
	ray = grug_core.combat_ray(player, 30)
	proof(f, "aim ray out at a mob (turned box)", "deck at a boar in the air in front", describe(ray),
		ray.reason == "node" and ray.node == BARRIER)
	-- the engine's ray as a client sees it: the barrier "blocking"
	-- (the eye starts inside the player's own box: that hit is skipped)
	local function own(pointed) return pointed.type == "object" and pointed.ref == player end
	local count, first = 0, nil
	for pointed in core.raycast(eye, centre(boar), true, false, {}) do
		if not own(pointed) then
			count = count + 1
			first = first or (pointed.type == "node" and core.get_node(pointed.under).name or pointed.type)
		end
	end
	proof(f, "engine ray, no pointabilities (as a client points)", "deck at the boar",
		("%d pointed things (%s)"):format(count, tostring(first)), count == 0)
	local wrapped
	for pointed in core.raycast(eye, centre(boar), true, false) do
		if not own(pointed) then
			wrapped = pointed.type == "node" and core.get_node(pointed.under).name or pointed.type
			break
		end
	end
	proof(f, "server raycast (the wrapper)", "deck at the boar", "first: " .. tostring(wrapped),
		wrapped == BARRIER)
	-- shot: a projectile at the boar beyond the barrier
	local spawned = grug_projectiles.spawn("r89halls_probe", {owner = player, origin = eye,
		direction = player:get_look_dir(), max_distance = 30, data = {}})
	proof(f, "projectile at a mob beyond", "deck at the boar in front",
		spawned and "spawned" or "refused (no lock)", not spawned)
	-- in flight: the boar on the deck, then set beyond the barrier at once
	boar:set_pos(H(f, 18.4, 8.5, 12))
	view(player, vector.offset(H(f, 13.5, 8.5, 10), 0, eye_height(player), 0), centre(boar))
	sleep(0.5)
	eye = grug_core.combat_eye_pos(player)
	look_at(player, eye, centre(boar))
	hits = {}
	spawned = grug_projectiles.spawn("r89halls_probe", {owner = player, origin = eye,
		direction = player:get_look_dir(), max_distance = 30, data = {}})
	boar:set_pos(H(f, 22.4, 8.5, 12))
	sleep(1.5)
	local hit = hits[1]
	proof(f, "projectile whose target crosses in flight", "deck at the boar, the boar set 4 nodes " ..
		"out through the barrier", spawned and (hit and ("hit at u %s"):format(fmt(U(f, hit.point))) or
		"no hit") or "refused", true, spawned and hit ~= nil and U(f, hit.point) > 20.5)
	boar:remove()
	-- the heal ray from the air in front onto the player on the deck
	still(player)
	player:set_pos(deck)
	sleep(0.5)
	local body = vector.offset(player:get_pos(), 0, 0.9, 0)
	local standin = {get_player_name = function() return "r89standin" end,
		is_player = function() return true end}
	local from = H(f, 23.5, 10, 10)
	ray = grug_core.combat_ray(standin, 30, {origin = from, direction = vector.subtract(body, from),
		friendly = true})
	proof(f, "heal ray in", "air in front at the player on the deck", describe(ray),
		ray.reason == "node" and ray.node == BARRIER)
	from = H(f, 13.6, 10, 10)
	ray = grug_core.combat_ray(standin, 30, {origin = from, direction = vector.subtract(body, from),
		friendly = true})
	proof(f, "heal ray, control", "deck behind the player", describe(ray),
		ray.reason == "friendly" and ray.target == player)
	from = H(f, 23.5, 10, 10)
	ray = grug_core.combat_ray(standin, 30, {origin = from, direction = vector.subtract(body, from)})
	proof(f, "aim ray in (ranged attack)", "air in front at the player on the deck", describe(ray),
		ray.reason == "node" and ray.node == BARRIER)
end

local function area_tests(player, f)
	local area = grug_core.area
	still(player)
	local deck = H(f, 16.5, 8.5, 10)
	view(player, vector.offset(deck, 0, eye_height(player), 0), H(f, 30, 0, 10))
	sleep(0.5)
	local anchor, why = area.anchor(player, 30)
	proof(f, "area anchor out", "deck at the field below", anchor and
		("anchor at u %s y %s"):format(fmt(U(f, anchor)), fmt(Y(anchor))) or tostring(why),
		anchor == nil or U(f, anchor) <= 20.5)
	view(player, vector.offset(H(f, 23.5, 8.5, 10), 0, eye_height(player), 0), H(f, 16, 8.6, 10))
	sleep(0.8)
	anchor, why = area.anchor(player, 30)
	proof(f, "area anchor in", "air in front at the deck", anchor and
		("anchor at u %s y %s"):format(fmt(U(f, anchor)), fmt(Y(anchor))) or tostring(why),
		anchor == nil or U(f, anchor) >= 20.5)
	-- an area on the hall's roof by the balcony's back wall, the player on the deck
	player:set_pos(H(f, 14, 8.5, 9))
	sleep(0.8)
	local roof = H(f, 11, 8.5, 9)
	local found = false
	for _, obj in ipairs(area.query(roof, {radius = 4})) do
		if obj == player then found = true end
	end
	proof(f, "area on the hall's roof", "an anchor on the hall's roof 3 nodes from a player on the " ..
		"deck, radius 4", found and "the player on the deck is in it" or "not reached", true, found)
end

-- 3. mob ----------------------------------------------------------------------
-- Hits on the player: every punch an arrow or a melee blow lands
-- (on_punchplayer runs before the damage), counted while `counting`.
local punches, counting = 0, false
core.register_on_punchplayer(function(player)
	if counting and player:get_player_name() == NAME then punches = punches + 1 end
end)
local function arrows_near(pos)
	local n = 0
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 40)) do
		local ent = obj:get_luaentity()
		if ent and ent.name and ent.name:find("arrow", 1, true) then n = n + 1 end
	end
	return n
end
-- The barrier's cells of a hall, or all of them set to `name` (air for the
-- control, the barrier back after it).
local function barrier_cells(f)
	local a, b = H(f, 20, 8, 6), H(f, 20, 12, 14)
	return core.find_nodes_in_area(vector.new(math.min(a.x, b.x), a.y, math.min(a.z, b.z)),
		vector.new(math.max(a.x, b.x), b.y, math.max(a.z, b.z)), {BARRIER, "air"})
end
local function set_barrier(f, name)
	for _, pos in ipairs(barrier_cells(f)) do core.set_node(pos, {name = name}) end
end

-- The archer's sight, lock and attack on the player standing on the rail.
local function attack(player, archer, f, label, open)
	local ent = archer:get_luaentity()
	local mob_eye = vector.offset(archer:get_pos(), 0, 1.5, 0)
	local p_eye = vector.offset(player:get_pos(), 0, eye_height(player), 0)
	local sight = ent:line_of_sight(mob_eye, p_eye)
	local engine_sight, blocker = core.line_of_sight(mob_eye, p_eye)
	local lock = grug_core.actor_projectile_lock(archer, player, mob_eye, 14, 60)
	local where = blocker and (core.get_node(blocker).name .. (" at u %s y %s"):format(fmt(U(f, blocker)),
		fmt(Y(blocker)))) or "none"
	local seen = open and sight == true and engine_sight == true and lock ~= nil or
		not open and sight ~= true and engine_sight == false and lock == nil and
		blocker ~= nil and core.get_node(blocker).name == BARRIER
	proof(f, "mob sight" .. label, ("bandit archer in front at u %s y %s, at the player on the rail")
		:format(fmt(U(f, archer:get_pos())), fmt(Y(archer:get_pos()))),
		("mobs_redo line_of_sight %s, core.line_of_sight %s (first block: %s), shot lock %s"):format(
		tostring(sight), tostring(engine_sight), where, lock and "made" or "none"), seen)
	local max = player:get_properties().hp_max or 20
	player:set_hp(max)
	punches, counting = 0, true
	local arrows, shots_seen, t, heal = 0, 0, 0, 0
	ent:do_attack(player, true)
	while t < 8 do
		local dt = coroutine.yield()
		t, heal = t + dt, heal + dt
		local n = arrows_near(archer:get_pos() or mob_eye)
		if n > arrows then shots_seen = shots_seen + (n - arrows) end
		arrows = n
		if heal >= 0.5 then heal = 0 player:set_hp(max) end
	end
	counting = false
	proof(f, "mob attack" .. label, "the archer at the player on the rail, 8 s",
		("arrows seen %d, hits on the player %d, mob state %s, player at u %s y %s"):format(shots_seen,
		punches, tostring(ent.state), fmt(U(f, player:get_pos())), fmt(Y(player:get_pos()))),
		open and punches > 0 or not open and punches == 0)
	player:set_hp(max)
end

local function mob_tests(player, f)
	still(player)
	local rail = H(f, 19, 9.6, 10)
	player:set_pos(rail)
	player:set_physics_override({gravity = 1, speed = 0, jump = 0})
	-- a stand-in platform in front of the balcony, a little below the deck
	-- (template frame y 7, u 25..27, v 9..11), so the archer's eye sees the
	-- player on the rail through the barrier; put back afterwards
	local platform = {}
	for u = 25, 27 do
		for v = 9, 11 do
			local pos = H(f, u, 7, v)
			platform[#platform + 1] = {pos = pos, node = core.get_node(pos)}
			core.set_node(pos, {name = "default:stone"})
		end
	end
	local stand = H(f, 26, 7.5, 10)
	local archer = core.add_entity(stand, "grug_mobs:bandit_archer")
	sleep(1)
	if not (archer and archer:get_luaentity()) then
		proof(f, "mob", "field", "no archer", false)
		return
	end
	-- it stays on its platform: no walking, no running
	archer:get_luaentity().walk_velocity = 0
	archer:get_luaentity().run_velocity = 0
	sleep(1)
	-- the nametag: the archer's per-viewer tag carriers seen by the player
	local seen = false
	for _, child in ipairs(archer:get_children()) do
		local c = child:get_luaentity()
		if c and c.name == "grug_core:tag_carrier" then
			local observers = child:get_observers()
			if type(observers) ~= "table" or observers[NAME] then seen = true end
		end
	end
	proof(f, "nametag through the barrier", ("the archer's tag %s nodes away, the player on the rail")
		:format(fmt(vector.distance(archer:get_pos(), player:get_pos()))),
		seen and "observed by the player" or "not observed", seen)
	attack(player, archer, f, "", false)
	-- the control: the same with this hall's barrier cells air, then back
	set_barrier(f, "air")
	player:set_pos(rail)
	sleep(0.5)
	attack(player, archer, f, ", control without the barrier", true)
	set_barrier(f, BARRIER)
	local back = 0
	for _, pos in ipairs(barrier_cells(f)) do
		if core.get_node(pos).name == BARRIER then back = back + 1 end
	end
	proof(f, "barrier restored", "after the control", back .. " cells", back == 45)
	archer:remove()
	for _, cell in ipairs(platform) do core.set_node(cell.pos, cell.node) end
	still(player)
end

local function light_row(f, label)
	local cells = {{"deck", 16, 9, 10}, {"rail top", 19, 10, 10}, {"barrier", 20, 10, 10},
		{"in front", 21, 10, 10}, {"gallery under the roof's back", 13, 9, 10}}
	local out = {}
	for _, c in ipairs(cells) do
		out[#out + 1] = c[1] .. " " .. tostring(core.get_node_light(H(f, c[2], c[3], c[4])))
	end
	log(("LIGHT %s %s: %s"):format(f, label, table.concat(out, ", ")))
end

-- 4. views ---------------------------------------------------------------------
-- The draft's poses (tools/r89_balcony_draft/arena.py VIEWS, hall frame
-- eye and target).
local VIEWS = {
	{"field", {53, 15, 33}, {12, 7, 3}},
	{"road", {42, -4.03, 24}, {16, 6.8, 6}},
	{"foot", {7.2, 1.97, 0.5}, {3, 2.6, 8}},
	{"stair", {3.3, 5.97, 13}, {12, 8.6, 13}},
	{"deck", {13.6, 9.97, 13.2}, {20, 9.8, 9}},
	{"parapet", {18.54, 9.97, 8.5}, {44, -4.3, 4}},
	{"rail", {19, 10.97, 9}, {42, -3.7, 5}},
	{"roof", {10, 9.97, 0}, {12, 10, 9}},
}
local function take(player, f, row, suffix)
	still(player)
	player:set_camera({mode = "first"})
	view(player, H(f, row[2][1], row[2][2], row[2][3]), H(f, row[3][1], row[3][2], row[3][3]))
	sleep(SETTLE)
	shot(f .. "_" .. row[1] .. (suffix or ""))
end

local function territory()
	local points = {
		{"stair foot", 3, 1.5, 4}, {"stair turn", 3, 5, 13}, {"upper stair", 11, 8.2, 13},
		{"deck", 16, 9, 10}, {"rail top", 19, 9.5, 10}, {"in front of the barrier", 21, 10, 10},
		{"hall roof", 5, 8.5, 0}, {"balcony roof", 16, 13.5, 9}, {"gate court", 16, 2, 10},
	}
	for _, f in ipairs(FACTIONS) do
		local other = f == "accord" and "throng" or "accord"
		for index, p in ipairs(points) do
			local pos = H(f, p[2], p[3], p[4])
			local own, theirs = grug_pvp.territory_at(pos, f), grug_pvp.territory_at(pos, other)
			local want_friendly = index <= 5
			local ok = want_friendly and (own == "friendly" and theirs == "enemy") or
				(not want_friendly and own == "contested" and theirs == "contested")
			proof(f, "territory " .. p[1], "grug_pvp.territory_at", own .. " / " .. theirs, ok)
		end
	end
end

local function main(player)
	core.set_timeofday(0.5)
	still(player)
	log(("site %d,%d datum %d reach %d"):format(site.x, site.z, site.y, site.reach))
	player:set_pos(vector.new(site.x, site.y + 30, site.z))
	local fp, done = world.footprint, false
	local t0 = core.get_us_time()
	core.emerge_area(vector.new(fp.min.x - MARGIN, site.y - 12, fp.min.z - MARGIN),
		vector.new(fp.max.x + MARGIN, site.y + 36, fp.max.z + MARGIN),
		function(_, _, remaining) if remaining == 0 then done = true end end)
	while not done do coroutine.yield() end
	log(("arena emerged in %.1f s"):format((core.get_us_time() - t0) / 1e6))
	-- 1. the barrier in the engine
	local def = core.registered_nodes[BARRIER]
	log(("barrier node: drawtype %s walkable %s pointable %s sunlight %s diggable %s groups.grug_air %s")
		:format(def.drawtype, tostring(def.walkable), tostring(def.pointable),
			tostring(def.sunlight_propagates), tostring(def.diggable), tostring(def.groups.grug_air)))
	for _, f in ipairs(FACTIONS) do
		local a, b = H(f, 0, 0, -15), H(f, 20, 18, 15)
		local n = #core.find_nodes_in_area(vector.new(math.min(a.x, b.x), a.y, math.min(a.z, b.z)),
			vector.new(math.max(a.x, b.x), b.y, math.max(a.z, b.z)), {BARRIER})
		proof(f, "barrier cells", "the hall box in the engine", n .. " cells", n == 45)
	end
	-- 2.
	territory()
	-- 3.
	for _, f in ipairs(FACTIONS) do
		-- the client loads the hall's blocks first (its own collision needs them)
		still(player)
		view(player, H(f, 15, 10, 10), H(f, 25, 8, 10))
		sleep(6)
		light_row(f, "day")
		walk_tests(player, f)
		mount_tests(player, f)
		ray_tests(player, f)
		area_tests(player, f)
		mob_tests(player, f)
	end
	-- 4. the views by day, with a boar on the road in front of each hall
	local boars = {}
	for _, f in ipairs(FACTIONS) do
		boars[#boars + 1] = core.add_entity(ground(H(f, 30, 6, 5)), "grug_mobs:boar")
		freeze(boars[#boars])
	end
	if SHOTS then
		for _, f in ipairs(FACTIONS) do
			for _, row in ipairs(VIEWS) do take(player, f, row) end
		end
	end
	core.set_timeofday(0)
	sleep(2)
	for _, f in ipairs(FACTIONS) do
		light_row(f, "night")
		if SHOTS then
			take(player, f, VIEWS[5], "_night")
			take(player, f, VIEWS[7], "_night")
		end
	end
	for _, b in ipairs(boars) do if b:get_pos() then b:remove() end end
	log(("RESULT %s pass=%d fail=%d findings=%d"):format(verdicts.fail == 0 and "PASS" or "FAIL",
		verdicts.pass, verdicts.fail, verdicts.finding))
end

local state = {phase = "wait", clock = 0}
local co
core.register_globalstep(function(dtime)
	if state.phase == "run" then
		local player = core.get_player_by_name(NAME)
		if not player then return end
		local ok, err = coroutine.resume(co, dtime)
		if not ok then
			log("RESULT FAIL error " .. tostring(err))
			state.phase = "done"
		elseif coroutine.status(co) == "dead" then
			state.phase = "done"
		end
		if state.phase == "done" then
			log("shutdown")
			core.request_shutdown("probe done", false, 0)
		end
		return
	end
	if state.phase ~= "wait" then return end
	state.clock = state.clock + dtime
	if state.clock < 0.5 then return end
	state.clock = 0
	local player = core.get_player_by_name(NAME)
	if not player then return end
	if not grug_core.world_preparation_status().ready then return end
	if player:get_meta():get_string("grug_classes:arriving") ~= "" then return end
	if not grug_classes.get_class(player) then
		submit(player, "", {faction_accord = "Accord"})
		submit(player, "", {race_human = "Human"})
		submit(player, "", {class_warrior = "Warrior"})
		submit(player, "", {create_character = "Create"})
		return
	end
	core.close_formspec(NAME, "")
	grug_xp.set_xp(player, grug_xp.xp_for_level(20))
	log("READY")
	co = coroutine.create(function() main(player) end)
	state.phase = "run"
	coroutine.resume(co, 0)
end)
