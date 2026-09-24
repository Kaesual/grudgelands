-- Round 20 cooks, capital introductions and destination-only travel handoffs.
local Q = grug_quests

Q.register_quest("r20_dwarf_start_cook", {
	title = "Warmth for the Timber Shift",
	npc = "r20_dwarf_start_cook",
	turnin_npc = "r20_dwarf_start_cook",
	min_level = 1,
	target_level = 1,
	faction = "accord",
	race = "dwarf",
	effort = "standard",
	prerequisites = {},
	description = "Hilda keeps the timber shift fed beside Hearthpine's oven. Bring three coal lumps for its fuel box; existing or traded coal is welcome. If you mine it yourself, use a pickaxe, even wood or stone, on a natural coal source rather than dismantling protected village scenery.",
	objectives = {{type = "item", item = "default:coal_lump", count = 3}},
	rewards = {xp = 20, copper = 10, items = {}},
})

Q.register_quest("r20_dwarf_capital_cook", {
	title = "Copperpan Supper",
	npc = "r20_dwarf_capital_cook",
	turnin_npc = "r20_dwarf_capital_cook",
	min_level = 10,
	target_level = 10,
	faction = "accord",
	race = "dwarf",
	effort = "standard",
	prerequisites = {},
	description = "Varda Copperpan has places at the table for late arrivals in Dur Brannoc. Bring five raw meat portions to the bakehouse cook. The meal is a shared provision task, not a Cooking qualification test.",
	objectives = {{type = "item", item = "mobs:meat_raw", count = 5}},
	rewards = {xp = 380, copper = 45, items = {}},
})

Q.register_quest("r20_dwarf_capital_intro", {
	title = "The Road to Dur Brannoc",
	npc = "r14_dwarf_elder",
	turnin_npc = "r20_dwarf_capital_envoy",
	min_level = 10,
	target_level = 10,
	faction = "accord",
	race = "dwarf",
	effort = "lesson",
	prerequisites = {},
	description = "Dur Brannoc's gates lead to trainers, repair services and the city's public workspaces. At level 10, follow the road to Dorrin Gateledger in the ancestor hall. Outside the city the country is more dangerous; keep to the route and avoid the higher-level wildlife. Speak with Dorrin and complete this introduction there.",
	objectives = {{type = "talk", npc = "r20_dwarf_capital_envoy", count = 1}},
	rewards = {xp = 285, copper = 40, items = {}},
})

Q.register_quest("r20_dwarf_capital_services", {
	title = "A Seat at Copperpan",
	npc = "r20_dwarf_capital_envoy",
	turnin_npc = "r20_dwarf_capital_cook",
	min_level = 10,
	target_level = 10,
	faction = "accord",
	race = "dwarf",
	effort = "lesson",
	prerequisites = {"r20_dwarf_capital_intro"},
	description = "Dorrin recommends the terrace bakehouse before your next climb. Speak with Varda Copperpan at the cook's place beside the oven, then complete the introduction with her. The Cooking trainer has a separate role; you do not need to learn the profession.",
	objectives = {{type = "talk", npc = "r20_dwarf_capital_cook", count = 1}},
	rewards = {xp = 285, copper = 40, items = {}},
})

Q.register_quest("r20_dwarf_capital_stores", {
	title = "Lamp Coal for the Gate Shift",
	npc = "r20_dwarf_capital_envoy",
	turnin_npc = "r20_dwarf_capital_envoy",
	min_level = 20,
	target_level = 20,
	faction = "accord",
	race = "dwarf",
	effort = "standard",
	prerequisites = {},
	description = "The gate shift keeps its lamp fuel apart from the smiths' metal stock. Bring eight coal lumps to Dorrin so the night watch can replenish that reserve without taking the bakehouse's fuel.",
	objectives = {{type = "item", item = "default:coal_lump", count = 8}},
	rewards = {xp = 780, copper = 60, items = {}},
})

Q.register_quest("r20_dwarf_journey_01", {
	title = "Word for Edda Tarnmantle",
	npc = "r20_dwarf_capital_envoy",
	turnin_npc = "r20_anchor_014_host",
	min_level = 21,
	target_level = 21,
	faction = "accord",
	race = "dwarf",
	effort = "lesson",
	prerequisites = {},
	description = "The capital keeps contact with the working settlements beyond its walls. Travel to Tarnwatch Fold in Frostbarrow Shelf and speak with Edda Tarnmantle. This is level 21–30 country; prepare your equipment before leaving the road. Complete the conversation with Edda Tarnmantle there. No parcel, fighting errand or return trip is required.",
	objectives = {{type = "talk", npc = "r20_anchor_014_host", count = 1}},
	rewards = {xp = 615, copper = 50, items = {}},
})

Q.register_quest("r20_dwarf_journey_02", {
	title = "Word for Kelda Screesort",
	npc = "r20_anchor_014_host",
	turnin_npc = "r20_anchor_061_host",
	min_level = 24,
	target_level = 24,
	faction = "accord",
	race = "dwarf",
	effort = "lesson",
	prerequisites = {},
	description = "The settlement and its nearby cutters need a direct line for their next repair season. Travel to Tarncut Mine in Frostbarrow Shelf and speak with Kelda Screesort. This is level 21–30 country; prepare your equipment before leaving the road. Complete the conversation with Kelda Screesort there. No parcel, fighting errand or return trip is required.",
	objectives = {{type = "talk", npc = "r20_anchor_061_host", count = 1}},
	rewards = {xp = 705, copper = 50, items = {}},
})

Q.register_quest("r20_dwarf_journey_03", {
	title = "Word for Borin Splitbolt",
	npc = "r20_anchor_061_host",
	turnin_npc = "r20_anchor_027_host",
	min_level = 31,
	target_level = 31,
	faction = "accord",
	race = "dwarf",
	effort = "lesson",
	prerequisites = {},
	description = "The next frontier post needs news from the safer roads before another loaded caravan attempts the ascent. Travel to Splitbolt Station in Stormvault Heights and speak with Borin Splitbolt. This is level 31–40 country; prepare your equipment before leaving the road. Complete the conversation with Borin Splitbolt there. No parcel, fighting errand or return trip is required.",
	objectives = {{type = "talk", npc = "r20_anchor_027_host", count = 1}},
	rewards = {xp = 915, copper = 50, items = {}},
})

Q.register_quest("r20_human_start_cook", {
	title = "The Second Oven",
	npc = "r20_human_start_cook",
	turnin_npc = "r20_human_start_cook",
	min_level = 1,
	target_level = 1,
	faction = "accord",
	race = "human",
	effort = "standard",
	prerequisites = {},
	description = "Bess Honeycrust has a second oven ready for Dawnmere's returning field hands. Bring three coal lumps for its fuel store. Traded supplies count; mining natural coal yourself only requires a pickaxe; wood and stone picks work too.",
	objectives = {{type = "item", item = "default:coal_lump", count = 3}},
	rewards = {xp = 20, copper = 10, items = {}},
})

Q.register_quest("r20_human_capital_cook", {
	title = "Bread for the Late Arrivals",
	npc = "r20_human_capital_cook",
	turnin_npc = "r20_human_capital_cook",
	min_level = 10,
	target_level = 10,
	faction = "accord",
	race = "human",
	effort = "standard",
	prerequisites = {},
	description = "Ansel Ovenward is setting a supper beside Highcourt's bakehouse for travellers who arrive after the bread is baked. Bring five raw meat portions for the pot. No Cooking profession is required.",
	objectives = {{type = "item", item = "mobs:meat_raw", count = 5}},
	rewards = {xp = 380, copper = 45, items = {}},
})

Q.register_quest("r20_human_capital_intro", {
	title = "The Road to Highcourt",
	npc = "r14_human_elder",
	turnin_npc = "r20_human_capital_envoy",
	min_level = 10,
	target_level = 10,
	faction = "accord",
	race = "human",
	effort = "lesson",
	prerequisites = {},
	description = "Highcourt has public workspaces, profession trainers and repair services beyond Dawnmere's small yard. At level 10, follow the road to Mariel Waybook at the chapel. The surrounding country is level 20–30, so travel by the road instead of testing its wildlife. Speak with Mariel and complete the introduction there.",
	objectives = {{type = "talk", npc = "r20_human_capital_envoy", count = 1}},
	rewards = {xp = 285, copper = 40, items = {}},
})

Q.register_quest("r20_human_capital_services", {
	title = "The Ovenward Welcome",
	npc = "r20_human_capital_envoy",
	turnin_npc = "r20_human_capital_cook",
	min_level = 10,
	target_level = 10,
	faction = "accord",
	race = "human",
	effort = "lesson",
	prerequisites = {"r20_human_capital_intro"},
	description = "Mariel sends new arrivals to Ansel Ovenward in the homes bakehouse. Speak with the cook beside the oven and complete this introduction there; the separate Cooking trainer is optional.",
	objectives = {{type = "talk", npc = "r20_human_capital_cook", count = 1}},
	rewards = {xp = 285, copper = 40, items = {}},
})

Q.register_quest("r20_human_capital_stores", {
	title = "Stone for the River Watch",
	npc = "r20_human_capital_envoy",
	turnin_npc = "r20_human_capital_envoy",
	min_level = 20,
	target_level = 20,
	faction = "accord",
	race = "human",
	effort = "standard",
	prerequisites = {},
	description = "The river watch needs low stone blocks to reset its supply-yard edge. Bring twelve cobble blocks to Mariel at Highcourt. This asks for ordinary material, not proof that you mined it.",
	objectives = {{type = "item", item = "default:cobble", count = 12}},
	rewards = {xp = 780, copper = 60, items = {}},
})

Q.register_quest("r20_human_journey_01", {
	title = "Word for Merren Oakstamp",
	npc = "r20_human_capital_envoy",
	turnin_npc = "r20_anchor_016_host",
	min_level = 21,
	target_level = 21,
	faction = "accord",
	race = "human",
	effort = "lesson",
	prerequisites = {},
	description = "The capital keeps contact with the working settlements beyond its walls. Travel to Whitebridge Market Close in Whitebridge Shire and speak with Merren Oakstamp. This is level 21–30 country; prepare your equipment before leaving the road. Complete the conversation with Merren Oakstamp there. No parcel, fighting errand or return trip is required.",
	objectives = {{type = "talk", npc = "r20_anchor_016_host", count = 1}},
	rewards = {xp = 615, copper = 50, items = {}},
})

Q.register_quest("r20_human_journey_02", {
	title = "Word for Halen Chalkthumb",
	npc = "r20_anchor_016_host",
	turnin_npc = "r20_anchor_062_host",
	min_level = 24,
	target_level = 24,
	faction = "accord",
	race = "human",
	effort = "lesson",
	prerequisites = {},
	description = "The settlement and its nearby cutters need a direct line for their next repair season. Travel to Bridgechalk Dig in Whitebridge Shire and speak with Halen Chalkthumb. This is level 21–30 country; prepare your equipment before leaving the road. Complete the conversation with Halen Chalkthumb there. No parcel, fighting errand or return trip is required.",
	objectives = {{type = "talk", npc = "r20_anchor_062_host", count = 1}},
	rewards = {xp = 705, copper = 50, items = {}},
})

Q.register_quest("r20_human_journey_03", {
	title = "Word for Toren Waterbarrel",
	npc = "r20_anchor_062_host",
	turnin_npc = "r20_anchor_031_host",
	min_level = 31,
	target_level = 31,
	faction = "accord",
	race = "human",
	effort = "lesson",
	prerequisites = {},
	description = "The next frontier post needs news from the safer roads before another loaded caravan attempts the ascent. Travel to Cinderline Watch in Ashenward March and speak with Toren Waterbarrel. This is level 31–40 country; prepare your equipment before leaving the road. Complete the conversation with Toren Waterbarrel there. No parcel, fighting errand or return trip is required.",
	objectives = {{type = "talk", npc = "r20_anchor_031_host", count = 1}},
	rewards = {xp = 915, copper = 50, items = {}},
})

Q.register_quest("r20_elf_start_cook", {
	title = "A Shared Grove Supper",
	npc = "r20_elf_start_cook",
	turnin_npc = "r20_elf_start_cook",
	min_level = 1,
	target_level = 1,
	faction = "accord",
	race = "elf",
	effort = "standard",
	prerequisites = {},
	description = "Liora Dewpot wants the grove's evening meal ready before the gatherers return. Bring three coal lumps to the oven in Silverleaf. Existing or traded fuel is welcome; a pickaxe is needed (wood and stone work too) if you choose to mine natural coal yourself.",
	objectives = {{type = "item", item = "default:coal_lump", count = 3}},
	rewards = {xp = 20, copper = 10, items = {}},
})

Q.register_quest("r20_elf_capital_cook", {
	title = "The Petalpot Share",
	npc = "r20_elf_capital_cook",
	turnin_npc = "r20_elf_capital_cook",
	min_level = 10,
	target_level = 10,
	faction = "accord",
	race = "elf",
	effort = "standard",
	prerequisites = {},
	description = "Mirael Petalpot keeps a common pot beside Lethariel's market bakehouse. Bring five raw meat portions for travellers and wardens sharing that table. You need no Cooking qualification to contribute.",
	objectives = {{type = "item", item = "mobs:meat_raw", count = 5}},
	rewards = {xp = 380, copper = 45, items = {}},
})

Q.register_quest("r20_elf_capital_intro", {
	title = "The Road to Lethariel",
	npc = "r14_elf_elder",
	turnin_npc = "r20_elf_capital_envoy",
	min_level = 10,
	target_level = 10,
	faction = "accord",
	race = "elf",
	effort = "lesson",
	prerequisites = {},
	description = "Lethariel's star hall receives travellers looking for the city's trainers, repairs and public workspaces. At level 10, follow the road to Eriath Boughwarden there. The woods beyond the protected city are level 20–30; avoid their wildlife while travelling. Speak with Eriath and complete the introduction in the hall.",
	objectives = {{type = "talk", npc = "r20_elf_capital_envoy", count = 1}},
	rewards = {xp = 285, copper = 40, items = {}},
})

Q.register_quest("r20_elf_capital_services", {
	title = "Petalpot Hospitality",
	npc = "r20_elf_capital_envoy",
	turnin_npc = "r20_elf_capital_cook",
	min_level = 10,
	target_level = 10,
	faction = "accord",
	race = "elf",
	effort = "lesson",
	prerequisites = {"r20_elf_capital_intro"},
	description = "Eriath recommends Mirael Petalpot's table at the market bakehouse before you set out again. Speak with the cook beside the oven, then complete this introduction there. Learning Cooking from its separate trainer is optional.",
	objectives = {{type = "talk", npc = "r20_elf_capital_cook", count = 1}},
	rewards = {xp = 285, copper = 40, items = {}},
})

Q.register_quest("r20_elf_capital_stores", {
	title = "Boards for the Grove Patrol",
	npc = "r20_elf_capital_envoy",
	turnin_npc = "r20_elf_capital_envoy",
	min_level = 20,
	target_level = 20,
	faction = "accord",
	race = "elf",
	effort = "standard",
	prerequisites = {},
	description = "The grove patrol needs ordinary oak boards for its covered stores. Bring ten planks to Eriath in Lethariel. Oak is welcome here; you do not need to cut a silverwood tree for this repair.",
	objectives = {{type = "item", item = "default:wood", count = 10}},
	rewards = {xp = 780, copper = 60, items = {}},
})

Q.register_quest("r20_elf_journey_01", {
	title = "Word for Ilwen Petalmeasure",
	npc = "r20_elf_capital_envoy",
	turnin_npc = "r20_anchor_018_host",
	min_level = 21,
	target_level = 21,
	faction = "accord",
	race = "elf",
	effort = "lesson",
	prerequisites = {},
	description = "The capital keeps contact with the working settlements beyond its walls. Travel to Lorindor Berrycourt in Lorindor and speak with Ilwen Petalmeasure. This is level 21–30 country; prepare your equipment before leaving the road. Complete the conversation with Ilwen Petalmeasure there. No parcel, fighting errand or return trip is required.",
	objectives = {{type = "talk", npc = "r20_anchor_018_host", count = 1}},
	rewards = {xp = 615, copper = 50, items = {}},
})

Q.register_quest("r20_elf_journey_02", {
	title = "Word for Saevin Rootscribe",
	npc = "r20_anchor_018_host",
	turnin_npc = "r20_anchor_063_host",
	min_level = 24,
	target_level = 24,
	faction = "accord",
	race = "elf",
	effort = "lesson",
	prerequisites = {},
	description = "The settlement and its nearby cutters need a direct line for their next repair season. Travel to Paleroot Cutting in Lorindor and speak with Saevin Rootscribe. This is level 21–30 country; prepare your equipment before leaving the road. Complete the conversation with Saevin Rootscribe there. No parcel, fighting errand or return trip is required.",
	objectives = {{type = "talk", npc = "r20_anchor_063_host", count = 1}},
	rewards = {xp = 705, copper = 50, items = {}},
})

Q.register_quest("r20_elf_journey_03", {
	title = "Word for Faeris Rootbinder",
	npc = "r20_anchor_063_host",
	turnin_npc = "r20_anchor_036_host",
	min_level = 31,
	target_level = 31,
	faction = "accord",
	race = "elf",
	effort = "lesson",
	prerequisites = {},
	description = "The next frontier post needs news from the safer roads before another loaded caravan attempts the ascent. Travel to Glassroot Gate in Glassroot Wilds and speak with Faeris Rootbinder. This is level 31–40 country; prepare your equipment before leaving the road. Complete the conversation with Faeris Rootbinder there. No parcel, fighting errand or return trip is required.",
	objectives = {{type = "talk", npc = "r20_anchor_036_host", count = 1}},
	rewards = {xp = 915, copper = 50, items = {}},
})

Q.register_quest("r20_undead_start_cook", {
	title = "Salt Against the Damp",
	npc = "r20_undead_start_cook",
	turnin_npc = "r20_undead_start_cook",
	min_level = 1,
	target_level = 1,
	faction = "throng",
	race = "undead",
	effort = "standard",
	prerequisites = {},
	description = "Neral Saltkeeper warms Stillgrave's salting room from the oven beside the common table. Bring three coal lumps to keep the damp out. Traded fuel counts; if you mine coal yourself, bring a pickaxe; wood and stone picks work too.",
	objectives = {{type = "item", item = "default:coal_lump", count = 3}},
	rewards = {xp = 20, copper = 10, items = {}},
})

Q.register_quest("r20_undead_capital_cook", {
	title = "Bowls for the Vigil",
	npc = "r20_undead_capital_cook",
	turnin_npc = "r20_undead_capital_cook",
	min_level = 10,
	target_level = 10,
	faction = "throng",
	race = "undead",
	effort = "standard",
	prerequisites = {},
	description = "Velis Mourningbowl has set bowls for Nhal Veyr's vigil keepers. Bring five raw meat portions to the cook in the mourners' hall so the preserved stores can last another shift. This does not require the Cooking profession.",
	objectives = {{type = "item", item = "mobs:meat_raw", count = 5}},
	rewards = {xp = 380, copper = 45, items = {}},
})

Q.register_quest("r20_undead_capital_intro", {
	title = "The Road to Nhal Veyr",
	npc = "r14_undead_elder",
	turnin_npc = "r20_undead_capital_envoy",
	min_level = 10,
	target_level = 10,
	faction = "throng",
	race = "undead",
	effort = "lesson",
	prerequisites = {},
	description = "Nhal Veyr keeps its profession trainers, repair services and public workspaces beyond Stillgrave's narrow paths. At level 10, follow the road to Ossa Quietregister in the vigil hall. Outside the city the country is level 20–30; pass through without provoking its wildlife. Speak with Ossa and complete the introduction there.",
	objectives = {{type = "talk", npc = "r20_undead_capital_envoy", count = 1}},
	rewards = {xp = 285, copper = 40, items = {}},
})

Q.register_quest("r20_undead_capital_services", {
	title = "The Vigil Table",
	npc = "r20_undead_capital_envoy",
	turnin_npc = "r20_undead_capital_cook",
	min_level = 10,
	target_level = 10,
	faction = "throng",
	race = "undead",
	effort = "lesson",
	prerequisites = {"r20_undead_capital_intro"},
	description = "Ossa asks you to meet Velis Mourningbowl at the homes mourners' hall. Speak with the cook at the oven and complete this introduction there. The Cooking trainer remains a separate, optional service.",
	objectives = {{type = "talk", npc = "r20_undead_capital_cook", count = 1}},
	rewards = {xp = 285, copper = 40, items = {}},
})

Q.register_quest("r20_undead_capital_stores", {
	title = "Coal for the Vigil Lamps",
	npc = "r20_undead_capital_envoy",
	turnin_npc = "r20_undead_capital_envoy",
	min_level = 20,
	target_level = 20,
	faction = "throng",
	race = "undead",
	effort = "standard",
	prerequisites = {},
	description = "The vigil lamps must outlast each watch, even when the covered courtyard is wet. Bring eight coal lumps to Ossa for the lamp reserve. Ordinary carried or traded fuel is sufficient.",
	objectives = {{type = "item", item = "default:coal_lump", count = 8}},
	rewards = {xp = 780, copper = 60, items = {}},
})

Q.register_quest("r20_undead_journey_01", {
	title = "Word for Sovel Namekeeper",
	npc = "r20_undead_capital_envoy",
	turnin_npc = "r20_anchor_020_host",
	min_level = 21,
	target_level = 21,
	faction = "throng",
	race = "undead",
	effort = "lesson",
	prerequisites = {},
	description = "The capital keeps contact with the working settlements beyond its walls. Travel to Ossuary Ledgerstead in Ossuary Reach and speak with Sovel Namekeeper. This is level 21–30 country; prepare your equipment before leaving the road. Complete the conversation with Sovel Namekeeper there. No parcel, fighting errand or return trip is required.",
	objectives = {{type = "talk", npc = "r20_anchor_020_host", count = 1}},
	rewards = {xp = 615, copper = 50, items = {}},
})

Q.register_quest("r20_undead_journey_02", {
	title = "Word for Neris Fossilhand",
	npc = "r20_anchor_020_host",
	turnin_npc = "r20_anchor_064_host",
	min_level = 24,
	target_level = 24,
	faction = "throng",
	race = "undead",
	effort = "lesson",
	prerequisites = {},
	description = "The settlement and its nearby cutters need a direct line for their next repair season. Travel to Memoryvein Dig in Ossuary Reach and speak with Neris Fossilhand. This is level 21–30 country; prepare your equipment before leaving the road. Complete the conversation with Neris Fossilhand there. No parcel, fighting errand or return trip is required.",
	objectives = {{type = "talk", npc = "r20_anchor_064_host", count = 1}},
	rewards = {xp = 705, copper = 50, items = {}},
})

Q.register_quest("r20_undead_journey_03", {
	title = "Word for Vaska Ashlistener",
	npc = "r20_anchor_064_host",
	turnin_npc = "r20_anchor_039_host",
	min_level = 31,
	target_level = 31,
	faction = "throng",
	race = "undead",
	effort = "lesson",
	prerequisites = {},
	description = "The next frontier post needs news from the safer roads before another loaded caravan attempts the ascent. Travel to Ashveil Watch in Blackwind Rise and speak with Vaska Ashlistener. This is level 31–40 country; prepare your equipment before leaving the road. Complete the conversation with Vaska Ashlistener there. No parcel, fighting errand or return trip is required.",
	objectives = {{type = "talk", npc = "r20_anchor_039_host", count = 1}},
	rewards = {xp = 915, copper = 50, items = {}},
})

Q.register_quest("r20_orc_start_cook", {
	title = "Keep the Long Fire Fed",
	npc = "r20_orc_start_cook",
	turnin_npc = "r20_orc_start_cook",
	min_level = 1,
	target_level = 1,
	faction = "throng",
	race = "orc",
	effort = "standard",
	prerequisites = {},
	description = "Ugra Brothstone keeps Sunscar's long fire supplied beside the oven. Bring three coal lumps for the covered fuel box. Existing or traded coal is welcome; You can mine natural coal with any pickaxe, including wood or stone.",
	objectives = {{type = "item", item = "default:coal_lump", count = 3}},
	rewards = {xp = 20, copper = 10, items = {}},
})

Q.register_quest("r20_orc_capital_cook", {
	title = "The Longladle Ration",
	npc = "r20_orc_capital_cook",
	turnin_npc = "r20_orc_capital_cook",
	min_level = 10,
	target_level = 10,
	faction = "throng",
	race = "orc",
	effort = "standard",
	prerequisites = {},
	description = "Gorla Longladle has a ration pot beside Gor Drazhak's cook-court oven. Bring five raw meat portions for the next watch and its travellers. You can help without learning Cooking.",
	objectives = {{type = "item", item = "mobs:meat_raw", count = 5}},
	rewards = {xp = 380, copper = 45, items = {}},
})

Q.register_quest("r20_orc_capital_intro", {
	title = "The Road to Gor Drazhak",
	npc = "r14_orc_elder",
	turnin_npc = "r20_orc_capital_envoy",
	min_level = 10,
	target_level = 10,
	faction = "throng",
	race = "orc",
	effort = "lesson",
	prerequisites = {},
	description = "Gor Drazhak offers public workspaces, trainers and repairs beyond Sunscar's camp. At level 10, follow the road to Thorga Roadspeaker in the skull hall. Its surrounding country is level 20–30, so avoid the wildlife and keep to the route. Speak with Thorga and complete this introduction there.",
	objectives = {{type = "talk", npc = "r20_orc_capital_envoy", count = 1}},
	rewards = {xp = 285, copper = 40, items = {}},
})

Q.register_quest("r20_orc_capital_services", {
	title = "A Bowl at Longladle",
	npc = "r20_orc_capital_envoy",
	turnin_npc = "r20_orc_capital_cook",
	min_level = 10,
	target_level = 10,
	faction = "throng",
	race = "orc",
	effort = "lesson",
	prerequisites = {"r20_orc_capital_intro"},
	description = "Thorga recommends a stop at Gorla Longladle's cook court. Speak with the cook beside the oven in the warren, then complete the introduction there. The nearby Cooking trainer is not required for this conversation.",
	objectives = {{type = "talk", npc = "r20_orc_capital_cook", count = 1}},
	rewards = {xp = 285, copper = 40, items = {}},
})

Q.register_quest("r20_orc_capital_stores", {
	title = "Stone for the Muster Yard",
	npc = "r20_orc_capital_envoy",
	turnin_npc = "r20_orc_capital_envoy",
	min_level = 20,
	target_level = 20,
	faction = "throng",
	race = "orc",
	effort = "standard",
	prerequisites = {},
	description = "The muster yard's supply edge has been worn down by loaded carts. Bring twelve cobble blocks to Thorga so the watch can reset it without taking stone from occupied homes.",
	objectives = {{type = "item", item = "default:cobble", count = 12}},
	rewards = {xp = 780, copper = 60, items = {}},
})

Q.register_quest("r20_orc_journey_01", {
	title = "Word for Brakka Jarward",
	npc = "r20_orc_capital_envoy",
	turnin_npc = "r20_anchor_022_host",
	min_level = 21,
	target_level = 21,
	faction = "throng",
	race = "orc",
	effort = "lesson",
	prerequisites = {},
	description = "The capital keeps contact with the working settlements beyond its walls. Travel to Speargrass Wellhold in Speargrass Reach and speak with Brakka Jarward. This is level 21–30 country; prepare your equipment before leaving the road. Complete the conversation with Brakka Jarward there. No parcel, fighting errand or return trip is required.",
	objectives = {{type = "talk", npc = "r20_anchor_022_host", count = 1}},
	rewards = {xp = 615, copper = 50, items = {}},
})

Q.register_quest("r20_orc_journey_02", {
	title = "Word for Gorren Redpick",
	npc = "r20_anchor_022_host",
	turnin_npc = "r20_anchor_065_host",
	min_level = 24,
	target_level = 24,
	faction = "throng",
	race = "orc",
	effort = "lesson",
	prerequisites = {},
	description = "The settlement and its nearby cutters need a direct line for their next repair season. Travel to Redpick Yard in Speargrass Reach and speak with Gorren Redpick. This is level 21–30 country; prepare your equipment before leaving the road. Complete the conversation with Gorren Redpick there. No parcel, fighting errand or return trip is required.",
	objectives = {{type = "talk", npc = "r20_anchor_065_host", count = 1}},
	rewards = {xp = 705, copper = 50, items = {}},
})

Q.register_quest("r20_orc_journey_03", {
	title = "Word for Drek Rampbinder",
	npc = "r20_anchor_065_host",
	turnin_npc = "r20_anchor_043_host",
	min_level = 31,
	target_level = 31,
	faction = "throng",
	race = "orc",
	effort = "lesson",
	prerequisites = {},
	description = "The next frontier post needs news from the safer roads before another loaded caravan attempts the ascent. Travel to Red Ramp Post in Bannerbreak Mesa and speak with Drek Rampbinder. This is level 31–40 country; prepare your equipment before leaving the road. Complete the conversation with Drek Rampbinder there. No parcel, fighting errand or return trip is required.",
	objectives = {{type = "talk", npc = "r20_anchor_043_host", count = 1}},
	rewards = {xp = 915, copper = 50, items = {}},
})

Q.register_quest("r20_troll_start_cook", {
	title = "The Pot Before the Rain",
	npc = "r20_troll_start_cook",
	turnin_npc = "r20_troll_start_cook",
	min_level = 1,
	target_level = 1,
	faction = "throng",
	race = "troll",
	effort = "standard",
	prerequisites = {},
	description = "Zemi Sweetroot has moved the common pot under Kapok's oven shelter before the rain arrives. Bring three coal lumps for the dry fuel basket. Traded supplies count; mining coal yourself only requires a pickaxe; wood and stone picks work too.",
	objectives = {{type = "item", item = "default:coal_lump", count = 3}},
	rewards = {xp = 20, copper = 10, items = {}},
})

Q.register_quest("r20_troll_capital_cook", {
	title = "Smoke Above the Cenote",
	npc = "r20_troll_capital_cook",
	turnin_npc = "r20_troll_capital_cook",
	min_level = 10,
	target_level = 10,
	faction = "throng",
	race = "troll",
	effort = "standard",
	prerequisites = {},
	description = "Teshani Smokereed is preparing the next meal beside Kezamba's shore smokehouse. Bring five raw meat portions for the travellers waiting above the cenote. No Cooking profession is required.",
	objectives = {{type = "item", item = "mobs:meat_raw", count = 5}},
	rewards = {xp = 380, copper = 45, items = {}},
})

Q.register_quest("r20_troll_capital_intro", {
	title = "The Road to Kezamba",
	npc = "r14_troll_elder",
	turnin_npc = "r20_troll_capital_envoy",
	min_level = 10,
	target_level = 10,
	faction = "throng",
	race = "troll",
	effort = "lesson",
	prerequisites = {},
	description = "Kezamba's shrine receives travellers looking for trainers, repairs and the city's public workspaces. At level 10, follow the road to Nalo Pathdrum there. The country around the city is level 20–30; leave its wildlife alone on the journey. Speak with Nalo and complete the introduction at the shrine.",
	objectives = {{type = "talk", npc = "r20_troll_capital_envoy", count = 1}},
	rewards = {xp = 285, copper = 40, items = {}},
})

Q.register_quest("r20_troll_capital_services", {
	title = "The Smokereed Welcome",
	npc = "r20_troll_capital_envoy",
	turnin_npc = "r20_troll_capital_cook",
	min_level = 10,
	target_level = 10,
	faction = "throng",
	race = "troll",
	effort = "lesson",
	prerequisites = {"r20_troll_capital_intro"},
	description = "Nalo sends new arrivals to Teshani Smokereed at the shore smokehouse. Speak with the cook beside the oven and complete this introduction there; the separate Cooking trainer is optional.",
	objectives = {{type = "talk", npc = "r20_troll_capital_cook", count = 1}},
	rewards = {xp = 285, copper = 40, items = {}},
})

Q.register_quest("r20_troll_capital_stores", {
	title = "Boards for the Rain Stores",
	npc = "r20_troll_capital_envoy",
	turnin_npc = "r20_troll_capital_envoy",
	min_level = 20,
	target_level = 20,
	faction = "throng",
	race = "troll",
	effort = "standard",
	prerequisites = {},
	description = "The rain stores need sound crosspieces above the damp floor. Bring ten junglewood planks to Nalo in Kezamba so the next cargo can stay dry without narrowing the walkway.",
	objectives = {{type = "item", item = "default:junglewood", count = 10}},
	rewards = {xp = 780, copper = 60, items = {}},
})

Q.register_quest("r20_troll_journey_01", {
	title = "Word for Taleko Drycord",
	npc = "r20_troll_capital_envoy",
	turnin_npc = "r20_anchor_024_host",
	min_level = 21,
	target_level = 21,
	faction = "throng",
	race = "troll",
	effort = "lesson",
	prerequisites = {},
	description = "The capital keeps contact with the working settlements beyond its walls. Travel to Whisperreed Landing in Whispering Reedlands and speak with Taleko Drycord. This is level 21–30 country; prepare your equipment before leaving the road. Complete the conversation with Taleko Drycord there. No parcel, fighting errand or return trip is required.",
	objectives = {{type = "talk", npc = "r20_anchor_024_host", count = 1}},
	rewards = {xp = 615, copper = 50, items = {}},
})

Q.register_quest("r20_troll_journey_02", {
	title = "Word for Zali Runoff",
	npc = "r20_anchor_024_host",
	turnin_npc = "r20_anchor_066_host",
	min_level = 24,
	target_level = 24,
	faction = "throng",
	race = "troll",
	effort = "lesson",
	prerequisites = {},
	description = "The settlement and its nearby cutters need a direct line for their next repair season. Travel to Reedstone Cut in Whispering Reedlands and speak with Zali Runoff. This is level 21–30 country; prepare your equipment before leaving the road. Complete the conversation with Zali Runoff there. No parcel, fighting errand or return trip is required.",
	objectives = {{type = "talk", npc = "r20_anchor_066_host", count = 1}},
	rewards = {xp = 705, copper = 50, items = {}},
})

Q.register_quest("r20_troll_journey_03", {
	title = "Word for Rumela Stormstep",
	npc = "r20_anchor_066_host",
	turnin_npc = "r20_anchor_048_host",
	min_level = 31,
	target_level = 31,
	faction = "throng",
	race = "troll",
	effort = "lesson",
	prerequisites = {},
	description = "The next frontier post needs news from the safer roads before another loaded caravan attempts the ascent. Travel to Thunderstep Watch in Thunderroot Wilds and speak with Rumela Stormstep. This is level 31–40 country; prepare your equipment before leaving the road. Complete the conversation with Rumela Stormstep there. No parcel, fighting errand or return trip is required.",
	objectives = {{type = "talk", npc = "r20_anchor_048_host", count = 1}},
	rewards = {xp = 915, copper = 50, items = {}},
})
