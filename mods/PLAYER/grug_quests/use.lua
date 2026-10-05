-- "Use at a place" (Round 36, quests.md "Objectives"): a quest object at the
-- objective's place, shown only to the players who still need it, used by
-- right-clicking it and holding the button for the objective's hold.
--
-- A use point is one act at one place (Q.use_key: place, object kind and
-- label). Its place is a clash site (the anchor) or a recipe quest place
-- (its spot on this world's region map; labels.lua Q.use_place). Once a
-- second, in its slot, each player's needed points (Q.use_needs, cached by
-- quest state) are measured against their places: within REACH the player
-- observes the point's object, which is added on the place's ground when the
-- first observer comes and removed with the last one. Nothing is written to
-- the map and the object is never saved.
--
-- The hold: a right-click on the object starts it; the hold pass (every
-- HOLD_STEP while a hold runs) ends it when the player lets go of the
-- button, steps more than USE_REACH from the object, dies or leaves, or the
-- object is gone; any damage interrupts it. A finished hold credits that
-- player only (Q.credit_use) and hides the object from them.
local Q = grug_quests
local regions = grug_mobs.spawn_regions

-- The kinds of quest object (kind -> {texture, size}): data/use_objects.json,
-- the one place their texture names live (a texture file of the art lane
-- replaces a placeholder there). Loaded before the quest files, whose
-- checks refuse an unknown kind (validate.lua, registry.lua).
Q.use_objects = (function()
	local file = core.get_modpath(core.get_current_modname()) .. "/data/use_objects.json"
	local handle = assert(io.open(file, "r"), "[grug_quests] data/use_objects.json is missing")
	local data = core.parse_json(handle:read("*a"))
	handle:close()
	assert(type(data) == "table", "[grug_quests] data/use_objects.json is not readable JSON")
	local out = {}
	for kind, row in pairs(data) do
		if kind ~= "notes" then
			assert(type(row) == "table" and type(row.texture) == "string" and row.texture ~= "" and
				(row.size == nil or (type(row.size) == "number" and row.size > 0 and row.size <= 4)),
				"[grug_quests] use object " .. tostring(kind) .. " needs a texture and a size of 0..4")
			out[kind] = {texture = row.texture, size = row.size or 1}
		end
	end
	return out
end)()
-- An unsaved object stays only in the active blocks round a player
-- (spawn_regions.lua LEADER_RANGE), so it is added only within that reach.
local REACH = regions.LEADER_RANGE
local USE_REACH = 5
local SLOTS, SLOT_PERIOD = 5, 0.2
local HOLD_STEP = 0.1
local ENTITY = "grug_quests:use_object"
-- Several points at one place stand beside each other: the n-th on the
-- n-th offset (nodes).
local RING = {{0, 0}, {2, 0}, {0, 2}, {-2, 0}, {0, -2}, {2, 2}, {-2, 2}, {2, -2}, {-2, -2}}
-- The ground is searched this far above and below the terrain height, in
-- the place's column and then a few beside it.
local SCAN = 40
local COLUMNS = {{0, 0}, {2, 0}, {-2, 0}, {0, 2}, {0, -2}, {3, 3}, {-3, 3}, {3, -3}, {-3, -3}}

-- key -> {objective, place (canonical ref), object = ObjectRef or nil,
-- observers = {name = true}, count}
local points = {}
-- player name -> {key, object, label, started (us), seconds, shown}
local holds = {}
Q._use_points, Q._use_holds = points, holds -- read by the fixture and the probe

local function feed(player, text)
	grug_core.feed(player, "quest", text, "quest_use")
end

-- {x, z} of a place on this world, or nil (a quest place without a spot).
function Q.use_place_xz(ref)
	if regions.clash_site(ref) then return regions.place(ref) end
	local zone, id = ref:match("^([^/]+)/(.+)$")
	return zone and regions.place_spot(zone, id) or nil
end

-- The stand position on walkable ground in column (x, z): the highest
-- walkable node that is no leaf or trunk, under a node that is neither
-- walkable nor liquid (air, grass, flowers). Nil when the column is not
-- loaded or has none.
local function column_ground(x, z)
	local y0 = math.floor(grug_zones.terrain_height_at(x, z) + 0.5)
	local open_above = false
	for y = y0 + SCAN, y0 - SCAN, -1 do
		local node = core.get_node_or_nil({x = x, y = y, z = z})
		if not node or node.name == "ignore" then return nil end
		local def = core.registered_nodes[node.name]
		local plant = core.get_item_group(node.name, "leaves") > 0 or core.get_item_group(node.name, "tree") > 0
		if def and def.walkable and not plant then
			return open_above and {x = x, y = y + 1, z = z} or nil
		end
		open_above = def ~= nil and not def.walkable and not plant and (def.liquidtype or "none") == "none"
	end
	return nil
end

local function ground(x, z)
	for _, o in ipairs(COLUMNS) do
		local pos = column_ground(x + o[1], z + o[2])
		if pos then return pos end
	end
	return nil
end

-- The first slot no other point at this place holds.
local function free_slot(place)
	local used = {}
	for _, point in pairs(points) do
		if point.place == place then used[point.slot] = true end
	end
	local slot = 1
	while used[slot] do slot = slot + 1 end
	return slot
end

-- The point's object, added at the place's ground when missing; nil while
-- the ground there is not loaded.
local function ensure_object(point)
	if point.object and point.object:is_valid() then return point.object end
	point.object = nil
	local offset = RING[(point.slot - 1) % #RING + 1]
	local pos = ground(math.floor(point.xz.x + offset[1] + 0.5), math.floor(point.xz.z + offset[2] + 0.5))
	if not pos then return nil end
	local kind = Q.use_objects[point.objective.object]
	local object = core.add_entity({x = pos.x, y = pos.y - 0.5 + kind.size / 2, z = pos.z}, ENTITY)
	if not object then return nil end
	local half = kind.size / 2
	object:set_properties({textures = {kind.texture}, visual_size = {x = kind.size, y = kind.size},
		selectionbox = {-half * 0.7, -half, -half * 0.7, half * 0.7, half, half * 0.7},
		nametag = point.objective.label})
	object:get_luaentity()._grug_use_key = point.key
	point.object = object
	return object
end

local function publish(point)
	if point.object and point.object:is_valid() then point.object:set_observers(point.observers) end
end

local function leave(key, name)
	local point = points[key]
	if not point or not point.observers[name] then return end
	point.observers[name] = nil
	if next(point.observers) then
		publish(point)
	else
		if point.object and point.object:is_valid() then point.object:remove() end
		points[key] = nil
	end
end

local function join(objective, name, xz)
	local key = Q.use_key(objective)
	local point = points[key]
	if not point then
		point = {key = key, objective = objective, place = objective.place, xz = xz, observers = {},
			slot = free_slot(objective.place)}
		points[key] = point
	end
	local fresh = not point.observers[name]
	point.observers[name] = true
	local had = point.object and point.object:is_valid()
	if ensure_object(point) and (fresh or not had) then publish(point) end
end

-- One player's pass: join the needed points within REACH, leave the others.
local function pass(player)
	local name = player:get_player_name()
	local near = {}
	local pos = player:get_hp() > 0 and player:get_pos()
	if pos then
		for _, objective in ipairs(Q.use_needs(player)) do
			local xz = Q.use_place_xz(objective.place)
			if xz then
				local dx, dz = xz.x - pos.x, xz.z - pos.z
				if dx * dx + dz * dz <= REACH * REACH then
					near[Q.use_key(objective)] = true
					join(objective, name, xz)
				end
			end
		end
	end
	for key, point in pairs(points) do
		if point.observers[name] and not near[key] then leave(key, name) end
	end
end
Q.use_pass = pass

local function stop(name, reason)
	local hold = holds[name]
	if not hold then return end
	holds[name] = nil
	local player = core.get_player_by_name(name)
	if player and reason then feed(player, hold.label .. ": " .. reason) end
end

-- A right-click on a quest object: a hold starts when the player still needs
-- its point and is within USE_REACH.
function Q.start_use(player, object)
	if not player or not player.is_player or not player:is_player() or player:get_hp() <= 0 then
		return false
	end
	local name = player:get_player_name()
	local ent = object and object:get_luaentity()
	local point = ent and points[ent._grug_use_key]
	if not point or not point.observers[name] or holds[name] then return false end
	local needed = false
	for _, objective in ipairs(Q.use_needs(player)) do
		if Q.use_key(objective) == point.key then needed = true end
	end
	local pos, at = player:get_pos(), object:get_pos()
	if not needed or not pos or not at or vector.distance(pos, at) > USE_REACH then return false end
	local hold = point.objective.hold
	holds[name] = {key = point.key, object = object, label = point.objective.label,
		started = core.get_us_time(), seconds = hold, shown = 0}
	feed(player, ("%s: 0/%d s"):format(point.objective.label, hold))
	return true
end

-- One hold step: true while it goes on.
local function step(name, hold, now)
	local player = core.get_player_by_name(name)
	if not player or player:get_hp() <= 0 then stop(name, nil); return end
	local object = hold.object
	local pos, at = player:get_pos(), object:is_valid() and object:get_pos()
	if not at or not pos then stop(name, "stopped."); return end
	if not player:get_player_control().place then stop(name, "stopped."); return end
	if vector.distance(pos, at) > USE_REACH then stop(name, "too far away."); return end
	local elapsed = now - hold.started
	if elapsed >= hold.seconds * 1000000 then
		holds[name] = nil
		if Q.credit_use(player, hold.key) then leave(hold.key, name) end
		return
	end
	local seconds = math.floor(elapsed / 1000000)
	if seconds > hold.shown then
		hold.shown = seconds
		feed(player, ("%s: %d/%d s"):format(hold.label, seconds, hold.seconds))
	end
end
Q.use_step = function(now)
	for name, hold in pairs(holds) do step(name, hold, now or core.get_us_time()) end
end

core.register_entity(ENTITY, {
	initial_properties = {physical = false, collide_with_objects = false, pointable = true,
		visual = "sprite", textures = {"blank.png"}, visual_size = {x = 1, y = 1},
		selectionbox = {-0.35, -0.5, -0.35, 0.35, 0.5, 0.35}, glow = 8, hp_max = 1,
		static_save = false, nametag_color = "#ffe080"},
	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
		-- Nobody sees it until its point names the observers.
		self.object:set_observers({})
	end,
	on_rightclick = function(self, clicker) Q.start_use(clicker, self.object) end,
	on_punch = function() return true end,
})

-- Any damage interrupts a hold.
core.register_on_player_hpchange(function(player, hp_change)
	if hp_change < 0 and holds[player:get_player_name()] then
		stop(player:get_player_name(), "interrupted.")
	end
end)
core.register_on_dieplayer(function(player) stop(player:get_player_name(), nil) end)

-- Players are polled once a second, each in one of SLOTS phases by join
-- order (the quest HUD's pattern, hud.lua); holds every HOLD_STEP while any
-- runs.
local slot_of, joined, accumulator, current_slot, hold_acc = {}, 0, 0, 0, 0
core.register_on_joinplayer(function(player)
	joined = joined + 1
	slot_of[player:get_player_name()] = joined % SLOTS + 1
end)
core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	slot_of[name], holds[name] = nil, nil
	for key in pairs(points) do leave(key, name) end
end)
core.register_globalstep(function(dtime)
	if next(holds) then
		hold_acc = hold_acc + dtime
		if hold_acc >= HOLD_STEP then
			hold_acc = 0
			Q.use_step()
		end
	end
	accumulator = accumulator + dtime
	if accumulator < SLOT_PERIOD then return end
	accumulator = accumulator - SLOT_PERIOD
	if accumulator > SLOT_PERIOD then accumulator = 0 end
	current_slot = current_slot % SLOTS + 1
	for name, slot in pairs(slot_of) do
		if slot == current_slot then
			local player = core.get_player_by_name(name)
			if player then pass(player) end
		end
	end
end)
-- A quest change (accepted, abandoned, credited elsewhere) re-checks at once.
Q.register_on_change(pass)
