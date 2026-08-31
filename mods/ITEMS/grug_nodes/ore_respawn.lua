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

-- The ore-node identities that retain the shipped R4 respawn behavior.
-- WP40 R7 places their natural deposits in its single VM transaction rather
-- than through engine scatter registrations, so registration geometry is no
-- longer a valid load-time coupling check. WP34 still owns the eventual
-- depth-aware respawn revision; until then this closed material roster remains
-- the authority for mined-node replacement only.
--
-- `grug_materials:abyssal_crystal_ore` is absent BY DESIGN, not by oversight:
-- R7's natural-resource catalog does not place it, because it is a
-- housing-isle depth-step payout, and world.md §5.4
-- states that isle clusters explicitly do NOT respawn under R4 -- a mined-out
-- step is what makes the next step worth buying. Listing it here would only
-- enter this respawn roster.
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
	is_ground_content = false,
	-- Plain stone with the pockets the vein left behind; the overlay is our
	-- own art, the stone below is default's tile (LICENSE-media.md).
	tiles = {"default_stone.png^grug_nodes_depleted_vein.png"},
	-- `stone = 1` is deliberately absent: this must not be usable as a stone
	-- source in recipes or be treated as stone by other mods. `cracky = 3`
	-- matches the ore it replaces, so it digs like the rest of the wall.
	--
	-- It is neither natural ground nor a resource. The authoritative mining
	-- transaction already accepted the ore that produced this placeholder;
	-- clearing the empty pocket therefore needs no second depth/harvest check.
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
			-- Use the local stratum node only for cosmetic wall consistency.
			-- Natural access remains authoritatively target-y-based and is not
			-- determined by the identity of the surrounding stratum.
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
-- Load-time identity check (landmine rule: never trust a hardcoded node name)
--

local function check_ore_list()
	for name in pairs(respawning_ores) do
		if not core.registered_nodes[name] then
			core.log("error", "[" .. MODNAME .. "] respawn list names " ..
				name .. ", which is not a registered node -- veins of it " ..
				"would respawn as an unknown node")
		end
	end
end

core.register_on_mods_loaded(check_ore_list)
