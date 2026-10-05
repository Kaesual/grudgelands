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
-- with %d for the next tier's `at`; `text_one` replaces it while that `at` is
-- 1 (and is the only text of a one-kill achievement). `flavour` shows in the
-- tab's tooltip. An optional `faction` ("accord" or "throng") gives a row to
-- that faction's characters only: the others never see or earn it (nor does
-- a character without a faction yet); a row without it is everyone's.
-- Names, flavour and cloak names are GPT-6 Astra's proposals
-- (Round 33); the selection and tiers are the user's (2026-10-04). Counters:
--   kill:animal           every wild animal: critters and hostile beasts,
--                         no humanoids (creatures.lua)
--   kill:zombie           the zombie family
--   kill:family:<family>  a family of creatures.lua (boar, rat, skeleton,
--                         golem, construct), sub-types included
--   kill:group:<group>    named leaders by role (creatures.lua ROLE_GROUPS)
--   kill:rare:<group>     named rares by registry id (RARE_GROUPS)
--   craft:<profession>    finished products grug_jobs counts as progress,
--                         by output count (cooking, alchemist)
--   death:<reason>        deaths by engine reason type, e.g. death:fall
--   boss:king, boss:dragon, boss:<boss id>   ledger kills (bosses.lua),
--                         e.g. boss:dragon:stormscale, boss:king:human
--   pvp:<stat>            a grug_pvp.stats counter, e.g. pvp:guards
--   quest:<quest id>      turn-ins of that quest (Round 36; a one-time quest
--                         counts once, so `at = 1` reads "completed")
--   quest_tag:<tag>       turn-ins of quests whose `tags` list the tag, e.g.
--                         every quest of a questline (Round 36)
--
return {
	defaults = {"none", "plain_grey"},
	cloaks = {
		{id = "none", name = "No cloak"},
		{id = "plain_grey", name = "Plain grey cloak",
			texture = "grug_achievements_cloak_plain_grey.png"},
		{id = "hunter_1", name = "Hunter's Green",
			texture = "grug_achievements_cloak_hunter_1.png"}, -- U1 C-U1.1
		{id = "hunter_2", name = "Trail Green",
			texture = "grug_achievements_cloak_hunter_2.png"}, -- U1 C-U1.2
		{id = "hunter_3", name = "Deepwood Green",
			texture = "grug_achievements_cloak_hunter_3.png"}, -- U1 C-U1.3
		{id = "kingslayer_1", name = "Fallen Crown",
			texture = "grug_achievements_cloak_kingslayer_1.png"}, -- U2 C-U2.1
		{id = "kingslayer_2", name = "Heavy Crown",
			texture = "grug_achievements_cloak_kingslayer_2.png"}, -- U2 C-U2.2
		{id = "kingslayer_3", name = "Empty Throne",
			texture = "grug_achievements_cloak_kingslayer_3.png"}, -- U2 C-U2.3
		{id = "wyvernslayer_1", name = "Stormscale",
			texture = "grug_achievements_cloak_wyvernslayer_1.png"}, -- U3 C-U3.1
		{id = "wyvernslayer_2", name = "Stormscale Crest",
			texture = "grug_achievements_cloak_wyvernslayer_2.png"}, -- U3 C-U3.2
		{id = "wyvernslayer_3", name = "Stormscale Mantle",
			texture = "grug_achievements_cloak_wyvernslayer_3.png"}, -- U3 C-U3.3
		{id = "dragonslayer_1", name = "Wyrmglass",
			texture = "grug_achievements_cloak_dragonslayer_1.png"}, -- U4 C-U4.1
		{id = "dragonslayer_2", name = "Wyrmglass Edge",
			texture = "grug_achievements_cloak_dragonslayer_2.png"}, -- U4 C-U4.2
		{id = "dragonslayer_3", name = "Wyrmglass Mantle",
			texture = "grug_achievements_cloak_dragonslayer_3.png"}, -- U4 C-U4.3
		{id = "honored_1", name = "Honored Red",
			texture = "grug_achievements_cloak_honored_1.png"}, -- U5 C-U5.1
		{id = "honored_2", name = "Honored Steel",
			texture = "grug_achievements_cloak_honored_2.png"}, -- U5 C-U5.2
		{id = "honored_3", name = "Honored Gold",
			texture = "grug_achievements_cloak_honored_3.png"}, -- U5 C-U5.3
		{id = "zombie_slayer_1", name = "Quiet Earth",
			texture = "grug_achievements_cloak_zombie_slayer_1.png"}, -- A1 C1.1
		{id = "zombie_slayer_2", name = "Settled Earth",
			texture = "grug_achievements_cloak_zombie_slayer_2.png"}, -- A1 C1.2
		{id = "zombie_slayer_3", name = "Last Goodnight",
			texture = "grug_achievements_cloak_zombie_slayer_3.png"}, -- A1 C1.3
		{id = "boaring_work_1", name = "Snout",
			texture = "grug_achievements_cloak_boaring_work_1.png"}, -- A2 C2.1
		{id = "boaring_work_2", name = "Tusks",
			texture = "grug_achievements_cloak_boaring_work_2.png"}, -- A2 C2.2
		{id = "boaring_work_3", name = "All Boar",
			texture = "grug_achievements_cloak_boaring_work_3.png"}, -- A2 C2.3
		{id = "suppers_ready_1", name = "Warm Bowl",
			texture = "grug_achievements_cloak_suppers_ready_1.png"}, -- A7 C7.1
		{id = "suppers_ready_2", name = "Second Helpings",
			texture = "grug_achievements_cloak_suppers_ready_2.png"}, -- A7 C7.2
		{id = "suppers_ready_3", name = "Everyone Eats",
			texture = "grug_achievements_cloak_suppers_ready_3.png"}, -- A7 C7.3
		{id = "bottle_service_1", name = "Corked",
			texture = "grug_achievements_cloak_bottle_service_1.png"}, -- A8 C8.1
		{id = "bottle_service_2", name = "Well Stocked",
			texture = "grug_achievements_cloak_bottle_service_2.png"}, -- A8 C8.2
		{id = "bottle_service_3", name = "House Reserve",
			texture = "grug_achievements_cloak_bottle_service_3.png"}, -- A8 C8.3
		{id = "rat_race_1", name = "Small Problem",
			texture = "grug_achievements_cloak_rat_race_1.png"}, -- A10 C10.1
		{id = "rat_race_2", name = "Bigger Problem",
			texture = "grug_achievements_cloak_rat_race_2.png"}, -- A10 C10.2
		{id = "loose_bones_1", name = "Spare Rib",
			texture = "grug_achievements_cloak_loose_bones_1.png"}, -- A12 C12.1
		{id = "loose_bones_2", name = "Missing Pieces",
			texture = "grug_achievements_cloak_loose_bones_2.png"}, -- A12 C12.2
		{id = "loose_bones_3", name = "Flat Pack",
			texture = "grug_achievements_cloak_loose_bones_3.png"}, -- A12 C12.3
		{id = "stone_deaf_1", name = "Hairline Crack",
			texture = "grug_achievements_cloak_stone_deaf_1.png"}, -- A16 C16.1
		{id = "stone_deaf_2", name = "Fault Line",
			texture = "grug_achievements_cloak_stone_deaf_2.png"}, -- A16 C16.2
		{id = "final_notice_1", name = "Account Closed",
			texture = "grug_achievements_cloak_final_notice_1.png"}, -- A17 C17.1
		{id = "rust_in_peace_1", name = "Loose Rivet",
			texture = "grug_achievements_cloak_rust_in_peace_1.png"}, -- A19 C19.1
		{id = "rust_in_peace_2", name = "Missing Tooth",
			texture = "grug_achievements_cloak_rust_in_peace_2.png"}, -- A19 C19.2
		{id = "no_more_orders_1", name = "Quiet Captain",
			texture = "grug_achievements_cloak_no_more_orders_1.png"}, -- A20 C20.1
		{id = "last_word_1", name = "Final Seal",
			texture = "grug_achievements_cloak_last_word_1.png"}, -- A22 C22.1
		{id = "grounded_1", name = "Hard Landing",
			texture = "grug_achievements_cloak_grounded_1.png"}, -- A24 C24.1
		-- Round 36 (story bible §6): one cloak each, named after the cloak.
		{id = "unburnt_roll", name = "Mantle of the Unburnt Roll",
			texture = "grug_achievements_cloak_unburnt_roll.png"},
		{id = "unbought_banner", name = "The Unbought Banner",
			texture = "grug_achievements_cloak_unbought_banner.png"},
		{id = "broken_due", name = "Mantle of the Broken Due",
			texture = "grug_achievements_cloak_broken_due.png"},
	},
	achievements = {
		-- U1
		{id = "hunter", name = "Hunter", counter = "kill:animal",
			text = "Kill %d wild animals.",
			flavour = "The woods have learned the sound of your boots.",
			tiers = {{at = 50, cloak = "hunter_1"}, {at = 150, cloak = "hunter_2"}, {at = 500, cloak = "hunter_3"}}},
		-- U2
		{id = "kingslayer", name = "Kingslayer", counter = "boss:king",
			text = "Kill enemy Kings %d times.",
			text_one = "Kill an enemy King.",
			flavour = "A crown is lighter when nobody is beneath it.",
			tiers = {{at = 1, cloak = "kingslayer_1"}, {at = 5, cloak = "kingslayer_2"}, {at = 20, cloak = "kingslayer_3"}}},
		-- U3
		{id = "wyvernslayer", name = "Wyvernslayer", counter = "boss:dragon:stormscale",
			text = "Kill the Stormscale Wyvern %d times.",
			text_one = "Kill the Stormscale Jungle Wyvern.",
			flavour = "The canopy has one less shadow to fear.",
			tiers = {{at = 1, cloak = "wyvernslayer_1"}, {at = 5, cloak = "wyvernslayer_2"}, {at = 20, cloak = "wyvernslayer_3"}}},
		-- U4
		{id = "dragonslayer", name = "Dragonslayer", counter = "boss:dragon:wyrmglass",
			text = "Kill the Wyrmglass Dragon %d times.",
			text_one = "Kill the Wyrmglass Ice Dragon.",
			flavour = "You brought back the colour of a winter that fought back.",
			tiers = {{at = 1, cloak = "dragonslayer_1"}, {at = 5, cloak = "dragonslayer_2"}, {at = 20, cloak = "dragonslayer_3"}}},
		-- U5
		{id = "honored", name = "Honored", counter = "pvp:guards",
			text = "Kill %d guards of the enemy faction.",
			flavour = "Your own gate opens a little wider when you return.",
			tiers = {{at = 50, cloak = "honored_1"}, {at = 150, cloak = "honored_2"}, {at = 500, cloak = "honored_3"}}},
		-- A1
		{id = "zombie_slayer", name = "Zombie Slayer", counter = "kill:zombie",
			text = "Kill %d zombies.",
			flavour = "Some neighbours need the goodnight said twice.",
			tiers = {{at = 50, cloak = "zombie_slayer_1"}, {at = 150, cloak = "zombie_slayer_2"}, {at = 500, cloak = "zombie_slayer_3"}}},
		-- A2
		{id = "boaring_work", name = "Boaring Work", counter = "kill:family:boar",
			text = "Kill %d boars.",
			flavour = "You had other plans. The boars had more boars.",
			tiers = {{at = 10, cloak = "boaring_work_1"}, {at = 50, cloak = "boaring_work_2"}, {at = 200, cloak = "boaring_work_3"}}},
		-- A7
		{id = "suppers_ready", name = "Supper's Ready", counter = "craft:cooking",
			text = "Cook %d dishes.",
			flavour = "The greatest spell at camp is still ‘food's ready.’",
			tiers = {{at = 50, cloak = "suppers_ready_1"}, {at = 150, cloak = "suppers_ready_2"}, {at = 500, cloak = "suppers_ready_3"}}},
		-- A8
		{id = "bottle_service", name = "Bottle Service", counter = "craft:alchemist",
			text = "Brew %d potions or elixirs.",
			flavour = "Everything is clearer after you label the bottles.",
			tiers = {{at = 50, cloak = "bottle_service_1"}, {at = 150, cloak = "bottle_service_2"}, {at = 500, cloak = "bottle_service_3"}}},
		-- A10
		{id = "rat_race", name = "Rat Race", counter = "kill:family:rat",
			text = "Kill %d rats.",
			flavour = "You won. Somehow there are still rats.",
			tiers = {{at = 25, cloak = "rat_race_1"}, {at = 100, cloak = "rat_race_2"}}},
		-- A12
		{id = "loose_bones", name = "Loose Bones", counter = "kill:family:skeleton",
			text = "Kill %d skeletons.",
			flavour = "Some assembly was required. Not any more.",
			tiers = {{at = 50, cloak = "loose_bones_1"}, {at = 150, cloak = "loose_bones_2"}, {at = 500, cloak = "loose_bones_3"}}},
		-- A16
		{id = "stone_deaf", name = "Stone Deaf", counter = "kill:family:golem",
			text = "Kill %d golems.",
			flavour = "You tried talking. The mountain was not listening.",
			tiers = {{at = 5, cloak = "stone_deaf_1"}, {at = 50, cloak = "stone_deaf_2"}}},
		-- A17
		{id = "final_notice", name = "Final Notice", counter = "kill:group:final_notice",
			text_one = "Kill a level-29 leader near a capital.",
			flavour = "The collector has received a strongly worded reply.",
			tiers = {{at = 1, cloak = "final_notice_1"}}},
		-- A19
		{id = "rust_in_peace", name = "Rust in Peace", counter = "kill:family:construct",
			text = "Kill %d war constructs.",
			flavour = "The war machine has developed a permanent maintenance problem.",
			tiers = {{at = 5, cloak = "rust_in_peace_1"}, {at = 50, cloak = "rust_in_peace_2"}}},
		-- A20
		{id = "no_more_orders", name = "No More Orders", counter = "kill:rare:bonerattle",
			text_one = "Kill Captain Bonerattle.",
			flavour = "His last order was considerably shorter than the others.",
			tiers = {{at = 1, cloak = "no_more_orders_1"}}},
		-- A22
		{id = "last_word", name = "Last Word", counter = "kill:group:last_word",
			text_one = "Kill Huskell or Paymaster Chirr.",
			flavour = "One kept calling the watch. One kept promising the pay. Enough.",
			tiers = {{at = 1, cloak = "last_word_1"}}},
		-- A24
		{id = "grounded", name = "Grounded", counter = "death:fall",
			text_one = "Die from a fall.",
			flavour = "The ground was exactly where you left it.",
			tiers = {{at = 1, cloak = "grounded_1"}}},
		-- Round 36, the main questline (story bible §6). The two final quest
		-- ids are fixed: each faction's last Warmaster turn-in; each row is
		-- its faction's alone (user, 2026-10-05).
		{id = "every_name_accounted_for", name = "Every Name Accounted For",
			faction = "accord", counter = "quest:accord_main_final",
			text_one = "Complete The Accord's main questline.",
			flavour = "You brought back the names the enemy meant to turn into numbers.",
			tiers = {{at = 1, cloak = "unburnt_roll"}}},
		{id = "our_oaths_are_ours", name = "Our Oaths Are Ours",
			faction = "throng", counter = "quest:throng_main_final",
			text_one = "Complete The Throng's main questline.",
			flavour = "Let them keep their coin. Nobody else speaks for our dead.",
			tiers = {{at = 1, cloak = "unbought_banner"}}},
		{id = "last_claim_denied", name = "The Last Claim Denied", counter = "boss:rift",
			text_one = "Defeat Isquarre the Tithe-Eater.",
			flavour = "The collector came for both armies. You sent him away empty.",
			tiers = {{at = 1, cloak = "broken_due"}}},
	},
}
