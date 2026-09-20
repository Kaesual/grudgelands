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
	for _, socket in ipairs(grug_core.settlement_sockets_at(provider.settlement)) do
		if socket.id == provider.socket and socket.role == "trainer" and
				socket.profession == provider.profession then
			return distance_squared(position, socket.pos) <= 4
		end
	end
	return false
end)

function grug_repair.can_open_trainer(player, entity)
	return grug_repair.provider_permitted(player, trainer_provider(entity))
end

local function esc(text) return core.formspec_escape(tostring(text)) end

local function form(session)
	local quote = session.quote
	local pages = math.max(1, math.ceil(#quote.items / PAGE_SIZE))
	session.page = math.max(1, math.min(pages, session.page))
	local fs = {"formspec_version[4]size[11,9]",
		"label[0.4,0.4;Equipment repairs]",
		"label[0.4,0.9;All professions can repair your equipment for money.]"}
	local first = (session.page - 1) * PAGE_SIZE + 1
	for i = first, math.min(#quote.items, first + PAGE_SIZE - 1) do
		local row = quote.items[i]
		local stack, y = row.expected, 1.6 + (i - first) * 0.72
		local label = stack:get_description():match("^[^\n]+") or stack:get_name()
		local percent = math.floor((65535 - stack:get_wear()) * 100 / 65535)
		fs[#fs + 1] = ("item_image[0.4,%.2f;0.6,0.6;%s]"):format(y, esc(stack:get_name()))
		fs[#fs + 1] = ("label[1.2,%.2f;%s (%d%%)]"):format(y + 0.22, esc(label), percent)
		fs[#fs + 1] = ("button[7.8,%.2f;2.7,0.6;repair_%d;Repair %s]")
			:format(y, i, esc(grug_money.format(row.price)))
	end
	if #quote.items == 0 then fs[#fs + 1] = "label[0.4,2;Nothing needs repair.]" end
	fs[#fs + 1] = ("button[0.4,7.75;3.4,0.7;all;Repair all: %s]")
		:format(esc(grug_money.format(quote.total)))
	fs[#fs + 1] = "button[4,7.75;0.7,0.7;previous;<]button[6.5,7.75;0.7,0.7;next;>]"
	fs[#fs + 1] = ("label[5,8.1;%d / %d]"):format(session.page, pages)
	fs[#fs + 1] = "button_exit[8.5,7.75;2,0.7;close;Close]"
	return table.concat(fs)
end

function grug_repair.open(player, provider)
	local quote, reason = grug_repair.quote(player, provider)
	if not quote then return false, reason end
	serial = serial + 1
	local session = {quote = quote, page = 1, formname = PREFIX .. serial}
	sessions[player:get_player_name()] = session
	core.show_formspec(player:get_player_name(), session.formname, form(session))
	return true
end

function grug_repair.open_trainer(player, entity)
	return grug_repair.open(player, trainer_provider(entity))
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
		core.show_formspec(name, formname, form(session))
	end
	return true
end)

local function clear(player) sessions[player:get_player_name()] = nil end
core.register_on_leaveplayer(clear)
core.register_on_dieplayer(clear)
