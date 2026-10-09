-- Station sounds (Round 45 playtest fix PT8, the user, 2026-10-09). A station
-- with a sound plays it only when a player starts a job there: at the
-- station the start found within 4 nodes (jobs.lua's station_nearby), for
-- recipe, enchant and upgrade jobs alike. The forge's idle hammer loop
-- (grug_ambience) is gone; furnaces keep their fire loop while they burn.
--
-- Queue rule: while the sound plays at a station and another job starts
-- there, it is queued once more, never more often (four starts within one
-- sound: the first plays, the second queues one more, the third and fourth
-- add nothing). Per station node: an end time and a queued flag, one
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

-- node position hash -> {ends = seconds, queued = bool}; one entry per
-- station node that sounded since the server started.
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
	if not slot or now >= slot.ends then
		if not grug_sounds.play(sound.event, pos) then return false end
		playing[key] = {ends = now + sound.seconds, queued = false}
		return "played"
	end
	if slot.queued then return false end
	slot.queued = true
	core.after(slot.ends - now, function()
		slot.queued = false
		slot.ends = seconds() + sound.seconds
		grug_sounds.play(sound.event, pos)
	end)
	return "queued"
end

grug_jobs.register_on_job_start(function(_, _, station_pos)
	grug_jobs.play_station_sound(station_pos)
end)
