-- Name bans from the website (docs/technical/web-bridge.md "Bans"). The last
-- list stays in this mod's storage, so a ban holds while the bridge is down
-- and across a restart: {version, entries = {lower-case name -> expires_at or
-- false}}. No engine calls but the two the caller passes in; the fixture runs
-- this file itself.

local B = {}

local KEY = "banlist"

function B.load(storage, deserialize)
	local raw = storage:get_string(KEY)
	local list = raw ~= "" and deserialize(raw) or nil
	if type(list) ~= "table" or type(list.entries) ~= "table" then
		return {version = 0, entries = {}}
	end
	return list
end

-- The list the bridge sent, stored; nil for one that is not a list.
function B.store(storage, serialize, banlist)
	if type(banlist.version) ~= "number" then return nil end
	local entries = {}
	for _, entry in ipairs(type(banlist.entries) == "table" and banlist.entries or {}) do
		if type(entry) == "table" and type(entry.name) == "string" then
			entries[entry.name:lower()] =
				type(entry.expires_at) == "number" and entry.expires_at or false
		end
	end
	local list = {version = banlist.version, entries = entries}
	storage:set_string(KEY, serialize(list))
	return list
end

-- Nil, or the ban that holds `name` at `now`: false without an end, or the
-- time it ends.
function B.active(list, name, now)
	local expires_at = list.entries[name:lower()]
	if expires_at == nil then return nil end
	if expires_at == false or expires_at > now then return expires_at end
	return nil
end

function B.text(expires_at)
	local text = "You are banned from this server."
	if expires_at then
		text = text .. " Ban ends: " .. os.date("!%Y-%m-%d %H:%M UTC", expires_at) .. "."
	end
	return text
end

return B
