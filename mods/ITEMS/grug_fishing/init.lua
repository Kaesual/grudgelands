--
-- FISHING (WP13 playtest round 5, 2026-09-16).
--
-- The playtest built the rod and Round 8 adds level-band catch tables:
--
--   * "The fishing rods of anglers sit in the middle of the hand, and they are
--     sticks. VoxeLibre has a rod that looks good, we should take it into the
--     game." -- so there is a real rod item, held by its grip (the pose half
--     of that is in `grug_visuals/wield_geometry.lua`, which this mod only
--     talks to through the `fishing_rod` group).
--   * "We should plan fish too (for cooking)." -- so the raw fish the game
--     already had gets a furnace-cooked twin and a second, earnable source.
--   * Fishing remains universal. `catch.lua` selects one table from the zone
--     level at the cast position, independent of faction and water salinity.
--
-- What is deliberately NOT here: the T4 Marshbloom Chowder and T5 Salt-Crusted
-- Fish recipes and the Well Fed buff model of `items_crafting.md` §2.3. Those
-- belong to **WP10** (professions, which owns free Cooking and the six cooking
-- groups); this mod ships the plain T1 dish the furnace can already make and
-- nothing that would pre-empt that design.
--
-- The mechanic is deliberately small and entirely server-side: no bobber
-- entity, no per-frame work, no client state. Right-click water with the rod
-- and the line is out; after a few seconds the water gives something back, as
-- long as the rod is still in the hand, the angler is still there and the
-- water still is too. Right-click again and the line comes back in.
--

grug_fishing = {}

local modpath = core.get_modpath(core.get_current_modname())
dofile(modpath .. "/catch.lua")

-- The group that says "this is a fishing rod": both the mechanic below and the
-- wield pose in `grug_visuals` dispatch on it, and neither names an item.
local ROD_GROUP = "fishing_rod"

-- How far from the spot an angler may drift before the line is lost, and how
-- often a pending cast is looked at. The scan interval is also the worst-case
-- lateness of a bite, which is why it is well under a second.
local REEL_RANGE = 8
local SCAN_INTERVAL = 0.5

-- A rod lasts 64 catches. Nothing else wears it: casting is free, and only the
-- water actually giving something back spends a use. Breaking needs no code of
-- ours -- `ItemStack::addWear` CLEARS the stack when the next step would pass
-- 65535 (src/inventory.cpp:358) -- and the catch is handed over before the wear
-- is paid, so the last one still lands.
local ROD_USES = 64
local ROD_WEAR = math.floor(65535 / ROD_USES)

--
-- The items
--

-- Forward declaration only: the right-click handler is the bottom half of this
-- file, and the item definition has to name it here.
local cast_or_reel

core.register_tool("grug_fishing:rod", {
	description = "Fishing Rod",
	inventory_image = "grug_fishing_rod.png",
	-- Far enough to fish from a bank rather than from inside the pond, and the
	-- same distance the line may then be left at (`REEL_RANGE`).
	range = REEL_RANGE,
	on_place = function(itemstack, player, pointed_thing)
		return cast_or_reel(itemstack, player, pointed_thing)
	end,
	on_secondary_use = function(itemstack, player, pointed_thing)
		return cast_or_reel(itemstack, player, pointed_thing)
	end,
	-- `liquids_pointable` is the whole reason a right-click can land on water
	-- at all: `default:water_source` declares `pointable = false`, and this
	-- flag is what lets one item through (lua_api.md, "pointability priority").
	liquids_pointable = true,
	-- A rod is not a digging tool and not a weapon: empty groupcaps, no damage
	-- groups, no `grug_equip_weapon`. Without this it would inherit the hand's
	-- capabilities and double as a spade.
	tool_capabilities = {
		full_punch_interval = 1.0,
		max_drop_level = 0,
		groupcaps = {},
		damage_groups = {},
	},
	groups = {tool = 1, [ROD_GROUP] = 1},
})

local BAND_FISH = {
	{"silver_trout", "Silver Trout", 2, "#b9d9df"},
	{"mire_carp", "Mire Carp", 3, "#71947b"},
	{"frostfin", "Frostfin", 4, "#8bb9e8"},
	{"ember_eel", "Ember Eel", 5, "#d86d3f"},
	{"storm_tuna", "Storm Tuna", 6, "#7c6bc2"},
}

for index = 1, #BAND_FISH do
	local row = BAND_FISH[index]
	local name = "grug_fishing:" .. row[1]
	core.register_craftitem(name, {
		description = row[2],
		inventory_image = "grug_mobs_item_raw_fish.png^[multiply:" .. row[4],
		on_use = core.item_eat(3),
		groups = {food_fish_raw = 1},
		_grug_tier = row[3],
	})
	mobs.add_eatable(name, 3)
end

-- COOKED FISH -- the T1 dish of `items_crafting.md` §2.3's cooking ladder,
-- with the numbers of the cooked meat it sits next to (`mobs/crafts.lua`:
-- eat 8, cooktime 5) and no food buff, because the Well Fed model is WP10's.
--
-- No new art: the icon is the existing raw fish run through a warm `^[multiply`
-- the way `grug_gear`'s cloth line and `grug_gathering`'s whole catalog are
-- tinted at runtime. One PNG fewer to license, and the two fish read as the
-- same fish.
core.register_craftitem("grug_fishing:cooked_fish", {
	description = "Cooked Fish",
	inventory_image = "grug_mobs_item_raw_fish.png^[multiply:#d59a5a",
	on_use = core.item_eat(8),
	groups = {food_fish = 1},
})
mobs.add_eatable("grug_fishing:cooked_fish", 8)

--
-- The recipes
--
-- The rod is three sticks and two lengths of Spider Silk -- the game's only
-- string-class material (`grug_mobs/items.lua`, "Spider Silk", Tailor T3) --
-- in VoxeLibre's own diagonal shape, mirrored so either hand's worth of
-- muscle memory works. Neither the rod nor the cooked fish carries a
-- `_grug_sell_price`: the cooked fish mirrors `mobs:meat`, which is unpriced
-- too, and the traders' anti-loop audit only walks recipes whose OUTPUT has a
-- price, so nothing here can print money (`grug_traders/init.lua` audit 3).
--
local STRING_ITEM = "grug_mobs:spider_silk"

core.register_craft({
	output = "grug_fishing:rod",
	recipe = {
		{"", "", "default:stick"},
		{"", "default:stick", STRING_ITEM},
		{"default:stick", "", STRING_ITEM},
	},
})

core.register_craft({
	output = "grug_fishing:rod",
	recipe = {
		{"default:stick", "", ""},
		{STRING_ITEM, "default:stick", ""},
		{STRING_ITEM, "", "default:stick"},
	},
})

core.register_craft({
	type = "cooking",
	output = "grug_fishing:cooked_fish",
	recipe = "grug_mobs:raw_fish",
	cooktime = 5,
})

--
-- The mechanic
--

-- player name -> {pos, due}. At most one line per angler, by construction.
local casts = {}

-- A monotonic seconds clock. `os.time` has one-second resolution and
-- `core.get_us_time` is not available to a mod, so the globalstep's own dtime
-- is the clock, which is also exactly the timebase the bite is measured in.
local clock = 0
local scan_at = 0

-- PcgRandom, not `math.random`: AGENTS.md's rule for anything whose sequence
-- must not depend on what else called the RNG this session. Seeded from the
-- wall clock, because a bite is the one thing here that SHOULD differ between
-- two identical casts.
local rng = PcgRandom(os.time())

local function is_water(pos)
	return core.get_item_group(core.get_node(pos).name, "water") > 0
end

local function holding_rod(player)
	return core.get_item_group(player:get_wielded_item():get_name(),
		ROD_GROUP) > 0
end

local function stop(name, message)
	casts[name] = nil
	if message then
		core.chat_send_player(name, message)
	end
end

-- The bite. Every condition is re-checked here and not trusted from the cast:
-- between the cast and now the angler may have walked off, put the rod away or
-- drained the pond.
local function reel(name, cast)
	local player = core.get_player_by_name(name)
	if not player then
		casts[name] = nil
		return
	end
	if not holding_rod(player) then
		return stop(name, "You put the rod away; the line is lost.")
	end
	if vector.distance(player:get_pos(), cast.pos) > REEL_RANGE then
		return stop(name, "You have drifted too far from your line.")
	end
	if not is_water(cast.pos) then
		return stop(name, "There is no water left where your float was.")
	end
	casts[name] = nil

	local entry = grug_fishing.catch_at(grug_fishing.table_for(cast.pos),
		rng:next(0, grug_fishing.CATCH_TOTAL - 1))
	local stack = ItemStack(entry.name .. " " .. entry.count)
	local description = core.registered_items[entry.name] and
		core.registered_items[entry.name].description or entry.name
	local left = player:get_inventory():add_item("main", stack)
	if not left:is_empty() then
		-- A full pack must not swallow the catch silently.
		core.add_item(player:get_pos(), left)
	end

	-- Only a catch wears the rod, and the write goes back through
	-- `set_wielded_item` so the client sees the new wear bar.
	local wielded = player:get_wielded_item()
	wielded:add_wear(ROD_WEAR)
	player:set_wielded_item(wielded)

	core.sound_play("default_water_footstep",
		{pos = cast.pos, gain = 0.5, max_hear_distance = 12}, true)
	core.chat_send_player(name, "You land " .. description .. ".")
end

core.register_globalstep(function(dtime)
	clock = clock + dtime
	if clock < scan_at then
		return
	end
	scan_at = clock + SCAN_INTERVAL
	-- Nobody fishing: one `next` and out. Throttled the AGENTS.md way, and the
	-- table is empty on every server where nobody has cast.
	if next(casts) == nil then
		return
	end
	-- Collected first, because `reel` writes `casts`.
	local due = {}
	for name, cast in pairs(casts) do
		if clock >= cast.due then
			due[#due + 1] = name
		end
	end
	table.sort(due) -- one deterministic order per tick
	for _, name in ipairs(due) do
		local cast = casts[name]
		if cast then
			reel(name, cast)
		end
	end
end)

-- Right-click. Pointing at water casts (or reels an existing line in early);
-- pointing at anything else with a line out reels it in, which is the only
-- way to stop waiting.
function cast_or_reel(itemstack, player, pointed_thing)
	if not player or not player.is_player or not player:is_player() then
		return itemstack
	end
	local name = player:get_player_name()
	if casts[name] then
		stop(name, "You reel the line back in.")
		return itemstack
	end
	if type(pointed_thing) ~= "table" or pointed_thing.type ~= "node" then
		return itemstack
	end
	local pos = pointed_thing.under
	if not pos or not is_water(pos) then
		return itemstack
	end
	casts[name] = {
		pos = {x = pos.x, y = pos.y, z = pos.z},
		due = clock + grug_fishing.wait_for(rng:next(0,
			grug_fishing.WAIT_SPREAD)),
	}
	core.sound_play("default_water_footstep",
		{pos = pos, gain = 0.3, max_hear_distance = 8}, true)
	return itemstack
end

core.register_on_leaveplayer(function(player)
	casts[player:get_player_name()] = nil
end)

core.register_on_dieplayer(function(player)
	casts[player:get_player_name()] = nil
end)

--
-- Startup audit. The pattern the grug_traders audits established: one action
-- line when clean, an error when not. A catch-table entry nobody registered
-- would be a silent "you caught nothing" at the moment the water bites.
--
core.register_on_mods_loaded(function()
	local missing = {}
	local entries = 0
	for tier = 1, 6 do
		local catch_table = grug_fishing.CATCH_TABLES[tier]
		for _, entry in ipairs(catch_table) do
			entries = entries + 1
			if not core.registered_items[entry.name] then
				missing[#missing + 1] = entry.name
			end
		end
	end
	if #missing > 0 then
		table.sort(missing)
		core.log("error", "[grug_fishing] catch table names unregistered " ..
			"item(s) " .. table.concat(missing, ", "))
	end
	core.log("action", "[grug_fishing] tables=6 entries=" .. entries ..
		" weight=" .. grug_fishing.CATCH_TOTAL .. " bite=" ..
		grug_fishing.MIN_WAIT .. ".." .. grug_fishing.MAX_WAIT ..
		"s rod_uses=" .. ROD_USES)
end)
