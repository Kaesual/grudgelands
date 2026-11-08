-- Disposable Round 72 RANGED probe (tools/r72_ranged/run.sh). Never shipped.
--
-- Four lanes on a forceloaded stone floor high in the air, each with one
-- Elf King (the ranged kings share one definition path) sent at a standing,
-- player-sized dummy:
--   open   the dummy 15 m away on the floor;
--   cover  12 m away behind a wall 4 high and 9 wide;
--   ledge  on a pillar 5 high, 10 m away (unreachable, in sight);
--   far    30 m away on the floor.
-- Each lane runs RUN_SECONDS (under the kings' 15 s no-contact reset; a
-- dummy is no player). Logged per lane: the ordinary shots (the
-- definition's arrow_override, wrapped: locked or refused), when the king
-- first saw the dummy, how far he moved, the ranged/melee phase, and the
-- navigation's events for him; at the end the navigation's server-wide
-- counts (searches, found, the largest search in us). Every line carries
-- "[r72ranged]"; the last one is "RESULT DONE".

local MOD = core.get_current_modname()
local P = "[r72ranged] "
local function log(s) core.log("action", P .. s) end
local floor, sqrt = math.floor, math.sqrt
local nav = mobs.grug_nav

local KING = "grug_mobs:king_elf"
local Y0 = 600 -- the floor's top node
local RUN_SECONDS = 14
local SAMPLE = 0.25
local LANES = {
	{name = "open", target = {x = 15, h = 0}},
	{name = "cover", target = {x = 12, h = 0}, wall = true},
	{name = "ledge", target = {x = 10, h = 5}, pillar = true},
	{name = "far", target = {x = 30, h = 0}},
}
local PITCH = 24

local function lane_z(i) return (i - 1) * PITCH end

-- The dummy (a player's collision box), standing still under gravity.
core.register_entity(MOD .. ":dummy", {
	initial_properties = {
		physical = true, collide_with_objects = false, static_save = false,
		hp_max = 1000, visual = "cube",
		textures = {"default_stone.png", "default_stone.png", "default_stone.png",
			"default_stone.png", "default_stone.png", "default_stone.png"},
		visual_size = {x = 0.6, y = 1.77},
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.77, 0.3},
	},
	-- A live target for the arrows' lock (grug_core homing.lua `identity`
	-- refuses an entity without health; the first run's every shot was
	-- refused so).
	health = 1000,
	on_activate = function(self)
		self.object:set_acceleration({x = 0, y = -9.81, z = 0})
		self.object:set_armor_groups({fleshy = 0, immortal = 1})
	end,
	on_punch = function() return true end,
})

-- Which lane a king belongs to (by object).
local by_object = {}

-- Count each ordinary shot: the wrapped arrow_override sees the arrow after
-- the lock; a refused lock removed it (grug_mobs.stamp_arrow_damage).
core.register_on_mods_loaded(function()
	local def = core.registered_entities[KING]
	local original = def.arrow_override
	def.arrow_override = function(ent, mob)
		original(ent, mob)
		local lane = mob and by_object[mob.object]
		if lane then
			local key = ent and ent._grug_lock and "shots" or "refused"
			lane[key] = lane[key] + 1
			if key == "shots" and not lane.first_shot then
				lane.first_shot = lane.t
			end
		end
	end
	nav.on_event = function(self, kind)
		local lane = self and self.object and by_object[self.object]
		if lane then lane.events[kind] = (lane.events[kind] or 0) + 1 end
	end
end)

local function build()
	local stone = {name = "default:stone"}
	local floor_cells = {}
	for i, lane in ipairs(LANES) do
		local z0 = lane_z(i)
		for x = -6, 36 do
			for z = z0 - 8, z0 + 8 do
				floor_cells[#floor_cells + 1] = {x = x, y = Y0, z = z}
			end
		end
		if lane.wall then
			for y = Y0 + 1, Y0 + 4 do
				for z = z0 - 4, z0 + 4 do
					floor_cells[#floor_cells + 1] = {x = 5, y = y, z = z}
				end
			end
		end
		if lane.pillar then
			for y = Y0 + 1, Y0 + 5 do
				floor_cells[#floor_cells + 1] = {x = 10, y = y, z = z0}
			end
		end
	end
	core.bulk_set_node(floor_cells, stone)
end

local function distance(a, b)
	local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
	return sqrt(x * x + y * y + z * z)
end

local function report(lane)
	local ev = {}
	for kind, n in pairs(lane.events) do ev[#ev + 1] = kind .. "=" .. n end
	table.sort(ev)
	log(("LANE %s shots=%d refused=%d first_sight=%s first_shot=%s moved=%.1f "
		.. "end_dist=%.1f melee_samples=%d gave_up=%s events={%s}"):format(lane.name,
		lane.shots, lane.refused, tostring(lane.first_sight), tostring(lane.first_shot),
		lane.moved, lane.end_dist or -1, lane.melee, tostring(lane.gave_up),
		table.concat(ev, ",")))
end

local function start()
	local live = {}
	for i, spec in ipairs(LANES) do
		local z0 = lane_z(i)
		local start_pos = {x = 0, y = Y0 + 1, z = z0}
		local tpos = {x = spec.target.x, y = Y0 + 1 + spec.target.h, z = z0}
		local obj = core.add_entity(start_pos, KING)
		local dummy = core.add_entity(tpos, MOD .. ":dummy")
		local ent = obj and obj:get_luaentity()
		if not ent or not dummy then
			core.log("error", P .. "spawn failed in lane " .. spec.name)
			return core.request_shutdown("r72ranged fail", false, 0)
		end
		local lane = {name = spec.name, obj = obj, dummy = dummy, shots = 0, refused = 0,
			moved = 0, melee = 0, events = {}, t = 0}
		by_object[obj] = lane
		live[#live + 1] = lane
	end
	-- One second for activation (level, stats), then the attack.
	core.after(1, function()
		for _, lane in ipairs(live) do
			local ent = lane.obj:get_luaentity()
			ent.timer = 0
			ent:do_attack(lane.dummy, true)
			lane.last = lane.obj:get_pos()
		end
		local t = 0
		local function sample()
			t = t + SAMPLE
			for _, lane in ipairs(live) do
				lane.t = t
				local ent = lane.obj:get_luaentity()
				local p, tp = lane.obj:get_pos(), lane.dummy:get_pos()
				if ent and p and tp then
					lane.moved = lane.moved + distance(p, lane.last)
					lane.last = p
					lane.end_dist = distance(p, tp)
					if not lane.first_sight and ent:line_of_sight(
							{x = p.x, y = p.y + 0.5, z = p.z},
							{x = tp.x, y = tp.y + 0.5, z = tp.z}) then
						lane.first_sight = t
					end
					if ent.dogshoot_switch == 2 then lane.melee = lane.melee + 1 end
					if ent.attack ~= lane.dummy then lane.gave_up = lane.gave_up or t end
				end
			end
			if t < RUN_SECONDS then return core.after(SAMPLE, sample) end
			for _, lane in ipairs(live) do report(lane) end
			local c = nav.counters
			log(("NAV searches=%d found=%d cap_waits=%d largest_us=%d"):format(c.searches,
				c.found, c.cap_waits, c.largest_us))
			log("RESULT DONE")
			core.request_shutdown("r72ranged done", false, 0)
		end
		core.after(SAMPLE, sample)
	end)
end

core.after(1, function()
	local minp = {x = -6, y = Y0 - 1, z = -8}
	local maxp = {x = 36, y = Y0 + 8, z = lane_z(#LANES) + 8}
	for bx = floor(minp.x / 16), floor(maxp.x / 16) do
		for by = floor(minp.y / 16), floor(maxp.y / 16) do
			for bz = floor(minp.z / 16), floor(maxp.z / 16) do
				core.forceload_block({x = bx * 16, y = by * 16, z = bz * 16}, true, -1)
			end
		end
	end
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining ~= 0 then return end
		core.after(0, function()
			build()
			log("arena built")
			core.after(1, start)
		end)
	end)
end)
