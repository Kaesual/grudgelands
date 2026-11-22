-- The Claim Stone model (Round 25 Lane A, docs/planning/round25-housing-plan.md
-- rulings 1-12 and 30-32; Round 26 rulings 8-10): claims and per-player
-- records, their persistence, the chunk index, drafts and activation, fuel as
-- a "paid until" time, permissions, the pick-up lock and placement validation.
-- Pure: every engine or world access is injected, so the same bytes run in
-- the engine (api.lua) and in tools/r25_claim_core/fixture.lua.
--
-- A claim is one map chunk (Round 85 ruling 6, plan §3.3): the 80 x 80
-- columns of the chunk that holds its stone (`center`), from MIN_Y upward.
-- One claim per chunk; placement asks the claim mask and its quota
-- (claim_mask.lua, through validate's `world.mask`).
--
-- A placed stone starts as a DRAFT (activated_at 0): it reserves its chunk
-- against other claims and keeps its arrival cube, but protects nothing and
-- is not active; it disappears DRAFT_SECONDS after placing unless the owner
-- activates it. Activation pays ACTIVATION_LUMPS lumps at once and starts the
-- fuel and the protection. For PICKUP_LOCK_SECONDS after activation the owner
-- cannot pick the stone up; that is the only lock (no placing lock).
--
--   api.storage   get_string(key), set_string(key, value), keys() -> array
--                 (mod storage; "" deletes a key)
--   api.now()     wall-clock seconds (os.time()); server downtime counts
--
-- Storage keys, one line each (player names are [A-Za-z0-9_-], so "|", ","
-- and "=" never occur inside a field):
--   next_id             the next claim id
--   claim:<id>          v3|owner|x|y|z|placed_at|activated_at|paid_until|
--                       expired_for|perms|kind|name  (activated_at 0: a
--                       draft; x, y, z the stone)
--                       perms = name=level,name=level
--                       kind: "" (a personal claim) or "account"; name:
--                       the home's name (Round 86, set_name; empty in a
--                       record of 0.85.0; never "|" or a newline)
--   player:<name>       v2|state|claim_id, or for a member of an account
--                       claim (Round 86) v2|member|<owner text>
-- The account Claim Stone (Round 86, plan §3.1): a claim of kind "account"
-- is a draft owned by the character that placed it (owner = its name,
-- ruling 16) until activation makes it the account claim, whose owner is
-- the owner text `account:<account id>:<faction>`, which no player name can
-- be. Its owners are the members: characters whose record is "member" with
-- that owner text (membership outlives the claim: rulings 13, 14). One
-- account claim per owner text; a member owns no personal claim.
-- Only v3 claim records load (the 0.85.0 map reset clears the v2 ones; no
-- conversion): load() returns the keys it did not load.
return function(api)
	assert(type(api) == "table" and type(api.storage) == "table" and
		type(api.now) == "function", "grug_housing registry: api missing")
	local storage, now = api.storage, api.now
	local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

	local M = {}
	M.MIN_Y = -100           -- rulings 1-2: the claim and the stone from y -100
	M.LUMP_SECONDS = 26160   -- ruling 10: one lump or charcoal, 7 h 16 min
	M.FUEL_MAX = 99          -- ruling 10: one fuel slot of 99 items
	-- Round 47 ruling 12: the cap is counted in time, 99 lumps' worth (about
	-- 30 days), so a fuel that burns longer than a lump (Anthracite, api.lua)
	-- fills it with fewer pieces. A piece goes in only if its whole time fits.
	M.FUEL_CAP_SECONDS = M.FUEL_MAX * M.LUMP_SECONDS
	M.DRAFT_SECONDS = 300    -- R26 ruling 8: an unactivated stone lasts 5 min
	M.ACTIVATION_LUMPS = 5   -- R26 ruling 9: activation pays 5 lumps at once
	M.PICKUP_LOCK_SECONDS = 43200 -- R26 ruling 10: 12 h after activation
	M.ISSUE_LEVEL = 20       -- ruling 7
	-- Round 85 ruling 6: the map chunk (chunksize 5), as claim_mask.lua's
	-- chunk_of and chunk_bounds (tools/r85_core pins them equal): chunk
	-- column cx covers x CHUNK * cx + CHUNK_ORIGIN .. + CHUNK - 1, the same
	-- in z.
	M.CHUNK = 80
	M.CHUNK_ORIGIN = -32
	local CHUNK, ORIGIN = M.CHUNK, M.CHUNK_ORIGIN

	local STATES = {never = true, carried = true, placed = true,
		destroyed = true, removed = true, needs_stone = true, member = true}
	M.ACCOUNT = "account"    -- the account claim's kind (the personal one: "")
	local LEVELS = {everything = true, interact = true}

	local claims = {}        -- id -> claim
	local by_chunk = {}      -- by_chunk[cz][cx] -> the claim of that chunk
	-- Round 81 (audit P4-02): the periodic scans touch only what can be due.
	local drafts = {}        -- id -> claim, every draft (activated_at 0)
	-- Never later than the lowest paid_until of a claim whose expiry is not
	-- reported yet (paid_until ~= expired_for); nil: none. expiry_scan
	-- returns at once before it; a refuel may leave it early (one full scan
	-- then sets it right), never late.
	local next_expiry = nil
	local players = {}       -- name -> record
	-- Round 86: owner text -> {name -> true}, every member (from the
	-- records), and owner text -> the activated account claim.
	local members = {}
	local account_claims = {}
	local next_id = 1
	local claim_count = 0
	-- Changes whenever a claim comes or goes, also on load and map reset
	-- (fix 0.50.2: the minimap's claim preview rebuilds its texture on it).
	local claim_set_version = 0
	-- The quota's taken columns (Round 85 ruling 16): kind id -> columns
	-- over every claim record, drafts and expired ones included, for the
	-- mask `taken_for`; nil until validate or quota_taken asks for that
	-- mask, then kept current by create and remove. Nothing is stored: it
	-- follows from the records.
	local taken, taken_for = nil, nil

	-- Serialization -----------------------------------------------------------

	local function split(text, separator)
		local result, start = {}, 1
		while true do
			local at = text:find(separator, start, true)
			if not at then
				result[#result + 1] = text:sub(start)
				return result
			end
			result[#result + 1] = text:sub(start, at - 1)
			start = at + #separator
		end
	end

	local function encode_claim(claim)
		local names = {}
		for name in pairs(claim.permissions) do names[#names + 1] = name end
		table.sort(names)
		local perms = {}
		for index = 1, #names do
			perms[index] = names[index] .. "=" .. claim.permissions[names[index]]
		end
		local c = claim.center
		return table.concat({"v3", claim.owner, c.x, c.y, c.z, claim.placed_at,
			claim.activated_at, claim.paid_until, claim.expired_for,
			table.concat(perms, ","), claim.kind, claim.name}, "|")
	end

	local function decode_claim(id, text)
		local f = split(text, "|")
		if f[1] ~= "v3" or #f ~= 12 then return nil end
		local claim = {id = id, owner = f[2],
			center = {x = tonumber(f[3]), y = tonumber(f[4]), z = tonumber(f[5])},
			placed_at = tonumber(f[6]), activated_at = tonumber(f[7]),
			paid_until = tonumber(f[8]), expired_for = tonumber(f[9]),
			permissions = {}, kind = f[11], name = f[12]}
		if claim.owner == "" or not claim.center.x or not claim.center.y or
				not claim.center.z or not claim.placed_at or
				not claim.activated_at or not claim.paid_until or
				not claim.expired_for then
			return nil
		end
		if f[10] ~= "" then
			local rows = split(f[10], ",")
			for index = 1, #rows do
				local pair = split(rows[index], "=")
				if #pair == 2 and pair[1] ~= "" and LEVELS[pair[2]] then
					claim.permissions[pair[1]] = pair[2]
				end
			end
		end
		return claim
	end

	-- Round 86: the account claim's owner text and its parts (an account id
	-- is [A-Za-z0-9_-]{1,64}, grug_accounts/model.lua; a faction id letters).
	function M.owner_text(account_id, faction)
		return "account:" .. account_id .. ":" .. faction
	end

	-- account id, faction of an owner text, else nil.
	local function parse_owner_text(text)
		if type(text) ~= "string" then return nil end
		return text:match("^account:([%w_%-]+):(%a+)$")
	end
	M.parse_owner_text = parse_owner_text

	local function encode_player(rec)
		if rec.state == "member" then
			return table.concat({"v2", "member", rec.account}, "|")
		end
		return table.concat({"v2", rec.state, rec.claim_id or 0}, "|")
	end

	local function decode_player(text)
		local f = split(text, "|")
		if f[1] ~= "v2" or #f ~= 3 or not STATES[f[2]] then return nil end
		if f[2] == "member" then
			if not parse_owner_text(f[3]) then return nil end
			return {state = "member", account = f[3]}
		end
		local claim_id = tonumber(f[3])
		return {state = f[2], claim_id = claim_id ~= 0 and claim_id or nil}
	end

	local function save_claim(claim)
		storage.set_string("claim:" .. claim.id, encode_claim(claim))
	end

	local function save_player(name)
		storage.set_string("player:" .. name, encode_player(players[name]))
	end

	-- A paid_until that expiry_scan has to report one day.
	local function note_expiry(claim)
		if claim.paid_until ~= claim.expired_for and
				(not next_expiry or claim.paid_until < next_expiry) then
			next_expiry = claim.paid_until
		end
	end
	-- For a tool that writes paid_until directly (the r25_claim_core engine
	-- probe's faked clock): call it after the write, or expiry_scan may
	-- return before that expiry. Game code changes paid_until only through
	-- this file, whose writers call note_expiry themselves.
	M.note_expiry = note_expiry

	-- The chunk index -----------------------------------------------------------

	-- The chunk column of a node coordinate.
	local function chunk_of(v) return floor((v - ORIGIN) / CHUNK) end
	M.chunk_of = chunk_of

	-- The claim's chunk: cx, cz.
	local function claim_chunk(claim)
		return chunk_of(claim.center.x), chunk_of(claim.center.z)
	end
	M.claim_chunk = claim_chunk

	-- The inclusive x/z node bounds of the claim's chunk: min_x, min_z,
	-- max_x, max_z (the y range is MIN_Y upward).
	function M.claim_bounds(claim)
		local cx, cz = claim_chunk(claim)
		local x0, z0 = CHUNK * cx + ORIGIN, CHUNK * cz + ORIGIN
		return x0, z0, x0 + CHUNK - 1, z0 + CHUNK - 1
	end

	-- One claim per chunk (validate refuses a second); a world that holds two
	-- records in one chunk anyway indexes the lower id, and the other is
	-- reached only through its owner and its id.
	local function index_add(claim)
		local cx, cz = claim_chunk(claim)
		local row = by_chunk[cz]
		if not row then row = {}; by_chunk[cz] = row end
		local held = row[cx]
		if not held or held.id > claim.id then row[cx] = claim end
	end

	local function index_remove(claim)
		local cx, cz = claim_chunk(claim)
		local row = by_chunk[cz]
		if row and row[cx] == claim then
			row[cx] = nil
			if next(row) == nil then by_chunk[cz] = nil end
		end
	end

	-- Round 86: the member index and the account claims ----------------------

	local function member_add(name, owner)
		local group = members[owner]
		if not group then group = {}; members[owner] = group end
		group[name] = true
	end

	local function member_remove(name, owner)
		local group = owner and members[owner]
		if group then
			group[name] = nil
			if next(group) == nil then members[owner] = nil end
		end
	end

	-- An activated account claim is indexed by its owner text (the lower id
	-- wins, as in the chunk index).
	local function account_add(claim)
		if claim.kind ~= M.ACCOUNT or not parse_owner_text(claim.owner) then return end
		local held = account_claims[claim.owner]
		if not held or held.id > claim.id then account_claims[claim.owner] = claim end
	end

	-- Loading -----------------------------------------------------------------

	-- Returns the claim keys whose record it did not load (another version or
	-- undecodable), sorted; the caller reports them (api.lua).
	function M.load()
		claims, by_chunk, players, claim_count = {}, {}, {}, 0
		drafts, next_expiry = {}, nil
		members, account_claims = {}, {}
		taken, taken_for = nil, nil
		claim_set_version = claim_set_version + 1
		next_id = tonumber(storage.get_string("next_id")) or 1
		local skipped = {}
		local keys = storage.keys()
		table.sort(keys)
		for index = 1, #keys do
			local key = keys[index]
			local id = tonumber(key:match("^claim:(%d+)$"))
			local name = key:match("^player:(.+)$")
			if id then
				local claim = decode_claim(id, storage.get_string(key))
				if claim then
					claims[id] = claim
					claim_count = claim_count + 1
					index_add(claim)
					account_add(claim)
					if claim.activated_at == 0 then drafts[id] = claim end
					note_expiry(claim)
					if id >= next_id then next_id = id + 1 end
				else
					skipped[#skipped + 1] = key
				end
			elseif name then
				local rec = decode_player(storage.get_string(key))
				players[name] = rec
				if rec and rec.state == "member" then member_add(name, rec.account) end
			end
		end
		return skipped
	end

	-- The platform's map reset (grug_core/map_reset.lua, the upgrade
	-- contract; Round 41 ruling 9): the claims are map-bound and go, also a
	-- record that does not decode. A player whose stone stood needs a new one
	-- from the Housing Steward, as after losing it; a carried stone and every
	-- other record stay, a membership too (Round 86 ruling 14: its members get
	-- account stones from the Steward), and so does the id counter
	-- (monotonic). Runs on the loaded registry; idempotent.
	function M.map_reset()
		local keys = storage.keys()
		for index = 1, #keys do
			if keys[index]:match("^claim:") then storage.set_string(keys[index], "") end
		end
		claims, by_chunk, claim_count = {}, {}, 0
		drafts, next_expiry = {}, nil
		account_claims = {}
		taken, taken_for = nil, nil
		claim_set_version = claim_set_version + 1
		storage.set_string("next_id", tostring(next_id))
		for name, rec in pairs(players) do
			if rec.state == "placed" then
				rec.state, rec.claim_id = "needs_stone", nil
				save_player(name)
			end
		end
	end

	-- Queries -----------------------------------------------------------------

	local function round(value) return floor(value + 0.5) end

	function M.claim_at(pos)
		local y = round(pos.y)
		if y < M.MIN_Y then return nil end
		local row = by_chunk[chunk_of(round(pos.z))]
		return row and row[chunk_of(round(pos.x))] or nil
	end

	-- The claim of chunk (cx, cz), or nil.
	function M.chunk_claim(cx, cz)
		local row = by_chunk[cz]
		return row and row[cx] or nil
	end

	function M.claim_by_id(id) return claims[id] end

	function M.claim_count() return claim_count end

	-- A number that changes whenever a claim is created or removed (and on
	-- load and map reset); equal numbers mean the same claim set.
	function M.claim_set_version() return claim_set_version end

	-- Every claim whose chunk meets the inclusive x/z rectangle, ordered by
	-- id: a lookup of the chunks under the rectangle.
	function M.claims_in(min_x, min_z, max_x, max_z)
		local list = {}
		local cx0, cx1 = chunk_of(min_x), chunk_of(max_x)
		for cz = chunk_of(min_z), chunk_of(max_z) do
			local row = by_chunk[cz]
			if row then
				for cx = cx0, cx1 do
					if row[cx] then list[#list + 1] = row[cx] end
				end
			end
		end
		table.sort(list, function(a, b) return a.id < b.id end)
		return list
	end

	-- Every claim, ordered by id.
	function M.all_claims()
		local list = {}
		for _, claim in pairs(claims) do list[#list + 1] = claim end
		table.sort(list, function(a, b) return a.id < b.id end)
		return list
	end

	-- A placed stone that was never activated (R26 ruling 8).
	function M.is_draft(claim)
		return claim ~= nil and claim.activated_at == 0
	end

	-- Seconds until a draft disappears; 0 for an activated claim.
	function M.draft_remaining(claim)
		if not M.is_draft(claim) then return 0 end
		return max(0, claim.placed_at + M.DRAFT_SECONDS - now())
	end

	-- Active: activated and fuelled. A draft is never active.
	function M.is_active(claim)
		return claim ~= nil and claim.activated_at ~= 0 and claim.paid_until > now()
	end

	function M.remaining_seconds(claim)
		if not claim then return 0 end
		return max(0, claim.paid_until - now())
	end

	-- Pieces of `seconds_each` (default one lump) whose whole time still fits
	-- under the cap. For lumps that is 99 minus the stack the remaining time
	-- stands for (a started lump counts as one), as before Round 47.
	function M.fuel_room(claim, seconds_each)
		seconds_each = tonumber(seconds_each) or M.LUMP_SECONDS
		return max(0, floor((M.FUEL_CAP_SECONDS - M.remaining_seconds(claim)) /
			seconds_each))
	end

	-- Whole unburnt lumps, returned on pick-up.
	function M.refund_lumps(claim)
		return floor(M.remaining_seconds(claim) / M.LUMP_SECONDS)
	end

	-- Round 86 (plan §3.1): the owner text of the account claim the
	-- character `name` is a member of, or nil. In memory (protection asks it
	-- on every dig and place of a non-owner); the records hold it, and the
	-- engine glue (account.lua) keeps them in line with grug_accounts.
	function M.account_owner_of(name)
		local rec = players[name]
		return rec and rec.state == "member" and rec.account or nil
	end

	-- The members of the owner text, sorted by name.
	function M.members(owner)
		local list = {}
		for name in pairs(members[owner] or {}) do list[#list + 1] = name end
		table.sort(list)
		return list
	end

	-- Every member as {name, owner}, sorted by name (the reconcile at load).
	function M.all_members()
		local list = {}
		for name, rec in pairs(players) do
			if rec.state == "member" then list[#list + 1] = {name = name, owner = rec.account} end
		end
		table.sort(list, function(a, b) return a.name < b.name end)
		return list
	end

	-- The activated account claim of the owner text, or nil.
	function M.account_claim(owner)
		return account_claims[owner]
	end

	-- A member's own account draft (ruling 16: it belongs to the character
	-- that placed it), or nil; the lowest id if a world holds two.
	local function own_draft(name)
		local found
		for _, claim in pairs(drafts) do
			if claim.kind == M.ACCOUNT and M.is_owner(claim, name) and
					(not found or claim.id < found.id) then
				found = claim
			end
		end
		return found
	end
	M.own_draft = own_draft

	-- The characters a claim's notices go to: the members of an account
	-- claim (also once it is removed), else its owner.
	function M.owner_names(claim)
		if parse_owner_text(claim.owner) then return M.members(claim.owner) end
		return {claim.owner}
	end

	-- The drafts of every member of an owner text (ruling 16: activation
	-- removes them), ordered by id; `except` (a claim) is left out.
	function M.member_drafts(owner, except)
		local list = {}
		for _, claim in pairs(drafts) do
			if claim ~= except and claim.kind == M.ACCOUNT and
					M.account_owner_of(claim.owner) == owner then
				list[#list + 1] = claim
			end
		end
		table.sort(list, function(a, b) return a.id < b.id end)
		return list
	end

	-- Round 86: THE question "is this character an owner of this claim";
	-- nothing else compares claim.owner with a player name. The owner text is
	-- the character's name, or for an account claim a text no name can be
	-- (`account:<id>:<faction>`), which its members hold (account_owner_of).
	function M.is_owner(claim, name)
		if not claim or type(name) ~= "string" then return false end
		if name == claim.owner then return true end
		local account = M.account_owner_of(name)
		return account ~= nil and account == claim.owner
	end

	-- Home names (Round 86 lane NAMES; plan rulings 8, 12, 15, concept
	-- ruling 11). The record's `name` holds the home's name: the default
	-- "<character>'s Home" of the character that placed the stone, written
	-- at placement (placement_name), or what an owner typed (set_name).
	-- A typed name follows ruling 8: 1-NAME_MAX characters of ASCII letters,
	-- digits, space, apostrophe and hyphen, no leading or trailing space, so
	-- it never holds the record's "|" or a newline, a formspec's or a HUD
	-- line's escape or a colour code. A default is a player name (the same
	-- safe characters plus "_") with "'s Home" and may be longer.
	M.NAME_MAX = 24

	-- true, or false and the line that says why (every refusal names the
	-- rule the player broke).
	function M.valid_name(text)
		if type(text) ~= "string" or text == "" then
			return false, "Type a name for your home."
		end
		if text:find("[^A-Za-z0-9 '%-]") then
			return false, "A home's name may use only letters A-Z, digits, spaces, ' and -."
		end
		if #text > M.NAME_MAX then
			return false, ("A home's name has at most %d characters."):format(M.NAME_MAX)
		end
		if text:sub(1, 1) == " " or text:sub(-1) == " " then
			return false, "A home's name cannot start or end with a space."
		end
		return true
	end

	-- The default name of a claim (plan §2.3): "<owner>'s Home" (always 's);
	-- for an activated account claim (its owner an owner text, never shown)
	-- with the first member by name (the member index, M.members), "Home"
	-- while it has none. An account draft's owner is its placer.
	function M.default_name(claim)
		local holder = claim.owner
		if parse_owner_text(holder) then holder = M.members(holder)[1] end
		return holder and holder .. "'s Home" or "Home"
	end

	-- The home's name, what every display of a claim reads: the stored name,
	-- else (a record of 0.85.0, whose name is empty) the default.
	function M.home_name(claim)
		local name = claim.name
		if type(name) == "string" and name ~= "" then return name end
		return M.default_name(claim)
	end

	-- Stores a typed name (ruling 8, checked here, whatever a client sent).
	-- Who may rename is the caller's question (is_owner). Returns true, or
	-- false and the reason.
	function M.set_name(claim, text)
		if not claim or not claims[claim.id] then return false, "No such claim." end
		local ok, reason = M.valid_name(text)
		if not ok then return false, reason end
		claim.name = text
		save_claim(claim)
		return true
	end

	-- The admin reset (concept ruling 11): the default name again, stored.
	function M.reset_name(claim)
		if not claim or not claims[claim.id] then return false, "No such claim." end
		claim.name = M.default_name(claim)
		save_claim(claim)
		return true, claim.name
	end

	function M.permission(claim, name)
		if not claim or type(name) ~= "string" then return nil end
		if M.is_owner(claim, name) then return "owner" end
		return claim.permissions[name]
	end

	-- The 3 x 3 x 3 air cube directly above the stone (ruling 6).
	function M.in_arrival_cube(claim, pos)
		local c = claim.center
		local x, y, z = round(pos.x), round(pos.y), round(pos.z)
		return x >= c.x - 1 and x <= c.x + 1 and z >= c.z - 1 and z <= c.z + 1 and
			y >= c.y + 1 and y <= c.y + 3
	end

	function M.arrival_cube_claim(pos)
		local claim = M.claim_at(pos)
		if claim and M.in_arrival_cube(claim, pos) then return claim end
		return nil
	end

	-- Whether a claim protects pos against name. `open_at(pos)` tells whether
	-- the node there is a placement target (air or buildable_to); it is asked
	-- only inside an arrival cube, where it refuses every placement, for a
	-- draft and an empty stone too. `digging(pos, name)` (optional) tells
	-- whether name is punching or digging a node there that is not air: a
	-- buildable_to node in the cube (snow) is then judged like any other node
	-- of the claim, so the owner can dig it (R26 ruling 12). World protection
	-- and the protection_bypass privilege are the engine wrapper's business
	-- (protection.lua). A draft or an empty claim protects nothing else.
	function M.protects(pos, name, open_at, digging)
		local claim = M.claim_at(pos)
		if not claim then return false end
		if M.in_arrival_cube(claim, pos) and open_at(pos) and
				not (digging and digging(pos, name)) then
			return true, claim
		end
		if not M.is_active(claim) then return false end
		local level = M.permission(claim, name)
		if level == "owner" or level == "everything" then return false end
		return true, claim
	end

	-- Player records ----------------------------------------------------------

	local function record(name)
		local rec = players[name]
		if not rec then
			rec = {state = "never"}
			players[name] = rec
		end
		return rec
	end

	function M.player_state(name)
		local rec = players[name]
		return rec and rec.state or "never"
	end

	-- The character's claim and its state. A member's claim (Round 86) is
	-- its account's activated claim, else its own account draft, else nil.
	function M.player_claim(name)
		local rec = players[name]
		if not rec then return nil, "never" end
		if rec.state == "member" then
			return account_claims[rec.account] or own_draft(name), "member"
		end
		return rec.claim_id and claims[rec.claim_id] or nil, rec.state
	end

	-- Seconds until the owner may pick the stone up (R26 ruling 10: 12 h
	-- after activation; a draft never waits). There is no placing lock.
	function M.pickup_wait(claim)
		if not claim or M.is_draft(claim) then return 0 end
		return max(0, claim.activated_at + M.PICKUP_LOCK_SECONDS - now())
	end

	local function wait_text(seconds)
		local hours = floor(seconds / 3600)
		local minutes = ceil((seconds - hours * 3600) / 60)
		if minutes == 60 then hours, minutes = hours + 1, 0 end
		return ("%d h %02d min"):format(hours, minutes)
	end
	M.wait_text = wait_text

	-- Transitions -------------------------------------------------------------

	-- Round 86: a member's refusal of a personal stone.
	local MEMBER_LINE = "You chose the Account Claim Stone: leave your account's home " ..
		"here first to take a personal one."

	-- Ruling 7. `level` is the player's level, `holds_stone` whether the stone
	-- item is in the player's inventory. On success the state is "carried";
	-- the caller hands out the item.
	function M.can_issue(name, level, holds_stone)
		if (tonumber(level) or 0) < M.ISSUE_LEVEL then
			return false, "You need level " .. M.ISSUE_LEVEL ..
				" to receive a Claim Stone."
		end
		local rec = players[name]
		if rec and rec.state == "placed" and rec.claim_id and claims[rec.claim_id] then
			return false, "Your Claim Stone is already placed."
		end
		if rec and rec.state == "member" then
			return false, MEMBER_LINE
		end
		if holds_stone then
			return false, "You already carry a Claim Stone."
		end
		return true
	end

	function M.issue(name, level, holds_stone)
		local ok, message = M.can_issue(name, level, holds_stone)
		if not ok then return false, message end
		local rec = record(name)
		rec.state = "carried"
		rec.claim_id = nil
		save_player(name)
		return true, "You received a Claim Stone."
	end

	-- Ruling 8: a carried stone that was dropped (or otherwise lost).
	function M.stone_lost(name)
		local rec = players[name]
		if not rec or rec.state ~= "carried" then return false end
		rec.state = "needs_stone"
		save_player(name)
		return true
	end

	-- Round 86, the account Claim Stone (concept §3.1 rulings 1-8, plan
	-- rulings 13, 14, 16) ------------------------------------------------------

	-- Ruling 3: whether `name` may choose the account of `owner` (the owner
	-- text its binding and faction give). A character with a placed personal
	-- stone picks it up first; a carried one vanishes at the choice (the
	-- caller's).
	function M.can_join(name, level, owner)
		if (tonumber(level) or 0) < M.ISSUE_LEVEL then
			return false, "You need level " .. M.ISSUE_LEVEL ..
				" to choose a Claim Stone."
		end
		if not parse_owner_text(owner) then return false, "No account." end
		local rec = players[name]
		if rec and rec.state == "member" then
			if rec.account == owner then
				return false, "You already chose the Account Claim Stone."
			end
			return false, "You are in another account's home."
		end
		if rec and rec.state == "placed" and rec.claim_id and claims[rec.claim_id] then
			return false, "Pick up your Claim Stone first: a character with a placed " ..
				"stone cannot choose."
		end
		return true
	end

	-- The choice made: `name` is a member of `owner` (the caller asked
	-- can_join).
	function M.join(name, owner)
		local rec = record(name)
		rec.state, rec.claim_id, rec.account = "member", nil, owner
		member_add(name, owner)
		save_player(name)
		-- Who owns the account's claim changed (the minimap's frames).
		claim_set_version = claim_set_version + 1
	end

	-- Ruling 5: whether the Steward may hand the member an account stone:
	-- not while its account's claim stands (joining it gives no item), its
	-- own draft stands or it carries a stone.
	function M.can_issue_account(name, level, holds_stone)
		if (tonumber(level) or 0) < M.ISSUE_LEVEL then
			return false, "You need level " .. M.ISSUE_LEVEL ..
				" to receive a Claim Stone."
		end
		local rec = players[name]
		if not rec or rec.state ~= "member" then
			return false, "Choose the Account Claim Stone first."
		end
		if account_claims[rec.account] then
			return false, "Your account's home stands: you share it without a stone."
		end
		if own_draft(name) then
			return false, "Your Account Claim Stone is already placed."
		end
		if holds_stone then
			return false, "You already carry a Claim Stone."
		end
		return true
	end

	-- Ruling 6: leaving, only at the Steward (the caller's), never with the
	-- own draft standing and never as the last member of a standing claim
	-- (the last member picks the stone up instead). Then "personal, no
	-- stone" (needs_stone).
	function M.can_leave(name)
		local rec = players[name]
		if not rec or rec.state ~= "member" then return false, "You are in no account's home." end
		if own_draft(name) then
			return false, "Pick up your Account Claim Stone's draft first."
		end
		local claim = account_claims[rec.account]
		if claim then
			local others = 0
			for other in pairs(members[rec.account] or {}) do
				if other ~= name then others = others + 1 end
			end
			if others == 0 then
				return false, "You are the last character in your account's home: " ..
					"pick its Claim Stone up instead."
			end
		end
		return true
	end

	-- The end of a membership without the Steward's refusals: leaving
	-- (after can_leave), an unlink, a binding that stops counting, a faction
	-- change, the deletion (ruling 8, plan §2.3). The record becomes
	-- needs_stone; returns the owner text it left, the member's own draft
	-- (the caller removes it) and the account claim when no member is left
	-- (the caller ends it, or leaves it ownerless after a list change:
	-- ruling 18), or nil when `name` was no member.
	function M.end_membership(name)
		local rec = players[name]
		if not rec or rec.state ~= "member" then return nil end
		local owner = rec.account
		local draft = own_draft(name)
		member_remove(name, owner)
		rec.state, rec.account, rec.claim_id = "needs_stone", nil, nil
		save_player(name)
		claim_set_version = claim_set_version + 1 -- its owners changed
		local orphan = not members[owner] and account_claims[owner] or nil
		return owner, draft, orphan
	end

	-- Placement validation (rulings 2, 3, 5, 6; Round 85 rulings 6, 14-16).
	-- `world`:
	--   mask                 the claim mask of the world (grug_housing.mask,
	--                        claim_mask.lua), or nil when its build failed:
	--                        then every placement is refused
	--   cube_clear(pos)      true when the 3 x 3 x 3 cube above pos is air
	--   kind_name(id)        (optional) a quota kind's name in the player's
	--                        words (its spawn area's name), for the message
	--
	-- The mask answers whether the stone's chunk is claim ground for the
	-- faction, as a whole (its zones, water, settlements, roads, camps,
	-- leaders, quest places, rare routes and the capital rings), with the
	-- rule that refused; the quota keeps half of every quest-named kind's
	-- ground free (`taken` over every claim record, drafts and expired ones
	-- included).
	local MESSAGES = {
		too_deep = "A Claim Stone cannot stand below y = " .. M.MIN_Y .. ".",
		no_faction = "Choose a faction first.",
		already_placed = "Your Claim Stone is already placed.",
		no_mask = "Claim Stones cannot be placed right now: this world's claim " ..
			"map failed to build. Tell an admin.",
		taken = "This claim square (80 x 80) already holds another Claim Stone.",
		quota = "This claim square (80 x 80) would put more than half of %s " ..
			"under claims; half of it stays free for the creatures quests send you after.",
		edge = "Too close to the edge of the claim square: place the stone at " ..
			"least one node further inside.",
		cube = "The 3 x 3 x 3 space above the stone must be empty.",
		-- the mask's reasons (claim_mask.lua), in its order
		shelf = "This claim square (80 x 80) reaches over the coastal shelf.",
		sea = "This claim square (80 x 80) reaches over the open sea.",
		enemy = "This claim square (80 x 80) reaches into enemy territory.",
		low_level = "This claim square (80 x 80) reaches into a level 1-10 zone.",
		high_level = "This claim square (80 x 80) reaches into a level 31+ zone.",
		not_home = "The whole claim square (80 x 80) must lie in your faction's " ..
			"home land.",
		town = "This claim square (80 x 80) comes within 16 nodes of a town or a " ..
			"protected landmark.",
		deep_water = "This claim square (80 x 80) reaches over protected deep " ..
			"water (24 nodes or more off the coast).",
		site = "This claim square (80 x 80) comes within 16 nodes of a village, " ..
			"camp or point of interest.",
		landmark = "This claim square (80 x 80) comes within 16 nodes of a " ..
			"protected landmark.",
		road = "A road runs through this claim square (80 x 80).",
		camp = "A camp's grounds reach into this claim square (80 x 80).",
		leader = "This claim square (80 x 80) comes within 16 nodes of where a " ..
			"zone leader stands.",
		place = "This claim square (80 x 80) comes within 16 nodes of a quest place.",
		rare = "This claim square (80 x 80) comes within 16 nodes of a rare " ..
			"creature's path.",
		capital_ring = "This claim square (80 x 80) lies next to a capital city: " ..
			"keep one whole square between your home and its walls.",
		not_ground = "This claim square (80 x 80) is no claim ground.",
	}
	M.MESSAGES = MESSAGES

	-- The quota's taken columns for `mask` (kind id -> columns), built from
	-- every claim record on the first call for a mask and then kept by
	-- create and remove. Read it, never write it.
	function M.quota_taken(mask)
		if taken_for ~= mask then
			taken, taken_for = {}, mask
			for _, claim in pairs(claims) do
				local cx, cz = claim_chunk(claim)
				mask.add_taken(taken, cx, cz, 1)
			end
		end
		return taken
	end

	-- Round 86: the account stone's own refusals (ruling 16). "not_member"
	-- and "account_stands" make the stone vanish (the caller's).
	MESSAGES.not_member = "This Account Claim Stone crumbles: you are in no " ..
		"account's home of this faction. A Housing Steward lets you choose one."
	MESSAGES.account_stands = "Your account's home already stands: this Account " ..
		"Claim Stone crumbles."
	MESSAGES.own_draft = "Your Account Claim Stone is already placed."
	MESSAGES.member = "You chose the Account Claim Stone: this Claim Stone is " ..
		"not yours to place."

	-- Returns true, or false, code, message (and for "quota" the kind id).
	-- The refusals keep this order: the player's own state first (depth,
	-- faction, one claim), then the chunk (the mask's rule, another claim in
	-- it, the quota), and last the two the player can fix on the spot (the
	-- chunk's edge, the arrival cube). `kind` (Round 86): the stone's claim
	-- kind, "" by default; an account stone needs a membership of the
	-- placer's faction whose claim does not stand and no own draft (ruling
	-- 16: every member may place a draft, only one is ever activated).
	function M.validate(name, faction, pos, world, kind)
		local function refuse(code, message)
			return false, code, message or MESSAGES[code]
		end
		local x, y, z = round(pos.x), round(pos.y), round(pos.z)
		if y < M.MIN_Y then return refuse("too_deep") end
		if faction ~= "accord" and faction ~= "throng" then
			return refuse("no_faction")
		end
		local rec = players[name]
		if kind == M.ACCOUNT then
			local owner = rec and rec.state == "member" and rec.account
			local _, owner_faction = parse_owner_text(owner)
			if owner_faction ~= faction then return refuse("not_member") end
			if account_claims[owner] then return refuse("account_stands") end
			if own_draft(name) then return refuse("own_draft") end
		elseif rec and rec.state == "member" then
			return refuse("member")
		elseif rec and rec.state == "placed" and rec.claim_id and claims[rec.claim_id] then
			return refuse("already_placed")
		end
		local mask = world.mask
		if not mask then return refuse("no_mask") end
		local cx, cz = chunk_of(x), chunk_of(z)
		local ground, reason = mask.ground(faction, cx, cz)
		if not ground then return refuse(MESSAGES[reason] and reason or "not_ground") end
		-- Drafts and expired claims hold their chunk too (R26 ruling 8): one
		-- claim record per chunk.
		if M.chunk_claim(cx, cz) then return refuse("taken") end
		local kind = mask.quota_refusal(cx, cz, M.quota_taken(mask))
		if kind then
			local label = world.kind_name and world.kind_name(kind) or kind
			return false, "quota", MESSAGES.quota:format(label), kind
		end
		local x0, z0 = CHUNK * cx + ORIGIN, CHUNK * cz + ORIGIN
		if x == x0 or x == x0 + CHUNK - 1 or z == z0 or z == z0 + CHUNK - 1 then
			return refuse("edge")
		end
		if not world.cube_clear({x = x, y = y, z = z}) then return refuse("cube") end
		return true
	end

	-- Round 86: the home's name stored when character `name` places a stone
	-- of `kind`: "<name>'s Home" for every kind (rulings 12, 15: an account
	-- claim's default names the character that placed it too).
	function M.placement_name(name, kind)
		return name .. "'s Home"
	end

	-- Rulings 3-6 accepted: the new claim, a draft (R26 ruling 8) until the
	-- owner activates it. `kind` (Round 86, optional): the stone's claim
	-- kind, "" (the personal stone) by default; `name` from placement_name
	-- (the default "<name>'s Home").
	function M.create(name, pos, kind)
		kind = kind or ""
		local t = now()
		local claim = {id = next_id, owner = name,
			center = {x = round(pos.x), y = round(pos.y), z = round(pos.z)},
			placed_at = t, activated_at = 0, paid_until = t, expired_for = t,
			permissions = {}, kind = kind, name = M.placement_name(name, kind)}
		next_id = next_id + 1
		storage.set_string("next_id", tostring(next_id))
		claims[claim.id] = claim
		claim_count = claim_count + 1
		claim_set_version = claim_set_version + 1
		index_add(claim)
		if taken then
			local cx, cz = claim_chunk(claim)
			taken_for.add_taken(taken, cx, cz, 1)
		end
		drafts[claim.id] = claim
		save_claim(claim)
		-- An account draft leaves its placer a member (ruling 16).
		if kind ~= M.ACCOUNT then
			local rec = record(name)
			rec.state, rec.claim_id = "placed", claim.id
			save_player(name)
		end
		return claim
	end

	-- `reason` "picked_up": the owner carries the stone again; "draft_expired":
	-- the draft crumbled, the owner needs a new stone ("needs_stone", issued
	-- at once); "removed": an admin removed it (state "removed", a new stone
	-- at once); anything else ("destroyed", and "deleted", whose caller then
	-- drops the record with forget_player): the owner's state becomes
	-- "destroyed". An account claim or draft (Round 86) changes no record:
	-- every member stays a member and may get an account stone again (rulings
	-- 5, 8, 13), and no `player:` record is made for an owner text.
	function M.remove(claim, reason)
		if not claims[claim.id] then return false end
		claims[claim.id] = nil
		drafts[claim.id] = nil
		claim_count = claim_count - 1
		claim_set_version = claim_set_version + 1
		index_remove(claim)
		if taken then
			local cx, cz = claim_chunk(claim)
			taken_for.add_taken(taken, cx, cz, -1)
		end
		storage.set_string("claim:" .. claim.id, "")
		if claim.kind == M.ACCOUNT then
			if account_claims[claim.owner] == claim then account_claims[claim.owner] = nil end
			return true
		end
		local rec = record(claim.owner)
		if rec.claim_id == claim.id then rec.claim_id = nil end
		if reason == "picked_up" then
			rec.state = "carried"
		elseif reason == "draft_expired" then
			rec.state = "needs_stone"
		elseif reason == "removed" then
			rec.state = "removed"
		else
			rec.state = "destroyed"
		end
		save_player(claim.owner)
		return true
	end

	-- Round 86 ruling 16: why an account draft cannot be activated
	-- ("not_member": its placer is in no account's home; "account_stands":
	-- the account's claim stands), else nil.
	function M.activation_refusal(claim)
		if claim.kind ~= M.ACCOUNT then return nil end
		local owner = M.account_owner_of(claim.owner)
		if not owner then return "not_member" end
		if account_claims[owner] then return "account_stands" end
		return nil
	end

	-- R26 ruling 9: activation of a draft with `count` lumps, at least
	-- ACTIVATION_LUMPS, at most FUEL_MAX. Starts the fuel, the protection and
	-- the pick-up lock. Returns the lumps burnt, or 0 and a reason code
	-- ("no_claim", "active", "too_few"; Round 86 for an account draft
	-- "not_member" and "account_stands"). Round 86 ruling 16: an account
	-- draft becomes its placer's account claim (its owner the owner text);
	-- only one per owner text is ever activated (member_drafts lists the
	-- others for the caller to remove).
	function M.activate(claim, count)
		count = floor(tonumber(count) or 0)
		if not claim or not claims[claim.id] then return 0, "no_claim" end
		if not M.is_draft(claim) then return 0, "active" end
		local refusal = M.activation_refusal(claim)
		if refusal then return 0, refusal end
		local owner = claim.kind == M.ACCOUNT and M.account_owner_of(claim.owner) or nil
		if count < M.ACTIVATION_LUMPS then return 0, "too_few" end
		local accepted = min(count, M.FUEL_MAX)
		local t = now()
		if owner then
			claim.owner = owner
			account_claims[owner] = claim
			-- Its owners changed from the placer to the members.
			claim_set_version = claim_set_version + 1
		end
		claim.activated_at = t
		claim.paid_until = t + accepted * M.LUMP_SECONDS
		drafts[claim.id] = nil
		note_expiry(claim)
		save_claim(claim)
		return accepted
	end

	-- Drafts whose DRAFT_SECONDS ran out, ordered by id; the caller removes
	-- them (reason "draft_expired"). Wall-clock time, so server downtime
	-- counts as it does for fuel.
	function M.draft_scan()
		local t, result = now(), {}
		for _, claim in pairs(drafts) do
			if claim.activated_at == 0 and claim.placed_at + M.DRAFT_SECONDS <= t then
				result[#result + 1] = claim
			end
		end
		table.sort(result, function(a, b) return a.id < b.id end)
		return result
	end

	-- Ruling 10: burns up to count pieces of `seconds_each` (default one
	-- lump; Round 47 ruling 12) into paid_until; returns the number accepted
	-- (never more than fit whole under the cap). A draft takes no fuel: it
	-- is activated first (R26 ruling 9).
	function M.add_fuel(claim, count, seconds_each)
		count = floor(tonumber(count) or 0)
		seconds_each = tonumber(seconds_each) or M.LUMP_SECONDS
		if not claim or not claims[claim.id] or count <= 0 or seconds_each <= 0 or
				M.is_draft(claim) then
			return 0
		end
		local accepted = min(count, M.fuel_room(claim, seconds_each))
		if accepted <= 0 then return 0 end
		claim.paid_until = max(now(), claim.paid_until) + accepted * seconds_each
		note_expiry(claim)
		save_claim(claim)
		return accepted
	end

	-- The deletion of a character (Round 83): its record goes from memory and
	-- storage. Its claims are removed first (M.remove saves the record).
	function M.forget_player(name)
		local rec = players[name]
		if rec and rec.state == "member" then member_remove(name, rec.account) end
		players[name] = nil
		storage.set_string("player:" .. name, "")
	end

	function M.set_permission(claim, name, level)
		if not claim or not claims[claim.id] then return false, "No such claim." end
		if type(name) ~= "string" or not name:match("^[%w_%-]+$") then
			return false, "Invalid player name."
		end
		-- Round 86: an owner's old entry (a member that was named before it
		-- joined) may be removed; it would apply again once it leaves.
		if level ~= nil and M.is_owner(claim, name) then
			return false, "The owner always has access."
		end
		if level ~= nil and not LEVELS[level] then
			return false, "Unknown permission level."
		end
		claim.permissions[name] = level
		save_claim(claim)
		if level then return true, name .. ": " .. level .. "." end
		return true, name .. " removed."
	end

	-- Claims whose fuel ran out since the last scan (each paid_until reported
	-- once), ordered by id. A draft is never reported.
	function M.expiry_scan()
		local t, result = now(), {}
		if not next_expiry or t < next_expiry then return result end
		next_expiry = nil
		for _, claim in pairs(claims) do
			if claim.paid_until <= t and claim.expired_for ~= claim.paid_until then
				claim.expired_for = claim.paid_until
				save_claim(claim)
				result[#result + 1] = claim
			else
				note_expiry(claim)
			end
		end
		table.sort(result, function(a, b) return a.id < b.id end)
		return result
	end

	return M
end
