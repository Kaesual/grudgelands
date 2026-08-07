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

-- NOT given a `level`, on purpose: default:stone_with_copper, _tin, _coal,
-- _gold, _iron. They are not gate-relevant -- copper/tin/coal/iron are T1
-- materials that must stay reachable with the starter pickaxe, and gold is
-- jewellery metal (§3.0.1), not a tool metal at all. The rock around them is
-- their gate and that is enough. Stating it as a rule: an ore node must NEVER
-- carry a higher level than the stratum it is embedded in, or it becomes
-- undiggable at the very depth it spawns.

--
-- 2. The pickaxe maxlevel ladder
--
-- Six `level` steps need six `maxlevel` thresholds; default ships three
-- (1/1/2/2/3/3). Only `cracky` is touched and only on the PICKAXES: strata
-- are a cracky-only material, so shovels, axes and swords keep their vendored
-- capabilities untouched.
--
-- SIDE EFFECT, consciously accepted: the bronze pickaxe drops from maxlevel 2
-- to 0 and therefore stops breaking default's level-2 nodes (obsidian, the
-- mese block, and -- via level 3 -- the diamond block). That follows from
-- §3.0.1, where bronze IS the T1 metal; the steel pickaxe (maxlevel 2, left
-- alone) still breaks all of them.
--
-- TEST BRIDGE, temporary: the mese and diamond pickaxes are unreachable in
-- normal play -- their ores now sit behind the very gate those tools would
-- open -- and WP28 deletes both tool tiers outright (§3.0.3). Their maxlevel
-- 4/5 exist for exactly one reason: so a runtime tester can `/giveme` one and
-- open the T5 and T6 strata at all. This is not a balance statement.
--
-- THE GAP: T2 (level 1) has no tool of its own today, because the iron
-- pickaxe only arrives with WP26/WP29. The ladder is still walkable end to
-- end: the steel pickaxe (maxlevel 2) covers T2 and T3, and iron ore sits in
-- the T1 band, so a stone pickaxe can mine the iron that becomes that steel.
--

-- upstream: full_punch_interval 1.2, max_drop_level 0,
--           cracky {times={[3]=1.60}, uses=10, maxlevel=1}, fleshy 2
-- T1 floor.
core.override_item("default:pick_wood", {
	tool_capabilities = {
		full_punch_interval = 1.2,
		max_drop_level = 0,
		groupcaps = {
			cracky = {times = {[3] = 1.60}, uses = 10, maxlevel = 0},
		},
		damage_groups = {fleshy = 2},
	},
})

-- upstream: full_punch_interval 1.3, max_drop_level 0,
--           cracky {times={[2]=2.0, [3]=1.00}, uses=20, maxlevel=1}, fleshy 3
-- T1 floor.
core.override_item("default:pick_stone", {
	tool_capabilities = {
		full_punch_interval = 1.3,
		max_drop_level = 0,
		groupcaps = {
			cracky = {times = {[2] = 2.0, [3] = 1.00}, uses = 20, maxlevel = 0},
		},
		damage_groups = {fleshy = 3},
	},
})

-- upstream: full_punch_interval 1.0, max_drop_level 1,
--           cracky {times={[1]=4.50, [2]=1.80, [3]=0.90}, uses=20, maxlevel=2}, fleshy 4
-- Bronze IS T1 (§3.0.1) -- it is the best of the three starter picks, not a
-- step above them, so it lands on the same level-0 rung.
core.override_item("default:pick_bronze", {
	tool_capabilities = {
		full_punch_interval = 1.0,
		max_drop_level = 1,
		groupcaps = {
			cracky = {times = {[1] = 4.50, [2] = 1.80, [3] = 0.90}, uses = 20, maxlevel = 0},
		},
		damage_groups = {fleshy = 4},
	},
})

-- default:pick_steel is NOT overridden. Its upstream maxlevel 2 is already
-- the right value: steel is the T3 metal (§3.0.1), so its pickaxe opens the
-- basalt band -- and, until the iron pickaxe exists, the slate band with it.

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
