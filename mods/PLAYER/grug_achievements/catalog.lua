--
-- The achievements and the cloaks they unlock (round33-plan.md §2.10). Pure
-- data; core.lua checks it at load. Adding an achievement is a row here (and
-- a cloak texture), never code, as long as its counter exists (init.lua).
--
-- Cloaks are cosmetic and never items. `texture` is the model's second
-- texture (32x32: outer face left, lining right, character_visuals.md §5b);
-- the "none" cloak has none. `defaults` are what every new character owns.
--
-- An achievement counts one COUNTER and has one or more TIERS; reaching a
-- tier's `at` earns it (once) and unlocks its cloak. `text` is the condition
-- with %d for the next tier's `at`. Counters:
--   kill:animal           every wild animal: critters and hostile beasts,
--                         no humanoids (creatures.lua)
--   kill:zombie           the zombie family
--   kill:family:<family>  one mob family (grug_mobs.family_of), counted only
--                         while some achievement asks for it
--   boss:king, boss:dragon, boss:<boss id>   ledger kills (bosses.lua),
--                         e.g. boss:dragon:stormscale, boss:king:human
--   pvp:<stat>            a grug_pvp.stats counter, e.g. pvp:guards
--
return {
	defaults = {"none", "grey"},
	cloaks = {
		{id = "none", name = "No cloak"},
		{id = "grey", name = "Plain grey cloak",
			texture = "grug_achievements_cloak_grey.png"},
		{id = "hunter", name = "Hunter's cloak",
			texture = "grug_achievements_cloak_hunter.png"},
		{id = "kingslayer", name = "Kingslayer's cloak",
			texture = "grug_achievements_cloak_kingslayer.png"},
		{id = "wyvernslayer", name = "Wyvernslayer's cloak",
			texture = "grug_achievements_cloak_wyvernslayer.png"},
		{id = "dragonslayer", name = "Dragonslayer's cloak",
			texture = "grug_achievements_cloak_dragonslayer.png"},
		{id = "honored", name = "Cloak of the Honored",
			texture = "grug_achievements_cloak_honored.png"},
	},
	achievements = {
		{id = "hunter", name = "Hunter", counter = "kill:animal",
			text = "Kill %d wild animals.",
			tiers = {{at = 100, cloak = "hunter"}}},
		{id = "kingslayer", name = "Kingslayer", counter = "boss:king",
			text = "Kill a King.",
			tiers = {{at = 1, cloak = "kingslayer"}}},
		{id = "wyvernslayer", name = "Wyvernslayer",
			counter = "boss:dragon:stormscale",
			text = "Kill the Stormscale Jungle Wyvern.",
			tiers = {{at = 1, cloak = "wyvernslayer"}}},
		{id = "dragonslayer", name = "Dragonslayer",
			counter = "boss:dragon:wyrmglass",
			text = "Kill the Wyrmglass Ice Dragon.",
			tiers = {{at = 1, cloak = "dragonslayer"}}},
		{id = "honored", name = "Honored", counter = "pvp:guards",
			text = "Kill %d guards of the enemy faction.",
			tiers = {{at = 50, cloak = "honored"}}},
	},
}
