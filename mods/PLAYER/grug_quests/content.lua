-- Round 14 V1 overworld quest catalog. The Nether is reserved for expansion one.

local Q = grug_quests

-- Fixed shares of the intended level interval: ordinary 20%, hard 25%,
-- and the camp finale 35% (progression.md section 4).
local XP = {20, 60, 100, 140, 180, 300, 380, 525, 805}
local COPPER = {10, 15, 20, 25, 30, 40, 50, 60, 80}
local LEVEL = {1, 2, 3, 4, 5, 8, 10, 11, 12}
local COUNT = {5, 4, 5, 4, 5, 6, 6, 6, 4}

local BANDITS = {"grug_mobs:bandit", "grug_mobs:bandit_archer"}
local GOBLINS = {"grug_mobs:goblin_raider", "grug_mobs:goblin_slinger",
	"grug_mobs:goblin_hound"}

local cultures = {
	{
		key = "dwarf", faction = "accord", start = "hearthpine",
		village = "copperfell_village", outpost = "copperfell_outpost", camp = "copperfell_bandit_camp",
		names = {"Brunna Flintbraid", "Orrik Pineledger", "Mara Deepwatch",
			"Tovin Ashthumb"},
		titles = {"Tusks at the Timberline", "Meat for the Smokehouse",
			"Rats in the Woodpiles", "Lanterns After Sundown", "The High Path",
			"Loose Stone on Copper Road", "A Ledger in the Scrub",
			"Hold the Marker Stones", "Ash Under the Nails"},
		descriptions = {
			"Boars are tearing through the timberline stores. Thin the sounder before another winter stack is lost.",
			"The smokehouse feeds every shift. Bring ordinary meat; who hunted it does not matter.",
			"Clear pests from the stores: boars by day or the giant rats that emerge after dusk.",
			"Patrol the lantern posts. Boars press the boundary by day and the restless dead replace them after dusk.",
			"Ibex are knocking loose slate above the high path. Clear the animals crowding the ledges.",
			"Boars and ibex have loosened stone over Copper Road. Clear the approach to Copper Road.",
			"Foxes scattered an ore ledger in the scrub. Clear the den so Orrik can recover the pages.",
			"A second goblin pack circles the outpost stones. Mara needs the road held before dusk.",
			"The bandits stole ore tallies and marked them with a hooked sun. Defeat the camp; Tovin waits inside with what he learned.",
		},
		targets = {{"grug_mobs:boar"}, false, {"grug_mobs:giant_rat", "grug_mobs:boar"},
			{"grug_mobs:zombie", "grug_mobs:boar"}, {"grug_mobs:ibex"},
			{"grug_mobs:ibex", "grug_mobs:boar"}, {"grug_mobs:fox"}, GOBLINS, BANDITS},
		zones = {false, false, false, false, false, false,
			"elandor_copperfell_foothills", "elandor_copperfell_foothills",
			"elandor_copperfell_foothills"},
		lessons = {"An Axe Worth Carrying", "Stone Before Steel",
			"Bring a wood axe so Brunna can show where its edge belongs and where it does not.",
			"Bring a stone pick. The lesson is optional, but the mountain is less forgiving than wood."},
	},
	{
		key = "human", faction = "accord", start = "dawnmere",
		village = "goldmead_village", outpost = "goldmead_outpost", camp = "goldmead_bandit_camp",
		names = {"Elian Reed", "Marta Millward", "Jon Vale", "Pella Thatch"},
		titles = {"Boars Beyond the Fence", "The Smokehouse Share", "Granary Teeth",
			"Shapes by Lanternlight", "The Missing Flock", "Flock on Mill Road",
			"Orchard Watch", "Empty Snares", "The Blackened Tally"},
		descriptions = {
			"Boars broke the east fence and rooted the seed rows. Drive them out before planting stops.",
			"Dawnmere owes the smokehouse a share. Bring ordinary meat for the common table.",
			"Clear pests from the granary: boars by day or the giant rats that emerge after dusk.",
			"Patrol the lantern road. Boars press the fields by day and breathless figures replace them after dusk.",
			"Wild turkeys have drawn off the village flock. Thin them near the outer fields.",
			"Boars and wild turkeys crowd Mill Road. Clear the local approach to Mill Road.",
			"Foxes have moved into the orchard margins. Give Marta's pickers room to work.",
			"The poachers left empty snares around the outpost. Jon wants the hunters found before they return.",
			"The bandits burned a hooked-sun mark into stolen grain tallies. Clear the camp and hear Pella's account.",
		},
		targets = {{"grug_mobs:boar"}, false, {"grug_mobs:giant_rat", "grug_mobs:boar"},
			{"grug_mobs:zombie", "grug_mobs:boar"}, {"grug_mobs:wild_turkey"},
			{"grug_mobs:wild_turkey", "grug_mobs:boar"},
			{"grug_mobs:fox"}, {"grug_mobs:poacher"}, BANDITS},
		zones = {false, false, false, false, false, false,
			"elandor_goldmead_vale", "elandor_goldmead_vale", "elandor_goldmead_vale"},
		lessons = {"A Woodsman's Edge", "A Pick for the Road",
			"Bring a wood axe and Elian will explain safe trees, shared timber and the first repair.",
			"Bring a stone pick for a short lesson before the road leaves the soft fields."},
	},
	{
		key = "elf", faction = "accord", start = "silverleaf",
		village = "starbough_village", outpost = "starbough_outpost", camp = "starbough_bandit_camp",
		names = {"Saelin Dewbough", "Ilyra Mossveil", "Theren Farstep", "Nima Fern"},
		titles = {"Roots Laid Bare", "The Grove's Portion", "Beneath the Seed Baskets",
			"Footfalls Without Breath", "Keepers of the Saplings", "Axes Without Leave",
			"Quiet the Lower Boughs", "Watch the Green Road", "Cinders in Green Cloth"},
		descriptions = {
			"Boars are rooting the youngest grove. Remove them before the exposed roots dry.",
			"The grove wastes nothing. Bring ordinary meat to be shared at the evening table.",
			"Clear pests from the seed stores: boars by day or the giant rats that emerge after dusk.",
			"Patrol the moss ring. Boars root there by day and the restless dead bend it after dusk.",
			"Foxes are worrying the sapling guards. Clear the animals from the tended ring.",
			"Secure the Silverleaf approach: poachers cut boughs by night and foxes scatter the road stores by day.",
			"More poachers hide beneath the lower boughs. Give the wardens room to restore the grove.",
			"Foxes scatter the scouts' trail signs. Clear the green road before Theren patrols it.",
			"The bandits carry green cloth burned by a hooked-sun mark. Defeat them and speak with Nima inside the camp.",
		},
		targets = {{"grug_mobs:boar"}, false, {"grug_mobs:giant_rat", "grug_mobs:boar"},
			{"grug_mobs:zombie", "grug_mobs:boar"}, {"grug_mobs:fox"}, {"grug_mobs:poacher", "grug_mobs:fox"},
			{"grug_mobs:poacher"}, {"grug_mobs:fox"}, BANDITS},
		zones = {false, false, false, false, false, false,
			"elandor_starbough_vale", "elandor_starbough_vale", "elandor_starbough_vale"},
		lessons = {"The Careful Axe", "Stone's Patient Lesson",
			"Bring a wood axe. Saelin's lesson is about choosing a tree before raising the tool.",
			"Bring a stone pick and learn why stone rewards patience rather than force."},
	},
	{
		key = "undead", faction = "throng", start = "stillgrave",
		village = "mournfen_village", outpost = "mournfen_outpost", camp = "mournfen_bandit_camp",
		names = {"Veyra Pall", "Mordec Silt", "Sera Vane", "Hollis Grey"},
		titles = {"Boars in the Dead Furrows", "Salt for What Remains",
			"Gnawing in the Crypt Stores", "The Uncalled Dead", "Furrows Gone Sour",
			"Tusks Along the Fen Road", "Mud That Moves", "Clear the Sluice",
			"Fire That the Fen Cannot Drown"},
		descriptions = {
			"Plague boars churn the old furrows into useless mire. Thin them before the retaining stones fail.",
			"Even preserved stores begin with fresh provisions. Bring ordinary meat to the salting table.",
			"Clear pests from the crypt stores: plague boars by day or giant rats after dusk.",
			"Patrol the old furrows. Plague boars churn them by day, while corpses answering no bell walk there after dusk.",
			"Another sounder has soured the outer furrows. Keep the old blight within its tended bounds.",
			"Plague boars crowd the Stillgrave end of the fen road. Clear the local approach to the fen road.",
			"Bog ooze is choking the village sluice. Break it apart before the water backs into the paths.",
			"Crocodiles have claimed the outpost channel. Clear the bank for Sera's patrol.",
			"The bandits carried cloth hot without flame, marked by a hooked sun. Defeat them and let Hollis explain what the fen could not cool.",
		},
		targets = {{"grug_mobs:plague_boar"}, false,
			{"grug_mobs:giant_rat", "grug_mobs:plague_boar"},
			{"grug_mobs:zombie", "grug_mobs:plague_boar"},
			{"grug_mobs:plague_boar"}, {"grug_mobs:plague_boar"},
			{"grug_mobs:bog_ooze"}, {"grug_mobs:crocodile"}, BANDITS},
		zones = {false, false, false, false, false, false,
			"kragmar_mournfen", "kragmar_mournfen", "kragmar_mournfen"},
		lessons = {"A Handle That Will Not Rot", "A Pick Among Headstones",
			"Bring a wood axe so Veyra can show how living handles are kept sound in dead soil.",
			"Bring a stone pick for a lesson in separating useful rock from a sealed grave."},
	},
	{
		key = "orc", faction = "throng", start = "sunscar",
		village = "redtusk_village", outpost = "redtusk_outpost", camp = "redtusk_bandit_camp",
		names = {"Gara Stonevoice", "Borak Redgrass", "Kesh Longstride",
			"Rokka Emberhand"},
		titles = {"Tusks at the Water Skins", "Meat for the Long Fire",
			"Rats Under the Hide Racks", "The Thirsting Dead", "Shells by the Bedrolls",
			"Husks on Redtusk Road", "Teeth Around the Herd", "Scour the Dry Wash",
			"No Forge Made This Brand"},
		descriptions = {
			"Boars have torn the water skins outside camp. Drive the sounder away from the racks.",
			"The long fire feeds warrior and herder alike. Bring ordinary meat for its next pot.",
			"Clear pests from the hide racks: boars by day or the giant rats that emerge after dusk.",
			"Patrol the water skins. Boars charge them by day and sun-dried husks approach after dusk.",
			"Scorpions have crawled under the bedrolls. Clear the camp edge before nightfall.",
			"Secure the Sunscar approach: sun-dried husks stalk the road at night, while plains runners trample the supply stacks by day.",
			"Hyenas circle the village herd. Thin the pack before it learns the fences.",
			"Scorpions fill the dry wash below the outpost. Clear Kesh's patrol route.",
			"The bandits branded supplies with a hooked sun no orcish forge made. Defeat them and hear Rokka's account.",
		},
		targets = {{"grug_mobs:boar"}, false, {"grug_mobs:giant_rat", "grug_mobs:boar"},
			{"grug_mobs:sun_dried_husk", "grug_mobs:boar"}, {"grug_mobs:scorpion"},
			{"grug_mobs:sun_dried_husk", "grug_mobs:plains_runner"},
			{"grug_mobs:hyena"}, {"grug_mobs:scorpion"}, BANDITS},
		zones = {false, false, false, false, false, false,
			"kragmar_redtusk_savanna", "kragmar_redtusk_savanna",
			"kragmar_redtusk_savanna"},
		lessons = {"Edge of the First Camp", "Stone Has No Pride",
			"Bring a wood axe. Gara will show the safe cut before strength becomes waste.",
			"Bring a stone pick. Stone has no pride, but it punishes a careless swing."},
	},
	{
		key = "troll", faction = "throng", start = "kapok",
		village = "raincall_village", outpost = "raincall_outpost", camp = "raincall_bandit_camp",
		names = {"Zalima Rainhum", "Daro Kapok", "Neshi Reedstep",
			"Veko Bluefeather"},
		titles = {"Boars in the Yam Beds", "Fill the Evening Pot",
			"Teeth in the Basket Weave", "Dead in the Rootways",
			"Vipers Under Broad Leaves", "Claws on Raincall Road",
			"The Coiled Footpath", "Cats at the Reed Line", "Smoke Beneath the Rain"},
		descriptions = {
			"Jungle boars are digging through the yam beds. Chase the sounder from the wet soil.",
			"The evening pot belongs to everyone who reaches it. Bring ordinary meat to fill it.",
			"Clear pests from the dry stores: jungle boars by day or giant rats after dusk.",
			"Patrol the rootways. Jungle boars dig there by day and old dead wander there after dusk.",
			"Vipers shelter beneath the broad leaves beside the homes. Clear the nearest nests.",
			"Tapirs crowd Raincall Road and scatter travellers from the narrow path. Thin the herd near Kapok.",
			"Vipers have coiled along the village footpath. Make the walk safe again.",
			"Jungle lynx watch the reed line below the outpost. Clear Neshi's patrol route.",
			"The bandits' wet cargo smoulders without being consumed and bears a hooked sun. Defeat them and speak with Veko.",
		},
		targets = {{"grug_mobs:jungle_boar"}, false,
			{"grug_mobs:giant_rat", "grug_mobs:jungle_boar"},
			{"grug_mobs:zombie", "grug_mobs:jungle_boar"}, {"grug_mobs:viper"},
			{"grug_mobs:tapir"},
			{"grug_mobs:viper"}, {"grug_mobs:jungle_lynx"}, BANDITS},
		zones = {false, false, false, false, false, false,
			"kragmar_raincall_basin", "kragmar_raincall_basin",
			"kragmar_raincall_basin"},
		lessons = {"A Dry-Handled Axe", "Stone Beneath the Moss",
			"Bring a wood axe and Zalima will show how to keep the handle dry and the cut clean.",
			"Bring a stone pick for a lesson in reading rock beneath moss and root."},
	},
}

-- Round 15 adds three independent local pairs per culture. Each pair hangs
-- from the main-story step that reaches its POI; neither local task gates the
-- other or the main chain. All targets below are members of the owning named
-- zone's closed spawn palette, except bandits, which are supplied by the
-- authored camp spawner at the same settlement.
local local_stories = {
	dwarf = {
		name = "Dagna Copperset",
		tasks = {
			{"village", "Stone for the Workyard", "The workshop needs ordinary cobble to reset its cartway after the last rockfall. Bring sound blocks from the local slopes.", item = "default:cobble", count = 8, bring = "Bring cobble"},
			{"village", "Tails Among the Tool Baskets", "Foxes slip beneath the open shelter by day and scatter the tool baskets. Clear them from the workyard.", {"grug_mobs:fox"}, 5},
			{"outpost", "The Signal Path", "After nightfall, goblin raiders use the low signal tower's blind side. Drive their pack from the lookout path.", GOBLINS, 4},
			{"outpost", "Sure Feet, Loose Stones", "Ibex crowd the shelf beside the guard shelter and send stones through its stores. Thin the herd around the post.", {"grug_mobs:ibex"}, 5},
			{"camp", "The Taken Workshop", "The ruined workshop is occupied, and its stolen tools will stay lost while the camp stands. Break the bandits around it.", BANDITS, 5},
			{"camp", "Cloth Around the Stolen Tools", "The raiders wrapped the stolen tools in their own linen. Bring some of that ordinary camp cloth so Tovin can identify the bundles.", item = "grug_mobs:linen_cloth", count = 5, bring = "Bring linen cloth"},
		},
	},
	human = {
		name = "Alda Sheaf",
		tasks = {
			{"village", "Food for the Granary Crew", "The granary crew cannot leave the open shed while carts are queued. Bring raw meat for their common pot.", item = "mobs:meat_raw", count = 4, bring = "Bring raw meat"},
			{"village", "Orchard at the Door", "Foxes are bold enough to cross the off-centre yard and worry the orchard edge. Give the pickers a clear morning.", {"grug_mobs:fox"}, 5},
			{"outpost", "Eyes Below the Tower", "After nightfall, poachers use the tower's own shadow to approach its side store. Hunt them before they learn the watch change.", {"grug_mobs:poacher"}, 4},
			{"outpost", "A Clear Eastern View", "Foxes keep tripping the warning cords across the lookout's open sightline. Clear the slope so the next alarm means danger.", {"grug_mobs:fox"}, 5},
			{"camp", "The Plundered Farm", "Bandits have turned a damaged farm into their yard. Drive them away from the patched house and its remaining stores.", BANDITS, 5},
			{"camp", "Linen Around the Grain", "The raiders tied the gathered grain with their own linen cloth. Bring enough camp cloth for Pella to mark the recovered sacks.", item = "grug_mobs:linen_cloth", count = 5, bring = "Bring linen cloth"},
		},
	},
	elf = {
		name = "Lethri Reedshade",
		tasks = {
			{"village", "Leather for the Covered Walk", "Rain has loosened the lashings above the communal walk. Bring ordinary leather so the bindings can be replaced.", item = "mobs:leather", count = 2, bring = "Bring ordinary leather"},
			{"village", "Fresh Cuts at the Saplings", "Poachers tested their axes beside the tended saplings. Find them after nightfall before the narrow houses hide another night's work.", {"grug_mobs:poacher"}, 5},
			{"outpost", "No Shadow on the Sightline", "After nightfall, poachers cross the lookout's open ground when the patrol turns. Clear the approach and restore the long view.", {"grug_mobs:poacher"}, 4},
			{"outpost", "Signs in the Ferns", "Foxes have dragged the trail signs below the elevated platform. Clear the fern line so the wardens can reset them.", {"grug_mobs:fox"}, 5},
			{"camp", "Axes at the Worksite", "Bandits shelter beside the poachers' cut trunks and sorted timber. Break their hold on the worksite.", BANDITS, 5},
			{"camp", "Bindings from the Worksite", "The cut trunks are bound with the raiders' linen cloth. Bring enough camp cloth for Nima to compare its knots with the poachers' work.", item = "grug_mobs:linen_cloth", count = 5, bring = "Bring linen cloth"},
		},
	},
	undead = {
		name = "Edris Wax",
		tasks = {
			{"village", "Gel for the Wax Store", "The wax keeper uses local slime gel to seal jars against the fen damp. Bring enough for the raised store shelves.", item = "grug_mobs:slime_gel", count = 3, bring = "Bring slime gel"},
			{"village", "Furrows by the Memorial", "Plague boars root against the stones of the tended memorial. Drive them back into the dead furrows.", {"grug_mobs:plague_boar"}, 5},
			{"outpost", "Teeth in the Watch Channel", "Crocodiles wait below the low watchhouse where the patrol must cross. Clear the channel before the water rises.", {"grug_mobs:crocodile"}, 4},
			{"outpost", "The Sheltered Niche", "Bog ooze pools beneath the observation niche and eats at its supports. Break up the nearest masses.", {"grug_mobs:bog_ooze"}, 5},
			{"camp", "Raised Stores, Living Guards", "Bandits have filled the old enclosure with raised stores that the fen cannot swallow. Remove their guards.", BANDITS, 5},
			{"camp", "Dry Cloth from a Wet Ruin", "The inner-band raiders carry linen that stayed dry inside the ruined enclosure. Bring enough for Hollis to wrap the heat-marked scrap.", item = "grug_mobs:linen_cloth", count = 5, bring = "Bring linen cloth"},
		},
	},
	orc = {
		name = "Morga Clayhand",
		tasks = {
			{"village", "Hide for the Low Annex", "The broad house's low annex needs fresh ties for its hide screens. Bring ordinary leather from the local hunt.", item = "mobs:leather", count = 2, bring = "Bring ordinary leather"},
			{"village", "Laughing Beyond the Annex", "Hyenas circle the broad house and worry the hides stacked by its low annex. Thin the pack around the village.", {"grug_mobs:hyena"}, 5},
			{"outpost", "Howls Below the Lookout", "Hyenas wait below the timber lookout and scatter anyone carrying stores uphill. Clear the post's approach.", {"grug_mobs:hyena"}, 4},
			{"outpost", "Stingers at the Palisade", "Scorpions shelter where the angled palisade meets dry ground. Clear them after sunset, when they leave the stones.", {"grug_mobs:scorpion"}, 5},
			{"camp", "Freight Beneath the Shade", "Bandits guard stolen caravan freight beneath their broad shade roof. Break their hold on the cargo.", BANDITS, 5},
			{"camp", "Bindings from the Loaded Sled", "The stolen freight is tied with the raiders' linen cloth. Bring enough of it for Rokka to compare the knots and brands.", item = "grug_mobs:linen_cloth", count = 5, bring = "Bring linen cloth"},
		},
	},
	troll = {
		name = "Amari Palmweave",
		tasks = {
			{"village", "Meat for the Preparation Roof", "The village preparation shelter has room for another shared meal. Bring raw meat from the basin hunt.", item = "mobs:meat_raw", count = 4, bring = "Bring raw meat"},
			{"village", "Hooves Between the Stilt Posts", "Tapirs push through the shade beneath the communal house. Thin the herd before the low path is blocked.", {"grug_mobs:tapir"}, 5},
			{"outpost", "A Dry Niche for Supplies", "Vipers have claimed the dry equipment niche beside the roofed lookout. Clear them after nightfall.", {"grug_mobs:viper"}, 4},
			{"outpost", "Eyes Beyond the Reeds", "Jungle lynx crouch beyond the lookout's reed line and keep the patrol under cover. Drive them away.", {"grug_mobs:jungle_lynx"}, 5},
			{"camp", "The Patched Canopy", "Bandits command the camp from a patched main canopy above their wet supplies. Break the fighters beneath it.", BANDITS, 5},
			{"camp", "Dry Bindings in the Rain", "The camp's sleeping shelters keep the raiders' linen cloth dry. Bring enough for Veko to wrap the smouldering cargo safely.", item = "grug_mobs:linen_cloth", count = 5, bring = "Bring linen cloth"},
		},
	},
}

local LOCAL_REWARDS = {
	village = {{xp = 285, copper = 40, level = 10, effort = "light"},
		{xp = 380, copper = 45, level = 10, effort = "standard"}},
	outpost = {{xp = 315, copper = 50, level = 11, effort = "light"},
		{xp = 420, copper = 55, level = 11, effort = "standard"}},
	camp = {{xp = 460, copper = 65, level = 12, effort = "standard"},
		{xp = 575, copper = 75, level = 12, effort = "hard"}},
}

local function quest_id(culture, number, title)
	local slug = title:lower():gsub("[^a-z0-9]+", "_"):gsub("^_", ""):gsub("_$", "")
	return ("r14_%s_%02d_%s"):format(culture.key, number, slug)
end

for _, culture in ipairs(cultures) do
	local npc = {
		elder = "r14_" .. culture.key .. "_elder",
		steward = "r14_" .. culture.key .. "_steward",
		scout = "r14_" .. culture.key .. "_scout",
		captive = "r14_" .. culture.key .. "_captive",
	}
	Q.register_npc(npc.elder, {settlement = culture.start, socket = "hall_quest",
		title = culture.names[1]})
	Q.register_npc(npc.steward, {settlement = culture.village,
		socket = "quest_steward", title = culture.names[2]})
	Q.register_npc(npc.scout, {settlement = culture.outpost,
		socket = "quest_scout", title = culture.names[3]})
	Q.register_npc(npc.captive, {settlement = culture.camp,
		socket = "quest_captive", title = culture.names[4]})
	local story = assert(local_stories[culture.key])
	npc.local_worker = "r15_" .. culture.key .. "_local"
	Q.register_npc(npc.local_worker, {settlement = culture.village,
		socket = "quest_local", title = story.name})

	local previous
	for number = 1, 9 do
		local id = quest_id(culture, number, culture.titles[number])
		local giver = number <= 6 and npc.elder or
			(number == 7 and npc.steward or npc.scout)
		local objective
		if number == 2 then
			objective = {type = "item", item = "mobs:meat_raw", count = COUNT[number],
				description = "Bring raw meat"}
		else
			objective = {type = "kill", mobs = culture.targets[number],
				count = COUNT[number], zone = culture.zones[number]}
		end
		Q.register_quest(id, {
			title = culture.titles[number], description = culture.descriptions[number] .. (number == 6 and "\n\nClear the local approach first. The village beyond is dangerous for beginners: reach level 10 before travelling there to seek its steward. Until then, continue hunting and preparing your equipment near home." or ""),
			npc = giver, turnin_npc = number == 6 and npc.steward or
				(number == 9 and npc.captive or giver),
			faction = culture.faction, race = culture.key, min_level = LEVEL[number],
			target_level = LEVEL[number], effort = number >= 8 and "hard" or "standard",
			prerequisites = previous and {previous} or {}, objectives = {objective},
			rewards = {xp = XP[number], copper = COPPER[number], items = {}},
		})
		previous = id
	end

	local first = quest_id(culture, 1, culture.titles[1])
	local axe = quest_id(culture, 10, culture.lessons[1])
	Q.register_quest(axe, {
		title = culture.lessons[1], description = culture.lessons[3] .. "\n\nOpen Basics in your Crafting tab to see the wood axe recipe: three planks and two sticks. You can make planks from a tree trunk and sticks from planks. Wood tools are fragile; stone lasts longer and bronze is your first durable upgrade. This lesson is optional; an axe made by a friend is welcome too.", npc = npc.elder,
		faction = culture.faction, race = culture.key, min_level = 1,
		target_level = 1, effort = "lesson",
		prerequisites = {first}, objectives = {{type = "item", item = "default:axe_wood",
			count = 1, description = "Bring a wood axe"}},
		rewards = {xp = 15, copper = 10, items = {}},
	})
	Q.register_quest(quest_id(culture, 11, culture.lessons[2]), {
		title = culture.lessons[2], description = culture.lessons[4] .. "\n\nUse Basics to make a wooden pick first, then mine stone. The stone pick recipe uses three stone blocks across the top and two sticks down the middle. Keep valuable tools repaired at a profession trainer or crafting station. This lesson is optional; a traded pick counts too.", npc = npc.elder,
		faction = culture.faction, race = culture.key, min_level = 2,
		target_level = 2, effort = "lesson",
		prerequisites = {axe}, objectives = {{type = "item", item = "default:pick_stone",
			count = 1, description = "Bring a stone pick"}},
		rewards = {xp = 45, copper = 15, items = {}},
	})

	local site_seen = {village = 0, outpost = 0, camp = 0}
	for number, task in ipairs(story.tasks) do
		local site = task[1]
		site_seen[site] = site_seen[site] + 1
		local reward = LOCAL_REWARDS[site][site_seen[site]]
		local giver = site == "village" and npc.local_worker or
			(site == "outpost" and npc.scout or npc.captive)
		local prerequisite_number = site == "village" and 6 or
			(site == "outpost" and 7 or 8)
		local objective
		if task.item then
			objective = {type = "item", item = task.item, count = task.count,
				description = task.bring}
		else
			objective = {type = "kill", mobs = task[4], count = task[5],
				zone = culture.zones[7]}
		end
		Q.register_quest(("r15_%s_local_%02d"):format(culture.key, number), {
			title = task[2], description = task[3], npc = giver,
			faction = culture.faction, race = culture.key,
			min_level = reward.level, target_level = reward.level,
			effort = reward.effort,
			prerequisites = {quest_id(culture, prerequisite_number,
				culture.titles[prerequisite_number])},
			objectives = {objective},
			rewards = {xp = reward.xp, copper = reward.copper, items = {}},
		})
	end
end
