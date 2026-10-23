-- The Crafting tab's queue view (Round 57 lane CRAFT; round57-plan.md
-- rulings 1-4; wireframe "Variant C open"), a box of ui.lua's that opens
-- from the job strip's "View Queue [N]" (open_craft_box) and goes back with
-- "◀ Back to recipe" (close_craft_box) or any recipe row, area tab or box
-- button. It lists the waiting jobs in queue order, each with its icon, its
-- line (grug_jobs.JOB_TEXTS, as below the bar), its area and ✕, which
-- cancels it and returns its ingredients and target item (jobs.lua
-- cancel_queued; refused with a note when the inventory cannot hold them).
-- No reordering (ruling 3). The running job is the strip's, with its stop
-- button. The ✕ buttons name the entry's id, so a click on a page the queue
-- has moved on from never cancels another job.

local F = grug_jobs.CRAFT_FIELDS
local BOX = grug_jobs.CRAFT_BOX
local n, clip = grug_jobs._fs_number, grug_jobs._clip_chars
local wrapped_labels = grug_jobs._wrapped_labels

local X = BOX.x + 0.2
local W = BOX.w - 0.4
local HEADER_Y = BOX.y + 0.2
local ROW_H, ROW_STEP = 0.85, 0.95
local BOX_COLOR = "#00000040"
local ROW_COLOR = "#ffffff12"
local DIM = "#9a9a9a"
local NOTE = "#f0c75e"
local NOTE_STEP = 0.38
local CHARS = 6.6
local QUEUE_NOTE = "Ingredients and the target item are taken when a job is queued; ✕ " ..
	"returns them. The queue keeps running while you are offline."

local function esc(value)
	return core.formspec_escape(tostring(value or ""))
end

-- The area a job belongs to: Basic or its profession, and the kind of an
-- enchant or upgrade ("Weaponsmith · enchant").
local function area_of(job)
	local recipe = job.recipe_def or (job.operation and grug_jobs.station_operation and
		grug_jobs.station_operation(job.operation))
	if not recipe then return "" end
	if recipe.area == "basic" then return "Basic" end
	local profession = grug_jobs.PROFESSIONS[recipe.profession or recipe.area or ""]
	local name = profession and profession.name or ""
	if job.kind == "enchant" or job.kind == "upgrade" then name = name .. " · " .. job.kind end
	return name
end

local function build(player, view)
	local st = view.st
	local fs = {("box[%s,%s;%s,%s;%s]"):format(n(BOX.x), n(BOX.y), n(BOX.w), n(BOX.h),
		BOX_COLOR)}
	fs[#fs + 1] = ("button[%s,%s;2.6,0.6;%s;%s]"):format(n(X), n(HEADER_Y), F.back,
		esc("◀ Back to recipe"))
	fs[#fs + 1] = ("label[%s,%s;Crafting queue]"):format(n(X + 2.8), n(HEADER_Y + 0.3))
	local used = (view.job and 1 or 0) + #view.queue
	local slots = used .. " of " .. grug_jobs.QUEUE_MAX .. " slots"
	fs[#fs + 1] = ("label[%s,%s;%s]"):format(n(X + W - #slots / CHARS), n(HEADER_Y + 0.3),
		esc(core.colorize(DIM, slots)))
	local y = HEADER_Y + 0.85
	st.queue_ids = {}
	for index, job in ipairs(view.queue) do
		st.queue_ids[index] = job.id
		local icon = grug_jobs.JOB_ICONS[job.kind or "recipe"]
		local text = grug_jobs.job_label(job)
		fs[#fs + 1] = ("box[%s,%s;%s,%s;%s]label[%s,%s;%d]"):format(n(X), n(y), n(W),
			n(ROW_H), ROW_COLOR, n(X + 0.15), n(y + ROW_H / 2), index)
		if icon then
			fs[#fs + 1] = ("item_image[%s,%s;0.6,0.6;%s]"):format(n(X + 0.45),
				n(y + (ROW_H - 0.6) / 2), esc(icon(job)))
		end
		fs[#fs + 1] = ("label[%s,%s;%s]label[%s,%s;%s]"):format(n(X + 1.2), n(y + 0.25),
			esc(clip(text, math.floor((W - 2.1) * CHARS))), n(X + 1.2), n(y + 0.6),
			esc(core.colorize(DIM, area_of(job))))
		fs[#fs + 1] = ("button[%s,%s;0.6,0.6;%s%s;✕]tooltip[%s%s;%s]"):format(
			n(X + W - 0.75), n(y + (ROW_H - 0.6) / 2), F.unqueue, job.id, F.unqueue, job.id,
			esc("Cancel this job: its ingredients come back."))
		y = y + ROW_STEP
	end
	if #view.queue == 0 then
		y = wrapped_labels(fs, X, y + 0.2, W, view.job and
			"Nothing is waiting. While a job runs, “Queue” adds the next one here." or
			"No job running.", DIM, NOTE_STEP)
	end
	y = wrapped_labels(fs, X, y + 0.25, W, QUEUE_NOTE, DIM, NOTE_STEP)
	if st.note then wrapped_labels(fs, X, y + 0.1, W, st.note, NOTE, NOTE_STEP) end
	return table.concat(fs)
end

local function fields(player, st, fields)
	if fields[F.back] then
		grug_jobs.close_craft_box(st)
		return true
	end
	for name in pairs(fields) do
		local id = tonumber(type(name) == "string" and name:match("^" .. F.unqueue .. "(%d+)$"))
		if id then
			local ok, reason = grug_jobs.cancel_queued(player, id)
			if not ok then st.note = reason end
			return true
		end
	end
	return false
end

grug_jobs.register_craft_box("queue", {build = build, fields = fields})
