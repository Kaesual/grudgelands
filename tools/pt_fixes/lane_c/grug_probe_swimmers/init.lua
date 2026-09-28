-- Disposable engine probe (playtest fix round, lane C). Never shipped:
-- tools/pt_fixes/lane_c/run.sh stages it through tools/luanti_headless.sh.
--
-- 1. Swimmers. Builds small ponds high above a deep-ocean column (so the
--    Kraken's own water-class leash is satisfied) with different shores: a
--    bare bank level with the water surface, the same bank planted with shore
--    vegetation, a sand beach with a one-deep shelf, a high wall with
--    waterlilies on the surface and a plain high wall as control. Reed
--    Angelfish and Krakens then run their real mobs_redo AI on the real engine
--    for SWIM_SECONDS; every SAMPLE seconds each swimmer's standing-in node
--    (exactly the point mobs_redo's get_nodes reads) is classified. Any
--    non-water sample is a violation, logged with its shape (stepped onto the
--    bank, inside a plant, above the surface, ...).
--    Displacement cases: a fish set down on the bank next to the water, one
--    stranded far from water, and one knocked towards the bank.
-- 2. Drop: a probe "player" kills a Reed Angelfish; exactly one raw fish
--    item must appear.
-- 3. Rod: the item def's first-person wield image and the image the attached
--    third-person wield entity receives.
--
-- A headless server has no client, so the "player" is an invisible entity
-- whose ObjectRef answers the player accessors (the r22_ability_punch
-- pattern). Everything else is shipped code.

local P = "[swimmer_probe] "
local SWIM_SECONDS = 240
local SAMPLE = 0.25
-- Per-swimmer movement floors over SWIM_SECONDS in the wander cells.
local MIN_PATH = 10
local MIN_DISTINCT = 5
local WATER = "default:water_source"
local FISH = "grug_mobs:reed_angelfish"
local KRAKEN = "grug_mobs:kraken"
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
	return ("(%.2f,%.2f,%.2f)"):format(p.x, p.y, p.z)
end

--
-- Step cost: every on_step of the two swimmer families, and the guard alone
-- when the build has one.
--
local cost = {}
local function wrap_cost(name)
	local proto = core.registered_entities[name]
	local original = proto.on_step
	local c = {us = 0, n = 0}
	cost[name] = c
	proto.on_step = function(self, dtime, moveresult)
		local t0 = core.get_us_time()
		local r = original(self, dtime, moveresult)
		c.us = c.us + (core.get_us_time() - t0)
		c.n = c.n + 1
		return r
	end
end
wrap_cost(FISH)
wrap_cost(KRAKEN)
local guard_cost = {us = 0, n = 0}
core.register_on_mods_loaded(function()
	if grug_mobs.swimmer_guard_step then
		local original = grug_mobs.swimmer_guard_step
		grug_mobs.swimmer_guard_step = function(self, dtime)
			local t0 = core.get_us_time()
			original(self, dtime)
			guard_cost.us = guard_cost.us + (core.get_us_time() - t0)
			guard_cost.n = guard_cost.n + 1
		end
	end
end)

--
-- Probe players (subset of tools/r22_ability_punch).
--
core.register_entity("grug_probe_swimmers:hero", {
	initial_properties = {
		physical = false, pointable = false, static_save = false,
		hp_max = 100, visual = "sprite", textures = {"blank.png"},
		is_visible = false, collisionbox = {-0.3, 0, -0.3, 0.3, 1.7, 0.3},
	},
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
	override("set_wielded_item", function(f, stack)
		return f.inv:set_stack("main", 1, stack)
	end)
	local get_player_by_name = core.get_player_by_name
	core.get_player_by_name = function(name)
		return by_name[name] or get_player_by_name(name)
	end
end

local function make_player(label, pos, wield)
	local ref = core.add_entity(pos, "grug_probe_swimmers:hero")
	assert(ref, "probe player entity was not added")
	install(ref)
	local name = "probe_" .. label
	local inv = core.create_detached_inventory("grug_probe_swim_" .. label, {})
	inv:set_size("main", 8)
	inv:set_stack("main", 1, ItemStack(wield or ""))
	fakes[ref] = {name = name, holder = ItemStack("default:stick"), inv = inv}
	by_name[name] = ref
	local auth = core.get_auth_handler()
	if not auth.get_auth(name) then auth.create_auth(name, "") end
	core.set_player_privs(name, {interact = true})
	return ref
end

--
-- Arena
--
local W = 295 -- water surface layer (every pond)
local BASE_Y = 289
local origin -- chosen at runtime inside a deep-ocean column

local SHORE_PLANTS = {"default:grass_3", "default:junglegrass", "default:papyrus",
	"default:marram_grass_1", "default:grass_5"}

-- A pond: interior [x0, x1] x [z0, z1] relative to its cell, `depth` water
-- layers ending at W. `bank` is the top y of the land around it; `plants`
-- puts shore vegetation on the bank, `lily` waterlilies on a third of the
-- surface, `shelf` a one-deep sand ring along the inside edge.
local function build_cell(data, area, ids, cx, cz, size, inset, spec)
	local x0, x1 = cx + inset, cx + size - 1 - inset
	local z0, z1 = cz + inset, cz + size - 1 - inset
	local floor_y = W - spec.depth
	for z = cz, cz + size - 1 do
		for x = cx, cx + size - 1 do
			local inside = x >= x0 and x <= x1 and z >= z0 and z <= z1
			local edge = inside and (x == x0 or x == x1 or z == z0 or z == z1)
			for y = BASE_Y, BASE_Y + 12 do
				local id = ids.air
				if inside then
					local bed = (spec.shelf and edge) and (W - 1) or floor_y
					if y < bed then id = ids.stone
					elseif y == bed then id = ids.sand
					elseif y <= W then id = ids.water
					elseif y == W + 1 and spec.lily and (x + 2 * z) % 3 == 0 then
						id = ids.lily
					end
				else
					if y < spec.bank then id = ids.dirt
					elseif y == spec.bank then id = spec.shelf and ids.sand or ids.grass
					elseif y == spec.bank + 1 and spec.plants then
						id = ids.plants[(x * 7 + z * 13) % #ids.plants + 1]
					end
				end
				data[area:index(x, y, z)] = id
			end
		end
	end
	return {x0 = x0, x1 = x1, z0 = z0, z1 = z1}
end

local FISH_CELLS = {
	{label = "fish_flush_bank", depth = 3, bank = W},
	{label = "fish_planted_bank", depth = 3, bank = W, plants = true},
	{label = "fish_sand_beach", depth = 3, bank = W, shelf = true},
	{label = "fish_lily_wall", depth = 3, bank = W + 2, lily = true},
	{label = "fish_wall_control", depth = 3, bank = W + 2},
	{label = "fish_displaced", depth = 3, bank = W},
}
local KRAKEN_CELLS = {
	{label = "kraken_flush_bank", depth = 4, bank = W, count = 2},
	{label = "kraken_planted_bank", depth = 4, bank = W, plants = true, count = 2},
	{label = "kraken_attack_to_land", depth = 4, bank = W, plants = true, count = 1,
		target = true},
}
local FISH_SIZE, FISH_INSET = 16, 4
local KRAKEN_SIZE, KRAKEN_INSET = 24, 4

local function cell_origin_fish(i)
	return origin.x + ((i - 1) % 3) * FISH_SIZE, origin.z + math.floor((i - 1) / 3) * FISH_SIZE
end
local function cell_origin_kraken(i)
	return origin.x + (i - 1) * KRAKEN_SIZE, origin.z + 2 * FISH_SIZE
end

local function arena_bounds()
	return vector.new(origin.x, BASE_Y, origin.z),
		vector.new(origin.x + 3 * KRAKEN_SIZE - 1, BASE_Y + 12,
			origin.z + 2 * FISH_SIZE + KRAKEN_SIZE - 1)
end

local function build_arena()
	local minp, maxp = arena_bounds()
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local cid = core.get_content_id
	local ids = {
		air = cid("air"), stone = cid("default:stone"), sand = cid("default:sand"),
		dirt = cid("default:dirt"), grass = cid("default:dirt_with_grass"),
		water = cid(WATER), lily = cid("grug_mapgen:freshwater_waterlily"),
		plants = {},
	}
	for _, n in ipairs(SHORE_PLANTS) do ids.plants[#ids.plants + 1] = cid(n) end
	-- Clear the whole box first (air over a stone base), then the cells.
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				data[area:index(x, y, z)] = y == BASE_Y and ids.stone or ids.air
			end
		end
	end
	for i, spec in ipairs(FISH_CELLS) do
		local cx, cz = cell_origin_fish(i)
		spec.pool = build_cell(data, area, ids, cx, cz, FISH_SIZE, FISH_INSET, spec)
		spec.cx, spec.cz = cx, cz
	end
	for i, spec in ipairs(KRAKEN_CELLS) do
		local cx, cz = cell_origin_kraken(i)
		spec.pool = build_cell(data, area, ids, cx, cz, KRAKEN_SIZE, KRAKEN_INSET, spec)
		spec.cx, spec.cz = cx, cz
	end
	vm:set_data(data)
	vm:write_to_map(true)
end

--
-- Swimmer sampling
--
local tracked = {} -- {obj, name, cell, label, samples, bad, first_bad, max_out, ...}
local by_class = {}

local function ref_point(obj)
	local pos = obj:get_pos()
	if not pos then return nil end
	local box = obj:get_properties().collisionbox
	return pos, vector.new(pos.x, pos.y + box[2] + 0.25, pos.z)
end

local function node_at(p)
	return core.get_node(vector.round(p)).name
end

local function classify(r)
	local here = node_at(r)
	if here == WATER then return nil, here end
	local below = node_at(vector.offset(r, 0, -1, 0))
	local def = core.registered_nodes[here] or {}
	local bdef = core.registered_nodes[below] or {}
	if def.walkable then return "inside_solid", here end
	if def.drawtype == "airlike" then
		if below == WATER then return "above_surface", here end
		if bdef.walkable then return "on_land", here end
		return "in_air", here
	end
	return "in_node:" .. here, here
end

local function outside_distance(pos, pool)
	local dx = math.max(pool.x0 - 0.5 - pos.x, 0, pos.x - (pool.x1 + 0.5))
	local dz = math.max(pool.z0 - 0.5 - pos.z, 0, pos.z - (pool.z1 + 0.5))
	return math.sqrt(dx * dx + dz * dz)
end

local function track(obj, cell, role)
	local ent = obj:get_luaentity()
	local rec = {obj = obj, ent = ent, name = ent.name, cell = cell, role = role or "wander",
		samples = 0, bad = 0, max_out = 0, classes = {}, id = #tracked + 1,
		path = 0, nodes = {}, distinct = 0}
	tracked[#tracked + 1] = rec
	return rec
end

local function sample_all()
	for _, rec in ipairs(tracked) do
		if not rec.dead and rec.role == "wander" then
			local pos, r = ref_point(rec.obj)
			if not pos then
				rec.dead = true
			else
				rec.samples = rec.samples + 1
				-- Movement: a guard that merely froze the swimmers would also
				-- keep every sample wet.
				if rec.last then rec.path = rec.path + vector.distance(rec.last, pos) end
				rec.last = pos
				local key = core.hash_node_position(vector.round(pos))
				if not rec.nodes[key] then
					rec.nodes[key] = true
					rec.distinct = rec.distinct + 1
				end
				local class, here = classify(r)
				local out = outside_distance(pos, rec.cell.pool)
				if out > rec.max_out then rec.max_out = out end
				if class then
					rec.bad = rec.bad + 1
					rec.classes[class] = (rec.classes[class] or 0) + 1
					if not rec.first_bad then
						local v = rec.obj:get_velocity() or vector.zero()
						rec.first_bad = ("t=%.1fs %s node=%s pos=%s vel=%s state=%s standing_in=%s standing_on=%s"):format(
							rec.samples * SAMPLE, class, here, fmt(pos), fmt(v),
							tostring(rec.ent.state), tostring(rec.ent.standing_in),
							tostring(rec.ent.standing_on))
					end
				end
			end
		end
	end
end

local function spawn(name, pos)
	local obj = core.add_entity(pos, name)
	assert(obj, name .. " was not added at " .. fmt(pos))
	local ent = obj:get_luaentity()
	ent.lifetimer = 20000 -- probe fixture: never despawn during the run
	return obj, ent
end

local function spawn_wanderers()
	local rng = PcgRandom(4242)
	for _, spec in ipairs(FISH_CELLS) do
		if spec.label ~= "fish_displaced" then
			local pool = spec.pool
			for _ = 1, 6 do
				local pos = vector.new(rng:next(pool.x0 + 1, pool.x1 - 1) + 0.0,
					W - rng:next(0, spec.depth - 1) + 0.0,
					rng:next(pool.z0 + 1, pool.z1 - 1) + 0.0)
				-- Hug the shore: half of them start one node from the bank.
				if rng:next(0, 1) == 1 then pos.x = pool.x1 end
				-- The beach shelf holds only the surface layer.
				if core.get_node(pos).name ~= WATER then pos.y = W end
				local obj = spawn(FISH, pos)
				track(obj, spec)
			end
		end
	end
	for _, spec in ipairs(KRAKEN_CELLS) do
		local pool = spec.pool
		for k = 1, spec.count do
			local pos = vector.new(pool.x1 - 1 - (k - 1) * 5, W - 3, pool.z0 + 4 + (k - 1) * 5)
			local obj, ent = spawn(KRAKEN, pos)
			local rec = track(obj, spec)
			if spec.target then
				local tpos = vector.new(pool.x1 + 6, W + 1, (pool.z0 + pool.z1) / 2)
				local target = core.add_entity(tpos, "grug_probe_swimmers:hero")
				rec.target = target
				ent:do_attack(target)
			end
		end
	end
end

-- Keep the attack scenario attacking: mobs_redo drops a target it cannot
-- see or reach after a while; the probe re-arms it every second.
local function rearm_attacks()
	for _, rec in ipairs(tracked) do
		if rec.target and not rec.dead and rec.ent.state ~= "attack" then
			rec.ent:do_attack(rec.target)
			rec.rearmed = (rec.rearmed or 0) + 1
		end
	end
end

--
-- Displacement cases (cell "fish_displaced", flush bank)
--
local displaced = {}
local function start_displaced()
	local spec = FISH_CELLS[6]
	local pool = spec.pool
	local zc = math.floor((pool.z0 + pool.z1) / 2)
	-- On the grass right next to the water.
	local a = spawn(FISH, vector.new(pool.x1 + 1, W + 0.7, zc))
	displaced.adjacent = {obj = a, start = a:get_pos(), back_at = nil}
	-- Stranded: four nodes from the nearest water.
	local s = spawn(FISH, vector.new(pool.x1 + 4, W + 0.7, pool.z1 + 3))
	displaced.stranded = {obj = s, start = s:get_pos(), max_move = 0, wet = false}
	-- Knocked towards the bank and up, the way a knockback pushes (velocity
	-- plus mobs_redo's pause_timer).
	local k, kent = spawn(FISH, vector.new(pool.x1 - 1, W - 1, pool.z0 + 1))
	displaced.knock = {obj = k, max_out = 0, dry = 0}
	core.after(1, function()
		if k:get_pos() then
			k:set_velocity(vector.new(4, 3, 0))
			kent.pause_timer = 0.25
		end
	end)
	displaced.t = 0
	displaced.pool = pool
end

local function sample_displaced(dt)
	if not displaced.t then return end
	displaced.t = displaced.t + dt
	local a = displaced.adjacent
	local pos, r = ref_point(a.obj)
	if pos and not a.back_at and node_at(r) == WATER then a.back_at = displaced.t end
	local s = displaced.stranded
	pos, r = ref_point(s.obj)
	if pos then
		local ddx, ddz = pos.x - s.start.x, pos.z - s.start.z
		local d = math.sqrt(ddx * ddx + ddz * ddz)
		if d > s.max_move then s.max_move = d end
		if node_at(r) == WATER then s.wet = true end
		s.state = s.obj:get_luaentity().state
	end
	local k = displaced.knock
	pos, r = ref_point(k.obj)
	if pos and displaced.t > 1 then
		local out = outside_distance(pos, displaced.pool)
		if out > k.max_out then k.max_out = out end
		if node_at(r) ~= WATER then
			k.dry = k.dry + 1
			k.last_dry = displaced.t
		end
	end
end

local function report_displaced()
	local a, s, k = displaced.adjacent, displaced.stranded, displaced.knock
	-- A vanished test fish would pass the checks below vacuously.
	check(a.obj:get_pos() ~= nil, "displaced adjacent: the test fish still exists")
	check(s.obj:get_pos() ~= nil, "displaced stranded: the test fish still exists")
	check(k.obj:get_pos() ~= nil, "displaced knockback: the test fish still exists")
	log(("displaced adjacent: back in water after %s s"):format(tostring(a.back_at)))
	check(a.back_at ~= nil and a.back_at <= 6,
		"a fish set down next to the water returns to it within 6 s")
	log(("displaced stranded: max horizontal move %.2f, reached water %s, state %s"):format(
		s.max_move, tostring(s.wet), tostring(s.state)))
	check(s.max_move <= 0.5 and not s.wet,
		"a fish stranded 4 nodes from water flops in place (no walking over land)")
	log(("displaced knockback: max %.2f nodes outside the pond, %d dry samples, last dry at %s s"):format(
		k.max_out, k.dry, tostring(k.last_dry)))
	check(k.max_out <= 1.0 and (k.last_dry or 0) <= 6,
		"a fish knocked towards the bank stays at/returns to the water within 6 s")
end

--
-- Drop
--
local function drop_test(done)
	local spec = FISH_CELLS[6]
	local pool = spec.pool
	local at = vector.new(math.floor((pool.x0 + pool.x1) / 2) - 1, W - 1,
		math.floor((pool.z0 + pool.z1) / 2) - 1)
	local obj, ent = spawn(FISH, at)
	local hero = make_player("fisher", vector.new(pool.x1 + 1.5, W + 1, at.z), "")
	core.after(0.5, function()
		local death = obj:get_pos() or at
		log("drop: fish drops def = " .. dump(ent.drops):gsub("\n", " "))
		-- A player's damage that is not a melee swing (a native punch is
		-- routed into the swing transaction): the shared ability-hit path,
		-- which runs the real on_punch, loot tag and death boundary.
		local dealt = grug_core.deal_ability_damage(hero, obj, 500)
		log("drop: ability hit dealt " .. tostring(dealt))
		core.after(2.5, function()
			check(not obj:get_pos() or (ent.health or 1) <= 0, "drop: the fish died")
			local total, stacks = 0, 0
			for _, o in ipairs(core.get_objects_inside_radius(death, 5)) do
				local le = o:get_luaentity()
				if le and le.name == "__builtin:item" then
					local st = ItemStack(le.itemstring)
					log("drop: item entity " .. le.itemstring .. " at " .. fmt(o:get_pos()))
					if st:get_name() == "grug_mobs:raw_fish" then
						total = total + st:get_count()
						stacks = stacks + 1
					else
						total = total + 1000 -- anything else is wrong
					end
				end
			end
			check(total == 1 and stacks == 1,
				("drop: exactly one grug_mobs:raw_fish dropped (got total=%d stacks=%d)"):format(total, stacks))
			done()
		end)
	end)
end

--
-- Rod
--
local ROD = "grug_fishing:rod"
local ROD_IMAGE = "grug_fishing_rod.png"
local ROD_FIRST_PERSON = "grug_fishing_rod.png^[transformFY^[transformR90"
local function rod_test()
	local def = core.registered_items[ROD]
	log("rod def wield_image=" .. tostring(def.wield_image) ..
		" inventory_image=" .. tostring(def.inventory_image) ..
		" _grug_world_wield_image=" .. tostring(def._grug_world_wield_image))
	check(def.wield_image == ROD_FIRST_PERSON,
		"rod: item def carries the transformed first-person wield_image")
	check(def.inventory_image == ROD_IMAGE, "rod: inventory image unchanged")
	local appearance = ItemStack(grug_visuals.wield_appearance(ItemStack(ROD)))
	local image = appearance:get_meta():get_string("wield_image")
	log("rod third-person appearance stack: " .. appearance:to_string())
	check(image == ROD_IMAGE,
		"rod: the third-person appearance stack overrides wield_image with the original image")
	-- A per-stack wield image still wins over the def field.
	local custom = ItemStack(ROD)
	custom:get_meta():set_string("wield_image", "custom.png")
	local cimg = ItemStack(grug_visuals.wield_appearance(custom)):get_meta():get_string("wield_image")
	check(cimg == "custom.png", "rod: a stack's own wield_image meta still wins")
	-- An item without the field keeps an empty override (unchanged behaviour).
	local sword = ItemStack(grug_visuals.wield_appearance(ItemStack("default:stick")))
	check(sword:get_meta():get_string("wield_image") == "",
		"rod: items without _grug_world_wield_image get no wield_image override")
end

-- The real attached entity: a probe player wields the rod and grug_visuals
-- attaches its wield entity; read the image off that entity.
local function rod_entity_test(pos)
	local hero = make_player("rodder", pos, ROD)
	-- The probe player has no race skin, so the skin half of apply has no
	-- texture list for player_api; only the wield half is under test here.
	local set_textures = player_api.set_textures
	player_api.set_textures = function(player, textures)
		if fakes[player] then return end
		return set_textures(player, textures)
	end
	local ok, err = pcall(grug_visuals.apply, hero)
	player_api.set_textures = set_textures
	if not ok then log("rod: grug_visuals.apply on the probe player raised: " .. tostring(err)) end
	local found
	for _, child in ipairs(hero:get_children()) do
		local le = child:get_luaentity()
		if le and le.name == "grug_visuals:wield" then found = child end
	end
	if not check(found ~= nil, "rod: the third-person wield entity is attached") then return end
	local props = found:get_properties()
	local stack = ItemStack(props.wield_item)
	log("rod wield entity: visual=" .. tostring(props.visual) .. " wield_item=" ..
		tostring(props.wield_item))
	check(stack:get_name() == ROD and
		stack:get_meta():get_string("wield_image") == ROD_IMAGE,
		"rod: the third-person wield entity renders the original rod image")
end

--
-- Driver
--
local function report_swimmers()
	local per = {}
	local total_bad = 0
	for _, rec in ipairs(tracked) do
		if rec.role == "wander" then
			local label = rec.cell.label
			local s = per[label] or {samples = 0, bad = 0, mobs = 0, bad_mobs = 0,
				max_out = 0, classes = {}, examples = {}, dead = 0,
				path = 0, min_path = math.huge, min_distinct = math.huge,
				attack = rec.target ~= nil}
			per[label] = s
			s.samples = s.samples + rec.samples
			s.bad = s.bad + rec.bad
			s.mobs = s.mobs + 1
			s.path = s.path + rec.path
			s.min_path = math.min(s.min_path, rec.path)
			s.min_distinct = math.min(s.min_distinct, rec.distinct)
			if rec.dead then s.dead = s.dead + 1 end
			if rec.bad > 0 then s.bad_mobs = s.bad_mobs + 1 end
			if rec.max_out > s.max_out then s.max_out = rec.max_out end
			for c, n in pairs(rec.classes) do s.classes[c] = (s.classes[c] or 0) + n end
			if rec.first_bad and #s.examples < 3 then
				s.examples[#s.examples + 1] = rec.name .. "#" .. rec.id .. " " .. rec.first_bad
			end
			total_bad = total_bad + rec.bad
		end
	end
	local labels = {}
	for label in pairs(per) do labels[#labels + 1] = label end
	table.sort(labels)
	for _, label in ipairs(labels) do
		local s = per[label]
		local cls = {}
		for c, n in pairs(s.classes) do cls[#cls + 1] = c .. "=" .. n end
		table.sort(cls)
		log(("%-22s mobs=%d samples=%d non_water=%d (%.1f%%) mobs_out=%d max_out=%.2f dead=%d classes={%s}"):format(
			label, s.mobs, s.samples, s.bad, s.samples > 0 and 100 * s.bad / s.samples or 0,
			s.bad_mobs, s.max_out, s.dead, table.concat(cls, " ")))
		for _, e in ipairs(s.examples) do log("  first: " .. e) end
		check(s.bad == 0 and s.dead == 0,
			label .. ": no swimmer ever occupied a non-water node")
		log(("%-22s movement: mean path %.1f nodes, min path %.1f, min distinct nodes %d"):format(
			label, s.path / s.mobs, s.min_path, s.min_distinct))
		-- Floors well below free swimming, far above a frozen swimmer (path 0,
		-- one node). The attack Kraken only has to reach the shore line.
		local need_path, need_nodes = MIN_PATH, MIN_DISTINCT
		if s.attack then need_path, need_nodes = 2, 2 end
		check(s.min_path >= need_path and s.min_distinct >= need_nodes,
			("%s: every swimmer still swims (path >= %d nodes, >= %d distinct nodes)"):format(
				label, need_path, need_nodes))
	end
	return total_bad
end

local function report_cost()
	for name, c in pairs(cost) do
		log(("cost %s: %d on_step calls, mean %.2f us/step"):format(
			name, c.n, c.n > 0 and c.us / c.n or 0))
	end
	if guard_cost.n > 0 then
		log(("cost swimmer guard alone: %d calls, mean %.2f us/call"):format(
			guard_cost.n, guard_cost.us / guard_cost.n))
	else
		log("cost swimmer guard alone: no guard in this build")
	end
end

local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("swimmer probe done", false, 0)
end

local function run_all()
	local ok, err = pcall(rod_test)
	check(ok, "rod checks ran" .. (ok and "" or (" (" .. tostring(err) .. ")")))
	local minp = arena_bounds()
	ok, err = pcall(rod_entity_test, vector.offset(minp, 2, 9, 2))
	check(ok, "rod entity check ran" .. (ok and "" or (" (" .. tostring(err) .. ")")))

	spawn_wanderers()
	start_displaced()
	log(("tracking %d wandering swimmers for %d s"):format(#tracked, SWIM_SECONDS))
	local elapsed, acc, rearm = 0, 0, 0
	local running = true
	core.register_globalstep(function(dtime)
		if not running then return end
		elapsed = elapsed + dtime
		acc = acc + dtime
		rearm = rearm + dtime
		if displaced.t and displaced.t < 20 then sample_displaced(dtime) end
		if acc >= SAMPLE then
			acc = acc - SAMPLE
			sample_all()
		end
		if rearm >= 1 then
			rearm = 0
			rearm_attacks()
		end
		if elapsed >= SWIM_SECONDS then
			running = false
			report_displaced()
			report_swimmers()
			report_cost()
			for _, rec in ipairs(tracked) do
				if rec.target then
					log(("kraken attack: re-armed %d times, final state %s"):format(
						rec.rearmed or 0, tostring(rec.ent.state)))
				end
			end
			drop_test(finish)
		end
	end)
end

-- Find a deep-ocean column (the Kraken's leash) on a coarse grid.
local function find_origin()
	for r = 0, 40 do
		for i = -r, r do
			for _, c in ipairs({{i, -r}, {i, r}, {-r, i}, {r, i}}) do
				local x, z = c[1] * 256, c[2] * 256
				local ok = true
				for _, d in ipairs({{0, 0}, {80, 0}, {0, 80}, {80, 80}}) do
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
