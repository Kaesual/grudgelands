-- The measured scenarios; run.sh picks one with SCENARIO=. All slots of a
-- scenario are named here by chunk indices, so a later run on the same kept
-- world (WORLD=) finds them generated.
local S = {}

local SIZES = {
	small = {96, 48, 96},
	mid = {128, 48, 128},
	big = {160, 64, 160},
	rec = {128, 64, 128, y = -112}, -- the recommendation, y -112..-49
}

-- A slot of `size`, on a coarse test grid that stays clear of every other test
-- slot. row 0.. picks z, column 0.. picks x. ky -1 is y -96.., -2 is y -176..
local function test_slot(lib, size, column, row, ky)
	local s = SIZES[size]
	local kx, kz = 101 + column * 8, -40 + row * 8
	local slot = lib.slot(kx, ky or -1, kz, s[1], s[2], s[3])
	if s.y then
		slot.minp.y = s.y
		slot.maxp.y = s.y + s[2] - 1
	end
	return slot
end

local function flush(lib, label)
	lib.phase("flush_" .. label)
	lib.wait(6)
	lib.phase_end()
end

-- Writes `tpl` whole, in one VoxelManip.
local function oneshot(lib, writer, tpl, slot, label)
	lib.phase("write_oneshot_" .. label)
	writer.reset_parts()
	writer.run(writer.vm_job(tpl, slot, {{slot.minp, slot.maxp}}, "engine"), 1)
	lib.phase_end(writer.parts_text())
end

-- Q1, Q2 (uncontended), Q3 by size: each box size from first emerge to reuse.
function S.sizes(lib, template, writer)
	writer.init(lib)
	lib.phase("baseline")
	lib.wait(20)
	lib.phase_end()
	local slots = {}
	for i, size in ipairs({"small", "mid", "big"}) do
		local s = SIZES[size]
		local tpl = template.build(s[1], s[2], s[3], 1)
		local truth = template.light(tpl)
		local slot = test_slot(lib, size, i, 1)
		slots[i] = {slot = slot, tpl = tpl, size = size}
		local p1, p2 = lib.grown(slot, 16)
		lib.logf("slot %s %s..%s: %d chunks with the 16-node margin, %d without", size,
			core.pos_to_string(slot.minp), core.pos_to_string(slot.maxp), #lib.chunks_of(p1, p2),
			#lib.chunks_of(slot.minp, slot.maxp))
		lib.phase("first_emerge_whole_" .. size)
		local t, gen, disk, mem, cancelled = lib.emerge(p1, p2)
		lib.phase_end(("emerge_s %.3f generated %d disk %d memory %d cancelled %d"):format(t, gen, disk, mem,
			cancelled))
		lib.phase("reemerge_memory_" .. size)
		t, gen, disk, mem, cancelled = lib.emerge(p1, p2)
		lib.phase_end(("emerge_s %.3f generated %d disk %d memory %d cancelled %d"):format(t, gen, disk, mem,
			cancelled))
		oneshot(lib, writer, tpl, slot, size)
		writer.verify(lib, "oneshot_" .. size, slot, tpl, truth)
		flush(lib, size)
		lib.phase("write_blocks2_" .. size)
		writer.reset_parts()
		writer.run(writer.vm_job(tpl, slot, writer.blocks(slot), "engine"), 2)
		lib.phase_end(writer.parts_text())
		writer.verify(lib, "blocks2_" .. size, slot, tpl, truth)
		flush(lib, size .. "2")
	end
	lib.phase("unload_wait")
	lib.wait(40)
	lib.phase_end()
	for _, entry in ipairs(slots) do
		local p1, p2 = lib.grown(entry.slot, 16)
		lib.phase("reuse_emerge_disk_" .. entry.size)
		local t, gen, disk, mem, cancelled = lib.emerge(p1, p2)
		lib.phase_end(("emerge_s %.3f generated %d disk %d memory %d cancelled %d"):format(t, gen, disk, mem,
			cancelled))
	end
	lib.phase("unload_wait2")
	lib.wait(40)
	lib.phase_end()
	for _, entry in ipairs(slots) do
		-- not emerged first: a VoxelManip read loads the blocks on the main thread
		oneshot(lib, writer, entry.tpl, entry.slot, "unloaded_" .. entry.size)
		flush(lib, "unloaded_" .. entry.size)
	end
end

-- Q3: the ways to write one 128 x 48 x 128 box. Every method starts from the
-- other layout (seed 2), the hard case of a reused slot, and is checked against
-- the template's nodes and the computed light, right away and 3 s later.
function S.methods(lib, template, writer)
	writer.init(lib)
	local s = SIZES.mid
	local tpl = template.build(s[1], s[2], s[3], 1)
	local other = template.build(s[1], s[2], s[3], 2)
	local truth = template.light(tpl)
	local slot = test_slot(lib, "mid", 1, 2)
	lib.phase("baseline")
	lib.wait(15)
	lib.phase_end()
	lib.emerge(lib.grown(slot, 16))
	oneshot(lib, writer, tpl, slot, "ref")
	writer.verify(lib, "oneshot_over_rock", slot, tpl, truth)
	flush(lib, "ref")

	-- the template as files: one schematic per column, made from the written box
	local dir = core.get_worldpath() .. "/r71spike"
	core.mkdir(dir)
	local columns = writer.columns(slot)
	local paths = {}
	local schem_bytes = 0
	local t0 = core.get_us_time()
	for k, area in ipairs(columns) do
		paths[k] = dir .. "/col" .. k .. ".mts"
		assert(core.create_schematic(area[1], area[2], nil, paths[k]))
		schem_bytes = schem_bytes + lib.file_size(paths[k])
	end
	lib.logf("SCHEMATICS %d files, %d bytes, made in %.0f ms", #paths, schem_bytes,
		(core.get_us_time() - t0) / 1000)

	local function start(label)
		oneshot(lib, writer, other, slot, "other_" .. label)
		lib.wait(1)
		writer.reset_parts()
		lib.phase("method_" .. label)
	end
	local function finish(label)
		lib.phase_end(writer.parts_text())
		writer.verify(lib, label, slot, tpl, truth)
		lib.wait(3)
		writer.verify(lib, label .. "_3s_later", slot, tpl, truth)
		flush(lib, label)
	end

	start("oneshot")
	writer.run(writer.vm_job(tpl, slot, {{slot.minp, slot.maxp}}, "engine"), 1)
	finish("oneshot")

	start("columns1")
	writer.run(writer.vm_job(tpl, slot, columns, "engine"), 1)
	finish("columns1")

	for _, n in ipairs({1, 2, 4, 8}) do
		local label = "blocks" .. n
		start(label)
		writer.run(writer.vm_job(tpl, slot, writer.blocks(slot), "engine"), n)
		finish(label)
	end

	start("schem_cols1_first")
	local job = {}
	for k, area in ipairs(columns) do
		job[k] = function() core.place_schematic(area[1], paths[k], "0", nil, true) end
	end
	writer.run(job, 1)
	finish("schem_cols1_first")
	start("schem_cols1_cached")
	writer.run(job, 1)
	finish("schem_cols1_cached")

	start("blocks2_nolight_fixlight")
	writer.run(writer.vm_job(tpl, slot, writer.blocks(slot), "none"), 2)
	local fix = {}
	for k, area in ipairs(writer.blocks(slot)) do
		fix[k] = function() core.fix_light(area[1], area[2]) end
	end
	writer.run(fix, 2)
	finish("blocks2_nolight_fixlight")

	-- light kept in the template (the tool can write it: the hull seals the box)
	start("blocks2_template_light")
	writer.run(writer.vm_job(tpl, slot, writer.blocks(slot), truth), 2)
	finish("blocks2_template_light")
	start("oneshot_template_light")
	writer.run(writer.vm_job(tpl, slot, {{slot.minp, slot.maxp}}, truth), 1)
	finish("oneshot_template_light")

	-- a compressed template: each block decompressed and decoded in the step
	local pack = template.pack(tpl)
	local packed = {}
	local rows, w = tpl.rows, tpl.w
	do
		local job2 = {}
		local list = writer.blocks(slot)
		for k, area in ipairs(list) do
			local bx = (area[1].x - slot.minp.x) / 16
			local by = (area[1].y - slot.minp.y) / 16
			local bz = (area[1].z - slot.minp.z) / 16
			local entry = pack.blocks[bz * 10000 + by * 100 + bx]
			job2[k] = function()
				local a = core.decompress(entry[1], "zstd")
				local b = core.decompress(entry[2], "zstd")
				local data, param2 = {a:byte(1, 4096)}, {b:byte(1, 4096)}
				for i = 1, 4096 do data[i] = pack.palette[data[i]] end
				local vm = VoxelManip()
				vm:read_from_map(area[1], area[2])
				vm:set_data(data)
				vm:set_param2_data(param2)
				vm:write_to_map(true)
			end
		end
		packed = job2
	end
	assert(rows and w)
	start("blocks2_packed")
	writer.run(packed, 2)
	finish("blocks2_packed")

	-- for scale: the per-node ways over one mapblock (4096 nodes)
	local a1 = slot.minp
	local a2 = vector.add(a1, 15)
	local positions = {}
	for z = a1.z, a2.z do
		for y = a1.y, a2.y do
			for x = a1.x, a2.x do positions[#positions + 1] = {x = x, y = y, z = z} end
		end
	end
	lib.phase("one_block_bulk_set_node")
	lib.timed(core.bulk_set_node, positions, {name = "default:stone"})
	lib.phase_end()
	lib.phase("one_block_set_node")
	lib.timed(function()
		for _, p in ipairs(positions) do core.set_node(p, {name = "default:cobble"}) end
	end)
	lib.phase_end()
	lib.phase("one_block_vm")
	lib.timed(function()
		writer.write_area(tpl, slot, a1, a2, "engine")
	end)
	lib.phase_end()

	lib.phase("find_nodes_with_meta_box")
	lib.timed(function()
		lib.logf("nodes with meta in the box: %d", #core.find_nodes_with_meta(slot.minp, slot.maxp))
	end)
	lib.phase_end()
end

-- Is the column at `at` generated as far as these points go?
local function ready_at(at)
	return core.get_node(at).name ~= "ignore"
end

local function fresh_land_spots(count)
	-- away from the start, where the character begins; the same list every run
	local from = {x = 0, z = -2550}
	local spots = {}
	for z = 3000, -3000, -340 do
		for x = -3400, 3400, 340 do
			if grug_zones.water_class_at(x, z) == "land" and
					math.abs(x - from.x) + math.abs(z - from.z) > 900 then
				spots[#spots + 1] = {x = x, y = math.max(grug_zones.terrain_height_at(x, z), 1) + 2, z = z}
			end
		end
	end
	local picked = {}
	-- spread over the list, deterministically
	local stride = math.max(1, math.floor(#spots / count))
	for i = 1, count do picked[i] = spots[1 + (i - 1) * stride] end
	return picked
end

-- Q2: what a chunk costs by place, and what a slot's first emerge does to a
-- player who generates terrain. The player teleports to fresh land, looking
-- along +z (the server generates what the camera faces); the time until its own
-- position and the points ahead of it exist. `r71spike_part = 2` skips the chunk
-- costs and takes later spots and slots: a second run on the same world.
function S.emerge(lib)
	local spots = fresh_land_spots(40)
	lib.logf("%d fresh land spots", #spots)
	local part = tonumber(core.settings:get("r71spike_part") or "") or 1
	local next_spot = part == 2 and 22 or 1
	local function spot()
		local at = spots[next_spot]
		next_spot = next_spot + 1
		return at
	end
	lib.phase("baseline")
	lib.wait(15)
	lib.phase_end()

	-- chunk costs, one chunk at a time, parked player
	local function cost(label, x, ky, z, n)
		lib.phase("chunk_" .. label)
		local times = {}
		for i = 1, n do
			local cx = x + (i - 1) * 80
			local at = {x = cx, y = lib.chunk_min(ky) + 40, z = z}
			times[i] = (lib.emerge(at, at))
		end
		lib.phase_end("chunks " .. lib.sizes_text(times))
	end
	if part == 1 then
		-- warm the generator's first-use costs away from the numbers
		lib.emerge_chunkwise({x = 16000, y = -40, z = 16000}, {x = 16079, y = 40, z = 16079})
		cost("offmap_k-2", 12008, -2, 8, 6)
		cost("offmap_k-1", 12008, -1, 8, 6)
		cost("offmap_k0", 12008, 0, 8, 6)
		cost("offmap_k1", 12008, 1, 8, 6)
		for i = 1, 3 do
			local at = spot()
			local k = lib.chunk_index(at.y)
			cost("land_surface_" .. i, at.x, k, at.z, 4)
			cost("land_k-1_" .. i, at.x, -1, at.z, 4)
		end
	end

	local ring = {{0, 0}, {0, 32}, {0, 64}, {-24, 64}, {24, 64}}
	-- one sample: the slot's emerge starts, the same step the player teleports
	local function sample(label, start_slot)
		local at = spot()
		local done = false
		local slot_s
		if start_slot then
			-- a second coroutine would be cleaner; the emerge runs on its callbacks
			start_slot(function(seconds)
				done = true
				slot_s = seconds
			end)
		else
			done = true
		end
		local player_now = lib.player()
		player_now:set_look_horizontal(0)
		player_now:set_look_vertical(0)
		player_now:set_pos(at)
		local t0 = core.get_us_time()
		local first, all
		while not all or not done do
			local now = (core.get_us_time() - t0) / 1e6
			if not first and ready_at(at) then first = now end
			if not all then
				local ok = true
				for _, r in ipairs(ring) do
					if not ready_at({x = at.x + r[1], y = at.y, z = at.z + r[2]}) then ok = false end
				end
				if ok then all = now end
			end
			if now > 15 then break end
			lib.yield()
		end
		lib.logf("SAMPLE %s player_own %.2f player_ring %.2f slot_s %s", label, first or -1, all or -1,
			tostring(slot_s))
		-- the rest of that spot's terrain, so the next sample starts idle
		lib.wait(8)
	end

	local function whole(slot)
		return function(finished)
			local p1, p2 = lib.grown(slot, 16)
			local t0 = core.get_us_time()
			local left
			core.emerge_area(p1, p2, function(_, _, remaining)
				left = remaining
				if left == 0 then finished((core.get_us_time() - t0) / 1e6) end
			end)
		end
	end
	local function chunkwise(slot)
		return function(finished)
			local p1, p2 = lib.grown(slot, 16)
			local chunks = lib.chunks_of(p1, p2)
			local t0 = core.get_us_time()
			local i = 0
			local function ask()
				i = i + 1
				local k = chunks[i]
				if not k then
					finished((core.get_us_time() - t0) / 1e6)
					return
				end
				local at = {x = lib.chunk_min(k.x) + 40, y = lib.chunk_min(k.y) + 40, z = lib.chunk_min(k.z) + 40}
				core.emerge_area(at, at, function(_, _, remaining)
					if remaining == 0 then ask() end
				end)
			end
			ask()
		end
	end

	lib.phase("gen_baseline")
	for i = 1, 3 do sample("baseline_" .. i) end
	lib.phase_end()
	local row = part == 2 and 5 or 3
	local function series(label, make, size, n)
		lib.phase("gen_" .. label)
		for i = 1, n do
			local slot = test_slot(lib, size, i, row)
			sample(label .. "_" .. i, make(slot))
		end
		row = row + 1
		if row == 8 then row = 9 end
		lib.phase_end()
	end
	series("whole_mid", whole, "mid", 3)
	series("chunkwise_mid", chunkwise, "mid", 3)
	series("whole_big", whole, "big", 3)
	series("chunkwise_big", chunkwise, "big", 3)
	lib.phase("gen_baseline_after")
	for i = 4, 5 do sample("baseline_" .. i) end
	lib.phase_end()
end

-- What the zone queries answer at a position.
local function answers(lib, label, pos)
	local name = lib.NAME
	local function try(fn, ...)
		local ok, value = pcall(fn, ...)
		return ok and tostring(value) or "ERROR " .. tostring(value)
	end
	lib.logf("ANSWERS %s %s: water_class_at %s territory_rule_at %s id_at %s biome_at %s pvp_rule_at %s " ..
		"mob_level_at %s is_protected(player) %s is_protected('') %s world_alterable %s open_sea %s location %q",
		label, core.pos_to_string(pos), try(grug_zones.water_class_at, pos.x, pos.z),
		try(grug_zones.territory_rule_at, pos), try(grug_zones.id_at, pos.x, pos.z),
		try(grug_zones.biome_at, pos.x, pos.z), try(grug_zones.pvp_rule_at, pos),
		try(grug_core.mob_level_at, pos), try(core.is_protected, pos, name), try(core.is_protected, pos, ""),
		try(grug_core.world_alterable, pos),
		try(grug_core.open_sea_at, pos),
		try(function() return (grug_map.location.text_of(lib.player())) end))
end

-- The seabed over a slot and the liquids in and round it, before writing.
local function survey(lib, label, slot)
	local cx, cz = slot.minp.x + slot.w / 2, slot.minp.z + slot.d / 2
	local low, high = 1000, -1000
	local p1, p2 = {x = slot.minp.x, y = -112, z = slot.minp.z}, {x = slot.maxp.x, y = 47, z = slot.maxp.z}
	lib.emerge(p1, p2)
	local vm = VoxelManip()
	local e1, e2 = vm:read_from_map(p1, p2)
	local area = VoxelArea(e1, e2)
	local data = vm:get_data()
	local WATER = core.get_content_id("default:water_source")
	local AIR, IGNORE = core.CONTENT_AIR, core.CONTENT_IGNORE
	for z = slot.minp.z, slot.maxp.z, 16 do
		for x = slot.minp.x, slot.maxp.x, 16 do
			for y = 47, -112, -1 do
				local c = data[area:index(x, y, z)]
				if c ~= WATER and c ~= AIR and c ~= IGNORE then
					if y < low then low = y end
					if y > high then high = y end
					break
				end
			end
		end
	end
	lib.logf("SEABED %s near %d,%d: between y %d and %d", label, cx, cz, low, high)
	local g1, g2 = lib.grown(slot, 16)
	local function count(a, b, what)
		return #core.find_nodes_in_area(a, b, what)
	end
	lib.logf("SURVEY %s box: %d water, %d lava, %d air; box with margin: %d water, %d lava, %d air", label,
		count(slot.minp, slot.maxp, {"group:water"}), count(slot.minp, slot.maxp, {"group:lava"}),
		count(slot.minp, slot.maxp, {"air"}), count(g1, g2, {"group:water"}), count(g1, g2, {"group:lava"}),
		count(g1, g2, {"air"}))
end

-- Names and counts of the Lua entities within `radius` of pos, but the player.
local function census(pos, radius)
	local counts, total = {}, 0
	for _, object in ipairs(core.get_objects_inside_radius(pos, radius)) do
		local entity = object:get_luaentity()
		if entity then
			counts[entity.name] = (counts[entity.name] or 0) + 1
			total = total + 1
		end
	end
	local parts = {}
	for name, n in pairs(counts) do parts[#parts + 1] = name .. "=" .. n end
	table.sort(parts)
	return total, table.concat(parts, " ")
end

local function room_of(slot, tpl)
	return {x = slot.minp.x + tpl.spawn.x + 0.5, y = slot.minp.y + tpl.spawn.y + 0.5, z = slot.minp.z + tpl.spawn.z + 0.5}
end

-- A teleport the client is filmed for: run.sh takes frames from the BURST on,
-- the teleport comes one second into it.
local function filmed_teleport(lib, name, pos, seconds)
	lib.logf("BURST %s %d", name, seconds)
	lib.wait(1.5)
	lib.logf("TELEPORT %s at %d ms", name, core.get_us_time() / 1000)
	lib.player():set_pos(pos)
	lib.wait(seconds)
end

-- Q7: a slot with a player inside; both depths; a control on land.
function S.visit(lib, template, writer)
	writer.init(lib)
	local s = SIZES.mid
	local tpl = template.build(s[1], s[2], s[3], 1)
	local player = lib.player()
	player:set_look_horizontal(0)
	player:set_look_vertical(0)

	local deep = test_slot(lib, "mid", 3, 8, -2)
	local shallow = test_slot(lib, "mid", 2, 8, -1)
	local map0 = lib.map_size()
	lib.logf("MAP size before %d", map0)
	lib.emerge(lib.grown(shallow, 16))
	survey(lib, "shallow", shallow)
	lib.emerge(lib.grown(deep, 16))
	survey(lib, "deep", deep)
	for _, entry in ipairs({{"shallow", shallow}, {"deep", deep}}) do
		answers(lib, entry[1] .. "_box", vector.add(entry[2].minp, 40))
		oneshot(lib, writer, tpl, entry[2], entry[1])
	end
	local hash_shallow = writer.read_box(shallow)
	local hash_deep = writer.read_box(deep)
	lib.wait(7)
	lib.logf("MAP size after two slots emerged and written %d (+%d)", lib.map_size(), lib.map_size() - map0)

	-- control: the same entity count on land, 60 s
	local land = fresh_land_spots(40)[38]
	lib.wait(0.2)
	filmed_teleport(lib, "land", land, 6)
	answers(lib, "land", land)
	for i = 1, 6 do
		lib.wait(10)
		lib.logf("LAND t %d entities within 96: %d %s", i * 10, census(land, 96))
	end

	filmed_teleport(lib, "first_shallow", room_of(shallow, tpl), 7)
	answers(lib, "player_in_shallow", lib.player():get_pos())
	lib.logf("STATE hp %d pos %s", lib.player():get_hp(), core.pos_to_string(lib.player():get_pos()))
	lib.phase("inside_shallow")
	for i = 1, 8 do
		lib.wait(10)
		local total, list = census(lib.player():get_pos(), 128)
		lib.logf("SHALLOW t %d entities within 128: %d %s; hp %d, map %d", i * 10, total, list,
			lib.player():get_hp(), lib.map_size())
	end
	lib.phase_end()

	filmed_teleport(lib, "first_deep", room_of(deep, tpl), 7)
	lib.phase("inside_deep")
	for i = 1, 6 do
		lib.wait(10)
		local total, list = census(lib.player():get_pos(), 128)
		lib.logf("DEEP t %d entities within 128: %d %s; hp %d, map %d", i * 10, total, list,
			lib.player():get_hp(), lib.map_size())
	end
	lib.phase_end()

	-- how far blocks are active round the player, along +x
	local at = vector.round(lib.player():get_pos())
	local farthest = 0
	for dx = 0, 160, 16 do
		if core.compare_block_status({x = at.x + dx, y = at.y, z = at.z}, "active") then farthest = dx end
	end
	lib.logf("ACTIVE along +x to %d nodes", farthest)

	-- back to the known slot: the client has its blocks
	filmed_teleport(lib, "again_shallow", room_of(shallow, tpl), 5)
	for _, entry in ipairs({{"shallow", shallow, hash_shallow}, {"deep", deep, hash_deep}}) do
		local got = writer.read_box(entry[2])
		lib.logf("HULL %s: hash %d, after the wait %d; box water %d lava %d", entry[1], entry[3].hash, got.hash,
			#core.find_nodes_in_area(entry[2].minp, entry[2].maxp, {"group:water"}),
			#core.find_nodes_in_area(entry[2].minp, entry[2].maxp, {"group:lava"}))
	end
	lib.wait(7)
	lib.logf("MAP size at the end %d (+%d)", lib.map_size(), lib.map_size() - map0)
end

-- Q6 first boot. In one box an earlier run's objects, node meta and a timer
-- meet a plain rewrite; two small boxes keep objects for the restart.
local function spawn_leftovers(lib, pos)
	local objects = {}
	objects.item = core.add_item(pos, "default:stick")
	objects.mob = core.add_entity(vector.add(pos, {x = 2, y = 0, z = 0}), "grug_mobs:bear")
	local item2 = core.add_item(vector.add(pos, {x = 0, y = 0, z = 2}), "default:apple")
	if item2 then item2:set_properties({static_save = false}) end
	local mob2 = core.add_entity(vector.add(pos, {x = 2, y = 0, z = 2}), "grug_mobs:bear")
	if mob2 then mob2:set_properties({static_save = false}) end
	lib.logf("LEFTOVERS spawned at %s: item %s mob %s, unsaved item %s mob %s", core.pos_to_string(pos),
		tostring(objects.item ~= nil), tostring(objects.mob ~= nil), tostring(item2 ~= nil), tostring(mob2 ~= nil))
end

local function small_slot(lib, ix)
	return lib.slot(145, -1, 40 + ix, 48, 32, 48)
end

function S.left1(lib, template, writer)
	writer.init(lib)
	local s = SIZES.mid
	local tpl = template.build(s[1], s[2], s[3], 1)
	local slot = test_slot(lib, "mid", 5, 8)
	lib.emerge(lib.grown(slot, 16))
	oneshot(lib, writer, tpl, slot, "left")
	local room = room_of(slot, tpl)
	lib.player():set_pos(room)
	lib.wait(4)
	spawn_leftovers(lib, room)
	local chest = vector.add(vector.round(room), {x = -2, y = 0, z = 0})
	core.set_node(chest, {name = "default:chest"})
	core.get_inventory({type = "node", pos = chest}):add_item("main", "default:gold_ingot 3")
	core.get_node_timer(chest):start(100000)
	lib.wait(3)
	lib.logf("A in the box with the player: %d %s", census(room, 16))
	-- leave; wait until the blocks went out of memory
	local away = fresh_land_spots(40)[20]
	lib.player():set_pos(away)
	lib.logf("A player away at %s", core.pos_to_string(away))
	lib.wait(45)
	lib.logf("A block status loaded %s active %s", tostring(core.compare_block_status(room, "loaded")),
		tostring(core.compare_block_status(room, "active")))
	lib.phase("A_rewrite")
	writer.reset_parts()
	writer.run(writer.vm_job(tpl, slot, writer.blocks(slot), "engine"), 4)
	lib.phase_end(writer.parts_text())
	local meta = core.get_meta(chest):to_table()
	lib.logf("A after rewrite: node %s, meta inventory items %s, meta fields %d, timer started %s, nodes with meta %d",
		core.get_node(chest).name, tostring(meta.inventory and meta.inventory.main and #meta.inventory.main or 0),
		(function() local n = 0 for _ in pairs(meta.fields or {}) do n = n + 1 end return n end)(),
		tostring(core.get_node_timer(chest):is_started()),
		#core.find_nodes_with_meta(slot.minp, slot.maxp))
	lib.player():set_pos(room)
	lib.wait(6)
	lib.logf("A player back in the box: %d %s", census(room, 16))
	-- the objects go again, by hand, and the meta sweep
	for object in core.objects_in_area(slot.minp, slot.maxp) do
		if not object:is_player() then object:remove() end
	end
	lib.phase("A_meta_sweep")
	lib.timed(function()
		for _, p in ipairs(core.find_nodes_with_meta(slot.minp, slot.maxp)) do
			core.get_meta(p):from_table(nil)
		end
		core.get_node_timer(chest):stop()
	end)
	lib.phase_end()
	lib.logf("A after the sweep: nodes with meta %d, timer %s", #core.find_nodes_with_meta(slot.minp, slot.maxp),
		tostring(core.get_node_timer(chest):is_started()))

	-- delete_area as the clear: blocks, meta, timers and static objects go, and
	-- the next emerge generates the area anew
	lib.player():set_pos(away)
	lib.wait(3)
	lib.phase("B_delete_area")
	lib.timed(function()
		lib.logf("delete_area %s", tostring(core.delete_area(slot.minp, slot.maxp)))
	end)
	lib.phase_end()
	lib.phase("B_reemerge")
	local t, gen, disk, mem, cancelled = lib.emerge(lib.grown(slot, 16))
	lib.phase_end(("emerge_s %.3f generated %d disk %d memory %d cancelled %d"):format(t, gen, disk, mem, cancelled))
	lib.logf("B a node in the box after the re-emerge: %s", core.get_node(room).name)

	-- for the restart: two small boxes, the player between them at shutdown
	local a, b = small_slot(lib, 0), small_slot(lib, 1)
	local g1 = lib.grown(a, 16)
	local _, g2 = lib.grown(b, 16)
	lib.emerge(g1, g2)
	local air = {name = "air"}
	for _, box in ipairs({a, b}) do
		for z = box.minp.z, box.maxp.z do
			for y = box.minp.y + 8, box.minp.y + 15 do
				for x = box.minp.x, box.maxp.x do core.set_node({x = x, y = y, z = z}, air) end
			end
		end
	end
	local pa = vector.add(a.minp, {x = 24, y = 9, z = 24})
	local pb = vector.add(b.minp, {x = 24, y = 9, z = 24})
	lib.player():set_pos(vector.divide(vector.add(pa, pb), 2))
	lib.wait(5)
	spawn_leftovers(lib, pa)
	spawn_leftovers(lib, pb)
	lib.wait(3)
	lib.logf("C before shutdown, box a: %d %s", census(pa, 16))
	lib.logf("C before shutdown, box b: %d %s", census(pb, 16))
end

-- The objects of a box that survive only in their blocks come to life under a
-- transient forceload and are removed. Returns seconds, the objects removed.
local function sweep(lib, slot)
	local t0 = core.get_us_time()
	local blocks = {}
	for z = slot.minp.z, slot.maxp.z, 16 do
		for y = slot.minp.y, slot.maxp.y, 16 do
			for x = slot.minp.x, slot.maxp.x, 16 do
				local p = {x = x, y = y, z = z}
				blocks[#blocks + 1] = p
				core.forceload_block(p, true, -1)
			end
		end
	end
	lib.wait_for(function()
		for _, p in ipairs(blocks) do
			if not core.compare_block_status(p, "active") then return false end
		end
		return true
	end, 15)
	-- one step more: activation of a block's objects comes with it
	lib.yield()
	local removed = 0
	for object in core.objects_in_area(slot.minp, slot.maxp) do
		if not object:is_player() then
			object:remove()
			removed = removed + 1
		end
	end
	for _, p in ipairs(blocks) do core.forceload_free_block(p, true) end
	return (core.get_us_time() - t0) / 1e6, removed
end

-- Q6 second boot. Box a is rewritten only (the control), box b swept first.
function S.left2(lib, template, writer)
	writer.init(lib)
	local a, b = small_slot(lib, 0), small_slot(lib, 1)
	local pa = vector.add(a.minp, {x = 24, y = 9, z = 24})
	local pb = vector.add(b.minp, {x = 24, y = 9, z = 24})
	local player = lib.player()
	lib.logf("D player at boot %s", core.pos_to_string(player:get_pos()))
	player:set_pos({x = 0, y = 40, z = -2550})
	lib.wait(8)
	lib.logf("D box a loaded %s, box b loaded %s", tostring(core.compare_block_status(pa, "loaded")),
		tostring(core.compare_block_status(pb, "loaded")))
	lib.wait(35)
	lib.logf("D after the wait: box a loaded %s, box b loaded %s", tostring(core.compare_block_status(pa, "loaded")),
		tostring(core.compare_block_status(pb, "loaded")))
	lib.phase("D_sweep_box_b")
	local seconds, removed = sweep(lib, b)
	lib.phase_end(("sweep_s %.2f removed %d"):format(seconds, removed))
	lib.player():set_pos(pb)
	lib.wait(6)
	lib.logf("D player in box b after the sweep: %d %s", census(pb, 16))
	lib.player():set_pos(pa)
	lib.wait(6)
	lib.logf("D player in box a, no sweep: %d %s", census(pa, 16))
	lib.logf("D that entity's static_save: unsaved objects do not come back; see the names above")

	-- the sweep at the full size, an empty generated box
	local s = SIZES.mid
	local slot = test_slot(lib, "mid", 5, 8)
	lib.player():set_pos({x = 0, y = 40, z = -2550})
	lib.wait(35)
	lib.phase("E_sweep_mid_cold")
	local seconds2, removed2 = sweep(lib, slot)
	lib.phase_end(("sweep_s %.2f removed %d"):format(seconds2, removed2))
	assert(s)
end

-- Q4, Q5: the whole preparation with a client online, at the recommended size:
-- five in a row in unused slots, two and three side by side, and one after the
-- other for a full [GRUG-PERF] minute. `r71spike_n`: mapblocks per step.
function S.queue(lib, template, writer)
	writer.init(lib)
	local n = tonumber(core.settings:get("r71spike_n") or "") or 2
	local s = SIZES.rec
	local tpl = template.build(s[1], s[2], s[3], 1)
	local other = template.build(s[1], s[2], s[3], 2)
	local truth = template.light(tpl)
	local truth_other = template.light(other)
	lib.phase("baseline")
	lib.wait(60)
	lib.phase_end()

	-- One preparation: generate if needed (one chunk at a time), sweep the
	-- objects, clear the meta, write.
	local function prepare(slot, layout, first, label)
		local t0 = core.get_us_time()
		local chunks = 0
		if first then
			chunks = #lib.emerge_chunkwise(lib.grown(slot, 16))
		end
		local t1 = core.get_us_time()
		local swept_s, removed = sweep(lib, slot)
		local t2 = core.get_us_time()
		lib.timed(function()
			for _, p in ipairs(core.find_nodes_with_meta(slot.minp, slot.maxp)) do
				core.get_meta(p):from_table(nil)
			end
		end)
		writer.run(writer.vm_job(layout, slot, writer.blocks(slot), "engine"), n)
		local t3 = core.get_us_time()
		lib.logf("PREP %s total %.2f s: emerge %.2f (%d chunks), sweep %.2f (%d objects), write %.2f", label,
			(t3 - t0) / 1e6, (t1 - t0) / 1e6, chunks, swept_s, removed, (t3 - t2) / 1e6)
	end

	local slots = {}
	for i = 1, 5 do slots[i] = test_slot(lib, "rec", i, 11) end

	lib.phase("queue5_first_use")
	local t0 = core.get_us_time()
	for i = 1, 5 do prepare(slots[i], tpl, true, "first_" .. i) end
	lib.phase_end(("queue_s %.1f"):format((core.get_us_time() - t0) / 1e6))
	writer.verify(lib, "queue_first_5", slots[5], tpl, truth)
	flush(lib, "queue5_first_use")

	-- two and three boxes at once: one writer per box, in the same step
	for _, count in ipairs({2, 3}) do
		local job = {}
		for i = 1, count do
			local list = writer.vm_job(other, slots[i], writer.blocks(slots[i]), "engine")
			for k, fn in ipairs(list) do job[(k - 1) * count + i] = fn end
		end
		lib.phase("parallel_" .. count)
		writer.run(job, n * count)
		lib.phase_end()
		for i = 1, count do
			writer.verify(lib, "parallel_" .. count .. "_" .. i, slots[i], other, truth_other)
		end
		flush(lib, "parallel_" .. count)
	end

	oneshot(lib, writer, tpl, slots[4], "rec")
	flush(lib, "oneshot_rec")

	-- one preparation after the other, with no pause, for a minute
	lib.phase("sustained")
	t0 = core.get_us_time()
	local i = 0
	while core.get_us_time() - t0 < 65e6 do
		i = i + 1
		prepare(slots[(i - 1) % 5 + 1], i % 2 == 0 and tpl or other, false, "sustained_" .. i)
	end
	lib.phase_end(("%d preparations"):format(i))
	lib.phase("after")
	lib.wait(10)
	lib.phase_end()
end

-- Q1: does generating a chunk change the outer mapblock of its generated
-- neighbour? Fills that layer with brick, generates the neighbour, counts.
function S.shell(lib)
	local BRICK = core.get_content_id("default:stonebrick")
	for i = 1, 6 do
		local ky = i % 2 == 0 and 0 or -1
		local kx, kz = 170 + i * 3, 4
		local a = {x = lib.chunk_min(kx) + 40, y = lib.chunk_min(ky) + 40, z = lib.chunk_min(kz) + 40}
		lib.emerge(a, a)
		local p1 = {x = lib.chunk_min(kx) + 64, y = lib.chunk_min(ky), z = lib.chunk_min(kz)}
		local p2 = {x = lib.chunk_min(kx) + 79, y = lib.chunk_min(ky) + 79, z = lib.chunk_min(kz) + 79}
		local vm = VoxelManip()
		vm:read_from_map(p1, p2)
		local data = vm:get_data()
		for n = 1, #data do data[n] = BRICK end
		vm:set_data(data)
		vm:write_to_map(true)
		local b = {x = lib.chunk_min(kx + 1) + 40, y = a.y, z = a.z}
		lib.emerge(b, b)
		local reader = VoxelManip()
		reader:read_from_map(p1, p2)
		local after = reader:get_data()
		local changed, names = 0, {}
		for n = 1, #after do
			if after[n] ~= BRICK then
				changed = changed + 1
				local name = core.get_name_from_content_id(after[n])
				names[name] = (names[name] or 0) + 1
			end
		end
		local parts = {}
		for name, count in pairs(names) do parts[#parts + 1] = name .. "=" .. count end
		table.sort(parts)
		lib.logf("SHELL chunk %d,%d,%d: %d of %d nodes of its outer block layer changed by the neighbour %s",
			kx, ky, kz, changed, #after, table.concat(parts, " "))
	end
end

-- Q7: who spawns round a player in a slot, and whether the box keeps them out:
-- a fresh slot as the game stands, then one with a gate on the spawn policy.
function S.spawns(lib, template, writer)
	writer.init(lib)
	local s = SIZES.mid
	local tpl = template.build(s[1], s[2], s[3], 1)
	local function watch(label, slot)
		local seen = {}
		for i = 1, 8 do
			lib.wait(10)
			local inside, outside, attacking = 0, 0, 0
			local at = lib.player():get_pos()
			for _, object in ipairs(core.get_objects_inside_radius(at, 160)) do
				local entity = object:get_luaentity()
				if entity and entity.name:find("^grug_mobs:") then
					local p = object:get_pos()
					local box = p.x >= slot.minp.x and p.x <= slot.maxp.x and p.y >= slot.minp.y and
						p.y <= slot.maxp.y and p.z >= slot.minp.z and p.z <= slot.maxp.z
					if box then inside = inside + 1 else outside = outside + 1 end
					if entity.state == "attack" then attacking = attacking + 1 end
					local key = tostring(object)
					if not seen[key] then
						seen[key] = true
						lib.logf("MOB %s %s at %s %s, level %s", label, entity.name,
							core.pos_to_string(vector.round(p)), box and "IN THE BOX" or "outside",
							tostring(entity._grug_level or entity.level))
					end
				end
			end
			lib.logf("WATCH %s t %d: in the box %d, outside %d, attacking %d, hp %d", label, i * 10, inside,
				outside, attacking, lib.player():get_hp())
		end
	end
	local function enter(slot)
		lib.emerge(lib.grown(slot, 16))
		oneshot(lib, writer, tpl, slot, "spawn")
		lib.player():set_pos(room_of(slot, tpl))
	end
	local plain = test_slot(lib, "mid", 1, 10)
	survey(lib, "plain", plain)
	enter(plain)
	watch("as_is", plain)

	local allows = grug_mobs.spawn_policy_allows
	local refused = 0
	grug_mobs.spawn_policy_allows = function(name, pos)
		if pos.x > 4100 then
			refused = refused + 1
			return false
		end
		return allows(name, pos)
	end
	local gated = test_slot(lib, "mid", 2, 10)
	survey(lib, "gated", gated)
	enter(gated)
	watch("gated", gated)
	lib.logf("the gate refused %d spawn points", refused)
end

return S
