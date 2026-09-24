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

-- One current server ray owns direct hostile casts. The structured result is
-- reused for diagnostics; enemy memory is written for the Target Frame but is
-- never read here.
local function current_enemy_target(user, def)
	local ray = grug_core.combat_ray(user, grug_abilities.get_range(user, def))
	debug_cast_ray(user, def, ray)
	if ray.status ~= "target" then
		return nil
	end
	if not grug_abilities.valid_target(user, ray.target, def.target_kind) then
		return nil
	end
	grug_abilities.set_target(user, ray.target, false)
	return ray.target
end

-- A current visible ally receives support; all other aim resolves to self.
-- The shared ray checks exact selection-box range and solid blockers. Neither
-- a stale client pointed reference nor Target Frame memory grants authority.
function grug_abilities.resolve_friendly_target(user, pointed, def)
	local ray = grug_core.combat_ray(user, grug_abilities.get_range(user, def))
	if ray.target and ray.reason == "friendly" and valid_ally(user, ray.target, def) then
		grug_abilities.set_target(user, ray.target, true)
		return ray.target
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

local function spell_damage_value(player, amount)
	local percent = grug_classes.get_spell_damage_percent(player)
	return math.floor(amount * (1 + percent / 100) + 0.5)
end

local function support_value(player, percent)
	local base = grug_core.base_pool(grug_core.get_player_level(player))
	local spell_power_percent = grug_classes.get_spell_power_bonus(player)
	return base * percent / 100 * (1 + spell_power_percent / 100)
end

--
-- Particle helpers (existing textures only; own effects are Phase 3).
--

local function beam(user, target, texture)
	local from = user:get_pos()
	from.y = from.y + (user:get_properties().eye_height or 1.5)
	local to = vector.offset(target:get_pos(), 0, 1, 0)
	local dist = vector.distance(from, to)
	local steps = math.max(2, math.floor(dist * 2))
	local dir = vector.direction(from, to)
	for i = 1, steps do
		core.add_particle({
			pos = vector.add(from, vector.multiply(dir, i * dist / steps)),
			velocity = vector.new(0, 0, 0),
			expirationtime = 0.25,
			size = 2.5,
			texture = texture,
			glow = 12,
		})
	end
end

local function burst(pos, texture, amount)
	core.add_particlespawner({
		amount = amount or 12,
		time = 0.2,
		-- NB `radius` is not a particlespawner field — spread via pos range.
		pos = {min = vector.offset(pos, -0.5, 0, -0.5),
			max = vector.offset(pos, 0.5, 1, 0.5)},
		vel = {min = vector.new(-2, 0, -2), max = vector.new(2, 3, 2)},
		exptime = {min = 0.3, max = 0.7},
		size = {min = 1.5, max = 3},
		texture = texture,
		glow = 10,
	})
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

-- What the equipped weapon is worth for one authoritative full swing: fleshy
-- damage and the shared soft-lock clock interval.
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
		stack = grug_core.get_equipped_weapon(player)
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

-- Working title kept from the design file. Deliberately a plain English verb,
-- not a Blizzard ability name.
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
		return strike_description .. " Generates " ..
			grug_abilities.swing_rage(player) .. " rage when it lands."
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
}
grug_abilities.register_ability(strike_def)

--
-- Warrior (rage; all abilities count as tank abilities: threat ×3)
--

grug_abilities.register_ability({
	id = "charge",
	class = "warrior",
	name = "Charge",
	kind = "cast",
	target_kind = "hostile",
	description = "Dash to an enemy up to 12 m away; damage scales with your level\n" ..
		"generating 15 rage and stunning eligible targets for 1.5 s.",
	values = function(user)
		return {damage = 3}
	end,
	description_for = function(user, def)
		return ("Dash to an enemy up to 12 m away, dealing %d damage\n" ..
			"generating 15 rage and stunning eligible targets for 1.5 s."):format(
				effective_number(user, def.values(user).damage))
	end,
	color = "#e8c85a",
	cost = {},
	cooldown = 10,
	-- Onset (skill_trees.md §2.2). The field names the effect key; the read
	-- itself is grug_abilities.effective_cooldown, because `cooldown` here is
	-- evaluated once at load time with no player in scope (§3.2).
	cooldown_talent = "charge_cooldown_sub",
	range = 12,
	cast = function(user, pointed, def)
		local target = current_enemy_target(user, def)
		if not target then
			return false, "No hostile target in your crosshair."
		end
		local tpos = target:get_pos()
		local dir = vector.direction(tpos, user:get_pos())
		local dest = vector.add(tpos, vector.multiply(dir, 1.3))
		dest.y = tpos.y
		grug_core.invalidate_combat_identity(user)
		user:set_pos(dest)
		grug_abilities.add_rage(user, 15)
		grug_core.deal_ability_damage(user, target,
			def.values(user).damage, {threat_mult = 3, on_accepted = function()
				if target:is_player() then
					grug_core.set_stun(target, 1.5)
				else
					local ent = mob_ent(target)
					if ent then grug_mobs.stun(ent, 1.5) end
				end
			end})
		return true
	end,
})

-- The rage dump (kit tuning 2026-08-06): no own cooldown — at the rage
-- income of the day a cooldown left the Warrior permanently rage-capped.
-- Ruling 25 (2026-09-16) lowered that income to 8 per landed swing, so
-- this now procs about every fourth swing rather than every other one.
grug_abilities.register_ability({
	id = "mighty_blow",
	kind = "swing",
	target_kind = "hostile",
	class = "warrior",
	name = "Mighty Blow",
	description = "A heavy melee hit: 150% weapon damage plus your melee bonus. Rides along on a landed swing whenever you have the rage.",
	color = "#c84a32",
	cost = {rage = 25},
	-- Melee at 3 m, so the elf's +5 m ability range does not apply (E7). This
	-- was a PRE-EXISTING bug, not something the weapon slot introduced: the
	-- perk was written as "+5 m on every ability" and gave elves an 8 m reach on
	-- a hit that is supposed to be within arm's length. The flag is all it
	-- takes -- grug_abilities.get_range honours it, and sync_kit derives the
	-- stack's `range` meta from get_range, so the engine's pointing reach and
	-- the target-lock fallback move together.
	melee = true,
	range = 3,
	-- The proc REPLACES the plain hit (classes.md §3): floor(weapon x 1.5) +
	-- melee bonus, x3 threat. No charge timer -- the rage cost IS the limiter
	-- (about every fourth swing at the ruling-25 income of +8 per landed
	-- hit; it was every other swing at the old +12).
	proc_swing = function(user, target, ctx)
		local tpos = target:get_pos() -- before the punch (lethal invalidates refs)
		-- Heavy Hand (skill_trees.md §2.2): +0.05 weapon-damage multiplier per
		-- rank; 1.5 exactly without it. Broadstroke's cleave is lane X3's.
		local mult = 1.5 + 0.05 * grug_classes.get_talent_bonus(user,
			"mighty_blow_multiplier_add")
		local damage = math.floor(ctx.weapon_damage * mult) + ctx.melee_bonus
		return damage, 3, function(action_id)
			burst(tpos, "mobs_blood.png", 6)
			if grug_classes.get_talent_bonus(user, "mighty_blow_cleave") > 0 then
				for _, obj in ipairs(core.get_objects_inside_radius(tpos, 3)) do
					if obj ~= target and grug_abilities.valid_target(user, obj, "hostile") then
						grug_core.deal_ability_damage(user, obj,
							math.floor(damage / 2), {threat_mult = 3, action_id = action_id})
					end
				end
			end
			grug_classes.try_trigger_talent_window(user, "ruination", 10, 120)
		end
	end,
})

-- The control tool (kit tuning 2026-08-06): in an engine where mobs
-- outrun players, the snare is the Warrior's identity.
--
-- TALENT-GATED since ruling 19 (2026-09-16, skill_trees.md §2.2/§3.4): every
-- class starts with Strike plus three, so Hamstring leaves the Warrior's base
-- kit and returns as Ruin's new-skill keystone. Until lane X3 wires the grant,
-- NO Warrior has it -- the same predicate that has kept Renew out of the kit
-- since WP19 keeps this one out too.
grug_abilities.register_ability({
	id = "hamstring",
	kind = "swing",
	target_kind = "hostile",
	class = "warrior",
	name = "Hamstring",
	talent_gated = true,
	description = "A landed swing cripples: slows the enemy by 50% for 5 s. Charges over 6 s.\nUnlocked via talents.",
	color = "#a8324e",
	charge = 6,
	cost = {rage = 10},
	-- Melee at 3 m: same pre-existing elf-range bug as Mighty Blow above, same
	-- one-flag fix (E7).
	melee = true,
	range = 3,
	-- The swing lands as usual; the proc adds the slow (classes.md §3).
	-- `post` runs only on a LANDED swing, so a dodged Hamstring does not
	-- snare (the old cast's dealt > 0 gate).
	proc_swing = function(user, target, ctx)
		local ent = mob_ent(target)
		local tpos = target:get_pos()
		return ctx.weapon_damage + ctx.melee_bonus, 3, function()
			local slow_time = 5 + grug_classes.get_talent_bonus(user,
				"hamstring_slow_add")
			local root_time = grug_classes.get_talent_bonus(user, "hamstring_root")
			if root_time > 0 and not grug_classes.talent_trigger_ready(user,
					"tendon_cut", 12) then root_time = 0 end
			if ent then
				if root_time > 0 then grug_mobs.root(ent, root_time) end
				grug_mobs.slow(ent, slow_time, 0.5)
			elseif target:get_hp() > 0 then
				if root_time > 0 then grug_core.set_root(target, root_time) end
				grug_core.set_move_modifier(target, "hamstring", {speed = -0.5},
					root_time + slow_time)
			end
			burst(tpos, "mobs_blood.png", 4)
		end
	end,
})

grug_abilities.register_ability({
	id = "taunt",
	class = "warrior",
	name = "Taunt",
	kind = "cast",
	target_kind = "hostile",
	description = "Forces the target mob to attack you.",
	color = "#e07b39",
	cost = {},
	cooldown = 8,
	cooldown_talent = "taunt_cooldown_sub", -- Grudge (skill_trees.md §2.1)
	range = 8,
	cast = function(user, pointed, def)
		local radius = grug_classes.get_talent_bonus(user, "taunt_radius")
		if radius > 0 then
			local affected = false
			for _, obj in ipairs(core.get_objects_inside_radius(user:get_pos(), radius)) do
				if grug_abilities.valid_target(user, obj, "hostile") then
					local ent = mob_ent(obj)
					if ent and ent.attack_type and grug_core.taunt(ent, user) then
						ent:do_attack(user, true); affected = true
					end
				end
			end
			return affected, affected and nil or "No hostile target in range."
		end
		local target = current_enemy_target(user, def)
		if not target then
			return false, "No hostile target in your crosshair."
		end
		local ent = mob_ent(target)
		if not ent or not ent.attack_type then
			return false, "Cannot be taunted."
		end
		-- Threat part (combat_stats.md §4): sets the taunter to top×1.1 and
		-- suppresses hysteresis target switches for 3 s.
		if not grug_core.taunt(ent, user) then
			return false, "That target is evading."
		end
		ent:do_attack(user, true)
		burst(target:get_pos(), "default_item_smoke.png^[multiply:#e07b39", 6)
		return true
	end,
})

--
-- Mage (mana)
--

local fireball_action_serial = 0

local function talent_rank_value(user, talent_id, effect_key, fallback)
	local def = grug_classes.registered_talents[talent_id]
	local rank = grug_classes.talent_rank(user, talent_id)
	local values = def and def.effects and def.effects[effect_key]
	return values and values[rank] or fallback
end

grug_projectiles.register("fireball", {
	speed = 20,
	max_distance = 20,
	-- A flight lasts one second and the server accepts at most one cast per
	-- second. Eight leaves room for latency/session overlap while still bounding
	-- stale shots per owner/session independently of the cast cadence.
	active_limit = 8,
	properties = {
		is_visible = true,
		visual = "sprite",
		textures = {"mobs_fire_particle.png"},
		visual_size = {x = 0.7, y = 0.7},
		glow = 12,
	},
	on_hit = function(owner, target, data, point, attacker_level)
		grug_core.deal_ability_damage(owner, target, data.damage,
			{attacker_level = attacker_level, action_id = data.action_id,
				on_accepted = function(_, critical)
					if not critical then return end
					grug_classes.try_trigger_talent_window(owner,
						"whitehot", talent_rank_value(owner, "whitehot",
							"whitehot_window", 8), 120)
				end})
		local splash = data.splash or 0
		if splash > 0 then
			for _, obj in ipairs(core.get_objects_inside_radius(point, 2)) do
				if obj ~= target and grug_abilities.valid_target(owner, obj, "hostile") then
					grug_core.deal_ability_damage(owner, obj, data.splash_damage,
						{attacker_level = attacker_level, action_id = data.action_id})
				end
			end
		end
	end,
})

-- Bread-and-butter nuke (kit tuning 2026-08-06): pays with mana plus a
-- server-authoritative one-second cast cadence instead of a talent-visible
-- cooldown. Release locks the current crosshair target; enemy memory is never aim.
local function fireball_values(user)
	local window = grug_classes.talent_window_active(user, "whitehot") and 6 or 0
	return {
		damage = spell_damage_value(user,
			grug_core.baseline_weapon_damage(
				grug_core.get_player_level(user))
			+ grug_classes.get_spell_power_bonus(user)
			+ grug_classes.get_talent_bonus(user, "fireball_damage_add") + window),
	}
end

grug_abilities.register_ability({
	id = "fireball",
	class = "mage",
	name = "Fireball",
	kind = "cast",
	target_kind = "hostile",
	description = "Hurls fire along your crosshair for up to 20 m;\n" ..
		"damage scales with your level; requires a visible hostile target.",
	values = fireball_values,
	description_for = function(user, def)
		return ("Hurls fire along your crosshair for up to 20 m:\n" ..
			"%d damage; requires a visible hostile target."):format(
				effective_number(user, def.values(user).damage))
	end,
	color = "#ff8833",
	cost = {mana_percent = 6},
	cooldown = 0,
	cast_interval = 1,
	range = 20,
	-- Far Cast (skill_trees.md §2.3) re-tunes a RANGE, so it cannot live in
	-- the field above: get_range reads this key per player, and sync_kit's
	-- per-stack `range` meta override follows it (§3.2).
	range_talent = "fireball_range_add",
	cast = function(user)
		local origin = grug_core.combat_eye_pos(user)
		local direction = user:get_look_dir()
		if not origin or not direction then
			return false, "Cannot determine your aim."
		end
		fireball_action_serial = fireball_action_serial + 1
		local action_id = user:get_player_name() .. ":fireball:" ..
			tostring(fireball_action_serial)
		local repair = rawget(_G, "grug_repair")
		local repair_receipt = repair and repair.capture_action(user, action_id)
		local spawned = grug_projectiles.spawn("fireball", {
			owner = user,
			origin = origin,
			direction = direction,
			max_distance = 20 + grug_classes.get_talent_bonus(user,
				"fireball_range_add")
				+ (grug_classes.get_race_perk(user, "ability_range_bonus") or 0),
			data = {
				-- Primary and Brand damage snapshot complete spell formulas at launch.
				damage = fireball_values(user).damage,
				splash = grug_classes.get_talent_bonus(user, "fireball_splash"),
				splash_damage = spell_damage_value(user, grug_classes.get_talent_bonus(user,
					"fireball_splash") + math.floor(
					grug_classes.get_spell_power_bonus(user) / 2)),
				action_id = repair_receipt or action_id,
			},
		})
		if not spawned then
			if repair then repair.cancel_action(user, action_id) end
			return false, "The fireball could not be launched."
		end
		local name = user:get_player_name()
		if grug_core.combat_debug_enabled(name)
				and grug_core.combat_debug_due(name, "cast:fireball", 0.1) then
			grug_core.combat_debug_log(name, "cast_fireball",
				"spawned direction=" .. tostring(direction.x) .. "," ..
				tostring(direction.y) .. "," .. tostring(direction.z))
		end
		return true
	end,
})

-- The rotation pivot (kit tuning 2026-08-06): kiting IS the Mage fantasy
-- here — root, make distance, keep nuking, re-nova when it is back up.
local function nova_values(user)
	local control = grug_classes.get_talent_bonus(user, "control_damage_add")
	local power = grug_classes.get_spell_power_bonus(user)
	return {damage = spell_damage_value(user,
		(grug_core.baseline_weapon_damage(grug_core.get_player_level(user)) + power) / 4
		+ control + (control > 0 and math.floor(power / 2) or 0))}
end

grug_abilities.register_ability({
	id = "frost_nova",
	class = "mage",
	name = "Frost Nova",
	values = nova_values,
	kind = "cast",
	target_kind = "self",
	description = "Damages and roots enemies within 5 m for 4 s,\n" ..
		"then slows them by 50% for 3 s.",
	color = "#66b8ff",
	cost = {mana_percent = 10},
	cooldown = 12,
	range = 4,
	cast = function(user, pointed, def)
		local pos = user:get_pos()
		local ranged = grug_classes.get_talent_bonus(user, "frost_nova_ranged")
		if ranged > 0 then
			local target = current_enemy_target(user, {
				id = def.id, target_kind = "hostile", range = 20,
			})
			if not target then return false, "No hostile target in your crosshair." end
			pos = target:get_pos()
		end
		-- Deep Chill and Hoarfrost (skill_trees.md §2.4); 0 each without the
		-- talent, so the base 4 s root and 3 s slow remain exact.
		local root_time = 4 + grug_classes.get_talent_bonus(user,
			"frost_nova_root_add")
		local slow_time = 3 + grug_classes.get_talent_bonus(user,
			"frost_nova_slow_add")
		local radius = ranged > 0 and ranged or 5
		local action_id = {}
		for _, obj in ipairs(core.get_objects_inside_radius(pos, radius)) do
			if grug_abilities.valid_target(user, obj, "hostile") then
				-- Capture before lethal mob punches can synchronously remove the object.
				local ent = mob_ent(obj)
				grug_core.deal_ability_damage(user, obj, nova_values(user).damage, {
					action_id = action_id,
					on_accepted = function()
						if obj:is_player() then
							if obj:get_hp() <= 0 then return end
							if grug_core.set_root(obj, root_time) then
								grug_core.mark_nova_root(obj, root_time)
							end
							grug_core.set_move_modifier(obj, "frost_nova_slow",
								{speed = -0.5}, root_time + slow_time)
						elseif ent and (ent.health or 0) > 0 and obj:get_pos() then
							grug_mobs.root(ent, root_time)
							ent._grug_nova_left = math.max(ent._grug_nova_left or 0, root_time)
							grug_mobs.slow(ent, slow_time, 0.5)
						end
					end,
				})
			end
		end
		burst(pos, "default_item_smoke.png^[multiply:#aaddff", 20)
		grug_core.mark_in_combat(user)
		return true
	end,
})

grug_abilities.register_ability({
	id = "blink",
	class = "mage",
	name = "Blink",
	kind = "cast",
	target_kind = "self",
	description = "Teleport up to 10 m in your look direction\n" ..
		"(blocked by walls).",
	color = "#b06aff",
	cost = {mana_percent = 8},
	cooldown = 15,
	cooldown_talent = "blink_cooldown_sub", -- Quick Step (skill_trees.md §2.4)
	range = 4,
	cast = function(user)
		local eye_height = user:get_properties().eye_height or 1.5
		local from = user:get_pos()
		local eye = vector.offset(from, 0, eye_height, 0)
		local dir = user:get_look_dir()
		-- Far Step (skill_trees.md §2.4); 10 m exactly without the talent.
		local distance = 10 + grug_classes.get_talent_bonus(user,
			"blink_distance_add")
		local dest_eye = vector.add(eye, vector.multiply(dir, distance))
		local ray = core.raycast(eye, dest_eye, false, false)
		local hit = ray:next()
		if hit and hit.type == "node" then
			dest_eye = vector.subtract(hit.intersection_point,
				vector.multiply(dir, 0.7))
		end
		-- Feet position; back off along the ray until there is room.
		local dest = vector.offset(dest_eye, 0, -eye_height, 0)
		for _ = 1, 12 do
			local feet = core.get_node_or_nil(vector.round(dest))
			local head = core.get_node_or_nil(vector.round(
				vector.offset(dest, 0, 1, 0)))
			local function free(node)
				if not node then
					return false
				end
				local ndef = core.registered_nodes[node.name]
				return ndef and not ndef.walkable
			end
			if free(feet) and free(head) then
				burst(from, "default_item_smoke.png^[multiply:#b06aff", 10)
				grug_core.invalidate_combat_identity(user)
				user:set_pos(dest)
				burst(dest, "default_item_smoke.png^[multiply:#b06aff", 10)
				return true
			end
			dest = vector.subtract(dest, vector.multiply(dir, 0.75))
			if vector.distance(dest, from) < 0.8 then
				break
			end
		end
		return false, "No room to blink."
	end,
})

--
-- Priest (mana)
--

grug_abilities.register_ability({
	id = "smite",
	class = "priest",
	name = "Smite",
	kind = "cast",
	target_kind = "hostile",
	description = "Smites an enemy up to 20 m away; damage scales with your level.",
	values = function(user, assume_shielded)
		local damage = math.floor((grug_core.baseline_weapon_damage(
				grug_core.get_player_level(user))
			+ grug_classes.get_spell_power_bonus(user)) * 1.5 + 0.5)
			+ grug_classes.get_talent_bonus(user, "smite_damage_add")
		if assume_shielded == nil then
			assume_shielded = grug_core.get_absorb(user) > 0
		end
		if assume_shielded then
			damage = damage + grug_classes.get_talent_bonus(user,
				"smite_damage_while_shielded_add")
		end
		return {damage = spell_damage_value(user, damage)}
	end,
	description_for = function(user, def)
		local unshielded = effective_number(user,
			def.values(user, false).damage)
		local shielded = effective_number(user,
			def.values(user, true).damage)
		local suffix = ""
		if shielded > unshielded then
			suffix = (" (+%d while shielded)"):format(shielded - unshielded)
		end
		return ("Smites an enemy up to 20 m away for %d damage%s."):format(
			unshielded, suffix)
	end,
	color = "#ffd97a",
	cost = {mana_percent = 5},
	cooldown = 2,
	cooldown_talent = "smite_cooldown_sub", -- Swift Word (skill_trees.md §2.6)
	range = 20,
	cast = function(user, pointed, def)
		local target = current_enemy_target(user, def)
		if not target then
			return false, "No hostile target in your crosshair."
		end
		beam(user, target, "default_item_smoke.png^[multiply:#ffe9a0")
		burst(target:get_pos(), "default_item_smoke.png^[multiply:#ffe9a0")
		-- Sharpened Word, and Warded Wrath while an absorb is up
		-- (skill_trees.md §2.6). Recompense's absorb is lane X3's.
		local absorb = grug_classes.get_talent_bonus(user, "smite_absorb")
		grug_core.deal_ability_damage(user, target, def.values(user).damage, {
			on_accepted = function(_, _, action_id)
				if absorb > 0 then
					grug_core.add_absorb(user, "recompense", support_value(user, absorb),
						15, user, action_id)
				end
			end,
		})
		return true
	end,
})

grug_abilities.register_ability({
	id = "flash_heal",
	class = "priest",
	name = "Flash Heal",
	kind = "cast",
	target_kind = "friendly",
	description = "Heals the pointed ally (or yourself); healing scales with your level.",
	values = function(user)
		return {
			heal = support_value(user, 25
				+ grug_classes.get_talent_bonus(user, "flash_heal_add")),
		}
	end,
	description_for = function(user, def)
		return ("Heals the pointed ally (or yourself) for %d."):format(
			effective_support_number(def.values(user).heal))
	end,
	color = "#7ae08a",
	cost = {mana_percent = 8},
	cooldown = 4,
	range = 15,
	cast = function(user, pointed, def)
		local target, err = grug_abilities.resolve_friendly_target(
			user, pointed, def)
		if not target then
			return false, err
		end
		if target:get_hp() <= 0 then
			return false, "Target is dead."
		end
		-- Gentle Hand (skill_trees.md §2.5); Hearten's splash is lane X3's.
		local amount = def.values(user).heal
		local action_id = {}
		grug_core.heal_player(user, target, amount,
			{action_id = action_id})
		local splash = grug_classes.get_talent_bonus(user, "flash_heal_splash")
		if splash > 0 then
			for _, obj in ipairs(core.get_objects_inside_radius(target:get_pos(), 8)) do
				if obj ~= target and grug_abilities.valid_target(user, obj, "friendly") then
					grug_core.heal_player(user, obj,
						math.floor(amount * splash / 100), {action_id = action_id})
				end
			end
		end
		burst(target:get_pos(), "mobs_heart_particle.png", 8)
		return true
	end,
})

-- Base-kit shield (kit tuning 2026-08-06, replaces Renew): an absorb
-- plays differently from a second heal and makes the Priest useful
-- BEFORE damage lands. The soak itself lives in grug_core's central hp
-- change modifier (grug_core.add_absorb).
grug_abilities.register_ability({
	id = "power_word_shield",
	class = "priest",
	name = "Power Word: Shield",
	kind = "cast",
	target_kind = "friendly",
	description = "Shields the pointed ally (or yourself); absorption scales\n" ..
		"with your level and lasts 15 s or until consumed.",
	values = function(user)
		return {
			absorb = support_value(user, 25
				+ grug_classes.get_talent_bonus(user, "shield_absorb_add")),
		}
	end,
	description_for = function(user, def)
		return ("Shields the pointed ally (or yourself): absorbs %d damage\n" ..
			"for 15 s or until consumed."):format(
				effective_support_number(def.values(user).absorb))
	end,
	color = "#e8e07a",
	cost = {mana_percent = 8},
	cooldown = 10,
	range = 15,
	cast = function(user, pointed, def)
		local target, err = grug_abilities.resolve_friendly_target(
			user, pointed, def)
		if not target then
			return false, err
		end
		if target:get_hp() <= 0 then
			return false, "Target is dead."
		end
		-- Warding Faith and Second Skin (skill_trees.md §2.5); their flat add
		-- joins the base before the central level scalar. The 15 s duration is
		-- unscaled. Turn Aside's dodge window is lane X3's.
		grug_core.add_absorb(target, "power_word_shield", def.values(user).absorb,
			15 + grug_classes.get_talent_bonus(user, "shield_duration_add"), user, {},
			{dodge_percent = talent_rank_value(user, "turn_aside", "dodge_chance_window", 0)})
		burst(target:get_pos(), "default_item_smoke.png^[multiply:#ffe9a0", 8)
		return true
	end,
})

-- Active renews: target name -> {ticks, amount, healer}
local renews = {}

-- Talent-gated (kit tuning 2026-08-06): stays registered, but sync_kit
-- does not grant it — the Priest's Mercy tree unlocks it in WP11, where Renew
-- is the Balm chain's keystone (skill_trees.md §2.5).
grug_abilities.register_ability({
	id = "renew",
	class = "priest",
	name = "Renew",
	kind = "cast",
	target_kind = "friendly",
	talent_gated = true,
	description = "Heal over time on the pointed ally (or yourself); healing\n" ..
		"scales with your level every 3 s for 12 s.\nUnlocked via talents.",
	values = function(user)
		return {heal = support_value(user, 8
			+ grug_classes.get_talent_bonus(user, "renew_tick_add"))}
	end,
	description_for = function(user, def)
		return ("Heal the pointed ally (or yourself) for %d every 3 s for 12 s.\n" ..
			"Unlocked via talents."):format(
				effective_support_number(def.values(user).heal))
	end,
	color = "#3fae6a",
	cost = {mana_percent = 6},
	cooldown = 8,
	range = 15,
	cast = function(user, pointed, def)
		local target, err = grug_abilities.resolve_friendly_target(
			user, pointed, def)
		if not target then
			return false, err
		end
		if target:get_hp() <= 0 then
			return false, "Target is dead."
		end
		-- Re-casting refreshes duration and snapshot amount.
		renews[target:get_player_name()] = {
			ticks = 4,
			amount = def.values(user).heal,
			healer = user:get_player_name(),
			action_id = {},
		}
		if grug_core.set_status then
			grug_core.set_status(target, "renew", {
				label = "Renew",
				duration = 12,
				kind = "buff",
			})
		end
		burst(target:get_pos(), "mobs_heart_particle.png", 5)
		return true
	end,
})

local renew_acc = 0

core.register_globalstep(function(dtime)
	renew_acc = renew_acc + dtime
	if renew_acc < 3 then
		return
	end
	renew_acc = 0
	for name, renew in pairs(renews) do
		local target = core.get_player_by_name(name)
		if not target or target:get_hp() <= 0 then
			renews[name] = nil
			if target and grug_core.clear_status then
				grug_core.clear_status(target, "renew")
			end
		else
			local healer = core.get_player_by_name(renew.healer) or target
			grug_core.heal_player(healer, target, renew.amount,
				{action_id = renew.action_id})
			burst(target:get_pos(), "mobs_heart_particle.png", 3)
			renew.ticks = renew.ticks - 1
			if renew.ticks <= 0 then
				renews[name] = nil
				if grug_core.clear_status then
					grug_core.clear_status(target, "renew")
				end
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	renews[player:get_player_name()] = nil
end)

core.register_on_dieplayer(function(player)
	renews[player:get_player_name()] = nil
end)

-- WP11 X3 talent-granted active skills. Entitlement is owned by the Skills
-- catalog through `talent_gated`; registering these definitions never inserts
-- or recreates an inventory representation.
grug_abilities.register_ability({
	id = "hold_ground", class = "warrior", talent_gated = true,
	kind = "cast", target_kind = "self", name = "Hold Ground",
	description = "Spend 25 rage to gain an absorb and root/slow immunity for 8 s.",
	color = "#c89b55", cost = {rage = 25}, cooldown = 60, range = 4,
	values = function(user)
		return {absorb = grug_core.base_pool(grug_core.get_player_level(user))
			* grug_classes.get_talent_bonus(user, "hold_ground_absorb") / 100}
	end,
	cast = function(user, pointed, def)
		grug_core.add_absorb(user, "hold_ground", def.values(user).absorb, 8,
			user, {})
		grug_core.set_move_immunity(user, 8)
		grug_classes.start_talent_window(user, "hold_ground", 8)
		burst(user:get_pos(), "default_item_smoke.png^[multiply:#c89b55", 14)
		return true
	end,
})

grug_abilities.register_ability({
	id = "cinderfall", class = "mage", talent_gated = true,
	kind = "cast", target_kind = "hostile", name = "Cinderfall",
	description = "Burst at the first aimed contact, damaging hostiles around it.",
	color = "#d85b2d", cost = {mana_percent = 12}, cooldown = 10, range = 20,
	cast = function(user, pointed, def)
		local ray = grug_core.combat_ray(user, grug_abilities.get_range(user, def))
		debug_cast_ray(user, def, ray)
		local pos = ray.pointed and ray.pointed.intersection_point
		if not pos or not ray.distance or ray.distance > ray.range then
			return false, "No contact in your crosshair."
		end
		local damage = spell_damage_value(user,
			grug_classes.get_talent_bonus(user, "cinderfall_damage")
			+ grug_classes.get_spell_power_bonus(user))
		local radius = 3 + grug_classes.get_talent_bonus(user,
			"cinderfall_radius_add")
		local action_id = {}
		for _, obj in ipairs(core.get_objects_inside_radius(pos, radius)) do
			if grug_abilities.valid_target(user, obj, "hostile") then
				grug_core.deal_ability_damage(user, obj, damage,
					{action_id = action_id})
			end
		end
		burst(pos, "mobs_fire_particle.png", 18)
		return true
	end,
})

grug_abilities.register_ability({
	id = "glacial_ward", class = "mage", talent_gated = true,
	kind = "cast", target_kind = "self", name = "Glacial Ward",
	description = "Surround yourself with a spell-powered absorb for 10 s.",
	color = "#8bd8f0", cost = {mana_percent = 10}, cooldown = 30, range = 4,
	values = function(user)
		return {absorb = support_value(user,
			grug_classes.get_talent_bonus(user, "glacial_ward_absorb"))}
	end,
	cast = function(user, pointed, def)
		grug_core.add_absorb(user, "glacial_ward", def.values(user).absorb, 10,
			user, {})
		burst(user:get_pos(), "mobs_bubble_particle.png^[multiply:#8bd8f0", 14)
		return true
	end,
})

grug_abilities.register_ability({
	id = "word_of_ruin", class = "priest", talent_gated = true,
	kind = "cast", target_kind = "hostile", name = "Word of Ruin",
	description = "Damage the aimed enemy and heal yourself from the damage.",
	color = "#a66bd4", cost = {mana_percent = 8}, cooldown = 12, range = 20,
	cast = function(user, pointed, def)
		local target = current_enemy_target(user, def)
		if not target then return false, "No hostile target in your crosshair." end
		local damage = spell_damage_value(user,
			grug_classes.get_talent_bonus(user, "word_of_ruin_damage")
			+ grug_classes.get_spell_power_bonus(user))
		grug_core.deal_ability_damage(user, target, damage, {
			on_accepted = function(dealt, _, action_id)
				local properties = user:get_properties() or {}
				if user:get_hp() < (tonumber(properties.hp_max) or 0) * 0.25 then
					grug_classes.try_trigger_talent_window(user, "last_word", 8, 180)
				end
				local ratio = grug_classes.get_talent_bonus(user, "drain_ratio_override")
				if ratio <= 0 then ratio = 50 end
				grug_core.heal_player(user, user, math.floor(dealt * ratio / 100),
					{no_crit = true, action_id = action_id})
			end,
		})
		return true
	end,
})
