local emitted_api = false

local function emit(tag, fields)
	fields.tag = tag
	core.log("action", "DUNGEON_PROBE_JSON " .. core.write_json(fields))
end

local function node_sample(vm, pos)
	local node = vm:get_node_at(pos)
	return {
		name = node.name,
		param1 = node.param1,
		param2 = node.param2,
	}
end

core.register_on_generated(function(vm, minp, maxp, blockseed)
	local notify = core.get_mapgen_object("gennotify") or {}
	local rooms = notify.dungeon or {}
	local emerged_minp, emerged_maxp = vm:get_emerged_area()

	if not emitted_api then
		emitted_api = true
		emit("mapgen_api", {
			get_data = type(vm.get_data),
			get_emerged_area = type(vm.get_emerged_area),
			get_param2_data = type(vm.get_param2_data),
			get_node_at = type(vm.get_node_at),
			get_flags = type(vm.get_flags),
			get_voxel_flags = type(vm.get_voxel_flags),
			get_dungeon_flags = type(vm.get_dungeon_flags),
			gennotify_type = type(notify),
		})
	end

	if #rooms == 0 then
		return
	end

	local center = rooms[1]

	emit("dungeon_event", {
		blockseed = blockseed,
		minp = minp,
		maxp = maxp,
		emerged_minp = emerged_minp,
		emerged_maxp = emerged_maxp,
		room_count = #rooms,
		first_room = {
			position = center,
			center = node_sample(vm, center),
			above = node_sample(vm, {
				x = center.x,
				y = center.y + 1,
				z = center.z,
			}),
			below = node_sample(vm, {
				x = center.x,
				y = center.y - 1,
				z = center.z,
			}),
		},
	})
end)
