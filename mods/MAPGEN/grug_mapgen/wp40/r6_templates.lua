-- Immutable WP40 R6 schematic expansion and quarter-turn materialization.

return function(hash, content, template_source)
	local MAX_SAFE = 9007199254740991
	local FACEDIR_ROTATE = {
		0,1,2,3, 1,2,3,0, 2,3,0,1, 3,0,1,2,
		4,13,10,19, 5,14,11,16, 6,15,8,17, 7,12,9,18,
		8,17,6,15, 9,18,7,12, 10,19,4,13, 11,16,5,14,
		12,9,18,7, 13,10,19,4, 14,11,16,5, 15,8,17,6,
		16,5,14,11, 17,6,15,8, 18,7,12,9, 19,4,13,10,
		20,23,22,21, 21,20,23,22, 22,21,20,23, 23,22,21,20,
	}
	local WALL_TO_ROT = {[2] = 0, [3] = 2, [4] = 1, [5] = 3}
	local ROT_TO_WALL = {[0] = 2, [1] = 4, [2] = 3, [3] = 5}
	local SILVERWOOD = {
		["default:aspen_tree"] = "grug_trees:silverwood_tree",
		["default:aspen_leaves"] = "grug_trees:silverwood_leaves",
	}

	local function fail(message)
		error("fail_template: " .. message, 0)
	end

	local function integer(value, label, minimum, maximum)
		if type(value) ~= "number" or value ~= value or value == math.huge or
				value == -math.huge or value % 1 ~= 0 or math.abs(value) > MAX_SAFE or
				value < minimum or value > maximum then
			fail(label .. " is not an exact bounded integer")
		end
		return value
	end

	local function text(value, label)
		if type(value) ~= "string" or value == "" or
				value:find("\0", 1, true) or value:find("\t", 1, true) or
				value:find("\r", 1, true) or value:find("\n", 1, true) then
			fail(label .. " is not length-safe text")
		end
		return value
	end

	local function dense(values, expected, label)
		if type(values) ~= "table" or getmetatable(values) ~= nil or
				#values ~= expected then
			fail(label .. " is not the expected plain array")
		end
		for index = 1, expected do
			if values[index] == nil then fail(label .. " has a hole") end
		end
		for key in pairs(values) do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > expected then
				fail(label .. " is not dense")
			end
		end
		return values
	end

	local function exact_fields(value, allowed, label)
		if type(value) ~= "table" or getmetatable(value) ~= nil then
			fail(label .. " is not a plain table")
		end
		for key in pairs(value) do
			if not allowed[key] then fail(label .. " has unexpected field " .. tostring(key)) end
		end
		for key in pairs(allowed) do
			if value[key] == nil then fail(label .. " is missing " .. key) end
		end
		return value
	end

	local function copy(value, active)
		if type(value) ~= "table" then return value end
		active = active or {}
		if active[value] then fail("template graph contains a cycle") end
		active[value] = true
		local result = {}
		for key, child in pairs(value) do result[copy(key, active)] = copy(child, active) end
		active[value] = nil
		return result
	end

	if type(hash) ~= "table" or type(hash.digest) ~= "function" or
			type(hash.digest_count) ~= "function" or
			type(hash.sha256_bytes) ~= "function" or type(hash.frame) ~= "function" or
			type(content) ~= "table" or type(content.decorations) ~= "function" or
			type(content.param2_kind) ~= "function" or
			type(template_source) ~= "table" or type(template_source.read) ~= "function" then
		fail("construction seams differ")
	end

	local contract = content.content_contract()
	local definitions = content.decorations()
	local source_cache = {}
	local records, by_id = {}, {}
	local maximum_x, maximum_y, maximum_z = 0, 0, 0

	local function replacement_for(definition, name)
		if definition.id == "elf_forest_silverwood" then
			return SILVERWOOD[name] or name
		elseif definition.id == "swamp_papyrus" and name == "default:dirt" then
			return "grug_nodes:mud"
		elseif definition.id == "deep_forest_apple_log" and
				name == "flowers:mushroom_brown" then
			return "air"
		end
		return name
	end

	local function param2_kind(content_ref, param2)
		local ok, kind = pcall(content.param2_kind, content_ref, param2)
		if not ok then fail("content classification failed") end
		if kind ~= "none" and kind ~= "facedir" and kind ~= "wallmounted" and
				kind ~= "colorfacedir" and kind ~= "colorwallmounted" and
				kind ~= "4dir" and kind ~= "color4dir" and kind ~= "degrotate" and
				kind ~= "colordegrotate" and kind ~= "meshoptions" and
				kind ~= "leveled" and kind ~= "flowingliquid" and
				kind ~= "glasslikeliquidlevel" and kind ~= "waving" and
				kind ~= "color" then
			fail("unknown param2 rotation kind " .. tostring(kind))
		end
		return kind
	end

	local function rotate_param2(kind, param2, rotation)
		if kind == "4dir" or kind == "color4dir" or kind == "degrotate" or
				kind == "colordegrotate" then
			fail("unsupported template param2 rotation kind " .. kind)
		end
		if rotation == 0 then return param2 end
		if kind == "facedir" or kind == "colorfacedir" then
			local direction = (param2 % 32) % 24
			local color = param2 - (param2 % 32)
			return color + FACEDIR_ROTATE[direction * 4 + rotation + 1]
		elseif kind == "wallmounted" or kind == "colorwallmounted" then
			local raw_wall = param2 % 8
			if raw_wall >= 6 then fail("invalid wallmounted template param2") end
			local color = param2 - raw_wall
			local wall = raw_wall
			if wall <= 1 then return param2 end
			local old_rotation = WALL_TO_ROT[wall]
			return color + ROT_TO_WALL[(old_rotation - rotation) % 4]
		end
		return param2
	end

	local function canonical_digest(definition_id, rotation, sx, sy, sz,
			yslice, cells)
		local parts = {
			hash.frame("grug_wp40_r6_template_v1"), hash.frame(definition_id),
			hash.frame(rotation), hash.frame(sx), hash.frame(sy), hash.frame(sz),
		}
		for y = 1, sy do parts[#parts + 1] = hash.frame(yslice[y]) end
		for index = 1, #cells do
			local cell = cells[index]
			parts[#parts + 1] = hash.frame(cell.name)
			parts[#parts + 1] = hash.frame(cell.probability)
			parts[#parts + 1] = hash.frame(cell.param2)
			parts[#parts + 1] = hash.frame(cell.force_place and "true" or "false")
		end
		return hash.hex(hash.sha256_bytes(table.concat(parts)))
	end

	local function read_source(filename)
		local schematic = source_cache[filename]
		if schematic ~= nil then return schematic end
		local ok, value = pcall(template_source.read, filename)
		if not ok or type(value) ~= "table" or getmetatable(value) ~= nil then
			fail("cannot read schematic " .. filename)
		end
		exact_fields(value, {size = true, yslice_prob = true, data = true},
			"schematic " .. filename)
		exact_fields(value.size, {x = true, y = true, z = true}, "schematic size")
		local sx = integer(value.size.x, "schematic size x", 1, 16)
		local sy = integer(value.size.y, "schematic size y", 1, 64)
		local sz = integer(value.size.z, "schematic size z", 1, 16)
		if sx * sy * sz > 16384 then fail("schematic cell bound exceeded") end
		dense(value.data, sx * sy * sz, "schematic data")
		dense(value.yslice_prob, sy, "schematic y slices")
		schematic = copy(value)
		source_cache[filename] = schematic
		return schematic
	end

	local function base_record(definition)
		local source = read_source(definition.asset_or_node)
		local sx, sy, sz = source.size.x, source.size.y, source.size.z
		local yslice = {}
		for index = 1, sy do
			local slice = source.yslice_prob[index]
			exact_fields(slice, {ypos = true, prob = true}, "schematic y slice")
			local y = integer(slice.ypos, "schematic local y", 0, sy - 1)
			if yslice[y + 1] ~= nil then fail("duplicate schematic y slice") end
			local probability = integer(slice.prob, "schematic slice probability", 0, 254)
			if probability % 2 ~= 0 then fail("odd schematic slice probability") end
			yslice[y + 1] = probability
		end
		for y = 1, sy do if yslice[y] == nil then fail("missing schematic y slice") end end
		local cells = {}
		for index = 1, #source.data do
			local source_cell = source.data[index]
			if type(source_cell) ~= "table" or getmetatable(source_cell) ~= nil then
				fail("schematic cell is not a plain table")
			end
			for key in pairs(source_cell) do
				if key ~= "name" and key ~= "prob" and key ~= "param2" and
						key ~= "force_place" then
					fail("schematic cell has unexpected field " .. tostring(key))
				end
			end
			local name = replacement_for(definition, text(source_cell.name,
				"schematic node name"))
			local probability = integer(source_cell.prob,
				"schematic node probability", 0, 254)
			if probability % 2 ~= 0 then fail("odd schematic node probability") end
			local param2 = integer(source_cell.param2, "schematic param2", 0, 255)
			local force_place = source_cell.force_place == true
			if source_cell.force_place ~= nil and source_cell.force_place ~= true and
					source_cell.force_place ~= false then
				fail("schematic force_place is not boolean")
			end
			local content_ref = 0
			local kind = "none"
			if name ~= "air" then
				content_ref = content.content_ref(name)
				if not content_ref then fail("template node is absent from content manifest: " .. name) end
				local mask = contract.content_kind_masks[content_ref]
				if math.floor(mask / 8) % 2 ~= 1 then
					fail("template node lacks decoration role: " .. name)
				end
				local target_cid, target_kind = contract.resolve_r6(content_ref, param2)
				if target_cid == contract.ignore_cid or target_kind ~= 1 then
					fail("template node is not a registered solid: " .. name)
				end
				kind = param2_kind(content_ref, param2)
				if kind == "4dir" or kind == "color4dir" or kind == "degrotate" or
						kind == "colordegrotate" then
					fail("template contains forbidden param2 rotation kind")
				end
			end
			cells[index] = {name = name, content_ref = content_ref,
				probability = probability, param2 = param2,
				force_place = force_place, param2_kind = kind}
		end
		return sx, sy, sz, yslice, cells
	end

	local function cell_index(x, y, z, sx, sy)
		return (z - 1) * sx * sy + (y - 1) * sx + x
	end

	local function rotate_record(definition, rotation, sx, sy, sz, yslice, cells)
		local rx, rz = sx, sz
		if rotation % 2 == 1 then rx, rz = sz, sx end
		local rotated = {}
		for z = 1, sz do
			for y = 1, sy do
				for x = 1, sx do
					local tx, tz
					if rotation == 0 then tx, tz = x, z
					elseif rotation == 1 then tx, tz = z, sx - x + 1
					elseif rotation == 2 then tx, tz = sx - x + 1, sz - z + 1
					else tx, tz = sz - z + 1, x end
					local source_cell = cells[cell_index(x, y, z, sx, sy)]
					rotated[cell_index(tx, y, tz, rx, sy)] = {
						name = source_cell.name, content_ref = source_cell.content_ref,
						probability = source_cell.probability,
						param2 = rotate_param2(source_cell.param2_kind,
							source_cell.param2, rotation),
						force_place = source_cell.force_place,
					}
				end
			end
		end
		local offset_y = 0
		if definition.rule:find("offset_y_plus_1", 1, true) then offset_y = 1
		elseif definition.rule:find("offset_y_minus_4", 1, true) then offset_y = -4 end
		local min_x = definition.rule:find("center_x", 1, true) and
			-math.floor((rx - 1) / 2) or 0
		local min_z = definition.rule:find("center_xz", 1, true) and
			-math.floor((rz - 1) / 2) or 0
		local result = {
			rotation = rotation, size_x = rx, size_y = sy, size_z = rz,
			min_x = min_x, max_x = min_x + rx - 1,
			min_y = offset_y, max_y = offset_y + sy - 1,
			min_z = min_z, max_z = min_z + rz - 1,
			y_slice_probabilities = copy(yslice), cells = rotated,
		}
		result.digest = canonical_digest(definition.id, rotation, rx, sy, rz,
			yslice, rotated)
		return result
	end

	for index = 1, #definitions do
		local definition = definitions[index]
		if definition.kind == "template" then
			local sx, sy, sz, yslice, cells = base_record(definition)
			local rotations = {}
			local computed_class = 2
			for rotation = 0, 3 do
				local record = rotate_record(definition, rotation, sx, sy, sz, yslice, cells)
				rotations[rotation + 1] = record
				local span_x = record.max_x - record.min_x + 1
				local span_y = record.max_y - record.min_y + 1
				local span_z = record.max_z - record.min_z + 1
				if span_x > maximum_x then maximum_x = span_x end
				if span_y > maximum_y then maximum_y = span_y end
				if span_z > maximum_z then maximum_z = span_z end
				if span_x > 5 or span_z > 5 then computed_class = 1 end
			end
			if definition.id == "emergent_jungle_tree" or
					definition.id == "deep_forest_apple_log" or
					definition.id == "badlands_large_cactus" or
					definition.id == "swamp_papyrus" then
				computed_class = 1
			end
			if definition.settlement_class ~= computed_class then
				fail("template settlement class differs at " .. definition.id)
			end
			local record = {definition_id = definition.id, rotations = rotations}
			records[#records + 1] = record
			by_id[definition.id] = record
		end
	end

	local probability_fields = {}
	local function probability_include(full_seed, definition_id, root_x, root_y,
			root_z, rotation, trial_kind, x, y, z, probability)
		integer(probability, "template probability", 0, 254)
		if probability == 0 then return false end
		if probability == 254 then return true end
		probability_fields[1], probability_fields[2], probability_fields[3] =
			definition_id, root_x, root_y
		probability_fields[4], probability_fields[5], probability_fields[6] =
			root_z, rotation, trial_kind
		local count
		if trial_kind == "slice" then
			probability_fields[7] = integer(y, "template slice y", 0, 63)
			count = 7
		elseif trial_kind == "node" then
			probability_fields[7] = integer(x, "template node x", 0, 15)
			probability_fields[8] = integer(y, "template node y", 0, 63)
			probability_fields[9] = integer(z, "template node z", 0, 15)
			count = 9
		else
			fail("template probability trial kind differs")
		end
		local digest = hash.digest_count("template_probability_v1", full_seed,
			probability_fields, count)
		return string.byte(digest, 1) < probability
	end

	local module = {}
	function module.record(definition_id) return copy(by_id[definition_id]) end
	function module.records() return copy(records) end
	function module.rotation(definition_id, rotation)
		integer(rotation, "rotation index", 0, 3)
		local record = by_id[definition_id]
		return record and copy(record.rotations[rotation + 1]) or nil
	end
	function module.rotation_runtime(definition_id, rotation)
		integer(rotation, "rotation index", 0, 3)
		local record = by_id[definition_id]
		return record and record.rotations[rotation + 1] or nil
	end
	function module.maximum_footprint()
		return maximum_x, maximum_y, maximum_z
	end
	function module.probability_include(...)
		return probability_include(...)
	end
	return module
end
