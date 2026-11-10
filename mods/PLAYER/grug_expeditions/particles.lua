-- The Expeditions' ambient particles (Round 73, concept section 4.8): the template's
-- `particles` lines (template.lua), drawn here in a style that fits the place. Rules:
-- docs/design/expeditions.md section 8; the lines: docs/technical/expedition-template-format.md.
--
-- One endless spawner per line and per player of the run inside, sent to that player
-- alone (`playername`): added when they enter the box, deleted when they leave it
-- (travel, logout, expelled) and when the run ends; a respawn inside keeps them. So
-- the particles run only while someone of the run is inside, reach nobody else, and
-- nothing is left after the run (a restart ends every run, and a client forgets its
-- spawners when it disconnects). Not the shared effect path of grug_core/particles.lua:
-- that one is public by rule and at most a second long; these belong to one run.
--
-- A line's amount is the most live particles its spawner keeps: an endless spawner
-- makes `rate` particles a second, each living at most `life` seconds, so rate x life
-- stays within the amount (a small amount shortens the life instead of rounding the
-- rate to nothing). grug_particle_scale scales the amount, 0 turns them off. A
-- template's amounts add up to template.PARTICLE_BUDGET at most (300).
--
-- STYLES, each drawn with texture modifiers over shipped PNGs (grug_core_mote.png, a
-- soft white mote, and default_paper.png):
--   drip   water drops falling from the box's top row and gone on the floor
--   dust   pale motes hanging in the air, fading in and out
--   ash    grey flakes sinking slowly, settling on the floor
--   paper  small paper scraps drifting down
--   ember  orange sparks of light rising, glowing
--   spark  bright sparks thrown up and falling back, short-lived
local M = grug_expeditions
local A = {}
M.ambience = A

local MOTE = "grug_core_mote.png^[multiply:"

-- life {min, max} in seconds; vel and acc in nodes a second; top: born in the box's
-- top row only; fade: alpha 0 -> peak -> 0 over the life ("pulse"), else 1 -> 0.
A.STYLES = {
	drip = {tex = MOTE .. "#8db4d0", size = {0.5, 0.8}, life = {0.6, 1.2}, top = true,
		vel = {{0, -0.5, 0}, {0, -0.2, 0}}, acc = {x = 0, y = -6, z = 0}, glow = 3,
		collide = true, peak = 0.8},
	dust = {tex = MOTE .. "#b8ab92", size = {0.6, 1.2}, life = {5, 8},
		vel = {{-0.08, -0.04, -0.08}, {0.08, 0.06, 0.08}}, glow = 2, pulse = true, peak = 0.55},
	ash = {tex = MOTE .. "#77716b", size = {0.6, 1.1}, life = {5, 8},
		vel = {{-0.15, -0.3, -0.15}, {0.15, -0.1, 0.15}}, glow = 1, collide = true, peak = 0.8},
	paper = {tex = "default_paper.png^[colorize:#5c4a2e:70", size = {1, 1.5}, life = {5, 8},
		vel = {{-0.3, -0.4, -0.3}, {0.3, -0.15, 0.3}}, glow = 1, collide = true, peak = 0.9},
	ember = {tex = MOTE .. "#ff7a2a", size = {0.6, 1.1}, life = {2, 3.5}, add = true,
		vel = {{-0.25, 0.4, -0.25}, {0.25, 1, 0.25}}, acc = {x = 0, y = -0.05, z = 0}, glow = 13,
		peak = 1},
	spark = {tex = MOTE .. "#ffd27a", size = {0.4, 0.7}, life = {0.5, 1}, add = true,
		vel = {{-1, 1.5, -1}, {1, 3, 1}}, acc = {x = 0, y = -9, z = 0}, glow = 14,
		collide = true, peak = 1},
}

-- The rate a second and the life range for `amount` live particles: rate x life <= amount.
function A.rate(style, amount)
	local life = style.life
	local rate = math.max(1, math.floor(amount / life[2]))
	local longest = math.min(life[2], amount / rate)
	return rate, math.min(life[1], longest), longest
end

local function vec(v) return {x = v[1], y = v[2], z = v[3]} end

-- The spawner definition of one line (map coordinates `min`, `max`: the box's cells)
-- for `name`, or nil when the scale turns it off.
function A.spawner(row, min, max, name)
	local style = A.STYLES[row.style]
	local scale = grug_core.particles and grug_core.particles.count or function(n) return n end
	local amount = scale(row.amount)
	if amount <= 0 then return nil end
	local rate, short, long = A.rate(style, amount)
	local low = {x = min.x - 0.5, y = (style.top and max.y or min.y) - 0.5, z = min.z - 0.5}
	local high = {x = max.x + 0.5, y = max.y + 0.5, z = max.z + 0.5}
	if style.top then low.y = high.y - 0.4 end
	return {
		amount = rate,
		time = 0,
		pos = {min = low, max = high},
		vel = {min = vec(style.vel[1]), max = vec(style.vel[2])},
		acc = style.acc,
		exptime = {min = short, max = long},
		size = {min = style.size[1], max = style.size[2]},
		collisiondetection = style.collide == true,
		collision_removal = style.collide == true and style.top == true,
		glow = style.glow,
		texture = {name = style.tex, blend = style.add and "add" or nil,
			alpha_tween = style.pulse and {0, style.peak, style = "pulse", reps = 1} or
				{style.peak, 0}},
		playername = name,
	}
end

local runs = {} -- run -> {rows = {{row, min, max}}, ids = {name -> {spawner ids}}}

local function stop(state, name)
	local ids = state.ids[name]
	if not ids then return end
	state.ids[name] = nil
	-- Gone already (a logout): the server-wide delete still frees the id.
	local target = core.get_player_by_name(name) and name or nil
	for _, id in ipairs(ids) do core.delete_particlespawner(id, target) end
end

local function start(state, name)
	if state.ids[name] or not core.get_player_by_name(name) then return end
	local ids = {}
	for _, entry in ipairs(state.rows) do
		local def = A.spawner(entry.row, entry.min, entry.max, name)
		local id = def and core.add_particlespawner(def)
		if id and id >= 0 then ids[#ids + 1] = id end
	end
	state.ids[name] = ids
end

M.register_on_ready(function(run)
	local def = M.definition(run.expedition)
	local tpl = def and def.template and M.templates[def.template]
	if not (tpl and tpl.particles and #tpl.particles > 0) then return end
	local state = {rows = {}, ids = {}}
	for _, row in ipairs(tpl.particles) do
		local m = run.minp
		state.rows[#state.rows + 1] = {row = row,
			min = {x = m.x + row.min.x, y = m.y + row.min.y, z = m.z + row.min.z},
			max = {x = m.x + row.max.x, y = m.y + row.max.y, z = m.z + row.max.z}}
	end
	runs[run] = state
	for name in pairs(run.inside) do start(state, name) end
end)

M.register_on_enter(function(run, name)
	local state = runs[run]
	if state then start(state, name) end
end)

M.register_on_leave(function(run, name)
	local state = runs[run]
	if state then stop(state, name) end
end)

M.register_on_end(function(run)
	local state = runs[run]
	if not state then return end
	for name in pairs(state.ids) do stop(state, name) end
	runs[run] = nil
end)

-- The live spawners of a run's player (a probe's reading): their count, or 0.
function A.count(run, name)
	local state = runs[run]
	return state and state.ids[name] and #state.ids[name] or 0
end
