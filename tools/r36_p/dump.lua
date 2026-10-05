-- Round 36 lane P: build every POI composition the way the game builds it and
-- write it for the review renderer (LuaJIT, no engine).
--
--   luajit tools/r36_p/dump.lua REPO OUT_DIR
--
-- The POI list is the settlement roster itself (`r7_settlement.roster`, the
-- table `r7_runtime.lua` walks): every profile except the capitals and the
-- starts. Each is built as the runtime builds it (`dofile(blueprint_file)(
-- options, profile)`, called again if it returns a factory) and must pass
-- `r7_settlement.prepare`, the validator the runtime runs. The anchor
-- activation node the R7 writer adds at the root (a guard banner on outpost
-- anchors 25..48, a camp fire on bandit anchors 49..60; `r7_anchor_roster.lua`)
-- is added at local (0, 1, 0).
--
-- Other palettes ("the same composition in another race"): the Round 14 and
-- Round 20 builders pick layout AND materials by `spec.race`. This script
-- loads a copy of the builder source with the palette lookups redirected to
-- `spec.palette_race` (exact, counted substitutions; anything else fails),
-- so only the materials change. The redirected builder with the POI's own
-- race must give the in-game cells exactly (checked per POI). The PvP camps
-- take another race of their faction natively (`art.race`); the fortress
-- has only faction materials, so its alternative is the other faction's
-- (`FORT[...]`, redirected the same way). The dragon arenas are the
-- blueprint's spawn stone plus the `arena_layout.lua` dressing on a flat
-- stand-in floor (the real floor is terrain).
--
-- Writes OUT_DIR/index.tsv (one row per POI, see `meta_fields`) and per POI
-- OUT_DIR/<key>__<variant>.tsv (x y z name param2, non-air) and
-- OUT_DIR/<key>.sockets.tsv (id role group x y z dir_x dir_z).
local repo, out = arg[1], arg[2]
assert(repo and out, "usage: dump.lua REPO OUT_DIR")
_G.core = _G.core or {}
local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
local settlement = dofile(dir .. "/r7_settlement.lua")
local source = dofile(dir .. "/source/simple_map.lua")
local pvp_catalog = dofile(dir .. "/r31_pvp_catalog.lua")
local arena_layout = dofile(dir .. "/arena_layout.lua")
local sha = dofile(repo .. "/tools/wp40/r6/common.lua").new_sha256()

local RACES = {"dwarf", "human", "elf", "undead", "orc", "troll"}
-- The six quest-lane seeds; a camp's race is rolled per world seed.
local SEEDS = {"42", "7", "2026", "1234", "99999", "314159"}
local options = {raw_sha256 = sha, full_seed = SEEDS[1]}

local function read(path)
	local f = assert(io.open(path, "rb"))
	local text = f:read("*a")
	f:close()
	return text
end

-- A builder source with its palette lookups redirected; every substitution
-- must match exactly `count` times (nil: at least once).
local function redirected(file, edits)
	local path = dir .. "/" .. file
	local text = read(path)
	for _, e in ipairs(edits) do
		local from = e[1]:gsub("%p", "%%%0")
		local n
		text, n = text:gsub(from, (e[2]:gsub("%%", "%%%%")))
		assert(n > 0 and (e[3] == nil or n == e[3]),
			file .. ": palette redirect matched " .. n .. "x: " .. e[1])
	end
	return assert(loadstring(text, "@" .. path))()
end
local r20_alt = redirected("r20_poi_blueprint.lua", {
	{"local p = assert(palettes[spec.race])", "local p = assert(palettes[spec.palette_race or spec.race])", 1},
	{'"grug_mapgen:poi_display_"..spec.race', '"grug_mapgen:poi_display_"..(spec.palette_race or spec.race)'},
})
local r14_alt = redirected("r14_poi_blueprint.lua", {
	{"local p = assert(palettes[spec.race],", "local p = assert(palettes[spec.palette_race or spec.race],", 1},
	{'p.accent = "grug_mapgen:poi_display_" .. spec.race', 'p.accent = "grug_mapgen:poi_display_" .. (spec.palette_race or spec.race)', 1},
	{"p.roof_block = roof_blocks[spec.race]", "p.roof_block = roof_blocks[spec.palette_race or spec.race]", 1},
})
local r31_alt = redirected("r31_pvp_poi_blueprint.lua", {
	{"local f=FORT[art.faction]", "local f=FORT[art.palette_faction or art.faction]", 1},
})

local zones = {}
for _, z in ipairs(source.zones) do zones[z.id] = z end
local arena_radius
for _, p in ipairs(source.anchor_profiles) do
	if p.arena_radius then arena_radius = p.arena_radius end
end

local function copy(t)
	local c = {}
	for k, v in pairs(t) do c[k] = v end
	return c
end

local function cell_lines(bp, extra)
	local lines = {}
	for _, c in ipairs(bp.cells) do
		if c.name ~= "air" then
			lines[#lines + 1] = table.concat({c.x, c.y, c.z, c.name, c.param2 or 0}, "\t")
		end
	end
	for _, c in ipairs(extra or {}) do
		lines[#lines + 1] = table.concat(c, "\t")
	end
	return lines
end

local function write_lines(path, lines)
	local f = assert(io.open(path, "w"))
	f:write(table.concat(lines, "\n"), "\n")
	f:close()
end

local function same(a, b)
	if #a ~= #b then return false end
	for i = 1, #a do if a[i] ~= b[i] then return false end end
	return true
end

-- The dragon arena's dressing on a flat floor of `ground` (arena_writer.lua
-- writes the same kinds onto the terrain's floor).
local ARENA_GROUND = {wyrmglass = "default:gravel",
	stormscale = "grug_nodes:dirt_with_canopy_litter"}
local function arena_cells(profile)
	local zone = zones[profile.zone_id]
	local theme = assert(arena_layout.THEMES[zone.id])
	local N, r = arena_layout.NODES, arena_radius
	local cells = {}
	for dz = -r - 1, r + 1 do
		for dx = -r - 1, r + 1 do
			if dx * dx + dz * dz <= (r + 1) * (r + 1) then
				local kind, detail, extra = arena_layout.hazard_at(theme, r, dx, dz,
					profile.x + dx, profile.z + dz)
				local floor = ARENA_GROUND[theme.id]
				if kind == "thin_ice" or kind == "ember" or kind == "basalt" then floor = N[kind] end
				if not (dx == 0 and dz == 0) then cells[#cells + 1] = {dx, 0, dz, floor, 0} end
				if kind == "frost" then
					for y = 1, detail do cells[#cells + 1] = {dx, y, dz, N.frost_stone, 0} end
				elseif kind == "trunk" then
					cells[#cells + 1] = {dx, 1, dz, "default:jungletree", detail}
				elseif kind == "rim" then
					for y = 1, detail do cells[#cells + 1] = {dx, y, dz, extra, 0} end
				end
			end
		end
	end
	return cells
end

local meta_fields = {"key", "group", "label", "race", "zone_id", "zone_name",
	"level_min", "level_max", "numeric_id", "x", "z", "turns", "variants", "seed_races"}
local index = {table.concat(meta_fields, "\t")}
local counts = {}

for _, profile in ipairs(settlement.roster) do
	if profile.slot ~= "capital" and profile.slot ~= "start" then
		-- 1. in game, through the runtime's own call and validator
		local bp = dofile(dir .. "/" .. profile.blueprint_file)(options, profile)
		if type(bp) == "function" then bp = bp(options) end
		local ok, err = pcall(settlement.prepare, profile, bp, sha)
		assert(ok, profile.key .. ": r7_settlement.prepare: " .. tostring(err))
		local n = profile.numeric_id
		local activation = {}
		if n >= 25 and n <= 48 then activation = {{0, 1, 0, "grug_nodes:guard_banner", 0}}
		elseif n >= 49 and n <= 60 then activation = {{0, 1, 0, "grug_nodes:camp_fire", 0}} end
		local art = profile.art or {}
		local group, race = art.kind, profile.race
		local variants, seed_races = {}, "-"
		local function emit(variant, lines)
			write_lines(out .. "/" .. profile.key .. "__" .. variant .. ".tsv", lines)
			variants[#variants + 1] = variant
		end
		local game = cell_lines(bp, activation)
		if profile.blueprint_file == "r20_poi_blueprint.lua" then
			if art.kind == "dragon" then
				local extra = arena_cells(profile)
				for _, c in ipairs(activation) do extra[#extra + 1] = c end
				game = cell_lines(bp, extra)
			end
			emit("game", game)
			if art.kind ~= "dragon" then
				for _, other in ipairs(RACES) do
					local spec = copy(art)
					spec.palette_race = other
					local lines = cell_lines(r20_alt(options, {art = spec, blueprint_schema = profile.blueprint_schema}), activation)
					if other == race then
						assert(same(lines, game), profile.key .. ": redirected builder differs in its own race")
					else
						emit("alt_" .. other, lines)
					end
				end
			end
		elseif profile.blueprint_file:match("^r7_.*_blueprint%.lua$") then
			group = "r14_" .. profile.slot:gsub("_1$", "")
			emit("game", game)
			local kind = ({village_1 = "village", outpost_1 = "outpost", bandit_1 = "camp"})[profile.slot]
			for _, other in ipairs(RACES) do
				local lines = cell_lines(r14_alt({schema = profile.blueprint_schema, race = race,
					kind = kind, palette_race = other}), activation)
				if other == race then
					assert(same(lines, game), profile.key .. ": redirected builder differs in its own race")
				else
					emit("alt_" .. other, lines)
				end
			end
		elseif profile.blueprint_file == "r31_pvp_poi_blueprint.lua" then
			if art.kind == "pvp_fortress" then
				emit("game", game)
				for _, faction in ipairs({"accord", "throng"}) do
					local a = copy(art)
					a.palette_faction = faction
					local p = copy(profile)
					p.art = a
					local lines = cell_lines(r31_alt(options, p), activation)
					if faction == art.faction then
						assert(same(lines, game), profile.key .. ": redirected builder differs in its own faction")
					else
						emit("alt_" .. faction, lines)
					end
				end
			else
				race = bp.landmarks.race
				local rolled = {}
				for _, seed in ipairs(SEEDS) do
					rolled[#rolled + 1] = seed .. "=" .. pvp_catalog.camp_race(sha, seed, n, art.faction)
				end
				seed_races = table.concat(rolled, ",")
				emit("game", game)
				for _, other in ipairs(pvp_catalog.FACTION_RACES[art.faction]) do
					if other ~= race then
						local a = copy(art)
						a.race = other
						local p = copy(profile)
						p.art = a
						local alt = dofile(dir .. "/" .. profile.blueprint_file)(options, p)
						assert(settlement.prepare(p, alt, sha))
						emit("alt_" .. other, cell_lines(alt, activation))
					end
				end
			end
		else
			error("unknown POI blueprint: " .. profile.blueprint_file)
		end
		local sockets = {}
		for _, s in ipairs(bp.landmarks.sockets or {}) do
			sockets[#sockets + 1] = table.concat({s.id, s.role,
				s.group or s.kind or (s.tags and s.tags[1]) or "-",
				s.x, s.y, s.z, s.dir.x, s.dir.z}, "\t")
		end
		write_lines(out .. "/" .. profile.key .. ".sockets.tsv", sockets)
		local zone = assert(zones[profile.zone_id], profile.key .. ": zone")
		local row = {key = profile.key, group = group, label = profile.label, race = race,
			zone_id = profile.zone_id, zone_name = zone.display_name,
			level_min = zone.level_min, level_max = zone.level_max, numeric_id = n,
			x = profile.x, z = profile.z, turns = art.turns or 0,
			variants = table.concat(variants, ","), seed_races = seed_races}
		local values = {}
		for i, f in ipairs(meta_fields) do values[i] = tostring(row[f]) end
		index[#index + 1] = table.concat(values, "\t")
		counts[group] = (counts[group] or 0) + 1
	end
end
write_lines(out .. "/index.tsv", index)
local summary = {}
for group, count in pairs(counts) do summary[#summary + 1] = group .. "=" .. count end
table.sort(summary)
print(("R36 P dump: %d POIs (%s)"):format(#index - 1, table.concat(summary, " ")))
