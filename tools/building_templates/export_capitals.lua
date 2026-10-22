-- The freeze exporter of the six capitals (Round 56 lane FREEZE-CAPITALS,
-- docs/technical/building-template-format.md §8): build every capital's
-- civic core and every district plot from the pre-freeze building
-- generators, cut each stamped part (with the writes of its building-bound
-- steps) out of the finished blueprint into a building template, and write
-- one roster per capital (format doc §4).
--
-- Usage (normally through export.py, which extracts the source):
--   luajit tools/building_templates/export_capitals.lua <repo> <pre-freeze wp13 dir> <out dir>
-- writes <out dir>/templates/*.tpl and <out dir>/layouts/*.roster (both
-- directories must exist) and prints the freeze report.
--
-- How it differs from the start towns' `export.lua`:
--   * a capital is many blueprints (the core and one per district plot), so
--     every blueprint is built on its own (`freeze_build.build_capital`);
--   * the probe tags every palette handle alike (`probe_role`, a capital
--     compares names across its handles), so a role's channel is the first
--     of the placement's palettes that binds the role to the cell's node;
--   * the placements are algorithmic: no layout, a roster of the templates
--     and palettes each capital uses;
--   * every template carries `extent` (the part's non-air cells, x0 z0 x1
--     z1) and `top` (its highest cell) as meta: the plot builders measure
--     the part as the generator built it (format doc §4.1).
--
-- LuaJIT only; a tool, never shipped.

local repo, src, out = arg[1], arg[2], arg[3]
assert(repo and src and out, "usage: export_capitals.lua <repo> <wp13 source dir> <out dir>")
local fb = dofile(repo .. "/tools/building_templates/freeze_build.lua")
local lib = dofile(repo .. "/tools/building_templates/export_lib.lua")
local key3, sorted_keys = lib.key3, lib.sorted_keys

-- The six capitals.
--   palettes   the named palettes of the roster, in order: a name and the
--              override tables it merges (`<module>.<FIELD>`: `plot` the
--              capital's plot builder, `core` an upvalue of its `M.core`,
--              `elf_parts`, `troll_palette`); `town` is the plain race
--              palette (no overrides);
--   core       `stamp` the line of `<key>.lua` whose stamps are the core's
--              placements (one per PLOTS row), `steps` its building-bound
--              steps (lines of `M.core`, the rule assigning a write to a
--              building: `plot` names it), `meta` counts of a step's writes
--              the core publishes;
--   plot       `stamp` the line of `<key>_plot.lua` that stamps a plot's
--              building, `steps` the building-bound steps of `M.build` (the
--              rule `main`: the plot's own building), `extra` the stamps of
--              further placements a roster's dressing makes (by file:line, a
--              name for their ids).
local DECOR = "room and apron decor (decor.dress_rooms)"
local CAPITALS = {
	{key = "highcourt",
		palettes = {{"town"}, {"white", {"plot.WHITE"}}, {"slate", {"plot.SLATE"}},
			{"white_slate", {"plot.WHITE", "plot.SLATE"}}},
		core = {stamp = 518, text = "parts.stamp(buf, part, plot.x", steps = {
			{lines = {571, 583}, text = "belfry", plot = "chapel",
				name = "the belfry on the chapel's ridge and its bell beam"},
			{lines = {623, 624, 630}, text = "inlay_floor(", plot = "kings_hall",
				name = "the marble bands inlaid in the hall's floor"},
			{lines = {649}, text = "parts.floor_torch(", plot = "kings_hall",
				name = "the braziers between the hall's bays"},
			{lines = {681}, text = "rug_accent", plot = "kings_hall",
				name = "the hangings on the hall's aisle walls"},
		}, meta = {kings_hall = {nave_floor = {623, 624, 630}}}},
		plot = {stamp = 305, steps = {
			{lines = {417}, text = "decor.dress_rooms", name = DECOR},
		}}},
	{key = "dur_brannoc",
		palettes = {{"town"}, {"slate", {"plot.SLATE"}}},
		core = {stamp = 436, text = "parts.stamp(buf, part, plot.x", steps = {
			{lines = {526, 527, 532}, text = "inlay_floor(", plot = "kings_hall",
				name = "the stone-block bands inlaid in the hall's floor"},
			{lines = {545}, text = "parts.floor_torch(", plot = "kings_hall",
				name = "the braziers between the hall's bays"},
		}, meta = {kings_hall = {nave_floor = {526, 527, 532}}}},
		plot = {stamp = 320, steps = {
			{lines = {423}, text = "decor.dress_rooms", name = DECOR},
		}}},
	{key = "lethariel",
		palettes = {{"elf", {"elf_parts.GREEN"}},
			{"pale", {"elf_parts.GREEN", "elf_parts.PALE_ROOF", "elf_parts.PALE_STONE"}}},
		core = {stamp = 560, text = "parts.stamp(buf, part, plot.x", steps = {}},
		plot = {stamp = 257, steps = {
			{lines = {353}, text = "decor.dress_rooms", name = DECOR},
		}}},
	{key = "nhal_veyr",
		palettes = {{"town"}, {"crypt", {"plot.CRYPT"}}, {"vault", {"plot.VAULT"}},
			{"crypt_vault", {"plot.CRYPT", "plot.VAULT"}}},
		core = {stamp = 511, text = "parts.stamp(buf, part, plot.x", steps = {
			{lines = {599, 600, 605}, text = "inlay_floor(", plot = "mausoleum",
				name = "the grave-slab bands inlaid in the mausoleum's floor"},
			{lines = {618}, text = "parts.floor_torch(", plot = "mausoleum",
				name = "the braziers between the mausoleum's bays"},
		}, meta = {mausoleum = {nave_floor = {599, 600, 605}}}},
		plot = {stamp = 344, steps = {
			{lines = {469}, text = "decor.dress_rooms", name = DECOR},
		}, extra = {["nhal_veyr_district_lore.lua:214"] = "ruin"}}},
	{key = "gor_drazhak",
		palettes = {{"town"}, {"ors", {"plot.ORS"}}},
		core = {stamp = 461, text = "parts.stamp(buf, part, plot.x", steps = {
			{lines = {526}, text = "breastwork(", ring = true,
				name = "the breastworks over the dwellings' flat decks"},
			{lines = {562, 563, 568}, text = "inlay_floor(", plot = "warlord_hall",
				name = "the ors-stone bands inlaid in the hall's floor"},
			{lines = {581}, text = "parts.floor_torch(", plot = "warlord_hall",
				name = "the braziers between the hall's bays"},
		}, meta = {warlord_hall = {nave_floor = {562, 563, 568}}},
			meta_lowest = {parapet_columns = {526}}},
		plot = {stamp = 328, steps = {
			{lines = {333}, text = "breastwork(", name = "the breastwork over a flat deck"},
			{lines = {434}, text = "decor.dress_rooms", name = DECOR},
		}, meta_lowest = {parapet_columns = {333}}}},
	{key = "kezamba",
		palettes = {{"town"}, {"basalt", {"troll_palette.BASALT"}},
			{"water", {"troll_palette.WATER"}},
			{"basalt_water", {"troll_palette.BASALT", "troll_palette.WATER"}},
			{"vine", {"troll_palette.VINE"}}, {"crop", {"troll_palette.CROP"}}},
		core = {stamp = 472, text = "parts.stamp(buf, part, plot.x", steps = {}},
		plot = {stamp = 250, steps = {
			{lines = {330}, text = "decor.dress_rooms", name = DECOR},
		}}},
}

local RACES = {"dwarf", "human", "elf", "undead", "orc", "troll"}

local report = {}
local function say(...) report[#report + 1] = table.concat({...}) end

local palettes_module = dofile(src .. "/palette.lua")
local OPTIONAL = {}
for _, role in ipairs(palettes_module.optional) do OPTIONAL[role] = true end

-- --------------------------------------------------------------------------
-- named palettes
-- --------------------------------------------------------------------------

local function signature(race, overrides)
	local list = {}
	for _, role in ipairs(sorted_keys(overrides or {})) do
		list[#list + 1] = role .. "=" .. overrides[role]
	end
	return race .. "|" .. table.concat(list, ",")
end

-- The capital's named palettes: {name, race, overrides, signature}.
local function named_palettes(config, race, core_fn)
	local modules = {
		plot = dofile(src .. "/" .. config.key .. "_plot.lua")(src),
		elf_parts = dofile(src .. "/elf_parts.lua")(src),
		troll_palette = dofile(src .. "/troll_palette.lua")(),
	}
	local list, by_signature = {}, {}
	for _, row in ipairs(config.palettes) do
		local overrides
		for _, ref in ipairs(row[2] or {}) do
			local module, field = ref:match("^([%w_]+)%.([%w_]+)$")
			local tbl
			if module == "core" then
				for index = 1, 200 do
					local name, value = debug.getupvalue(core_fn, index)
					if name == nil then break end
					if name == field then tbl = value end
				end
			else
				tbl = modules[module] and modules[module][field]
			end
			assert(type(tbl) == "table", config.key .. ": no override table " .. ref)
			overrides = overrides or {}
			for role, node in pairs(tbl) do overrides[role] = node end
		end
		local entry = {name = row[1], race = race, overrides = overrides,
			signature = signature(race, overrides)}
		if by_signature[entry.signature] then
			error(config.key .. ": palettes " .. row[1] .. " and " ..
				by_signature[entry.signature].name .. " are the same")
		end
		by_signature[entry.signature] = entry
		list[#list + 1] = entry
	end
	return list, by_signature
end

-- --------------------------------------------------------------------------
-- labelling
-- --------------------------------------------------------------------------

-- Does `handle` bind `role` to `name`? true, or the family suffix.
local function binds(handle, role, name)
	local family = palettes_module.prefix_roles[role]
	if family then
		for _, suffix in ipairs(family) do
			if handle.variant(role, suffix) == name then return suffix end
		end
		return nil
	end
	if OPTIONAL[role] then return handle.maybe(role) == name or nil end
	local ok, bound = pcall(handle.node, role)
	return ok and bound == name or nil
end

local ROOF_ROLES = {roof_stair = true, roof_stair_outer = true,
	roof_stair_inner = true, roof_slab = true, roof_ridge = true}

-- A real value and its probe twin -> a legend entry. `candidates` are the
-- placement's palettes in order, each {channel, handle}; a roof role tries
-- the roof channel first (where main and roof bind it alike, the roof
-- palette is the one the generator roofed with).
local function label(lib_parts, name, param2, pname, candidates)
	assert(fb.strip(pname) == name, "probe twin differs: " .. tostring(pname) ..
		" for " .. tostring(name))
	local _, _, role = fb.untag(pname)
	if not role then
		if name == "air" then return {kind = "air"} end
		return {kind = "node", name = name, o = lib.orientation_of(name, param2)}
	end
	local order = candidates
	if ROOF_ROLES[role] then
		order = {}
		for _, candidate in ipairs(candidates) do
			if candidate.channel == "roof" then table.insert(order, 1, candidate)
			else order[#order + 1] = candidate end
		end
	end
	for _, candidate in ipairs(order) do
		local hit = binds(candidate.handle, role, name)
		if hit then
			return {kind = "role", role = role, channel = candidate.channel,
				variant = type(hit) == "string" and hit or nil,
				o = lib.orientation_of(name, param2)}
		end
	end
	error("no palette of the placement binds " .. role .. " to " .. name)
end

local function with_fallback(entry, prev_entry)
	if entry.kind ~= "role" or not OPTIONAL[entry.role] then return entry end
	if entry.role == "bed_fancy" then
		entry.fallback_entry = {kind = "role", role = "bed", variant = entry.variant,
			channel = entry.channel, o = entry.o}
	elseif prev_entry and prev_entry.kind == "air" then
		entry.fallback = "air"
	elseif prev_entry then
		local copy = {}
		for key, value in pairs(prev_entry) do copy[key] = value end
		copy.fallback, copy.fallback_entry = nil, nil
		entry.fallback_entry = copy
	end
	return entry
end

-- --------------------------------------------------------------------------
-- one blueprint
-- --------------------------------------------------------------------------

local placements_all = {}
local capitals_done = {}

-- The extent of a part's non-air cells and its highest cell, in its frame.
local function measure(cells)
	local x0, z0, x1, z1, top
	for _, cell in ipairs(cells) do
		if cell.name ~= "air" then
			x0 = x0 and math.min(x0, cell.x) or cell.x
			z0 = z0 and math.min(z0, cell.z) or cell.z
			x1 = x1 and math.max(x1, cell.x) or cell.x
			z1 = z1 and math.max(z1, cell.z) or cell.z
		end
		top = top and math.max(top, cell.y) or cell.y
	end
	return {x0, z0, x1, z1}, top
end

local function has_door_tag(tags)
	for _, tag in ipairs(tags or {}) do
		if tag == "door" then return true end
	end
	return false
end

-- Cut one blueprint (`which` = "core" or a plot index).
local function export_blueprint(config, cap, which)
	local real = fb.build_capital(src, config.key, which, "real")
	local probe = fb.build_capital(src, config.key, which, "probe_role")
	lib.parts = real.parts
	assert(#real.writes == #probe.writes, config.key .. " " .. tostring(which) ..
		": the probe build wrote " .. #probe.writes .. " cells, the real one " ..
		#real.writes)
	for index, write in ipairs(real.writes) do
		local other = probe.writes[index]
		assert(write.x == other.x and write.y == other.y and write.z == other.z and
			write.name == fb.strip(other.name) and write.param2 == other.param2,
			config.key .. " " .. tostring(which) .. ": the probe build differs at write " ..
			index)
	end
	local label_of = which == "core" and "core" or real.plot_id
	local part_file = which == "core" and config.key .. ".lua" or
		config.key .. "_plot.lua"
	local spec = which == "core" and config.core or config.plot

	-- the probe build's palette handles, named
	local handle_name = {}
	for _, record in ipairs(probe.handles) do
		local named = cap.by_signature[signature(record.race, record.overrides)]
		handle_name[record.id] = named
	end
	local function named_of(state, handle)
		local id = handle and state.handle_of[handle]
		if not id then return nil end
		local named = handle_name[id]
		if not named then
			local record
			for _, r in ipairs(probe.handles) do if r.id == id then record = r end end
			error(config.key .. " " .. label_of .. ": a palette the roster does not name: " ..
				signature(record.race, record.overrides))
		end
		return named
	end

	-- the step table
	local steps = {}
	for _, step in ipairs(spec.steps or {}) do
		for _, line in ipairs(step.lines) do
			local text = real.lines[line] or ""
			assert(text:find(step.text, 1, true) or
				(real.lines[step.lines[1]] or ""):find(step.text, 1, true),
				config.key .. ": " .. part_file .. " line " .. line .. " is not '" ..
				step.text .. "': " .. text)
			steps[line] = step
		end
	end

	-- the placements, in stamp order
	local placements, by_id = {}, {}
	local main_caller = part_file .. ":" .. spec.stamp
	local extra_count = {}
	for k, stamp in ipairs(real.stamps) do
		local id
		if stamp.caller == main_caller then
			if which == "core" then
				local row = real.plots[#placements + 1]
				assert(row, config.key .. ": more core stamps than plots")
				id = row.id
			else
				assert(#placements == 0, config.key .. " " .. label_of .. ": two plot stamps")
				id = real.plot_id
			end
		elseif config.plot.extra and config.plot.extra[stamp.caller] and which ~= "core" then
			local tag = config.plot.extra[stamp.caller]
			extra_count[tag] = (extra_count[tag] or 0) + 1
			id = real.plot_id .. "_" .. tag .. "_" .. extra_count[tag]
		end
		if id then
			local pstamp = probe.stamps[k]
			assert(pstamp and pstamp.caller == stamp.caller, "probe stamps differ")
			local generator = assert(pstamp.generator, id .. ": no generator")
			local main = assert(named_of(probe, generator.palette), id .. ": no main palette")
			local roof = named_of(probe, generator.roof)
			local pl = {capital = config.key, blueprint = label_of, id = id,
				race = cap.race, stamp = stamp, pstamp = pstamp, ox = stamp.ox, oy = stamp.oy,
				oz = stamp.oz, turns = stamp.turns, w = stamp.w, d = stamp.d,
				main = main, roof = roof ~= main and roof or nil,
				generator = generator, content = {}, points = {}, moved = {},
				steps = {}, channels = {}}
			pl.candidates = {{channel = nil, handle = main.real}}
			if pl.roof then
				pl.candidates[#pl.candidates + 1] = {channel = "roof", handle = pl.roof.real}
			end
			local fp = stamp.result.footprint[1]
			pl.fx1, pl.fz1 = fp.x, fp.z
			pl.fx2, pl.fz2 = fp.x + fp.w - 1, fp.z + fp.d - 1
			placements[#placements + 1] = pl
			by_id[id] = pl
		end
	end
	if which == "core" then
		assert(#placements == #real.plots, config.key .. ": " .. #placements ..
			" core stamps for " .. #real.plots .. " plots")
	end
	local main_pl = which ~= "core" and by_id[real.plot_id] or nil

	-- every named palette as a candidate for a building-bound write, after
	-- the placement's own
	local function bb_candidates(pl)
		local list = {}
		for _, c in ipairs(pl.candidates) do list[#list + 1] = c end
		for _, named in ipairs(cap.palettes) do
			if named ~= pl.main and named ~= pl.roof then
				list[#list + 1] = {channel = named.name, handle = named.real}
			end
		end
		return list
	end

	-- 1. every placement's own part
	for _, pl in ipairs(placements) do
		local cells, pcells = pl.stamp.cells, pl.pstamp.cells
		assert(#cells == #pcells, pl.id .. ": the probe part differs")
		for index, cell in ipairs(cells) do
			local twin = pcells[index]
			assert(twin.x == cell.x and twin.y == cell.y and twin.z == cell.z)
			local key = key3(cell.x, cell.y, cell.z)
			local prev, pprev = pl.stamp.prev[key], pl.pstamp.prev[key]
			local prev_entry
			if prev then
				prev_entry = label(real.parts, prev.name, prev.param2, pprev.name, pl.candidates)
			end
			pl.content[key] = {x = cell.x, y = cell.y, z = cell.z,
				entry = with_fallback(label(real.parts, cell.name, cell.param2, twin.name,
					pl.candidates), prev_entry),
				name = cell.name, param2 = cell.param2}
		end
		for group, list in pairs(pl.stamp.points) do pl.points[group] = fb.copy(list) end
		local extent, top = measure(cells)
		pl.meta = {}
		for key, value in pairs(pl.stamp.meta) do pl.meta[key] = value end
		pl.meta.extent, pl.meta.top = extent, top
	end

	-- 2. the building-bound writes, in write order
	local bb = {}
	local ring_at = 1
	for index, write in ipairs(real.writes) do
		local step = steps[write.line]
		if step then
			local pl = step.plot and by_id[step.plot] or main_pl
			if step.position then
				-- the placement whose footprint, grown by one node, holds it
				local best
				pl = nil
				for _, other in ipairs(placements) do
					local dx = math.max(other.fx1 - write.x, 0, write.x - other.fx2)
					local dz = math.max(other.fz1 - write.z, 0, write.z - other.fz2)
					local distance = math.max(dx, dz)
					if distance <= 1 then
						if best == nil or distance < best then pl, best = other, distance
						elseif distance == best then
							error(config.key .. ": the write at " .. key3(write.x, write.y,
								write.z) .. " is next to two buildings")
						end
					end
				end
			end
			if step.ring then
				-- a ring round the footprint, one node out, written building by
				-- building in stamp order: the first such placement from the
				-- one the last ring cell belonged to
				pl = nil
				for k = ring_at, #placements do
					local other = placements[k]
					local on_x = write.x == other.fx1 - 1 or write.x == other.fx2 + 1
					local on_z = write.z == other.fz1 - 1 or write.z == other.fz2 + 1
					local in_x = write.x >= other.fx1 - 1 and write.x <= other.fx2 + 1
					local in_z = write.z >= other.fz1 - 1 and write.z <= other.fz2 + 1
					if pl == nil and in_x and in_z and (on_x or on_z) then
						pl, ring_at = other, k
					end
				end
			end
			assert(pl, config.key .. " " .. label_of .. ": no building for the step " .. step.name)
			assert(index > pl.stamp.write_index, "a building-bound write before its stamp")
			local x, y, z = lib.to_part_frame(pl, write.x, write.y, write.z)
			local key = key3(x, y, z)
			local param2 = lib.unrotate_param2(write.name, write.param2, pl.turns)
			local before = pl.content[key]
			local entry = label(real.parts, write.name, param2, probe.writes[index].name,
				bb_candidates(pl))
			pl.content[key] = {x = x, y = y, z = z, name = write.name, param2 = param2,
				entry = with_fallback(entry, before and before.entry), step = step}
			pl.steps[step.name] = (pl.steps[step.name] or 0) + 1
			bb[index] = pl
		end
	end
	-- a count of a step's writes on the lowest course it wrote, per placement
	-- it wrote into (the columns of a breastwork ring, whose merlons stand a
	-- course higher)
	for key, lines in pairs(spec.meta_lowest or {}) do
		local lowest, counts = {}, {}
		for index, write in ipairs(real.writes) do
			for _, line in ipairs(lines) do
				local pl = write.line == line and bb[index]
				if pl then
					if lowest[pl] == nil or write.y < lowest[pl] then
						lowest[pl], counts[pl] = write.y, 0
					end
					if write.y == lowest[pl] then counts[pl] = counts[pl] + 1 end
				end
			end
		end
		for pl, count in pairs(counts) do pl.meta[key] = count end
	end
	for id, counts in pairs(spec.meta or {}) do
		local pl = by_id[id]
		for key, lines in pairs(counts) do
			local count = 0
			for _, write in ipairs(real.writes) do
				for _, line in ipairs(lines) do
					if write.line == line then count = count + 1 end
				end
			end
			pl.meta[key] = count
		end
	end

	-- 3. the town points derived from a building: the door-tagged sockets
	-- the town places within three nodes of a door, and the door-tagged
	-- socket overrides (a part's own socket moved onto its doorstep)
	local function part_frame_point(pl, x, y, z, face)
		local px, py, pz = lib.to_part_frame(pl, x, y, z)
		return px, py, pz, face and (face - pl.turns) % 4 or nil
	end
	local part_ids = {}
	for _, pl in ipairs(placements) do
		local row
		for _, r in ipairs(real.plots or {}) do if r.id == pl.id then row = r end end
		for _, entry in ipairs(pl.stamp.result.sockets or {}) do
			part_ids[entry.id] = pl
			local recast = row and row.recast and row.recast[entry.role]
			if recast and recast.from then
				part_ids[entry.id:gsub(recast.from, recast.to, 1)] = pl
			end
		end
	end
	for id, override in pairs(real.overrides) do
		if has_door_tag(override.tags) then
			local pl = part_ids[id]
			assert(pl, config.key .. ": the override " .. id .. " is no part's socket")
			local found
			for _, point in ipairs(pl.points.sockets or {}) do
				if point.id == id then found = point end
			end
			assert(found, id .. ": not in the part's points")
			-- the stamped socket, for the coordinates the override leaves
			local stamped
			for _, entry in ipairs(pl.stamp.result.sockets) do
				if entry.id == id then stamped = entry end
			end
			local x, y, z, face = part_frame_point(pl, override.x or stamped.x,
				override.y or stamped.y, override.z or stamped.z,
				override.face or stamped.face)
			found.x, found.y, found.z, found.face = x, y, z, face
			found.tags = fb.copy(override.tags)
			pl.moved_overrides = pl.moved_overrides or {}
			pl.moved_overrides[#pl.moved_overrides + 1] = id
			say("  - socket override ", id, " -> ", pl.id,
				": the part's socket on its doorstep, tagged door (derived from the placement)")
		end
	end
	if which == "core" then
		for _, socket in ipairs(real.blueprint.landmarks.sockets) do
			if not part_ids[socket.id] and has_door_tag(socket.tags) then
				local found, best, tie
				for _, pl in ipairs(placements) do
					for _, door in ipairs(pl.stamp.result.doors or {}) do
						local distance = math.max(math.abs(door.x - socket.x),
							math.abs(door.y - socket.y), math.abs(door.z - socket.z))
						if distance <= 3 then
							if best == nil or distance < best then
								found, best, tie = pl, distance, false
							elseif distance == best and pl ~= found then
								tie = true
							end
						end
					end
				end
				assert(not tie, config.key .. ": socket " .. socket.id .. " stands at two doors")
				if found then
					local x, y, z, face = part_frame_point(found, socket.x, socket.y,
						socket.z, socket.face)
					found.moved[#found.moved + 1] = {group = "sockets", id = socket.id,
						point = {group = "sockets", x = x, y = y, z = z, face = face,
							attrs = {{key = "id", value = socket.id}}}}
					say("  - socket ", socket.id, " -> ", found.id,
						": a door-tagged town socket within 3 nodes of its door (",
						best, " nodes)")
				end
			end
		end
	end

	-- 4. the town writes the town keeps inside each template's box
	for _, pl in ipairs(placements) do
		local x1, y1, z1, x2, y2, z2
		for _, cell in pairs(pl.content) do
			x1 = x1 and math.min(x1, cell.x) or cell.x
			y1 = y1 and math.min(y1, cell.y) or cell.y
			z1 = z1 and math.min(z1, cell.z) or cell.z
			x2 = x2 and math.max(x2, cell.x) or cell.x
			y2 = y2 and math.max(y2, cell.y) or cell.y
			z2 = z2 and math.max(z2, cell.z) or cell.z
		end
		pl.kept, pl.kept_steps = 0, {}
		for index = pl.stamp.write_index + 1, #real.writes do
			if not bb[index] then
				local write = real.writes[index]
				local ok, x, y, z = pcall(lib.to_part_frame, pl, write.x, write.y, write.z)
				if ok and x >= x1 and x <= x2 and y >= y1 and y <= y2 and z >= z1 and
						z <= z2 and pl.content[key3(x, y, z)] then
					pl.kept = pl.kept + 1
					local text = (real.lines[write.line] or "?"):gsub("^%s+", "")
					local name = "line " .. tostring(write.line) .. ": " .. text
					pl.kept_steps[name] = (pl.kept_steps[name] or 0) + 1
				end
			end
		end
	end

	-- the channels each placement's cells use
	for _, pl in ipairs(placements) do
		for _, cell in pairs(pl.content) do
			for _, entry in ipairs({cell.entry, cell.entry.fallback_entry}) do
				if entry.channel then pl.channels[entry.channel] = true end
			end
		end
		pl.stamp = {meta = pl.meta, result = pl.stamp.result, cells = pl.stamp.cells}
		pl.pstamp = nil
		placements_all[#placements_all + 1] = pl
	end
	return placements
end

-- --------------------------------------------------------------------------
-- main
-- --------------------------------------------------------------------------

say("# The freeze report of the capitals (tools/building_templates/export.py).")
say("# The pre-freeze source is the commit export.py names; every count is measured.")

local rosters = {}
for _, config in ipairs(CAPITALS) do
	local core_module = dofile(src .. "/" .. config.key .. ".lua")(src)
	local race = ({highcourt = "human", dur_brannoc = "dwarf", lethariel = "elf",
		nhal_veyr = "undead", gor_drazhak = "orc", kezamba = "troll"})[config.key]
	local list, by_signature = named_palettes(config, race, core_module.core)
	for _, named in ipairs(list) do named.real = palettes_module.new(race, named.overrides) end
	local cap = {key = config.key, race = race, palettes = list, by_signature = by_signature}
	say("")
	say("== ", config.key, " (", race, ")")
	say("points moved into templates:")
	local core = export_blueprint(config, cap, "core")
	local districts = dofile(src .. "/" .. config.key .. "_districts.lua")(src)
	local plots = {}
	for index = 1, #districts.plots() do
		for _, pl in ipairs(export_blueprint(config, cap, index)) do plots[#plots + 1] = pl end
	end
	say("building-bound steps (their writes are template content):")
	for _, part in ipairs({"core", "plot"}) do
		for _, step in ipairs(config[part].steps or {}) do
			say("  - ", part, ": ", step.name, " (", config.key, part == "plot" and "_plot" or "",
				".lua line ", table.concat(step.lines, ", "), ")")
		end
	end
	cap.core, cap.plots = core, plots
	rosters[#rosters + 1] = cap
	say("placements: ", #core, " in the core, ", #plots, " on the district plots")
end

-- render and merge identical templates
local templates, template_order = {}, {}
for _, pl in ipairs(placements_all) do
	local rendered = lib.render(pl)
	local body = rendered.head .. "\n" .. rendered.tail
	local found
	for _, name in ipairs(template_order) do
		if templates[name].body == body then found = templates[name] end
	end
	if not found then
		local name = pl.capital .. "_" .. pl.id
		-- a district plot sharing a core building's id (Lethariel's two
		-- mere shrines) names its template after the district plot
		if templates[name] then name = pl.capital .. "_plot_" .. pl.id end
		found = {name = name, body = body, rendered = rendered, users = {}, races = {}}
		assert(not templates[found.name], "two templates named " .. found.name)
		templates[found.name] = found
		template_order[#template_order + 1] = found.name
	end
	found.users[#found.users + 1] = pl
	found.races[pl.race] = true
	pl.template = found.name
end

local RACE_RANK = {}
for index, race in ipairs(RACES) do RACE_RANK[race] = index end
for _, name in ipairs(template_order) do
	local t = templates[name]
	local races = {}
	for race in pairs(t.races) do races[#races + 1] = race end
	table.sort(races, function(a, b) return RACE_RANK[a] < RACE_RANK[b] end)
	local users = {}
	for _, pl in ipairs(t.users) do users[#users + 1] = pl.capital .. ":" .. pl.id end
	lib.write_file(out .. "/templates/" .. name .. ".tpl", table.concat({
		"grudgelands-building-template 1",
		"# Frozen from the building generators (Round 56): " .. table.concat(users, ", "),
		"name " .. name,
		t.rendered.head,
		"races " .. table.concat(races, " "),
		t.rendered.tail, ""}, "\n"))
end

-- every placement and its template, per capital
for _, cap in ipairs(rosters) do
	say("")
	say("== ", cap.key, " placements (id -> template)")
	for _, list in ipairs({cap.core, cap.plots}) do
		for _, pl in ipairs(list) do
			say("  ", pl.blueprint, " ", pl.id, " -> ", pl.template)
		end
	end
end

-- the use line of a placement: its template and its palettes
local function use_key(pl)
	local line = {pl.template}
	local fields = {}
	if pl.main.name ~= "town" then fields[#fields + 1] = "main=" .. pl.main.name end
	if pl.channels.roof then fields[#fields + 1] = "roof=" .. pl.roof.name end
	for _, channel in ipairs(sorted_keys(pl.channels)) do
		if channel ~= "roof" then fields[#fields + 1] = channel .. "=" .. channel end
	end
	return table.concat(line, " "), table.concat(fields, " ")
end

for _, cap in ipairs(rosters) do
	local used = {town = true}
	local uses, use_order = {}, {}
	for _, list in ipairs({cap.core, cap.plots}) do
		for _, pl in ipairs(list) do
			local template, fields = use_key(pl)
			local key = template .. (fields ~= "" and (" " .. fields) or "")
			if not uses[key] then
				uses[key] = {count = 0, template = template, fields = fields}
				use_order[#use_order + 1] = key
			end
			uses[key].count = uses[key].count + 1
			used[pl.main.name] = true
			if pl.channels.roof then used[pl.roof.name] = true end
			for channel in pairs(pl.channels) do
				if channel ~= "roof" then used[channel] = true end
			end
		end
	end
	local lines = {"grudgelands-town-roster 1",
		"# The templates and palettes the capital's code places (frozen in Round 56):",
		"# the civic core's buildings and every district plot's.",
		"town " .. cap.key, "race " .. cap.race, ""}
	for _, named in ipairs(cap.palettes) do
		do
			local line = {"palette", named.name, "race=" .. cap.race}
			for _, role in ipairs(sorted_keys(named.overrides or {})) do
				line[#line + 1] = role .. "=" .. named.overrides[role]
			end
			lines[#lines + 1] = table.concat(line, " ")
		end
	end
	lines[#lines + 1] = ""
	for _, key in ipairs(use_order) do
		local use = uses[key]
		lines[#lines + 1] = "use " .. use.template .. " count=" .. use.count ..
			(use.fields ~= "" and (" " .. use.fields) or "")
	end
	lines[#lines + 1] = ""
	lib.write_file(out .. "/layouts/" .. cap.key .. ".roster", table.concat(lines, "\n"))
end

-- the per-template report
say("")
say("== templates: ", #template_order, " for ", #placements_all, " placements")
local shared, cells_total, role_total, node_total = 0, 0, 0, 0
for _, name in ipairs(template_order) do
	local t = templates[name]
	if #t.users > 1 then shared = shared + 1 end
	cells_total = cells_total + t.rendered.cells
	role_total = role_total + t.rendered.role_cells
	node_total = node_total + t.rendered.node_cells
end
say("templates shared by several placements: ", shared)
say("cells ", cells_total, " (role ", role_total, ", fixed-node ", node_total,
	", force-air ", cells_total - role_total - node_total, ")")
for _, name in ipairs(template_order) do
	local t, r = templates[name], templates[name].rendered
	local users = {}
	for _, pl in ipairs(t.users) do users[#users + 1] = pl.capital .. ":" .. pl.id end
	say("")
	say("-- ", name, " (", table.concat(users, ", "), ")")
	say("   cells ", r.cells, ", legend ", r.legend, ", role cells ", r.role_cells,
		", fixed-node cells ", r.node_cells, ", force-air cells ",
		r.cells - r.role_cells - r.node_cells, ", race switches 0, undecided 0")
	for _, pl in ipairs(t.users) do
		local list = {}
		for _, step in ipairs(sorted_keys(pl.steps)) do
			list[#list + 1] = step .. " " .. pl.steps[step]
		end
		if #list > 0 then say("   building-bound writes (", pl.id, "): ", table.concat(list, "; ")) end
		if pl.kept > 0 then
			say("   town writes kept in its box (", pl.id, "): ", pl.kept)
			for _, step in ipairs(sorted_keys(pl.kept_steps)) do
				say("     ", pl.kept_steps[step], "x ", step)
			end
		end
	end
end

-- The templates read back through the game's own loader, with the roster's
-- palettes: every placement's part must be exactly the cells cut for it.
local game_wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local loader = dofile(game_wp13 .. "/templates.lua")(game_wp13)
local game_palettes = dofile(game_wp13 .. "/palette.lua")
local parsed = {}
for _, name in ipairs(template_order) do
	local path = out .. "/templates/" .. name .. ".tpl"
	local file = assert(io.open(path, "rb"))
	parsed[name] = loader.parse_template(file:read("*a"), path, name)
	file:close()
end
for _, cap in ipairs(rosters) do
	local handles = {}
	for _, named in ipairs(cap.palettes) do
		handles[named.name] = game_palettes.new(cap.race, named.overrides)
	end
	for _, list in ipairs({cap.core, cap.plots}) do
		for _, pl in ipairs(list) do
			local main = handles[pl.main.name]
			local function palette_of(channel)
				if channel == nil then return main end
				if channel == "roof" then return handles[pl.roof.name] end
				return assert(handles[channel], "no palette " .. channel)
			end
			local got = lib.cells_of(loader.part(parsed[pl.template], pl.id, pl.race,
				palette_of).buffer)
			for key, cell in pairs(pl.content) do
				assert(got[key] == cell.name .. "/" .. cell.param2, pl.template .. " for " ..
					pl.capital .. ":" .. pl.id .. ": the cell " .. key .. " reads back as " ..
					tostring(got[key]) .. ", not " .. cell.name .. "/" .. cell.param2)
			end
			for key in pairs(got) do
				assert(pl.content[key], pl.template .. ": an extra cell " .. key)
			end
		end
	end
end
say("")
say("every template reads back through wp13/templates.lua as exactly the cells",
	" cut for each of its placements")

print(table.concat(report, "\n"))
