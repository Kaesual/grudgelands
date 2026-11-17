-- Round 81 SPAWN: the merged spawn table as text (LuaJIT).
--
--   local text = dofile(repo .. "/tools/r81_spawn/merged_table.lua")(repo)
--
-- Loads every grug_mobs spawn row through tools/r24_density_xp/roster.lua
-- (the real spawn_policy.lua clock wrapper, the real zone data), hands each
-- prepared row to mobs:spawn_specific's ABM spec exactly as mobs/api.lua
-- builds it (defaults, mob_chance_multiplier 1) and runs the real
-- spawn_abms.lua on it. The text lists every row that registers (its
-- prepared fields; a function as "function <file>"), the retired rows per
-- mob, and each merged ABM (nodes, neighbours, y range, interval, chance,
-- each row's pick probability). Byte-identical text before and after a
-- change means the merged ABMs and every kept row are unchanged.
return function(repo)
	local roster = dofile(repo .. "/tools/r24_density_xp/roster.lua")(repo)
	assert(#roster.failed == 0, "mob files failed: " .. table.concat(roster.failed, "; "))
	local gm = roster.grug_mobs

	local function fmt(value)
		local kind = type(value)
		if kind == "function" then
			local src = debug.getinfo(value, "S").short_src or "?"
			return "function " .. (src:match("([^/]+)$") or src)
		elseif kind == "table" then
			local keys = {}
			for k in pairs(value) do keys[#keys + 1] = k end
			table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
			local parts = {}
			for _, k in ipairs(keys) do
				parts[#parts + 1] = (type(k) == "number" and "" or (tostring(k) .. "=")) ..
					fmt(value[k])
			end
			return "{" .. table.concat(parts, ",") .. "}"
		elseif kind == "number" then
			return string.format("%.17g", value)
		end
		return tostring(value)
	end

	-- spawn_abms.lua on a fake engine.
	local saved = {core = rawget(_G, "core"), mobs = rawget(_G, "mobs"),
		grug_mobs = rawget(_G, "grug_mobs")}
	local abms, loaded = {}, {}
	_G.core = {
		register_abm = function(spec) abms[#abms + 1] = spec end,
		register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
		log = function() end,
		get_item_group = function() return 0 end,
	}
	_G.mobs = {}
	_G.grug_mobs = gm
	dofile(repo .. "/mods/ENTITIES/grug_mobs/spawn_abms.lua")

	local lines, kept = {}, {}
	for i, def in ipairs(roster.rows) do
		-- mobs:spawn -> mobs:spawn_specific defaults (mobs/api.lua).
		local spec = {
			nodenames = def.nodes or {"group:soil", "group:stone"},
			neighbors = def.neighbors or {"air"},
			interval = def.interval or 30,
			chance = math.max(1, (def.chance or 5000) * 1),
			min_y = def.min_height or -31000,
			max_y = def.max_height or 31000,
			action = function() end,
		}
		local before = #lines
		if gm.spawn_row_kept(def.name, spec.max_y) then
			kept[#kept + 1] = "row " .. def.name .. " " .. fmt(def)
		end
		mobs.register_spawn_abm(spec, def.name)
		assert(#lines == before)
	end
	for _, fn in ipairs(loaded) do fn() end
	for name, value in pairs(saved) do rawset(_G, name, value) end

	lines[#lines + 1] = "kept rows " .. #kept
	for _, line in ipairs(kept) do lines[#lines + 1] = line end
	for _, abm in ipairs(abms) do
		lines[#lines + 1] = ("abm %s interval %s chance %s y %s..%s"):format(abm.label,
			fmt(abm.interval), fmt(abm.chance), fmt(abm.min_y), fmt(abm.max_y))
		lines[#lines + 1] = "  nodes " .. fmt(abm.nodenames)
		lines[#lines + 1] = "  neighbors " .. fmt(abm.neighbors)
	end
	return table.concat(lines, "\n") .. "\n", {rows = roster.rows, kept = kept, abms = abms,
		roster = roster}
end
