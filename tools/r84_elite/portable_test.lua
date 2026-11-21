-- Round 84 lane ELITE: the actors the map never saves (zone leaders, the
-- rift boss, the depth pulse's arrivals) leave no first snapshot in their
-- mapblock, and a snapshot an older version left there removes itself.
--
-- The engine is modelled from its source (Luanti 5.18.0,
-- docs/technical/upstream-workarounds.md §11): `core.add_entity` runs the
-- activation callbacks, then stores the staticdata in the object's block
-- when the object still says static_save (`addActiveObjectRaw`); a
-- non-static object whose block was saved and unloaded before it was
-- deactivated leaves that entry behind; a block that loads activates its
-- entries, and an entity removed at activation takes its entry with it
-- (`removeRemovedObjects`). Driven with the real grug_mobs/unsaved.lua and
-- the activation order of init.lua's after_activate wrapper; source checks
-- pin the spawners, the definitions and the wrapper.
--
-- Usage: luajit tools/r84_elite/portable_test.lua <repo>
-- Prints "R84 ELITE PORTABLE PASS checks=<n>" or raises (non-zero exit).

local repo = assert(arg[1], "usage: portable_test.lua <repo>")
local checks, failures = 0, 0
local function check(cond, label)
	checks = checks + 1
	if not cond then
		failures = failures + 1
		print("FAIL " .. label)
	end
end
local function read(rel)
	local f = assert(io.open(repo .. "/" .. rel, "rb"), rel)
	local s = f:read("*a")
	f:close()
	return s
end
local function has(text, needle) return text:find(needle, 1, true) ~= nil end

-- ---------------------------------------------------------------------------
-- The engine model.
-- ---------------------------------------------------------------------------
local LEADER = "grug_mobs:hollowbell_treant"
local BOSS = "grug_mobs:rift_boss"
local BAT = "grug_mobs:blood_bat"
local prototypes = {
	[LEADER] = {_grug_unsaved = true}, -- a leader sub-type (subtypes.lua)
	[BOSS] = {_grug_unsaved = true, _grug_authored = true}, -- rift.lua's definition
	[BAT] = {}, -- shared with ambient mobs
}
local stored = {} -- the block's entries {name, data} (one block suffices)
local logs, deaths, after_claim = {}, 0, 0

-- The entity's staticdata: its own fields, as mob_staticdata saves them.
local function staticdata_of(ent)
	local out = {}
	for k, v in pairs(ent) do
		if k ~= "object" and type(v) ~= "function" then out[k] = v end
	end
	return out
end

-- One activation: the saved fields, then the wrapper's first statement and,
-- for a kept entity, the rest of the activation.
local function activate(name, data)
	local object = {props = {static_save = true}, removed = false}
	local ent = setmetatable({name = name, object = object, health = 10},
		{__index = prototypes[name]})
	function object:set_properties(p) for k, v in pairs(p) do self.props[k] = v end end
	function object:remove() self.removed = true end
	function object:get_luaentity() return not self.removed and ent or nil end
	for k, v in pairs(data or {}) do ent[k] = v end
	if grug_mobs.unsaved_claim(ent) then
		after_claim = after_claim + 1
	end
	return object, ent
end

_G.core = {
	log = function(level, text) logs[#logs + 1] = level .. ": " .. text end,
	-- addActiveObjectRaw: the activation, then the add-time entry when the
	-- object still says static_save; nil for an object removed meanwhile
	-- (l_add_entity).
	add_entity = function(_, name, data)
		local object, ent = activate(name, data)
		if object.removed then return nil end
		if object.props.static_save ~= false then
			object.entry = {name = name, data = staticdata_of(ent)}
			stored[#stored + 1] = object.entry
		end
		return object
	end,
}

-- mobs:add_mob: the authored mark goes in as staticdata; `refuse` models
-- the active-mob limit.
local refuse = false
_G.grug_mobs = {
	add_mob = function(pos, def)
		if refuse then return nil end
		local object = core.add_entity(pos, def.name,
			def._grug_authored and {_grug_authored = true} or nil)
		return object and object:get_luaentity()
	end,
}
assert(loadfile(repo .. "/mods/ENTITIES/grug_mobs/unsaved.lua"))()

-- The live object's block is saved and unloaded before the object's own
-- deactivation: the deactivation reloads the block, does not find the entry
-- among the active ones and leaves it stored (the engine's fault this lane
-- works around).
local function unload_alive(object)
	object.removed = true
end

-- The block loads again: every entry activates; an entity that removed
-- itself at activation takes its entry with it.
local function reload()
	local kept, came = {}, {}
	for _, entry in ipairs(stored) do
		local object, ent = activate(entry.name, entry.data)
		came[#came + 1] = ent
		if not object.removed then kept[#kept + 1] = entry end
	end
	stored = kept
	return came
end

local function kill(ent)
	-- The death boundary pays out (drops, loot, kill and quest credit, the
	-- leader's timer); a removal never reaches it.
	deaths = deaths + 1
	ent.object.removed = true
end
-- ---------------------------------------------------------------------------
-- A. What 0.83.0 left in a map: static_save = false came after the add, so
-- each block holds the first snapshot of the actor added there (a leader:
-- mobs:add_mob's authored mark, no leader mark; the rift boss: nothing; a
-- depth pulse arrival: nothing).
-- ---------------------------------------------------------------------------
do
	stored = {
		{name = LEADER, data = {_grug_authored = true}},
		{name = BOSS, data = {}},
		{name = BAT, data = {}},
	}
	after_claim, deaths = 0, 0
	local came = reload()
	check(#came == 3, "A the next visit activates all three snapshots")
	check(came[1].object.removed and came[1].object.props.static_save == false and
		came[1]._grug_leader == nil and came[2].object.removed,
		"A the leader's and the boss's snapshots remove themselves")
	check(not came[3].object.removed, "A the arrival's snapshot stays an ordinary mob")
	check(after_claim == 1, "A nothing else of a removed snapshot's activation runs")
	check(deaths == 0, "A a removed snapshot reaches no death: no drops, loot or credit")
	check(#stored == 1 and stored[1].name == BAT, "A their entries left the block; the arrival's stays")
	local seen = 0
	for _, line in ipairs(logs) do
		if line:find("saved copy of " .. LEADER, 1, true) or line:find("saved copy of " .. BOSS, 1, true) then
			seen = seen + 1
		end
	end
	check(seen == 2, "A each removal leaves an action line")
	stored = {}
end

-- ---------------------------------------------------------------------------
-- B. The fix: static_save is off from the first activation on.
-- ---------------------------------------------------------------------------
do
	after_claim = 0
	local ent = grug_mobs.add_mob_unsaved({x = 0, y = 0, z = 0},
		{name = LEADER, ignore_count = true, _grug_authored = true})
	check(ent and not ent.object.removed and ent._grug_unsaved == true,
		"B the spawner's own leader survives its activation inside the add")
	check(ent.object.props.static_save == false and #stored == 0,
		"B ...unsaved before the engine could store a snapshot")
	check(after_claim == 1, "B ...and its activation runs on")
	local boss = grug_mobs.add_entity_unsaved({x = 0, y = 0, z = 0}, BOSS)
	check(boss and not boss.removed and boss.props.static_save == false and #stored == 0,
		"B the rift boss: kept, no snapshot")
	local bat = grug_mobs.add_mob_unsaved({x = 0, y = 0, z = 0}, {name = BAT, ignore_count = true})
	check(bat and bat.object.props.static_save == false and #stored == 0,
		"B a depth pulse arrival: no snapshot")
	unload_alive(ent.object)
	unload_alive(boss)
	unload_alive(bat.object)
	check(#reload() == 0, "B the next visit finds nothing to activate")
	-- After a death the spawner adds the next one the same way.
	local again = grug_mobs.add_mob_unsaved({x = 0, y = 0, z = 0},
		{name = LEADER, ignore_count = true, _grug_authored = true})
	kill(again)
	check(deaths == 1 and #stored == 0, "B a killed leader leaves nothing behind")
end

-- ---------------------------------------------------------------------------
-- C. The placing mark covers only the add in progress.
-- ---------------------------------------------------------------------------
do
	refuse = true
	check(grug_mobs.add_mob_unsaved({x = 0, y = 0, z = 0},
		{name = LEADER, ignore_count = true}) == nil, "C a refused add returns nil")
	refuse = false
	local object, ent = activate(LEADER, {_grug_authored = true})
	check(object.removed and ent.object.props.static_save == false,
		"C ...and leaves no mark: a later snapshot still removes itself")
	-- A spawner that adds such an actor past the helpers loses it at once
	-- (and the log says so) instead of leaving a snapshot.
	local lines = #logs
	check(core.add_entity({x = 0, y = 0, z = 0}, BOSS) == nil and #stored == 0 and #logs == lines + 1,
		"C an add past the helpers removes itself at once, visibly")
	-- A plain mob activating while nothing is placed is untouched.
	local plain = activate(BAT, nil)
	check(not plain.removed and plain.props.static_save == true, "C an ordinary mob keeps its saved form")
end

-- ---------------------------------------------------------------------------
-- D. The game's sources.
-- ---------------------------------------------------------------------------
do
	local init = read("mods/ENTITIES/grug_mobs/init.lua")
	local wrapper_at = init:find("local old_tag_after_activate = def.after_activate", 1, true)
	check(wrapper_at ~= nil, "D init.lua's after_activate wrapper found")
	local wrapper = wrapper_at and init:sub(wrapper_at, wrapper_at + 900) or ""
	local claim = wrapper:find("if not grug_mobs.unsaved_claim(self) then return end", 1, true)
	local live_claim = wrapper:find("if not grug_mobs.live_claim(self) then return end", 1, true)
	local first_call = wrapper:find("grug_mobs%.[%w_]+%(") or 0
	check(claim and live_claim and claim < live_claim and wrapper:find("grug_mobs.unsaved_claim", 1, true) ==
		first_call, "D the unsaved claim is the wrapper's first statement")
	check(has(init, 'dofile(modpath .. "/unsaved.lua")'), "D init.lua loads unsaved.lua")
	check(has(init, "if def._grug_unsaved then\n\t\tcore.registered_entities[name]._grug_unsaved = true"),
		"D register_mob publishes _grug_unsaved on the prototype")

	local subtypes = read("mods/ENTITIES/grug_mobs/subtypes.lua")
	local branch_at = subtypes:find("if sub.leader then", 1, true)
	local branch = branch_at and subtypes:sub(branch_at, (subtypes:find("\n\tend\n", branch_at, true)))
	check(branch and has(branch, "def._grug_unsaved = true"), "D every leader sub-type is _grug_unsaved")

	local rift = read("mods/ENTITIES/grug_mobs/rift.lua")
	local rift_def = rift:match('grug_mobs%.register_mob%("grug_mobs:rift_boss".-\n}%)\n') or ""
	check(has(rift_def, "_grug_unsaved = true,"), "D the rift boss is _grug_unsaved")
	local spawn_boss = rift:match("local function spawn_boss%(s, players%).-\nend\n") or ""
	check(has(spawn_boss, "grug_mobs.add_entity_unsaved(pos, BOSS)") and
		not has(spawn_boss, "core.add_entity"), "D spawn_boss adds the boss unsaved")

	local regions = read("mods/ENTITIES/grug_mobs/spawn_regions.lua")
	local tick = regions:match("function SR%.leader_tick%(now, players, zone_ids%).-\nend\n") or ""
	check(has(tick, "grug_mobs.add_mob_unsaved(pos, {name = name") and
		not has(tick, "grug_mobs.add_mob(pos"), "D SR.leader_tick adds leaders unsaved")

	local pulse = read("mods/ENTITIES/grug_mobs/depth_pulse.lua")
	local dp_spawn = pulse:match("function DP%.spawn%(mob, spot, now%).-\nend\n") or ""
	check(has(dp_spawn, "grug_mobs.add_mob_unsaved(spot,") and not has(dp_spawn, "grug_mobs.add_mob(spot"),
		"D DP.spawn adds arrivals unsaved")

	for _, file in ipairs({"spawn_regions.lua", "rift.lua", "depth_pulse.lua"}) do
		check(not has(read("mods/ENTITIES/grug_mobs/" .. file), "set_properties({static_save = false})"),
			"D " .. file .. " sets static_save after no add any more")
	end
end

-- ---------------------------------------------------------------------------
-- E. The catalogue: a leader sub-type is placed by its spot and nothing else
-- (an ordinary spawn of an `_grug_unsaved` role would remove itself at once).
-- ---------------------------------------------------------------------------
do
	local json = dofile(repo .. "/tools/r28_b1/json.lua")
	local leaders = {}
	local n = 0
	for _, row in ipairs(json.parse(read("mods/ENTITIES/grug_mobs/data/subtypes.json"))) do
		if row.leader == true then
			leaders[row.role] = true
			n = n + 1
		end
	end
	check(n > 0, "E the catalogue has leader sub-types (" .. n .. ")")
	local zones = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua").zones
	local stray, files = {}, 0
	for _, zone in ipairs(zones) do
		local f = io.open(repo .. "/mods/ENTITIES/grug_mobs/data/zones/" .. zone.id .. ".spawns.json", "rb")
		if f then
			files = files + 1
			local recipe = json.parse(f:read("*a")).recipe or {}
			f:close()
			local function scan(t, part)
				if type(t) ~= "table" then return end
				for k, v in pairs(t) do
					if k == "role" and type(v) == "string" and leaders[v] and part ~= "leaders" then
						stray[#stray + 1] = zone.id .. ":" .. v
					end
					scan(v, part)
				end
			end
			for key, part in pairs(recipe) do scan(part, key) end
		end
	end
	check(files > 30, "E the zones' spawn files read (" .. files .. ")")
	check(#stray == 0, "E no recipe roster names a leader sub-type: " .. table.concat(stray, ", "))
end

if failures > 0 then
	error(("R84 ELITE PORTABLE FAIL %d of %d"):format(failures, checks), 0)
end
print(("R84 ELITE PORTABLE PASS checks=%d"):format(checks))
