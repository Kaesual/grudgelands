-- Disposable engine probe (Round 24 Lane H, ruling 32: pausable character
-- creation). Never shipped: tools/r24_creation_pause/run.sh stages it through
-- tools/luanti_headless.sh.
--
-- A headless server has no client, so each "player" is a probe entity whose
-- ObjectRef answers the player accessors character creation uses (name, meta,
-- inventory, armor groups, HUD, inventory formspec, physics, position). The
-- engine parts are real: preparation progress/readiness from grug_core's
-- scheduler, the arrival emerge, the start positions, and the whole
-- core.registered_on_player_receive_fields chain (sfinv first, then every
-- mod's handler) for dialog and inventory ("") submissions. The probe calls
-- only the join/newplayer/leave callbacks of grug_classes/selection.lua and
-- sfinv, and records show_formspec/close_formspec for its names.
--
-- Choice consumers of other mods (kit grants, visuals, skills page ...) run
-- on the probe object inside pcall; their errors on a fake player are logged
-- as notes, not failures.

local P = "[creation_pause_probe] "
local BASE = vector.new(0, 120, 0)
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
end

local RACE_FORM, CLASS_FORM = "grug_classes:race", "grug_classes:class"
local LOADING_FORM, FACTION_FORM = "grug_classes:loading", "grug_factions:select"
local PAUSED = "Character creation paused \226\128\147 press I to continue"
local READY = "World ready \226\128\147 press I to continue"
local WAITING = "Preparing the world \226\128\147 press I to see progress"

core.register_globalstep(function(dtime) clock = clock + dtime end)

core.register_entity("grug_probe_creation_pause:hero", {
	initial_properties = {
		physical = false, pointable = false, static_save = false,
		hp_max = 20, visual = "sprite", textures = {"blank.png"},
		is_visible = false,
	},
})

--
-- Probe players.
--
local fakes, by_name = {}, {}
local shows, restores = {}, {}
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
	override("set_pos", function(f, p) f.pos = vector.copy(p) end)
	override("get_hp", function(f) return f.hp end)
	override("set_hp", function(f, hp) f.hp = hp end)
	override("set_inventory_formspec", function(f, fs)
		f.inventory_formspec = fs
		f.inventory_writes = f.inventory_writes + 1
	end)
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
	override("set_wielded_item", function(f, s) return f.inv:set_stack("main", 1, s) end)

	local get_player_by_name = core.get_player_by_name
	core.get_player_by_name = function(name)
		return by_name[name] or get_player_by_name(name)
	end
	local show_formspec = core.show_formspec
	core.show_formspec = function(name, formname, form)
		if fakes[name] then
			shows[#shows + 1] = {name = name, formname = formname, form = form, t = clock}
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
	local ref = core.add_entity(BASE, "grug_probe_creation_pause:hero")
	assert(ref, "probe entity was not added")
	install(ref)
	holders[name] = holders[name] or ItemStack("default:stick")
	local inv = core.get_inventory({type = "detached", name = "grug_probe_cp_" .. name}) or
		core.create_detached_inventory("grug_probe_cp_" .. name, {})
	inv:set_size("main", 32)
	local fake = {
		name = name, ref = ref, holder = holders[name], inv = inv,
		armor = {fleshy = 100}, pos = vector.copy(BASE), hp = 20,
		huds = {}, hud_next = 0, flags = {}, physics = {},
		props = {hp_max = 20}, inventory_formspec = "", inventory_writes = 0,
	}
	fakes[ref] = fake
	fakes[name] = fake
	by_name[name] = ref
	local auth = core.get_auth_handler()
	if not auth.get_auth(name) then auth.create_auth(name, "") end
	return ref, fake
end

-- Only creation's and sfinv's own player callbacks run for probe players.
local function ours(fn)
	local ok, info = pcall(debug.getinfo, fn, "S")
	local source = ok and info and info.source or ""
	return source:find("grug_classes/selection.lua", 1, true) ~= nil or
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
	local ref, fake = make_ref(name)
	if is_new then run_list(core.registered_on_newplayers, "newplayer", ref) end
	local n = run_list(core.registered_on_joinplayers, "join", ref)
	-- sfinv's own join write (before creation's lock on a reconnect) is not
	-- the hand-back this probe counts.
	restores[name] = 0
	log(("joined %s (new=%s, %d callbacks)"):format(name, tostring(is_new), n))
	return ref, fake
end

local function leave(name)
	local ref = by_name[name]
	run_list(core.registered_on_leaveplayers, "leave", ref, false)
	by_name[name] = nil
	log("left " .. name)
end

-- The engine's dispatch (RUN_CALLBACKS_MODE_OR_SC): registration order, the
-- first truthy return ends it. Returns the handling mod.
local function submit(name, formname, fields)
	local ref = by_name[name]
	for _, fn in ipairs(core.registered_on_player_receive_fields) do
		local ok, handled = pcall(fn, ref, formname, fields)
		local mod = core.callback_origins[fn].mod
		if not ok then
			check(false, ("receive_fields of %s raised: %s"):format(mod, tostring(handled)))
			return "error:" .. mod
		end
		if handled then return mod end
	end
	return nil
end

local function hint(name)
	local texts = {}
	for _, def in pairs(fakes[name].huds) do
		if def.text and def.text ~= "" then texts[#texts + 1] = def.text end
	end
	return table.concat(texts, " | ")
end

local function shows_since(mark, name)
	local out = {}
	for i = mark + 1, #shows do
		if shows[i].name == name then out[#out + 1] = shows[i] end
	end
	return out
end

local function last_show(name)
	for i = #shows, 1, -1 do
		if shows[i].name == name then return shows[i].formname end
	end
end

local function meta(name, key) return holders[name]:get_meta():get_string(key) end

-- Choice setters: the flow is ours; other mods' consumers on a fake player
-- are best-effort (pcall), and the persisted meta decides the result.
local function guard_setter(tbl, field, key)
	local original = tbl[field]
	tbl[field] = function(player, id, ...)
		local fake = fakes[player]
		if not fake then return original(player, id, ...) end
		local ok, result = pcall(original, player, id, ...)
		if not ok then
			log(("note: a %s consumer failed on the probe object: %s"):format(
				field, tostring(result)))
			return meta(fake.name, key) == id
		end
		return result
	end
end

--
-- Scenario: a list of stages; each stage returns nil to continue at once or a
-- predicate + timeout to wait for.
--
local stages = {}
local function stage(label, fn) stages[#stages + 1] = {label = label, fn = fn} end

local function run_stage(index)
	local s = stages[index]
	if not s then
		log(("RESULT %s checks=%d failures=%d t=%.1fs"):format(
			failures == 0 and "PASS" or "FAIL", checks, failures, clock))
		core.after(1, function() core.request_shutdown("creation pause probe done") end)
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

local ready_at_start
local marks = {}
local function delay(seconds)
	local target = clock + seconds
	return function() return clock >= target end, seconds + 5
end

stage("join during preparation", function()
	ready_at_start = grug_core.world_preparation_status().ready
	log("preparation ready at join: " .. tostring(ready_at_start))
	join("probe_new", true)
	join("probe_open", true)
	if not ready_at_start then
		-- An existing complete character reconnecting during preparation.
		holders.probe_done = ItemStack("default:stick")
		local m = holders.probe_done:get_meta()
		m:set_string("grug_factions:faction", "accord")
		m:set_string("grug_classes:race", "human")
		m:set_string("grug_classes:class", "warrior")
		join("probe_done", false)
	end
	return delay(0.5)
end)

stage("Esc on the waiting screen", function()
	if ready_at_start then
		log("note: preparation was already ready; the engine run cannot observe the readiness transition (portable test covers it)")
		check(last_show("probe_new") == FACTION_FORM, "join after readiness opens the faction dialog")
		marks.new = #shows
		check(submit("probe_new", FACTION_FORM, {quit = "true"}) == "grug_classes",
			"Esc on the faction dialog handled by grug_classes")
		return delay(1.5)
	end
	check(last_show("probe_new") == LOADING_FORM, "new player sees the waiting screen")
	check(fakes.probe_new.inventory_formspec:find("Preparing", 1, true) ~= nil,
		"inventory formspec = waiting screen")
	check(fakes.probe_new.armor.immortal == 1, "new player immortal in stasis")
	check(last_show("probe_done") == LOADING_FORM, "complete character waits during preparation")
	marks.new = #shows
	check(submit("probe_new", LOADING_FORM, {quit = "true"}) == "grug_classes",
		"Esc on the waiting screen handled by grug_classes")
	check(submit("probe_done", LOADING_FORM, {quit = "true"}) == "grug_classes",
		"Esc on the complete character's waiting screen handled")
	check(hint("probe_new") == PAUSED, "paused hint: " .. hint("probe_new"))
	check(hint("probe_done") == WAITING, "preparation-only hint: " .. hint("probe_done"))
	return function() return grug_core.world_preparation_status().ready end, 200
end)

stage("after readiness", function()
	check(#shows_since(marks.new, "probe_new") == 0, "nothing re-opened for probe_new")
	if ready_at_start then
		check(hint("probe_new") == PAUSED, "paused hint on the faction step")
	else
		check(#shows_since(marks.new, "probe_done") == 0, "release opened nothing for probe_done")
		check(hint("probe_new") == READY, "ready hint while dismissed: " .. hint("probe_new"))
		check(last_show("probe_open") == FACTION_FORM, "open waiting screen replaced by the faction step")
		check(hint("probe_open") == "", "no hint while the dialog is open")
		check(fakes.probe_done.armor.immortal == nil, "complete character released")
		check((restores.probe_done or 0) >= 1, "complete character's inventory handed back to sfinv")
		check(hint("probe_done") == "", "complete character's hint removed")
		check(vector.equals(fakes.probe_done.pos, BASE), "complete character not teleported")
	end
	check(fakes.probe_new.inventory_formspec:find("choose_accord", 1, true) ~= nil,
		"inventory formspec = faction step")
	return nil
end)

local set_player_inventory_formspec
stage("inventory key: faction and race", function()
	local writes = fakes.probe_new.inventory_writes
	set_player_inventory_formspec(by_name.probe_new)
	check(fakes.probe_new.inventory_writes == writes, "sfinv writes nothing during creation")
	check(submit("probe_new", "", {choose_accord = "The Accord"}) == "grug_classes",
		"inventory faction choice handled by grug_classes (sfinv passed)")
	check(meta("probe_new", "grug_factions:faction") == "accord", "faction persisted")
	check(last_show("probe_new") == RACE_FORM, "race dialog follows")
	marks.new = #shows
	check(submit("probe_new", RACE_FORM, {quit = "true"}) == "grug_classes", "Esc on race")
	check(hint("probe_new") == PAUSED, "paused hint on the race step")
	return delay(1.5)
end)

stage("race and class from the inventory, then disconnect", function()
	check(#shows_since(marks.new, "probe_new") == 0, "race dialog not re-opened")
	check(fakes.probe_new.inventory_formspec:find("choose_human", 1, true) ~= nil,
		"inventory formspec = race step")
	submit("probe_new", "", {choose_human = "Human"})
	check(meta("probe_new", "grug_classes:race") == "human", "race persisted")
	check(last_show("probe_new") == CLASS_FORM, "class dialog follows")
	-- All in this server step: the arrival emerge the race choice started
	-- cannot have completed yet, so the class stays pending.
	check(submit("probe_new", CLASS_FORM, {quit = "true"}) == "grug_classes", "Esc on class")
	check(fakes.probe_new.inventory_formspec:find("choose_mage", 1, true) ~= nil,
		"inventory formspec = class step")
	submit("probe_new", "", {choose_mage = "Mage"})
	check(meta("probe_new", "grug_classes:pending_class") == "mage", "pending class persisted at once")
	check(meta("probe_new", "grug_classes:class") == "", "class not applied before the arrival")
	check(last_show("probe_new") == LOADING_FORM, "arrival waiting screen after the class choice")
	leave("probe_new")
	return delay(3)
end)

stage("reconnect with a pending class", function()
	check(meta("probe_new", "grug_classes:class") == "", "still no class after the disconnect")
	check(meta("probe_new", "grug_classes:pending_class") == "mage", "pending class survived")
	marks.new = #shows
	join("probe_new", false)
	check(fakes.probe_new.armor.immortal == 1, "reconnect is back in stasis")
	return function()
		return meta("probe_new", "grug_classes:class") ~= ""
	end, 90
end)

stage("arrival after the reconnect", function()
	local s = shows_since(marks.new, "probe_new")
	local saw_class = false
	for _, row in ipairs(s) do
		if row.formname == CLASS_FORM then saw_class = true end
	end
	check(s[1] and s[1].formname == LOADING_FORM, "reconnect opened the arrival waiting screen")
	check(not saw_class, "reconnect did not ask for the class again")
	check(meta("probe_new", "grug_classes:class") == "mage", "persisted pending class applied")
	check(meta("probe_new", "grug_classes:pending_class") == "", "pending class cleared")
	local start = grug_core.start_position("accord", "human")
	check(start and vector.equals(fakes.probe_new.pos, start), "teleported to the human start " ..
		core.pos_to_string(fakes.probe_new.pos))
	check(fakes.probe_new.armor.immortal == nil, "stasis released")
	check(hint("probe_new") == "", "hint removed")
	check((restores.probe_new or 0) >= 1, "inventory handed back to sfinv")
	check(not sfinv.inventory_suspended(by_name.probe_new), "sfinv no longer suspended")
	check(submit("probe_new", "", {grug_probe_unknown = "x"}) ~= "grug_classes",
		"inventory submissions no longer reach creation")
	return nil
end)

stage("named dialogs, Esc on class", function()
	check(submit("probe_open", FACTION_FORM, {choose_throng = "The Throng"}) == "grug_classes",
		"faction dialog choice handled")
	check(last_show("probe_open") == RACE_FORM, "race dialog follows")
	submit("probe_open", RACE_FORM, {choose_orc = "Orc"})
	check(last_show("probe_open") == CLASS_FORM, "class dialog follows")
	marks.open = #shows
	check(submit("probe_open", CLASS_FORM, {quit = "true"}) == "grug_classes", "Esc on class")
	check(hint("probe_open") == PAUSED, "paused hint on the class step")
	return delay(1.5)
end)

stage("class from the inventory with the arrival loaded", function()
	check(#shows_since(marks.open, "probe_open") == 0, "class dialog not re-opened")
	submit("probe_open", "", {choose_warrior = "Warrior"})
	return function() return meta("probe_open", "grug_classes:class") ~= "" end, 90
end)

stage("named flow result", function()
	check(meta("probe_open", "grug_classes:class") == "warrior", "class applied")
	local start = grug_core.start_position("throng", "orc")
	check(start and vector.equals(fakes.probe_open.pos, start), "teleported to the orc start")
	check((restores.probe_open or 0) >= 1, "inventory handed back to sfinv")
	check(fakes.probe_open.armor.immortal == nil, "stasis released")
	check(hint("probe_open") == "", "hint removed")
	return nil
end)

core.register_on_mods_loaded(function()
	guard_setter(grug_factions, "set_faction", "grug_factions:faction")
	guard_setter(grug_classes, "set_race", "grug_classes:race")
	guard_setter(grug_classes, "set_class", "grug_classes:class")
	set_player_inventory_formspec = sfinv.set_player_inventory_formspec
	sfinv.set_player_inventory_formspec = function(player, context)
		local fake = fakes[player]
		if not fake then return set_player_inventory_formspec(player, context) end
		if not sfinv.inventory_suspended(player) then
			restores[fake.name] = (restores[fake.name] or 0) + 1
		end
		local ok, err = pcall(set_player_inventory_formspec, player, context)
		if not ok then
			log("note: sfinv page render failed on the probe object: " .. tostring(err))
		end
	end
end)

core.after(1, function()
	local minp, maxp = vector.offset(BASE, -8, -8, -8), vector.offset(BASE, 8, 8, 8)
	core.emerge_area(minp, maxp, function(_, _, remaining)
		if remaining > 0 then return end
		core.after(0, function()
			assert(core.forceload_block(BASE, true, -1))
			run_stage(1)
		end)
	end)
end)
