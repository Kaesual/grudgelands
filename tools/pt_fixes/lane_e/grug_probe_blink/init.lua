-- Disposable engine probe (playtest fix lane E, Blink targeting). Never
-- shipped: tools/pt_fixes/lane_e/run.sh stages it through
-- tools/luanti_headless.sh.
--
-- Part 1 calls the shipped pure function grug_abilities.blink_destination with
-- the live map (its default world) against geometry built per scenario in an
-- air box high above the terrain. Every scenario runs in its own lane:
-- a stone floor, the caster standing on it at (ox, floor top, oz), looking
-- toward +z at a given pitch.
--
-- Part 2 casts the real Blink through grug_abilities.try_cast with a probe
-- "player" (an invisible entity whose ObjectRef answers the player accessors
-- the cast path reads), and checks position, mana and cooldown.

local P = "[blink_probe] "
local BASE = vector.new(200, 300, 200)
local SPACING = 10
local EYE = 1.47
local BOX = {-0.3, 0, -0.3, 0.3, 1.7, 0.3}
local FLOOR_TOP = BASE.y + 0.5
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

local function near(a, b, tol) return math.abs(a - b) <= tol end
local function fmt(v)
	return v and ("(%.2f, %.2f, %.2f)"):format(v.x, v.y, v.z) or "nil"
end

local STONE = "default:stone"
local function put(ox, oz, x, y, z, name)
	core.set_node(vector.new(ox + x, BASE.y + y, oz + z), {name = name or STONE})
end
-- Solid block from (x1, y1, z1) to (x2, y2, z2), lane-relative node coords.
local function block(ox, oz, x1, y1, z1, x2, y2, z2, name)
	for x = x1, x2 do
		for y = y1, y2 do
			for z = z1, z2 do put(ox, oz, x, y, z, name) end
		end
	end
end

local function look(pitch_deg)
	local a = math.rad(pitch_deg)
	-- Positive pitch looks down (Luanti's look_vertical convention).
	return vector.new(0, -math.sin(a), math.cos(a))
end

-- Independent checks on a destination: the player box overlaps no walkable
-- node (sampled on a 0.1 grid, inset 0.01) and the caster's eye sees the
-- destination eye through walkable nodes.
local function box_free(dest)
	for x = BOX[1] + 0.01, BOX[4] - 0.01 + 1e-9, 0.1 do
		for y = BOX[2] + 0.01, BOX[5] - 0.01 + 1e-9, 0.1 do
			for z = BOX[3] + 0.01, BOX[6] - 0.01 + 1e-9, 0.1 do
				local p = vector.new(dest.x + x, dest.y + y, dest.z + z)
				local np = vector.round(p)
				local node = core.get_node(np)
				local def = core.registered_nodes[node.name]
				if not def then return false, p end
				if def.walkable then
					-- Inside one of the node's real collision boxes?
					local r = vector.subtract(p, np)
					for _, b in ipairs(core.get_node_boxes("collision_box", np, node)) do
						if r.x > b[1] and r.x < b[4] and r.y > b[2] and r.y < b[5] and
								r.z > b[3] and r.z < b[6] then
							return false, p
						end
					end
				end
			end
		end
	end
	return true
end

local function line_clear(a, b)
	for hit in core.raycast(a, b, false, false) do
		if hit.type == "node" then
			local def = core.registered_nodes[core.get_node(hit.under).name]
			if not def or def.walkable then return false end
		end
	end
	return true
end

-- Scenario: label, pitch (deg, + down; or dir), build(ox, oz), caster feet
-- height above the floor top (default 0) and expectation:
--   fail = true, or dz / dy (relative to the caster feet) with tolerances,
--   max_dz, and extra(dest, ox, oz) -> ok, msg.
local scenarios = {
	{label = "flat_down_10", pitch = 10, dz = EYE / math.tan(math.rad(10)), dy = 0},
	{label = "flat_down_20", pitch = 20, dz = EYE / math.tan(math.rad(20)), dy = 0},
	{label = "flat_down_35", pitch = 35, dz = EYE / math.tan(math.rad(35)), dy = 0},
	{label = "flat_down_60 (0.85 m < 1.5 m)", pitch = 60, fail = true},
	{label = "tower_down_60", pitch = 60, feet = 4,
		build = function(ox, oz) block(ox, oz, 0, 1, 0, 0, 4, 0) end,
		dz = (4 + EYE) / math.tan(math.rad(60)), dy = -4},
	{label = "wall_5m_horizontal", pitch = 0,
		build = function(ox, oz) block(ox, oz, -2, 1, 5, 2, 3, 5) end,
		dz = 4.5 - 0.35, dy = 0},
	{label = "step_1_side_face", pitch = math.deg(math.atan(1.0 / 4.5)),
		build = function(ox, oz) block(ox, oz, -2, 1, 5, 2, 1, 7) end,
		dz = 5, dy = 1},
	{label = "step_1_top_face", pitch = math.deg(math.atan(0.47 / 6)),
		build = function(ox, oz) block(ox, oz, -2, 1, 5, 2, 1, 7) end,
		dz = 6, dy = 1},
	{label = "wall_2_low_face_no_climb", pitch = math.deg(math.atan(1.0 / 4.5)),
		build = function(ox, oz) block(ox, oz, -2, 1, 5, 2, 2, 5) end,
		dz = 4.5 - 0.35, dy = 0},
	{label = "wall_2_eye_level_no_climb", pitch = 0,
		build = function(ox, oz) block(ox, oz, -2, 1, 5, 2, 2, 5) end,
		dz = 4.5 - 0.35, dy = 0},
	-- Real collision boxes: a bottom slab is half a node high.
	{label = "slab_top_face", pitch = math.deg(math.atan(0.97 / 6)),
		build = function(ox, oz) block(ox, oz, -2, 1, 5, 2, 1, 7, "stairs:slab_wood") end,
		dz = 6, dy = 0.5},
	{label = "slab_side_face_step_up", pitch = math.deg(math.atan(1.2 / 4.5)),
		build = function(ox, oz) block(ox, oz, -2, 1, 5, 2, 1, 7, "stairs:slab_wood") end,
		dz = 5, dy = 0.5},
	{label = "air_forward", pitch = 0, dz = 10, dy = 0},
	{label = "air_up_45", pitch = -45, dz = 10 * math.cos(math.rad(45)),
		dy = 10 * math.sin(math.rad(45))},
	{label = "air_straight_up", dir = vector.new(0, 1, 0), dz = 0, dy = 10},
	{label = "hole_ahead", pitch = 0,
		build = function(ox, oz) block(ox, oz, -2, 0, 8, 2, 0, 12, "air") end,
		dz = 10, dy = 0, extra = function(dest)
			local below = core.get_node(vector.offset(dest, 0, -0.5, 0)).name
			return below == "air", "air below the destination (" .. below .. ")"
		end},
	{label = "overhang_low_ceiling", pitch = 12,
		build = function(ox, oz) block(ox, oz, -2, 2, 6, 2, 2, 10) end,
		max_dz = 5.5 - 0.3, min_dz = 1.5, dy = 0},
	{label = "tunnel_2_high_fits", pitch = 0,
		build = function(ox, oz)
			block(ox, oz, -1, 3, 2, 1, 3, 13)
			block(ox, oz, -2, 1, 2, -2, 2, 13)
			block(ox, oz, 2, 1, 2, 2, 2, 13)
		end, dz = 10, dy = 0},
	{label = "tunnel_1_high_front", pitch = 0,
		-- The ceiling's front face at eye level: stand in front of it.
		build = function(ox, oz) block(ox, oz, -2, 2, 4, 2, 2, 13) end,
		dz = 3.5 - 0.35, dy = 0},
	{label = "wall_close_fails", pitch = 0,
		build = function(ox, oz) block(ox, oz, -2, 1, 1, 2, 3, 1) end,
		fail = true},
	{label = "ceiling_up_45", pitch = -45,
		build = function(ox, oz) block(ox, oz, -3, 5, -1, 3, 5, 12) end,
		dz = 4.5 - (0.5 + EYE), dy = 4.5 - 0.5 - 1.7 - 0.05},
	{label = "grass_passable_down_20", pitch = 20,
		build = function(ox, oz)
			block(ox, oz, -1, 1, 1, 1, 1, 9, "default:grass_3")
		end, dz = EYE / math.tan(math.rad(20)), dy = 0},
	{label = "window_1x1_line_of_sight", pitch = 0,
		build = function(ox, oz)
			block(ox, oz, -3, 1, 4, 3, 4, 4)
			put(ox, oz, 0, 2, 4, "air")
		end, dz = 10, dy = 0},
	{label = "wall_up_over_top_no_through", pitch = -2,
		-- A 5-high wall: aim at its face above head height; never land behind.
		build = function(ox, oz) block(ox, oz, -3, 1, 4, 3, 5, 4) end,
		max_dz = 3.5 - 0.3 + 0.01, min_dz = 1.5},
}

local function run_pure(index, sc)
	local ox = BASE.x + (index - 1) * SPACING
	local oz = BASE.z
	if sc.build then sc.build(ox, oz) end
	local feet = vector.new(ox, FLOOR_TOP + (sc.feet or 0), oz)
	local eye = vector.offset(feet, 0, EYE, 0)
	local dir = sc.dir or look(sc.pitch)
	local dest = grug_abilities.blink_destination(eye, dir, 10, EYE, BOX)
	log(("%s: pitch=%s dest=%s dz=%s dy=%s"):format(sc.label,
		tostring(sc.pitch and ("%.1f"):format(sc.pitch) or "dir"), fmt(dest),
		dest and ("%.2f"):format(dest.z - feet.z) or "-",
		dest and ("%.2f"):format(dest.y - feet.y) or "-"))
	if sc.fail then
		check(dest == nil, sc.label .. ": no destination (fails)")
		return
	end
	if not check(dest ~= nil, sc.label .. ": has a destination") then return end
	local dz, dy = dest.z - feet.z, dest.y - feet.y
	if sc.dz then
		check(near(dz, sc.dz, 0.1), ("%s: dz %.2f ~ %.2f"):format(sc.label, dz, sc.dz))
	end
	if sc.max_dz then
		check(dz <= sc.max_dz and dz >= sc.min_dz, ("%s: dz %.2f in [%.2f, %.2f]")
			:format(sc.label, dz, sc.min_dz, sc.max_dz))
	end
	if sc.dy then
		check(near(dy, sc.dy, 0.02), ("%s: dy %.2f ~ %.2f"):format(sc.label, dy, sc.dy))
	end
	check(near(dest.x, feet.x, 0.51), sc.label .. ": stays in the look plane")
	local free, where = box_free(dest)
	check(free, sc.label .. ": player box inside no solid node" ..
		(free and "" or (" (solid at " .. fmt(where) .. ")")))
	check(line_clear(eye, vector.offset(dest, 0, EYE, 0)),
		sc.label .. ": destination eye in line of sight")
	check(vector.distance(feet, dest) >= 1.5, sc.label .. ": moved >= 1.5 m")
	if sc.extra then
		local ok, msg = sc.extra(dest, ox, oz)
		check(ok, sc.label .. ": " .. msg)
	end
end

--
-- Part 2: integrated casts with a probe player.
--
core.register_entity("grug_probe_blink:hero", {
	initial_properties = {
		physical = false, pointable = false, static_save = false,
		hp_max = 100, visual = "sprite", textures = {"blank.png"},
		is_visible = false, collisionbox = BOX, eye_height = EYE,
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
	override("get_look_dir", function(f) return vector.copy(f.look) end)
	override("get_look_horizontal", function() return 0 end)
	override("get_look_vertical", function(f) return f.pitch end)
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

local function make_player(label, pos, pitch)
	local ref = core.add_entity(pos, "grug_probe_blink:hero")
	assert(ref, "probe player entity was not added")
	install(ref)
	local name = "probe_" .. label
	local inv = core.create_detached_inventory("grug_probe_blink_" .. label, {})
	inv:set_size("main", 8)
	fakes[ref] = {name = name, look = look(pitch), pitch = math.rad(pitch),
		holder = ItemStack("grug_abilities:blink"), inv = inv}
	by_name[name] = ref
	local auth = core.get_auth_handler()
	if not auth.get_auth(name) then auth.create_auth(name, "") end
	core.set_player_privs(name, {interact = true})
	ref:get_meta():set_string("grug_classes:class", "mage")
	return ref
end

local function run_cast(index, label, pitch, build, expect_ok, dz)
	local ox = BASE.x + (index - 1) * SPACING
	local oz = BASE.z
	if build then build(ox, oz) end
	local feet = vector.new(ox, FLOOR_TOP, oz)
	local ref = make_player(label, feet, pitch)
	local def = grug_abilities.registered.blink
	check(grug_abilities.is_unlocked(ref, "blink"), label .. ": Blink unlocked for a mage")
	grug_abilities.restore_mana(ref, 1000000)
	local cost = grug_abilities.cost_for(ref, def.cost, "blink").mana or 0
	local mana = grug_abilities.get_mana(ref)
	local ok = grug_abilities.try_cast(ref, def, nil, true)
	local pos = ref:get_pos()
	local paid = mana - grug_abilities.get_mana(ref)
	log(("%s: try_cast=%s pos=%s paid=%d (cost %d) ready=%s"):format(label,
		tostring(ok), fmt(pos), paid, cost,
		tostring(grug_abilities.ready(ref, "blink"))))
	if expect_ok then
		check(ok == true, label .. ": cast succeeded")
		check(near(pos.z - feet.z, dz, 0.1) and near(pos.y, feet.y, 0.02),
			("%s: moved to dz %.2f ~ %.2f on the ground"):format(label,
				pos.z - feet.z, dz))
		check(paid == cost and cost > 0, label .. ": paid the mana cost")
		check(not grug_abilities.ready(ref, "blink"), label .. ": cooldown armed")
	else
		check(not ok, label .. ": cast refused")
		check(vector.distance(pos, feet) < 1e-6, label .. ": did not move")
		check(paid == 0, label .. ": paid no mana")
		check(grug_abilities.ready(ref, "blink"), label .. ": cooldown not armed")
	end
end

local casts = {
	{"cast_flat_down_20", 20, nil, true, EYE / math.tan(math.rad(20))},
	{"cast_wall_close_fails", 0,
		function(ox, oz) block(ox, oz, -2, 1, 1, 2, 3, 1) end, false},
	{"cast_flat_down_60_fails", 60, nil, false},
}

local function finish()
	log(("RESULT %s checks=%d failures=%d"):format(
		failures == 0 and "PASS" or "FAIL", checks, failures))
	core.request_shutdown("blink probe done", false, 0)
end

local function run_all()
	for index, sc in ipairs(scenarios) do
		local ok, err = pcall(run_pure, index, sc)
		check(ok, sc.label .. ": scenario ran without error" ..
			(ok and "" or (" (" .. tostring(err) .. ")")))
	end
	for i, c in ipairs(casts) do
		local ok, err = pcall(run_cast, #scenarios + i, c[1], c[2], c[3], c[4], c[5])
		check(ok, c[1] .. ": cast ran without error" ..
			(ok and "" or (" (" .. tostring(err) .. ")")))
	end
	finish()
end

-- One cleared air box per lane with a stone floor at BASE.y.
local function build_arena(minp, maxp)
	local vm = core.get_voxel_manip()
	local emin, emax = vm:read_from_map(minp, maxp)
	local area = VoxelArea(emin, emax)
	local data = vm:get_data()
	local c_air = core.get_content_id("air")
	local c_floor = core.get_content_id(STONE)
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			for x = minp.x, maxp.x do
				data[area:index(x, y, z)] = y == BASE.y and c_floor or c_air
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
end

core.after(2, function()
	local lanes = #scenarios + #casts
	local minp = vector.offset(BASE, -5, -6, -5)
	local maxp = vector.offset(BASE, SPACING * lanes + 5, 16, 16)
	log("emerging arena " .. core.pos_to_string(minp) .. " - " ..
		core.pos_to_string(maxp))
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		core.after(0, function()
			build_arena(minp, maxp)
			core.after(0.5, run_all)
		end)
	end)
end)
