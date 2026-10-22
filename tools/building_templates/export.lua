-- The freeze exporter (Round 56 lane FREEZE-TOWNS,
-- docs/technical/building-template-format.md §8): build every start town
-- from the pre-freeze building generators and cut each building out of the
-- finished town into a building template, with one layout per town.
--
-- Usage (normally through export.py, which extracts the source):
--   luajit tools/building_templates/export.lua <repo> <pre-freeze wp13 dir> <out dir>
-- writes <out dir>/templates/*.tpl, <out dir>/layouts/*.layout (both
-- directories must exist) and prints the
-- freeze report (the building-bound steps, the points moved, per template its
-- cells, legend, roles, fixed nodes and the town writes kept in its box).
--
-- LuaJIT only; a tool, never shipped.

local repo, src, out = arg[1], arg[2], arg[3]
assert(repo and src and out, "usage: export.lua <repo> <wp13 source dir> <out dir>")
local fb = dofile(repo .. "/tools/building_templates/freeze_build.lua")
local lib = dofile(repo .. "/tools/building_templates/export_lib.lua")
local key3, sorted_keys, to_part_frame = lib.key3, lib.sorted_keys, lib.to_part_frame
local unrotate_param2, orientation_of = lib.unrotate_param2, lib.orientation_of
local DIR_FACE, render, write_file, cells_of = lib.DIR_FACE, lib.render, lib.write_file,
	lib.cells_of
local parts -- the pre-freeze parts module (the same rotation the game runs)

local RACES = {"dwarf", "human", "elf", "undead", "orc", "troll"}
local RACE_RANK = {}
for index, race in ipairs(RACES) do RACE_RANK[race] = index end

-- The six start towns. `palettes` names every palette handle the town makes
-- besides its own (h1, called `town` where a layout must name it), in the
-- order the town creates them. `steps` are the BUILDING-BOUND steps (format
-- doc §8): the statements of the town's build function (line, and a piece of
-- its text the exporter checks) whose writes go into the template, with the
-- rule that says which building a write belongs to:
--   house     the house the decor kit is dressing (its room's id);
--   plot      the named placement;
--   position  the placement whose footprint, grown by one node, holds the
--             cell (a prop hung on a wall stands one node outside it).
-- `inside` names the hand-set destination points the town places for a
-- building (taken from the town's own destinations).
local TOWNS = {
	{id = "hearthpine", palettes = {h2 = "slate"}, steps = {
		{line = 379, text = "decor.dress_rooms", assign = "house", kept = true,
			name = "room and apron decor (decor.dress_rooms)",
			why = "the paved approaches (line 261) come after it and clear the " ..
				"headroom of nine touches it stands on them"},
	}},
	{id = "dawnmere", palettes = {h2 = "tile"}, steps = {
		{line = 372, text = "parts.stamp(buf, belfry", assign = "plot",
			plot = "meeting_hall", name = "the belfry on the meeting hall's ridge"},
		{line = 462, text = 'wall_prop("barn_wheel"', assign = "position",
			name = "a cart wheel on the barn wall"},
		{line = 463, text = 'wall_prop("barn_wheel"', assign = "position",
			name = "a cart wheel on the barn wall"},
		{line = 464, text = 'wall_prop("inn_wheel"', assign = "position",
			name = "a cart wheel on the inn gable"},
		{line = 465, text = 'wall_prop("inn_wheel"', assign = "position",
			name = "a cart wheel on the inn gable"},
		{line = 532, text = 'paved_prop("crates"', assign = "position",
			name = "the crates stacked indoors (barn, meeting hall)"},
		{line = 571, text = "decor.dress_rooms", assign = "house",
			name = "room and apron decor (decor.dress_rooms)"},
	}},
	{id = "silverleaf", palettes = {h2 = "pale"}, steps = {
		{line = 389, text = "parts.stamp(buf, spire", assign = "plot",
			plot = "moon_shrine", name = "the spire on the shrine's ridge"},
		{line = 430, text = "lantern_under(", assign = "position",
			name = "the lanterns under the covered market's bays"},
		{line = 439, text = "parts.beacon(", assign = "position",
			name = "the gable lights of the four houses"},
		{line = 546, text = "decor.dress_rooms", assign = "house",
			name = "room and apron decor (decor.dress_rooms)"},
	}},
	{id = "stillgrave", palettes = {h2 = "crypt"}, steps = {
		{line = 588, text = "decor.dress_rooms", assign = "house",
			name = "room and apron decor (decor.dress_rooms)"},
	}},
	{id = "sunscar", palettes = {}, steps = {
		{line = 479, text = "parts.wall_torch(buf, palette, cresset", assign = "position",
			name = "the two cressets in the round lodge"},
		{line = 520, text = "buf:put(brazier[1], 9", assign = "position",
			name = "the brazier stands on the warlord hall's deck"},
		{line = 521, text = "parts.floor_torch(buf, palette, brazier", assign = "position",
			name = "the brazier fires on the warlord hall's deck"},
		{line = 687, text = 'wall_prop("hall_wheel_west"', assign = "position",
			name = "a wagon wheel on the warlord hall"},
		{line = 691, text = 'wall_prop("hall_wheel_north"', assign = "position",
			name = "a wagon wheel on the warlord hall"},
		{line = 692, text = 'wall_prop("armoury_wheel"', assign = "position",
			name = "a wagon wheel on the armoury"},
		{line = 693, text = 'wall_prop("bone_lodge_wheel"', assign = "position",
			name = "a wagon wheel on the bone lodge"},
		{line = 730, text = "decor.dress_rooms", assign = "house",
			name = "room and apron decor (decor.dress_rooms)"},
	}, inside = {{id = "warlord_platform", plot = "warlord_hall"}}},
	{id = "kapok", palettes = {h2 = "terrace"}, steps = {
		{line = 536, text = "decor.dress_rooms", assign = "house",
			name = "room and apron decor (decor.dress_rooms)"},
	}},
}

local report = {}
local function say(...) report[#report + 1] = table.concat({...}) end

local palettes_module

-- --------------------------------------------------------------------------
-- one town
-- --------------------------------------------------------------------------

local placements_all = {}
local layouts = {}
local undecided_total = 0

local function export_town(config)
	local town = config.id
	local real = fb.build(src, town, "real")
	local probe = fb.build(src, town, "probe")
	parts = real.parts
	lib.parts = parts
	palettes_module = palettes_module or dofile(src .. "/palette.lua")
	-- the probe build answered every question as the real one did
	assert(#real.writes == #probe.writes, town .. ": the probe build wrote " ..
		#probe.writes .. " cells, the real one " .. #real.writes)
	for index, write in ipairs(real.writes) do
		local other = probe.writes[index]
		assert(write.x == other.x and write.y == other.y and write.z == other.z and
			write.name == fb.strip(other.name) and write.param2 == other.param2,
			town .. ": the probe build differs at write " .. index)
	end
	local race = real.handles[1].race
	say("")
	say("== ", town, " (", race, "): ", #real.writes, " writes, ",
		#real.stamps, " stamps")

	-- the step table
	local steps = {}
	for _, step in ipairs(config.steps) do
		local text = real.lines[step.line] or ""
		assert(text:find(step.text, 1, true), town .. ": line " .. step.line ..
			" is not '" .. step.text .. "': " .. text)
		steps[step.line] = step
	end

	-- the placements, in stamp order
	local building_line = real.stamps[1].line
	local placements, by_id = {}, {}
	for k, stamp in ipairs(real.stamps) do
		if stamp.line == building_line then
			local plot = real.plots[#placements + 1]
			assert(plot, town .. ": more stamps than plots")
			local pstamp = probe.stamps[k]
			-- no start town's building plants (Round 56 lane TREES): a part
			-- that did would be a planted template (format doc §4.2)
			assert(not stamp.planting, town .. " " .. plot.id .. " plants trees or undergrowth")
			local pl = {town = town, id = plot.id, race = race, stamp = stamp,
				pstamp = pstamp, ox = stamp.ox, oy = stamp.oy, oz = stamp.oz,
				turns = stamp.turns, w = stamp.w, d = stamp.d, lift = plot.lift,
				main_h = real.handle_of[stamp.generator.palette],
				roof_h = stamp.generator.roof and real.handle_of[stamp.generator.roof],
				generator = stamp.generator, content = {}, points = {},
				point_groups = {}, moved = {}, bb_writes = 0, steps = {}}
			assert(pl.main_h, town .. " " .. plot.id .. ": unknown main palette")
			local fp = stamp.result.footprint[1]
			pl.fx1, pl.fz1 = fp.x, fp.z
			pl.fx2, pl.fz2 = fp.x + fp.w - 1, fp.z + fp.d - 1
			placements[#placements + 1] = pl
			by_id[pl.id] = pl
		end
	end
	assert(#placements == #real.plots, town .. ": " .. #placements ..
		" building stamps for " .. #real.plots .. " plots")

	local function handle_real(hid)
		for _, record in ipairs(real.handles) do
			if record.id == hid then return record end
		end
		error("unknown palette handle " .. tostring(hid))
	end

	-- A real value with its probe twin -> a legend entry.
	local function label(pl, name, param2, pname, side)
		assert(fb.strip(pname) == name, "probe twin differs")
		local _, hid, role = fb.untag(pname)
		if not hid then
			if name == "air" then return {kind = "air"} end
			return {kind = "node", name = name, o = orientation_of(name, param2)}
		end
		local channel
		if hid == pl.main_h then channel = nil
		elseif side == "bb" and hid == "h1" then channel = "town"
		elseif hid == pl.roof_h then channel = "roof"
		else error(town .. " " .. pl.id .. ": palette " .. hid .. " is not one of its own") end
		local entry = {kind = "role", role = role, channel = channel,
			o = orientation_of(name, param2), hid = hid}
		local family = palettes_module.prefix_roles[role]
		if family then
			local handle = handle_real(hid).real
			for _, suffix in ipairs(family) do
				if handle.variant(role, suffix) == name then entry.variant = suffix end
			end
			assert(entry.variant, "no variant for " .. name)
		end
		return entry
	end

	local function optional(role)
		for _, name in ipairs(palettes_module.optional) do
			if name == role then return true end
		end
		return false
	end

	-- the fallback of an optional role: the plain bed for a fancy one, else
	-- what the cell held before the write
	local function with_fallback(entry, prev_entry)
		if entry.kind ~= "role" or not optional(entry.role) then return entry end
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

	-- 1. every building's own part
	for _, pl in ipairs(placements) do
		local cells, pcells = pl.stamp.cells, pl.pstamp.cells
		assert(#cells == #pcells, pl.id .. ": the probe part differs")
		for index, cell in ipairs(cells) do
			local twin = pcells[index]
			assert(twin.x == cell.x and twin.y == cell.y and twin.z == cell.z)
			local key = key3(cell.x, cell.y, cell.z)
			local prev, pprev = pl.stamp.prev[key], pl.pstamp.prev[key]
			local prev_entry
			if prev then prev_entry = label(pl, prev.name, prev.param2, pprev.name, "part") end
			pl.content[key] = {x = cell.x, y = cell.y, z = cell.z,
				entry = with_fallback(label(pl, cell.name, cell.param2, twin.name, "part"),
					prev_entry),
				name = cell.name, param2 = cell.param2}
		end
		for group, list in pairs(pl.stamp.points) do
			pl.points[group] = fb.copy(list)
		end
	end

	-- 2. the building-bound writes, in write order
	local function owner_of(write, step)
		if step.assign == "plot" then return by_id[step.plot] end
		if step.assign == "house" then
			local id = write.context and write.context.id
			return by_id[id] or error(town .. ": decor write without a house")
		end
		local found, best
		for _, pl in ipairs(placements) do
			local dx = math.max(pl.fx1 - write.x, 0, write.x - pl.fx2)
			local dz = math.max(pl.fz1 - write.z, 0, write.z - pl.fz2)
			local distance = math.max(dx, dz)
			if distance <= 1 then
				if best == nil or distance < best then found, best = pl, distance
				elseif distance == best then
					error(town .. ": the write at " .. key3(write.x, write.y, write.z) ..
						" is next to two buildings")
				end
			end
		end
		return found or error(town .. ": the write at " ..
			key3(write.x, write.y, write.z) .. " (line " .. write.line ..
			") belongs to no building")
	end
	local bb = {}
	for index, write in ipairs(real.writes) do
		local step = steps[write.line]
		if step and not step.kept then
			local pl = owner_of(write, step)
			assert(index > pl.stamp.write_index, "a building-bound write before its stamp")
			local x, y, z = to_part_frame(pl, write.x, write.y, write.z)
			local key = key3(x, y, z)
			local param2 = unrotate_param2(write.name, write.param2, pl.turns)
			local before = pl.content[key]
			local entry = label(pl, write.name, param2, probe.writes[index].name, "bb")
			pl.content[key] = {x = x, y = y, z = z, name = write.name, param2 = param2,
				entry = with_fallback(entry, before and before.entry), step = step}
			pl.bb_writes = pl.bb_writes + 1
			pl.steps[step.name] = (pl.steps[step.name] or 0) + 1
			bb[index] = pl
		end
	end

	-- 3. the town points derived from a building
	local function to_template_point(pl, point, face_dir)
		local x, y, z = to_part_frame(pl, point.x, point.y, point.z)
		local out = {x = x, y = y, z = z}
		if face_dir then
			local face = DIR_FACE[face_dir.x .. ":" .. face_dir.z]
			assert(face, "a socket direction is not axis aligned")
			out.face = (face - pl.turns) % 4
		end
		return out
	end
	for _, socket in ipairs(real.sockets) do
		local door_tag = false
		for _, tag in ipairs(socket.tags or {}) do
			if tag == "door" then door_tag = true end
		end
		if door_tag then
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
			assert(not tie, town .. ": socket " .. socket.id .. " stands at two doors")
			if found then
				local point = to_template_point(found, socket, socket.dir)
				point.attrs = {{key = "id", value = socket.id}}
				point.group = "sockets"
				found.moved[#found.moved + 1] = {group = "sockets", id = socket.id,
					rule = "a door-tagged town socket within 3 nodes of its door (" ..
						best .. " nodes)", point = point}
			end
		end
	end
	for _, wanted in ipairs(config.inside or {}) do
		local pl = by_id[wanted.plot]
		local spot
		for _, destination in ipairs(real.blueprint.landmarks.destinations) do
			if destination.id == wanted.id then spot = destination end
		end
		assert(spot, town .. ": no destination " .. wanted.id)
		local point = to_template_point(pl, spot)
		point.attrs = {{key = "id", value = wanted.id}}
		point.group = "inside"
		pl.moved[#pl.moved + 1] = {group = "inside", id = wanted.id,
			rule = "a destination the town sets by hand on the building", point = point}
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
				local ok, x, y, z = pcall(to_part_frame, pl, write.x, write.y, write.z)
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

	say("building-bound steps (their writes are template content):")
	local listed = {}
	for _, step in ipairs(config.steps) do
		if not listed[step.name] and not step.kept then
			listed[step.name] = true
			say("  - ", step.name, " (line ", step.line, ")")
		end
	end
	if next(listed) == nil then say("  (none moved)") end
	say("points moved into templates:")
	local any = false
	for _, pl in ipairs(placements) do
		for _, moved in ipairs(pl.moved) do
			any = true
			say("  - ", moved.group, " ", moved.id, " -> ", pl.id, ": ", moved.rule)
		end
	end
	if not any then say("  (none)") end
	say("building-bound steps kept in town code by the stamp-time rule:")
	any = false
	for _, step in ipairs(config.steps) do
		if step.kept then
			any = true
			local count = 0
			for _, write in ipairs(real.writes) do
				if write.line == step.line then count = count + 1 end
			end
			say("  - ", step.name, " (line ", step.line, ", ", count, " writes): ", step.why)
		end
	end
	if not any then say("  (none: every building-bound step moved whole)") end

	layouts[#layouts + 1] = {town = town, race = race, placements = placements,
		config = config, handles = real.handles}
	for _, pl in ipairs(placements) do placements_all[#placements_all + 1] = pl end
end

-- --------------------------------------------------------------------------
-- main
-- --------------------------------------------------------------------------

say("# The freeze report of the start towns (tools/building_templates/export.py).")
say("# The pre-freeze source is the commit export.py names; every count is measured.")
for _, config in ipairs(TOWNS) do export_town(config) end

-- render and merge identical templates
local templates, template_order = {}, {}
for _, pl in ipairs(placements_all) do
	local rendered = render(pl)
	local body = rendered.head .. "\n" .. rendered.tail
	local found
	for _, name in ipairs(template_order) do
		if templates[name].body == body then found = templates[name] end
	end
	if not found then
		found = {name = pl.town .. "_" .. pl.id, body = body, rendered = rendered,
			users = {}, races = {}}
		templates[found.name] = found
		template_order[#template_order + 1] = found.name
	end
	found.users[#found.users + 1] = pl
	found.races[pl.race] = true
	pl.template = found.name
end


for _, name in ipairs(template_order) do
	local t = templates[name]
	local races = {}
	for race in pairs(t.races) do races[#races + 1] = race end
	table.sort(races, function(a, b) return RACE_RANK[a] < RACE_RANK[b] end)
	local users = {}
	for _, pl in ipairs(t.users) do users[#users + 1] = pl.town .. ":" .. pl.id end
	write_file(out .. "/templates/" .. name .. ".tpl", table.concat({
		"grudgelands-building-template 1",
		"# Frozen from the building generators (Round 56): " .. table.concat(users, ", "),
		"name " .. name,
		t.rendered.head,
		"races " .. table.concat(races, " "),
		t.rendered.tail, ""}, "\n"))
end

for _, layout in ipairs(layouts) do
	local lines = {"grudgelands-town-layout 1",
		"# The start town's buildings in stamp order (frozen in Round 56).",
		"town " .. layout.town, "race " .. layout.race, ""}
	local names = layout.config.palettes
	local used = {}
	local place_lines = {}
	for _, pl in ipairs(layout.placements) do
		local channels = {}
		for _, cell in pairs(pl.content) do
			local entries = {cell.entry, cell.entry.fallback_entry}
			for _, entry in ipairs(entries) do
				if entry.channel then channels[entry.channel] = true end
			end
		end
		local line = {"place", pl.id, "template=" .. pl.template, "x=" .. pl.ox,
			"y=" .. pl.oy, "z=" .. pl.oz, "turns=" .. pl.turns}
		if pl.main_h ~= "h1" then
			line[#line + 1] = "main=" .. assert(names[pl.main_h])
			used[pl.main_h] = true
		end
		if channels.roof then
			local name = pl.roof_h == "h1" and "town" or assert(names[pl.roof_h])
			line[#line + 1] = "roof=" .. name
			used[pl.roof_h] = true
		end
		if channels.town then
			line[#line + 1] = "town=town"
			used.h1 = true
		end
		if pl.lift then line[#line + 1] = "lift=" .. pl.lift end
		place_lines[#place_lines + 1] = table.concat(line, " ")
	end
	for _, record in ipairs(layout.handles) do
		if used[record.id] then
			local line = {"palette", record.id == "h1" and "town" or
				assert(layout.config.palettes[record.id]), "race=" .. record.race}
			for _, role in ipairs(sorted_keys(record.overrides or {})) do
				line[#line + 1] = role .. "=" .. record.overrides[role]
			end
			lines[#lines + 1] = table.concat(line, " ")
		end
	end
	if #lines > 5 then lines[#lines + 1] = "" end
	for _, line in ipairs(place_lines) do lines[#lines + 1] = line end
	lines[#lines + 1] = ""
	write_file(out .. "/layouts/" .. layout.town .. ".layout", table.concat(lines, "\n"))
end

-- the per-template report
say("")
say("== templates: ", #template_order, " for ", #placements_all, " placements")
local shared = 0
for _, name in ipairs(template_order) do
	local t = templates[name]
	if #t.users > 1 then shared = shared + 1 end
end
say("templates shared by several placements: ", shared)
for _, name in ipairs(template_order) do
	local t, r = templates[name], templates[name].rendered
	local users = {}
	for _, pl in ipairs(t.users) do users[#users + 1] = pl.town .. ":" .. pl.id end
	say("")
	say("-- ", name, " (", table.concat(users, ", "), ")")
	say("   cells ", r.cells, ", legend ", r.legend, ", role cells ", r.role_cells,
		", fixed-node cells ", r.node_cells, ", force-air cells ",
		r.cells - r.role_cells - r.node_cells, ", race switches 0, undecided 0")
	for _, pl in ipairs(t.users) do
		local steps = {}
		for _, step in ipairs(sorted_keys(pl.steps)) do
			steps[#steps + 1] = step .. " " .. pl.steps[step]
		end
		if #steps > 0 then say("   building-bound writes (", pl.id, "): ", table.concat(steps, "; ")) end
		say("   town writes kept in its box (", pl.id, "): ", pl.kept)
		for _, step in ipairs(sorted_keys(pl.kept_steps)) do
			say("     ", pl.kept_steps[step], "x ", step)
		end
	end
end

-- The templates read back through the game's own loader: every placement's
-- part must be exactly the cells the freeze cut for it.
local game_wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local loader = dofile(game_wp13 .. "/templates.lua")(game_wp13)
local game_palettes = dofile(game_wp13 .. "/palette.lua")
local function overrides_of(pl, hid)
	if not hid then return nil end
	for _, layout in ipairs(layouts) do
		if layout.town == pl.town then
			for _, record in ipairs(layout.handles) do
				if record.id == hid then return record.overrides end
			end
		end
	end
end
local function palette_of(pl, race)
	local main = game_palettes.new(race, overrides_of(pl, pl.main_h))
	local roof = pl.roof_h and game_palettes.new(race, overrides_of(pl, pl.roof_h)) or main
	local town = game_palettes.new(race)
	return function(channel)
		if channel == "roof" then return roof end
		if channel == "town" then return town end
		return main
	end
end
local parsed = {}
for _, name in ipairs(template_order) do
	local path = out .. "/templates/" .. name .. ".tpl"
	local file = assert(io.open(path, "rb"))
	parsed[name] = loader.parse_template(file:read("*a"), path, name)
	file:close()
	for _, pl in ipairs(templates[name].users) do
		local got = cells_of(loader.part(parsed[name], pl.id, pl.race,
			palette_of(pl, pl.race)).buffer)
		local count = 0
		for key, cell in pairs(pl.content) do
			count = count + 1
			assert(got[key] == cell.name .. "/" .. cell.param2, name .. " for " ..
				pl.town .. ":" .. pl.id .. ": the cell " .. key .. " reads back as " ..
				tostring(got[key]) .. ", not " .. cell.name .. "/" .. cell.param2)
		end
		for key in pairs(got) do
			assert(pl.content[key], name .. ": an extra cell " .. key)
		end
	end
end
say("")
say("every template reads back through wp13/templates.lua as exactly the cells",
	" cut for each of its placements")

-- per-race shapes (ruling 22): resolve each template for every race and
-- compare with what the generator builds for that race (the cells no
-- building-bound step wrote)
say("")
say("== per-race shapes: how often another race builds a different shape")
local differs_total, failed_total = 0, 0
for _, name in ipairs(template_order) do
	local pl = templates[name].users[1]
	local generator = pl.generator
	local main_ov, roof_ov = overrides_of(pl, pl.main_h), overrides_of(pl, pl.roof_h)
	local differs, failed = {}, {}
	for _, race in ipairs(RACES) do
		local result = fb.generator(src, generator.make, fb.copy(generator.spec), race,
			main_ov, roof_ov, "real")
		local ok, part = pcall(loader.part, parsed[name], pl.id, race, palette_of(pl, race))
		if not result or not ok then
			failed[#failed + 1] = race
		else
			local got = cells_of(part.buffer)
			local same = true
			local seen = {}
			for _, cell in ipairs(result.cells) do
				local key = key3(cell.x, cell.y, cell.z)
				seen[key] = true
				local mine = pl.content[key]
				if not (mine and mine.step) and got[key] ~= cell.name .. "/" .. cell.param2 then
					same = false
				end
			end
			for key in pairs(got) do
				local mine = pl.content[key]
				if not seen[key] and not (mine and mine.step) then same = false end
			end
			if not same then differs[#differs + 1] = race end
			assert(race ~= pl.race or same, name .. ": the placing race differs")
		end
	end
	differs_total = differs_total + #differs
	failed_total = failed_total + #failed
	say("  ", name, " (", pl.race, "): ", #differs, " of 5 other races build another shape",
		#differs > 0 and (" (" .. table.concat(differs, ", ") .. ")") or "",
		#failed > 0 and ("; failed: " .. table.concat(failed, ", ")) or "")
end
say("  total: ", differs_total, " race builds of another shape, ", failed_total,
	" failed (informational: every template is placed by its own race only, or by",
	" races that build it identically)")

print(table.concat(report, "\n"))
