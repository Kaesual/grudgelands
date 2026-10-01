-- The Professions tab of the Character page (Round 28 ruling 23): per known
-- profession its tier, the crafts made in that tier against the count the
-- next tier needs, and a note while the character level caps the tier
-- (state.lua: the effective tier never exceeds the character's ten-level
-- band). grug_inventory owns the tab row and asks for the body here, because
-- grug_jobs depends on grug_inventory and not the other way round.

-- One row per known profession, primary slots first, then the secondaries:
-- {name, tier, crafts, needed (nil at T6), capped, next_level}.
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
			capped = needed ~= nil and character_tier <= tier,
			next_level = tier * 10 + 1,
		}
	end
	return rows
end

local NOTE_COLOR = "#f0c75e"
local ROW_Y, ROW_STEP = 1.0, 1.45

local function esc(value)
	return core.formspec_escape(tostring(value or ""))
end

-- The tab body in sfinv's legacy coordinates (content ends before y = 7.0;
-- three rows -- two primaries and Cooking -- end at about 4.5). Pure.
function grug_jobs.professions_formspec(rows)
	if #rows == 0 then
		return "label[0.2,1.0;" .. esc("No professions learned yet. Profession " ..
			"trainers in the towns and capitals teach them.") .. "]"
	end
	local fs = {}
	for index, row in ipairs(rows) do
		local y = ROW_Y + (index - 1) * ROW_STEP
		fs[#fs + 1] = ("label[0.2,%.2f;%s]"):format(y,
			esc(("%s — Tier %d"):format(row.name, row.tier)))
		local progress
		if row.needed then
			progress = ("Crafts: %d/%d toward tier %d"):format(row.crafts,
				row.needed, row.tier + 1)
		else
			progress = "Highest tier reached."
		end
		fs[#fs + 1] = ("label[0.2,%.2f;%s]"):format(y + 0.4, esc(progress))
		if row.capped then
			-- A saturated count advances on the next current-tier craft once
			-- the level allows it (state.lua record_craft).
			local note
			if row.crafts >= row.needed then
				note = ("Capped by your level: reach level %d, then craft " ..
					"once more for tier %d."):format(row.next_level, row.tier + 1)
			else
				note = ("Capped by your level: tier %d needs character " ..
					"level %d."):format(row.tier + 1, row.next_level)
			end
			fs[#fs + 1] = ("label[0.2,%.2f;%s]"):format(y + 0.8,
				esc(core.colorize(NOTE_COLOR, note)))
		end
	end
	fs[#fs + 1] = ("label[0.2,6.4;%s]"):format(esc("Only crafts of the current " ..
		"tier count toward the next one."))
	return table.concat(fs)
end

function grug_jobs.character_professions_formspec(player)
	return grug_jobs.professions_formspec(grug_jobs.profession_overview(player))
end
