-- The game's own letters (Round 48, mail plan rulings 15-16, 17.3, §3.19,
-- §3.20; docs/design/mail.md §8), each sent once per character through
-- grug_mail.send_system, with a player-meta flag set once it went out:
--   * the welcome letter, an admin letter, at the arrival or at the first
--     join of a character created before mail existed;
--   * the Riding Trainer's letter at level 15, only while the character
--     owns no riding tier;
--   * the Housing Steward's letter at level 20, only while the character
--     never had a Claim Stone.
-- The level letters follow grug_xp.register_on_level_change: once per jump
-- (14 -> 21 sends both) and at every join, so an existing character gets a
-- letter late, and only while it is still useful. A letter that is no
-- longer useful is never sent (its flag is set without it).

local TEXTS = grug_mail.texts

-- A created character (the arrival or a join after it); a player still
-- creating one stores nothing (grug_classes/selection.lua). The starter
-- quest's grant asks the same (quest.lua).
function grug_mail.character_ready(player)
	return grug_classes.get_class(player) ~= nil and grug_factions.get_faction(player) ~= nil
end

local WELCOME = "grug_mail:welcome_sent"
local LEVEL_LETTERS = {
	{flag = "grug_mail:letter_riding", level = 15, from = "Riding Trainer", text = TEXTS.riding,
		-- No riding tier yet (a boat is the Shipwright's, not a riding tier).
		useful = function(player)
			for _, id in ipairs(grug_mounts.owned_tier_ids(player)) do
				for _, riding in ipairs(grug_mounts.RIDING_TIERS) do
					if id == riding then return false end
				end
			end
			return true
		end},
	{flag = "grug_mail:letter_housing", level = 20, from = "Housing Steward", text = TEXTS.housing,
		-- Never had a Claim Stone (a lost or picked-up one is not "never").
		useful = function(player)
			local _, state = grug_housing.player_claim(player:get_player_name())
			return state == "never"
		end},
}
grug_mail.LEVEL_LETTERS = LEVEL_LETTERS

-- The display name of the player's race capital (the settlement in the
-- capital slot of the player's race), read once per race.
local capitals
local function capital_of(player)
	if not capitals then
		capitals = {}
		for _, row in ipairs(grug_core.settlement_socket_settlements()) do
			if row.slot == "capital" and row.race_id then
				capitals[row.race_id] = row.display_name or row.key
			end
		end
	end
	return capitals[grug_classes.get_race(player) or ""] or "your capital"
end
grug_mail.capital_of = capital_of

-- {player} and {capital} filled at send time (never a fixed place in the
-- text, the quest-text rule).
local function fill(text, player)
	local name = player:get_player_name()
	return (text:gsub("{player}", function() return name end)
		:gsub("{capital}", function() return capital_of(player) end))
end
grug_mail.fill_letter = fill

local function send(player, kind, from, text)
	return grug_mail.send_system(player:get_player_name(), kind, from, fill(text.subject, player),
		fill(text.body, player))
end

-- The welcome letter, once per character.
function grug_mail.send_welcome(player)
	local meta = player:get_meta()
	if meta:get_string(WELCOME) ~= "" or not grug_mail.character_ready(player) then return false end
	local ok = send(player, "admin", nil, TEXTS.welcome)
	if ok then meta:set_string(WELCOME, "1") end
	return ok == true
end

-- The level letters a character at `level` is owed, in level order.
function grug_mail.send_level_letters(player, level)
	if not grug_mail.character_ready(player) then return end
	local meta = player:get_meta()
	for _, letter in ipairs(LEVEL_LETTERS) do
		if level >= letter.level and meta:get_string(letter.flag) == "" then
			local ok = true
			if letter.useful(player) then ok = send(player, "npc", letter.from, letter.text) end
			if ok then meta:set_string(letter.flag, "1") end
		end
	end
end

core.register_on_joinplayer(grug_mail.send_welcome)
grug_classes.register_on_arrival(grug_mail.send_welcome)
grug_xp.register_on_level_change(function(player, _, new_level)
	grug_mail.send_level_letters(player, new_level)
end)
