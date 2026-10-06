-- The one particle path (Round 40, round40-plan.md §2.4-§2.6, §2.15, §3.4):
-- every game effect is a named list of emitters in particle_effects.lua, and
-- grug_core.particles.play(id, frame) turns it into engine calls. This file
-- and that catalogue are the one place a review checks the particle budget
-- ("hundreds at once, never thousands", AGENTS.md "Performance").
--
-- Engine facts (Luanti 5.17.0-dev, reference_projects/luanti):
-- * A spawner is serialized once per receiver inside the Lua call. One that
--   is unattached and lives 0 < time <= 1 s goes only to the players within
--   max_block_send_distance; an attached, longer or endless one goes to
--   every player on the server (src/server.cpp:1739). So this helper never
--   attaches a spawner and clamps its time to (0, 1].
-- * add_particle is queued and sent in the next server step to every player
--   in range, all of a step's particles in one compressed batch per player
--   (src/server.cpp:1656-1700). Exact shapes (a ring that marks a radius)
--   are single particles placed here, because a spawner's `radius` gives a
--   disc that is denser at the edge, not a ring (client/particles.cpp:384).
-- * `attract` is a rate: a particle gets |strength| x its distance from the
--   origin as speed, once at birth; a pulling one with die_on_contact lives
--   at most 1 / strength seconds (client/particles.cpp:398-458).
-- Nothing passes `playername`: no effect is private, every player in range
-- sees it the engine's way.
--
-- grug_particle_scale (settingtypes.txt, default 1.0, 0..2, read once at
-- load) scales every spawner's amount and every single-particle count, with
-- a floor of one particle per emitter; lifetimes, shapes and speeds stay.
-- 0 turns particles off entirely (play returns at once). A spawner's packet
-- has the same size at any amount, so the scale lowers what clients draw,
-- not a spawner's bytes; single particles scale both.
--
-- An emitter (coordinates in metres, in the frame of its anchor: +x is the
-- caster's facing, +y up, +z the caster's left -- Luanti is left-handed):
--   kind    "spawner" or "single" (a Lua loop of add_particle)
--   n       particles before the scale
--   time    spawner only: seconds, or "frame" (frame.time); clamped (0, 1]
--   at      "caster" (default) or "target": which anchor of the frame
--   shape   {"box", min, max}           a box (uniform)
--           {"line", from, to}          spawner: pos tweened over `time`;
--                                       single: evenly spaced, both ends in
--           {"line", "frame"}           the same along frame.from..frame.to
--                                       (world positions)
--           {"disc", centre, r, ring}   spawner: `radius` {r, 0, r} (a disc
--                                       heavy at the edge); single: an exact
--                                       ring of n when `ring`, else a disc
--           {"sphere", centre, r, shell}  spawner: `radius` {r, r, r} (a
--                                       shell) or a +-r box; single: on or in
--                                       the sphere
--   vel     {min, max} birth velocity; acc: a vector
--   radial  {min, max}: outward speed at the shape's radius (a spawner gets a
--           point attractor of negative strength speed / r, so inner
--           particles are slower); single: that speed outward from the
--           centre, or "reach": the speed that carries each particle to
--           frame.reach (metres from the centre) at the end of its life
--   attract {origin, strength, kill, at}: a point attractor at `origin` in
--           the anchor `at` (default the emitter's own), spawners only
--   exp, size  {min, max}; glow 0..14
--   color   tints default_item_smoke.png (frame.color overrides it), or tex:
--           a texture of its own; fade (default true): alpha 1 -> 0
-- A spawner's ranges (box extents, vel, acc) stay world-aligned; its centre
-- and line ends turn with the facing. A single particle turns entirely.
--
-- frame: {caster = pos, target = pos, dir = horizontal unit facing (default
-- +x), from, to, time, reach, color}. An emitter whose anchor is missing is
-- skipped; an unknown effect id logs a warning. An effect never stops a cast.

local particles = {}
grug_core.particles = particles

local MAX_TIME = 1      -- longer spawners go to every player (server.cpp:1739)
local MAX_COUNT = 128   -- per emitter, before the scale
local MAX_EXPTIME = 3
local MAX_SCALE = 2
local SMOKE = "default_item_smoke.png^[multiply:"

-- The scale from a setting string: a number in [0, MAX_SCALE], else 1.
function particles.parse_scale(value)
	local scale = tonumber(value)
	if not scale or scale ~= scale then
		return 1
	end
	return math.max(0, math.min(MAX_SCALE, scale))
end

particles.SCALE = particles.parse_scale(core.settings:get("grug_particle_scale"))

-- Particles of an emitter of `n` at `scale` (default the setting): none at
-- 0, otherwise rounded and at least one.
function particles.count(n, scale)
	scale = scale or particles.SCALE
	if scale <= 0 or n <= 0 then
		return 0
	end
	return math.max(1, math.floor(n * scale + 0.5))
end

-- A player's horizontal facing, the frame's `dir`.
function particles.facing(player)
	return core.yaw_to_dir(player:get_look_horizontal())
end

local registry = {}

local SHAPES = {box = true, line = true, disc = true, sphere = true}

-- nil when the emitter list keeps the budget rules, else the first problem.
function particles.check(emitters)
	if type(emitters) ~= "table" or #emitters == 0 then
		return "no emitters"
	end
	for index, e in ipairs(emitters) do
		local label = "emitter " .. index .. ": "
		if e.kind ~= "spawner" and e.kind ~= "single" then
			return label .. "kind must be spawner or single"
		end
		if type(e.n) ~= "number" or e.n < 1 or e.n > MAX_COUNT or e.n % 1 ~= 0 then
			return label .. "n must be an integer 1.." .. MAX_COUNT
		end
		if e.kind == "spawner" and e.time ~= "frame" and (type(e.time) ~= "number"
				or e.time <= 0 or e.time > MAX_TIME) then
			return label .. "a spawner's time must be in (0, " .. MAX_TIME .. "]"
		end
		if type(e.exp) ~= "table" or not e.exp[2] or e.exp[2] > MAX_EXPTIME
				or e.exp[1] <= 0 or e.exp[1] > e.exp[2] then
			return label .. "exp must be {min, max} within (0, " .. MAX_EXPTIME .. "]"
		end
		if type(e.shape) ~= "table" or not SHAPES[e.shape[1]] then
			return label .. "unknown shape"
		end
		if e.at and e.at ~= "caster" and e.at ~= "target" then
			return label .. "at must be caster or target"
		end
		if e.attract and e.kind ~= "spawner" then
			return label .. "attract is a spawner field"
		end
		if e.radial == "reach" and e.kind ~= "single" then
			return label .. "radial reach needs single particles"
		end
		if e.attached or e.playername then
			return label .. "never attached, never private"
		end
	end
	return nil
end

-- id -> an emitter list, or a function(frame) returning one (then `sample`
-- is a frame the check runs it with at load).
function particles.register(id, emitters, sample)
	assert(type(id) == "string" and not registry[id],
		"particle effect needs a new id: " .. tostring(id))
	local list = emitters
	if type(emitters) == "function" then
		list = emitters(sample or {})
	end
	local problem = particles.check(list)
	assert(not problem, "particle effect " .. id .. ": " .. tostring(problem))
	registry[id] = emitters
end

function particles.registered(id)
	return registry[id]
end

-- A local point (or offset) in the anchor's frame to world coordinates.
local function world(anchor, dir, v)
	return vector.new(anchor.x + v[1] * dir.x - v[3] * dir.z, anchor.y + v[2],
		anchor.z + v[1] * dir.z + v[3] * dir.x)
end

local function turn(dir, v)
	return vector.new(v[1] * dir.x - v[3] * dir.z, v[2], v[1] * dir.z + v[3] * dir.x)
end

local function vec(v)
	return vector.new(v[1], v[2], v[3])
end

local function rand(a, b)
	return a + (b - a) * math.random()
end

local function texture(e, frame)
	local name = e.tex or (SMOKE .. (frame.color or e.color))
	if e.fade == false then
		return name
	end
	return {name = name, alpha_tween = {1, 0}}
end

local function shape_radius(shape)
	if shape[1] == "disc" or shape[1] == "sphere" then
		return shape[3]
	end
	return 1
end

local function spawner(e, frame, dir, anchor, n)
	local time = e.time
	if time == "frame" then
		time = frame.time or MAX_TIME
	end
	time = math.max(0.01, math.min(MAX_TIME, time))
	local def = {
		amount = n,
		time = time,
		exptime = {min = e.exp[1], max = e.exp[2]},
		size = {min = e.size[1], max = e.size[2]},
		glow = e.glow or 0,
		texture = texture(e, frame),
	}
	local shape, centre = e.shape, nil
	local kind = shape[1]
	if kind == "box" then
		local lo, hi = shape[2], shape[3]
		centre = world(anchor, dir, {(lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2,
			(lo[3] + hi[3]) / 2})
		local half = vector.new((hi[1] - lo[1]) / 2, (hi[2] - lo[2]) / 2,
			(hi[3] - lo[3]) / 2)
		def.pos = {min = vector.subtract(centre, half), max = vector.add(centre, half)}
	elseif kind == "line" then
		local from, to
		if shape[2] == "frame" then
			from, to = frame.from, frame.to
			if not from or not to then return end
		else
			from, to = world(anchor, dir, shape[2]), world(anchor, dir, shape[3])
		end
		def.pos_tween = {from, to}
		centre = vector.multiply(vector.add(from, to), 0.5)
	elseif kind == "disc" or shape[4] then
		local r = shape[3]
		centre = world(anchor, dir, shape[2])
		def.pos = centre
		def.radius = kind == "disc" and vector.new(r, 0, r) or vector.new(r, r, r)
	else
		local r = shape[3]
		centre = world(anchor, dir, shape[2])
		def.pos = {min = vector.offset(centre, -r, -r, -r), max = vector.offset(centre, r, r, r)}
	end
	if e.vel then
		def.vel = {min = vec(e.vel[1]), max = vec(e.vel[2])}
	end
	if e.acc then
		def.acc = vec(e.acc)
	end
	if e.radial then
		local r = shape_radius(shape)
		def.attract = {kind = "point", origin = centre, die_on_contact = false,
			strength = {min = -e.radial[2] / r, max = -e.radial[1] / r}}
	elseif e.attract then
		local a = e.attract
		local origin_anchor = frame[a.at or e.at or "caster"]
		if not origin_anchor then return end
		def.attract = {kind = "point", origin = world(origin_anchor, dir, a.origin),
			strength = a.strength, die_on_contact = a.kill == true}
	end
	core.add_particlespawner(def)
end

-- A unit vector at random (rejection sampling keeps it uniform).
local function random_unit()
	while true do
		local x, y, z = math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1
		local l = math.sqrt(x * x + y * y + z * z)
		if l > 0.05 and l <= 1 then
			return x / l, y / l, z / l
		end
	end
end

-- One single particle's local position and the centre its radial speed
-- points away from.
local function single_point(shape, i, n)
	local kind = shape[1]
	if kind == "box" then
		local lo, hi = shape[2], shape[3]
		return {rand(lo[1], hi[1]), rand(lo[2], hi[2]), rand(lo[3], hi[3])},
			{(lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, (lo[3] + hi[3]) / 2}
	elseif kind == "line" then
		local from, to = shape[2], shape[3]
		local f = n > 1 and (i - 1) / (n - 1) or 0.5
		local p = {from[1] + (to[1] - from[1]) * f, from[2] + (to[2] - from[2]) * f,
			from[3] + (to[3] - from[3]) * f}
		return p, p
	end
	local c, r = shape[2], shape[3]
	if kind == "disc" then
		local angle, distance
		if shape[4] then
			-- An exact ring: n points evenly on the circle.
			angle, distance = 2 * math.pi * (i - 1) / n, r
		else
			angle, distance = 2 * math.pi * math.random(), r * math.sqrt(math.random())
		end
		return {c[1] + math.cos(angle) * distance, c[2], c[3] + math.sin(angle) * distance}, c
	end
	local x, y, z = random_unit()
	local distance = shape[4] and r or r * math.random() ^ (1 / 3)
	return {c[1] + x * distance, c[2] + y * distance, c[3] + z * distance}, c
end

local function singles(e, frame, dir, anchor, n)
	local shape = e.shape
	local tex = texture(e, frame)
	local acc = e.acc and turn(dir, e.acc) or nil
	local vlo, vhi = e.vel and e.vel[1] or {0, 0, 0}, e.vel and e.vel[2] or {0, 0, 0}
	local framed = shape[1] == "line" and shape[2] == "frame"
	if framed and (not frame.from or not frame.to) then return end
	for i = 1, n do
		local exptime = rand(e.exp[1], e.exp[2])
		local v = {rand(vlo[1], vhi[1]), rand(vlo[2], vhi[2]), rand(vlo[3], vhi[3])}
		local pos, velocity
		if framed then
			-- World positions along frame.from..frame.to; nothing turns.
			local f = n > 1 and (i - 1) / (n - 1) or 0.5
			pos = vector.add(frame.from, vector.multiply(vector.subtract(frame.to, frame.from), f))
			velocity = vec(v)
		else
			local p, c = single_point(shape, i, n)
			if e.radial then
				local dx, dy, dz = p[1] - c[1], p[2] - c[2], p[3] - c[3]
				local d = math.sqrt(dx * dx + dy * dy + dz * dz)
				if d > 0 then
					local speed
					if e.radial == "reach" then
						speed = math.max(0, ((frame.reach or d) - d) / exptime)
					else
						speed = rand(e.radial[1], e.radial[2])
					end
					v[1], v[2], v[3] = v[1] + dx / d * speed, v[2] + dy / d * speed,
						v[3] + dz / d * speed
				end
			end
			pos, velocity = world(anchor, dir, p), turn(dir, v)
		end
		core.add_particle({
			pos = pos,
			velocity = velocity,
			acceleration = acc,
			expirationtime = exptime,
			size = rand(e.size[1], e.size[2]),
			glow = e.glow or 0,
			texture = tex,
		})
	end
end

local DEFAULT_DIR = vector.new(1, 0, 0)

-- Plays effect `id` (particle_effects.lua) in `frame` (see the header).
function particles.play(id, frame)
	if particles.SCALE <= 0 then
		return
	end
	local effect = registry[id]
	if not effect then
		core.log("warning", "[grug_core] unknown particle effect " .. tostring(id))
		return
	end
	if type(effect) == "function" then
		effect = effect(frame)
	end
	local dir = frame.dir or DEFAULT_DIR
	for _, e in ipairs(effect) do
		local anchor = frame[e.at or "caster"]
		local n = particles.count(e.n)
		local framed = e.shape[1] == "line" and e.shape[2] == "frame"
		if (anchor or framed) and n > 0 then
			if e.kind == "spawner" then
				spawner(e, frame, dir, anchor, n)
			else
				singles(e, frame, dir, anchor, n)
			end
		end
	end
end
