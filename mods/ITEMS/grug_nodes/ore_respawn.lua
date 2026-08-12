-- R4 ore respawn (WP6/T9, docs/design/world.md §2 rule R4).
--
-- A vein a player mines does not vanish for good: the dug ore leaves a
-- "Depleted Vein" placeholder behind, and after 15-30 minutes a node timer
-- turns that placeholder back into the very ore that was mined there. A
-- persistent world therefore never runs dry, while the mining trip itself
-- still feels like consuming a finite deposit for the next half hour.
--
-- Why a placeholder node and not a bookkeeping table: the node timer IS the
-- persistence. It is saved inside the mapblock, survives a restart, and the
-- engine catches it up on block activation (`ServerEnvironment::activateBlock`
-- steps the block's node timers by the time the block was inactive), so a
-- vein mined in a corner of the world that nobody visits for a week respawns
-- the moment that corner is loaded again. No mod storage, no global step, no
-- ABM scanning the map -- zero runtime cost while nothing is happening.
--
-- Accepted behaviour: **digging the placeholder cancels the respawn.** The
-- timer lives and dies with the node, and the depleted vein drops nothing, so
-- a player who clears the pocket out of their tunnel trades the future ore
-- for a tidy wall. That is a fair, self-explanatory deal and keeps the
-- mechanism free of any hidden state outside the node.

local MODNAME = core.get_current_modname()

local DEPLETED = "grug_nodes:depleted_vein"

-- Node meta key holding the itemstring of the ore to grow back.
local META_ORE = "grug_ore"

-- Respawn delay in seconds, rolled per node: 15-30 minutes of real time.
-- The design doc gives no number; this range is picked so that a vein is
-- gone for the rest of the current mining trip (short trips) but is back on
-- the next session, and the randomisation keeps a mined-out cavern from
-- popping back in one synchronised wave.
local RESPAWN_MIN = 900
local RESPAWN_MAX = 1800

-- The ores that respawn.
--
-- COUPLING: mods/MAPGEN/grug_mapgen/ores.lua owns every ore registration of
-- this game (default's own register_ores() is deliberately not called, see
-- the tail of mods/BASE/default/mapgen.lua). This list mirrors the
-- `scatter_ores` table there exactly. The blob ores from the same file
-- (default:clay, default:silver_sand, default:dirt, default:gravel) are left
-- out on purpose: they are terrain filler, not veins, and regrowing dirt or
-- gravel would fight the player's landscaping instead of keeping the world
-- stocked. `check_ore_list()` below re-verifies the coupling at load time,
-- so a future ore added in grug_mapgen shows up as a log warning instead of
-- silently never respawning.
--
-- `grug_materials:abyssal_crystal_ore` is absent BY DESIGN, not by oversight:
-- no register_ore places it (grug_mapgen/ores.lua registers no scatter ore for
-- it), because it is a housing-isle depth-step payout, and world.md §5.4
-- states that isle clusters explicitly do NOT respawn under R4 -- a mined-out
-- step is what makes the next step worth buying. Listing it here would only
-- earn a startup warning from check_ore_list().
local respawning_ores = {}
for _, key in ipairs(grug_materials.CURRENT_SCATTER_RESOURCES) do
	local node = grug_materials.resource_node(key)
	if not node then
		error("grug_nodes: unknown respawn resource " .. key)
	end
	respawning_ores[node] = true
end

--
-- The placeholder node
--

core.register_node(DEPLETED, {
	description = "Depleted Vein",
	-- Plain stone with the pockets the vein left behind; the overlay is our
	-- own art, the stone below is default's tile (LICENSE-media.md).
	tiles = {"default_stone.png^grug_nodes_depleted_vein.png"},
	-- `stone = 1` is deliberately absent: this must not be usable as a stone
	-- source in recipes or be treated as stone by other mods. `cracky = 3`
	-- matches the ore it replaces, so it digs like the rest of the wall.
	--
	-- NO `level` EITHER, and that is not an oversight (§3.0.1/§3.0.4): a
	-- depleted vein only ever appears where somebody could already break the
	-- ore that stood there, it drops nothing, and the ores that produce it in
	-- practice (coal, tin, copper, iron, gold) carry no `level` themselves
	-- because they are deliberately not gate-relevant. The rock AROUND the
	-- pocket is the depth gate, never the single pocket.
	groups = {cracky = 3, grug_depleted = 1},
	drop = "",
	sounds = default.node_sound_stone_defaults(),
	on_timer = function(pos)
		local ore = grug_materials.canonical_name(
			core.get_meta(pos):get_string(META_ORE))
		if respawning_ores[ore] then
			core.set_node(pos, {name = ore})
		else
			-- Meta lost or pointing at an ore that no longer exists (world
			-- upgraded, list changed): never leave the placeholder in the
			-- world forever -- fall back to the wall it sits in.
			--
			-- Not a hardcoded `default:stone`: that is only the tier-1
			-- stratum. At -600 it would punch a level-0 hole into a level-3
			-- granite wall, i.e. a free bypass of the §3.0.4 depth gate,
			-- reachable by anyone who waits out a timer next to a lost meta.
			core.set_node(pos, {name = grug_materials.stratum_node_for(pos.y)})
		end
		-- set_node dropped the timer with the node anyway; be explicit.
		return false
	end,
})

--
-- The dig hook
--

-- ONE global handler for all ores instead of an on_dig/after_dig_node per ore
-- node: default is vendored and must stay unpatched (VENDOR.md), and
-- core.override_item on seven nodes would be seven places to keep in sync.
--
-- Ordering guarantee (builtin/game/item.lua, core.node_dig): drops are handed
-- to the digger by handle_node_drops() and only THEN is the node removed and
-- the registered_on_dignodes run. Writing a node at `pos` here can therefore
-- not eat the drop of the ore that was just mined.
--
-- No zone check today, on purpose:
--   * Capitals, outposts and enemy territory (world.md R1/R2) and the ocean
--     (R3) are covered by the central core.is_protected override -- node_dig
--     refuses the dig there before this callback can ever run.
--   * R4's real exception, guild mining claims and housing plots, does not
--     exist yet. WP16 slots its claim check in at the marker below.
--
-- Not gated on `digger` being a player either: the only non-player digger
-- that could exist is a machine mod, and there is none (mobs_redo's
-- path-digging uses core.remove_node/set_node, which fire no dignode
-- callback at all). Respawning after such a dig would be correct anyway.
core.register_on_dignode(function(pos, oldnode, digger)
	if not oldnode or not respawning_ores[oldnode.name] then
		return
	end
	-- WP16: `if grug_claims.is_claimed(pos) then return end` -- inside a
	-- guild mining claim what is dug stays dug (world.md R4/§5).
	if core.get_node(pos).name ~= "air" then
		-- Another dignode callback or a node callback already claimed the
		-- spot; do not overwrite whatever it put there.
		return
	end
	core.set_node(pos, {name = DEPLETED})
	core.get_meta(pos):set_string(META_ORE, oldnode.name)
	core.get_node_timer(pos):start(math.random(RESPAWN_MIN, RESPAWN_MAX))
end)

--
-- Load-time coupling check (landmine rule: never trust a hardcoded node name)
--

local function check_ore_list()
	local registered = {}
	for _, def in pairs(core.registered_ores) do
		if def.ore_type == "scatter" then
			registered[def.ore] = true
		end
	end
	for name in pairs(respawning_ores) do
		if not core.registered_nodes[name] then
			core.log("error", "[" .. MODNAME .. "] respawn list names " ..
				name .. ", which is not a registered node -- veins of it " ..
				"would respawn as an unknown node")
		elseif not registered[name] then
			core.log("warning", "[" .. MODNAME .. "] respawn list names " ..
				name .. ", which no mod registers as a scatter ore anymore")
		end
	end
	for name in pairs(registered) do
		if not respawning_ores[name] then
			core.log("warning", "[" .. MODNAME .. "] scatter ore " .. name ..
				" is not in the R4 respawn list (ore_respawn.lua) -- veins " ..
				"of it are gone for good once mined")
		end
	end
end

core.register_on_mods_loaded(check_ore_list)
