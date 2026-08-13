local modpath = core.get_modpath(core.get_current_modname())

core.set_gen_notify({dungeon = true})
core.register_mapgen_script(modpath .. "/mapgen.lua")

local points = {}
for z = -4, 4 do
	for x = -4, 4 do
		points[#points + 1] = {x = x * 80, y = -240, z = z * 80}
	end
end

local next_point = 1

local function emit(tag, fields)
	fields.tag = tag
	core.log("action", "DUNGEON_PROBE_JSON " .. core.write_json(fields))
end

local function emerge_next()
	local pos = points[next_point]
	if not pos then
		emit("complete", {requested_mapchunks = #points})
		core.request_shutdown("WP40 dungeon probe complete", false, 0)
		return
	end

	next_point = next_point + 1
	core.emerge_area(pos, pos, function(_, action, calls_remaining)
		if action == core.EMERGE_CANCELLED or action == core.EMERGE_ERRORED then
			emit("emerge_error", {
				action = action,
				position = pos,
			})
		end
		if calls_remaining == 0 then
			core.after(0, emerge_next)
		end
	end)
end

core.register_on_mods_loaded(function()
	local dungeon_noise = assert(
		core.get_mapgen_setting_noiseparams("mgv7_np_dungeons"),
		"missing active mgv7_np_dungeons")
	local spread = assert(dungeon_noise.spread, "missing dungeon noise spread")
	local function canonical_number(value)
		return string.format("%.6g", value)
	end
	local canonical_dungeon_noise = table.concat({
		canonical_number(dungeon_noise.offset),
		canonical_number(dungeon_noise.scale),
		canonical_number(spread.x),
		canonical_number(spread.y),
		canonical_number(spread.z),
		canonical_number(dungeon_noise.seed),
		canonical_number(dungeon_noise.octaves),
		canonical_number(dungeon_noise.persistence or dungeon_noise.persist),
		canonical_number(dungeon_noise.lacunarity),
		dungeon_noise.flags or "",
	}, string.char(124))
	emit("main_api", {
		engine_version = core.get_version().string,
		requested_mapchunks = #points,
		seed = core.get_mapgen_setting("seed"),
		mg_name = core.get_mapgen_setting("mg_name"),
		mg_flags = core.get_mapgen_setting("mg_flags"),
		mgv7_spflags = core.get_mapgen_setting("mgv7_spflags"),
		chunksize = core.get_mapgen_setting("chunksize"),
		water_level = core.get_mapgen_setting("water_level"),
		mgv7_dungeon_ymin = core.get_mapgen_setting("mgv7_dungeon_ymin"),
		mgv7_dungeon_ymax = core.get_mapgen_setting("mgv7_dungeon_ymax"),
		mgv7_np_dungeons = canonical_dungeon_noise,
	})
	core.after(0, emerge_next)
end)
