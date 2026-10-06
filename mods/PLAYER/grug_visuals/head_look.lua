--
-- THE HEAD LOOK (Round 40 H1, character_visuals.md §5d): a player's head
-- follows the look up and down. The engine already turns the whole player
-- with the camera, so only the pitch is left: one relative rotation override
-- on the model's `Head` bone, on top of whatever clip plays (stand, walk, a
-- pose of poses.lua; their small head keys stay).
--
-- THE AXIS. The override is a rotation about the Head bone's own x axis, in
-- radians; a positive angle turns the face UP. `Head` hangs under `Body`,
-- which the model turns half round about y, so the bone's x is the
-- character's left and its -z is the face; the engine applies a relative
-- override in the bone's own frame after its animated rotation
-- (activeobject.h BoneOverride::getRotationEulerDeg, BoneSceneNode). The
-- engine's look pitch is the other way round (get_look_vertical: negative is
-- up). tools/r40_an2/portable_test.lua proves the sign on the model file.
--
-- ONLY ON A CHANGE. Every write makes the engine send all of the player's
-- bone overrides to every client that sees it (unit_sao.cpp sendOutdatedData),
-- so the pitch is quantized to 5° steps and written only when the step
-- changes: a steady look sends nothing.
--
-- NEVER IDENTITY (upstream-workarounds.md §3). A client snaps the first
-- override it gets for a bone (no interpolation) and erases one that has come
-- back to exactly identity (content_cao.cpp processMessage, activeobject.h
-- isIdentity), so the next one would snap again. A level head is therefore a
-- tiny tilt, written on join while nothing shows yet, and never removed.
--
-- THE PASS. No step visits every player (AGENTS.md "Performance"): each step
-- visits its share of a round robin, so every player is looked at about every
-- PERIOD seconds, which also caps the writes at about four per second.
--

local HEAD_BONE = "Head"
-- Degrees per quantization step and the clamp (down negative, up positive):
-- the angles the user accepted on the animation page (round40-plan.md §2.14).
-- At 50° down the chin's lower edge still stands in front of the chest, at
-- 60° up the back of the head reaches the back's plane.
local STEP = 5
local DOWN, UP = -50, 60
-- Each player is looked at about this often (seconds).
local PERIOD = 0.25
-- A new angle blends over this long; shorter than two server steps (0.18 s
-- at the default 0.09 s, the closest two visits of a player come), so a
-- blend has ended before the next write starts one.
local BLEND = 0.15
-- The level head: radians, far below anything visible, never identity.
local EPSILON = 0.001

grug_visuals.HEAD_LOOK = {step = STEP, down = DOWN, up = UP, period = PERIOD,
	blend = BLEND, epsilon = EPSILON}

-- player name -> row {player, deg (the step last written), dead,
-- hold_until (us)}; `order` holds the same rows for the round robin.
local rows = {}
local order = {}
local cursor = 0
local budget = 0

-- One table reused for every write (the engine reads it during the call).
local VEC = {x = EPSILON, y = 0, z = 0}
local ROTATION = {vec = VEC, interpolation = BLEND}
local OVERRIDE = {rotation = ROTATION}

local function write(row, deg, blend)
	row.deg = deg
	VEC.x = deg == 0 and EPSILON or math.rad(deg)
	ROTATION.interpolation = blend
	row.player:set_bone_override(HEAD_BONE, OVERRIDE)
end

-- The head's pitch for a look pitch (radians, the engine's sign): degrees up,
-- clamped and rounded to the nearest step.
function grug_visuals.head_step(look_vertical)
	local deg = -math.deg(look_vertical)
	if deg < DOWN then deg = DOWN elseif deg > UP then deg = UP end
	return math.floor(deg / STEP + 0.5) * STEP
end
local head_step = grug_visuals.head_step

-- No write while another bone of the player blends: every write re-sends
-- all of its overrides, which cuts that blend short (upstream-workarounds.md
-- §3, "Related"). Charge's `Body` lead blends in while the charge pose runs
-- and out under a hold (hold_head). The look waits; the next visit after
-- catches up.
local function held(row)
	if row.hold_until then
		if core.get_us_time() < row.hold_until then return true end
		row.hold_until = nil
	end
	return grug_visuals.current_pose(row.player) == "charge"
end

local function visit(row)
	-- A dead body lies with its head level; the look returns on respawn.
	local deg = row.dead and 0 or head_step(row.player:get_look_vertical())
	if deg ~= row.deg and not held(row) then
		write(row, deg, BLEND)
	end
end

-- Holds the head's writes for `seconds` (a longer running hold stays): for
-- a blend on another bone of the player (lane CH's lead blending back).
function grug_visuals.hold_head(player, seconds)
	local row = rows[player:get_player_name()]
	if not row then return end
	local until_us = core.get_us_time() + seconds * 1e6
	if not row.hold_until or until_us > row.hold_until then
		row.hold_until = until_us
	end
end

core.register_globalstep(function(dtime)
	local n = #order
	if n == 0 then
		budget = 0
		return
	end
	-- n players every PERIOD seconds; the remainder carries over, and a long
	-- step visits each player at most once.
	budget = budget + n * dtime / PERIOD
	local visits = math.floor(budget)
	if visits == 0 then return end
	if visits >= n then
		visits, budget = n, 0
	else
		budget = budget - visits
	end
	for _ = 1, visits do
		cursor = cursor % n + 1
		visit(order[cursor])
	end
end)

core.register_on_joinplayer(function(player)
	local row = {player = player, deg = 0, dead = player:get_hp() <= 0}
	rows[player:get_player_name()] = row
	order[#order + 1] = row
	-- The first override snaps on the clients: the level head, unseen.
	write(row, 0, 0)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	local row = rows[name]
	if not row then return end
	rows[name] = nil
	for i = 1, #order do
		if order[i] == row then
			order[i] = order[#order]
			order[#order] = nil
			break
		end
	end
end)

-- The pass levels a dead player's head (visit).
core.register_on_dieplayer(function(player)
	local row = rows[player:get_player_name()]
	if row then row.dead = true end
end)

core.register_on_respawnplayer(function(player)
	local row = rows[player:get_player_name()]
	if row then row.dead = nil end
end)
