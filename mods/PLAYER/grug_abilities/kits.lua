-- The MVP class kits (docs/design/classes.md §3–§5). Numbers live in the
-- design doc — change them there first.

--
-- Targeting helpers. Hostile casts use one current server eye/look ray;
-- pointed_thing and enemy memory are presentation/input context only. Friendly
-- heals retain their separate ally-memory fallback.
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

local function in_lock_range(user, obj, def)
	return vector.distance(user:get_pos(), obj:get_pos())
		<= grug_abilities.get_range(user, def)
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

-- Friendly target for heals: an explicit object is authoritative input. A
-- valid pointed ally locks; an invalid explicit object refuses the cast
-- without spending its cost or cooldown. Only the absence of an explicit
-- object may use the soft-locked ally — this is what makes healing moving
-- allies workable — or fall back to self. Deliberately no LOS check on the
-- fallback: healing the ally who just kited around a tree is the point of the
-- lock.
local function heal_target(user, pointed, def)
	if pointed and pointed.type == "object" then
		if pointed.ref and valid_ally(user, pointed.ref, def) then
			grug_abilities.set_target(user, pointed.ref, true)
			return pointed.ref
		end
		return nil, "Invalid target."
	end
	local obj = grug_abilities.get_target(user, true)
	if obj and valid_ally(user, obj, def)
			and in_lock_range(user, obj, def) then
		grug_abilities.set_target(user, obj, true) -- refresh the lock
		return obj
	end
	return user
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
-- Root/slow effects (Frost Nova, Hamstring). Mobs: grug_mobs.root/slow —
-- restore runs as a reload-safe countdown inside the mob's do_custom (a
-- core.after timer here once persisted permanently-immobile mobs into the
-- world file). Players (PvP): named modifiers on the grug_core movement
-- aggregator (ruling 11, 2026-09-16; skill_trees.md §3.9).
--
-- The staged chain this used to be is gone. It wrote `physics_override`
-- directly, walked its stages on a core.after chain and restored to
-- `{speed = 1, jump = 1}` after the last one — which clobbered every other
-- speed modifier in the game, and was the reason the old comment here said
-- "MVP caveat: the override clobbers other speed modifiers — fine while none
-- exist". Ruling 11 ends that: each stage is now its own NAMED modifier with
-- its OWN duration, they overlap freely, and the aggregator adds them per
-- axis under one clamp (ruling 26: `clamp(1 + Sum, 0.1, 1.5)`).
--
-- The shipped numbers are unchanged, and the arithmetic is worth writing out
-- because the overlap is what preserves them. Frost Nova's stages are
-- `{speed = 0.1, jump = 0.3, time = 4}` then `{speed = 0.5, time = 3}`:
--   * stage 1 registers speed -0.9 / jump -0.7 for 4 s,
--   * stage 2 registers speed -0.5 / jump 0 for 4+3 = 7 s (its duration runs
--     from NOW to the END of its window, so it overlaps stage 1),
--   * t < 4 s: speed = clamp(1 - 0.9 - 0.5) = 0.1, jump = 1 - 0.7 = 0.3,
--   * 4 s <= t < 7 s: speed = 1 - 0.5 = 0.5, jump = 1.
-- Both are exactly what the old chain wrote, and the clamp floor (0.1) is
-- the same number the design already used for the root stage.
--
-- The old "a stronger snare stage is running; keep it" guard is gone with
-- the chain, and nothing is lost: a Hamstring cast into a running Frost Nova
-- now ADDS -0.5 to the sum, which is already clamped at 0.1, so it still
-- cannot lift the ally's root. Effects overlapping freely is the ruling.
--
-- A relog inside the window still clears the effect (physics overrides are
-- not persisted, and the aggregator drops the record on join) — the accepted
-- MVP caveat is unchanged, and reconnecting takes longer than any current
-- effect.
--

-- stages: list of {speed = n, jump = n, time = seconds} — ABSOLUTE
-- multipliers, as the design writes them. `id` names the effect; stage i > 1
-- is registered as `id .. "_" .. i` so the stages of ONE cast overlap each
-- other but a second cast of the SAME ability refreshes rather than stacks.
local function apply_player_speed_stages(target, stages, id)
	local elapsed = 0
	for index = 1, #stages do
		local stage = stages[index]
		local name = index == 1 and id or (id .. "_" .. index)
		elapsed = elapsed + stage.time
		grug_core.set_move_modifier(target, name, {
			speed = stage.speed - 1,
			jump = (stage.jump or 1) - 1,
		}, elapsed)
	end
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
local strike_def = {
	id = "strike",
	kind = "swing",
	target_kind = "hostile",
	universal = true, -- every class, and a character with no class yet (E1)
	name = "Strike",
	-- The rage number is COMPOSED from the ledger constant rather than
	-- written out: this string is the one place a player reads it, and a
	-- second copy of a tuning number is a second thing to forget.
	description = "A full melee swing with your equipped weapon. Hold LMB and keep a hostile in your crosshair; the shared weapon clock prevents click spam. Generates " .. grug_abilities.RAGE_PER_SWING ..
		" rage when it lands.",
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
	description = "Dash to an enemy up to 12 m away, dealing 3 damage\n" ..
		"and generating 15 rage.",
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
		user:set_pos(dest)
		grug_abilities.add_rage(user, 15)
		grug_core.deal_ability_damage(user, target, 3, {threat_mult = 3})
		burst(tpos, "default_item_smoke.png", 8)
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
		return math.floor(ctx.weapon_damage * mult) + ctx.melee_bonus, 3,
			function() burst(tpos, "mobs_blood.png", 6) end
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
			if ent then
				grug_mobs.slow(ent, 5, 0.5)
			elseif target:get_hp() > 0 then
				apply_player_speed_stages(target, {{speed = 0.5, time = 5}},
					"hamstring")
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
		local target = current_enemy_target(user, def)
		if not target then
			return false, "No hostile target in your crosshair."
		end
		local ent = mob_ent(target)
		if not ent or not ent.attack_type then
			return false, "Cannot be taunted."
		end
		ent:do_attack(user, true)
		-- Threat part (combat_stats.md §4): sets the taunter to top×1.1 and
		-- suppresses hysteresis target switches for 3 s.
		grug_core.taunt(ent, user)
		burst(target:get_pos(), "default_item_smoke.png^[multiply:#e07b39", 6)
		return true
	end,
})

--
-- Mage (mana)
--

grug_projectiles.register("fireball", {
	speed = 20,
	max_distance = 20,
	-- Normal native use arrives at roughly five inputs per second and a flight
	-- lasts one second. Eight preserves that behavior while bounding a modified
	-- client's zero-cooldown burst per owner/session.
	active_limit = 8,
	-- Distance expires after one second at the decided speed. The longer
	-- lifetime is only a stalled/unloaded-motion safety guard.
	lifetime = 2,
	properties = {
		is_visible = true,
		visual = "sprite",
		textures = {"mobs_fire_particle.png"},
		visual_size = {x = 0.7, y = 0.7},
		glow = 12,
	},
	on_hit = function(owner, target, data)
		grug_core.deal_ability_damage(owner, target, data.damage)
	end,
})

-- Bread-and-butter nuke (kit tuning 2026-08-06): pays with mana instead
-- of a cooldown — 5 mana against a 240+ pool was free. It is directional:
-- target acquisition belongs to the projectile, not cast-time enemy memory.
grug_abilities.register_ability({
	id = "fireball",
	class = "mage",
	name = "Fireball",
	kind = "cast",
	target_kind = "hostile",
	description = "Hurls fire along your crosshair for up to 20 m:\n" ..
		"6 + spell power damage; misses still cost mana.",
	color = "#ff8833",
	cost = {mana = 8},
	cooldown = 0,
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
		local spawned = grug_projectiles.spawn("fireball", {
			owner = user,
			origin = origin,
			direction = direction,
			-- The FLIGHT half of Far Cast. grug_projectiles prefers
			-- params.max_distance over the registered one (init.lua:195), and
			-- the registration's 20 is a load-time constant.
			max_distance = 20 + grug_classes.get_talent_bonus(user,
				"fireball_range_add"),
			data = {
				-- Tinder (skill_trees.md §2.3). Brand's splash is lane X3's.
				damage = 6 + grug_classes.get_spell_power_bonus(user)
					+ grug_classes.get_talent_bonus(user, "fireball_damage_add"),
			},
		})
		if not spawned then
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
grug_abilities.register_ability({
	id = "frost_nova",
	class = "mage",
	name = "Frost Nova",
	kind = "cast",
	target_kind = "self",
	description = "Roots all enemies within 5 m for 4 s,\n" ..
		"then slows them by 50% for 3 s.",
	color = "#66b8ff",
	cost = {mana = 10},
	cooldown = 12,
	range = 4,
	cast = function(user)
		local pos = user:get_pos()
		-- Deep Chill and Hoarfrost (skill_trees.md §2.4); 0 each without the
		-- talent, so the shipped 4 s root and 3 s slow are exact. Frostbind's
		-- ranged origin and Rimebite's damage are lane X3's.
		local root_time = 4 + grug_classes.get_talent_bonus(user,
			"frost_nova_root_add")
		local slow_time = 3 + grug_classes.get_talent_bonus(user,
			"frost_nova_slow_add")
		for _, obj in ipairs(core.get_objects_inside_radius(pos, 5)) do
			if grug_abilities.valid_target(user, obj, "hostile") then
				if obj:is_player() then
					apply_player_speed_stages(obj, {
						{speed = 0.1, jump = 0.3, time = root_time},
						{speed = 0.5, time = slow_time},
					}, "frost_nova")
					burst(obj:get_pos(), "mobs_bubble_particle.png^[multiply:#88ccff", 8)
				else
					local ent = mob_ent(obj)
					if ent then
						grug_mobs.root(ent, root_time)
						-- queued: starts after the root
						grug_mobs.slow(ent, slow_time, 0.5)
						burst(obj:get_pos(), "mobs_bubble_particle.png^[multiply:#88ccff", 8)
					end
				end
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
	cost = {mana = 8},
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
	description = "Smites an enemy up to 20 m away:\n" ..
		"4 + spell power damage.",
	color = "#ffd97a",
	cost = {mana = 4},
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
		local damage = 4 + grug_classes.get_spell_power_bonus(user)
			+ grug_classes.get_talent_bonus(user, "smite_damage_add")
		if grug_core.get_absorb(user) > 0 then
			damage = damage + grug_classes.get_talent_bonus(user,
				"smite_damage_while_shielded_add")
		end
		grug_core.deal_ability_damage(user, target, damage)
		return true
	end,
})

grug_abilities.register_ability({
	id = "flash_heal",
	class = "priest",
	name = "Flash Heal",
	kind = "cast",
	target_kind = "friendly",
	description = "Heals the pointed ally (or yourself) for\n" ..
		"8 + 2x spell power.",
	color = "#7ae08a",
	cost = {mana = 8},
	cooldown = 4,
	range = 15,
	cast = function(user, pointed, def)
		local target, err = heal_target(user, pointed, def)
		if not target then
			return false, err
		end
		if target:get_hp() <= 0 then
			return false, "Target is dead."
		end
		-- Gentle Hand (skill_trees.md §2.5); Hearten's splash is lane X3's.
		grug_core.heal_player(user, target,
			8 + 2 * grug_classes.get_spell_power_bonus(user)
			+ grug_classes.get_talent_bonus(user, "flash_heal_add"))
		burst(target:get_pos(), "mobs_heart_particle.png", 8)
		return true
	end,
})

-- Base-kit shield (kit tuning 2026-08-06, replaces Renew): an absorb
-- plays differently from a second heal and makes the Priest useful
-- BEFORE damage lands. The soak itself lives in grug_core's central hp
-- change modifier (grug_core.set_absorb).
grug_abilities.register_ability({
	id = "power_word_shield",
	class = "priest",
	name = "Power Word: Shield",
	kind = "cast",
	target_kind = "friendly",
	description = "Shields the pointed ally (or yourself): absorbs\n" ..
		"8 + 2x spell power damage for 15 s or until consumed.",
	color = "#e8e07a",
	cost = {mana = 8},
	cooldown = 10,
	range = 15,
	cast = function(user, pointed, def)
		local target, err = heal_target(user, pointed, def)
		if not target then
			return false, err
		end
		if target:get_hp() <= 0 then
			return false, "Target is dead."
		end
		-- Warding Faith and Second Skin (skill_trees.md §2.5); their flat add
		-- joins the base before the central level scalar. The 15 s duration is
		-- unscaled. Turn Aside's dodge window is lane X3's.
		grug_core.set_absorb(target,
			8 + 2 * grug_classes.get_spell_power_bonus(user)
			+ grug_classes.get_talent_bonus(user, "shield_absorb_add"),
			15 + grug_classes.get_talent_bonus(user, "shield_duration_add"), user)
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
	description = "Heal over time on the pointed ally (or yourself):\n" ..
		"3 + spell power every 3 s for 12 s.\nUnlocked via talents.",
	color = "#3fae6a",
	cost = {mana = 6},
	cooldown = 8,
	range = 15,
	cast = function(user, pointed, def)
		local target, err = heal_target(user, pointed, def)
		if not target then
			return false, err
		end
		if target:get_hp() <= 0 then
			return false, "Target is dead."
		end
		-- Re-casting refreshes duration and snapshot amount.
		renews[target:get_player_name()] = {
			ticks = 4,
			amount = 3 + grug_classes.get_spell_power_bonus(user),
			healer = user:get_player_name(),
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
			grug_core.heal_player(healer, target, renew.amount)
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
