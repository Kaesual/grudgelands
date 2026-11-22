-- Round 86 lane PREVIEW portable test (LuaJIT): the Claim Stone's placement
-- preview per map chunk (docs/planning/round86-plan.md §4 PREVIEW, ruling 2;
-- docs/design/housing.md §2 "Placement preview").
--
--   luajit tools/r86_preview/portable_test.lua <repo>
--
-- Runs the shipped bytes of grug_housing api.lua (with registry.lua and
-- preview.lua), a real mask of claim_mask.lua built on a small constructed
-- world, and grug_map minimap_view.lua, base.lua and minimap.lua on a fake
-- engine. Checks:
--   A  the preview's answer per chunk equals placement's (validate through
--      api.lua's validate_placement at the chunk's middle): both factions
--      over 13 x 13 chunks around the origin (negative coordinates
--      included), at the start, after placements, at a full quota and after
--      a removal; a chunk the preview allows takes a stone inside it and
--      refuses one on its edge ("edge", not the chunk's sake);
--   Q  the quota per chunk: placements fill a quest kind's half, the chunk
--      with a large share turns "quota" while a chunk with a small share of
--      the same kind stays allowed; a removal frees it again; a chunk that
--      holds two kinds' ground (the tie cell) answers for both;
--   R  every reason id the mask can name (a mask that names each in turn)
--      answers the same in the preview and in validate, an unknown one as
--      "not_ground"; a claim already in the chunk is "taken"; no mask
--      refuses every chunk as "no_mask";
--   H  the hint line: one short line per code ("This square: ..."), a hint
--      for every refusal the registry has a message for, the quota names
--      the kind's area, no mask says so in two lines;
--   M  the minimap's claim mode (the real minimap.lua): on with every item
--      of the stone item set (two kinds give the same picture), off with
--      another item or without a faction; the cell texture's red covers
--      exactly the refused chunks, pixel for pixel; a grid line on every
--      chunk edge; the player's chunk framed green and filled green when
--      free; every `[fill` valid by the engine's checks; the line beside
--      the bezel names the player's chunk and goes with claim mode; a
--      placement and a removal by another player show at once, a still
--      player sends nothing, crossing a chunk edge inside one cell moves
--      the frame and the line; no mask: every chunk red and its line; the
--      base bakes no Claim Stone overlay any more; the line's dark box
--      (fix round 1) shows exactly with the line and fits it;
--   B  the box's width estimate against the drawn widths, and every hint
--      in its box at HUD and GUI scaling 1 and 1.5.
-- Prints "R86 PREVIEW PORTABLE PASS checks=<n>" or the failures and raises.
local repo = assert(arg[1], "usage: portable_test.lua <repo>")
local floor = math.floor
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

-- ---------------------------------------------------------------------------
-- A constructed world and its real mask (after tools/r85_mask): an Accord
-- claim zone x -192 .. 127, a capital zone 128 .. 287 with its city, a
-- low-level zone west of it, contested land east, a Throng zone north of z
-- 208; two roads, a village, a landmark, a camp, a leader, a quest place
-- and a rare's route.
-- ---------------------------------------------------------------------------
local CM = dofile(repo .. "/mods/PLAYER/grug_housing/claim_mask.lua")
local ZONES = {
	acc_low = {id = "acc_low", faction = "accord", level_min = 1, level_max = 10,
		territory_rule = "accord_home"},
	acc_claim = {id = "acc_claim", faction = "accord", level_min = 11, level_max = 20,
		territory_rule = "accord_home"},
	acc_cap = {id = "acc_cap", faction = "accord", level_min = 20, level_max = 30,
		civic_no_hostiles = true, territory_rule = "accord_home"},
	contested = {id = "contested", level_min = 31, level_max = 40,
		territory_rule = "contested_land"},
	thr_claim = {id = "thr_claim", faction = "throng", level_min = 21, level_max = 30,
		territory_rule = "throng_home"},
}
local function zone_of(x, z)
	if z >= 208 then return ZONES.thr_claim end
	if x < -192 then return ZONES.acc_low end
	if x < 128 then return ZONES.acc_claim end
	if x < 288 then return ZONES.acc_cap end
	return ZONES.contested
end
local function city_member(x, z) return x >= 178 and x <= 238 and z >= -130 and z <= -70 end
local CITY = {id = "cap", anchor = {x = 208, z = -100}, rows = {}}
for lz = -30, 30 do CITY.rows[lz] = {-30, 30} end
local LANDMARK = {x = 60, z = 20}
local function water_of(x, z)
	if x >= -100 and x <= -90 and z >= -100 and z <= -60 then return "planned_water" end
	if z < -360 then return "coastal_shelf" end
	return "land"
end
local function territory_of(x, z)
	if city_member(x, z) or (x == LANDMARK.x and z == LANDMARK.z) then return "hard_protected" end
	return zone_of(x, z).territory_rule
end
local BOXES = {{kind = "site", min_x = -260, max_x = -240, min_z = 300, max_z = 320}}
local world = {bounds = {min_x = -400, max_x = 400, min_z = -400, max_z = 400},
	zones = {ZONES.acc_low, ZONES.acc_claim, ZONES.acc_cap, ZONES.contested, ZONES.thr_claim}}
function world.water_at(x, z) return water_of(x, z) end
function world.zone_at(x, z) return zone_of(x, z) end
function world.territory_at(x, z) return territory_of(x, z) end
function world.height_at() return 10 end
function world.feature_in(x0, z0, x1, z1, margin)
	for _, b in ipairs(BOXES) do
		if b.min_x - margin <= x1 and b.max_x + margin >= x0 and b.min_z - margin <= z1 and
				b.max_z + margin >= z0 then
			return b.kind, "village"
		end
	end
	local a0, c0, a1, c1 = x0 - margin, z0 - margin, x1 + margin, z1 + margin
	if LANDMARK.x >= a0 and LANDMARK.x <= a1 and LANDMARK.z >= c0 and LANDMARK.z <= c1 then
		return "landmark", "functional:1"
	end
	if 178 <= a1 and 238 >= a0 and -130 <= c1 and -70 >= c0 then return "town", "hard:cap" end
	return nil
end
world.roads = {
	{id = "road:1", X = {-400, 0, 400}, Z = {250.3, 250.3, 250.3}, R = {5, 5, 5}, reach = 3},
	{id = "road:2", X = {-30.5, 0}, Z = {-60.5, -60.5}, R = {5, 5}, reach = 2.52},
}
world.cities = {CITY}
local spawn = CM.new_spawn()
local function region(kind_id, quest, camp)
	return {kind = {id = kind_id, quest_target = quest}, camp = camp}
end
-- "meadow" (a quest kind): 16 cells in chunks (-2 .. 0, -2 .. 0), one far
-- cell and the tie cell (4, 0) the capital zone's "commons" holds too
local CLAIM_CELLS = {}
for j = -4, -1 do for i = -4, -1 do CLAIM_CELLS[#CLAIM_CELLS + 1] = {i, j, "meadow"} end end
CLAIM_CELLS[#CLAIM_CELLS + 1] = {-3, 3, "camp"}
CLAIM_CELLS[#CLAIM_CELLS + 1] = {1, 5, "plain"}
CLAIM_CELLS[#CLAIM_CELLS + 1] = {3, 5, "meadow"}
CLAIM_CELLS[#CLAIM_CELLS + 1] = {4, 0, "meadow"}
local CAP_CELLS = {{4, 0, "commons"}, {5, 0, "commons"}, {5, 1, "commons"}}
local function each(cells)
	return function(fn)
		for _, c in ipairs(cells) do
			if c[3] == "camp" then
				fn(c[1], c[2], region("bandits", nil, {id = "bandits"}))
			else
				fn(c[1], c[2], region(c[3], c[3] ~= "plain"))
			end
		end
	end
end
CM.add_zone_spawn(spawn, "acc_claim", each(CLAIM_CELLS), {{x = -128, z = -300}},
	{{x = -80, z = -209}}, true)
CM.add_zone_spawn(spawn, "acc_cap", each(CAP_CELLS), {}, {}, true)
CM.add_rare_route(spawn, {{x = 30, z = 360}, {x = 300, z = 300}})
world.spawn = spawn
local mask = CM.build(world, {})

-- ---------------------------------------------------------------------------
-- The fake engine: what api.lua and minimap.lua call
-- ---------------------------------------------------------------------------
local data = {}
local joins, steps, sent = {}, {}, 0
local players, windows, factions = {}, {}, {}
rawset(_G, "core", {
	get_current_modname = function() return "grug_map" end,
	get_modpath = function(name)
		local roots = {grug_map = "/mods/PLAYER/grug_map", grug_housing = "/mods/PLAYER/grug_housing"}
		return roots[name] and repo .. roots[name] or nil
	end,
	get_modnames = function() return {"grug_map"} end,
	get_worldpath = function() return "/nonexistent-world" end,
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
	get_us_time = function() return 0 end,
	log = function() end,
	settings = {get = function() return nil end},
	encode_png = function(_, _, bytes) return bytes end,
	safe_file_write = function() return true end,
	dynamic_add_media = function() return true end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_leaveplayer = function() end,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	get_connected_players = function()
		local list = {}
		for _, p in pairs(players) do list[#list + 1] = p end
		table.sort(list, function(a, b) return a.name < b.name end)
		return list
	end,
	get_player_by_name = function(name) return players[name] end,
	get_player_window_information = function(name) return windows[name] end,
	get_timeofday = function() return 0.5 end,
})
rawset(_G, "grug_core", {DAY_PHASE_START = 0.1875, DAY_PHASE_END = 0.8125,
	faction_ids = {"accord", "throng"},
	map_reset = {clear = function() end, pending = function() return false end},
	severe = {report = function() end},
	zone_authority_installed = function() return true end,
	get_player_faction = function(name) return factions[name] end,
	settlement_socket_settlements = function() return {} end,
	settlement_sockets_at = function() return {} end,
	start_identities = function() return {} end})
rawset(_G, "grug_mobs", {spawn_regions = {area_by_tag = function(tag)
	return tag == "acc_claim/meadow" and {name = "Meadow Fields"} or nil
end}})
rawset(_G, "grug_housing", {})
dofile(repo .. "/mods/PLAYER/grug_housing/api.lua")
local H = grug_housing
local model = H.model
H.mask = mask
local P = dofile(repo .. "/mods/PLAYER/grug_housing/preview.lua")

local function new_player(name, pos)
	local meta = {}
	local p = {name = name, pos = pos, wield = "", huds = {}, next_id = 0}
	function p:get_player_name() return self.name end
	function p:get_pos() return {x = self.pos.x, y = self.pos.y, z = self.pos.z} end
	function p:get_look_horizontal() return 0 end
	function p:get_wielded_item()
		local item = self.wield
		return {get_name = function() return item end}
	end
	-- each item in its own slot: a new item is a slot switch
	function p:get_wield_index()
		return self.wield == "" and 1 or self.wield == H.STONE_ITEM and 2 or
			self.wield == "test:account_stone" and 4 or 3
	end
	function p:get_meta()
		return {get_string = function(_, k) return meta[k] or "" end,
			set_string = function(_, k, value) meta[k] = value end}
	end
	function p:hud_add(def)
		self.next_id = self.next_id + 1
		local copy = {}
		for k, value in pairs(def) do copy[k] = value end
		self.huds[self.next_id] = copy
		return self.next_id
	end
	function p:hud_change(id, stat, value)
		sent = sent + 1
		self.huds[id][stat] = value
	end
	function p:hud_remove(id) self.huds[id] = nil end
	function p:hud_set_flags() end
	function p:set_minimap_modes() end
	return p
end

-- validate's answer for a stone of `faction` in the middle of chunk (cx, cz)
-- (a character with no record of its own), through api.lua
local probe = new_player("probe", {x = 0, y = 10, z = 0})
local function placement(faction, cx, cz, dx, dz)
	factions.probe = faction
	local x0, z0 = CM.chunk_bounds(cx, cz)
	local ok, code, _, kind = H.validate_placement(probe,
		{x = x0 + (dx or 40), y = 10, z = z0 + (dz or 40)})
	return ok, code, kind
end
-- A: preview and placement agree on every chunk of both factions.
local FACTIONS = {"accord", "throng"}
local function agree(label)
	local bad, allowed, refused = 0, 0, 0
	local first
	for _, f in ipairs(FACTIONS) do
		for cz = -6, 6 do
			for cx = -6, 6 do
				local code, kind = H.chunk_refusal(f, cx, cz)
				local ok, vcode, vkind = placement(f, cx, cz)
				local same
				if code == nil then
					same = ok == true
					allowed = allowed + 1
				else
					same = not ok and vcode == code and vkind == kind
					refused = refused + 1
				end
				if not same then
					bad = bad + 1
					first = first or ("%s %d,%d: preview %s, validate %s"):format(f, cx, cz,
						tostring(code), tostring(ok and "ok" or vcode))
				end
			end
		end
	end
	check(bad == 0, ("A %s: preview equals placement on %d chunks (%d allowed, %d refused)%s")
		:format(label, allowed + refused, allowed, refused, first and (": " .. first) or ""))
	return allowed, refused
end

do
	local allowed, refused = agree("at the start")
	check(allowed >= 8 and refused >= 100, "A the world has both kinds of chunk")
	-- a chunk the preview allows takes a stone inside and refuses one on its
	-- edge for the spot, not the chunk
	local inside, edge = 0, 0
	for _, c in ipairs(mask.list("accord")) do
		if not H.chunk_refusal("accord", c[1], c[2]) then
			if placement("accord", c[1], c[2], 1, 78) then inside = inside + 1 end
			local ok, code = placement("accord", c[1], c[2], 0, 40)
			if not ok and code == "edge" then edge = edge + 1 end
		end
	end
	check(inside > 0 and inside == edge, ("A an allowed chunk: a stone inside passes (%d), one on " ..
		"its edge is refused for the edge (%d)"):format(inside, edge))
end

-- ---------------------------------------------------------------------------
-- Q  the quota per chunk
-- ---------------------------------------------------------------------------
local KIND = "acc_claim/meadow"
local function share(cx, cz, kind)
	for _, row in ipairs(mask.kind_columns(cx, cz)) do
		if row[1] == kind then return row[2] end
	end
	return 0
end
do
	local placed = {}
	-- the accord ground chunks holding the kind, the largest share first
	local holders = {}
	for _, c in ipairs(mask.list("accord")) do
		local s = share(c[1], c[2], KIND)
		if s > 0 then holders[#holders + 1] = {cx = c[1], cz = c[2], s = s} end
	end
	table.sort(holders, function(a, b)
		if a.s ~= b.s then return a.s > b.s end
		if a.cz ~= b.cz then return a.cz < b.cz end
		return a.cx < b.cx
	end)
	local limit = mask.kind_by_id[KIND].limit
	check(#holders >= 3, "Q the kind's ground lies in several claim-ground chunks (" .. #holders .. ")")
	-- the target keeps the largest share; claims go on the others, the next
	-- largest first, until the target turns red; the smallest share is kept
	-- back to show that it stays allowed
	local target, small = holders[1], holders[#holders]
	local turned
	for index = 2, #holders - 1 do
		local c = holders[index]
		local x0, z0 = CM.chunk_bounds(c.cx, c.cz)
		placed[#placed + 1] = model.create("q" .. index, {x = x0 + 40, y = 10, z = z0 + 40})
		agree("after placement " .. (index - 1))
		local code, kind = H.chunk_refusal("accord", target.cx, target.cz)
		if code == "quota" then
			turned = kind
			break
		end
	end
	eq(turned, KIND, "Q the chunk with the largest share turns red for the quota")
	local taken = H.quota_taken()[KIND] or 0
	check(taken + target.s > limit and taken + small.s <= limit,
		("Q per chunk: taken %d + %d (large) > %d >= taken + %d (small)"):format(taken, target.s,
			limit, small.s))
	eq(H.chunk_refusal("accord", small.cx, small.cz), nil,
		"Q the chunk with the small share of the same kind stays allowed")
	eq(select(2, placement("accord", target.cx, target.cz)), "quota", "Q placement says quota too")
	-- a removal frees it again
	model.remove(placed[#placed], "picked_up")
	placed[#placed] = nil
	agree("after a removal")
	eq(H.chunk_refusal("accord", target.cx, target.cz), nil, "Q a removal frees the large chunk")
	-- the tie cell's chunk holds both kinds' ground
	local cx, cz = CM.chunk_of(4 * 32), CM.chunk_of(0)
	local kinds = mask.kind_columns(cx, cz)
	check(#kinds == 2 and share(cx, cz, KIND) > 0 and share(cx, cz, "acc_cap/commons") > 0,
		"Q the tie cell's chunk holds two kinds' ground")
	for _, c in ipairs(placed) do model.remove(c, "picked_up") end
	agree("after every claim went")
end

-- ---------------------------------------------------------------------------
-- R  every reason, a claim, no mask
-- ---------------------------------------------------------------------------
do
	-- a claim in an allowed chunk: "taken" in both
	local free
	for _, c in ipairs(mask.list("accord")) do
		if not H.chunk_refusal("accord", c[1], c[2]) then free = c break end
	end
	local x0, z0 = CM.chunk_bounds(free[1], free[2])
	local claim = model.create("other", {x = x0 + 40, y = 10, z = z0 + 40})
	eq(H.chunk_refusal("accord", free[1], free[2]), "taken", "R a claim in the chunk: taken")
	eq(select(2, placement("accord", free[1], free[2])), "taken", "R ...placement says taken")
	agree("with a claim")
	model.remove(claim, "picked_up")
	-- a mask that names each reason id in turn (and the real quota)
	local REASONS = {"shelf", "sea", "enemy", "low_level", "high_level", "not_home", "town",
		"deep_water", "site", "landmark", "road", "camp", "leader", "place", "rare",
		"capital_ring", "no_faction", "something_new"}
	local named = {}
	local fake = setmetatable({ground = function(_, cx, cz)
		local reason = named[cx .. "," .. cz]
		if reason then return false, reason end
		return mask.ground("accord", cx, cz)
	end}, {__index = mask})
	H.mask = fake
	local bad = {}
	for index, reason in ipairs(REASONS) do
		local cx, cz = index - 9, 3 - index % 5
		named[cx .. "," .. cz] = reason
		local code = H.chunk_refusal("accord", cx, cz)
		local _, vcode = placement("accord", cx, cz)
		local want = model.MESSAGES[reason] and reason or "not_ground"
		if code ~= want or vcode ~= want then bad[#bad + 1] = reason .. ":" .. tostring(code) end
	end
	check(#bad == 0, "R every reason id the same in the preview and placement (" ..
		table.concat(bad, " ") .. ")")
	-- no mask: every chunk refused
	H.mask = nil
	local all = true
	for cz = -6, 6 do
		for cx = -6, 6 do all = all and H.chunk_refusal("accord", cx, cz) == "no_mask" end
	end
	check(all, "R no mask: every chunk no_mask")
	eq(select(2, placement("accord", 0, 0)), "no_mask", "R ...placement says no_mask")
	H.mask = mask
end

-- ---------------------------------------------------------------------------
-- H  the hint line
-- ---------------------------------------------------------------------------
do
	eq(P.hint(nil), "This square: free to claim", "H a free square")
	local missing, long = {}, {}
	for code in pairs(model.MESSAGES) do
		-- the refusals for the spot and the player's own state are not the
		-- chunk's (STONE's account steps since its merge included)
		local own = {no_mask = true, already_placed = true, edge = true, cube = true,
			too_deep = true, not_member = true, account_stands = true, own_draft = true,
			member = true}
		if not P.HINTS[code] and not own[code] then
			missing[#missing + 1] = code
		end
	end
	for code in pairs(P.HINTS) do
		local text = P.hint(code, "Meadow Fields")
		if not text:find("^This square: ") or #text > 60 or text:find("\n") then
			long[#long + 1] = code
		end
	end
	table.sort(missing)
	check(#missing == 0, "H a hint for every refusal of the chunk (" .. table.concat(missing, " ") .. ")")
	check(#long == 0, "H every hint one line of at most 60 characters (" .. table.concat(long, " ") .. ")")
	eq(H.claim_hint("quota", KIND), "This square: too much of Meadow Fields is claimed already",
		"H the quota names the kind's area")
	eq(H.claim_hint("road"), "This square: a road runs through it", "H a road")
	check(select(2, P.hint("no_mask"):gsub("\n", "")) == 1 and P.hint("no_mask"):find("admin"),
		"H no mask: two lines, tell an admin")
	eq(P.hint("something_new"), "This square: it is no claim ground", "H an unknown code")
end

-- ---------------------------------------------------------------------------
-- M  the minimap's claim mode
-- ---------------------------------------------------------------------------
-- the engine's `[fill` checks (imagesource.cpp, CHECK_DIM), as r502_cmap's
local function fills(texture)
	local list = {}
	for part in (texture .. "^"):gmatch("([^%^]*)%^") do
		if part:find("^%[fill") then
			local w, h, x, y, color = part:match("^%[fill:(%d+)x(%d+):(%d+),(%d+):(#%x+)$")
			list[#list + 1] = {w = tonumber(w), h = tonumber(h), x = tonumber(x), y = tonumber(y),
				color = color, raw = part}
		end
	end
	return list
end
local function fills_valid(list, size)
	for _, f in ipairs(list) do
		if not (f.w and f.w >= 1 and f.h >= 1 and f.x >= 0 and f.y >= 0 and f.x < size and
				f.y < size) then
			return false, f.raw
		end
	end
	return true
end
rawset(_G, "grug_factions", {get_faction = function(p) return factions[p:get_player_name()] end,
	register_on_faction_chosen = function() end})
rawset(_G, "grug_quests", {marker_states = function() return {}, 1 end,
	register_on_markers_changed = function() end})
rawset(_G, "grug_parties", {view = function() return nil end, register_on_change = function() end})
rawset(_G, "grug_home", {get = function() return nil end, known_waypoints = function() return {} end,
	claim_waypoint = function() return nil end})
dofile(repo .. "/mods/CORE/grug_core/hud_layout.lua")
-- a second stone kind in the item set, as lane STONE's account stone
H.STONE_ITEMS["test:account_stone"] = "account"
local text = assert(io.open(repo .. "/mods/PLAYER/grug_map/base.lua", "rb")):read("*a")
check(not text:find("claim_overlay", 1, true) and not text:find("claim_rules", 1, true),
	"M base.lua bakes no Claim Stone overlay")
local B = dofile(repo .. "/mods/PLAYER/grug_map/base.lua")
rawset(_G, "grug_map", {quest_slots = function() return {} end,
	atlas = dofile(repo .. "/mods/PLAYER/grug_map/atlas.lua"),
	location = {text_of = function() return "Somewhere" end}, base = B})
dofile(repo .. "/mods/PLAYER/grug_map/minimap.lua")
local minimap = grug_map.minimap
local NW, NH = 1215, 1080
minimap.install({minimap = {quality = "normal", width = NW, height = NH,
	tiles = B.tiles(NW, NH, B.MINI_PREFIX)}})
check(minimap.available(), "M the minimap is available")
local V = minimap.view
local view = minimap.geometry()
local size = view.combined
local RED = ("#%02x%02x%02x%02x"):format(unpack(B.CLAIM_RED))
local GREEN_EDGE, GREEN_FILL, GRID = "#40d04acc", "#40d04a4d", "#0004"

local me = new_player("me", {x = -70.3, y = 10, z = -70.6})
players.me = me
windows.me = {size = {x = 1920, y = 1080}, real_hud_scaling = 1, real_gui_scaling = 1}
factions.me = "accord"
for _, fn in ipairs(joins) do fn(me) end
local function step(n)
	for _ = 1, n or 1 do
		for _, fn in ipairs(steps) do fn(0.1) end
	end
end
-- the line's dark box (fix round 1): the image just under the bezel
local hint_def
local function box_def()
	for _, def in pairs(me.huds) do
		if def.type == "image" and def.z_index == 44 then return def end
	end
end
-- The box holds the line: shown exactly with it, the darker grey fill, its
-- right edge `pad` right of the text's, as wide as the text's estimate
-- plus the padding (the text's bottom `pad` above the box's bottom).
local function box_fits(label)
	local box, def = box_def(), hint_def()
	if def.text == "" then
		eq(box.text, "", label .. ": no box without the line")
		return
	end
	local w, h = box.text:match("^%[fill:(%d+)x(%d+):#34343494$")
	w, h = tonumber(w), tonumber(h)
	local width = V.text_width(def.text, 16)
	local px, py = box.position.x * 1920, box.position.y * 1080
	local tx, ty = def.position.x * 1920, def.position.y * 1080
	check(w and math.abs(px + w - (tx + 4)) < 0.6 and w >= width + 8 and w <= width + 9 and
		math.abs(py + h - (ty + 4)) < 0.6, label .. ": the box fits the line (" .. tostring(box.text) .. ")")
end
function hint_def()
	for _, def in pairs(me.huds) do
		if def.type == "text" and def.alignment and def.alignment.x == -1 then return def end
	end
end
local function chunk_here()
	return floor((floor(me.pos.x + 0.5) + 32) / 80), floor((floor(me.pos.z + 0.5) + 32) / 80)
end
-- The texture's claim layer against the preview, pixel for pixel: red
-- exactly on the refused chunks; a grid line on every chunk edge; the
-- player's chunk framed (and filled when free) in green.
local function audit(label, faction)
	local texture = minimap.texture_of(me)
	local list = fills(texture)
	local ok, bad_fill = fills_valid(list, size)
	check(ok, label .. ": every fill valid (" .. tostring(bad_fill) .. ")")
	local cx, cy = V.cell(view, me.pos.x, me.pos.z)
	local ox, oy = V.origin(view, cx, cy)
	local cols, rows = V.chunk_cells(view, ox, oy, 80, -32)
	local red = {}
	for _, f in ipairs(list) do
		if f.color == RED then
			for y = f.y, f.y + f.h - 1 do
				for x = f.x, f.x + f.w - 1 do red[y * size + x] = true end
			end
		end
	end
	local wrong, cells = 0, 0
	for _, row in ipairs(rows) do
		for _, col in ipairs(cols) do
			cells = cells + 1
			local refused = H.chunk_refusal(faction, col[1], row[1]) ~= nil
			for y = row[2], row[3] - 1 do
				for x = col[2], col[3] - 1 do
					if (red[y * size + x] == true) ~= refused then wrong = wrong + 1 end
				end
			end
		end
	end
	check(cells >= 25 and wrong == 0, ("%s: red exactly on the refused chunks (%d chunks, %d " ..
		"pixels wrong)"):format(label, cells, wrong))
	-- the grid: one line per chunk edge on the texture, the whole side long
	local lines = {}
	for _, f in ipairs(list) do
		if f.color == GRID then lines[(f.w == 1 and "x" or "y") .. (f.w == 1 and f.x or f.y)] = f end
	end
	local grid_ok = true
	for _, col in ipairs(cols) do
		if col[4] >= 0 then grid_ok = grid_ok and lines["x" .. col[4]] and lines["x" .. col[4]].h == size end
	end
	for _, row in ipairs(rows) do
		if row[4] >= 0 then grid_ok = grid_ok and lines["y" .. row[4]] and lines["y" .. row[4]].w == size end
	end
	check(grid_ok, label .. ": a grid line on every chunk edge")
	-- the player's chunk
	local pcx, pcz = chunk_here()
	local col, row
	for _, c in ipairs(cols) do if c[1] == pcx then col = c end end
	for _, r in ipairs(rows) do if r[1] == pcz then row = r end end
	local edges, filled = {}, false
	for _, f in ipairs(list) do
		if f.color == GREEN_EDGE then edges[#edges + 1] = f end
		if f.color == GREEN_FILL and f.x == col[2] and f.y == row[2] and f.w == col[3] - col[2] and
				f.h == row[3] - row[2] then
			filled = true
		end
	end
	local free = H.chunk_refusal(faction, pcx, pcz) == nil
	local framed = #edges == 4 and edges[1].x == col[4] and edges[1].y == row[4] and
		edges[1].w == col[5] - col[4] and edges[2].y == row[5] - 1
	check(framed, label .. ": the player's chunk framed green")
	eq(filled, free, label .. ": filled green exactly when free")
	-- the line beside the bezel
	local def = hint_def()
	eq(def and def.text, H.claim_hint(H.chunk_refusal(faction, pcx, pcz)), label .. ": the line")
	return texture
end

step(6)
local normal = minimap.texture_of(me)
check(normal and not normal:find("%[fill"), "M no stone: the plain texture")
eq(hint_def() and hint_def().text, "", "M no stone: no line")
box_fits("M no stone")
me.wield = H.STONE_ITEM
step()
eq(minimap.claim_of(me), "accord", "M the personal stone: claim mode")
local held = audit("M the personal stone", "accord")
me.wield = "test:account_stone"
step()
eq(minimap.claim_of(me), "accord", "M the account stone: claim mode")
eq(minimap.texture_of(me), held, "M both stones: the same preview")
me.wield = H.STONE_ITEM
step()
-- a still player sends nothing
sent = 0
step(3)
eq(sent, 0, "M a still player in claim mode sends nothing")
-- the player's chunk: free here?
local pcx, pcz = chunk_here()
local here_free = H.chunk_refusal("accord", pcx, pcz) == nil
check(here_free, "M the player starts in a free chunk (" .. pcx .. "," .. pcz .. ")")
eq(hint_def().text, "This square: free to claim", "M the line: free")
box_fits("M free")
eq(hint_def().number, 0x8fe596, "M ...in the free colour")
-- another player's placement in the player's chunk shows at once
local x0, z0 = CM.chunk_bounds(pcx, pcz)
local claim = model.create("other", {x = x0 + 30, y = 10, z = z0 + 30})
step()
local with_claim = audit("M a claim in the player's chunk", "accord")
check(with_claim ~= held, "M ...the texture changed")
eq(hint_def().text, "This square: a Claim Stone already stands in it", "M ...the line says taken")
eq(hint_def().number, 0xff9c8c, "M ...in the refused colour")
local yellow = 0
for _, f in ipairs(fills(with_claim)) do if f.color == "#f0d040cc" then yellow = yellow + 1 end end
eq(yellow, 4, "M ...the other's claim framed yellow")
model.remove(claim, "picked_up")
step()
eq(minimap.texture_of(me), held, "M its removal: the preview as before")
-- crossing a chunk edge inside one cell
do
	local edge_x
	for k = -3, 3 do
		local e = 80 * k - 32.5
		if V.cell(view, e - 0.4, me.pos.z) == V.cell(view, e + 0.4, me.pos.z) then edge_x = e break end
	end
	check(edge_x ~= nil, "M a chunk edge inside a cell")
	me.pos.x = edge_x - 0.4
	step()
	local west_hint, west = hint_def().text, minimap.texture_of(me)
	audit("M west of the edge", "accord")
	me.pos.x = edge_x + 0.4
	step()
	local east = minimap.texture_of(me)
	audit("M east of the edge, same cell", "accord")
	check(east ~= west, "M the frame moved with the chunk inside one cell")
	check(type(west_hint) == "string", "M the line follows (" .. tostring(west_hint) .. " -> " ..
		tostring(hint_def().text) .. ")")
	me.pos.x, me.pos.z = -70.3, -70.6
	step()
end
-- walking: the texture follows the cells, every one audited
do
	local ok = true
	for i = 1, 30 do
		me.pos.x, me.pos.z = -300 + i * 21.7, -250 + i * 17.3
		step()
		local before = #failures
		audit("M walking " .. i, "accord")
		ok = ok and #failures == before
	end
	check(ok, "M a walk over 30 cells: every texture right")
	me.pos.x, me.pos.z = -70.3, -70.6
	step()
end
-- the other faction: its own preview
factions.me = "throng"
step()
audit("M the Throng", "throng")
check(minimap.texture_of(me) ~= held, "M the Throng's preview differs")
-- no faction: no claim mode, no line
factions.me = nil
step()
eq(minimap.claim_of(me), nil, "M no faction: no claim mode")
eq(minimap.texture_of(me), normal, "M no faction: the plain texture")
eq(hint_def().text, "", "M no faction: no line")
box_fits("M no faction")
factions.me = "accord"
-- another item
me.wield = "default:dirt"
step()
eq(minimap.texture_of(me), normal, "M another item: the plain texture")
eq(hint_def().text, "", "M another item: no line")
box_fits("M another item")
-- no mask: every chunk red and its line
H.mask = nil
me.wield = H.STONE_ITEM
step()
audit("M no mask", "accord")
eq(hint_def().text, P.NO_MASK, "M no mask: the line says so")
box_fits("M no mask (two lines)")
H.mask = mask

-- B  the box (fix round 1): the width estimate against the widths measured
-- in Round 86's screenshots (GUI scaling 1, HUD font 16 px), at most 6 %
-- above; at HUD scaling 1 and 1.5 every hint (the shortest, the longest
-- with a long area name, no mask's two lines) fits its box, which stays
-- left of the bezel and on the screen.
do
	for _, m in ipairs({{"This square: free to claim", 176},
			{"This square: a road runs through it", 237},
			{"This square: too much of Lorindor Shell Strand is claimed already", 453},
			{"This square: it lies next to a capital's walls", 293}}) do
		local w = V.text_width(m[1], 16)
		check(w >= m[2] and w <= m[2] * 1.06, ("B the estimate of %q: %.1f px, drawn %d"):format(
			m[1], w, m[2]))
	end
	local texts = {P.FREE, P.NO_MASK, P.hint("quota", "Lorindor Shell Strand of the Deep Reaches")}
	for code in pairs(P.HINTS) do texts[#texts + 1] = P.hint(code, "Meadow Fields") end
	local ok, widest = true, 0
	for _, hud in ipairs({1, 1.5}) do
		for _, gui in ipairs({1, 1.5}) do
			local frame = V.frame(view, grug_core.hud_layout.minimap_box({size = {x = 1920, y = 1080},
				real_hud_scaling = hud, real_gui_scaling = gui}))
			for _, text in ipairs(texts) do
				local g = V.hint_box(frame, text, 6)
				local width, lines = V.text_width(text, 16 * gui)
				widest = math.max(widest, g.w)
				ok = ok and g.text_x - width >= g.x + 1 and g.text_x <= g.x + g.w - 1 and
					g.text_y - lines * 1.15 * 16 * gui >= g.y and g.text_y < g.y + g.h and
					g.x >= 0 and g.x + g.w <= frame.center_x - frame.diameter / 2 and
					g.y + g.h <= frame.center_y + frame.diameter / 2 + 1
			end
		end
	end
	check(ok, "B every hint fits its box at HUD and GUI scaling 1 and 1.5 (widest " .. widest .. " px)")
end

if #failures > 0 then
	for _, failure in ipairs(failures) do print("FAIL " .. failure) end
	error(("R86 PREVIEW PORTABLE FAIL %d of %d checks"):format(#failures, checks), 0)
end
print("R86 PREVIEW PORTABLE PASS checks=" .. checks)
