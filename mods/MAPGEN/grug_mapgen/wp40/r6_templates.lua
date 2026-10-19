-- Immutable WP40 R6 schematic expansion and quarter-turn materialization.
--
-- Round 47 lane TC: a row whose asset is `treegen:<species>` is a generated
-- tree (tree_templates.lua). `generated` = {full_seed = the world seed
-- string, trees = the tree_templates module} builds its variants for this
-- world at every construction, in main and emerge alike; a row of an MTS
-- asset is expanded as before. Generated variants pass the same checks
-- (bounds, vocabulary, decoration role, registered solids, no 4dir), are
-- stored sparse and turned per placement (`generated_cells`), and their
-- settlement class is computed here, never pinned in the row.
--
-- Round 51 lane LK: a row whose asset is `kitgen:<key>` is a structure of
-- the land kit (kit_templates.lua, `generated.kit`), built and turned the
-- same way; its cells are runs the writer places by the kit's ground rule
-- (r6_settlement.lua), its runs may be required.

return function(hash, content, template_source, generated)
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

	if type(hash) ~= "table" or type(hash.placement) ~= "function" or
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
	local trees = generated and generated.trees
	local kit = generated and generated.kit
	if generated ~= nil and (type(generated) ~= "table" or
			type(generated.full_seed) ~= "string" or generated.full_seed == "" or
			type(trees) ~= "table" or type(trees.variant) ~= "function" or
			(kit ~= nil and (type(kit) ~= "table" or type(kit.variant) ~= "function"))) then
		fail("generated tree seam differs")
	end

	local function replacement_for(definition, name)
		if definition.id == "swamp_papyrus" and name == "default:dirt" then
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
		-- THE VERTICAL ANCHOR, and the one node the three bush schematics floated
		-- on before 2026-09-15.
		--
		-- Luanti places a schematic decoration with its y = 0 slice ON the
		-- surface node: `Decoration::placeDeco` passes the heightmap value itself
		-- and `DecoSchematic::generate` only adds `place_offset_y` to it
		-- (`reference_projects/luanti/src/mapgen/mg_decoration.cpp`). A WP40
		-- template is anchored one node HIGHER, on the first free node above the
		-- surface, because a decoration here never cuts the natural surface --
		-- `decoration_support_ref` asks for the host at `candidate.y - 1`, and
		-- the writer refuses a cell that would replace a natural surface node.
		--
		-- Two things the catalog inherited from Luanti therefore encode that same
		-- single node of clearance a SECOND time, and each lifted its decoration
		-- one node into the air: the all-air bottom slice of `bush.mts`,
		-- `pine_bush.mts` and `acacia_bush.mts`, and `offset_y_plus_1`, which is
		-- Luanti's `place_offset_y = 1` for `blueberry_bush.mts` and
		-- `apple_log.mts` transcribed unchanged.
		--
		-- So the anchor is the schematic's lowest OCCUPIED slice. That consumes a
		-- leading all-air slice, and it is exactly the node `offset_y_plus_1`
		-- names, which is why that rule adds nothing here and may not be combined
		-- with an air base. (`offset_y_minus_4`, which sank the emergent jungle
		-- schematic, left with it in Round 47: the kapok is a generated tree.)
		local occupied_base = 0
		while occupied_base < sy - 1 do
			local empty = true
			for z = 1, sz do
				for x = 1, sx do
					if cells[cell_index(x, occupied_base + 1, z, sx, sy)].name ~= "air" then
						empty = false
					end
				end
			end
			if not empty then break end
			occupied_base = occupied_base + 1
		end
		local offset_y = -occupied_base
		if definition.rule:find("offset_y_plus_1", 1, true) and
				occupied_base ~= 0 then
			fail("template offsets its own air base at " .. definition.id)
		end
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

	-- GENERATED TREES. One variant set per species and world, shared by
	-- every row of that species. The checks are the MTS cells' own:
	-- bounds (the generator's box, x and z -8..8 -- wood may reach 8, one
	-- past the leaf box -- and y -1..63), the cell bound, every node in the
	-- production content with the decoration role, a registered solid, and
	-- no 4dir/degrotate rotation kind.
	local species_variants = {}
	local kit_variants = {}
	local generated_seconds = 0
	local name_refs = {}
	local function generated_ref(name)
		local cached = name_refs[name]
		if cached then return cached[1], cached[2] end
		local content_ref = content.content_ref(name)
		if not content_ref then fail("template node is absent from content manifest: " .. name) end
		local mask = contract.content_kind_masks[content_ref]
		if math.floor(mask / 8) % 2 ~= 1 then
			fail("template node lacks decoration role: " .. name)
		end
		local target_cid, target_kind = contract.resolve_r6(content_ref, 0)
		if target_cid == contract.ignore_cid or target_kind ~= 1 then
			fail("template node is not a registered solid: " .. name)
		end
		local kind = param2_kind(content_ref, 0)
		if kind ~= "none" and kind ~= "facedir" then
			fail("generated tree node has rotation kind " .. kind .. ": " .. name)
		end
		name_refs[name] = {content_ref, kind}
		return content_ref, kind
	end
	local function check_cell(x, y, z, param2, kind, label)
		integer(x, label .. " x", -8, 8)
		integer(y, label .. " y", -1, 63)
		integer(z, label .. " z", -8, 8)
		integer(param2, label .. " param2", 0, 23)
		if kind == "none" and param2 ~= 0 then fail(label .. " turns a node without rotation") end
	end
	-- `source` is the tree module or the kit module (Round 51 lane LK);
	-- the kit's seeds hash under a domain of their own.
	local function variants_of(key, source)
		source = source or trees
		local cache = source == trees and species_variants or kit_variants
		local list = cache[key]
		if list then return list end
		local row = source.BY_KEY[key]
		if not row then fail("unknown generated species " .. tostring(key)) end
		local started = os.clock()
		local domain = source == trees and "tree_template_seed_v1" or "kit_template_seed_v1"
		local seeds = source.template_seeds(key, function(k)
			return hash.digest_count(domain, generated.full_seed, {key, k}, 2)
		end)
		list = {}
		for index = 1, #seeds do
			local v = source.variant(key, seeds[index])
			if v.count + v.root_count > 16384 then fail("generated tree cell bound exceeded") end
			v.ref, v.kind, v.rref, v.rkind = {}, {}, {}, {}
			for cell = 1, v.count do
				v.ref[cell], v.kind[cell] = generated_ref(v.name[cell])
				check_cell(v.x[cell], v.y[cell], v.z[cell], v.param2[cell], v.kind[cell],
					"generated tree cell")
			end
			for cell = 1, v.root_count do
				v.rref[cell], v.rkind[cell] = generated_ref(v.rname[cell])
				check_cell(v.rx[cell], v.ry[cell], v.rz[cell], v.rparam2[cell],
					v.rkind[cell], "generated root cell")
			end
			for run = 1, #v.runs do
				local r = v.runs[run]
				integer(r.first, "root run start", 1, v.root_count)
				integer(r.last, "root run end", r.first, v.root_count)
				integer(r.parent, "root run parent", 0, run - 1)
				if r.required ~= nil and type(r.required) ~= "boolean" then
					fail("root run requirement is not boolean")
				end
			end
			v.bounds = {}
			for rotation = 0, 3 do
				local min_x, max_x, min_y, max_y, min_z, max_z =
					source.rotated_bounds(v, rotation)
				v.bounds[rotation + 1] = {min_x = min_x, max_x = max_x, min_y = min_y,
					max_y = max_y, min_z = min_z, max_z = max_z}
			end
			v.digest = hash.hex(hash.sha256_bytes(v.bytes))
			v.bytes = nil
			list[index] = v
		end
		generated_seconds = generated_seconds + os.clock() - started
		cache[key] = list
		return list
	end

	local function generated_record(definition, key, source)
		local variants = variants_of(key, source)
		local rotations = {}
		local computed_class = 2
		for rotation = 0, 3 do
			local union
			for index = 1, #variants do
				local b = variants[index].bounds[rotation + 1]
				if not union then
					union = {min_x = b.min_x, max_x = b.max_x, min_y = b.min_y,
						max_y = b.max_y, min_z = b.min_z, max_z = b.max_z}
				else
					union.min_x = math.min(union.min_x, b.min_x)
					union.max_x = math.max(union.max_x, b.max_x)
					union.min_y = math.min(union.min_y, b.min_y)
					union.max_y = math.max(union.max_y, b.max_y)
					union.min_z = math.min(union.min_z, b.min_z)
					union.max_z = math.max(union.max_z, b.max_z)
				end
				if b.max_x - b.min_x + 1 > 5 or b.max_z - b.min_z + 1 > 5 then
					computed_class = 1
				end
			end
			union.rotation = rotation
			union.size_x = union.max_x - union.min_x + 1
			union.size_y = union.max_y - union.min_y + 1
			union.size_z = union.max_z - union.min_z + 1
			rotations[rotation + 1] = union
		end
		if definition.settlement_class ~= nil then
			fail("generated template pins a settlement class at " .. definition.id)
		end
		return {definition_id = definition.id, species = key, generated = true,
			kit = (kit ~= nil and source == kit) or nil, rotations = rotations,
			variants = variants},
			computed_class
	end

	local classes = {}
	for index = 1, #definitions do
		local definition = definitions[index]
		local generated_key = definition.kind == "template" and
			definition.asset_or_node:match("^treegen:([a-z_]+)$")
		local kit_key = definition.kind == "template" and
			definition.asset_or_node:match("^kitgen:([a-z_]+)$")
		if kit_key then
			if not kit then fail("kit template without the kit at " .. definition.id) end
			local record, class = generated_record(definition, kit_key, kit)
			classes[definition.id] = class
			records[#records + 1] = record
			by_id[definition.id] = record
		elseif generated_key then
			if not trees then fail("generated template without a world seed at " .. definition.id) end
			local record, class = generated_record(definition, generated_key)
			classes[definition.id] = class
			records[#records + 1] = record
			by_id[definition.id] = record
		elseif definition.kind == "template" then
			local sx, sy, sz, yslice, cells = base_record(definition)
			local rotations = {}
			local computed_class = 2
			for rotation = 0, 3 do
				local record = rotate_record(definition, rotation, sx, sy, sz, yslice, cells)
				rotations[rotation + 1] = record
				local span_x = record.max_x - record.min_x + 1
				local span_z = record.max_z - record.min_z + 1
				if span_x > 5 or span_z > 5 then computed_class = 1 end
			end
			if definition.id == "deep_forest_apple_log" or
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

	-- The placement hash of a world seed (r6_hash.lua `placement`), with the
	-- salts of its rows' streams, built once per seed.
	local placements = {}
	local function stream(full_seed, domain, definition_id)
		local world = placements[full_seed]
		if not world then
			local mix, salt = hash.placement(full_seed)
			world = {mix = mix, salt = salt, salts = {}}
			placements[full_seed] = world
		end
		local salts = world.salts[domain]
		if not salts then
			salts = {}
			world.salts[domain] = salts
		end
		local value = salts[definition_id]
		if not value then
			value = world.salt(domain, definition_id)
			salts[definition_id] = value
		end
		return world.mix, value
	end

	-- A template's probability trial: the low byte of a draw below the
	-- slice's or node's probability (0..254 of 256). The draw chains the
	-- row's stream at the root into the local slice y or node x/y/z. The
	-- rotation is the root's own (decoration_rotation), so it adds nothing.
	local function probability_include(full_seed, definition_id, root_x, root_y,
			root_z, rotation, trial_kind, x, y, z, probability)
		integer(probability, "template probability", 0, 254)
		if probability == 0 then return false end
		if probability == 254 then return true end
		local mix, salt = stream(full_seed, "template_probability", definition_id)
		local root = mix(root_x, root_y, root_z, salt)
		local draw
		if trial_kind == "slice" then
			draw = mix(-1, integer(y, "template slice y", 0, 63), -1, root)
		elseif trial_kind == "node" then
			draw = mix(integer(x, "template node x", 0, 15),
				integer(y, "template node y", 0, 63),
				integer(z, "template node z", 0, 15), root)
		else
			fail("template probability trial kind differs")
		end
		return draw % 256 < probability
	end

	-- A generated record's copy: its own rotations, the variants shared
	-- (read-only by contract; they are the world's and never change).
	local function copy_record(record)
		if not record or not record.generated then return copy(record) end
		return {definition_id = record.definition_id, species = record.species,
			generated = true, kit = record.kit, rotations = copy(record.rotations),
			variants = record.variants}
	end

	local module = {}
	function module.record(definition_id) return copy_record(by_id[definition_id]) end
	function module.records()
		local result = {}
		for index = 1, #records do result[index] = copy_record(records[index]) end
		return result
	end
	-- The settlement class each generated row computed (rows id -> 1 or 2),
	-- for r6_content.lua's once-only `set_template_classes`.
	function module.generated_classes() return copy(classes) end
	-- The identity the R7 manifest binds: the MTS records whole (frozen), and
	-- per generated row its species and the digest of every variant (this
	-- world's; the lane fixture pins sample seeds).
	function module.identity()
		local static, generated_rows = {}, {}
		for index = 1, #records do
			local record = records[index]
			if record.generated then
				local digests = {}
				for v = 1, #record.variants do digests[v] = record.variants[v].digest end
				generated_rows[#generated_rows + 1] = {definition_id = record.definition_id,
					species = record.species, kit = record.kit, digests = digests}
			else
				static[#static + 1] = copy(record)
			end
		end
		return {static = static, generated = generated_rows}
	end
	-- CPU seconds this construction spent building the generated variants.
	function module.generated_seconds() return generated_seconds end
	function module.root_ground_names()
		local names = {}
		for index = 1, #(trees and trees.ROOT_GROUND or {}) do
			names[index] = trees.ROOT_GROUND[index]
		end
		return names
	end
	-- The ground a kit run's column stands on (kit_templates.lua GROUND).
	function module.kit_ground_names()
		local names = {}
		for index = 1, #(kit and kit.GROUND or {}) do names[index] = kit.GROUND[index] end
		return names
	end
	function module.rotation(definition_id, rotation)
		integer(rotation, "rotation index", 0, 3)
		local record = by_id[definition_id]
		return record and copy(record.rotations[rotation + 1]) or nil
	end
	-- The variant (1-based) a generated row's candidate at a root takes: the
	-- row's own stream of the placement hash at the root, independent of its
	-- rotation's.
	function module.variant_index(full_seed, definition_id, root_x, root_y, root_z)
		local record = by_id[definition_id]
		if not record or not record.generated then fail("not a generated template") end
		local mix, salt = stream(full_seed, "decoration_variant", definition_id)
		return mix(root_x, root_y, root_z, salt) % #record.variants + 1
	end
	-- Which root runs a placed tree keeps (handoff §5): a run whose every
	-- cell passes the writer's test `cell_ok(cell)` (ground right under the
	-- cell's column at the foot, none at the foot's level, the cell free),
	-- a fork's toe only with its parent run. Returns kept[run] = boolean.
	function module.kept_root_runs(runs, cell_ok)
		local kept = {}
		for run_index = 1, #runs do
			local run = runs[run_index]
			local ok = run.parent == 0 or kept[run.parent] == true
			for part = 1, ok and #run or 0 do
				if not cell_ok(run[part]) then
					ok = false
					break
				end
			end
			kept[run_index] = ok
		end
		return kept
	end
	-- One generated variant turned by `rotation`, as the writer's cells
	-- {x, y, z, include, content_ref, param2, force_place, optional} (stems
	-- force-placed, leaves optional), its root runs (each {parent, cells})
	-- and its turned bounds.
	function module.generated_cells(definition_id, variant_index, rotation)
		integer(rotation, "rotation index", 0, 3)
		local record = by_id[definition_id]
		local v = record and record.generated and record.variants[variant_index]
		if not v then fail("generated variant differs") end
		local rotate, stem, leaf = trees.rotate, trees.STEM, trees.LEAF
		if record.kit then rotate, stem, leaf = kit.rotate, kit.STEM, kit.LEAF end
		local cells = {}
		for index = 1, v.count do
			local x, z = rotate(v.x[index], v.z[index], rotation)
			local flag = v.flag[index]
			cells[index] = {x = x, y = v.y[index], z = z, include = true,
				content_ref = v.ref[index],
				param2 = rotate_param2(v.kind[index], v.param2[index], rotation),
				force_place = flag == stem, optional = flag == leaf}
		end
		local runs = {}
		for run_index = 1, #v.runs do
			local run = v.runs[run_index]
			local list = {parent = run.parent, required = run.required}
			for index = run.first, run.last do
				local x, z = rotate(v.rx[index], v.rz[index], rotation)
				list[#list + 1] = {x = x, y = v.ry[index], z = z,
					content_ref = v.rref[index],
					param2 = rotate_param2(v.rkind[index], v.rparam2[index], rotation)}
			end
			runs[run_index] = list
		end
		return cells, runs, v.bounds[rotation + 1]
	end
	function module.rotation_runtime(definition_id, rotation)
		integer(rotation, "rotation index", 0, 3)
		local record = by_id[definition_id]
		return record and record.rotations[rotation + 1] or nil
	end
	function module.probability_include(...)
		return probability_include(...)
	end
	return module
end
