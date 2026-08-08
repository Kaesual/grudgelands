-- The new ore nodes and their raw items (items_crafting.md §3.0.1).
--
-- BINDING RULE, and the reason every `level` below looks "too low":
--
--   An ore node carries the `level` of the BAND IT SITS IN, never the level
--   of its own material tier.
--
-- Silver is the T4 lead metal but its vein sits in the T3 band, so it is a
-- level-2 node. Giving it level 3 would demand a T4 pickaxe -- which is made
-- of silversteel, which needs silver: a hard deadlock. The rule also closes
-- the cave leak from the other side: an ore is exactly as hard as the rock
-- around it, so a natural cavern at −600 does not hand out free silver to a
-- player who could never have dug down to it. Corollary (see overrides.lua):
-- an ore may never carry a HIGHER level than its stratum either.
--
-- Backgrounds stay `default_stone.png` even though after the stratum
-- conversion these veins actually sit in slate/basalt/granite. That is
-- deliberate: the pale vein reads clearly against the dark wall it is
-- embedded in -- a vein reads by its overlay, not by its backdrop. There is
-- also nothing to match it to: every mineral ore in the game, ours and
-- default's alike, is registered with `wherein = "default:stone"` and carries
-- the one stone background, so a per-stratum ore variant would mean five
-- extra node registrations per ore for a backdrop nobody looks at.
--
-- Tiles are engine texture modifiers over vendored minetest_game art -- no
-- new PNG is shipped (LICENSE-media.md). The parenthesised grouping applies
-- `[colorize:` to the overlay ONLY, not to the stone behind it.

-- NB deliberately NOT called `register_ore`: `core.register_ore` is the mapgen
-- placement call and lives in grug_mapgen/ores.lua. This one only registers the
-- node an ore vein is made of; nothing here decides where it spawns.
local function register_ore_node(name, description, tiles, groups, drop)
	core.register_node("grug_materials:" .. name, {
		description = description,
		tiles = {tiles},
		groups = groups,
		drop = "grug_materials:" .. drop,
		is_ground_content = true,
		sounds = default.node_sound_stone_defaults(),
	})
end

-- Quartz -- T2 gem, common, sits in the slate band (level 1).
register_ore_node("stone_with_quartz", "Quartz Ore",
	"default_stone.png^(default_mineral_diamond.png^[colorize:#eaf6ff:120)",
	{cracky = 2, level = 1}, "quartz_crystal")

-- Silver -- T4 lead metal, vein in the basalt band (level 2). See the rule
-- above: this is the deadlock breaker, not an oversight.
register_ore_node("stone_with_silver", "Silver Ore",
	"default_stone.png^(default_mineral_iron.png^[colorize:#e8edf2:200)",
	{cracky = 2, level = 2}, "silver_lump")

-- Garnet -- T4 gem, granite band (level 3).
register_ore_node("stone_with_garnet", "Garnet Ore",
	"default_stone.png^(default_mineral_diamond.png^[colorize:#9e1526:210)",
	{cracky = 2, level = 3}, "garnet_crystal")

-- Abyssal Crystal -- the T6 material, abyssal rock band (level 5).
--
-- INTERFACE NOTE: this node is placed by NO `register_ore` call, anywhere.
-- Decided 2026-08-08: items_crafting.md §3.0.2 makes Grudgesteel bindingly
-- dependent on the housing-isle depth step, so the crystal must not be
-- scatterable on the continent. Its two placers are:
--   * WP24 -- treasure cluster of the purchased isle depth step (world.md §5.4)
--   * WP23 -- 10 % apex dragon hoard (items_crafting.md §10 P5)
-- It is registered here so both work packages have something to place, and so
-- that the item exists before either of them lands.
register_ore_node("abyssal_crystal_ore", "Abyssal Crystal Ore",
	"default_stone.png^(default_mineral_diamond.png^[colorize:#3a1f6e:210)",
	{cracky = 1, level = 5}, "abyssal_crystal")

--
-- The raw items
--
-- `_grug_sell_price` is the trader buy price in COPPER (economy.md §1).
--
-- THE BAND IS BINDING: items_crafting.md §8.1 says "herbs/materials sold to
-- vendors: 1-6c each, scaling with material tier". Every value here lives
-- inside 1..6 -- these are raw materials, not gear, and the tier shows as a
-- position in that band, never as a bigger number.
--
-- Two fixed points inside the band, both pre-existing:
--   * `default:iron_lump` = 3c, the anchor (mods/ENTITIES/grug_traders).
--   * `default:diamond`   = 3c, capped there ON PURPOSE so the vendor floor
--     can never out-pay using a diamond (same file). Diamond is the T6 gem,
--     so no lower-tier gem may be priced above it.
--
-- Hence the ordering: quartz 2c (common T2 gem, below the iron anchor) <
-- garnet 3c = diamond 3c (both gems; diamond's 3c is the existing anti-loop
-- cap and garnet may only reach it, not pass it) < silver 4c (a T4 metal
-- lump, one step above the iron-lump anchor) < abyssal crystal 6c (the band
-- ceiling, the one material with no continental deposit at all).
--
-- None of them has a recipe yet (smelting is WP26, cutting is WP10), so no
-- vendor loop can exist around these prices today -- when the recipes land,
-- grug_traders' audit 3 re-proves that on every start.
local function register_raw(name, description, image, price)
	core.register_craftitem("grug_materials:" .. name, {
		description = description,
		inventory_image = image,
		_grug_sell_price = price,
	})
end

register_raw("quartz_crystal", "Quartz Crystal",
	"default_diamond.png^[colorize:#eaf6ff:120", 2)
register_raw("silver_lump", "Silver Lump",
	"default_iron_lump.png^[colorize:#e8edf2:200", 4)
register_raw("garnet_crystal", "Garnet Crystal",
	"default_diamond.png^[colorize:#9e1526:210", 3)
register_raw("abyssal_crystal", "Abyssal Crystal",
	"default_diamond.png^[colorize:#3a1f6e:210", 6)
