-- Round 40 lane AN2: the Lua cost of the head-look pass (round40-plan.md §5:
-- no pass handles every player in one step).
--
--   luajit tools/r40_an2/bench_pass.lua [repo]
--
-- Loads the REAL grug_visuals/head_look.lua on a stand-in engine with 100
-- players and times its globalstep at the default server step (0.09 s):
-- everyone looking steadily (no writes) and everyone looking around without
-- pause (every visit writes). The stand-in ObjectRef methods only count
-- calls, so the numbers are the Lua side of the pass; the engine's own
-- get_look_vertical and set_bone_override calls come on top. Before this
-- lane there was no pass at all. A comparison, never a target.

local ROOT = arg and arg[1] or "."
local PLAYERS, DTIME, STEPS, ROUNDS = 100, 0.09, 20000, 5

local steps, joins = {}, {}
core = {
	register_globalstep = function(fn) steps[#steps + 1] = fn end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	register_on_leaveplayer = function() end,
	register_on_dieplayer = function() end,
	register_on_respawnplayer = function() end,
}
grug_visuals = {}
dofile(ROOT .. "/mods/PLAYER/grug_visuals/head_look.lua")
local pass = steps[1]

local looks, written = 0, 0
local players = {}
for i = 1, PLAYERS do
	local p = {name = "p" .. i, look = 0}
	function p:get_player_name() return self.name end
	function p:get_hp() return 20 end
	function p:get_look_vertical()
		looks = looks + 1
		return self.look
	end
	function p:set_bone_override() written = written + 1 end
	players[i] = p
	for _, fn in ipairs(joins) do fn(p) end
end

local function run(label, moving)
	local best, total_looks, total_writes = math.huge, 0, 0
	for _ = 1, ROUNDS do
		looks, written = 0, 0
		local t = 0
		local start = os.clock()
		for s = 1, STEPS do
			if moving then
				-- Everyone's look moves by a step's worth every server step.
				t = t + 1
				local v = math.rad(((t % 20) - 10) * 5)
				for i = 1, PLAYERS do players[i].look = v end
			end
			pass(DTIME)
		end
		local elapsed = os.clock() - start
		if moving then
			-- Take out the cost of moving the stand-ins' looks.
			local t0 = os.clock()
			for _ = 1, STEPS do
				t = t + 1
				local v = math.rad(((t % 20) - 10) * 5)
				for i = 1, PLAYERS do players[i].look = v end
			end
			elapsed = elapsed - (os.clock() - t0)
		end
		best = math.min(best, elapsed)
		total_looks, total_writes = looks, written
	end
	local per_step = best / STEPS * 1e6
	local seconds = STEPS * DTIME
	print(string.format("%-28s %6.2f us/step  %7.1f us/s  visits/s %6.1f  writes/s %6.1f",
		label, per_step, per_step / DTIME, total_looks / seconds, total_writes / seconds))
end

print(string.format("head-look pass, %d players, dtime %.2f s, best of %d x %d steps",
	PLAYERS, DTIME, ROUNDS, STEPS))
run("steady look (no writes)", false)
run("looking around (all write)", true)
