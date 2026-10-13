-- Disposable engine probe (Round 47 lane FS): a burning furnace and a
-- burning Dual Furnace play their ambience loop to two player stand-ins, then
-- the furnace is removed (core.remove_node, the call builtin core.node_dig
-- ends with) and the Dual Furnace is blown up (its registered on_blast, the
-- grug_jobs override). Each removal must fade that loop to 0 for both
-- listeners in the same server step, over grug_ambience.data.stop_fade, and
-- leave the other loop alone; later passes must not start it again. Never
-- shipped: tools/r47_fs/engine.sh stages it through tools/luanti_headless.sh.
--
-- No client exists, so the stand-ins (tables answering the few ObjectRef
-- methods the ambience pass calls) join only grug_ambience, and the sound
-- calls to them are recorded with probe handles instead of being sent.

local P = "[r47fs_probe] "
local function log(msg) core.log("action", P .. msg) end
local failures = 0
local function check(ok, label)
	log((ok and "ok   " or "FAIL ") .. label)
	if not ok then failures = failures + 1 end
end

local A = grug_ambience
local D = A.data
local BASE = {x = 0, y = 300, z = 0}
local FURNACE = {x = BASE.x + 3, y = BASE.y, z = BASE.z}
local DUAL = {x = BASE.x - 3, y = BASE.y, z = BASE.z}
local NAMES = {"r47fs_a", "r47fs_b"}

-- ---------------------------------------------------------------- stand-ins
local fakes = {}
local function make_fake(name, pos)
	local store = {}
	local meta = {}
	function meta:get(k) return store[k] end
	function meta:get_int(k) return math.floor(tonumber(store[k]) or 0) end
	function meta:set_int(k, v) store[k] = tostring(v) end
	local p = {}
	function p:get_player_name() return name end
	function p:get_pos() return vector.copy(pos) end
	function p:get_meta() return meta end
	function p:is_player() return true end
	return p
end

-- Sound calls to a stand-in are recorded; every other call goes through.
local FIRST = 1000000
local plays, fades = {}, {}
local next_handle = FIRST
local sound_play, sound_fade, get_player_by_name = core.sound_play, core.sound_fade,
	core.get_player_by_name
core.sound_play = function(spec, params, ephemeral)
	if type(params) == "table" and params.to_player and fakes[params.to_player] then
		next_handle = next_handle + 1
		plays[#plays + 1] = {spec = spec, params = params, handle = next_handle, ephemeral = ephemeral}
		return next_handle
	end
	return sound_play(spec, params, ephemeral)
end
core.sound_fade = function(handle, step, gain)
	if type(handle) == "number" and handle > FIRST then
		fades[#fades + 1] = {handle = handle, step = step, gain = gain}
		return
	end
	return sound_fade(handle, step, gain)
end
core.get_player_by_name = function(name)
	return fakes[name] or get_player_by_name(name)
end

local function from(fn, file)
	local info = debug.getinfo(fn, "S")
	return info and info.source and info.source:find(file, 1, true) ~= nil
end

-- The loop playing to `name` at `pos` (started and not faded to 0).
local function loop_at(name, pos)
	local stopped = {}
	for _, f in ipairs(fades) do if f.gain == 0 then stopped[f.handle] = true end end
	for _, s in ipairs(plays) do
		local q = s.params.pos
		if s.params.loop and s.params.to_player == name and q and vector.equals(q, pos) and
				not stopped[s.handle] then
			return s
		end
	end
end

local function stops_for(handles)
	local n = 0
	for _, f in ipairs(fades) do
		for _, h in ipairs(handles) do
			if f.handle == h and f.gain == 0 then n = n + 1 end
		end
	end
	return n
end

-- ---------------------------------------------------------------- the run
local function finish()
	log(failures == 0 and "RESULT PASS" or ("RESULT FAIL failures=" .. failures))
	core.request_shutdown("r47 fs probe done", false, 0)
end

local function after_passes()
	local gain = D.gains.furnace
	local furnace, dual = {}, {}
	for _, name in ipairs(NAMES) do
		local f, d = loop_at(name, FURNACE), loop_at(name, DUAL)
		check(f and f.spec.name == "grug_ambience_fire" and math.abs(f.spec.gain - gain) < 1e-9,
			name .. ": the furnace loop plays at " .. tostring(f and f.spec.gain))
		check(d and d.spec.name == "grug_ambience_fire" and math.abs(d.spec.gain - gain) < 1e-9,
			name .. ": the Dual Furnace loop plays at " .. tostring(d and d.spec.gain))
		furnace[#furnace + 1] = f and f.handle
		dual[#dual + 1] = d and d.handle
	end
	if failures > 0 then return finish() end
	local count = #plays

	-- The dig path: builtin node_dig removes the node with core.remove_node.
	fades = {}
	core.remove_node(FURNACE)
	check(core.get_node(FURNACE).name == "air", "the furnace is gone")
	check(#fades == 2 and stops_for(furnace) == 2,
		"removed: the furnace loop faded to 0 for both listeners in the same step (" .. #fades .. " fades)")
	check(stops_for(dual) == 0, "removed: the Dual Furnace loop plays on")
	for _, f in ipairs(fades) do
		check(math.abs(gain / f.step - D.stop_fade) < 1e-6,
			("removed: fade over %.2f s"):format(gain / f.step))
	end

	-- The explosion path: the registered on_blast (grug_jobs: contents, then
	-- core.remove_node).
	fades = {}
	local drops = core.registered_nodes["grug_smelting:dual_furnace_active"].on_blast(DUAL)
	check(core.get_node(DUAL).name == "air" and type(drops) == "table", "the Dual Furnace is blown up")
	check(#fades == 2 and stops_for(dual) == 2,
		"blown up: the Dual Furnace loop faded to 0 for both listeners in the same step (" .. #fades .. " fades)")

	core.after(5, function()
		check(#plays == count, "five seconds on: nothing started again (" .. (#plays - count) .. " plays)")
		finish()
	end)
end

local function start()
	-- The hook sits on the real definitions, after every override at load.
	for _, node in ipairs({"default:furnace_active", "grug_smelting:dual_furnace_active"}) do
		local def = core.registered_nodes[node]
		check(def and def.on_destruct and from(def.on_destruct, "grug_ambience/init.lua"),
			node .. ": on_destruct is the ambience hook")
	end
	check(not from(core.registered_nodes["grug_nodes:camp_fire"].on_destruct or start,
		"grug_ambience/init.lua"), "grug_nodes:camp_fire: no ambience hook")
	core.set_node(FURNACE, {name = "default:furnace_active"})
	core.set_node(DUAL, {name = "grug_smelting:dual_furnace_active"})
	local joins = {}
	for _, fn in ipairs(core.registered_on_joinplayers) do
		if from(fn, "grug_ambience/init.lua") then joins[#joins + 1] = fn end
	end
	check(#joins == 1, "one ambience join callback")
	for index, name in ipairs(NAMES) do
		fakes[name] = make_fake(name, {x = BASE.x, y = BASE.y, z = BASE.z + index})
		for _, fn in ipairs(joins) do fn(fakes[name]) end
	end
	-- Two full passes (eight slots of 0.25 s each).
	core.after(4.5, after_passes)
end

core.register_on_mods_loaded(function()
	core.after(1, function()
		core.emerge_area(vector.subtract(BASE, 16), vector.add(BASE, 16), function(_, _, remaining)
			if remaining == 0 then start() end
		end)
	end)
end)
