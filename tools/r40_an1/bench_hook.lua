-- Round 40 lane AN1: the cost of player_api's animation pass with the pose
-- hooks (round40-plan.md §5: no pass handles every player in one step).
--
--   luajit tools/r40_an1/bench_hook.lua [repo]
--
-- Loads the REAL player_api/api.lua, the REAL Scout bow-draw hook (cut from
-- grug_abilities/scout.lua) and, when present, the REAL pose module
-- (grug_visuals/poses.lua) on a stand-in engine with 100 players, then times
-- player_api.globalstep: everyone standing, everyone walking, and ten of the
-- hundred in a held pose (when the pose module exists). The stand-in
-- ObjectRef methods only count calls, so the numbers are the Lua side of the
-- pass. A comparison, never a target: run it on the base and on the branch.

local ROOT = arg and arg[1] or "."
local PLAYERS, STEPS, ROUNDS = 100, 2000, 5

local function read(path)
	local handle = io.open(ROOT .. "/" .. path, "rb")
	if not handle then return nil end
	local text = handle:read("*a")
	handle:close()
	return text
end

local now_us = 0
local joins, leaves, steps = {}, {}, {}
local connected = {}
core = {
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_leaveplayer = function(fn) leaves[#leaves + 1] = fn end,
	register_on_dieplayer = function() end,
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	get_connected_players = function() return connected end,
	calculate_knockback = function() return 0 end,
	get_us_time = function() return now_us end,
	get_modpath = function(name)
		return ROOT .. (name == "player_api" and "/mods/BASE/" or "/mods/PLAYER/") .. name
	end,
	log = function() end,
}
minetest = core
table.copy = function(t)
	local out = {}
	for k, v in pairs(t) do out[k] = type(v) == "table" and table.copy(v) or v end
	return out
end

dofile(ROOT .. "/mods/BASE/player_api/init.lua")

grug_visuals = {}
grug_core = {register_on_settled_incoming_hit = function() end}
local poses_file = read("mods/PLAYER/grug_visuals/poses.lua")
if poses_file then
	-- The registration apply.lua makes, then the pose module on top of it.
	local reg = read("mods/PLAYER/grug_visuals/apply.lua"):match(
		"\n(grug_visuals%.PLAYER_MODEL = .-\nend)\n")
	assert(loadstring(reg, "=apply.lua registration"))()
	dofile(ROOT .. "/mods/PLAYER/grug_visuals/poses.lua")
end
local model = poses_file and grug_visuals.PLAYER_MODEL or "character.b3d"

local draws = {}
local scout_hook = read("mods/PLAYER/grug_abilities/scout.lua"):match(
	"\n(player_api%.register_control_animation_override%(function.-\nend%))\n")
assert(loadstring("local draws = ...\n" .. scout_hook, "=scout.lua hook"))(draws)

local sent = 0
local function new_player(name)
	local p = {name = name, controls = {}, hp = 20}
	function p:get_player_name() return self.name end
	function p:get_player_control() return self.controls end
	function p:get_hp() return self.hp end
	function p:set_animation() sent = sent + 1 end
	function p:play_animation() sent = sent + 1 end
	function p:set_properties() end
	function p:set_local_animation() end
	return p
end
for i = 1, PLAYERS do
	local p = new_player("p" .. i)
	connected[i] = p
	for _, fn in ipairs(joins) do fn(p) end
	player_api.set_model(p, model)
end

local function run(label, setup)
	setup()
	local best
	for _ = 1, ROUNDS do
		sent = 0
		local t0 = os.clock()
		for _ = 1, STEPS do
			now_us = now_us + 50000
			player_api.globalstep(0.05)
		end
		local dt = os.clock() - t0
		best = best and math.min(best, dt) or dt
	end
	print(string.format("%-34s %7.1f ns per player-step  (%d animation sends in the last round)",
		label, best / (STEPS * PLAYERS) * 1e9, sent))
end

print(string.format("bench_hook: %d players, %d steps, best of %d; pose module %s",
	PLAYERS, STEPS, ROUNDS, poses_file and "loaded" or "absent"))
run("everyone standing", function()
	for _, p in ipairs(connected) do p.controls = {} end
end)
run("everyone walking", function()
	for _, p in ipairs(connected) do p.controls = {up = true} end
end)
run("ten Scouts drawing, rest walking", function()
	for i = 1, 10 do draws["p" .. i] = {} end
end)
for i = 1, 10 do draws["p" .. i] = nil end
if poses_file then
	run("ten in a held pose, rest walking", function()
		for i = 1, 10 do grug_visuals.start_pose(connected[i], "charge") end
	end)
end
