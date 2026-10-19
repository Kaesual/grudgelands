-- Talent trees (docs/design/skill_trees.md, WP11 lane X1: "the model").
--
-- This file is the registry, the point budget, the two gate kinds, the
-- spend/respec rules, the validating persistence path and the two accessors
-- every consumer reads; the 48 talents of the three shipped classes are DATA
-- in talents_warrior.lua, talents_mage.lua and talents_priest.lua, and the
-- timed-window table lives in talent_windows.lua. Lane X1 ships INERT:
-- registering a talent changes no number by itself; the consumers are the
-- one-line reads lane X2 puts at the sites skill_trees.md §3.8 names.
--
-- Shape (§1.1/§1.2): two trees per class, two chains per tree, four tiers per
-- chain. Ranks run 5 / 4 / 3 down a chain, and the capstone has exactly ONE
-- rank (ruling 17), so the capstone's chain is 5+4+3+1 = 13 and the other
-- 5+4+3+3 = 15 -- 28 ranks per tree, 56 per class.
--
-- Points (§1.3, ruling 1): one every two levels, the first at level 2, so
-- floor(level / 2) and 30 at level 60. Never persisted -- deriving it is what
-- makes "points available" and "level" incapable of disagreeing.
--
-- Gates (§1.2), and both are needed:
--   * a TIER GATE is points already spent IN THAT TREE -- 0 / 5 / 12 / 20;
--   * a HARD CHAIN is "all ranks of the talent above it, in the same chain".
-- A capstone therefore costs 21 points in its tree (its chain to 12, eight
-- more anywhere in the tree to open the gate, and the capstone itself), which
-- is level 42, and two capstones would cost 42 of the 30 points a character
-- ever sees. Ruling 18's "exactly one capstone" is arithmetic here, not a rule.

local META_TALENTS = "grug_classes:talents"

-- Points in the tree required BEFORE the first rank of a talent of this tier.
grug_classes.TALENT_TIER_GATES = {0, 5, 12, 20}
-- Ranks by tier; a capstone overrides its tier-4 entry with one rank.
grug_classes.TALENT_TIER_RANKS = {5, 4, 3, 3}
grug_classes.TALENT_CAPSTONE_RANKS = 1
grug_classes.TALENT_LEVELS_PER_POINT = 2

grug_classes.registered_trees = {}
grug_classes.tree_ids = {} -- registration order
grug_classes.registered_talents = {}
grug_classes.talent_ids = {} -- registration order

--
-- The closed effect vocabulary (§3.1: "every effect key present in the closed
-- vocabulary table"). A typo is a startup failure, never a silently inert
-- talent, and skill_trees.md §3.7 group 5 walks this table against the real
-- consumer sources. The comment on each key is the site that reads it; `X3`
-- marks a key whose consumer belongs to lane X3 (keystones, capstones and the
-- two talents that re-tune an ability X3 still has to register).
--

local EFFECT_KEYS = {
	-- Lane X2 consumers (the reads this lane wrote).
	armor_percent_add = "grug_quality raw armor-rating aggregation",
	max_hp_percent_add = "grug_classes/stats.lua get_max_hp",
	max_mana_percent_add = "grug_classes/stats.lua get_max_mana",
	crit_chance_add = "grug_classes/stats.lua get_crit_chance",
	rage_per_hit_taken_add = "grug_abilities/init.lua hit-taken rage",
	rage_per_swing_add = "grug_abilities/init.lua the five swing rage sites",
	threat_mult_add = "grug_core/combat.lua casts, grug_abilities/init.lua swings",
	heal_threat_factor_sub = "grug_core/combat.lua add_heal_threat",
	taunt_cooldown_sub = "grug_abilities/init.lua effective_cooldown",
	charge_cooldown_sub = "grug_abilities/init.lua effective_cooldown",
	blink_cooldown_sub = "grug_abilities/init.lua effective_cooldown",
	smite_cooldown_sub = "grug_abilities/init.lua effective_cooldown",
	mighty_blow_multiplier_add = "grug_abilities/kits.lua Mighty Blow",
	fireball_damage_add = "grug_abilities/kits.lua Fireball",
	fireball_range_add = "grug_abilities/kits.lua spawn, init.lua get_range",
	ice_nova_root_add = "grug_abilities/kits.lua Ice Nova",
	ice_nova_slow_add = "grug_abilities/kits.lua Ice Nova",
	blink_distance_add = "grug_abilities/kits.lua Blink",
	heal_add = "grug_abilities/kits.lua Heal",
	shield_absorb_add = "grug_abilities/kits.lua Shield",
	shield_cooldown_sub = "grug_abilities/init.lua effective_cooldown",
	smite_damage_add = "grug_abilities/kits.lua Smite",
	smite_damage_while_shielded_add = "grug_abilities/kits.lua Smite",
	combat_mana_regen_add = "grug_abilities/init.lua in-combat mana regen",
	-- Lane X3 consumers (keystones, capstones, and the two finishers whose
	-- ability X3 still has to register or un-gate).
	hold_ground_absorb = "X3",
	armor_rating_add_low_hp = "grug_inventory/equipment.lua armor aggregation",
	taunt_radius = "X3",
	mighty_blow_cleave = "X3",
	crit_chance_add_window = "X3",
	crit_cap_override = "X3",
	hamstring_slow_add = "X3",
	hamstring_root = "X3",
	fireball_splash = "X3",
	whitehot_window = "X3",
	whitehot_damage = "grug_abilities/kits.lua Fireball, inside Whitehot's window",
	cinderfall_damage = "X3",
	cinderfall_radius_add = "X3",
	ice_nova_ranged = "X3",
	control_damage_add = "X3",
	glacial_ward_absorb = "X3",
	mend_tick_add = "X3",
	heal_splash = "X3",
	dodge_chance_window = "X3",
	word_of_ruin_damage = "X3",
	drain_ratio_override = "X3",
	smite_absorb = "X3",
	-- Round 11 Scout consumers.
	loose_damage_add = "grug_abilities/scout.lua Loose",
	loose_second_arrow = "grug_abilities/scout.lua Twin Shot",
	loose_range_add = "grug_abilities/scout.lua Longshot",
	longshot_damage_add = "grug_abilities/scout.lua Longshot hit beyond 25 m",
	arrow_refund_chance = "grug_abilities/scout.lua Loose settlement",
	draw_time_sub = "grug_abilities/scout.lua draw clock",
	pinning_root = "grug_abilities/scout.lua Pinning Shot",
	dodge_chance_add = "grug_classes/stats.lua dodge",
	melee_damage_add = "grug_abilities/init.lua authoritative swing",
	opening_multiplier = "grug_abilities/scout.lua Opening",
	opening_charge_sub = "grug_abilities/init.lua effective charge",
	sidestep_cooldown_sub = "grug_abilities/init.lua effective cooldown",
	root_slow_immunity = "grug_classes/scout.lua Shake Loose",
	dodge_cap_override = "grug_classes/stats.lua dodge cap",
}

local POOL_EFFECT_KIND = {
	max_hp_percent_add = "hp",
	max_mana_percent_add = "mana",
	hold_ground_absorb = "neutral",
}

-- Shared accessor for the talent UI and every pool-derived talent consumer.
-- Passing `percent` previews a particular rank; omitting it resolves the
-- player's current total for that effect key.
function grug_classes.pool_talent_amount(player, effect_key, percent)
	local pool = POOL_EFFECT_KIND[effect_key]
	if not pool then
		return nil
	end
	if percent == nil then
		percent = grug_classes.get_talent_bonus(player, effect_key)
	end
	return grug_classes.pool_percent_amount(player, pool, percent)
end

function grug_classes.pool_talent_effect_key(def)
	for effect_key in pairs(def.effects or {}) do
		if POOL_EFFECT_KIND[effect_key] then
			return effect_key
		end
	end
	return nil
end

grug_classes.TALENT_EFFECT_KEYS = EFFECT_KEYS

-- Keys that only count while the talent's own timed window runs (§3.2: the
-- one new shape revision 2 adds). get_talent_bonus returns 0 for them when no
-- window is running, so a consumer needs no second accessor.
local WINDOW_KEYS = {
	armor_rating_add_low_hp = true,
	crit_chance_add_window = true,
	crit_cap_override = true,
	whitehot_window = true,
	whitehot_damage = true,
	dodge_chance_window = true,
	drain_ratio_override = true,
	dodge_cap_override = true,
}

grug_classes.TALENT_WINDOW_KEYS = WINDOW_KEYS

-- Level-proof values (Round 35, skill_trees.md §2.10). A flat "+N" added
-- before the damage scalar fades as the level grows (Tinder's +5 was +43 % of
-- a Fireball at level 10 and +11 % at level 60), so these keys store a
-- PERCENTAGE of a level reference instead. get_talent_bonus hands every
-- consumer the amount at the player's level, so the consumers keep adding it
-- exactly where they added the flat value:
--   damage -- % of a base hit, grug_core.baseline_melee_total(level): the raw
--             same-level hit before the damage scalar, which the scalar turns
--             into one eighth of the base pool (a same-level Fireball without
--             gear is exactly 100 %);
--   armor  -- % of grug_core.armor_k(level), the rating that halves the hit
--             of a same-level attacker.
-- Like the flat values they replace, the amounts do not grow with gear --
-- except the caster keys below, which follow the staff or wand (Round 46).
local LEVEL_SCALED_KEYS = {
	armor_percent_add = "armor",
	armor_rating_add_low_hp = "armor",
	fireball_damage_add = "damage",
	fireball_splash = "damage",
	whitehot_damage = "damage",
	cinderfall_damage = "damage",
	control_damage_add = "damage",
	smite_damage_add = "damage",
	smite_damage_while_shielded_add = "damage",
	word_of_ruin_damage = "damage",
	loose_damage_add = "damage",
	longshot_damage_add = "damage",
	melee_damage_add = "damage",
}

grug_classes.TALENT_LEVEL_SCALED_KEYS = LEVEL_SCALED_KEYS

-- The Mage's and Priest's damage keys (Round 46, the user's answer of
-- 2026-10-12): they follow the caster weapon like the spell they add to.
-- Their reference is a "spell base hit", the base hit times spell base /
-- Bw(L) (grug_core.spell_base), so an own-level staff or wand keeps every
-- number exactly, an older one weakens the talent part in the same
-- proportion as the spell, and none halves it. Warrior and Scout keys stay
-- on the base hit.
local SPELL_KEYS = {
	fireball_damage_add = true,
	fireball_splash = true,
	whitehot_damage = true,
	cinderfall_damage = true,
	control_damage_add = true,
	smite_damage_add = true,
	smite_damage_while_shielded_add = true,
	word_of_ruin_damage = true,
}

grug_classes.TALENT_SPELL_KEYS = SPELL_KEYS

local function level_reference(unit, level)
	level = math.max(1, math.min(60, math.floor(tonumber(level) or 1)))
	if unit == "armor" then
		return grug_core.armor_k(level)
	end
	return grug_core.baseline_melee_total(level)
end

-- Spell base / Bw(L) for the player's caster weapon at `level`: 1 with an
-- own-level staff or wand, 0.5 without one. grug_abilities owns the weapon
-- lookup and loads after this mod; without it the ratio is 1.
function grug_classes.spell_weapon_ratio(player, level)
	local abilities = rawget(_G, "grug_abilities")
	if not abilities or type(abilities.caster_weapon_ilvl) ~= "function" then
		return 1
	end
	level = math.max(1, math.min(60, math.floor(tonumber(level) or 1)))
	return grug_core.spell_base(level, abilities.caster_weapon_ilvl(player))
		/ grug_core.baseline_weapon_damage(level)
end

-- What a stored value of `key` is worth at the player's level: the value
-- itself for a key that is not level-scaled. The talent UI previews each rank
-- through it; get_talent_bonus applies the same rule to the summed total.
function grug_classes.talent_level_amount(player, key, value)
	local unit = LEVEL_SCALED_KEYS[key]
	if not unit then
		return value
	end
	local level = grug_xp.get_level(player)
	local amount = value * level_reference(unit, level) / 100
	if SPELL_KEYS[key] then
		amount = amount * grug_classes.spell_weapon_ratio(player, level)
	end
	return amount
end

--
-- Registration. Mirrors register_class/register_ability: the shape is
-- asserted at load time, so a malformed talent stops the server instead of
-- quietly doing nothing.
--

function grug_classes.register_tree(def)
	assert(type(def) == "table", "tree definition must be a table")
	assert(def.id and def.class and def.name,
		"incomplete tree definition: " .. tostring(def.id))
	assert(not grug_classes.registered_trees[def.id],
		"duplicate tree id " .. tostring(def.id))
	assert(grug_classes.registered_classes[def.class],
		"tree " .. def.id .. " names an unknown class " .. tostring(def.class))
	assert(type(def.chains) == "table" and #def.chains == 2,
		"tree " .. def.id .. " needs exactly two chains (ruling 2)")
	assert(def.chains[1] ~= def.chains[2],
		"tree " .. def.id .. " has the same chain twice")
	assert(def.capstone_chain == def.chains[1]
		or def.capstone_chain == def.chains[2],
		"tree " .. def.id .. " has no capstone_chain among its chains")
	def.talents = {} -- registration order, filled by register_talent
	grug_classes.registered_trees[def.id] = def
	table.insert(grug_classes.tree_ids, def.id)
	return def
end

local function ranks_for(tree, def)
	if def.capstone then
		return grug_classes.TALENT_CAPSTONE_RANKS
	end
	return grug_classes.TALENT_TIER_RANKS[def.tier]
end

function grug_classes.register_talent(def)
	assert(type(def) == "table", "talent definition must be a table")
	assert(def.id and def.tree and def.chain and def.name,
		"incomplete talent definition: " .. tostring(def.id))
	assert(not grug_classes.registered_talents[def.id],
		"duplicate talent id " .. def.id)
	local tree = grug_classes.registered_trees[def.tree]
	assert(tree, "talent " .. def.id .. " names an unknown tree " ..
		tostring(def.tree))
	assert(def.chain == tree.chains[1] or def.chain == tree.chains[2],
		"talent " .. def.id .. " names a chain outside its tree")
	assert(type(def.tier) == "number" and def.tier >= 1 and def.tier <= 4
		and def.tier == math.floor(def.tier),
		"talent " .. def.id .. " has no tier in 1..4")
	assert(not def.keystone or def.tier == 3,
		"talent " .. def.id .. " is a keystone outside tier 3")
	assert(not def.capstone or def.tier == 4,
		"talent " .. def.id .. " is a capstone outside tier 4")
	assert(not def.capstone or def.chain == tree.capstone_chain,
		"talent " .. def.id .. " is a capstone off its tree's capstone chain")
	assert(not (def.keystone and def.capstone),
		"talent " .. def.id .. " is both keystone and capstone")
	def.ranks = ranks_for(tree, def)
	def.class = tree.class
	assert(type(def.effects) == "table", "talent " .. def.id .. " has no effects")
	local keys = 0
	for key, values in pairs(def.effects) do
		assert(EFFECT_KEYS[key], "talent " .. def.id ..
			" uses effect key '" .. tostring(key) ..
			"', which is not in the closed vocabulary")
		assert(type(values) == "table" and #values == def.ranks,
			"talent " .. def.id .. " effect '" .. key .. "' needs exactly " ..
			def.ranks .. " values, one per rank")
		for _, value in ipairs(values) do
			assert(type(value) == "number",
				"talent " .. def.id .. " effect '" .. key ..
				"' has a non-numeric rank value")
		end
		keys = keys + 1
	end
	assert(keys > 0, "talent " .. def.id .. " declares no effect at all")
	grug_classes.registered_talents[def.id] = def
	table.insert(grug_classes.talent_ids, def.id)
	table.insert(tree.talents, def)
	return def
end

-- The talent one tier above this one in the SAME chain (the hard chain).
-- Built by the audit below, so a lookup is a table index on the hot paths.
local function talent_above(def)
	return def.above
end

--
-- Load-time audit (§3.1). Everything that cannot be checked while a single
-- talent registers -- counts per chain, per tree and per class -- is checked
-- once, here, after the data below has run.
--

function grug_classes.audit_talents()
	local trees_of_class = {}
	for _, tree_id in ipairs(grug_classes.tree_ids) do
		local tree = grug_classes.registered_trees[tree_id]
		trees_of_class[tree.class] = (trees_of_class[tree.class] or 0) + 1
		local by_slot, keystones, capstones, ranks = {}, {}, 0, 0
		for _, def in ipairs(tree.talents) do
			local slot = def.chain .. ":" .. def.tier
			assert(not by_slot[slot], "tree " .. tree_id ..
				" has two talents at " .. slot)
			by_slot[slot] = def
			ranks = ranks + def.ranks
			if def.keystone then
				keystones[def.chain] = (keystones[def.chain] or 0) + 1
			end
			if def.capstone then
				capstones = capstones + 1
			end
		end
		assert(#tree.talents == 8,
			"tree " .. tree_id .. " holds " .. #tree.talents ..
			" talents instead of 8")
		assert(capstones == 1,
			"tree " .. tree_id .. " holds " .. capstones ..
			" capstones instead of 1")
		for _, chain in ipairs(tree.chains) do
			assert(keystones[chain] == 1, "tree " .. tree_id .. " chain " ..
				chain .. " holds " .. tostring(keystones[chain]) ..
				" keystones instead of 1")
			for tier = 1, 4 do
				assert(by_slot[chain .. ":" .. tier], "tree " .. tree_id ..
					" chain " .. chain .. " has no tier-" .. tier .. " talent")
			end
			for tier = 2, 4 do
				by_slot[chain .. ":" .. tier].above =
					by_slot[chain .. ":" .. (tier - 1)]
			end
		end
		assert(ranks == 28, "tree " .. tree_id .. " holds " .. ranks ..
			" ranks instead of the 28 of skill_trees.md §1.2")
		-- A `window` def contributes ONLY through the windowed branch of
		-- get_talent_bonus, and that branch is entered per KEY. A windowed
		-- talent carrying a key outside WINDOW_KEYS would therefore be
		-- silently unreadable -- no error, no effect, the worst failure a
		-- numeric talent system has. One assert closes it.
		for _, def in ipairs(tree.talents) do
			if def.window then
				for key in pairs(def.effects) do
					assert(WINDOW_KEYS[key], "talent " .. def.id ..
						" is windowed but its key '" .. key ..
						"' is not in WINDOW_KEYS, so nothing could ever " ..
						"read it")
				end
			end
		end
		tree.ranks = ranks
	end
	for class_id, count in pairs(trees_of_class) do
		assert(count == 2, "class " .. class_id .. " holds " .. count ..
			" trees instead of 2")
	end
end

--
-- The 48 talents of the three shipped classes (skill_trees.md §§2.1-2.6).
-- DATA ONLY: every "Modifies" cell of those tables is a consumer elsewhere.
-- Descriptions are player-facing text for the sfinv page; /talents keeps a
-- read-only rank summary without reproducing them.
--

dofile(core.get_modpath(core.get_current_modname()) .. "/talents_warrior.lua")
dofile(core.get_modpath(core.get_current_modname()) .. "/talents_mage.lua")
dofile(core.get_modpath(core.get_current_modname()) .. "/talents_priest.lua")
dofile(core.get_modpath(core.get_current_modname()) .. "/scout_talents.lua")
grug_classes.audit_talents()

--
-- Runtime state. One parsed cache per online player (the pattern of
-- grug_abilities' runtime tables) plus the timed-window table of §3.2, which
-- is the single place a window lives. Both are cleared on leave; the windows
-- additionally on death and on respec (§3.7 group 7 -- and those are the only
-- three lifecycle events left, since ruling 20 removed the class change).
--

local cache = {} -- player name -> {ranks, tree_points, spent, static, windowed}
local META_UNBROKEN_READY = "grug_classes:unbroken_ready"

-- The points a character of `level` has earned in total: the one rule, also
-- read by the level-up banner (grug_xp) and the level-change notice below.
function grug_classes.talent_points_at(level)
	return math.floor(level / grug_classes.TALENT_LEVELS_PER_POINT)
end

function grug_classes.talent_points_total(player)
	return grug_classes.talent_points_at(grug_xp.get_level(player))
end

-- Trees of a class, in registration order. Nil class = no trees.
function grug_classes.trees_of_class(class_id)
	local list = {}
	for _, tree_id in ipairs(grug_classes.tree_ids) do
		local tree = grug_classes.registered_trees[tree_id]
		if tree.class == class_id then
			list[#list + 1] = tree
		end
	end
	return list
end

-- Does this talent belong to this class? A hand-edited meta string that gives
-- a Warrior a Mage talent is exactly as invalid as an unknown id.
local function talent_of_class(def, class_id)
	return class_id ~= nil and def.class == class_id
end

-- Drop every rank whose tier gate or hard chain is unsatisfied, together with
-- everything below it in its chain. Dropping only ever lowers a tree's point
-- total, so the loop shrinks monotonically and terminates.
--
-- The gate compares "points in the tree MINUS this talent's own ranks"
-- against the tier gate, which is the order-independent form of "the points
-- already spent when its first rank was bought": a legal build satisfies it
-- at every rank, and a forged one that skipped the gate does not.
local function enforce_gates(ranks)
	local talents = grug_classes.registered_talents
	local gates = grug_classes.TALENT_TIER_GATES
	while true do
		local points = {}
		for id, rank in pairs(ranks) do
			local def = talents[id]
			points[def.tree] = (points[def.tree] or 0) + rank
		end
		local drop = nil
		for _, id in ipairs(grug_classes.talent_ids) do
			local rank = ranks[id]
			if rank then
				local def = talents[id]
				local ok = (points[def.tree] or 0) - rank >= gates[def.tier]
				if ok and def.tier > 1 then
					local above = talent_above(def)
					ok = above ~= nil and (ranks[above.id] or 0) >= above.ranks
				end
				if not ok then
					drop = drop or {}
					drop[#drop + 1] = id
				end
			end
		end
		if not drop then
			return
		end
		for _, id in ipairs(drop) do
			ranks[id] = nil
		end
	end
end

-- Total spent, and the per-tree totals.
local function totals(ranks)
	local spent, tree_points = 0, {}
	for id, rank in pairs(ranks) do
		local def = grug_classes.registered_talents[id]
		spent = spent + rank
		tree_points[def.tree] = (tree_points[def.tree] or 0) + rank
	end
	return spent, tree_points
end

-- The first half of the read path: the stored string, read as far as "is this
-- a rank this character could name". Unknown ids, other classes' talents and
-- over-rank values are already gone here, but no gate and no budget has been
-- applied yet. `parse` below continues from it, and the level-drop chat line
-- reports the total of THIS -- the count after the budget clamp would say how
-- many ranks a level-4 character may hold rather than how many the reset
-- actually took away.
local function scan_stored_ranks(player)
	local class_id = grug_classes.get_class(player)
	local raw = player:get_meta():get_string(META_TALENTS) or ""
	local ranks = {}
	for id, value in raw:gmatch("(%a[%w_]*)=(%-?%d+)") do
		local def = grug_classes.registered_talents[id]
		if def and talent_of_class(def, class_id) then
			local rank = math.floor(tonumber(value) or 0)
			if rank > def.ranks then
				rank = def.ranks
			end
			if rank > 0 then
				ranks[id] = rank
			end
		end
	end
	return ranks
end

-- The read path VALIDATES, it does not trust (§3.3). Unknown ids are dropped,
-- ranks are clamped to the talent's own rank count, a rank whose gate or hard
-- chain is unsatisfied is dropped with everything below it in its chain, and
-- the total is clamped to floor(level / 2) by giving back the deepest ranks
-- first. A hand-edited meta string cannot buy a capstone at level 4.
local function parse(player)
	local ranks = scan_stored_ranks(player)
	enforce_gates(ranks)
	local budget = grug_classes.talent_points_total(player)
	local spent = totals(ranks)
	while spent > budget do
		-- Deepest tier first, latest registration first inside a tier: the
		-- refund order has to be a total order or two servers disagree about
		-- the same forged string.
		local worst = nil
		for _, id in ipairs(grug_classes.talent_ids) do
			if ranks[id] then
				local def = grug_classes.registered_talents[id]
				if not worst or def.tier >= worst.tier then
					worst = def
				end
			end
		end
		if not worst then
			break
		end
		ranks[worst.id] = ranks[worst.id] - 1
		if ranks[worst.id] <= 0 then
			ranks[worst.id] = nil
		end
		enforce_gates(ranks)
		spent = totals(ranks)
	end
	local total_spent, tree_points = totals(ranks)
	-- Pre-summed bonuses, so the consumers on the damage pipeline pay one
	-- table index. Windowed talents are kept apart: their contribution
	-- depends on a clock, so it cannot live in a cached sum.
	--
	-- Summed in REGISTRATION order, not in `pairs` order: no effect key has
	-- two contributors on one character today (the three shared keys are
	-- shared across classes, never inside one), but a float sum whose order
	-- depends on a hash is a defect waiting for the day one does.
	local static, windowed = {}, {}
	for _, id in ipairs(grug_classes.talent_ids) do
		local rank = ranks[id]
		if rank then
			local def = grug_classes.registered_talents[id]
			if def.window then
				windowed[#windowed + 1] = def
			else
				for key, values in pairs(def.effects) do
					static[key] = (static[key] or 0) + values[rank]
				end
			end
		end
	end
	return {
		ranks = ranks,
		spent = total_spent,
		tree_points = tree_points,
		static = static,
		windowed = windowed,
	}
end

local function state(player)
	local name = player:get_player_name()
	local entry = cache[name]
	if not entry then
		entry = parse(player)
		cache[name] = entry
	end
	return entry
end

function grug_classes.invalidate_talents(player)
	cache[player:get_player_name()] = nil
end

local function serialize(ranks)
	local parts = {}
	for _, id in ipairs(grug_classes.talent_ids) do
		local rank = ranks[id]
		if rank and rank > 0 then
			parts[#parts + 1] = id .. "=" .. rank
		end
	end
	return table.concat(parts, ",")
end

grug_classes.serialize_talents = serialize

-- Timed windows (§3.2): the window runtime lives in talent_windows.lua.
dofile(core.get_modpath(core.get_current_modname()) .. "/talent_windows.lua")

--
-- The two accessors every consumer reads (§3.2). get_talent_bonus is the
-- deliberate twin of get_race_perk, down to the grug_core stub override at
-- the bottom of this file.
--

-- Summed bonus of this key over the player's ranked talents; 0 when none.
-- A level-scaled key answers with its amount at the player's level.
function grug_classes.get_talent_bonus(player, key)
	if not player or not player.is_player or not player:is_player() then
		return 0
	end
	local entry = state(player)
	local total = entry.static[key] or 0
	if WINDOW_KEYS[key] then
		for _, def in ipairs(entry.windowed) do
			local values = def.effects[key]
			if values and grug_classes.talent_window_active(player, def.id) then
				total = total + values[entry.ranks[def.id]]
			end
		end
	end
	if total ~= 0 and LEVEL_SCALED_KEYS[key] then
		return grug_classes.talent_level_amount(player, key, total)
	end
	return total
end

-- 0..5; used by the kit grant, the gates and the UI, never by a numeric
-- consumer.
function grug_classes.talent_rank(player, talent_id)
	if not player or not player.is_player or not player:is_player() then
		return 0
	end
	return state(player).ranks[talent_id] or 0
end

function grug_classes.talent_points_spent(player)
	return state(player).spent
end

-- The central Core modifier has already resolved dodge, pressure, armor and
-- absorb when this non-modifier callback runs. Trigger only from a surviving
-- punch whose actual HP loss leaves the Warrior below 20%; environmental and
-- fully absorbed events never open the window.
core.register_on_player_hpchange(function(player, hp_change, reason)
	if hp_change >= 0 or reason.type ~= "punch" or
			grug_classes.talent_rank(player, "unbroken") <= 0 then
		return
	end
	local hp_after = player:get_hp() + hp_change
	local properties = player:get_properties() or {}
	local max_hp = tonumber(properties.hp_max) or 0
	if hp_after <= 0 or max_hp <= 0 or hp_after >= max_hp * 0.20 then
		return
	end
	local now = os.time()
	local meta = player:get_meta()
	if now < (tonumber(meta:get_string(META_UNBROKEN_READY)) or 0) then return end
	meta:set_string(META_UNBROKEN_READY, tostring(now + 180))
	grug_classes.start_talent_window(player, "unbroken", 8)
	grug_core.proc_flash(player, "unbroken")
	local inventory = rawget(_G, "grug_inventory")
	if inventory and inventory.refresh then inventory.refresh(player) end
end, false)

function grug_classes.talent_points_available(player)
	return grug_classes.talent_points_total(player)
		- grug_classes.talent_points_spent(player)
end

function grug_classes.tree_points(player, tree_id)
	return state(player).tree_points[tree_id] or 0
end

local talents_changed_callbacks = {}

-- func(player) -- called after any change to a character's talents (a spend,
-- a respec, an admin level drop). The mirror of register_on_class_chosen;
-- grug_abilities re-syncs the kit here once lane X3 grants talent abilities.
function grug_classes.register_on_talents_changed(func)
	table.insert(talents_changed_callbacks, func)
end

local function commit(player, ranks)
	player:get_meta():set_string(META_TALENTS, serialize(ranks))
	cache[player:get_player_name()] = nil
	for _, func in ipairs(talents_changed_callbacks) do
		func(player)
	end
end

--
-- Spending, and the refusal reasons the UI shows.
--

-- Returns true, or false plus the reason a point cannot go here.
function grug_classes.can_spend_talent(player, talent_id)
	local def = grug_classes.registered_talents[talent_id]
	if not def then
		return false, "No such talent."
	end
	local class_id = grug_classes.get_class(player)
	if not class_id then
		return false, "You have no class yet."
	end
	if not talent_of_class(def, class_id) then
		return false, def.name .. " belongs to another class."
	end
	if grug_classes.talent_points_available(player) < 1 then
		return false, "No talent points left."
	end
	local rank = grug_classes.talent_rank(player, talent_id)
	if rank >= def.ranks then
		return false, def.name .. " is already at " .. def.ranks .. "/" ..
			def.ranks .. "."
	end
	local tree = grug_classes.registered_trees[def.tree]
	local gate = grug_classes.TALENT_TIER_GATES[def.tier]
	local in_tree = grug_classes.tree_points(player, def.tree) - rank
	if in_tree < gate then
		return false, def.name .. " needs " .. gate .. " points in " ..
			tree.name .. " (you have " .. in_tree .. ")."
	end
	local above = talent_above(def)
	if above and grug_classes.talent_rank(player, above.id) < above.ranks then
		return false, def.name .. " needs " .. above.name .. " at " ..
			above.ranks .. "/" .. above.ranks .. "."
	end
	return true
end

function grug_classes.spend_talent(player, talent_id)
	local ok, reason = grug_classes.can_spend_talent(player, talent_id)
	if not ok then
		return false, reason
	end
	local entry = state(player)
	local ranks = {}
	for id, rank in pairs(entry.ranks) do
		ranks[id] = rank
	end
	ranks[talent_id] = (ranks[talent_id] or 0) + 1
	commit(player, ranks)
	return true
end

-- A respec is a FULL reset (ruling 20): every rank to 0, all points back.
-- Pricing and the money transaction live on the sfinv page; this function is
-- the deterministic reset used there and by the free admin level-drop path.
function grug_classes.respec(player)
	local spent = grug_classes.talent_points_spent(player)
	grug_classes.clear_talent_windows(player)
	commit(player, {})
	return spent
end

--
-- Level changes (§3.6 and ruling 20's last bullet). Called from the existing
-- grug_xp level-change registration in stats.lua, so the order against
-- apply_stats is fixed rather than incidental.
--
-- A level drop would otherwise leave more ranks spent than floor(level / 2)
-- allows. Only a direct grug_xp.set_xp to less XP lowers a level (/xp only
-- grants XP; no game path takes any away). Rather than blocking spends or
-- refunding cheapest-first, the talent state is wiped and every point
-- returned -- free, because no player action can lower a level and the
-- simplest correct behaviour wins.
function grug_classes.on_level_change_talents(player, old_level, new_level)
	cache[player:get_player_name()] = nil
	if old_level == nil then
		return
	end
	if new_level < old_level then
		-- The stored total, not the re-parsed one: the cache was dropped a
		-- few lines up, so talent_points_spent would already have been
		-- trimmed to floor(new_level / 2) and a big drop would under-report
		-- what it wiped.
		local spent = 0
		for _, rank in pairs(scan_stored_ranks(player)) do
			spent = spent + rank
		end
		if spent > 0 then
			grug_classes.respec(player)
			grug_core.feed(player, "quest", "Your level dropped: all " .. spent ..
				" talent points were returned.", "talents")
		end
		return
	end
	-- old_level is nil on join (grug_xp/init.lua:32-33). Arithmetic on nil
	-- here would error on every single join, which is why the guard above is
	-- not optional.
	if grug_classes.talent_points_at(new_level)
			> grug_classes.talent_points_at(old_level) then
		local left = grug_classes.talent_points_available(player)
		if left > 0 then
			-- In the message feed beside the level-up's XP line, never chat.
			grug_core.feed(player, "quest", "Talent point earned - " .. left ..
				" to spend. Open the Talents & Skills tab.", "talents")
		end
	end
end

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	grug_classes.clear_talent_windows(player)
	cache[name] = nil
end)

-- A character's FIRST class pick at creation is not a class change (ruling 20
-- removed those), but it does decide which talents are the character's at all,
-- and the parsed cache may already exist from a read taken before it. One
-- invalidation is cheaper than reasoning about whether such a read can happen.
grug_classes.register_on_class_chosen(function(player)
	cache[player:get_player_name()] = nil
end)

core.register_on_dieplayer(function(player)
	grug_classes.clear_talent_windows(player)
end)

--
-- Read-only chat summary. Buying ranks and resetting a build live exclusively
-- on the sfinv Talents page; no command can mutate talent state.
--

local function tree_line(player, tree)
	return ("%s [%d]"):format(tree.name, grug_classes.tree_points(player, tree.id))
end

local function talent_line(player, def)
	local rank = grug_classes.talent_rank(player, def.id)
	local mark = " "
	if def.keystone then
		mark = "*"
	elseif def.capstone then
		mark = "!"
	end
	local line = ("  %s %-16s %d/%d  %s"):format(mark, def.id, rank,
		def.ranks, def.name)
	if rank < def.ranks then
		local ok, reason = grug_classes.can_spend_talent(player, def.id)
		if not ok then
			line = line .. "  (" .. reason .. ")"
		end
	end
	return line
end

core.register_chatcommand("talents", {
	params = "",
	description = "Show a read-only summary of your talent trees",
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "You must be online."
		end
		local class_id = grug_classes.get_class(player)
		if not class_id then
			return false, "You have no class yet."
		end
		local lines = {
			("%s - %d talent points, %d spent, %d left"):format(
				grug_classes.registered_classes[class_id].name,
				grug_classes.talent_points_total(player),
				grug_classes.talent_points_spent(player),
				grug_classes.talent_points_available(player)),
		}
		for _, tree in ipairs(grug_classes.trees_of_class(class_id)) do
			lines[#lines + 1] = tree_line(player, tree)
			for _, chain in ipairs(tree.chains) do
				for _, def in ipairs(tree.talents) do
					if def.chain == chain then
						lines[#lines + 1] = talent_line(player, def)
					end
				end
			end
		end
		lines[#lines + 1] =
			"* keystone, ! capstone. Open the Talents & Skills tab to make changes."
		return true, table.concat(lines, "\n")
	end,
})

-- FIRST talents-changed consumer, and the reason the callback exists at all.
-- `grug_classes.apply_stats` is the only writer of a player's `hp_max`
-- (stats.lua), and until this line it ran on an equipment change, a level
-- change and the class pick only -- so Weathered raised get_max_hp while the
-- character's actual ceiling stayed where it was until something else moved
-- it, and a respec left the raised ceiling behind.
--
-- Registered HERE rather than from stats.lua, which is dofile'd before this
-- file and would find no callback to register on; and registered first, so a
-- later consumer (lane X3's sync_kit, which has to take a talent-granted
-- button back on a respec) reads stats that are already current -- the same
-- ordering rule stats.lua states for the equipment-change seam.
--
-- Deliberately WITHOUT heal_gain: spending a point must not hand out free
-- health, and apply_stats already clamps current HP down when a respec lowers
-- the maximum.
grug_classes.register_on_talents_changed(function(player)
	grug_classes.apply_stats(player)
end)

-- Stub override (same pattern as grug_core.get_race_perk): mods below
-- grug_classes in the dependency graph read talents through grug_core.
grug_core.get_talent_bonus = grug_classes.get_talent_bonus
