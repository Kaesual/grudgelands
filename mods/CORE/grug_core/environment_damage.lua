-- Environmental player damage (combat_stats.md "Environmental damage").
--
-- Suffocation and drowning: one head-node read per living player per second;
-- the eye height and box come from grug_core.player_body (combat_ray.lua),
-- the pool from get_properties() only when a tick deals damage, and the
-- `noclip` privilege (grug_core.has_priv, cached) only for a head node that
-- would suffocate.
-- Character-creation stasis is engine-immortal and explicitly exempt.
-- Lava is settled in the central hp-change modifier (combat.lua), which
-- replaces the engine's flat node damage with the amount computed here.
-- Players only: mobs_redo applies its own node damage to mobs.

-- The pass visits each player once a second on its join slot (Round 81
-- PASSES; audit X4-05), each visit up to a server step early or late. A
-- visit deals its `elapsed` rounded to whole ticks: one at steady steps of
-- up to 0.25 s whatever the join moment (on a server lagging above that the
-- slot period stretches and the rounding drifts), the seconds a stall
-- covered at once, and at
-- most one on the join visit (0 to 1 s after the join), as the shared
-- accumulator's first firing. No per-player carry: one that starts at a
-- join moment can settle near a whole tick, where step jitter makes visits
-- of 0 and 2 ticks.
local CHECK_INTERVAL = 1

-- Round 24 ruling 24: shares of the ACTUAL pool per second.
local LAVA_PERCENT = 20
local DROWNING_PERCENT = 10

grug_core.DROWNING_CUSTOM_TYPE = "grug_core:drowning"

function grug_core.should_suffocate(node_def, in_stasis, has_noclip)
	if in_stasis or has_noclip or not node_def then
		return false
	end
	-- Ordinary opaque cubes inherit these defaults from Luanti. Explicit
	-- non-regular geometry must never suffocate (doors, panes, stairs, etc.).
	-- Unlike VoxeLibre, our full stone nodes do not carry an opaque group.
	local groups = node_def.groups or {}
	return node_def.walkable ~= false and
		(node_def.liquidtype == nil or node_def.liquidtype == "none") and
		(node_def.collision_box == nil or node_def.collision_box.type == "regular") and
		(node_def.node_box == nil or node_def.node_box.type == "regular") and
		(node_def.drawtype == nil or node_def.drawtype == "normal") and
		node_def.sunlight_propagates ~= true and groups.disable_suffocation ~= 1
end

function grug_core.suffocation_damage(hp_max)
	return math.max(1, math.floor((tonumber(hp_max) or 0) * 0.05))
end

-- `percent` of the pool, rounded UP so full HP always dies within
-- 100 / percent ticks; minimum 1 for any positive pool. Integer arithmetic
-- first: hp_max * percent is exact, so an exact multiple of 100 stays exact.
local function pool_share(hp_max, percent)
	hp_max = tonumber(hp_max) or 0
	if hp_max <= 0 then
		return 0
	end
	return math.max(1, math.ceil(hp_max * percent / 100))
end

function grug_core.lava_damage(hp_max)
	return pool_share(hp_max, LAVA_PERCENT)
end

-- A node in the group `grug_pool_damage` (Round 36: the rift's void) hurts by
-- that percent of the actual pool per second, like lava, so a visitor of any
-- level has the same seconds to climb out. The engine's tick names the node;
-- its flat damage_per_second only switches the tick on. nil for any other
-- reason.
function grug_core.node_pool_damage(reason, hp_max)
	if not reason or reason.type ~= "node_damage" or reason.from ~= "engine" or
			type(reason.node) ~= "string" then
		return nil
	end
	local percent = core.get_item_group(reason.node, "grug_pool_damage")
	if percent <= 0 then return nil end
	return pool_share(hp_max, percent)
end

function grug_core.drowning_damage(hp_max)
	return pool_share(hp_max, DROWNING_PERCENT)
end

-- The engine's own node-damage tick names the damaging node; lava is the
-- `lava` group (default:lava_source/flowing). Mod-issued node damage (the
-- dragon scorch) keeps its own amount.
function grug_core.is_engine_lava_damage(reason)
	return reason ~= nil and reason.type == "node_damage" and
		reason.from == "engine" and type(reason.node) == "string" and
		core.get_item_group(reason.node, "lava") > 0
end

-- A dragon's wrath on a fight participant outside its arena (grug_mobs
-- boss_dragons.lua, Round 31): never soaked by a shield.
grug_core.DRAGON_WRATH_CUSTOM_TYPE = "grug_mobs:dragon_wrath"

-- The max-HP clamp (Round 37, PLY-02/CMB-06): when hp_max drops below the
-- current HP (a pool buff expires, gear with +HP % comes off), the engine
-- itself lowers HP with an engine-origin "set_hp" (read_object_properties,
-- src/script/common/c_content.cpp:344-347); every mod set_hp carries
-- from = "mod". grug_classes.apply_stats' own clamp (a join) carries the
-- custom type below. Neither is damage: no dismount, no interrupted hold, no
-- shield soaks it.
grug_core.MAX_HP_CLAMP_CUSTOM_TYPE = "grug_core:max_hp_clamp"

function grug_core.is_max_hp_clamp(reason)
	return reason ~= nil and reason.type == "set_hp" and (reason.from == "engine" or
		reason.custom_type == grug_core.MAX_HP_CLAMP_CUSTOM_TYPE)
end

-- The environmental sources the absorb shield never soaks (ruling 24):
-- fall, engine lava and this file's drowning tick; the dragon's wrath; and
-- the max-HP clamp, which is no damage at all.
function grug_core.bypasses_absorb(reason)
	if not reason then
		return false
	end
	return reason.type == "fall" or reason.type == "drown" or
		grug_core.is_engine_lava_damage(reason) or
		reason.custom_type == grug_core.DRAGON_WRATH_CUSTOM_TYPE or
		grug_core.is_max_hp_clamp(reason)
end

-- Mirrors the engine's drowning condition (src/server/player_sao.cpp:154-170):
-- a head node with `drowning > 0`, no breath left, not immortal and the
-- player's `drowning` flag on. Only the damage cadence and amount are ours.
function grug_core.should_drown(node_def, breath, immortal, drowning_flag)
	return node_def ~= nil and (tonumber(node_def.drowning) or 0) > 0 and
		(tonumber(breath) or 1) <= 0 and not immortal and drowning_flag ~= false
end

local function in_creation_stasis(player)
	return grug_core.player_in_creation_stasis and
		grug_core.player_in_creation_stasis(player:get_player_name()) == true
end

-- The head point: the eye height, but never above the body's own box. On
-- foot the eye is inside the box (stand 1.47 of 1.7, sit 0.8 of 1.0, lay 0.3
-- of 0.3); a rider's eye height is the camera's, up to 3.5 nodes over the
-- mount's feet (grug_mounts camera, 0.45.1), so the sit box's top (1.0, inside
-- the mount's body) stands in for it and a mount fits every gap its body fits.
local function head_node_def(player, body)
	local pos = player:get_pos()
	if not pos then
		return nil
	end
	local box = body.collisionbox
	local head = {
		x = pos.x,
		y = pos.y + math.min(body.eye_height or 1.47, box and box[5] or math.huge),
		z = pos.z,
	}
	local node = core.get_node(head)
	return node and core.registered_nodes[node.name] or nil
end

local function drowning_flag(player)
	if not player.get_flags then
		return true
	end
	local flags = player:get_flags()
	return not flags or flags.drowning ~= false
end

grug_core.register_player_pass(CHECK_INTERVAL, function(player, elapsed)
	local ticks = math.floor(elapsed / CHECK_INTERVAL + 0.5)
	if ticks >= 1 and player:get_hp() > 0 and not in_creation_stasis(player) then
		local def = head_node_def(player, grug_core.player_body(player))
		-- should_suffocate with `noclip` asked only for a node that would
		-- suffocate: the same answer as asking first.
		if grug_core.should_suffocate(def, false, false) and
				not grug_core.has_priv(player:get_player_name(), "noclip") then
			local per_second = grug_core.suffocation_damage(player:get_properties().hp_max)
			player:set_hp(math.max(0, player:get_hp() - per_second * ticks), {
				type = "set_hp",
				from = "mod",
				custom_type = "grug_core:suffocation",
			})
		end
		-- The engine's own drown tick (every 2 s, flat node `drowning`)
		-- is cancelled in the central hp-change modifier; this per-second
		-- tick replaces it. Breath depletion stays the engine's.
		if def and (tonumber(def.drowning) or 0) > 0 and player:get_hp() > 0 and
				grug_core.should_drown(def, player:get_breath(),
					(player:get_armor_groups().immortal or 0) ~= 0,
					drowning_flag(player)) then
			local per_second = grug_core.drowning_damage(player:get_properties().hp_max)
			player:set_hp(math.max(0, player:get_hp() - per_second * ticks), {
				type = "drown",
				custom_type = grug_core.DROWNING_CUSTOM_TYPE,
			})
		end
	end
end)
