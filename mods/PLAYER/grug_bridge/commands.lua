-- The website's commands (docs/technical/web-bridge.md "Commands"): each
-- checks its arguments, which are untrusted input, and answers a result code
-- and a message for the administrator. An error raised here is caught by the
-- caller (link.lua).

local M = grug_mail.model

local C = {}

C.CAPABILITIES = {"online", "kick", "banlist", "chat", "mail", "action.give_money",
	"action.give_xp", "action.give_item", "action.grant_priv", "action.revoke_priv"}

C.REASON_MAX = 200
C.CHAT_MAX = 500
C.ADMIN_MAX = 64
C.AMOUNT_MAX = 1000000

-- One line of plain text: colour and translation escapes go whole, then what
-- M.clean removes from a player's text. Without `max` nothing is cut.
function C.plain(text, max)
	text = tostring(text or ""):gsub("\27%(.-%)", ""):gsub("\27.?", "")
	return M.clean(text, max, false)
end

--
-- Arguments
--

local function invalid(what)
	return "invalid_args", "Invalid " .. what .. "."
end

-- An optional or required one-line text within `max`: the plain text, or nil
-- when it is missing, empty or too long.
local function line(value, max)
	if type(value) ~= "string" then return nil end
	local text = C.plain(value)
	if text == "" or M.text_length(text) > max then return nil end
	return text
end

local function whole_number(value, max)
	return type(value) == "number" and value == math.floor(value) and
		value >= 1 and value <= max
end

local function subject_of(args)
	if type(args.subject) ~= "string" then return nil end
	local subject = M.clean(args.subject, nil, false)
	if subject == "" or M.text_length(subject) > M.SUBJECT_MAX then return nil end
	return subject
end

-- The body as it will be stored; nil and a refusal when empty or too long.
local function body_of(args)
	if type(args.body) ~= "string" then return nil, "Invalid body." end
	local text, refusal = M.check_body(args.body)
	if not text then return nil, refusal end
	if text == "" then return nil, "The body is empty." end
	return text
end

-- An online player: the player, or nil, a code and a message.
local function online(args)
	local name = args.name
	if type(name) ~= "string" or name == "" then
		return nil, invalid("name")
	end
	local player = core.get_player_by_name(name)
	if player then return player end
	if core.player_exists(name) then
		return nil, "not_online", name .. " is not online."
	end
	return nil, "unknown_target", "There is no character called " .. name .. "."
end

-- An online player with a finished character: a character being created
-- stores nothing (grug_classes/selection.lua), a grant included.
local function character(args)
	local player, code, message = online(args)
	if not player then return nil, code, message end
	if not grug_mail.character_ready(player) then
		return nil, "refused", args.name .. " is still creating a character."
	end
	return player
end

--
-- The command types
--

local TYPES = {}

TYPES["kick"] = function(args)
	local player, code, message = online(args)
	if not player then return code, message end
	local reason
	if args.reason ~= nil then
		-- An empty reason is no reason.
		if type(args.reason) ~= "string" then return invalid("reason") end
		reason = C.plain(args.reason)
		if M.text_length(reason) > C.REASON_MAX then return invalid("reason") end
		if reason == "" then reason = nil end
	end
	core.kick_player(args.name, reason)
	return "ok", args.name .. " was kicked."
end

TYPES["chat.send"] = function(args)
	local admin = line(args.admin, C.ADMIN_MAX)
	if not admin then return invalid("admin") end
	local text = line(args.text, C.CHAT_MAX)
	if not text then return invalid("text") end
	core.chat_send_all("[Admin]<" .. admin .. "> " .. text)
	return "ok", ""
end

-- The ticket a command names: the ticket, or nil, a code and a message.
local function ticket_of(args)
	if not whole_number(args.ticket_id, math.huge) then
		return nil, invalid("ticket_id")
	end
	local ticket = grug_mail.ticket(args.ticket_id)
	if not ticket then
		return nil, "unknown_target", "That message is gone."
	end
	return ticket
end

TYPES["mail.answer"] = function(args)
	local admin = line(args.admin, C.ADMIN_MAX)
	if not admin then return invalid("admin") end
	local ticket, code, message = ticket_of(args)
	if not ticket then return code, message end
	if ticket.state ~= "open" then return "refused", "That message is already closed." end
	local body, refusal = body_of(args)
	if not body then return "invalid_args", refusal end
	local ok, failure = grug_mail.answer_ticket(ticket.id, admin, body)
	if not ok then return "refused", failure end
	return "ok", "Answer sent to " .. ticket.from .. "."
end

TYPES["mail.close"] = function(args)
	local admin = line(args.admin, C.ADMIN_MAX)
	if not admin then return invalid("admin") end
	local ticket, code, message = ticket_of(args)
	if not ticket then return code, message end
	local ok, failure = grug_mail.close_ticket(ticket.id, admin, false)
	if not ok then return "refused", failure end
	return "ok", ""
end

TYPES["mail.delete"] = function(args)
	local admin = line(args.admin, C.ADMIN_MAX)
	if not admin then return invalid("admin") end
	local ticket, code, message = ticket_of(args)
	if not ticket then return code, message end
	local ok, failure = grug_mail.delete_ticket(ticket.id, admin)
	if not ok then return "refused", failure end
	return "ok", ""
end

TYPES["mail.send"] = function(args)
	local admin = line(args.admin, C.ADMIN_MAX)
	if not admin then return invalid("admin") end
	local to = line(args.to, 40)
	if not to then return invalid("to") end
	local subject = subject_of(args)
	if not subject then return invalid("subject") end
	-- Checked here: send_system would cut.
	local body, refusal = body_of(args)
	if not body then return "invalid_args", refusal end
	local ok, result = grug_mail.send_system(to, "admin", M.ADMIN_LABEL, subject, body)
	if not ok then return "unknown_target", result end
	core.log("action", ("[grug_bridge] admin %s wrote admin letter #%d to %s"):format(
		admin, result, to))
	return "ok", "Letter sent to " .. to .. "."
end

TYPES["mail.broadcast"] = function(args)
	local admin = line(args.admin, C.ADMIN_MAX)
	if not admin then return invalid("admin") end
	local subject = subject_of(args)
	if not subject then return invalid("subject") end
	local body, refusal = body_of(args)
	if not body then return "invalid_args", refusal end
	local id, failure = grug_mail.send_broadcast(subject, body, admin)
	if not id then return "refused", failure end
	return "ok", ""
end

TYPES["mail.broadcast_delete"] = function(args)
	local admin = line(args.admin, C.ADMIN_MAX)
	if not admin then return invalid("admin") end
	if not whole_number(args.broadcast_id, math.huge) then return invalid("broadcast_id") end
	local ok, failure = grug_mail.delete_broadcast(args.broadcast_id, admin)
	if not ok then return "unknown_target", failure end
	return "ok", ""
end

local function gift_notice(player, text)
	grug_core.feed(player, "notice", "An administrator gave you " .. text .. ".")
end

TYPES["action.give_money"] = function(args)
	local player, code, message = character(args)
	if not player then return code, message end
	if not whole_number(args.copper, C.AMOUNT_MAX) then return invalid("copper") end
	local balance = grug_money.add(player, args.copper)
	gift_notice(player, grug_money.format(args.copper))
	return "ok", args.name .. " now carries " .. grug_money.format(balance) .. "."
end

TYPES["action.give_xp"] = function(args)
	local player, code, message = character(args)
	if not player then return code, message end
	if not whole_number(args.amount, C.AMOUNT_MAX) then return invalid("amount") end
	-- No source: no race bonus. The feed shows the XP itself.
	local ok, granted = grug_xp.add_xp(player, args.amount)
	if not ok then return "refused", "The game refused the amount." end
	return "ok", ("%d XP granted, %s is level %d."):format(granted, args.name,
		grug_xp.get_level(player))
end

-- Registered, but nothing a grant can hand out: the engine's own entries. A
-- skill or a mount item is a binding of the hotbar and an empty Bag of Coins
-- is worth nothing, so those are refused below.
local NOT_GIVEN = {[""] = true, air = true, ignore = true, unknown = true}

TYPES["action.give_item"] = function(args)
	local player, code, message = character(args)
	if not player then return code, message end
	local item = args.item
	if type(item) ~= "string" then return invalid("item") end
	-- rawget: the table's index answers an alias with the item behind it.
	if NOT_GIVEN[item] or not rawget(core.registered_items, item) then
		return "unknown_target", "There is no item called " .. item .. "."
	end
	if core.get_item_group(item, "grug_bound_skill") > 0 or item == grug_money.BAG then
		return "refused", "That item cannot be given."
	end
	local stack = ItemStack(item)
	if not whole_number(args.count, stack:get_stack_max()) then return invalid("count") end
	stack:set_count(args.count)
	if not grug_inventory.fits(player, {stack}) then
		return "refused", args.name .. " has no room for that."
	end
	local leftover = grug_inventory.give(player, stack)
	-- The fit check makes this unreachable; never lose an item if it is not.
	if not leftover:is_empty() then core.add_item(player:get_pos(), leftover) end
	gift_notice(player, (stack:get_short_description() or item) .. " x" .. args.count)
	return "ok", ("%d x %s given to %s."):format(args.count, item, args.name)
end

-- The privilege a command names: the name, or nil, a code and a message.
local function privilege_of(args)
	if type(args.priv) ~= "string" or args.priv == "" then return nil, invalid("priv") end
	if not core.registered_privileges[args.priv] then
		return nil, "unknown_target", "There is no privilege called " .. args.priv .. "."
	end
	return args.priv
end

TYPES["action.grant_priv"] = function(args)
	local player, code, message = online(args)
	if not player then return code, message end
	local priv
	priv, code, message = privilege_of(args)
	if not priv then return code, message end
	local privs = core.get_player_privs(args.name)
	if privs[priv] then return "ok", args.name .. " already has " .. priv .. "." end
	privs[priv] = true
	core.set_player_privs(args.name, privs) -- runs the on_grant callbacks
	return "ok", args.name .. " now has " .. priv .. "."
end

TYPES["action.revoke_priv"] = function(args)
	local player, code, message = online(args)
	if not player then return code, message end
	local priv
	priv, code, message = privilege_of(args)
	if not priv then return code, message end
	local privs = core.get_player_privs(args.name)
	if not privs[priv] then return "ok", args.name .. " does not have " .. priv .. "." end
	privs[priv] = nil
	core.set_player_privs(args.name, privs) -- runs the on_revoke callbacks
	-- The server's admin always holds the give_to_admin privileges.
	if core.get_player_privs(args.name)[priv] then
		return "refused", args.name .. " keeps " .. priv .. " as the server's admin."
	end
	return "ok", args.name .. " no longer has " .. priv .. "."
end

-- A code and a message for `command`.
function C.run(command)
	local run = TYPES[command.type]
	if not run then
		return "unsupported", "Unknown command type: " .. tostring(command.type)
	end
	if type(command.args) ~= "table" then return invalid("args") end
	return run(command.args)
end

return C
