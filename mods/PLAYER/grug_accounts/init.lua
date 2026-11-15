-- Website accounts, phase 1 (Round 79, docs/technical/web-accounts.md;
-- round79-plan.md §3): a character may be linked to an account on the
-- realm's website, and the rewards the administrator grants that account
-- reach every linked character. The website owns accounts, bindings and
-- rewards; this mod keeps its list (model.lua), runs the link by code
-- (flow.lua) and gives every character its id. grug_bridge carries it all;
-- without the bridge the stored list still grants its rewards and nothing is
-- sent.
grug_accounts = {}

local path = core.get_modpath(core.get_current_modname())
local Model = dofile(path .. "/model.lua")
local Flow = dofile(path .. "/flow.lua")

local META_ID = "grug_accounts:character_id"
local META_SEEN = "grug_accounts:seen"

-- The one place the page names (rulings 13 and 17).
grug_accounts.WEBSITE = "grudgelands.com/play"

local function log(level, text)
	core.log(level, "[grug_accounts] " .. text)
end

local secure
do
	local ok, source = pcall(function() return SecureRandom() end)
	if ok then secure = source end
end
local fallback_count = 0

-- `bytes` random bytes as lower-case hex.
local function random_hex(bytes)
	local raw
	if secure then raw = secure:next_bytes(bytes) end
	if type(raw) ~= "string" or #raw ~= bytes then
		fallback_count = fallback_count + 1
		return core.sha1(table.concat({os.time(), core.get_us_time(), fallback_count,
			math.random()}, ":")):sub(1, bytes * 2)
	end
	return (raw:gsub(".", function(char) return ("%02x"):format(char:byte()) end))
end

local ids = {}         -- online name -> character id (its meta)
local own_success = {} -- name -> the success line of its own request
local push_event       -- set by attach: the bridge's event queue
local change_callbacks, state_callbacks = {}, {}
local mods_loaded = false

local model = Model({storage = core.get_mod_storage(), serialize = core.serialize,
	deserialize = core.deserialize, log = log,
	online_id = function(name) return ids[name] end})
model.load()

-- Still being created: no class or faction yet, or created but not arrived
-- (grug_classes sets its arriving mark at "Create character" and clears it
-- at the arrival teleport, right before the arrival callbacks run).
local function in_creation(player)
	return grug_classes.get_class(player) == nil or grug_factions.get_faction(player) == nil or
		player:get_meta():get_string("grug_classes:arriving") ~= ""
end

-- The character's id, given at its first join (also in character creation)
-- and never changed: web-accounts.md §2.
local function ensure_id(player)
	local name = player:get_player_name()
	if ids[name] then return ids[name] end
	local meta = player:get_meta()
	local id, write = model.assign_id(name, meta:get_string(META_ID), function()
		return random_hex(16)
	end)
	if write then meta:set_string(META_ID, id) end
	ids[name] = id
	return id
end

-- The binding and reward notices since what the character last saw; they
-- wait while it is being created (the arrival runs this again).
local function report(player)
	if in_creation(player) then return end
	local name = player:get_player_name()
	local meta = player:get_meta()
	local seen = meta:get_string(META_SEEN)
	local lines, now_seen = model.notices(seen, name, own_success[name])
	own_success[name] = nil
	for _, line in ipairs(lines) do grug_core.feed(player, "notice", line) end
	if now_seen ~= seen then meta:set_string(META_SEEN, now_seen) end
end

local flow = Flow({
	now = os.time,
	schedule = core.after,
	push = function(event) if push_event then push_event(event) end end,
	new_request_id = function() return random_hex(8) end,
	enabled = function() return grug_accounts.enabled() end,
	in_creation = function(name)
		local player = core.get_player_by_name(name)
		return not player or in_creation(player)
	end,
	online = function(name) return core.get_player_by_name(name) ~= nil end,
	character_id = function(name) return ids[name] end,
	account_of = model.account_of,
	clean = model.clean,
	log = log,
	on_state = function(name)
		local player = core.get_player_by_name(name)
		if not player then return end
		for _, callback in ipairs(state_callbacks) do callback(player) end
	end,
	on_linked = function(name, text)
		own_success[name] = text
		local player = core.get_player_by_name(name)
		if player then report(player) end
	end,
})

--
-- The API (round79-plan.md §3.3)
--

function grug_accounts.enabled()
	return push_event ~= nil and model.version() > 0
end

function grug_accounts.character_id(player)
	return ensure_id(player)
end

function grug_accounts.account_of(name)
	return model.account_of(name)
end

-- Still being created (the Account page shows only can_link's line then).
function grug_accounts.in_creation(player)
	return in_creation(player)
end

function grug_accounts.can_link(player)
	return flow.can_request(player:get_player_name())
end

function grug_accounts.has_reward(name, reward_id)
	return model.has_reward(name, reward_id)
end

function grug_accounts.rewards_of(name)
	return model.rewards_of(name)
end

function grug_accounts.register_reward(id, def)
	assert(not mods_loaded, "grug_accounts.register_reward: only at load time")
	model.register_reward(id, def)
end

function grug_accounts.catalog()
	return model.catalog()
end

-- callback(names): the names whose binding or rewards changed (online or
-- not), after a list was applied.
function grug_accounts.register_on_change(callback)
	assert(type(callback) == "function", "grug_accounts.register_on_change: not a function")
	change_callbacks[#change_callbacks + 1] = callback
end

function grug_accounts.link_state(player)
	return flow.state(player:get_player_name())
end

function grug_accounts.request_link(player, text)
	return flow.request(player:get_player_name(), text)
end

function grug_accounts.confirm_link(player)
	return flow.confirm(player:get_player_name())
end

function grug_accounts.cancel_link(player)
	return flow.cancel(player:get_player_name())
end

-- callback(player): the link state shown on the page changed.
function grug_accounts.register_on_link_state(callback)
	assert(type(callback) == "function", "grug_accounts.register_on_link_state: not a function")
	state_callbacks[#state_callbacks + 1] = callback
end

--
-- The bridge's side: grug_bridge calls only these.
--

function grug_accounts.attach(push)
	push_event = push
end

-- The list from a response (web-accounts.md §5.2): applied when its version
-- differs. Open requests of characters it binds end, the online characters
-- read their notices, then the change callbacks run.
function grug_accounts.apply_list(list)
	local names = model.apply(list)
	if not names then return false end
	for _, name in ipairs(names) do
		local player = core.get_player_by_name(name)
		if player then
			flow.list_applied(name)
			report(player)
		end
	end
	if #names > 0 then
		for _, callback in ipairs(change_callbacks) do callback(names) end
	end
	return true
end

function grug_accounts.link_answer(args)
	return flow.answer(args)
end

function grug_accounts.catalog_rows()
	return model.catalog_rows()
end

function grug_accounts.accounts_version()
	return model.version()
end

--
-- Hooks
--

core.register_on_mods_loaded(function() mods_loaded = true end)

core.register_on_joinplayer(function(player)
	ensure_id(player)
	report(player)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	flow.leave(name)
	ids[name], own_success[name] = nil, nil
end)

grug_classes.register_on_arrival(report)

-- The Account page (the PAGE lane writes it).
dofile(path .. "/page.lua")
