local sessions, serial = {}, 0
local PREFIX = "grug_repair:service:"
local PAGE_SIZE = 8

local function distance_squared(a, b)
	if not a or not b then return math.huge end
	return (a.x - b.x)^2 + (a.y - b.y)^2 + (a.z - b.z)^2
end

local function trainer_provider(entity)
	if not entity then return nil end
	return {kind = "trainer", entity = entity, object = entity.object,
		settlement = entity._grug_start, socket = entity._grug_socket,
		profession = entity._grug_profession}
end

grug_repair.register_provider("trainer", function(player, provider)
	local entity, object = provider.entity, provider.object
	if not entity or not object or entity.object ~= object or
			object:get_luaentity() ~= entity or entity._grug_socket_role ~= "trainer" or
			entity._grug_start ~= provider.settlement or entity._grug_socket ~= provider.socket or
			entity._grug_profession ~= provider.profession or
			not grug_jobs.PROFESSIONS[provider.profession] then return false end
	local position = object:get_pos()
	if distance_squared(player:get_pos(), position) > 64 then return false end
	local race
	for _, settlement in ipairs(grug_core.settlement_socket_settlements()) do
		if settlement.key == provider.settlement then race = settlement.race_id break end
	end
	local definition = race and grug_classes.registered_races[race]
	if not definition or grug_factions.get_faction(player) ~= definition.faction then
		return false
	end
	-- Every trainer socket repairs, the mender on a socket whose profession
	-- no trainer teaches (Round 45, Cooking) included.
	for _, socket in ipairs(grug_core.settlement_sockets_at(provider.settlement)) do
		if socket.id == provider.socket and socket.role == "trainer" and
				socket.profession == provider.profession then
			return distance_squared(position, socket.pos) <= 4
		end
	end
	return false
end)

-- Repair happens in towns (Round 46 ruling 16; the claim stations' repair
-- of Round 29 is gone) and, since Round 58, at the Miner's Guild's camp
-- vendors (below).
function grug_repair.can_open_trainer(player, entity)
	return grug_repair.provider_permitted(player, trainer_provider(entity))
end

-- The camp vendor (Round 58, miners_guild.md §3: "each camp has ... a
-- vendor who ... repairs"): the provider is the `vendor_camp` socket the
-- vendor stands on, by settlement key and socket id (plain strings; the
-- vendor window holds no ObjectRef). Every action re-checks that the socket
-- is a camp vendor socket, that the player stands within 8 nodes of it and
-- belongs to the camp's faction (the race the camp is registered as).
local function camp_vendor_provider(settlement, socket)
	if type(settlement) ~= "string" or type(socket) ~= "string" then return nil end
	return {kind = "camp_vendor", settlement = settlement, socket = socket}
end

grug_repair.register_provider("camp_vendor", function(player, provider)
	local race
	for _, settlement in ipairs(grug_core.settlement_socket_settlements()) do
		if settlement.key == provider.settlement then race = settlement.race_id break end
	end
	local definition = race and grug_classes.registered_races[race]
	if not definition or grug_factions.get_faction(player) ~= definition.faction then
		return false
	end
	for _, socket in ipairs(grug_core.settlement_sockets_at(provider.settlement)) do
		if socket.id == provider.socket and socket.role == "vendor" and socket.kind == "camp" then
			return distance_squared(player:get_pos(), socket.pos) <= 64
		end
	end
	return false
end)

function grug_repair.can_open_camp_vendor(player, settlement, socket)
	return grug_repair.provider_permitted(player, camp_vendor_provider(settlement, socket))
end

local function esc(text) return core.formspec_escape(tostring(text)) end

-- The mender (0.45.1, fix plan row 12): a trainer provider whose profession
-- no trainer teaches (grug_jobs.trainer_teaches). Its form is titled
-- grug_jobs.MENDER_TITLE (the user, 2026-10-10) and shows
-- grug_jobs.GREETINGS.mender below the title, one label per wrapped line;
-- everything below moves down by the greeting's height. A teaching
-- trainer's "Repair equipment" form keeps the plain title and shows no
-- greeting.
local function is_mender(provider)
	return provider.kind == "trainer" and not grug_jobs.trainer_teaches(provider.profession)
end

-- Shared content for standalone services and the trader's Repair tab. The
-- caller retains the server-owned quote; this renderer cannot authorize repair.
function grug_repair.quote_formspec(quote, page, width, top, footer, action_prefix)
	action_prefix = action_prefix or ""
	local pages = math.max(1, math.ceil(#quote.items / PAGE_SIZE))
	page = math.max(1, math.min(pages, page or 1))
	local fs = {}
	local first = (page - 1) * PAGE_SIZE + 1
	for i = first, math.min(#quote.items, first + PAGE_SIZE - 1) do
		local row = quote.items[i]
		local stack, y = row.expected, top + (i - first) * 0.75
		local label = stack:get_description():match("^[^\n]+") or stack:get_name()
		local percent = math.floor((65535 - stack:get_wear()) * 100 / 65535)
		fs[#fs + 1] = ("item_image[0.5,%.2f;0.6,0.6;%s]"):format(y, esc(stack:get_name()))
		fs[#fs + 1] = ("tooltip[0.5,%.2f;0.6,0.6;%s]"):format(y, esc(stack:get_description()))
		fs[#fs + 1] = ("label[1.3,%.2f;%s]"):format(y + 0.3, esc(label))
		fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(width - 5.8, y + 0.3,
			esc("Durability " .. percent .. "%"))
		fs[#fs + 1] = ("button[%.2f,%.2f;2.35,0.55;%srepair_%d;Repair %s]")
			:format(width - 2.85, y, action_prefix, i, esc(grug_money.format(row.price)))
	end
	if #quote.items == 0 then fs[#fs + 1] = ("label[0.5,%.2f;Nothing needs repair.]"):format(top + 0.3) end
	fs[#fs + 1] = ("button[%.2f,%.2f;3.5,0.6;%sall;Repair all: %s]")
		:format(width - 4, footer, action_prefix, esc(grug_money.format(quote.total)))
	fs[#fs + 1] = ("button[%.2f,%.2f;0.7,0.6;previous;<]button[%.2f,%.2f;0.7,0.6;next;>]")
		:format(width / 2 - 1.6, footer, width / 2 + 0.9, footer)
	fs[#fs + 1] = ("label[%.2f,%.2f;%d / %d]"):format(width / 2 - 0.55, footer + 0.3, page, pages)
	return table.concat(fs), page
end

local function form(session, player)
	local quote = session.quote
	local mender = is_mender(quote.provider)
	local greeting = mender and grug_jobs.GREETINGS and grug_jobs.GREETINGS.mender
	local width, top = 16, 2.2
	local fs = {"", grug_core.ui.service_header(width, mender and grug_jobs.MENDER_TITLE or
		"Equipment repairs", "Restore your equipment")}
	local info_y = 1.55
	if greeting then
		for piece in (grug_inventory.wrap_text(greeting, 67) .. "\n"):gmatch("(.-)\n") do
			fs[#fs + 1] = ("label[0.5,%.2f;%s]"):format(info_y, esc(piece))
			info_y = info_y + 0.42
		end
		info_y = info_y + 0.1
	end
	fs[#fs + 1] = ("label[0.5,%.2f;%s]"):format(info_y, esc(quote.provider.kind == "camp_vendor" and
		"The camp vendor repairs your equipment for money." or "All professions can repair your equipment for money."))
	top = info_y + 0.65
	local footer = top + math.max(1, math.min(PAGE_SIZE, #quote.items)) * 0.75 + 0.4
	local body
	body, session.page = grug_repair.quote_formspec(quote, session.page, width, top, footer)
	fs[#fs + 1] = body
	fs[#fs + 1] = ("button_exit[0.5,%.2f;2,0.6;close;Close]"):format(footer)
	fs[1] = grug_core.ui.frame(width, footer + 1.0, nil, nil, player)
	return table.concat(fs)
end

-- The trader embeds the quote in its own session; all provider authorization
-- still goes through the same authoritative camp socket validator.
function grug_repair.camp_vendor_quote(player, settlement, socket)
	return grug_repair.quote(player, camp_vendor_provider(settlement, socket))
end

function grug_repair.open(player, provider)
	local quote, reason = grug_repair.quote(player, provider)
	if not quote then return false, reason end
	serial = serial + 1
	local session = {quote = quote, page = 1, formname = PREFIX .. serial}
	sessions[player:get_player_name()] = session
	core.show_formspec(player:get_player_name(), session.formname, form(session, player))
	return true
end

function grug_repair.open_trainer(player, entity)
	return grug_repair.open(player, trainer_provider(entity))
end

-- The camp vendor window's Repair button (grug_traders/trade.lua).
function grug_repair.open_camp_vendor(player, settlement, socket)
	return grug_repair.open(player, camp_vendor_provider(settlement, socket))
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname:sub(1, #PREFIX) ~= PREFIX then return false end
	local name = player:get_player_name()
	local session = sessions[name]
	if not session or session.formname ~= formname then return true end
	if fields.quit or not grug_repair.provider_permitted(player, session.quote.provider) then
		sessions[name] = nil
		return true
	end
	local selected, count
	count = fields.all and 1 or 0
	for i = 1, #session.quote.items do
		if fields["repair_" .. i] then selected, count = i, count + 1 end
	end
	if count > 1 then return true end
	if count == 1 then
		local quote = selected and grug_repair.single_quote(session.quote, selected) or session.quote
		local _, reason = grug_repair.apply(player, quote)
		core.chat_send_player(name, reason)
		sessions[name] = nil
		grug_repair.open(player, session.quote.provider)
	elseif fields.next or fields.previous then
		session.page = session.page + (fields.next and 1 or -1)
		core.show_formspec(name, formname, form(session, player))
	end
	return true
end)

local function clear(player) sessions[player:get_player_name()] = nil end
core.register_on_leaveplayer(clear)
core.register_on_dieplayer(clear)
