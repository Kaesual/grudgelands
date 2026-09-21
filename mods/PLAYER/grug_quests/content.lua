-- Round 14 V1 overworld quest catalog. The Nether is reserved for expansion one.

local Q = grug_quests

local XP = {150, 300, 550, 900, 1500, 3000, 2200, 2800, 3400}
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
			"Patrol the water skins. Boars charge them by day and the thirsty dead approach after dusk.",
			"Scorpions have crawled under the bedrolls. Clear the camp edge before nightfall.",
			"Secure the Sunscar approach: sun-dried husks stalk the road at night, while plains runners trample the supply stacks by day.",
			"Hyenas circle the village herd. Thin the pack before it learns the fences.",
			"Scorpions fill the dry wash below the outpost. Clear Kesh's patrol route.",
			"The bandits branded supplies with a hooked sun no orcish forge made. Defeat them and hear Rokka's account.",
		},
		targets = {{"grug_mobs:boar"}, false, {"grug_mobs:giant_rat", "grug_mobs:boar"},
			{"grug_mobs:zombie", "grug_mobs:boar"}, {"grug_mobs:scorpion"},
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
			"Jungle lynx stalk Raincall Road. Thin them near Kapok before they take more travellers.",
			"Vipers have coiled along the village footpath. Make the walk safe again.",
			"Jungle lynx watch the reed line below the outpost. Clear Neshi's patrol route.",
			"The bandits' wet cargo smoulders without being consumed and bears a hooked sun. Defeat them and speak with Veko.",
		},
		targets = {{"grug_mobs:jungle_boar"}, false,
			{"grug_mobs:giant_rat", "grug_mobs:jungle_boar"},
			{"grug_mobs:zombie", "grug_mobs:jungle_boar"}, {"grug_mobs:viper"},
			{"grug_mobs:jungle_lynx"},
			{"grug_mobs:viper"}, {"grug_mobs:jungle_lynx"}, BANDITS},
		zones = {false, false, false, false, false, false,
			"kragmar_raincall_basin", "kragmar_raincall_basin",
			"kragmar_raincall_basin"},
		lessons = {"A Dry-Handled Axe", "Stone Beneath the Moss",
			"Bring a wood axe and Zalima will show how to keep the handle dry and the cut clean.",
			"Bring a stone pick for a lesson in reading rock beneath moss and root."},
	},
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
			npc = giver, turnin_npc = number == 9 and npc.captive or giver,
			faction = culture.faction, race = culture.key, min_level = LEVEL[number],
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
		prerequisites = {first}, objectives = {{type = "item", item = "default:axe_wood",
			count = 1, description = "Bring a wood axe"}},
		rewards = {xp = 150, copper = 10, items = {}},
	})
	Q.register_quest(quest_id(culture, 11, culture.lessons[2]), {
		title = culture.lessons[2], description = culture.lessons[4] .. "\n\nUse Basics to make a wooden pick first, then mine stone. The stone pick recipe uses three stone blocks across the top and two sticks down the middle. Keep valuable tools repaired at a profession trainer or crafting station. This lesson is optional; a traded pick counts too.", npc = npc.elder,
		faction = culture.faction, race = culture.key, min_level = 2,
		prerequisites = {axe}, objectives = {{type = "item", item = "default:pick_stone",
			count = 1, description = "Bring a stone pick"}},
		rewards = {xp = 250, copper = 15, items = {}},
	})
end
