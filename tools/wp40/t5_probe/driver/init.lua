-- Disposable WP40 T5-0 probe driver, never shipped: it carries the documented
-- core.request_insecure_environment() exception (AGENTS.md:170-171) for 12.4.
--
-- docs/research/luanti-lua.md:234 says "We never use it."  The exception is
-- declared here and in driver/mod.conf, is scoped to one best-effort
-- /proc/self/status read on the main state, and is FAIL-SOFT: if the insecure
-- environment is unavailable, the file unreadable, or a field absent, the
-- process_metrics record carries the literal string "unavailable" with a
-- non-empty reason and the run continues (contract 12.4).  It does NOT
-- hard-error the way tools/wp40/runtime_probe/init.lua:6-10 does, and no field
-- can vanish the way that probe's kibibytes() helper lets one vanish at :39-42.
--
-- Main-state driver (contract 8.1): arm switch, IPC publish and readback,
-- emerge scheduling, main-env on_generated telemetry, the two-pass bounded
-- readback and its lane digests, the two in-run deadlines, and shutdown.
--
-- STATED EXEMPTION, contract 10.12: this file legitimately uses a RAW main-state
-- VoxelManip (core.get_voxel_manip() plus read_from_map, legal outside the
-- emerge environment -- reference_projects/luanti/src/script/lua_api/
-- l_vmanip.cpp:44-45 forbids read_from_map only in the mapgen environment).  It
-- is outside the payload sweep's path scope because it is not the payload,
-- makes no mapgen-VM call, and runs after every chunk has been generated.

local MOD_NAME = "grug_wp40_t5_probe"
local SCHEMA = "grug_wp40_t5_probe_synthetic_v0"
local MARKER = "WP40_T5_PROBE_JSON "
local CONFIG_KEY = MOD_NAME .. ":config"
local STATE_KEY = MOD_NAME .. ":mapgen_state"
local CHUNK_KEY_PREFIX = MOD_NAME .. ":chunk:"

local EMERGE_DEADLINE_US = 45000000
local RUN_DEADLINE_US = 60000000
local INTERPASS_WAIT_S = 2.5
local CORE_VOXELS = 110592

local modpath = core.get_modpath(core.get_current_modname())

-- Must run in the mod's main scope at init time (doc/lua_api.md:8292-8300).
local insecure = core.request_insecure_environment()

local arm = core.settings:get(MOD_NAME .. ".arm")
local order = core.settings:get(MOD_NAME .. ".order")
if arm ~= "A1" and arm ~= "B" then
	error(MOD_NAME .. ": " .. MOD_NAME .. ".arm must be A1 or B, got " ..
		tostring(arm))
end
if order ~= "O1" and order ~= "O2" then
	error(MOD_NAME .. ": " .. MOD_NAME .. ".order must be O1 or O2, got " ..
		tostring(order))
end
local run_id = arm .. "-" .. order

-- Published before the emerge threads start, which is what lets the payload
-- read it at mapgen-script load time (the production pattern of
-- mods/MAPGEN/grug_mapgen/ocean_mask.lua:46).
core.ipc_set(CONFIG_KEY, {arm = arm, order = order})
core.register_mapgen_script(modpath .. "/mapgen.lua")

--
-- Coordinate literals (contract 10.3, 10.10, 12.3).  The driver uses LITERALS
-- where the payload uses formulas; the two agreeing is itself a cross-check,
-- because chunk_callback.light_write_box_min/_max come from the payload's clip
-- formulas and digest_excl.excluded_boxes comes from the table below.
--
local CHUNKS = {
	[8] = {
		minp = {x = 608, y = -32, z = 688},
		maxp = {x = 687, y = 47, z = 767},
		pos = {x = 648, y = 8, z = 728},
	},
	[10] = {
		minp = {x = 768, y = -32, z = 688},
		maxp = {x = 847, y = 47, z = 767},
		pos = {x = 808, y = 8, z = 728},
	},
	[11] = {
		minp = {x = 848, y = -32, z = 688},
		maxp = {x = 927, y = 47, z = 767},
		pos = {x = 888, y = 8, z = 728},
	},
}

local CORE_BOX = {
	[8] = {624, -16, 704, 671, 31, 751},
	[10] = {784, -16, 704, 831, 31, 751},
	[11] = {864, -16, 704, 911, 31, 751},
}
local SEAM_BOX = {824, -16, 696, 871, 23, 735}

local BOXES = {
	cut = {628, 0, 712, 635, 7, 719},
	fill = {628, -8, 712, 635, -1, 719},
	water = {644, 0, 712, 651, 7, 719},
	facedir = {660, 0, 712, 667, 7, 719},
	["4lo"] = {840, 0, 712, 847, 7, 719},
	["4hi"] = {848, 0, 712, 855, 7, 719},
}

local WRITE_EXTENT_BOXES = {
	[8] = {"cut", "fill", "water", "facedir"},
	[10] = {"4lo"},
	[11] = {"4hi"},
}

local LIGHT_WRITE_BOX = {
	[8] = {613, -23, 697, 682, 22, 734},
	[10] = {825, -15, 697, 847, 22, 734},
	[11] = {848, -15, 697, 870, 22, 734},
}

local ORDERS = {O1 = {8, 10, 11}, O2 = {11, 10, 8}}
local schedule = ORDERS[order]

local LANES = {"content", "param2", "light_day", "light_night"}
local EXCLUDED_KIND = {
	content = "write_extent",
	param2 = "write_extent",
	light_day = "light_write_box",
	light_night = "light_write_box",
}

local ACTION_NAMES = {
	[core.EMERGE_GENERATED] = "generated",
	[core.EMERGE_FROM_MEMORY] = "memory",
	[core.EMERGE_FROM_DISK] = "disk",
	[core.EMERGE_CANCELLED] = "cancelled",
	[core.EMERGE_ERRORED] = "errored",
}

local function box_min(box)
	return {x = box[1], y = box[2], z = box[3]}
end

local function box_max(box)
	return {x = box[4], y = box[5], z = box[6]}
end

--
-- Emission (contract 12.1, 12.2).
--
local main_seq = 0
local t0 = 0

local function emit(tag, fields)
	main_seq = main_seq + 1
	fields.schema = SCHEMA
	fields.tag = tag
	fields.arm = arm
	fields.order = order
	fields.run_id = run_id
	fields.state = "main"
	fields.seq = main_seq
	core.log("action", MARKER .. core.write_json(fields))
end

--
-- Canonical byte packing (contract 12.6).  Lookup tables, never `s = s .. c`;
-- every lane string is built with a table plus table.concat.
--
local CHR = {}
local DAY_CHR = {}
local NIGHT_CHR = {}
for value = 0, 255 do
	CHR[value] = string.char(value)
	DAY_CHR[value] = string.char(value % 16)
	NIGHT_CHR[value] = string.char(math.floor(value / 16))
end

-- content is two bytes, big-endian.  Memoized per content id: a compared region
-- holds tens of distinct ids, so this collapses to one table lookup per node.
local content_pair_cache = {}
local function content_pair(id)
	local packed = content_pair_cache[id]
	if packed == nil then
		packed = CHR[math.floor(id / 256)] .. CHR[id % 256]
		content_pair_cache[id] = packed
	end
	return packed
end

-- CONTENT_IGNORE is 127 in reference_projects/luanti/src/content_mapnode.h; the
-- lookup is the authority and the constant is only the fallback.
local ignore_ok, ignore_id = pcall(core.get_content_id, "ignore")
local IGNORE_ID = (ignore_ok and ignore_id) or 127

--
-- One traversal per (compared region, exclusion set) producing every lane the
-- caller asked for.  Ascending flat index over the compared box in the engine's
-- own VoxelArea order -- x fastest, then y, then z slowest -- with MinEdge and
-- extent taken from the values read_from_map RETURNED, never from the requested
-- box (reference_projects/luanti/src/voxel.h:267-273,
-- reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:35-45).
--
-- A region that is a box LIST is serialized by traversing the region in the
-- same ascending order and SKIPPING every index inside the union -- never by
-- traversing the boxes.  The per-row active-box hoisting below is exactly that
-- union test, evaluated once per row instead of once per voxel.
--
local function pack_lanes(read, box, excluded, want_content, want_light)
	local emin = read.emin
	local extent_x = read.emax.x - emin.x + 1
	local extent_y = read.emax.y - emin.y + 1
	local content, param2, light = read.content, read.param2, read.light
	local out_content, out_param2, out_day, out_night = {}, {}, {}, {}
	local kept = 0
	local skipped = 0
	local ignore_count = 0
	local box_count = excluded and #excluded or 0
	local z_active = {}
	local row_x0, row_x1 = {}, {}
	for z = box[3], box[6] do
		local z_base = (z - emin.z) * extent_y * extent_x
		local z_count = 0
		for index = 1, box_count do
			local other = excluded[index]
			if z >= other[3] and z <= other[6] then
				z_count = z_count + 1
				z_active[z_count] = other
			end
		end
		for y = box[2], box[5] do
			local row_base = z_base + (y - emin.y) * extent_x
			local row_count = 0
			for index = 1, z_count do
				local other = z_active[index]
				if y >= other[2] and y <= other[5] then
					row_count = row_count + 1
					row_x0[row_count] = other[1]
					row_x1[row_count] = other[4]
				end
			end
			for x = box[1], box[4] do
				local skip = false
				for index = 1, row_count do
					if x >= row_x0[index] and x <= row_x1[index] then
						skip = true
						break
					end
				end
				if skip then
					skipped = skipped + 1
				else
					local at = row_base + (x - emin.x) + 1
					kept = kept + 1
					if want_content then
						local id = content[at]
						out_content[kept] = content_pair(id)
						if id == IGNORE_ID then
							ignore_count = ignore_count + 1
						end
						out_param2[kept] = CHR[param2[at]]
					else
						local id = content[at]
						if id == IGNORE_ID then
							ignore_count = ignore_count + 1
						end
					end
					if want_light then
						local value = light[at]
						out_day[kept] = DAY_CHR[value]
						out_night[kept] = NIGHT_CHR[value]
					end
				end
			end
		end
	end
	return {
		node_count = kept,
		excluded_voxels = skipped,
		content_ignore_count = ignore_count,
		content = want_content and core.sha256(table.concat(out_content, "", 1, kept)) or nil,
		param2 = want_content and core.sha256(table.concat(out_param2, "", 1, kept)) or nil,
		light_day = want_light and core.sha256(table.concat(out_day, "", 1, kept)) or nil,
		light_night = want_light and core.sha256(table.concat(out_night, "", 1, kept)) or nil,
	}
end

local function read_box(box)
	local started = core.get_us_time()
	local manip = core.get_voxel_manip()
	local emin, emax = manip:read_from_map(box_min(box), box_max(box))
	local read = {
		emin = emin,
		emax = emax,
		content = manip:get_data(),
		param2 = manip:get_param2_data(),
		light = manip:get_light_data(),
	}
	read.readback_us = core.get_us_time() - started
	return read
end

--
-- Quiescence (contract 10.15, V-09): pass 1's digests are kept and pass 2's are
-- compared against them.  No literal pipe anywhere -- string.char(124) is the
-- rule and the separator here simply avoids needing one.
--
local pass1_digests = {}
local quiescent = true

local function track(key, sha, pass)
	if pass == 1 then
		pass1_digests[key] = sha
	elseif pass1_digests[key] ~= sha then
		quiescent = false
	end
end

--
-- Deadlines, abort and termination (contract 14.2, 15).
--
local aborted = false
local chunks_generated = 0
local mapgen_records = 0
local emerge_phase_us = 0
local interpass_wait_s = 0
local passes_done = 0
local liquid_update_s = tonumber(core.settings:get("liquid_update"))

local function process_metrics_fields()
	local fields = {
		available = false,
		rss_bytes = "unavailable",
		rss_peak_bytes = "unavailable",
		virtual_bytes = "unavailable",
		cpu_seconds = "unavailable",
		lua_bytes_main = math.floor(collectgarbage("count") * 1024),
		reason = "",
	}
	if not insecure then
		fields.reason = "core.request_insecure_environment() returned nil"
		return fields
	end
	local ok, status = pcall(function()
		local handle = insecure.io.open("/proc/self/status", "rb")
		if not handle then
			return nil
		end
		local body = handle:read("*a")
		handle:close()
		return body
	end)
	if not ok or type(status) ~= "string" then
		fields.reason = "/proc/self/status could not be read"
		return fields
	end
	local clock_ok, seconds = pcall(function()
		return insecure.os.clock()
	end)
	if clock_ok and type(seconds) == "number" then
		fields.cpu_seconds = seconds
	end
	local missing = {}
	local function kibibytes(field)
		local value = status:match("\n" .. field .. ":[ \t]+(%d+)[ \t]+kB")
		local number = value and tonumber(value)
		if not number then
			missing[#missing + 1] = field
			return "unavailable"
		end
		return math.floor(number) * 1024
	end
	fields.rss_bytes = kibibytes("VmRSS")
	fields.rss_peak_bytes = kibibytes("VmHWM")
	fields.virtual_bytes = kibibytes("VmSize")
	if #missing == 0 and fields.cpu_seconds ~= "unavailable" then
		fields.available = true
	else
		local parts = {}
		if #missing > 0 then
			parts[#parts + 1] = "missing fields: " .. table.concat(missing, ",")
		end
		if fields.cpu_seconds == "unavailable" then
			parts[#parts + 1] = "os.clock() unavailable"
		end
		fields.reason = table.concat(parts, "; ")
	end
	return fields
end

local function finish(ok)
	local total_us = core.get_us_time() - t0
	local emerge_met = emerge_phase_us > 0 and emerge_phase_us <= EMERGE_DEADLINE_US
	local run_met = total_us <= RUN_DEADLINE_US
	if ok and not run_met and not aborted then
		aborted = true
		emit("abort", {
			code = "A-09",
			reason = "run deadline exceeded",
			detail = "total_us " .. total_us .. " exceeds run_deadline_us " ..
				RUN_DEADLINE_US,
		})
	end
	emit("process_metrics", process_metrics_fields())
	emit("settling", {
		liquid_update_s = liquid_update_s or -1,
		periodic_drain_suppressed = (liquid_update_s ~= nil) and
			(liquid_update_s > (core.get_us_time() - t0) / 1000000),
		interpass_wait_s = interpass_wait_s,
		quiescent = quiescent and passes_done == 2,
		settling_is_probe_local = true,
	})
	local total = core.get_us_time() - t0
	emit("complete", {
		ok = ok and not aborted and run_met and emerge_met and
			chunks_generated == 3 and quiescent and passes_done == 2,
		chunks_generated = chunks_generated,
		records_emitted = main_seq + 1 + mapgen_records,
		total_us = total,
		emerge_deadline_us = EMERGE_DEADLINE_US,
		run_deadline_us = RUN_DEADLINE_US,
		emerge_deadline_met = emerge_met,
		run_deadline_met = total <= RUN_DEADLINE_US,
	})
	core.request_shutdown("WP40 t5-probe " .. run_id .. " complete", false, 0.1)
end

local function abort(code, reason, detail)
	if aborted then
		return
	end
	aborted = true
	emit("abort", {code = code, reason = reason, detail = detail})
	finish(false)
end

--
-- The manifest (contract 12.3, 13.2).  Every digest below is a labelled
-- key=value text with a versioned schema first line, hashed once with
-- core.sha256; no digest is ever taken over probe JSON as emitted.
--
local function canonical_number(value)
	return string.format("%.6g", tonumber(value) or 0)
end

local function noiseparams_sha256()
	local names = {
		"mg_biome_np_heat",
		"mg_biome_np_heat_blend",
		"mg_biome_np_humidity",
		"mg_biome_np_humidity_blend",
		"mgv7_np_terrain_alt",
		"mgv7_np_terrain_base",
	}
	table.sort(names)
	local parts = {"schema=wp40-t5-probe-noiseparams-v1\n"}
	for index = 1, #names do
		local name = names[index]
		local noise = core.get_mapgen_setting_noiseparams(name)
		parts[#parts + 1] = "noise=" .. name .. "\n"
		if type(noise) == "table" then
			local spread = noise.spread or {}
			parts[#parts + 1] = "value=" .. table.concat({
				canonical_number(noise.offset),
				canonical_number(noise.scale),
				canonical_number(spread.x),
				canonical_number(spread.y),
				canonical_number(spread.z),
				canonical_number(noise.seed),
				canonical_number(noise.octaves),
				canonical_number(noise.persistence or noise.persist),
				canonical_number(noise.lacunarity),
				noise.flags or "",
			}, ",") .. "\n"
		else
			parts[#parts + 1] = "value=unavailable\n"
		end
	end
	return core.sha256(table.concat(parts))
end

-- Contract 10.4: an explicit table.sort over collected names, never a pairs()
-- walk, and the id is bound as well as the name -- a name-only digest satisfies
-- X-01 while leaving a permuted id assignment undetected.
local function content_id_table_sha256()
	local names = {}
	local count = 0
	for name in pairs(core.registered_nodes) do
		count = count + 1
		names[count] = name
	end
	table.sort(names)
	local parts = {"schema=wp40-t5-probe-content-id-table-v1\n"}
	for index = 1, count do
		local name = names[index]
		local ok, id = pcall(core.get_content_id, name)
		parts[#parts + 1] = "name=" .. name .. "\n"
		parts[#parts + 1] = "id=" .. tostring((ok and id) or -1) .. "\n"
	end
	return core.sha256(table.concat(parts)), count
end

local function mod_list_sha256()
	local names = core.get_modnames() or {}
	table.sort(names)
	local parts = {"schema=wp40-t5-probe-mod-list-v1\n"}
	for index = 1, #names do
		parts[#parts + 1] = "mod=" .. names[index] .. "\n"
	end
	return core.sha256(table.concat(parts))
end

-- Reproduces tools/wp40/t5_probe/digest_lib.sh's canonical text byte for byte,
-- so the in-band value and the shell's injection proof are the same digest.
local function payload_sha256()
	local names = {"mod.conf", "init.lua", "mapgen.lua", "vm_proxy.lua"}
	local parts = {"schema=wp40-t5-probe-payload-v1\n"}
	for index = 1, #names do
		local handle = assert(io.open(modpath .. "/" .. names[index], "rb"),
			"cannot read injected file " .. names[index])
		local body = assert(handle:read("*a"))
		handle:close()
		parts[#parts + 1] = "file_name=" .. names[index] .. "\n"
		parts[#parts + 1] = "file_content_sha256=" .. core.sha256(body) .. "\n"
	end
	return core.sha256(table.concat(parts))
end

-- Contract 5, read back in band.  The three PER-RUN keys of 10.2 -- port, and
-- the two probe switches -- are deliberately absent: X-02 requires this object
-- to be identical across all four runs, and the arm and order are already
-- carried by the common fields and by arm_switch_value.
local MAPGEN_SETTING_NAMES = {
	"chunksize",
	"fixed_map_seed",
	"liquid_loop_max",
	"liquid_queue_purge_time",
	"liquid_update",
	"mapgen_limit",
	"mg_flags",
	"mg_name",
	"mgv7_cave_width",
	"mgv7_cavern_limit",
	"mgv7_dungeon_ymax",
	"mgv7_dungeon_ymin",
	"mgv7_large_cave_depth",
	"mgv7_spflags",
	"num_emerge_threads",
	"secure.trusted_mods",
	"seed",
	"water_level",
}

local function mapgen_settings()
	local out = {}
	for index = 1, #MAPGEN_SETTING_NAMES do
		local name = MAPGEN_SETTING_NAMES[index]
		local value = core.get_mapgen_setting(name)
		if value == nil then
			value = core.settings:get(name)
		end
		if value == nil then
			out[name] = "unavailable"
		else
			out[name] = tostring(value)
		end
	end
	return out
end

local function emit_manifest()
	local version = core.get_version()
	local game_id = "unavailable"
	local ok, info = pcall(core.get_game_info)
	if ok and type(info) == "table" and type(info.id) == "string" then
		game_id = info.id
	end
	local table_sha, table_count = content_id_table_sha256()
	local jit_table = rawget(_G, "jit")
	emit("manifest", {
		engine_string = version.string,
		engine_hash = version.hash or "unavailable",
		engine_is_dev = version.is_dev == true,
		lua_runtime = (jit_table and jit_table.version) or "bundled Lua 5.1",
		game_id = game_id,
		seed = tostring(core.get_mapgen_setting("seed")),
		mapgen_settings = mapgen_settings(),
		mapgen_noiseparams_sha256 = noiseparams_sha256(),
		content_id_table_sha256 = table_sha,
		content_id_count = table_count,
		mod_list_sha256 = mod_list_sha256(),
		payload_digest = payload_sha256(),
		arm_switch_value = arm,
		emerge_order = {schedule[1], schedule[2], schedule[3]},
		t0_us = t0,
	})
end

--
-- IPC readback (contract 12.4, seam S3b).  There is no push and no key
-- enumeration (reference_projects/luanti/src/script/lua_api/l_ipc.cpp:128-133),
-- so the main state polls the four keys it knows the mapgen state writes.
--
local canonical_value
canonical_value = function(value)
	local kind = type(value)
	if kind == "nil" then
		return "nil"
	elseif kind == "boolean" then
		return value and "true" or "false"
	elseif kind == "number" then
		return string.format("%.14g", value)
	elseif kind == "string" then
		return string.format("%q", value)
	elseif kind == "table" then
		local names = {}
		local count = 0
		for name in pairs(value) do
			count = count + 1
			names[count] = tostring(name)
		end
		table.sort(names)
		local parts = {}
		for index = 1, count do
			local name = names[index]
			local item = value[name]
			if item == nil then
				item = value[tonumber(name)]
			end
			parts[index] = name .. "=" .. canonical_value(item)
		end
		return "{" .. table.concat(parts, ";") .. "}"
	end
	return "unsupported:" .. kind
end

local function emit_ipc_readback()
	local keys = {STATE_KEY}
	for index = 1, #schedule do
		keys[#keys + 1] = CHUNK_KEY_PREFIX .. schedule[index]
	end
	table.sort(keys)
	local started = core.get_us_time()
	local poll_used = false
	local found = 0
	local parts = {"schema=wp40-t5-probe-ipc-values-v1\n"}
	for index = 1, #keys do
		local key = keys[index]
		local value = core.ipc_get(key)
		if value == nil then
			poll_used = true
			core.ipc_poll(key, 1000)
			value = core.ipc_get(key)
		end
		if value ~= nil then
			found = found + 1
		end
		if type(value) == "table" and type(value.mapgen_records) == "number" and
				value.mapgen_records > mapgen_records then
			mapgen_records = value.mapgen_records
		end
		parts[#parts + 1] = "key=" .. key .. "\n"
		parts[#parts + 1] = "value=" .. canonical_value(value) .. "\n"
	end
	emit("ipc_readback", {
		keys_expected = 4,
		keys_found = found,
		keys = keys,
		poll_used = poll_used,
		total_us = core.get_us_time() - started,
		values_sha256 = core.sha256(table.concat(parts)),
	})
end

--
-- The two-pass readback (contract 12.3, 12.6, 10.15).  Both arms emit all 32
-- digest, 24 digest_excl and 24 digest_incl records over identical regions:
-- V-01 and V-02 compare B against A1 over an excluded region, and digests
-- cannot be subtracted, so an arm-B-only emission would make the
-- out-of-extent-write detector unrunnable.
--
local function emit_digests_for_region(pass, region, kx, box, read)
	local full = pack_lanes(read, box, nil, true, true)
	for index = 1, #LANES do
		local lane = LANES[index]
		local sha = full[lane]
		track("digest/" .. region .. "/" .. kx .. "/" .. lane, sha, pass)
		emit("digest", {
			pass = pass,
			region = region,
			kx = kx,
			lane = lane,
			node_count = full.node_count,
			sha256 = sha,
			box_min = box_min(box),
			box_max = box_max(box),
			content_ignore_count = full.content_ignore_count,
			readback_us = read.readback_us,
		})
	end
end

local function emit_excl_for_chunk(pass, kx, box, read)
	local write_boxes = {}
	local names = WRITE_EXTENT_BOXES[kx]
	for index = 1, #names do
		write_boxes[index] = BOXES[names[index]]
	end
	local light_boxes = {LIGHT_WRITE_BOX[kx]}
	local sets = {
		{kind = "write_extent", boxes = write_boxes, want_content = true},
		{kind = "light_write_box", boxes = light_boxes, want_content = false},
	}
	for set_index = 1, #sets do
		local set = sets[set_index]
		local packed = pack_lanes(read, box, set.boxes, set.want_content,
			not set.want_content)
		local listed = {}
		for index = 1, #set.boxes do
			listed[index] = {
				min = box_min(set.boxes[index]),
				max = box_max(set.boxes[index]),
			}
		end
		for index = 1, #LANES do
			local lane = LANES[index]
			if EXCLUDED_KIND[lane] == set.kind then
				local sha = packed[lane]
				track("excl/" .. kx .. "/" .. set.kind .. "/" .. lane, sha, pass)
				emit("digest_excl", {
					pass = pass,
					region = "core",
					kx = kx,
					lane = lane,
					node_count = packed.node_count,
					sha256 = sha,
					box_min = box_min(box),
					box_max = box_max(box),
					content_ignore_count = packed.content_ignore_count,
					readback_us = read.readback_us,
					excluded_kind = set.kind,
					excluded_boxes = listed,
					excluded_voxels = packed.excluded_voxels,
				})
			end
		end
	end
end

local function emit_incl_for_boxes(pass, region, kx, region_box, names, read)
	for name_index = 1, #names do
		local name = names[name_index]
		local box = BOXES[name]
		local packed = pack_lanes(read, box, nil, true, false)
		for lane_index = 1, 2 do
			local lane = LANES[lane_index]
			local sha = packed[lane]
			track("incl/" .. name .. "/" .. lane, sha, pass)
			emit("digest_incl", {
				pass = pass,
				region = region,
				kx = kx,
				lane = lane,
				node_count = packed.node_count,
				sha256 = sha,
				box_min = box_min(region_box),
				box_max = box_max(region_box),
				content_ignore_count = packed.content_ignore_count,
				readback_us = read.readback_us,
				included_extent_min = box_min(box),
				included_extent_max = box_max(box),
				box_name = name,
			})
		end
	end
end

local MEASURED_KX = {8, 10, 11}

local function run_pass(pass)
	for index = 1, #MEASURED_KX do
		local kx = MEASURED_KX[index]
		local box = CORE_BOX[kx]
		local read = read_box(box)
		emit_digests_for_region(pass, "core", kx, box, read)
		if aborted then
			return
		end
		emit_excl_for_chunk(pass, kx, box, read)
		if aborted then
			return
		end
		if kx == 8 then
			emit_incl_for_boxes(pass, "core", 8, box,
				{"cut", "fill", "water", "facedir"}, read)
		end
	end
	local seam_read = read_box(SEAM_BOX)
	emit_digests_for_region(pass, "seam", -1, SEAM_BOX, seam_read)
	emit_incl_for_boxes(pass, "seam", -1, SEAM_BOX, {"4lo", "4hi"}, seam_read)
	passes_done = passes_done + 1
end

local function readback_phase()
	emerge_phase_us = core.get_us_time() - t0
	if emerge_phase_us > EMERGE_DEADLINE_US then
		abort("A-09", "emerge deadline exceeded",
			"emerge phase took " .. emerge_phase_us .. " us, deadline " ..
			EMERGE_DEADLINE_US)
		return
	end
	emit_ipc_readback()
	run_pass(1)
	if aborted then
		return
	end
	local pass1_done_us = core.get_us_time()
	core.after(INTERPASS_WAIT_S, function()
		interpass_wait_s = (core.get_us_time() - pass1_done_us) / 1000000
		run_pass(2)
		if aborted then
			return
		end
		finish(true)
	end)
end

--
-- Serial emerge scheduling (contract 10.6): one chunk at a time,
-- core.emerge_area(pos, pos, cb) at the chunk centre, completion on
-- calls_remaining == 0, chained with core.after(0, ...), kicked off from
-- core.register_on_mods_loaded plus one core.after(0, ...).  Never a globalstep.
--
local emerge_index = 0
local emerge_next

emerge_next = function()
	emerge_index = emerge_index + 1
	local kx = schedule[emerge_index]
	if kx == nil then
		core.after(0, readback_phase)
		return
	end
	local chunk = CHUNKS[kx]
	local started = core.get_us_time()
	core.emerge_area(chunk.pos, chunk.pos, function(_, action, calls_remaining)
		if calls_remaining ~= 0 then
			return
		end
		local now = core.get_us_time()
		if action == core.EMERGE_GENERATED then
			chunks_generated = chunks_generated + 1
		end
		emit("emerge_done", {
			kx = kx,
			action = ACTION_NAMES[action] or ("unknown_" .. tostring(action)),
			calls_remaining = calls_remaining,
			elapsed_us = now - t0,
			deadline_us = EMERGE_DEADLINE_US,
			generated_us = now - started,
		})
		local value = core.ipc_get(CHUNK_KEY_PREFIX .. kx)
		if type(value) == "table" then
			if value.light_restore_failed then
				abort("A-16", "light preservation failure",
					"chunk kx " .. kx .. ": the payload's independent " ..
					"verification traversal rejected the step-6 restore " ..
					"before set_light_data")
				return
			end
			if value.extents_contained == false then
				abort("A-12", "declared write extent is not contained in minp..maxp",
					"chunk kx " .. kx)
				return
			end
		end
		if now - t0 > EMERGE_DEADLINE_US then
			abort("A-09", "emerge deadline exceeded",
				"elapsed " .. (now - t0) .. " us after chunk kx " .. kx)
			return
		end
		core.after(0, emerge_next)
	end)
end

--
-- Main-environment on_generated telemetry.  Dispatch is on minp.x alone, the
-- same key the payload uses, so the two partitions describe the same chunks.
--
local MAIN_BY_MINP_X = {[608] = 8, [768] = 10, [848] = 11}

core.register_on_generated(function(minp, maxp, blockseed)
	if MAIN_BY_MINP_X[minp.x] == nil then
		return
	end
	local started = core.get_us_time()
	emit("main_on_generated", {
		minp = {x = minp.x, y = minp.y, z = minp.z},
		maxp = {x = maxp.x, y = maxp.y, z = maxp.z},
		blockseed = blockseed,
		callback_us = core.get_us_time() - started,
	})
end)

core.register_on_mods_loaded(function()
	t0 = core.get_us_time()
	emit_manifest()
	core.after(0, emerge_next)
end)
