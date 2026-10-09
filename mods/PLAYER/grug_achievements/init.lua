--
-- Achievements and cloaks (round33-plan.md §2.10, character_visuals.md §5b).
--
-- Every character collects achievements (catalog.lua) by counters kept in its
-- own player meta; an earned tier unlocks a cloak. Cloaks are cosmetic and
-- never items: the Character page lists the owned ones in a dropdown under
-- the model, and grug_visuals draws the selected one on the player model.
-- Pure rules: core.lua (counters, tiers, unlocks, selection) and
-- creatures.lua (which kill counts as what).
--
-- Counters come from six hooks, each O(1) per event:
--   * grug_mobs' eligible kill (every credited participant of a mob death):
--     kill:animal and kill:zombie, kill:family:<family>, kill:group:<group>
--     (named leaders by role) and kill:rare:<group> (named rares by registry
--     id), the last three only while an achievement asks for them; the
--     counters of an entity name are looked up once and cached;
--   * the boss ledger (grug_mobs.register_on_boss_kill): boss:king,
--     boss:dragon and boss:<boss id>;
--   * grug_pvp's counters (grug_pvp.register_on_stat): pvp:<stat>, read from
--     grug_pvp.stats, never copied;
--   * grug_jobs' counted crafts (grug_jobs.register_on_award_progress):
--     craft:<profession> by the items a craft or job made (cooking: dishes,
--     alchemist: potions and elixirs, both counted at their preparation);
--   * deaths: death:<reason type>, e.g. death:fall;
--   * grug_quests' turn-ins (grug_quests.register_on_turn_in, Round 36):
--     quest:<quest id> and quest_tag:<tag> for each of the quest's `tags`,
--     each only while an achievement asks for it.
-- Every achievement is also settled once at join, so a counter that moved
-- without a hook (an admin edit) still earns its tier. A row with a
-- `faction` (catalog.lua) is never shown to, settled for or earned by a
-- character of the other faction or one without a faction yet.
--
-- Public API:
--   grug_achievements.add(player, counter[, amount])  count and settle
--   grug_achievements.select_cloak(player, id) -> bool
--   grug_achievements.selected_cloak(player) -> id
--   grug_achievements.unlocked_cloaks(player) -> {id, ...}
--   grug_achievements.cloak_dropdown(player, x, y, w) -> formspec
--   grug_achievements.choose_cloak_by_name(player, name) -> changed?
--   grug_achievements.character_achievements_formspec(player, context, area)
--   grug_achievements.handle_tab_fields(player, context, fields) -> handled?
--

grug_achievements = {}

local modpath = core.get_modpath(core.get_current_modname())
local R = dofile(modpath .. "/core.lua")
local C = dofile(modpath .. "/creatures.lua")
local book = R.build(dofile(modpath .. "/catalog.lua"))

grug_achievements.rules = R
grug_achievements.creatures = C
grug_achievements.book = book

local EMPTY = {}
local DONE_COLOR = "#7fd66b"
local PROGRESS_COLOR = "#f0c75e"

--
-- Counters and settling
--

local function value_of(player, counter)
	local stat = counter:match("^pvp:(.+)$")
	if stat then
		local pvp = rawget(_G, "grug_pvp")
		return pvp and pvp.stats(player)[stat] or 0
	end
	return R.count(player:get_meta(), counter)
end

local function announce(player, rows)
	for _, row in ipairs(rows) do
		local text = "Achievement: " .. R.title(row.achievement, row.tier)
		if row.cloak then
			text = text .. " — " .. book.cloak[row.cloak].name .. " unlocked"
		end
		grug_core.feed(player, "notice", text, "achievement:" ..
			row.achievement.id .. ":" .. row.tier)
	end
	-- The cloak picker (3D mode) and the Achievements list both changed.
	grug_inventory.refresh_character(player)
end

-- The character's faction (nil while it has none, in character creation).
local function faction_of(player)
	return grug_core.get_player_faction(player:get_player_name())
end

local function settle(player, ach)
	if not R.visible(ach, faction_of(player)) then
		return false
	end
	local rows = R.settle(book, player:get_meta(), ach, value_of(player, ach.counter))
	if #rows > 0 then
		announce(player, rows)
		return true
	end
	return false
end

-- Settle every achievement on `counter`; a tab showing the progress is
-- re-sent when nothing was earned (an earning re-sends the page anyway).
local function counter_changed(player, counter)
	local achievements = book.by_counter[counter]
	if not achievements then
		return
	end
	local announced = false
	for _, ach in ipairs(achievements) do
		announced = settle(player, ach) or announced
	end
	if not announced then
		grug_inventory.refresh_character_tab(player, "achievements")
	end
end

function grug_achievements.add(player, counter, amount)
	if not player or not player.is_player or not player:is_player() then
		return
	end
	R.add(player:get_meta(), counter, amount or 1)
	counter_changed(player, counter)
end

core.register_on_joinplayer(function(player)
	local meta = player:get_meta()
	for _, ach in ipairs(R.visible_list(book, faction_of(player))) do
		local rows = R.settle(book, meta, ach, value_of(player, ach.counter))
		if #rows > 0 then
			announce(player, rows)
		end
	end
end)

--
-- Hooks
--

-- Entity name -> the counters one kill of it feeds (cached; the lookup runs
-- once per name).
local kill_counters = {}

local function subtype_of(name)
	local mobs_mod = rawget(_G, "grug_mobs")
	return mobs_mod and mobs_mod.subtype and mobs_mod.subtype(name) or nil
end

local function wanted(counter, list)
	if book.by_counter[counter] then
		list[#list + 1] = counter
	end
end

function grug_achievements.kill_counters(name)
	if type(name) ~= "string" then
		return EMPTY
	end
	local list = kill_counters[name]
	if list then
		return list
	end
	list = {}
	local base = C.base_of(name, subtype_of)
	if base then
		local class = C.class_of(base)
		if class then
			list[#list + 1] = "kill:" .. class
		end
		local family = C.family_of(base)
		if family then
			wanted("kill:family:" .. family, list)
		end
		local group = C.role_group(name)
		if group then
			wanted("kill:group:" .. group, list)
		end
	end
	kill_counters[name] = list
	return list
end

if core.global_exists("grug_mobs") then
	grug_mobs.register_on_eligible_kill(function(player, ent)
		local list = grug_achievements.kill_counters(ent and ent.name)
		for index = 1, #list do
			grug_achievements.add(player, list[index], 1)
		end
		local rare = ent and ent._grug_rare_id and C.rare_group(ent._grug_rare_id)
		if rare and book.by_counter["kill:rare:" .. rare] then
			grug_achievements.add(player, "kill:rare:" .. rare, 1)
		end
	end)

	grug_mobs.register_on_boss_kill(function(player, id)
		local kind = id:match("^([%a_]+):")
		if kind then
			grug_achievements.add(player, "boss:" .. kind, 1)
		end
		grug_achievements.add(player, "boss:" .. id, 1)
	end)
end

if core.global_exists("grug_jobs") and grug_jobs.register_on_award_progress then
	-- `items`: what the craft or crafting job made (Round 45: a job counts its
	-- whole quantity at once).
	grug_jobs.register_on_award_progress(function(player, recipe, items)
		local counter = "craft:" .. tostring(recipe.profession)
		if book.by_counter[counter] then
			grug_achievements.add(player, counter, items or recipe.count or 1)
		end
	end)
end

if core.global_exists("grug_quests") then
	grug_quests.register_on_turn_in(function(player, id, def)
		local counter = "quest:" .. id
		if book.by_counter[counter] then
			grug_achievements.add(player, counter, 1)
		end
		for _, tag in ipairs(def.tags or EMPTY) do
			counter = "quest_tag:" .. tag
			if book.by_counter[counter] then
				grug_achievements.add(player, counter, 1)
			end
		end
	end)
end

core.register_on_dieplayer(function(player, reason)
	local counter = "death:" .. tostring(reason and reason.type or "unknown")
	if book.by_counter[counter] then
		grug_achievements.add(player, counter, 1)
	end
end)

if core.global_exists("grug_pvp") then
	grug_pvp.register_on_stat(function(player, key)
		counter_changed(player, "pvp:" .. key)
	end)
end

--
-- Cloaks
--

function grug_achievements.selected_cloak(player)
	return R.selected(book, player:get_meta())
end

function grug_achievements.unlocked_cloaks(player)
	return R.unlocked(book, player:get_meta())
end

function grug_achievements.select_cloak(player, id)
	if not R.select(book, player:get_meta(), id) then
		return false
	end
	grug_visuals.apply(player)
	grug_sounds.play("cloak", player)
	return true
end

grug_visuals.register_cloak_source(function(player)
	local meta = player:get_meta()
	return R.cloak_texture(book, meta), R.selected(book, meta)
end)

-- The Character page's cloak picker (3D mode, beside the model). Items are
-- the owned cloaks by name; the client sends the chosen name back.
function grug_achievements.cloak_dropdown(player, x, y, w)
	local meta = player:get_meta()
	local selected = R.selected(book, meta)
	local items, index = {}, 1
	for position, id in ipairs(R.unlocked(book, meta)) do
		items[position] = core.formspec_escape(book.cloak[id].name)
		if id == selected then
			index = position
		end
	end
	return ("dropdown[%.2f,%.2f;%.2f;grug_cloak;%s;%d]"):format(x, y, w,
		table.concat(items, ","), index)
end

-- Every submission of the page carries the dropdown's value, so only a name
-- that differs from the selection is a choice.
function grug_achievements.choose_cloak_by_name(player, name)
	local meta = player:get_meta()
	local selected = R.selected(book, meta)
	for _, id in ipairs(R.unlocked(book, meta)) do
		if book.cloak[id].name == name then
			return id ~= selected and grug_achievements.select_cloak(player, id)
		end
	end
	return false
end

--
-- The Achievements mode of the Character page: one column of rows in the
-- page's mode area (Round 44, real coordinates), the cloak's outer face
-- beside each, paged when there are more.
--

local ROW_STEP, PER_PAGE = 0.95, 7
local PAGER_H = 0.7
local TEXT_CHARS = 38

local function clip(text, limit)
	if #text <= limit then
		return text
	end
	return text:sub(1, limit - 2) .. ".."
end

-- One achievement's two lines and its picture, for this character: the
-- tier being worked towards with its progress, or the last tier once all are
-- earned.
function grug_achievements.row(player, ach)
	local meta = player:get_meta()
	local earned = R.earned(meta, ach)
	local value = value_of(player, ach.counter)
	local tiers = #ach.tiers
	local next_tier = ach.tiers[math.min(earned + 1, tiers)]
	local title, status
	if earned >= tiers then
		title = R.title(ach, tiers)
		status = core.colorize(DONE_COLOR, "Earned")
	else
		title = R.title(ach, earned + 1)
		status = core.colorize(PROGRESS_COLOR,
			math.min(value, next_tier.at) .. "/" .. next_tier.at)
	end
	local text = next_tier.at == 1 and ach.text_one or ach.text
	if text:find("%%d") then
		text = text:format(next_tier.at)
	end
	-- The picture: the cloak of the next (or last) tier, dimmed until earned.
	local cloak = next_tier.cloak and book.cloak[next_tier.cloak]
	local image = cloak and cloak.texture and
		(cloak.texture .. "^[sheet:2x1:0,0") or nil
	if image and earned < tiers then
		image = image .. "^[multiply:#5a5a5a"
	end
	-- The tooltip: the whole condition, the flavour line and the cloak.
	local tip = text
	if ach.flavour then
		tip = tip .. "\n\"" .. ach.flavour .. "\""
	end
	if cloak then
		tip = tip .. "\nCloak: " .. cloak.name
	end
	return title, status, text, image, tip
end

-- Only the character's own achievements are listed and paged: a row of the
-- other faction is never shown.
local function page_count(list)
	return math.max(1, math.ceil(#list / PER_PAGE))
end

-- `area` is the mode area {x, y, w, h}: the rows from its top, the pager at
-- its foot.
function grug_achievements.character_achievements_formspec(player, context, area)
	local list = R.visible_list(book, faction_of(player))
	local pages = page_count(list)
	local page = math.max(1, math.min(context.grug_achievements_page or 1, pages))
	context.grug_achievements_page = page
	local fs = {}
	local first = (page - 1) * PER_PAGE
	for slot = 1, PER_PAGE do
		local ach = list[first + slot]
		if not ach then
			break
		end
		local x = area.x
		local y = area.y + (slot - 1) * ROW_STEP
		local title, status, text, image, tip = grug_achievements.row(player, ach)
		-- The rect covers the row's picture and both lines.
		fs[#fs + 1] = ("tooltip[%.2f,%.2f;%.2f,0.85;%s]"):format(x, y, area.w,
			core.formspec_escape(tip))
		if image then
			fs[#fs + 1] = ("image[%.2f,%.2f;0.42,0.84;%s]"):format(x, y,
				core.formspec_escape(image))
		end
		-- Real-coordinate labels are centred on their y.
		fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(x + 0.6, y + 0.2,
			core.formspec_escape(title .. "  " .. status))
		fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(x + 0.6, y + 0.62,
			core.formspec_escape(clip(text, TEXT_CHARS)))
	end
	if pages > 1 then
		local right, y = area.x + area.w, area.y + area.h - PAGER_H
		fs[#fs + 1] = ("label[%.2f,%.2f;%d/%d]button[%.2f,%.2f;0.8,%.2f;grug_ach_prev;<]" ..
			"button[%.2f,%.2f;0.8,%.2f;grug_ach_next;>]"):format(right - 2.5,
			y + PAGER_H / 2, page, pages, right - 1.7, y, PAGER_H, right - 0.8, y,
			PAGER_H)
	end
	return table.concat(fs)
end

function grug_achievements.handle_tab_fields(player, context, fields)
	if fields.grug_ach_prev or fields.grug_ach_next then
		local page = (context.grug_achievements_page or 1) +
			(fields.grug_ach_next and 1 or -1)
		context.grug_achievements_page = math.max(1, math.min(page,
			page_count(R.visible_list(book, faction_of(player)))))
		sfinv.set_player_inventory_formspec(player, context)
		return true
	end
	return false
end

--
-- Startup audit: every mob grug_mobs registers is classified (creatures.lua).
--
core.register_on_mods_loaded(function()
	local mobs_mod = rawget(_G, "grug_mobs")
	if not (mobs_mod and mobs_mod.registered_cadence) then
		return
	end
	local names = {}
	for name in pairs(mobs_mod.registered_cadence) do
		names[#names + 1] = name
	end
	local missing = C.unclassified(names, subtype_of)
	if #missing > 0 then
		core.log("warning", "[grug_achievements] not classified for the kill " ..
			"counters (creatures.lua): " .. table.concat(missing, ", "))
	end
	local animals, zombies = 0, 0
	for _, name in ipairs(names) do
		local class = C.class_of(C.base_of(name, subtype_of))
		if class == "animal" then
			animals = animals + 1
		elseif class == "zombie" then
			zombies = zombies + 1
		end
	end
	core.log("action", ("[grug_achievements] %d achievements, %d cloaks; %d of " ..
		"%d mobs count as wild animals, %d as zombies"):format(#book.achievements,
		#book.cloaks, animals, #names, zombies))
end)
