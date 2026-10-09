-- Station sounds (Round 45 playtest fix PT8, the user, 2026-10-09). A station
-- with a sound plays it only when a player starts a job there: at the
-- station the start found within 4 nodes (jobs.lua's station_nearby), for
-- recipe, enchant and upgrade jobs alike. The forge's idle hammer loop
-- (grug_ambience) is gone; furnaces keep their fire loop while they burn.
--
-- Queue rule: while the sound plays at a station and another job starts
-- there, it is queued once more, never more often (four starts within one
-- sound: the first plays, the second queues one more, the third and fourth
-- add nothing). Per station node: an end time and a queued start time, one
-- core.after for a queued sound; nothing runs per step.
--
-- The sound is the profession's craft cue (grug_sounds), which before played
-- at the job's end; a recipe made at such a station has no end cue now
-- (state.lua's craft_sound). `seconds` is the shipped file's length.

-- station kind -> {event, seconds}. Stations without a row are silent: the
-- tanning rack, tailor bench, carving bench and jeweller's bench have no
-- sound of their own; the furnace and the dual furnace stay as they are.
local STATION_SOUNDS = {
	forge = {event = "craft_smithy", seconds = 1.5},
	brewing_stand = {event = "craft_alchemy", seconds = 1.8},
}
grug_jobs.STATION_SOUNDS = STATION_SOUNDS

local function seconds()
	return core.get_us_time() / 1000000
end

-- node position hash -> {ends = seconds, pending = seconds | nil}: `ends`
-- is when the last sound played or queued there ends, `pending` the start of
-- a queued one. Moved forward when a sound is queued, so a start in the step
-- before the queued sound's core.after runs cannot play on top of it. An
-- expired entry goes when a start finds it.
local playing = {}

-- Plays the sound of the station at `pos` (a position station_nearby
-- returned) under the queue rule. Returns "played", "queued", or false
-- (no station sound, nothing played or queued).
function grug_jobs.play_station_sound(pos)
	if not pos then return false end
	local node = core.get_node_or_nil(pos)
	local def = node and core.registered_nodes[node.name]
	local sound = def and STATION_SOUNDS[def._grug_station or ""]
	if not sound then return false end
	local key = core.hash_node_position(pos)
	local now = seconds()
	local slot = playing[key]
	if slot and now >= slot.ends then
		playing[key], slot = nil, nil
	end
	if not slot then
		if not grug_sounds.play(sound.event, pos) then return false end
		playing[key] = {ends = now + sound.seconds}
		return "played"
	end
	-- One queued sound at most: while it waits, a start adds nothing; once
	-- it plays, a start queues the next one.
	if slot.pending and now < slot.pending then return false end
	local at = slot.ends
	slot.pending, slot.ends = at, at + sound.seconds
	core.after(at - now, function() grug_sounds.play(sound.event, pos) end)
	return "queued"
end

grug_jobs.register_on_job_start(function(_, _, station_pos)
	grug_jobs.play_station_sound(station_pos)
end)
