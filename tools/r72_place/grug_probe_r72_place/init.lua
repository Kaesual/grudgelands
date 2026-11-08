-- Disposable Round 72 PLACE probe (never shipped): the placement rules of
-- grug_core/placement.lua on the real engine. Logs "[r72place]" lines, then
-- shuts the server down. In a forceloaded block high in the sky, on a cobble
-- floor, with stand-in bodies (a physical entity that does not collide with
-- objects and carries mobs_redo's `_cmi_is_mob`, `health` and `_grug_cbox`,
-- like every mob):
--   * the seam: builtin core.item_place_node refuses cobble into a body's
--     cell and places it into a free cell;
--   * the falling node: sand dropped from four nodes above a body falls
--     through it (bodies do not collide with objects) and drops as an item;
--     the same sand over a free cell lands as a node;
--   * the cost: one area query (grug_core.body_in_cells) with nobody near and
--     with ten bodies around, against a whole placement through the seam
--     (core.get_us_time over many calls).
--   PROBE=tools/r72_place/grug_probe_r72_place tools/luanti_headless.sh 150
-- The lane's one run (2026-11-08) placed with a nil placer, whose empty name
-- grug_core's protection refuses everywhere, so its seam line only showed the
-- protection refusal (and its placement timings a protected refusal); the
-- placer below carries a name and the log names each cell's protection. The
-- falling and query lines of that run: body cell air, one sand item, free
-- cell sand; the query 0.41 us with nobody near, 3.06 us among ten bodies.
local function log(fmt, ...)
	core.log("action", "[r72place] " .. fmt:format(...))
end

local BOX = {-0.4, -0.01, -0.4, 0.4, 1.8, 0.4}
local DUMMY = "grug_probe_r72_place:body"
core.register_entity(DUMMY, {
	initial_properties = {physical = true, collide_with_objects = false, collisionbox = BOX,
		visual = "sprite", is_visible = false, static_save = false},
	_cmi_is_mob = true, health = 20, _grug_cbox = BOX,
})

local BASE = {x = 8, y = 408, z = 8}
local function P(dx, dy, dz) return {x = BASE.x + dx, y = BASE.y + dy, z = BASE.z + dz} end
local objects = {}
local function body(dx, dz)
	local object = core.add_entity(P(dx, 0.5, dz), DUMMY)
	objects[#objects + 1] = object
	return object
end
-- A named non-player placer: the empty name is protected everywhere
-- (grug_core/protection.lua), and a non-player is never in combat.
local PLACER = {
	get_player_name = function() return "r72place_probe" end,
	is_player = function() return false end,
}
local function pointed(dx, dz)
	return {type = "node", under = P(dx, 0, dz), above = P(dx, 1, dz)}
end

local function finish(results)
	for _, object in ipairs(objects) do
		if object:get_pos() then object:remove() end
	end
	core.forceload_free_block(BASE, true)
	log("result %s", results)
	core.request_shutdown("r72place probe done")
end

local function falling_checks(results)
	local in_body = core.get_node(P(2, 1, 4)).name
	local free = core.get_node(P(6, 1, 4)).name
	local items = 0
	for _, object in ipairs(core.get_objects_inside_radius(P(2, 1, 4), 3)) do
		local entity = object:get_luaentity()
		if entity and entity.name == "__builtin:item" and
				ItemStack(entity.itemstring):get_name() == "default:sand" then
			items = items + 1
		end
	end
	log("falling body_cell=%s dropped_items=%d free_cell=%s", in_body, items, free)
	local ok = in_body == "air" and items == 1 and free == "default:sand"
	finish(results .. (ok and " falling=OK" or " falling=MISMATCH"))
end

local function run()
	-- The floor: cobble at y = BASE.y over 16 x 8.
	for dx = 0, 15 do
		for dz = 0, 7 do core.set_node(P(dx, 0, dz), {name = "default:cobble"}) end
	end
	-- The seam.
	body(2, 1)
	local _, refused_at = core.item_place_node(ItemStack("default:cobble"), PLACER, pointed(2, 1))
	local _, placed_at = core.item_place_node(ItemStack("default:cobble"), PLACER, pointed(4, 1))
	local seam_ok = refused_at == nil and core.get_node(P(2, 1, 1)).name == "air" and
		placed_at ~= nil and core.get_node(P(4, 1, 1)).name == "default:cobble"
	log("seam body_cell=%s free_cell=%s protected=%s,%s", core.get_node(P(2, 1, 1)).name,
		core.get_node(P(4, 1, 1)).name, tostring(core.is_protected(P(2, 1, 1), "r72place_probe")),
		tostring(core.is_protected(P(4, 1, 1), "r72place_probe")))
	core.remove_node(P(4, 1, 1))

	-- The cost: the area query alone, nobody near and ten bodies around.
	local N = 2000
	local far = {P(14, 1, 7)}
	local t0 = core.get_us_time()
	for _ = 1, N do grug_core.body_in_cells(far) end
	local empty_us = (core.get_us_time() - t0) / N
	for i = 0, 9 do body(8 + (i % 5), 5 + math.floor(i / 5) * 2) end
	local near = {P(10, 1, 4)} -- among them, overlapping none
	t0 = core.get_us_time()
	local hits = 0
	for _ = 1, N do
		if grug_core.body_in_cells(near) then hits = hits + 1 end
	end
	local crowd_us = (core.get_us_time() - t0) / N
	-- A whole placement through the seam (place and take away again), in the
	-- free corner and among the ten.
	local function placement_us(dx, dz)
		local cell = P(dx, 1, dz)
		local t = core.get_us_time()
		for _ = 1, N do
			core.item_place_node(ItemStack("default:cobble"), PLACER, pointed(dx, dz))
			core.remove_node(cell)
		end
		return (core.get_us_time() - t) / N
	end
	local place_far_us = placement_us(14, 7)
	local place_crowd_us = placement_us(10, 4)
	log("cost calls=%d query_empty_us=%.2f query_ten_bodies_us=%.2f overlaps=%d " ..
		"placement_empty_us=%.2f placement_ten_bodies_us=%.2f", N, empty_us, crowd_us, hits,
		place_far_us, place_crowd_us)

	-- The falling node: sand four above a body, and four above a free cell.
	body(2, 4)
	core.set_node(P(2, 4, 4), {name = "default:sand"})
	core.set_node(P(6, 4, 4), {name = "default:sand"})
	core.spawn_falling_node(P(2, 4, 4))
	core.spawn_falling_node(P(6, 4, 4))
	core.after(4, falling_checks, "seam=" .. (seam_ok and "OK" or "MISMATCH"))
end

core.after(1, function()
	core.forceload_block(BASE, true)
	core.emerge_area(P(0, 0, 0), P(15, 8, 7), function(_, _, remaining)
		if remaining == 0 then core.after(1, run) end
	end)
end)
