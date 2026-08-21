-- WP40 T5-0 engine-seam probe: committed coordinate audit
-- (contract docs/research/wp40-t5-0-engine-probe-contract.md, sections 6.2
-- and 6.4; review checklist item 13).
--
-- WHAT THIS PROVES.  The probe measures three mapchunk columns -- k_y = 0,
-- k_z = 9, k_x in {8, 10, 11} -- and the contract claims two things about
-- them that the whole measurement rests on:
--
--   1. no grug structure anchor reaches any of the three chunks, so
--      structures.lua returns before it ever fetches a voxelmanip; and
--   2. the ocean mask does not fire in any of the three chunks, and it does
--      not fire BECAUSE every column of the grown box is at least
--      TAPER + INSET_MAX = 300 nodes INLAND -- not because the box sits far
--      out at sea, and not because the box is below the mask floor.
--
-- Both are RECOMPUTED here from the repository sources.  Restating a
-- hand-copied anchor list, or a hand-copied lo value, would be worthless as
-- evidence: it could not notice a source change.  Review item 13 checks
-- exactly that distinction.
--
-- MECHANISM, and why it is recompute rather than restate.  Three different
-- techniques, each chosen for what the source in question actually is:
--
--   * mods/CORE/grug_core/init.lua -- the anchor tables are BUILT by two
--     `do ... end` blocks at load time (the outpost frame arithmetic and the
--     bandit retry offsets are real code, not data).  So the audit EXECUTES
--     that source: it reads the file, cuts it at the first line that needs a
--     live engine (`local storage = core.get_mod_storage()`, everything
--     above it is pure arithmetic), compiles the prefix and runs it under a
--     sandbox environment with setfenv.  The anchors come out of the mod's
--     own loop, so a changed capital, ring radius or retry offset changes
--     this audit's answer.  The cut marker is asserted; if it moves or
--     disappears the audit dies instead of guessing.
--   * mods/MAPGEN/grug_mapgen/geometry.lua -- a plain module that returns a
--     `build(cfg)` factory and takes the continent rectangle as an argument.
--     The audit `loadfile`s it unchanged and calls the real
--     `box_needs_mask` / `continent_distance` it hands back, with the
--     rectangle taken from the grug_core values loaded above.
--   * `box_distance_range` (geometry.lua) and `chunk_covers`
--     (structures.lua) are file-local functions that neither module
--     exports, and structures.lua as a whole cannot load headless.  So the
--     audit EXTRACTS the two function bodies verbatim from the source bytes
--     -- located by their exact signature line, terminated by the first
--     `end` at the same indentation -- and compiles that text.  The
--     arithmetic executed is the file's own, character for character; an
--     edit to either function changes what runs here.  As a cross-check the
--     extracted `box_distance_range` is required to agree with the module's
--     real exported `box_needs_mask` on every box tested.
--
-- The audit imports NOTHING from the six locked T2 surfaces of contract
-- section 8.3.  geometry.lua and structures.lua are ordinary, non-locked
-- mapgen files.
--
-- USAGE
--   lua coordinate_audit.lua [REPO_ROOT]
-- REPO_ROOT defaults to the repository this script itself lives in, derived
-- from arg[0], so a runner can point it at an archived tree instead.
--
-- OUTPUT AND EXIT.  stdout is deterministic canonical text: fixed line
-- order, no timestamps, no floats, no pairs() walk anywhere in the output
-- path (every table iteration that reaches stdout goes through an explicit
-- table.sort).  It is byte-identical under LuaJIT and under
-- tools/bin/lua51.  Exit 0 with a final line COORDINATE AUDIT GREEN, or a
-- non-zero exit with a stdout line COORDINATE AUDIT FAILED, the failing
-- check names and a message on stderr.  Failure is signalled with a
-- top-level `error` rather than an exit call, because this file has to stay
-- clean under sweep 5 of docs/research/luanti-lua.md:310-321; only the
-- interpreter's own traceback prefix on stderr then differs between the two
-- interpreters, never stdout.
--
-- Plain Lua 5.1: no 5.2+ stdlib, no bitwise or integer-division operators,
-- no LuaJIT-only escapes, no engine API.

local script = arg and arg[0] or ""
local derived = script:match("^(.*)/tools/wp40/t5_probe/coordinate_audit%.lua$")
local repo = arg and arg[1] or nil
if repo == nil or repo == "" then
	repo = derived or "."
end

local CORE_PATH = "mods/CORE/grug_core/init.lua"
local STRUCTURES_PATH = "mods/MAPGEN/grug_mapgen/structures.lua"
local GEOMETRY_PATH = "mods/MAPGEN/grug_mapgen/geometry.lua"

-- The mapgen water level.  NOT a free parameter and NOT part of either claim
-- above: geometry.lua only uses it to place MASK_MIN_Y, and the audit
-- asserts the resulting MASK_MIN_Y equals the -14 the contract names.  The
-- repository sets no water_level override anywhere, so the engine default
-- of 1 applies (reference_projects/luanti/src/defaultsettings.cpp; the same
-- value is pinned in the WP40 source catalog).
local WATER_LEVEL = 1

-- The vertical lattice of contract section 6.3.
local CENTRAL_MIN = -32
local CENTRAL_MAX = 47
local CHUNK_SPAN = 80

local MEASURED_KX = {8, 10, 11}
local MEASURED_KZ = 9
local MEASURED_KX_FREE_LO = -14
local MEASURED_KX_FREE_HI = 14
-- The deep-ocean family the contract rejected, for the contrast.
local REJECTED_KX_LO = 30
local REJECTED_KX_HI = 35

local failures = 0
local checks_run = 0

local function emit(text)
	print(text)
end

local function die(message)
	emit("FAIL " .. message)
	emit("COORDINATE AUDIT FAILED")
	io.stderr:write("coordinate_audit: " .. message .. "\n")
	error("coordinate audit failed", 0)
end

local function check(ok, label, detail)
	checks_run = checks_run + 1
	if ok then
		emit("ok   " .. label .. " -- " .. detail)
	else
		failures = failures + 1
		emit("FAIL " .. label .. " -- " .. detail)
	end
end

local function num(value)
	return string.format("%d", value)
end

local function slurp(path)
	local handle = io.open(path, "rb")
	if not handle then
		die("cannot read " .. path)
	end
	local text = handle:read("*a")
	handle:close()
	if not text or text == "" then
		die("empty source file " .. path)
	end
	return text
end

-- Verbatim extraction of one file-local function: from its exact signature
-- line to the first `end` line at the SAME indentation.  Deeper `end` lines
-- carry more indentation and therefore cannot match, so the terminator is
-- unambiguous without parsing.
local function extract_function(source, path, indent, name, args)
	local head = "\n" .. indent .. "local function " .. name .. "(" .. args ..
		")\n"
	local from, to = source:find(head, 1, true)
	if not from then
		die("signature of " .. name .. " not found in " .. path)
	end
	if source:find(head, to, true) then
		die("signature of " .. name .. " is not unique in " .. path)
	end
	local tail = "\n" .. indent .. "end\n"
	local stop = source:find(tail, to, true)
	if not stop then
		die("body terminator of " .. name .. " not found in " .. path)
	end
	return source:sub(from + 1, stop + #tail - 2)
end

local function compile_extract(text, name, env)
	local chunk, err = loadstring(text .. "\nreturn " .. name,
		"@" .. name .. "(extracted)")
	if not chunk then
		die("extracted " .. name .. " does not compile: " .. tostring(err))
	end
	setfenv(chunk, env)
	return chunk()
end

emit("== WP40 T5-0 coordinate audit (contract 6.2 and 6.4) ==")
emit("repo " .. repo)
emit("source " .. CORE_PATH)
emit("source " .. STRUCTURES_PATH)
emit("source " .. GEOMETRY_PATH)

--------------------------------------------------------------------------
-- Load grug_core's pure prefix and let it build its own anchor tables.
--------------------------------------------------------------------------

local core_src = slurp(repo .. "/" .. CORE_PATH)
local CUT_MARKER = "\nlocal storage = core.get_mod_storage()\n"
local cut_at = core_src:find(CUT_MARKER, 1, true)
if not cut_at then
	die("cut marker (the first load-time engine call) not found in " ..
		CORE_PATH)
end
local core_prefix = core_src:sub(1, cut_at)
if not core_prefix:find("function grug_core.bandit_camp_candidates(anchor)",
		1, true) then
	die("cut marker sits before the bandit-camp anchors in " .. CORE_PATH)
end

local core_env = {
	math = math, string = string, table = table, pairs = pairs,
	ipairs = ipairs, next = next, select = select, type = type,
	tostring = tostring, tonumber = tonumber, assert = assert,
	error = error, unpack = unpack, setmetatable = setmetatable,
	getmetatable = getmetatable, rawget = rawget, rawset = rawset,
}
local core_chunk, core_err = loadstring(core_prefix, "@" .. CORE_PATH)
if not core_chunk then
	die(CORE_PATH .. " prefix does not compile: " .. tostring(core_err))
end
setfenv(core_chunk, core_env)
local loaded_ok, load_err = pcall(core_chunk)
if not loaded_ok then
	die(CORE_PATH .. " prefix does not run headless: " .. tostring(load_err))
end

local gc = core_env.grug_core
if type(gc) ~= "table" then
	die(CORE_PATH .. " prefix did not define grug_core")
end
for _, name in ipairs({"capitals", "outpost_anchors", "outpost_candidates",
		"bandit_camp_anchors", "bandit_camp_candidates"}) do
	if gc[name] == nil then
		die("grug_core." .. name .. " missing from the loaded prefix")
	end
end

emit("== 0. constants, read out of the loaded sources ==")
emit("grug_core: CONTINENT_X_HALF " .. num(gc.CONTINENT_X_HALF) ..
	", CONTINENT_Z_MIN " .. num(gc.CONTINENT_Z_MIN) ..
	", CONTINENT_Z_MAX " .. num(gc.CONTINENT_Z_MAX))
emit("grug_core: CAMP_HALF " .. num(gc.CAMP_HALF) ..
	", OUTPOST_HALF " .. num(gc.OUTPOST_HALF) .. ", bandit half 0")

--------------------------------------------------------------------------
-- geometry.lua: the real module, plus the verbatim box_distance_range.
--------------------------------------------------------------------------

local build, build_err = loadfile(repo .. "/" .. GEOMETRY_PATH)
if not build then
	die(GEOMETRY_PATH .. " does not load: " .. tostring(build_err))
end
build = build()
if type(build) ~= "function" then
	die(GEOMETRY_PATH .. " did not return a build function")
end
-- cfg.inset is the documented headless stub (geometry.lua:30, :78): it
-- replaces the coast noise so no engine object is needed.  box_needs_mask
-- never samples it -- the whole point of that fast path -- so the stub
-- cannot influence anything this audit measures.
local geo = build({
	x_half = gc.CONTINENT_X_HALF,
	z_min = gc.CONTINENT_Z_MIN,
	z_max = gc.CONTINENT_Z_MAX,
	water_level = WATER_LEVEL,
	inset = function() return 0 end,
})

local geo_src = slurp(repo .. "/" .. GEOMETRY_PATH)
local bdr_src = extract_function(geo_src, GEOMETRY_PATH, "\t",
	"box_distance_range", "minp, maxp, grow")
local box_distance_range = compile_extract(bdr_src, "box_distance_range", {
	math = math,
	X_HALF = gc.CONTINENT_X_HALF,
	Z_MIN = gc.CONTINENT_Z_MIN,
	Z_MAX = gc.CONTINENT_Z_MAX,
})

local struct_src = slurp(repo .. "/" .. STRUCTURES_PATH)
local cc_src = extract_function(struct_src, STRUCTURES_PATH, "",
	"chunk_covers", "minp, maxp, x, z, half")
local chunk_covers = compile_extract(cc_src, "chunk_covers", {})

local THRESHOLD = geo.TAPER + geo.INSET_MAX
emit("geometry.lua: TAPER " .. num(geo.TAPER) .. ", INSET_MAX " ..
	num(geo.INSET_MAX) .. ", TAPER+INSET_MAX " .. num(THRESHOLD) ..
	", SHELL " .. num(geo.SHELL) .. ", SEA_FLOOR_CAP " ..
	num(geo.SEA_FLOOR_CAP) .. ", MASK_MIN_Y " .. num(geo.MASK_MIN_Y))
emit("extracted verbatim: box_distance_range (" .. num(#bdr_src) ..
	" bytes), chunk_covers (" .. num(#cc_src) .. " bytes)")

--------------------------------------------------------------------------
-- 1. Structure envelope.
--------------------------------------------------------------------------

emit("== 1. structure envelope (contract 6.4) ==")

local points = {}
local counts = {capital = 0, outpost = 0, bandit = 0}
local function add_point(kind, x, z, half)
	points[#points + 1] = {kind = kind, x = x, z = z, half = half}
	counts[kind] = counts[kind] + 1
end

-- Capitals.  structures.lua tests a capital footprint with the same
-- arithmetic chunk_covers performs, spelled out inline at
-- structures.lua:779-782, with half = CAMP_HALF.
local races = {}
for race_id in pairs(gc.capitals) do
	races[#races + 1] = race_id
end
table.sort(races)
for _, race_id in ipairs(races) do
	local capital = gc.capitals[race_id]
	add_point("capital", capital.x, capital.z, gc.CAMP_HALF)
end

-- Outposts: every candidate of every anchor, half = OUTPOST_HALF
-- (structures.lua:559-567, chunk_near_outpost).
local outposts = gc.outpost_anchors()
for i = 1, #outposts do
	local cands = gc.outpost_candidates(outposts[i])
	for c = 1, #cands do
		add_point("outpost", cands[c].x, cands[c].z, gc.OUTPOST_HALF)
	end
end

-- Bandit camps: every candidate of every anchor, half = 0
-- (structures.lua:761-769, chunk_near_bandit_camp).
local bandits = gc.bandit_camp_anchors()
for i = 1, #bandits do
	local cands = gc.bandit_camp_candidates(bandits[i])
	for c = 1, #cands do
		add_point("bandit", cands[c].x, cands[c].z, 0)
	end
end

emit("candidate points: capitals " .. num(counts.capital) .. " (half " ..
	num(gc.CAMP_HALF) .. "), outposts " .. num(counts.outpost) ..
	" (half " .. num(gc.OUTPOST_HALF) .. "), bandit camps " ..
	num(counts.bandit) .. " (half 0), total " .. num(#points))

check(#outposts == 24, "outpost anchor count",
	num(#outposts) .. " anchors, expected 24")
check(#bandits == 12, "bandit anchor count",
	num(#bandits) .. " anchors, expected 12")
check(#points == 138, "candidate point total",
	num(#points) .. " points, contract 6.4 says 138")

local env_x, env_z = 0, 0
for i = 1, #points do
	local p = points[i]
	local ax = math.abs(p.x) + p.half
	local az = math.abs(p.z) + p.half
	if ax > env_x then env_x = ax end
	if az > env_z then env_z = az end
end
emit("envelope: abs(x) at most " .. num(env_x) .. ", abs(z) at most " ..
	num(env_z))
check(env_x == 1354, "envelope x", num(env_x) .. ", contract 6.4 says 1354")
check(env_z == 1554, "envelope z", num(env_z) .. ", contract 6.4 says 1554")

local function central_min(k) return CENTRAL_MIN + CHUNK_SPAN * k end
local function central_max(k) return CENTRAL_MAX + CHUNK_SPAN * k end

-- Project every point onto the lattice with the extracted chunk_covers.
-- The k window is generous on purpose (one chunk of slack on each side): it
-- only bounds the search, chunk_covers alone decides membership.
local columns = {}
local column_count = 0
for i = 1, #points do
	local p = points[i]
	local kx_lo = math.floor((p.x - p.half - CENTRAL_MAX) / CHUNK_SPAN) - 1
	local kx_hi = math.floor((p.x + p.half - CENTRAL_MIN) / CHUNK_SPAN) + 1
	local kz_lo = math.floor((p.z - p.half - CENTRAL_MAX) / CHUNK_SPAN) - 1
	local kz_hi = math.floor((p.z + p.half - CENTRAL_MIN) / CHUNK_SPAN) + 1
	for kx = kx_lo, kx_hi do
		for kz = kz_lo, kz_hi do
			local minp = {x = central_min(kx), z = central_min(kz)}
			local maxp = {x = central_max(kx), z = central_max(kz)}
			if chunk_covers(minp, maxp, p.x, p.z, p.half) then
				local key = num(kx) .. "/" .. num(kz)
				if not columns[key] then
					columns[key] = {kx = kx, kz = kz}
					column_count = column_count + 1
				end
			end
		end
	end
end

emit("distinct (k_x, k_z) chunk columns: " .. num(column_count))
check(column_count == 122, "distinct column count",
	num(column_count) .. ", contract 6.4 says 122")

-- Deterministic per-row summary: explicit sort, never a pairs() walk.
local rows = {}
local row_order = {}
for _, col in pairs(columns) do
	local row = rows[col.kz]
	if not row then
		row = {n = 0, lo = col.kx, hi = col.kx}
		rows[col.kz] = row
		row_order[#row_order + 1] = col.kz
	end
	row.n = row.n + 1
	if col.kx < row.lo then row.lo = col.kx end
	if col.kx > row.hi then row.hi = col.kx end
end
table.sort(row_order)
local summed = 0
for i = 1, #row_order do
	local kz = row_order[i]
	local row = rows[kz]
	summed = summed + row.n
	emit("  k_z " .. num(kz) .. ": " .. num(row.n) .. " column(s), k_x " ..
		num(row.lo) .. ".." .. num(row.hi))
end
check(summed == column_count, "row summary is complete",
	num(summed) .. " of " .. num(column_count) .. " columns listed")

for i = 1, #MEASURED_KX do
	local kx = MEASURED_KX[i]
	local key = num(kx) .. "/" .. num(MEASURED_KZ)
	check(columns[key] == nil,
		"measured column (" .. num(kx) .. "," .. num(MEASURED_KZ) ..
			") is structure-free",
		columns[key] == nil and "absent from the 122-column set" or
			"PRESENT in the structure set")
end

local band_hits = 0
for kx = MEASURED_KX_FREE_LO, MEASURED_KX_FREE_HI do
	if columns[num(kx) .. "/" .. num(MEASURED_KZ)] then
		band_hits = band_hits + 1
	end
end
check(band_hits == 0,
	"k_z " .. num(MEASURED_KZ) .. " is structure-free over k_x " ..
		num(MEASURED_KX_FREE_LO) .. ".." .. num(MEASURED_KX_FREE_HI),
	num(band_hits) .. " structure column(s) in the band")

check(rows[MEASURED_KZ] == nil,
	"k_z " .. num(MEASURED_KZ) .. " carries no structure column at any k_x",
	rows[MEASURED_KZ] == nil and "the whole row is empty" or
		"the row is occupied")

local nearest_gap = nil
for i = 1, #row_order do
	local gap = math.abs(row_order[i] - MEASURED_KZ)
	if nearest_gap == nil or gap < nearest_gap then
		nearest_gap = gap
	end
end
emit("nearest occupied row to k_z " .. num(MEASURED_KZ) .. ": " ..
	num(nearest_gap) .. " chunk column(s) away")

--------------------------------------------------------------------------
-- 2. Ocean Mask derivation.
--------------------------------------------------------------------------

emit("== 2. ocean mask (contract 6.2) ==")

check(geo.SHELL == 16, "SHELL", num(geo.SHELL) .. ", contract 6.2 says 16")
check(THRESHOLD == 300, "TAPER+INSET_MAX",
	num(THRESHOLD) .. ", contract 6.2 says 300")
check(geo.MASK_MIN_Y == -14, "MASK_MIN_Y",
	num(geo.MASK_MIN_Y) .. ", contract 6.2 says -14")

-- SIGN CONVENTION.  lo is the inland-signed distance: POSITIVE inside the
-- continent rectangle, negative outside.  Three probes of geometry.lua's own
-- continent_distance pin that down, so "lo >= 300" cannot be misread as
-- "300 nodes away from land".
local sign_probes = {
	{0, 900, 800, "continent centre, deep inland"},
	{0, 0, -100, "middle of the strait, open water"},
	{2848, 900, -1348, "far out at sea beyond the flank"},
}
for i = 1, #sign_probes do
	local probe = sign_probes[i]
	local d = geo.continent_distance(probe[1], probe[2])
	check(d == probe[3],
		"continent_distance(" .. num(probe[1]) .. "," .. num(probe[2]) .. ")",
		num(d) .. " (" .. probe[4] .. "), expected " .. num(probe[3]))
end
check(sign_probes[1][3] > 0 and sign_probes[2][3] < 0,
	"sign convention: positive is inland",
	"inland " .. num(sign_probes[1][3]) .. " > 0 > open water " ..
		num(sign_probes[2][3]))

-- The threshold itself is a property of box_needs_mask, not an assumption:
-- a one-column box at inland distance 300 is skipped, the same box one node
-- nearer the strait is masked.  Both sit at y 47, above MASK_MIN_Y.
local function column_box(x, z)
	return {x = x, y = CENTRAL_MIN, z = z}, {x = x, y = CENTRAL_MAX, z = z}
end
local edge_in_min, edge_in_max = column_box(0, gc.CONTINENT_Z_MIN + THRESHOLD)
local edge_out_min, edge_out_max =
	column_box(0, gc.CONTINENT_Z_MIN + THRESHOLD - 1)
check(geo.box_needs_mask(edge_in_min, edge_in_max, 0) == false,
	"threshold behaviour at lo = " .. num(THRESHOLD),
	"box_needs_mask false")
check(geo.box_needs_mask(edge_out_min, edge_out_max, 0) == true,
	"threshold behaviour at lo = " .. num(THRESHOLD - 1),
	"box_needs_mask true")

local z_min_c = central_min(MEASURED_KZ)
local z_max_c = central_max(MEASURED_KZ)
emit("measured row k_z " .. num(MEASURED_KZ) .. ": central z [" ..
	num(z_min_c) .. "," .. num(z_max_c) .. "], central y [" ..
	num(CENTRAL_MIN) .. "," .. num(CENTRAL_MAX) .. "]")
check(CENTRAL_MAX >= geo.MASK_MIN_Y,
	"guard 1 does not decide",
	"maxp.y " .. num(CENTRAL_MAX) .. " is not below MASK_MIN_Y " ..
		num(geo.MASK_MIN_Y) .. ", so the underground fast path is not taken")

-- Independent confirmation that lo really is the minimum inland-signed
-- distance over the GROWN box: walk every column of the grown box through
-- geometry.lua's own continent_distance and compare the minimum with lo.
local function grown_min_distance(minp, maxp, grow)
	local best = nil
	for x = minp.x - grow, maxp.x + grow do
		for z = minp.z - grow, maxp.z + grow do
			local d = geo.continent_distance(x, z)
			if best == nil or d < best then best = d end
		end
	end
	return best
end

local function report_chunk(prefix, kx, expect_lo, expect_mask)
	local minp = {x = central_min(kx), y = CENTRAL_MIN, z = z_min_c}
	local maxp = {x = central_max(kx), y = CENTRAL_MAX, z = z_max_c}
	local grow = geo.SHELL
	local lo = box_distance_range(minp, maxp, grow)
	local ax_far = math.max(math.abs(minp.x), math.abs(maxp.x)) + grow
	local az_far = math.max(math.abs(minp.z), math.abs(maxp.z)) + grow
	local az_near = math.max(minp.z - grow, 0)
	local flank = gc.CONTINENT_X_HALF - ax_far
	local front = az_near - gc.CONTINENT_Z_MIN
	local back = gc.CONTINENT_Z_MAX - az_far
	local mask = geo.box_needs_mask(minp, maxp, grow)
	local inland = lo >= THRESHOLD
	emit(prefix .. " k_x " .. num(kx) .. ": central x [" .. num(minp.x) ..
		"," .. num(maxp.x) .. "], flank " .. num(flank) .. ", front " ..
		num(front) .. ", back " .. num(back) .. ", lo " .. num(lo) ..
		", lo>=" .. num(THRESHOLD) .. " " .. (inland and "yes" or "no") ..
		", box_needs_mask " .. tostring(mask))
	local label = "k_x " .. num(kx)
	if expect_lo ~= nil then
		check(lo == expect_lo, label .. " lo",
			num(lo) .. ", contract 6.2 says " .. num(expect_lo))
	end
	check(mask == expect_mask, label .. " box_needs_mask",
		tostring(mask) .. ", expected " .. tostring(expect_mask))
	-- Tie the extracted box_distance_range to the module's real
	-- box_needs_mask: if the extraction ever drifted from the function the
	-- module actually calls, this disagrees.
	local derived_mask = (maxp.y < geo.MASK_MIN_Y) or (lo < THRESHOLD)
	check(derived_mask == mask, label .. " extracted range agrees with module",
		"recomputed " .. tostring(derived_mask) .. ", module " ..
			tostring(mask))
	local grid = grown_min_distance(minp, maxp, grow)
	check(grid == lo, label .. " lo is the grown box minimum",
		"min continent_distance over the grown box " .. num(grid) ..
			" equals lo " .. num(lo))
	return lo, mask, inland
end

local EXPECTED_LO = {572, 572, 557}
local measured_lo = {}
for i = 1, #MEASURED_KX do
	local kx = MEASURED_KX[i]
	local lo, mask, inland = report_chunk("measured", kx, EXPECTED_LO[i], false)
	measured_lo[i] = lo
	check(mask == false and inland,
		"k_x " .. num(kx) .. " skipped because it is deep INLAND",
		"lo " .. num(lo) .. " is " .. num(lo - THRESHOLD) ..
			" nodes past the " .. num(THRESHOLD) ..
			"-node threshold, on the inland side")
end

emit("== 3. rejected coordinate family (contract 6.2) ==")
emit("a deep-ocean family does NOT escape the mask: same k_z, same y, only" ..
	" k_x moved out to sea")
local rejected_fired = 0
local rejected_total = 0
local rejected_worst = nil
for kx = REJECTED_KX_LO, REJECTED_KX_HI do
	rejected_total = rejected_total + 1
	local lo, mask = report_chunk("rejected", kx, nil, true)
	if rejected_worst == nil or lo > rejected_worst then rejected_worst = lo end
	if mask then rejected_fired = rejected_fired + 1 end
	check(lo < THRESHOLD, "k_x " .. num(kx) .. " lo below threshold",
		num(lo) .. " < " .. num(THRESHOLD))
	check(lo < 0, "k_x " .. num(kx) .. " lies outside the rectangle",
		"lo " .. num(lo) .. " is negative, i.e. open sea")
end
check(rejected_fired == rejected_total,
	"the whole rejected family is masked",
	num(rejected_fired) .. " of " .. num(rejected_total) ..
		" chunks fire the mask")

local measured_text = {}
for i = 1, #measured_lo do
	measured_text[i] = num(measured_lo[i])
end
emit("contrast: the measured family is SKIPPED with lo " ..
	table.concat(measured_text, ", ") .. " (all at least " .. num(THRESHOLD) ..
	", i.e. inland); the rejected family is MASKED, its least negative lo " ..
	"being " .. num(rejected_worst) .. " (i.e. at sea)")

emit("== summary ==")
emit("checks run " .. num(checks_run) .. ", failing " .. num(failures))
if failures == 0 then
	emit("COORDINATE AUDIT GREEN")
else
	emit("COORDINATE AUDIT FAILED")
	io.stderr:write("coordinate_audit: " .. num(failures) ..
		" check(s) failed\n")
	error("coordinate audit failed", 0)
end
