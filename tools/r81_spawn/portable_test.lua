-- Round 81 lane SPAWN portable test (LuaJIT): the spawn fixes of the 2026-11
-- audit (round81-plan.md §4 SPAWN, rulings 5 and 6).
--
--   luajit tools/r81_spawn/portable_test.lua [REPO]
--
-- A. The merged spawn table (tools/r81_spawn/merged_table.lua over the real
--    rows, spawn_policy.lua and spawn_abms.lua) is byte-identical to the dump
--    pinned at the base (merged_spawn_table.txt): removing the palette layer
--    and the retired surface rows moved no kept row and no merged chance.
-- B. The Elder Bear, Elder Plaguehide Bear and Silverback rolls (bear.lua,
--    jungle_ape.lua) in the definitions' after_activate: 1 in 10 for a fresh
--    entity of the base name, never with staticdata (a reactivation, a rare),
--    never for a copied definition under another name (a sub-type).
-- C. spawn_action (mobs/api.lua, MOB2-01): the same outcome per attempt; the
--    day toggle, height and light refuse before the policy and the scans; the
--    repellent scan only while the node is registered.
-- D. region_density_allows (density.lua, X4-06): the early refusal answers
--    exactly as the full count over random populations, and stops early on a
--    crowded area at its budget.
-- E. The settlement heartbeat (start_npcs.lua, MOB2-02): each row once per
--    heartbeat, a twentieth of the rows per step, a 5 s step one heartbeat.
-- F. camps.lua (MOB2-05): the camp fire has no timer, no place_camp, only the
--    guard posts are camp types; the fire's init sets its infotext only.
-- G. Definitions (MOB3-09, DD2-01): no dogshoot count fields, no physical =
--    false on the three fliers, the Lava Seep runs 4.6.
-- The call counts of C, D and E are tools/r81_spawn/measure.lua's (run it on
-- the base for the "before"). Prints "R81 SPAWN PORTABLE PASS checks=<n>".
local repo = arg[1] or "."
local checks = 0
local function check(ok, label)
	checks = checks + 1
	if not ok then error("FAIL " .. label, 2) end
end
local function read(path)
	local handle = assert(io.open(repo .. "/" .. path, "rb"))
	local text = handle:read("*a")
	handle:close()
	return text
end
local MOBS = repo .. "/mods/ENTITIES/grug_mobs"

-- ---------------------------------------------------------------------------
-- A. The merged spawn table
-- ---------------------------------------------------------------------------
local roster
do
	local text, info = dofile(repo .. "/tools/r81_spawn/merged_table.lua")(repo)
	roster = info.roster
	local pinned = read("tools/r81_spawn/merged_spawn_table.txt")
	if text ~= pinned then
		io.stderr:write(text)
	end
	check(text == pinned, "A the merged spawn table is the base's, byte for byte")
	check(#info.rows == #info.kept and #info.kept == 33, "A every row registers, 33 rows: " ..
		#info.rows .. "/" .. #info.kept)
	check(#info.abms == 3, "A three merged ABMs")
end

-- ---------------------------------------------------------------------------
-- B. Elder Bear and Silverback
-- ---------------------------------------------------------------------------
do
	local defs, tiers = {}, {}
	local env = setmetatable({
		grug_mobs = {
			register_mob = function(name, def) defs[name] = def end,
			set_tier = function(ent, tier) tiers[#tiers + 1] = tier; ent._grug_tier = tier end,
			atlas_textures = function(texture, n)
				local list = {}
				for i = 1, n do list[i] = texture end
				return list
			end,
		},
	}, {__index = _G})
	for _, file in ipairs({"bear.lua", "jungle_ape.lua"}) do
		local chunk = assert(loadfile(MOBS .. "/" .. file))
		setfenv(chunk, env)
		chunk()
	end
	local real_random = math.random
	local function activate(name, def_name, staticdata, roll)
		local def = defs[def_name or name]
		local self = {name = name, description = def.description, object = {}}
		math.random = function() return roll end
		def.after_activate(self, staticdata, def, 0)
		math.random = real_random
		return self
	end
	local cases = {
		{"grug_mobs:bear", "Elder Bear"},
		{"grug_mobs:plaguehide_bear", "Elder Plaguehide Bear"},
		{"grug_mobs:jungle_ape", "Silverback"},
	}
	for _, case in ipairs(cases) do
		local name, elder = case[1], case[2]
		check(type(defs[name].after_activate) == "function", "B " .. name .. " rolls on activation")
		local hit = activate(name, nil, "", 1)
		check(hit.description == elder and hit._grug_tier == "elite", "B a fresh " .. name ..
			" rolled 1 is the " .. elder)
		local miss = activate(name, nil, nil, 2)
		check(miss._grug_tier == nil and miss.description ~= elder, "B a fresh " .. name ..
			" rolled 2 stays normal")
		local back = activate(name, nil, "return {_grug_level = 30}", 1)
		check(back._grug_tier == nil, "B a reactivated " .. name .. " never rolls")
		local sub = activate("grug_mobs:copied_role", name, "", 1)
		check(sub._grug_tier == nil and sub.description ~= elder,
			"B a sub-type copying " .. name .. " never rolls")
	end
	-- One in ten over many fresh spawns.
	local elders = 0
	for _ = 1, 20000 do
		local self = {name = "grug_mobs:bear", object = {}}
		defs["grug_mobs:bear"].after_activate(self, "", defs["grug_mobs:bear"], 0)
		if self._grug_tier == "elite" then elders = elders + 1 end
	end
	check(elders > 1700 and elders < 2300, "B about 1 in 10 fresh bears is an Elder: " .. elders)
end

-- ---------------------------------------------------------------------------
-- C, D (counts) and E: tools/r81_spawn/measure.lua on this tree
-- ---------------------------------------------------------------------------
local m = dofile(repo .. "/tools/r81_spawn/measure.lua")(repo)
do
	local by = {}
	for _, s in ipairs(m.spawn) do by[s.name] = s end
	for _, name in ipairs({"night", "dark", "too high"}) do
		local s = by[name]
		check(not s.spawned and s.policy == 0 and s.count == 0 and s.find == 0,
			"C " .. name .. ": refused before the policy and the scans")
	end
	check(not by["policy refuses"].spawned and by["policy refuses"].count == 0,
		"C the policy refuses before count_mobs")
	check(not by["cap full"].spawned and by["cap full"].find == 0, "C the cap refuses")
	check(by.spawns.spawned and by.spawns.find == 0,
		"C a spawn without the repellent scan (not registered)")
	check(not by["repellent (registered)"].spawned and by["repellent (registered)"].find == 1,
		"C a registered repellent still refuses")
	local api = read("mods/ENTITIES/mobs/api.lua")
	check(api:find("GRUG PATCH (Round 81 SPAWN, MOB2-01)", 1, true) ~= nil, "C the patch marker")
	local h = m.heartbeat
	check(h.served_low == 4 and h.served_high == 4, "E every row 4 times in 20 s: " ..
		h.served_low .. ".." .. h.served_high)
	check(h.most_per_step <= 3, "E at most 3 of 60 rows per step: " .. h.most_per_step)
	check(h.long_step_serves == h.rows, "E a 5 s step serves one whole heartbeat")
	local d = m.density
	check(d.first == false and d.last == false and d.first_reads < 20 and d.last_reads <= 600,
		"D a full budget stops the count early")
end

-- D. Identity: the early answer equals the full count's.
do
	local saved = {grug_mobs = rawget(_G, "grug_mobs"), core = rawget(_G, "core")}
	local objects = {}
	_G.core = {settings = {get = function() return nil end},
		get_objects_inside_radius = function() return objects end}
	local camp_tag = {["zone/camp"] = {is_camp = true}}
	_G.grug_mobs = {spawn_regions = {core = {DENSITY = {sparse = 0.5, normal = 0.75, dense = 1}},
		area_by_tag = function(tag) return camp_tag[tag] end}}
	dofile(MOBS .. "/density.lua")
	local G = _G.grug_mobs
	math.randomseed(81)
	local names = {"grug_mobs:fox", "grug_mobs:boar", "grug_mobs:rat"}
	local tags = {"zone/kind", "zone/kind", "zone/camp", nil}
	local compared = 0
	for _ = 1, 3000 do
		objects = {}
		local n = math.random(0, 40)
		for _ = 1, n do
			local ent
			if math.random() < 0.8 then
				ent = {name = names[math.random(#names)], _grug_area = tags[math.random(4)],
					_grug_spawn_clock = math.random() < 0.8 and "day" or "night",
					_grug_rare_id = math.random() < 0.05 and "r" or nil,
					_grug_tier = math.random() < 0.05 and "boss" or nil}
			end
			objects[#objects + 1] = {get_luaentity = function() return ent end}
		end
		local density = ({"sparse", "normal", "dense"})[math.random(3)]
		local weight, total = math.random(1, 5), math.random(5, 12)
		local answer = G.region_density_allows({x = 0, y = 0, z = 0}, "zone", "day",
			{density = density}, "grug_mobs:fox", weight, total)
		-- The full count, as before Round 81.
		local budget = G.region_budget("zone", "day", density)
		local share = G.density_share(budget, weight, total)
		local t, s = 0, 0
		for i = 1, #objects do
			local ent = objects[i].get_luaentity()
			if ent and ent._grug_area and ent._grug_spawn_clock == "day" and not ent._grug_rare_id
					and ent._grug_tier ~= "rare" and ent._grug_tier ~= "boss" and
					not (camp_tag[ent._grug_area] and camp_tag[ent._grug_area].is_camp) then
				t = t + 1
				if ent.name == "grug_mobs:fox" then s = s + 1 end
			end
		end
		if answer ~= G.area_density_decision(t, s, budget, share) then
			error(("FAIL D identity: n=%d total=%d same=%d budget=%d share=%d"):format(n, t, s,
				budget, share))
		end
		compared = compared + 1
	end
	checks = checks + compared
	for name, value in pairs(saved) do rawset(_G, name, value) end
	print(("D %d random populations: the early answer is the full count's"):format(compared))
end

-- ---------------------------------------------------------------------------
-- F. camps.lua: the camp fire is scenery
-- ---------------------------------------------------------------------------
do
	local overrides, lbms, meta_writes, timers = {}, {}, {}, 0
	local env = setmetatable({
		grug_mobs = {},
		core = {
			override_item = function(name, def) overrides[name] = def end,
			register_lbm = function(def) lbms[def.name] = def end,
			get_meta = function()
				local store = {}
				return {
					get_int = function(_, k) return store[k] or 0 end,
					set_int = function(_, k, v) store[k] = v; meta_writes[#meta_writes + 1] = k end,
					get_string = function(_, k) return store[k] or "" end,
					set_string = function(_, k, v) store[k] = v; meta_writes[#meta_writes + 1] = k end,
				}
			end,
			get_node_timer = function()
				return {start = function() timers = timers + 1 end, is_started = function() return false end}
			end,
		},
	}, {__index = _G})
	local chunk = assert(loadfile(MOBS .. "/camps.lua"))
	setfenv(chunk, env)
	chunk()
	local fire = overrides["grug_nodes:camp_fire"]
	check(fire and fire.on_timer == nil and type(fire.on_construct) == "function",
		"F the camp fire keeps its on_construct, has no on_timer")
	fire.on_construct({x = 0, y = 0, z = 0})
	lbms["grug_mobs:camp_fire_init"].action({x = 1, y = 0, z = 0})
	check(timers == 0, "F no camp fire timer is armed")
	local infotext = 0
	for _, k in ipairs(meta_writes) do
		check(k == "infotext" or k == "_grug_camp_init", "F the fire writes only its infotext: " .. k)
		if k == "infotext" then infotext = infotext + 1 end
	end
	check(infotext == 2, "F both init paths write the infotext")
	check(env.grug_mobs.place_camp == nil, "F place_camp is gone")
	local types = {}
	for id in pairs(env.grug_mobs.registered_camp_types) do types[#types + 1] = id end
	table.sort(types)
	check(#types == 2 and types[1] == "guard_accord" and types[2] == "guard_throng",
		"F only the guard posts are camp types: " .. table.concat(types, ","))
	local banner = overrides["grug_nodes:guard_banner"]
	check(banner and type(banner.on_timer) == "function", "F the guard banner keeps its timer")
end

-- ---------------------------------------------------------------------------
-- G. Definitions
-- ---------------------------------------------------------------------------
do
	local defs = roster.defs
	local n = 0
	for name, def in pairs(defs) do
		n = n + 1
		check(def.dogshoot_count_max == nil and def.dogshoot_count2_max == nil,
			"G no dogshoot count fields: " .. name)
	end
	check(n > 100, "G the roster's definitions: " .. n)
	for _, name in ipairs({"grug_mobs:glowwing", "grug_mobs:ember_wisp", "grug_mobs:wisp"}) do
		check(defs[name] and defs[name].physical == nil, "G no physical = false: " .. name)
	end
	check(defs["grug_mobs:lava_flan"].run_velocity == 4.6, "G the Lava Seep runs 4.6")
	local text = read("mods/ENTITIES/grug_mobs/boss_floor.lua") ..
		read("mods/ENTITIES/grug_mobs/boss_dragons.lua") .. read("mods/ENTITIES/grug_mobs/rift.lua")
	check(not text:find("BOSS_QUIET", 1, true) and not text:find("remove_dragon_whelps", 1, true) and
		not text:find("crack_nodes(cells", 1, true), "G the dead exports are gone")
end

print("R81 SPAWN PORTABLE PASS checks=" .. checks)
