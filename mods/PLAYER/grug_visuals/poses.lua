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
-- replaces anything (another pose, a seat).
--
-- The end of a pose answers a `<base>_resume` animation for one step
-- (apply.lua): the player's own client ignores the plain base animation and
-- would keep showing the pose.
--
-- The Round 78 emotes (Wave, Dance; play_emote below) ride the same row.
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
-- The frame a one-shot starts at. Mighty Blow's damage lands in the same
-- server step that fires the pose, so the cut starts at the top of the
-- swing (frame 4); the blend raises the arm.
grug_visuals.POSE_START = {swing = 4}
-- At most one flinch per this many seconds: in a brawl every hit would
-- otherwise restart it and the character would only twitch.
grug_visuals.FLINCH_GAP = 1.5

-- The animations a flinch may interrupt: player_api's own, no pose.
local FLINCH_OVER = {stand = true, walk = true, mine = true, walk_mine = true,
	stand_resume = true, walk_resume = true, mine_resume = true,
	walk_mine_resume = true}

-- player name -> {pose, walk (the twin's name), once, loop, started (us),
-- ends (us, nil = until stopped), fresh (restart on the next answer: true,
-- or the frame to start at)}, or RESUME for the step after stop_pose.
local active = {}
local last_flinch = {}
local RESUME = {}

local function moving(controls)
	return controls.up or controls.down or controls.left or controls.right
end

-- The animation that hands a pose back to player_api's own choice, as
-- player_api would pick it.
function grug_visuals.resume_animation(controls)
	local acting = controls.LMB or controls.RMB
	if moving(controls) then
		return acting and "walk_mine_resume" or "walk_resume"
	end
	return acting and "mine_resume" or "stand_resume"
end
local resume = grug_visuals.resume_animation

player_api.register_control_animation_override(function(player, controls)
	local name = player:get_player_name()
	local row = active[name]
	if not row then return end
	if row == RESUME then
		active[name] = nil
		return resume(controls)
	end
	local walking = moving(controls)
	-- An emote ends on a move, a jump or a click (an attack, a cast), and
	-- when something else took the model over meanwhile (a mount: this hook
	-- does not run while the player is attached).
	if row.emote then
		if walking or controls.jump or controls.LMB or controls.RMB or (row.shown
				and player_api.get_animation(player).animation ~= row.pose) then
			active[name] = nil
			return resume(controls)
		end
		row.shown = true
	end
	local now = core.get_us_time()
	if row.once then
		-- A one-shot ends when its clip has played: the twin's length at the
		-- speed player_api plays it now, from the frame it started at.
		local clip = walking and row.clip.walk or row.clip.stand
		local fps = controls.sneak and FPS / 2 or FPS
		if row.first + (now - row.started) / 1e6 * fps >= clip.y - clip.x then
			active[name] = nil
			return resume(controls)
		end
	elseif row.ends and now >= row.ends then
		active[name] = nil
		return resume(controls)
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
	if row == RESUME then row = nil end
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
	local loop, fresh, first = nil, nil, 0
	if clip.once then
		loop = false
		first = grug_visuals.POSE_START[pose] or 0
		fresh = first > 0 and first or true
	end
	active[name] = {pose = pose, walk = pose .. "_walk", clip = clip,
		once = clip.once, loop = loop, started = now, ends = ends,
		fresh = fresh, first = first}
end

-- Plays `pose` on `player` for an instant action: a held pose for `hold`
-- seconds (default POSE_HOLD), a one-shot once from its start (a repeat
-- restarts it).
function grug_visuals.play_pose(player, pose, hold)
	hold = hold or grug_visuals.POSE_HOLD[pose] or 0
	start(player, pose, core.get_us_time() + hold * 1e6)
end

-- Holds `pose` until stop_pose: the seam for an action with its own end
-- (Charge's dash, grug_abilities/charge.lua: start_pose(player, "charge")
-- and stop_pose at its stop or cancel).
function grug_visuals.start_pose(player, pose)
	start(player, pose, nil)
end

-- Ends `pose` if it is the one running (a later pose that replaced it stays).
function grug_visuals.stop_pose(player, pose)
	local name = player:get_player_name()
	local row = active[name]
	if row and row.pose == pose then
		active[name] = RESUME
	end
end

-- The pose running on `player`, or nil.
function grug_visuals.current_pose(player)
	local row = active[player:get_player_name()]
	return row and row.pose
end

--
-- THE EMOTES (Round 78 ruling 10, round78-plan.md §3.1): Wave and Dance from
-- the quickbar (grug_quickbar). One click plays the emote once, Dance as
-- three rounds of its loop; moving, jumping, a click (an attack or a cast;
-- a skill's pose replaces it anyway) and mounting end it, and the player's
-- own client gets the `<base>_resume` way back like after a pose. The same
-- emote again while it plays is ignored, another one replaces it, and at
-- most one emote starts per EMOTE_GAP, so a click flood sends no flood of
-- animations.
--
-- A rider waves seated (`wave_sit`: the upper body; the legs stay on the
-- saddle) and has no Dance. The mount re-asserts `sit` through player_api
-- every step it differs (grug_mounts/entity.lua), so the seated clip goes
-- to the object directly while player_api keeps `sit`, and `sit` is played
-- again when the clip is over (a timer; nothing runs per step). Any other
-- pose change (a dismount) simply replaces it.
--
grug_visuals.EMOTE_GAP = 1.0
-- A looping emote's length in seconds: three rounds of the 40-frame Dance.
grug_visuals.EMOTE_PLAY = {dance = 4.0}
local EMOTES = grug_visuals.EMOTE_CLIPS
-- player_api's blend for every switch (player_api/api.lua GRUG PATCH).
local BLEND = 0.12
local last_emote = {}
-- player name -> {emote, ends (us)} of the seated emote playing.
local seated = {}

local function play_seated(player, name, emote, range, now)
	local running = seated[name]
	if running and running.emote == emote and now < running.ends then
		return false, "playing"
	end
	local seconds = (range.y - range.x) / FPS
	local row = {emote = emote, ends = now + seconds * 1e6}
	seated[name] = row
	-- A standing emote cut by the mount is over.
	if active[name] and active[name].emote then active[name] = nil end
	player:set_animation(range, FPS, BLEND, false)
	core.after(seconds, function()
		if seated[name] ~= row then return end
		seated[name] = nil
		local current = core.get_player_by_name(name)
		if current and player_api.player_attached[name]
				and player_api.get_animation(current).animation == "sit" then
			player_api.set_animation(current, "sit", FPS, true, true)
		end
	end)
	return true
end

-- Plays `emote` (a key of EMOTE_CLIPS) on `player`. Returns true, or false
-- and why: "unknown", "dead", "busy" (within EMOTE_GAP of the last start),
-- "playing" (the same emote runs), "seated" (no seated clip, or attached to
-- something that is no mount).
function grug_visuals.play_emote(player, emote)
	local clip = EMOTES[emote]
	if not clip then return false, "unknown" end
	if player:get_hp() <= 0 then return false, "dead" end
	local name = player:get_player_name()
	local now = core.get_us_time()
	if last_emote[name] and now - last_emote[name] < grug_visuals.EMOTE_GAP * 1e6 then
		return false, "busy"
	end
	if player_api.player_attached[name] then
		if not clip.sit or player_api.get_animation(player).animation ~= "sit" then
			return false, "seated"
		end
		local ok, why = play_seated(player, name, emote, clip.sit, now)
		if ok then last_emote[name] = now end
		return ok, why
	end
	local row = active[name]
	if row and row ~= RESUME and row.emote and row.pose == emote then
		return false, "playing"
	end
	last_emote[name] = now
	local loop, ends = nil, nil
	if clip.once then
		loop = false
	else
		ends = now + (grug_visuals.EMOTE_PLAY[emote] or 0) * 1e6
	end
	active[name] = {pose = emote, emote = true, clip = clip, once = clip.once,
		loop = loop, started = now, ends = ends, first = 0, fresh = true}
	return true
end

-- A light flinch on a hit taken: rate-limited, and only over player_api's own
-- animations, never over another pose, a seat or death.
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
	local name = player:get_player_name()
	active[name] = nil
	seated[name] = nil
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	active[name] = nil
	last_flinch[name] = nil
	last_emote[name] = nil
	seated[name] = nil
end)
