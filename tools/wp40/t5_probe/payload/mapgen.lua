-- WP40 T5-0 engine-seam probe -- the registered mapgen script (contract 9,
-- 10.10, 12.3).  Disposable: injected into a generated world's game tree by
-- tools/wp40/t5_probe/run_t5_probe.sh, never shipped with the game.
--
-- This file NEVER touches the raw mapgen VoxelManip.  Callback argument 1 goes
-- straight into the counting proxy on the first statement of the callback and
-- is never bound to a name any method call could be written against; the proxy
-- (payload/vm_proxy.lua) is the one permitted holder, contract 10.12.
--
-- Two arms, one file.  Arm A1 performs ZERO VoxelManip calls of any kind --
-- including get_emerged_area, which is why emin/emax are null there (12.3) --
-- while still emitting the same case, the same DECLARED extents (they are
-- literals, not measurements) and all-zero counters.  Arm B runs 10.10's seven
-- step sequence.

local load_started_us = core.get_us_time()

local MOD_NAME = "grug_wp40_t5_probe"
local SCHEMA = "grug_wp40_t5_probe_synthetic_v0"
local MARKER = "WP40_T5_PROBE_JSON "
local CONFIG_KEY = MOD_NAME .. ":config"
local STATE_KEY = MOD_NAME .. ":mapgen_state"
local CHUNK_KEY_PREFIX = MOD_NAME .. ":chunk:"
local LIGHT_ROLLUP_SCHEMA = "schema=wp40-t5-probe-light-outside-v1"

-- Light-dirty neighbourhood radius and the emerged shell, both engine-fixed.
local LIGHT_RADIUS = 15

local vm_proxy = dofile(core.get_modpath(MOD_NAME) .. "/vm_proxy.lua")

-- string.char lookup for the two light banks' packing and the slab hashes;
-- param1 is a u8 (l_vmanip.cpp:284-292).
local CHR = {}
for value = 0, 255 do
	CHR[value] = string.char(value)
end

--
-- Arm and order.  The driver publishes them over IPC before the emerge threads
-- start; the load-time ipc_get is also seam S4's measurement.  core.settings is
-- present in this state (ModApiUtil::InitializeAsync creates it,
-- reference_projects/luanti/src/script/lua_api/l_util.cpp:908-909) and is the
-- fallback, so a failed round trip is recorded as ipc_get_ok = false instead of
-- silently mislabelling every record in the file.
--
local ipc_get_started = core.get_us_time()
local config = core.ipc_get(CONFIG_KEY)
local ipc_get_us = core.get_us_time() - ipc_get_started
local ipc_get_ok = type(config) == "table" and type(config.arm) == "string" and
	type(config.order) == "string"

local arm, order
if ipc_get_ok then
	arm = config.arm
	order = config.order
else
	arm = core.settings:get(MOD_NAME .. ".arm") or "A1"
	order = core.settings:get(MOD_NAME .. ".order") or "O1"
end
local is_treatment = (arm == "B")

local mapgen_seq = 0

local function emit(tag, fields)
	mapgen_seq = mapgen_seq + 1
	fields.schema = SCHEMA
	fields.tag = tag
	fields.arm = arm
	fields.order = order
	fields.run_id = arm .. "-" .. order
	fields.state = "mapgen"
	fields.seq = mapgen_seq
	core.log("action", MARKER .. core.write_json(fields))
end

-- core.write_json turns an EMPTY table into JSON null and has no other way to
-- express one: read_json_value only ever sees non-nil table values
-- (reference_projects/luanti/src/script/common/c_content.cpp:2260-2289), and the
-- engine documents the empty-table rule at
-- reference_projects/luanti/doc/lua_api.md:8112-8113.  Every `null` this file
-- emits is therefore a fresh empty table -- fresh, so nothing can ever mutate a
-- shared one into a non-null value.
local function json_null()
	return {}
end

local function vec(x, y, z)
	return {x = x, y = y, z = z}
end

--
-- The synthetic payload (contract 9): six literal box sextuples
-- {minx, miny, minz, maxx, maxy, maxz}, five literal node names, one param2
-- constant, and a dispatcher keyed on minp.x alone.  The box NAME is the table
-- key, never a field of the tuple.
--
local BOXES = {
	cut = {628, 0, 712, 635, 7, 719},
	fill = {628, -8, 712, 635, -1, 719},
	water = {644, 0, 712, 651, 7, 719},
	facedir = {660, 0, 712, 667, 7, 719},
	["4lo"] = {840, 0, 712, 847, 7, 719},
	["4hi"] = {848, 0, 712, 855, 7, 719},
}

local PARAM2_VALUE = 1

local PAYLOAD_NODE_NAMES = {
	"air",
	"default:stone",
	"default:water_source",
	"default:goldblock",
	"stairs:stair_cobble",
}

--
-- Node property resolution, once per mapgen state (seam S4f).  L(id) is the
-- brief's light triple (paramtype == "light", sunlight_propagates,
-- light_source) folded into one integer so the dirty predicate is one compare;
-- liquidtype drives q.  Unset fields resolve through nodedef_default, which
-- builtin/emerge/register.lua:16 installs as each definition's __index.
--
local content_ids = {}
local id_names = {}
local light_code = {}
local is_liquid = {}
local registered_nodes_available = false

local function absorb(name, id, def)
	content_ids[name] = id
	local code = 0
	if def.paramtype == "light" then
		code = code + 1
	end
	if def.sunlight_propagates then
		code = code + 2
	end
	code = code + 4 * (tonumber(def.light_source) or 0)
	light_code[id] = code
	is_liquid[id] = (def.liquidtype ~= nil and def.liquidtype ~= "none")
end

do
	local nodes = core.registered_nodes
	if type(nodes) == "table" then
		-- (a) The raw walk.  It exists to give light_code / is_liquid coverage
		-- for the ARBITRARY pre-existing content ids the probe meets in the
		-- get_data buffer, which is why it cannot be replaced by the five-name
		-- resolution below.
		for name, def in pairs(nodes) do
			local ok, id = pcall(core.get_content_id, name)
			if ok and type(id) == "number" then
				absorb(name, id, def)
				id_names[id] = name
			end
		end

		-- (b) The five payload names, resolved DIRECTLY.  pairs() walks raw keys
		-- only, and core.registered_nodes carries the alias metatable installed
		-- at builtin/emerge/register.lua:44
		-- (__index = rawget(t, core.registered_aliases[name])), so a name that
		-- exists only as an ALIAS is invisible to the walk above.  Measured in
		-- this game's emerge state: "default:goldblock" is exactly such a name --
		-- mods/ITEMS/grug_materials/registry.lua:372 maps it to
		-- "grug_materials:gold_block" -- so the walk alone left
		-- content_ids["default:goldblock"] nil, flipped
		-- registered_nodes_available to false, and silently degraded arm B into
		-- an A1-shaped run.
		--
		-- core.get_content_id resolves an alias to the TARGET's id, and the
		-- indexed lookup resolves it to the TARGET's definition, so the id and
		-- the properties always describe the same node.
		registered_nodes_available = true
		for index = 1, #PAYLOAD_NODE_NAMES do
			local name = PAYLOAD_NODE_NAMES[index]
			local ok, id = pcall(core.get_content_id, name)
			local def = nodes[name]
			if ok and type(id) == "number" and type(def) == "table" then
				absorb(name, id, def)
				-- id_names is deliberately NOT overwritten when the raw walk
				-- already named this id.  It labels case_baseline's
				-- native_content_at_extent, which reports what was ALREADY in
				-- the buffer, so the REGISTERED (target) name is the honest
				-- label; writing the probe's alias spelling over it would
				-- report a native node under a name this game never registered.
				-- Where the raw walk left no entry at all, the alias spelling is
				-- better than none.
				if id_names[id] == nil then
					id_names[id] = name
				end
			else
				registered_nodes_available = false
			end
		end
	end
end

local AIR_ID = content_ids["air"]

local function light_of(id)
	local code = light_code[id]
	if code == nil then
		return -1
	end
	return code
end

--
-- Case specifications.  Keyed by minp.x alone (contract 9 item 4); the three
-- measured mapchunks are k_y = 0, k_z = 9, k_x in {8, 10, 11}, whose central
-- slices start at 80 * k_x - 32.
--
local function build_case(case_name, kx, content_boxes, param2_boxes,
		write_extent_content, write_extent_param2)
	local bx0, by0, bz0, bx1, by1, bz1
	for index = 1, #content_boxes do
		local box = BOXES[content_boxes[index][1]]
		if bx0 == nil then
			bx0, by0, bz0, bx1, by1, bz1 = box[1], box[2], box[3], box[4], box[5], box[6]
		else
			if box[1] < bx0 then bx0 = box[1] end
			if box[2] < by0 then by0 = box[2] end
			if box[3] < bz0 then bz0 = box[3] end
			if box[4] > bx1 then bx1 = box[4] end
			if box[5] > by1 then by1 = box[5] end
			if box[6] > bz1 then bz1 = box[6] end
		end
	end
	local param2_min, param2_max
	if #param2_boxes > 0 then
		local box = BOXES[param2_boxes[1][1]]
		param2_min = vec(box[1], box[2], box[3])
		param2_max = vec(box[4], box[5], box[6])
	end
	return {
		case = case_name,
		kx = kx,
		content_boxes = content_boxes,
		param2_boxes = param2_boxes,
		write_extent_content = write_extent_content,
		write_extent_param2 = write_extent_param2,
		param2_extent_min = param2_min,
		param2_extent_max = param2_max,
		-- The content extent's BOUNDING BOX is used for exactly one purpose:
		-- deriving light_write_box (10.10).  Every containment check and every
		-- dirty count uses the boxes themselves.
		bbox = {bx0, by0, bz0, bx1, by1, bz1},
		anchor = vec(math.floor((bx0 + bx1) / 2), math.floor((by0 + by1) / 2),
			math.floor((bz0 + bz1) / 2)),
	}
end

local CASES = {
	[608] = build_case("bounded", 8, {
		{"cut", "air"},
		{"fill", "default:stone"},
		{"water", "default:water_source"},
		{"facedir", "stairs:stair_cobble"},
	}, {
		{"facedir", PARAM2_VALUE},
	}, 2048, 512),
	[768] = build_case("4lo", 10, {
		{"4lo", "default:goldblock"},
	}, {}, 512, 0),
	[848] = build_case("4hi", 11, {
		{"4hi", "default:goldblock"},
	}, {}, 512, 0),
}

--
-- light_write_box = (content bounding box (+) 15, clipped at the emerged
-- boundary) intersected with the central slice minp..maxp (10.10).  Both clips
-- are written as formulas even where they do not bite for a given case: the
-- emerged clip never bites here, the central-slice clip is what bites for 4lo
-- and 4hi.
--
local function light_write_box(spec, minp, maxp, emin, emax)
	local bbox = spec.bbox
	local x0, y0, z0 = bbox[1] - LIGHT_RADIUS, bbox[2] - LIGHT_RADIUS, bbox[3] - LIGHT_RADIUS
	local x1, y1, z1 = bbox[4] + LIGHT_RADIUS, bbox[5] + LIGHT_RADIUS, bbox[6] + LIGHT_RADIUS
	if x0 < emin.x then x0 = emin.x end
	if y0 < emin.y then y0 = emin.y end
	if z0 < emin.z then z0 = emin.z end
	if x1 > emax.x then x1 = emax.x end
	if y1 > emax.y then y1 = emax.y end
	if z1 > emax.z then z1 = emax.z end
	if x0 < minp.x then x0 = minp.x end
	if y0 < minp.y then y0 = minp.y end
	if z0 < minp.z then z0 = minp.z end
	if x1 > maxp.x then x1 = maxp.x end
	if y1 > maxp.y then y1 = maxp.y end
	if z1 > maxp.z then z1 = maxp.z end
	return {x0, y0, z0, x1, y1, z1}
end

local function box_inside(box, minp, maxp)
	return box[1] >= minp.x and box[2] >= minp.y and box[3] >= minp.z and
		box[4] <= maxp.x and box[5] <= maxp.y and box[6] <= maxp.z
end

local function extents_contained(spec, minp, maxp)
	for index = 1, #spec.content_boxes do
		if not box_inside(BOXES[spec.content_boxes[index][1]], minp, maxp) then
			return false
		end
	end
	for index = 1, #spec.param2_boxes do
		if not box_inside(BOXES[spec.param2_boxes[index][1]], minp, maxp) then
			return false
		end
	end
	return true
end

--
-- STEP 6a -- restore.  Index/offset driven: it converts the light_write_box to
-- index-space offsets once and then never sees a world coordinate again.  This
-- traversal and the verification traversal below share no code, on purpose --
-- see the comment on verify_outside.
--
local function restore_outside(calc, snap, extent_x, extent_y, extent_z,
		off_x0, off_y0, off_z0, off_x1, off_y1, off_z1)
	for zi = 0, extent_z - 1 do
		local z_base = zi * extent_y * extent_x
		local z_in = (zi >= off_z0 and zi <= off_z1)
		for yi = 0, extent_y - 1 do
			local row_base = z_base + yi * extent_x
			if z_in and yi >= off_y0 and yi <= off_y1 then
				for xi = 0, off_x0 - 1 do
					local at = row_base + xi + 1
					calc[at] = snap[at]
				end
				for xi = off_x1 + 1, extent_x - 1 do
					local at = row_base + xi + 1
					calc[at] = snap[at]
				end
			else
				for xi = 0, extent_x - 1 do
					local at = row_base + xi + 1
					calc[at] = snap[at]
				end
			end
		end
	end
end

--
-- STEP 6b -- the independent verification (contract 12.6).  Built from scratch:
-- it walks WORLD coordinates over the emerged box in ascending z / y / x,
-- recomputes the flat index from the 12.6 formula with the EMERGED MinEdge and
-- extent (reference_projects/luanti/src/voxel.h:267-273), and decides
-- inside/outside by comparing (x, y, z) against the light_write_box LITERALS.
-- It never reads an index range, an offset table, a helper or any value the
-- restore loop produced.
--
-- That independence is the whole point: a verification that re-walked the
-- restore's own index set would be checked against itself -- the counter would
-- be 0 and the hashes would agree whatever the restore did, and abort A-16
-- could never fire.
--
-- Hashing is one z-slab at a time (at most 112 * 112 = 12,544 bytes per lane),
-- with the 112 slab digests rolled up through the labelled key=value
-- canonicalization, so peak Lua string size stays near 13 KB rather than
-- 1.3 MB.  The rollup text carries NO lane discriminator: the two hashes are
-- compared for equality, so their canonical texts must be identical whenever
-- their bytes are.
--
local function verify_outside(calc, snap, emin, emax, box)
	local lx0, ly0, lz0, lx1, ly1, lz1 = box[1], box[2], box[3], box[4], box[5], box[6]
	local extent_x = emax.x - emin.x + 1
	local extent_y = emax.y - emin.y + 1
	local mismatch = 0
	local snap_lines = {}
	local restored_lines = {}
	local line_count = 0
	local snap_bytes = {}
	local restored_bytes = {}
	for z = emin.z, emax.z do
		local packed = 0
		for y = emin.y, emax.y do
			for x = emin.x, emax.x do
				local inside = (x >= lx0 and x <= lx1 and y >= ly0 and y <= ly1 and
					z >= lz0 and z <= lz1)
				if not inside then
					local flat = (z - emin.z) * extent_y * extent_x +
						(y - emin.y) * extent_x + (x - emin.x)
					local snap_value = snap[flat + 1]
					local restored_value = calc[flat + 1]
					if snap_value ~= restored_value then
						mismatch = mismatch + 1
					end
					packed = packed + 1
					snap_bytes[packed] = CHR[snap_value]
					restored_bytes[packed] = CHR[restored_value]
				end
			end
		end
		line_count = line_count + 1
		local label = "z=" .. z .. "\n"
		snap_lines[line_count] = label .. "sha256=" ..
			core.sha256(table.concat(snap_bytes, "", 1, packed)) .. "\n"
		restored_lines[line_count] = label .. "sha256=" ..
			core.sha256(table.concat(restored_bytes, "", 1, packed)) .. "\n"
	end
	local header = LIGHT_ROLLUP_SCHEMA .. "\n" ..
		"emin=" .. emin.x .. "," .. emin.y .. "," .. emin.z .. "\n" ..
		"emax=" .. emax.x .. "," .. emax.y .. "," .. emax.z .. "\n" ..
		"box_min=" .. lx0 .. "," .. ly0 .. "," .. lz0 .. "\n" ..
		"box_max=" .. lx1 .. "," .. ly1 .. "," .. lz1 .. "\n"
	return mismatch,
		core.sha256(header .. table.concat(snap_lines)),
		core.sha256(header .. table.concat(restored_lines))
end

-- Payload-owned reuse buffers (l_vmanip.cpp:97, :264).  The emerged volume is
-- the same 112^3 for every measured chunk, so one set is reused across
-- callbacks; snapshot and calc are deliberately distinct tables.
local buffer_content
local buffer_param2
local buffer_snapshot
local buffer_calc

local function on_generated(raw_object, minp, maxp, blockseed)
	local proxy = vm_proxy.wrap(raw_object)
	local started_us = core.get_us_time()
	local spec = CASES[minp.x]
	if spec == nil then
		return
	end
	local lua_bytes_before = math.floor(collectgarbage("count") * 1024)

	local contained = extents_contained(spec, minp, maxp)

	local dirty_content_by_box = {}
	local dirty_param2_by_box = {}
	for index = 1, #spec.content_boxes do
		dirty_content_by_box[spec.content_boxes[index][1]] = 0
	end
	for index = 1, #spec.param2_boxes do
		dirty_param2_by_box[spec.param2_boxes[index][1]] = 0
	end

	local dirty_content = 0
	local dirty_param2 = 0
	local liquid_dirty = false
	local light_dirty = false
	local emin, emax
	local light_box
	local light_voxels = 0
	local mismatch_count = 0
	local snapshot_sha256 = ""
	local restored_sha256 = ""
	local restore_failed = false

	if is_treatment and contained and registered_nodes_available then
		-- STEP 1 -- the emerged geometry and the pre-write buffers.
		emin, emax = proxy:get_emerged_area()
		local extent_x = emax.x - emin.x + 1
		local extent_y = emax.y - emin.y + 1
		local extent_z = emax.z - emin.z + 1
		buffer_content = proxy:get_data(buffer_content)
		if #spec.param2_boxes > 0 then
			buffer_param2 = proxy:get_param2_data(buffer_param2)
		end

		-- STEP 2 -- the realized dirty sets, the four predicates and the case's
		-- native baseline, all from the pre-write buffers.  The anchor column
		-- is scanned first because it crosses a write box.
		local anchor = spec.anchor
		local native_surface_y
		do
			local column_base = (anchor.z - emin.z) * extent_y * extent_x +
				(anchor.x - emin.x)
			for y = maxp.y, minp.y, -1 do
				local value = buffer_content[column_base + (y - emin.y) * extent_x + 1]
				if value ~= AIR_ID then
					native_surface_y = y
					break
				end
			end
		end

		local native_content_at_extent = {}
		local native_air_count = 0
		local native_liquid_count = 0

		for index = 1, #spec.content_boxes do
			local entry = spec.content_boxes[index]
			local box = BOXES[entry[1]]
			local target = content_ids[entry[2]]
			local target_liquid = is_liquid[target]
			local target_light = light_of(target)
			local changed = 0
			for z = box[3], box[6] do
				local z_base = (z - emin.z) * extent_y * extent_x
				for y = box[2], box[5] do
					local row_base = z_base + (y - emin.y) * extent_x
					for x = box[1], box[4] do
						local at = row_base + (x - emin.x) + 1
						local old = buffer_content[at]
						local old_name = id_names[old] or ("content_id:" .. old)
						native_content_at_extent[old_name] =
							(native_content_at_extent[old_name] or 0) + 1
						if old == AIR_ID then
							native_air_count = native_air_count + 1
						end
						if is_liquid[old] then
							native_liquid_count = native_liquid_count + 1
						end
						if old ~= target then
							changed = changed + 1
							if is_liquid[old] or target_liquid then
								liquid_dirty = true
							end
							if light_of(old) ~= target_light then
								light_dirty = true
							end
							buffer_content[at] = target
						end
					end
				end
			end
			dirty_content_by_box[entry[1]] = changed
			dirty_content = dirty_content + changed
		end

		for index = 1, #spec.param2_boxes do
			local entry = spec.param2_boxes[index]
			local box = BOXES[entry[1]]
			local target = entry[2]
			local changed = 0
			for z = box[3], box[6] do
				local z_base = (z - emin.z) * extent_y * extent_x
				for y = box[2], box[5] do
					local row_base = z_base + (y - emin.y) * extent_x
					for x = box[1], box[4] do
						local at = row_base + (x - emin.x) + 1
						if buffer_param2[at] ~= target then
							changed = changed + 1
							buffer_param2[at] = target
						end
					end
				end
			end
			dirty_param2_by_box[entry[1]] = changed
			dirty_param2 = dirty_param2 + changed
		end

		emit("case_baseline", {
			case = spec.case,
			anchor_column = vec(anchor.x, anchor.y, anchor.z),
			native_surface_y = native_surface_y or json_null(),
			native_content_at_extent = native_content_at_extent,
			native_air_count = native_air_count,
			native_liquid_count = native_liquid_count,
		})

		-- STEP 3 -- the pre-commit param1 snapshot over the full emerged VM.
		if light_dirty then
			buffer_snapshot = proxy:get_light_data(buffer_snapshot)
		end

		-- STEP 4 -- two separately gated uploads, never conflated.
		if dirty_content > 0 then
			proxy:set_data(buffer_content)
		end
		if dirty_param2 > 0 then
			proxy:set_param2_data(buffer_param2)
		end

		-- STEP 5 -- the bounded light sequence.
		if light_dirty then
			light_box = light_write_box(spec, minp, maxp, emin, emax)
			light_voxels = (light_box[4] - light_box[1] + 1) *
				(light_box[5] - light_box[2] + 1) *
				(light_box[6] - light_box[3] + 1)
			proxy:set_lighting({day = 0, night = 0},
				vec(light_box[1], light_box[2], light_box[3]),
				vec(light_box[4], light_box[5], light_box[6]))
			proxy:calc_lighting(vec(emin.x, minp.y, emin.z),
				vec(emax.x, maxp.y, emax.z), true)
			buffer_calc = proxy:get_light_data(buffer_calc)

			-- STEP 6 -- restore, then verify independently.
			restore_outside(buffer_calc, buffer_snapshot,
				extent_x, extent_y, extent_z,
				light_box[1] - emin.x, light_box[2] - emin.y, light_box[3] - emin.z,
				light_box[4] - emin.x, light_box[5] - emin.y, light_box[6] - emin.z)
			mismatch_count, snapshot_sha256, restored_sha256 =
				verify_outside(buffer_calc, buffer_snapshot, emin, emax, light_box)
			restore_failed = (mismatch_count ~= 0) or
				(snapshot_sha256 ~= restored_sha256)

			-- STEP 7 -- the bounded upload, and the liquid rescan.  Both are
			-- skipped when the verification failed: A-16 is raised BEFORE
			-- set_light_data, so no unverified param1 ever reaches the map.
			if not restore_failed then
				proxy:set_light_data(buffer_calc)
			end
		end
		if liquid_dirty and not restore_failed then
			proxy:update_liquids()
		end
	end

	local chunk_key = CHUNK_KEY_PREFIX .. spec.kx
	local ipc_started = core.get_us_time()
	core.ipc_set(chunk_key, {
		arm = arm,
		order = order,
		case = spec.case,
		kx = spec.kx,
		dirty_content = dirty_content,
		dirty_param2 = dirty_param2,
		dirty_light = light_dirty,
		dirty_liquid = liquid_dirty,
		light_restore_failed = restore_failed,
		extents_contained = contained,
		-- The chunk_callback below will be this state's record number
		-- mapgen_seq + 1; the driver reads the maximum over the three chunk
		-- keys to report an exact records_emitted across both partitions.
		mapgen_records = mapgen_seq + 1,
	})
	local ipc_set_us = core.get_us_time() - ipc_started

	local light_box_min, light_box_max = json_null(), json_null()
	if light_dirty and light_box ~= nil then
		light_box_min = vec(light_box[1], light_box[2], light_box[3])
		light_box_max = vec(light_box[4], light_box[5], light_box[6])
	end

	emit("chunk_callback", {
		case = spec.case,
		kx = spec.kx,
		minp = vec(minp.x, minp.y, minp.z),
		maxp = vec(maxp.x, maxp.y, maxp.z),
		emin = emin and vec(emin.x, emin.y, emin.z) or json_null(),
		emax = emax and vec(emax.x, emax.y, emax.z) or json_null(),
		blockseed = blockseed,
		ops = proxy.ops,
		op_us = proxy.op_us,
		callback_us = core.get_us_time() - started_us,
		write_extent_content = spec.write_extent_content,
		write_extent_param2 = spec.write_extent_param2,
		param2_extent_min = spec.param2_extent_min and
			vec(spec.param2_extent_min.x, spec.param2_extent_min.y,
				spec.param2_extent_min.z) or json_null(),
		param2_extent_max = spec.param2_extent_max and
			vec(spec.param2_extent_max.x, spec.param2_extent_max.y,
				spec.param2_extent_max.z) or json_null(),
		dirty_content = dirty_content,
		dirty_param2 = dirty_param2,
		dirty_content_by_box = dirty_content_by_box,
		dirty_param2_by_box = dirty_param2_by_box,
		dirty_liquid = liquid_dirty,
		dirty_light = light_dirty,
		light_write_box_min = light_box_min,
		light_write_box_max = light_box_max,
		light_write_voxels = light_voxels,
		restored_outside_dirty_mismatch_count = mismatch_count,
		light_outside_box_snapshot_sha256 = snapshot_sha256,
		light_outside_box_restored_sha256 = restored_sha256,
		lua_bytes_before = lua_bytes_before,
		lua_bytes_after = math.floor(collectgarbage("count") * 1024),
		ipc_set_us = ipc_set_us,
		ipc_set_key = chunk_key,
		production_adopted = false,
	})
end

core.register_on_generated(on_generated)
local callback_index = #core.registered_on_generateds

--
-- Load-time telemetry (contract 12.3, seams S4b-i, S4c, S4d, S9, S11).  The
-- three prohibitions are recorded as the distinct things they are and are NOT
-- collapsed into one another:
--
--   S4b-i   the engine's callback-scoped VoxelManip global is ABSENT outside a
--           callback -- telemetry only, and this file never reads it.
--   S4b-ii  the mapgen-object route is a null dereference, not a clean error --
--           source-settled, so it is never called here at all.
--   S4b-iii update_liquids at load time is NOT EXPRESSIBLE: it is an object
--           method, so with no VoxelManip there is nothing to call it on.  An
--           unreachable state, not a guarded one.
--   S4c     VoxelManip() RETURNS NO VALUES.  GET_ENV_PTR expands to
--           GET_ENV_PTR_NO_MAP_LOCK, which logs a deprecation line and does
--           `return 0` on a null env
--           (reference_projects/luanti/src/script/lua_api/l_internal.h:44-51).
--           What is recorded is the NUMBER OF VALUES RETURNED, never the value
--           of a first result: `tally` below counts with select("#", ...) and
--           reports -1 for a raise, so "returned zero values" and "raised" stay
--           distinguishable.
--
local vmanip_constructor = rawget(_G, "VoxelManip")
local vmanip_ctor_type = type(vmanip_constructor)

local function tally(ok, ...)
	if not ok then
		return -1
	end
	return select("#", ...)
end

local vmanip_ctor_return_count = tally(pcall(vmanip_constructor))

local function has_function(name)
	return type(core[name]) == "function"
end

local edges_min, edges_max = core.get_mapgen_edges()

local state_value = {
	arm = arm,
	order = order,
	callback_index = callback_index,
	seed = core.get_mapgen_setting("seed"),
	chunksize = tonumber(core.get_mapgen_setting("chunksize")) or -1,
	registered_nodes_available = registered_nodes_available,
	vmanip_ctor_type = vmanip_ctor_type,
	vmanip_ctor_return_count = vmanip_ctor_return_count,
}

local ipc_set_started = core.get_us_time()
core.ipc_set(STATE_KEY, state_value)
local ipc_set_us = core.get_us_time() - ipc_set_started

emit("mapgen_state_init", {
	load_us = core.get_us_time() - load_started_us,
	ipc_get_us = ipc_get_us,
	ipc_set_us = ipc_set_us,
	ipc_get_ok = ipc_get_ok,
	ipc_set_key = STATE_KEY,
	seed = core.get_mapgen_setting("seed"),
	chunksize = tonumber(core.get_mapgen_setting("chunksize")) or -1,
	mapgen_edges_min = vec(edges_min.x, edges_min.y, edges_min.z),
	mapgen_edges_max = vec(edges_max.x, edges_max.y, edges_max.z),
	callback_index = callback_index,
	vmanip_ctor_type = vmanip_ctor_type,
	vmanip_ctor_return_count = vmanip_ctor_return_count,
	has_request_insecure_environment = has_function("request_insecure_environment"),
	has_get_gametime = has_function("get_gametime"),
	has_get_timeofday = has_function("get_timeofday"),
	has_get_server_uptime = has_function("get_server_uptime"),
	registered_nodes_available = registered_nodes_available,
	lua_bytes = math.floor(collectgarbage("count") * 1024),
})
