-- Round 85 lane RESET portable test (docs/planning/round85-plan.md §4 RESET,
-- §3.3): after the 0.85.0 map reset no claim record is left, whatever its
-- version, the Housing Steward hands out stones and a Claim Stone home falls
-- back to the innkeeper. Loads the REAL files under minimal stubs:
--
--   A. grug_housing/registry.lua: a world with a v2 claim (production's
--      0.83.0 record) and a v3 claim (the record of plan §3.3), a record of
--      another version and the pre-reset pass's entries. The load reads
--      whichever version this checkout's registry knows; M.map_reset then
--      clears every `claim:` key of every version, both owners need a new
--      stone and may take one, a carried stone stays, the pass's
--      `recovered:` / `packed:` entries, `pack_seq` and `next_id` stay; a
--      second clear and a reload change nothing;
--   B. grug_home/claim_home.lua on that registry: a home set to either claim
--      falls back to the innkeeper at once (grug_home.get), the stale target
--      is dropped at the next join with the message, and the relocation
--      clear it registers with grug_core.map_reset empties the target.
--
-- The existing proofs of the same path, for the v2 record: tools/r41_up
-- (B3 the registry's clear, C the relocation), tools/r25_home_stone (F a
-- stale claim home), tools/r50_pgame (C the entries across M.map_reset).
-- This test holds both record versions, so it stands before and after the
-- registry moves to v3.
--
-- Usage (repo root): luajit tools/r85_reset/portable_test.lua [repo]
local repo = arg and arg[1] or "."
local failures, checks = 0, 0
local function check(ok, label)
	checks = checks + 1
	if not ok then
		failures = failures + 1
		print("FAIL " .. label)
	end
	return ok
end
local function eq(actual, expected, label)
	return check(actual == expected, label .. " (got " .. tostring(actual) ..
		", expected " .. tostring(expected) .. ")")
end
local function snapshot(t)
	local rows = {}
	for k, v in pairs(t) do rows[#rows + 1] = k .. "=" .. tostring(v) end
	table.sort(rows)
	return table.concat(rows, "\n")
end

-- The world as the pre-reset pass leaves it. Records: v2 as 0.50.0 to 0.84.x
-- write it, v3 exactly as plan §3.3 agrees it (12 fields, kind and name empty).
local V2 = "v2|alice|100|10|100|900|950|99999|0|bob=interact"
local V3 = "v3|bob|-33|-100|48|900|950|99999|0|||"
local data = {
	next_id = "9",
	["claim:3"] = V2,
	["claim:7"] = V3,
	["claim:8"] = "v4|future|0|0|0|1|1|1|1||||",
	["player:alice"] = "v2|placed|3",
	["player:bob"] = "v2|placed|7",
	["player:carol"] = "v2|carried|0",
	["player:dave"] = "v2|destroyed|0",
	pack_seq = "1",
	["recovered:alice:1:1"] = "grug_housing:packed_container 1 0 \"\\u0001seq\\u00021\\u0003\"",
	["recovered:bob:1:1"] = "grug_smelting:charcoal 4",
	["packed:alice:1:1"] = "return {}",
}
local _, bars = V3:gsub("|", "|")
eq(bars + 1, 12, "A the v3 record has twelve fields")

-- A. The registry's map reset.
local function model()
	local storage = {
		get_string = function(k) return data[k] or "" end,
		set_string = function(k, v) if v == "" then data[k] = nil else data[k] = v end end,
		keys = function()
			local keys = {}
			for k in pairs(data) do keys[#keys + 1] = k end
			table.sort(keys)
			return keys
		end,
	}
	local m = dofile(repo .. "/mods/PLAYER/grug_housing/registry.lua")({
		storage = storage, now = function() return 1000 end})
	m.load()
	return m
end
local m = model()
check(m.claim_count() <= 2, "A the load reads at most the two claims it knows")
m.map_reset()
local left = {}
for k in pairs(data) do
	if k:match("^claim:") then left[#left + 1] = k end
end
eq(table.concat(left, ","), "", "A no claim record of any version is left")
eq(m.claim_count(), 0, "A no claim after the reset")
eq(m.claim_at({x = 100, y = 10, z = 100}), nil, "A the v2 square protects nothing")
eq(m.claim_at({x = -33, y = 0, z = 48}), nil, "A ...nor the v3 chunk")
eq(data.next_id, "9", "A the id counter stays")
for _, name in ipairs({"alice", "bob"}) do
	local claim, state = m.player_claim(name)
	check(claim == nil and state == "needs_stone", "A " .. name .. "'s placed stone needs a new one")
	eq(m.can_issue(name, 20, false), true, "A the Housing Steward hands " .. name .. " a stone")
end
eq(m.player_state("carol"), "carried", "A a carried stone stays carried")
eq(m.can_issue("carol", 20, true), false, "A ...and no second one")
eq(m.player_state("dave"), "destroyed", "A other records stay")
eq(data.pack_seq, "1", "A pack_seq stays")
check(data["recovered:alice:1:1"] ~= nil and data["recovered:bob:1:1"] ~= nil and
	data["packed:alice:1:1"] ~= nil, "A the pass's entries and contents stay")
local after = snapshot(data)
m.map_reset()
eq(snapshot(data), after, "A a second clear changes nothing")
m = model()
eq(m.claim_count(), 0, "A a later start loads no claim")
eq(snapshot(data), after, "A ...and writes nothing")

-- B. The Claim Stone home on that registry (grug_home/claim_home.lua).
local chat, joins, relocate = {}, {}, {}
local home_meta = {alice = {["grug_home:claim"] = "3"}, bob = {["grug_home:claim"] = "7"}}
local function player(name)
	local meta = home_meta[name]
	return {
		get_player_name = function() return name end,
		is_player = function() return true end,
		get_meta = function()
			return {
				get_string = function(_, k) return meta[k] or "" end,
				set_string = function(_, k, v) if v == "" then meta[k] = nil else meta[k] = v end end,
			}
		end,
	}
end
local home_storage = {}
core = {
	get_mod_storage = function()
		return {
			get_string = function(_, k) return home_storage[k] or "" end,
			set_string = function(_, k, v) if v == "" then home_storage[k] = nil else home_storage[k] = v end end,
		}
	end,
	register_on_joinplayer = function(fn) joins[#joins + 1] = fn end,
	chat_send_player = function(name, text) chat[#chat + 1] = name .. ": " .. text end,
}
vector = {new = function(x, y, z) return {x = x, y = y, z = z} end}
grug_core = {map_reset = {register_on_relocate = function(fn) relocate[#relocate + 1] = fn end}}
grug_factions = {get_faction = function() return "accord" end}
grug_housing = {
	player_claim = m.player_claim,
	is_owner = m.is_owner, -- Round 86: the owner question
	is_draft = m.is_draft,
	is_active = m.is_active,
	arrival_pos = function(claim) return {x = claim.center.x, y = claim.center.y + 1, z = claim.center.z} end,
	register_on_claim_changed = function() end,
}
local INN = {id = "highcourt", label = "Highcourt"}
grug_home = {innkeeper = function() return INN end, cancel = function() end}
dofile(repo .. "/mods/PLAYER/grug_home/claim_home.lua")
eq(#relocate, 1, "B claim_home registers one relocation clear")
eq(grug_home.get(player("alice")), INN, "B alice's home falls back to the innkeeper at once")
eq(grug_home.home_is_claim(player("bob")), false, "B ...so does bob's")
for _, fn in ipairs(joins) do fn(player("bob")) end
eq(home_meta.bob["grug_home:claim"], nil, "B bob's stale target is dropped at the join")
eq(chat[1], "bob: Your Claim Stone is gone. Your home is now the Highcourt Innkeeper.",
	"B ...with the message")
for _, fn in ipairs(relocate) do fn(player("alice")) end
eq(home_meta.alice["grug_home:claim"], nil, "B the relocation clears alice's target")
eq(#chat, 1, "B ...silently")
local ok, message = grug_home.set_home_claim(player("alice"))
check(not ok and message == "You have no placed Claim Stone.", "B no claim to set as home")

if failures > 0 then
	error("R85 RESET FIXTURE FAIL failures=" .. failures .. " checks=" .. checks, 0)
end
print("R85 RESET FIXTURE PASS checks=" .. checks)
