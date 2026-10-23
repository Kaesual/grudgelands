-- Basic recipe unlock (Round 47 lane CR; round47-plan.md ruling 19). A Basic
-- recipe is listed once the character has held every ingredient at least
-- once; a group ingredient counts when any member was held. The starter set
-- (sticks and every wooden tool) is known from the start. Profession areas
-- keep their tier rule (ui.lua).
--
-- The held set: player meta HELD_KEY, the format word "1", then the tokens
-- held, sorted and separated by spaces. Only tokens a Basic recipe names are
-- kept: an item entry's name, or "group:<name>" for a group entry, so the
-- set stays small however many items a character has held (at most the
-- catalog's distinct ingredient tokens; tools/r47_cr measures it). An item
-- that only becomes an ingredient in a later version counts once it is held
-- again. The key is new (the Round 37 discovery's key went with the 0.45.0
-- migration); a character without it is scanned at its join, silently: its
-- first scan, which existing characters get at their first login after the
-- update and new characters at their first join.
--
-- The scan reads every list of the player's inventory (equipment, bags,
-- the overflow and the target slot included; the engine's craft lists are
-- empty, the grid having size 0). When it runs (as Round 37's discovery did, commit c232bdea):
--   - at join (the first-login scan) and before the Crafting tab is built
--     (ui.lua, quiet: the build shows the result);
--   - in the player's slot of SLOTS x SLOT_PERIOD = 0.5 s after an
--     inventory action, a dug node or a crafted delivery (jobs.lua), and
--     every SWEEP seconds for items that arrived otherwise (pickups,
--     rewards, trades); a step visits one slot's players only, never all.
-- A scan that unlocks recipes writes one feed line: "New recipe: X", or
-- "New recipes: X and N more", and resends an open Crafting page.
--
-- The tier unlock (Round 57 ruling 6): a profession tier also unlocks,
-- recursively, every Basic recipe its recipes and station operations need
-- (Thread, then Patch Bolt). The walk (needed_basic, once per profession
-- and tier, after load): for each ingredient entry, the Basic recipes that
-- make it (its item, or any member of its group), then theirs, each once.
-- A step that turns a product back into its own ingredient is never a
-- source: a Basic recipe X <- Y is left out when another Basic recipe makes
-- Y from X (block and stairs, block and bars, sand and sandstone), so only
-- the one-way chains count. The unlocked set: player meta UNLOCKED_KEY in
-- the held set's format (the format word "1", then the sorted recipe ids,
-- space-separated); an id no recipe has any more is never shown. It grows
-- at a learn (tier 1), at a tier advance (that tier) and at the admin's
-- /prof (tiers 1..N), and at every join from each learned profession's
-- tiers 1..its tier (silent: the catch-up of characters already past a
-- tier, and of recipes a later version adds). An unlock stays when the
-- profession is unlearned. "Held once" keeps working beside it.
--
-- API:
--   grug_jobs.recipe_known(player, recipe) -> whether the list shows it
--   grug_jobs.scan_held(player[, quiet])   -> the number of recipes unlocked
--   grug_jobs.held_dirty(player)           (a scan in the player's next slot)
--   grug_jobs.needed_basic(profession, tier) -> the Basic recipe ids (a list)
--   grug_jobs.unlock_basic_tiers(player, profession, from, to[, quiet])
--                                          -> the number of recipes it added
--   grug_jobs.HELD_KEY, grug_jobs.HELD_STARTER, grug_jobs.BASIC_UNLOCKED_KEY

local HELD_KEY = "grug_jobs:held"
local UNLOCKED_KEY = "grug_jobs:basic_unlocked"
local FORMAT = "1"
local SLOTS, SLOT_PERIOD, SWEEP = 5, 0.1, 10
-- Sticks and every wooden tool (ruling 19), by output.
local STARTER = {"default:stick", "grug_materials:pick_wood", "grug_materials:axe_wood",
	"grug_materials:shovel_wood", "grug_farming:hoe"}

grug_jobs.HELD_KEY = HELD_KEY
grug_jobs.HELD_STARTER = STARTER
grug_jobs.BASIC_UNLOCKED_KEY = UNLOCKED_KEY

--
-- The index of the Basic catalog, built at its first use (after load):
-- the tokens it names, its groups, the recipes per token, the starter
-- recipes; and per item name the tokens holding it gives.
--

local index
local function catalog()
	if index then return index end
	index = {tokens = {}, groups = {}, by_token = {}, starter = {}}
	local starter_outputs = {}
	for _, name in ipairs(STARTER) do starter_outputs[name] = true end
	for _, recipe in ipairs(grug_jobs.recipes_in_area("basic")) do
		if starter_outputs[recipe.output] then index.starter[recipe.id] = true end
		for _, entry in ipairs(recipe.ingredients) do
			local token = grug_jobs.ingredient_token(entry)
			if not index.tokens[token] then
				index.tokens[token] = true
				if entry.group then index.groups[#index.groups + 1] = entry.group end
			end
			index.by_token[token] = index.by_token[token] or {}
			table.insert(index.by_token[token], recipe)
		end
	end
	table.sort(index.groups)
	return index
end

local tokens_by_name = {}
local function tokens_of(name)
	local tokens = tokens_by_name[name]
	if tokens then return tokens end
	local idx = catalog()
	tokens = {}
	if idx.tokens[name] then tokens[1] = name end
	for _, group in ipairs(idx.groups) do
		if core.get_item_group(name, group) > 0 then tokens[#tokens + 1] = "group:" .. group end
	end
	tokens_by_name[name] = tokens
	return tokens
end

--
-- The held set: read once per session, written when it grows.
--

-- A set in the format word's format (the held set, the unlocked set).
local function read_set(player, key)
	local set = {}
	local first = true
	for word in player:get_meta():get_string(key):gmatch("%S+") do
		-- The format word first; an unknown format reads as an empty set.
		if first then
			if word ~= FORMAT then break end
			first = false
		else
			set[word] = true
		end
	end
	return set
end

local function write_set(player, key, set)
	local words = {}
	for word in pairs(set) do words[#words + 1] = word end
	table.sort(words)
	table.insert(words, 1, FORMAT)
	player:get_meta():set_string(key, table.concat(words, " "))
end

local cached, unlocked_cache = {}, {}
local function load(player)
	local name = player:get_player_name()
	local held = cached[name]
	if held then return held end
	held = read_set(player, HELD_KEY)
	cached[name] = held
	return held
end

local function save(player, held)
	write_set(player, HELD_KEY, held)
end

local function load_unlocked(player)
	local name = player:get_player_name()
	local set = unlocked_cache[name]
	if set then return set end
	set = read_set(player, UNLOCKED_KEY)
	unlocked_cache[name] = set
	return set
end

local function known(held, recipe)
	for _, entry in ipairs(recipe.ingredients) do
		if not held[grug_jobs.ingredient_token(entry)] then return false end
	end
	return true
end

-- Whether the Crafting tab lists `recipe`: every recipe outside Basic (the
-- tier rule is ui.lua's), a starter recipe, a Basic recipe whose every
-- ingredient was held or that a profession tier unlocked (Round 57).
function grug_jobs.recipe_known(player, recipe)
	if recipe.area ~= "basic" then return true end
	if catalog().starter[recipe.id] then return true end
	return known(load(player), recipe) or load_unlocked(player)[recipe.id] == true
end

-- The feed line of a scan that unlocked `recipes`: the first by name.
local function unlock_line(recipes)
	local labels = {}
	for i, recipe in ipairs(recipes) do labels[i] = grug_core.item_name(recipe.output) end
	table.sort(labels)
	if #labels == 1 then return "New recipe: " .. labels[1] end
	return ("New recipes: %s and %d more"):format(labels[1], #labels - 1)
end

-- Scans every list of the player's inventory. Returns the number of
-- recipes the scan unlocked (0 for the silent first scan). `quiet`: no
-- resend of the open page (the caller builds it).
function grug_jobs.scan_held(player, quiet)
	local inv = player:get_inventory()
	if not inv then return 0 end
	local first = player:get_meta():get_string(HELD_KEY) == ""
	local held = load(player)
	local new = {}
	for _, list in pairs(inv:get_lists()) do
		for _, stack in ipairs(list) do
			local name = stack:get_name()
			if name ~= "" then
				for _, token in ipairs(tokens_of(name)) do
					if not held[token] then
						held[token] = true
						new[#new + 1] = token
					end
				end
			end
		end
	end
	if first or #new > 0 then save(player, held) end
	if first or #new == 0 then return 0 end
	local idx, unlocked, looked = catalog(), {}, {}
	for _, token in ipairs(new) do
		for _, recipe in ipairs(idx.by_token[token] or {}) do
			if not looked[recipe.id] then
				looked[recipe.id] = true
				if not idx.starter[recipe.id] and known(held, recipe) then
					unlocked[#unlocked + 1] = recipe
				end
			end
		end
	end
	if #unlocked == 0 then return 0 end
	grug_core.feed(player, "notice", unlock_line(unlocked))
	if not quiet and grug_jobs.refresh_crafting_page then
		grug_jobs.refresh_crafting_page(player)
	end
	return #unlocked
end

--
-- The tier unlock (Round 57 ruling 6; head comment).
--

-- Per item name, the Basic recipes that make it, the steps that turn a
-- product back into its own ingredient left out; built at the first use.
local makers
local function basic_makers()
	if makers then return makers end
	local basic = grug_jobs.recipes_in_area("basic")
	local inputs = {} -- output -> the item ingredients of its Basic recipes
	for _, recipe in ipairs(basic) do
		inputs[recipe.output] = inputs[recipe.output] or {}
		for _, entry in ipairs(recipe.ingredients) do
			if entry.item then inputs[recipe.output][entry.item] = true end
		end
	end
	makers = {}
	for _, recipe in ipairs(basic) do
		local back = false
		for _, entry in ipairs(recipe.ingredients) do
			if entry.item and inputs[entry.item] and inputs[entry.item][recipe.output] then
				back = true
			end
		end
		if not back then
			makers[recipe.output] = makers[recipe.output] or {}
			table.insert(makers[recipe.output], recipe)
		end
	end
	return makers
end

-- The Basic recipes that make what one ingredient entry accepts.
local group_makers = {}
local function makers_of(entry)
	local by_output = basic_makers()
	if entry.item then return by_output[entry.item] or {} end
	local list = group_makers[entry.group]
	if list then return list end
	list = {}
	local outputs = {}
	for output in pairs(by_output) do
		if core.get_item_group(output, entry.group) > 0 then outputs[#outputs + 1] = output end
	end
	table.sort(outputs)
	for _, output in ipairs(outputs) do
		for _, recipe in ipairs(by_output[output]) do list[#list + 1] = recipe end
	end
	group_makers[entry.group] = list
	return list
end

-- The ids of every Basic recipe that the recipes and station operations of
-- `profession` at exactly `tier` need, recursively, in the walk's order.
-- The list is the cache's own: never write into it.
local needed = {}
function grug_jobs.needed_basic(profession, tier)
	local key = profession .. ":" .. tier
	if needed[key] then return needed[key] end
	local list, seen = {}, {}
	local function walk(ingredients)
		for _, entry in ipairs(ingredients or {}) do
			for _, recipe in ipairs(makers_of(entry)) do
				if not seen[recipe.id] then
					seen[recipe.id] = true
					list[#list + 1] = recipe.id
					walk(recipe.ingredients)
				end
			end
		end
	end
	for _, recipe in ipairs(grug_jobs.recipes_in_area(profession)) do
		if recipe.tier == tier then walk(recipe.ingredients) end
	end
	if grug_jobs.station_operations then
		for _, op in ipairs(grug_jobs.station_operations()) do
			if op.profession == profession and op.tier == tier then
				walk(op.ingredients)
				walk(op.weapon_extra)
			end
		end
	end
	needed[key] = list
	return list
end

-- Unlocks the Basic recipes of `profession`'s tiers `from`..`to`. Returns the
-- number of recipes the set gained. Unless `quiet`, the ones the list did
-- not show before get one feed line ("New recipes: …", as the scan's) and
-- an open Crafting page is resent.
function grug_jobs.unlock_basic_tiers(player, profession, from, to, quiet)
	if not grug_jobs.PROFESSIONS[profession] then return 0 end
	local set = load_unlocked(player)
	local held, starter = load(player), catalog().starter
	local added, shown = 0, {}
	for tier = math.max(1, from), math.min(6, to) do
		for _, id in ipairs(grug_jobs.needed_basic(profession, tier)) do
			if not set[id] then
				local recipe = grug_jobs.recipe(id)
				if recipe and not starter[id] and not known(held, recipe) then
					shown[#shown + 1] = recipe
				end
				set[id] = true
				added = added + 1
			end
		end
	end
	if added == 0 then return 0 end
	write_set(player, UNLOCKED_KEY, set)
	if quiet or #shown == 0 then return added end
	grug_core.feed(player, "notice", unlock_line(shown))
	if grug_jobs.refresh_crafting_page then grug_jobs.refresh_crafting_page(player) end
	return added
end

-- The join's catch-up: every learned profession's tiers up to its tier.
local function catch_up(player)
	for profession in pairs(grug_jobs.PROFESSIONS) do
		local level = grug_jobs.profession_level(player, profession)
		if level >= 1 then grug_jobs.unlock_basic_tiers(player, profession, 1, level, true) end
	end
end

--
-- When the scan runs: SLOTS slots of SLOT_PERIOD each; a player sits in one
-- slot (assigned in turn at join) and is scanned there when dirty or when
-- SWEEP seconds have passed since its last scan.
--

local slot_of, members, dirty, visits = {}, {}, {}, {}
for slot = 1, SLOTS do members[slot] = {} end
local joined, accumulator, current = 0, 0, 0
local SWEEP_VISITS = SWEEP / (SLOTS * SLOT_PERIOD)

function grug_jobs.held_dirty(player)
	local name = player:get_player_name()
	if slot_of[name] then dirty[name] = true end
end

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	joined = joined + 1
	local slot = joined % SLOTS + 1
	slot_of[name], visits[name], dirty[name] = slot, 0, nil
	members[slot][name] = true
	-- The first-login scan. A new character's starter kit arrives later, at
	-- "Create character" (grug_factions), and is found by the next scan.
	grug_jobs.scan_held(player, true)
	catch_up(player)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	local slot = slot_of[name]
	if slot then members[slot][name] = nil end
	cached[name], slot_of[name], dirty[name], visits[name] = nil, nil, nil, nil
	unlocked_cache[name] = nil
end)

core.register_on_player_inventory_action(function(player)
	grug_jobs.held_dirty(player)
end)

core.register_on_dignode(function(_, _, digger)
	if digger and digger.is_player and digger:is_player() then grug_jobs.held_dirty(digger) end
end)

core.register_globalstep(function(dtime)
	accumulator = accumulator + dtime
	if accumulator < SLOT_PERIOD then return end
	-- A stall longer than one period collapses to a single slot.
	accumulator = accumulator - SLOT_PERIOD
	if accumulator > SLOT_PERIOD then accumulator = 0 end
	current = current % SLOTS + 1
	for name in pairs(members[current]) do
		visits[name] = visits[name] + 1
		if dirty[name] or visits[name] >= SWEEP_VISITS then
			dirty[name], visits[name] = nil, 0
			local player = core.get_player_by_name(name)
			if player then grug_jobs.scan_held(player) end
		end
	end
end)
