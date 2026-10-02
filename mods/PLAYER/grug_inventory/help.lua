-- Help page: a short player guide in five sub-pages, selected by buttons at
-- the top of the page. Every sub-page is static text, so each one is built
-- once at load time; opening the page only concatenates the button row.
--
-- Legacy coordinates (see ui.lua): the button row sits at y = 0 and the
-- text area ends above the shared inventory boundary at y = 7.0. The body is
-- a hypertext[] element, which scrolls on its own when a sub-page is longer
-- than the area. Links are read-only textarea[] elements (selectable, Ctrl+C
-- copies) with a button_url[] beside them; a formspec cannot open a browser
-- by itself, and button_url only asks the player first.

local PAGE = "grug_inventory:help"
local DEFAULT_SECTION = "start"

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
		"• Your starter weapon is already equipped on the Character page. Open the Skills tab, drag a combat skill onto your hotbar, select it and left-click a creature to fight.",
		"• Talk to the people of your start town. A yellow ! above someone means they have a quest for you.",
		"• Craft a Wooden Pickaxe early: stone and ore need a pickaxe. Dirt, sand and other loose ground dig by hand (or with a skill selected), a shovel is fastest. The Basics book in the Crafting tab shows tools, weapons and armor you can make.",
		"",
		heading("Levels and zones"),
		"• Creatures, quests, mining ore and gems, and fishing give XP, up to level 60. Creatures 10 or more levels below you give none; ore, gems and fish always give some. Every second level gives a talent point for the Talents tab.",
		"• Your faction lives on its own continent. Your start town lies in a level 1-10 zone on its outer side, and levels rise toward the front where the two continents meet: 11-20 home zones, the capital zones (20-30) and heartlands (21-30), 31-40 frontiers, 31-59 on the front itself and level 60 on the two dragon islands.",
		"• Zones of level 31 and above are contested by both factions.",
		"• Underground creatures get stronger with depth: 3 levels per 50 nodes below y 0 (level 60 near y -1000), and never weaker than the zone above them.",
		"",
		heading("Capitals"),
		"• Around level 10, head for your people's capital: trainers for every profession, riding, repairs and new quests. No hostile creatures roam there.",
		"• Accord: Highcourt (Humans), Dur Brannoc (Dwarves), Lethariel (Elves). Throng: Gor Drazhak (Orcs), Nhal Veyr (Undead), Kezamba (Trolls).",
		"",
		heading("Protected ground"),
		"• Nobody can dig or place blocks in capitals, start towns and the bare strip around them (no trees or plants grow there, so you can see where the protection ends). This applies from 100 blocks below the town up to the sky; deeper down the normal rules apply.",
		"• In the level 1-30 zones only their own faction may dig and build. Zones of level 31 and above, and everything below y -700, are open to both factions.",
	})},
	{id = "quests", label = "Quests & Professions", x = 1.5, w = 3.1, text = body({
		heading("Quests"),
		"• Symbols above quest givers: yellow ! = new quest, yellow ? = ready to hand in, silver ? = in progress, silver ! = needs a higher level. The Map tab shows the same symbols.",
		"• Right-click a quest giver, choose a quest from the list and press Accept. When it is done, take it to the person with the yellow ? (often the giver) and press Complete.",
		"• Objectives are: bring items (counted from your inventory and bags, taken when you hand in), defeat creatures, or speak with a named person. Everyone nearby who helped with damage or healing gets kill credit; the killing blow is not needed.",
		"• The Quests tab holds up to 20 active quests and can track up to ten on screen. When the log is full, finish or abandon a quest before you accept a new one.",
		"• Quest givers wait in start towns, capitals, villages and camps. At level 10 your start town sends you on to your capital.",
		"",
		heading("Professions"),
		"• Anyone can craft the plain tools, weapons and armor of every material from the Basics book. Professions improve and enchant gear and make special goods.",
		"• Learn two primary professions plus Cooking, which everyone may add. Learning is free: right-click a trainer. Unlearning a primary profession erases its progress.",
		"• Trainers: every start town has a Cooking trainer; every capital has trainers for all eight professions, each with a public workstation next to it. Learned recipes appear in that profession's book in the Crafting tab.",
		"• Weaponsmith (Forge): enchants swords, daggers and battle axes.",
		"• Armorsmith (Forge): enchants metal armor and shields.",
		"• Leatherworker (Tanning Rack): leather bags and weapon grips; enchants leather armor.",
		"• Tailor (Tailor Bench): cloth bags and bolt bundles; enchants cloth armor.",
		"• Woodcarver (Carving Bench): enchants staves, wands and bows.",
		"• Goldsmith (Jeweller's Bench): cuts gems; makes trinkets, spellbooks and settings; enchants trinkets and spellbooks.",
		"• Alchemist: prepares potion and elixir mixtures in the crafting grid; anyone may finish a mixture at a Brewing Stand. Only Alchemists can pick healing herbs.",
		"• Cooking (grid and furnace): meals with a five-minute buff.",
		"• A profession starts at tier 1. 10, 15, 20, 25 and 30 crafts at your current tier open the next one, but your level caps it: tier 1 up to level 10, tier 2 from level 11, up to tier 6 from level 51.",
	})},
	{id = "basics", label = "Basics", x = 4.6, w = 1.5, text = body({
		heading("Ores and depth"),
		"• Deeper stone is harder and needs a better pick; its tooltip names the pick tier. Any pick breaks the stone near the surface (down to y -100); below that you need Iron (T2) from y -101, Steel (T3) from y -301, Silversteel (T4) from y -501, Embersteel (T5) from y -701 and Abyssal Steel (T6) from y -1001.",
		"• Every ore and gem needs the pick of the layer where it first appears, at any depth: Coal found deep down still breaks with any pick.",
		"• Dirt, sand, gravel, clay, snow and mud need no pick: dig them by hand or, faster, with a shovel.",
		"• Slate, Basalt and Granite are decorative building stone: any pick breaks them and they drop themselves.",
		"• Coal, Copper, Tin, Iron and Quartz: in stone from the surface (mountains too) downward; any pick. Coal, Copper and Tin are most common above y -100, Iron between y -101 and y -300.",
		"• Gold and the region's common gem (Citrine, Garnet or Jade, depending on where you dig): below y -100; Iron pick or better.",
		"• Silver: below y -300; Steel pick or better.",
		"• Emberglass and the region's rare gem (Diamond, Sapphire or Ruby): below y -500; Silversteel pick or better.",
		"• Abyssal Crystal: below y -700; Embersteel pick or better.",
		"• A pick that is too weak cannot dig the stone or ore at all.",
		"• Better tools need a character level: Iron picks, axes and shovels from level 5, Steel from 15, Silversteel from 25, Embersteel from 35 and Abyssal Steel from 45; the tooltip shows it. Wood, stone and bronze tools need none.",
		"• Every ore or gem you dig and every fish you catch gives XP; deeper ores, gems (more than ores) and fish from higher-level waters give more.",
		"",
		heading("Smelting"),
		"• Smelt ore into bars in a Furnace. Alloys need a Dual Furnace: Bronze = Copper + Tin, Steel = Iron + Coal, Silversteel = Steel + Silver, Embersteel = Silversteel + Emberglass, Abyssal Steel = Embersteel + Abyssal Crystal.",
		"",
		heading("Crafting book"),
		"• Basics shows starter recipes right away. Finding a recipe's main material reveals further recipes, even when it is carried in a bag. This only reveals recipes: crafting itself has no level requirement.",
		"",
		heading("Skills and combat"),
		"• Skills use the items in your hand slots on the Character page, never one in the hotbar. Select a skill and left-click a target; if the skill is not ready, you strike with your weapon.",
		"• Hand slots by class: Warriors carry a weapon and a shield (only Warriors use shields), Mages and Priests a weapon and a spellbook in the Caster offhand. Scouts carry a bow in the Ranged slot for the bow skills and a sword or dagger in the Melee slot for Strike and every melee skill. Both hand items always count toward your stats.",
		"• Scouts have a quiver slot for up to 500 arrows: drag or shift-click arrows onto it, and picked-up arrows go there first. Click it to take up to 100 arrows. Shots use the quiver first, then your inventory. Arrows stack to 100.",
		"• The Skills tab keeps every unlocked skill and bought mount: drag an icon into your inventory. Drop icons you do not need; you can drag them back at any time.",
		"",
		heading("Bags, food and repair"),
		"• The Bags tab holds up to four bags of 8 to 32 slots. Vendors sell a Small Bag; Tailors and Leatherworkers make bags of every size.",
		"• Eat food out of combat for a five-minute buff: instant healing, regeneration and sometimes extra stats. Only one food buff is active at a time.",
		"• Gear wears out with use and stops working when broken. Every profession trainer of your faction repairs it for money.",
		"",
		heading("Riding, home and death"),
		"• The Riding Trainer at the stable of each capital of your faction sells riding at levels 15 and 30 (ground mounts) and 45 and 60 (flying mounts). Your mount then waits in the Skills tab: use its icon to mount or dismount.",
		"• The Shipwright beside the Riding Trainer sells a Boat at level 15 and an Improved Boat at level 30. Use the boat icon while standing or swimming in water, and again to go ashore. Any hit throws you into the water.",
		"• Set your home at an innkeeper in a start town or capital of your faction. The Map tab has Return home (every 30 minutes, not in combat).",
		"• Dying costs no items, money or XP, but ends your active buffs. You respawn at your home.",
		"• The Group tab makes a party of up to 10 players of your faction.",
	})},
	{id = "formulas", label = "Formulas", x = 6.1, w = 1.7, text = body({
		heading("Character formulas"),
		"Your current values are on the Character page; these are the rules behind them.",
		"",
		"• Base pool = 20 + 5 x level + 0.66 x level squared (rounded).",
		"• Maximum pools use B x C x (100 + G + T + S)%, where B is the base pool, C the class factor, G the gear percentage, T the talent percentage and S the active status percentage.",
		"• Caster mana uses the neutral base pool, then adds mana percentages. Rage is always 0-100.",
		"• Strength adds floor(Strength / 10) as flat melee damage. Scouts use Dexterity instead, for melee and bow damage alike.",
		"• Intelligence adds floor(Intelligence / 10) as spell power: flat spell damage and a percentage bonus to healing and absorbs.",
		"• Dexterity adds 0.1 percentage point each of Crit and Dodge per point; Crit starts at 5%.",
		"• Crit and Dodge are each capped at 30% unless a named talent temporarily raises that cap. Character shows the effective values after caps.",
		"• Crit multiplies damage by 1.5. Dodge avoids the hit entirely.",
		"• Armor is a rating resolved against the attacker's level: damage reduction is rating / (rating + 20 + 0.5 x attacker level) for attackers up to level 60 (each level above 60 adds 8.5 more); only this final reduction is capped at 70%. The rating includes gear, statuses and talents; Unbroken multiplies it and can add its emergency bonus.",
		"• Item level is counted once, in the weapon's base damage; your character level applies the shared damage fit; there is no separate item-level multiplier.",
		"• At level 60, an item-level 70 weapon gives about 9% more effective swing damage than item level 60, while item level 50 gives about 7% less, before enchants.",
		"• Healing and absorbs are percentages of the caster's neutral base pool; spell power is a percentage bonus.",
		"• Mana costs are percentages of the unmodified neutral base pool. Enchants and talents do not make a spell cost more.",
		"• Mana regeneration is 1 + 0.15 x level per second out of combat. The Troll multiplier applies only out of combat. In combat you regenerate the larger of one quarter of that rate and 0.25% of your maximum mana per second; Cold Focus multiplies that combat rate.",
		"• Food regeneration pauses while you are in combat; its other bonuses stay active.",
	})},
	{id = "about", label = "About & Feedback", x = 7.8, w = 2.6, text = body({
		heading("About Grudgelands"),
		"Grudgelands is open source and in active development. Use Discord for questions and feedback, GitHub issues for concrete bugs.",
		"",
		"Copy a link (desktop): click into it, press Ctrl+A, then Ctrl+C. Open asks before starting your browser.",
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

-- Geometry (legacy coordinates, 10.4 wide; content must end before y = 7.0).
-- In legacy units (S = one slot spacing, imgsize = 13/15 S, padding 0.325 S)
-- a textarea/hypertext at (y, h) spans (y + 0.35) S to
-- (y + 0.35 + 0.8667 h - 0.1333) S from the form's top edge, and an element
-- at y = 7.0 starts at 7.325 S. The body below therefore ends at 6.96 S; the
-- lowest About button ends at 7.21 S (guiFormSpecMenu.cpp parseHyperText,
-- parseTextArea, parseButton; spacing/padding/m_btn_height at :3339-3342).
local BUTTON_Y, BUTTON_H = 0.0, 0.7
local BODY_X, BODY_Y, BODY_W = 0.2, 0.85, 10.2
local BODY_H = 6.8          -- full-height sub-pages
local ABOUT_BODY_H = 2.4    -- About: text above the link rows (ends 3.15 S)
local LINK_Y, LINK_STEP = 2.95, 0.95
local LINK_FIELD_W, LINK_BUTTON_X, LINK_BUTTON_W, LINK_H = 7.7, 8.1, 2.1, 0.65

local SECTION_BY_ID = {}
local BODIES = {}
for _, section in ipairs(SECTIONS) do
	SECTION_BY_ID[section.id] = section
	local height = section.id == "about" and ABOUT_BODY_H or BODY_H
	local fs = {("hypertext[%.2f,%.2f;%.2f,%.2f;;%s]"):format(
		BODY_X, BODY_Y, BODY_W, height, esc(section.text))}
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

local function help_content(context)
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
	fs[#fs + 1] = BODIES[selected]
	return table.concat(fs)
end

sfinv.register_page(PAGE, {
	title = "Help",
	get = function(self, player, context)
		return sfinv.make_formspec(player, context, help_content(context), true)
	end,
	on_player_receive_fields = function(self, player, context, fields)
		for _, section in ipairs(SECTIONS) do
			if fields["grug_help_" .. section.id] then
				context.grug_help_section = section.id
				sfinv.set_page(player, PAGE)
				return true
			end
		end
	end,
})
