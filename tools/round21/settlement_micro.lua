-- Small production geometry cases; no terrain sessions, worlds or populations.
return function(repo)
	local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
	local palettes = dofile(dir .. "/palette.lua")
	local avenue = dofile(dir .. "/avenue.lua")(dir)
	local streets = dofile(dir .. "/street_plan.lua")(dir)
	local approach = dofile(dir .. "/plot_approach.lua")
	local palette = palettes.new("troll")
	local function key(c) return c.x .. ":" .. c.y .. ":" .. c.z end
	local function cells(runs, height, split)
		local out = {}
		for _, run in ipairs(runs) do
			local intervals = {{run.from, run.to}}
			if split and run.from < 0 and run.to >= 0 then intervals = {{run.from, -1}, {0, run.to}} end
			for _, interval in ipairs(intervals) do
				local spec = {}
				for k, v in pairs(run) do spec[k] = v end
				spec.from, spec.to, spec.lamp_phase = interval[1], interval[2], run.lamp_phase or run.from
				local piece = avenue.run(palette, spec, height)
				for _, cell in ipairs(piece.cells) do
					local k = key(cell)
					if not out[k] then out[k] = cell.name .. ":" .. cell.param2 end
				end
			end
		end
		return out
	end
	local count = 0
	for _, kind in ipairs({"L", "T", "X"}) do
		local runs = streets.attach({
			{id = "a", axis = "x", at = 0, from = -12, to = kind == "L" and 0 or 12},
			{id = "b", axis = "z", at = 0, from = kind == "X" and -12 or 0, to = 12},
		})
		local function height() return 3 end
		local whole, split = cells(runs, height), cells(runs, height, true)
		for k, v in pairs(whole) do assert(split[k] == v, "split " .. kind .. " " .. k) end
		for k, v in pairs(split) do assert(whole[k] == v, "whole " .. kind .. " " .. k) end
		for z = -2, 2 do for x = -2, 2 do
			assert(whole[x .. ":3:" .. z], kind .. " missing junction quarter")
			for y = 4, 6 do assert(not whole[x .. ":" .. y .. ":" .. z], "blocked junction") end
		end end
		count = count + 1
	end
	local sloped_runs = streets.attach({
		{id = "slope_a", axis = "x", at = 0, from = -12, to = 0},
		{id = "slope_b", axis = "z", at = 0, from = 0, to = 12},
	})
	local function hill(x, z) return 4 + math.floor(x / 5) + math.floor(z / 7) end
	local slope, sliced = cells(sloped_runs, hill), cells(sloped_runs, hill, true)
	for k, v in pairs(slope) do assert(sliced[k] == v, "sloped split mismatch") end
	for k, v in pairs(sliced) do assert(slope[k] == v, "sloped split excess") end
	local joint_y
	for z = -2, 2 do for x = -2, 2 do
		local top
		for y = -10, 30 do
			local value = slope[x .. ":" .. y .. ":" .. z]
			if value and not value:match("^air:") then top = y end
		end
		assert(top, "sloped corner missing")
		joint_y = joint_y or top
		assert(top == joint_y, "junction is not one flat landing")
	end end
	local landing = {id = "landing", axis = "x", at = 0, from = 0, to = 20,
		landings = {{p = 0, y = 6}}}
	local cut = avenue.run(palette, landing, function(x) return x < 4 and 9 or 6 end)
	local top = {}
	for _, cell in ipairs(cut.cells) do
		if cell.z == 0 and cell.name ~= "air" then top[cell.x] = math.max(top[cell.x] or -1000, cell.y) end
	end
	assert(top[0] == 6, "core landing is not pinned")
	for x = 1, 20 do assert(math.abs(top[x] - top[x - 1]) <= 1, "landing step") end
	local fitted = approach.new({{min_x = -4, max_x = 4, min_z = 0, max_z = 8,
		entry_x = 0, y = 6}}, {{id = "street", axis = "x", at = -6, from = -12, to = 12, junctions = {}}})
	for _, natural in ipairs({2, 10}) do
		assert(fitted.surface(5, 4, natural) == 6, "inner collar not flush")
		assert(fitted.surface(13, 4, natural) == natural, "collar escaped bound")
		for z = -3, -1 do assert(fitted.surface(0, z, natural) == 6, "entrance disconnected") end
	end
	fitted.plots[1].road_y = 8
	assert(fitted.surface(0, -4, 2) == 2 and fitted.surface(0, -1, 2) == 7,
		"approach overwrote road or lost slope")
	assert(fitted.surface(4, -4, 2) == 2, "collar buried carriageway")
	local ramp = dofile(dir .. "/kezamba_ramp.lua")(dir)
	local gate = dofile(dir .. "/kezamba_gate.lua")(dir)
	local spec = {id = "gate", axis = "x", at = 0, from = 0, to = 16, width = 5, reach = 40}
	local ground = function(x) return x < 8 and 8 or 3 end
	local piece = ramp.run(palette, spec, ground, avenue.run(palette, spec, ground), {gate = 16})
	local tops = {}
	for _, cell in ipairs(piece.cells) do
		if cell.z == 0 and cell.name ~= "air" then tops[cell.x] = math.max(tops[cell.x] or -1000, cell.y) end
	end
	assert(tops[15] == 3 and tops[16] == 3, "gate landing not flat")
	local threshold = gate.run(palette, {axis = "x", at = 0, from = 15, to = 17}, ground, {centre = 16})
	for _, cell in ipairs(threshold.cells) do
		assert(not (math.abs(cell.z) <= 2 and cell.y <= 6), "threshold overwrites ramp")
	end
	return "round21_settlement\tjunctions=" .. count .. "\tsplit=equal\tlandings=2\tcollars=cut+fill\n"
end
