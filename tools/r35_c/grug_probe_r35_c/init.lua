-- Disposable engine probe (Round 35 Lane C: character creation in one
-- window). Never shipped: tools/r35_c/engine.sh stages it through
-- tools/luanti_headless.sh. The harness is Round 24's creation probe.
--
-- A headless server has no client, so each "player" is a probe entity whose
-- ObjectRef answers the player accessors character creation uses (name, meta,
-- inventory, armor groups, HUD, inventory formspec, physics, position). The
-- engine parts are real: preparation progress/readiness from grug_core's
-- scheduler, the arrival emerge, the start positions, the real look panel and
-- the whole core.registered_on_player_receive_fields chain (sfinv first, then
-- every mod's handler) for dialog and inventory ("") submissions, driven with
-- the fields a client sends. The probe calls only the join/newplayer/leave
-- callbacks of grug_classes/selection.lua and sfinv, and records
-- show_formspec/close_formspec for its names.
--
-- Choice consumers of other mods (kit grants, visuals, skills page ...) run
-- on the probe object inside pcall; their errors on a fake player are logged
-- as notes, not failures.

local P = "[r35_c_probe] "
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
	return ok
end

local CREATE_FORM, LOADING_FORM = "grug_classes:create", "grug_classes:loading"
local PAUSED = "Character creation paused \226\128\147 press I to continue"
local READY = "World ready \226\128\147 press I to continue"
local IDENTITY = {"grug_factions:faction", "grug_classes:race", "grug_classes:class",
	"grug_visuals:look", "grug_classes:arriving"}

core.register_globalstep(function(dtime) clock = clock + dtime end)

core.register_entity("grug_probe_r35_c:hero", {
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
	local ref = core.add_entity(BASE, "grug_probe_r35_c:hero")
	assert(ref, "probe entity was not added")
	install(ref)
	holders[name] = holders[name] or ItemStack("default:stick")
	local inv = core.get_inventory({type = "detached", name = "grug_probe_r35c_" .. name}) or
		core.create_detached_inventory("grug_probe_r35c_" .. name, {})
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
local function nothing_stored(name)
	for _, key in ipairs(IDENTITY) do
		if meta(name, key) ~= "" then return false end
	end
	return true
end
local function inv_has(name, needle)
	return fakes[name].inventory_formspec:find(needle, 1, true) ~= nil
end

-- Choice setters: the flow is ours; other mods' consumers on a fake player
-- are best-effort (pcall), and the persisted meta decides the result.
local function guard(tbl, field, done)
	local original = tbl[field]
	tbl[field] = function(player, value, ...)
		local fake = fakes[player]
		if not fake then return original(player, value, ...) end
		local ok, result = pcall(original, player, value, ...)
		if not ok then
			log(("note: a %s consumer failed on the probe object: %s"):format(
				field, tostring(result)))
			return done(fake.name, value)
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
		core.after(1, function() core.request_shutdown("r35 c probe done") end)
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

stage("join, wait for the world", function()
	ready_at_start = grug_core.world_preparation_status().ready
	log("preparation ready at join: " .. tostring(ready_at_start))
	join("probe_a", true)
	join("probe_b", true)
	-- The join dialog opens one server step later (core.after(0)).
	return delay(0.5)
end)

stage("Esc on the waiting screen", function()
	if not ready_at_start then
		check(last_show("probe_a") == LOADING_FORM, "a new player waits for the world")
		check(fakes.probe_a.armor.immortal == 1, "stasis while the world is prepared")
		check(submit("probe_a", LOADING_FORM, {quit = "true"}) == "grug_classes",
			"Esc on the waiting screen")
		check(hint("probe_a") == PAUSED, "paused hint: " .. hint("probe_a"))
	end
	return function() return grug_core.world_preparation_status().ready end, 200
end)

stage("the window after readiness", function()
	check(last_show("probe_b") == CREATE_FORM, "the open dialog becomes the window")
	if ready_at_start then
		log("note: preparation was already ready; the readiness transition is the portable test's")
		check(submit("probe_a", CREATE_FORM, {quit = "true"}) == "grug_classes", "Esc on the window")
		check(hint("probe_a") == PAUSED, "paused hint on the window")
	else
		check(hint("probe_a") == READY, "ready hint while dismissed: " .. hint("probe_a"))
	end
	check(inv_has("probe_a", "faction_accord"), "the inventory is the window")
	check(inv_has("probe_a", "bgcolor[#080808FF;both;#000000FF]"), "the dark backdrop")
	return nil
end)

local set_player_inventory_formspec
stage("the draft through the inventory key", function()
	local writes = fakes.probe_a.inventory_writes
	set_player_inventory_formspec(by_name.probe_a)
	check(fakes.probe_a.inventory_writes == writes, "sfinv writes nothing during creation")
	check(submit("probe_a", "", {faction_accord = "The Accord"}) == "grug_classes",
		"faction from the inventory handled by grug_classes (sfinv passed)")
	check(last_show("probe_a") == CREATE_FORM, "the window opens again")
	check(not inv_has("probe_a", "model["), "no model before a race")
	submit("probe_a", "", {race_human = "Human"})
	check(inv_has("probe_a", "grug_visuals_human_body.png"), "the human preview (real look panel)")
	check(inv_has("probe_a", ";false;true;0,79;30]"), "mouse rotation on, auto-rotation off")
	submit("probe_a", "", {race_dwarf = "Dwarf"})
	check(inv_has("probe_a", "grug_visuals_dwarf_body.png"), "a race change redraws the preview")
	submit("probe_a", "", {class_mage = "Mage"})
	check(inv_has("probe_a", "create_character"), "Create active")
	submit("probe_a", "", {faction_throng = "The Throng"})
	check(not inv_has("probe_a", "model[") and not inv_has("probe_a", "create_character"),
		"a faction change clears race and look")
	submit("probe_a", "", {race_human = "Human"})
	check(not inv_has("probe_a", "model["), "a forged race of the other faction is refused")
	submit("probe_a", "", {race_orc = "Orc"})
	check(inv_has("probe_a", "style[class_mage;bgcolor=#8a6a1e;font=bold]"),
		"the class stayed through the faction change")
	local before = fakes.probe_a.inventory_formspec
	submit("probe_a", "", {look_next_tone = ">"})
	check(fakes.probe_a.inventory_formspec ~= before, "a look button changes the draft")
	submit("probe_a", "", {look_random = "Random"})
	marks.a = #shows
	check(submit("probe_a", CREATE_FORM, {quit = "true"}) == "grug_classes", "Esc on the window")
	check(hint("probe_a") == PAUSED, "paused hint")
	check(nothing_stored("probe_a"), "nothing stored before Create")
	return delay(1.5)
end)

stage("Create, a second Create, then disconnect mid-load", function()
	check(#shows_since(marks.a, "probe_a") == 0, "the window was not re-opened")
	check(inv_has("probe_a", "style[race_orc;bgcolor=#8a6a1e;font=bold]"), "the draft survived Esc")
	check(submit("probe_a", "", {create_character = "Create character"}) == "grug_classes",
		"Create from the inventory")
	check(meta("probe_a", "grug_factions:faction") == "throng", "faction stored")
	check(meta("probe_a", "grug_classes:race") == "orc", "race stored")
	check(meta("probe_a", "grug_classes:class") == "mage", "class stored")
	check(meta("probe_a", "grug_visuals:look"):match("^%d,%d,%d,%d,%d$") ~= nil,
		"look stored: " .. meta("probe_a", "grug_visuals:look"))
	check(meta("probe_a", "grug_classes:arriving") == "1", "marked arriving")
	check(last_show("probe_a") == LOADING_FORM, "the waiting screen after Create")
	local look = meta("probe_a", "grug_visuals:look")
	check(submit("probe_a", CREATE_FORM, {create_character = "Create character"}) == "grug_classes",
		"a second Create is swallowed")
	submit("probe_a", "", {faction_accord = "The Accord"})
	check(meta("probe_a", "grug_factions:faction") == "throng" and
		meta("probe_a", "grug_visuals:look") == look, "a second Create changes nothing")
	-- All in this server step: the arrival emerge cannot have completed yet.
	leave("probe_a")
	return delay(3)
end)

stage("reconnect during the arrival wait", function()
	check(meta("probe_a", "grug_classes:arriving") == "1", "still arriving after the disconnect")
	marks.a = #shows
	join("probe_a", false)
	check(fakes.probe_a.armor.immortal == 1, "reconnect is back in stasis")
	return function() return meta("probe_a", "grug_classes:arriving") == "" end, 90
end)

stage("arrival after the reconnect", function()
	local s = shows_since(marks.a, "probe_a")
	local saw_window = false
	for _, row in ipairs(s) do
		if row.formname == CREATE_FORM then saw_window = true end
	end
	check(s[1] and s[1].formname == LOADING_FORM, "the reconnect resumed the arrival wait")
	check(not saw_window, "the reconnect did not show the window again")
	local start = grug_core.start_position("throng", "orc")
	check(start and vector.equals(fakes.probe_a.pos, start), "teleported to the orc start " ..
		core.pos_to_string(fakes.probe_a.pos))
	check(meta("probe_a", "grug_classes:class") == "mage", "still a mage")
	check(fakes.probe_a.armor.immortal == nil, "stasis released")
	check(hint("probe_a") == "", "hint removed")
	check((restores.probe_a or 0) >= 1, "inventory handed back to sfinv")
	check(not sfinv.inventory_suspended(by_name.probe_a), "sfinv no longer suspended")
	check(submit("probe_a", "", {grug_probe_unknown = "x"}) ~= "grug_classes",
		"inventory submissions no longer reach creation")
	return nil
end)

stage("the named dialog to an arrival", function()
	submit("probe_b", CREATE_FORM, {faction_accord = "The Accord"})
	submit("probe_b", CREATE_FORM, {race_elf = "Elf"})
	submit("probe_b", CREATE_FORM, {create_character = "Create character"})
	check(nothing_stored("probe_b"), "Create refused without a class")
	submit("probe_b", CREATE_FORM, {class_scout = "Scout"})
	check(submit("probe_b", CREATE_FORM, {create_character = "Create character"}) ==
		"grug_classes", "Create from the dialog")
	return function() return meta("probe_b", "grug_classes:arriving") == "" and
		meta("probe_b", "grug_classes:class") ~= "" end, 90
end)

stage("named flow result, then a draft disconnect", function()
	local start = grug_core.start_position("accord", "elf")
	check(start and vector.equals(fakes.probe_b.pos, start), "teleported to the elf start")
	check(meta("probe_b", "grug_classes:class") == "scout", "a scout")
	check(fakes.probe_b.armor.immortal == nil, "stasis released")
	check((restores.probe_b or 0) >= 1, "inventory handed back to sfinv")
	join("probe_c", true)
	submit("probe_c", "", {faction_accord = "The Accord"})
	submit("probe_c", "", {race_human = "Human"})
	submit("probe_c", "", {class_priest = "Priest"})
	leave("probe_c")
	join("probe_c", false)
	check(inv_has("probe_c", "Choose your faction"), "a disconnect before Create starts over")
	check(nothing_stored("probe_c"), "nothing stored for the abandoned draft")
	check(fakes.probe_c.armor.immortal == 1, "the new draft is in stasis")
	leave("probe_c")
	return nil
end)

core.register_on_mods_loaded(function()
	guard(grug_factions, "set_faction", function(name, id)
		return meta(name, "grug_factions:faction") == id end)
	guard(grug_classes, "set_race", function(name, id)
		return meta(name, "grug_classes:race") == id end)
	guard(grug_classes, "set_class", function(name, id)
		return meta(name, "grug_classes:class") == id end)
	guard(grug_visuals.creation_panel, "store", function(name)
		return meta(name, "grug_visuals:look") ~= "" end)
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
