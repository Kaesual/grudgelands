-- Round 40 CH: the server-side Lua cost of Charge, before and after the dash
-- (a disposable probe, never shipped; numbers are comparisons, never
-- targets). A headless server has no player, so the probe calls what the
-- cast calls on natural terrain of a pinned seed:
--   cast     "before": the destination search (grug_abilities.
--            charge_destination), the only map work of the teleport cast;
--            "after": the same search plus the planned path
--            (grug_abilities.charge_plan), when the build has it
--   carrier  "after" only: real dashes (grug_abilities.charge_dash) of
--            stand-in riders, each Lua on_step of the carrier timed
-- The stand-in rider is an entity behind a player-shaped proxy that
-- core.get_player_by_name returns for its name (the dash re-fetches its
-- rider by name every step). Its target is a plain entity, so the arrival
-- check runs and finds no hostile: the hit's damage path is not part of it.
--   KEEP=1 SEED=4242 PROBE=tools/r40_ch/bench \
--     ~/projects/grudgelands-orchestration/r40/engine_run.sh <label> 300
-- (from the worktree root; the "[r40 ch bench]" lines of the kept log).

local US = core.get_us_time
local BOX = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}
local EYE = 1.47
local REPS = 5
local MOD = core.get_current_modname()

local function log(line)
	core.log("action", "[r40 ch bench] " .. line)
end

local function median(list)
	table.sort(list)
	return list[math.floor((#list + 1) / 2)] or 0
end

local function pct(list, p)
	table.sort(list)
	return list[math.max(1, math.ceil(#list * p))] or 0
end

-- Feet height of the highest standing spot in the column (walkable below,
-- two passable nodes above) between y_hi and y_lo; nil if none.
local function surface(x, z, y_hi, y_lo)
	for y = y_hi, y_lo, -1 do
		local below = core.registered_nodes[core.get_node({x = x, y = y - 1, z = z}).name]
		local here = core.registered_nodes[core.get_node({x = x, y = y, z = z}).name]
		local up = core.registered_nodes[core.get_node({x = x, y = y + 1, z = z}).name]
		if below and below.walkable and here and not here.walkable and
				(here.liquidtype or "none") == "none" and up and not up.walkable then
			return y - 0.5
		end
	end
	return nil
end

core.register_entity(MOD .. ":rider", {
	initial_properties = {
		physical = false, static_save = false, pointable = false,
		visual = "sprite", textures = {"grug_mobs_blank.png"},
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
	},
})
core.register_entity(MOD .. ":target", {
	initial_properties = {
		physical = false, static_save = false,
		visual = "sprite", textures = {"grug_mobs_blank.png"},
		collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
	},
})

-- The cast's map work from `origin` to every target spot.
local function casts(origin)
	local dests, plans, both = {}, {}, {}
	local cases, refused, cut, jumps = 0, 0, 0, 0
	for _, dist in ipairs({6, 11}) do
		for k = 0, 15 do
			local ang = k * math.pi / 8
			local x = math.floor(origin.x + dist * math.cos(ang) + 0.5)
			local z = math.floor(origin.z + dist * math.sin(ang) + 0.5)
			local y = surface(x, z, math.floor(origin.y) + 8, math.floor(origin.y) - 8)
			if y then
				cases = cases + 1
				local target = {x = x, y = y, z = z}
				local d_list, p_list, b_list = {}, {}, {}
				local dest, plan
				for _ = 1, REPS do
					local c0 = US()
					dest = grug_abilities.charge_destination(origin, EYE, BOX, target)
					local c1 = US()
					d_list[#d_list + 1] = c1 - c0
					if dest and grug_abilities.charge_plan then
						plan = grug_abilities.charge_plan(origin, dest)
						local c2 = US()
						p_list[#p_list + 1] = c2 - c1
						b_list[#b_list + 1] = c2 - c0
					end
				end
				dests[#dests + 1] = median(d_list)
				if not dest then
					refused = refused + 1
				elseif plan then
					plans[#plans + 1] = median(p_list)
					both[#both + 1] = median(b_list)
					if plan.cut then cut = cut + 1 end
					jumps = jumps + (plan.jumps or 0)
				end
			end
		end
	end
	return {dests = dests, plans = plans, both = both, cases = cases,
		refused = refused, cut = cut, jumps = jumps}
end

local function summary(label, list)
	if #list == 0 then return label .. ": none" end
	local sum = 0
	for _, v in ipairs(list) do sum = sum + v end
	return ("%s: median %d us, p90 %d us, max %d us, mean %.1f us (%d casts)"):format(
		label, median(list), pct(list, 0.9), pct(list, 1), sum / #list, #list)
end

-- Stand-in riders: a proxy that answers like a player and forwards the rest
-- to the rider entity.
local proxies = {}
local real_get_player = core.get_player_by_name
core.get_player_by_name = function(name)
	return proxies[name] or real_get_player(name)
end

local function proxy(obj, name)
	local p = {}
	p.get_player_name = function() return name end
	p.is_player = function() return true end
	p.get_hp = function() return 20 end
	p.set_fov = function() end
	p.get_look_horizontal = function() return 0 end
	p.get_meta = function() return core.get_mod_storage() end
	return setmetatable(p, {__index = function(_, key)
		local f = obj[key]
		if type(f) ~= "function" then return f end
		return function(_, ...) return f(obj, ...) end
	end})
end

local function carriers(origin, done)
	if not grug_abilities.charge_dash then
		log("carrier: this build has no dash (before)")
		return done()
	end
	local name = "grug_abilities:charge_carrier"
	local def = core.registered_entities[name]
	local inner = def.on_step
	local steps = {}
	def.on_step = function(self, dtime, moveresult)
		local c0 = US()
		inner(self, dtime, moveresult)
		steps[#steps + 1] = US() - c0
	end
	local spots = {}
	for k = 0, 7 do
		local ang = k * math.pi / 4
		local x = math.floor(origin.x + 11 * math.cos(ang) + 0.5)
		local z = math.floor(origin.z + 11 * math.sin(ang) + 0.5)
		local y = surface(x, z, math.floor(origin.y) + 8, math.floor(origin.y) - 8)
		if y then spots[#spots + 1] = {x = x, y = y, z = z} end
	end
	local k, dashes, starts = 0, 0, {}
	local function next_run()
		k = k + 1
		local spot = spots[k]
		if not spot then
			def.on_step = inner
			local sum = 0
			for _, v in ipairs(steps) do sum = sum + v end
			log(("carrier: %d dashes, %d carrier steps, per step mean %.1f us, median %d us, p90 %d us, max %d us")
				:format(dashes, #steps, sum / math.max(1, #steps), median(steps),
					pct(steps, 0.9), pct(steps, 1)))
			log(summary("dash start (charge_dash: plan, carrier, attach)", starts))
			return done()
		end
		local rider = core.add_entity(origin, MOD .. ":rider")
		local target = core.add_entity(vector.offset(spot, 0, 0, 0), MOD .. ":target")
		local pname = "bench:" .. k
		proxies[pname] = proxy(rider, pname)
		local dest = grug_abilities.charge_destination(origin, EYE, BOX, spot)
		if not dest then
			rider:remove()
			target:remove()
			proxies[pname] = nil
			return core.after(0.1, next_run)
		end
		local c0 = US()
		local ok = grug_abilities.charge_dash(proxies[pname], target, dest,
			grug_abilities.registered.charge)
		starts[#starts + 1] = US() - c0
		if ok then dashes = dashes + 1 end
		core.after(1.5, function()
			rider:remove()
			target:remove()
			proxies[pname] = nil
			next_run()
		end)
	end
	next_run()
end

local function run(origin)
	local r = casts(origin)
	log(("casts from %s: %d targets at 6 and 11 m in 16 directions, %d refused (no room or no line of sight), %d paths cut, %d hole jumps")
		:format(core.pos_to_string(origin), r.cases, r.refused, r.cut, r.jumps))
	log(summary("destination search (before and after)", r.dests))
	log(summary("planned path (after)", r.plans))
	log(summary("destination + path (after)", r.both))
	-- Entities only step in active blocks; with no player that means
	-- force-loaded ones.
	local blocks = {}
	for bx = math.floor((origin.x - 14) / 16), math.floor((origin.x + 14) / 16) do
		for by = math.floor((origin.y - 10) / 16), math.floor((origin.y + 10) / 16) do
			for bz = math.floor((origin.z - 14) / 16), math.floor((origin.z + 14) / 16) do
				local b = {x = bx * 16, y = by * 16, z = bz * 16}
				if core.forceload_block(b, true) then blocks[#blocks + 1] = b end
			end
		end
	end
	core.after(1, function()
		carriers(origin, function()
			for _, b in ipairs(blocks) do core.forceload_free_block(b, true) end
			log("done")
			core.request_shutdown("r40 ch bench done", false, 0)
		end)
	end)
end

-- Land near one of the candidate points (surface at y >= 2 with ground in
-- most directions around it).
local CANDIDATES = {{0, 0}, {256, 0}, {0, 256}, {-256, 0}, {0, -256}, {512, 512}}

local function land_near(cx, cz)
	for dz = -8, 8, 4 do
		for dx = -8, 8, 4 do
			local x, z = cx + dx, cz + dz
			local y = surface(x, z, 78, 2)
			if y then
				local around = 0
				for k = 0, 7 do
					local ang = k * math.pi / 4
					if surface(math.floor(x + 11 * math.cos(ang) + 0.5),
							math.floor(z + 11 * math.sin(ang) + 0.5),
							math.floor(y) + 8, math.floor(y) - 8) then
						around = around + 1
					end
				end
				if around >= 6 then return {x = x, y = y, z = z} end
			end
		end
	end
	return nil
end

core.register_on_mods_loaded(function()
	core.after(2, function()
		local k = 0
		local function try_next()
			k = k + 1
			local c = CANDIDATES[k]
			if not c then
				log("no land found near the candidates")
				core.request_shutdown("r40 ch bench done", false, 0)
				return
			end
			local p1 = {x = c[1] - 24, y = -16, z = c[2] - 24}
			local p2 = {x = c[1] + 24, y = 79, z = c[2] + 24}
			local t0 = US()
			core.emerge_area(p1, p2, function(_, _, remaining)
				if remaining > 0 then return end
				log(("emerged %s..%s in %.1f s"):format(core.pos_to_string(p1),
					core.pos_to_string(p2), (US() - t0) / 1e6))
				local origin = land_near(c[1], c[2])
				if origin then run(origin) else try_next() end
			end)
		end
		try_next()
	end)
end)
