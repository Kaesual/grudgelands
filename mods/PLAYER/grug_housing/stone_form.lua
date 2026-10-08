-- The owner's Claim Stone formspec (ruling 13): fuel slot, remaining time,
-- access list, pick up with confirmation and "Set as home" when grug_home
-- offers it. A draft (Round 26 ruling 8) gets a small form of its own: the
-- time left, counting down every second while the form is open, the
-- activation button, pick up and close; no fuel slot, access list or "Set as
-- home" (permissions are set once the stone is active). It has no text field
-- and no inventory list, so the per-second redraw loses nothing the player
-- typed or held. Lane A's stone node opens the form through
-- grug_housing.open_stone_interface(player, claim) on the owner's
-- right-click.
--
-- One session per player holds the claim id, never the claim table: every
-- action re-reads the player's claim from the registry and re-checks that it
-- is still placed, still the player's own and still within reach.

return function(ui)

local FORMNAME = "grug_housing:stone"
local NOTICE = "grug_housing:notice"
local LIST = "fuel"
-- How far the owner may stand from the stone while the form acts.
local REACH = 10

local sessions = {}
local detached = {}

-- The client holds one formspec at a time: a form another mod shows replaces
-- ours without a "quit", and the draft countdown must not pop ours back over
-- it. Any other form shown to the player (or a close of ours or of any form)
-- ends the session, as default/node_formspec.lua does for node forms.
local show_formspec = core.show_formspec
function core.show_formspec(playername, formname, formspec)
	if formspec == "" then
		if formname == "" or formname == FORMNAME then sessions[playername] = nil end
	elseif formname ~= FORMNAME and formname ~= NOTICE then
		sessions[playername] = nil
	end
	return show_formspec(playername, formname, formspec)
end

local function inventory_name(name)
	return "grug_housing_fuel_" .. name
end

-- The player's claim, if it is still the placed claim of this session, owned
-- by the player and within reach; nil otherwise.
local function current_claim(player, session)
	if not session then return nil end
	local name = player:get_player_name()
	local claim, state = grug_housing.player_claim(name)
	if not claim or state ~= "placed" or claim.id ~= session.claim_id or
			grug_housing.permission(claim, name) ~= "owner" then
		return nil
	end
	local pos, center = player:get_pos(), claim.center
	if not pos or not center then return nil end
	local dx, dy, dz = pos.x - center.x, pos.y - center.y, pos.z - center.z
	if dx * dx + dy * dy + dz * dz > REACH * REACH then return nil end
	return claim
end

-- Players with access, without the owner, sorted by name. The claim carries
-- them as `permissions = {[name] = level}`; the level is read back through
-- the contract's permission() so the list shows what protection enforces.
local LEVEL_LABEL = {interact = "Interact", everything = "Everything"}

local function access_rows(claim)
	local rows = {}
	local map = type(claim.permissions) == "table" and claim.permissions or {}
	for name in pairs(map) do
		local level = grug_housing.permission(claim, name)
		if name ~= claim.owner and LEVEL_LABEL[level] then
			rows[#rows + 1] = {name = name, level = level}
		end
	end
	table.sort(rows, function(a, b) return a.name < b.name end)
	return rows
end

-- "4 min 05 s": the draft countdown, to the second.
local function countdown(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	return ("%d min %02d s"):format(math.floor(seconds / 60), seconds % 60)
end

-- R26 rulings 8-9: the draft's own form (redrawn every second while open).
local function draft_formspec(claim, session)
	local need = grug_housing.ACTIVATION_LUMPS
	local fs = {"formspec_version[4]size[10.75,4.9]",
		"label[0.4,0.5;" .. ui.esc("Your Claim Stone (draft, not active)") .. "]"}
	fs[#fs + 1] = ("label[0.4,1.05;%s]"):format(ui.text(
		"It protects nothing yet and crumbles in " ..
		countdown(grug_housing.draft_remaining(claim)) ..
		" unless you activate it.", ui.RED))
	fs[#fs + 1] = "label[0.4,1.5;" .. ui.esc(("Activation takes %d coal lumps or " ..
		"charcoal from your inventory"):format(need)) .. "]"
	fs[#fs + 1] = "label[0.4,1.9;" .. ui.esc(("(%s of fuel) and protects your " ..
		"home at once."):format(ui.format_remaining(need * grug_housing.LUMP_SECONDS))) .. "]"
	fs[#fs + 1] = ("button[0.4,2.3;4.2,0.7;activate;%s]"):format(
		ui.esc(("Activate (%d coal)"):format(need)))
	fs[#fs + 1] = "tooltip[activate;" .. ui.esc(("After activation the stone " ..
		"stays in place for %d hours."):format(
		grug_housing.PICKUP_LOCK_SECONDS / 3600)) .. "]"
	if session.message then
		fs[#fs + 1] = ("label[0.4,3.35;%s]"):format(ui.text(session.message,
			session.message_color))
	end
	fs[#fs + 1] = "button[0.4,3.8;3.1,0.8;pick_up;Pick up stone]"
	fs[#fs + 1] = "button_exit[7.25,3.8;3.1,0.8;close;Close]"
	return table.concat(fs)
end

local function fuel_section(fs, claim, inv)
	local left = grug_housing.is_active(claim) and
		(grug_housing.remaining_seconds(claim) or 0) or 0
	local lumps = ui.lumps(left)
	fs[#fs + 1] = "label[0.4,0.5;Your Claim Stone]"
	fs[#fs + 1] = "label[0.4,1.1;Fuel: coal lumps or charcoal]"
	fs[#fs + 1] = ("list[%s;%s;0.4,1.4;1,1;]"):format(inv, LIST)
	if lumps > 0 then
		-- The slot itself stays empty so coal and charcoal can both be put;
		-- the burning lumps are drawn over it (images take no clicks).
		fs[#fs + 1] = ("item_image[0.4,1.4;1,1;%s]"):format(ui.DISPLAY_FUEL)
		fs[#fs + 1] = ("label[%.2f,2.15;%d]"):format(lumps >= 10 and 1.0 or 1.12, lumps)
	end
	if left > 0 then
		fs[#fs + 1] = ("label[1.7,1.65;%s]"):format(ui.text(
			"Fuel left: " .. ui.format_remaining(left), left < ui.DAY and ui.RED or nil))
	else
		fs[#fs + 1] = ("label[1.7,1.65;%s]"):format(ui.text(
			"No fuel: anyone can access your home right now", ui.RED))
	end
	fs[#fs + 1] = "label[1.7,2.15;" ..
		ui.esc("One lump burns 7 h 16 min, 99 lumps about 30 days.") .. "]"
	local wait = grug_housing.pickup_wait(claim) or 0
	if wait > 0 then
		fs[#fs + 1] = "label[1.7,2.6;" .. ui.esc("Pick-up possible in " ..
			ui.format_remaining(wait) .. ".") .. "]"
	end
end

local function main_formspec(player, claim, session)
	session.draft = grug_housing.is_draft(claim)
	if session.draft then return draft_formspec(claim, session) end
	local name = player:get_player_name()
	local inv = "detached:" .. inventory_name(name)
	local fs = {"formspec_version[4]size[10.75,13]"}
	fuel_section(fs, claim, inv)

	local rows = access_rows(claim)
	session.names = {}
	local entries = {}
	for index, row in ipairs(rows) do
		session.names[index] = row.name
		entries[index] = ui.esc(row.name .. " — " .. LEVEL_LABEL[row.level])
	end
	if session.selected and not session.names[session.selected] then
		session.selected = nil
	end
	fs[#fs + 1] = "label[0.4,3.0;Access for other players]"
	if #entries == 0 then
		fs[#fs + 1] = "textlist[0.4,3.3;5.4,2.65;perm_list;#999999Nobody else has access.;0;false]"
	else
		fs[#fs + 1] = ("textlist[0.4,3.3;5.4,2.65;perm_list;%s;%d;false]"):format(
			table.concat(entries, ","), session.selected or 0)
	end
	fs[#fs + 1] = ("field[6.1,3.6;4.25,0.7;perm_name;Player name;%s]"):format(
		ui.esc(session.typed or ""))
	fs[#fs + 1] = "field_close_on_enter[perm_name;false]"
	fs[#fs + 1] = "button[6.1,4.45;2.05,0.7;perm_interact;Interact]"
	fs[#fs + 1] = "button[8.3,4.45;2.05,0.7;perm_everything;Everything]"
	fs[#fs + 1] = "button[6.1,5.25;4.25,0.7;perm_remove;Remove access]"
	fs[#fs + 1] = "tooltip[perm_interact;" ..
		ui.esc("Doors, gates, chests, furnaces and stations") .. "]"
	fs[#fs + 1] = "tooltip[perm_everything;Also building and digging]"
	if session.message then
		fs[#fs + 1] = ("label[0.4,6.3;%s]"):format(ui.text(session.message,
			session.message_color))
	end
	fs[#fs + 1] = "button[0.4,6.75;3.1,0.8;pick_up;Pick up stone]"
	local home = rawget(_G, "grug_home")
	if home and type(home.set_home_claim) == "function" then
		fs[#fs + 1] = "button[3.8,6.75;3.1,0.8;set_home;Set as home]"
	end
	fs[#fs + 1] = "button_exit[7.25,6.75;3.1,0.8;close;Close]"
	fs[#fs + 1] = "list[current_player;main;0.4,7.85;8,1;]"
	fs[#fs + 1] = "list[current_player;main;0.4,9.1;8,3;8]"
	fs[#fs + 1] = ("listring[%s;%s]listring[current_player;main]"):format(inv, LIST)
	return table.concat(fs)
end

local function confirm_formspec(draft)
	local lines = draft and
		("label[0.4,1.1;" .. ui.esc("It is not active yet; you can place it " ..
			"again at once.") .. "]") or
		("label[0.4,1.1;The protection ends at once. Whole unburnt lumps come back.]" ..
		"label[0.4,1.6;" .. ui.esc(("You can place it again at once; activation " ..
			"costs %d lumps again."):format(grug_housing.ACTIVATION_LUMPS)) .. "]")
	return "formspec_version[4]size[9.5,3.9]" ..
		"label[0.4,0.5;Pick up your Claim Stone?]" .. lines ..
		"button[0.4,2.6;4.2,0.8;confirm_pick_up;Pick up]" ..
		"button[4.9,2.6;4.2,0.8;cancel_pick_up;Cancel]"
end

local function notice_formspec(message, color)
	return "formspec_version[4]size[9.5,2.9]" ..
		("label[0.4,0.7;%s]"):format(ui.text(message, color)) ..
		"button_exit[3.15,1.6;3.2,0.8;ok;OK]"
end

local function show(player, session)
	local name = player:get_player_name()
	if session.mode == "confirm" then
		local claim = current_claim(player, session)
		core.show_formspec(name, FORMNAME, confirm_formspec(claim ~= nil and
			grug_housing.is_draft(claim)))
		return true
	end
	local claim = current_claim(player, session)
	if not claim then
		sessions[name] = nil
		core.close_formspec(name, FORMNAME)
		return false
	end
	core.show_formspec(name, FORMNAME, main_formspec(player, claim, session))
	return true
end

local function say(session, message, color)
	session.message = message
	session.message_color = color
end

-- Return the part of a put that add_fuel did not accept: into the inventory
-- (grug_inventory.give), and onto the ground beside the player when it is
-- full.
local function give_back(player, stack)
	if stack:is_empty() then return end
	local leftover = grug_inventory.give(player, stack)
	if not leftover:is_empty() then
		core.add_item(player:get_pos(), leftover)
	end
end

local function ensure_inventory(name)
	if detached[name] then return end
	detached[name] = core.create_detached_inventory(inventory_name(name), {
		allow_move = function() return 0 end,
		allow_take = function() return 0 end,
		allow_put = function(_, _, _, stack, player)
			if not grug_housing.is_fuel(stack:get_name()) or
					player:get_player_name() ~= name then
				return 0
			end
			local session = sessions[name]
			local claim = session and session.mode == "main" and
				current_claim(player, session)
			-- A draft takes no fuel: it is activated first (R26 ruling 9).
			if not claim or grug_housing.is_draft(claim) then return 0 end
			return stack:get_count()
		end,
		on_put = function(inv, listname, index, stack, player)
			-- The slot never keeps anything: the fuel is burnt into the claim
			-- or handed back.
			inv:set_stack(listname, index, ItemStack(""))
			local session = sessions[name]
			local claim = current_claim(player, session)
			local count = stack:get_count()
			local accepted = 0
			if claim then
				session.busy = true
				accepted = tonumber(grug_housing.add_fuel(claim, count)) or 0
				session.busy = nil
				accepted = math.max(0, math.min(count, math.floor(accepted)))
			end
			local rest = count - accepted
			if rest > 0 then
				give_back(player, ItemStack(stack:get_name() .. " " .. rest))
			end
			if not session then return end
			if accepted == 0 then
				say(session, ("The fuel slot is full (%d lumps)."):format(
					grug_housing.FUEL_MAX), ui.RED)
			elseif rest > 0 then
				say(session, ("Added %d, %d returned: the slot holds at most %d."):format(
					accepted, rest, grug_housing.FUEL_MAX))
			else
				say(session, ("Added %d."):format(accepted))
			end
			show(player, session)
		end,
	}, name)
	detached[name]:set_size(LIST, 1)
end

function grug_housing.open_stone_interface(player, claim)
	if not player or not player.is_player or not player:is_player() or
			type(claim) ~= "table" then
		return false
	end
	local name = player:get_player_name()
	if grug_housing.permission(claim, name) ~= "owner" then return false end
	ensure_inventory(name)
	local session = {claim_id = claim.id, mode = "main"}
	sessions[name] = session
	return show(player, session)
end

-- The typed name, else the selected row.
local function target_name(session, fields)
	local typed = (fields.perm_name or ""):trim()
	if typed ~= "" then return typed end
	return session.selected and session.names and session.names[session.selected]
end

local function set_access(player, session, claim, fields, level)
	local owner = player:get_player_name()
	local target = target_name(session, fields)
	if not target then
		say(session, "Type a player name or select one from the list.", ui.RED)
		return
	end
	if target == owner then
		say(session, "You own this claim.", ui.RED)
		return
	end
	local current = grug_housing.permission(claim, target)
	if level then
		if not core.player_exists(target) then
			say(session, "There is no player called " .. target .. ".", ui.RED)
			return
		end
		if current == level then
			say(session, target .. " already has " .. LEVEL_LABEL[level] .. ".")
			return
		end
	elseif not LEVEL_LABEL[current] then
		say(session, target .. " has no access.", ui.RED)
		return
	end
	session.busy = true
	local ok, message = grug_housing.set_permission(claim, target, level)
	session.busy = nil
	if ok then
		session.typed = nil
		session.selected = nil
		say(session, message or (level and (target .. ": " .. LEVEL_LABEL[level] .. ".")
			or (target .. " no longer has access.")))
	else
		say(session, message or "That did not work.", ui.RED)
	end
end

-- R26 ruling 9: the activation button pays the lumps from the inventory.
local function activate(player, session)
	session.busy = true
	local ok, message = grug_housing.activate(player)
	session.busy = nil
	say(session, message or (ok and "Your Claim Stone is active." or
		"The Claim Stone could not be activated."), not ok and ui.RED or nil)
end

local function pick_up(player, session)
	local name = player:get_player_name()
	if not current_claim(player, session) then
		sessions[name] = nil
		core.close_formspec(name, FORMNAME)
		return
	end
	session.busy = true
	local ok, message = grug_housing.pick_up(player)
	session.busy = nil
	if ok then
		sessions[name] = nil
		core.show_formspec(name, NOTICE, notice_formspec(
			message or "You picked up your Claim Stone."))
		return
	end
	session.mode = "main"
	say(session, message or "You cannot pick up the stone now.", ui.RED)
	show(player, session)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname == NOTICE then return true end
	if formname ~= FORMNAME then
		-- Fields from another form: ours is no longer open.
		sessions[player:get_player_name()] = nil
		return false
	end
	local name = player:get_player_name()
	local session = sessions[name]
	if not session then return true end
	if session.mode == "confirm" then
		if fields.confirm_pick_up then
			pick_up(player, session)
		elseif fields.cancel_pick_up then
			session.mode = "main"
			show(player, session)
		elseif fields.quit then
			sessions[name] = nil
		end
		return true
	end
	if fields.perm_name then session.typed = fields.perm_name end
	local claim = current_claim(player, session)
	if not claim then
		sessions[name] = nil
		if not fields.quit then core.close_formspec(name, FORMNAME) end
		return true
	end
	if fields.perm_list then
		local event = core.explode_textlist_event(fields.perm_list)
		if (event.type == "CHG" or event.type == "DCL") and session.names and
				session.names[event.index] then
			session.selected = event.index
			session.typed = session.names[event.index]
			say(session, nil)
			show(player, session)
		end
		return true
	end
	if fields.perm_interact then
		set_access(player, session, claim, fields, "interact")
	elseif fields.perm_everything then
		set_access(player, session, claim, fields, "everything")
	elseif fields.perm_remove then
		set_access(player, session, claim, fields, nil)
	elseif fields.activate then
		activate(player, session)
	elseif fields.pick_up then
		session.mode = "confirm"
	elseif fields.set_home then
		local home = rawget(_G, "grug_home")
		if home and type(home.set_home_claim) == "function" then
			local ok, message = home.set_home_claim(player, claim)
			if ok == false then
				say(session, message or "You cannot set your home here.", ui.RED)
			else
				say(session, message or "Your Claim Stone is now your home.")
			end
		end
	elseif fields.quit then
		sessions[name] = nil
		return true
	else
		-- Enter in the name field, or anything unknown: keep the form as is.
		return true
	end
	show(player, session)
	return true
end)

-- Every change of the claim redraws an open form; a claim that is gone closes
-- it. The acting player's own call (busy) redraws once, afterwards.
function ui.stone_claim_changed(claim, event)
	if type(claim) ~= "table" then return end
	for name, session in pairs(sessions) do
		if session.claim_id == claim.id and not session.busy then
			local player = core.get_player_by_name(name)
			if not player then
				sessions[name] = nil
			elseif event == "picked_up" or event == "destroyed" or
					event == "removed" or event == "draft_expired" then
				sessions[name] = nil
				core.close_formspec(name, FORMNAME)
			elseif session.mode == "main" then
				show(player, session)
			end
		end
	end
end

local function forget(player)
	local name = player:get_player_name()
	sessions[name] = nil
	if detached[name] then
		core.remove_detached_inventory(inventory_name(name))
		detached[name] = nil
	end
end
core.register_on_leaveplayer(forget)
core.register_on_dieplayer(function(player)
	local name = player:get_player_name()
	if sessions[name] then
		sessions[name] = nil
		core.close_formspec(name, FORMNAME)
	end
end)

-- R26: the draft countdown counts down while the form is open. Only players
-- whose open stone form currently shows a draft are redrawn, once a second;
-- closing the form, activating, picking up or the draft's expiry ends it
-- (the session is gone or no longer a draft).
local DRAFT_TICK = 1
local draft_elapsed = 0
core.register_globalstep(function(dtime)
	draft_elapsed = draft_elapsed + dtime
	if draft_elapsed < DRAFT_TICK then return end
	draft_elapsed = 0
	for name, session in pairs(sessions) do
		if session.draft and session.mode == "main" and not session.busy then
			local player = core.get_player_by_name(name)
			if player then show(player, session) else sessions[name] = nil end
		end
	end
end)

-- Test seam for tools/r25_interfaces (read-only views of the session state).
ui.stone_sessions = sessions
ui.stone_formname = FORMNAME

end
