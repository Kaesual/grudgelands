-- The deletion of a character (Round 83, docs/technical/web-bridge.md
-- "character.delete"; the rule: module guide, "Rules for every mod"): the
-- one registry of what is cleared. Every mod that keeps a store keyed by a
-- character's name (mod storage or memory that outlives a logout) defines
-- `<its table>.forget_character(name)` and is listed in MODS below.
-- grug_bridge's deletion runs them all after the engine is done with the
-- player, and again right before the engine removes the auth entry and the
-- player record.
--
-- A clear takes the exact name and must:
--   - work for an offline character (no ObjectRef; player meta goes with the
--     engine's player record and needs no clear);
--   - be idempotent and cheap when nothing is stored (it runs twice, and for
--     every deleted name, most of which hold nothing in most stores);
--   - keep what other characters hold about the name as their data (letters,
--     sent copies, reports) and apply the mod's own rules to a shared record
--     (a clan's or a party's successor);
--   - never call core.set_player_privs or core.set_player_password: both
--     create an auth entry for a missing name.
--
-- The list is the order, read at the deletion (not at load: the mods are
-- loaded by then, and a fixture that loads one of them needs no stub of this
-- file). The order matters:
--   grug_accounts first     the tombstone in the id index
--   grug_parties            before grug_expeditions: its member-left callback
--                           expels the name from a party's run or hands the
--                           run to the last member
--   grug_housing            before grug_home: a claim removal is heard there
--                           (the event "deleted" writes no notice, and
--                           grug_home's clear drops any notice last)

local M = {}

M.MODS = {"grug_accounts", "grug_classes", "grug_parties", "grug_clans",
	"grug_expeditions", "grug_housing", "grug_home", "grug_mail", "grug_achievements"}

local function clear_of(mod)
	local tab = rawget(_G, mod)
	return type(tab) == "table" and tab.forget_character or nil
end

-- The listed mods that lack their clear (a renamed function or a mod left out
-- of the game): checked once every mod has loaded, so a gap stops the start.
function M.missing()
	local list = {}
	for _, mod in ipairs(M.MODS) do
		if type(clear_of(mod)) ~= "function" then list[#list + 1] = mod end
	end
	return list
end

-- Runs every clear for `name`, in order. One failing clear does not stop the
-- others; the error afterwards names every mod that failed (the deletion then
-- answers `error`, and the website's retry runs them again).
function M.clear(name)
	assert(type(name) == "string" and name ~= "", "grug_core.character_delete.clear: a name")
	local failed = {}
	for _, mod in ipairs(M.MODS) do
		local ok, err = pcall(clear_of(mod), name)
		if not ok then
			failed[#failed + 1] = mod
			core.log("error", ("[grug_core] the character clear of %s failed: %s"):format(
				mod, tostring(err)))
		end
	end
	if #failed > 0 then
		error("character clears failed: " .. table.concat(failed, ", "), 0)
	end
end

return M
