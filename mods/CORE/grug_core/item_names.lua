-- Player-facing item names for running text (quest objectives, rewards,
-- dialogue, the quest tracker). An item's description is its whole tooltip:
-- the name on the first line, then stat lines that other mods append once all
-- items are registered ("Restores 5 HP instantly.", "Usable by: ...",
-- "Durability: ...", "Requires level 4"). Running text shows only the name.
-- Item tooltips themselves stay untouched.

-- Visible text of a string that may carry engine escapes: translation markup
-- ("\27(T@mobs)Raw Meat\27E", argument "\27F...\27E") resolves to the game's
-- English text, colour escapes ("\27(c@#fff)", "\27(b@...)") are dropped.
-- Translation comes first, so a later line cut never lands inside an escape.
function grug_core.plain_text(text)
	text = tostring(text or "")
	if core.get_translated_string then
		local translated = core.get_translated_string("en", text)
		if type(translated) == "string" then text = translated end
	end
	-- Whatever escape the engine kept (colours) or, without the engine
	-- resolver, the translation markup itself.
	text = text:gsub("\27%([^)]*%)", ""):gsub("\27.?", "")
	return text
end

local function first_line(text)
	if type(text) ~= "string" or text == "" then return nil end
	local line = grug_core.plain_text(text):match("^[^\n]*"):match("^%s*(.-)%s*$")
	if line == "" then return nil end
	return line
end

-- The name of `item` (an item name, an item string or an ItemStack): its
-- short_description, else the first line of its description, else the
-- registered item name itself. Always one line of plain text.
function grug_core.item_name(item)
	local name = item
	if type(item) ~= "string" then
		name = item and item.get_name and item:get_name() or ""
	end
	name = name:match("^%S*")
	local def = core.registered_items[name]
	if not def and core.registered_aliases then
		local target = core.registered_aliases[name]
		def = target and core.registered_items[target]
	end
	return def and (first_line(def.short_description) or first_line(def.description))
		or (name ~= "" and name or "Unknown item")
end
