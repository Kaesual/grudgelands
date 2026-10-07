-- Disposable engine probe (Round 41 lane UP: the platform's map reset).
-- Never shipped: tools/r41_up/engine.sh stages it through
-- tools/luanti_headless.sh for two boots of the same world.
--
--   boot 1 (no reset pending): waits for the world preparation and the start
--     NPCs, places a Claim Stone for the character "oldhero" and writes what
--     boot 2 checks to the world folder, then shuts down. engine.sh deletes
--     map.sqlite (map_meta.txt and the rest of the world stay) and raises
--     grug_reset_world to 1, as the platform does.
--   boot 2 (the reset): the map-bound state is cleared during the load, the
--     world record follows; "oldhero" (a 0.40 character: race stored, no
--     record) is held, then moved to the human start without the arrival
--     flow, its home claim cleared and its record written; a new character
--     records the world's value and is not moved; the start areas are
--     prepared again; the old Claim Stone node is gone.
--
-- A headless server has no client, so each "player" is a probe entity whose
-- ObjectRef answers the player accessors the code uses (the Round 35 creation
-- probe's harness, tools/r35_c). Only the join/newplayer/leave callbacks of
-- grug_core/map_reset.lua, grug_classes/selection.lua and sfinv run for them.

local P = "[r41_up_probe] "
local BASE = vector.new(0, 120, 0)
local STATE_FILE = core.get_worldpath() .. "/r41_up_probe.txt"
local failures, checks = 0, 0
local clock = 0

local function log(msg) core.log("action", P .. msg) end
local function check(ok, msg)
	checks = checks + 1
	if ok then
		log("ok   " .. msg)
	else
		failures = failures + 1
		core.log("error", P .. "FAIL " .. msg)
	end
	return ok
end

core.register_globalstep(function(dtime) clock = clock + dtime end)

core.register_entity("grug_probe_r41_up:hero", {
	initial_properties = {
		physical = false, pointable = false, static_save = false,
		hp_max = 20, visual = "sprite", textures = {"blank.png"},
		is_visible = false,
	},
})

--
-- Probe players (the Round 35 harness, trimmed).
--
local fakes, by_name = {}, {}
local methods

local function install(ref)
	if methods then return end
	methods = getmetatable(ref)
	local function override(name, fn)
		local original = methods[name]
		methods[name] = function(self, ...)
			local fake = fakes[self]
			if fake then return fn(fake, ...) end
			if original then return original(self, ...) end
		end
	end
	override("is_player", function() return true end)
	override("get_player_name", function(f) return f.name end)
	override("get_meta", function(f) return f.holder:get_meta() end)
	override("get_inventory", function(f) return f.inv end)
	override("get_velocity", function() return vector.new(0, 0, 0) end)
	override("add_velocity", function() end)
	override("get_armor_groups", function(f) return table.copy(f.armor) end)
	override("set_armor_groups", function(f, g) f.armor = table.copy(g) end)
	override("get_pos", function(f) return vector.copy(f.pos) end)
	override("set_pos", function(f, p) f.pos = vector.copy(p); f.moves = f.moves + 1 end)
	override("get_hp", function(f) return f.hp end)
	override("set_hp", function(f, hp) f.hp = hp end)
	override("set_inventory_formspec", function(f, fs) f.inventory_formspec = fs end)
	override("get_inventory_formspec", function(f) return f.inventory_formspec end)
	override("hud_add", function(f, def)
		f.hud_next = f.hud_next + 1
		f.huds[f.hud_next] = table.copy(def)
		return f.hud_next
	end)
	override("hud_change", function(f, id, stat, value)
		if f.huds[id] then f.huds[id][stat] = value end
	end)
	override("hud_remove", function(f, id) f.huds[id] = nil end)
	override("hud_get_flags", function(f) return table.copy(f.flags) end)
	override("hud_set_flags", function(f, flags)
		for key, value in pairs(flags) do f.flags[key] = value end
	end)
	override("set_physics_override", function(f, o)
		for key, value in pairs(o) do f.physics[key] = value end
	end)
	override("get_physics_override", function(f) return table.copy(f.physics) end)
	override("get_properties", function(f) return table.copy(f.props) end)
	override("set_properties", function(f, props)
		for key, value in pairs(props) do f.props[key] = value end
	end)
	override("set_nametag_attributes", function() end)
	override("get_player_control", function() return {} end)
	override("get_player_control_bits", function() return 0 end)
	override("get_look_dir", function() return vector.new(0, 0, 1) end)
	override("get_look_horizontal", function() return 0 end)
	override("get_look_vertical", function() return 0 end)
	override("get_wield_list", function() return "main" end)
	override("get_wield_index", function() return 1 end)
	override("get_wielded_item", function(f) return f.inv:get_stack("main", 1) end)

	local get_player_by_name = core.get_player_by_name
	core.get_player_by_name = function(name)
		return by_name[name] or get_player_by_name(name)
	end
	local show_formspec = core.show_formspec
	core.show_formspec = function(name, formname, form)
		if fakes[name] then
			fakes[name].shows[#fakes[name].shows + 1] = formname
			return
		end
		return show_formspec(name, formname, form)
	end
	local close_formspec = core.close_formspec
	core.close_formspec = function(name, formname)
		if fakes[name] then return end
		return close_formspec(name, formname)
	end
end

local holders = {} -- name -> ItemStack whose meta stands in for player meta

local function make_ref(name)
	local ref = core.add_entity(BASE, "grug_probe_r41_up:hero")
	assert(ref, "probe entity was not added")
	install(ref)
	holders[name] = holders[name] or ItemStack("default:stick")
	local inv = core.get_inventory({type = "detached", name = "grug_probe_r41up_" .. name}) or
		core.create_detached_inventory("grug_probe_r41up_" .. name, {})
	inv:set_size("main", 32)
	local fake = {
		name = name, ref = ref, holder = holders[name], inv = inv,
		armor = {fleshy = 100}, pos = vector.copy(BASE), hp = 20, moves = 0,
		huds = {}, hud_next = 0, flags = {}, physics = {}, shows = {},
		props = {hp_max = 20}, inventory_formspec = "",
	}
	fakes[ref] = fake
	fakes[name] = fake
	by_name[name] = ref
	local auth = core.get_auth_handler()
	if not auth.get_auth(name) then auth.create_auth(name, "") end
	return ref, fake
end

local function ours(fn)
	local ok, info = pcall(debug.getinfo, fn, "S")
	local source = ok and info and info.source or ""
	return source:find("grug_classes/selection.lua", 1, true) ~= nil or
		source:find("grug_core/map_reset.lua", 1, true) ~= nil or
		source:find("sfinv/api.lua", 1, true) ~= nil
end

local function run_list(list, label, ...)
	local n = 0
	for _, fn in ipairs(list) do
		if ours(fn) then
			n = n + 1
			local ok, err = pcall(fn, ...)
			check(ok, label .. " callback ran" .. (ok and "" or (" (" .. tostring(err) .. ")")))
		end
	end
	return n
end

local function join(name, is_new)
	local ref = make_ref(name)
	if is_new then run_list(core.registered_on_newplayers, "newplayer", ref) end
	local n = run_list(core.registered_on_joinplayers, "join", ref)
	log(("joined %s (new=%s, %d callbacks)"):format(name, tostring(is_new), n))
	return ref
end

local function meta(name, key) return holders[name]:get_meta():get_string(key) end

--
-- Stages: each returns nil to go on at once, or a predicate and a timeout.
--
local stages = {}
local function stage(label, fn) stages[#stages + 1] = {label = label, fn = fn} end

local function run_stage(index)
	local s = stages[index]
	if not s then
		log(("RESULT %s checks=%d failures=%d t=%.1fs"):format(
			failures == 0 and "PASS" or "FAIL", checks, failures, clock))
		core.after(1, function() core.request_shutdown("r41 up probe done") end)
		return
	end
	log(("stage %d: %s (t=%.1fs)"):format(index, s.label, clock))
	local wait, timeout = s.fn()
	if not wait then
		core.after(0.1, run_stage, index + 1)
		return
	end
	local started = clock
	local function poll()
		if wait() then
			core.after(0.1, run_stage, index + 1)
		elseif clock - started > timeout then
			check(false, s.label .. ": timed out after " .. timeout .. " s")
			core.after(0.1, run_stage, index + 1)
		else
			core.after(0.2, poll)
		end
	end
	poll()
end

local function prefix_count(storage, prefix)
	local n = 0
	for _, key in ipairs(storage:get_keys()) do
		if key:sub(1, #prefix) == prefix then n = n + 1 end
	end
	return n
end

local function emerged(pos, radius)
	local done = false
	core.emerge_area(vector.offset(pos, -radius, -radius, -radius),
		vector.offset(pos, radius, radius, radius), function(_, _, remaining)
			if remaining == 0 then done = true end
		end)
	return function() return done end
end

local function write_state(rows)
	local f = assert(io.open(STATE_FILE, "w"))
	f:write(core.serialize(rows))
	f:close()
end
local function read_state()
	local f = io.open(STATE_FILE, "r")
	if not f then return nil end
	local text = f:read("*a")
	f:close()
	return core.deserialize(text)
end

local reset = grug_core.map_reset
local boot2 = reset.pending()
local saved = boot2 and read_state() or nil
-- What the clears left, read during this mod's load: after the clearing
-- mods (this probe depends on them), before anything refills.
local at_load = {
	prep = grug_core.world_preparation_status(),
	startnpc = prefix_count(grug_mobs.storage, "startnpc:"),
	live_gen = prefix_count(grug_mobs.storage, "live_gen:"),
	claims = grug_housing.model.claim_count(),
	old_state = grug_housing.model.player_state("oldhero"),
}
log(("boot %d: setting pending=%s applied=%d"):format(boot2 and 2 or 1,
	tostring(boot2), reset.applied))

if not boot2 then
	stage("boot 1: the world is prepared", function()
		check(reset.applied == 0, "boot 1 runs without a reset")
		return function() return grug_core.world_preparation_status().ready end, 200
	end)
	stage("boot 1: the start NPCs are placed", function()
		return function() return prefix_count(grug_mobs.storage, "startnpc:") > 0 end, 60
	end)
	local claim_pos
	stage("boot 1: a Claim Stone near the human start", function()
		local start = grug_core.start_position("accord", "human")
		claim_pos = vector.round(vector.offset(start, 0, 30, 40))
		return emerged(claim_pos, 8), 60
	end)
	stage("boot 1: place it and remember", function()
		core.set_node(claim_pos, {name = grug_housing.DRAFT_STONE})
		local claim = grug_housing.model.create("oldhero", claim_pos)
		check(core.get_node(claim_pos).name == grug_housing.DRAFT_STONE, "the claim node stands")
		check(grug_housing.model.player_state("oldhero") == "placed", "oldhero's stone is placed")
		write_state({claim_id = claim.id, claim_pos = claim_pos,
			startnpc = prefix_count(grug_mobs.storage, "startnpc:"),
			live_gen = prefix_count(grug_mobs.storage, "live_gen:"),
			prep_total = grug_core.world_preparation_status().total})
		log(("remembered: claim %d at %s, %d start NPC markers, %d generations"):format(
			claim.id, core.pos_to_string(claim_pos), prefix_count(grug_mobs.storage, "startnpc:"),
			prefix_count(grug_mobs.storage, "live_gen:")))
		return nil
	end)
else
	local arrivals = 0
	grug_classes.register_on_arrival(function(p)
		if fakes[p] then arrivals = arrivals + 1 end
	end)
	stage("boot 2: the clears during the load", function()
		check(saved ~= nil, "boot 1's notes are in the world folder")
		saved = saved or {}
		check(reset.applied == 1, "the reset applies setting 1")
		check(at_load.prep.mode == "starts" and at_load.prep.total == 0 and
			not at_load.prep.ready, "the preparation plan starts again (mode kept)")
		check(at_load.startnpc == 0 and (saved.startnpc or 0) > 0,
			"the start NPC markers are gone (" .. tostring(saved.startnpc) .. " before)")
		check(at_load.live_gen == (saved.live_gen or -1),
			"the liveness generations stay (" .. at_load.live_gen .. ")")
		check(at_load.claims == 0, "no housing claim survives")
		check(at_load.old_state == "needs_stone", "oldhero needs a new stone: " ..
			tostring(at_load.old_state))
		-- oldhero as the 0.40 world left it: created, no record, a claim home.
		local m = ItemStack("default:stick")
		holders.oldhero = m
		local om = m:get_meta()
		om:set_string("grug_factions:faction", "accord")
		om:set_string("grug_classes:race", "human")
		om:set_string("grug_classes:class", "warrior")
		om:set_string("grug_xp:xp", "50000")
		om:set_string("grug_home:claim", tostring(saved.claim_id or 1))
		join("oldhero", false)
		join("newbie", true)
		check(meta("newbie", "grug_core:reset_world") == "1", "a new character records 1 at once")
		check(meta("oldhero", "grug_core:reset_world") == "", "oldhero has no record yet")
		check(grug_core.player_in_creation_stasis("oldhero"), "oldhero is held")
		check(fakes.oldhero.armor.immortal == 1, "...and safe")
		return function() return grug_core.world_preparation_status().ready end, 200
	end)
	stage("boot 2: the start areas are prepared again", function()
		local status = grug_core.world_preparation_status()
		check(status.ready and status.total > 0 and status.completed == status.total,
			("the starts are prepared again (%d/%d)"):format(status.completed, status.total))
		return function() return meta("oldhero", "grug_core:reset_world") == "1" end, 90
	end)
	stage("boot 2: oldhero at the human start", function()
		local start = grug_core.start_position("accord", "human")
		check(vector.equals(fakes.oldhero.pos, start), "oldhero moved to the human start " ..
			core.pos_to_string(fakes.oldhero.pos))
		check(fakes.oldhero.moves == 1, "one move")
		check(not grug_core.player_in_creation_stasis("oldhero"), "oldhero released")
		check(fakes.oldhero.armor.immortal == nil, "...no longer immortal")
		check(meta("oldhero", "grug_home:claim") == "", "the home claim is cleared")
		check(meta("oldhero", "grug_xp:xp") == "50000", "the XP stays")
		check(meta("oldhero", "grug_classes:class") == "warrior", "the class stays")
		check(arrivals == 0, "no arrival flow")
		check(fakes.newbie.moves == 0 and meta("newbie", "grug_classes:race") == "",
			"the new character is in creation, never moved")
		return emerged(saved.claim_pos, 8), 60
	end)
	stage("boot 2: the old claim node is gone", function()
		local node = core.get_node(saved.claim_pos)
		check(node.name ~= "ignore" and not grug_housing.STONE_NODES[node.name],
			"the regenerated map has no Claim Stone there: " .. node.name)
		check(grug_housing.model.claim_at(saved.claim_pos) == nil, "no claim protects it")
		return nil
	end)
end

core.register_on_mods_loaded(function()
	local set_player_inventory_formspec = sfinv.set_player_inventory_formspec
	sfinv.set_player_inventory_formspec = function(player, context)
		if not fakes[player] then return set_player_inventory_formspec(player, context) end
		local ok, err = pcall(set_player_inventory_formspec, player, context)
		if not ok then log("note: sfinv page render failed on the probe object: " .. tostring(err)) end
	end
end)

core.after(1, function()
	core.emerge_area(vector.offset(BASE, -8, -8, -8), vector.offset(BASE, 8, 8, 8),
		function(_, _, remaining)
			if remaining > 0 then return end
			core.after(0, function()
				assert(core.forceload_block(BASE, true, -1))
				run_stage(1)
			end)
		end)
end)
