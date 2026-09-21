local root = assert(arg[1], "repository root required")

local callbacks = {}
local shown = {}
local persistent = {}
local logs = {}

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
	register_on_player_receive_fields = function(callback)
		callbacks.receive_fields = callback
	end,
	register_on_leaveplayer = function(callback) callbacks.leave = callback end,
	chat_send_player = function() end,
	log = function(level, message) logs[#logs + 1] = level .. "|" .. message end,
	global_exists = function(name) return rawget(_G, name) ~= nil end,
}

grug_xp = {get_level = function() return 1 end}
grug_inventory = {refresh = function() end}
grug_mobs = {register_start_socket_role = function() end}
grug_jobs = {
	PROFESSIONS = {
		cooking = {name = "Cooking", class = "secondary"},
		weaponsmith = {name = "Weaponsmith", class = "primary"},
	},
}

dofile(root .. "/mods/PLAYER/grug_jobs/state.lua")
dofile(root .. "/mods/PLAYER/grug_jobs/trainers.lua")

local function open(actor, profession)
	assert(grug_jobs.open_trainer(actor, profession, {x = 0, y = 0, z = 0}))
	return shown[actor:get_player_name()].formspec
end

local function submit(actor, field)
	assert(callbacks.receive_fields(actor, "grug_jobs:trainer", {[field] = true}))
	return shown[actor:get_player_name()].formspec
end

local function run_pair(first_name, second_name, profession)
	local first, second = player(first_name), player(second_name)
	assert(open(first, profession):find("Learn ", 1, true))
	assert(open(second, profession):find("Learn ", 1, true))
	local first_form = submit(first, "grug_jobs_learn")
	assert(first_form:find("You already know", 1, true))
	assert(grug_jobs.has(first, profession))
	assert(not grug_jobs.has(second, profession))
	local second_before = open(second, profession)
	assert(not second_before:find("You already know", 1, true))
	assert(not second_before:find("grug_jobs_unlearn", 1, true))
	local second_form = submit(second, "grug_jobs_learn")
	assert(second_form:find("You already know", 1, true))
	assert(grug_jobs.has(first, profession) and grug_jobs.has(second, profession))
	callbacks.leave(first)
	local reconnected = player(first_name)
	assert(open(reconnected, profession):find("You already know", 1, true))
	assert(grug_jobs.has(reconnected, profession))
	return first, second
end

local a, b = run_pair("cook_a", "cook_b", "cooking")
local d, c = run_pair("smith_b", "smith_a", "weaponsmith")
assert(grug_jobs.has(a, "cooking") and grug_jobs.has(b, "cooking"))
assert(grug_jobs.has(c, "weaponsmith") and grug_jobs.has(d, "weaponsmith"))
open(a, "cooking")
submit(a, "grug_jobs_unlearn")
submit(a, "grug_jobs_confirm")
assert(not grug_jobs.has(a, "cooking") and grug_jobs.has(b, "cooking"))
local cook_a, cook_b = false, false
local cook_unlearn = false
for _, line in ipairs(logs) do
	if line:find("trainer_learn player=cook_a profession=cooking known_before=false known_after=true", 1, true) then
		cook_a = true
	elseif line:find("trainer_learn player=cook_b profession=cooking known_before=false known_after=true", 1, true) then
		cook_b = true
	elseif line:find("trainer_unlearn player=cook_a profession=cooking known_before=true known_after=false", 1, true) then
		cook_unlearn = true
	end
end
assert(cook_a and cook_b and cook_unlearn,
	"trainer diagnostics did not preserve player identity")

io.write("r14_profession_isolation_v1|cooking=isolated|primary=isolated|reconnect=persistent\n")
