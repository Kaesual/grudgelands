-- The furnace's fire and arrow (0.49.1 ruling 7, fix-0.49.1-plan.md §4
-- ANIM), shared by the plain furnace form (default/furnace.lua) and the
-- profession workspaces' furnace and dual furnace (grug_jobs/workspaces.lua).
-- It lives here because both reach grug_inventory (their station view), and
-- the plain furnace's form only shows without grug_jobs.
--
-- While a fuel burns, the fire is an animated_image[] over that fuel's burn
-- time; while an item cooks, the arrow is one over that item's cooking time,
-- like the crafting bar (grug_jobs.progress_bar). Each starts at its own
-- elapsed fraction (frame_start) at every build, so the two stay
-- independent, and the client moves them on its own: a form is re-sent only
-- at a change of state (`changed` below), not on every timer tick.
--
-- The strips (tools/r491_anim/gen_furnace_strips.py): FILL frames, then as
-- many buffer frames holding the end picture (the fire's lowest flame,
-- never empty; the arrow full). The server notices an end only at its next
-- one-second tick, so the animation holds its end until that re-send. The
-- buffer lasts as long as the duration, and at least MIN_BUFFER: a shorter
-- duration runs its frames over MIN_BUFFER (it then ends a little short of
-- its end picture; the re-send restarts it).
local M = {}

local FIRE = {texture = "grug_inventory_furnace_fire.png", fill = 15, name = "grug_furnace_fire"}
local ARROW = {texture = "grug_inventory_furnace_arrow.png", fill = 22, name = "grug_furnace_arrow"}
FIRE.frames, ARROW.frames = 2 * FIRE.fill, 2 * ARROW.fill
M.FIRE, M.ARROW = FIRE, ARROW
-- Seconds: the one-second tick plus a second of lag.
M.MIN_BUFFER = 2
local FIRE_OFF = "default_furnace_fire_bg.png"

-- The fill frame (0-based) for `elapsed` of `total` seconds, and the
-- milliseconds per frame.
local function timing(strip, elapsed, total)
	local span = math.max(total, M.MIN_BUFFER)
	local frame = math.floor(math.max(0, elapsed) / span * strip.fill)
	return math.min(strip.fill - 1, frame),
		math.max(1, math.floor(span * 1000 / strip.fill + 0.5))
end

local function element(strip, x, y, w, h, frame, duration)
	if duration then
		return ("animated_image[%.3f,%.3f;%.3f,%.3f;%s;%s;%d;%d;%d]"):format(x, y, w, h,
			strip.name, strip.texture, strip.frames, duration, frame + 1)
	end
	return ("image[%.3f,%.3f;%.3f,%.3f;%s^[verticalframe:%d:%d]"):format(x, y, w, h,
		strip.texture, strip.frames, frame)
end

-- The fire at (x, y), w x h: `left` of `total` seconds of the current fuel
-- remain; `burning` false holds it still (a blocked plain furnace burns no
-- fuel). A `total` of 0: no fire. A burnt-out fuel the furnace has not
-- replaced yet (the plain furnace lights the next one a tick later) keeps
-- its lowest flame.
function M.fire(x, y, w, h, left, total, burning)
	total = tonumber(total) or 0
	if total <= 0 then
		return ("image[%.3f,%.3f;%.3f,%.3f;%s]"):format(x, y, w, h, FIRE_OFF)
	end
	left = math.max(0, math.min(total, tonumber(left) or 0))
	local frame, duration = timing(FIRE, total - left, total)
	return element(FIRE, x, y, w, h, frame, burning and duration or nil)
end

-- The arrow at (x, y), w x h: `done` of `total` seconds of the current item
-- are cooked; `cooking` false holds it still (no fuel, the output full), at
-- the end picture once the item is done.
function M.arrow(x, y, w, h, done, total, cooking)
	total = tonumber(total) or 0
	done = math.max(0, tonumber(done) or 0)
	if total <= 0 then return element(ARROW, x, y, w, h, 0) end
	if not cooking then
		return element(ARROW, x, y, w, h, math.min(ARROW.fill,
			math.floor(done / total * ARROW.fill)))
	end
	local frame, duration = timing(ARROW, done, total)
	return element(ARROW, x, y, w, h, frame, duration)
end

-- Whether `formspec`, built now from `left` seconds of fuel and `done`
-- seconds of cooking, must be re-sent to the viewer whose session table is
-- `context`; it is remembered there as the last build. The comparison
-- ignores the frame starts, which move on every build. A new fuel (more
-- fuel left than at the last build) or a new item (less cooked) is a
-- change too, even when it leaves the form's text as it was.
function M.changed(context, formspec, left, done)
	local key = formspec:gsub("(animated_image%[[^%]]*;)%d+%]", "%1]")
	left, done = tonumber(left) or 0, tonumber(done) or 0
	local last = context.grug_furnace_last
	context.grug_furnace_last = {key = key, left = left, done = done}
	return not last or last.key ~= key or left > last.left + 0.01 or
		done < last.done - 0.01
end

return M
