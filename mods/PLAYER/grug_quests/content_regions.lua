-- Round 20 regional bundles. Each location has two independent jobs and one consequence.
local Q = grug_quests

Q.register_quest("r20_anchor_014_01", {
	title = "The Cairn Mortar",
	npc = "r20_anchor_014_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "The cairn beside Tarnwatch's bent southern lane has shed its mortar into the caravan track. Bring ten sound cobble blocks for its base; the smith can fit them while the sleds are unloaded. Existing or traded supplies are welcome.",
	faction = "accord",
	objectives = {{type = "item", item = "default:cobble", count = 10}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_014_02", {
	title = "Hooves Above the Sleds",
	npc = "r20_anchor_014_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Ibex come down the conifer slopes by day and knock the loaded sleds against Tarnwatch's hall. Clear four animals from Frostbarrow Shelf while the masons reset the cairn.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:ibex"}, zone = "elandor_frostbarrow_shelf", count = 4}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_014_03", {
	title = "The Bell After Dark",
	npc = "r20_anchor_014_host",
	min_level = 23,
	target_level = 23,
	effort = "standard",
	prerequisites = {"r20_anchor_014_02"},
	description = "With the sled lane open, Edda can hear raiders signalling beyond the cairn after dark. Defeat four goblin raiders in Frostbarrow Shelf before their night party learns where the caravans sleep.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:goblin_raider"}, zone = "elandor_frostbarrow_shelf", count = 4}},
	rewards = {xp = 900, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_016_01", {
	title = "The Press Frame",
	npc = "r20_anchor_016_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Whitebridge's little market press has lost the brace that keeps its frame square. Bring eight ordinary oak planks for the covered workbench; the nearby boatworkers have already claimed the sound timber in their own stock. Existing or traded supplies are welcome.",
	faction = "accord",
	objectives = {{type = "item", item = "default:wood", count = 8}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_016_02", {
	title = "The Poacher's Market",
	npc = "r20_anchor_016_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Poachers set snares along Whitebridge Shire's grass and forest margins at night, then bring their catch past the market close. Remove four of them so the morning wagons can use that approach.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:poacher"}, zone = "elandor_whitebridge_shire", count = 4}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_016_03", {
	title = "A Light Beyond the Bridge",
	npc = "r20_anchor_016_host",
	min_level = 23,
	target_level = 23,
	effort = "standard",
	prerequisites = {"r20_anchor_016_02"},
	description = "Now the snares are quiet, the watch can distinguish the lights that belong to no traveller. Hunt three wisps after dark among Whitebridge Shire's damp ground and woodland litter; the bridge itself is not their spawning ground.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:wisp"}, zone = "elandor_whitebridge_shire", count = 3}},
	rewards = {xp = 900, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_018_01", {
	title = "Stones Around the Roots",
	npc = "r20_anchor_018_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Berrycourt's orchard crew needs a low stone rim to keep washed soil against the roots. Bring eight cobble blocks to Lorindor Berrycourt, leaving the tended trees and protected court intact. Existing or traded supplies are welcome.",
	faction = "accord",
	objectives = {{type = "item", item = "default:cobble", count = 8}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_018_02", {
	title = "No Snares in Berrycourt",
	npc = "r20_anchor_018_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "At night, poachers work Lorindor's silver-leaf and forest margins beyond Berrycourt. Defeat four of them while the orchard crew rebuilds the root beds.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:poacher"}, zone = "elandor_lorindor", count = 4}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_018_03", {
	title = "The Uninvited Lanterns",
	npc = "r20_anchor_018_host",
	min_level = 23,
	target_level = 23,
	effort = "standard",
	prerequisites = {"r20_anchor_018_02"},
	description = "The snares have gone, but pale lights still lead late pickers away from Lorindor's orchard paths. Disperse three wisps after dark around the damp woodland, then report back to Ilwen.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:wisp"}, zone = "elandor_lorindor", count = 3}},
	rewards = {xp = 900, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_020_01", {
	title = "Shelves for the Remembered",
	npc = "r20_anchor_020_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "The namekeeper will not let another stone tablet rest on a rotten archive shelf. Bring eight gravewood planks to Ossuary Ledgerstead; the local gravewood trunks make the boards these shelves require. Existing or traded supplies are welcome.",
	faction = "throng",
	objectives = {{type = "item", item = "grug_trees:gravewood_wood", count = 8}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_020_02", {
	title = "Teeth Beside the Archive",
	npc = "r20_anchor_020_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Blightfang wolves hunt along Ossuary Reach's bone-forest floor and cut off visitors carrying names to the archive. Defeat four of them without disturbing the memorial plots.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:blightfang_wolf"}, zone = "kragmar_ossuary_reach", count = 4}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_020_03", {
	title = "The Trees That Refuse Rest",
	npc = "r20_anchor_020_host",
	min_level = 23,
	target_level = 23,
	effort = "standard",
	prerequisites = {"r20_anchor_020_02"},
	description = "Once the wolf tracks are cleared, the night watch can reach the older grove. Three gravewood treants there keep tearing at the boundary markers after dark. Put them down in Ossuary Reach and bring the report to Sovel.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:gravewood_treant"}, zone = "kragmar_ossuary_reach", count = 3}},
	rewards = {xp = 900, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_022_01", {
	title = "Shade Before Strength",
	npc = "r20_anchor_022_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Wellhold's water jars stand in the sun whenever a shade brace splits. Bring eight acacia planks for the roof above the jars; do not dismantle the village's shelters for timber. Existing or traded supplies are welcome.",
	faction = "throng",
	objectives = {{type = "item", item = "default:acacia_wood", count = 8}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_022_02", {
	title = "Stripes in the Cutting Grass",
	npc = "r20_anchor_022_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Speargrass tigers cross the dry grass by day and stalk the cutters approaching Wellhold. Clear three from Speargrass Reach while the shade is repaired.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:speargrass_tiger"}, zone = "kragmar_speargrass_reach", count = 3}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_022_03", {
	title = "Night at the Water Jars",
	npc = "r20_anchor_022_host",
	min_level = 23,
	target_level = 23,
	effort = "standard",
	prerequisites = {"r20_anchor_022_02"},
	description = "The cutters can reach the well again, but the jars are unsafe after sunset. Hunt four scorpions on Speargrass Reach's dry grass and clay when they emerge at night.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:scorpion"}, zone = "kragmar_speargrass_reach", count = 4}},
	rewards = {xp = 900, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_024_01", {
	title = "A Landing That Holds",
	npc = "r20_anchor_024_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Whisperreed's landing needs crosspieces strong enough to keep laden travellers above the mud. Bring eight junglewood planks to the sheltered landing workshop; this is a repair delivery, not a boatbuilding lesson. Existing or traded supplies are welcome.",
	faction = "throng",
	objectives = {{type = "item", item = "default:junglewood", count = 8}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_024_02", {
	title = "Tapirs on the Dry Path",
	npc = "r20_anchor_024_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Tapirs crowd the dry paths through Whispering Reedlands by day. Clear four so carriers can bring their loads to Whisperreed Landing without stepping into the pools.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:tapir"}, zone = "kragmar_whispering_reedlands", count = 4}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_024_03", {
	title = "Cold Lights in the Reeds",
	npc = "r20_anchor_024_host",
	min_level = 23,
	target_level = 23,
	effort = "standard",
	prerequisites = {"r20_anchor_024_02"},
	description = "The cleared paths are drawing travellers after dusk, when false lights gather over the reeds. Disperse three wisps in Whispering Reedlands at night and return to Taleko.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:wisp"}, zone = "kragmar_whispering_reedlands", count = 3}},
	rewards = {xp = 900, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_026_01", {
	title = "Fuel Under Cover",
	npc = "r20_anchor_026_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Rimebell keeps its signal fuel under a roof because wet coal serves no watch. Bring six coal lumps for that dry store while the lookout checks the shelf road. Existing or traded supplies are welcome.",
	faction = "accord",
	objectives = {{type = "item", item = "default:coal_lump", count = 6}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_026_02", {
	title = "The Sled Track Pack",
	npc = "r20_anchor_026_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Snow leopards hunt Frostbarrow Shelf's gravel and snowy patches at night. Defeat three near the sled routes before another caravan loses its rear guard.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:snow_leopard"}, zone = "elandor_frostbarrow_shelf", count = 3}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_026_03", {
	title = "Notches on the Signal Pole",
	npc = "r20_anchor_026_host",
	min_level = 23,
	target_level = 23,
	effort = "standard",
	prerequisites = {"r20_anchor_026_02"},
	description = "After the cats are driven back, the watch can read the new notches on its signal pole. They match a goblin slinger band's night signals. Defeat four slingers in Frostbarrow Shelf.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:goblin_slinger"}, zone = "elandor_frostbarrow_shelf", count = 4}},
	rewards = {xp = 900, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_027_01", {
	title = "Shutters Against the Storm",
	npc = "r20_anchor_027_host",
	min_level = 31,
	target_level = 31,
	effort = "standard",
	prerequisites = {},
	description = "The wind has pulled Splitbolt's shutters off their braces. Bring eight pine planks for the storm-facing shelter; the snowy pines of Stormvault Heights provide suitable timber. Existing or traded supplies are welcome.",
	faction = "accord",
	objectives = {{type = "item", item = "default:pine_wood", count = 8}},
	rewards = {xp = 1220, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_027_02", {
	title = "The Frost That Walks",
	npc = "r20_anchor_027_host",
	min_level = 31,
	target_level = 31,
	effort = "standard",
	prerequisites = {},
	description = "Frost strays stand on Stormvault Heights' gravel and snow after dark, loosing arrows across the ascent. Defeat four so the watch can reach its storm markers.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:frost_stray"}, zone = "elandor_stormvault_heights", count = 4}},
	rewards = {xp = 1220, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_027_03", {
	title = "Slatehook's Cargo",
	npc = "r20_anchor_027_host",
	min_level = 33,
	target_level = 33,
	effort = "standard",
	prerequisites = {"r20_anchor_027_02"},
	description = "With the ascent watched again, Borin can point you toward Slatehook Camp in Stormvault Heights. Defeat four bandit archers around that occupied camp; they are camp guards, not the roaming night poachers.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:bandit_archer"}, zone = "elandor_stormvault_heights", count = 4}},
	rewards = {xp = 1300, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_028_01", {
	title = "Stones for the Sighting Line",
	npc = "r20_anchor_028_host",
	min_level = 31,
	target_level = 31,
	effort = "standard",
	prerequisites = {},
	description = "Archshadow's sighting stones no longer line up across the ridge crossing. Bring eight cobble blocks for their low footing so the watch can reset the line without narrowing the passage. Existing or traded supplies are welcome.",
	faction = "accord",
	objectives = {{type = "item", item = "default:cobble", count = 8}},
	rewards = {xp = 1220, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_028_02", {
	title = "Wings Over the Crossing",
	npc = "r20_anchor_028_host",
	min_level = 31,
	target_level = 31,
	effort = "standard",
	prerequisites = {},
	description = "Crag eagles dive over Stormvault Heights' rocky ground by day. Defeat three that threaten travellers using the crossing, then report to Archshadow Post.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:crag_eagle"}, zone = "elandor_stormvault_heights", count = 3}},
	rewards = {xp = 1220, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_028_03", {
	title = "The Watch Beyond the Ash Wind",
	npc = "r20_anchor_028_host",
	min_level = 40,
	target_level = 40,
	effort = "hard",
	prerequisites = {"r20_anchor_028_02"},
	description = "The ridge report names the Throng watch in Blackwind Rise across the frontier. At level 40, defeat three Throng guards at its military outposts or their patrols. These are armed garrisons, not villagers or players; do not approach Nhal Veyr's stronger city watch.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:guard_throng"}, zone = "kragmar_blackwind_rise", count = 3}},
	rewards = {xp = 1975, copper = 100, items = {}},
})

Q.register_quest("r20_anchor_030_01", {
	title = "An Axle for the Empty Cart",
	npc = "r20_anchor_030_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "The cart beside Oakspan Tollhouse cannot move until its axle supports are replaced. Bring eight oak planks for the covered cart bay while the road patrol clears the approach. Existing or traded supplies are welcome.",
	faction = "accord",
	objectives = {{type = "item", item = "default:wood", count = 8}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_030_02", {
	title = "The Tollhouse Snares",
	npc = "r20_anchor_030_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Poachers hide their snares in Whitebridge Shire's grass and forest margins at night. Defeat four so the tollhouse crew can recover the road markers in daylight.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:poacher"}, zone = "elandor_whitebridge_shire", count = 4}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_030_03", {
	title = "Night Lights at Oakspan",
	npc = "r20_anchor_030_host",
	min_level = 23,
	target_level = 23,
	effort = "standard",
	prerequisites = {"r20_anchor_030_02"},
	description = "After the snare line is removed, strange lights still cross the darker wet ground near Oakspan. Disperse three wisps in Whitebridge Shire after nightfall.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:wisp"}, zone = "elandor_whitebridge_shire", count = 3}},
	rewards = {xp = 900, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_031_01", {
	title = "A Wall Against Embers",
	npc = "r20_anchor_031_host",
	min_level = 31,
	target_level = 31,
	effort = "standard",
	prerequisites = {},
	description = "Embers blow straight through the low gap in Cinderline's wind wall. Bring ten cobble blocks for that gap so the watch's covered barrels stay sheltered. Existing or traded supplies are welcome.",
	faction = "accord",
	objectives = {{type = "item", item = "default:cobble", count = 10}},
	rewards = {xp = 1220, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_031_02", {
	title = "The Ashen Wood Stirs",
	npc = "r20_anchor_031_host",
	min_level = 31,
	target_level = 31,
	effort = "standard",
	prerequisites = {},
	description = "Ashen treants move through Ashenward March's forest litter at night. Defeat three before the watch sends another barrel crew into those scorched stands.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:ashen_treant"}, zone = "elandor_ashenward_march", count = 3}},
	rewards = {xp = 1220, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_031_03", {
	title = "Coalbrand's Watchers",
	npc = "r20_anchor_031_host",
	min_level = 33,
	target_level = 33,
	effort = "standard",
	prerequisites = {"r20_anchor_031_02"},
	description = "The barrel route is usable again, and its stolen cargo has been traced to Coalbrand Camp in Ashenward March. Defeat four bandit archers guarding that camp's supplies.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:bandit_archer"}, zone = "elandor_ashenward_march", count = 4}},
	rewards = {xp = 1300, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_032_01", {
	title = "Posts for the Last Hedge",
	npc = "r20_anchor_032_host",
	min_level = 31,
	target_level = 31,
	effort = "standard",
	prerequisites = {},
	description = "The last hedge has gaps wide enough for loaded wagons to drift off the dispatch lane. Bring eight oak planks for the marker posts at Last Hedge Redoubt. Existing or traded supplies are welcome.",
	faction = "accord",
	objectives = {{type = "item", item = "default:wood", count = 8}},
	rewards = {xp = 1220, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_032_02", {
	title = "Dead on the Dispatch Road",
	npc = "r20_anchor_032_host",
	min_level = 31,
	target_level = 31,
	effort = "standard",
	prerequisites = {},
	description = "Skeleton raiders take the dispatch road through Ashenward March after nightfall. Defeat four while the watch restores the road's markers.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:skeleton_raider"}, zone = "elandor_ashenward_march", count = 4}},
	rewards = {xp = 1220, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_032_03", {
	title = "Standards Across the Mesa",
	npc = "r20_anchor_032_host",
	min_level = 40,
	target_level = 40,
	effort = "hard",
	prerequisites = {"r20_anchor_032_02"},
	description = "The dispatches identify a Throng garrison across Bannerbreak Mesa. At level 40, defeat three Throng guards at those frontier military posts or their patrols. Leave civilians, players and Gor Drazhak's city watch outside this mission.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:guard_throng"}, zone = "kragmar_bannerbreak_mesa", count = 3}},
	rewards = {xp = 1975, copper = 100, items = {}},
})

Q.register_quest("r20_anchor_034_01", {
	title = "The Trough's New Kerb",
	npc = "r20_anchor_034_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Petalbank's trough has lost the stone kerb that keeps washwater out of the berry baskets. Bring eight cobble blocks for its edge; the covered court must stay open to carriers. Existing or traded supplies are welcome.",
	faction = "accord",
	objectives = {{type = "item", item = "default:cobble", count = 8}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_034_02", {
	title = "Wardens Without Arrows",
	npc = "r20_anchor_034_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Poachers enter Lorindor's woodland at night and force Petalbank's wardens away from the gathering routes. Defeat four so the wardens can take their normal posts again.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:poacher"}, zone = "elandor_lorindor", count = 4}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_034_03", {
	title = "Lanterns We Did Not Hang",
	npc = "r20_anchor_034_host",
	min_level = 23,
	target_level = 23,
	effort = "standard",
	prerequisites = {"r20_anchor_034_02"},
	description = "The wardens have rehung their own lamps, but other lights still move beyond them after dark. Disperse three wisps in Lorindor's damp woodland and report to Petalbank.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:wisp"}, zone = "elandor_lorindor", count = 3}},
	rewards = {xp = 900, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_035_01", {
	title = "A Chart Table Repaired",
	npc = "r20_anchor_035_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Moonfall's chart table rocks whenever the lookout marks a route. Bring eight oak planks for its frame; the observatory is a shelter for path-watchers, not a new magical instrument. Existing or traded supplies are welcome.",
	faction = "accord",
	objectives = {{type = "item", item = "default:wood", count = 8}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_035_02", {
	title = "Fangs Beneath the Fallen Bough",
	npc = "r20_anchor_035_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Wolves prowl Moonfall Wood's forest floor beneath the fallen boughs. Defeat four so the observers can check the lake paths without abandoning their charts.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:wolf"}, zone = "elandor_moonfall_wood", count = 4}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_035_03", {
	title = "The Moonlit Snare Line",
	npc = "r20_anchor_035_host",
	min_level = 23,
	target_level = 23,
	effort = "standard",
	prerequisites = {"r20_anchor_035_02"},
	description = "The clear paths expose a second hazard: poachers return to the wood at night. Defeat four in Moonfall Wood before the next dawn survey follows their snare line.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:poacher"}, zone = "elandor_moonfall_wood", count = 4}},
	rewards = {xp = 900, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_036_01", {
	title = "Stone Under the Passage",
	npc = "r20_anchor_036_host",
	min_level = 31,
	target_level = 31,
	effort = "standard",
	prerequisites = {},
	description = "Rain has loosened the footing beneath Glassroot Gate's cliff passage. Bring ten cobble blocks for the low support so carriers can keep using the route while it is repaired. Existing or traded supplies are welcome.",
	faction = "accord",
	objectives = {{type = "item", item = "default:cobble", count = 10}},
	rewards = {xp = 1220, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_036_02", {
	title = "Rootsnare's Stolen Cloth",
	npc = "r20_anchor_036_host",
	min_level = 31,
	target_level = 31,
	effort = "standard",
	prerequisites = {},
	description = "Rootsnare Camp's bandits have taken supplies intended for the passage. Defeat four bandits at the occupied camp in Glassroot Wilds, rather than hunting unrelated forest creatures.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:bandit"}, zone = "elandor_glassroot_wilds", count = 4}},
	rewards = {xp = 1220, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_036_03", {
	title = "The Other Rootwatch",
	npc = "r20_anchor_036_host",
	min_level = 40,
	target_level = 40,
	effort = "hard",
	prerequisites = {"r20_anchor_036_02"},
	description = "The recovered report points across Thunderroot Wilds to the Throng's frontier watch. At level 40, defeat three Throng guards at those military outposts or their patrols. This does not include villagers, players or Kezamba's capital guard.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:guard_throng"}, zone = "kragmar_thunderroot_wilds", count = 3}},
	rewards = {xp = 1975, copper = 100, items = {}},
})

Q.register_quest("r20_anchor_038_01", {
	title = "A Shelf for Stone Names",
	npc = "r20_anchor_038_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Boneledger's stone names have outlasted their wooden shelf. Bring eight gravewood planks for the record shelter so the watch can keep road reports separate from memorial tablets. Existing or traded supplies are welcome.",
	faction = "throng",
	objectives = {{type = "item", item = "grug_trees:gravewood_wood", count = 8}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_038_02", {
	title = "The Hungry Gravewood",
	npc = "r20_anchor_038_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Gravewood treants stir on Ossuary Reach's bone-covered forest floor after dark. Defeat three before the next ledger carrier follows that road.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:gravewood_treant"}, zone = "kragmar_ossuary_reach", count = 3}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_038_03", {
	title = "A Pack on the Ledger Road",
	npc = "r20_anchor_038_host",
	min_level = 23,
	target_level = 23,
	effort = "standard",
	prerequisites = {"r20_anchor_038_02"},
	description = "With the night grove quiet, the keeper can send carriers farther along the road. Defeat four blightfang wolves in Ossuary Reach so the hungry packs do not take their place.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:blightfang_wolf"}, zone = "kragmar_ossuary_reach", count = 4}},
	rewards = {xp = 900, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_039_01", {
	title = "Keep the Lamps Burning",
	npc = "r20_anchor_039_host",
	min_level = 31,
	target_level = 31,
	effort = "standard",
	prerequisites = {},
	description = "Ashveil reads its wind markers by lamplight, but the covered fuel box is nearly empty. Bring six coal lumps for the lamps before the next night watch. Existing or traded supplies are welcome.",
	faction = "throng",
	objectives = {{type = "item", item = "default:coal_lump", count = 6}},
	rewards = {xp = 1220, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_039_02", {
	title = "Ash Among Living Branches",
	npc = "r20_anchor_039_host",
	min_level = 31,
	target_level = 31,
	effort = "standard",
	prerequisites = {},
	description = "Gravewood treants move among Blackwind Rise's bone-littered trees after dark. Defeat three so the watchers can read the branches' movement without confusing it with the wind.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:gravewood_treant"}, zone = "kragmar_blackwind_rise", count = 3}},
	rewards = {xp = 1220, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_039_03", {
	title = "The Pallcloth Thieves",
	npc = "r20_anchor_039_host",
	min_level = 33,
	target_level = 33,
	effort = "standard",
	prerequisites = {"r20_anchor_039_02"},
	description = "Vaska's cleared sightline reveals who is carrying the stolen cloth: Pallcloth Camp's archers. Defeat four bandit archers in that Blackwind Rise camp and return to the watch.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:bandit_archer"}, zone = "kragmar_blackwind_rise", count = 4}},
	rewards = {xp = 1300, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_040_01", {
	title = "The Dispatch Shelf",
	npc = "r20_anchor_040_host",
	min_level = 31,
	target_level = 31,
	effort = "standard",
	prerequisites = {},
	description = "Hollowarch's dispatch shelf has sagged under damp message stones. Bring eight local gravewood planks to the roofed station; the old arches themselves must remain untouched. Existing or traded supplies are welcome.",
	faction = "throng",
	objectives = {{type = "item", item = "grug_trees:gravewood_wood", count = 8}},
	rewards = {xp = 1220, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_040_02", {
	title = "Claws Beneath the Arch",
	npc = "r20_anchor_040_host",
	min_level = 31,
	target_level = 31,
	effort = "standard",
	prerequisites = {},
	description = "Plaguehide bears move through Blackwind Rise's bone-forest floor beside the arch approaches. Defeat three before the next carrier attempts the crossing.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:plaguehide_bear"}, zone = "kragmar_blackwind_rise", count = 3}},
	rewards = {xp = 1220, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_040_03", {
	title = "The Watch Under the Storm",
	npc = "r20_anchor_040_host",
	min_level = 40,
	target_level = 40,
	effort = "hard",
	prerequisites = {"r20_anchor_040_02"},
	description = "The dispatches name the Accord watch in Stormvault Heights. At level 40, defeat three Accord guards at the frontier outposts or their patrols there. Do not attack civilians, players or Dur Brannoc's city watch for this report.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:guard_accord"}, zone = "elandor_stormvault_heights", count = 3}},
	rewards = {xp = 1975, copper = 100, items = {}},
})

Q.register_quest("r20_anchor_042_01", {
	title = "Posts for the Shade",
	npc = "r20_anchor_042_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Cutgrass Watch has a roof cloth but too few sound posts to hold its shade. Bring eight acacia planks for the cutters' waiting place beside the shelter. Existing or traded supplies are welcome.",
	faction = "throng",
	objectives = {{type = "item", item = "default:acacia_wood", count = 8}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_042_02", {
	title = "The Cutters' Long Walk",
	npc = "r20_anchor_042_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Speargrass tigers hunt the dry cutting grounds by day. Defeat three in Speargrass Reach so the cutters can bring their bundles back to the watch.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:speargrass_tiger"}, zone = "kragmar_speargrass_reach", count = 3}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_042_03", {
	title = "Raiders at the Signal Fire",
	npc = "r20_anchor_042_host",
	min_level = 23,
	target_level = 23,
	effort = "standard",
	prerequisites = {"r20_anchor_042_02"},
	description = "The daytime route is clearer, but goblin raiders gather near the signal paths after sunset. Defeat four in Speargrass Reach during the night watch.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:goblin_raider"}, zone = "kragmar_speargrass_reach", count = 4}},
	rewards = {xp = 900, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_043_01", {
	title = "Planks for the Ascent",
	npc = "r20_anchor_043_host",
	min_level = 31,
	target_level = 31,
	effort = "standard",
	prerequisites = {},
	description = "The mesa ramp's side supports need replacing before another heavy load climbs it. Bring ten acacia planks to Red Ramp Post's sheltered work area. Existing or traded supplies are welcome.",
	faction = "throng",
	objectives = {{type = "item", item = "default:acacia_wood", count = 10}},
	rewards = {xp = 1220, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_043_02", {
	title = "Shells Among the Planks",
	npc = "r20_anchor_043_host",
	min_level = 31,
	target_level = 31,
	effort = "standard",
	prerequisites = {},
	description = "Scorpions emerge on Bannerbreak Mesa's clay and dry grass after dark, hiding among stored planks. Defeat four while the ramp crew keeps its loads under cover.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:scorpion"}, zone = "kragmar_bannerbreak_mesa", count = 4}},
	rewards = {xp = 1220, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_043_03", {
	title = "Sunderstrap's Sentinels",
	npc = "r20_anchor_043_host",
	min_level = 33,
	target_level = 33,
	effort = "standard",
	prerequisites = {"r20_anchor_043_02"},
	description = "Once the plank yard is safe, Drek can send you toward Sunderstrap Camp. Defeat four bandit archers guarding its stolen loads in Bannerbreak Mesa.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:bandit_archer"}, zone = "kragmar_bannerbreak_mesa", count = 4}},
	rewards = {xp = 1300, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_044_01", {
	title = "A Standard Needs a Footing",
	npc = "r20_anchor_044_host",
	min_level = 31,
	target_level = 31,
	effort = "standard",
	prerequisites = {},
	description = "Tornstandard's banner footing is splitting where the supply lane bends. Bring eight cobble blocks for the low base, leaving the working military banner in place. Existing or traded supplies are welcome.",
	faction = "throng",
	objectives = {{type = "item", item = "default:cobble", count = 8}},
	rewards = {xp = 1220, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_044_02", {
	title = "The Empty Mesa Patrol",
	npc = "r20_anchor_044_host",
	min_level = 31,
	target_level = 31,
	effort = "standard",
	prerequisites = {},
	description = "Skeleton raiders cross Bannerbreak Mesa's clay and dry ground at night. Defeat four so dispatch runners can reach the hold before dawn.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:skeleton_raider"}, zone = "kragmar_bannerbreak_mesa", count = 4}},
	rewards = {xp = 1220, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_044_03", {
	title = "The Last Hedge Abroad",
	npc = "r20_anchor_044_host",
	min_level = 40,
	target_level = 40,
	effort = "hard",
	prerequisites = {"r20_anchor_044_02"},
	description = "The next report concerns the Accord's Last Hedge frontier in Ashenward March. At level 40, defeat three Accord guards at the military outposts or their patrols in that zone. Civilians, players and Highcourt's city watch are not targets.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:guard_accord"}, zone = "elandor_ashenward_march", count = 3}},
	rewards = {xp = 1975, copper = 100, items = {}},
})

Q.register_quest("r20_anchor_046_01", {
	title = "A Dry Signal Shelf",
	npc = "r20_anchor_046_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Reedvoice's signal shelf has sunk below the driest line on its posts. Bring eight junglewood planks to raise the shelf inside the shelter without blocking the reed-path entrance. Existing or traded supplies are welcome.",
	faction = "throng",
	objectives = {{type = "item", item = "default:junglewood", count = 8}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_046_02", {
	title = "Cats by the Reed Pipes",
	npc = "r20_anchor_046_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Jungle lynx watch Whispering Reedlands' forest margins by day and keep the signal carriers from their paths. Defeat four, then return to Reedvoice Station.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:jungle_lynx"}, zone = "kragmar_whispering_reedlands", count = 4}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_046_03", {
	title = "The False Answering Lights",
	npc = "r20_anchor_046_host",
	min_level = 23,
	target_level = 23,
	effort = "standard",
	prerequisites = {"r20_anchor_046_02"},
	description = "The carriers can travel by day, but lights in the wet reeds mimic the station's signals after dusk. Disperse three wisps in Whispering Reedlands at night.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:wisp"}, zone = "kragmar_whispering_reedlands", count = 3}},
	rewards = {xp = 900, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_047_01", {
	title = "Rope Rack Timbers",
	npc = "r20_anchor_047_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Totemwater's rope rack needs sound crosspieces before the next river crossing. Bring eight junglewood planks for the covered rack; the river path must stay open beside it. Existing or traded supplies are welcome.",
	faction = "throng",
	objectives = {{type = "item", item = "default:junglewood", count = 8}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_047_02", {
	title = "Jaws at the River Path",
	npc = "r20_anchor_047_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Crocodiles wait on Totemwater Reach's muddy banks where carriers leave the path. Defeat three and give the crossing crew room to work.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:crocodile"}, zone = "kragmar_totemwater_reach", count = 3}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_047_03", {
	title = "Mud Around the Marker",
	npc = "r20_anchor_047_host",
	min_level = 23,
	target_level = 23,
	effort = "standard",
	prerequisites = {"r20_anchor_047_02"},
	description = "With the banks clearer, the crew can see bog ooze collecting below the route marker. Break up four in Totemwater Reach's muddy ground before the next load comes through.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:bog_ooze"}, zone = "kragmar_totemwater_reach", count = 4}},
	rewards = {xp = 900, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_048_01", {
	title = "A Gutter Before the Rain",
	npc = "r20_anchor_048_host",
	min_level = 31,
	target_level = 31,
	effort = "standard",
	prerequisites = {},
	description = "Thunderstep's roof runoff cuts across the forest ascent. Bring eight cobble blocks for a shallow gutter beside the shelter, keeping the walking line free. Existing or traded supplies are welcome.",
	faction = "throng",
	objectives = {{type = "item", item = "default:cobble", count = 8}},
	rewards = {xp = 1220, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_048_02", {
	title = "Rainchar's Burning Cargo",
	npc = "r20_anchor_048_host",
	min_level = 31,
	target_level = 31,
	effort = "standard",
	prerequisites = {},
	description = "Rainchar Camp's bandits hold supplies intended for the ascent. Defeat four bandits at that occupied camp in Thunderroot Wilds and report to Rumela.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:bandit"}, zone = "kragmar_thunderroot_wilds", count = 4}},
	rewards = {xp = 1220, copper = 85, items = {}},
})

Q.register_quest("r20_anchor_048_03", {
	title = "Across the Glass Passage",
	npc = "r20_anchor_048_host",
	min_level = 40,
	target_level = 40,
	effort = "hard",
	prerequisites = {"r20_anchor_048_02"},
	description = "The report points across Glassroot Wilds to the Accord's frontier watch. At level 40, defeat three Accord guards at its military outposts or their patrols. This mission concerns armed guards, never villagers, players or Lethariel's capital watch.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:guard_accord"}, zone = "elandor_glassroot_wilds", count = 3}},
	rewards = {xp = 1975, copper = 100, items = {}},
})

Q.register_quest("r20_anchor_061_01", {
	title = "A Handle for the Cutting",
	npc = "r20_anchor_061_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Tarncut's spare pick has lost its working head, and the sorting crew needs a replacement. Bring one ordinary stone pick, made or traded; no proof of mining is required. Existing or traded supplies are welcome.",
	faction = "accord",
	objectives = {{type = "item", item = "default:pick_stone", count = 1}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_061_02", {
	title = "Rams on the Haul Lane",
	npc = "r20_anchor_061_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Mountain rams wander Frostbarrow Shelf's rocky ground by day and block the mine's haul approaches. Clear four while the crew sorts the next load.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:mountain_ram"}, zone = "elandor_frostbarrow_shelf", count = 4}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_061_03", {
	title = "The Cold Shift",
	npc = "r20_anchor_061_host",
	min_level = 23,
	target_level = 23,
	effort = "standard",
	prerequisites = {"r20_anchor_061_02"},
	description = "The daytime lane is open, but snow leopards hunt the shelf's gravel and snow after dusk. Defeat three during the cold shift so the next sled can leave safely.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:snow_leopard"}, zone = "elandor_frostbarrow_shelf", count = 3}},
	rewards = {xp = 900, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_062_01", {
	title = "Braces for the Pale Face",
	npc = "r20_anchor_062_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Bridgechalk's pale cutting face needs timber braces above the working edge. Bring ten oak planks to the quarry shelter; this shallow worksite is not a newly opened underground mine. Existing or traded supplies are welcome.",
	faction = "accord",
	objectives = {{type = "item", item = "default:wood", count = 10}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_062_02", {
	title = "The Surveyor's Snare",
	npc = "r20_anchor_062_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Poachers set snares in Whitebridge Shire's grassy and wooded margins at night, catching the quarry surveyors' route. Defeat four before the crew returns to its markers.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:poacher"}, zone = "elandor_whitebridge_shire", count = 4}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_062_03", {
	title = "A Quarry Hand's Pick",
	npc = "r20_anchor_062_host",
	min_level = 23,
	target_level = 23,
	effort = "standard",
	prerequisites = {"r20_anchor_062_02"},
	description = "With the survey route clear, the quarry can put another hand on the stone. Bring an ordinary stone pick to the work shelter; a traded or previously used pick counts. Existing or traded supplies are welcome.",
	faction = "accord",
	objectives = {{type = "item", item = "default:pick_stone", count = 1}},
	rewards = {xp = 900, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_063_01", {
	title = "A Gentle Edge",
	npc = "r20_anchor_063_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Paleroot's cutters need a spare stone pick for work beside the orchard roots. Bring one to the braced shelter; you may craft it, buy it or use an existing spare. Existing or traded supplies are welcome.",
	faction = "accord",
	objectives = {{type = "item", item = "default:pick_stone", count = 1}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_063_02", {
	title = "The Survey Stakes Vanish",
	npc = "r20_anchor_063_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Poachers cross Lorindor's woodland at night and disturb the survey stakes outside the cutting. Defeat four so the crew can recover its marked line in daylight.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:poacher"}, zone = "elandor_lorindor", count = 4}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_063_03", {
	title = "Light on the Cutting Marks",
	npc = "r20_anchor_063_host",
	min_level = 23,
	target_level = 23,
	effort = "standard",
	prerequisites = {"r20_anchor_063_02"},
	description = "The recovered line leads into damp ground where wisps gather after dark. Disperse three in Lorindor before another cutter mistakes them for work lamps.",
	faction = "accord",
	objectives = {{type = "kill", mobs = {"grug_mobs:wisp"}, zone = "elandor_lorindor", count = 3}},
	rewards = {xp = 900, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_064_01", {
	title = "The Record Shed Frame",
	npc = "r20_anchor_064_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Memoryvein keeps its rock tallies in a shed apart from the memorial stones. Bring eight gravewood planks for that shed's frame, using the local tree's ordinary sawn boards. Existing or traded supplies are welcome.",
	faction = "throng",
	objectives = {{type = "item", item = "grug_trees:gravewood_wood", count = 8}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_064_02", {
	title = "The Cutters' Uneasy Night",
	npc = "r20_anchor_064_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Gravewood treants move through Ossuary Reach's bone forest after dark and keep the cutters from their return path. Defeat three without disturbing the tended memorials.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:gravewood_treant"}, zone = "kragmar_ossuary_reach", count = 3}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_064_03", {
	title = "A Tool for Unnamed Stone",
	npc = "r20_anchor_064_host",
	min_level = 23,
	target_level = 23,
	effort = "standard",
	prerequisites = {"r20_anchor_064_02"},
	description = "The night route is quiet enough for a new cutting shift. Bring one ordinary stone pick for the crew's spare rack; no special relic or freshly mined stone is required. Existing or traded supplies are welcome.",
	faction = "throng",
	objectives = {{type = "item", item = "default:pick_stone", count = 1}},
	rewards = {xp = 900, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_065_01", {
	title = "Roof Over the Sorting Trays",
	npc = "r20_anchor_065_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Redpick's sorting trays lie beneath a roof whose braces have begun to split. Bring ten acacia planks so the yard can keep its loads covered before the next caravan. Existing or traded supplies are welcome.",
	faction = "throng",
	objectives = {{type = "item", item = "default:acacia_wood", count = 10}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_065_02", {
	title = "Hunters at the Water Shade",
	npc = "r20_anchor_065_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Hyenas prowl Speargrass Reach's dry grass and clay near the cutters' water stops. Defeat four while the crew repairs the sorting roof.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:hyena"}, zone = "kragmar_speargrass_reach", count = 4}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_065_03", {
	title = "Stings in the Drill Stack",
	npc = "r20_anchor_065_host",
	min_level = 23,
	target_level = 23,
	effort = "standard",
	prerequisites = {"r20_anchor_065_02"},
	description = "The water stops are safer, but scorpions emerge around the drill stacks after sunset. Defeat four in Speargrass Reach on the night shift.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:scorpion"}, zone = "kragmar_speargrass_reach", count = 4}},
	rewards = {xp = 900, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_066_01", {
	title = "Timbers Kept Above Water",
	npc = "r20_anchor_066_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Reedstone's timber stacks must stay above the wet ground if the quarry is to remain workable. Bring eight junglewood planks for the raised supports beside its shelter. Existing or traded supplies are welcome.",
	faction = "throng",
	objectives = {{type = "item", item = "default:junglewood", count = 8}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_066_02", {
	title = "The Quarry Pool Moves",
	npc = "r20_anchor_066_host",
	min_level = 21,
	target_level = 21,
	effort = "standard",
	prerequisites = {},
	description = "Bog ooze collects on Whispering Reedlands' muddy ground around the quarry approaches. Break up four so the crew can reach its stored tools.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:bog_ooze"}, zone = "kragmar_whispering_reedlands", count = 4}},
	rewards = {xp = 820, copper = 70, items = {}},
})

Q.register_quest("r20_anchor_066_03", {
	title = "Jaws Along the Haul Path",
	npc = "r20_anchor_066_host",
	min_level = 23,
	target_level = 23,
	effort = "standard",
	prerequisites = {"r20_anchor_066_02"},
	description = "Once the ooze is cleared, the haulers can use the bank path again. Defeat three crocodiles on Whispering Reedlands' muddy banks before the next load leaves Reedstone Cut.",
	faction = "throng",
	objectives = {{type = "kill", mobs = {"grug_mobs:crocodile"}, zone = "kragmar_whispering_reedlands", count = 3}},
	rewards = {xp = 900, copper = 70, items = {}},
})
