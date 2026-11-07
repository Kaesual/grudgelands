-- The website's mirror of the admin inbox and the announcements
-- (docs/technical/web-bridge.md "Events"). grug_mail tells this file whenever
-- a whole list was written; it keeps each entry as last sent and sends what
-- differs. No engine calls; the fixture runs this file itself.

local KINDS = {
	tickets = {changed = "mail.ticket", field = "ticket", removed = "mail.ticket_removed"},
	broadcasts = {changed = "mail.broadcast", field = "broadcast",
		removed = "mail.broadcast_removed"},
}

local Mirror = {}
Mirror.__index = Mirror

local function new(push, encode)
	return setmetatable({push = push, encode = encode,
		known = {tickets = {}, broadcasts = {}}}, Mirror)
end

function Mirror:row(kind, entry)
	return {type = KINDS[kind].changed, [KINDS[kind].field] = entry}
end

-- The state the website is assumed to have: nothing is sent.
function Mirror:seed(kind, list)
	local known = {}
	for _, entry in ipairs(list) do known[entry.id] = self.encode(entry) end
	self.known[kind] = known
end

-- `list` was just written. New and changed entries, oldest first (the lists
-- keep the newest first), then the removed ones in id order.
function Mirror:saved(kind, list)
	local before, known = self.known[kind], {}
	for index = #list, 1, -1 do
		local entry = list[index]
		local json = self.encode(entry)
		known[entry.id] = json
		if before[entry.id] ~= json then self.push(self:row(kind, entry)) end
	end
	self.known[kind] = known
	local gone = {}
	for id in pairs(before) do
		if not known[id] then gone[#gone + 1] = id end
	end
	table.sort(gone)
	for _, id in ipairs(gone) do
		self.push({type = KINDS[kind].removed, id = id})
	end
end

-- Everything again as ordinary events, then the ids the snapshot held.
function Mirror:resync(tickets, broadcasts)
	local ids = {tickets = {}, broadcasts = {}}
	for kind, list in pairs({tickets = tickets, broadcasts = broadcasts}) do
		self:seed(kind, list)
		for index, entry in ipairs(list) do ids[kind][index] = entry.id end
	end
	for _, kind in ipairs({"tickets", "broadcasts"}) do
		local list = kind == "tickets" and tickets or broadcasts
		for index = #list, 1, -1 do self.push(self:row(kind, list[index])) end
	end
	self.push({type = "mail.snapshot_end", ticket_ids = ids.tickets,
		broadcast_ids = ids.broadcasts})
end

return {new = new}
