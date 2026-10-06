-- Welcome window: a short introduction shown once per character, when it
-- first arrives in its start town (grug_classes.register_on_arrival). It has
-- no state of its own: the arrival happens exactly once, so a window closed
-- with Esc or lost to a disconnect is never shown again.
--
-- Real coordinates, 11 x 10.1. The text is two hypertext[] elements (they
-- scroll on their own if a large font overflows them); the links are the
-- Help -> About addresses plus the credits, as button_url[] (the client asks
-- before opening a browser).

local FORM = "grug_inventory:welcome"
local CREDITS_URL = "https://github.com/Kaesual/grudgelands/blob/main/CREDITS.md"

local HEADING_COLOR = "#f0c75e"
local MUTED_COLOR = "#b8b0a0"
local RULE_COLOR = "#3a3833"

local function esc(text)
	return core.formspec_escape(text)
end

-- Hypertext markup. The texts must not contain "<" or "\" outside the tags:
-- hypertext treats both as control characters.
local function colored(color, text)
	return "<style color=" .. color .. ">" .. text .. "</style>"
end

local function point(title, text)
	return colored(HEADING_COLOR, "•") .. " <b>" .. title .. "</b> " .. text
end

local BODY = table.concat({
	"Two factions, one old grudge and a wide world between them. A few things to get you started:",
	"",
	point("Explore.", "Your start town lies on the quiet edge of your continent. " ..
		"The closer you travel to the front, the more dangerous it gets."),
	point("Level up.", "Creatures, quests, mining and fishing all give experience, up to level 60."),
	point("Do quests.", "A yellow <b>!</b> above someone means they have a task for you."),
	point("Use your skills.", "Drag skills from the Skills tab onto your hotbar, " ..
		"select one and left-click."),
	point("Team up.", "Invite friends of your faction on the Party tab and adventure together."),
	"",
	colored(MUTED_COLOR, "Everything else is explained on the Help tab of your inventory (I)."),
}, "\n")

local FOOTER = colored(MUTED_COLOR, "Grudgelands is free and open source. " ..
	"Questions or feedback? Join us on Discord. Found a bug? Please report it on GitHub. " ..
	"If you want to support development, you can buy me a coffee.")

-- The link row: Help -> About's addresses by id, plus the credits. Widths
-- follow the labels; the row spans the text width (10.0).
local LINK_ROW = {
	{id = "discord", label = "Discord", w = 1.5},
	{id = "issues", label = "Report a bug", w = 2.1},
	{id = "source", label = "Source code", w = 2.0},
	{id = "credits", label = "Credits", w = 1.5, url = CREDITS_URL},
	{id = "coffee", label = "Buy me a coffee", w = 2.4},
}

local URLS = {}
for _, link in ipairs(grug_inventory.LINKS) do
	URLS[link.id] = link.url
end

local LEFT, TEXT_W = 0.5, 10.0
local LINK_GAP = 0.125

-- Everything but the player's line is fixed, so it is built once.
local function build_tail()
	local fs = {
		("hypertext[%.2f,1.55;%.2f,4.85;;%s]"):format(LEFT, TEXT_W, esc(BODY)),
		("box[%.2f,6.55;%.2f,0.03;%s]"):format(LEFT, TEXT_W, RULE_COLOR),
		("hypertext[%.2f,6.75;%.2f,1.2;;%s]"):format(LEFT, TEXT_W, esc(FOOTER)),
	}
	local x = LEFT
	for _, link in ipairs(LINK_ROW) do
		local url = link.url or URLS[link.id]
		assert(url, "[grug_inventory] welcome: no address for link " .. link.id)
		fs[#fs + 1] = ("button_url[%.2f,8.1;%.2f,0.6;grug_welcome_%s;%s;%s]"):format(
			x, link.w, link.id, esc(link.label), esc(url))
		x = x + link.w + LINK_GAP
	end
	fs[#fs + 1] = "style[grug_welcome_ok;bgcolor=#2f6a2a;font=bold]"
	fs[#fs + 1] = ("button_exit[%.2f,9.05;2.6,0.8;grug_welcome_ok;Got it]"):format(
		LEFT + TEXT_W - 2.6)
	return table.concat(fs)
end
local TAIL = build_tail()

-- "Thorvin, Dwarf Warrior of The Accord"; parts the character lacks are left
-- out (an admin may have broken the identity).
local function who(player)
	local race = grug_classes.get_race_def(player)
	local class = grug_classes.get_class_def(player)
	local faction = grug_factions.display_name(grug_factions.get_faction(player))
	local text = player:get_player_name()
	local kind = {}
	kind[#kind + 1] = race and race.name
	kind[#kind + 1] = class and class.name
	if #kind > 0 then
		text = text .. ", " .. table.concat(kind, " ")
	end
	if faction then
		text = text .. " of " .. faction
	end
	return text
end

function grug_inventory.welcome_formspec(player)
	local head = "<bigger><b>" .. colored(HEADING_COLOR, "Welcome to Grudgelands") ..
		"</b></bigger>\n" .. colored(MUTED_COLOR, who(player))
	return "formspec_version[4]size[11,10.1]" ..
		("hypertext[%.2f,0.4;%.2f,1.1;;%s]"):format(LEFT, TEXT_W, esc(head)) .. TAIL
end

grug_classes.register_on_arrival(function(player)
	core.show_formspec(player:get_player_name(), FORM,
		grug_inventory.welcome_formspec(player))
end)

-- "Got it", Esc and the link buttons: nothing to do (button_url opens its own
-- confirmation on the client).
core.register_on_player_receive_fields(function(_, formname)
	if formname == FORM then
		return true
	end
end)
