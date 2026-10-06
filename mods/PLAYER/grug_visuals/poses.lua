--
-- THE POSES (Round 40, character_visuals.md §5c): when the player model plays
-- the pose clips apply.lua registers (POSE_CLIPS).
--
-- A pose is one row per player, written by the event that fires it (a cast, a
-- landed Mighty Blow, a hit taken, the Charge dash). player_api's animation
-- pass already visits every player each step and asks its override hooks
-- (player_api GRUG PATCH); the hook here reads one table slot, so a player
-- without a pose costs a lookup and nothing runs on its own clock. The hook
-- answers the walking twin while the player moves, and ends an expired row.
--
-- Precedence: the newest pose replaces the running one; a flinch never
-- replaces anything (another pose, the Scout's drawn bow, a seat).
--

local CLIPS = grug_visuals.POSE_CLIPS
-- player_api's frame rate for the player model; sneaking halves it.
local FPS = player_api.registered_models[grug_visuals.PLAYER_MODEL].animation_speed

-- How long a held pose stays after the instant action that fired it, in
-- seconds. Casts are instant, so the arms hold just long enough to read: the
-- 0.12 s blend in, a moment held, the blend out. Hold Ground holds its guard
-- for a moment too, not for the whole 8 s buff: the Warrior keeps fighting
-- under it, and a held guard would hide every swing (the pose hook wins over
-- the mine pose) and the Mighty Blow cut.
grug_visuals.POSE_HOLD = {cast1 = 0.6, cast2 = 0.6, block = 1.0}
-- At most one flinch per this many seconds: in a brawl every hit would
-- otherwise restart it and the character would only twitch.
grug_visuals.FLINCH_GAP = 1.5

-- The animations a flinch may interrupt: player_api's own, no pose.
local FLINCH_OVER = {stand = true, walk = true, mine = true, walk_mine = true}

-- player name -> {pose, walk (the twin's name), once, loop, started (us),
-- ends (us, nil = until stopped), fresh (restart on the next answer)}
local active = {}
local last_flinch = {}

local function moving(controls)
	return controls.up or controls.down or controls.left or controls.right
end

player_api.register_control_animation_override(function(player, controls)
	local name = player:get_player_name()
	local row = active[name]
	if not row then return end
	local walking = moving(controls)
	local now = core.get_us_time()
	if row.once then
		-- A one-shot ends when its clip has played: the twin's length at the
		-- speed player_api plays it now.
		local clip = walking and row.clip.walk or row.clip.stand
		local fps = controls.sneak and FPS / 2 or FPS
		if (now - row.started) / 1e6 * fps >= clip.y - clip.x then
			active[name] = nil
			return
		end
	elseif row.ends and now >= row.ends then
		active[name] = nil
		return
	end
	local fresh = row.fresh
	row.fresh = nil
	return walking and row.walk or row.pose, row.loop, fresh
end)

local function start(player, pose, ends)
	local clip = assert(CLIPS[pose], "unknown pose")
	local name = player:get_player_name()
	local now = core.get_us_time()
	local row = active[name]
	if row and row.pose == pose and not clip.once then
		-- The same held pose again (a second cast): it holds on, no restart;
		-- one held until stopped stays so.
		if ends and row.ends then
			row.ends = math.max(ends, row.ends)
		else
			row.ends = nil
		end
		return
	end
	local loop
	if clip.once then loop = false end
	active[name] = {pose = pose, walk = pose .. "_walk", clip = clip,
		once = clip.once, loop = loop, started = now, ends = ends,
		fresh = clip.once}
end

-- Plays `pose` on `player` for an instant action: a held pose for `hold`
-- seconds (default POSE_HOLD), a one-shot once from its start (a repeat
-- restarts it).
function grug_visuals.play_pose(player, pose, hold)
	hold = hold or grug_visuals.POSE_HOLD[pose] or 0
	start(player, pose, core.get_us_time() + hold * 1e6)
end

-- Holds `pose` until stop_pose: the seam for an action with its own end (lane
-- CH's Charge dash: start_pose(player, "charge") and stop_pose on arrival,
-- miss or cancel).
function grug_visuals.start_pose(player, pose)
	start(player, pose, nil)
end

-- Ends `pose` if it is the one running (a later pose that replaced it stays).
function grug_visuals.stop_pose(player, pose)
	local name = player:get_player_name()
	local row = active[name]
	if row and row.pose == pose then
		active[name] = nil
	end
end

-- The pose running on `player`, or nil.
function grug_visuals.current_pose(player)
	local row = active[player:get_player_name()]
	return row and row.pose
end

-- A light flinch on a hit taken: rate-limited, and only over player_api's own
-- animations, never over another pose, the drawn bow, a seat or death.
function grug_visuals.flinch(player)
	local name = player:get_player_name()
	if active[name] or player_api.player_attached[name] then return end
	local now = core.get_us_time()
	if last_flinch[name] and now - last_flinch[name] < grug_visuals.FLINCH_GAP * 1e6 then
		return
	end
	if not FLINCH_OVER[player_api.get_animation(player).animation] then return end
	last_flinch[name] = now
	start(player, "flinch", nil)
end

-- Non-lethal hits only (a lethal one lays the body down).
grug_core.register_on_settled_incoming_hit(function(player)
	grug_visuals.flinch(player)
end)

core.register_on_dieplayer(function(player)
	active[player:get_player_name()] = nil
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	active[name] = nil
	last_flinch[name] = nil
end)
