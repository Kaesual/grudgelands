-- Plant tooltips (Round 48, plant-growth-plan.md §4.1): every plant item and
-- harvest says in one line how it grows or where it comes from. One pass
-- after every other description writer (grug_food appends its own lines when
-- it registers a food), idempotent like grug_materials'
-- apply_tool_level_tooltips: a description that already carries its line is
-- left alone. Returns the sorted item names it covers.
local LINES = {
	harvest = "Craft into seeds. Grows on wet farm soil in light.",
	seeds = "Plant on farm soil near water. Needs daylight or torchlight.",
	dark_harvest = "Craft into spores. Grows on wet farm soil, even in the dark.",
	spores = "Plant on farm soil near water. Grows even in the dark.",
	papyrus = "Grows on dirt, mud or sand near water. Leave the bottom stalk to regrow.",
	cactus = "Grows on sand or mesa clay. Leave the bottom piece to regrow.",
	sapling = "Needs open sky or glass to grow.",
	salt_crust = "Scraped from a salt pan or found in the wild.",
	salt_pan = "Place on any ground near water. Collects salt crust.",
	wild = "Found in the wild only.",
	herb = "Gathered in the wild by alchemists.",
}

local WILD = {"grug_gathering:wild_cocoa", "grug_gathering:rock_salt",
	"grug_gathering:sunleaf", "grug_gathering:marshbloom", "grug_gathering:stormkelp"}
local HERBS = {"grug_gathering:gravemoss", "grug_gathering:dragonweed",
	"grug_gathering:crimson_lotus"}

return function(crops)
	local line_for = {}
	for index = 1, #crops do
		local row = crops[index]
		line_for[row.harvest_item] = row.profile.dark and LINES.dark_harvest or LINES.harvest
		line_for[row.seed] = row.profile.dark and LINES.spores or LINES.seeds
	end
	line_for["default:papyrus"] = LINES.papyrus
	line_for["default:cactus"] = LINES.cactus
	line_for["grug_cooking:salt_crust"] = LINES.salt_crust
	line_for["grug_farming:salt_pan"] = LINES.salt_pan
	for _, name in ipairs(WILD) do line_for[name] = LINES.wild end
	for _, name in ipairs(HERBS) do line_for[name] = LINES.herb end
	for name in pairs(core.registered_items) do
		if core.get_item_group(name, "sapling") > 0 then line_for[name] = LINES.sapling end
	end

	local names = {}
	for name in pairs(line_for) do
		if not core.registered_items[name] then
			error("grug_farming: tooltip for a missing item " .. name, 0)
		end
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local line = line_for[name]
		local description = core.registered_items[name].description or name
		if not description:find(line, 1, true) then
			core.override_item(name, {description = description .. "\n" .. line})
		end
	end
	return names
end
