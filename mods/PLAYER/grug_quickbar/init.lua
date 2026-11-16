-- The quickbar (Round 44, ui-crafting-rework-plan.md ruling 9 and §3.5): the
-- rising edge of aux1 (E; grug_keys) opens a small window on the left of the
-- screen with the character's purchased mounts and boats on top (and
-- Dismount below them while riding), the potion belt and the hotbar switch
-- (A and B, Round 50) below, the emotes (Round 78; icon buttons since Round
-- 80) and the Return home button at the foot. A click uses the mount, boat, potion,
-- Dismount, emote or Return home and closes the window. The window is sent once per opening and refreshed only by a
-- hotbar switch. Its own mod because it reaches mounts, home travel and the
-- inventory's belt, and grug_mounts and grug_home already depend on
-- grug_inventory.
--
-- Every action keeps the gates of its owner: grug_mounts.toggle (combat,
-- the boat's water surface, the flight rules, dismount of the active tier),
-- the potion's own on_use with the shared potion cooldown
-- (grug_traders.potion_cooldown_left), grug_home.return_home (combat, the
-- cooldown, a running return), grug_visuals.play_emote (the seated clips on
-- a mount, its rate limit, the emote gate this mod hands it). No "menu open" check: the client releases
-- every key while a menu or the chat is open, so E cannot rise there.
grug_quickbar = {}

local FORMNAME = "grug_quickbar:bar"
grug_quickbar.FORMNAME = FORMNAME
local BELT = grug_inventory.POTION_BELT

-- Real coordinates: inventory-sized slots (1 unit, 0.25 apart, as a list[]
-- draws them), four to a row.
local COLUMNS, SLOT, GAP, PAD = 4, 1, 0.25, 0.5
local PITCH = SLOT + GAP
local WIDTH = PAD * 2 + COLUMNS * SLOT + (COLUMNS - 1) * GAP
local SLOT_COLOR = "#00000069" -- the empty-slot colour of the inventory lists
local ACTIVE_COLOR = "#7ae08a" -- the frame of the mount or boat being ridden

-- The emotes (Round 78 ruling 10; round80-plan.md rulings 1 and 7, §3.1,
-- §3.3), in the grid's order: Wave and Dance for every character, then the
-- account rewards in catalogue order (this list registers them, so its
-- order is theirs). A reward emote is the character's while its website
-- account gives `reward`, read live (grug_accounts.has_reward) at every
-- check and never stored, like a reward cloak. Each has its icon,
-- grug_quickbar_emote_<id>.png, and a dimmed `_off` copy
-- (tools/r80_emote/icons.py renders both from the player model).
grug_quickbar.EMOTES = {
	{id = "wave", name = "Wave"},
	{id = "dance", name = "Dance"},
	{id = "cheer", name = "Cheer", reward = "emote:cheer"},
}
local EMOTE_FIELD = "grug_quickbar_emote_"
local EMOTE_CLIPS = grug_visuals.EMOTE_CLIPS
-- The portable fixtures load this file without grug_accounts: no reward
-- emotes there.
local accounts = rawget(_G, "grug_accounts")

local function icon(id, off)
	return "grug_quickbar_emote_" .. id .. (off and "_off" or "") .. ".png"
end

-- The one answer to "which emotes does this character have" (§3.3): the
-- quickbar's grid and grug_visuals.play_emote's gate both ask it.
function grug_quickbar.owns_emote(player, id)
	for _, entry in ipairs(grug_quickbar.EMOTES) do
		if entry.id == id then
			return not entry.reward or (accounts ~= nil and
				accounts.has_reward(player:get_player_name(), entry.reward))
		end
	end
	return false
end

-- The character's emotes, in the grid's order.
function grug_quickbar.emotes(player)
	local out = {}
	for _, entry in ipairs(grug_quickbar.EMOTES) do
		if grug_quickbar.owns_emote(player, entry.id) then out[#out + 1] = entry end
	end
	return out
end

grug_visuals.set_emote_gate(grug_quickbar.owns_emote)

-- The reward emotes in grug_accounts' catalogue: the Account page shows
-- the emote's icon. The window is sent once per opening, so a grant or a
-- removal shows at the next opening; the gate follows at once.
if accounts then
	for _, entry in ipairs(grug_quickbar.EMOTES) do
		if entry.reward then
			accounts.register_reward(entry.reward, {kind = "emote", name = entry.name,
				icon = icon(entry.id), hint = "Play it from the quickbar (E)."})
		end
	end
end

-- player name -> true from a send until the window's quit or a click.
local open = {}

local function esc(value)
	return core.formspec_escape(tostring(value or ""))
end

-- A belt stack the quickbar offers: a potion or elixir with a use.
local function usable(stack)
	local def = not stack:is_empty() and core.registered_items[stack:get_name()]
	return def and def.on_use ~= nil and
		core.get_item_group(stack:get_name(), "grug_potion") > 0 or false
end

-- The window for `player`: pure apart from the reads, for the fixture.
function grug_quickbar.formspec(player)
	-- The text grows as a window of the usual height does (text_growth).
	local growth = grug_core.ui.text_growth(player, WIDTH, 9)
	local fs = {growth ~= 1 and grug_core.ui.fonts(growth) or ""}
	local y = 0.45
	fs[#fs + 1] = grug_core.ui.title(PAD, y, "Quickbar", growth, growth) ..
		"style_type[label;font_size=" .. grug_core.ui.font_size(0.85, growth) .. "]"
	y = y + 0.55
	local section_y, section_index = y, #fs + 1
	fs[section_index] = ""
	fs[#fs + 1] = grug_core.ui.heading(PAD, y, "Mounts and boats", growth)
	y = y + 0.3
	local tiers = grug_mounts.owned_tier_ids(player)
	local active = grug_mounts.active[player:get_player_name()]
	if #tiers == 0 then
		fs[#fs + 1] = ("label[%.3f,%.2f;%s]"):format(PAD, y + 0.25,
			esc(core.colorize("#8a8a8a", "No mounts or boats yet.")))
		y = y + 0.6
	else
		for index, tier_id in ipairs(tiers) do
			local tier = grug_mounts.TIERS[tier_id]
			local model = grug_mounts.model_for(player, tier_id)
			local x = PAD + ((index - 1) % COLUMNS) * PITCH
			local row_y = y + math.floor((index - 1) / COLUMNS) * PITCH
			local field = "grug_quickbar_mount_" .. tier_id
			local riding = active ~= nil and active.tier == tier_id
			if riding then
				fs[#fs + 1] = ("box[%.3f,%.3f;%.2f,%.2f;%s]"):format(x - 0.06, row_y - 0.06,
					SLOT + 0.12, SLOT + 0.12, ACTIVE_COLOR)
			end
			fs[#fs + 1] = ("image_button[%.3f,%.3f;%d,%d;%s;%s;]"):format(x, row_y, SLOT, SLOT,
				esc(model and model.icon or tier.icon), field)
			fs[#fs + 1] = ("tooltip[%s;%s]"):format(field, esc(
				(model and model.description .. "\n" or "") ..
				("%s — %g nodes/s"):format(tier.name, tier.speed) ..
				(riding and "\nClick to dismount." or "")))
		end
		local rows = math.floor((#tiers - 1) / COLUMNS) + 1
		y = y + rows * SLOT + (rows - 1) * GAP
	end
	-- Dismount (0.45.1): only while riding, the same manual dismount as a
	-- click on the framed mount.
	if active then
		y = y + GAP
		fs[#fs + 1] = ("button[%.3f,%.3f;%.3f,0.6;grug_quickbar_dismount;Dismount]"):format(PAD, y,
			WIDTH - PAD * 2)
		y = y + 0.6
	end
	fs[section_index] = grug_core.ui.panel(0.2, section_y - 0.2, WIDTH - 0.4, y - section_y + 0.4)
	y = y + 0.65
	section_y, section_index = y, #fs + 1
	fs[section_index] = ""
	fs[#fs + 1] = grug_core.ui.heading(PAD, y, "Potion belt", growth)
	y = y + 0.3
	local inv = player:get_inventory()
	for index = 1, grug_inventory.POTION_BELT_SIZE do
		local x = PAD + (index - 1) * PITCH
		fs[#fs + 1] = ("box[%.3f,%.3f;%d,%d;%s]"):format(x, y, SLOT, SLOT, SLOT_COLOR)
		local stack = inv:get_stack(BELT, index)
		-- An item button, not a list slot (a slot would pick the stack up);
		-- the item string carries the count, which the button draws.
		if usable(stack) then
			fs[#fs + 1] = ("item_image_button[%.3f,%.3f;%d,%d;%s;grug_quickbar_belt_%d;]"):format(
				x, y, SLOT, SLOT, esc(stack:to_string()), index)
		end
	end
	y = y + SLOT
	-- The hotbar switch (Round 50 ruling 2): the inventory views' element,
	-- the two buttons side by side on the slot columns.
	fs[section_index] = grug_core.ui.panel(0.2, section_y - 0.2, WIDTH - 0.4, y - section_y + 0.4)
	y = y + 0.65
	section_y, section_index = y, #fs + 1
	fs[section_index] = ""
	fs[#fs + 1] = grug_core.ui.heading(PAD, y, "Active Hotbar", growth)
	y = y + 0.3
	fs[#fs + 1] = grug_inventory.hotbar_switch(player, PAD, y, SLOT, 0.6, PITCH, 0)
	y = y + 0.6
	fs[section_index] = grug_core.ui.panel(0.2, section_y - 0.2, WIDTH - 0.4, y - section_y + 0.4)
	-- The emotes (Round 78 ruling 10, Round 80 ruling 7): the character's
	-- emotes as icon buttons, four to a row in the mounts' slot size, the
	-- tooltip naming each. A rider plays the seated clips; an emote without
	-- one (Dance) is greyed while riding: its dimmed icon on a dark button
	-- that does not react, under its own field, a click on it changes
	-- nothing.
	y = y + 0.65
	section_y, section_index = y, #fs + 1
	fs[section_index] = ""
	fs[#fs + 1] = grug_core.ui.heading(PAD, y, "Emotes", growth)
	y = y + 0.3
	local emotes = grug_quickbar.emotes(player)
	for index, entry in ipairs(emotes) do
		local x = PAD + ((index - 1) % COLUMNS) * PITCH
		local row_y = y + math.floor((index - 1) / COLUMNS) * PITCH
		local field, tip = EMOTE_FIELD .. entry.id, entry.name
		local off = active ~= nil and not EMOTE_CLIPS[entry.id].sit
		if off then
			field, tip = field .. "_off", entry.name .. "\nNot while riding."
			fs[#fs + 1] = ("style[%s,%s:hovered,%s:pressed;bgcolor=#2a2a2a]"):format(
				field, field, field)
		end
		fs[#fs + 1] = ("image_button[%.3f,%.3f;%d,%d;%s;%s;]"):format(x, row_y, SLOT, SLOT,
			icon(entry.id, off), field) .. ("tooltip[%s;%s]"):format(field, esc(tip))
	end
	local rows = math.floor((#emotes - 1) / COLUMNS) + 1
	y = y + rows * SLOT + (rows - 1) * GAP
	fs[section_index] = grug_core.ui.panel(0.2, section_y - 0.2, WIDTH - 0.4, y - section_y + 0.4)
	fs[#fs + 1] = "style_type[label;font_size=" .. grug_core.ui.font_size(0.85, growth) .. "]"
	local home_label, home_state = grug_inventory.home_state(player)
	if home_label then
		y = y + 0.65
		fs[#fs + 1] = grug_core.ui.panel(0.2, y - 0.2, WIDTH - 0.4, 1.3)
		fs[#fs + 1] = grug_core.ui.heading(PAD, y, "Home: " .. home_label, growth)
		y = y + 0.3
		fs[#fs + 1] = ("button[%.3f,%.3f;%.3f,0.6;grug_quickbar_home;%s]"):format(PAD, y,
			WIDTH - PAD * 2, esc(("Return home (%s)"):format(home_state)))
		y = y + 0.6
	end
	-- Two lines: formspec labels do not wrap, and the window is narrow.
	y = y + 0.45
	fs[#fs + 1] = ("label[%.3f,%.2f;%s]"):format(PAD, y,
		esc(core.colorize("#c8c8c8", "Click to use; the window closes.")))
	y = y + 0.4
	fs[#fs + 1] = ("label[%.3f,%.2f;%s]"):format(PAD, y,
		esc(core.colorize("#c8c8c8", "A and B switch the hotbar.")))
	local height = y + 0.45
	-- Padding must follow the native position/anchor in the parser.
	return grug_core.ui.frame(WIDTH, height) ..
		"position[0.02,0.5]anchor[0,0.5]" ..
		(grug_core.ui.window_padding and grug_core.ui.window_padding(player) or "") ..
		table.concat(fs)
end

-- Opens the window (the rising edge of aux1). Not while dead or while
-- another mod owns the inventory (character creation), like the map window.
function grug_quickbar.open(player)
	if sfinv.inventory_suspended(player) or (player:get_hp() or 1) <= 0 then return false end
	local name = player:get_player_name()
	open[name] = true
	core.show_formspec(name, FORMNAME, grug_quickbar.formspec(player))
	return true
end

-- Drinks the belt slot `index` through the item's own on_use, like the
-- engine's use of a wielded item: a nil result leaves the stack alone (a
-- refusal: the cooldown, full health, the level), any other result replaces
-- it. Returns whether the potion was used.
function grug_quickbar.drink(player, index)
	local inv = player:get_inventory()
	local stack = inv:get_stack(BELT, index)
	if not usable(stack) then return false end
	local def = core.registered_items[stack:get_name()]
	local result = def.on_use(ItemStack(stack), player, {type = "nothing"})
	if result == nil then return false end
	inv:set_stack(BELT, index, ItemStack(result))
	return true
end

-- One click acts once and closes the window; the quit of the close (or of
-- Esc) and any event after it change nothing. A hotbar switch keeps the
-- window open and shows it again with the new layout marked.
function grug_quickbar.handle_fields(player, fields)
	local name = player:get_player_name()
	if not open[name] then return end
	if grug_inventory.hotbar_switch_fields(player, fields) then
		core.show_formspec(name, FORMNAME, grug_quickbar.formspec(player))
		return
	end
	local acted = false
	for tier_id = 1, #grug_mounts.TIERS do
		if fields["grug_quickbar_mount_" .. tier_id] then
			if grug_mounts.owns_tier(player, tier_id) then grug_mounts.toggle(player, tier_id) end
			acted = true
			break
		end
	end
	-- A no-op when the ride already ended (dismount answers false).
	if not acted and fields.grug_quickbar_dismount then
		grug_mounts.dismount(player, "manual", false)
		acted = true
	end
	if not acted then
		for index = 1, grug_inventory.POTION_BELT_SIZE do
			if fields["grug_quickbar_belt_" .. index] then
				grug_quickbar.drink(player, index)
				acted = true
				break
			end
		end
	end
	-- A greyed emote (riding) is no field here: the window stays. The gate in
	-- play_emote refuses an emote the character does not have.
	if not acted then
		for _, entry in ipairs(grug_quickbar.EMOTES) do
			if fields[EMOTE_FIELD .. entry.id] then
				grug_visuals.play_emote(player, entry.id)
				acted = true
				break
			end
		end
	end
	if not acted and fields.grug_quickbar_home then
		grug_home.return_home(player)
		acted = true
	end
	if acted or fields.quit then open[name] = nil end
	if acted then core.close_formspec(name, FORMNAME) end
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then return false end
	grug_quickbar.handle_fields(player, fields)
	return true
end)

grug_keys.register_on_press("aux1", function(player) grug_quickbar.open(player) end)

core.register_on_leaveplayer(function(player) open[player:get_player_name()] = nil end)
core.register_on_dieplayer(function(player) open[player:get_player_name()] = nil end)
