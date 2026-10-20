-- The MVP class kits (docs/design/classes.md §3–§5). Numbers live in the
-- design doc — change them there first.

--
-- Targeting helpers. Hostile casts use one current server eye/look ray;
-- pointed_thing and target memory are presentation context only. Every
-- activation resolves its current visible target on the server.
--

local function mob_ent(obj)
	if obj:is_player() then
		return nil
	end
	local ent = obj:get_luaentity()
	return (ent and ent._cmi_is_mob) and ent or nil
end

local function valid_ally(user, obj, def)
	return grug_abilities.valid_target(user, obj, def.target_kind)
end

local function debug_cast_ray(user, def, ray)
	local name = user:get_player_name()
	if not grug_core.combat_debug_enabled(name) then
		return
	end
	if not grug_core.combat_debug_due(name, "cast:ray", 0.1) then
		return
	end
	local target = ray.target
	local target_name = "none"
	if target then
		if target:is_player() then
			target_name = "player:" .. target:get_player_name()
		else
			local ent = target:get_luaentity()
			target_name = "entity:" .. (ent and ent.name or "unknown")
		end
	end
	grug_core.combat_debug_log(name, "cast_ray",
		"ability=" .. def.id .. " status=" .. tostring(ray.status) ..
		" reason=" .. tostring(ray.reason) .. " target=" .. target_name ..
		" distance=" .. tostring(ray.distance or "none") ..
		" range=" .. tostring(ray.range or "none"))
end

-- The one aim authority of a targeted skill, free of side effects: one current
-- server ray to the skill's effective range, then the skill's own target rule.
-- A friendly skill needs a pointed ally ("friendly" ray reason); every other
-- kind needs a ray "target" (a live hostile). Returns the target (or nil) and
-- the structured ray. The casts below add Target Frame memory and diagnostics;
-- the crosshair overlay (crosshair.lua) reads it bare, about 7 times a second,
-- and passes the eye position it already computed as `origin`.
function grug_abilities.aimed_target(user, def, origin)
	local ray = grug_core.combat_ray(user, grug_abilities.get_range(user, def),
		origin and {origin = origin} or nil)
	local target = ray.target
	if def.target_kind == "friendly" then
		if ray.reason ~= "friendly" then target = nil end
	elseif ray.status ~= "target" then
		target = nil
	end
	if target and not valid_ally(user, target, def) then
		target = nil
	end
	return target, ray
end

-- One current server ray owns direct hostile casts. The structured result is
-- reused for diagnostics; enemy memory is written for the Target Frame but is
-- never read here.
local function current_enemy_target(user, def)
	local target, ray = grug_abilities.aimed_target(user, def)
	debug_cast_ray(user, def, ray)
	if not target then
		return nil
	end
	grug_abilities.set_target(user, target, false)
	return target
end

-- A current visible ally receives support; aim at no ally resolves to self.
-- An aimed ally the PvP flag forbids (an unflagged helper, a flagged ally:
-- pvp-plan ruling 6) is a refusal, never a self-cast (Round 31 ruling 9):
-- nil plus the reason, so try_cast spends nothing. The shared ray checks
-- exact selection-box range and solid blockers. Neither a stale client
-- pointed reference nor Target Frame memory grants authority.
grug_abilities.SUPPORT_REFUSED = "You must be flagged for PvP to support a flagged ally."

function grug_abilities.support_refused(user, obj)
	return obj ~= nil and obj ~= user and obj:is_player() and obj:get_hp() > 0
		and grug_factions.same_faction(user, obj)
		and not grug_pvp.can_support(user, obj)
end

function grug_abilities.resolve_friendly_target(user, pointed, def)
	local target, ray = grug_abilities.aimed_target(user, def)
	if target then
		grug_abilities.set_target(user, target, true)
		return target
	end
	if ray.reason == "friendly" and grug_abilities.support_refused(user, ray.target) then
		return nil, grug_abilities.SUPPORT_REFUSED
	end
	return user
end

-- Tooltips show the central pipeline's current-level value before crit and
-- target-level malus. Casts keep passing the unscaled value returned by each
-- definition's values() accessor into the real settlement seam, so the
-- formula exists in exactly one place and a later balance pass changes no UI
-- plumbing.
local function effective_number(player, amount)
	return grug_core.scale_player_damage(player, nil, amount)
end

-- Healing and absorb definitions already return a current-level absolute
-- amount derived from the class-neutral base pool. The central support seam is
-- therefore an identity: applying level_scale here would square progression.
local function effective_support_number(amount)
	return math.floor(amount)
end

-- Not rounded here: deal_ability_damage floors once after the level scalar,
-- like Loose and every swing (Round 36).
local function spell_damage_value(player, amount)
	local percent = grug_classes.get_spell_damage_percent(player)
	return amount * (1 + percent / 100)
end

-- The item level of the caster weapon (a staff or a wand) in the Weapon
-- slot, nil without one; get_equipped_weapon already drops a broken or
-- unusable stack. Upgrades and the crown count (grug_items.effective_ilvl).
-- Public: the caster talent amounts read it too (grug_classes talents.lua).
function grug_abilities.caster_weapon_ilvl(player)
	local weapon = grug_core.get_equipped_weapon(player)
	if not weapon or weapon:is_empty() then
		return nil
	end
	local def = weapon:get_definition() or {}
	local groups = def.groups or {}
	if (groups.staff or 0) <= 0 and (groups.wand or 0) <= 0 and
			(groups.grug_caster_weapon or 0) <= 0 then
		return nil
	end
	local items = rawget(_G, "grug_items")
	return items and items.effective_ilvl(weapon) or tonumber(def._grug_ilvl)
end

-- Fireball's, Ice Nova's and Smite's base before spell power (Round 46
-- ruling 10): half from the level, half from the caster weapon.
function grug_abilities.spell_base(player)
	return grug_core.spell_base(grug_core.get_player_level(player),
		grug_abilities.caster_weapon_ilvl(player))
end

-- Heal, Mend, Shield, Recompense and Glacial Ward: a share of the base pool
-- times the support factor (gear Intelligence, grug_classes stats.lua).
local function support_value(player, percent)
	local base = grug_core.base_pool(grug_core.get_player_level(player))
	return base * percent / 100 * grug_classes.get_support_factor(player)
end

--
-- Particle effects: the catalogue in grug_core/particle_effects.lua, played
-- through grug_core.particles (Round 40). Every call sits where the skill
-- really fired -- after a cast's last refusal, in a proc's landed post --
-- never on the Strike fallback (round40-plan.md §2.4).
--

local function fx(id, frame)
	grug_core.particles.play(id, frame)
end

local function facing(player)
	return grug_core.particles.facing(player)
end

--
-- Universal authoritative swing (classes.md §2b, combat_stats.md §2).
--
-- Swing ability items intentionally have NO on_use. Luanti therefore keeps
-- direct object acquisition and first-person held animation; init.lua restores
-- ground-level dropped-loot pickup on a bounded server ray because the no-dig
-- pointabilities can mask its native selection box. Enemy packets are
-- zero-damage input only; init.lua latches a direct click once and runs held
-- repeats against the soft lock on the shared equipped-weapon clock. Every due
-- attack is one full slot-fed swing, with the selected charged proc folded into
-- that one accepted transaction.
--

-- An empty weapon slot is an empty slot (B1): no fallback to whatever is in
-- the hand, and the swing is a fist (C2: an empty slot makes skills weak, never
-- uncastable).
--
-- "A fist" is not a number to pick — it is THIS game's hand item, and the
-- engine's own bare-handed punch reads exactly these capabilities. The
-- numbers are 0.9 / fleshy 1, and they come from ONE place: this game's own
-- `mods/BASE/default/tools.lua:8-19`, which overrides the hand item. The
-- engine itself supplies neither — builtin's hand
-- (reference_projects/luanti/builtin/game/register.lua:447-451) carries no
-- `tool_capabilities` at all, and the C++ fallback is full_punch_interval
-- **1.4** with an empty damage-group map (src/tool.h:60-72). So a hardcoded
-- 1.0 made an empty slot swing 11 % SLOWER through the Strike than the same
-- character punching bare-handed through the held-button path, for no reason
-- anyone could have found in a design doc — and reading the value is what
-- keeps the two paths equal if default's hand is ever re-tuned.
-- `ItemStack("")` is the hand: an empty stack resolves to the "" item
-- definition, which is what the engine hands a punch that carries no tool.
--
-- Read once after every mod has registered, not at load time: default's
-- override_item runs in BASE and we are in PLAYER, but the ordering is a mod
-- dependency we do not declare, so the values are simply not final yet here.
-- The literals below are the fallback if the hand ever loses its capabilities.
local bare_hand = {damage = 1, interval = 0.9}

core.register_on_mods_loaded(function()
	local caps = ItemStack(""):get_tool_capabilities() or {}
	local damage = caps.damage_groups and caps.damage_groups.fleshy
	if type(damage) == "number" and damage >= 0 then
		bare_hand.damage = damage
	end
	local fpi = caps.full_punch_interval
	if type(fpi) == "number" and fpi > 0 then
		bare_hand.interval = fpi
	end
end)

-- What the melee weapon (grug_core.get_melee_weapon: a Scout's Melee slot,
-- everyone else's Weapon slot) is worth for one authoritative full swing:
-- fleshy damage and the shared soft-lock clock interval.
--
-- Read during kit/equipment synchronization, clock validation and proc
-- preparation. Callers that already fetched the equipped stack pass that copy
-- to avoid a duplicate slot/cache read. Unequipping drops every swing to the
-- bare-hand baseline; swapping a weapon updates the granted stacks before the
-- next authoritative attempt.
-- grug_inventory caches the slot itself, so this costs one ItemStack copy.
--
-- get_tool_capabilities() resolves the per-stack meta override before the item
-- definition, which is how WP5's rolled attack-speed affix will reach this
-- without a line of change here.
function grug_abilities.swing_stats(player, equipped)
	local stack = equipped
	if stack == nil then
		stack = grug_core.get_melee_weapon(player)
	end
	if not stack or stack:is_empty() then
		return bare_hand.damage, bare_hand.interval
	end
	local caps = stack:get_tool_capabilities() or {}
	local damage = caps.damage_groups and caps.damage_groups.fleshy or 0
	local fpi = caps.full_punch_interval
	-- A non-positive interval would break the authoritative attack clock.
	-- Nothing equippable declares one -- but the interval comes out of item
	-- meta, and meta is data.
	if type(fpi) ~= "number" or fpi <= 0 then
		fpi = bare_hand.interval
	end
	return damage, fpi
end

-- The melee weapon's BASE swing interval (Round 46 ruling 9): its item
-- definition's, before the attack-speed enchant shortens the stack's copy;
-- the bare hand's without a weapon. A landed swing's rage scales with it.
function grug_abilities.base_swing_interval(player, equipped)
	local stack = equipped
	if stack == nil then
		stack = grug_core.get_melee_weapon(player)
	end
	if not stack or stack:is_empty() then
		return bare_hand.interval
	end
	local caps = (stack:get_definition() or {}).tool_capabilities or {}
	local fpi = caps.full_punch_interval
	if type(fpi) ~= "number" or fpi <= 0 then
		return bare_hand.interval
	end
	return fpi
end

-- Working title kept from the design file. Deliberately a plain English verb,
-- not an ability name from an existing commercial game.
local strike_description = "A full melee swing with your equipped weapon. " ..
	"Hold LMB and keep a hostile in your crosshair; the shared weapon clock " ..
	"prevents click spam."

local strike_def = {
	id = "strike",
	kind = "swing",
	target_kind = "hostile",
	universal = true, -- every class, and a character with no class yet (E1)
	name = "Strike",
	description = strike_description,
	description_for = function(player)
		local class_def = grug_classes.get_class_def(player)
		if not class_def or class_def.resource ~= "rage" then
			return strike_description
		end
		-- The equipped weapon's grant per hit (ruling 9), one decimal.
		local rage = ("%.1f"):format(grug_abilities.swing_rage(player))
		return strike_description .. " Generates " ..
			(rage:gsub("%.0$", "")) .. " rage when it lands."
	end,
	-- Bone white, deliberately neutral (E8): the four class colours carry the
	-- ability identities and a fifth colour would compete with them. With an
	-- empty weapon slot the item falls back to this orb, which reads correctly
	-- as "you are punching with your fists".
	color = "#d9d3c0",
	cost = {}, -- no resource cost: it is what GENERATES the resource
	-- Melee, so the elf's +5 m ability range does not apply (E7) -- it would
	-- otherwise hand elves an 8 m sword.
	melee = true,
	range = 3,
	-- A blade attack for the family keys (Fine Edge's damage_pct:blade);
	-- only the Scout's vocabulary names the tag.
	tags = {"blade"},
}
grug_abilities.register_ability(strike_def)

--
-- The class kits, one file per class (Round 52): kits_warrior.lua,
-- kits_mage.lua and kits_priest.lua. Each returns a function that takes the
-- shared helpers above as K, so no file adds a global. A file's order is its
-- class's ability order (grug_abilities.by_class: the catalogue row and the
-- initial hotbar), so a talent-gated skill goes at the END of its file.
--
-- WP11 X3 talent-granted active skills. Entitlement is owned by the Skills
-- catalog through `talent_gated`; registering these definitions never inserts
-- or recreates an inventory representation.
--

local K = {
	mob_ent = mob_ent,
	debug_cast_ray = debug_cast_ray,
	current_enemy_target = current_enemy_target,
	effective_number = effective_number,
	effective_support_number = effective_support_number,
	spell_damage_value = spell_damage_value,
	support_value = support_value,
	fx = fx,
	facing = facing,
	-- Round 53: the family keys (damage_pct, radius_add, duration_add ...)
	-- and the area filter.
	family_bonus = grug_abilities.family_bonus,
	target_filter = grug_abilities.target_filter,
}
dofile(core.get_modpath(core.get_current_modname()) .. "/kits_warrior.lua")(K)
dofile(core.get_modpath(core.get_current_modname()) .. "/kits_mage.lua")(K)
dofile(core.get_modpath(core.get_current_modname()) .. "/kits_priest.lua")(K)
