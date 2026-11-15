-- The link by code, per online character (Round 79, docs/technical/
-- web-accounts.md §4, §5.3, §5.4, §6; round79-plan.md §3.1): the code check,
-- the attempt limit, the three events, the answers the website sends and the
-- two timeouts. Pure: every engine access is injected, so
-- tools/r79_acc/portable_test.lua runs this file itself.
--
--   api.now()                  Unix seconds
--   api.schedule(seconds, fn)  core.after
--   api.push(event)            the bridge's event queue (grug_bridge)
--   api.new_request_id()       16 lower-case hex digits
--   api.enabled()              the bridge is active and holds a list
--   api.in_creation(name)      a character still being created
--   api.online(name)           the character is online
--   api.character_id(name)     the online character's id, or nil
--   api.account_of(name)       the counting binding's {id, name}, or nil
--   api.clean(text, max)       website text as one plain line
--   api.log(level, text)
--   api.on_state(name)         the state shown on the page changed
--   api.on_linked(name, text)  the character's own request ended as linked
--
-- States: idle, checking (request sent), offer (shown), confirming
-- (confirmation sent), linked (the one-off success line) and refused (with
-- its line). The first three are an open request. A code never reaches the
-- log: lines name the request id.
return function(api)
	local F = {}
	F.ANSWER_SECONDS = 30      -- a request or a confirmation without an answer
	F.OFFER_SECONDS = 120      -- an offer the player does not confirm
	F.ATTEMPTS = 5             -- link requests per character ...
	F.ATTEMPT_SECONDS = 600    -- ... in this window (session state)
	F.CODE_LENGTH = 10
	F.ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	F.NAME_MAX = 64

	F.TEXT = {
		unknown_code = "The website does not know this code. Please check it.",
		expired_code = "This code has expired. Please create a new one on the website.",
		used_code = "This code was already used or replaced. Please create a new one on the website.",
		account_full = "That website account already has 10 characters.",
		already_linked = "This character is already linked to a website account.",
		too_many_attempts = "Too many attempts on the website. Please wait a while and try again.",
		other = "The website refused the link. Please try again later.",
		bad_code = "A code has 10 letters and digits, as the website shows it.",
		attempts = "Too many link attempts. Please wait a few minutes and try again.",
		creation = "Finish creating your character first. You can link it afterwards.",
		linked = "This character is already linked to a website account.",
		no_id = "This character has no id yet. Please log in again.",
		unavailable = "Linking is not available right now.",
		timeout = "The website did not answer. Please try again later.",
		lapsed = "The offer lapsed. Please enter the code again.",
	}

	local OPEN = {checking = true, offer = true, confirming = true}
	-- The contract's table (§5.4): the outcomes each state takes.
	local VALID = {checking = {offer = true, refused = true}, offer = {},
		confirming = {linked = true, refused = true}}
	local OUTCOMES = {offer = true, linked = true, refused = true}
	-- The refusal reasons (§5.4); an unknown one is shown as `other`.
	local REASONS = {unknown_code = true, expired_code = true, used_code = true,
		account_full = true, already_linked = true, too_many_attempts = true, other = true}

	local sessions = {}   -- name -> {state, request_id, account_name, message,
	                      -- expires_at, deadline, attempts = {times}}
	local by_request = {} -- request id -> name, for the request a session holds

	local function session_of(name)
		local session = sessions[name]
		if not session then
			session = {state = "idle", attempts = {}}
			sessions[name] = session
		end
		return session
	end

	local function set(name, session, state, fields)
		session.state = state
		session.account_name, session.message, session.expires_at, session.deadline,
			session.answered = nil, nil, nil, nil, nil
		for key, value in pairs(fields or {}) do session[key] = value end
		if not OPEN[state] and state ~= "linked" and session.request_id then
			by_request[session.request_id] = nil
			session.request_id = nil
		end
		api.on_state(name)
	end

	local function arm(name, session, seconds)
		session.deadline = api.now() + seconds
		local id, state = session.request_id, session.state
		local function check()
			local current = sessions[name]
			if not current or current.request_id ~= id or current.state ~= state then return end
			local left = current.deadline - api.now()
			if left > 0 then
				api.schedule(left, check)
				return
			end
			api.push({type = "account.link_cancel", request_id = id, name = name})
			api.log("action", ("link request %s of %s cancelled: no %s in time"):format(id, name,
				state == "offer" and "confirmation" or "answer"))
			set(name, current, "refused", {message = state == "offer" and F.TEXT.lapsed or F.TEXT.timeout})
		end
		api.schedule(seconds, check)
	end

	-- Ends an open request with a cancel event (the player, a leave, a new
	-- request, a direct binding).
	local function cancel_open(name, session, why)
		if not OPEN[session.state] then return false end
		api.push({type = "account.link_cancel", request_id = session.request_id, name = name})
		api.log("action", ("link request %s of %s cancelled: %s"):format(session.request_id, name, why))
		return true
	end

	local function finish_linked(name, session, account)
		local text = "Linked to the website account " .. account.name .. "."
		api.log("action", ("link request %s of %s ended linked to account %s"):format(
			session.request_id, name, account.id))
		set(name, session, "linked", {account_name = account.name, message = text})
		api.on_linked(name, text)
	end

	-- The code as the website wants it (§4): upper case, no spaces or
	-- hyphens; nil when it is not 10 symbols of the alphabet.
	function F.normalize(text)
		if type(text) ~= "string" or #text > 64 then return nil end
		local code = text:upper():gsub("[%s%-]", "")
		if #code ~= F.CODE_LENGTH or code:find("[^" .. F.ALPHABET .. "]") then return nil end
		return code
	end

	local function recent_attempts(session)
		local now, kept = api.now(), {}
		for _, at in ipairs(session.attempts) do
			if now - at < F.ATTEMPT_SECONDS then kept[#kept + 1] = at end
		end
		session.attempts = kept
		return #kept
	end

	function F.can_request(name)
		if not api.enabled() then return false, F.TEXT.unavailable end
		if api.in_creation(name) then return false, F.TEXT.creation end
		if api.account_of(name) then return false, F.TEXT.linked end
		if not api.character_id(name) then return false, F.TEXT.no_id end
		if recent_attempts(session_of(name)) >= F.ATTEMPTS then return false, F.TEXT.attempts end
		return true
	end

	-- {state, account_name?, message?, expires_at?}
	function F.state(name)
		local session = sessions[name] or {state = "idle"}
		return {state = session.state, account_name = session.account_name,
			message = session.message, expires_at = session.expires_at}
	end

	-- A refusal before any request: shown as the status line unless a request
	-- is open, which goes on.
	local function refuse_locally(name, session, text)
		if not OPEN[session.state] then set(name, session, "refused", {message = text}) end
		return false, text
	end

	function F.request(name, text)
		local session = session_of(name)
		local ok, refusal = F.can_request(name)
		if not ok then return refuse_locally(name, session, refusal) end
		local code = F.normalize(text)
		if not code then return refuse_locally(name, session, F.TEXT.bad_code) end
		cancel_open(name, session, "a new request")
		if session.request_id then by_request[session.request_id] = nil end
		local id = api.new_request_id()
		session.request_id = id
		by_request[id] = name
		session.attempts[#session.attempts + 1] = api.now()
		api.push({type = "account.link_request", request_id = id, name = name,
			character_id = api.character_id(name), code = code})
		api.log("action", ("link request %s of %s sent"):format(id, name))
		set(name, session, "checking")
		arm(name, session, F.ANSWER_SECONDS)
		return true
	end

	function F.confirm(name)
		local session = sessions[name]
		if not session or session.state ~= "offer" then return false, "There is no offer to confirm." end
		api.push({type = "account.link_confirm", request_id = session.request_id, name = name,
			character_id = api.character_id(name)})
		api.log("action", ("link request %s of %s confirmed"):format(session.request_id, name))
		set(name, session, "confirming")
		arm(name, session, F.ANSWER_SECONDS)
		return true
	end

	function F.cancel(name)
		local session = sessions[name]
		if not session or not cancel_open(name, session, "the player") then
			return false, "There is no request to cancel."
		end
		set(name, session, "idle")
		return true
	end

	-- The player left: an open request is cancelled and the session (with its
	-- attempts) forgotten.
	function F.leave(name)
		local session = sessions[name]
		if not session then return end
		cancel_open(name, session, "the player left")
		if session.request_id then by_request[session.request_id] = nil end
		sessions[name] = nil
	end

	-- An applied list holds a counting binding for the character: an open
	-- request ends, in `confirming` as linked, otherwise with a cancel.
	function F.list_applied(name)
		local session = sessions[name]
		if not session or not OPEN[session.state] then return end
		local account = api.account_of(name)
		if not account then return end
		if session.state == "confirming" then
			finish_linked(name, session, account)
		else
			cancel_open(name, session, "the character was bound on the website")
			set(name, session, "idle")
		end
	end

	-- The command account.link_answer (§5.4): a result code and a message.
	function F.answer(args)
		local id = args.request_id
		if type(id) ~= "string" or #id ~= 16 or id:find("[^0-9a-f]") then
			return "invalid_args", "Invalid request_id."
		end
		if type(args.name) ~= "string" or args.name == "" then return "invalid_args", "Invalid name." end
		local outcome = args.outcome
		if not OUTCOMES[outcome] then return "invalid_args", "Invalid outcome." end
		local account_name
		if outcome ~= "refused" then
			if type(args.account_name) ~= "string" then return "invalid_args", "Invalid account_name." end
			account_name = api.clean(args.account_name, F.NAME_MAX)
		elseif type(args.reason) ~= "string" then
			return "invalid_args", "Invalid reason."
		end
		local name = by_request[id]
		local session = name and sessions[name]
		if not session or session.request_id ~= id then
			if not api.online(args.name) then return "not_online", args.name .. " is not online." end
			return "refused", "The game has no open request with this id."
		end
		if name ~= args.name then return "invalid_args", "The name is not the request's character." end
		if session.state == "linked" then
			-- The list that held the binding came first (§6) and ended it: its
			-- one linked answer is shown; any later answer came after the end.
			if outcome == "linked" and not session.answered then
				session.answered = true
				return "ok", "Shown to the player."
			end
			return "refused", "The request has ended."
		end
		if not VALID[session.state][outcome] then
			return "invalid_args", ("The outcome %s does not fit the request's state %s."):format(
				outcome, session.state)
		end
		if outcome == "offer" then
			set(name, session, "offer", {account_name = account_name,
				expires_at = api.now() + F.OFFER_SECONDS})
			arm(name, session, F.OFFER_SECONDS)
			return "ok", "Shown to the player."
		end
		if outcome == "refused" then
			local reason = REASONS[args.reason] and args.reason or "other"
			api.log("action", ("link request %s of %s refused: %s"):format(id, name, reason))
			set(name, session, "refused", {message = F.TEXT[reason]})
			return "ok", "Shown to the player."
		end
		local account = api.account_of(name)
		if not account then return "invalid_args", "The binding is not in the list." end
		finish_linked(name, session, account)
		return "ok", "Shown to the player."
	end

	return F
end
