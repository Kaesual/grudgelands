-- Acceptance for the protected civic-core boundary shared by all six capitals.
--
--     luajit -e 'io.write(dofile("tools/wp13/precinct_ring_kat.lua")("/abs/repo"))'
--     tools/bin/lua51 -e 'io.write(dofile("tools/wp13/precinct_ring_kat.lua")("/abs/repo"))'
--
-- An optional second argument is an engine probe's highcourt-core.tsv. It is
-- checked by the same walker, so the offline construction rule and the nodes
-- actually written by Luanti cannot drift apart unnoticed.
--
-- Plain Lua 5.1; the same bytes must run under LuaJIT and PUC 5.1.

return function(repo, engine_tsv)
	assert(type(repo) == "string" and repo:sub(1, 1) == "/",
		"precinct ring KAT requires an absolute repository root")
	local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
	local parts = dofile(wp13 .. "/parts.lua")
	local palettes = dofile(wp13 .. "/palette.lua")
	local lagoon = dofile(wp13 .. "/kezamba_lagoon.lua")()
	local precinct_ring = dofile(wp13 .. "/precinct_ring.lua")

	local RADIUS = 46
	local GATE_HALF = 6
	local function key(x, y, z) return x .. ":" .. y .. ":" .. z end
	local function is_gate(x, z)
		return (math.abs(x) == RADIUS and math.abs(z) <= GATE_HALF) or
			(math.abs(z) == RADIUS and math.abs(x) <= GATE_HALF)
	end
	local function is_corner(x, z)
		return math.abs(x) >= RADIUS - 2 and
			math.abs(z) >= RADIUS - 2
	end
	local function air(cell)
		return cell == nil or cell.name == "air"
	end

	local function generated_buffer(capital)
		local out = parts.buffer()
		for _, cell in ipairs(capital.core().cells) do
			out:put(cell.x, cell.y, cell.z, cell.name, cell.param2)
		end
		return out
	end

	local function expect(buf, label, x, y, z, wanted)
		local cell = buf:at(x, y, z)
		assert(cell and cell.name == wanted, label .. ": protected ring differs at " ..
			x .. "," .. y .. "," .. z .. ": wanted " .. wanted ..
			", found " .. tostring(cell and cell.name))
	end

	-- A corner drum/tower replaces five columns of the square ring. Its y=2
	-- outer course must be the capital's exact full-solid structural material:
	-- any non-air cell is not enough to prove a closed protected detour.
	local function expect_corner_detours(buf, label, material_at)
		for _, sx in ipairs({-1, 1}) do
			for _, sz in ipairs({-1, 1}) do
				local cx, cz = sx * 45, sz * 45
				for offset = -2, 2 do
					for _, point in ipairs({{cx + offset, cz - 2},
							{cx + 2, cz + offset}, {cx + offset, cz + 2},
							{cx - 2, cz + offset}}) do
						local material = type(material_at) == "function" and
							material_at(point[1], point[2]) or material_at
						assert(parts.full_solid(material), label ..
							": corner material is not full-solid: " .. material)
						local cell = buf:at(point[1], 2, point[2])
						assert(cell and cell.name == material, label ..
							": corner detour differs at " .. point[1] .. ",2," ..
							point[2] .. ": wanted " .. material .. ", found " ..
							tostring(cell and cell.name))
					end
				end
			end
		end
	end

	local dwarf = palettes.new("dwarf")
	local orc = palettes.new("orc")
	local undead = palettes.new("undead")
	local troll = palettes.new("troll")
	local dwarf_stone = dwarf.maybe("castle_wall") or dwarf.node("wall_accent")
	local orc_bank = orc.node("subsoil")
	local orc_crest = orc.node("ground_bare")
	local orc_tower = orc.maybe("wall_infill") or orc.node("foundation")
	local undead_stone = undead.maybe("castle_wall") or
		undead.node("wall_accent")
	local troll_log = troll.node("tree_log")

	local function same(buf, x, y, z, name)
		local cell = buf:at(x, y, z)
		return cell ~= nil and cell.name == name
	end
	local function standard_gate(buf, label, x, z, ring_column)
		local offset = (math.abs(x) == RADIUS) and z or x
		local support = math.abs(offset) == 3 or math.abs(offset) == 6
		if not support then
			assert(air(buf:at(x, 1, z)) and air(buf:at(x, 2, z)), label ..
				": authored gate passage is blocked at " .. x .. "," .. z)
		end
		-- Gatehouse supports can share masonry with a parapet. Every other one
		-- of the 52 band columns must differ from the capital's ring signature.
		assert(support or not ring_column(buf, x, z), label ..
			": ring material enters the authored gate at " .. x .. "," .. z)
	end
	local specs = {
		{
			id = "highcourt", style = "clipped_hedge",
			capital = dofile(wp13 .. "/highcourt.lua")(wp13),
			check = function(buf, label, x, z)
				expect(buf, label, x, 1, z, "default:bush_stem")
				expect(buf, label, x, 2, z, "default:bush_leaves")
				expect(buf, label, x, 3, z, "default:bush_leaves")
			end,
			gate = function(buf, label, x, z)
				standard_gate(buf, label, x, z, function(at, px, pz)
					return same(at, px, 1, pz, "default:bush_stem") and
						same(at, px, 2, pz, "default:bush_leaves") and
						same(at, px, 3, pz, "default:bush_leaves")
				end)
			end,
		},
		{
			id = "dur_brannoc", style = "masonry_and_corner_drums",
			capital = dofile(wp13 .. "/dur_brannoc.lua")(wp13),
			corners = true, corner_material = dwarf_stone,
			check = function(buf, label, x, z)
				expect(buf, label, x, 1, z, dwarf_stone)
				expect(buf, label, x, 2, z, dwarf_stone)
			end,
			gate = function(buf, label, x, z)
				standard_gate(buf, label, x, z, function(at, px, pz)
					return same(at, px, 1, pz, dwarf_stone) and
						same(at, px, 2, pz, dwarf_stone)
				end)
			end,
		},
		{
			id = "gor_drazhak", style = "earth_bank_and_stakes",
			capital = dofile(wp13 .. "/gor_drazhak.lua")(wp13),
			corners = true, corner_material = function(x, z)
				-- The bank's first column beyond each explicit five-column corner
				-- skip is the join into the closed tower perimeter.
				if (math.abs(x) == RADIUS or math.abs(z) == RADIUS) and
						not is_corner(x, z) then
					return orc_crest
				end
				return orc_tower
			end,
			check = function(buf, label, x, z)
				expect(buf, label, x, 1, z, orc_bank)
				expect(buf, label, x, 2, z, orc_crest)
			end,
			gate = function(buf, label, x, z)
				standard_gate(buf, label, x, z, function(at, px, pz)
					return same(at, px, 1, pz, orc_bank) and
						same(at, px, 2, pz, orc_crest)
				end)
			end,
		},
		{
			id = "nhal_veyr", style = "masonry_bars_and_corner_drums",
			capital = dofile(wp13 .. "/nhal_veyr.lua")(wp13),
			corners = true, corner_material = undead_stone,
			check = function(buf, label, x, z)
				expect(buf, label, x, 1, z, undead_stone)
				expect(buf, label, x, 2, z, undead_stone)
			end,
			gate = function(buf, label, x, z)
				standard_gate(buf, label, x, z, function(at, px, pz)
					return same(at, px, 1, pz, undead_stone) and
						same(at, px, 2, pz, undead_stone)
				end)
			end,
		},
		{
			id = "lethariel", style = "silverwood_hedge_or_mere",
			capital = dofile(wp13 .. "/lethariel.lua")(wp13),
			water = function(x, z)
				-- MERE[46] is {-35,46}; the authored one-column shore margin
				-- therefore replaces the north ring from x=-36 through x=46.
				return z == RADIUS and x >= -36 and x <= RADIUS
			end,
			check = function(buf, label, x, z)
				expect(buf, label, x, 1, z, "grug_trees:silverwood_tree")
				expect(buf, label, x, 2, z, "grug_trees:silverwood_leaves")
				expect(buf, label, x, 3, z, "grug_trees:silverwood_leaves")
			end,
			gate = function(buf, label, x, z)
				standard_gate(buf, label, x, z, function(at, px, pz)
					return same(at, px, 1, pz, "grug_trees:silverwood_tree") and
						same(at, px, 2, pz, "grug_trees:silverwood_leaves") and
						same(at, px, 3, pz, "grug_trees:silverwood_leaves")
				end)
			end,
		},
		{
			id = "kezamba", style = "junglewood_palisade_or_cenote",
			capital = dofile(wp13 .. "/kezamba.lua")(wp13),
			water = lagoon.lagoon,
			check = function(buf, label, x, z)
				for y = 1, 3 do
					expect(buf, label, x, y, z, troll_log)
				end
			end,
			gate = function(buf, label, x, z)
				-- Threshold posts, plants and planned water may occupy the band;
				-- the three-course palisade signature itself may not.
				assert(not (same(buf, x, 1, z, troll_log) and
					same(buf, x, 2, z, troll_log) and
					same(buf, x, 3, z, troll_log)), label ..
					": palisade enters the authored threshold at " .. x .. "," .. z)
			end,
		},
	}

	-- The production walker itself owns the four gate bands. Compare its exact
	-- default coordinate set with an independent perimeter enumeration so a
	-- widened or narrowed band cannot hide behind the generated-buffer checks.
	local walked = {}
	local expected_seen = {}
	local walked_count = precinct_ring.walk(function(x, z)
		walked[x .. ":" .. z] = true
	end)
	local expected_count = 0
	for offset = -RADIUS, RADIUS do
		for _, spot in ipairs({{offset, -RADIUS}, {RADIUS, offset},
				{offset, RADIUS}, {-RADIUS, offset}}) do
			local x, z = spot[1], spot[2]
			local mark = x .. ":" .. z
			if not is_gate(x, z) and not expected_seen[mark] then
				expected_seen[mark] = true
				expected_count = expected_count + 1
				assert(walked[mark], "precinct walker omits " .. mark)
			elseif is_gate(x, z) then
				assert(not walked[mark], "precinct walker enters gate band at " .. mark)
			end
		end
	end
	assert(walked_count == 316 and expected_count == 316,
		"precinct walker coordinate population differs")

	local function check_ring(buf, spec, label)
		local seen = {}
		local protected, gates, corners, water = 0, 0, 0, 0
		for offset = -RADIUS, RADIUS do
			for _, spot in ipairs({{offset, -RADIUS}, {RADIUS, offset},
					{offset, RADIUS}, {-RADIUS, offset}}) do
				local x, z = spot[1], spot[2]
				local mark = x .. ":" .. z
				if not seen[mark] then
					seen[mark] = true
					if is_gate(x, z) then
						spec.gate(buf, label, x, z)
						gates = gates + 1
					elseif spec.water and spec.water(x, z) then
						water = water + 1
					elseif spec.corners and is_corner(x, z) then
						corners = corners + 1
					else
						spec.check(buf, label, x, z)
						protected = protected + 1
					end
				end
			end
		end
		if spec.corner_material then
			expect_corner_detours(buf, label, spec.corner_material)
		end
		assert(protected + gates + corners + water == 368,
			label .. ": ring population differs")
		assert(gates == 52, label .. ": authored gate population differs")
		return protected, gates, corners, water
	end

	local report = {}
	report[#report + 1] = table.concat({"precinct_ring_walk", walked_count,
		368 - walked_count}, "\t") .. "\n"
	local buffers = {}
	for _, spec in ipairs(specs) do
		local buf = generated_buffer(spec.capital)
		buffers[spec.id] = buf
		local protected, gates, corners, water = check_ring(buf, spec, spec.id)
		report[#report + 1] = table.concat({"precinct_ring", spec.id,
			spec.style, protected, gates, corners, water}, "\t") .. "\n"
	end

	-- A later district writer is exactly the class of operation that exposed
	-- the playtest defect. Put one of its cells through the ring, require the
	-- checker to reject the result, then restore the original cell and prove
	-- that the same generated buffer is clean again.
	local highcourt = buffers.highcourt
	local x, y, z = 10, 2, -RADIUS
	local saved = assert(highcourt:at(x, y, z), "mutation target differs")
	local saved_name, saved_param2 = saved.name, saved.param2
	highcourt:put(x, y, z, parts.AIR, 0)
	local ok = pcall(check_ring, highcourt, specs[1],
		"highcourt district-overwrite mutation")
	assert(not ok, "district overwrite mutation escaped the ring KAT")
	highcourt:put(x, y, z, saved_name, saved_param2)
	check_ring(highcourt, specs[1], "highcourt restored")
	report[#report + 1] = "precinct_ring_mutation\trejected\trestored\n"

	-- Narrowing Kezamba's gate mask writes dry palisade columns into the
	-- thirteen-column threshold band. The gate-content checks must catch it.
	local kezamba_spec = specs[6]
	local kezamba_mutated = generated_buffer(kezamba_spec.capital)
	precinct_ring.walk(function(px, pz)
		for py = 1, 3 do kezamba_mutated:put(px, py, pz, troll_log) end
	end, {gate_half = 2, skip = lagoon.lagoon})
	ok = pcall(check_ring, kezamba_mutated, kezamba_spec,
		"kezamba gate-width mutation")
	assert(not ok, "gate-width mutation escaped the ring KAT")
	local kezamba_restored = generated_buffer(kezamba_spec.capital)
	check_ring(kezamba_restored, kezamba_spec, "kezamba gate width restored")
	buffers.kezamba = kezamba_restored
	report[#report + 1] = "precinct_ring_gate_width_mutation\trejected\trestored\n"

	-- A corner substitute is part of the protected circuit. Punch one exact
	-- material cell out of Dur Brannoc's south-west drum, then reconstruct it.
	local dur_spec = specs[2]
	local dur_mutated = generated_buffer(dur_spec.capital)
	dur_mutated:put(-47, 2, -47, parts.AIR, 0)
	ok = pcall(check_ring, dur_mutated, dur_spec, "dur brannoc corner mutation")
	assert(not ok, "corner-hole mutation escaped the ring KAT")
	local dur_restored = generated_buffer(dur_spec.capital)
	check_ring(dur_restored, dur_spec, "dur brannoc corner restored")
	buffers.dur_brannoc = dur_restored
	report[#report + 1] = "precinct_ring_corner_hole_mutation\trejected\trestored\n"

	if engine_tsv ~= nil then
		assert(type(engine_tsv) == "string" and engine_tsv:sub(1, 1) == "/",
			"engine buffer path must be absolute")
		local cells = {}
		local file = assert(io.open(engine_tsv, "r"))
		for line in file:lines() do
			if line:sub(1, 1) ~= "#" then
				local x0, y0, z0, name, param2 = line:match(
					"^(-?%d+)\t(-?%d+)\t(-?%d+)\t([^\t]+)\t(%d+)$")
				assert(x0, "engine buffer row differs: " .. line)
				cells[key(tonumber(x0), tonumber(y0), tonumber(z0))] =
					{name = name, param2 = tonumber(param2)}
			end
		end
		assert(file:close())
		local engine = {at = function(_, x0, y0, z0)
			return cells[key(x0, y0, z0)]
		end}
		local protected, gates, corners, water = check_ring(engine, specs[1],
			"highcourt engine buffer")
		report[#report + 1] = table.concat({"precinct_ring_engine",
			"highcourt", protected, gates, corners, water}, "\t") .. "\n"
	end

	return table.concat(report)
end
