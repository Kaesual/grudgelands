local root = assert(arg[1], "repository root required")

local callbacks, shown, persistent, chats = {}, {}, {}, {}

local function meta_for(name)
	persistent[name] = persistent[name] or {}
	local values = persistent[name]
	return {
		get_int = function(_, key) return tonumber(values[key]) or 0 end,
		set_int = function(_, key, value) values[key] = value end,
		get_string = function(_, key) return tostring(values[key] or "") end,
		set_string = function(_, key, value) values[key] = value end,
	}
end

local function player(name)
	return {
		is_player = function() return true end,
		get_player_name = function() return name end,
		get_meta = function() return meta_for(name) end,
		get_pos = function() return {x = 0, y = 0, z = 0} end,
	}
end

core = {
	formspec_escape = function(value) return tostring(value) end,
	show_formspec = function(name, formname, formspec)
		shown[name] = {formname = formname, formspec = formspec}
	end,
	register_on_player_receive_fields = function(callback) callbacks.receive = callback end,
	register_on_leaveplayer = function(callback) callbacks.leave = callback end,
	chat_send_player = function(name, text) chats[#chats + 1] = name .. "|" .. text end,
	log = function() end,
}

grug_xp = {get_level = function() return 25 end}
grug_inventory = {refresh = function() end}
grug_mobs = {register_start_socket_role = function() end}
grug_jobs = {PROFESSIONS = {
	cooking = {name = "Cooking", class = "secondary"},
	weaponsmith = {name = "Weaponsmith", class = "primary"},
}}

dofile(root .. "/mods/PLAYER/grug_jobs/state.lua")
dofile(root .. "/mods/PLAYER/grug_jobs/trainers.lua")

local function open(actor, profession)
	assert(grug_jobs.open_trainer(actor, profession, {x = 0, y = 0, z = 0}))
	return shown[actor:get_player_name()].formspec
end

local function submit(actor, field)
	assert(callbacks.receive(actor, "grug_jobs:trainer", {[field] = true}))
	return shown[actor:get_player_name()].formspec
end

local cook_a, cook_b = player("cook_a"), player("cook_b")
assert(open(cook_a, "cooking"):find("Learn Cooking", 1, true))
local learned = submit(cook_a, "grug_jobs_learn")
assert(learned:find("Learned Cooking", 1, true), "success message missing")
assert(learned:find("Inventory > Crafting", 1, true), "book guidance missing")
assert(grug_jobs.has(cook_a, "cooking") and not grug_jobs.has(cook_b, "cooking"),
	"learning leaked between players")
local revisit = open(cook_a, "cooking")
assert(revisit:find("Known: Cooking", 1, true), "known revisit status missing")
assert(not revisit:find("Learned Cooking", 1, true), "revisit pretends to learn")
assert(not revisit:find("grug_jobs_unlearn", 1, true), "Cooking offers Unlearn")
submit(cook_a, "grug_jobs_unlearn")
submit(cook_a, "grug_jobs_confirm")
assert(grug_jobs.has(cook_a, "cooking"), "forged Cooking unlearn succeeded")

local smith_a, smith_b = player("smith_a"), player("smith_b")
open(smith_a, "weaponsmith")
submit(smith_a, "grug_jobs_learn")
assert(grug_jobs.has(smith_a, "weaponsmith") and
	 not grug_jobs.has(smith_b, "weaponsmith"), "primary learning leaked")
submit(smith_a, "grug_jobs_confirm")
assert(grug_jobs.has(smith_a, "weaponsmith"), "forged confirmation bypassed prompt")
local confirmation = submit(smith_a, "grug_jobs_unlearn")
assert(confirmation:find("Only this profession's progression", 1, true),
	"progression-loss confirmation missing")
local cancelled = submit(smith_a, "grug_jobs_cancel")
assert(cancelled:find("progression are unchanged", 1, true) and
	grug_jobs.has(smith_a, "weaponsmith"), "cancel changed profession")
submit(smith_a, "grug_jobs_unlearn")
submit(smith_a, "grug_jobs_confirm")
assert(not grug_jobs.has(smith_a, "weaponsmith"), "confirmed primary remained")
assert(grug_jobs.has(cook_a, "cooking"), "primary unlearn changed Cooking")

local ui_core = core
grug_inventory = {}
sfinv = {make_formspec = function() end, get_nav_fs = function() return "" end}
core = {
	formspec_escape = ui_core.formspec_escape,
	register_on_mods_loaded = function() end,
	registered_items = {},
}
dofile(root .. "/mods/PLAYER/grug_inventory/ui.lua")
local selected = grug_inventory.selected_button_style("pick", true)
local plain = grug_inventory.selected_button_style("pick", false)
assert(selected:find("border=true", 1, true) and selected:find("bgcolor=#", 1, true),
	"selected style lacks border/tint")
assert(plain:find("border=false", 1, true), "plain style lacks non-colour distinction")

local quest_ui = assert(io.open(root .. "/mods/PLAYER/grug_quests/ui.lua", "rb")):read("*a")
local quest_hud = assert(io.open(root .. "/mods/PLAYER/grug_quests/hud.lua", "rb")):read("*a")
assert(quest_ui:find('description:match("^[^\\n]+")', 1, true),
	"quest page does not shorten item descriptions")
assert(quest_hud:find('description:match("^[^\\n]+")', 1, true),
	"quest HUD does not shorten item descriptions")
local quest_state = assert(io.open(root .. "/mods/PLAYER/grug_quests/state.lua", "rb")):read("*a")
assert(quest_state:find("stack:get_name() == objective.item", 1, true),
	"turn-in no longer matches item identity independently of wear")

local equipment = assert(io.open(root ..
	"/mods/PLAYER/grug_inventory/equipment.lua", "rb")):read("*a")
local hint_start = assert(equipment:find("local raw_weapon_controls", 1, true))
local hint_source = equipment:sub(hint_start)
assert(hint_source:find("get_player_control", 1, true) and
	not hint_source:find("override_item", 1, true) and
	not hint_source:find("on_use", 1, true),
	"raw-weapon hint no longer observes input without changing item callbacks")

io.write("r18_ux_v1|trainer=success+known+confirm|cooking=protected|players=isolated|style=tint+border|quest=concise+wear_identity|raw_weapon=observed_only\n")
