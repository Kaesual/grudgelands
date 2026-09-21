return function(repo)
repo = assert(repo, "repository path required")
local env = {}; setmetatable(env, {__index = _G}); env._G = env

local function player(name, faction, invites)
	return {name = name, faction = faction, invites = invites ~= false,
		get_player_name = function(self) return self.name end}
end

local me = player("Me", "accord")
local alpha = player("Alpha", "accord", false)
local escaped = player("A,lice]", "accord")
local party = player("Party", "accord")
local zebra = player("Zebra", "accord")
local hostile = player("Hostile", "throng")
local connected = {zebra, hostile, me, party, escaped, alpha}
local context = {page = "grug_parties:group"}
local page, change_callback
local invited = {}

local function formspec_escape(value)
	return tostring(value):gsub("\\", "\\\\"):gsub("%]", "\\]")
		:gsub("%[", "\\["):gsub(";", "\\;"):gsub(",", "\\,")
end

env.core = {
	formspec_escape = formspec_escape,
	get_connected_players = function() return connected end,
	get_player_by_name = function(name)
		for _, p in ipairs(connected) do if p.name == name then return p end end
	end,
	explode_textlist_event = function(value)
		local kind, index = value:match("^(%u+):(%d+)$")
		return {type = kind, index = tonumber(index)}
	end,
	register_on_mods_loaded = function() end,
}
env.grug_factions = {get_faction = function(p) return p and p.faction end}
env.grug_parties = {
	view = function(who)
		local name = type(who) == "string" and who or who.name
		if name == "Party" then
			return {leader = "Party", members = {{name = "Party", online = true, hp = 20, hp_max = 20}}}
		end
	end,
	pending = function() return {} end,
	invitations_enabled = function(p) return p.invites ~= false end,
	hud_enabled = function() return true end,
	invite = function(_, name)
		invited[#invited + 1] = name
		if not env.core.get_player_by_name(name) then return false, "Both players must be online." end
		if env.core.get_player_by_name(name).faction ~= me.faction then
			return false, "Party members must belong to the same faction."
		end
		return true, "Invitation sent."
	end,
	accept = function() return false, "unused" end,
	decline = function() return false, "unused" end,
	leave = function() return false, "unused" end,
	kick = function() return false, "unused" end,
	transfer_leader = function() return false, "unused" end,
	set_invitations_enabled = function() return true, "updated" end,
	set_hud_enabled = function() return true, "updated" end,
	register_on_change = function(callback) change_callback = callback end,
}
env.sfinv = {
	pages = {}, pages_unordered = {},
	register_page = function(name, definition)
		definition.name = name; page = definition
	end,
	make_formspec = function(_, _, content) return content end,
	get_page = function() return context.page end,
	set_page = function(p, name)
		context.page = name
		if name == "grug_parties:group" then page:on_enter(p, context) end
	end,
}

local chunk = assert(loadfile(repo .. "/mods/PLAYER/grug_parties/ui.lua"))
setfenv(chunk, env); chunk()
assert(page and change_callback)
page:on_enter(me, context)

local names = {}
for index, row in ipairs(context.grug_party_online_rows) do names[index] = row.name end
assert(table.concat(names, "|") == "A,lice]|Alpha|Party|Zebra")
assert(context.grug_party_online == "A,lice]")
local form = page:get(me, context)
assert(form:find("real_coordinates[true]", 1, true))
assert(form:find("A\\,lice\\]", 1, true), "roster label was not formspec escaped")
assert(form:find("Alpha (Invites off)", 1, true))
assert(form:find("Party (In party)", 1, true))
assert(not form:find("Hostile", 1, true) and not form:find("Me;", 1, true))
for kind, x, y, w, h in form:gmatch("([%a_]+)%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);") do
	if kind == "button" or kind == "textlist" or kind == "textarea" then
		assert(tonumber(y) + tonumber(h) < 7.2 * 15 / 13, "Group control overlaps inventory")
	end
end

-- Choose Zebra from the displayed snapshot, then change the online roster.
page:on_player_receive_fields(me, context, {grug_party_online_list = "CHG:4"})
assert(context.grug_party_online == "Zebra")
local aaron = player("Aaron", "accord")
connected = {alpha, party, me, hostile, zebra, escaped, aaron}
page:on_player_receive_fields(me, context, {grug_party_refresh = "Refresh"})
assert(context.grug_party_online == "Zebra", "online selection did not survive reorder")
connected = {aaron, me, alpha, hostile, party, escaped}
page:on_player_receive_fields(me, context, {grug_party_invite = "Invite"})
assert(invited[#invited] == "Zebra", "changed roster reinterpreted the old row index")
assert(context.grug_party_notice == "Refused: Both players must be online.")

-- The action refresh takes a new sorted snapshot and cannot retain the stale name.
names = {}
for index, row in ipairs(context.grug_party_online_rows) do names[index] = row.name end
assert(table.concat(names, "|") == "A,lice]|Aaron|Alpha|Party")
assert(context.grug_party_online == nil, "vanished selection redirected to another player")
assert(not context.grug_party_online_rows[5])
form = page:get(me, context)
assert(form:find(";-1;false]", 1, true), "lost selection did not clear the client highlight")
local calls = #invited
page:on_player_receive_fields(me, context, {grug_party_invite = "Invite"})
assert(#invited == calls and context.grug_party_notice ==
	"Refused: Select an online same-faction player.")

return "r15_group_roster PASS sorted=4 self=excluded hostile=excluded stale=safe status=shown escaping=pass\n"
end
