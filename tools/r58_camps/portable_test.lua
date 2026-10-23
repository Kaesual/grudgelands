-- Round 58 lane CAMPS portable test (LuaJIT): the mining camps, the war
-- camps as mining camps, the camps under construction and the camp module
-- (`wp40/r58_camps.lua`, `r58_camp_catalog.lua`, `r58_camp_blueprint.lua`).
--
--   luajit tools/r58_camps/portable_test.lua [REPO]
--
-- P  placement over three seeds (the real world assembly, as main places):
--    42 camps (20 mining camps, 16 war camps, 6 under construction), each
--    in its own zone, a contested camp on its continent's faction, a camp
--    under construction of the other faction; `camps()` returns the 36
--    with lifts sorted by id, their tiers (6 T2, 8 T3, 6 T4, 8 T5, 8 T6)
--    and `levels` 1..tier (148 levels in all); the 128-node town gap and
--    the 16-node anchor gap, the centre distance to every other placed POI
--    (at least the step's spacing; the smallest printed); the band.
-- D  determinism: a second assembly places the same text, a fresh load of
--    the module gives the same lists from the text and from the parsed
--    positions; a broken layout is refused.
-- B  the blueprints of every camp: the socket contract (a mining or war
--    camp: `lift` on the lift node's cell, `quest_foreman`, `vendor_camp`
--    of kind "camp"; a camp under construction: two gate guards, two yard
--    guards and the captain, no lift, no vendor, no quest and no lift node),
--    the war camps' Round 31 sockets unchanged, and the lift socket at the
--    module's lift column for every camp of seed 42.
-- R  the real runtime of seed 42 (tools/seed_fleet/runtime.lua): every camp
--    registered with its sockets, the activation roster still 42 rows (6
--    capitals, 24 outposts, 12 bandit camps; no camp joins it), so the zone
--    overlay's 36 columns hold; the chunk of three camps written by the
--    real writer holds the lift node at the lift column, one above the
--    fitted anchor.
-- K  the classification: world protection (mining camp "mining_camp", a
--    camp under construction "war_camp" with the PvP margin), the map's icon
--    kinds and layers, the PvP garrison (a mining camp is no garrison, a
--    camp under construction is a camp of its builder with the named
--    captain at the top of its zone's band), the module's index (get, near).
-- Prints "R58 CAMPS PORTABLE PASS checks=<n>" or raises.
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local t0 = os.clock()
local dir = repo .. "/mods/MAPGEN/grug_mapgen/wp40"
_G.core = _G.core or {}
local common = dofile(repo .. "/tools/wp40/r6/common.lua")
local sha = common.new_sha256()
local SEEDS = {"42", "17713522922938657774", "5575844014311305038"}
local catalog = dofile(dir .. "/r58_camp_catalog.lua")
local pvp = dofile(dir .. "/r31_pvp_catalog.lua")
local rot = dofile(dir .. "/../wp13/plot_approach.lua").rot
local function module() return dofile(dir .. "/r58_camps.lua") end
local C = module()

local function assembly() return dofile(dir .. "/world_assembly.lua")(dir, sha) end
local A = assembly()
local R = A.placement.rules
local zone_by_id, zone_by_number = {}, {}
for _, z in ipairs(A.source.zones) do zone_by_id[z.id] = z; zone_by_number[z.numeric_id] = z end
local function continent(zone)
	return zone.macro_region == "elandor_mainland" and "accord" or
		(zone.macro_region == "kragmar_mainland" and "throng" or nil)
end
local CAMP_KINDS = {mining_camp = true, pvp_camp_low = true, pvp_camp_high = true,
	camp_construction = true}

local function serial(list)
	local out = {}
	for _, c in ipairs(list) do
		out[#out + 1] = table.concat({c.id, c.kind or "", c.faction, tostring(c.race), c.zone_id,
			tostring(c.tier), c.anchor.x, c.anchor.z, c.lift and c.lift.x or "",
			c.lift and c.lift.z or "", c.levels and #c.levels or ""}, " ")
	end
	return table.concat(out, "\n")
end

-- P and D
local worlds = {}
for seed_index, seed in ipairs(SEEDS) do
	local W = A.world(seed)
	local source = W.place()
	local text = W.placement_text
	local seams = {raw_sha256 = sha, full_seed = seed}
	local camps, under = C.camps(text, seams), C.under_construction(text)
	worlds[seed] = {text = text, camps = camps, under = under, source = source}
	check(#camps == 36 and #under == 6, "P " .. seed .. " 36 camps with lifts and 6 under construction")
	local tiers, level_total, kinds = {0, 0, 0, 0, 0, 0}, 0, {mining_camp = 0, war_camp = 0}
	for index, c in ipairs(camps) do
		if index > 1 then check(camps[index - 1].id < c.id, "P " .. seed .. " sorted by id") end
		local zone = zone_by_id[c.zone_id]
		check(c.tier == catalog.tier_of(zone.level_min) and #c.levels == c.tier,
			"P " .. c.id .. " tier and levels")
		for level = 1, c.tier do check(c.levels[level] == level, "P " .. c.id .. " level " .. level) end
		tiers[c.tier] = tiers[c.tier] + 1
		level_total = level_total + #c.levels
		kinds[c.kind] = kinds[c.kind] + 1
		if c.kind == "mining_camp" then
			check(c.faction == continent(zone) and c.race == zone.race_region,
				"P " .. c.id .. " faction of its continent, race of its zone")
		else
			check(c.race ~= nil and pvp.FACTION_RACES[c.faction], "P " .. c.id .. " rolled race")
		end
	end
	check(kinds.mining_camp == 20 and kinds.war_camp == 16, "P " .. seed .. " 20 mining and 16 war camps")
	check(tiers[1] == 0 and tiers[2] == 6 and tiers[3] == 8 and tiers[4] == 6 and tiers[5] == 8 and
		tiers[6] == 8, "P " .. seed .. " tiers 6/8/6/8/8")
	check(level_total == 148, "P " .. seed .. " 148 levels")
	for _, u in ipairs(under) do
		local zone = zone_by_id[u.zone_id]
		check(zone.territory_rule == "contested_land" and zone.level_min == 31 and
			u.faction ~= continent(zone), "P " .. u.id .. " in a contested T4 zone, of the other faction")
	end
	-- Every camp on its own zone's land, the gaps, the spacing.
	local horizontal = W.horizontal_factory({source = source, schemas = A.schemas,
		canonical = A.canonical, deterministic = A.deterministic, raw_sha256 = sha}).new(seed)
	local placed, towns = {}, {}
	for _, a in ipairs(source.anchors) do
		if a.slot_id == "start" or a.slot_id == "capital" then
			towns[#towns + 1] = {x = a.position.x, z = a.position.z,
				half = a.slot_id == "capital" and 266 or 76}
		elseif a.placement_mode == "placed" then
			placed[#placed + 1] = a
		end
	end
	local profile = {}
	for _, p in ipairs(A.source.anchor_profiles) do profile[p.id] = p end
	local nearest = math.huge
	local steps = {}
	for _, a in ipairs(placed) do
		if CAMP_KINDS[a.template_id] then
			local class, _, owner = horizontal.classification_values_at(a.position.x, a.position.z)
			check(class == "land" and owner == a.zone_numeric_id, "P " .. seed .. " " .. a.id .. " on its zone's land")
			local half = profile[a.template_id].fitting_width / 2
			for _, t in ipairs(towns) do
				local gap = half + t.half + R.TOWN_GAP
				check(math.abs(t.x - a.position.x) >= gap or math.abs(t.z - a.position.z) >= gap,
					"P " .. seed .. " " .. a.id .. " keeps the town gap")
			end
			local step = R.STEPS[a.placement_step] or R.STEPS[#R.STEPS]
			steps[a.placement_step] = (steps[a.placement_step] or 0) + 1
			for _, q in ipairs(placed) do
				if q ~= a then
					local qh = profile[q.template_id].fitting_width / 2
					local gap = half + qh + R.ANCHOR_GAP
					check(math.abs(q.position.x - a.position.x) >= gap or
						math.abs(q.position.z - a.position.z) >= gap,
						"P " .. seed .. " " .. a.id .. " keeps the anchor gap to " .. q.id)
					local dx, dz = q.position.x - a.position.x, q.position.z - a.position.z
					local d = math.sqrt(dx * dx + dz * dz)
					-- a Round 58 camp keeps its spacing (at its step) from every
					-- POI placed before it: every earlier pass and the earlier
					-- camp rows (the war camps' own rules: tools/r46_pl)
					if (a.pass or 1) == 2 and q.numeric_id < a.numeric_id then
						check(d >= R.KINDS[a.template_id].spacing * step.spacing - 1e-9,
							"P " .. seed .. " " .. a.id .. " spaced from " .. q.id)
					end
					if d < nearest then nearest = d end
				end
			end
			if a.placement_step == 1 and a.band then
				local zone = zone_by_number[a.zone_numeric_id]
				local level = horizontal.zone_level_at(a.position.x, a.position.z, a.zone_numeric_id)
				local count = zone.level_max - zone.level_min + 1
				local c1, c2 = math.floor(count / 3), math.floor(count * 2 / 3)
				local third = level < zone.level_min + c1 and 1 or (level < zone.level_min + c2 and 2 or 3)
				check(third == ({low = 1, mid = 2, high = 3})[a.band], "P " .. seed .. " " .. a.id .. " in its band")
			end
		end
	end
	local parts = {}
	for step = 1, R.WET_RESORT do if steps[step] then parts[#parts + 1] = step .. ":" .. steps[step] end end
	check(not steps[R.WET_RESORT], "P " .. seed .. " no camp on a wet core")
	print(("  seed %s: camp steps %s, nearest POI centre %.0f nodes, placement %.1f s"):format(seed,
		table.concat(parts, " "), nearest, W.placement_stats and W.placement_stats.seconds or 0))
	if seed_index == 1 then
		-- D: a second assembly, a fresh module, the parsed positions.
		local W2 = assembly().world(seed)
		W2.place()
		check(W2.placement_text == text, "D a second assembly places the same text")
		local C2 = module()
		check(serial(C2.camps(text, seams)) == serial(camps), "D a fresh module, the same camps")
		check(serial(C2.under_construction(text)) == serial(under), "D the same camps under construction")
		local positions = A.placement.parse(text, A.source)
		check(serial(C2.camps(positions, seams)) == serial(camps), "D the parsed positions give the same camps")
		local bare = C2.camps(text)
		for index, c in ipairs(bare) do
			check(c.lift.x == camps[index].lift.x and c.lift.z == camps[index].lift.z and
				(c.kind == "war_camp") == (c.race == nil), "D without seams only a war camp's race is missing")
		end
		check(not pcall(C2.camps, text:gsub("\n[^\n]+\n$", "\n")), "D a truncated layout is refused")
		check(not pcall(C2.camps, 7), "D a layout that is no text or table is refused")
	end
end
check(C.ROOM_FLOOR_Y[1] == -50 and C.ROOM_FLOOR_Y[2] == -250 and C.ROOM_FLOOR_Y[3] == -450 and
	C.ROOM_FLOOR_Y[4] == -650 and C.ROOM_FLOOR_Y[5] == -950 and C.ROOM_FLOOR_Y[6] == -1050,
	"P the room floors per tier")

-- B: every camp blueprint (seed 42).
local settlement = dofile(dir .. "/r7_settlement.lua")
local SEED = SEEDS[1]
local options = {raw_sha256 = sha, full_seed = SEED}
local world = worlds[SEED]
local by_id = {}
for _, c in ipairs(world.camps) do by_id[c.id] = c end
for _, u in ipairs(world.under) do by_id[u.id] = u end
local built = {}
local war_sockets = {pvp_camp_low = {"gate_west", "gate_east", "yard_west", "yard_east", "captain"},
	pvp_camp_high = {"gate_west", "gate_east", "tower_west", "tower_east", "yard_west", "captain"}}
for _, profile in ipairs(settlement.roster) do
	local camp = by_id[profile.key]
	if camp then
		local bp = dofile(dir .. "/" .. profile.blueprint_file)(options, profile)
		built[profile.key] = bp
		local sockets, cells = {}, {}
		for _, s in ipairs(bp.landmarks.sockets) do sockets[s.id] = s end
		for _, cell in ipairs(bp.cells) do cells[cell.x .. ":" .. cell.y .. ":" .. cell.z] = cell.name end
		local lift_cells = 0
		for _, cell in ipairs(bp.cells) do if cell.name == "grug_mapgen:guild_lift" then lift_cells = lift_cells + 1 end end
		local kind = profile.art.kind
		local label = "B " .. profile.key
		if kind == "camp_construction" then
			check(not sockets.lift and not sockets.vendor_camp and not sockets.quest_foreman and lift_cells == 0,
				label .. " no lift, no vendor, no foreman")
			for _, id in ipairs({"gate_west", "gate_east", "yard_west", "yard_east"}) do
				check(sockets[id] and sockets[id].role == "guard_post", label .. " " .. id)
			end
			check(sockets.captain and sockets.captain.role == "captain", label .. " the captain")
			local n = 0
			for _ in pairs(sockets) do n = n + 1 end
			check(n == 5, label .. " five garrison sockets")
			check(bp.landmarks.race == profile.art.race and bp.landmarks.faction == camp.faction,
				label .. " registers as its builder")
			for _, cell in ipairs(bp.cells) do
				check(not cell.name:find("bed") and cell.name ~= "grug_decor:cottages_straw_mat",
					label .. " no bed")
			end
		else
			local lift = sockets.lift
			check(lift and lift.role == "lift" and lift.y == 1 and lift_cells == 1 and
				cells[lift.x .. ":1:" .. lift.z] == "grug_mapgen:guild_lift", label .. " the lift socket on the lift node")
			check(camp.anchor.x + lift.x == camp.lift.x and camp.anchor.z + lift.z == camp.lift.z,
				label .. " the lift socket at the module's lift column")
			check(sockets.quest_foreman and sockets.quest_foreman.role == "quest", label .. " the foreman")
			check(sockets.vendor_camp and sockets.vendor_camp.role == "vendor" and
				sockets.vendor_camp.kind == "camp", label .. " the camp vendor")
			for _, id in ipairs({"quest_foreman", "vendor_camp"}) do
				local s = sockets[id]
				check(cells[s.x .. ":1:" .. s.z] == nil or cells[s.x .. ":1:" .. s.z] == "air",
					label .. " " .. id .. " stands in the open")
				check(cells[s.x .. ":2:" .. s.z] == nil or cells[s.x .. ":2:" .. s.z] == "air",
					label .. " " .. id .. " has headroom")
			end
			if war_sockets[kind] then
				for _, id in ipairs(war_sockets[kind]) do
					check(sockets[id] ~= nil, label .. " keeps its Round 31 socket " .. id)
				end
			else
				check(sockets.gate_west and sockets.gate_east and
					(profile.art.contested == (sockets.yard_west ~= nil)), label .. " its guards")
				check(bp.landmarks.race == camp.race, label .. " registers as its zone's race")
			end
		end
	end
end
local n_built = 0
for _ in pairs(built) do n_built = n_built + 1 end
check(n_built == 42, "B 42 camp blueprints")

-- R: the real runtime of seed 42.
do
	local RT = dofile(repo .. "/tools/seed_fleet/runtime.lua")(repo, SEED)
	check(RT.main.placement_layout_text() == world.text, "R the runtime places the same camps")
	local rows = RT.main.settlement_sockets(RT.built)
	local registered = {}
	for _, row in ipairs(rows) do registered[row.key] = row end
	for id, camp in pairs(by_id) do
		local row = registered[id]
		check(row and row.anchor.x == camp.anchor.x and row.anchor.z == camp.anchor.z,
			"R " .. id .. " registered at its anchor")
		if camp.lift then
			local found
			for _, s in ipairs(row.sockets) do if s.id == "lift" then found = s end end
			check(found and row.anchor.x + found.x == camp.lift.x and row.anchor.z + found.z == camp.lift.z,
				"R " .. id .. " registry lift socket at the lift column")
		end
	end
	local families = {}
	for _, r in ipairs(RT.built.anchor_roster.rows) do families[r.family] = (families[r.family] or 0) + 1 end
	check(#RT.built.anchor_roster.rows == 42 and families.capital == 6 and families.outpost == 24 and
		families.bandit == 12, "R the activation roster stays 42 rows")
	-- The writer writes the lift node: three camps' chunks.
	local lift_cid = RT.fake.get_content_id("grug_mapgen:guild_lift")
	local wanted = {"mining_camp_copperfell_foothills", "pvp_camp_broken_causeway_throng_high",
		"mining_camp_bannerbreak_mesa"}
	for _, id in ipairs(wanted) do
		local camp = by_id[id]
		local row = registered[id]
		local y = row.anchor.y + 1
		local minp = {x = RT.origin(camp.lift.x), y = RT.origin(y), z = RT.origin(camp.lift.z)}
		local maxp = {x = minp.x + 79, y = minp.y + 79, z = minp.z + 79}
		local vm = RT.new_vm(minp)
		local plan, generation = RT.built.session.plan_slice(minp, maxp)
		local result = RT.built.writer.apply(vm, minp, maxp, plan, generation)
		check(type(result) == "string", "R " .. id .. " chunk written")
		local data = vm.written.data or vm.native.data
		local ex, ey, ez = minp.x - 16, minp.y - 16, minp.z - 16
		local index = (camp.lift.z - ez) * 112 * 112 + (y - ey) * 112 + (camp.lift.x - ex) + 1
		check(data[index] == lift_cid, "R " .. id .. " the lift node at the lift column, one above the anchor")
	end
	print(("  runtime of seed %s: main %.1f s, build %.1f s"):format(SEED, RT.seconds.main, RT.seconds.build))
end

-- K: classification.
do
	local wp = dofile(dir .. "/world_protection.lua")
	check(wp.settlement_kind("mining_camp") == "mining_camp" and wp.settlement_margin("mining_camp") == 0,
		"K a mining camp's protection kind")
	check(wp.settlement_kind("camp_construction") == "war_camp" and
		wp.settlement_margin("camp_construction") == wp.PVP_MARGIN, "K a camp under construction is a war camp")
	check(wp.settlement_kind("pvp_accord_low") == "war_camp", "K a war camp stays a war camp")
	local icons = dofile(repo .. "/mods/PLAYER/grug_map/settlement_icons.lua")
	check(icons.kind("mining_camp") == "mine" and icons.layer("mining_camp") == "pois" and
		icons.poi_word("mining_camp") == "Mining camp", "K the map shows a mining camp")
	check(icons.kind("camp_construction") == "war_camp" and icons.layer("camp_construction") == "pvp",
		"K the map shows a camp under construction as a war camp")
	local json = dofile(repo .. "/tools/r28_b1/json.lua")
	local handle = assert(io.open(repo .. "/mods/ENTITIES/grug_mobs/data/pvp_names.json", "r"))
	local names = json.parse(handle:read("*a"))
	handle:close()
	local G = dofile(repo .. "/mods/ENTITIES/grug_mobs/pvp_garrison.lua").new(pvp, names, catalog)
	for _, row in ipairs(catalog.mining) do
		check(G.settlement_kind(row.key) == "mining_camp" and G.poi(row.key) == nil and
			G.slot(row.key, row.race, {role = "guard_post", tags = {"gate"}}, {11, 20}) == nil,
			"K " .. row.key .. " is no garrison")
	end
	for _, row in ipairs(catalog.construction) do
		local zone = zone_by_id[row.zone_id]
		local band = {zone.level_min, zone.level_max}
		check(G.settlement_kind(row.key) == "pvp_camp" and G.poi(row.key) == row, "K " .. row.key .. " a camp")
		local captain = G.slot(row.key, row.race, {role = "captain"}, band)
		check(captain and captain.entity == "grug_mobs:captain_" .. row.faction and
			captain.level_min == zone.level_max and type(captain.name) == "string" and
			captain.name:find("^Captain ") ~= nil, "K " .. row.key .. " its named captain")
		local guard = G.slot(row.key, row.race, {role = "guard_post", tags = {"gate"}}, band)
		check(guard and guard.entity == "grug_mobs:guard_" .. row.faction and
			guard.level_min == zone.level_max - 2 and guard.level_max == zone.level_max and
			guard.name_key == nil, "K " .. row.key .. " its guards")
	end
	check(G.settlement_kind("pvp_camp_broken_causeway_accord_low") == "pvp_camp",
		"K a war camp keeps its garrison")
	-- The index of the main environment.
	local index = C.index(world.text, {raw_sha256 = sha, full_seed = SEED})
	local camp = index.camps[1]
	check(index.get(camp.id) == camp and index.get(world.under[1].id) ~= nil and index.get("nothing") == nil,
		"K index.get")
	check(index.near({x = camp.lift.x + 2, y = 20, z = camp.lift.z - 3}) == camp, "K index.near the surface lift")
	check(index.near({x = camp.lift.x, y = -60, z = camp.lift.z}) == nil, "K index.near not in the rooms")
	check(index.near({x = camp.lift.x + 40, y = 20, z = camp.lift.z}) == nil, "K index.near not far off")
	-- The turn rule the module and the blueprints share.
	for _, row in ipairs(catalog.mining) do
		check(pvp.gate_turns(row) == (row.faction == "accord" and 0 or 2), "K " .. row.key .. " turns")
	end
	local x, z = rot(catalog.LIFT.mining_camp.x, catalog.LIFT.mining_camp.z, 2)
	check(x == 0 and z == -catalog.LIFT.mining_camp.z, "K a Throng camp's lift turns with it")
end

print(("R58 CAMPS PORTABLE PASS checks=%d (%.1f s)"):format(checks, os.clock() - t0))
