-- Round 82 lane BOOT: what the WP13 building library builds, as digests, and
-- what building it costs, as counts.
--
--   luajit tools/r82_boot/dump.lua REPO [SEED ...] > out.txt
--
-- REPO is the checkout whose `mods/` is built (and whose seed fleet harness
-- is used). Every line is `<section>\t<name>\t<value>`; the `count` and
-- `time` lines are the cost, every other line is output and must be equal
-- between two trees that claim to build the same (compare with
-- `grep -v '^count\|^time'`):
--
--   build    every blueprint of every settlement profile of
--            `r7_settlement.roster` (starts, villages, POIs, PvP POIs, camps:
--            built with each SEED as the runtime builds them; each capital's
--            core and every district plot once): SHA-256 over a canonical
--            serialisation of the whole blueprint (cells, param2, metadata,
--            landmarks, sockets, points, every field);
--   turned   each capital plot turned 1 to 3 quarter turns the way
--            `r7_settlement` turns a plot's cells per chunk (`rot`, a fresh
--            buffer, `resolve_panes`), its cell list;
--   palette  every role of every race through `node`, `maybe` and `variant`
--            (results and error messages), and `new` with bad overrides;
--   green    per SEED and capital (the seed fleet harness's main runtime):
--            the city trees (`green.cells`) and the ground cover
--            (`green.cover`) over the capital's whole square, from a first
--            and from a second `green` (an idle release rebuilds it);
--   count    the template parses, tree generations, buffer writes and reads
--            (each of which built one string key before Round 82), resolve-
--            free cells, and every buffer position given as -0 or as a
--            non-integer (both must stay 0: a numeric key merges -0 and 0);
--   time     CPU seconds and KB allocated of one construction of every
--            blueprint, without the counting hooks.
local repo = assert(arg[1], "usage: dump.lua REPO [SEED ...]")
local seeds = {}
for index = 2, #arg do seeds[#seeds + 1] = arg[index] end
local wp13 = repo .. "/mods/MAPGEN/grug_mapgen/wp13"
local wp40 = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
_G.core = _G.core or {}
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local sha = common.new_sha256()
local function digest(text) return common.hex(sha(text)) end

local function canonical(value, out)
	local kind = type(value)
	if kind == "table" then
		local keys = {}
		for key in pairs(value) do keys[#keys + 1] = key end
		table.sort(keys, function(a, b)
			if type(a) ~= type(b) then return type(a) < type(b) end
			return a < b
		end)
		out[#out + 1] = "{"
		for _, key in ipairs(keys) do
			canonical(key, out)
			out[#out + 1] = "="
			canonical(value[key], out)
			out[#out + 1] = ";"
		end
		out[#out + 1] = "}"
	elseif kind == "number" then
		out[#out + 1] = string.format("n%.17g", value)
	elseif kind == "string" then
		out[#out + 1] = string.format("%q", value)
	elseif kind == "boolean" then
		out[#out + 1] = value and "T" or "F"
	else
		out[#out + 1] = kind
	end
	return out
end
local function canon_digest(value) return digest(table.concat(canonical(value, {}))) end
local function emit(section, name, value) print(section .. "\t" .. name .. "\t" .. value) end

-- The counting hooks ---------------------------------------------------------
local counts = {parse = 0, tree = 0, put = 0, at = 0, negative_zero = 0,
	non_integer = 0}
local hooked = true
local real_dofile = dofile
local function odd(v) return v == 0 and 1 / v < 0 or v % 1 ~= 0 end
local function note(x, y, z)
	for _, v in ipairs({x, y, z}) do
		if v == 0 and 1 / v < 0 then counts.negative_zero = counts.negative_zero + 1
		elseif v % 1 ~= 0 then counts.non_integer = counts.non_integer + 1 end
	end
end
_G.dofile = function(path)
	local result = real_dofile(path)
	if not hooked then return result end
	if path:match("/parts%.lua$") then
		local Buffer = getmetatable(result.buffer()).__index
		local put, at = Buffer.put, Buffer.at
		Buffer.put = function(self, x, y, z, ...)
			counts.put = counts.put + 1
			if odd(x) or odd(y) or odd(z) then note(x, y, z) end
			return put(self, x, y, z, ...)
		end
		Buffer.at = function(self, x, y, z)
			counts.at = counts.at + 1
			if odd(x) or odd(y) or odd(z) then note(x, y, z) end
			return at(self, x, y, z)
		end
	elseif path:match("/templates%.lua$") then
		return function(...)
			local M = result(...)
			local parse = M.parse_template
			M.parse_template = function(...)
				counts.parse = counts.parse + 1
				return parse(...)
			end
			return M
		end
	elseif path:match("/tree_templates%.lua$") then
		return function(...)
			local T = result(...)
			local tree = T.tree
			T.tree = function(...)
				counts.tree = counts.tree + 1
				return tree(...)
			end
			return T
		end
	end
	return result
end
local function emit_counts(stage)
	for _, key in ipairs({"parse", "tree", "put", "at", "negative_zero", "non_integer"}) do
		emit("count", stage .. "." .. key, counts[key])
		counts[key] = 0
	end
end

-- Every blueprint ---------------------------------------------------------------
local settlement = dofile(wp40 .. "/r7_settlement.lua")
local capital_source = dofile(wp40 .. "/r7_capital_blueprint.lua")
local rot = dofile(wp13 .. "/plot_approach.lua").rot
local function build_all(seed, capitals, visit)
	local options = {full_seed = seed, raw_sha256 = sha}
	for _, profile in ipairs(settlement.roster) do
		if profile.slot == "capital" then
			if capitals then
				local kit = capital_source.kit(profile.key)
				visit(profile, "core", kit.core.build())
				for _, plot in ipairs(kit.plots) do visit(profile, plot.id, plot.build()) end
			end
		else
			local source = dofile(wp40 .. "/" .. profile.blueprint_file)(options, profile)
			if type(source) == "function" then source = source(options) end
			visit(profile, "blueprint", source)
		end
	end
end
local parts = dofile(wp13 .. "/parts.lua")
local function turned(cells, turns)
	local buf = parts.buffer()
	for index = 1, #cells do
		local cell = cells[index]
		local x, z = rot(cell.x, cell.z, turns)
		buf:put(x, cell.y, z, cell.name, parts.canonical_param2(cell.name,
			parts.rotate_param2(cell.param2, parts.param2_kind(cell.name), turns)))
	end
	parts.resolve_panes(buf)
	local order, count = buf:cells()
	local out = {}
	for index = 1, count do
		local c = order[index]
		out[index] = {c.x, c.y, c.z, c.name, c.param2}
	end
	return out
end
local first_seed = seeds[1] or "12345"
for index, seed in ipairs(#seeds > 0 and seeds or {first_seed}) do
	build_all(seed, index == 1, function(profile, id, blueprint)
		local name = profile.key .. "/" .. id
		if profile.slot ~= "capital" then name = name .. "@" .. seed end
		emit("build", name, canon_digest(blueprint))
		if profile.slot == "capital" and id ~= "core" then
			for turns = 1, 3 do
				emit("turned", name .. "/" .. turns, canon_digest(turned(blueprint.cells, turns)))
			end
		end
	end)
	emit_counts("build@" .. seed)
end

-- The palette handles -----------------------------------------------------------
do
	local palettes = dofile(wp13 .. "/palette.lua")
	local races = {}
	for race in pairs(palettes.races) do races[#races + 1] = race end
	table.sort(races)
	local probe_roles = {}
	for _, role in ipairs(palettes.required) do probe_roles[#probe_roles + 1] = role end
	for _, role in ipairs(palettes.optional) do probe_roles[#probe_roles + 1] = role end
	local families = {}
	for role in pairs(palettes.prefix_roles) do families[#families + 1] = role end
	table.sort(families)
	for _, role in ipairs(families) do probe_roles[#probe_roles + 1] = role end
	probe_roles[#probe_roles + 1] = "no_such_role"
	local function answer(ok, value) return (ok and "ok:" or "error:") .. tostring(value) end
	for _, race in ipairs(races) do
		local h = palettes.new(race)
		local lines = {}
		for _, role in ipairs(probe_roles) do
			lines[#lines + 1] = role .. " node=" .. answer(pcall(h.node, role)) ..
				" maybe=" .. answer(pcall(h.maybe, role))
			local suffixes = palettes.prefix_roles[role]
			for _, suffix in ipairs(suffixes or {"_x"}) do
				lines[#lines + 1] = role .. suffix .. " variant=" ..
					answer(pcall(h.variant, role, suffix))
			end
			lines[#lines + 1] = role .. " bad variant=" .. answer(pcall(h.variant, role, "_nope"))
		end
		emit("palette", race, digest(table.concat(lines, "\n")))
	end
	local bad = {{"human", {no_such_role = "default:dirt"}}, {"human", {wall = ""}},
		{"human", "x"}, {"nobody", nil}, {"human", {signature = "default:stone"}},
		{"elf", {wall = "default:stone", roof_slab = "stairs:slab_wood"}}}
	for index, case in ipairs(bad) do
		local ok, value = pcall(palettes.new, case[1], case[2])
		emit("palette", "new" .. index, ok and ("ok:" .. tostring(value.node("wall"))) or
			("error:" .. tostring(value)))
	end
end

-- The city green of each capital --------------------------------------------------
local function upvalue(fn, wanted)
	for index = 1, 255 do
		local name, value = debug.getupvalue(fn, index)
		if name == nil then break end
		if name == wanted then return value end
	end
	error("upvalue " .. wanted .. " not found")
end
for _, seed in ipairs(seeds) do
	local R = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, seed)
	local native = dofile(wp40 .. "/r7_native.lua")
	local authority = R.main.build_authority(native.identities())
	local ps = authority.planner_source
	local settlements = upvalue(R.main.settlement_sockets, "settlements")
	local function column(x, z)
		local _, _, _, _, _, terrain_y, water_y = ps.column_values_at(x, z)
		local road = ps.road_column_at and ps.road_column_at(x, z) == "surface" or false
		if type(water_y) ~= "number" or water_y <= terrain_y then water_y = nil end
		return terrain_y, water_y, road
	end
	emit_counts("runtime@" .. seed)
	for _, row in ipairs(settlements) do
		local profile, prepared = row.profile, row.prepared
		if profile.slot == "capital" then
			local anchor = authority.zones_session.anchor(profile.zone_id, profile.slot)
			local rects, city = {}, nil
			for _, b in ipairs(prepared.blueprints) do
				if b.descriptor.kind == "reference" then
					local rect = settlement.plot_rect(b, anchor.x, anchor.z)
					rect.turns = b.descriptor.turns or 0
					rects[#rects + 1] = rect
				elseif b.descriptor.kind == "overlay" then
					city = b.city
				end
			end
			local box = {min_x = anchor.x - 280, max_x = anchor.x + 280,
				min_z = anchor.z - 280, max_z = anchor.z + 280}
			for pass = 1, 2 do
				local green = city.green({x = anchor.x, z = anchor.z}, rects, column)
				local cells = green.cells(box)
				local taken = {}
				for _, c in ipairs(cells) do taken[c.x .. ":" .. c.y .. ":" .. c.z] = true end
				local cover = green.cover(box, taken)
				emit("green", profile.key .. "@" .. seed .. "/cells" .. pass,
					#cells .. " " .. canon_digest(cells))
				emit("green", profile.key .. "@" .. seed .. "/cover" .. pass,
					#cover .. " " .. canon_digest(cover))
				emit_counts("green." .. profile.key .. "@" .. seed .. "." .. pass)
			end
		end
	end
end

-- The cost of one construction, without the hooks --------------------------------
hooked = false
do
	collectgarbage("collect")
	local started = os.clock()
	build_all(first_seed, true, function() end)
	local seconds = os.clock() - started
	collectgarbage("collect")
	collectgarbage("stop")
	local before = collectgarbage("count")
	build_all(first_seed, true, function() end)
	local allocated = collectgarbage("count") - before
	collectgarbage("restart")
	emit("time", "build_all.seconds", string.format("%.2f", seconds))
	emit("time", "build_all.kb", string.format("%.0f", allocated))
end
