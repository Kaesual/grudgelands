-- Lane C: stone formspec, Housing Manager dialog and character-page status
-- (rulings 13-14). Codes against the interface contract in api.lua only.
--
--   interface.lua    shared text helpers and the character-page status
--   stone_form.lua   the owner's stone formspec (fuel, access list, pick up)
--   manager.lua      the Housing Manager in the six capitals

local ui = {}

-- Fuel kinds and the lump duration come from the claim core (api.lua):
-- grug_housing.is_fuel, LUMP_SECONDS and FUEL_MAX. The fuel slot shows the
-- unburnt lumps, ceil(remaining / LUMP_SECONDS).
ui.DAY = 86400
ui.RED = "#ff6060"
ui.GREEN = "#8fdc7a"
ui.DISPLAY_FUEL = "default:coal_lump"

function ui.esc(text)
	return (core.formspec_escape(tostring(text or "")))
end

-- A label's text, escaped and, when a colour is given, coloured.
function ui.text(text, color)
	local escaped = ui.esc(text)
	if color then return core.colorize(color, escaped) end
	return escaped
end

-- "12 d 4 h 31 min", to the minute (floored); "< 1 min" for the last seconds.
function ui.format_remaining(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	local minutes = math.floor(seconds / 60)
	if minutes == 0 then return seconds > 0 and "< 1 min" or "0 min" end
	local days = math.floor(minutes / 1440)
	local hours = math.floor((minutes % 1440) / 60)
	minutes = minutes % 60
	if days > 0 then return ("%d d %d h %d min"):format(days, hours, minutes) end
	if hours > 0 then return ("%d h %d min"):format(hours, minutes) end
	return ("%d min"):format(minutes)
end

function ui.lumps(seconds)
	seconds = math.max(0, tonumber(seconds) or 0)
	return math.ceil(seconds / grug_housing.LUMP_SECONDS)
end

-- Greedy word wrap into at most `width` characters per line.
function ui.wrap(text, width)
	local lines, line = {}, ""
	for word in tostring(text or ""):gmatch("%S+") do
		if line ~= "" and #line + 1 + #word > width then
			lines[#lines + 1] = line
			line = word
		else
			line = line == "" and word or line .. " " .. word
		end
	end
	if line ~= "" then lines[#lines + 1] = line end
	return lines
end

--
-- Character page status (ruling 14). Shown once the player has received a
-- stone (state is not "never"); read from the claim registry only, so it is
-- the same wherever the player is.
--

-- nil, or {text = ..., color = nil or ui.RED}.
function grug_housing.character_status(name)
	local claim, state = grug_housing.player_claim(name)
	if state == "placed" and claim then
		if grug_housing.is_active(claim) then
			local left = grug_housing.remaining_seconds(claim) or 0
			return {text = "Claim Stone fuel: " .. ui.format_remaining(left),
				color = left < ui.DAY and ui.RED or nil}
		end
		return {text = "Your Claim Stone needs fuel, anyone can access your home right now",
			color = ui.RED}
	elseif state == "destroyed" then
		return {text = "Your Claim Stone has been destroyed", color = ui.RED}
	elseif state == "carried" then
		return {text = "Your Claim Stone is in your inventory, not placed yet"}
	elseif state == "needs_stone" then
		return {text = "You have no Claim Stone; ask a Housing Manager for a new one"}
	end
	return nil
end

-- Legacy-coordinate labels for the Character page at (x, y); "" when there is
-- nothing to show. Wrapped to the free column between the model and the gear.
local STATUS_WIDTH, STATUS_STEP = 36, 0.45

function grug_housing.character_status_formspec(name, x, y)
	local status = grug_housing.character_status(name)
	if not status then return "" end
	local fs = {}
	for index, line in ipairs(ui.wrap(status.text, STATUS_WIDTH)) do
		fs[index] = ("label[%.2f,%.2f;%s]"):format(x, y + (index - 1) * STATUS_STEP,
			ui.text(line, status.color))
	end
	return table.concat(fs)
end

-- The Character page is a cached inventory formspec; it is rebuilt only when
-- the status text actually changes (claim events, and a slow poll for the
-- minute countdown and for state changes without a claim event).
local shown = {}

local function status_key(name)
	local status = grug_housing.character_status(name)
	if not status then return "" end
	return status.text .. "|" .. (status.color or "")
end

function ui.refresh_character(player)
	local name = player:get_player_name()
	local key = status_key(name)
	if shown[name] == key then return end
	shown[name] = key
	local sfinv = rawget(_G, "sfinv")
	local context = sfinv and sfinv.contexts and sfinv.contexts[name]
	if context and context.page == "grug_inventory:character" then
		-- Suspended (character creation) inventories are left alone by sfinv.
		sfinv.set_player_inventory_formspec(player, context)
	end
end

local POLL_SECONDS = 10
local poll = 0
core.register_globalstep(function(dtime)
	poll = poll + dtime
	if poll < POLL_SECONDS then return end
	poll = 0
	for _, player in ipairs(core.get_connected_players()) do
		ui.refresh_character(player)
	end
end)

core.register_on_joinplayer(function(player)
	-- The page sfinv builds on join already carries the current status.
	local name = player:get_player_name()
	shown[name] = status_key(name)
end)

core.register_on_leaveplayer(function(player)
	shown[player:get_player_name()] = nil
end)

local path = core.get_modpath("grug_housing")
dofile(path .. "/stone_form.lua")(ui)
dofile(path .. "/manager.lua")(ui)

grug_housing.register_on_claim_changed(function(claim, event)
	ui.stone_claim_changed(claim, event)
	local owner = claim and claim.owner and core.get_player_by_name(claim.owner)
	if owner then ui.refresh_character(owner) end
end)
