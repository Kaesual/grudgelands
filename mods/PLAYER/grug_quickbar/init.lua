-- The quickbar (Round 44, ui-crafting-rework-plan.md ruling 9 and §3.5): the
-- rising edge of aux1 (E; grug_keys) opens a small window on the left of the
-- screen with the character's purchased mounts and boats on top, the potion
-- belt below and the Return home button at the foot. A click uses the mount,
-- boat, potion or Return home and closes the window. The window is sent once
-- per opening and never refreshed. Its own mod because it reaches mounts,
-- home travel and the inventory's belt, and grug_mounts and grug_home already
-- depend on grug_inventory.
--
-- Every action keeps the gates of its owner: grug_mounts.toggle (combat,
-- the boat's water surface, the flight rules, dismount of the active tier),
-- the potion's own on_use with the shared potion cooldown
-- (grug_traders.potion_cooldown_left), grug_home.return_home (combat, the
-- cooldown, a running return). No "menu open" check: the client releases
-- every key while a menu or the chat is open, so E cannot rise there.
grug_quickbar = {}

local FORMNAME = "grug_quickbar:bar"
grug_quickbar.FORMNAME = FORMNAME
local BELT = grug_inventory.POTION_BELT

-- Real coordinates: inventory-sized slots (1 unit, 0.25 apart, as a list[]
-- draws them), four to a row.
local COLUMNS, SLOT, GAP, PAD = 4, 1, 0.25, 0.375
local PITCH = SLOT + GAP
local WIDTH = PAD * 2 + COLUMNS * SLOT + (COLUMNS - 1) * GAP
local SLOT_COLOR = "#00000069" -- the empty-slot colour of the inventory lists
local ACTIVE_COLOR = "#7ae08a" -- the frame of the mount or boat being ridden

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
	local fs = {}
	local y = 0.45
	fs[#fs + 1] = ("label[%.3f,%.2f;Quickbar]"):format(PAD, y)
	y = y + 0.55
	fs[#fs + 1] = ("label[%.3f,%.2f;Mounts and boats]"):format(PAD, y)
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
	y = y + 0.45
	fs[#fs + 1] = ("label[%.3f,%.2f;Potion belt]"):format(PAD, y)
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
	local home_label, home_state = grug_inventory.home_state(player)
	if home_label then
		y = y + 0.45
		fs[#fs + 1] = ("label[%.3f,%.2f;%s]"):format(PAD, y, esc("Home: " .. home_label))
		y = y + 0.3
		fs[#fs + 1] = ("button[%.3f,%.3f;%.3f,0.8;grug_quickbar_home;%s]"):format(PAD, y,
			WIDTH - PAD * 2, esc(("Return home (%s)"):format(home_state)))
		y = y + 0.8
	end
	y = y + 0.45
	fs[#fs + 1] = ("label[%.3f,%.2f;%s]"):format(PAD, y,
		esc(core.colorize("#c8c8c8", "Click to use; the window closes.")))
	local height = y + 0.45
	return ("formspec_version[6]size[%.3f,%.3f]position[0.02,0.5]anchor[0,0.5]"):format(
		WIDTH, height) .. table.concat(fs)
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
-- Esc) and any event after it change nothing.
function grug_quickbar.handle_fields(player, fields)
	local name = player:get_player_name()
	if not open[name] then return end
	local acted = false
	for tier_id = 1, #grug_mounts.TIERS do
		if fields["grug_quickbar_mount_" .. tier_id] then
			if grug_mounts.owns_tier(player, tier_id) then grug_mounts.toggle(player, tier_id) end
			acted = true
			break
		end
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
