-- The starter quest "Use a mailbox in one of the cities" (Round 48, mail plan
-- ruling 15, §3.18; docs/design/mail.md §8): a system quest of grug_quests
-- (no NPC, no objectives), one id for both factions. Every character gets it
-- once: at its arrival, or at a join while it has not had it yet. Opening any
-- mailbox turns it in through grug_quests.turn_in, the one completion path,
-- so turn-in listeners and achievements see it. A full quest log skips it for
-- good.

local TEXTS = grug_mail.texts.quest
local QUEST = "mailbox_visit"
grug_mail.STARTER_QUEST = QUEST
-- Set when the quest was granted, or skipped because the log was full.
local GRANTED = "grug_mail:quest_granted"

grug_quests.register_quest(QUEST, {
	system = true,
	turnin_text = "Open a mailbox beside the waystone of a capital or a starting village",
	title = TEXTS.title,
	description = TEXTS.description,
	min_level = 1, level = 1,
	-- A little XP (one kill equivalent at level 1) and 25c: the first letters'
	-- postage (ruling 17.2).
	rewards = {weight = 1, copper = 25},
})

-- Grants the quest once per character. Returns true when it was accepted.
function grug_mail.grant_starter_quest(player)
	local meta = player:get_meta()
	if meta:get_string(GRANTED) ~= "" or not grug_mail.character_ready(player) then return false end
	if grug_quests.quest_held(player, QUEST) or grug_quests.log_full(player) then
		meta:set_string(GRANTED, "1")
		return false
	end
	local ok = grug_quests.accept(player, QUEST)
	if ok then meta:set_string(GRANTED, "1") end
	return ok == true
end

-- Opening any mailbox turns the quest in; the quest's completion line goes
-- to the message feed with the turn-in (quests have no completion text). A
-- refused turn-in (a full purse) says why and leaves the quest active.
grug_mail.register_on_mailbox_open(function(player)
	if grug_quests.quest_held(player, QUEST) ~= "active" then return end
	local ok, message = grug_quests.turn_in(player, QUEST)
	if ok then
		grug_core.feed(player, "quest", TEXTS.completion, "quest:" .. QUEST)
	elseif message then
		grug_core.feed(player, "notice", message, "quest:" .. QUEST)
	end
end)

core.register_on_joinplayer(grug_mail.grant_starter_quest)
grug_classes.register_on_arrival(grug_mail.grant_starter_quest)
