-- Shared helpers for area skills (Round 52, round52-class-plan.md §3
-- "CORE-B", rulings C3-C5 and D9; class-redesign/skill-inventory.md §2 B4,
-- B5, the group helper, and §3a the ground anchor). Nothing shipped calls
-- them yet (D1): Nova, Cinderfall and the splashes keep their plain spheres
-- until round K rewires them.
--
--   area.anchor(player, range, opts)  the ground anchor of a crosshair area
--   area.ground_below(point, start)   the ground search alone
--   area.query(anchor, opts)          the targets of a ground-anchored area
--   area.group(caster, opts)          the recipients of a self-centred group
--                                     heal (self always included)
--   area.cone(caster, opts)           the targets in a cone in front of the
--                                     caster (Round 53)
--   area.fall_height(anchor, radius)  room for falling visuals above it
--   area.delayed(caster, spec)        one impact after a fixed delay
--
-- Relations stay with the caller: a filter or `eligible` predicate is the
-- abilities' valid_target (grug_core never depends on grug_abilities).
--
-- One rule for every area, cone and group (0.53.1, the user's ruling of
-- 2026-10-20): whatever the filter accepts within the horizontal radius and
-- the band of H above or below the anchor (a cone: also its opening; a
-- group: around the caster) is reached. No line of sight: walls, step edges
-- and floors inside the band hide no one.

local area = {}
grug_core.area = area

-- H of §3a: the ground search depth and the half height of the damage band,
-- one number for both.
area.H = 3
area.NO_GROUND = "No ground found."
-- The warning lives exactly as long as the delay, as single particles whose
-- lifetime is the delay (the dragon's lightning_ring pattern), and a
-- particle lives at most particles.lua's MAX_EXPTIME of 3 s.
area.MAX_DELAY = 3
-- Falling visuals start at most this high, and below the first solid node
-- above the anchor (§3a item 5).
area.CEILING_CAP = 12
-- A target's body: the middle of a mob's collision box, or this high above
-- a player's feet.
local PLAYER_BODY = 0.9
-- Falling particles stay half a node below the ceiling; a shorter fall than
-- MIN_FALL (a crawlspace) shows none.
local FALL_MARGIN = 0.5
local MIN_FALL = 1.5

local function round(value)
	return math.floor(value + 0.5)
end

-- true / false, or nil where the map is not loaded. An unknown node is
-- solid, as the engine's default node features are.
local function walkable_at(x, y, z)
	local node = core.get_node_or_nil({x = x, y = y, z = z})
	if not node then
		return nil
	end
	local def = core.registered_nodes[node.name]
	return def == nil or def.walkable ~= false
end

-- The anchor's x/z stay the aimed point's, kept inside the searched column
-- (a hit on a wall face lies on the column's border).
local function inside(value, centre)
	return math.max(centre - 0.45, math.min(centre + 0.45, value))
end

-- The ground under `point` (§3a items 2 and 6): the top of the first
-- walkable node with a non-walkable node above it, searched straight down
-- the column of the node `start` (default the node holding `point`; a
-- terrain hit passes the node on the ray's side of the face it hit), down to
-- a top at most H metres below `point`. Liquids and plants are not walkable,
-- so the search looks through them. nil when there is none, or the map is
-- not loaded there.
function area.ground_below(point, start)
	local x = start and start.x or round(point.x)
	local top = start and start.y or round(point.y)
	local z = start and start.z or round(point.z)
	-- The lowest node whose top (y + 0.5) lies within H of the point.
	local lowest = math.ceil(point.y - area.H - 0.5)
	local above = walkable_at(x, top + 1, z)
	for y = top, lowest, -1 do
		local here = walkable_at(x, y, z)
		if here == nil or above == nil then
			return nil
		end
		if here and not above then
			return vector.new(inside(point.x, x), y + 0.5, inside(point.z, z))
		end
		above = here
	end
	return nil
end

-- The terrain point of a ray: the first walkable (or unknown) or liquid
-- node it meets (plants are passed; a liquid surface is a point, so deep
-- water finds no ground below it). Node-only, so the engine's raycast is the
-- right one (AGENTS.md "Combat, input and notices"); objects do not stop it,
-- so an object that is no legal enemy leaves the terrain behind it.
local function terrain_point(ray)
	if not ray.origin or not ray.destination then
		return nil
	end
	for pointed in core.raycast(ray.origin, ray.destination, false, true) do
		if pointed.type == "node" then
			local node = core.get_node_or_nil(pointed.under)
			local def = node and core.registered_nodes[node.name]
			if node and (def == nil or def.walkable ~= false or
					(def.liquidtype or "none") ~= "none") then
				return pointed.intersection_point, pointed.above
			end
		end
	end
	return nil
end

-- The anchor of a crosshair area (§3a items 1-3): a legal enemy under the
-- crosshair gives its position at this moment, otherwise the terrain hit
-- does; then the ground below it. Returns anchor, target (the enemy or nil),
-- or nil, area.NO_GROUND -- a def.cast returns that refusal as it is, so
-- nothing is paid and no cooldown is armed (grug_abilities.try_cast).
-- opts.is_enemy(obj): the caller's target rule on top of the combat ray's
-- own hostile classification (the abilities' valid_target "hostile").
function area.anchor(player, range, opts)
	local ray = grug_core.combat_ray(player, range)
	local target = ray.status == "target" and ray.target or nil
	if target and opts and opts.is_enemy and not opts.is_enemy(target) then
		target = nil
	end
	local point, start
	if target then
		point = target:get_pos()
	else
		point, start = terrain_point(ray)
	end
	local anchor = point and area.ground_below(point, start)
	if not anchor then
		return nil, area.NO_GROUND
	end
	return anchor, target
end

-- An object's body point (a beam's end, Rebuke): the middle of a mob's live
-- collision box (read without get_properties), or a player's body.
local function body_point(obj, pos)
	if obj:is_player() then
		return vector.offset(pos, 0, PLAYER_BODY, 0)
	end
	local ent = obj:get_luaentity()
	local box = ent and (ent._grug_cbox or (ent.initial_properties and
		ent.initial_properties.collisionbox) or ent.collisionbox)
	if type(box) == "table" and box[2] and box[5] then
		return vector.offset(pos, 0, (box[2] + box[5]) / 2, 0)
	end
	return pos
end
area.body_point = body_point

-- A stable name for the last tie-break: players by name, entities by their
-- registered name.
local function object_key(obj)
	if obj:is_player() then
		return "p:" .. obj:get_player_name()
	end
	local ent = obj:get_luaentity()
	return "e:" .. tostring(ent and ent.name or "")
end

-- Nearest first; ties by height, then x, z, then the key: the same scene
-- always gives the same order.
local function nearest_first(a, b)
	if a.d2 ~= b.d2 then return a.d2 < b.d2 end
	if a.pos.y ~= b.pos.y then return a.pos.y < b.pos.y end
	if a.pos.x ~= b.pos.x then return a.pos.x < b.pos.x end
	if a.pos.z ~= b.pos.z then return a.pos.z < b.pos.z end
	return a.key < b.key
end

-- The targets of a ground-anchored area (§3a item 4): objects within
-- horizontal radius opts.radius of the anchor and within opts.band (default
-- H) above or below it, accepted by opts.filter(obj); nearest first, at most
-- opts.cap (default all).
function area.query(anchor, opts)
	local radius = opts.radius
	local band = opts.band or area.H
	local filter, cap = opts.filter, opts.cap
	local candidates = {}
	for _, obj in ipairs(core.get_objects_in_area(
			vector.offset(anchor, -radius, -band, -radius),
			vector.offset(anchor, radius, band, radius))) do
		local pos = obj:get_pos()
		if pos then
			local dx, dz = pos.x - anchor.x, pos.z - anchor.z
			local d2 = dx * dx + dz * dz
			if d2 <= radius * radius and math.abs(pos.y - anchor.y) <= band and
					(not filter or filter(obj)) then
				candidates[#candidates + 1] = {obj = obj, pos = pos, d2 = d2,
					key = object_key(obj)}
			end
		end
	end
	table.sort(candidates, nearest_first)
	local hits = {}
	for index = 1, math.min(cap or #candidates, #candidates) do
		hits[index] = candidates[index].obj
	end
	return hits
end

local function hp_share(player)
	local max_hp = tonumber(player:get_properties().hp_max) or 0
	if max_hp <= 0 then
		return 1
	end
	return player:get_hp() / max_hp
end

-- Lowest HP share first; ties nearest first, then by name.
local function neediest_first(a, b)
	if a.share ~= b.share then return a.share < b.share end
	if a.d2 ~= b.d2 then return a.d2 < b.d2 end
	return a.key < b.key
end

-- The recipients of a self-centred group heal (skill-inventory.md §3 item
-- 3): the caster always, plus players within horizontal radius opts.radius
-- of the caster and within opts.band (default H) above or below its feet
-- that opts.eligible(obj) accepts (the abilities' valid_target "friendly").
-- At most opts.cap in all, the caster counted; lowest HP share first. The
-- caster keeps its place whatever its HP, and takes its turn in the order.
-- Returns a list of players.
function area.group(caster, opts)
	local centre = caster:get_pos()
	local radius = opts.radius
	local band = opts.band or area.H
	local others = {}
	for _, obj in ipairs(core.get_objects_in_area(
			vector.offset(centre, -radius, -band, -radius),
			vector.offset(centre, radius, band, radius))) do
		local pos = obj ~= caster and obj:is_player() and obj:get_pos()
		if pos then
			local dx, dy, dz = pos.x - centre.x, pos.y - centre.y, pos.z - centre.z
			if dx * dx + dz * dz <= radius * radius and math.abs(dy) <= band and
					opts.eligible(obj) then
				others[#others + 1] = {obj = obj, share = hp_share(obj),
					d2 = dx * dx + dy * dy + dz * dz, key = obj:get_player_name()}
			end
		end
	end
	table.sort(others, neediest_first)
	local chosen = {{obj = caster, share = hp_share(caster), d2 = 0,
		key = caster:get_player_name()}}
	local room = (opts.cap or #others + 1) - 1
	for index = 1, math.min(room, #others) do
		chosen[#chosen + 1] = others[index]
	end
	table.sort(chosen, neediest_first)
	local players = {}
	for index = 1, #chosen do
		players[index] = chosen[index].obj
	end
	return players
end

-- The targets of a facing cone (round53-plan.md §4 HOOKS: Ice Wave 70° 5 m,
-- Broadstroke 100° 3 m, Flourish 90° 3 m): objects within horizontal
-- radius opts.radius of the caster's feet, within opts.band (default H)
-- above or below them and within opts.angle (the whole opening, degrees)
-- of the caster's horizontal facing (opts.dir, default the look), accepted
-- by opts.filter(obj) -- the abilities' valid_target, which carries the PvP
-- flag; nearest first, at most opts.cap. One standing inside the caster has
-- no direction and counts. The caster is never a target.
function area.cone(caster, opts)
	local centre = caster:get_pos()
	local radius = opts.radius
	local band = opts.band or area.H
	local dir = opts.dir or core.yaw_to_dir(caster:get_look_horizontal())
	local cos_half = math.cos(math.rad(opts.angle / 2))
	local candidates = {}
	for _, obj in ipairs(core.get_objects_in_area(
			vector.offset(centre, -radius, -band, -radius),
			vector.offset(centre, radius, band, radius))) do
		local pos = obj ~= caster and obj:get_pos()
		if pos then
			local dx, dz = pos.x - centre.x, pos.z - centre.z
			local d2 = dx * dx + dz * dz
			local len = math.sqrt(d2)
			if d2 <= radius * radius and math.abs(pos.y - centre.y) <= band and
					(len < 0.01 or (dx * dir.x + dz * dir.z) / len >= cos_half) and
					opts.filter(obj) then
				candidates[#candidates + 1] = {obj = obj, pos = pos, d2 = d2,
					key = object_key(obj)}
			end
		end
	end
	table.sort(candidates, nearest_first)
	local hits = {}
	for index = 1, math.min(opts.cap or #candidates, #candidates) do
		hits[index] = candidates[index].obj
	end
	return hits
end

-- The first solid (or unloaded) node in column x/z from `base` up, within
-- CEILING_CAP; nil when there is none. `skip_ground`: first rise past the
-- solid nodes at the bottom (a slope climbing into this column), so the
-- ceiling is the first solid above open air; a column solid all the way up
-- is rock beside the area and gives nil.
local function ceiling_of(x, base, z, skip_ground)
	local step = 0
	if skip_ground then
		while step < area.CEILING_CAP and walkable_at(x, base + step, z) ~= false do
			step = step + 1
		end
		if step >= area.CEILING_CAP then
			return nil
		end
	end
	for s = step, area.CEILING_CAP - 1 do
		if walkable_at(x, base + s, z) ~= false then
			return base + s
		end
	end
	return nil
end

-- How far falling visuals may start above the anchor (§3a item 5): half a
-- node below the first solid node above it, at most CEILING_CAP. An
-- unloaded node counts as solid. With `radius` the lowest ceiling over the
-- anchor and four points at 0.6 x radius around it (the falling disc's
-- reach), so a sloped cave ceiling never starts a fall inside rock.
local SAMPLE = 0.6
function area.fall_height(anchor, radius)
	local x, z = round(anchor.x), round(anchor.z)
	local base = round(anchor.y)
	local ceiling = ceiling_of(x, base, z, false)
	if radius and radius > 0 then
		local r = SAMPLE * radius
		for _, offset in ipairs({{r, 0}, {-r, 0}, {0, r}, {0, -r}}) do
			local top = ceiling_of(round(anchor.x + offset[1]), base,
				round(anchor.z + offset[2]), true)
			if top and (not ceiling or top < ceiling) then
				ceiling = top
			end
		end
	end
	if not ceiling then
		return area.CEILING_CAP
	end
	return math.min(area.CEILING_CAP,
		math.max(0, ceiling - 0.5 - anchor.y - FALL_MARGIN))
end

-- Pending impacts per caster: name -> {[entry] = true}, entry.job the
-- core.after job.
local pending = {}

-- One impact after a fixed delay (B5, C3, D9). At once: a warning ring of
-- single particles on the anchor that lives exactly the delay, and large
-- particles that fall from below the ceiling onto it in that time. After
-- `delay` seconds: an impact burst and spec.impact(caster, anchor), with the
-- caster fetched again by name. D9: the caster leaving cancels the impact
-- (leave callback below); a caster who died still lands it. The impact
-- finds its targets itself (area.query), so every object is current.
--   spec.anchor  the ground anchor (area.anchor)
--   spec.delay   seconds, (0, MAX_DELAY]
--   spec.impact  function(caster, anchor)
--   spec.radius  the warning ring's and the burst's reach (metres)
--   spec.color   tint of every particle (default the effects' own)
--   spec.warning, spec.fall, spec.burst: particle effect ids (default
--                area_warning, area_fall, area_impact); false shows none.
-- core.after, not a globalstep: one engine timer per pending impact, no
-- per-step work; a cooldown bounds how many a caster can have.
-- Returns true, or false and a refusal for a malformed spec.
function area.delayed(caster, spec)
	local delay = tonumber(spec.delay)
	if not spec.anchor or type(spec.impact) ~= "function" or not delay or
			delay <= 0 or delay > area.MAX_DELAY then
		core.log("warning", "[grug_core] area.delayed: malformed spec")
		return false, "Invalid area."
	end
	local name = caster:get_player_name()
	local anchor = vector.copy(spec.anchor)
	local frame = {target = anchor, reach = spec.radius, time = delay,
		color = spec.color}
	local play = grug_core.particles.play
	if spec.warning ~= false then
		play(spec.warning or "area_warning", frame)
	end
	if spec.fall ~= false then
		local height = area.fall_height(anchor, spec.radius)
		if height >= MIN_FALL then
			play(spec.fall or "area_fall", {target = anchor, reach = spec.radius,
				time = delay, height = height, color = spec.color})
		end
	end
	local entry = {}
	entry.job = core.after(delay, function()
		local list = pending[name]
		if list then
			list[entry] = nil
			if next(list) == nil then
				pending[name] = nil
			end
		end
		local player = core.get_player_by_name(name)
		if not player then
			return
		end
		if spec.burst ~= false then
			play(spec.burst or "area_impact", {target = anchor, reach = spec.radius,
				color = spec.color})
		end
		spec.impact(player, anchor)
	end)
	pending[name] = pending[name] or {}
	pending[name][entry] = true
	return true
end

-- How many impacts `name` has pending (fixtures and the probe).
function area.pending_count(name)
	local count = 0
	for _ in pairs(pending[name] or {}) do
		count = count + 1
	end
	return count
end

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	for entry in pairs(pending[name] or {}) do
		entry.job:cancel()
	end
	pending[name] = nil
end)
