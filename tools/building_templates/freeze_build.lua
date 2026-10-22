-- The instrumented town build the exporter reads (Round 56 lane
-- FREEZE-TOWNS, building-template-format.md §8).
--
-- `build(src, town, mode)` runs one start town of the WP13 library in
-- `src` (a pre-freeze copy of `mods/MAPGEN/grug_mapgen/wp13`, where the
-- towns still call the building generators) and records:
--   * every write into the town's own buffer, in order, with the line of
--     the town file that caused it (the STEP) and the context the exporter
--     asked for (the house the decor kit is dressing);
--   * every stamp: the part as the generator built it, its anchor, turns,
--     the palette handles the generator was given, and the stamp result;
--   * every write into every part buffer, with the value it replaced
--     (`prev`), so an optional role knows what its cell held before it;
--   * the planting of every part buffer (Round 56 lane TREES, format doc
--     §4.2): the buffer as it stood when the part first planted a tree or
--     scattered undergrowth, the stems in planting order (the `dressing`
--     planter, its height argument and the buffer's tree spacing), the
--     undergrowth call, the cells planting wrote and the cells written
--     after it (`late`), and why the part cannot be a planted template
--     when its planting does not follow cells, trees, undergrowth, late;
--   * the town's PLOTS and SOCKETS (upvalues of the build function).
--
-- `mode` is "real" (the race palettes as they are) or "probe" (tagged
-- palettes: every palette handle binds every role to `<node>#<handle>:<role>`,
-- and every name predicate of the library strips the tag first, so the probe
-- build answers every question exactly as the real one does where it can).
--
-- LuaJIT only (it reads upvalues through `debug`); a tool, never shipped.

local M = {}

M.TAG = "#"

-- "<node>#h<n>:<role>" -> node, handle, role (nil for an untagged name).
function M.untag(name)
	if type(name) ~= "string" then return name end
	local real, handle, role = name:match("^(.-)#(h%d+):([%w_]+)$")
	if real then return real, handle, role end
	return name
end

local function strip(name)
	if type(name) ~= "string" then return name end
	local real = name:match("^(.-)#h%d+:[%w_]+$")
	return real or name
end
M.strip = strip

local function retag(real, tagged)
	local tag = type(tagged) == "string" and tagged:match("(#h%d+:[%w_]+)$")
	if tag then return real .. tag end
	return real
end

-- A lookup table keyed by node names answers a tagged name as its node.
local function strip_lookups(tbl)
	if type(tbl) ~= "table" or getmetatable(tbl) then return end
	setmetatable(tbl, {__index = function(t, key)
		if type(key) == "string" then
			local real = strip(key)
			if real ~= key then return rawget(t, real) end
		end
		return nil
	end})
end

local function upvalue(fn, wanted)
	for index = 1, 200 do
		local name, value = debug.getupvalue(fn, index)
		if name == nil then return nil end
		if name == wanted then return value end
	end
end

-- Every upvalue table of `fn` whose name is listed.
local function patch_upvalue_tables(fn, names)
	for _, wanted in ipairs(names) do
		local value = upvalue(fn, wanted)
		if type(value) == "table" then strip_lookups(value) end
	end
end

-- The statement of the town's build function that caused the current
-- write (the STEP), and the innermost line of the town file on the stack.
local function town_source_line(state)
	local inner
	for level = 3, 80 do
		local info = debug.getinfo(level, "Slf")
		if not info then break end
		if info.source == state.town_source then
			inner = inner or info.currentline
			-- a capital's plot builder is loaded once per district file, so
			-- its build function is matched by where it is defined
			if info.func == state.build_fn or (state.build_linedefined and
					info.linedefined == state.build_linedefined) then
				return info.currentline, inner
			end
		end
	end
	return nil, inner
end

local function shallow_copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for key, item in pairs(value) do out[key] = shallow_copy(item) end
	return out
end
M.copy = shallow_copy

-- Install the instrumented `dofile` for one run; returns the restore
-- function. `state.town_buf` is the first buffer the town file creates.
local function install(mode, state)
	-- "probe_role" (the capitals) tags every handle alike (`h0`): a capital's
	-- own code compares names across its handles (a hall floor laid by one
	-- handle against the paving another names), which a per-handle tag would
	-- answer differently; the exporter tells the handles apart by what each
	-- binds.
	local probe = mode == "probe" or mode == "probe_role"
	local role_only = mode == "probe_role"
	local saved_dofile = dofile
	local shared = {}
	state.shared = shared

	local function load_parts(path)
		local parts = saved_dofile(path)
		local Buffer = getmetatable(parts.buffer()).__index
		local orig_put = Buffer.put
		Buffer.put = function(self, x, y, z, name, param2)
			local p2 = param2 or parts.place_param2(name)
			if self == state.town_buf then
				local w = state.writes
				local line, inner = town_source_line(state)
				w[#w + 1] = {x = x, y = y, z = z, name = name, param2 = p2,
					line = line, inner = inner,
					context = state.context[#state.context]}
			else
				local key = x .. ":" .. y .. ":" .. z
				local prev = self.cell[key]
				local track = state.part_prev[self]
				if track == nil then
					track = {}
					state.part_prev[self] = track
				end
				track[key] = prev and {name = prev.name, param2 = prev.param2} or false
				local plant = state.planting[self]
				if plant and plant.active > 0 then
					plant.planted[key] = true
				elseif plant then
					plant.late[key] = (plant.late[key] or 0) + 1
					plant.late_count = plant.late_count + 1
				end
			end
			return orig_put(self, x, y, z, name, param2)
		end
		local orig_buffer = parts.buffer
		parts.buffer = function()
			local buf = orig_buffer()
			local info = debug.getinfo(2, "S")
			if state.town_buf == nil and info and info.source == state.town_source then
				state.town_buf = buf
			end
			return buf
		end
		local orig_stamp = parts.stamp
		parts.stamp = function(target, part, ox, oy, oz, turns)
			local caller = debug.getinfo(2, "Sl")
			local points = orig_stamp(target, part, ox, oy, oz, turns)
			if target == state.town_buf then
				local source, count = part.buffer:cells()
				local cells = {}
				for index = 1, count do
					local cell = source[index]
					cells[index] = {x = cell.x, y = cell.y, z = cell.z,
						name = cell.name, param2 = cell.param2}
				end
				local meta = {}
				for key, value in pairs(part) do
					if key ~= "buffer" and key ~= "points" and key ~= "w" and
							key ~= "d" then
						meta[key] = value
					end
				end
				state.stamps[#state.stamps + 1] = {part = part, cells = cells,
					prev = state.part_prev[part.buffer] or {},
					planting = state.planting[part.buffer],
					w = part.w, d = part.d, meta = meta,
					points = shallow_copy(part.points or {}),
					ox = ox, oy = oy, oz = oz, turns = turns % 4,
					line = town_source_line(state), result = points,
					generator = state.generator_of[part] or state.generator,
					caller = caller and (caller.short_src:match("[^/]+$") .. ":" ..
						caller.currentline),
					write_index = #state.writes}
				state.generator = nil
			end
			return points
		end
		if probe then
			for _, fn in ipairs({parts.param2_kind, parts.shaped, parts.tree_piece,
					parts.place_param2, parts.pane_connects, parts.full_solid,
					parts.wild_soil, parts.is_pane}) do
				patch_upvalue_tables(fn, {"PARAM2_KIND", "SHAPED", "TREE_PIECES",
					"PLACE_PARAM2", "PANE_CONNECTS", "FULL_SOLID", "WILD_SOIL",
					"PANE_NAMES", "PREFIX_KIND"})
			end
			patch_upvalue_tables(Buffer.put, {"TREE_PIECES"})
			local orig_canonical = parts.canonical_param2
			parts.canonical_param2 = function(name, param2)
				return orig_canonical(strip(name), param2)
			end
			local orig_base = parts.pane_base
			parts.pane_base = function(name)
				local base = orig_base(strip(name))
				return base and retag(base, name) or nil
			end
			-- `resolve_panes` with the tag kept on the settled name.
			parts.resolve_panes = function(buf)
				local order, count = buf:cells()
				local panes = {}
				for index = 1, count do
					local cell = order[index]
					local base = orig_base(strip(cell.name))
					if base then panes[#panes + 1] = {cell = cell, base = base} end
				end
				for index = 1, #panes do
					local cell, base = panes[index].cell, panes[index].base
					local any, total, connected = cell.param2, 0, {}
					for dir = 0, 3 do
						local dx, dz = parts.facedir_step(dir)
						local n = buf:at(cell.x + dx, cell.y, cell.z + dz)
						local hit = n ~= nil and parts.pane_connects(n.name)
						connected[dir] = hit
						if hit then any = dir total = total + 1 end
					end
					local tagged_flat = retag(base .. "_flat", cell.name)
					if total == 0 then
						buf:put(cell.x, cell.y, cell.z, tagged_flat, cell.param2)
					elseif total == 1 or (total == 2 and
							((connected[0] and connected[2]) or
								(connected[1] and connected[3]))) then
						buf:put(cell.x, cell.y, cell.z, tagged_flat, (any + 1) % 4)
					else
						buf:put(cell.x, cell.y, cell.z, retag(base, cell.name), 0)
					end
				end
				return #panes
			end
		end
		return parts
	end

	local function load_palette(path)
		local palettes = saved_dofile(path)
		local orig_new = palettes.new
		local copy = {}
		for key, value in pairs(palettes) do copy[key] = value end
		copy.new = function(race, overrides)
			local real = orig_new(race, overrides)
			local id = "h" .. (#state.handles + 1)
			local record = {id = id, race = race,
				overrides = shallow_copy(overrides), real = real}
			state.handles[#state.handles + 1] = record
			if not probe then
				state.handle_of[real] = id
				return real
			end
			local function tag(name, role)
				if name == nil then return nil end
				return name .. "#" .. (role_only and "h0" or id) .. ":" .. role
			end
			local handle = {race = race}
			function handle.node(role) return tag(real.node(role), role) end
			function handle.maybe(role) return tag(real.maybe(role), role) end
			function handle.variant(role, suffix)
				return tag(real.variant(role, suffix), role)
			end
			function handle.names(role)
				local out = {}
				for index, name in ipairs(real.names(role)) do
					out[index] = tag(name, role)
				end
				return out
			end
			state.handle_of[handle] = id
			record.probe = handle
			return handle
		end
		return copy
	end

	-- Every function of a generator module records the outermost call that
	-- built a part: `state.generator` (the start towns: the call before the
	-- next stamp) and `state.generator_of[part]` (the capitals, whose
	-- modules also hold helpers that build no part).
	local function wrap_generators(path, module_name)
		local loader = saved_dofile(path)
		return function(directory)
			local module = loader(directory)
			for name, fn in pairs(module) do
				if type(fn) == "function" then
					module[name] = function(palette, spec, ...)
						local outer = state.generator == nil
						local record = {make = name, module = module_name,
							palette = palette,
							roof = type(spec) == "table" and spec.roof_palette or nil,
							spec = shallow_copy(spec)}
						if outer then state.generator = record end
						state.depth = state.depth + 1
						local result = fn(palette, spec, ...)
						state.depth = state.depth - 1
						if state.depth == 0 and type(result) == "table" and
								result.buffer and not state.generator_of[result] then
							state.generator_of[result] = record
						end
						return result
					end
				end
			end
			return module
		end
	end

	local function wrap_decor(path)
		local loader = saved_dofile(path)
		return function(directory)
			local module = loader(directory)
			if probe then
				patch_upvalue_tables(module.is_window, {"WINDOW"})
				-- open ground is a set of names: it answers by the node
				local open_ground = module.open_ground
				module.open_ground = function(...)
					local set, plain = open_ground(...), {}
					for name in pairs(set) do plain[strip(name)] = true end
					strip_lookups(plain)
					return plain
				end
			end
			local dress_house = module.dress_house
			module.dress_house = function(brush, house, opts)
				state.context[#state.context + 1] = {kind = "house",
					id = house.room and house.room.id}
				local result = dress_house(brush, house, opts)
				state.context[#state.context] = nil
				return result
			end
			return module
		end
	end

	local function wrap_layout(path)
		local loader = saved_dofile(path)
		return function(directory)
			local module = loader(directory)
			if probe then patch_upvalue_tables(module.green, {"GREEN_ROUTINE"}) end
			return module
		end
	end

	-- The town trees are the town's (never template content), and the tree
	-- routine picks its species row by comparing names: it gets the real ones.
	local PLANTERS = {"tree", "broadleaf", "columnar", "acacia", "gravewood",
		"jungle_tree", "emergent"}
	-- The planting record of a part buffer, begun at its first planting call
	-- with a copy of the buffer (and of what each cell replaced).
	local function planting_of(buf)
		local plant = state.planting[buf]
		if plant then return plant end
		local snapshot, prev = {}, {}
		for key, cell in pairs(buf.cell) do
			snapshot[key] = {x = cell.x, y = cell.y, z = cell.z, name = cell.name,
				param2 = cell.param2}
		end
		for key, value in pairs(state.part_prev[buf] or {}) do prev[key] = value end
		plant = {snapshot = snapshot, prev = prev, stems = {}, planted = {}, late = {},
			late_count = 0, active = 0}
		state.planting[buf] = plant
		return plant
	end
	local function wrap_planting(module)
		local direct_grown = module.grown
		module.grown = function(buf, ...)
			local plant = buf ~= state.town_buf and state.planting[buf]
			if buf ~= state.town_buf and not (plant and plant.active > 0) then
				planting_of(buf).bad = "a part calls dressing.grown itself"
			end
			return direct_grown(buf, ...)
		end
		for _, name in ipairs(PLANTERS) do
			local planter = module[name]
			module[name] = function(buf, palette, x, z, height, ...)
				if buf == state.town_buf then return planter(buf, palette, x, z, height, ...) end
				local plant = planting_of(buf)
				if plant.active > 0 then return planter(buf, palette, x, z, height, ...) end
				if plant.undergrowth or plant.late_count > 0 then
					plant.bad = "a tree planted after the undergrowth or a later write"
				end
				if select("#", ...) > 0 then plant.bad = "a planter called with a top" end
				plant.stems[#plant.stems + 1] = {x = x, z = z, kind = name,
					height = height, spacing = buf.tree_spacing}
				plant.active = plant.active + 1
				local planted = planter(buf, palette, x, z, height)
				plant.active = plant.active - 1
				return planted
			end
		end
		local undergrowth = module.undergrowth
		module.undergrowth = function(buf, palette, x1, z1, x2, z2, density, patch)
			if buf == state.town_buf then
				return undergrowth(buf, palette, x1, z1, x2, z2, density, patch)
			end
			local plant = planting_of(buf)
			if plant.undergrowth or plant.late_count > 0 or patch then
				plant.bad = "a second undergrowth, one after a later write, or a patchy one"
			end
			plant.undergrowth = {x1, z1, x2, z2, density}
			plant.active = plant.active + 1
			local a, b = undergrowth(buf, palette, x1, z1, x2, z2, density, patch)
			plant.active = plant.active - 1
			return a, b
		end
	end

	local function wrap_dressing(path)
		local loader = saved_dofile(path)
		return function(directory)
			local module = loader(directory)
			if probe then
				local grown = module.grown
				module.grown = function(buf, palette, ...)
					local plain = {race = palette.race}
					function plain.node(role) return strip(palette.node(role)) end
					function plain.maybe(role) return strip(palette.maybe(role)) end
					return grown(buf, plain, ...)
				end
				-- a race whose undergrowth is the bone pile writes the fixed
				-- pieces of the skeleton set instead (a name comparison)
				local undergrowth_at = module.undergrowth_at
				module.undergrowth_at = function(buf, palette, x, y, z)
					if strip(palette.node("undergrowth")) == module.BONES then
						local plain = {race = palette.race}
						function plain.node(role) return strip(palette.node(role)) end
						return undergrowth_at(buf, plain, x, y, z)
					end
					return undergrowth_at(buf, palette, x, y, z)
				end
			end
			wrap_planting(module)
			return module
		end
	end

	_G.dofile = function(path)
		local name = path:match("([^/]+)%.lua$")
		if name == "dressing" then return wrap_dressing(path) end
		if name == "parts" then
			shared.parts = shared.parts or load_parts(path)
			return shared.parts
		elseif name == "palette" then
			shared.palette = shared.palette or load_palette(path)
			return shared.palette
		elseif name == "buildings" or name == "capitals" or name == "elf_parts" or
				name == "troll_parts" or name == "undead_parts" then
			return wrap_generators(path, name)
		elseif name == "decor_kit" then
			return wrap_decor(path)
		elseif name == "layout" then
			return wrap_layout(path)
		end
		return saved_dofile(path)
	end
	return function() _G.dofile = saved_dofile end
end

-- Build one town. Returns the record described above plus the blueprint.
function M.build(src, town, mode)
	local state = {mode = mode, writes = {}, stamps = {}, handles = {},
		handle_of = {}, part_prev = {}, planting = {}, context = {}, generator = nil,
		generator_of = {}, depth = 0,
		town_source = "@" .. src .. "/" .. town .. ".lua"}
	local restore = install(mode, state)
	local saved_dofile = dofile
	local ok, result = pcall(function()
		local loader = saved_dofile(src .. "/" .. town .. ".lua")
		local build = loader(src)
		state.build_fn = build
		state.plots = upvalue(build, "PLOTS")
		state.sockets = upvalue(build, "SOCKETS")
		state.upvalues = {}
		for index = 1, 200 do
			local name, value = debug.getupvalue(build, index)
			if name == nil then break end
			state.upvalues[name] = value
		end
		return build()
	end)
	restore()
	if not ok then error(town .. " (" .. mode .. "): " .. tostring(result), 0) end
	state.blueprint = result
	state.parts = state.shared.parts
	-- the town file's lines, for the step names
	state.lines = {}
	local file = assert(io.open(src .. "/" .. town .. ".lua", "rb"))
	for line in file:read("*a"):gmatch("([^\n]*)\n") do
		state.lines[#state.lines + 1] = line
	end
	file:close()
	return state
end

-- The source lines of a wp13 file, for the step names.
local function source_lines(path)
	local lines = {}
	local file = assert(io.open(path, "rb"))
	for line in file:read("*a"):gmatch("([^\n]*)\n") do
		lines[#lines + 1] = line
	end
	file:close()
	return lines
end

-- Build one blueprint of a capital (Round 56 lane FREEZE-CAPITALS): its
-- civic core (`which` = "core", the town file `<key>.lua`, the build
-- function its `M.core`) or its district plot number `which` in the order
-- of `<key>_districts.lua` M.plots() (the town file `<key>_plot.lua`, the
-- build function its `M.build`, which every district file loads a copy of).
-- The record is `M.build`'s, plus for a plot `row` (the roster row) and
-- `overrides` (what its `socket_overrides` answered, by socket id).
function M.build_capital(src, key, which, mode)
	local file = which == "core" and key .. ".lua" or key .. "_plot.lua"
	local state = {mode = mode, writes = {}, stamps = {}, handles = {},
		handle_of = {}, part_prev = {}, planting = {}, context = {}, generator = nil,
		generator_of = {}, depth = 0, overrides = {},
		town_source = "@" .. src .. "/" .. file}
	local lines = source_lines(src .. "/" .. file)
	if which ~= "core" then
		for number, line in ipairs(lines) do
			if line:find("^%s*function M%.build%(") then state.build_linedefined = number end
		end
		assert(state.build_linedefined, file .. " has no M.build")
	end
	local restore = install(mode, state)
	local wrapped_dofile = dofile
	local ok, result = pcall(function()
		if which == "core" then
			local module = wrapped_dofile(src .. "/" .. file)(src)
			state.build_fn = module.core
			state.plots = upvalue(module.core, "PLOTS")
			for _, row in ipairs(state.plots) do
				local overrides = row.socket_overrides
				if type(overrides) == "function" then
					row.socket_overrides = function(...)
						local answer = overrides(...)
						for id, value in pairs(answer) do
							state.overrides[id] = shallow_copy(value)
						end
						return answer
					end
				end
			end
			return module.core()
		end
		local districts = wrapped_dofile(src .. "/" .. key .. "_districts.lua")(src)
		local entry = districts.plots()[which]
		local row = upvalue(entry.build, "plot")
		assert(type(row) == "table" and row.id == entry.id, key .. ": no roster row for " ..
			tostring(entry.id))
		state.row, state.plot_id = row, entry.id
		local overrides = row.socket_overrides
		if type(overrides) == "function" then
			row.socket_overrides = function(...)
				local answer = overrides(...)
				for id, value in pairs(answer) do state.overrides[id] = shallow_copy(value) end
				return answer
			end
		end
		local blueprint = entry.build()
		row.socket_overrides = overrides
		return blueprint
	end)
	restore()
	if not ok then
		error(key .. " " .. tostring(which) .. " (" .. mode .. "): " .. tostring(result), 0)
	end
	state.blueprint = result
	state.parts = state.shared.parts
	state.lines = lines
	return state
end

-- One generator call in isolation with `race`'s palettes (tagged in the
-- probe mode): the part's cells, or nil and the error. `spec` is a copy of
-- the town's spec; its `roof_palette` is rebuilt from `roof_overrides`.
function M.generator(src, make, spec, race, main_overrides, roof_overrides, mode)
	local state = {mode = mode or "probe", writes = {}, stamps = {}, handles = {},
		handle_of = {}, part_prev = {}, planting = {}, context = {}, town_source = "@-",
		generator_of = {}, depth = 0}
	local restore = install(state.mode, state)
	local ok, result = pcall(function()
		local palettes = dofile(src .. "/palette.lua")
		local buildings = dofile(src .. "/buildings.lua")(src)
		local main = palettes.new(race, main_overrides)
		local copy = shallow_copy(spec)
		copy.roof_palette = roof_overrides and palettes.new(race, roof_overrides) or nil
		local part = buildings[make](main, copy)
		local source, count = part.buffer:cells()
		local cells = {}
		for index = 1, count do
			local cell = source[index]
			cells[index] = {x = cell.x, y = cell.y, z = cell.z, name = cell.name,
				param2 = cell.param2}
		end
		return {cells = cells, handles = state.handles, points = part.points,
			w = part.w, d = part.d}
	end)
	restore()
	if not ok then return nil, result end
	return result
end

return M
