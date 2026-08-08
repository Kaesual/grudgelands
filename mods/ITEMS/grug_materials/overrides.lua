-- Re-parameterisation of the vendored `default` mod (items_crafting.md
-- §3.0.1/§3.0.4).
--
-- Everything here goes through `core.override_item` on purpose: VENDOR.md
-- says wrapper before in-place patch, so mods/BASE/default stays byte-for-byte
-- upstream and this file is the single place a future default update has to
-- be re-checked against.
--
-- GOTCHA that shapes every block below: `core.override_item` REPLACES a named
-- field wholesale -- it does not merge. Handing it `groups = {level = 3}`
-- would drop `cracky` and make the node undiggable, and handing it a partial
-- `tool_capabilities` would delete the dig times. So every override restates
-- the CURRENT upstream value verbatim (read out of mods/BASE/default/nodes.lua
-- and tools.lua) with exactly one field changed. If default is ever updated,
-- diff those two files against the values quoted in the comments here.

--
-- 1. Mese is Emberstone now
--
-- §3.0.1: the mese TOOL tier is retired, the mese ORE node is repurposed as
-- Emberstone, the glowing T5 crystal. The vendored texture already reads that
-- way, so this is a rename plus one group -- no new art, no new item.
--

-- upstream: groups = {cracky = 1}, drop = "default:mese_crystal"
-- `level = 3` = the granite band (T4). Per the ore rule in ores.lua the vein
-- is as hard as the rock it sits in, not as hard as the metal it yields.
core.override_item("default:stone_with_mese", {
	description = "Emberstone Ore",
	groups = {cracky = 1, level = 3},
})

-- upstream: groups = {cracky = 1}
-- `level = 5` = the abyssal band (T6). Diamond stays a gem, never a tool
-- metal (§3.0.1), but it is an endgame gem and lives behind the last gate.
core.override_item("default:stone_with_diamond", {
	groups = {cracky = 1, level = 5},
})

-- Pure renames for coherence -- description only, nothing else touched, so
-- the recipes and the light_source of these three stay exactly as default
-- registered them. (`default:mese` already carries level 2 upstream; we do
-- not restate its groups here precisely because we are not changing them.)
core.override_item("default:mese_crystal", {description = "Emberstone Crystal"})
core.override_item("default:mese_crystal_fragment", {description = "Emberstone Shard"})
core.override_item("default:mese", {description = "Emberstone Block"})

-- The six vendored LIGHT SOURCES go with them: every one is crafted from
-- Emberstone crystal (mods/BASE/default/crafting.lua), so a "Mese Lamp" sitting
-- next to an "Emberstone Crystal" in the same recipe is a visible break in the
-- rename. Description only again -- `light_source`, `tiles`, `groups` and the
-- recipes stay exactly as default registered them. All six itemstrings verified
-- against mods/BASE/default/nodes.lua (:2852 and :2864-2892); the five posts go
-- through `default.register_mesepost`, which registers exactly ONE node per call
-- (functions.lua:503) plus a craft recipe -- no second variant under another
-- name to chase.
core.override_item("default:meselamp", {description = "Emberstone Lamp"})
core.override_item("default:mese_post_light", {description = "Apple Wood Emberstone Post Light"})
core.override_item("default:mese_post_light_acacia_wood", {description = "Acacia Wood Emberstone Post Light"})
core.override_item("default:mese_post_light_junglewood", {description = "Jungle Wood Emberstone Post Light"})
core.override_item("default:mese_post_light_pine_wood", {description = "Pine Wood Emberstone Post Light"})
core.override_item("default:mese_post_light_aspen_wood", {description = "Aspen Wood Emberstone Post Light"})

-- NOT renamed, on purpose: the four mese TOOLS (default:pick_mese,
-- default:shovel_mese, default:axe_mese, default:sword_mese). §3.0.1 retires
-- the mese tool tier outright and WP28 deletes all four, so renaming them would
-- only be churn on items that are on their way out. (The mese pickaxe still
-- gets a `maxlevel` bump in section 3 -- as a temporary test bridge, not as a
-- game item.)

-- NOT given a `level`, on purpose: default:stone_with_copper, _tin, _coal,
-- _gold, _iron. They are not gate-relevant -- copper/tin/coal/iron are T1
-- materials that must stay reachable with the starter pickaxe, and gold is
-- jewellery metal (§3.0.1), not a tool metal at all. The rock around them is
-- their gate and that is enough. Stating it as a rule: an ore node must NEVER
-- carry a higher level than the stratum it is embedded in, or it becomes
-- undiggable at the very depth it spawns.

--
-- 2. `default:stone` is the T1 stratum and must say so
--
-- §3.0.4 authors the dispatch group as "`grug_stratum = <tier>` on EVERY
-- stratum". Five of the six are registered in init.lua and carry it; the
-- sixth is `default:stone`, which we keep as the T1 rock precisely because it
-- is already the mapgen filler, the cobble source and the `wherein` of every
-- ore. Without this override `group:grug_stratum` would be a predicate for
-- "T2..T6 rock" while the doc calls it "is stratum rock" -- and the next
-- consumer (WP24's isle generator, WP16's claims) would copy the line out of
-- the doc and silently lose T1.
--
-- With it, `group:grug_stratum` IS a complete "is this the depth-gated rock
-- of some tier" predicate, and a caller can read the tier straight off the
-- group value (1..6) instead of re-deriving it from y.
--
-- Consequence for the four underground mob spawn rows (grug_mobs spider,
-- zombie, stone golem, mesa golem): their `nodes = {"default:stone",
-- "group:grug_stratum"}` now names default:stone twice. Redundant but
-- harmless -- mobs_redo resolves the list to a content-id set -- and it is
-- left alone on purpose, because the explicit name documents the T1 band and
-- survives even if this override is ever dropped.
--
-- upstream (mods/BASE/default/nodes.lua): groups = {cracky = 3, stone = 1}
-- Both restated: override_item REPLACES `groups`, it does not merge, and
-- `stone = 1` is what default's own furnace and stone-tool recipes take.
-- `level` stays absent -- T1 is level 0, i.e. no gate at all. Nothing else of
-- the node is named here, so `drop`, `sounds` and `legacy_mineral` keep their
-- upstream values untouched.
core.override_item("default:stone", {
	groups = {cracky = 3, stone = 1, grug_stratum = 1},
})

--
-- 3. The pickaxe maxlevel ladder
--
-- Six `level` steps need six `maxlevel` thresholds; default ships three
-- (1/1/2/2/3/3). Only `cracky` is touched and only on the PICKAXES: strata
-- are a cracky-only material, so shovels, axes and swords keep their vendored
-- capabilities untouched.
--
-- READ THIS BEFORE TOUCHING ANY NUMBER BELOW. `maxlevel` is not only the
-- diggability gate; the engine feeds `leveldiff = maxlevel - node level` into
-- three formulas at once (src/tool.cpp:394-414 of the reference checkout):
--
--     leveldiff < 0            -> not diggable at all
--     leveldiff > 1            -> time = time / leveldiff
--     real_uses = min(uses * 3^leveldiff, 65535)
--
-- So lowering a `maxlevel` silently shreds durability and dig speed against
-- everything the tool can still dig. WP25 re-parameterises the GATE; it is
-- not a nerf of the starter tools. Every lowered pick below therefore gets
-- `uses` and `times` compensated so that its EFFECTIVE values against
-- ordinary level-0 rock (`default:stone`, `cracky = 3`) are exactly what they
-- were before WP25. The per-tool comments show the arithmetic.
--
-- SIDE EFFECT, consciously accepted: the bronze pickaxe drops from maxlevel 2
-- to 0 and therefore stops breaking default's level-2 nodes -- obsidian (plus
-- obsidian brick and obsidian block), the steel/copper/tin/bronze blocks and
-- the mese block. Nothing else in default is gated: default has no level-1
-- node at all, and its one level-3 node, `default:diamondblock`, was already
-- out of bronze's reach at the upstream maxlevel 2. That follows from §3.0.1,
-- where bronze IS the T1 metal; the steel pickaxe (maxlevel 2, left alone)
-- still breaks every one of them.
--
-- TEST BRIDGE, temporary: the mese and diamond pickaxes are unreachable in
-- normal play -- their ores now sit behind the very gate those tools would
-- open -- and WP28 deletes both tool tiers outright (§3.0.3). Their maxlevel
-- 4/5 exist for exactly one reason: so a runtime tester can `/giveme` one and
-- open the T5 and T6 strata at all. This is not a balance statement.
--
-- THE GAP: T2 (level 1) has no tool of its own today, because the iron
-- pickaxe only arrives with WP26/WP29. What that leaves is a ladder walkable
-- DOWN TO -500 with today's item set: the steel pickaxe (maxlevel 2) covers
-- T2 and T3, and iron ore sits in the T1 band, so a stone pickaxe can mine
-- the iron that becomes that steel. T4-T6 (below -500) are NOT open to any
-- craftable tool today -- WP26/WP29 open them with the silversteel/
-- embersteel/grudgesteel picks; until then the only keys are the two test
-- bridges below.
--

-- upstream: full_punch_interval 1.2, max_drop_level 0,
--           cracky {times={[3]=1.60}, uses=10, maxlevel=1}, fleshy 2
-- T1 floor.
--
-- COMPENSATION vs. level-0 rock (uses 10 -> 30, times unchanged):
--   before  leveldiff = 1-0 = 1 -> real_uses = 10 * 3^1 = 30 blocks
--                                 time  = 1.60 s (no division, leveldiff <= 1)
--   after   leveldiff = 0-0 = 0 -> real_uses = 30 * 3^0 = 30 blocks
--                                 time  = 1.60 s
core.override_item("default:pick_wood", {
	tool_capabilities = {
		full_punch_interval = 1.2,
		max_drop_level = 0,
		groupcaps = {
			cracky = {times = {[3] = 1.60}, uses = 30, maxlevel = 0},
		},
		damage_groups = {fleshy = 2},
	},
})

-- upstream: full_punch_interval 1.3, max_drop_level 0,
--           cracky {times={[2]=2.0, [3]=1.00}, uses=20, maxlevel=1}, fleshy 3
-- T1 floor.
--
-- COMPENSATION vs. level-0 rock (uses 20 -> 60, times unchanged):
--   before  leveldiff = 1 -> real_uses = 20 * 3^1 = 60 blocks, time = 1.00 s
--   after   leveldiff = 0 -> real_uses = 60 * 3^0 = 60 blocks, time = 1.00 s
core.override_item("default:pick_stone", {
	tool_capabilities = {
		full_punch_interval = 1.3,
		max_drop_level = 0,
		groupcaps = {
			cracky = {times = {[2] = 2.0, [3] = 1.00}, uses = 60, maxlevel = 0},
		},
		damage_groups = {fleshy = 3},
	},
})

-- upstream: full_punch_interval 1.0, max_drop_level 1,
--           cracky {times={[1]=4.50, [2]=1.80, [3]=0.90}, uses=20, maxlevel=2}, fleshy 4
-- Bronze IS T1 (§3.0.1) -- it is the best of the three starter picks, not a
-- step above them, so it lands on the same level-0 rung.
--
-- COMPENSATION vs. level-0 rock (uses 20 -> 180, ALL THREE times halved):
--   before  leveldiff = 2-0 = 2 -> real_uses = 20 * 3^2 = 180 blocks
--                                  time = 0.90 / 2 = 0.45 s   (cracky 3)
--                                  time = 1.80 / 2 = 0.90 s   (cracky 2)
--                                  time = 4.50 / 2 = 2.25 s   (cracky 1)
--   after   leveldiff = 0      -> real_uses = 180 * 3^0 = 180 blocks
--                                  no time division, so the halved literals
--                                  ARE the effective times: 0.45/0.90/2.25 s
-- This is the pick that made the defect visible: uncompensated it ended up at
-- 20 blocks and 0.90 s, i.e. exactly as durable as the 10c stone pick while
-- costing 40c (§8.2).
core.override_item("default:pick_bronze", {
	tool_capabilities = {
		full_punch_interval = 1.0,
		max_drop_level = 1,
		groupcaps = {
			cracky = {times = {[1] = 2.25, [2] = 0.90, [3] = 0.45}, uses = 180, maxlevel = 0},
		},
		damage_groups = {fleshy = 4},
	},
})

-- default:pick_steel is NOT overridden. Its upstream maxlevel 2 is already
-- the right value: steel is the T3 metal (§3.0.1), so its pickaxe opens the
-- basalt band -- and, until the iron pickaxe exists, the slate band with it.

-- DELIBERATELY NOT COMPENSATED -- the two picks below, and only these two.
-- Their maxlevel goes UP (3 -> 4 and 3 -> 5), so against ordinary level-0
-- rock their leveldiff rises by 1 resp. 2 and the same engine formulas make
-- them 3x resp. 9x more durable and (via `time /= leveldiff`) faster than
-- upstream. That is left standing because these are not game items: both are
-- unreachable in normal play and WP28 deletes them (§3.0.3). Their numbers
-- are therefore NOT a balance statement about anything -- in particular they
-- must never be used as the basis of a wear-budget check (§8.3 budgets ~3000
-- combat events per item; these picks are outside that system).

-- upstream: full_punch_interval 0.9, max_drop_level 3,
--           cracky {times={[1]=2.4, [2]=1.2, [3]=0.60}, uses=20, maxlevel=3}, fleshy 5
-- Test bridge to T5, see above.
core.override_item("default:pick_mese", {
	tool_capabilities = {
		full_punch_interval = 0.9,
		max_drop_level = 3,
		groupcaps = {
			cracky = {times = {[1] = 2.4, [2] = 1.2, [3] = 0.60}, uses = 20, maxlevel = 4},
		},
		damage_groups = {fleshy = 5},
	},
})

-- upstream: full_punch_interval 0.9, max_drop_level 3,
--           cracky {times={[1]=2.0, [2]=1.0, [3]=0.50}, uses=30, maxlevel=3}, fleshy 5
-- Test bridge to T6, see above.
core.override_item("default:pick_diamond", {
	tool_capabilities = {
		full_punch_interval = 0.9,
		max_drop_level = 3,
		groupcaps = {
			cracky = {times = {[1] = 2.0, [2] = 1.0, [3] = 0.50}, uses = 30, maxlevel = 5},
		},
		damage_groups = {fleshy = 5},
	},
})
