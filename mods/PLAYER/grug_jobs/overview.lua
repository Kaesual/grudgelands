-- The professions overview (Round 28 ruling 23; on the Crafting tab since
-- Round 45 lane UI, spec ruling 6): per known profession its tier, the
-- crafts made in that tier against the count the next tier needs, and a note
-- while the character level caps the tier (state.lua: the effective tier
-- never exceeds the character's ten-level band). The Crafting tab (ui.lua,
-- craft_box.lua) draws it into its crafting box while no recipe is chosen.

-- One row per known profession, primary slots first, then the secondaries:
-- {name, tier, crafts, needed (nil at T6), capped, next_level}; `capped`
-- means the count is full and only the character level holds the tier.
function grug_jobs.profession_overview(player)
	local order = {}
	for slot = 1, grug_jobs.PRIMARY_SLOTS do
		local profession = grug_jobs.primary_at(player, slot)
		if profession then order[#order + 1] = profession end
	end
	for _, profession in ipairs(grug_jobs.SECONDARY_PROFESSIONS) do
		if grug_jobs.has(player, profession) then order[#order + 1] = profession end
	end
	local character_tier = grug_jobs.character_tier(player)
	local rows = {}
	for _, profession in ipairs(order) do
		local tier = grug_jobs.profession_level(player, profession)
		local needed = grug_jobs.CRAFTS_TO_ADVANCE[tier]
		rows[#rows + 1] = {
			name = grug_jobs.PROFESSIONS[profession].name,
			tier = tier,
			crafts = needed and math.min(needed,
				grug_jobs.crafts_in_tier(player, profession)) or 0,
			needed = needed,
			-- Only when the level is what blocks advancement: the count is
			-- full and the character's band does not allow the next tier.
			capped = needed ~= nil and character_tier <= tier and
				grug_jobs.crafts_in_tier(player, profession) >= needed,
			next_level = tier * 10 + 1,
		}
	end
	return rows
end

local NOTE_COLOR = "#f0c75e"
-- Real-coordinate labels are centred on their y; one printed line each.
local LINE_STEP, ROW_GAP = 0.42, 0.26
-- Characters per line in a mode area `area.w` units wide.
local CHARS_PER_UNIT = 6.6

local function esc(value)
	return core.formspec_escape(tostring(value or ""))
end

-- The overview drawn into `area` = {x, y, w, h} in real coordinates: per
-- profession its name and tier, its progress and, while the level caps it,
-- the note, wrapped to the area's width; the footer at the area's foot when
-- the rows leave room. A row that would pass the area's foot (four capped
-- rows in the Crafting tab's narrow box) is left out with a pointer to the
-- area tabs, which show every profession's tier progress. Pure.
function grug_jobs.professions_formspec(rows, area)
	local width = math.floor(area.w * CHARS_PER_UNIT)
	local last_y = area.y + area.h - 0.25
	local fs = {}
	local function line(y, text)
		fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(area.x, y, esc(text))
	end
	-- One label per wrapped line; returns the y below the last one.
	local function lines(y, text, color)
		for piece in (grug_inventory.wrap_text(text, width) .. "\n"):gmatch("(.-)\n") do
			line(y, color and core.colorize(color, piece) or piece)
			y = y + LINE_STEP
		end
		return y
	end
	local function count(text)
		local _, breaks = grug_inventory.wrap_text(text, width):gsub("\n", "")
		return breaks + 1
	end
	if #rows == 0 then
		lines(area.y + 0.35, "No professions learned yet. Profession " ..
			"trainers in the capitals teach them.")
		return table.concat(fs)
	end
	local y = area.y + 0.35
	for index, row in ipairs(rows) do
		local progress, note
		if row.needed then
			progress = ("Crafts: %d/%d toward tier %d"):format(row.crafts,
				row.needed, row.tier + 1)
		else
			progress = "Highest tier reached."
		end
		if row.capped then
			-- The full count advances on the next current-tier craft once the
			-- level allows it (state.lua record_craft).
			note = ("Capped by your level: reach level %d, then craft " ..
				"once more for tier %d."):format(row.next_level, row.tier + 1)
		end
		local needed = 1 + count(progress) + (note and count(note) or 0)
		-- Room for the pointer after it, unless it is the last row.
		local reserve = index < #rows and LINE_STEP + ROW_GAP or 0
		if y + (needed - 1) * LINE_STEP + reserve > last_y then
			lines(y, "More on the area tabs above.")
			return table.concat(fs)
		end
		line(y, ("%s — Tier %d"):format(row.name, row.tier))
		y = lines(y + LINE_STEP, progress)
		if note then y = lines(y, note, NOTE_COLOR) end
		y = y + ROW_GAP
	end
	-- The footer when the rows leave room for it (four capped rows do not).
	local footer = grug_inventory.wrap_text("Only crafts of the current tier " ..
		"count toward the next one.", width)
	local _, breaks = footer:gsub("\n", "")
	local footer_y = area.y + area.h - 0.25 - breaks * LINE_STEP
	if y <= footer_y then lines(footer_y, footer) end
	return table.concat(fs)
end
