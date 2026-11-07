-- The exchange with the bridge (docs/technical/web-bridge.md), free of engine
-- calls: what opts names is passed in, so the portable fixture
-- tools/r691_bridge/portable_test.lua runs this file itself. One request at a
-- time; the caller sends what `request` builds and hands the outcome to
-- `finish`, which answers the seconds until the next request.

local L = {}

L.PROTOCOL = 1
L.DEFAULT_NEXT_MS = 2000
L.MIN_NEXT_MS = 1000
L.MAX_NEXT_MS = 30000
L.TIMEOUT = 5                 -- seconds a request may take
L.BACKOFF = {5, 10, 20, 40, 60} -- seconds after the 1st, 2nd, ... failure
L.REFUSED_RETRY = 60          -- seconds after a 401 or a 409
L.MAX_REQUEST = 256 * 1024    -- bytes
L.MAX_RESPONSE = 1024 * 1024  -- bytes
L.EVENTS_PER_REQUEST = 100
L.QUEUE_MAX = 1000
L.ONLINE_EVERY = 30           -- seconds between complete online lists
L.MESSAGE_MAX = 200           -- characters of a result's message

-- One event may not hold up the queue for ever by never fitting a request. A
-- ticket holding a reported letter stays far below this.
L.EVENT_MAX = L.MAX_REQUEST / 2

local REPLACEMENT = "\239\191\189" -- U+FFFD

-- `text` as valid UTF-8, each stray byte replaced. The JSON writer copies bytes
-- as they are, and M.clean keeps a lead byte without its continuation, which a
-- modified client can place in a ticket: a bridge that refuses such a body
-- would never acknowledge the event, and the queue would stand still.
function L.valid_utf8(text)
	if not text:find("[\128-\255]") then return text end
	local out, at, length = {}, 1, #text
	while at <= length do
		local byte = text:byte(at)
		local size, low, high = 1, 128, 191
		if byte >= 128 then
			if byte >= 194 and byte <= 223 then size = 2
			elseif byte >= 224 and byte <= 239 then
				size = 3
				if byte == 224 then low = 160 elseif byte == 237 then high = 159 end
			elseif byte >= 240 and byte <= 244 then
				size = 4
				if byte == 240 then low = 144 elseif byte == 244 then high = 143 end
			else size = 0 end
		end
		local valid = size > 0
		for index = 1, size - 1 do
			local next_byte = text:byte(at + index)
			if not next_byte or next_byte < (index == 1 and low or 128) or
					next_byte > (index == 1 and high or 191) then
				valid = false
				break
			end
		end
		if valid then
			out[#out + 1] = text:sub(at, at + size - 1)
			at = at + size
		else
			out[#out + 1] = REPLACEMENT
			at = at + 1
		end
	end
	return table.concat(out)
end

local Link = {}
Link.__index = Link

-- opts: boot, version, capabilities (list); encode(table) -> JSON;
-- decode(JSON) -> table or nil; now() -> Unix seconds; log(level, text);
-- clean(text, max) -> one line of at most `max` characters; online_rows() ->
-- list; banlist_version() -> number; run_command(command) -> code, message;
-- on_banlist(banlist); on_resync(name).
function L.new(opts)
	local link = setmetatable({opts = opts, boot = opts.boot, first = 1, last = 0,
		events = {}, next_seq = 1, dropped = 0, results = {}, ledger = {},
		online_change = 1, online_sent = 0, online_at = nil, failures = 0}, Link)
	return link
end

--
-- Events
--

function Link:queued()
	return self.last - self.first + 1
end

function Link:forget_oldest()
	self.events[self.first] = nil
	self.first = self.first + 1
end

-- Queues `event` ({type = ..., fields}), adding its seq and time. Encoded
-- here, so one that cannot be written is lost alone and never stops the queue.
function Link:push(event)
	event.seq, event.time = self.next_seq, self.opts.now()
	local ok, json = pcall(self.opts.encode, event)
	if not ok or type(json) ~= "string" or #json > L.EVENT_MAX then
		self.dropped = self.dropped + 1
		self.opts.log("warning", "lost an event of type " .. tostring(event.type))
		return false
	end
	self.next_seq = self.next_seq + 1
	self.last = self.last + 1
	self.events[self.last] = {seq = event.seq, json = L.valid_utf8(json)}
	if self:queued() > L.QUEUE_MAX then
		self:forget_oldest()
		self.dropped = self.dropped + 1
	end
	return true
end

function Link:online_changed()
	self.online_change = self.online_change + 1
end

--
-- The request
--

-- The list as a JSON array, written here: core.write_json turns an empty
-- table into null.
local function array(items)
	return "[" .. table.concat(items, ",") .. "]"
end

function Link:online_due()
	return self.online_change ~= self.online_sent or not self.online_at or
		self.opts.now() - self.online_at >= L.ONLINE_EVERY
end

-- The request body. Results go first, then the online list, then the oldest
-- unacknowledged events, up to L.EVENTS_PER_REQUEST and L.MAX_REQUEST. What
-- did not fit stays queued for the next request.
function Link:request()
	local opts = self.opts
	local head = opts.encode({protocol = L.PROTOCOL, boot = self.boot,
		game_version = opts.version, capabilities = opts.capabilities,
		banlist_version = opts.banlist_version(), dropped_events = self.dropped})
	head = head:sub(1, -2) -- reopened for the fields written below
	local online
	if self:online_due() then
		local rows = {}
		for index, row in ipairs(opts.online_rows()) do rows[index] = opts.encode(row) end
		online = array(rows)
	end
	-- 40: the fields' names and punctuation below.
	local size = #head + 40 + (online and #online + 10 or 0)
	local results, events = {}, {}
	for index, entry in ipairs(self.results) do
		if size + #entry.json + 1 > L.MAX_REQUEST then break end
		size = size + #entry.json + 1
		results[index] = entry.json
	end
	for index = self.first, math.min(self.last, self.first + L.EVENTS_PER_REQUEST - 1) do
		local json = self.events[index].json
		if size + #json + 1 > L.MAX_REQUEST then break end
		size = size + #json + 1
		events[#events + 1] = json
	end
	self.flight = {results = #results, online = online ~= nil,
		online_change = self.online_change}
	return head .. ',"results":' .. array(results) .. ',"events":' .. array(events) ..
		(online and ',"online":' .. online or "") .. "}"
end

--
-- The answer
--

function Link:guard(what, func, ...)
	local ok, failure = pcall(func, ...)
	if not ok then self.opts.log("error", what .. " failed: " .. tostring(failure)) end
end

function Link:keep_result(entry)
	entry.queued = true
	self.results[#self.results + 1] = entry
end

-- At most once: the id is written before anything acts, and an id seen before
-- never acts again. Its stored result goes out again unless it is still
-- queued; nothing goes out while it is running.
function Link:command(command)
	if type(command) ~= "table" or type(command.id) ~= "string" or command.id == "" then
		self.opts.log("warning", "ignored a command without an id")
		return
	end
	local seen = self.ledger[command.id]
	if seen then
		if seen.json and not seen.queued then self:keep_result(seen) end
		return
	end
	local entry = {}
	self.ledger[command.id] = entry
	local code, message
	if type(command.expires_at) == "number" and self.opts.now() > command.expires_at then
		code, message = "expired", "The command expired before it reached the game."
	else
		local ok, a, b = pcall(self.opts.run_command, command)
		if ok then
			code, message = a, b
		else
			self.opts.log("error", ("command %s (%s) raised: %s"):format(command.id,
				tostring(command.type), tostring(a)))
			code, message = "error", "The action raised an error; see the server log."
		end
	end
	self.opts.log("action", ("command %s (%s): %s %s"):format(command.id,
		tostring(command.type), tostring(code), tostring(message or "")))
	entry.json = self.opts.encode({id = command.id,
		status = code == "ok" and "done" or "failed", code = code,
		message = self.opts.clean(message or "", L.MESSAGE_MAX)})
	self:keep_result(entry)
end

function Link:accept(reply, flight)
	-- The bridge has what this request carried. Its results are forgotten
	-- now; a lost response repeats them, and the bridge takes them by id.
	for _ = 1, flight.results do
		table.remove(self.results, 1).queued = false
	end
	if flight.online then
		self.online_sent = flight.online_change
		self.online_at = self.opts.now()
	end
	if self.failures > 0 or self.refused then
		self.opts.log("action", "the bridge answers again")
	end
	self.failures, self.refused = 0, nil
	if type(reply.ack_seq) == "number" then
		while self.first <= self.last and self.events[self.first].seq <= reply.ack_seq do
			self:forget_oldest()
		end
	end
	if type(reply.banlist) == "table" then
		self:guard("the ban list", self.opts.on_banlist, reply.banlist)
	end
	if type(reply.resync) == "table" then
		for _, name in ipairs(reply.resync) do
			self:guard("a resync", self.opts.on_resync, name)
		end
	end
	if type(reply.commands) == "table" then
		for _, command in ipairs(reply.commands) do
			self:guard("a command", self.command, self, command)
		end
	end
	local next_ms = tonumber(reply.next_ms) or L.DEFAULT_NEXT_MS
	return math.max(L.MIN_NEXT_MS, math.min(L.MAX_NEXT_MS, next_ms)) / 1000
end

function Link:failed(reason)
	self.failures = self.failures + 1
	if self.failures == 1 then
		self.opts.log("warning", "the bridge does not answer: " .. reason)
	end
	return L.BACKOFF[math.min(self.failures, #L.BACKOFF)]
end

-- res: the engine's HTTPRequestResult. Answers the seconds to wait.
function Link:finish(res)
	local flight = self.flight or {results = 0}
	self.flight = nil
	local code = res.code
	if code == 401 or code == 409 then
		if self.refused ~= code then
			self.refused = code
			self.opts.log("warning", code == 401 and "the bridge refused the token" or
				"the bridge does not speak this protocol")
		end
		return L.REFUSED_RETRY
	end
	if code ~= 200 or not res.succeeded then
		return self:failed(res.timeout and "timeout" or ("status " .. tostring(code)))
	end
	if #(res.data or "") > L.MAX_RESPONSE then return self:failed("response too large") end
	local reply = self.opts.decode(res.data or "")
	if type(reply) ~= "table" or reply.protocol ~= L.PROTOCOL then
		return self:failed("unreadable response")
	end
	return self:accept(reply, flight)
end

return L
