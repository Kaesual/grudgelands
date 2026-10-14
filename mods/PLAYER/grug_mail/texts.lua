-- The texts of the starter quest and the system letters (Round 48: lane
-- TEXT, the Opus text review, the user's picks of 2026-10-14: welcome O,
-- riding A, housing C+, quest B+), copied exactly from the pick page's
-- data: the user's final texts, never reworded. In letters, {player} and
-- {capital} are filled when the letter is sent (letters.lua); the quest
-- texts carry no placeholder (grug_quests fills only its own, labels.lua
-- P.KINDS).
return {
	welcome = {
		subject = "Welcome to Grudgelands",
		body = "Welcome to Grudgelands, {player}.\n\n" ..
			"This world is hard on purpose. It shouldn't be hard by accident. If " ..
			"something breaks, confuses you or just feels wrong, I want to hear " ..
			"about it.\n\n" ..
			"Every capital and starting village has a mailbox beside its waystone. " ..
			"Read your letters there, send letters and items to players of your " ..
			"faction, and write to me under \"To the admin\". Feedback and bug reports " ..
			"are very welcome, and writing to me is free.\n\n" ..
			"Server Admin",
	},
	riding = {
		subject = "You've earned a place in the saddle",
		body = "Word of your progress has reached the stables, {player}.\n\n" ..
			"You've earned a place in the saddle. Come to {capital} and see me about " ..
			"buying a mount. There's work enough waiting for you without wearing out " ..
			"your boots on the way to it.\n\n" ..
			"Riding Trainer",
	},
	housing = {
		subject = "A door of your own",
		body = "Word of your progress has reached the king, {player}.\n\n" ..
			"You may now make a home in our lands. Visit me in {capital}; I will " ..
			"give you a Claim Stone and show you where it may stand. You've spent " ..
			"enough nights with your belongings packed. Perhaps it's time for a door " ..
			"you can close behind you.\n\n" ..
			"Housing Steward",
	},
	quest = {
		title = "Use a mailbox in one of the cities",
		description = "Someone has written to you, and for once you needn't hunt anything to " ..
			"collect it. There is a mailbox beside the waystone of every capital and " ..
			"starting village. Open any one of them; your letter is waiting.",
		completion = "An errand with no teeth in it. Take 25 copper for your first letter's " ..
			"postage.",
	},
}
