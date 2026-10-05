-- Disposable Round 35 T upstream check (tools/r35_t/upstream_check.sh).
-- Never shipped. The repro of the upstream report (server raycast turns a
-- `rotate = true` selection box by degrees read as radians, Luanti 5.12+):
-- an entity with a tall, narrow rotated box, turned through yaws 0-345 deg
-- in 15 deg steps, and per yaw one horizontal ray through the ENGINE alone
-- (core.raycast, none of the game's code) at 1.5 nodes height straight
-- through the box's vertical axis, which every turn of the box contains. A
-- fixed engine hits at every yaw. Every line carries "[r35tup]"; the probe
-- ends the server when done.
local P = "[r35tup] "
local function log(s) core.log("action", P .. s) end

core.register_entity("grug_probe_r35_t_upstream:pillar", {
	initial_properties = {
		visual = "cube", textures = {"blank.png"},
		visual_size = {x = 0.6, y = 2, z = 0.6},
		selectionbox = {-0.3, 0, -0.3, 0.3, 2, 0.3, rotate = true},
		collisionbox = {-0.3, 0, -0.3, 0.3, 2, 0.3},
		physical = false, static_save = false,
	},
})

local BASE = {x = 8, y = 200, z = 8}
local phase, t, emerged = "wait", 0, false

local function run()
	local obj = core.add_entity(BASE, "grug_probe_r35_t_upstream:pillar")
	if not obj then
		log("RESULT UPSTREAM ERROR could not add the entity")
		return
	end
	local misses, marks = 0, {}
	for deg = 0, 345, 15 do
		obj:set_yaw(math.rad(deg))
		local from = vector.add(BASE, {x = 0, y = 1.5, z = -2})
		local to = vector.add(BASE, {x = 0, y = 1.5, z = 2})
		local hit = false
		for pointed in core.raycast(from, to, true, false) do
			if pointed.type == "object" and pointed.ref == obj then hit = true end
		end
		if not hit then misses = misses + 1 end
		marks[#marks + 1] = deg .. ":" .. (hit and "hit" or "MISS")
	end
	obj:remove()
	log("UPSTREAM " .. table.concat(marks, " "))
	local version = core.get_version()
	log(("RESULT UPSTREAM engine %s %s: %d of 24 yaws miss -> %s"):format(
		version.project, version.hash or version.string, misses,
		misses == 0 and "FIXED (the Lua workaround can go, see upstream-workarounds.md)"
		or "BUG PRESENT (keep the workaround)"))
end

core.register_globalstep(function(dtime)
	t = t + dtime
	if phase == "wait" and t > 3 then
		core.emerge_area(vector.subtract(BASE, {x = 8, y = 8, z = 8}),
			vector.add(BASE, {x = 8, y = 8, z = 8}), function(_, _, remaining)
				if remaining == 0 then emerged = true end
			end)
		core.forceload_block(BASE, true)
		phase, t = "emerge", 0
	elseif phase == "emerge" and (emerged or t > 60) then
		run()
		phase, t = "done", 0
	elseif phase == "done" and t > 1 then
		log("RESULT DONE")
		phase = "off"
		core.request_shutdown("r35tup probe done", false, 0)
	end
end)
