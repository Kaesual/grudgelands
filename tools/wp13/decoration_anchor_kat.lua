-- The vertical anchor of every WP40 template decoration -- the KAT that turns
-- red if bushes float again (WP13 playtest round 3, 2026-09-15).
--
-- Luanti places a schematic decoration with its y = 0 slice ON the surface node
-- (`Decoration::placeDeco` hands `DecoSchematic::generate` the heightmap value
-- and only `place_offset_y` is added to it). WP40 anchors a template one node
-- HIGHER, on the first free node above the surface, because a decoration here
-- never cuts the natural surface. Everything the catalog inherited from Luanti
-- that encodes "one above the surface" -- the all-air bottom slice of the three
-- bush schematics, and `offset_y_plus_1` -- is therefore a SECOND copy of that
-- node in this frame and used to lift its decoration into the air.
--
-- The property asserted here is the fix, stated positively:
--
--     the lowest OCCUPIED slice of every template lands exactly on the
--     decoration's own anchor, `min_y + air_base == 0`,
--
-- unless the row authors a deliberate negative offset (`offset_y_minus_4`, the
-- emergent jungle tree, which is sunk on purpose).
--
-- WHAT IS MEASURED AND WHAT IS FROZEN. Every schematic's size and byte length
-- are read from the file itself and cross-checked against the input roster the
-- production manifest pins. Its `air_base` -- the number of leading slices that
-- contain no node at all -- needs the compressed node data, and the pure-5.1
-- interpreter cannot inflate it; so under LuaJIT the file is decoded and the
-- frozen value is VERIFIED against it, and under PUC 5.1 a synthetic schematic
-- of the frozen shape is fed through the same production expander. Both
-- interpreters therefore run the identical assertion, and one of them proves
-- the frozen table against the bytes.
--
-- SCOPE: this is a REGRESSION guard, not a design guard. It asserts that the
-- catalog as it stands is ground-anchored, and it cannot catch a schematic
-- ADDED with an air base -- adding one means adding its `air_base` to `SHAPES`
-- below, after which the assertion is satisfied by construction. Nor does it
-- cover `offset_y_minus_4`, which bypasses the air-base consumption entirely.
-- A future template that wanted either would need a new case here.
--
-- Run from the repo root, under both interpreters:
--     luajit -e 'io.write(dofile("tools/wp13/decoration_anchor_kat.lua")("."))'
--     tools/bin/lua51 -e 'io.write(dofile("tools/wp13/decoration_anchor_kat.lua")("."))'
return function(repo)
	local function fail(message)
		error("decoration anchor KAT: " .. message, 0)
	end
	local function check(condition, message)
		if not condition then fail(message) end
		return condition
	end

	-- asset -> size and the frozen leading-all-air slice count. Exactly three
	-- schematics carry such a slice, and they are exactly the three bushes the
	-- user saw hovering.
	local SHAPES = {
		{"acacia_bush.mts", 3, 3, 3, 1, 114},
		{"acacia_tree.mts", 9, 9, 9, 0, 207},
		{"apple_log.mts", 4, 2, 1, 0, 88},
		{"apple_tree.mts", 7, 8, 7, 0, 209},
		{"aspen_tree.mts", 5, 14, 5, 0, 174},
		{"blueberry_bush.mts", 3, 1, 3, 0, 80},
		{"bush.mts", 3, 3, 3, 1, 99},
		{"emergent_jungle_tree.mts", 7, 37, 7, 0, 504},
		{"grug_gravewood_small.mts", 7, 7, 7, 0, 171},
		{"grug_gravewood_tall.mts", 7, 9, 7, 0, 191},
		{"jungle_tree.mts", 5, 17, 5, 0, 255},
		{"large_cactus.mts", 5, 7, 5, 0, 87},
		{"papyrus_on_dirt.mts", 1, 7, 1, 0, 73},
		{"pine_bush.mts", 3, 3, 3, 1, 110},
		{"pine_tree.mts", 5, 16, 5, 0, 178},
		{"small_pine_tree.mts", 5, 12, 5, 0, 174},
		{"snowy_pine_tree_from_sapling.mts", 5, 16, 5, 0, 235},
	}
	local GRAVEWOOD = {["grug_gravewood_small.mts"] = true,
		["grug_gravewood_tall.mts"] = true}

	local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
	local common = dofile(repo .. "/tools/wp40/r6/common.lua")
	local manifest = dofile(wp40 .. "/r7_r6_manifest.lua")()
	local templates_factory = dofile(wp40 .. "/r6_templates.lua")

	local shape_by_asset = {}
	for index = 1, #SHAPES do
		local row = SHAPES[index]
		shape_by_asset[row[1]] = {x = row[2], y = row[3], z = row[4],
			air_base = row[5], bytes = row[6]}
	end

	local function asset_path(asset)
		if GRAVEWOOD[asset] then
			return repo .. "/mods/ITEMS/grug_trees/schematics/" .. asset
		end
		return repo .. "/mods/BASE/default/schematics/" .. asset
	end

	-- The uncompressed MTS header: magic, version, size, the y-slice
	-- probabilities and the node-name table. Enough to pin the shape in plain
	-- 5.1; the node data below it is zlib and is only read under LuaJIT.
	local function read_header(asset)
		local bytes = common.read_file(asset_path(asset))
		check(bytes:sub(1, 4) == "MTSM", "MTS signature differs: " .. asset)
		local function u16(offset)
			local high, low = bytes:byte(offset, offset + 1)
			check(low ~= nil, "truncated MTS header: " .. asset)
			return high * 256 + low
		end
		check(u16(5) == 4, "MTS version differs: " .. asset)
		return u16(7), u16(9), u16(11), #bytes
	end

	local out = {}
	local function emit(line) out[#out + 1] = line end

	--
	-- 1. The frozen shapes against the files, and against the pinned roster.
	--
	local decoded = nil
	local ok_ffi = pcall(function() return common.read_mts(asset_path("bush.mts")) end)
	local assets = {}
	for asset in pairs(shape_by_asset) do assets[#assets + 1] = asset end
	table.sort(assets)
	for index = 1, #assets do
		local asset = assets[index]
		local shape = shape_by_asset[asset]
		local sx, sy, sz, bytes = read_header(asset)
		check(sx == shape.x and sy == shape.y and sz == shape.z,
			"schematic size moved: " .. asset)
		check(bytes == shape.bytes, "schematic byte length moved: " .. asset)
		local key = (GRAVEWOOD[asset] and "mods/ITEMS/grug_trees/schematics/" or
			"mods/BASE/default/schematics/") .. asset
		check(manifest.input_bytes[key] == bytes,
			"schematic is not the one the R6 manifest pins: " .. asset)
		local verified = "frozen"
		if ok_ffi then
			local schematic = common.read_mts(asset_path(asset))
			local air = 0
			for y = 0, sy - 1 do
				local occupied = false
				for z = 0, sz - 1 do
					for x = 0, sx - 1 do
						if schematic.data[z * sy * sx + y * sx + x + 1].name ~= "air" then
							occupied = true
						end
					end
				end
				if occupied then break end
				air = air + 1
			end
			check(air == shape.air_base, "leading air slices moved: " .. asset)
			verified = "decoded"
		end
		emit(string.format("asset %s %dx%dx%d air_base=%d bytes=%d %s",
			asset, sx, sy, sz, shape.air_base, bytes, verified))
	end
	decoded = ok_ffi

	--
	-- 2. Every production template row through the real expander.
	--
	local function new_content(decorations, source_names)
		local refs, names, masks = {}, {}, {}
		local content = {}
		local contract = {ignore_cid = 65535, content_cids = {},
			content_kind_masks = masks}
		function contract.resolve_r6(content_ref, param2)
			return 1000 + content_ref, 1, 1, param2, masks[content_ref]
		end
		function content.content_contract() return contract end
		function content.decorations() return decorations end
		function content.content_ref(name)
			if refs[name] == nil then
				names[#names + 1] = name
				refs[name] = #names
				masks[#names] = 8
				contract.content_cids[#names] = 1000 + #names
			end
			return refs[name]
		end
		-- param2 rotation is not what this KAT measures; every node is declared
		-- rotation-free so a facedir trunk simply carries its param2 through.
		function content.param2_kind() return "none" end
		for index = 1, #source_names do content.content_ref(source_names[index]) end
		return content
	end

	local hash = {}
	function hash.frame(value)
		local text = tostring(value)
		return string.format("%d:%s;", #text, text)
	end
	-- Not cryptographic and never published: `r6_templates` only needs a stable
	-- 32-byte reduction to build the record digests this KAT does not compare.
	function hash.sha256_bytes(bytes)
		local state, parts = 2166136261, {}
		for index = 1, #bytes do
			state = (state * 16777619 + bytes:byte(index)) % 4294967296
		end
		for index = 1, 32 do
			state = (state * 1103515245 + 12345) % 4294967296
			parts[index] = string.char(math.floor(state / 65536) % 256)
		end
		return table.concat(parts)
	end
	function hash.hex(bytes)
		return (bytes:gsub(".", function(byte)
			return string.format("%02x", byte:byte())
		end))
	end
	function hash.digest() return hash.sha256_bytes("digest") end
	function hash.digest_count() return hash.sha256_bytes("count") end

	local function synthetic(asset)
		local shape = shape_by_asset[asset]
		local data = {}
		for z = 0, shape.z - 1 do
			for y = 0, shape.y - 1 do
				for x = 0, shape.x - 1 do
					local name = "air"
					if y >= shape.air_base and x == 0 and z == 0 then
						name = "kat:node"
					end
					data[z * shape.y * shape.x + y * shape.x + x + 1] =
						{name = name, prob = 254, param2 = 0, force_place = false}
				end
			end
		end
		local yslice = {}
		for y = 0, shape.y - 1 do yslice[y + 1] = {ypos = y, prob = 254} end
		return {size = {x = shape.x, y = shape.y, z = shape.z},
			yslice_prob = yslice, data = data}
	end

	local source = {}
	function source.read(asset)
		check(shape_by_asset[asset] ~= nil, "unfrozen schematic: " .. asset)
		if decoded then return common.read_mts(asset_path(asset)) end
		return synthetic(asset)
	end

	local rows = {}
	for index = 1, #manifest.decorations do
		rows[index] = manifest.decorations[index]
	end
	local module = templates_factory(hash, new_content(rows, {"kat:node"}), source)

	local anchored, sunk = 0, 0
	for index = 1, #rows do
		local row = rows[index]
		if row.kind == "template" then
			local shape = check(shape_by_asset[row.asset_or_node],
				"unfrozen schematic in the catalog: " .. row.asset_or_node)
			local sunk_rule = row.rule:find("offset_y_minus_4", 1, true) ~= nil
			for rotation = 0, 3 do
				local record = module.rotation(row.id, rotation)
				check(record.max_y - record.min_y + 1 == shape.y,
					"template vertical span moved at " .. row.id)
				if sunk_rule then
					check(record.min_y == -4,
						"authored sink moved at " .. row.id .. ": " .. record.min_y)
				else
					check(record.min_y + shape.air_base == 0,
						"template does not rest on its anchor at " .. row.id ..
						": min_y " .. record.min_y .. " with air base " ..
						shape.air_base)
				end
			end
			if sunk_rule then sunk = sunk + 1 else anchored = anchored + 1 end
			emit(string.format("row %s %s min_y=%d air_base=%d rule=%s",
				row.id, row.asset_or_node, module.rotation(row.id, 0).min_y,
				shape.air_base, row.rule))
		end
	end
	check(anchored >= 15 and sunk == 1,
		"template population differs: " .. anchored .. " anchored, " .. sunk ..
		" sunk")

	--
	-- 3. The rule itself, on shapes the catalog does not (yet) contain.
	--
	local function probe(size_y, air_base, rule)
		local definitions = {{id = "kat_probe", biomes = {"kat"},
			kind = "template", asset_or_node = "kat_probe.mts", host = "kat:soil",
			numerator = 1, denominator = 1,
			rule = rule .. ";center_xz;quarter_turn_rotation",
			settlement_class = 2}}
		local probe_source = {}
		function probe_source.read()
			local data, yslice = {}, {}
			for y = 0, size_y - 1 do
				yslice[y + 1] = {ypos = y, prob = 254}
				data[y + 1] = {name = y >= air_base and "kat:node" or "air",
					prob = 254, param2 = 0, force_place = false}
			end
			return {size = {x = 1, y = size_y, z = 1}, yslice_prob = yslice,
				data = data}
		end
		return templates_factory(hash, new_content(definitions, {"kat:node"}),
			probe_source)
	end
	for air_base = 0, 3 do
		local record = probe(5, air_base, "").rotation("kat_probe", 0)
		check(record.min_y == -air_base,
			"anchor does not consume " .. air_base .. " air slices")
		emit(string.format("rule air_base=%d min_y=%d", air_base, record.min_y))
	end
	local ok, message = pcall(probe, 5, 1, "offset_y_plus_1")
	check(not ok and tostring(message):find("offsets its own air base", 1, true),
		"a transcribed +1 offset on top of an air base did not fail closed")
	emit("rule offset_y_plus_1 over an air base fails closed")
	local plus_one = probe(5, 0, "offset_y_plus_1").rotation("kat_probe", 0)
	check(plus_one.min_y == 0,
		"offset_y_plus_1 is not the anchor itself: " .. plus_one.min_y)
	emit("rule offset_y_plus_1 without an air base min_y=0")

	emit(string.format("decoration anchor KAT PASS: %d assets, %d templates " ..
		"anchored, %d sunk, air_base %s", #assets, anchored, sunk,
		decoded and "decoded from the schematics" or "read from the frozen table"))
	return table.concat(out, "\n") .. "\n"
end
