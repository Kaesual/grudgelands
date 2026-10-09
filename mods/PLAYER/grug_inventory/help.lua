-- Help page: a short player guide in six sub-pages, selected by buttons at
-- the top of the page. Every sub-page is static text, so each one is built
-- once at load time; opening the page only concatenates the button row. The
-- Sound sub-page adds the music and ambience controls of grug_ambience
-- (Round 34) above its text, built per player.
--
-- No inventory view (spec §3.1): the page has the whole window. Legacy
-- coordinates (see ui.lua): the button row sits at y = 0 and the text area
-- ends near the window's bottom edge. The body is a hypertext[] element,
-- which scrolls on its own when a sub-page is longer than the area. Links
-- are read-only textarea[] elements (selectable, Ctrl+C copies) with a
-- button_url[] beside them; a formspec cannot open a browser by itself, and
-- button_url only asks the player first.

local PAGE = "grug_inventory:help"
local DEFAULT_SECTION = "start"

-- The game's version has one source, the `version` line of game.conf
-- (0.<round>.<patch>, CHANGELOG.md). The engine reads no such key; a mod may
-- read the game directory (lua_api.md core.get_game_info).
local function read_game_version()
	local info = core.get_game_info()
	local version = info and info.path and
		Settings(info.path .. "/game.conf"):get("version")
	if type(version) ~= "string" or not version:match("^%d+%.%d+%.%d+$") then
		core.log("warning", "[grug_inventory] game.conf has no valid version line")
		return nil
	end
	return version
end
grug_inventory.GAME_VERSION = read_game_version()

local function esc(text)
	return core.formspec_escape(text)
end

local HEADING_COLOR = "#f0c75e"

local function heading(text)
	return "<style color=" .. HEADING_COLOR .. "><b>" .. text .. "</b></style>"
end

-- One hypertext body. Paragraphs are separated by a blank line; lines that
-- start with "• " are list items. The markup must not contain "<" or "\"
-- except in the tags above: hypertext treats both as control characters.
local function body(lines)
	return table.concat(lines, "\n")
end

local SECTIONS = {
	{id = "start", label = "Start", x = 0.0, w = 1.5, text = body({
		heading("Your first steps"),
		"• Your starter weapon is already equipped on the Character page. Open the Talents & Skills tab, drag a combat skill onto your hotbar, select it and left-click a creature to fight.",
		"• Talk to the people of your start town. A yellow ! above someone means they have a quest for you.",
		"• Craft a Wooden Pickaxe early: stone and ore need a pickaxe. Dirt, sand and other loose ground dig by hand (or with a skill selected), a shovel is fastest. The Basic area of the Crafting tab lists the tools, torches, blocks and other goods anyone can make.",
		"",
		heading("Keys"),
		"• I opens your inventory. E opens the quickbar: your mounts and boats, the potion belt and Return home; a click uses one and closes it. Z opens the map with your quest log.",
		"• E and Z are your client's Aux1 and Zoom keys. If you changed those keys in the client's settings, your own keys open the quickbar and the map.",
		"• With the client setting \"Aux1 key for climbing/descending\" on, holding E also makes you sink in water and climb down ladders.",
		"• With the client setting \"Toggle Aux1 key\" on, the quickbar opens on every second press of E.",
		"",
		heading("Levels and zones"),
		"• Creatures, quests, mining ore and gems, and fishing give XP, up to level 60. Creatures 10 or more levels below you give none; ore, gems and fish always give some. Every second level gives a talent point for the Talents & Skills tab.",
		"• Your faction lives on its own continent. Your start town lies in a level 1-10 zone on its outer side, and levels rise toward the front where the two continents meet: 11-20 home zones, the capital zones (20-30) and heartlands (21-30), 31-40 frontiers, 31-59 on the front itself and level 60 on the two dragon islands.",
		"• Zones of level 31 and above are contested by both factions.",
		"• Underground creatures get stronger with depth: 3 levels per 50 nodes below y 0 (level 60 near y -1000), and never weaker than the zone above them.",
		"",
		heading("Capitals"),
		"• Around level 10, head for your people's capital: trainers for the professions, riding, repairs and new quests. No hostile creatures roam there.",
		"• Accord: Highcourt (Humans), Dur Brannoc (Dwarves), Lethariel (Elves). Throng: Gor Drazhak (Orcs), Nhal Veyr (Undead), Kezamba (Trolls).",
		"",
		heading("Protected ground"),
		"• Nobody can dig or place blocks in capitals, start towns and the treeless strip around them (only grass and low plants grow there, so you can see where the protection ends). This applies from 100 blocks below the town up to the sky; deeper down the normal rules apply.",
		"• In the level 1-30 zones only their own faction may dig and build. Zones of level 31 and above, and everything below y -500, are open to both factions.",
	})},
	{id = "quests", label = "Quests & Professions", x = 1.5, w = 3.1, text = body({
		heading("Quests"),
		"• Symbols above quest givers: yellow ! = new quest, yellow ? = ready to hand in, silver ? = in progress, silver ! = needs a higher level. The minimap shows the same symbols; the map (Z) shows a ? only for your active quests.",
		"• Right-click a quest giver, choose a quest from the list and press Accept. When it is done, take it to the person with the yellow ? (often the giver) and press Complete.",
		"• Objectives are: bring items (counted from your inventory and bags, taken when you hand in), defeat creatures, or speak with a named person. Everyone nearby who helped with damage or healing gets kill credit; the killing blow is not needed.",
		"• Your quest log is in the map window (Z or the Map tab): up to 20 active quests, up to ten tracked on screen. Select a quest to read it and to see its targets on the map where they are known. When the log is full, finish or abandon a quest before you accept a new one.",
		"• Quest givers wait in start towns, capitals, villages and camps. At level 10 your start town sends you on to your capital.",
		"",
		heading("Professions"),
		"• Anyone can craft tools, torches, blocks and other plain goods in the Basic area of the Crafting tab. Weapons, armor, offhands, trinkets and bags come only from professions, which also enchant and upgrade gear.",
		"• Everyone knows Cooking from the start. Learn two primary professions plus Alchemy, which everyone may add. Learning is free: right-click a trainer. Unlearning a primary profession erases its progress.",
		"• Trainers: every capital has trainers for the six primary professions and Alchemy, each with a public station next to it. A learned profession gets its own area in the Crafting tab.",
		"• Weaponsmith (Forge): makes swords, daggers and battle axes; enchants and upgrades them.",
		"• Armorsmith (Forge): makes metal armor and shields; enchants and upgrades them.",
		"• Leatherworker (Tanning Rack): makes leather armor, bows and leather bags; enchants and upgrades leather armor and bows.",
		"• Tailor (Tailor Bench): makes cloth armor, spellbooks and cloth bags (from bolt bundles); enchants and upgrades cloth armor and spellbooks.",
		"• Woodcarver (Carving Bench): makes staves and wands; enchants and upgrades them.",
		"• Goldsmith (Jeweller's Bench): cuts gems; makes trinkets and settings; enchants and upgrades trinkets.",
		"• An enchant grows with the item level up to its tier's top (T1 up to item level 10 ... T6 up to 60); the tooltip names its tier. An upgrade lifts an item to its tier's top item level and keeps its enchants.",
		"• Alchemy (Brewing Stand): brews finished potions and elixirs. Only alchemists can pick healing herbs.",
		"• Cooking: meals with a five-minute buff. Simple dishes are crafted in the Crafting tab; good dishes are prepared raw there and finished in a furnace.",
		"• A profession starts at tier 1. 10, 15, 20, 25 and 30 crafts at your current tier open the next one, but your level caps it: tier 1 up to level 10, tier 2 from level 11, up to tier 6 from level 51. Every item a job makes counts, up to what the tier still needs. Only finished goods (gear, trinkets, bags, potions, dishes) and enchants count: upgrades, stations and materials such as bolts, settings or cut gems do not.",
	})},
	{id = "basics", label = "Basics", x = 4.6, w = 1.5, text = body({
		heading("Ores and depth"),
		"• Deeper stone is harder and needs a better pick; its tooltip names the pick tier. Any pick breaks the stone near the surface (down to y -100); below that you need Iron (T2) from y -101, Steel (T3) from y -301, Silversteel (T4) from y -501, Embersteel (T5) from y -701 and Abyssal Steel (T6) from y -1001.",
		"• Every ore and gem needs the pick of the layer where it first appears, at any depth: Coal found deep down still breaks with any pick.",
		"• Dirt, sand, gravel, clay, snow and mud need no pick: dig them by hand or, faster, with a shovel.",
		"• Slate, Basalt and Granite are decorative building stone: any pick breaks them and they drop themselves.",
		"• Coal, Copper, Tin, Iron and Quartz: in stone from the surface (mountains too) downward; any pick. Coal, Copper and Tin are most common above y -100, Iron between y -101 and y -300.",
		"• Gold: below y -100; Iron pick or better.",
		"• Silver: below y -300; Steel pick or better.",
		"• Emberglass: below y -500; Silversteel pick or better.",
		"• Abyssal Crystal: below y -700; Embersteel pick or better.",
		"• Gems: one kind per layer, only in that layer's stone and everywhere on the map: Citrine down to y -100 (any pick), Jade from y -101 (Iron), Garnet from y -301 (Steel), Sapphire from y -501 (Silversteel), Ruby from y -701 (Embersteel) and Diamond from y -1001 (Abyssal Steel).",
		"• A pick that is too weak cannot dig the stone or ore at all.",
		"• Better tools need a character level: Iron picks, axes and shovels from level 5, Steel from 15, Silversteel from 25, Embersteel from 35 and Abyssal Steel from 45; the tooltip shows it. Wood, stone and bronze tools need none.",
		"• Every ore or gem you dig and every fish you catch gives XP; deeper ores, gems (more than ores) and fish from higher-level waters give more.",
		"",
		heading("Smelting"),
		"• Smelt ore into bars in a Furnace. Alloys need a Dual Furnace: Bronze = Copper + Tin, Steel = Iron + Coal, Silversteel = Steel + Silver, Embersteel = Silversteel + Emberglass, Abyssal Steel = Embersteel + Abyssal Crystal.",
		"",
		heading("Crafting"),
		"• The Crafting tab has an area for Basic recipes, Cooking, each of your primary professions and Alchemy, and every area shows all its recipes. Search the list, turn its pages or tick Craftable only; ×N says how many times the items in your inventory and bags make a recipe. A profession recipe needs that profession at the recipe's tier.",
		"• Choose a recipe, set the quantity (or press Max) and press Craft now. The ingredients are taken at once and the job runs on its own, with the window closed and while you are offline too; the result waits in the four Output slots, and Take all moves it into your inventory. Stop gives the ingredients back when your inventory has room.",
		"• One job at a time. Profession recipes need their station within 4 blocks: a Forge, Tanning Rack, Tailor Bench, Carving Bench, Jeweller's Bench or Brewing Stand. These stations open no window; furnaces and dual furnaces still do.",
		"",
		heading("Skills and combat"),
		"• Skills use the items in your hand slots on the Character page, never one in the hotbar. Select a skill and left-click a target; if the skill is not ready, you strike with your weapon.",
		"• Hand slots by class: Warriors carry a weapon and a shield (only Warriors use shields), Mages and Priests a weapon and a spellbook in the Caster offhand. Scouts carry a bow in the Ranged slot for the bow skills and a sword or dagger in the Melee slot for Strike and every melee skill. Both hand items always count toward your stats.",
		"• Scouts have a quiver slot for up to 500 arrows: drag or shift-click arrows onto it, and picked-up arrows go there first. Click it to take up to 100 arrows. Shots use the quiver first, then your inventory. Arrows stack to 100.",
		"• The Talents & Skills tab keeps every unlocked skill: drag one onto your hotbar. Skills stay on the hotbar; drag one back to the list to remove it and take it again at any time.",
		"",
		heading("Bags, food and repair"),
		"• The Inventory tab holds up to four bags of 8 to 32 slots; their slots follow your inventory's as one list. New items fill your inventory and bags before the hotbar. Sort orders everything but the hotbar. Vendors sell a Small Bag; Tailors and Leatherworkers make bags of every size.",
		"• The potion belt on the Inventory tab holds four potions or elixirs; drink them from the quickbar (E).",
		"• Eat food out of combat for a five-minute buff: instant healing, regeneration and sometimes extra stats. Only one food buff is active at a time.",
		"• Gear wears out with use and stops working when broken. Every profession trainer of your faction repairs it for money, and so does @MENDER@ in every start town and capital.",
		"",
		heading("Riding, home and death"),
		"• The Riding Trainer at the stable of each capital of your faction sells riding at levels 15 and 30 (ground mounts) and 45 and 60 (flying mounts). Your mounts then wait in the quickbar: press E and click one to mount or dismount.",
		"• The Shipwright beside the Riding Trainer sells a Boat at level 15 and an Improved Boat at level 30. Use the boat from the quickbar (E) while standing or swimming in water, and again to go ashore. Any hit throws you into the water.",
		"• In every capital the Crownbinder lifts one item with a Fallen Crown and a fee: its item level rises to its tier's top + 5 and its enchants one tier, once per item. The Decor Merchant there sells decorative blocks and lights.",
		"• Set your home at an innkeeper in a start town or capital of your faction. The Character page and the quickbar (E) have Return home (every 30 minutes, not in combat).",
		"• Dying costs no items, money or XP, but ends your active buffs. You respawn at your home.",
		"• The Party & PvP tab makes a party of up to 10 players of your faction and holds the Flag me for PvP button.",
	})},
	{id = "formulas", label = "Formulas", x = 6.1, w = 1.7, text = body({
		heading("Character formulas"),
		"Your current values are on the Character page; these are the rules behind them.",
		"",
		"• Base pool = 20 + 5 x level + 0.66 x level squared (rounded).",
		"• Maximum pools use B x C x (100 + G + T + S)%, where B is the base pool, C the class factor, G the gear percentage, T the talent percentage and S the active status percentage.",
		"• Caster mana uses the neutral base pool, then adds mana percentages. Rage is always 0-100.",
		"• Strength adds Strength / 10 as flat melee damage, fractions included; the final damage is rounded down once. Scouts use Dexterity instead, for melee and bow damage alike.",
		"• Intelligence adds Intelligence / 10 as spell power, flat spell damage. Intelligence from gear also raises healing and absorbs: each 10 adds as much as it adds to a base hit (about 2.3% at level 60).",
		"• Dexterity adds 0.05 percentage point of Crit and 0.1 of Dodge per point; Crit starts at 5%.",
		"• Crit and Dodge are each capped at 30% unless a named talent temporarily raises that cap. Character shows the effective values after caps.",
		"• Crit doubles damage and healing. Dodge avoids the hit entirely.",
		"• Armor is a rating resolved against the attacker's level: damage reduction is rating / (rating + 20 + 0.5 x attacker level) for attackers up to level 60 (each level above 60 adds 8.5 more); only this final reduction is capped at 70%. The rating includes gear, statuses and talents; Unbroken multiplies it and can add its emergency bonus.",
		"• Item level is counted once, in the weapon's base damage; your character level applies the shared damage fit; there is no separate item-level multiplier.",
		"• At level 60, an item-level 70 weapon gives about 9% more effective swing damage than item level 60, while item level 50 gives about 7% less, before enchants.",
		"• Healing and absorbs are percentages of the caster's neutral base pool, raised by Intelligence from gear; without it you heal exactly the listed share.",
		"• Mana costs are percentages of the unmodified neutral base pool. Enchants and talents do not make a spell cost more.",
		"• Mana regeneration is 1 + 0.15 x level per second out of combat. The Troll multiplier applies only out of combat. In combat you regenerate the larger of one quarter of that rate and 0.25% of your maximum mana per second; Cold Focus multiplies that combat rate.",
		"• Food regeneration pauses while you are in combat; its other bonuses stay active.",
	})},
	{id = "about", label = "About", x = 7.8, w = 1.4, text = body({
		heading("About Grudgelands" .. (grug_inventory.GAME_VERSION and
			", version " .. grug_inventory.GAME_VERSION or "")),
		"Grudgelands is open source and in active development. Use Discord for questions and feedback, GitHub issues for concrete bugs.",
		"",
		"Copy a link (desktop): click into it, press Ctrl+A, then Ctrl+C. Open asks before starting your browser.",
	})},
	{id = "sound", label = "Sound", x = 9.2, w = 1.2, text = body({
		heading("Music and ambience"),
		"• Music plays only in the six capitals, each with its own pieces, one after another with short pauses. It starts when you enter a capital and fades out when you leave.",
		"• In a capital the music takes the place of the ambience; with music off you hear the capital's ambience instead.",
		"• Each piece is downloaded once, while music is on and you are in a capital; the first one may take a moment. With music off nothing is downloaded.",
		"• Ambience: the sound of the land around you by region, day and night, the sea and the caves, running water, and the forges and hearths of the settlements.",
		"• In chat: /music on, /music off or /music 50 (volume in percent; music starts at 35); /ambience works the same.",
		"• Your client's own volume setting still applies on top of these.",
	})},
}

-- Copyable links of the About sub-page, one row each.
local LINKS = {
	{id = "discord", label = "Discord: questions and feedback",
		url = "https://discord.gg/M4auM7yunk"},
	{id = "issues", label = "GitHub issues: bug reports",
		url = "https://github.com/Kaesual/grudgelands/issues"},
	{id = "source", label = "Source code (GitHub)",
		url = "https://github.com/Kaesual/grudgelands"},
	{id = "coffee", label = "Support development: buy me a coffee",
		url = "https://buymeacoffee.com/kaesual"},
}
-- The welcome window (welcome.lua) links the same addresses.
grug_inventory.LINKS = LINKS

-- Geometry (legacy coordinates, 10.4 wide; the window is 11.85 S high, ui.lua).
-- In legacy units (S = one slot spacing, imgsize = 13/15 S, padding 0.325 S)
-- a textarea/hypertext at (y, h) spans (y + 0.35) S to
-- (y + 0.35 + 0.8667 h - 0.1333) S from the form's top edge. The full body
-- below therefore ends at 11.47 S, the Sound body at 11.46 S; the lowest
-- About button ends at 7.21 S (guiFormSpecMenu.cpp parseHyperText,
-- parseTextArea, parseButton; spacing/padding/m_btn_height at :3339-3342).
local BUTTON_Y, BUTTON_H = 0.0, 0.7
local BODY_X, BODY_Y, BODY_W = 0.2, 0.85, 10.2
local BODY_H = 12.0         -- full-height sub-pages
local ABOUT_BODY_H = 2.4    -- About: text above the link rows (ends 3.15 S)
local SOUND_BODY_Y = 2.75   -- Sound: text below the two control rows
local SOUND_BODY_H = 9.8
local LINK_Y, LINK_STEP = 2.95, 0.95
local LINK_FIELD_W, LINK_BUTTON_X, LINK_BUTTON_W, LINK_H = 7.7, 8.1, 2.1, 0.65

local SECTION_BY_ID = {}
local BODIES = {}
for _, section in ipairs(SECTIONS) do
	SECTION_BY_ID[section.id] = section
	local y, height = BODY_Y, BODY_H
	if section.id == "about" then height = ABOUT_BODY_H end
	if section.id == "sound" then y, height = SOUND_BODY_Y, SOUND_BODY_H end
	local fs = {("hypertext[%.2f,%.2f;%.2f,%.2f;;%s]"):format(
		BODY_X, y, BODY_W, height, esc(section.text))}
	if section.id == "about" then
		for index, link in ipairs(LINKS) do
			local y = LINK_Y + (index - 1) * LINK_STEP
			fs[#fs + 1] = ("label[%.2f,%.2f;%s]"):format(BODY_X, y, esc(link.label))
			-- Read-only (unnamed) textarea: selectable and copyable, not sent.
			fs[#fs + 1] = ("textarea[%.2f,%.2f;%.2f,%.2f;;;%s]"):format(
				BODY_X + 0.1, y + 0.45, LINK_FIELD_W, LINK_H, esc(link.url))
			fs[#fs + 1] = ("button_url[%.2f,%.2f;%.2f,%.2f;grug_help_url_%s;Open;%s]")
				:format(LINK_BUTTON_X, y + 0.45, LINK_BUTTON_W, LINK_H, link.id,
					esc(link.url))
		end
	end
	BODIES[section.id] = table.concat(fs)
end

-- The repair NPC of the starts and capitals is named by one constant,
-- grug_jobs.MENDER_TITLE (Round 45), never spelled out here. grug_jobs
-- loads after this mod, so a body naming it carries the marker @MENDER@ and
-- gets the title at its first build once grug_jobs exists.
local MENDER_MARK = "@MENDER@"
local function body_of(id)
	local text = BODIES[id]
	if not text:find(MENDER_MARK, 1, true) then return text end
	local jobs = rawget(_G, "grug_jobs")
	if not (jobs and jobs.MENDER_TITLE) then return text end
	text = text:gsub(MENDER_MARK, (esc(jobs.MENDER_TITLE):gsub("%%", "%%%%")))
	BODIES[id] = text
	return text
end

-- The Sound sub-page's controls: grug_ambience builds them per player.
local function sound_controls(player)
	local ambience = rawget(_G, "grug_ambience")
	if not ambience then return "" end
	return ambience.settings_formspec(player, BODY_X, BODY_Y + 0.15)
end

local function help_content(player, context)
	local selected = SECTION_BY_ID[context.grug_help_section] and
		context.grug_help_section or DEFAULT_SECTION
	local fs = {}
	for _, section in ipairs(SECTIONS) do
		local field = "grug_help_" .. section.id
		fs[#fs + 1] = grug_inventory.selected_button_style(field,
			section.id == selected)
		fs[#fs + 1] = ("button[%.2f,%.2f;%.2f,%.2f;%s;%s]"):format(
			section.x, BUTTON_Y, section.w, BUTTON_H, field, esc(section.label))
	end
	if selected == "sound" then fs[#fs + 1] = sound_controls(player) end
	fs[#fs + 1] = body_of(selected)
	return table.concat(fs)
end

sfinv.register_page(PAGE, {
	title = "Help",
	get = function(self, player, context)
		return sfinv.make_formspec(player, context, help_content(player, context), false)
	end,
	on_player_receive_fields = function(self, player, context, fields)
		for _, section in ipairs(SECTIONS) do
			if fields["grug_help_" .. section.id] then
				context.grug_help_section = section.id
				sfinv.set_page(player, PAGE)
				return true
			end
		end
		local ambience = rawget(_G, "grug_ambience")
		if context.grug_help_section == "sound" and ambience and
				ambience.handle_settings_fields(player, fields) then
			sfinv.set_page(player, PAGE)
			return true
		end
	end,
})
