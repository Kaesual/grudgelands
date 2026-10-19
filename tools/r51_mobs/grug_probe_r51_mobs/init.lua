-- Disposable engine probe (Round 51 lane MOBS, step M1). Never shipped:
-- tools/r51_mobs/probe.sh stages it through tools/luanti_headless.sh.
--
-- A test arena high above a deep-ocean column (nothing built below it):
-- three pools and a tank, built with a VoxelManip and force-loaded.
--   lake_frog, lake_tortoise  a lake 3 deep with a one-deep sand shelf along
--                             its edge and a bank level with the water;
--   sea_ray                   sea water 5 deep to a bank level with it;
--   tank                      a 6-deep tank with every new water mob.
-- 1. Every new mob spawns by command (core.add_entity, as /spawnentity
--    does): its name, level, tier and HP are logged, and every swimmer stays
--    in the water for the run.
-- 2. Amphibian navigation (sea plan §6.1): a frog and a tortoise chase a
--    probe player who swims to the shore, walks 9 nodes inland, waits, and
--    swims back; logged every second, checked: they follow ashore, reach the
--    player there, and follow back into the water.
-- 3. The swimmer reset (S11): a stingray fights a probe player in the water,
--    keeps fighting while the player stays in, resets (healed, given up) the
--    moment the player steps ashore, never attacks the player standing on
--    the bank, never leaves the water, and takes the player again once back
--    in the water.
-- 4. Fish loot: one kill of each family by the probe player's ability hit
--    drops its band's fish.
-- A headless server has no client, so a "player" is an invisible entity
-- whose ObjectRef answers the player accessors (tools/pt_fixes/lane_c).
-- The mob code is the shipped code. Lines "[r51mobs] ...", "RESULT PASS".

local P = "[r51mobs] "
local WATER = "default:water_source"
local W = 300 -- the water surface layer of every pool
local BASE_Y = 290
local failures, checks = 0, 0

local function log(msg) core.log("action", P .. msg) end
local function check(ok, msg)
	checks = checks + 1
	if ok then
		log("ok   " .. msg)
	else
		failures = failures + 1
		core.log("error", P .. "FAIL " .. msg)
	end
	return ok
end
local function fmt(p)
	return p and ("(%.1f,%.1f,%.1f)"):format(p.x, p.y, p.z) or "nil"
end

--
-- Probe players (tools/pt_fixes/lane_c, tools/r22_ability_punch).
--
core.register_entity("grug_probe_r51_mobs:hero", {
	initial_properties = {
		physical = false, pointable = false, static_save = false,
		hp_max = 100, visual = "sprite", textures = {"blank.png"},
		is_visible = false, collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
	},
	-- A mob's bite must not remove the probe player.
	on_punch = function() return true end,
})

local fakes, by_name = {}, {}
local methods
local function install(ref)
	if methods then return end
	methods = getmetatable(ref)
	local function override(name, fn)
		local original = methods[name]
		methods[name] = function(self, ...)
			local fake = fakes[self]
			if fake then return fn(fake, ...) end
			return original(self, ...)
		end
	end
	override("is_player", function() return true end)
	override("get_player_name", function(f) return f.name end)
	override("get_player_control", function() return {} end)
	override("get_player_control_bits", function() return 0 end)
	override("get_look_dir", function() return vector.new(0, 0, 1) end)
	override("get_look_horizontal", function() return 0 end)
	override("get_look_vertical", function() return 0 end)
	override("get_meta", function(f) return f.holder:get_meta() end)
	override("get_inventory", function(f) return f.inv end)
	override("get_wield_list", function() return "main" end)
	override("get_wield_index", function() return 1 end)
	override("get_wielded_item", function(f) return f.inv:get_stack("main", 1) end)
	override("set_wielded_item", function(f, stack) return f.inv:set_stack("main", 1, stack) end)
	local get_player_by_name = core.get_player_by_name
	core.get_player_by_name = function(name)
		return by_name[name] or get_player_by_name(name)
	end
end

local function make_player(label, pos)
	local ref = core.add_entity(pos, "grug_probe_r51_mobs:hero")
	assert(ref, "probe player entity was not added")
	install(ref)
	local name = "probe_" .. label
	local inv = core.create_detached_inventory("grug_probe_r51_" .. label, {})
	inv:set_size("main", 8)
	fakes[ref] = {name = name, holder = ItemStack("default:stick"), inv = inv}
	by_name[name] = ref
	local auth = core.get_auth_handler()
	if not auth.get_auth(name) then auth.create_auth(name, "") end
	core.set_player_privs(name, {interact = true})
	return ref
end

--
-- Arena: cells in a row along x.
--
local CELLS = {
	{label = "lake_frog", size = 32, inset = 6, depth = 3, shelf = true},
	{label = "lake_tortoise", size = 32, inset = 6, depth = 3, shelf = true},
	{label = "sea_ray", size = 32, inset = 6, depth = 5},
	{label = "tank", size = 48, inset = 12, depth = 6},
}
local cell = {}
local origin

local function arena_bounds()
	local length = 0
	for _, spec in ipairs(CELLS) do length = length + spec.size end
	return vector.new(origin.x, BASE_Y, origin.z),
		vector.new(origin.x + length - 1, BASE_Y + 14, origin.z + 39)
end

local function build_arena()
	local minp, maxp = arena_bounds()
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local cid = core.get_content_id
	local air, stone, sand = cid("air"), cid("default:stone"), cid("default:sand")
	local dirt, grass, water = cid("default:dirt"), cid("default:dirt_with_grass"), cid(WATER)
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				-- Land everywhere first: dirt to the bank level W, grass on top.
				local id = air
				if y < W then id = dirt elseif y == W then id = grass end
				if y == BASE_Y then id = stone end
				data[area:index(x, y, z)] = id
			end
		end
	end
	local cx = origin.x
	for _, spec in ipairs(CELLS) do
		local x0, x1 = cx + spec.inset, cx + spec.size - 1 - spec.inset
		local z0, z1 = origin.z + spec.inset, origin.z + spec.size - 1 - spec.inset
		local floor_y = W - spec.depth
		for z = z0, z1 do
			for x = x0, x1 do
				local edge = x == x0 or x == x1 or z == z0 or z == z1
				local bed = (spec.shelf and edge) and (W - 1) or floor_y
				for y = BASE_Y + 1, W + 1 do
					local id = air
					if y < bed then id = stone
					elseif y == bed then id = sand
					elseif y <= W then id = water end
					data[area:index(x, y, z)] = id
				end
			end
		end
		spec.pool = {x0 = x0, x1 = x1, z0 = z0, z1 = z1,
			xc = math.floor((x0 + x1) / 2), zc = math.floor((z0 + z1) / 2)}
		cell[spec.label] = spec
		cx = cx + spec.size
	end
	vm:set_data(data)
	vm:write_to_map(true)
end

-- The point mobs_redo reads as standing_in (collision-box bottom + 0.25).
local function ref_point(obj)
	local pos = obj:get_pos()
	if not pos then return nil end
	local box = obj:get_properties().collisionbox
	return pos, vector.new(pos.x, pos.y + box[2] + 0.25, pos.z)
end
local function node_at(p)
	return core.get_node(vector.round(p)).name
end
local function hdist(a, b)
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end
-- On land: the standing point is not water and the node below it is solid.
local function on_land(obj)
	local pos, r = ref_point(obj)
	if not pos then return false end
	if node_at(r) == WATER then return false end
	local below = core.registered_nodes[node_at(vector.offset(r, 0, -0.6, 0))]
	return below ~= nil and below.walkable == true
end

local function spawn(name, pos)
	local obj = core.add_entity(pos, name)
	assert(obj, name .. " was not added at " .. fmt(pos))
	local ent = obj:get_luaentity()
	ent.lifetimer = 20000 -- never despawn during the run
	grug_mobs.ensure_init(ent)
	return obj, ent
end

-- Keeps a forced fight going as if the player kept hitting: the ambient
-- pursuit clock (aggro.lua) would end a fight without incoming damage
-- after 15 s.
local function sustain(ent)
	if ent and ent.temp and ent.attack then ent.temp.grug_damage_at = grug_core.mono_time() end
end

--
-- 1. Showcase: every new mob in the tank (swimmers in the water, the
--    amphibians on the bank and in the water).
--
local SHOW = {
	"grug_mobs:tortoise_t1", "grug_mobs:tortoise_t2", "grug_mobs:tortoise_t3",
	"grug_mobs:tortoise_t4", "grug_mobs:tortoise_t5", "grug_mobs:tortoise_t6",
	"grug_mobs:frog_t1", "grug_mobs:frog_t2", "grug_mobs:frog_t3",
	"grug_mobs:frog_t4", "grug_mobs:frog_t5", "grug_mobs:frog_t6",
	"grug_mobs:stingray_t1", "grug_mobs:stingray_t2", "grug_mobs:stingray_t3",
	"grug_mobs:stingray_t4", "grug_mobs:stingray_t6",
	"grug_mobs:bay_shark", "grug_mobs:abyssal_shark", "grug_mobs:goby",
}
local shown = {}
local function showcase()
	local pool = cell.tank.pool
	local swimmers, amphibians = 0, 0
	for _, name in ipairs(SHOW) do
		local def = core.registered_entities[name]
		local swimmer = def and def._grug_swim_dy ~= nil
		local pos
		if swimmer then
			local k = swimmers
			swimmers = swimmers + 1
			pos = vector.new(pool.x0 + 3 + (k % 4) * 6, W - 2 - (k % 3),
				pool.z0 + 3 + math.floor(k / 4) * 6)
		else
			local j = amphibians
			amphibians = amphibians + 1
			if j % 2 == 0 then
				pos = vector.new(pool.x0 - 3, W + 1, pool.z0 + 1 + j * 2) -- on the bank
			else
				pos = vector.new(pool.x0 + 1, W, pool.z0 + 1 + j * 2) -- at the surface
			end
		end
		local obj, ent = spawn(name, pos)
		shown[#shown + 1] = {obj = obj, ent = ent, name = name, swimmer = swimmer,
			samples = 0, dry = 0, first_dry = nil}
	end
end
local function sample_showcase(t)
	for _, rec in ipairs(shown) do
		if rec.swimmer and rec.obj:get_pos() then
			local _, r = ref_point(rec.obj)
			rec.samples = rec.samples + 1
			if node_at(r) ~= WATER then
				rec.dry = rec.dry + 1
				rec.first_dry = rec.first_dry or ("t=%.1f %s"):format(t, node_at(r))
			end
		end
	end
end
local function report_showcase()
	for _, rec in ipairs(shown) do
		local e = rec.ent
		local alive = rec.obj:get_pos() ~= nil
		local props = alive and rec.obj:get_properties() or {}
		log(("mob %-24s alive=%s shows %q L%s tier=%s hp=%s/%s size=%.2f disposition=%s voice=%s"):format(
			rec.name, tostring(alive), tostring(e.description), tostring(e._grug_level),
			tostring(e._grug_tier), tostring(e.health), tostring(e.hp_max),
			props.visual_size and props.visual_size.x or 0, tostring(grug_mobs.disposition(e)),
			tostring(e.sounds and next(e.sounds) ~= nil)))
		check(alive, rec.name .. " spawned by command and is still there")
		if rec.swimmer then
			check(rec.dry == 0, ("%s stayed in the water (%d samples, %d dry%s)"):format(
				rec.name, rec.samples, rec.dry, rec.first_dry and (", first " .. rec.first_dry) or ""))
		end
	end
end

--
-- 2. Amphibian navigation: a scripted swim to the shore, inland and back.
--
local chases = {}
local function start_chase(label, mob_name, spec)
	local pool = spec.pool
	local zc, xc = pool.zc + 0.5, pool.xc + 0.5
	local surface = W - 0.3 -- feet in the surface water node
	local land = W + 0.5
	local hero = make_player("chase_" .. label, vector.new(xc - 2, surface, zc))
	local obj, ent = spawn(mob_name, vector.new(xc - 6, W - 0.5, zc))
	local c = {label = label, hero = hero, obj = obj, ent = ent, t = 0, leg = 1,
		hold = 0, phase = "water", log_t = 0, samples = {},
		legs = {
			{x = xc - 2, y = surface, phase = "water", hold = 3},
			{x = pool.x1, y = W - 0.45, phase = "wading", hold = 0},
			{x = pool.x1 + 4.5, y = land, phase = "ashore", hold = 0},
			{x = pool.x1 + 9.5, y = land, phase = "inland", hold = 12},
			{x = pool.x1, y = W - 0.45, phase = "back", hold = 0},
			{x = xc - 3, y = surface, phase = "water_again", hold = 12},
		},
		near = {}, mob_land = false, dropped = 0}
	ent:do_attack(hero)
	chases[#chases + 1] = c
end
local HERO_SPEED = 1.8
local function step_chase(c, dtime)
	if c.done then return end
	c.t = c.t + dtime
	sustain(c.ent)
	local leg = c.legs[c.leg]
	local hp = c.hero:get_pos()
	local to = vector.new(leg.x, leg.y, hp.z)
	local d = vector.distance(hp, to)
	if d > 0.05 then
		local stepd = math.min(d, HERO_SPEED * dtime)
		c.hero:set_pos(vector.add(hp, vector.multiply(vector.direction(hp, to), stepd)))
	else
		c.hold = c.hold + dtime
		if c.hold >= leg.hold then
			c.hold = 0
			c.leg = c.leg + 1
			if not c.legs[c.leg] then c.done = true end
		end
	end
	local phase = leg.phase
	local mp = c.obj:get_pos()
	if not mp then return end
	local dist = hdist(mp, c.hero:get_pos())
	local reach = (c.ent.reach or 2) + 1.5
	local n = c.near[phase] or {min = math.huge, close = false}
	c.near[phase] = n
	if dist < n.min then n.min = dist end
	if dist <= reach then n.close = true end
	if (phase == "ashore" or phase == "inland") and on_land(c.obj) then c.mob_land = true end
	if phase == "water_again" and on_land(c.obj) then c.land_late = true end
	if c.ent.attack ~= c.hero then
		c.dropped = c.dropped + 1
		c.ent:do_attack(c.hero) -- logged, and re-armed to keep measuring
	end
	c.log_t = c.log_t + dtime
	if c.log_t >= 1 then
		c.log_t = 0
		local _, r = ref_point(c.obj)
		log(("chase %s t=%.0f %s player=%s mob=%s in=%s dist=%.1f state=%s"):format(
			c.label, c.t, phase, fmt(c.hero:get_pos()), fmt(mp), node_at(r), dist,
			tostring(c.ent.state)))
	end
end
local function report_chase(c)
	for _, phase in ipairs({"water", "wading", "ashore", "inland", "back", "water_again"}) do
		local n = c.near[phase] or {min = -1}
		log(("chase %s %-11s min distance %.1f close=%s"):format(c.label, phase, n.min, tostring(n.close)))
	end
	log(("chase %s: target dropped %d steps (re-armed), mob ended in %s"):format(
		c.label, c.dropped, c.obj:get_pos() and node_at(select(2, ref_point(c.obj))) or "nil"))
	check(c.done, c.label .. ": the scripted route finished")
	check(c.mob_land, c.label .. ": followed the player out of the water onto the shore")
	check(c.near.inland and c.near.inland.close,
		c.label .. ": reached the player standing 9 nodes inland")
	check(c.near.water_again and c.near.water_again.close,
		c.label .. ": followed the player back into the water and reached it")
	check(c.dropped == 0, c.label .. ": never gave the target up")
end

--
-- 3. The swimmer reset.
--
local ray = {}
local function start_ray()
	local pool = cell.sea_ray.pool
	local zc = pool.zc + 0.5
	ray.in_water = vector.new(pool.x1 - 1, W - 0.3, zc)
	ray.ashore = vector.new(pool.x1 + 2, W + 0.5, zc)
	ray.hero = make_player("ray", ray.in_water)
	ray.obj, ray.ent = spawn("grug_mobs:stingray_t1", vector.new(pool.x1 - 5, W - 3, zc))
	ray.ent.health = math.floor(ray.ent.hp_max / 2)
	ray.ent.old_health = ray.ent.health
	ray.ent:do_attack(ray.hero)
	ray.t, ray.phase = 0, "fight"
	ray.attacks_ashore, ray.dry, ray.samples = 0, 0, 0
	log(("ray: %s L%d hp %d/%d, player in the water at %s"):format(ray.ent.name,
		ray.ent._grug_level, ray.ent.health, ray.ent.hp_max, fmt(ray.in_water)))
end
local function step_ray(dtime)
	if ray.done then return end
	ray.t = ray.t + dtime
	local e = ray.ent
	if ray.obj:get_pos() then
		local _, r = ref_point(ray.obj)
		ray.samples = ray.samples + 1
		if node_at(r) ~= WATER then ray.dry = ray.dry + 1 end
	end
	if ray.phase == "fight" then
		sustain(e)
		if ray.t >= 5 then
			ray.fight_ok = e.attack == ray.hero and e.health < e.hp_max
			log(("ray t=%.1f before stepping ashore: attack=%s hp=%d/%d"):format(ray.t,
				tostring(e.attack == ray.hero), e.health, e.hp_max))
			ray.hero:set_pos(ray.ashore)
			ray.phase, ray.ashore_at = "ashore", ray.t
		end
	elseif ray.phase == "ashore" then
		if not ray.reset_at and e.attack == nil then
			ray.reset_at = ray.t
			ray.healed = e.health == e.hp_max
			ray.gave_up = e.temp and e.temp.grug_gave_up and e.temp.grug_gave_up.name
			ray.evading = e.temp and e.temp.grug_evading ~= nil
			log(("ray t=%.1f reset %.1f s after the player stepped ashore: hp %d/%d, given up %s, evading %s"):format(
				ray.t, ray.t - ray.ashore_at, e.health, e.hp_max, tostring(ray.gave_up), tostring(ray.evading)))
		end
		if ray.reset_at and e.attack then ray.attacks_ashore = ray.attacks_ashore + 1 end
		if ray.t >= ray.ashore_at + 24 then
			local pos = ray.obj:get_pos()
			ray.ashore_dist = pos and hdist(pos, ray.ashore)
			local home = ray.ent._grug_home
			log(("ray t=%.1f after 24 s with the player on the bank (%.1f nodes away, %.1f from its spawn point): attacks %d"):format(
				ray.t, ray.ashore_dist or -1, (pos and home) and hdist(pos, home) or -1,
				ray.attacks_ashore))
			-- Back into the water, a few nodes from wherever the ray swims now.
			local pool = cell.sea_ray.pool
			local back = vector.new(math.max(pool.x0 + 1, math.min(pool.x1 - 1, (pos or ray.in_water).x + 3)),
				W - 0.3, math.max(pool.z0 + 1, math.min(pool.z1 - 1, (pos or ray.in_water).z)))
			ray.hero:set_pos(back)
			ray.phase, ray.back_at = "back", ray.t
		end
	elseif ray.phase == "back" then
		if e.attack == ray.hero and not ray.retaken then
			ray.retaken = ray.t - ray.back_at
			log(("ray t=%.1f takes the player again %.1f s after the return"):format(ray.t, ray.retaken))
		end
		if ray.t >= ray.back_at + 15 then ray.done = true end
	end
end
local function report_ray()
	check(ray.fight_ok, "ray: fights a player in the water (no heal, no reset)")
	check(ray.reset_at ~= nil and ray.reset_at - ray.ashore_at <= 2.5,
		"ray: resets within 2.5 s of the player stepping ashore")
	check(ray.healed, "ray: healed to full on the reset")
	check(ray.gave_up == "probe_ray", "ray: gave the player up")
	check(ray.attacks_ashore == 0, "ray: never attacks the player standing on the bank (24 s)")
	check(ray.dry == 0, ("ray: never left the water (%d samples)"):format(ray.samples))
	check(ray.retaken ~= nil, "ray: takes the player again once back in the water")
end

--
-- 4. Fish loot: one kill per family.
--
local KILLS = {
	{"grug_mobs:tortoise_t3", "grug_fishing:silver_trout"}, -- L20: band 2
	{"grug_mobs:frog_t1", "grug_mobs:raw_fish"},
	{"grug_mobs:stingray_t6", "grug_fishing:storm_tuna"},
	{"grug_mobs:bay_shark", "grug_fishing:mire_carp"},
	{"grug_mobs:abyssal_shark", "grug_fishing:storm_tuna"},
	{"grug_mobs:goby", "grug_mobs:raw_fish"},
}
local function kill_test(done)
	local pool = cell.tank.pool
	local hunter = make_player("hunter", vector.new(pool.x1 - 1, W - 0.3, pool.z1 - 1))
	local i = 0
	local function next_kill()
		i = i + 1
		local row = KILLS[i]
		if not row then return done() end
		local at = vector.new(pool.x1 - 4, W - 2, pool.z1 - 4)
		local obj, ent = spawn(row[1], at)
		local death = obj:get_pos()
		-- One ability hit for the log; the kill itself is the loot path's own
		-- death settlement with the hunter's loot tag (a level-1 probe player
		-- deals little to a level-70 elite).
		local before = ent.health
		local dealt = grug_core.deal_ability_damage(hunter, obj, 1000000)
		local hits = 1
		log(("kill %s: one ability hit dealt %s (hp %s -> %s)"):format(row[1], tostring(dealt),
			tostring(before), tostring(ent.health)))
		if obj:get_pos() and (ent.health or 0) > 0 then
			ent._grug_player_tag = {name = "probe_hunter", until_t = core.get_gametime() + 60}
			ent.health = 0
			ent:check_for_death({type = "punch", puncher = hunter})
		end
		core.after(2.5, function()
			local found, items = 0, {}
			for _, o in ipairs(core.get_objects_inside_radius(death, 6)) do
				local le = o:get_luaentity()
				if le and le.name == "__builtin:item" then
					local st = ItemStack(le.itemstring)
					items[#items + 1] = le.itemstring
					if st:get_name() == row[2] then found = found + st:get_count() end
					o:remove()
				end
			end
			log(("kill %s (L%s) in %d hits: drops %s"):format(row[1], tostring(ent._grug_level),
				hits, table.concat(items, ", ")))
			check(found > 0, ("kill %s drops %s"):format(row[1], row[2]))
			next_kill()
		end)
	end
	next_kill()
end

--
-- Driver
--
local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(failures == 0 and "PASS" or "FAIL",
		checks, failures))
	core.request_shutdown("r51 mobs probe done", false, 0)
end

local RUN_SECONDS = 75
local function run_all()
	showcase()
	start_chase("frog", "grug_mobs:frog_t1", cell.lake_frog)
	start_chase("tortoise", "grug_mobs:tortoise_t1", cell.lake_tortoise)
	start_ray()
	local t, acc, running = 0, 0, true
	core.register_globalstep(function(dtime)
		if not running then return end
		t = t + dtime
		acc = acc + dtime
		for _, c in ipairs(chases) do step_chase(c, dtime) end
		step_ray(dtime)
		if acc >= 0.25 then
			acc = 0
			sample_showcase(t)
		end
		local busy = not ray.done
		for _, c in ipairs(chases) do busy = busy or not c.done end
		if (not busy and t >= 30) or t >= RUN_SECONDS then
			running = false
			report_showcase()
			for _, c in ipairs(chases) do report_chase(c) end
			report_ray()
			kill_test(finish)
		end
	end)
end

-- A deep-ocean column on a coarse grid: open sea, nothing below the arena.
local function find_origin()
	for r = 0, 40 do
		for i = -r, r do
			for _, c in ipairs({{i, -r}, {i, r}, {-r, i}, {r, i}}) do
				local x, z = c[1] * 256, c[2] * 256
				local ok = true
				for _, d in ipairs({{0, 0}, {140, 0}, {0, 40}, {140, 40}}) do
					if grug_zones.water_class_at(x + d[1], z + d[2]) ~= "deep_ocean" then
						ok = false
						break
					end
				end
				if ok then return vector.new(x, 0, z) end
			end
		end
	end
end

core.after(2, function()
	origin = find_origin()
	if not check(origin ~= nil, "found a deep-ocean column for the arena") then
		return finish()
	end
	local minp, maxp = arena_bounds()
	log("arena " .. core.pos_to_string(minp) .. " - " .. core.pos_to_string(maxp))
	for bx = math.floor(minp.x / 16), math.floor(maxp.x / 16) do
		for bz = math.floor(minp.z / 16), math.floor(maxp.z / 16) do
			for by = math.floor(minp.y / 16), math.floor(maxp.y / 16) do
				core.forceload_block(vector.new(bx * 16, by * 16, bz * 16), true, -1)
			end
		end
	end
	core.emerge_area(vector.offset(minp, -16, -16, -16), vector.offset(maxp, 16, 16, 16),
		function(_, _, remaining)
			if remaining > 0 then return end
			core.after(0, function()
				build_arena()
				core.after(1, run_all)
			end)
		end)
end)
