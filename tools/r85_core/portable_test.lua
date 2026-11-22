-- Round 85 lane CORE portable test (LuaJIT): a housing claim is one map chunk
-- (docs/planning/round85-plan.md §3.3, §4 CORE; docs/design/housing.md §1-§2).
--
--   luajit tools/r85_core/portable_test.lua <repo>
--
-- Runs the shipped bytes of grug_housing registry.lua, api.lua and
-- claim_mask.lua (a real mask built on a small constructed world) under stubs:
--   A  the record: the v3 text of the plan (twelve fields, kind and name
--      empty), read back with kind and name kept; only v3 loads, every other
--      record is returned as skipped (another version, a wrong field count,
--      a bad number);
--   B  the chunk arithmetic of the registry equals claim_mask.lua's, at
--      negative coordinates and at the edges; claim_at, claims_in,
--      claim_bounds and the arrival cube through the registry's own readers;
--   C  one claim record per chunk: a draft, an active and an expired claim
--      hold their chunk; after the removal the chunk is free;
--   D  every refusal: depth, faction, one claim, no mask, each reason id the
--      mask returns (through the real mask: claim ground, a road, the sea)
--      with its own message, the chunk taken, the quota, the chunk's edge,
--      the cube; a message for every reason id the mask can name;
--   E  the quota over every claim record (drafts and expired ones included):
--      refused above half, the exact half allowed, a crumbled draft and a
--      pick-up free their share, a refuel changes nothing, and the kept
--      count always equals one rebuilt from the records;
--   F  api.lua: without a mask every placement is refused with its line;
--      with one, the quota names the kind's area; a record of another
--      version is reported as severe, except at the start that applies a
--      map reset (which clears it); quota_taken is nil without a mask.
-- Prints "R85 CORE PORTABLE PASS checks=<n>" or the failures and raises.
local repo = assert(arg[1], "usage: portable_test.lua <repo>")
local checks, failures = 0, {}
local function check(ok, label)
	checks = checks + 1
	if not ok then failures[#failures + 1] = label end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) .. ", expected " ..
		tostring(expected) .. ")")
end

local CM = dofile(repo .. "/mods/PLAYER/grug_housing/claim_mask.lua")
local factory = dofile(repo .. "/mods/PLAYER/grug_housing/registry.lua")
local clock = 1000
local function new_storage(data)
	data = data or {}
	return {data = data,
		get_string = function(key) return data[key] or "" end,
		set_string = function(key, value) data[key] = value ~= "" and value or nil end,
		keys = function()
			local keys = {}
			for key in pairs(data) do keys[#keys + 1] = key end
			return keys
		end}
end
local function new_model(storage)
	local model = factory({storage = storage, now = function() return clock end})
	return model, model.load()
end

-- ---------------------------------------------------------------------------
-- A  the record
-- ---------------------------------------------------------------------------
local FORMAT = "v3|owner|x|y|z|placed_at|activated_at|paid_until|expired_for|perms|kind|name"
local function record_text(values)
	local out = {}
	for field in FORMAT:gmatch("[^|]+") do out[#out + 1] = tostring(values[field] or field) end
	return table.concat(out, "|")
end
do
	local _, bars = FORMAT:gsub("|", "")
	eq(bars + 1, 12, "A the agreed record has twelve fields")
	local storage = new_storage()
	local M = new_model(storage)
	local claim = M.create("ann", {x = -33, y = -100, z = 48})
	eq(storage.data["claim:" .. claim.id], record_text({owner = "ann", x = -33, y = -100, z = 48,
		placed_at = 1000, activated_at = 0, paid_until = 1000, expired_for = 1000, perms = "",
		kind = "", name = ""}), "A a new draft writes the v3 text, kind and name empty")
	M.set_permission(claim, "bob", "interact")
	M.set_permission(claim, "cid", "everything")
	eq(storage.data["claim:" .. claim.id], record_text({owner = "ann", x = -33, y = -100, z = 48,
		placed_at = 1000, activated_at = 0, paid_until = 1000, expired_for = 1000,
		perms = "bob=interact,cid=everything", kind = "", name = ""}),
		"A permissions in the tenth field")
	-- a later round fills kind and name: read and written back unchanged
	storage.data["claim:9"] = record_text({owner = "dee", x = 500, y = 3, z = 500,
		placed_at = 900, activated_at = 950, paid_until = 99999, expired_for = 0, perms = "",
		kind = "orc", name = "The Long Hearth"})
	storage.data["claim:10"] = "v2|eve|100|10|100|900|950|99999|0|bob=interact"
	storage.data["claim:11"] = "v4|fay|0|0|0|1|1|1|1||||"
	storage.data["claim:12"] = record_text({owner = "gus", x = 1000, y = 1, z = 1000,
		placed_at = 1, activated_at = 1, paid_until = 1, expired_for = 1, perms = "",
		kind = "", name = ""}) .. "|"
	storage.data["claim:13"] = record_text({owner = "hal", x = "soon", y = 1, z = 1,
		placed_at = 1, activated_at = 1, paid_until = 1, expired_for = 1, perms = "",
		kind = "", name = ""})
	local N, skipped = new_model(storage)
	eq(N.claim_count(), 2, "A only the two v3 records load")
	eq(table.concat(skipped, ","), "claim:10,claim:11,claim:12,claim:13",
		"A the others are returned as skipped, sorted")
	local dee = N.claim_by_id(9)
	check(dee and dee.kind == "orc" and dee.name == "The Long Hearth", "A kind and name read")
	N.add_fuel(N.claim_by_id(9), 1)
	check(storage.data["claim:9"]:sub(-20) == "|orc|The Long Hearth", "A ...and written back")
	eq(N.claim_by_id(claim.id).permissions.cid, "everything", "A permissions read back")
	check(storage.data["claim:10"] ~= nil, "A a skipped record stays in storage (the reset clears it)")
	N.map_reset()
	local left = 0
	for key in pairs(storage.data) do if key:match("^claim:") then left = left + 1 end end
	eq(left, 0, "A the map reset clears every claim key, whatever its version")
end

-- ---------------------------------------------------------------------------
-- B  the chunk arithmetic and the readers
-- ---------------------------------------------------------------------------
do
	local M = new_model(new_storage())
	local same = true
	for x = -2000, 2000 do
		same = same and M.chunk_of(x) == CM.chunk_of(x) and
			M.chunk_of(x) == math.floor((math.floor(x / 16) + 2) / 5)
	end
	check(same, "B the registry's chunk equals claim_mask.lua's and the engine's (-2000..2000)")
	eq(M.CHUNK, CM.CHUNK, "B the chunk side")
	-- a stone at -40 / 60: chunk (-1, 1), x -112 .. -33, z 48 .. 127
	local c = M.create("ann", {x = -40, y = 5, z = 60})
	local x0, z0, x1, z1 = M.claim_bounds(c)
	local a0, b0, a1, b1 = CM.chunk_bounds(-1, 1)
	check(x0 == -112 and x1 == -33 and z0 == 48 and z1 == 127 and
		x0 == a0 and z0 == b0 and x1 == a1 and z1 == b1, "B claim_bounds is the chunk's")
	local cx, cz = M.claim_chunk(c)
	check(cx == -1 and cz == 1 and M.chunk_claim(-1, 1) == c, "B claim_chunk and chunk_claim")
	local inside = true
	for _, p in ipairs({{-112, 48}, {-33, 48}, {-112, 127}, {-33, 127}, {-72, 88}}) do
		inside = inside and M.claim_at({x = p[1], y = 0, z = p[2]}) == c
	end
	check(inside, "B claim_at: the four corners and the middle")
	local outside = true
	for _, p in ipairs({{-113, 48}, {-32, 48}, {-112, 47}, {-112, 128}, {-32, 128}, {-113, 47}}) do
		outside = outside and M.claim_at({x = p[1], y = 0, z = p[2]}) == nil
	end
	check(outside, "B claim_at: one node beyond each edge and corner")
	check(M.claim_at({x = -33.49, y = 0, z = 127.4}) == c and
		M.claim_at({x = -32.5, y = 0, z = 100}) == nil, "B claim_at rounds to the node")
	check(M.claim_at({x = -50, y = -100, z = 60}) == c and
		M.claim_at({x = -50, y = -101, z = 60}) == nil and
		M.claim_at({x = -50, y = 31000, z = 60}) == c, "B from MIN_Y upward, no top")
	eq(#M.claims_in(-200, -200, -113, 300), 0, "B claims_in: a rectangle ending one node west")
	eq(#M.claims_in(-200, -200, -112, 47), 0, "B claims_in: ...or one node south")
	eq(M.claims_in(-112, 127, -112, 127)[1], c, "B claims_in: the corner column")
	eq(M.claims_in(-33, 48, 500, 500)[1], c, "B claims_in: a rectangle from the far corner")
	local d = M.create("bob", {x = 10, y = 5, z = 60})
	local list = M.claims_in(-200, 0, 200, 200)
	check(#list == 2 and list[1] == c and list[2] == d, "B claims_in: both, by id")
	check(M.in_arrival_cube(c, {x = -39, y = 8, z = 61}) and
		M.arrival_cube_claim({x = -41, y = 6, z = 59}) == c and
		not M.in_arrival_cube(c, {x = -38, y = 6, z = 60}), "B the arrival cube above the stone")
	M.activate(c, 5)
	check(M.protects({x = -112, y = 0, z = 127}, "stranger", function() return false end) and
		not M.protects({x = -113, y = 0, z = 127}, "stranger", function() return false end),
		"B protection ends at the chunk's edge")
end

-- ---------------------------------------------------------------------------
-- The constructed world and its real mask (claim_mask.lua): one Accord zone
-- (level 11-20) over x and z -352 .. 447 (chunks -4 .. 5), a road along
-- z 400 from x 200 to 440, and one quest-named kind on the 32 x 32 cells
-- i, j = 0 .. 4 (x and z 0 .. 159): 25 cells, ground 25600 columns, limit
-- 12800.
-- ---------------------------------------------------------------------------
local VALE = {id = "vale", faction = "accord", level_min = 11, level_max = 20,
	territory_rule = "accord_home"}
local spawn = CM.new_spawn()
local kind = {id = "meadow", quest_target = true}
CM.add_zone_spawn(spawn, "vale", function(fn)
	for j = 0, 4 do
		for i = 0, 4 do fn(i, j, {kind = kind}) end
	end
end, {}, {}, true)
local mask = CM.build({bounds = {min_x = -352, max_x = 447, min_z = -352, max_z = 447},
	zones = {VALE},
	water_at = function() return "land" end,
	zone_at = function() return VALE end,
	territory_at = function() return "accord_home" end,
	feature_in = function() return nil end,
	roads = {{id = "r", X = {200, 440}, Z = {400, 400}, R = {}, reach = 4.5}},
	cities = {}, spawn = spawn}, {})
eq(mask.kind_by_id["vale/meadow"].limit, 12800, "the kind's limit: half of 25 cells")
local blocked = {}
local world = {mask = mask,
	cube_clear = function(pos) return not blocked[pos.x .. "/" .. pos.z] end,
	kind_name = function(id) return id == "vale/meadow" and "Vale Meadows" or id end}

-- ---------------------------------------------------------------------------
-- C  one claim per chunk
-- ---------------------------------------------------------------------------
do
	clock = 1000
	local M = new_model(new_storage())
	local function code(name, x, z)
		local ok, c = M.validate(name, "accord", {x = x, y = 10, z = z}, world)
		return ok and "ok" or c
	end
	-- chunk (-3, -3): x and z -272 .. -193; no quest ground there
	local draft = M.create("ann", {x = -230, y = 10, z = -230})
	eq(code("bob", -200, -260), "taken", "C a draft holds its chunk")
	M.activate(draft, 5)
	eq(code("bob", -260, -200), "taken", "C an active claim holds it")
	clock = draft.paid_until + 1
	check(not M.is_active(draft), "C (the claim has run out)")
	eq(code("bob", -271, -271), "taken", "C an expired claim holds it")
	eq(code("bob", -150, -230), "ok", "C the chunk east is free")
	M.remove(draft, "picked_up")
	eq(code("bob", -200, -260), "ok", "C after the pick-up the chunk is free")
	clock = 1000
end

-- ---------------------------------------------------------------------------
-- D  every refusal
-- ---------------------------------------------------------------------------
do
	clock = 1000
	local M = new_model(new_storage())
	local function try(name, faction, x, y, z, w)
		local ok, code, message, extra = M.validate(name, faction, {x = x, y = y, z = z}, w or world)
		return ok and "ok" or code, message, extra
	end
	eq(try("ann", "accord", -230, 10, -230), "ok", "D claim ground: accepted")
	eq(try("ann", "accord", -230, -101, -230), "too_deep", "D below y -100")
	eq(try("ann", "nobody", -230, 10, -230), "no_faction", "D no faction")
	eq(try("ann", "accord", -230, 10, -230, {cube_clear = world.cube_clear}), "no_mask",
		"D no mask: every placement refused")
	local code, message = try("ann", "accord", 300, 10, 410)
	check(code == "road" and message == M.MESSAGES.road, "D the mask's road, its own message")
	code, message = try("ann", "throng", -230, 10, -230)
	check(code == "enemy" and message == M.MESSAGES.enemy, "D the other faction's zone: enemy")
	code = try("ann", "accord", 600, 10, 0)
	eq(code, "sea", "D beyond the world plan: the mask's sea")
	M.create("bob", {x = -150, y = 10, z = -230})
	eq(try("ann", "accord", -170, 10, -210), "taken", "D the chunk taken")
	M.create("other", {x = 88, y = 10, z = 88})
	M.create("third", {x = 88, y = 10, z = 8})
	local q, qmessage, qkind = try("ann", "accord", 8, 10, 88)
	check(q == "quota" and qkind == "vale/meadow" and
		qmessage:find("Vale Meadows", 1, true) ~= nil, "D the quota, naming the kind's area")
	eq(try("ann", "accord", -272, 10, -230), "edge", "D on the chunk's west edge")
	eq(try("ann", "accord", -230, 10, -193), "edge", "D on its north edge")
	blocked["-230/-230"] = true
	eq(try("ann", "accord", -230, 10, -230), "cube", "D the arrival cube blocked")
	blocked["-230/-230"] = nil
	M.create("ann", {x = -230, y = 10, z = -230})
	eq(try("ann", "accord", -230, 10, -130), "already_placed", "D one claim per player")
	-- a message for every reason id the mask can name (claim_mask.lua's list)
	local missing = {}
	for _, id in ipairs({"shelf", "sea", "enemy", "low_level", "high_level", "not_home",
			"town", "deep_water", "site", "landmark", "road", "camp", "leader", "place", "rare",
			"capital_ring", "no_faction", "too_deep", "already_placed", "no_mask", "taken",
			"quota", "edge", "cube", "not_ground"}) do
		local text = M.MESSAGES[id]
		if type(text) ~= "string" or text == "" or text:find("101", 1, true) then
			missing[#missing + 1] = id
		end
	end
	eq(table.concat(missing, ","), "", "D every reason has its own line, none of the old square")
	eq(M.MESSAGES.capital_zone, nil, "D the capital zones' gate is gone")
end

-- ---------------------------------------------------------------------------
-- E  the quota
-- ---------------------------------------------------------------------------
do
	clock = 1000
	local storage = new_storage()
	local M = new_model(storage)
	local function taken()
		return M.quota_taken(mask)["vale/meadow"] or 0
	end
	local function rebuilt()
		local fresh = new_model(storage)
		return fresh.quota_taken(mask)["vale/meadow"] or 0
	end
	local function code(name, x, z)
		local ok, c = M.validate(name, "accord", {x = x, y = 10, z = z}, world)
		return ok and "ok" or c
	end
	local cols = {}
	for _, row in ipairs(mask.kind_columns(1, 1)) do cols["1,1"] = row[2] end
	for _, row in ipairs(mask.kind_columns(1, 0)) do cols["1,0"] = row[2] end
	for _, row in ipairs(mask.kind_columns(0, 1)) do cols["0,1"] = row[2] end
	for _, row in ipairs(mask.kind_columns(2, 1)) do cols["2,1"] = row[2] end
	check(cols["1,1"] == 6400 and cols["1,0"] == 3840 and cols["0,1"] == 3840 and
		cols["2,1"] == 2560, "E the chunks' columns of the kind")
	eq(taken(), 0, "E nothing taken")
	local draft = M.create("ann", {x = 88, y = 10, z = 88})
	eq(taken(), 6400, "E a draft takes its columns")
	local spent = M.create("bob", {x = 88, y = 10, z = 8})
	M.activate(spent, 5)
	clock = spent.paid_until + 1
	check(not M.is_active(spent), "E (bob's claim has run out)")
	eq(taken(), 10240, "E an expired claim keeps its columns")
	eq(taken(), rebuilt(), "E the kept count equals one rebuilt from the records")
	eq(code("cid", 8, 88), "quota", "E above half refused (10240 + 3840 > 12800)")
	eq(code("cid", 168, 88), "ok", "E the exact half allowed (10240 + 2560 = 12800)")
	eq(code("cid", -230, -230), "ok", "E a chunk without the kind is not limited")
	eq(M.add_fuel(spent, 3), 3, "E a refuel")
	eq(taken(), 10240, "E ...changes nothing")
	M.remove(draft, "draft_expired")
	eq(taken(), 3840, "E the crumbled draft frees its share")
	eq(code("cid", 8, 88), "ok", "E ...and the chunk it blocked is allowed")
	M.create("cid", {x = 8, y = 10, z = 88})
	eq(taken(), 7680, "E the new claim takes its columns")
	M.remove(spent, "picked_up")
	eq(taken(), 3840, "E a pick-up frees its share")
	eq(taken(), rebuilt(), "E the kept count still equals a rebuilt one")
	M.map_reset()
	eq(taken(), 0, "E the map reset leaves nothing taken")
	clock = 1000
end

-- ---------------------------------------------------------------------------
-- F  api.lua
-- ---------------------------------------------------------------------------
local function load_api(data, pending)
	local severe = {}
	rawset(_G, "core", {
		get_modpath = function(name) return repo .. "/mods/PLAYER/" .. name end,
		get_mod_storage = function()
			return {get_string = function(_, k) return data[k] or "" end,
				set_string = function(_, k, v) data[k] = v ~= "" and v or nil end,
				get_keys = function()
					local keys = {}
					for k in pairs(data) do keys[#keys + 1] = k end
					return keys
				end}
		end,
		get_node_or_nil = function() return {name = "air"} end,
		log = function() end,
	})
	rawset(_G, "grug_core", {
		map_reset = {clear = function(_, fn) if pending then fn() end end,
			pending = function() return pending end},
		severe = {report = function(source, summary, details, key)
			severe[#severe + 1] = {source = source, summary = summary, details = details, key = key}
		end},
		zone_authority_installed = function() return true end,
		get_player_faction = function() return "accord" end,
	})
	rawset(_G, "grug_mobs", {spawn_regions = {area_by_tag = function(tag)
		return tag == "vale/meadow" and {name = "Vale Meadows"} or nil
	end}})
	rawset(_G, "grug_housing", {})
	dofile(repo .. "/mods/PLAYER/grug_housing/api.lua")
	return grug_housing, severe
end
do
	local old = {["claim:3"] = "v2|eve|100|10|100|900|950|99999|0|", ["player:eve"] = "v2|placed|3"}
	local H, severe = load_api(old, false)
	check(#severe == 1 and severe[1].key == "claim_records" and severe[1].details == "claim:3",
		"F a v2 record without a reset: one severe report naming it")
	eq(H.model.claim_count(), 0, "F ...and it is not loaded")
	local _, quiet = load_api({["claim:3"] = old["claim:3"]}, true)
	eq(#quiet, 0, "F at the start that applies a map reset: no report (the reset clears it)")
	H = load_api({}, false)
	check(H.RADIUS == nil and H.CHUNK == 80 and H.claim_bounds and H.chunk_claim,
		"F the claim size is the chunk, no radius")
	local player = {get_player_name = function() return "ann" end}
	local ok, code, message = H.validate_placement(player, {x = 88, y = 10, z = 88})
	check(not ok and code == "no_mask" and message == H.model.MESSAGES.no_mask,
		"F no mask: refused with its line")
	eq(H.quota_taken(), nil, "F no mask: no quota count")
	H.mask = mask
	check(H.validate_placement(player, {x = 88, y = 10, z = 88}) == true, "F with the mask: allowed")
	H.model.create("bob", {x = 88, y = 10, z = 88})
	H.model.create("cid", {x = 88, y = 10, z = 8})
	ok, code, message = H.validate_placement(player, {x = 8, y = 10, z = 88})
	check(not ok and code == "quota" and message == ("This claim square (80 x 80) would put " ..
		"more than half of Vale Meadows under claims; half of it stays free for the " ..
		"creatures quests send you after."),
		"F the quota names the kind's area (" .. tostring(message) .. ")")
	eq(H.quota_taken()["vale/meadow"], 10240, "F quota_taken for the preview")
	check(H.column_problem("accord", "land", VALE, false) == nil and
		H.column_problem("accord", "land", VALE, "hard_protected") == "town",
		"F column_problem: territory false judges the zone alone")
	local capital = {faction = "accord", level_min = 20, level_max = 30, civic_no_hostiles = true,
		territory_rule = "accord_home"}
	eq(H.column_problem("accord", "land", capital, "accord_home"), nil,
		"F the capital zones are claim ground for the column rule")
end

if #failures > 0 then
	for _, failure in ipairs(failures) do print("FAIL " .. failure) end
	error(("R85 CORE PORTABLE FAIL %d of %d checks"):format(#failures, checks), 0)
end
print(("R85 CORE PORTABLE PASS checks=%d"):format(checks))
