-- The account model (Round 79, docs/technical/web-accounts.md §2, §5.2, §8;
-- round79-plan.md §3.1): the website's list as the game holds it, the id
-- index, the counting rule for a binding, the reward catalogue and the
-- notices a character gets when its binding or rewards change. Pure: every
-- engine access is injected (the text rule grug_core.text, itself pure, is
-- read at call time), so tools/r79_acc/portable_test.lua runs this file
-- itself.
--
--   api.storage      get_string(key), set_string(key, value) (mod storage)
--   api.serialize    core.serialize; api.deserialize core.deserialize
--   api.log(level, text)
--   api.online_id(name) -> the character id in an online character's meta,
--                    or nil for a character that is offline
--
-- Storage keys:
--   list           the applied list, cleaned: {version, characters =
--                  {{name, character_id, account_id}}, accounts = {{id, name,
--                  rewards = {id...}}}}
--   id:<name>      the id index, the name in lower case: a character id, or
--                  M.TOMBSTONE (written by the deletion of the character,
--                  Round 83: M.forget)
-- Names are unique per realm without regard to case (the engine refuses a
-- second one), so every table here is keyed by the lower-case name.
return function(api)
	-- The engine's mod storage is userdata, a fixture's a table.
	assert(type(api) == "table" and api.storage ~= nil and
		type(api.online_id) == "function", "grug_accounts model: api missing")
	local storage, log = api.storage, api.log

	local M = {}
	M.TOMBSTONE = "tombstone"
	M.NAME_MAX = 64         -- characters of an account name (§5.2)
	M.ACCOUNT_ID_MAX = 64
	M.PLAYER_NAME_MAX = 20  -- the engine's PLAYERNAME_SIZE

	local LIST_KEY = "list"
	local INDEX_PREFIX = "id:"

	local version = 0
	local bindings = {}   -- lower name -> {name, character_id, account_id}
	local accounts = {}   -- account id -> {id, name, rewards = {id -> true}}
	local catalog = {}    -- the registered rewards, in registration order
	local catalog_by_id = {}
	local mismatch_logged = {}

	--
	-- Text and forms
	--

	-- One UTF-8 character: a lead byte and its continuation bytes.
	local CHAR = "[%z\1-\127\194-\244][\128-\191]*"

	-- Website text as one plain line, as grug_bridge's C.plain cleans it:
	-- colour and translation escapes go whole, control characters and stray
	-- bytes go, a lead byte with the wrong number of continuation bytes too
	-- (the shared rule, grug_core.text.utf8_whole), line ends become spaces,
	-- outer blanks go, at most `max` characters.
	function M.clean(text, max)
		text = tostring(text or ""):gsub("\27%(.-%)", ""):gsub("\27.?", "")
		local whole = grug_core.text.utf8_whole
		local kept, count = {}, 0
		for char in text:gmatch(CHAR) do
			local byte = char:byte()
			if char == "\n" or char == "\r" or char == "\t" then
				kept[#kept + 1] = " "
			elseif whole(char) and not (byte < 32 or byte == 127) then
				kept[#kept + 1] = char
			end
		end
		text = table.concat(kept):match("^%s*(.-)%s*$")
		if not max then return text end
		local out = {}
		for char in text:gmatch(CHAR) do
			count = count + 1
			if count > max then break end
			out[count] = char
		end
		return table.concat(out)
	end

	function M.valid_name(name)
		return type(name) == "string" and #name >= 1 and #name <= M.PLAYER_NAME_MAX and
			name:find("^[A-Za-z0-9_%-]+$") ~= nil
	end

	function M.valid_character_id(id)
		return type(id) == "string" and #id == 32 and id:find("^[0-9a-f]+$") ~= nil
	end

	function M.valid_account_id(id)
		return type(id) == "string" and #id >= 1 and #id <= M.ACCOUNT_ID_MAX and
			id:find("^[A-Za-z0-9_%-]+$") ~= nil
	end

	function M.valid_reward_id(id)
		return type(id) == "string" and id:find("^[a-z0-9_]+:[a-z0-9_]+$") ~= nil
	end

	--
	-- The reward catalogue
	--

	-- def = {kind, name, icon, hint, description?}; the id is "<kind>:<name>".
	function M.register_reward(id, def)
		assert(M.valid_reward_id(id), "grug_accounts.register_reward: bad id " .. tostring(id))
		assert(not catalog_by_id[id], "grug_accounts.register_reward: " .. id .. " twice")
		assert(type(def) == "table" and def.kind == id:match("^([^:]+)") and
			type(def.name) == "string" and def.name ~= "" and type(def.icon) == "string" and
			type(def.hint) == "string" and (def.description == nil or type(def.description) == "string"),
			"grug_accounts.register_reward: incomplete definition for " .. id)
		local entry = {id = id, kind = def.kind, name = def.name, icon = def.icon, hint = def.hint,
			description = def.description}
		catalog[#catalog + 1] = entry
		catalog_by_id[id] = entry
	end

	function M.catalog()
		local list = {}
		for index, entry in ipairs(catalog) do
			list[index] = {id = entry.id, kind = entry.kind, name = entry.name, icon = entry.icon,
				hint = entry.hint, description = entry.description}
		end
		return list
	end

	-- What the website receives (§5.1): id, kind and name only.
	function M.catalog_rows()
		local rows = {}
		for index, entry in ipairs(catalog) do
			rows[index] = {id = entry.id, kind = entry.kind, name = entry.name}
		end
		return rows
	end

	--
	-- The list
	--

	local function array(value)
		return type(value) == "table" and value or {}
	end

	-- The list as the game keeps it, from what the website sent; nil when it
	-- has no numeric version (§5.2). `quiet` for the stored copy, which was
	-- clean already.
	local function build(sent, quiet)
		if type(sent) ~= "table" or type(sent.version) ~= "number" then return nil end
		local function warn(text)
			if not quiet then log("warning", text) end
		end
		local list = {version = sent.version, characters = {}, accounts = {}}
		local by_id = {}
		for _, row in ipairs(array(sent.accounts)) do
			if type(row) ~= "table" or not M.valid_account_id(row.id) or type(row.name) ~= "string" then
				warn("dropped a malformed account row")
			elseif by_id[row.id] then
				warn("dropped a second account row for " .. row.id)
			else
				local rewards = {}
				for _, reward in ipairs(array(row.rewards)) do
					if M.valid_reward_id(reward) then rewards[#rewards + 1] = reward end
				end
				local account = {id = row.id, name = M.clean(row.name, M.NAME_MAX), rewards = rewards}
				by_id[row.id] = account
				list.accounts[#list.accounts + 1] = account
			end
		end
		local seen, doubled = {}, {}
		for _, row in ipairs(array(sent.characters)) do
			if type(row) ~= "table" or not M.valid_name(row.name) or
					not M.valid_character_id(row.character_id) or not M.valid_account_id(row.account_id) then
				warn("dropped a malformed character row")
			elseif not by_id[row.account_id] then
				warn("dropped the row of " .. row.name .. ": no account " .. row.account_id)
			else
				local key = row.name:lower()
				if seen[key] then doubled[key] = true end
				seen[key] = {name = row.name, character_id = row.character_id, account_id = row.account_id}
			end
		end
		for key, row in pairs(seen) do
			if doubled[key] then
				warn("dropped every row of " .. row.name .. ": the name is listed twice")
			else
				list.characters[#list.characters + 1] = row
			end
		end
		table.sort(list.characters, function(a, b) return a.name:lower() < b.name:lower() end)
		return list
	end

	local function index_list(list)
		version, bindings, accounts = list.version, {}, {}
		for _, account in ipairs(list.accounts) do
			local rewards = {}
			for _, reward in ipairs(account.rewards) do rewards[reward] = true end
			accounts[account.id] = {id = account.id, name = account.name, rewards = rewards}
		end
		for _, row in ipairs(list.characters) do bindings[row.name:lower()] = row end
	end

	-- What a name's binding means for the page, the rewards and the website:
	-- differs exactly when something a consumer shows or checks changed.
	local function signature(key)
		local binding = bindings[key]
		if not binding then return "" end
		local account = accounts[binding.account_id]
		local rewards = {}
		for reward in pairs(account.rewards) do rewards[#rewards + 1] = reward end
		table.sort(rewards)
		return table.concat({binding.account_id, binding.character_id, account.name,
			table.concat(rewards, ",")}, "|")
	end

	function M.load()
		local raw = storage:get_string(LIST_KEY)
		local stored = raw ~= "" and api.deserialize(raw) or nil
		local list = build(stored, true)
		if list then index_list(list) end
	end

	function M.version()
		return version
	end

	-- Applies the list the website sent when its version differs from the
	-- held one (also a lower one: a restored backup). Answers nil when the
	-- list was ignored or held already, else the names whose binding, account
	-- name or rewards changed (sorted; possibly none).
	function M.apply(sent)
		local list = build(sent)
		if not list then
			log("warning", "ignored an account list without a version")
			return nil
		end
		if list.version == version then return nil end
		local before, names = {}, {}
		for key, binding in pairs(bindings) do
			before[key] = {name = binding.name, signature = signature(key)}
		end
		local previous = bindings
		index_list(list)
		storage:set_string(LIST_KEY, api.serialize(list))
		for key, binding in pairs(bindings) do
			local old = before[key]
			if not old or old.signature ~= signature(key) then names[#names + 1] = binding.name end
			local was = previous[key]
			if not was or was.account_id ~= binding.account_id then
				log("action", ("binding of %s to account %s (list version %s)"):format(
					binding.name, binding.account_id, tostring(version)))
			end
		end
		for key, old in pairs(before) do
			if not bindings[key] then
				names[#names + 1] = old.name
				log("action", ("binding of %s to account %s removed (list version %s)"):format(
					old.name, previous[key].account_id, tostring(version)))
			end
		end
		table.sort(names)
		return names
	end

	--
	-- The id index and the counting rule (§2)
	--

	-- nil (no entry), a character id, or M.TOMBSTONE.
	function M.index_entry(name)
		local value = storage:get_string(INDEX_PREFIX .. name:lower())
		if value == "" then return nil end
		return value
	end

	local function index_set(name, value)
		storage:set_string(INDEX_PREFIX .. name:lower(), value)
	end

	-- The deletion of a character (Round 83, web-accounts.md §2): the index
	-- entry becomes the tombstone, always, also when there is none (else a
	-- new character of the name would adopt the binding's id), and the
	-- binding row of the stored list goes at once (ruling 17; the version
	-- stays, the website's next list replaces it anyway). Logs nothing: the
	-- deletion's one line names the character.
	function M.forget(name)
		index_set(name, M.TOMBSTONE)
		local key = name:lower()
		if not bindings[key] then return end
		bindings[key] = nil
		local raw = storage:get_string(LIST_KEY)
		local stored = raw ~= "" and api.deserialize(raw) or nil
		if type(stored) ~= "table" or type(stored.characters) ~= "table" then return end
		local kept = {}
		for _, row in ipairs(stored.characters) do
			if type(row) == "table" and type(row.name) == "string" and row.name:lower() ~= key then
				kept[#kept + 1] = row
			end
		end
		stored.characters = kept
		storage:set_string(LIST_KEY, api.serialize(stored))
	end

	-- The id a joining character keeps or gets: its meta id (which wins over
	-- the index, rewriting it), else the index's id, else an adopted binding's
	-- id, else a new one from new_id(). Answers the id and whether the meta
	-- must be written.
	function M.assign_id(name, meta_id, new_id)
		local entry = M.index_entry(name)
		if meta_id ~= nil and meta_id ~= "" and not M.valid_character_id(meta_id) then
			log("warning", "the character id of " .. name .. " is malformed; it gets a new one")
			meta_id = nil
		end
		if meta_id and meta_id ~= "" then
			if entry ~= meta_id then
				if entry ~= nil then
					log("action", ("the id index of %s disagreed with its meta (%s); the meta wins"):format(
						name, entry == M.TOMBSTONE and "a tombstone" or entry))
				end
				index_set(name, meta_id)
			end
			return meta_id, false
		end
		local id
		if entry == nil then
			local binding = bindings[name:lower()]
			if binding then
				id = binding.character_id
				log("action", ("%s adopts the character id of its binding"):format(name))
			else
				id = new_id()
			end
		elseif entry == M.TOMBSTONE then
			id = new_id()
		else
			id = entry
		end
		index_set(name, id)
		return id, true
	end

	-- The binding that counts for `name` (online: its meta id; offline: the
	-- index), or nil. A binding for another character id is ignored and
	-- logged once per boot.
	function M.counting(name)
		local key = name:lower()
		local binding = bindings[key]
		if not binding then return nil end
		local id = api.online_id(name) or M.index_entry(name)
		if id == nil or id == binding.character_id then return binding end
		local mark = key .. "|" .. binding.character_id
		if not mismatch_logged[mark] then
			mismatch_logged[mark] = true
			log("action", ("ignored the binding of %s: it names another character id"):format(name))
		end
		return nil
	end

	-- nil or {id, name}: the counting binding's account.
	function M.account_of(name)
		local binding = M.counting(name)
		if not binding then return nil end
		local account = accounts[binding.account_id]
		return {id = account.id, name = account.name}
	end

	-- The catalogue's entries the counting binding's account holds, in
	-- catalogue order; an id the catalogue does not know grants nothing.
	local function held(name)
		local binding = M.counting(name)
		if not binding then return {} end
		local rewards, out = accounts[binding.account_id].rewards, {}
		for _, entry in ipairs(catalog) do
			if rewards[entry.id] then out[#out + 1] = entry end
		end
		return out
	end

	function M.has_reward(name, reward_id)
		for _, entry in ipairs(held(name)) do
			if entry.id == reward_id then return true end
		end
		return false
	end

	function M.rewards_of(name)
		local out = {}
		for index, entry in ipairs(held(name)) do
			out[index] = {id = entry.id, kind = entry.kind, name = entry.name}
		end
		return out
	end

	--
	-- Notices (round79-plan.md §3.1)
	--

	-- `seen` is what the character last saw, "<account id>|<reward,...>"
	-- (player meta grug_accounts:seen; "" when never). Answers the feed lines
	-- for what changed since and the new value. `own` is the success line of
	-- the character's own code request when it ended as linked: shown
	-- instead of the binding line.
	function M.notices(seen, name, own)
		local old_account, old_list = (seen or ""):match("^([^|]*)|(.*)$")
		old_account, old_list = old_account or "", old_list or ""
		local old_rewards = {}
		for reward in old_list:gmatch("[^,]+") do old_rewards[reward] = true end
		local account = M.account_of(name)
		local now_rewards, ids = {}, {}
		for _, entry in ipairs(held(name)) do
			now_rewards[entry.id] = entry
			ids[#ids + 1] = entry.id
		end
		local lines = {}
		local account_id = account and account.id or ""
		if account_id ~= old_account then
			if account then
				lines[#lines + 1] = own or
					("This character is now linked to the website account " .. account.name .. ".")
			else
				lines[#lines + 1] = "This character is no longer linked to a website account."
			end
		end
		local gained, lost = {}, {}
		for _, entry in ipairs(catalog) do
			if now_rewards[entry.id] and not old_rewards[entry.id] then gained[#gained + 1] = entry.name end
			if old_rewards[entry.id] and not now_rewards[entry.id] then lost[#lost + 1] = entry.name end
		end
		if #gained > 0 then
			lines[#lines + 1] = "Your account gives you: " .. table.concat(gained, ", ") .. "."
		end
		if #lost > 0 then
			lines[#lines + 1] = "Your account no longer gives you: " .. table.concat(lost, ", ") .. "."
		end
		return lines, account_id .. "|" .. table.concat(ids, ",")
	end

	return M
end
