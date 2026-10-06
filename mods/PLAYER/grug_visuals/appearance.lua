--
-- The stored appearance (round39-web-data-plan.md §3; the contract is
-- docs/technical/module-guide.md "Player meta read by external tools").
--
-- What a player character looks like, as data for tools outside the game (the
-- realm website, which reads player meta and never runs game code): player
-- meta `grug_visuals:appearance`, compact JSON. apply.lua writes it whenever
-- the small key below changes, which includes the first apply after every
-- join, and only when the JSON differs from the stored value.
--
-- Pure: no ObjectRef, no inventory read. The constants and the closed texture
-- grammar at the top are plain data a tool reads without an engine (the
-- exporter in tools/web_data takes them from here, tools/r39_wm checks every
-- stored string against them); the builders below take the stacks and the
-- spec apply.lua already holds.
--

grug_visuals.APPEARANCE_META = "grug_visuals:appearance"

-- Raised on any change to the format (and documented in the contract).
grug_visuals.APPEARANCE_VERSION = 1

-- Bytes per stored texture string (body, cloak, either hand image). The worst
-- case tools/r39_wm measures -- every armour slot filled, enchanted in both
-- channels and broken, the longest look, the longest cloak and hand image --
-- is 1,382 bytes (the body; a hand image 268, a cloak 44); the cap leaves
-- about half again as much.
grug_visuals.APPEARANCE_TEXTURE_MAX = 2048

-- Bytes for the whole JSON value: four texture strings at the cap plus a fixed
-- overhead of 2,048 bytes for everything else (keys, ids, item names, the
-- look, the enchant ids). The measured upper bound -- the longest of every
-- part at once -- is 2,964 bytes, 1,002 of them outside the texture strings.
grug_visuals.APPEARANCE_JSON_OVERHEAD = 2048
grug_visuals.APPEARANCE_JSON_MAX = 4 * grug_visuals.APPEARANCE_TEXTURE_MAX +
	grug_visuals.APPEARANCE_JSON_OVERHEAD

--
-- THE CLOSED TEXTURE GRAMMAR. Every stored texture string is a `chain`:
--
--   chain    = part { "^" part }        the first part is never a modifier
--   part     = file | "(" chain ")" | "[" modifier
--   modifier = name { ":" argument }    the arguments `modifiers[name]` lists
--
-- `^` overlays the next part on what came before; `^[name:...` applies a
-- modifier to everything before it in the same chain; parentheses group, at
-- most `max_depth` deep. Nothing is ever escaped: no `\` occurs, and no file
-- name or argument contains `^ : ( ) [`. A `mask` argument is a file name; a
-- `cracko` draws the engine's crack texture, which no string names.
--
grug_visuals.APPEARANCE_TEXTURE = {
	max_depth = 4,
	escaped = false,
	-- A file is a PNG name of these characters with this suffix, and exists in
	-- one of `dirs` (paths relative to the game's root).
	file = {charset = "a-z0-9_", suffix = ".png"},
	dirs = {
		"mods/PLAYER/grug_visuals/textures",      -- skin, look, armour layers
		"mods/PLAYER/grug_achievements/textures", -- cloaks
		"mods/ITEMS/grug_gear/textures",          -- hand items and their masks
	},
	-- Engine files a modifier draws without naming them.
	engine_files = {cracko = "crack_anylength.png"},
	-- Argument kinds.
	args = {
		int = "an optional '-' and 1 to 3 decimal digits",
		color = "'#' and 6 lowercase hexadecimal digits",
		file = "a file name by the file rule",
	},
	modifiers = {
		colorize = {"color", "int"},
		cracko = {"int", "int"},
		hsl = {"int", "int", "int"},
		mask = {"file"},
		multiply = {"color"},
		opacity = {"int"},
		verticalframe = {"int", "int"},
	},
}

--
-- The hand image: what the engine's wielditem draws for a stack
-- (src/client/wieldmesh.cpp setItem, src/inventory.cpp): its wield image when
-- one is set, the stack meta's over the definition's, else its inventory image,
-- the same order. `_grug_world_wield_image` sits between the two wield images,
-- as wield_appearance (apply.lua) puts it. Enchant colours and the broken
-- look are in the stack's own image meta (grug_quality, grug_repair).
--
local function image_name(image)
	if type(image) == "table" then
		image = image.name
	end
	return type(image) == "string" and image or ""
end

function grug_visuals.hand_image(stack)
	local meta = stack:get_meta()
	local def = core.registered_items[stack:get_name()] or {}
	local image = meta:get_string("wield_image")
	if image == "" then
		image = image_name(def._grug_world_wield_image)
	end
	if image == "" then
		image = image_name(def.wield_image)
	end
	if image == "" then
		image = meta:get_string("inventory_image")
	end
	if image == "" then
		image = image_name(def.inventory_image)
	end
	return image
end

-- The enchant ids of a piece: its affixes' stat ids, prefix first
-- (grug_quality allows one per channel, never the same stat twice).
local function enchant_ids(affixes)
	local prefix, suffix = grug_visuals.affix_pair(affixes)
	local out = {}
	out[#out + 1] = prefix
	out[#out + 1] = suffix
	return out
end

local function stack_affixes(stack)
	local items = rawget(_G, "grug_items")
	return items and items.get_affixes(stack) or nil
end

-- One hand slot: S plus the pose and the drawn image; nil when empty.
local function hand_slot(stack)
	if not stack or stack:is_empty() then
		return nil
	end
	local name = stack:get_name()
	local def = core.registered_items[name]
	return {
		item = name,
		broken = grug_core.equipment_is_broken(stack),
		enchant = enchant_ids(stack_affixes(stack)),
		pose = grug_visuals.pose_for(name, core.get_item_group,
			def and def._grug_wield_pose),
		image = grug_visuals.hand_image(stack),
	}
end

local function joined(ids)
	return table.concat(ids, ",")
end

-- THE KEY: everything the stored value depends on beyond compose's own key
-- (which already covers race, look, the armour's line, tier, broken state
-- and colour layers) -- the cloak, the armour's item names and enchant ids,
-- and both hand slots. apply.lua compares it on every pass and builds the
-- JSON only when it changed. `spec` is player_spec's.
function grug_visuals.appearance_key(spec, compose_key, cloak_texture, cloak_id)
	local key = compose_key .. ";" .. tostring(cloak_texture) .. ";" ..
		tostring(cloak_id)
	local worn = spec.worn or {}
	for _, slot in ipairs(grug_visuals.SLOTS) do
		local piece = worn[slot]
		key = key .. ";" .. (piece and piece.name .. "+" ..
			joined(enchant_ids(piece.affixes)) or "-")
	end
	for _, field in ipairs({"mainhand", "offhand"}) do
		local hand = hand_slot(spec[field])
		key = key .. ";" .. (hand and hand.item .. (hand.broken and "!" or "") ..
			"+" .. joined(hand.enchant) .. "+" .. hand.image or "-")
	end
	return key
end

-- The appearance as a plain table, the JSON's shape. `result` is compose's
-- for `spec`; `cloak_texture` nil or CLOAK_NONE and `cloak_id` nil both mean
-- no cloak.
function grug_visuals.appearance(spec, result, cloak_texture, cloak_id)
	-- The race the body is drawn as (compose's fallback for none or unknown).
	local race = spec.race
	if grug_visuals.RACES[race] == nil then
		race = grug_visuals.FALLBACK_RACE
	end
	local size = grug_visuals.RACES[race].size
	local slots = {}
	local worn = spec.worn or {}
	for _, slot in ipairs(grug_visuals.SLOTS) do
		local piece = worn[slot]
		if piece then
			slots[slot] = {item = piece.name,
				broken = spec.armor_broken and spec.armor_broken[slot] == true or false,
				enchant = enchant_ids(piece.affixes)}
		end
	end
	slots.mainhand = hand_slot(spec.mainhand)
	slots.offhand = hand_slot(spec.offhand)
	if cloak_texture == nil or cloak_texture == grug_visuals.CLOAK_NONE then
		cloak_texture = "none"
	end
	return {
		v = grug_visuals.APPEARANCE_VERSION,
		race = race,
		look = grug_visuals.normalize_look(race, spec.look),
		cloak = type(cloak_id) == "string" and cloak_id ~= "" and cloak_id or "none",
		visual_size = {x = size.x, y = size.y, z = size.z},
		textures = {body = result.textures[1], cloak = cloak_texture},
		slots = slots,
	}
end

--
-- Compact JSON in the contract's key order. Hand-written for this one shape:
-- deterministic, and loadable without the engine's write_json.
--
local function json_string(text)
	return '"' .. (tostring(text):gsub('[%c"\\]', function(char)
		if char == '"' or char == "\\" then
			return "\\" .. char
		end
		return ("\\u%04x"):format(char:byte())
	end)) .. '"'
end

local function json_number(value)
	return ("%.14g"):format(value)
end

local function json_slot(entry)
	local parts = {'{"item":', json_string(entry.item), ',"broken":',
		entry.broken and "true" or "false", ',"enchant":['}
	for index, id in ipairs(entry.enchant) do
		parts[#parts + 1] = (index > 1 and "," or "") .. json_string(id)
	end
	parts[#parts + 1] = "]"
	if entry.pose then
		parts[#parts + 1] = ',"pose":' .. json_string(entry.pose) ..
			',"image":' .. json_string(entry.image)
	end
	parts[#parts + 1] = "}"
	return table.concat(parts)
end

local SLOT_ORDER = {"head", "chest", "legs", "feet", "mainhand", "offhand"}

function grug_visuals.appearance_json(data)
	local look = {}
	for index, category in ipairs(grug_visuals.LOOK_CATEGORIES) do
		look[index] = json_string(category) .. ":" .. json_number(data.look[category])
	end
	local slots = {}
	for _, slot in ipairs(SLOT_ORDER) do
		if data.slots[slot] then
			slots[#slots + 1] = json_string(slot) .. ":" .. json_slot(data.slots[slot])
		end
	end
	local size = data.visual_size
	return table.concat({
		'{"v":', json_number(data.v),
		',"race":', json_string(data.race),
		',"look":{', table.concat(look, ","), "}",
		',"cloak":', json_string(data.cloak),
		',"visual_size":{"x":', json_number(size.x), ',"y":', json_number(size.y),
		',"z":', json_number(size.z), "}",
		',"textures":{"body":', json_string(data.textures.body),
		',"cloak":', json_string(data.textures.cloak), "}",
		',"slots":{', table.concat(slots, ","), "}}",
	})
end
