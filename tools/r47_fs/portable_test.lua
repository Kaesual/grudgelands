-- Round 47 lane FS portable test (LuaJIT): the furnace loop (rulings 14-16).
--
--   luajit tools/r47_fs/portable_test.lua [REPO]
--
-- Loads the REAL grug_ambience rules.lua, data.lua and init.lua on a fake
-- engine (every data name shipped). Checks:
--   H  the hook: both burning furnaces (default:furnace_active and the Dual
--      Furnace's grug_smelting:dual_furnace_active) get an on_destruct that
--      keeps the node's own one; camp fires, cold furnaces and flowing water
--      are not touched; loading adds no globalstep beyond the one pass;
--   G  the gain: both furnaces play the fire loop at 60 % of the fire gain
--      (times the player's volume), a camp fire at the fire gain, to each
--      listener as before;
--   S  the stop: removing a burning furnace (a dig or an explosion's
--      on_blast both remove the node, so on_destruct runs) fades its loop to
--      0 for every listener at once, over D.stop_fade, and nothing else; the
--      next passes do not start it again; a player who did not hear it gets
--      nothing; with ambience off nothing is sent;
--   U  unchanged: a camp fire removed and a furnace that goes out (swap_node,
--      no on_destruct) fade on the next pass over the 3 s crossfade, as
--      before.
-- The kinds, gains and the Dual Furnace in data.lua: tools/r45_pt8. The
-- engine side (the real on_destruct path): tools/r47_fs/engine.sh.
-- Prints "R47 FS PORTABLE PASS checks=<n>" or the failures (exit 1).

local ROOT = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-9 end

local MOD = ROOT .. "/mods/CORE/grug_ambience"
local D = dofile(MOD .. "/data.lua")

------------------------------------------------------------------------------
-- Fake engine.
------------------------------------------------------------------------------
local us = 0
local steps, joins, leaves, loaded = {}, {}, {}, {}
local players = {}
local sounds, fades = {}, {}
local next_handle = 0
local found_nodes = {} -- node name -> list of positions
local own_destructs = {} -- the furnace's own on_destruct calls
local shipped = {}
for _, names in pairs(D.beds) do for _, n in ipairs(names) do shipped[#shipped + 1] = n .. ".ogg" end end
for _, e in pairs(D.emitters) do shipped[#shipped + 1] = e.sound .. ".ogg" end
local function camp_destruct() end
local registered = {
	["default:furnace"] = {},
	["default:furnace_active"] = {on_destruct = function(pos)
		own_destructs[#own_destructs + 1] = pos
	end},
	["grug_smelting:dual_furnace"] = {},
	["grug_smelting:dual_furnace_active"] = {},
	["grug_nodes:camp_fire"] = {on_destruct = camp_destruct},
	["default:water_source"] = {liquidtype = "source"},
	["default:water_flowing"] = {liquidtype = "flowing",
		liquid_alternative_source = "default:water_source"},
}
local overridden = {}
core = {
	get_current_modname = function() return "grug_ambience" end,
	get_modpath = function() return MOD end,
	get_dir_list = function(path)
		if path:find("/sounds$") then return shipped end
		return {}
	end,
	register_on_mods_loaded = function(fn) loaded[#loaded + 1] = fn end,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
	register_chatcommand = function() end,
	get_player_by_name = function(name) return players[name] end,
	get_us_time = function() return us end,
	get_timeofday = function() return 0.5 end,
	registered_nodes = registered,
	get_content_id = function() return 1 end,
	get_node_raw = function() return 0 end,
	find_nodes_in_area = function(minp, maxp, names)
		local wanted = {}
		for _, n in ipairs(names) do wanted[n] = true end
		local out = {}
		for name, list in pairs(found_nodes) do
			if wanted[name] then
				for _, p in ipairs(list) do
					if p.x >= minp.x and p.x <= maxp.x and p.y >= minp.y and p.y <= maxp.y and
							p.z >= minp.z and p.z <= maxp.z then
						out[name] = out[name] or {}
						table.insert(out[name], p)
					end
				end
			end
		end
		return out
	end,
	hash_node_position = function(p) return (p.x + 1000) * 1000000 + (p.y + 1000) * 1000 + p.z + 1000 end,
	sound_play = function(spec, params, ephemeral)
		next_handle = next_handle + 1
		sounds[#sounds + 1] = {spec = spec, params = params, ephemeral = ephemeral, handle = next_handle}
		return next_handle
	end,
	sound_fade = function(handle, step, gain)
		fades[#fades + 1] = {handle = handle, step = step, gain = gain}
	end,
	dynamic_add_media = function() return true end,
	formspec_escape = function(text) return text end,
	log = function() end,
	override_item = function(name, fields)
		overridden[name] = true
		for k, v in pairs(fields) do registered[name][k] = v end
	end,
}
grug_core = {
	atmosphere_moods = {human = true, underground = true},
	get_atmosphere = function() return "human" end,
	is_day_phase = function() return true end,
}
grug_map = {location = {in_town = function() return false end, capital_of = function() return nil end}}

dofile(MOD .. "/init.lua")
for _, fn in ipairs(loaded) do fn() end
local A = grug_ambience

local function new_player(name, pos, volume)
	local store = {}
	if volume then store["grug_ambience:ambience_volume"] = tostring(volume) end
	local meta = {}
	function meta:get(k) return store[k] end
	function meta:get_int(k) return math.floor(tonumber(store[k]) or 0) end
	function meta:set_int(k, v) store[k] = tostring(v) end
	local p = {}
	function p:get_player_name() return name end
	function p:get_pos() return {x = pos.x, y = pos.y, z = pos.z} end
	function p:get_meta() return meta end
	players[name] = p
	for _, fn in ipairs(joins) do fn(p) end
	return p
end
local function run(seconds)
	for _ = 1, math.floor(seconds / 0.25 + 0.5) do
		us = us + 250000
		for _, fn in ipairs(steps) do fn(0.25) end
	end
end
-- The loops playing to `name` at `pos` (started, not faded to 0 since).
local function loops_at(name, pos)
	local stopped = {}
	for _, f in ipairs(fades) do if f.gain == 0 then stopped[f.handle] = true end end
	local list = {}
	for _, s in ipairs(sounds) do
		local p = s.params.pos
		if s.params.loop and s.params.to_player == name and p and p.x == pos.x and
				p.y == pos.y and p.z == pos.z and not stopped[s.handle] then
			list[#list + 1] = s
		end
	end
	return list
end
-- The engine's removal of a node: its on_destruct, then the node is gone.
local function remove(name, pos)
	local def = registered[name]
	if def.on_destruct then def.on_destruct(pos) end
	local list = found_nodes[name]
	for i = #list, 1, -1 do
		if list[i].x == pos.x and list[i].y == pos.y and list[i].z == pos.z then table.remove(list, i) end
	end
end

------------------------------------------------------------------------------
-- H. The hook.
------------------------------------------------------------------------------
do
	check(overridden["default:furnace_active"] and overridden["grug_smelting:dual_furnace_active"],
		"H both burning furnaces are hooked")
	check(not overridden["grug_nodes:camp_fire"] and registered["grug_nodes:camp_fire"].on_destruct ==
		camp_destruct, "H a camp fire keeps its own on_destruct, untouched")
	check(not overridden["default:furnace"] and not overridden["grug_smelting:dual_furnace"] and
		not overridden["default:water_flowing"], "H cold furnaces and flowing water are not hooked")
	check(#steps == 1, "H one globalstep (the existing pass), no new per-tick work")
	check(type(A.stop_emitters_at) == "function", "H grug_ambience.stop_emitters_at exists")
end

------------------------------------------------------------------------------
-- G. The gain.
------------------------------------------------------------------------------
local FURNACE = {x = 3, y = 10, z = 0}
local DUAL = {x = -3, y = 10, z = 0}
local CAMP = {x = 0, y = 10, z = 4}
local FAR_FURNACE = {x = 200, y = 10, z = 0}
found_nodes["default:furnace_active"] = {FURNACE, FAR_FURNACE}
found_nodes["grug_smelting:dual_furnace_active"] = {DUAL}
found_nodes["grug_nodes:camp_fire"] = {CAMP}
new_player("ana", {x = 0, y = 10, z = 0})
new_player("bo", {x = 1, y = 10, z = 1}, 50)
new_player("cy", {x = 200, y = 10, z = 2}) -- hears only the far furnace
new_player("di", {x = 2, y = 10, z = -1})
run(2)
do
	local fire, furnace = D.gains.fire, D.gains.fire * 0.6
	for _, row in ipairs({{"ana", 1}, {"bo", 0.5}, {"di", 1}}) do
		local name, volume = row[1], row[2]
		local f, d, c = loops_at(name, FURNACE)[1], loops_at(name, DUAL)[1], loops_at(name, CAMP)[1]
		check(f and f.spec.name == "grug_ambience_fire" and near(f.spec.gain, furnace * volume),
			"G " .. name .. ": the furnace plays the fire loop at 60 % (" .. tostring(f and f.spec.gain) .. ")")
		check(d and d.spec.name == "grug_ambience_fire" and near(d.spec.gain, furnace * volume),
			"G " .. name .. ": the Dual Furnace sounds like the furnace (" .. tostring(d and d.spec.gain) .. ")")
		check(c and c.spec.name == "grug_ambience_fire" and near(c.spec.gain, fire * volume),
			"G " .. name .. ": the camp fire keeps the fire gain (" .. tostring(c and c.spec.gain) .. ")")
		check(f and f.ephemeral == false and f.params.loop and f.params.to_player == name,
			"G " .. name .. ": a positional loop to that player only")
	end
	check(#loops_at("cy", FAR_FURNACE) == 1 and #loops_at("cy", FURNACE) == 0,
		"G cy hears only the far furnace")
end

------------------------------------------------------------------------------
-- S. The stop on dig or explosion.
------------------------------------------------------------------------------
do
	-- di switches ambience off: nothing of hers plays any more.
	A.set(players.di, "ambience", false, nil)
	check(#loops_at("di", FURNACE) == 0, "S ambience off: di's loops are faded already")
	local handles = {}
	for _, name in ipairs({"ana", "bo"}) do handles[name] = loops_at(name, FURNACE)[1].handle end
	local others = {}
	for _, name in ipairs({"ana", "bo"}) do
		others[#others + 1] = loops_at(name, DUAL)[1].handle
		others[#others + 1] = loops_at(name, CAMP)[1].handle
	end
	others[#others + 1] = loops_at("cy", FAR_FURNACE)[1].handle
	local plays_before = #sounds
	fades = {}
	own_destructs = {}
	run(0.75) -- part way into the next 2 s window: the stop is not a pass
	fades = {}
	remove("default:furnace_active", FURNACE)
	check(#fades == 2, "S one fade per listener, nothing else (" .. #fades .. ")")
	for _, name in ipairs({"ana", "bo"}) do
		local hit
		for _, f in ipairs(fades) do if f.handle == handles[name] then hit = f end end
		local from = loops_at(name, DUAL)[1].spec.gain -- the same furnace gain
		check(hit and hit.gain == 0 and near(from / hit.step, D.stop_fade),
			"S " .. name .. ": the furnace loop fades to 0 over D.stop_fade")
	end
	check(D.stop_fade > 0 and D.stop_fade <= 0.5, "S the stop fade is short (" .. D.stop_fade .. " s)")
	for _, f in ipairs(fades) do
		for _, h in ipairs(others) do check(f.handle ~= h, "S no other loop is touched") end
	end
	check(#own_destructs == 1 and own_destructs[1] == FURNACE, "S the furnace's own on_destruct still runs")
	run(6)
	check(#loops_at("ana", FURNACE) == 0 and #loops_at("bo", FURNACE) == 0,
		"S the next passes do not start it again")
	local stopped_others = 0
	for _, f in ipairs(fades) do
		for _, h in ipairs(others) do if f.handle == h then stopped_others = stopped_others + 1 end end
	end
	check(stopped_others == 0 and #sounds == plays_before,
		"S the Dual Furnace, the camp fire and the far furnace play on, nothing restarts")
	-- The Dual Furnace blown up (its on_blast removes the node).
	local dual = {ana = loops_at("ana", DUAL)[1].handle, bo = loops_at("bo", DUAL)[1].handle}
	fades = {}
	remove("grug_smelting:dual_furnace_active", DUAL)
	check(#fades == 2 and fades[1].gain == 0 and fades[2].gain == 0 and
		((fades[1].handle == dual.ana and fades[2].handle == dual.bo) or
			(fades[1].handle == dual.bo and fades[2].handle == dual.ana)),
		"S the Dual Furnace destroyed: its loop stops for both listeners at once")
	-- A furnace nobody hears: nothing sent.
	fades = {}
	A.stop_emitters_at({x = 50, y = 10, z = 50})
	check(#fades == 0, "S a position without a loop sends nothing")
end

------------------------------------------------------------------------------
-- U. Unchanged paths.
------------------------------------------------------------------------------
do
	-- A camp fire removed: no hook, it fades on the next pass (3 s crossfade).
	local camp = loops_at("ana", CAMP)[1].handle
	fades = {}
	remove("grug_nodes:camp_fire", CAMP)
	check(#fades == 0, "U a removed camp fire sends nothing at once")
	run(2)
	local hit
	for _, f in ipairs(fades) do if f.handle == camp then hit = f end end
	check(hit and hit.gain == 0 and near(D.gains.fire / hit.step, D.crossfade),
		"U ... and fades on the next pass over the crossfade")
	-- A furnace that goes out: swap_node, no on_destruct; the next pass fades it.
	local far = loops_at("cy", FAR_FURNACE)[1].handle
	fades = {}
	found_nodes["default:furnace_active"] = {}
	check(#fades == 0, "U a furnace going out sends nothing at once")
	run(2)
	hit = nil
	for _, f in ipairs(fades) do if f.handle == far then hit = f end end
	check(hit and hit.gain == 0 and near(D.gains.furnace / hit.step, D.crossfade),
		"U ... and fades on the next pass over the crossfade, as before")
end

if failures > 0 then
	print(("R47 FS PORTABLE FAIL failures=%d checks=%d"):format(failures, checks))
	os.exit(1)
end
print(("R47 FS PORTABLE PASS checks=%d"):format(checks))
