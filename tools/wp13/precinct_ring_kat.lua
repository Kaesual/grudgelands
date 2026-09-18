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

	-- Dur Brannoc's and Nhal Veyr's round corner drums replace five columns
	-- of the square parapet. Their y=2 outer course is a closed 5x5 perimeter,
	-- so this is a protected detour rather than an opening in the boundary.
	local function expect_corner_drums(buf, label)
		for _, sx in ipairs({-1, 1}) do
			for _, sz in ipairs({-1, 1}) do
				local cx, cz = sx * 45, sz * 45
				for offset = -2, 2 do
					for _, point in ipairs({{cx + offset, cz - 2},
							{cx + 2, cz + offset}, {cx + offset, cz + 2},
							{cx - 2, cz + offset}}) do
						assert(not air(buf:at(point[1], 2, point[2])), label ..
							": corner drum opens at " .. point[1] .. ",2," ..
							point[2])
					end
				end
			end
		end
	end

	local dwarf = palettes.new("dwarf")
	local orc = palettes.new("orc")
	local undead = palettes.new("undead")
	local troll = palettes.new("troll")
	local specs = {
		{
			id = "highcourt", style = "clipped_hedge",
			capital = dofile(wp13 .. "/highcourt.lua")(wp13),
			check = function(buf, label, x, z)
				expect(buf, label, x, 1, z, "default:bush_stem")
				expect(buf, label, x, 2, z, "default:bush_leaves")
				expect(buf, label, x, 3, z, "default:bush_leaves")
			end,
		},
		{
			id = "dur_brannoc", style = "masonry_and_corner_drums",
			capital = dofile(wp13 .. "/dur_brannoc.lua")(wp13),
			corners = true, corner_check = expect_corner_drums,
			check = function(buf, label, x, z)
				local stone = dwarf.maybe("castle_wall") or dwarf.node("wall_accent")
				expect(buf, label, x, 1, z, stone)
				expect(buf, label, x, 2, z, stone)
			end,
		},
		{
			id = "gor_drazhak", style = "earth_bank_and_stakes",
			capital = dofile(wp13 .. "/gor_drazhak.lua")(wp13),
			corners = true,
			check = function(buf, label, x, z)
				if is_corner(x, z) then
					assert(not air(buf:at(x, 1, z)) and not air(buf:at(x, 2, z)),
						label .. ": corner tower opens at " .. x .. "," .. z)
					return
				end
				expect(buf, label, x, 1, z, orc.node("subsoil"))
				expect(buf, label, x, 2, z, orc.node("ground_bare"))
			end,
		},
		{
			id = "nhal_veyr", style = "masonry_bars_and_corner_drums",
			capital = dofile(wp13 .. "/nhal_veyr.lua")(wp13),
			corners = true, corner_check = expect_corner_drums,
			check = function(buf, label, x, z)
				local stone = undead.maybe("castle_wall") or
					undead.node("wall_accent")
				expect(buf, label, x, 1, z, stone)
				expect(buf, label, x, 2, z, stone)
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
		},
		{
			id = "kezamba", style = "junglewood_palisade_or_cenote",
			capital = dofile(wp13 .. "/kezamba.lua")(wp13),
			water = lagoon.lagoon,
			check = function(buf, label, x, z)
				for y = 1, 3 do
					expect(buf, label, x, y, z, troll.node("tree_log"))
				end
			end,
		},
	}

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
						gates = gates + 1
					elseif spec.water and spec.water(x, z) then
						water = water + 1
					elseif spec.corners and is_corner(x, z) then
						corners = corners + 1
						if not spec.corner_check then
							spec.check(buf, label, x, z)
						end
					else
						spec.check(buf, label, x, z)
						protected = protected + 1
					end
				end
			end
		end
		if spec.corner_check then spec.corner_check(buf, label) end
		assert(protected + gates + corners + water == 368,
			label .. ": ring population differs")
		assert(gates == 52, label .. ": authored gate population differs")
		return protected, gates, corners, water
	end

	local report = {}
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
